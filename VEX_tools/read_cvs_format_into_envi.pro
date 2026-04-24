pro read_cvs_format_into_ENVI

n=[0,5,6,7,8,9,10,11,12,13,14,15,16,17,24,25,28,29,30,31,32,34,35,37,38,39,40,41,42,50,51,52,53,54,55,56,57,58,59, $
	60,61,62,63,64,65,66,67,68,69,70,71,72,73,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,104,105,106,107, $
	109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136, $
	137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,154,155,156,157,158,159,160]

;toplot_idx=78

N_column=162
i=0L
row=strarr(1)

filename=dialog_pickfile(TITLE="Select input trend file")

index=strarr(N_column,FILE_LINES(filename))

progressbar = Obj_New('progressbar', Color='red', Text='Loading... 0'+' %'$
      ,/NOCANCEL,/FAST_LOOP,/start,title='Load CSV format file ',xsize=300,ysize=20)

    OPENR, unit, filename, /GET_LUN
    readf,unit,row
dim=fstat(unit)
WHILE (((j = STRPOS(row, '"'))) NE -1) DO STRPUT, row, ' ', j
prima=STRSPLIT(row,';',/EXTRACT, /PRESERVE_NULL)
prima=strtrim(prima,2)
WHILE ~ EOF(unit) DO BEGIN
	progressbar -> Update, fix(i*100.*600./dim.size), Text='Loading... ' + StrTrim(fix(i*100.*600./dim.size),2)+' %'
;    print,i
    readf,unit,row
WHILE (((j = STRPOS(row, '"'))) NE -1) DO STRPUT, row, ' ', j
	index[*,i]=STRSPLIT(row,';',/EXTRACT, /PRESERVE_NULL);,/REGEX);, /PRESERVE_NULL)
    i=i+1
ENDWHILE
index=strtrim(index,2)
	N_row=i-1
	index=reform(index[*,0:N_row-1],N_column,N_row)
    free_lun,unit

progressbar -> Destroy

;param='SPECT TEMP'
;toplot_idx=(where(prima eq param))

;------------------------------------------------
;toplot_idx=toplot_idx[0]
;y=float(reform(index[toplot_idx,*]))
;idx=reform(where(y ne 0))
;iplot,index[0,idx],y[idx],ystyle=1,ytitle=prima[toplot_idx],xtitle=prima[0],/scatter
;------------------------------------------------

;------------------------------------------------
y=float(index[n,*])
y=reform(transpose(y,[1,0]),(size(y))[2],1,125)
y(where(y eq 0))='NaN'
envi_enter_data,y,bnames=prima[n];,wl=y[0,*]
;------------------------------------------------

;----------------------------

