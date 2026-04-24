FUNCTION v_scet2jul, input_SCET, VEX=vex, ROSETTA=rosetta, NO_WARNING=no_warning

 scet = input_SCET ;do not modify original variable

 ; Extract partition (if used)
 IF SIZE(SCET,/TNAME) EQ "STRING" THEN BEGIN
       split = strsplit(scet, '/', COUNT=slashcount, /EXTRACT)
       IF slashcount GT 1 THEN BEGIN
         partition = split[0]
         scet      = split[1]
       ENDIF
 ENDIF

 ; Separate Integer and Fractional part
 split = strsplit(scet, '.', COUNT=dotcount, /EXTRACT)
 IF dotcount EQ 2 THEN scet_frac= split[1] ELSE $
 IF dotcount EQ 1 THEN scet_frac= 0        ELSE message, "ERROR converting SCET, more than one dot found in the scet string."
 scet_int = split[0]

 ; Convert to double (fractional part is in fractions of 2^-16 of seconds)
 SCET= double(scet_int)+double(scet_frac)/65536d

 IF KEYWORD_SET(ROSETTA) THEN $
   jul_start = JULDAY(1,1,2003,0,0,0.)  $ ;2003-01-01T0:0:0.0
 ELSE $
   jul_start = JULDAY(3,1,2005,0,0,0.)    ;2005-03-01T0:0:0.0

 jul_scet = jul_start + (double(scet)/86400d) ; 86400 = 24h x 60min x 60s

 IF ~KEYWORD_SET(NO_WARNING) THEN print, "WARNING: SCET convertion is only approximate. Use SPICE for an accurate result."

 return, jul_scet

END
