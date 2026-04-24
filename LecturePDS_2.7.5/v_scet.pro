function v_scet, SCET0, SCET1, SCET2, PRINT = print

;+ $Id: v_scet.pro,v 1.6 2007/02/20 16:15:34 flo Exp $
;
; NAME
;   V_SCET
;
; PURPOSE
;   Time strings management for Virtis Rosetta: converts SCET from
;      3-integer to S/C count format or reverse.
;
; CALLING SEQUENCE:
;   OutTime = v_SCET(S0, S1, S2)      ; 3-word to float
;        or
;   OutTime = v_SCET(Scet)          ; double-float format
;
; INPUTS:
; Either
;     S0,S1,S2: 3-integers encoding of a scet a provided TM paquets and PDS suffixes
;          Should be three short integers
; Or
;     SCET: S/C count (number of seconds elapsed from last clock resynch)
;          Should be a double precision floating point
;
; OUTPUTS:
; Either
;     result: SCET in S/C count (number of seconds from last clock resynch on ground)
;          Returned as double precision floating point
; Or
;     result: a 3-elt long array providing encoding of a scet as provided 
;             in TM paquets and PDS suffixes
;
; KEYWORDS
;     PRINT: print results with proper formatting
;
; EXAMPLE:
;     im = virtispds('FS535916.QUB') 
;     scet = im.suffix(0:2,0,0)                               ; first data SCET
;     print, v_scet(Scet(0),Scet(1),Scet(2)), f='(F20.5)'      ; print Scet with decimals 
;
;
;     tscet = v_scet(Scet(0),Scet(1),Scet(2))
;     print, v_scet(Tscet)           ; reverts to 3-integer format
;
; PRECAUTIONS:
;     Accuracy to be checked in details (at least 1s currently, seems better than 0.01s)
;     Apparently revertible, accuracy to be checked in details [but output format is different from input format]
;
; MODIFICATION HISTORY:
; 	Written:     Stephane Erard, LESIA, July 2005
;          SE, April 2006: reverse function in v_invscet
;          SE, May 2006: Merge both functions in a single one
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




on_error, 2

; Determine type of argument
Case N_params() of
3: begin
  scet= Ulong(Scet0)* 2UL ^ 16UL + Ulong(Scet1) + double(Scet2) / 2d ^ 16d
 If keyword_set(Print) then begin
    print,scet, f='(F20.6)'
 endif
end

1: begin
 If size(Scet0, /dim) NE 0 then begin
     print,'Argument must be scalar'
     return, -1
 endif 
 scet = lonarr(3)

 scet(0) = long(scet0 / 2UL ^ 16UL)
 scet(1) = long(scet0 mod 2UL ^ 16UL)
 scet(2) = long((scet0-long(scet0))*2d ^ 16d)

 If keyword_set(Print) then begin
    print, scet
 endif
end

else: begin
     print,'Accepts either 1 or 3 arguments'
     return, -1
end 
endcase

return, scet
END