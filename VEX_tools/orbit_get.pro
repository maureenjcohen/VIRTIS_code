;+
; NAME:
;     orbit_get
;
; PURPOSE:
;     this routine returns the orbit number which corresponds to a given Spacecraft clock time
;     The orbit number is calculated from the percienter time written in the SPICE ORVF/ORVV kernels
;     The orbit split time is defined as Pericenter time +6h
;
; CALLING SEQUENCE:
;     orbit= orbit_get (scet [,orbitarray][,/CONVERT_SCET][,/ORVV])
;
; INPUTS:
;     scet : Spacecraft clock time.
;            It can be a Number or a String, with or without partition, 1 element or N element array
;            Valid examples: 43232323 or 43232323.2 or '43232323.2' or '1/43232323.2'
;
; OPTIONAL INPUTS:
;     orbitarray : Variable with the 2-D array with the scets for each orbit
;                  If this variable is set, the function uses it instead of reading the SPICE file,
;                  which increases the speed (for multiple orbit searchs)
;     *Note: if orbitarray is given, ORVV keyword is ignored
;
; OPTIONAL KEYWORDS:
;     CONVERT_SCET : if active, the input variable scet is converted to double after execution
;
;     ORVV : if active, the routine reads the corrected kernel (instead of the predicted one by default)
;
;     *Note: if orbitarray is given, ORVV keyword is ignored
;
; OUTPUTS:
;     returns the orbit number (integer) which corresponds to the input SCET time
;     returns -1 if the given time is outside the kernel limits
;     The orbit number is taken from the SPICE orbit file ORVF_______________000xx.ORB
;     For Cruise phase (before orbit insertion) the orbit number returned is 9999
;     If CONVERT_SCET is set, input variable scet is converted to double after execution.
;
; OPTIONAL OUTPUT:
;     orbitarray : Variable to store the 2-D array with the scets for each orbit
;                  to be used as input for next runs of the function
;
; EXAMPLES:
;     Simple call of the function: (scet variable is not modified)
;           orbit_num = orbit_get(scet)
;
;     Simple call of the function: (scet variable is converted to double)
;           orbit_num = orbit_get(scet, /CONVERT_SCET)
;
;     N-element array of SCET times is also allowed:
;           orbit_num = orbit_get([scet1,scet2,scet3,scet4])
;
;     For multiple calls of the function, using orbitarray increases speed:
;           orbit1_num = orbit_get(scet1,orbitarray) ;array is obtained as output of first call
;           orbit2_num = orbit_get(scet2,orbitarray) ;does not read SPICE file anymore
;           orbit3_num = orbit_get(scet3,orbitarray) ;does not read SPICE file anymore
;           orbit4_num = orbit_get(scet4,orbitarray) ;does not read SPICE file anymore
;
;     Use corrected orbit file instead of the predicted one (only past orbits are considered)
;           orbit_num = orbit_get(scet, /ORVV)
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;     Uses the kernels in the spice kernels directory 'orbnum': "ftp://ssols01.esac.esa.int/pub/data/SPICE/VEX/kernels/orbnum/"
;          either the predicted ORVF_*.ORB or the corrected one ORVF_*.ORB
;
; MODIFICATION HISTORY:
;     Written by Giuseppe Piccioni, IASF-INAF, August 2006, giuseppe.piccioni @ iasf-roma.inaf.it
;     29 Nov 2006 by A.Cardesin: added nice comments
;                                added support for input scet number or string (with/without partition)
;                                added search for SPICE Orbit file within directory
;                                added support for Cruise phase (orbit 9999 by convention)
;                                added option to input/output orbitarray, and thus improve speed
;                                added CONVERT_SCET keyword to convert scet time to double
;     08 Nov 2007 by A.Cardesin: modified orbitarrray is always array of pericenter times
;                                added ORVV keyword to select which SPICE kernel to use (predicted or not)
;                                solved bug checking whether SCET is higher than the maximum time in the orbit file
;                                changed Orbit split time from PERI+7h to PERI+6h
;     24 Apr 2008 by A.Cardesin: modified to allow also array of SCET as input
;     30 Jul 2008 by A.Cardesin: added server address
;-

