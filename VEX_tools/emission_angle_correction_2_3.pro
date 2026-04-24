;+
; NAME:
;     Emission_Angle_Correction_2_3
;
; PURPOSE:
;     Correction of Emission Angle for VIRTIS calibrated data at 2.3 microns
;
;     The correction implemented here comes from a scientific publication :
;        "Variations in Venus cloud particle properties : a new view of Venus’s cloud
;         morphology as observed by the Galileo Near-infrared Mapping Spectrometer"
;         R. W. Carlson, L. W. Kamp, K. H. Baines, J. B. Pollack, D. H. Grinspoon,
;         Th. Encrenaz: P. Drossart and F. W. Taylor.
;         Planetary Space Science, Vol.41. No. I, pp. 411-485, 1993
;
;     Note: This procedure is meant for Venus Airglow observations. The correction for other types of
;           observations has not been tested.
;
; CALLING SEQUENCE:
;     emission_angle_correction_2_3, QUBE=input_cube, EMband=input_EMband, CORRECTED_QUBE=cube, /NO_POPUPS
;
; INPUTS:
;      No inputs are needed, the routine prompts for input bands with ENVI dialogs
;
; OUTPUTS:
;     Input calibrated cube or band corrected for emission angle and backscatering.
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
;         > emission_angle_correction_2_3
;
;     Input variables can be passed directly through IDL command line:
;         > cal  = virtispds()
;         > geo  = virtispds()
;         > band = (cal.qube)[135,*,*]
;         > EM   = (geo.qube)[27,*,*]*(geo.qube_coeff)[13]
;         > emission_angle_correction_2_3, QUBE=band, EMband=EM, CORRECTED_QUBE=corrected_cube
;
; REQUIRED FILES:
;     uses routine "select_envi_file.pro" for ENVI integration
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;
; MODIFICATION HISTORY:
;     Written by A.Cardesin, IASF-INAF, June 2008, Alejandro.Cardesin @ iasf-roma.inaf.it
;     Modified Dec 2008 by AC, Added keyword NO_POPUPS
;-

PRO emission_angle_correction_2_3, event, QUBE=input_cube, EMband=input_EMband, CORRECTED_QUBE=cube, NO_POPUPS=no_popups

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

;SELECT EMERGENCE ANGLE BAND (convert to radians)-----------------------
IF N_ELEMENTS(input_EMband) EQ 0 THEN BEGIN

	EMband = select_cube_from_envi(/BAND, TITLE="Select band containing emergence angle values", CANCEL=cancel)
	if cancel then return

ENDIF ELSE EMBand= input_EMBand

EMband = !pi/180.*float(EMband) ;in RADIANS
;---------------------------------------------------

IF ~KEYWORD_SET(NO_POPUPS) THEN $
progressbar = Obj_New('progressbar', Color='red', Text='Processing band... 0'+' %'$
      ,/NOCANCEL,/FAST_LOOP,/start,title='Emission angle and back-scatter correction',xsize=300,ysize=20)


; PERFORM OPERATION FOR EACH BAND OF THE CUBE ------
for b=0,nb-1 do begin
	IF ~KEYWORD_SET(NO_POPUPS) THEN $
	progressbar -> Update, fix(b*100./nb), Text='Processing band... ' + StrTrim(fix(b*100./nb),2)+' %'
	cube[*,*,b] = cube[*,*,b] / (0.232 + 0.768*cos(EMband)) ; backscatter correction (see reference publication)
endfor
;---------------------------------------------------

IF ~KEYWORD_SET(NO_POPUPS) THEN progressbar -> Destroy

; Put result back into ENVI (if called from there)
IF N_ELEMENTS(input_cube) eq 0 THEN $

	envi_enter_data, cube, bnames="EMCorrected("+bnameRAD+")", descrip='VIRTIS cube corrected', wl=wavelengthRAD, zplot_titles=['Wavelength [micron]', 'Radiance  [W/m2 micron sr]'] $

ELSE BEGIN

	; Otherwise put back cube in correct format [B,S,L] and return
	cube = reform(cube, ns, nl, nb)
	cube = transpose(cube,[2,0,1])

ENDELSE

END
