function V_PDSPAR, label, name, abort, MVAL=mvalue, COUNT=matches, INDEX = nfound, $
     NAMESPACE = namespace, NONUMERIC = Nonumeric

;+ $Id: v_pdspar.pro,v 1.8 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;          V_PDSPAR
;
; PURPOSE:
;     Obtain the value associated to a keyword in a PDS label
;
; CALLING SEQUENCE:
;     result = V_PDSPAR( lbl, name,[ abort, MVAL=, COUNT=, INDEX =, NAMESPACE =])
;
; INPUTS:
;     Lbl =  PDS label array, (e.g. as returned by V_HEADPDS or V_READPDS)  
;          string array, each element has a maximum length of 80 characters
;     Name = Keyword to look for (does not contain spaces).
;
;
; OUTPUTS:
;     Result = value of parameter in header. If parameter is double 
;          precision, float, long or string, the result is of that type. 
;
;
; KEYWORDS:
;     ABORT - string specifying that V_PDSPAR should do a RETALL
;          if a parameter is not found.  ABORT should contain
;          a string to be printed if the keyword parameter is not found.
;          If not supplied V_PDSPAR will return with a negative
;          !err if a keyword is not found.
;
;     COUNT - Optional keyword to return the number of times the keyword is
;          found in the label - integer scalar
;
;     MVAL - Optional keyword to return the value of requested keyword 
;          that exceeds the normal allowable string size that can be 
;          printed by the PRINT function. The 'zeroth' record of MVAL-
;          MVAL(*,0) contains the number of following records that 
;          contain meaningful information.
;
;     INDEX - Optional keyword to return an array of the line numbers 
;          where the keyword was found in the PDS label.
;
;     NAMESPACE - Namespaces are prefices ending in ":" that introduce 
;           instrument-specific keywords (e.g., ROSETTA:). 
;           Normally, the search does not include the namespace (i.e., it is 
;           filtered from both the search string 'name' and the label 'lbl').
;           When this option is set, the match must include the possible 
;           namespace.
;
;     NONUMERIC - If set, returns string as is, does not extract numerical value.
;            Mostly useful to preserve units after values (default is to return the 
;            first numerical value found in string).
;
;
; SIDE EFFECTS:
;          !err is set to -1 if parameter not found.
;
;
; EXAMPLES:
;          Given a PDS header, h, return the values of the axis dimension 
;          values. Then return the number of sample bits per pixel.
;
;     IDL> x_axis = v_pdspar( h ,' LINES')         ; Extract Xaxis dimension
;     IDL> y_axis = v_pdspar( h ,' LINE_SAMPLES')  ; Extract Yaxis dimension
;     IDL> bitpix = v_pdspar( h ,' SAMPLE_BITS')   ; Extract bits/pixel value 
;
; PROCEDURE:
;     First removes blank lines and comments from label.
;     Each element of lbl is searched for a ' = ' or a '=' and the part of each 
;     that preceeds the ' = ' is saved in the variable 'keyword', with 
;     any line that contains no ' = ' also saved in keyword. 
;     Namespaces are filtered from both 'Name' and 'keyword'.
;     Spaces are removed.
;     'keyword' is then searched for elements that exactly match 'Name'. 
;     If search succeeds then returns following characters and possibly 
;     next lines, if they do not contain a keyword. An error occurs if search fails.
;     String values are converted to numeric values, if possible, 
;     by the V_STR2NUM function (if /NONUMERIC not set)
;
;    
; NOTE:
;     Original PDSPAR requires that the label being searched has records of
;     standard 80 byte length. - This doesn't seem true, fortunately (SE 2000)
;
; MODIFICATION HISTORY:
;     Adapted by John D. Koch from SXPAR by DMS, July, 1994 
;     Modified for VIRTIS, Stephane Erard, IAS, Oct. 1999
;     Updated from SBNIDL 2.0, Stephane Erard, Sept. 2000
;        Removed search of partial match in keywords, ie 'name'
;        should be an exact match of keyword (mandatory: many
;        PDS keywords are parts of other keywords).
;     SE, Oct 2003: handles multiline lists and comments on keyword lines
;        Now merges lists of values written on several lines in label.
;        Now filters comments after values
;     SE, Sept 2004: Handles keyword/value separator non conformity 
;          (some VIRTIS-VEX M ground calibrations files)
;        Now search for ' = ' then for '=' if no occurrence found. This can 
;        be an issue whenever '=' appears in a comment line (TBC)
;     SE, June 2005: Handles namespaces in keywords
;        Now removes namespace from both search string and label, except if 
;        NAMESPACE=1 (both namespace and keyword should match).
;     SE, LESIA, June 2005. Various changes:
;        Removes all internal spaces from keywords/label
;        Returns scalar if only one value
;        Fixed numerical conversion issues - now returns numbers whenever possible
;     SE, LESIA, Dec 2005: Improvement of multiline values parsing (2nd try)
;        Always merges successive lines that contain only values
;          - output index still points on the original label (but mval is probably wrong) 
;             + Parses values starting with an empty line
;             + Filters all comments
;        No longer check list delimiters (returns all kinds of values/list, including matrices)
;        Now returns END line number (checks it is actually present)
;        Now returns empty string (rather than 0) if keyword not present (to be checked !!!)
;        Added keyword Nonumeric (to preserve units if present)
;     SE, LESIA, Jan 2006: Small fix for labels with non standard separators 
;        (didn't get the right END line number, crashed on previous keyword)
;     SE, LESIA, Feb 2006: fix to return end_object lines when no value is associated
;        (to be watched...)
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
;----------------------------------------------------------------------

 params = N_params()
 if params LT 2 then begin
     print,'Syntax - result = v_pdspar(lbl,name [,abort,MVAL=,COUNT=,INDEX=,NAMESPACE = ])'
     return, -1
 endif 

 value = 0
 if params LE 2 then begin
      abort_return = 0
      abort = 'PDS Label'
 endif else abort_return = 1
if abort_return then On_error,1 else On_error,2     ; return


;       Check for valid header + remove unused lines

  lbl = label
  s = size(lbl)
  if ( s(0) NE 1 ) or ( s(2) NE 7 ) then $
        message,abort+' (first parameter) must be a string array'

; removes empty line (begins with spaces + 10b)
;   + comment line (begins with spaces + '/*') — SE, Dec 2005
; (mandatory to parse values starting with an empty line)
temp = where(strmid(strtrim(lbl,1), 0, 1) EQ string(10b) $
     or strmid(strtrim(lbl,1), 0, 2) EQ '/*', comp=indiceO)
lbl = lbl(indiceO)


;       Prepare keyword

  nam = strcompress(strupcase(name),/rem)  ;Copy name, make upper case, no space
  temp = (strsplit(nam, ':', /extract))
  if size(temp, /dim) GT 1 and NOT(keyword_set(namespace)) then nam = temp(1)


;     Loop on lines of the header 

 Sep = ' = '
 key_end = strpos(lbl,Sep)			;find ' = ' in all lines of lbl
 r = size(key_end)
 stopper = r(r(r(0)-1))
 keyword = strarr(stopper)

 for j = 0,stopper-2 do begin 
;    if key_end(j) LT 0 then keyword(j) = '*' $ 
;       else keyword(j)=strcompress(strmid(lbl(j),0,key_end(j)),/rem)
    if key_end(j) LT 0 then begin 
          keyword(j) = '*'                                                                 ; FIX for end_object, SE Feb2006
          if strcompress(strmid(lbl(j),0,strlen(lbl(j))-1),/rem) EQ 'END_OBJECT' then $
               keyword(j) = 'END_OBJECT'
       endif else keyword(j)=strcompress(strmid(lbl(j),0,key_end(j)),/rem)
   if NOT(keyword_set(namespace)) then begin
     temp = (strsplit(keyword(j), ':', /extract))
     if size(temp, /dim) GT 1 then keyword(j) = temp(1)
   endif
 endfor
keyword(stopper-1) =' '      ; END, last line
nfound = where(keyword EQ nam, matches)

if nam EQ "END" then begin     ; special processing for END tag
  temp = strtrim(lbl(stopper-1),2)
 if strmid(temp,0, strlen(temp)-1) EQ "END" then begin
  matches = 1
  nfound = indiceO(stopper -1)
 endif else begin
  matches = 0
  nfound = -1
 endelse
  return,''
endif

 if matches EQ 0 then begin          ;look for '=' if no ' = ' found
   Sep = '='
;  message,"Non-standard keyword/value separator, trying '='", /cont
   key_end = strpos(lbl,Sep)			;find '=' in all lines of lbl
   r = size(key_end)
   stopper = r(r(r(0)-1))
   keyword = strarr(stopper)
   for j = 0,stopper-1 do begin 
;    if key_end(j) LT 0 then keyword(j) = '*' $
;     else keyword(j)=strcompress(strmid(lbl(j),0,key_end(j)),/rem)
    if key_end(j) LT 0 then begin 
          keyword(j) = '*'                                                                  ; FIX for end_object, SE Feb2006
          if strcompress(strmid(lbl(j),0,strlen(lbl(j))-1),/rem) EQ 'END_OBJECT' then $
               keyword(j) = 'END_OBJECT'
       endif else keyword(j)=strcompress(strmid(lbl(j),0,key_end(j)),/rem)
     if NOT(keyword_set(namespace)) then begin
       temp = (strsplit(keyword(j), ':', /extract))
       if size(temp, /dim) GT 1 then keyword(j) = temp(1)
    endif
   endfor
   keyword(stopper-1) =' '      ; END, last line
   nfound = where(keyword EQ nam, matches)
 endif 
; removed for consistency, SE, 09/2000
; if matches EQ 0 then nfound = where(strpos(keyword,nam) GT -1,matches)


; Process string parameter and use V_STR2NUM to obtain numeric value

 if matches GT 0 then begin
    line = lbl(nfound)
    nfd = size(nfound)
    quitter = nfd(nfd(nfd(0)-1))
    svalue = strarr(quitter)
    mvalue = strarr(quitter,100)
    value = svalue
    lsep = strlen(Sep)
    i = 0

    while i LT quitter do begin      ; loops on occurrences of keyword
      n = nfound(i)
      knd = key_end(n)
      retrn = strpos(line(i),string(10b))
      if retrn EQ -1 then retrn = 80
      svalue(i) = strmid(line(i),knd+lsep,retrn-knd-lsep+1)
      svalue(i) = strmid(line(i),knd+lsep,retrn-knd-lsep)
;      spot = strpos(svalue(i),string(10b))
;      if spot GT 0 then svalue(i)=strmid(svalue(i),0,spot)      ; removes EOL on one byte
      spot = strpos(svalue(i),'/*')         ; removes comments in line, SE, Oct 2003
      if spot GT 0 then svalue(i)=strmid(svalue(i),0,spot)


; Process multiline lists, SE oct 2003 - Dec 2005
; if starts with an empty line
      j = 0
      if (strcompress(svalue(i), /rem)) EQ string(0b) then begin
          If  keyword(n+1) NE '*' then begin     ; no value present
            !ERR =-1
             return, value
          endif
       svalue(i) = lbl(n+1)          ; to next line
       spot = strpos(svalue(i),string(10b))
       if spot GT 0 then svalue(i)=strmid(svalue(i),0,spot)      ; removes EOL on one byte
       spot = strpos(svalue(i),'/*')         ; removes comments in line
       if spot GT 0 then svalue(i)=strmid(svalue(i),0,spot)        
       j = 1
      endif

; append following lines with no keyword
     j = j+1
     while (keyword(n+j) EQ '*') do begin
        nxtline = lbl(n+j)
               ; deletes final LF before merging
        svalue(i) = svalue(i) + strcompress(strmid(nxtline,0,strlen(nxtline)-1))
        j = j+1
     endwhile

; Process string values
      check = strpos(svalue(i),'"')
      if check GT -1 then begin      
         k = n
         c=strpos(svalue(i),'"',check+1)
         if c GT -1  then value(i)=strcompress(svalue(i),/rem) else begin
              for a = 0,key_end(n)+1  do value(i)=value(i)+' '
              value(i) = value(i) + svalue(i)
         endelse
         m = 0
         m2 = 0
         while c LT 0 do begin
            k = k+1
           m = m+1
           m2=fix(m/24)
           if m2 EQ 0 then value(i)=value(i) + ' ' + lbl(k) $
                else if m2 GT 0 then mvalue(i,m2)=mvalue(i,m2)+' '+lbl(k) $
                else print,'Illegal value of variable m2 ='+m2            
           c = strpos(lbl(k),'"')
;         if (c GT -1) then if(keyword(k+1) EQ '*') then c = -1 
         endwhile 
         mvalue(i,0)=fix(m2(0))
      endif else $
          If not(keyword_set(Nonumeric)) then $
          svalue(i) = strcompress(svalue(i),/rem)
      i = i + 1
    endwhile

    temp = v_str2num(svalue(0), type= stype)     ; use first element's type 
    value = Make_array(quitter,Type = stype)
    If keyword_set(Nonumeric) then value = svalue $
     else for i=0, quitter-1 do value(i) = v_str2num(svalue(i))
    if quitter EQ 1 then value = value(0)     ; scalar

; Return index to line numbers in input label
     nfound = indiceO(nfound)    

 endif else begin
   if abort_return then message,'Keyword '+nam+' not found in '+abort
   value = ''
   nfound = -1
   !ERR = -1
 endelse

;              Tout cela ne vaut pas le poison qui découle
;                       De tes yeux, de tes yeux verts,
;              Lacs où mon âme tremble et se voit à l'envers...
;                        Mes songes viennent en foule
;                  Pour se désaltérer à ces gouffres amers.

;     To print value and mvalue after running pdspar use:
;           print,value(*)
;           for d = 1,mvalue(*,0) do print,mvalue(*,d)  
;          where '*' is any number valid for value(*)  


return,value
END