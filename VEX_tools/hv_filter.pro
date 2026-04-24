;+
; NAME:
;     HV_filter
;
; PURPOSE:
;     Double directional filtering: Horizontal + Vertical to increase detail of an image or qube
;
; CALLING SEQUENCE:
;     HV_filter, QUBE=input_qube, FILTERED_QUBE=FILTERED_qube
;
; INPUTS:
;      No inputs are needed, the routine prompts for input qubes with ENVI dialogs
;
; OUTPUTS:
;     Input qube filtered
;     Result is shown in ENVI (if called from there) or given as an output variable).
;
; OPTIONAL KEYWORDS:
;     QUBE : input qube
;     FILTERED_QUBE: output variable containing FILTERED cube or band
;
; EXAMPLE:
;     Simple call to the routine prompts for inputs using ENVI
;         > HV_filter
;
;     Input variables can be passed directly through IDL command line:
;         > cal  = virtispds()
;         > geo  = virtispds()
;         > qube = (cal.qube)[27,*,*]
;         > HV_filter, QUBE=qube, FILTERED_QUBE=filtered_qube
;
; REQUIRED FILES:
;     none (ENVI integration is recommended)
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;
; MODIFICATION HISTORY:
;     Written by A.Cardesin, IASF-INAF, April 2008, Alejandro.Cardesin @ iasf-roma.inaf.it
;     Modified June 2008 by A.Cardesin: Corrected bug doing reform/transpose/reform
;
;-

PRO HV_filter, event, QUBE=input_cube, FILTERED_QUBE=cube

;SELECT QUBE -------------------------------------------------------
IF N_ELEMENTS(input_cube) EQ 0 THEN BEGIN
    ; Read with ENVI if no variables are passed

	; Let IDL know that I'm using ENVI functions (otherwise it doesn't compile)
	FORWARD_FUNCTION ENVI_init_tile, ENVI_get_tile

	;Run ENVI if it is not running yet
	help,name='envi_open_file',/procedures, output=help_envi_compiled
	IF N_ELEMENTS(help_envi_compiled) LE 1 THEN ENVI

	envi_select, dims=dimsRAD, fid=fidRAD, pos=posRAD,TITLE='Choose a VIRTIS cube or a single band' ;,/MASK,/ROI
	if (fidRAD eq -1) then return
	envi_file_query, fidRAD, fname=fnameRAD, bnames=bnameRAD, WL=wavelengthRAD, data_type=data_type,ns=ns, nl=nl, interleave = interleave
	nb=N_ELEMENTS(posRAD)
	bnameRAD = bnameRAD[posRAD]
	cube=fltarr(ns,nl,nb)
	tile_id = envi_init_tile(fidRAD, posRAD, num_tiles=num_tiles, interleave=(interleave > 1), $
	                         xs=dimsRAD[1], xe=dimsRAD[2], ys=dimsRAD[3], ye=dimsRAD[4])
	for i=0L, num_tiles-1 do begin
		data = envi_get_tile(tile_id, i)
		cube(*,i,*)=data(*,*)
	endfor
	envi_tile_done, tile_id

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

	cube = reform(input_cube, nb, ns, nl) ; build 3-D cube in case a single band was passed
	cube = transpose(cube,[1,2,0])  ;ENVI format requires [s,l,b] while the calibration routine gives [b,s,l]
	cube = reform(      cube, ns, nl, nb) ; build 3-D cube in case a single band was passed

ENDELSE
;---------------------------------------------------

; SELECT A SINGLE BAND (this is no longer used) ----
;envi_select, dims=dimsRAD, fid=fidRAD, /BAND_ONLY, pos=posRAD,TITLE="Select band containing Radiance" ;,/MASK,/ROI
;if (fidRAD eq -1) then return
;envi_file_query, fidRAD, fname=fnameRAD, bnames=bnameRAD, WL=wavelengthRAD, data_type=data_type,ns=ns, nl=nl, nb=nb
;bnameRAD = bnameRAD[posRAD]
;RAD     =float(envi_get_data(FID=fidRAD, pos=posRAD, dims=dimsRAD))
;---------------------------------------------------

progressbar = Obj_New('progressbar', Color='red', Text='Processing band... 0'+' %'$
      ,/NOCANCEL,/FAST_LOOP,/start,title='HV Double directional filtering',xsize=300,ysize=20)


KERNEL_H = [[-1,-1,-1],$ ; Kernel for
            [ 0, 0, 0],$ ; directional  (horizontal)
            [ 1, 1, 1]]  ; convolution

KERNEL_V = [[-1, 0, 1],$ ; Kernel for
            [-1, 0, 1],$ ; directional  (vertical)
            [-1, 0, 1]]  ; convolution


; PERFORM OPERATION FOR EACH BAND OF THE CUBE ------
for b=0,nb-1 do begin
	progressbar -> Update, fix(b*100./nb), Text='Processing band... ' + StrTrim(fix(b*100./nb),2)+' %'
	raw = cube[*,*,b] * 100000. ; multiplied by a factor, filters don't work well with low values
    grad_H  = CONVOL(raw    , kernel_H,/CENTER,/EDGE_TRUNCATE) ; horizontal filter
    grad_HV = CONVOL(grad_H , kernel_V,/CENTER,/EDGE_TRUNCATE) ; vertical filter
	cube[*,*,b] = grad_HV
endfor
;---------------------------------------------------

progressbar -> Destroy

; Put result back into ENVI (if called from there)
IF N_ELEMENTS(input_cube) eq 0 THEN $

	envi_enter_data, cube, bnames="HVFiltered("+bnameRAD+")", descrip='VIRTIS cube filtered', wl=wavelengthRAD, zplot_titles=['Wavelength [micron]', 'Radiance  [W/m2 micron sr]'] $

ELSE BEGIN

; Otherwise put back cube in correct format and return
	cube = reform(cube, ns, nl, nb)
	cube = transpose(cube,[2,0,1])

ENDELSE

END