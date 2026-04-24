function V_STR2NUM, Ivalue, TYPE = type, SILENT = silent, IN_TYPE = in_type, EXTRACT = extract

;+ $Id: v_str2num.pro,v 1.7 2008/11/24 15:59:05 erard Exp $
;
; NAME:
;          V_STR2NUM
;
; PURPOSE:
;           Return the numeric value of a string, if possible.
;           Otherwise return the input string.
;           Return smallest Type that can accommodate the value, except byte.
;
; CALLING SEQUENCE:
;          result = V_STR2NUM(Ivalue, [Type=Type])
;
; INPUT:
;          Ivalue = a scalar string to be converted to its numeric value 
;               or a numeric value to be converted to its 'smallest' form (except byte)
;
; OUTPUT:
;          result = numeric value of input string, or unaltered string
;               if numeric conversion is not possible.
;              (smallest Type that can accommodate it, except byte).
;
; OPTIONAL KEYWORD:
;    TYPE:  output, contain the IDL type of the result
;    IN_TYPE: input, contains the desired IDL type of result.
;          (1 to 7 or 14 - this may result in round-off errors).
;          This option allows convertion to byte. Beware that, if later converted 
;          back to a string, this can yield major problems in the IDL session 
;          (if ascii < 32).
;    EXTRACT: if set, extracts the first value from a string. Otherwise, the string must match a value exactly.
;             May be used to handle IDL type notation (eg, '123L') or values embedded in text
;
;	SILENT - Disable warning messages.
;
; EXAMPLES:
;
;          x = v_str2num('123')     ; Returns '123' in a numerical variable
;
;     Test:
;          sval= '-1.3D-10'                                 
;          print, v_str2num(sval, type=tt) , tt, '  ', sval
;
; PROCEDURE / LIMITATIONS:
;          The input string is first tested to see if it is an ISO time string
;          by searching for ':' or 'T' (see modification history). If so it
;          is returned unchanged as a string. 
;          Dates/time strings can be further handled with V_TIME.PRO
;          Also filters S/C clock time strings by searching for '/'.
;          S/C clock time strings can be further handled with V_SCET2UT.PRO
;
;          Numerical values are identified by matching a regular expression.
;          This does not necessarily cover all possibilities.
;          Support Exp notation (e or E), but requires decimal point ***
;
;          With no option, the string must match a numerical value. If option EXTRACT is set
;          the first value is returned (this can be misleading).
;          If the string does not contain a numerical value, the argument is returned as a
;          string with no warning - result type should always be tested.
;
;          The string is then tested for a complex value: yes if it contains two 
;          numerical values separated by '(', ',' or ')' (minimal testing). 
;          Does not support double precision complexes.
;
;          Type is set to float is the string contains '.', E, e, d, or D
;          Integer Types are then tested for the optimal format 
;          (from INTEGER to LONG64 - conversion to bytes is removed to avoid 
;          messing with function characters in the 0-31 range: the result is 
;          converted back to string in higher level routines).
;          Converts to double precision if integer with more than 18 numerals,
;          or if floating point with more than 7 numerals (to retain accuracy).
;
;          Beware that a conversion error may occur before call when using 
;          a numerical argument. Example:
;          print, v_str2num(68630136.701), f='(F20.4)'  ; is rounded before call:
;          print, 68630136.701, f='(F20.4)'     ; rounding by IDL itself
;
;
;
; HISTORY:
;          Original str2num.pro:
;          Written by John D. Koch, July, 1994
;          27 July 1999, M. Barker: fixed bug that converted a date in format of
;		1991-05-12 to 1991, so that if a '-' is 
;		detected and neither 'e' or 'E' are detected,
;		the value is left as a string.
;
;          Processing has been completely changed - S. Erard, LESIA, June 2005
;               + use "new" integer Types (long and long64)
;               + removed conversion to bytes, to avoid non printable characters
;               Maintained name and arguments for compatibility
;          SE, July 2005: handles reset number in S/C clock counts
;          SE, Nov 2005: added forced type option (IN_TYPE) + SILENT option.
;          SE, Nov 2008: Replaced error trapping by regex check, to run under GDL
;                        Now recognizes floats with E and no .
;                        No longer modifies input argument
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
;----------------------------------------------------------------------


 svalue = Ivalue     ; preserve input
 if ( N_PARAMS() NE 1)then begin
     print,'Syntax - result =v_str2num(svalue,[ Type = Type])
     return, -1
 endif 

 value = 0
 s = size(svalue)			
 if ( s(0) NE 0 ) and not(keyword_set(silent)) then begin
      message, 'Argument must be a scalarÊÑ using first element ', /info
      svalue = svalue(0)
 endif
 Ttype = 7          ; default Type is string
