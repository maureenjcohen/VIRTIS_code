;+
; NAME:
;   V_GEO_CONTOUR
;
; PURPOSE:
;   Display a contour plot of a selected band with respect to one or two geometry bands
;
; INPUT:
;   none, procedure prompts for bands to display
;
; OPTIONAL KEYWORDS:
;   BAND       : matrix with Z values to plot
;   XAxis      : matrix with X coordinates
;   YAxis      : matrix with Y coordinates
;   RANGE      : range of Z values to be considered (image is scaled using this given range)
;   INVALID    : value to impose to pixels outside given range (if no invalid value is given, Min and Max Range are used)
;   iTOOL      : 1 (by default) to use iContour, or 0 to use classical Contour
;   VIEW_TITLE : set title of the contour plot window
;   zTITLE     : set title of the contour plot
;   xTitle     : set title of the Y Axis
;   yTitle     : set title of the Y Axis
;   COLOR_TABLE: index of color table to use (5: STD-GAMMA by default)
;   Colorbar_Title: title of color bar (e.g. "Radiance [W/m2/microns/sr]")
;   _EXTRA     : Extra keywords are passed to the CONTOUR or ICONTOUR procedure (e.g. FILL, etc)
;
; EXAMPLE:
;   v_geo_contour, BAND=band77, XAxis=local_time, YAXIS=latitude, RANGE=[0.01, 0.14], XTITLE="Local Time", iTOOL=0, INVALID=float('NaN')
;
; COMMENTS:
;   Local Time and Longitude are centered around zero if the XTITLE or YTITLE are specified. ([-12,12];[-180,180])
;
; PROCEDURE:
;   The routine uses the colorbar.pro routine from David Fanning (http://www.dfanning.com/programs/colorbar.pro)
;
; MODIFICATION HISTORY:
;   Written by Alejandro Cardesin, IASF-INAF, November 2007, alejandro.cardesin @ iasf-roma.inaf.it
;   Modified February 2008, A.Cardesin : Rewritten to be called also outside ENVI. Added keywords.
;   Modified April 2008, AC : X and Y axis are now optional
;   Modified July  2008, AC : Solved minor problems with titles
;-

pro v_geo_contour, event, $
                   BAND=Zin, XAxis=Xin, YAxis=Yin, RANGE=range, INVALID=invalid, VIEW_TITLE=View_Title, zTITLE=zTitle, xTitle=xTitle, yTitle=yTitle,$
                   COLOR_TABLE=color_table, Colorbar_Title=Colorbar_Title, iTOOL=iTool, _EXTRA=extraKeywords

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFINE VARIABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;RANGE= [0   ,1000] ; typical for coverage
;RANGE= [0.03,0.08] ; typical for band 1.27um (airglow)
;RANGE= [0.01,0.15] ; typical for band 1.27um (airglow)
;RANGE= [0.01,0.14] ; typical for band 1.74um
;RANGE= [1e4 ,3e6 ] ; typical for Rayleigh

;invalid  = float('NaN') ; Set this keyword to set to a certain value the pixels outside the given range so that they are not shown in the contour
;iTOOL = 0 ; 1 to use iContour (by default), 0 to use classical Contour

IF N_ELEMENTS(iTool  ) EQ 0 THEN iTool = 1 ; by default use iContour
IF N_ELEMENTS(Nlevels) EQ 0 THEN Nlevels = 128 ; by default

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load RGB TABLE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DEVICE, GET_DECOMPOSED=decomposed ; save original decomposed state
TVLCT, R1, G1, B1, /GET           ; save original color table
IF N_ELEMENTS(Color_Table) EQ 0 then Color_Table = 5 ; STD-Gamma by default
DEVICE, DECOMPOSED=0
LOADCT, Color_Table & TVLCT, R,G,B,/GET ; get RGB of STD-GAMMA palette
RGB_table=[[R],[G],[B]]
TVLCT, R1, G1, B1 ;restore original color table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SELECT BANDS (if called from ENVI)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IF N_ELEMENTS(Zin) EQ 0 THEN BEGIN

	; Let IDL know that I'm using ENVI functions (otherwise it doesn't compile)
	FORWARD_FUNCTION ENVI_GET_DATA

	;Run ENVI if it is not running yet
	help,name='envi_open_file',/procedures, output=help_envi_compiled
	IF N_ELEMENTS(help_envi_compiled) LE 1 THEN ENVI

	envi_select, dims=dimsZ, fid=fidZ, pos=posZ,/BAND_ONLY,TITLE="Select radiance band to plot" ;,/MASK,/ROI
	if (fidZ eq -1) then return

	envi_select, dims=dimsX, fid=fidX, pos=posX,/BAND_ONLY,TITLE="Select X axis (optional)";,/MASK,/ROI
	if (fidX eq -1) then x=0

	envi_select, dims=dimsY, fid=fidY, pos=posY,/BAND_ONLY,TITLE="Select Y axis (optional)";,/MASK,/ROI
	if (fidY eq -1) then y=0 ;return

	envi_file_query, fidZ, fname=fnameZ, bnames=zTitle, WL=wavelengthZ, data_type=data_type
	if (fidX ne -1) then $
	envi_file_query, fidX, fname=fnameX, bnames=xTitle
	if (fidY ne -1) then $
	envi_file_query, fidY, fname=fnameY, bnames=yTitle

	if n_elements(wavelengthZ) gt 1 then wavelengthZ = strtrim(wavelengthZ[posZ],2)
	zTitle = zTitle[posZ]
	if (fidX ne -1) then xTitle = xTitle[posX] else xTitle="samples"
	if (fidY ne -1) then yTitle = yTitle[posY] else yTitle="lines"

	z=float(envi_get_data(FID=fidZ, pos=posZ, dims=dimsZ))
	if fidX ne -1 then $
	x=float(envi_get_data(FID=fidX, pos=posX, dims=dimsX))
	if fidy ne -1 then $
	y=float(envi_get_data(FID=fidY, pos=posY, dims=dimsY))
