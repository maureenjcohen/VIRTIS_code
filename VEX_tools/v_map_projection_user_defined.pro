;+
; NAME:
;     V_MAP_PROJECTION_USER_DEFINED
;
; PURPOSE:
;     Simple call to V_MAP_PROJECTION with the QUERY keyword to popup options dialog
;
; CALL_SEQUENCE:
;     This function can be called either from ENVI or from IDL with no inputs
;     See source code "v_map_projection.pro" for more information.
;
; MODIFICATION HISTORY:
;     Written by Alejandro Cardesin, IASF-INAF, June 2008, alejandro.cardesin @ iasf-roma.inaf.it
;-

pro v_map_projection_user_defined, event

	v_map_projection, /QUERY

end