; (000)	SCET TIME
; (001)	Default
; (002)	ME Mode
; (003)	M Mode
; (004)	H Mode
; (005)	M Power Converter
; (006)	H Power Converter
; (007)	M IFE +5V power
; (008)	H IFE +5V power
; (009)	ADC power
; (010)	EEPROM +5V
; (011)	POWER LINE
; (012)	DHSU +5V Volt
; (013)	DHSU +5V Ampere
; (014)	Power Supply Temperute
; (015)	DPU Temperute
; (016)	IFEVoltage
; (017)	EEPROMVoltage
; (018)	Thermistors
; (019)	Thermistors1
; (020)	Thermistors2
; (021)	Thermistors3
; (022)	Thermistors4
; (023)	General H			-------------------------------------- H ------------------------------
; (024)	ECA Status
; (025)	ECA Power Status
; (026)	Cooler Mode
; (027)	Cooler Motor Driver
; (028)	CCE +28V
; (029)	Cooler Cold Temp
; (030)	Cooler Motor Voltage
; (031)	CCE Second. Voltage
; (032)	CCE Motor Current
; (033)	General M			-------------------------------------- M ------------------------------
; (034)	ECA Status
; (035)	ECA Power Status
; (036)	Cooler Mode
; (037)	Cooler Motor Driver
; (038)	CCE +28V
; (039)	Cooler Cold Temp
; (040)	Cooler Motor Voltage
; (041)	CCE Second. Voltage
; (042)	Cooler Motor Current
; (043)	M VIS				-------------------------------------- M ------------------------------
; (044)	CCD Scan
; (045)	ADC latch-up
; (046)	Word Error
; (047)	Time Error
; (048)	H/K Acquisition
; (049)	Last cmd CCD
; (050)	CCD VDR
; (051)	CCD VDD
; (052)	+5 V
; (053)	+12 V
; (054)	-12 V
; (055)	+20 V
; (056)	+21 V
; (057)	CCD Lamp Volt
; (058)	CCD Temp
; (059)	CCD Temp Res Volt
; (060)	CCD Temp Offest
; (061)	Radiator Temp
; (062)	Ledge Temp
; (063)	OM Base Temp
; (064)	M Cooler Temp
; (065)	H Cooler Temp
; (066)	CCD Win X1
; (067)	CCD Win Y1
; (068)	CCD Win X2
; (069)	CCD Win Y2
; (070)	CCD Delay
; (071)	CCD Expo
; (072)	VIS Mirror Sin
; (073)	VIS Mirror Cos
; (074)	M IR			-------------------------------------- M ------------------------------
; (075)	IR WIN Y1
; (076)	IR WIN Y2
; (077)	IR DELAY
; (078)	IR EXPO
; (079)	IR VDETCO
; (080)	IR VDETADJ
; (081)	IR FPA TEMP
; (082)	IR TEMP RES
; (083)	IR TEMP OFFSET
; (084)	SHUTTER TEMP
; (085)	GRATING TEMP
; (086)	SPECT TEMP
; (087)	TELE TEMP
; (088)	SU MOTOR TEMP
; (089)	SU MOTOR CURR
; (090)	IR LAMP VOLT
; (091)	IR VPOS
; (092)	IR VDP
; (093)	IRFPA SCAN
; (094)	HK FLAG
; (095)	CMD TIME ERR
; (096)	CMD WORD ERR
; (097)	SCAN CMD ERR
; (098)	DETECT ST
; (099)	ADC LTC
; (100)	ANN ST
; (101)	COVER DIRECT
; (102)	CLOSE POS
; (103)	OPEN POS
; (104)	LAMP CURR
; (105)	LAMP CMD
; (106)	SHUTT CURR
; (107)	SHUTT CMD
; (108)	M H				-------------------------------------- H ------------------------------
; (109)	INTEGRATION TIME
; (110)	BIAS
; (111)	I_LAMP
; (112)	I SHUTTER
; (113)	I PEM MODE
; (114)	TEST INIT
; (115)	V LINE REF
; (116)	V DET DIG
; (117)	V DET ANA
; (118)	V DETCOM
; (119)	V DETADJ
; (120)	V +5
; (121)	V +12
; (122)	V -12
; (123)	V +21
; (124)	TEMP VREF
; (125)	DET TEMP
; (126)	GROUND
; (127)	I VDET ANA
; (128)	I VDET DIG
; (129)	I +5
; (130)	I +12
; (131)	I LAMP
; (132)	I SHUTTER HEATER
; (133)	TEMP PRISM
; (134)	TEMP CAL S
; (135)	TEMP CAL T
; (136)	TEMP SHUT
; (137)	TEMP GRATING
; (138)	TEMP OBJ
; (139)	TEMP FPA
; (140)	TEMP PEM
; (141)	LAST SENT REQ
; (142)	STOP READOUT
; (143)	DET
; (144)	SHUTTER
; (145)	FPA HEATER
; (146)	LAMP SPEC T
; (147)	LAMP_SPECT S
; (148)	LAMP_RADIO
; (149)	TEMP_DET
; (150)	STATUS_SHUTTER
; (151)	MS REQ ACQ
; (152)	COVER DIR
; (153)	COVER WAVE
; (154)	COVER STEP
; (155)	ADC LATCHUP
; (156)	SHUTTER CLOSED
; (157)	SHUTTER OPEN
; (158)	FPGA HES 1
; (159)	FPGA HES 2
; (160)	ANNEAL LIMIT
; (161)

end