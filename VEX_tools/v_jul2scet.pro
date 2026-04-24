
FUNCTION v_jul2scet, jul_date, corr_factor, VEX=vex, ROSETTA=rosetta, NO_WARNING=no_warning, PARTITION=partition, DOUBLE=double

 IF KEYWORD_SET(ROSETTA) THEN $
   jul_orig = JULDAY(1,1,2003,0,0,0.)  $ ;2003-01-01T0:0:0.0
 ELSE $
   jul_orig = JULDAY(3,1,2005,0,0,0.)  ;2005-03-01T0:0:0.0

 scet = double(jul_date - jul_orig) * 86400d ;24h x 60min x 60s

 ; You can also apply an optional correction factor (if you know it)
 IF N_ELEMENTS(corr_factor) EQ 1 THEN scet += corr_factor

 IF ~KEYWORD_SET(double) THEN BEGIN

 	; Convert fractional part to fractions of 2^-16 seconds
 	scet_int = string(floor(scet),F='(I011)')
 	scet_frac= string(floor((scet-floor(scet))*65536d),F='(I05)')
 	scet = scet_int+'.'+scet_frac

	IF N_ELEMENTS(partition) EQ 1 THEN scet = strtrim(partition,2)+'/'+scet

 ENDIF


 IF ~KEYWORD_SET(NO_WARNING) THEN print, "WARNING: SCET calculation is only approximate. Use SPICE for an accurate result."

 return, scet

END
