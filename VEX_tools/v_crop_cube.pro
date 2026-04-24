;+
; NAME:
;    v_crop_cube
;
; PURPOSE:
;    Remove first line, repeated lines (optional) and first 6 samples
;
; INPUT:
;    input_cube : variable with 3D cube or 2D image
;
; KEYWORD PARAMETERS:
;    SCAN_MODE_ID : (set by default) remove the repeated part of the cube
;
;    SAMPLES: output variable containing number of samples of output cube
;
;    LINES: output variable containing number of lines of output cube
;
; MODIFICATION HISTORY:
;    Written  by A.Cardesin, July 2008, Alejandro.Cardesin @ iasf-roma.inaf.it
;    Modified by A.Cardesin, June 2009: Adapted also for 2D images/bands
;-

pro v_crop_cube, cube, SCAN_MODE_ID=scan_mode_id, LINES=lines, SAMPLES=samples

if (size(cube,/N_DIM) EQ 3) then begin

	bands   = long((size(cube,/DIM))[0])
	samples = long((size(cube,/DIM))[1])
	lines   = long((size(cube,/DIM))[2])

endif else $
if (size(cube,/N_DIM) EQ 2 ) then begin

	bands   = 1
	samples = long((size(cube,/DIM))[0])
	lines   = long((size(cube,/DIM))[1])

	cube    = reform(cube, bands, samples, lines)

	flag2D  = 1 ; remember to put output back into 2D

endif else message, "ERROR: input has wrong dimensions, expected 3D cube or 2D image"

;-------------------------------------------------------------------------
; LINES:
;-------------------------------------------------------------------------

;; always remove first line
cube = cube[*,*,1:*]

; remove repeated lines if SCAN_MODE is 1 (or if not specified)
IF N_elements(scan_mode_id) EQ 0 || scan_mode_id EQ 1 THEN cube = cube[*,*,0:(samples<(lines))-2]

lines = (size(cube,/DIM))[2]

;-------------------------------------------------------------------------
; SAMPLES:
;-------------------------------------------------------------------------

; remove first 6 samples
cube = cube[*,ceil(6*samples/256.):(samples-1),*]

samples = (size(cube,/DIM))[1]


;-------------------------------------------------------------------------
; END
;
if keyword_set(flag2D) then cube = reform(cube)

end
