function v_time, InTime, Dsecond, PRINT = print

;+ $Id: v_time.pro,v 1.3 2007/02/20 16:15:34 flo Exp $
;
; NAME
;   V_TIME
;
; PURPOSE
;   Convert time from vectorial form to ISO string and back
;     (ISO strings are used e.g. in FITS and PDS headers)
;   Also compute date/time after a given lapse of time
;
; CALLING SEQUENCE:
;   OutTime = v_time(InTime, [Dsec]) 
;
; INPUTS:
; InTime = Time either as an ISO string, as a 'time vector', or as Julian day
;      Vector form is [Year, Month, Day, Hour, Minutes, Seconds] 
;          (ISO order, different from that of standard IDL routines)
;          Year, month and day must be provided
;      ISO strings are of the form YYYY-MM-DDThh:mm:ss.fff
;           (where 'T' is literal T, and no space is present)
;      Julian day should be provided in double precision to maintain resolution
; If no argument is provided, use current UTC (provided by OS clock)
;
;  Dsecond: optional offset in seconds to add to input time. If provided, the first
;          argument is updated but no format conversion is performed. 
;
; OUTPUTS:
;  result: Converted time (ISO to vector, vector or Julian day to ISO) 
;          or time + offset in input format
;
; KEYWORDS
;  PRINT: print result on command window
;
; EXAMPLES:
;
;     print, v_time()                ; return current UTC as ISO string
;     print, v_time('2005-05-16T01:26:20')      ; convert ISO string
;     print, v_time([2005,5,15,23,50,20.2])     ; convert vector
;     print, v_time(2453506.55981482d)          ; convert Julian day
;                                        add offset and preserve format
;     print, v_time([2005,5,15, 23, 50, 20.2], 20)
;
; PRECAUTIONS:
;     The syntax of the input ISO string is not checked
;     Does not handle ISO strings with time zone (with suffix +01:00), 
;          except UTC/GMT marker in input (with suffix Z)
;     Does not handle modified Julian days
;     Comptutation accuracy is supposedly 0.1 ms 
;     Check your system clock/time zone if used with no input!
;     Requires IDL 5.4 (at least)
;
; MODIFICATION HISTORY:
; 	Written:     Stephane Erard, May 2005
;     SE, June 2005. 
;        Changed Dsecond from keyword to argument
;          (to handle null offsets).
;        Fixed fraction of seconds in offset mode
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




; Determine type of argument

;on_error, 1
If N_params() EQ 0 then inTime = systime(/jul,/UTC)

Ttype = size(inTime, /type)
Tdim = size(inTime, /dim)

If Ttype EQ 7 and Tdim EQ 0 then type = 0 else $    ; string
  If Ttype NE 7 and Tdim EQ 0 then type = 2 else $     ; Julian time
    If Ttype NE 7 and Tdim GE 3 and Tdim LE 6 then type = 1 else begin $  ; vector
     Message, 'Inconsistent time input',/cont
     Message, 'Should be ISO string, time vector or Julian day'
endelse

offmode  = N_params() GE 2?1:0
if not(offmode) then Dsecond = 0.


SWITCH Type OF

0: begin                  ;ISO string

vect = strsplit(inTime, /ext, '-T:')     ; parse string
outTime = fltarr(6)     ; set missing values to 0
outTime(0) = vect

if offmode then begin     ; offset mode
     outTime(5) = outTime(5) +Dsecond
     outTime = v_time(outTime)
endif else begin
; convert to integer if no fraction of second is provided
if outTime(5)-long(outTime(5)) EQ 0 then outTime = long(outTime) 
endelse

break     ; done
end

1: begin                  ;vector

Temp = fltarr(6)
Temp(0) = inTime      ; set missing values to 0
inTime = Temp
; convert to Julian day
if offmode then  inTime(5) = inTime(5)+Dsecond     ; offset mode
Jul = JulDay(inTime(1),inTime(2),inTime(0),inTime(3),inTime(4),inTime(5))
inTime = Jul
end

2: begin                  ;Julian time

f2= (inTime-long(inTime))*86400.d    ; retrieve fractions of seconds
frac= f2-long(f2)

form2='(C(CYI,"-",CMOI2.2,"-",CDI2.2,"T",'
form2 = form2 + 'CHI2.2,":",CMI2.2,":",CSI2.2,"."),I3.3)'  ; includes millisecondes
outTime =  string(FORMAT=form2, inTime, frac*1000)
if offmode then  outTime = v_time(outTime) ; back to initial format in offset mode

end
ENDSWITCH


If keyword_set(Print) then print, outTime
return, outTime
END