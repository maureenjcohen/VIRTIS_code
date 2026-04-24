function v_transfunchk, $
	value, $
	coef, $
	conv_OhmToKelvin = conv_OhmToKelvin, $
	conv_VoltToKelvin = conv_VoltToKelvin, $
	signed = signed

;+ $Id: v_transfunchk.pro,v 1.4 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;  v_transfunchk
;  
; PURPOSE:
;  Translate the value given in argument, following the transfert function given by coef 
;     
; CALLING SEQUENCE:
;  result=v_transfunchk(value, coef [, conv_OhmToKelvin] [, conv_VoltToKelvin] [, signed])
;     
; INPUTS:
;  value = HK value to translate
;  coef = transfert function which has to be a 3 elements array representing the 
;         coeficients of a  2nd order polynomial
;
; OPTIONAL INPUT KEYWORDS:
;  conv_OhmToKelvin = flag indicating that the result of the transfert function
;                     is in Ohm and has to be converted into Kelvin
;  conv_VoltToKelvin = flag indicating that the result of the transfert function
;                     is in Volt and has to be converted into Kelvin
;  sign = flag indicated that the word "value" is signed
;
; OUTPUTS:
;  result = the value translated 
;
; MODIFICATION HISTORY:
;  Written by Florence HENRY, dec. 2005
;  Small modif to process vectors, SE, Nov 2006
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
	
	if (value(0) eq 'FFFF'X ) then begin
		return, value
	endif
	
	coef = reform(coef)
	
	if (keyword_set(signed) and value(0) gt 32768) then begin
		; Two's complement
		value = -float(uint(NOT value) + 1)
	endif
	
	
   VoltToKelvin = dblarr(2,40)
	VoltToKelvin(0,*) = [330, 320, 310, 305, 300, 290, 280, 273.15, 270, 260, $
		250, 240, 230, 220, 210, 200, 190, 180, 170, 160, 150, 140, 130, 120, $
		110, 100, 95, 90, 85, 80, 77.35, 75, 70, 65, 60, 58, 56, 54, 52, 50]
   VoltToKelvin(1,*) = [0.44647, 0.47069, 0.49484, 0.50688, 0.51892, 0.54294, $
		0.5669, 0.58327, 0.5908, 0.61465, 0.63841, 0.66208, 0.68564, 0.70908, $
		0.73238, 0.75554, 0.77855, 0.80138, 0.82404, 0.8465, 0.86873, 0.89072, $
		0.91243, 0.93383, 0.95487, 0.9755 ,0.98564, 0.99565, 1.00552, 1.01525, $
		1.02032, 1.02482, 1.03425, 1.04353, 1.05267, 1.05629, 1.05988, 1.06346, $
		1.067, 1.07053]

   OhmToKelvin = dblarr(2,34)
	OhmToKelvin(0,*) = [673.15, 653.15, 633.15, 613.15, 593.15, 573.15, 553.15, $
		533.15, 513.15, 493.15, 473.15, 453.15, 433.15, 413.15, 393.15, 373.15, $
		353.15, 333.15, 313.15, 293.15, 273.15, 253.15, 233.15, 213.15, 193.15, $
		173.15, 153.15, 133.15, 113.15, 93.15, 73.15, 53.15, 33.15, 13.15]
   OhmToKelvin(1,*) = [1244.49, 1209.37, 1174.03, 1138.47, 1102.68, 1066.68, $
		1030.46, 994.01, 957.34, 920.46, 883.36, 846.03, 808.48, 770.71, 732.72, $
		694.5, 656.05, 617.39, 578.49, 539.36, 500, 460.31, 420.33, 380.03, $
		339.41, 298.43, 257.03, 215.14, 172.64, 129.5, 86.1, 44.62, 12.67, 1.25]

	
	a = coef[0]
	b = coef[1]
	c = coef[2]
	res = a * value * value + b * value + c
	
	if keyword_set(conv_OhmToKelvin) then begin
		res = interpol(OhmToKelvin[0,*], OhmToKelvin[1,*], res, /lsquadratic)
	endif else begin
		if keyword_set(conv_VoltToKelvin) then begin
			res = interpol(VoltToKelvin[0,*], VoltToKelvin[1,*], res, /lsquadratic)
		endif
	endelse	
	
	return, res
end
