;+
; NAME:
;     IA_Corr
;
; PURPOSE:
;     Correction of for emergence angle and the reflected solar radiation for VIRTIS data 
;
;     Note: the use of the method could be usesful only if in the band is not an absorber and in thermal region.
;           the function radiant is used in order to increase the readibility of the routine
;
; CALLING SEQUENCE:
;     ia_cor, cube, geo, band, correct
;
; INPUTS:
;      cube : is a stucture containing the spectral data
;      geo : is a structure containing the geometrical data
;      band : the VIRTIS band for the correction
;
; OUTPUTS:
;     correct : 2D matrix containig the correct data 
;
; EXAMPLE:
;     Input variables can be passed directly through IDL command line:
;         > cube  = virtispds()
;         > geo   = virtispds()
;         > band  = 291
;         > ia_corr,cube,geo,band correct
;         > TV, correct
;
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.4.1 for Linux [Ubuntu 8.10].
;
; MODIFICATION HISTORY:
;     Written by R. Politi, IASF-INAF,18 December 2008, romolo.politi @ iasf-roma.inaf.it
;
;-
Function radiant, angl 
	res=(angl*!pi)/180.d
	Return,Double(res)
End
;#################################
Pro ia_corr,cube,geo,band, correct
  ia=26 ; incidence angle index
  iav=Reform(geo.qube[ia,*,*]*geo.qube_coeff[ia]) ; array containing the incidence angles in degrees
  sz=Size(cube.qube,/Dimensions)
  newcb=FltArr(sz[1],sz[2])
  newcb[*,*]=cube.qube[band,*,*]
  sz=Size(newcb,/Dimensions)
;################################################
;# Correction for the emergence angle           #
;################################################
  For i=0,sz[1]-1 Do For j=0,sz[0]-1 Do Begin
	newcb[j,i]=(newcb[j,i]/Cos(radiant(geo.qube[27,j,i]*geo.qube_coeff[27])))*Cos(Min(radiant(geo.qube[27,*,i]*geo.qube_coeff[27]),/NaN))
  EndFor
;################################################
;# Definition of the correction line            #
;################################################
  mean_v=FltArr(sz[1])
  pippo=newcb
  pippo[Where(pippo LT 0)]=!Values.F_NaN
  For i=0,sz[1]-1 Do Begin
	mean_v[i]=Min(newcb[8:30,i],/NaN)
  EndFor
;################################################
;# Perform the incidence angle correction       #
;################################################
  correct=newcb
  For i=0,sz[1]-1 Do begin
	correct[*,i]=newcb[*,i]-mean_v[i]+Min(mean_v,/NaN);.01
  EndFor
End