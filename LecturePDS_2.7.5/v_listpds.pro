Function V_ListPDS, Dimen0, COUNT=count, SILENT = silent

;+ $Id: v_listpds.pro,v 1.6 2007/12/05 17:08:14 erard Exp $
;
; NAME:
;	V_ListPDS
;
; PURPOSE:
;	Extract values from a list in a PDS label, and return them in an array
;
; CALLING SEQUENCE:
;	result = V_ListPDS(DIMEN)
;
; INPUTS:
;	Dimen =  Value found in PDS label for keywords such as CORE_ITEMS
;	   Should look like '(n1,n2,n3,...)' or '{n1,n2,n3,...}'
;       Normally an output of v_pdspar routine. Unchanged on output
;
; OUTPUTS:
;	result = A N-element integer vector with values in order of apparition.
;               Returns -1 (scalar) if Dimen is not correctly formatted.
;               Values are converted to digits if possible.
;
; OPTIONAL OUTPUTS:
;	COUNT - Optional keyword to return the number of values found
;               in the string. Equals -1 if Dimen is not correctly formatted.
;               (no longer used)
;
; WARNING:
;	Print a message if the list is uncomplete, ie does not end with a ')'
;          This may means that the list of values written on several lines, and
;          should be provided completely (or that the list is followed by a unit).
;
;	SILENT - Disable warning messages
;
; EXAMPLES:
;	To extract axes names of a Qube (values from AXIS_NAME list):
;
;	IDL> Nax = v_listpds(v_pdspar(h, 'AXIS_NAME'))
;
; MODIFICATION HISTORY:
;	Written: Stephane Erard, IAS, Sept. 2000
;          Updated, SE, Nov 2000 :
;               - Always returns a vector of integers if values are bytes
;          Updated, SE, LESIA, June 2005 :
;               - Returns input argument if not a list, but maintains error code
;          Updated, SE, LESIA, Nov 2007 :
;               - Now supports PDS lists in round brackets (not ordered), mainly
;                 to process SOFTWARE_VERSION_ID
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
;--------------------------------------------------------------------

      Dimen=strcompress(Dimen0, /remove)
      debut=strmid(dimen,0,1)
      length = strlen(dimen)-1
      fin=strmid(dimen,length,1)
      if debut EQ '{' then begin     ; process round brackets
          StrPut, dimen, '(', 0
          Pos = StrPos(dimen, '}', 0)
          StrPut, dimen, ')', Pos
          debut=strmid(dimen,0,1)
          fin=strmid(dimen,length,1)
      endif


      if debut NE '(' then goto, perdu
      if fin NE ')' then begin
          length = length +1
          pb =1
          if NOT keyword_set(silent) then message, $
             'WARNING - Uncomplete list of values ('+dimen+')', /INF
      endif
      dimen = strmid(dimen,1,length-1)

      if (!version.release GE 5.3) then begin
          Dim = strsplit(dimen, ',', /extract)
          count = (size(dim))(1)
      endif else begin

      Dim=strarr(100)
      count = 0
      while length GT 0 do begin
        count= count+1
        rightp = strpos(dimen,',')
        if rightp EQ -1 then rightp = strlen(dimen)
        Dim(count-1) = strmid(dimen,0,rightp)
        length = strlen(dimen) - rightp
        dimen = strmid(dimen,rightp+1,length)
      endwhile
     Dim = Dim(0:count-1)

    endelse

     a = v_str2num(Dim(0), type=type)
     if type  EQ 1 then type = 2
     Dim0 = Make_array(count, type=type)
     For i=0, count-1 do Dim0(i) = v_str2num(Dim(i))
     return, Dim0

perdu: 
;          Dim0 = [-1]     ; returns nothing if arg is not a list
;          count = -1
          !ERR = -1
          Dim0 = Dimen0
          count = 1
         if NOT keyword_set(silent) then message, $
             'WARNING - Value  ('+dimen+') is not a list', /INF
          return, Dim0

END
