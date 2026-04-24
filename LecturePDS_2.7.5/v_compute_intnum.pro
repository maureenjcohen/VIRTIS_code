function v_compute_intnum, val1, val2

;+ $Id: v_compute_intnum.pro,v 1.5 2007/04/23 15:00:41 flo Exp $
;
; NAME:
;  v_compute_intnum
;
; PURPOSE:
;  The Virtis-H integration time is stored in the Housekeeping packets into 2 words of 2 bytes each
;  This function computes the integration time uses given those 2 words
;  
; CALLING SEQUENCE:
;  Result=v_compute_intnum(val1, val2)
;               
; INPUTS:
;  val1 = least significant word
;  val2 = most significant word
;       
; OUTPUTS:
;  Result = The translated integration time
;
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
	
	IntNum = replicate(double('FFFF'X), n_elements(val1))

	valid = where((val1 ne 'FFFF'X) and (val2 ne 'FFFF'X)) 
	if (valid[0] eq -1) then return, IntNum
	
	IntNum[valid] = (val1[valid] + val2[valid] * 1024) * 512e-6
	
	return, IntNum
end
