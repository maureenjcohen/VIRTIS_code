;+
; NAME:
;     V_GEO_CONTOUR_OVERPLOT
;
; PURPOSE:
;     Simple call to V_GEO_CONTOUR with the OVERPLOT keyword, as it cannot be called directly from ENVI
;
; MODIFICATION HISTORY:
;     Written by Alejandro Cardesin, IASF-INAF, 07 Nov 2007, alejandro.cardesin @ iasf-roma.inaf.it
;-

pro v_geo_contour_overplot, event

v_geo_contour, /overplot

end
