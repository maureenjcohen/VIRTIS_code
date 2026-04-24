pro v_fcode, cube, label, FILTER = filter, MISSING = missing, VERBOSE= verbose

;+
;
; NAME
;   V_fcode
;
; PURPOSE
;   Filter special values in VIRTIS calibrated cubes
;   Adapted to VEx M calibrated files generated after June 2007
;
; CALLING SEQUENCE:
;   v_FCODE, qube [, label]
;
; INPUTS:
;     Qube = original calibrated cube from virtispds or v_readpds, floating point
;            Must be a named variable (ie: qube, not result.qube)
;     Label =  PDS label (e.g. as returned by V_HEADPDS or V_READPDS)  
;                  Ñ string array, optional
;
; OUTPUTS:
;     Qube is filtered, with encoded values replaced by NaN (if floats) or zeroes (if integers)
;     NaN values are not displayed by the plot command
;
;
; KEYWORDS
;     FILTER: Filtering option (to be completed)
;          0: no filtering
;          1: filter saturation codes only (default)
;          2: filter all special codes
;     MISSING: Value used to replace special codes. Default is NaN code for real data
;     VERBOSE: prints a little info for monitoring
;
; EXAMPLE (for testing):
;     d=virtispds('/Volumes/Data2/VEx/calibrations/EGSE_April2007/BIDQH2')
;     d.qube(100, 100) = -1000                                            
;     dd=d.qube                                                           
;     plot, dd(*, 100)  
;     v_fcode, dd     ; set saturated data to 0 (NaN if real)
;     loadct, 12
;     oplot, dd(*, 100), col=200
;     ...
;     v_fcode, dd, filter=2, missing =0     ; set all special codes to 0
;
; MODIFICATION HISTORY:
;   Written:     Stephane Erard, LESIA, June 2007
;   18 July 2007, SE: Completed for other special codes, can change substitute value
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
If size(Cube, /type) EQ 7 then message, 'Argument should not be a structure'

DefSat  = -1000     ; default Virtis VEx value for saturation
Minval  = -999      ; default Virtis VEx value for valid minimum 
If N_elements(filter) EQ 0 then filter = 1     ; keyword not set => filter 1
Cind = -1

CASE filter of
1: begin     ; filter saturation
   If N_params() GE 2 then begin      ; if label provided
       Satcode = v_pdspar(label, "CORE_HIGH_INSTR_SATURATION")
       Isat = size(Satcode, /dim)
       Satcode = Satcode((Isat -1)>0)     ; pick up the last one, for M calibrated labels
       If satcode EQ '"NULL"' then Satcode = DefSat
   endif else Satcode = DefSat
   Cind = where(cube EQ Satcode, count)
end
2: begin     ; filter all special codes
   If N_params() GE 2 then begin      ; if label provided
       Mincode = v_pdspar(label, "VALID_MINIMUM")
       Isat = size(Mincode, /dim)
       Mincode = Mincode((Isat -1)>0)     ; pick up the last one, for M calibrated labels
       If Mincode EQ '"NULL"' then Satcode = Minval
   endif else Mincode = Minval
   Cind = where(cube LT Mincode, count)
end
else:      ; do nothing if filter = 0
endcase

;print, count
If N_elements(Missing) EQ 0 then begin          ; default values
     Missing = !values.F_Nan                    ; floats
     If size(Cube, /type) NE 4 and size(Cube, /type) NE 5 then Missing = 0  ; integers
endif
If Cind(0) NE -1 then cube(Cind) = Missing


END