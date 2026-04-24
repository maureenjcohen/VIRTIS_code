Pro V_SWAPDATA, variable, LSB_SOURCE = LSB_source, FORCE = force, SILENT = silent

;+ $Id: v_swapdata.pro,v 1.6 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;      V_SWAPDATA
;
; PURPOSE:
;      Convert IDL variables from MSB/LSB to current machine architecture
;          (default is from MSB to host)
;
; CALLING SEQUENCE:
;      V_SWAPDATA, variable, [ /LSB , /FORCE, /SILENT]
;
; PARAMETERS:
;      variable - The data to be converted
;            May be a scalar, an array, or a structure; must be a named variable 
;            All datatypes are supported, including floats and complex
;            The variable is swapped in place to save memory
;                    (the original variable is erased)
;
; OPTIONAL INPUT KEYWORD:
;      LSB_SOURCE = when set, converts from LSB data to host
;      FORCE= Forces data swapping (does not check machine architecture)
;
;            V_ SWAPDATA will leave variables unchanged on MSB machines,
;             unless the FORCE or LSB_source keywords are set.
;
;      SILENT - Inhibits messages
;
; MODIFICATION HISTORY:
;       v_MSBtoHost: Written, Stephane Erard, IAS. Nov 2000
;          adapted from conv_unix_vax June 1998 (in ASTRON)
;       Stephane Erard, LESIA June 2005, update:
;          - Now uses much faster and versatile swap_endian routines
;               (support all platforms, all data types and all data structures automatically)
;          - Still supports pre-5.6 IDL (but less efficient)
;
;       v_SwapData: adapted from v_msbtohost - Stephane Erard, LESIA June 2005
;          - Turned to a procedure for consistency, and changed name
;          - Added conversion from LSB source data here for flexibility
;          - Replaced simulation of other architectures by FORCE option
;       Update, Oct 2005 — SE, LESIA
;          - Added messages, and SILENT keyword
;          - Skip processing if type is Byte (no filtering in Swap_endian_inplace)
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
;***********************************************************
;
on_error, 2
;  Check to see if VARIABLE is defined
;
 if N_params() LT 1 then $
      message,'Syntax - V_SwapData, variable, [/LSB] [, /FORCE ] [, /SILENT ]'

Dtype = size(variable, /type)
If Dtype EQ 1 then goto, fin

IF not(keyword_set( FORCE )) THEN BEGIN           ; Convert to machine architecture

 if not(keyword_set( LSB_source )) then begin           ; From MSB to host

  if !version.release ge 5.6 then begin
    Swap_Endian_InPlace, Variable, /swap_if_little
  endif else begin
    if byte(1,0) then variable=swap_endian(temporary(variable))
  endelse
  if byte(1,0) and not(keyword_set(SILENT)) then message, 'Swap performed', /cont

  endif else begin                                                      ; From LSB to host

  if !version.release ge 5.6 then begin
    Swap_Endian_InPlace, Variable, /swap_if_big
  endif else begin
    if not(byte(1,0)) then variable=swap_endian(temporary(variable))
  endelse
  if not(byte(1,0)) and not(keyword_set(SILENT)) then message, 'Swap performed', /cont

  endelse

ENDIF ELSE BEGIN                                             ; Convert anyway

  if !version.release ge 5.6 then begin
    Swap_Endian_InPlace, Variable
  endif else begin
    variable=swap_endian(temporary(variable))
  endelse
  if not(keyword_set(SILENT)) then message, 'Swap performed', /cont

ENDELSE

fin:
END