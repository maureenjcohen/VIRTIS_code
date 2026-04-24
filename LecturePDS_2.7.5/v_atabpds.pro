function V_ATABPDS, filename, label, object, SILENT = silent, C_name = columns


;+ $Id: v_atabpds.pro,v 1.8 2008/11/24 15:59:41 erard Exp $
;
; NAME:
;	V_ATABPDS  (Ascii-Table PDS)
;
; PURPOSE:
;	Reads a PDS Ascii table object into an IDL structure.
;                Reads a single table identified by pointer and label lines
;
; CALLING SEQUENCE:
;	Result = V_ATABPDS(Filename, Label, Object [,/SILENT] )
;
; INPUTS:
;	Filename = name of the file containing the PDS label 
;	     (if detached label, this is the label file)
;	Label = String array containing the PDS label itself (returned by v_headpds)
;           object = Object definition limits in label + data pointer (returned by v_objpds)
;
; OUTPUTS:
;	Result = Structure with fields:
;               .columnN = N vectors containing the PDS table (can be of various types)
;
; OPTIONAL KEYWORDS:
;	C_name: returns column names in a vector 
;	SILENT - suppresess console messages
;
; EXAMPLE:
;	Read a single Ascii table, the i-th object in the label, in a variable:
;
;               Obj_def =  V_OBJPDS(label, /all)
;               Obj_num = (size(obj_def, /dim))(0)      ; number of objects found
;               data = V_ATABPDS(filename, label, Obj_def(i), SILENT = silent)
;
;
; COMMENTS:
;       Requires correct label formatting (ROW_BYTES must include line terminator, CR-LF)
;          + correct data types in the label (!)
;       Does not require the last data record to be completed.
;       Does not require column names.
;       Does not support external format definition (^Structure ).
;       I/O format is different from the original SBNIDL routine tascpds.pro
;               Result is still a structure to handle tables containing different variable types
;       STREAM mode: each line is a record in this case (variable length)
;
; MODIFICATION HISTORY:
;       Stephane Erard, LESIA, Feb 2006 Written
;	     Remotely derived from v_tascpds, but still partly adapted from SBNIDL 2.0
;               Read any table in file, given pointer to the object
;       SE, April 06: Changed loop variable to long (for new Magellan topo)
;       Stephane Erard, LESIA, Feb 2007
;	          Changed handling of detached labels. 
;       SE, July 07:  Fixed case where table name is provided also
;       SE, July 08:  Handle case where RECORD_BYTES is not provided 
;                     (only occurs with ascii tables in stream mode [?])
;       SE, Oct 08:  Refined data type identification (first remove spaces and quotes)
;                    No longer stops here with the PDS spectral library
;       SE, Nov 08:  Replaced assoc by readu for compatibility with GDL
;                    Implemented support for files in stream mode (variable line length)
;                    Intended to read the PDS MRO spectral library 
;                      (some files have incorrect data type in their label, though)
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


  On_error,2                    ;2, Return to user   0: debug

; ------- Check for filename input

 if N_params() LT 3 then begin		
    print,'Syntax - result = ATABPDS( filename, lbl, Object [,/SILENT])'
    return, -1
 endif

 silent = keyword_set( SILENT )
 fname = filename 

; object definition area in label
lbl_obj = label(object.start:object.stop)
     
; ------- To do: Check type of arguments


; ------- Determine type of data in file

; get exact type in objpoint
 objpoint = Object.type
 
; check formatting
 inform = v_pdspar( lbl_obj, 'INTERCHANGE_FORMAT' )     
 if !ERR EQ -1 then begin
   message,'ERROR - '+fname+': missing required INTERCHANGE_FORMAT keyword'
 endif else begin
   inform = inform(0)
   infst =  strpos(inform,'"')     ; remove '"'s from inform 
   if infst GT -1 then $
        inform = strmid(inform,infst+1,strpos(inform,'"',infst+1)-infst-1)
;   spot = strpos(inform,10b)     ;remove line feeds from names
;   if spot GT 0 then inform=strtrim(strmid(inform,0,spot-1),2)
   if inform EQ 'BINARY' then message, $
        'ERROR- '+fname+' is a BINARY table file; try V_BTABPDS.'
 endelse
 record_bytes = v_pdspar(label,'RECORD_BYTES')	
; if !ERR EQ -1 then message, $
;        'ERROR - '+fname+' missing required RECORD_BYTES keyword'
 if !ERR EQ -1 then record_bytes= 1     ; default (should not be used...)


; get column format
; (should also check that all columns are properly documented)
; (+ stop if Container objects present- do this in v_readpds) 

