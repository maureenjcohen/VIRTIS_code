PRO get_cooler_time_from_CMH
; Read Cooler times from the Command History File (CMDPF)


  ON_ERROR, 0
  ;ON_IOERROR, ERROR

  IF N_ELEMENTS(file_path) EQ 0 THEN $
        file_path=dialog_pickfile(path="C:\VVX Data Archive\DDS Files\",$
                                  TITLE="Select input CMDPF file", FILTER=["*CMDPF*.dat","*.*"])
  IF file_path EQ "" THEN return


  ;;============================================================
  ;; Extract COOLER commands from command history file
  ;;============================================================

  OPENR, unit, file_path, /GET_LUN

  cooler_M_ON = 0d
  cooler_M_OFF= 0d

  cooler_H_ON = 0d
  cooler_H_OFF= 0d

  M_total_time = 0d ;M cooler total time
  H_total_time = 0d ;H cooler total time

  M_status="OFF" ;initial state
  H_status="OFF" ;initial state

  row = ""
  counter = 0ULL

  WHILE ~ EOF(unit) DO BEGIN

     counter +=1

     readf,unit,row

     IF STRPOS(row, "ZVR")     NE  0 THEN CONTINUE ;skip non Virtis commands
     IF STRPOS(row, "Cooler")  EQ -1 THEN CONTINUE ;skip non cooler commands
     IF STRPOS(row, "D   D  ") NE -1 THEN CONTINUE ;skip deleted commands
     IF STRPOS(row, "DELETED") NE -1 THEN CONTINUE ;skip deleted commands
     IF STRPOS(row, "ABORTED") NE -1 THEN CONTINUE ;skip deleted commands

     ZVRcommand  = STRMID(row, 0, 8) ; extract ZVR command

     ;Extract Date+Time
     yyyy = long(STRMID(row, 76, 2) + 2000)
     doy  = long(STRMID(row, 79, 3))
     hh   = long(STRMID(row, 83, 2))
     mm   = long(STRMID(row, 86, 2))
     ss   = long(STRMID(row, 89, 2))

     ;Convert to Julian
     juldate = double( JULDAY(1,1,yyyy,hh,mm,ss) + doy-1 ) ;use 1stJan and add DOY-1 (can't process DOY directly)

     ;; M cooler ON
     IF ZVRcommand EQ "ZVR00113" || ZVRcommand EQ "ZVR00125" THEN BEGIN
       IF M_status EQ "ON" THEN print, "WARNING: M cooler already ON [Line:"+strtrim(counter,2)+"] Orbit "+string(orbit_get(v_jul2scet(juldate ,/NO_WARN,/DOUBLE),orbitarray),F='(I04)')$
       ELSE $
        cooler_M_ON =[cooler_M_ON , juldate]
       M_status="ON"
     ENDIF

     ;; H cooler ON
     IF ZVRcommand EQ "ZVR00113" || ZVRcommand EQ "ZVR00136" || ZVRcommand EQ "ZVR00114" THEN BEGIN
       IF H_status EQ "ON" THEN print, "WARNING: H cooler already ON [Line:"+strtrim(counter,2)+"] Orbit "+string(orbit_get(v_jul2scet(juldate ,/NO_WARN,/DOUBLE),orbitarray),F='(I04)')$
       ELSE $
        cooler_H_ON =[cooler_H_ON , juldate]
       H_status="ON"
     ENDIF

     ;; M cooler OFF
     IF ZVRcommand EQ "ZVR00115" || ZVRcommand EQ "ZVR00127" || ZVRcommand EQ "ZVR00114" THEN BEGIN
       IF M_status EQ "OFF" THEN print, "WARNING: M cooler already OFF [Line:"+strtrim(counter,2)+"] Orbit "+string(orbit_get(v_jul2scet(juldate ,/NO_WARN,/DOUBLE),orbitarray),F='(I04)')$
       ELSE $
        cooler_M_OFF=[cooler_M_OFF, juldate]
       M_status="OFF"
     ENDIF

     ;; H cooler OFF
     IF ZVRcommand EQ "ZVR00115" || ZVRcommand EQ "ZVR00138" THEN BEGIN
       IF H_status EQ "OFF" THEN print, "WARNING: H cooler already OFF [Line:"+strtrim(counter,2)+"] Orbit "+string(orbit_get(v_jul2scet(juldate ,/NO_WARN,/DOUBLE),orbitarray),F='(I04)')$
       ELSE $
        cooler_H_OFF=[cooler_H_OFF, juldate]
       H_status="OFF"
     ENDIF

  ENDWHILE

  free_lun,unit
  close, unit

  ;;============================================================

  IF N_ELEMENTS(cooler_M_ON) EQ 1 || N_ELEMENTS(cooler_M_OFF) EQ 1  ||  $
     N_ELEMENTS(cooler_H_ON) EQ 1 || N_ELEMENTS(cooler_H_OFF) EQ 1 THEN $
        message, "###ERROR### ON/OFF commands not found"

  cooler_M_ON = cooler_M_ON[1:*]  ;remove initial value 0.0
  cooler_H_ON = cooler_H_ON[1:*]  ;remove initial value 0.0
  cooler_M_OFF= cooler_M_OFF[1:*] ;remove initial value 0.0
  cooler_H_OFF= cooler_H_OFF[1:*] ;remove initial value 0.0

 ; cooler_M_ON = cooler_M_ON[where(ceil(cooler_M_ON) NE 2454369)]  ;remove the ON command when VIRTIS was switched off by ESOC (24Sep2007)

  IF N_ELEMENTS(cooler_M_ON) NE N_ELEMENTS(cooler_M_OFF) THEN print, "###WARNING### Inconsistency between M ON and M OFF commands"
  IF N_ELEMENTS(cooler_H_ON) NE N_ELEMENTS(cooler_H_OFF) THEN print, "###WARNING### Inconsistency between H ON and H OFF commands"

  ; Convert to SCET time
  cooler_M_ON = v_jul2scet(cooler_M_ON ,/NO_WARN,/DOUBLE)
  cooler_H_ON = v_jul2scet(cooler_H_ON ,/NO_WARN,/DOUBLE)
  cooler_M_OFF= v_jul2scet(cooler_M_OFF,/NO_WARN,/DOUBLE)
  cooler_H_OFF= v_jul2scet(cooler_H_OFF,/NO_WARN,/DOUBLE)

  ; Get cooler duration
  cooler_M_Duration = (cooler_M_OFF - cooler_M_ON)/3600. ; in hours
  cooler_H_Duration = (cooler_H_OFF - cooler_H_ON)/3600. ; in hours

  ; Get orbit numbers
  M_ON_Orbit  = string(orbit_get(cooler_M_ON , orbitarray),F='(I04)') ;orbitarray is not needed, used for faster check
  H_ON_Orbit  = string(orbit_get(cooler_H_ON , orbitarray),F='(I04)') ;orbitarray is not needed, used for faster check

  ; Get MTP numbers
  M_ON_MTP    = v_orbit2mtp(M_ON_Orbit,/STR)
  H_ON_MTP    = v_orbit2mtp(H_ON_Orbit,/STR)


; ==================================================================
;  VIRTIS - M (calculate total times per MTP)
; ==================================================================

  ; initialise variables
  previousMTP = ""  ; name of previous MTP processed
  MTP_Names_M = ""  ; matrix of MTP names
  MTP_Times_M = 0.0 ; matrix of MTP total times
  iMTP        = 0   ; index of MTP

  FOR i=0, N_ELEMENTS(M_ON_MTP)-1 DO BEGIN

	; if it's a new MTP
	if M_ON_MTP[i] ne previousMTP then begin
		iMTP        = iMTP + 1                   ; increment MTP index
		MTP_Names_M = [MTP_Names_M, M_ON_MTP[i]] ; add name of the MTP to array
        MTP_Times_M = [MTP_Times_M,0.0]          ; add new counter for this MTP
	endif

	; increment duration
	MTP_Times_M[iMTP] = MTP_Times_M[iMTP]+cooler_M_Duration[i]

	previousMTP = M_ON_MTP[i]

  ENDFOR

; ==================================================================
;  VIRTIS - H (calculate total times per MTP)
; ==================================================================

 ; initialise variables
  previousMTP = ""  ; name of previous MTP processed
  MTP_Names_H = ""  ; matrix of MTP names
  MTP_Times_H = 0.0 ; matrix of MTP total times
  iMTP        = 0   ; index of MTP

  FOR i=0, N_ELEMENTS(H_ON_MTP)-1 DO BEGIN

	; if it's a new MTP
	if H_ON_MTP[i] ne previousMTP then begin
		iMTP        = iMTP + 1                   ; increment MTP index
		MTP_Names_H = [MTP_Names_H, H_ON_MTP[i]] ; add name of the MTP to array
        MTP_Times_H = [MTP_Times_H,0.0]          ; add new counter for this MTP
	endif

	; increment duration
	MTP_Times_H[iMTP] = MTP_Times_H[iMTP]+cooler_H_Duration[i]

	previousMTP = H_ON_MTP[i]

  ENDFOR

  ; remove first dummy value
  MTP_Names_M = MTP_Names_M[1:*]
  MTP_Times_M = MTP_Times_M[1:*]
  MTP_Names_H = MTP_Names_H[1:*]
  MTP_Times_H = MTP_Times_H[1:*]

  ; Merge Times and names of MTPs in a single string array
  Total_MTP_M = MTP_Names_M + "	"+ string(MTP_Times_M,F='(F7.2)')
  Total_MTP_H = MTP_Names_H + "	"+ string(MTP_Times_H,F='(F7.2)')

  ; Merge Times of each orbit in a single string array
  VIRTIS_M_array = M_ON_MTP+"	"+M_ON_Orbit+"	"+string(cooler_M_ON,F='(F15.3)')+"	"+string(cooler_M_OFF,F='(F15.3)')+"	"+string(cooler_M_DURATION,F='(F7.2)')
  VIRTIS_H_array = H_ON_MTP+"	"+H_ON_Orbit+"	"+string(cooler_H_ON,F='(F15.3)')+"	"+string(cooler_H_OFF,F='(F15.3)')+"	"+string(cooler_H_DURATION,F='(F7.2)')


  ; ------------------------------------------------------------------------

  M_text = ["TOTAL COOLER DURATION :"+string(total(cooler_M_duration),F='(F7.2)')+" hours","",$
            "==========================================="               ,$
 		    "      VIRTIS-M Total Time per MTP          "               ,$
 		    "==========================================="               ,$
 		    " MTP           Time",$
		    "---------------------",$
		     Total_MTP_M,"",$
		    "==========================================="               ,$
		    "      VIRTIS-M cooler time by orbit"                       ,$
		    "==========================================="               ,$
		    "MTP    ORBIT       SCET_ON        SCET_OFF         Time",$
		    "--------------------------------------------------------",$
             VIRTIS_M_Array]

  H_text = ["TOTAL COOLER DURATION :"+string(total(cooler_H_duration),F='(F7.2)')+" hours","",$
            "==========================================="               ,$
 		    "      VIRTIS-H Total Time per MTP          "               ,$
 		    "==========================================="               ,$
 		    " MTP           Time",$
		    "---------------------",$
		     Total_MTP_H,"",$
		     "==========================================="               ,$
		    "      VIRTIS-H cooler time by orbit"                       ,$
		    "==========================================="               ,$
		    "MTP    ORBIT       SCET_ON        SCET_OFF         Time",$
		    "--------------------------------------------------------",$
             VIRTIS_H_Array]

  xdisplayfile, dummy, text=M_text, TITLE="VIRTIS-M Cooler Times from Command History", FONT="Courier*8", WIDTH=60, /EDIT
  xdisplayfile, dummy, text=H_text, TITLE="VIRTIS-H Cooler Times from Command History", FONT="Courier*8", WIDTH=60, /EDIT

 return

ERROR:
message, "IOerror found"

END

;     ;; M cooler ON
;     IF ZVRcommand EQ "ZVR00113" || ZVRcommand EQ "ZVR00125" THEN cooler_ON_time=juldate
;     ENDIF
;
;     ;; H cooler ON
;     IF ZVRcommand EQ "ZVR00113" || ZVRcommand EQ "ZVR00136" THEN cooler_ON_time=juldate
;     ENDIF
;
;     IF ZVRcommand EQ "ZVR00115" || ZVRcommand EQ "ZVR00127" THEN BEGIN
;     ENDIF
;
;     IF ZVRcommand EQ "ZVR00115" || ZVRcommand EQ "ZVR00138" THEN BEGIN
;     ENDIF
