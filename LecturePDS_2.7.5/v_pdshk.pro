function v_pdshk, image

;+ $Id: v_pdshk.pro,v 1.11 2008/04/07 08:37:45 bjacquet Exp $
;
; NAME:
;  v_pdshk
;  
; PURPOSE:
;  Translates the housekeepings values contained in an image suffix
;  (returned by the procedure virtispds.pro)
;     
; CALLING SEQUENCE:
;  image = virtispds(path_name)
;  result = v_pdshk(image)
;     
; INPUTS:
;  image = structure returned by virtispds()
;
; OUTPUTS:
;  Result = structure composed of :
;    - a double array containing all the translated housekeeping values
;    - a string array containing the name of the housekeepings
;
; PROCEDURES USED:
;  Functions : v_translatehk, v_transfunchk, v_compute_intnum, v_compute_scet
;
; MODIFICATION HISTORY:
;  Written by Florence HENRY, dec. 2005
;  jan. 2006 : modified the input arguments.
;  test de modification
;-    
;
;###########################################################################
;
; LICENSE
;
;  Copyright (c) 1999-2008, Stéphane Erard, CNRS - Observatoire de Paris
;  All rights reserved.
;  Non-profit redistribution and non-profit use in source and binary forms, 
;  with or without modification, are permitted provided that the following 
;  conditions are met:
; 
;        Redistributions of source code must retain the above copyright
;        notice, this list of conditions, the following disclaimer, and
;        all the modifications history.
;        Redistributions in binary form must reproduce the above copyright
;        notice, this list of conditions, the following disclaimer and all the
;        modifications history in the documentation and/or other materials 
;        provided with the distribution.
;        Neither the name of the CNRS and Observatoire de Paris nor the
;        names of its contributors may be used to endorse or promote products
;        derived from this software without specific prior written permission.
; 
; THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;

	DEBUG = 1
	
	suffix = image.suffix

	mission = ''
	test_mission_val = v_pdspar(image.label, 'SPACECRAFT_NAME')
	if (test_mission_val ne '') then begin
	
		;;; Old version of PDS labels
		mission = (stregex(test_mission_val, '^([^ ]+)_ORBITER', /extract, /subexpr))[1]
		
	endif else begin
	
		test_mission_val = v_pdspar(image.label, 'MISSION_NAME')
		if (test_mission_val ne '') then begin
		
			;;; New version of PDS labels
			mission = (stregex(test_mission_val, '"([^"]+)"', /extract, /subexpr))[1]
			mission = strjoin(strsplit(mission, ' ', /extract))

			;;; Contournement de INTERNATIONAL ROSETTA MISSION
			if (strpos(mission, 'ROSETTA') ne -1) then $
				mission = 'ROSETTA'
			
		endif
		
	endelse
	
	if (mission eq '') then return, 0
	; if (DEBUG) then print, mission

	hk_size = size(suffix)
	n_suffix = hk_size[1]
	case hk_size[0] of
		1: begin
			n_band = 1
			n_frame = 1
		end
		2 : begin
			n_band = hk_size[2]
			n_frame = 1
		end
		else : begin
			n_band = hk_size[2]
			n_frame = hk_size[3]
		end
	endcase
	
	if (n_suffix eq 72) then begin
		instrument = 'Virtis-H'
		nb_values = 91
		suf_scet = [0, 7, 19, 29]
		suf_int = [32]
		suf_spare = [1, 2, 6, 8, 9, 18, 20, 21, 28, 30, 31, 33, 70, 71]
	endif else begin
		if (n_suffix eq 82) then begin
			instrument = 'Virtis-M'
			nb_values = 102
			suf_scet = [0, 7, 19, 29, 58]
			suf_int = [-1]
			suf_spare = [1, 2, 6, 8, 9, 18, 20, 21, 28, 30, 31, 57, 59, 60, 81]
		endif else begin
			return, -1
		endelse
	endelse

	suf_science_field = 9
	suf_hk_field = where(indgen(nb_values) gt suf_science_field)
	
	values = dblarr(nb_values, n_band, n_frame)
	
	i_value = 0
	for i=0,n_suffix-1 do begin
		case 1 of
			(where(i eq suf_spare) ne -1)	: begin
				id = -2
			end
			(where(i eq suf_int) ne -1)	: begin
				i_2 = i+1
				id = -1
				res = v_compute_intnum(suffix[i_2, *, *], suffix[i, *, *])
			end
			(where(i eq suf_scet) ne -1)   : begin
				i_2 = i+1
				i_3 = i+2
				id = -1
				res = v_compute_scet(suffix[i, *, *], suffix[i_2, *, *], suffix[i_3, *, *])
			end
			else : begin
				val = suffix[i, *, *]
				id = i
				res = v_translatehk(id, val, mission, instrument)
			end
		endcase
		if (id ne -2) then begin
			n_val = n_elements(res) / (n_band * n_frame)
			res = reform(res, n_val, n_band, n_frame)
			values[i_value : i_value + n_val - 1, *, *] = res[*, *, *]
			i_value += n_val
		endif
	endfor

	; Suppress the bands where all the HK are equal to 'FFFF'X
	band_max = n_band
	band_max = max((array_indices(values[suf_hk_field, *, *], $
		where(values[suf_hk_field, *, *] ne 'FFFF'X)))[1,*])
	
	result = {values : dblarr(nb_values, band_max+1, n_frame), $
		names : strarr(nb_values)}
		
	result.values = values[*, 0:band_max, *]
	result.names = v_hk_names(instrument)

	return, result

end