; Struct = v_pdspar(lbl_obj,'CONTAINER')
; if !ERR NE -1 then begin
;     message, 'Container objects not implemented', /cont
;     !ERR = -1
;     return, 0
; endif

 columns = v_pdspar( lbl_obj,'COLUMNS', count=NcTot)
 if !ERR EQ -1 then begin
   message,'ERROR - '+fname+': missing required COLUMNS keyword'
 endif else columns = columns(0)
 data_type = v_pdspar( lbl_obj,'DATA_TYPE',COUNT= dcount,INDEX=typ_ind)
 if !ERR EQ -1 then message, $
       'ERROR - '+fname+' missing required DATA_TYPE keywords'
 length = fix(v_pdspar( lbl_obj,'BYTES',COUNT=bcount,INDEX=len_ind))
 if !ERR EQ -1 then message, $
       'ERROR - '+fname+' missing required BYTES keywords' 
 start = v_pdspar( lbl_obj,'START_BYTE',COUNT=cols,INDEX=st_ind) - 1
 if !ERR EQ -1 then message, $
       'ERROR - '+fname+' missing required START_BYTE keywords' 
 name = v_pdspar( lbl_obj,'NAME',INDEX=nam_ind, count=NcNam)
 if !ERR EQ -1 then begin 
     if not silent then message,'WARNING - '+fname+' missing required NAME keywords', /cont
     name = 'column'+indgen(cols+1)
 endif
cols = cols(0)


; Check for stream mode files
Stream = 0
IF (strupcase(v_pdspar(label, 'RECORD_TYPE')) EQ 'STREAM') then stream = 1


; Remove table name from column names if present
 ;if nam_ind(0) LT obj_ind(1) then begin
 ;   name = name(1:cols)
 ;   nam_ind = nam_ind(1:cols)
 ;endif
; columns = strarr(cols+1)
; columns(0) = 'columns'
 columns = strarr(cols)

; Trim extraneous characters from column names and data_types
 for j = 0,NcNam-1 do begin
   nmst =  strpos(name(j),'"')+1                ; remove '"'s from names
   if nmst GT 0 then $
      name(j)=strmid(name(j),nmst,strpos(name(j),'"',nmst)-nmst)
   nmst =  strpos(name(j),"'")+1                ; remove "'"s from names
   if nmst GT 0 then $
      name(j)=strmid(name(j),nmst,strpos(name(j),"'",nmst)-nmst)   
   nmpar = strpos(name(j),'(')                  ; remove '()'s from names
   if nmpar GT 0 then name(j)= strmid(name(j),0,nmpar) 
   nmst = strpos(name(j),10b) 			; remove end-of-line controls
   if nmst LT 0 then nmst = strpos(name(j),13b) 
   if nmst GT 0 then name(j) = strmid(name(j),0,nmst-1)
 endfor

 for j = 0,NcTot-1 do begin
   dtst =  strpos(data_type(j),'"')+1   	; remove '"'s from data types
   if dtst GT 0 then $
   data_type(j) = strmid(data_type(j),dtst,strpos(data_type(j),'"',dtst)-dtst)
   dtst =  strpos(data_type(j),"'")+1   	; remove "'"s from data types
   if dtst GT 0 then $
   data_type(j) = strmid(data_type(j),dtst,strpos(data_type(j),"'",dtst)-dtst)
   dtst = strpos(data_type(j),10b) 		; remove end-of-line controls
   if dtst LT 0 then dtst = strpos(data_type(j),13b) 
   if dtst GT 0 then data_type(j) = strmid(data_type(j),0,dtst-1) 
   spot = strpos(data_type(j),'_')+1
   if spot GT 0 then $                	; remove prefixes from data types
        data_type(j)=strmid(data_type(j),spot,strlen(data_type(j))-spot+1)
 endfor
 name = strtrim(name,2)
 data_type = strtrim(data_type,2)
 columns = name(0:cols-1)

 X = v_pdspar( lbl_obj,'ROW_BYTES')
 Y = v_pdspar( lbl_obj,'ROWS') 
 X = long(X(0))
 Y = long(Y(0))


; ------ Read pointer to find location of the table data  

; Inform user of program status if /SILENT not set
 if not (SILENT) then begin 
    st = (cols*Y)       
    text = strtrim(string(cols),2)+' Columns and '+strtrim(string(Y),2)+' Rows'
    if (st GT 0) then message,'Now reading table with '+text,/INFORM else $
    	message,fname+" has ROWS or COLUMNS = 0, no data read"
 endif

; parse pointer to data object
PtObj =  V_POINTPDS(object.pointer,record_bytes)
skip = PtObj.offset    ; offset in bytes
datafile_found = (PtObj.filename NE '')
if datafile_found NE 0 then begin     ; if detached label, look for file location

   fname = file_search(PtObj.filename, /fold)        ; works from IDL 5.5 and up
   temp = file_info(fname)
; If not found in current directory, try in label directory
  if not(temp.exists) then begin
     DirName = v_getpath(filename, FBname)     ; get path to label under IDL ≥ 5.4
     fname = file_search(Dirname+PtObj.filename, /fold)
     temp = file_info(fname)
  endif
  if not(temp.exists) then  message, 'ERROR - Could not re-open '+ PtObj.filename
endif


; ----- Read data into a 1-dimensional byte array and check for
;  proper end-of-line characters and X dimension

 openr, unit, fname, ERROR = err, /GET_LUN
 if err LT 0 then message,'Error opening file ' + ' ' + fname
 filestat=fstat(unit)
; XY = filestat.size - skip                     ; includes EOL
 XY = X*Y                         ; works if other objects present after this


