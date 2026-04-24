
function to_word,arr

if size(arr,/N_dimensions) gt 1 then return,arr[0,*]*256L+arr[1,*] else return,arr[0]*256L+arr[1]

end


pro temp_DDS_extract, filename

; APID = 20
; type =3 subtype = 25 sid = 3 (P1VAL) is temperature read by SPC

   ; filename = "C:\VVX Data Archive\DDS Files\2007-05-01\002_TLM_20_2007-05-01T00-00-00Z_2007-06-01T00-00-00Z.dat"

    IF N_ELEMENTS(filename) EQ 0 THEN $
     filename=dialog_pickfile(TITLE="Select input telemetry file", FILTER="*.dat")
    IF filename EQ "" then return ELSE print, filename


    OPENR, unit, filename, /GET_LUN
	info=fstat(unit)
    size=info.size
	bin=bytarr(size)
    readu,unit,bin
    close, unit
    free_lun, unit

    IF 2*(SIZE/2) NE SIZE THEN bin=[0B,bin] ; correct if size is an odd number

	limit=0L
	i=size-2
	while limit eq 0 do begin
	word=bin[i]*256L+bin[i+1]
    	if (word eq '0814'X) then limit=i
	i=i-1
    endwhile
limit=limit/2-9
	i=9L
	word='0000'X
	length='0000'X
	type='0000'X
	subtype='0000'X
	sid='0000'X
	HK='0000'X
	scan_hk=0.
	idx_hk=0
	wrd=reform(bin,2,ceil(N_elements(bin)/2.))
	while i lt limit do begin
	word=wrd[*,i]
	word=to_word(word)
    	if (word eq '0814'X) then begin

			idx=3 & length=to_word(wrd[*,i+(idx-1)])
			idx=7 & type=wrd[1,i+(idx-1)];*256L+bin[i+2*(idx-1)+1]
			idx=8 & subtype=wrd[0,i+(idx-1)];*256L+bin[i+2*(idx-1)+1]
			idx=9 & sid=wrd[1,i+(idx-1)];*256L+bin[i+2*(idx-1)+1]
		j=i
    	i=i+18+length+(4*2)-1
		endif
    	if (word eq '0814'X) and (type eq 3) and (subtype eq 25) and (sid eq 3) then begin
			idx_hk=[idx_hk,j]
    	endif
	i=i+1
    endwhile

    If N_ELEMENTS(idx_hk) EQ 1 THEN message, "Error: no packets found with APID=20, type=3, subtype=25, sid=3 (P1VAL)"

			idx_hk=idx_hk[1:*]
			idx=33+1 & HK_NVRAT102=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			idx=34+1 & HK_NVRAT101=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			idx=35+1 & HK_NVRAT202=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			idx=36+1 & HK_NVRAT201=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			idx=4 & scet1=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			idx=5 & scet2=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			idx=6 & scet_frac=reform(to_word(wrd[*,idx_hk+(idx-1)]))
			scet=double(scet1)*65536.+double(scet2)+double(scet_frac)/65536.
			scan_hk=[transpose(scet),transpose(HK_NVRAT102),transpose(HK_NVRAT101),transpose(HK_NVRAT202),transpose(HK_NVRAT201)]
			scan_hk=reform(scan_hk,5,N_ELEMENTS(scan_hk)/5)

x=double(scan_hk[1:4,*])
y = 2.46028E-11*x^6. - 1.42656E-08*x^5. + 3.11085E-06*x^4. - 3.00119E-04*x^3. + 1.61619E-02*x^2. + 9.99444E-01*x - 2.40355E+02
scan_hk[1:4,*]=float(y)+273.23
;window,1
;plot,scan_hk[0,*],scan_hk[1,*],ystyle=1,ytitle='VIR M TEMP N (CCD)'
;window,2
;plot,scan_hk[0,*],scan_hk[2,*],ystyle=1,ytitle='VIR H TEMP N'
;window,3
;plot,scan_hk[0,*],scan_hk[3,*],ystyle=1,ytitle='VIR M TEMP R (IR)'
;window,4
;plot,scan_hk[0,*],scan_hk[4,*],ystyle=1,ytitle='VIR H TEMP R'

iplot,scan_hk[0,*],scan_hk[1,*],ystyle=1,NAME='VIR M TEMP N (CCD)'            ,COLOR=[0,0,200]
iplot,scan_hk[0,*],scan_hk[3,*],ystyle=1,NAME='VIR M TEMP R (IR)'   ,/OVERPLOT,COLOR=[200,0,0]
iplot,scan_hk[0,*],scan_hk[2,*],ystyle=1,NAME='VIR H TEMP N ColdBox',/OVERPLOT,COLOR=[0,200,0]
iplot,scan_hk[0,*],scan_hk[4,*],ystyle=1,NAME='VIR H TEMP R ColdBox',/OVERPLOT,COLOR=[0,0,0  ]

text_filename = dialog_pickfile(TITLE="Select directory for output text file",/DIR)
if text_filename EQ "" then return else text_filename=text_filename+file_basename(filename)+'.txt'

utctime = make_array(N_ELEMENTS(idx_hk),/STRING)
for i=0L,N_ELEMENTS(scan_hk)/5 -1 do utctime[i]=v_time('2005-03-01T00:00:00', reform(scan_hk[0,i]))

scan_hk = string(scan_hk, format='("	",F15.3,"	",F10.3,"	",F10.3,"	",F10.3,"	",F10.3)')

openw,wunit,text_filename,/get_lun
printf, wunit,'UTC_TIME	SCET	HK_NVRAT102	HK_NVRAT101	HK_NVRAT202	HK_NVRAT201'
printf, wunit,[transpose(utctime)+transpose(scan_hk)]
close, wunit
free_lun,wunit

xdisplayfile, text_filename

end