ENDIF ELSE BEGIN
	Z = Zin
	IF N_ELEMENTS(Xin) GT 0 THEN X = Xin ELSE X = 0
	IF N_ELEMENTS(Yin) GT 0 THEN Y = Yin ELSE Y = 0
ENDELSE


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set default values to axis if not defined
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

IF N_ELEMENTS(X) EQ 1 THEN BEGIN
	X = (Z-Z) ; matrix of same dimensions of Z
	xsize = (size(reform(x),/dim))[0]
	for i=0,xsize-1 do X[i,*]=i
ENDIF

IF N_ELEMENTS(Y) EQ 1 THEN BEGIN
	Y = (Z-Z) ; matrix of same dimensions of Z
	ysize = (size(reform(y),/dim))[1]
	for i=0,ysize-1 do Y[*,i]=i
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set bad values to "Not a Number"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

xbad=where(x le -21450)
ybad=where(y le -21450)

if xbad[0] ne -1 then x[xbad] = float('NaN')
if ybad[0] ne -1 then y[ybad] = float('NaN')

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RESCALE LONGITUDES AND LOCAL TIME
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if N_elements(xTitle) EQ 0 then xTitle = ""
if N_elements(yTitle) EQ 0 then yTitle = ""

;if STRPOS(STRUPCASE(xTitle),"LONG" ) ne -1 then if max(x,/NaN) gt 180 then X = ((X + 180) mod 360) - 360 ;if max(x,min=min,/NaN) - min gt 350 then X[where(X gt 180)] = X[where(X gt 180)]-360
;if STRPOS(STRUPCASE(yTitle),"LONG" ) ne -1 then if max(y,/NaN) gt 180 then Y = ((Y + 180) mod 360) - 360 ;if max(y,min=min,/NaN) - min gt 350 then Y[where(Y gt 180)] = Y[where(Y gt 180)]-360
if STRPOS(STRUPCASE(xTitle),"LOCAL") ne -1 then if max(x,/NaN) gt  12 then X = ((X +  12) mod  24) -  24 ;if max(x,min=min,/NaN) - min gt 23  then X[where(X gt 12 )] = X[where(X gt 12 )]-24
if STRPOS(STRUPCASE(yTitle),"LOCAL") ne -1 then if max(y,/NaN) gt  12 then Y = ((Y +  12) mod  24) -  24 ;if max(y,min=min,/NaN) - min gt 23  then Y[where(Y gt 12 )] = Y[where(Y gt 12 )]-24

;Xin = ((Xin + Xoffset*Xfactor) mod xsize) - Xoffset*Xfactor ; Mod to put 180-360° to -180°-0° / 12-24h to -12-0h


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RANGE, scale image using given range
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
If N_ELEMENTS(Range) NE 0 THEN BEGIN
	if N_ELEMENTS(invalid) NE 0 then begin
		ind = where(z lt Range[0] OR z gt Range[1])
		if ind[0] ne -1 then z[ind] = invalid
	endif else $
	z = Range[1] < z > Range[0]
ENDIF ELSE Range = [min(z,/NaN, max=max),max]

Zscl = BYTSCL(z, MAX=Range[1], MIN=Range[0], /NAN)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display with iCONTOUR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IF KEYWORD_SET(iTOOL) THEN BEGIN
	icontour, z,x,y, /IRREGULAR,N_LEVELS=nlevels, RGB_TABLE=RGB_table, $
	                 TITLE=zTitle, VIEW_TITLE=View_Title, YTITLE=yTitle, XTITLE=xTitle, $
	                 /NO_SAVEPROMPT, _STRICT_EXTRA=extraKeywords

	; Display COLORBAR (see  http://www.ittvis.com/services/techtip.asp?ttid=3812 )
	void = itgetcurrent(TOOL=oTool)
	void = oTool->DoAction(oTool->FindIdentifiers('*INSERT/COLORBAR'))
	idColorbar = oTool->FindIdentifiers('*ANNOTATION LAYER/COLORBAR')
	void = oTool->DoSetProperty(idColorbar, 'AXIS_TITLE', Colorbar_Title)
	void = oTool->DoSetProperty(idColorbar, 'BORDER_ON', 1)
ENDIF $

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display with CONTOUR classic
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ELSE BEGIN

	window, /FREE
	LOADCT, Color_Table
	CONTOUR, z, x, y, /irregular ,$
	                 YTITLE=yTitle, XTITLE=xTitle, TITLE=zTitle,$
	                 NLEVELS=nlevels, C_COLORS=indgen(nlevels)*256./nlevels   ,$
	                 YSTYLE=0, XSTYLE=0                    ,$
	                 POSITION=[0.12, 0.12, 0.85, 0.92]     ,$
	                 BACKGROUND=255, COLOR=0, _STRICT_EXTRA=extraKeywords

	; Set Colorbar and title (uses colorbar routine from http://www.dfanning.com/programs/colorbar.pro)
	colorbar, COLOR=0, POSITION=[0.95, 0.05, 0.99, 0.95], /VERTICAL, $
	          RANGE=RANGE, FORMAT="(F12.2)"

ENDELSE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RESTORE DISPLAY STATUS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DEVICE, DECOMPOSED=decomposed ; restore original decomposed state
TVLCT, R1, G1, B1             ; restore original color table

END
