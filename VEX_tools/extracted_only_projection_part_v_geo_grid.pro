;
; This file contains only the code relevant to the map projection
; as extracted from the original routine v_geo_grid.pro
; 
; 06 August 2009: INAF-ESA Alejandro.Cardesin @ esa.int
;

; Z is always RADIANCE ----------------------------------------------------------
Zin = (Radiance[ValidGeometryIndex])[ValidDATAIndex]
;--------------------------------------------------------------------------------

; Y is always LATITUDE ----------------------------------------------------------
Yin = (Latitude[ValidGeometryIndex])[ValidDATAIndex]
;--------------------------------------------------------------------------------

; X can be LONGITUDE or LOCAL_TIME ----------------------------------------------
IF longkey THEN Xin = (Longitude[ValidGeometryIndex])[ValidDataIndex] $
ELSE           	Xin = (LocalTime[ValidGeometryIndex])[ValidDataIndex]
;--------------------------------------------------------------------------------

; RESCALE Local Time to range ([-12,12]) ----------------------------------------
IF ~longkey THEN Xin = ( (Xin+12) mod 24 ) - 12
;--------------------------------------------------------------------------------


; Define AXIS Parameters --------------------------------------------------------

; If no parameters were given, fix grid size : 512x512
IF (N_ELEMENTS(Xsize ) NE 0) + (N_ELEMENTS(Xdelta ) NE 0) + (N_ELEMENTS(Xrange ) NE 0) EQ 0 THEN Xsize  = 512.
IF (N_ELEMENTS(Ysize ) NE 0) + (N_ELEMENTS(Ydelta ) NE 0) + (N_ELEMENTS(Yrange ) NE 0) EQ 0 THEN Ysize  = 512.

; If only one parameter is given, fix another one
IF (N_ELEMENTS(Xsize ) NE 0) + (N_ELEMENTS(Xdelta ) NE 0) + (N_ELEMENTS(Xrange ) NE 0) EQ 1 THEN $
	IF N_ELEMENTS(Xrange) EQ 0 THEN Xrange = [min(Xin,/NAN),max(Xin,/NAN)] ELSE Xsize = 512. ;Xrange = [min(Xin,/NAN)-0.1*abs(min(Xin,/NAN)),max(Xin,/NAN)+0.1*abs(max(Xin,/NAN))] ELSE Xsize = 512.
IF (N_ELEMENTS(Ysize ) NE 0) + (N_ELEMENTS(Ydelta ) NE 0) + (N_ELEMENTS(Yrange ) NE 0) EQ 1 THEN $
	IF N_ELEMENTS(Yrange) EQ 0 THEN Yrange = [min(Yin,/NAN),max(Yin,/NAN)] ELSE Ysize = 512. ;Yrange = [min(Yin,/NAN)-0.1*abs(min(Yin,/NAN)),max(Yin,/NAN)+0.1*abs(max(Yin,/NAN))] ELSE Ysize = 512.

; Calculate the missing parameter
IF N_ELEMENTS(Xsize        ) EQ 0 THEN Xsize  = (Xrange[1]-XRange[0])/float(Xdelta)
IF N_ELEMENTS(Ysize        ) EQ 0 THEN Ysize  = (Yrange[1]-YRange[0])/float(Ydelta)
IF N_ELEMENTS(Xdelta       ) EQ 0 THEN Xdelta = (Xrange[1]-XRange[0])/float(Xsize )
IF N_ELEMENTS(Ydelta       ) EQ 0 THEN Ydelta = (Yrange[1]-YRange[0])/float(Ysize )
IF N_ELEMENTS(Xrange       ) EQ 0 THEN Xrange = min(Xin,/NAN)+[0, (Xsize-1)*float(Xdelta)]
IF N_ELEMENTS(Yrange       ) EQ 0 THEN Yrange = min(Yin,/NAN)+[0, (Ysize-1)*float(Ydelta)]

; Create AXIS
Xaxis = indgen(Xsize)*float(Xdelta)+Xrange[0]
Yaxis = indgen(Ysize)*float(Ydelta)+Yrange[0]


; SHIFT Xaxis (if the image is centered around noon or prime meridian)

Xshifted = ((Xin + Xrange[1]-Xrange[0]) mod (Xrange[1]-Xrange[0])) - ((Xrange[1]-Xrange[0])/2)

if (max(Xshifted)-min(Xshifted))*1.1 lt (max(Xin)-min(Xin)) then begin
	Xin = Xshifted
	shifted = 1         ; flag to remember that Xaxis was shifted
endif

;--------------------------------------------------------------------------------

;starttime = systime(/seconds) ; debugging


; Prepare for the GRIDDING ------------------------------------------------------

; AVERAGE pixels with same coordinates
; (basically aggregates pixels within EPSILON/5 distance, to make process faster)
grid_input, Xin, Yin, Zin, Xsorted, Ysorted, Zsorted, EPSILON=0.2*min([Xdelta, Ydelta]), DUPLICATES="AVG"


; TRIANGULATE averaged pixels and obtain image boundaries
triangulate, Xsorted, Ysorted, triangles, boundaries ;, FVALUE=Zsorted,SPHERE=sphere,/DEGREES

;--------------------------------------------------------------------------------


;===================================================================================
;=============== Perform GRIDDING using GRIDDATA OR TRIGRID   ======================
;===================================================================================

IF keyword_Set(trigrid_function) THEN BEGIN

; TRIGRID is more efficient and accurate although it has some problems in the boundaries
; ###TO BE CORRECTED### There is a problem with images centered in the poles.

	Zsorted[boundaries]=-1e7 ; remove boundaries to avoid problems of triangulation in the borders
	grid = TRIGRID(Xsorted, Ysorted, Zsorted, triangles, $
	               [Xdelta, Ydelta], [Xrange[0],Yrange[0], Xrange[1],Yrange[1]],$
	               NX=xSize, NY=ySize, MISSING=float('NaN'),MIN_VALUE=-1e6) ;, SPHERE=sphere, /DEGREES)

ENDIF ELSE BEGIN

; GRIDDATA is quite complex but it is working fine now. Ellipse and other options might be changed to obtain better results.
; There is a small problem when using high resolution grids, as the grid might have empty points whithin the image.
; For the moment we use low resolution grids so it's OK, but this should be solved in the future (hopefully using Trigrid)

	ellipse = 1.*[Xdelta,Ydelta] ; define distance to search values for each pixel of the grid
	grid = griddata(Xsorted, Ysorted, Zsorted,$
	                /INVERSE_DISTANCE, SEARCH_ELLIPSE=ellipse,$
	                START=[Xrange[0],Yrange[0]], DELTA=[Xdelta,Ydelta], DIMENSION=[xSize,ySize],$
	                MISSING=float('NaN'), TRIANGLES=triangles, MAX_PER_SECTOR=1)

ENDELSE

;print, "Grid completed in "+strtrim(systime(/seconds)-starttime, 2)+" seconds"



; MEDIAN FILTER also to final grid obtained -------------------------------------
If keyword_set(median_filter) then	grid = median(grid, 3)
;--------------------------------------------------------------------------------


; RECOVER XAXIS if it was shifted before ----------------------------------------
if keyword_set(shifted)       then  grid = shift(grid, Xsize/2)
;--------------------------------------------------------------------------------