if STREAM then begin     ; files in stream mode, pointers are given as line numbers
 if skip NE 0 then begin
  bidon = strarr(skip)
  readf, unit, bidon
 endif
 table = strarr(Y)
 readf, unit, table
 free_lun, unit

endif else begin

; file = assoc(unit,bytarr(XY,/NOZERO),skip)
;  avoids assoc procedure for GDL
 bidon = bytarr(skip,/NOZERO)  ; skips header + previous objects
 readu, unit,bidon
 filedata = file(0)
 filedata = bytarr(XY,/NOZERO) ; ascii table
 readu, unit,filedata
 free_lun, unit
 cr=where(filedata eq 13b,ctcr)
 lf=where(filedata eq 10b,ctlf)
  X1 = XY / Y
  if XY mod Y NE 0 then message, 'Something wrong with dimensions'
  filedata=reform(filedata,X1,Y)
  table = string(filedata)

endelse

; remove EOL
  for i = 0L, Y-1 do begin
     if strmid(table(i), strlen(table(i))-2,2) EQ string([13b,10b]) then $
          table(i) = strmid(table(i), 0, strlen(table(i))-2)
     if strmid(table(i), strlen(table(i))-1,1) EQ string([10b]) then $
          table(i) = strmid(table(i), 0, strlen(table(i))-1)
     if strmid(table(i), strlen(table(i))-1,1) EQ string([13b]) then $
          table(i) = strmid(table(i), 0, strlen(table(i))-1)
 endfor


; ------ format data array and convert string array

; Convert string array into structure of appropriate column vectors
; Cname = CREATE_STRUCT('column_names',columns)
 Nnam = N_elements(nam_ind)
 ; skip table name if present
 If Nnam GT N_elements(st_ind) then begin
     nam_ind = nam_ind(1:Nnam-1)
     columns = name(1:cols)
 endif
 for k=0,cols-1 do begin
    column = 'column'+strtrim(string(k+1),2)
    if k LT cols-1 then begin
        st = where(st_ind GT nam_ind(k) AND st_ind LT nam_ind(k+1))
        d = where(typ_ind GT nam_ind(k) AND typ_ind LT nam_ind(k+1)) 
        l = where(len_ind GT nam_ind(k) AND len_ind LT nam_ind(k+1)) 
    endif else begin
        st = where(st_ind GT nam_ind(k))
        d = where(typ_ind GT nam_ind(k))
        l = where(len_ind GT nam_ind(k)) 
    endelse
    strt = start(st)
    bytes = length(l)
    vect = strmid(table,strt(0),bytes(0))
    type = data_type(d)
; cannot use v_typepds, encoding is unknown

; First remove quotes if any     ; Oct 2008 @SEmodif
     type(0) = strtrim(type(0), 2)     ; remove ending spaces
  if strmid(type(0),0,1) EQ '"' then type(0) = strmid(type(0),1, strlen(type(0))-1)
  if strmid(type(0),strlen(type(0))-1,1) EQ '"' then type(0) = strmid(type(0),0, strlen(type(0))-1)

    if strmid(type(0),0,5) eq 'ASCII' then $
      type(0)=strmid(type(0),6,strlen(type(0))-6) 

    If k EQ 0 then begin
    CASE type(0) OF
           'INTEGER': data = CREATE_STRUCT(column,long(vect)) 
           'UNSIGNED_INTEGER': data = CREATE_STRUCT(column,long(vect)) 
           'REAL': data = CREATE_STRUCT(column,float(vect)) 
           'FLOAT': data = CREATE_STRUCT(column,float(vect)) 
           'CHARACTER': data = CREATE_STRUCT(column,vect) 
           'DOUBLE': data = CREATE_STRUCT(column,double(vect)) 
           'BYTE': data = CREATE_STRUCT(column,fix(vect)) 
           'BOOLEAN': data = CREATE_STRUCT(column,fix(vect)) 
           'TIME': data = CREATE_STRUCT(column,vect) 
           'DATE': data = CREATE_STRUCT(column,vect) 
           else: message, type(0)+' not a recognized PDS data type!'
    ENDCASE
    endif else begin
    CASE type(0) OF
           'INTEGER': data = CREATE_STRUCT(data,column,long(vect)) 
           'UNSIGNED_INTEGER': data = CREATE_STRUCT(data,column,long(vect)) 
           'REAL': data = CREATE_STRUCT(data,column,float(vect)) 
           'FLOAT': data = CREATE_STRUCT(data,column,float(vect)) 
           'CHARACTER': data = CREATE_STRUCT(data,column,vect) 
           'DOUBLE': data = CREATE_STRUCT(data,column,double(vect)) 
           'BYTE': data = CREATE_STRUCT(data,column,fix(vect)) 
           'BOOLEAN': data = CREATE_STRUCT(data,column,fix(vect)) 
           'TIME': data = CREATE_STRUCT(data,column,vect) 
           'DATE': data = CREATE_STRUCT(data,column,vect) 
           else: message, type(0)+' not a recognized PDS data type!'
    ENDCASE
    endelse

    vect = 0

 endfor

 if not (SILENT) then help, /STRUCTURE, data

; Return table structure
return, data

end 
