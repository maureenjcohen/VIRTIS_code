
FUNCTION v_jul2utc, jul_date

; INPUT: julian date (number)
; OUTPUT: UTC date (string YYYY-MM-DDThh:mm:ss.sss)

   IF N_ELEMENTS(jul_date) EQ 0 THEN jul_date = systime(/jul, /utc) ;current time by default

   UTC_date=string(FORMAT='(C(CYI,"-",CMOI2.2,"-",CDI2.2,"T",CHI2.2,":",CMI2.2,":",CSF05.2))',double(JUL_date))


   return, UTC_date

END
