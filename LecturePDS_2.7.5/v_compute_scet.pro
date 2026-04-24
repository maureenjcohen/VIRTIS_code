function v_compute_scet, $
	val1, val2, val3

;+ $Id: v_compute_scet.pro,v 1.6 2008/05/13 09:11:34 bjacquet Exp $
;
; NAME:
;  v_compute_scet
;
; PURPOSE:
;  The SCET values located in the PDS suffix are stored into 3 words of 2 bytes each
;  This function compte a SCET value given those 3 words
;  
; CALLING SEQUENCE:
;  Result=v_compute_scet(val1, val2, val3)
;               
; INPUTS:
;  val1 = Most significant word
;  val2 = Middle word
;  val3 = Least significant word
;       
; OUTPUTS:
;  Result = The SCET (SpaceCraft Elapsed Time)
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

	scet = replicate(double('FFFF'X), n_elements(val1))

	valid = where(val1 ne 'FFFF'X)
	if (valid[0] eq -1) then return, scet
	
	scet[valid]  = ulong(val1[valid]) * 2D^16D
	scet[valid] += ulong(val2[valid])
	scet[valid] += double(double(val3[valid]) / 2D^16D)
		
	return, scet
end
