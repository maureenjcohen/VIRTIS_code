;+
; NAME:
;     V_GEO_CONTOUR_SURFACE
;
; PURPOSE:
;     Simple call to V_GEO_CONTOUR with the keywords to design a 3D surface
;     (parameters cannot be specified directly from ENVI)
;
; MODIFICATION HISTORY:
;     Written by Alejandro Cardesin, IASF-INAF, November 2007, alejandro.cardesin @ iasf-roma.inaf.it
;-

pro v_geo_contour_surface, event

v_geo_contour, PLANAR=0, /FILL, /SHADING

end
