function V_POINTPDS, pointer, record_bytes, SILENT = silent
;+
; NAME:
;	V_POINTPDS
; PURPOSE:
;	Parse data object pointer for reading
;
; CALLING SEQUENCE:
;	Result= V_POINTPDS(pointer, record_bytes [,/SILENT] )
;
; INPUTS:
;	Pointer = PDS Pointer to object (value of line e.g.,  ^IMAGE). Can be a vector
;	RECORD_BYTES = Bytes per record, from PDS label. Scalar
;
; OUTPUTS:
;	Result = Structure with fields 
;               .file = filename (string)
;               .offset = offset in file, in bytes (integer)
;           Result is a vector if Pointer was a vector.
;
; OPTIONAL KEYWORDS:
;	SILENT - suppresess console messages
;
; EXAMPLE:
;                   pointer = v_pdspar(label,'^IMAGE')
;                   record_bytes = long(v_pdspar(label,'RECORD_BYTES'))
;                   PtObj =  V_POINTPDS(pointer,record_bytes)
;
; MODIFICATION HISTORY:
;       Written: Stephane Erard, LESIA, Oct 2005
;          Extracted from v_imagepds for easier maintenance
;          (that was a modified version of SBNIDL imagepds.pro version 2.0, July 1999)
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
;==================================================================
 
  On_error,2                    ;2 =Return to user    0= debug

      ; PDS file pointers may follow any of these formats:
      ;
      ;   ^IMAGE = ("file.img", 320 <BYTES>)        Offset in bytes
      ;   ^IMAGE = ("file.img", 3)                   Offset in records
      ;   ^IMAGE = "file.img"                            No offset
      ;   ^IMAGE = 3000 <BYTES>                    Offset in bytes, attached
      ;   ^IMAGE = 5                                Offset in records, attached
      ;
      ; N.B.: PDS offsets are 1-based (i.e., the first record in the file is
      ; record 1, not record 0)

Npt = (size(pointer, /Dim))(0)
If size(pointer, /N_Dim) EQ 0 then Npt =1
result = {pointeur, filename:' ', offset:0L}	
if Npt GT 0 then result = replicate(result, Npt)


For ii = 0, Npt-1 do begin

      point = strtrim(pointer(ii))      ; Copy the string with spaces removed
      skip = 0L                           ; Byte offset to the beginning of the IMAGE
      byte_offset_flag = 0L        ; >0 if the offset is given in bytes

      ; Remove any parentheses from the string:
      rightp = strpos(point,'(') + 1
      leftp  = strpos(point,')')
      if rightp GT -1 AND leftp GT -1 then begin
        length = leftp - rightp
        point  = strmid(point,rightp,length)
      endif

      ; Now check for a byte offset flag ("<BYTES>"), remove it if found and
      ; set our own logical flag accordingly:
      rightp = strpos(point,'<BYTES>')
      if rightp GT -1 then begin
        byte_offset_flag = 1
        point  = strtrim(strmid(point,0,rightp))    ; Also trim blanks
      endif 

      ; If there are double quotes in the remainder of the string, there should
      ; be two of them and they surround the file name, which we extract:
      rightp = strpos(point,'"')
      if rightp GT -1 then begin
        leftp = strpos(point,'"',rightp+1)
      endif else begin
        leftp = -1
      endelse

      ; ...If there was a filename, save it:
      datafile_found = 0
      datafile = ''
      if rightp GT -1  AND  leftp GT -1  then begin
        length   = leftp - rightp - 1
        datafile = strmid(point,rightp+1,length)
        datafile_found = 1

        ; Now remove the file name from the pointer string:
        length = strlen(point) - leftp
        point  = strmid(point,leftp+1,length)

      endif else if (rightp GT -1  AND  leftp EQ -1) OR $
                    (rightp EQ -1  AND  leftp GT -1) then begin
        message, 'ERROR - Badly formatted file pointer: '+ pointer(ii)
      endif

      ; Remove anything remaining up to and including the possible comma, 
      ; trim blanks, and see what's left:

      rightp = strpos(point,',')+1;
      if rightp GT -1 then begin
        length = strlen(point)
        point  = strmid(point,rightp,length-rightp)
      endif
      point = strtrim(point)

      ; If we're left with a non-null string, try converting it to an integer.
      ; Otherwise, our offset is zero:
      if strlen(point) EQ 0 then skip = 0L else skip = long(v_str2num(point))

     ; Convert to offset in bytes
      if (byte_offset_flag EQ 0) and (skip NE 0) then skip = (skip - 1) * long(record_bytes)
      if (byte_offset_flag GT 0) and (skip NE 0) then skip = (skip - 1) 

      Result(ii).filename = datafile
      Result(ii).offset = skip

Endfor

Return, result

End
