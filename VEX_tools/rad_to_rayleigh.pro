;+
; NAME:
;     rad_to_rayleigh
;
; PURPOSE:
;
;     Conversion from radiance (in W/m2/sr/um) to MegaRayleigh
;     (MR, one megaRayleigh corresponds to the
;     brightness of an extended source emitting 1012 photons cm-2s-1 in 4p steradiants).
;     This unity is widely used to compare data taken with different instruments (from space and ground)
;
; CALLING SEQUENCE:
;     Rad_to_Rayleigh, QUBE=input_cube, WL=wl, RAYLEIGH=ouput_cube, /NO_POPUPS
;
; INPUTS:
;      If no inputs are given, the routine prompts for input bands with ENVI dialogs
;
; OUTPUTS:
;     Input calibrated cube converted to MR.
;     Result is shown in ENVI (if called from there) or given as an output variable).
;
; OPTIONAL KEYWORDS:
;     QUBE : input calibrated cube or band in Radiance
;     WL   : array with wavelengths for each spectel (in microns)
;     RAYLEIGH: output variable containing converted cube or band in Rayleigh units
;     NO_POPUPS: do not show any dialog or progress bars
;
; EXAMPLE:
;     Simple call to the routine prompts for inputs using ENVI
;         > Rad_to_Rayleigh
;
;     Input variables can be passed directly through IDL command line:
;         > cal  = virtispds()
;         > wl   = (cal.table)[*,0,0]
;         > Rad_to_Rayleigh, QUBE=cal.qube, WL=wl, RAYLEIGH=converted_cube
;
; PROCEDURE:
;     Uses the routine "select_cube_from_envi.pro" for ENVI integration
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;
; MODIFICATION HISTORY:
;     Written by A.Migliorini, IASF-INAF, June 2008, Alessandra.Migliorini @ iasf-roma.inaf.it
;     Modified June 2008 by A.Cardesin: Added select_cube_from_ENVI
;     Modified Dec  2008 by A.Cardesin: Added keyword NO_POPUPS
;-


PRO Rad_to_Rayleigh, event, QUBE=input_cube, WL=wl, RAYLEIGH=cube, NO_POPUPS=no_popups

; dlambda_vis = 1.89124 * 1.E-3
dlambda_ir = 9.46673 * 1.E-3

;SELECT QUBE -------------------------------------------------------
IF N_ELEMENTS(input_cube) EQ 0 THEN BEGIN
    ; Read with ENVI if no variables are passed
	cube = select_cube_from_envi(TITLE="Select a VIRTIS cube", BSL=0, CANCEL=cancel, fname=fname, bnames=bnames, WL=wl, data_type=data_type, nb=nb, ns=ns, nl=nl, interleave=interleave)
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

IF ~KEYWORD_SET(NO_POPUPS) THEN $
	progressbar = Obj_New('progressbar', Color='red', Text='Processing cube... 0'+' %'$
      			,/NOCANCEL,/FAST_LOOP,/start,title='Radiance to Rayleigh ',xsize=300,ysize=20)

for b=0,nb-1 do begin
	IF ~KEYWORD_SET(NO_POPUPS) THEN $
	progressbar -> Update, fix(b*100./nb), Text='Processing cube... ' + StrTrim(fix(b*100./nb),2)+' %'

        ; RAYLEIGH CONVERSION
	cube[*,*,b] = 1.9864867 * !pi * wl[b] * cube[*,*,b] * 1.E9 * dlambda_ir * 1e-6 ; in Mega Rayleigh

endfor

IF ~KEYWORD_SET(NO_POPUPS) THEN progressbar -> Destroy

; Put result back into ENVI (if called from there)
IF N_ELEMENTS(input_cube) eq 0 THEN $

	envi_enter_data, cube, bnames="Rayleigh("+bnames+")", descrip='VIRTIS cube in Rayleigh', wl=wl, zplot_titles=['Wavelength [micron]', '[MR]'] $

ELSE BEGIN
; Otherwise put back cube in correct format and return
	cube = reform(cube, ns, nl, nb)
	cube = transpose(cube,[2,0,1])
ENDELSE

END