If Keyword_set(In_Type) then $
     if in_type LT 1 or (in_Type GT 7 and In_Type NE 14) then in_type =0 ; unset forced type option


;	trap value as a string if may be a date/time expression
 if (strpos(svalue,':') GE 0) or (strpos(svalue,'T') GE 0) then goto, CONVERT
 if strpos((no_white=strcompress(svalue,/remove_all)),'-') GT 1 then begin
   if strpos(no_white,'e') EQ -1 and strpos(no_white,'E') EQ -1 $
   then goto, CONVERT
 endif
;	trap value as a string if it looks like a time with a reset number
 if (strpos(svalue,'/') GE 0) then goto, CONVERT


 l = strlen(svalue)
 temp = svalue

; on_ioerror, CONVERT		; jump to CASE if type conversion fails


; original regex, found on a web site Ñ does not allow . with no decimals
;NumEx = '^[-\+]?[0-9]*(\.)?[0-9]+([eE][-\+]?[0-9]+)?$'

; This one should match most integer/float notation
NumEx = '^[-\+]?([0-9]*(\.)?[0-9]+|[0-9]+(\.)?[0-9]*)([eEdD][-\+]?[0-9]+)?$'


If keyword_set(extract) then $
 NumEx = '[-\+]?([0-9]*(\.)?[0-9]+|[0-9]+(\.)?[0-9]*)([eEdD][-\+]?[0-9]+)?'



; ÑÑÑÑ Complex Types only ÑÑÑÑ

vect = strsplit(svalue, /ext, '(,)')         ; parse string
 if size(vect, /dim) EQ 2 then begin          ; assumed complex if 2 elt found
     Temp = stregex(vect(0), NumEx, /bool)
     If not(temp) then goto, CONVERT     ; does not include a number
     Temp = stregex(vect(1), NumEx, /bool)
     If not(temp) then goto, CONVERT     ; does not include a number
   temp = complex(vect(0),vect(1))
   Ttype=6
   goto, CONVERT
 endif


; ÑÑÑÑ Non-complex Types ÑÑÑÑ

Temp = stregex(svalue, NumEx, /bool)

If not(temp) then goto, CONVERT     ; does not include a number
svalue = StrUpCase(svalue)
If keyword_set(extract) then svalue=stregex(svalue, NumEx, /ext) ; keep only numerical substring


if stregex(svalue, '\.|E|D') NE -1 then begin      ; Identify floating values
;(strpos(svalue,'.') GT 0 OR strpos(StrLowCase(svalue),'e') GT 0) then begin ; a bit heavy...
   temp = double(svalue)     ; will return a string on conversion error
   Ttype = 4   
   vect = strsplit(svalue, /ext, '.')              ; parse string
   if total(strlen(vect)) GE 8 then Ttype = 5      ; double required
   if (strpos(svalue,'E') GT 0) then Ttype = 4      ; other float notations
   if (strpos(svalue,'D') GT 0) then Ttype = 5
endif else begin                                             ; Integer Types
 
   temp = long64(svalue)     ; convert to largest integer Type
                                              ; or return a string on conversion error
    atemp = abs(temp)

   if (atemp GT 2UL^31-1) then Ttype = 14 $
       else if (atemp GT 32767) then Ttype = 3  else Ttype = 2
;   if (temp GE 0) and (temp LE 255) then Ttype = 1      ; intentionally commented out, see header
;   if (temp GE 0) and (temp GT 2UL^32-1) then Ttype = 15 
; (the above line does not work: convertion is already performed)

   if (strlen(svalue) GE 19) then Ttype = 5         ; double float required
 endelse

; on_ioerror, NULL

 CONVERT:
; force output type only if convertible 
If Ttype NE 7 and Keyword_set(In_Type) then Ttype = In_Type 
	CASE Ttype OF
;                15 : value=Ulong64(temp)
                14 : value=long64(temp)
                7 : value=Ivalue
                6 : value=temp
                5 : value=double(svalue)
                4 : value=float(svalue)
                3 : value=long(temp)
                2 : value=fix(temp)
                1 : value=byte(temp)
	  else: if NOT keyword_set(silent) then message,'No corresponding type'
	ENDCASE

 FIN:
 Type = Ttype
 return,value
 end

