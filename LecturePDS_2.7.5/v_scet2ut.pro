function v_scet2ut, label, SCET, PRINT = print, VEX= VEx, RESYNCH = resynch, SILENT= silent

;+ $Id: v_scet2ut.pro,v 1.8 2007/07/06 10:36:33 erard Exp $
;
; NAME
;   V_SCET2UT
;
; PURPOSE
;   Time strings management for Virtis Rosetta: converts SCET to UTC for a given session
;
; CALLING SEQUENCE:
;   OutTime = v_SCET2UT(label, SCET) 
;
; INPUTS:
;     Label =  PDS label (e.g. as returned by V_HEADPDS or V_READPDS)  
;                  Ñ string array, optional
;     SCET = Spacecraft clock count of current event. Can be a vector.
;                 Should be provided as (signed) long or 64-bits integer, 
;                 or double precision float.
;
; OUTPUTS:
;     result: corresponding UTC for this SCET, as ISO time string.
;            Directly comparable to TC timeline or external events.
;            Precision is better than 1s with SCET provided as double.
;
;            If SCET is outside current session, a message is issued and variable
;        !ERR is set to -1. In this case, results may be doubtful.
;            If no label is provided, count from initial time origin (last 
;        synchronization before launch). Result is then very approximative because 
;        neither S/C-Earth distance nor S/C clock drift are corrected
;        (assume scet is actually an encoded UTC).
;
; KEYWORDS
;     RESYNCH: resynchronization number in output, 0 if not present 
;                    (which should mean 1)
;     PRINT: print intermediate results on command window
;     SILENT: filters console messages
;     VEX: specifies VEx mission for time origin (used if label not provided) 
;               - default is to use Rosetta time origin
;
; EXAMPLES:
;     lbl = v_headpds('FS535916.QUB') 
;     scet = 68635016.15d   
;     print, v_scet2ut(lbl, SCET)        ; return UTC as ISO string
;
;     scet = 68635016.15d
;     print, v_scet2ut(Scet)             ; Rosetta
; returns:     2005-03-05T09:16:56.000
;     print, v_scet2ut(Scet, /VEx)       ; VEx
; returns:     2007-05-03T09:16:56.000
;
;
; PRECAUTIONS:
;     Requires S/C clock in label to be provided in ESA's fashion (# of s since clock reset)
;     Determine S/C vs UTC offset from session start in the label. Therefore, 
;          SCET must be inside the session to maintain accuracy 
;          (i.e., use only with SCETs corresponding to the label).
;     S/C clock offset is assumed constant during a session.
;     Bad rounding errors occur if argument is not long integer or double precision real.
;     Calls V_TIME.PRO, which requires IDL 5.4 (at least)
;
; MODIFICATION HISTORY:
;   Written:     Stephane Erard, LESIA, June 2005
;        SE, July 2005: changed filtering of possible resynch # in session limits
;        SE, Nov 2005: support for VEx time origin through the VEX keyword 
;                    (no label provided, mission ID must be mentioned manually)
;                     + fix for unknown S/C stop count
;        SE, Dec 2005: added RESYNCH keyword
;                      + Now accepts scet argument as string (output of v_pdspar) 
;        SE, April 2007: small fix in scet parsing
;        SE, July 2007: VEX time origin updated from SPICE result
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



on_error, 2     ; return to main

If not(keyword_set(silent)) then silent = 0
If N_params() LE 1 then begin      ; if label not provided

  scet= label
  start_utc = '2003-1-1T0:0:0.0'     ; Rosetta in flight
;  if keyword_set(VEX) then start_utc = '2005-02-28T0:0:0.0'     ; VEx in flight
  if keyword_set(VEX) then start_utc = '2005-02-28T23:59:59.815'     ; VEx in flight, from SPICE estimate

  start_scet = 0.d
  stop_scet = 900000001.d
  resynch =0
  if not(silent) then message, 'No label provided. Counting from S/C time origin', /cont

Endif else begin

  start_utc = (v_pdspar(label, 'START_TIME'))(0)
  start_scet = ((v_pdspar(label, 'SPACECRAFT_CLOCK_START_COUNT'))(0))
  stop_scet = ((v_pdspar(label, 'SPACECRAFT_CLOCK_STOP_COUNT'))(0))
     ; filter possible resynch # 
   temp = strpos(start_scet,'/') 
  if temp GE 0 then begin
      resynch = (strsplit(start_scet, /ext, '/'))(0)
      start_scet = (strsplit(start_scet, /ext, '/'))(1)
  endif
  temp = strpos(stop_scet,'/') 
  if temp GE 0 then stop_scet = (strsplit(stop_scet, /ext, '/'))(1)
  if string(stop_scet) EQ '"NULL"' then stop_scet = 900000001.d     ; in case it's missing

Endelse

;time_launch = Julday(1,1,2003,0,0,0.)
;start_scet2 = v_time(time_launch, Dsec = start_scet)   ; vector



Tdim = (size(scet, /dim))(0) > 1
If size(scet, /type) EQ 7 then begin
    temp = strpos(scet,'/') 
    if temp GE 0 then scet = (strsplit(scet, /ext, '/'))(1) 
    scet = v_str2num(scet)
endif

result = strarr(Tdim )
for i = 0, Tdim-1 do begin     ; loop on SCET elements
; Time check: SCET should be inside session, or nearby 
 If scet(i) gt stop_scet or scet(i) lt start_scet then begin
  if not(silent) then message, 'Event is outside session', /cont
  !err = -1               ; to be checked immediately in output
 endif
 time_offset = double(scet(i)) - double(start_scet)
 result(i) = v_time(start_utc, time_offset)
endfor

; time_offset = scet - start_scet
; result = v_time(start_utc, time_offset)

If keyword_set(Print) then begin
print, start_utc
print, start_scet, f='(F20.6)'
print, time_offset, f='(F20.6)'
print, result
endif

return, result
END