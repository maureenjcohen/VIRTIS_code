;+
; NAME:
;     Get_Cooler_Times_From_Log
;
; PURPOSE:
;     Calculates the cooling duration for each orbit and MTP from the VIRTIS log file (e.g. VIRTIS_log_v5.0.txt)
;     The cooling times are an estimation from the start and end of the observations
;     A cooling time of 3h is added to each orbit, corresponding to the Cool Down phase  (optional)
;     An extra correction of 38min is added for M before MTP023 (optional)
;
; CALLING SEQUENCE:
;     Get_Cooler_Times_From_Log [,log_path] [,/NO_COOLDOWN][,/NO_CORRECTION]
;
; OPTIONAL INPUTS:
;     log_path : input path of the VIRTIS log file
;
;     If no inputs are provided, program prompts for input log filepath
;
; OPTIONAL KEYWORDS:
;     NO_COOLDOWN: by default the routine adds 3h of cooling down.
;                  Set this keyword to consider only the time from first to last observation.
;
;     NO_CORRECTION: by default the routine adds a correction of 38min for M files before MTP023
;                    Set this keyword to ignore this correction.
;
; OUTPUTS:
;     One log window is shown for each channel (H&M) with the cooler times for each orbit and MTP
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;
; MODIFICATION HISTORY:
;     Written by Alejandro Cardesin, IASF-INAF, April 2008, alejandro.cardesin @ iasf-roma.inaf.it
;
;-

;------------------------------------------------------
; Function to conver SCETs into float
function virtis_get_float_scet, SCETin
	SCETsplit= (strsplit(SCETin   ,"/",/EXTRACT))[1]  ; remove partition "1/"
	SCETint  = (strsplit(SCETsplit,".",/EXTRACT))[0]  ; get integer part
	SCETfrac = (strsplit(SCETsplit,".",/EXTRACT))[1]  ; get fractional part
	SCETout = Ulong(SCETint) + double(SCETfrac) / 2d ^ 16d
	return, SCETout
end
;------------------------------------------------------

