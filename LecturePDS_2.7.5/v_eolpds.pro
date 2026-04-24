function V_EOLPDS, label, LFonly = LFonly, print = print, Continue=cont, Silent= Silent

;+ $Id: v_eolpds.pro,v 1.5 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;	V_EOLPDS
;
; PURPOSE:
;	Manage End Of Line markers in label strings.
;
; CALLING SEQUENCE:
;	Result=V_EOLPDS (Label)
;
; INPUTS:
;	Label = Array string, containing a PDS label 
;  (one keyword/value per line).
;
; OUTPUTS:
;	Result = Same array  with fixed EOL.
;
; OPTIONAL OUTPUT KEYWORDS:
;	LFonly - Default is to replace LF-only EOL (present in labels returned
;     by v_headpds.pro) by CR/LF EOL (the PDF standard). When this
;     keyword is set, changes CR/LF to LF-only (library internal format).
;	Print - Fixes all existing EOL and completes to 79 characters, plus 
;     issues a warning for lines too long. This is intended for clean printing on 
;     Unix systems. Beware that this changes the label length.
;	Continue - default is to stop whenever a non-standard EOL (neither LF nor CR/LF) 
;     is uncountered. When this keyword is set, continues and prints all errors. 
;     This allows to print non-standard labels, in particular with LF/CR EOL
;     (sometimes resulting from reading standard labels with
;     headpds.pro in the SNBPDS library up to 4.1).
;          Silent -  Get rid of messages (does not perform EOL or line length check)
;
; MODIFICATION HISTORY:
;     April 2001: written, Stephane Erard, IAS
;     July 2004: added Print keyword, SE
;     SE, LESIA, Nov 2005: 
;          Added Continue and Silent keywords
;          Now handles LF/CR EOL (SNBPDS library output)
;
;-
;
;###########################################################################
;
; LICENSE
;
;  Copyright (c) 1999-2008, StŽphane Erard, CNRS - Observatoire de Paris
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

  On_error,2                   ;2: Return to user            ; O: debug


     chaine = label
     sz= size(chaine)
     naxis = sz[0]                                         ;Number of dimensions
     if naxis GT 0 then nax = sz[ 1:naxis ]   ;Vector of dimensions
     type = sz[naxis + 1]                             ;Data type
     If type NE 7 then message, 'Label should be a string'
      dim= sz[1]
     endL = string([13b,10b]) ; standard PDS eol marker
     endL2 = string([10b,13b]) ; inverted by headpds (SNBPDS 4.0) in some situ

     for i = 0, dim-1 do begin
      lon = strlen(chaine(i))
      Fin1 = strmid(chaine(i), lon-1, 1)
      Fin2 = strmid(chaine(i), lon-2, 2)
      If Fin1 NE string(10B) and Not(keyword_set(silent)) then $
          message, string(FORMAT="('Wrong EOL in line',I4)", i), cont=cont
      If keyword_set(Print) then begin
          If Fin2 EQ endL or Fin2 EQ endL2 then chaine(i)= strmid(chaine(i), 0, lon-2) $
               else if Fin1 EQ string(10B) then chaine(i)= strmid(chaine(i), 0, lon-1)
          comp =(79-strlen(chaine(i))>0)
          if comp GT 0 then chaine(i)=  chaine(i)+strjoin(replicate(' ', comp)) $
               else if Not(keyword_set(silent)) then $
               message, string(format="('Label line ',I4,' too long')",i) , /cont
      endif else begin
       If not(keyword_set(LFonly)) then begin
          If Fin2 NE endL then chaine(i)= strmid(chaine(i), 0, lon-1) + endL
          If Fin2 EQ endL2 then chaine(i)= strmid(chaine(i), 0, lon-2) + endL
       endif else begin
          If Fin2 EQ endL or Fin2 EQ endL2 then chaine(i)= strmid(chaine(i), 0, lon-2) + string([10b])
      endelse
     endelse
     endfor

     return, chaine

 end 
