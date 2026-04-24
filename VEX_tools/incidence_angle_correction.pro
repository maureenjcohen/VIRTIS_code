;+
; NAME:
;     Incidence_Angle_Correction
;
; PURPOSE:
;     Subtract the solar radiation reflected by the cloud top for VIRTIS calibrated
;     data (either a single band or a full cube)
;
;     The correction implemented here is performed using the reflection profile extracted from
;     the average of the first 22 lines of the cube (from 8 to 30)
;
;     Note: The method is not usable when the vortex is in the first 22 lines
;
; CALLING SEQUENCE:
;     incidence_angle_correction, QUBE=input_cube, EMband=input_EMband, CORRECTED_QUBE=cube, /NO_POPUPS
;
; INPUTS:
;      No inputs are needed, the routine prompts for input bands with ENVI dialogs
;
; OUTPUTS:
;     Input calibrated cube or band corrected for sun radiation scattere by the clouds top.
;     Result is shown in ENVI (if called from there) or given as an output variable).
;
; OPTIONAL KEYWORDS:
;     QUBE : input calibrated cube or band
;     EMBAND : 2-D array with the Emission Angle values for each pixel (from the GEO cube)
;     CORRECTED_QUBE: output variable containing corrected cube or band
;     NO_POPUPS: do not show any dialog or progress bars
;
; EXAMPLE:
;     Simple call to the routine prompts for inputs using ENVI
;         > incidence_angle_correction
;
;     Input variables can be passed directly through IDL command line:
;         > cal  = virtispds()
;         > geo  = virtispds()
;         > band = (cal.qube)[291,*,*]
;         > INC   = (geo.qube)[26,*,*]*(geo.qube_coeff)[26]
;         > incidence_angle_correction, QUBE=band, EMband=INC, CORRECTED_QUBE=corrected_cube
;
; REQUIRED FILES:
;     uses routine "select_envi_file.pro" for ENVI integration
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.4.1 for Linux [Ubuntu 8.10].
;
; MODIFICATION HISTORY:
;     Written by R. Politi, IASF-INAF, December 2008, romolo.politi @ iasf-roma.inaf.it
;
;-

PRO incidence_angle_correction, event, QUBE=input_cube, Iband=input_Iband, CORRECTED_QUBE=cube, NO_POPUPS=no_popups

;SELECT QUBE -------------------------------------------------------
IF N_ELEMENTS(input_cube) EQ 0 THEN BEGIN

    ; Read with ENVI if no variables are passed
	cube = select_cube_from_envi(TITLE="Select a VIRTIS cube", BSL=0, CANCEL=cancel, fname=fnameRAD, bnames=bnameRAD, WL=wavelengthRAD, data_type=data_type, nb=nb, ns=ns, nl=nl, interleave=interleave)
	if cancel then return

ENDIF ELSE BEGIN
    ;If variables are passed, check dimensions and reform data for processing

	ndims= size(input_cube, /N_DIM)
	if ndims eq 3 then begin
		dims  = size(input_cube, /DIM)
		nb = dims[0] ; number of bands
		ns = dims[1] ; number of samples
		nl = dims[2] ; number of lines
	endif else begin
		dims  = size(input_cube, /DIM)
		nb = 1       ; number of bands
		ns = dims[0] ; number of samples
		nl = dims[1] ; number of lines
	endelse

	; Convert data from [B,S,L] to envi format [S,L,B]
	cube = reform(input_cube, nb, ns, nl) ; build 3-D cube in case a single band was passed
	cube = transpose(cube,[1,2,0])  ;ENVI format requires [s,l,b] while the calibration routine gives [b,s,l]
	cube = reform(      cube, ns, nl, nb) ; build 3-D cube in case a single band was passed

ENDELSE
;---------------------------------------------------

;SELECT INCIDENCE ANGLE BAND (convert to radians)-----------------------
IF N_ELEMENTS(input_Iband) EQ 0 THEN BEGIN

	Iband = select_cube_from_envi(/BAND, TITLE="Select band containing incidence angle values", CANCEL=cancel)
	if cancel then return

ENDIF ELSE IBand= input_IBand

Iband = !pi/180.*float(Iband) ;in RADIANS
;---------------------------------------------------

IF ~KEYWORD_SET(NO_POPUPS) THEN $
 progressbar = Obj_New('progressbar', Color='red', Text='Processing band... 0'+' %'$
      ,/NOCANCEL,/FAST_LOOP,/start,title='Incidence angle correction',xsize=300,ysize=20)


; PERFORM OPERATION FOR EACH BAND OF THE CUBE ------
for b=0,nb-1 do begin
	IF ~KEYWORD_SET(NO_POPUPS) THEN $
		progressbar -> Update, fix(b*100./nb), Text='Processing band... ' + StrTrim(fix(b*100./nb),2)+' %'
	;################################################
	;# Definition of the correction line            #
	;################################################
	mean_v=FltArr(nl)
	pippo=Reform(cube[*,*,b])
	negative=Where(pippo LT 0)
	if negative[0] ne -1 then pippo[negative]=!Values.F_NaN
	For i=0,nl-1 Do Begin
	  mean_v[i]=Min(cube[*,i,b],/NaN)
	EndFor

	;################################################
	;# Perform the incidence angle correction       #
	;################################################

	For i=0,nl-1 Do begin
;	  cube[*,i,b]=cube[*,i,b]-mean_v[i]+Min(mean_v,/NaN);.01
	  cube[*,i,b]=cube[*,i,b]-(Min(cube[8:30,i,b],/NaN))
	EndFor
endfor
;---------------------------------------------------

IF ~KEYWORD_SET(NO_POPUPS) THEN progressbar -> Destroy

; Put result back into ENVI (if called from there)
IF N_ELEMENTS(input_cube) eq 0 THEN $

	envi_enter_data, cube, bnames="IACorrected("+bnameRAD+")", descrip='VIRTIS cube corrected', wl=wavelengthRAD, zplot_titles=['Wavelength [micron]', 'Radiance  [W/m2 micron sr]'] $

ELSE BEGIN

	; Otherwise put back cube in correct format [B,S,L] and return
	cube = reform(cube, ns, nl, nb)
	cube = transpose(cube,[2,0,1])

ENDELSE

END