;========================================================
; MAIN ROUTINE: read cooler times from virtis log file
;=======================================================
pro get_cooler_times_from_log, log_path, NO_CoolDown=NO_CoolDown, NO_Correction=NO_Correction

	; set keyword to add cooldown time (+3h) and correction (+38min for M channel until MTP22)
	NO_CoolDown   = keyword_set(NO_CoolDown  )
	NO_Correction = keyword_set(NO_Correction)

	; select log file if not given
	if N_ELEMENTS(log_path) EQ 0 THEN log_path = dialog_pickfile(path="dummmy_path", FILTER="*.txt")
	if log_path EQ "" then return

	; Open log file
	openr, log, log_path, /get_lun
	nlines = file_lines(log_path)
	line = ""

	; READ KEYWORD NAMES FROM TITLE -----------------------------------------
	readf, log, line ; read titles

	titles = line
	titles = strsplit(titles,"	",/EXTRACT)

	iCHANNEL = where(STRPOS(STRUPCASE(titles),"CHANNEL_ID") GE 0)
	if N_ELEMENTS(iCHANNEL) NE 1 || iCHANNEL EQ -1 THEN $
		message, "ERROR: could not find CHANNEL_ID"

	iSCETstart = where(STRPOS(STRUPCASE(titles),"CLOCK_START_COUNT") GE 0)
	if N_ELEMENTS(iSCETstart) NE 1 || iSCETstart EQ -1 THEN $
		message, "ERROR: could not find CLOCK_START_COUNT"

	iSCETstop  = where(STRPOS(STRUPCASE(titles),"CLOCK_STOP_COUNT") GE 0)
	if N_ELEMENTS(iSCETstop) NE 1 || iSCETstop EQ -1 THEN $
		message, "ERROR: could not find CLOCK_STOP_COUNT"

	ifilename  = (where(STRPOS(STRUPCASE(titles),"PRODUCT_ID") GE 0))[0]
	if N_ELEMENTS(ifilename) LT 1 || ifilename EQ -1 THEN $
		message, "ERROR: could not find PRODUCT_ID"

	iMTP       = where(STRPOS(STRUPCASE(titles),"PLANNING_CYCLE") GE 0)
	if N_ELEMENTS(iMTP) NE 1 || iMTP EQ -1 THEN $
		message, "ERROR: could not find PLANNING_CYCLE"

	iDURATION  = where(STRPOS(STRUPCASE(titles),"DURATION") GE 0)
	if N_ELEMENTS(iDURATION) NE 1 || iDURATION EQ -1 THEN $
		message, "ERROR: could not find DURATION"
	; ----------------------------------------------------------------------


	; ==========================================================================
	; CHECK COOLER DURATION FOR BOTH CHANNELS H-M
	;
	VIRTIS_CHANNEL= ["VIRTIS-M","VIRTIS-H"]

	for ch=0, 1 do begin ; for both channels M-H

		point_lun, log, 1		; point to first valid line

		; Initialise variables
		previousMTP   = ""
		previousOrbit = ""
		firstStart= 0.
		lastStop  = 0.
		TotOrbit  = 0.
		TotMTP    = 0.
		TotMission= 0.

		; Set titles for output logs
		Total_table = ["==========================================="      ,$
		               "      "+VIRTIS_CHANNEL[ch]+" cooler time by orbit",$
		               "==========================================="      ,$
		               "MTP	ORBIT	Orb_TIME	MTP_TIME	Total_Time"   ,$
		               "----------------------------------------------------------"]
		MTP_list    = ["==========================================="      ,$
		               "      "+VIRTIS_CHANNEL[ch]+" cooler time by MTP"  ,$
		               "==========================================="      ,$
		               "MTP	   Hours"                                     ,$
		               "----------------"]


		;---------------------------------------------------------------
		; PROCESS EACH LINE OF THE LOG FILE
		;
		FOR i=0, nlines-2 do begin

			; Read line and split values
			readf, log, line
			values = strsplit(line, "	",/EXTRACT)

			; Get the values we need
			filename = values[ifilename ]
			MTP      = values[iMTP      ]
			SCETstart= values[iSCETstart]
			SCETstop = values[iSCETstop ]
			Duration = values[iDuration ]
			Channel  = values[iChannel  ]

			; Get orbit number and file type ("I","V","S","T","H")
			orbit     = STRMID(filename, 2,4)
			qube_type = STRMID(filename, 1,1)

			; Skip files from CRUISE, VOI and VOCP
			IF STRPOS(MTP,"MTP") LT 0 THEN CONTINUE

			; Consider only Infrared files for VIRTIS-M and "S" files for VIRTIS-H
			IF (ch EQ 0 && qube_type NE "I") || (ch EQ 1 && qube_type NE "S") THEN CONTINUE

			; special case for first file
			if previousorbit eq "" then begin
				firstStart = virtis_get_float_scet(SCETstart[0]) ; set first start time
				lastStop   = virtis_get_float_scet(SCETstop[0] ) ; set last  stop  time
				previousMTP   = MTP
				previousorbit = orbit
				continue
			endif

			; When a new orbit is found, calculate duration of the previous orbit and update log
			if orbit ne previousorbit then begin

				; calculate cooler duration of previous orbit
				TotOrbit    = (lastStop - firstStart)/3600.; total time for this orbit
				if TotOrbit lt 0 then message, "Error calculating cooler time: negative duration."
				If ~(NO_CoolDown) THEN TotOrbit = TotOrbit +3 ; add 3h cooldown unless keyword is set
				If ~(NO_Correction) && (MTP lt "MTP023") && (ch eq 1) then TotOrbit = TotOrbit+0.6 ; for M before MTP023 add also 38min

				; Increase counters
				TotMTP      = TotMTP    + TotOrbit  ; total time for this MTP
				TotMission  = TotMission+ TotOrbit  ; total time for this Mission

				; Update log
				if i ne 0 then $ ;skip first time
				Total_Table = [Total_Table, string(previousMTP)+"	"+string(previousorbit,F='(I5)')+"	"+$
			                            	string(TotOrbit   ,F='(F8.2)')+"	"+string(TotMTP       ,F='(F8.2)')+"	"+string(TotMission,F='(F10.2)')]

				; If a new MTP is found, write MTP duration in log and reset counter
				if MTP ne previousMTP then begin
					MTP_list = [MTP_list,previousMTP+"	"+string(TotMTP,F='(F8.2)')]
					TotMTP = 0.
				endif

				; Save the time of the first switch ON in this orbit
				firstStart = virtis_get_float_scet(SCETstart[0])
			endif

			; Save the time of the last switch OFF in this orbit
			lastStop   = virtis_get_float_scet(SCETstop[0] )

			; Update previous variables
			previousMTP   = MTP
			previousorbit = orbit

		endfor ;for each line of the file
		; ---------------------------------------------------------

		; Calculate duration also for last orbit of the file
		TotOrbit    = (lastStop - firstStart)/3600.; total time for this orbit
		if TotOrbit lt 0 || TotOrbit gt 24 then message, "Error calculating cooler time: duration is negative or bigger than 24h: "+TotOrbit
		If ~(NO_CoolDown) THEN TotOrbit = TotOrbit +3 ; add 3h cooldown unless keyword is set
		If ~(NO_Correction) && (MTP lt "MTP023") && (ch eq 1) then TotOrbit = TotOrbit+0.6 ; for M before MTP023 add also extra 38min

		; Increase counters
		TotMTP      = TotMTP    + TotOrbit  ; total time for this MTP
		TotMission  = TotMission+ TotOrbit  ; total time for this Mission

		; Update log
		Total_Table = [Total_Table, string(previousMTP)+"	"+string(previousorbit,F='(I5)')+"	"+$
			                            	string(TotOrbit   ,F='(F8.2)')+"	"+string(TotMTP       ,F='(F8.2)')+"	"+string(TotMission,F='(F10.2)')]

		; Update MTP list
		MTP_list = [MTP_list,previousMTP+"	"+string(TotMTP,F='(F8.2)')]

		; Display Log file
		xdisplayfile, dummy, text=["TOTAL COOLER DURATION :"+string(TotMission,F='(F7.2)')+" hours","", string(MTP_list),"", string(Total_Table)], TITLE = VIRTIS_CHANNEL[ch]+" Cooler Time from log", FONT="COURIER*8", WIDTH=60, /EDIT

	endfor ;for both channels M+H
	; ==========================================================================

	close, log
	free_lun, log

end