function orbit_get,inputSCET, orbitarray, CONVERT_SCET=convert_scet, ORVV=orvv

 dummy=strarr(1)
 row=strarr(1)
 rowflt=0.
 rowarr=0.d
 SPICEpath='C:\SPICE\'

 orbit_num = make_array(N_elements(inputSCET), /LONG)

 for i =0, N_elements(inputSCET)-1 do begin

    ;;
    ;; Check SCET Time
    ;;
;    IF N_ELEMENTS(inputSCET) NE 1 THEN $
;       message, "ERROR: input SCETtime must be a scalar String or Number"

    ; inputSCET will not be modified (unless CONVERT_SCET is active)
    SCET=inputSCET[i]

    ; Extract partition (if used)
    IF SIZE(SCET,/TNAME) EQ "STRING" THEN BEGIN
       split = strsplit(scet, '/', COUNT=slashcount, /EXTRACT)
       IF slashcount GT 1 THEN BEGIN
         partition = split[0]
         scet      = split[1]
       ENDIF
    ENDIF
    ; Convert to Double
    SCET= double(scet)

    ; If CONVERT_SCET keyword is active, input variable scet is converted to double
    IF KEYWORD_SET(convert_scet) THEN $
     inputSCET[i]=string(scet, F='(F20.6)')

    ;;
    ;; Read the SPICE file (unless orbit array has already been provided)
    ;;
    IF SIZE(orbitarray,/N_DIMENSIONS) NE 2 THEN BEGIN

       ;;
       ;; Search the SPICE orbit file (either predicted or corrected)
       ;;
       IF KEYWORD_SET(ORVV) THEN filter = 'ORVV*.ORB' ELSE filter = 'ORVF*.ORB'
       pushd,SPICEpath
       SPICEfile=FILE_SEARCH(filter)
       popd
       IF SPICEfile[0] EQ '' THEN $
         message, "ERROR: SPICE orbit file not found in the given directory. Please check."

	   ;select latest file version
	   SPICEfile=SPICEfile[N_ELEMENTS(SPICEfile)-1]

       ;;
       ;; Read Spice file skipping first two lines
       ;;
       OPENR, unit, SPICEpath+SPICEfile, /GET_LUN
       readf,unit,dummy
       readf,unit,dummy

       WHILE ~ EOF(unit) DO BEGIN
         readf,unit,row
	     rowarr=[rowarr,double(strmid(row,0,5)),double(strmid(row,33,16))]
       ENDWHILE

       free_lun,unit

	   N_row=N_elements(rowarr)/2
	   orbitarray=reform(rowarr[1:*],2,N_row)

    ENDIF

    ;;
    ;; Check SCET time: Cruise, VOI or too big
    ;;
    IF SCET lt 35000000  THEN orbit_num[i] = 9999 ELSE $ ; For Cruise Phase orbit=9999 by convention
    IF SCET lt 35824050  THEN orbit_num[i] = 0000 ELSE $ ; For VOI and VOCP orbit=0000 by convention
    IF SCET gt orbitarray[1,(N_ELEMENTS(orbitarray)/2)-1] THEN BEGIN
      orbit_num[i] = -1
      print, "#### ERROR ####: SCET input time is too big, please check"
    ENDIF ELSE BEGIN

	    ;;
    	;; Search Orbit  (transforming the pericenter time in start of orbit (-18h from peri))
    	;;

    	ind = where((SCET + 18*3600.) gt orbitarray[1,*], found)
    	IF found LT 1 THEN $
    		message, "ERROR: Cannot find Orbit for SCET time:"+SCET

	    orbit_num[i] = floor(orbitarray[0,ind[N_ELEMENTS(ind)-1]])
	ENDELSE

endfor

; If CONVERT_SCET keyword is active, input variable scet is converted to double
IF KEYWORD_SET(convert_scet) THEN inputSCET=double(inputSCET)

return,orbit_num

END
