function V_HEADPDS, filename,remain,SILENT=silent, external= external
;+
; NAME:
;	V_HEADPDS
;
; PURPOSE:
;	Read a PDS label into an array variable.
;
; CALLING SEQUENCE:
;	Result=V_HEADPDS (filename [,remain,/SILENT])
;
; INPUTS:
;	FILENAME = Scalar string containing the name of the PDS file  
;		to be read.
;
; OUTPUTS:
;	Result = PDS label array constructed from designated record.
;
; OPTIONAL INPUT KEYWORDS:
;
;     EXTERNAL - handles external files recursively in labels
;          (will not try to include them if set.
;          Otherwise, will look for ^STRUCTURE keywords)
;     SILENT - suppresses console messages
;     REMAIN - returns extra text after label, if any exists
;
; EXAMPLE:
;	Read a PDS file TEST.PDS into a PDS header array, lbl.
;		IDL> lbl = V_HEADPDS( 'TEST.PDS')
;
; PROCEDURES USED:
;	Functions:   V_PDSPAR
;
; MODIFICATION HISTORY:
;   headpds.pro:
;	Adapted by John D Koch,from READFITS by Wayne Landsman,August,1994
;    v_headpds.pro:
;  Adapted by Yann HELLO for DEC alpha platforms, february 97
;  Modified for VIRTIS, Stephane Erard, oct. 99
;     Updated from SBNIDL 2.0, Stephane Erard, sept. 2000
;          + Removes extra lines from label, checks label end
;  Updated, nov 2000 (SE):
;     - Read labels with CR only end of line correctly (VIMS)
;     Fixed identification of EOL markers, Nov 2000 (SE) 
;  Apr 2001 (SE): Can now read labels longer than 32767 characters
;  SE, Feb 2006. Updated:
;     - Soften file name search for Unix (plays with case)
;     - Added keyword External to include extra description provided 
;          through ^STRUCTURE (must be in same directory, which must be the current one)
;  FH, Feb 2008. Small change in error message to return name of missing file
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


  On_error,2                    ;2: Return to user    0: debug        

; Check for filename input

 params = N_params()

 if params(0) LT 1 then begin		
    print,'Syntax - result = HEADPDS( filename [,remain,/SILENT] )'
    return, -1
 endif
 if not keyword_set(external) then external = 0

     							
; Open file 
 
case !VERSION.ARCH of
'alpha': openr, unit,filename,ERROR=err,/GET_LUN, /compress
else:  openr, unit, filename, ERROR = err, /GET_LUN, /BLOCK, /compress
endcase


; Try and change case, works from IDL 5.5
 if err LT 0 then begin
     fname = filename
    filename = file_search(filename, /fold)
    case !VERSION.ARCH of
      'alpha': openr, unit,filename,ERROR=err,/GET_LUN, /compress
      else:  openr, unit, filename, ERROR = err, /GET_LUN, /BLOCK, /compress
    endcase
    if err LT 0 then message,'ERROR - '+fname+': Error opening file ' + ' ' + fname
;    free_lun,unit
 endif

 if not keyword_set(SILENT) and not external then print, 'Reading label ', filename


 status = fstat(unit)					
 pointlun = 0
 nbytes = 32000 < status.size 
 if (!VERSION.ARCH EQ 'alpha') then nbytes = 5000 < status.size
 morceau = status.size / 32001 +1

; Read PDS label information

a = assoc(unit,bytarr(nbytes))

Endline=string([13b,10b])     ; standard PDS eol marker
jump = 2
label1= '   '
Kt = 0
remain = ''
imorc = 0

While imorc LT morceau do begin
 if imorc NE morceau-1 or morceau EQ 1 then begin
     lbl = remain + string(a(imorc))      ; + ' ' + Endline
 endif else begin
       offs = (morceau-1)*32000L
       nbytes = status.size - offs
       b = assoc(unit,bytarr(nbytes),offs)
      lbl = remain + string(b(0))
 endelse
 lf = where(byte(lbl) EQ 13b,lines)
 if lines LE 0 then begin
    lf = where(byte(lbl) EQ 10b,lines)
    jump = 1
 endif else begin                    ; in case label lines end with CR only (VIMS)
    if strmid(lbl,lf(0)+1,1) NE string(10b) then jump = 1
 endelse
 if lf(0) EQ -1 then message, 'ERROR - '+filename+':This is not a readable PDS label'
 label = strarr(lines)
 k = 0
 label(k) = strmid(lbl,0,lf(k))+ string(10b)
 k=1
 r = k
 fin = 0
 while k LT lines do begin
    label(k)= strmid(lbl,lf(k-1)+jump,lf(k)-lf(k-1)-jump)+string(10b)
    eol = strpos(label(k),string(10b))
    if strtrim(strmid(label(k),0,eol),2) EQ 'END' then begin
          k = lines 
          fin =1
          imorc = morceau
    endif
    k = k+1
    r = r+1
 endwhile
label = label(0:r-1)     ; remove extra lines from label
if imorc LT morceau-1 then $
  remain = strmid(lbl,lf(k-1)+jump,strlen(lbl))

label1=[label1, label]
;print, label
;Kt = Kt + k
;if imorc NE morceau-1 or morceau EQ 1 then print, kT, label1(kt), remain
;print, imorc,  label(0)
imorc = imorc + 1
endwhile


label = label1(1:*)


;	Include external definition files

If External then begin
     goto, final
endif else begin
  struct = v_pdspar(label,'^STRUCTURE',count=Sc,INDEX=st_ind)
  If Sc GT 0 then begin
     Struct = strcompress(strupcase(Struct),/rem)  ; make upper case, no space
     For ii = Sc-1, 0, -1 do begin
       Sfile = (strsplit(Struct(ii), '"', /extract))(0)
       if not keyword_set(SILENT) then print, 'Reading external file:  ', Sfile
       temp = v_headpds(Sfile, /external)
       label = [label(0:st_ind(ii)), temp, label(st_ind(ii)+1:*)]
     endfor
  endif
endelse

if (fin eq 0) then message,  'WARNING -'+filename+': Incomplete label',/CONTINUE

;	Read object to determine type of data in file

 if not keyword_set(SILENT) then begin
    object = v_pdspar(label,'OBJECT')
    if !ERR EQ -1 then message, $
        'WARNING -'+filename+': Missing OBJECT keyword',/CONTINUE
 endif								

;	Read any text following the label, if asked for

 if params(0) GT 1 then begin
     rlines = lines-r-1
     if (rlines LE 0) then remain=' ' else begin 
      remain = strarr(rlines)
      i = 0
      while r LT lines-1 do begin
         remain(i) = strmid(lbl,lf(r-1)+jump,lf(r)-lf(r-1)-jump)+string(10b)
         r = r+1
         i = i+1
      endwhile
    endelse
endif


; Return the label and release the file unit

final:
 close, unit
 free_lun,unit
 return, label 


 end 
