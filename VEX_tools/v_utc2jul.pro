FUNCTION v_utc2jul, utcTime

   ON_IOERROR, FORMAT_ERROR

   vect = strsplit(utcTime, /ext, '-T:Z') ; parse string
   outTime = fltarr(6)  ; set missing values to 0
   outTime(0) = vect

   Year  = outTime[0]
   Month = outTime[1]
   Day   = outTime[2]
   hh    = outTime[3]
   mm    = outTime[4]
   ss    = outTime[5]

   jul_date = JULDAY(Month,Day,Year,hh,mm,ss)

   return, jul_date

FORMAT_ERROR:

   print, "### FORMAT ERROR ###: cannot convert UTC time string: "+utcTime
   return, 0

END

;; OLD conversion method (less efficient and error prompt)
;   ;Remove final Z if any
;   IF STRPOS(utc_date, "Z") GT -1 THEN utc_date=strjoin(strsplit(utc_date, "Z",/EXTRACT))
;
;   Year  = long(STRMID(utc_date, 0 ,4))
;   Month = long(STRMID(utc_date, 5 ,2))
;   Day   = long(STRMID(utc_date, 8 ,2))
;   hh    = long(STRMID(utc_date, 11,2))
;   mm    = long(STRMID(utc_date, 14,2))
;   ss    = float(STRMID(utc_date, 17,10))

