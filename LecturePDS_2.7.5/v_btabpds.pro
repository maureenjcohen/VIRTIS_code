function V_BTABPDS, filename, label, Object, SILENT = silent, C_name = columns

;+ $Id: v_btabpds.pro,v 1.5 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;	V_BTABPDS   (binary-table PDS)

; PURPOSE:
;	Read a PDS binary table object into an IDL structure.
;                Reads a single table identified by pointer and label lines
;
; CALLING SEQUENCE:
;	Result = V_BTABPDS (Filename, Label, Object [,/SILENT] )
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
; OPTIONAL INPUT KEYWORDS:
;	C_name: returns column names in a vector 
;	SILENT - suppresess console messages
;
; EXAMPLE:
;	Read a single binary table, the i-th object in the label, in a variable:
;
;               Obj_def =  V_OBJPDS(label, /all)
;               Obj_num = (size(obj_def, /dim))(0)      ; number of objects found
;               data = V_BTABPDS(filename, label, Obj_def(i), SILENT = silent)
;
; COMMENTS:
;       Requires correct label formatting (ROW_BYTES is correct)
;       Does not require the last data record to be completed.
;       Does not require column names.
;       Does not support external format definition (^Structure ).
;       I/O format is different from the original SNBIDL routine tbinpds.pro
;               Result is still a structure to handle tables containing different variable types
;       Won't work with external column format (see below; fails with container objects...)
;
; modification history (v_tbinpds):
;	Adapted by John D. Koch from READFITS by Wayne Landsman,December,1994
;
;       10/6/99 M.Barker - Fixed bug that miscalculated offset.
;       10/15/99 M.Barker - Added support of scaling and offset factors.
;       Modified for VIRTIS, Stephane Erard, oct. 99
;       Stephane Erard, sept. 2000:     Updated from SBNIDL 2.0,
;               Fixed search for object pointer
;       Stephane Erard, LESIA, Dec 2005:
;          Fixed scaling process
;          Added search for INDEX_TABLE, std PDS object
;          Changed access to data object (offset...)
;          Changed type/endian conversion (more complete)
;       Stephane Erard, LESIA, Jan 2006:
;           Added support for DATA_TABLE + default names if column names not present
;
; MODIFICATION HISTORY (v_btabpds):
;       Stephane Erard, LESIA, Feb 2006
;	Derived from v_tbinpds with different I/O
;          Now read any table in file, given pointer to the object
;          Fixed structure length for I/O (solves rare EOF errors depending on dimensions)
;       Stephane Erard, LESIA, June 2006
;	Fixed column number...
;          Now performs IEEE float swapping (required to read floats on Intel)
;       Stephane Erard, LESIA, Jan 2007
;	Fixed interchange format handling
;       Stephane Erard, LESIA, Feb 2007
;	Changed handling of detached labels. Fixed byte conversions.
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


  On_error,2                   ;2, Return to user       
							
; ------- Check for filename input

 if N_params() LT 2 then begin		
    print,'Syntax - result = BTABPDS( filename, lbl, Object [,/SILENT])'
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
   infst =  strpos(inform,'"') 		; remove '"'s from inform 
   if infst GT -1 then $			
	inform = strmid(inform,infst+1,strpos(inform,'"',infst+1)-infst-1)
   if inform EQ "ASCII" then message, $
	'ERROR- '+fname+' is an ASCII table file; try ATABPDS.'
 endelse
 record_bytes = v_pdspar(label,'RECORD_BYTES')	
 if !ERR EQ -1 then message, $
        'ERROR - '+fname+' missing required RECORD_BYTES keyword'

 ; M.Barker 10/8/99:
 ; Look for scaling and offset factors.  These are not required, so if none
 ; found, then we must make sure future uses of !ERR are not confused.
 scale_flag=0
 offset_flag=0
 scale = v_pdspar(label,'SCALING_FACTOR',INDEX=sc_ind)
 if !ERR EQ -1 then !ERR = 0 else scale_flag=1
 offset = v_pdspar(label,'OFFSET',INDEX=off_ind)
 if !ERR EQ -1 then !ERR = 0 else offset_flag=1
 ;-------------------------------------

 ; get column format
; (should check that all columns are properly documented)
; (if not, should look for a ^structure pointer)
 Struct = v_pdspar(lbl_obj,'^STRUCTURE')
  Struct = strcompress(strupcase(Struct),/rem)  ; make upper case, no space
  Struct = (strsplit(Struct, '"', /extract))(0)
;  if not silent then print, 'Reading external file', struct
 if !ERR NE -1 then begin
     message, 'External table format not implemented', /cont
     !ERR = -1
     return, 0
;     temp = v_headpds(Struct)     ; just a try - won't work with CONTAINER
;     lbl_obj = [lbl_obj, temp]
 endif
; columns = v_pdspar(lbl_obj,'COLUMNS')
 columns = v_pdspar(lbl_obj,'COLUMNS',COUNT=cols)
 if !ERR EQ -1 then begin
   message,'ERROR - '+fname+': missing required COLUMNS keyword'
 endif else columns = columns(0)
 data_type = v_pdspar(lbl_obj,'DATA_TYPE',COUNT= dcount,INDEX=typ_ind)
 if !ERR EQ -1 then message, $
       'ERROR - '+fname+' missing required DATA_TYPE keywords'
 length = v_pdspar(lbl_obj,'BYTES',COUNT=bcount,INDEX=len_ind)
 if !ERR EQ -1 then message, $
       'ERROR - '+fname+' missing required BYTES keywords' 
; col_start = v_pdspar(lbl_obj,'START_BYTE',COUNT=cols,INDEX=st_ind) - 1
 col_start = v_pdspar(lbl_obj,'START_BYTE',INDEX=st_ind) - 1
 if !ERR EQ -1 then message, $
       'ERROR - '+fname+' missing required START_BYTE keywords' 
  name = v_pdspar(lbl_obj,'NAME',INDEX=nam_ind)


 if !ERR EQ -1 then begin 
     if not silent then message,'WARNING - '+fname+' missing required NAME keywords', /cont
     name = 'column'+indgen(cols+1)
 endif
;cols = cols(0)
cols = columns

; 	Check to see if there may be an 'array-column' in the file

 arrays = 0
 items = v_pdspar(lbl_obj,'ITEMS',COUNT=arrays,INDEX=is_ind)
 if !ERR GT -1 then begin
    item_bytes = v_pdspar(lbl_obj,'ITEM_BYTES',COUNT=iarrays,INDEX=ib_ind)
    if !ERR GT -1 then begin
       if iarrays NE arrays then message,$
 	'ERROR - '+fname+': ITEMS count and ITEM_BYTES count discrepancy'
       length = [temporary(length),item_bytes]
       len_ind = [temporary(len_ind),ib_ind]
    endif    
    if dcount(0) LT cols then begin  
    	item_type = v_pdspar(lbl_obj,'ITEM_TYPE',COUNT=iarrays,INDEX=it_ind)
        if !ERR EQ -1 then message,$
 	  'ERROR - '+fname+' missing required ITEM_TYPE keyword' else $
        if iarrays NE arrays then message,$
 	  'ERROR - '+fname+': ITEMS count and ITEM_TYPE count discrepancy' 
        data_type = [temporary(data_type),item_type]
        typ_ind = [temporary(typ_ind),it_ind]
    endif 
 endif 


; Remove table name from column names if present
 ;if nam_ind(0) LT obj_ind(1) then begin
 ;   name = name(1:cols)
 ;   nam_ind = nam_ind(1:cols)
 ;endif
; columns = strarr(cols+1)
; columns(0) = 'columns'
 columns = strarr(cols)

;       Trim extraneous characters from column names and data_types
 arch = strarr(cols)
 for j = 0,cols-1 do begin
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
   dtst =  strpos(data_type(j),'"')+1   ; remove '"'s from data types
   if dtst GT 0 then $
  data_type(j) = strmid(data_type(j),dtst,strpos(data_type(j),'"',dtst)-dtst)
   dtst =  strpos(data_type(j),"'")+1   ; remove "'"s from data types
   if dtst GT 0 then $
  data_type(j) = strmid(data_type(j),dtst,strpos(data_type(j),"'",dtst)-dtst)
   dtst = strpos(data_type(j),10b) 		; remove end-of-line controls
   if dtst LT 0 then dtst = strpos(data_type(j),13b) 
   if dtst GT 0 then data_type(j) = strmid(data_type(j),0,dtst-1) 
    spot = strpos(data_type(j),'_')+1
   if spot GT 0 then begin                 ; remove prefixes from data types
        arch(j)=strmid(data_type(j),0,spot(0)-1)  ; and store in 'arch'
        data_type(j)=strmid(data_type(j),spot,strlen(data_type(j))-spot+1)
   endif
 endfor
 name = strtrim(name,2)
 data_type = strtrim(data_type,2)
 columns = name

;	Read the table dimensions
 X = v_pdspar( label,'ROW_BYTES')
 Y = v_pdspar( label,'ROWS')
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

; old method
;if datafile_found NE 0 then begin     ; if detached label, look for file location
      ; works from 6.0 only
;;   dir = File_DirName(fname, /mark)     ; look in label directory if set 
;;   fname = dir + PtObj.filename
;   fname = PtObj.filename
;   temp = file_info(fname)
;; If the exact file name didn't work, try change case:
;  if not(temp.exists) then begin
       ; works from IDL 5.5 only
;  fname = file_search(fname, /fold)
       ; alternatively, look for lowcases only
;;     fname = dir + strlowcase(PtObj.filename)
;     temp = file_info(fname)
;  endif
;  if not(temp.exists) then  message, 'ERROR - Could not re-open '+fname
;endif

; ------ Read data into a byte array

 openr, unit, fname, ERROR = err, /GET_LUN
 if err LT 0 then message,'Error opening file ' + ' ' + fname
 file = assoc(unit,bytarr(X,Y,/NOZERO),skip, /packed)
 table = file(0)
 free_lun, unit


; -------Interpret correct values from byte array table

; data = CREATE_STRUCT('column_names',columns)
 for k=0,cols-1 do begin
    if k LT cols-1 then begin
        ;M.Barker 10/8/99, fixed SE 2005
        ;If scaling and/or offset factors are present:
        if scale_flag then sf = where(sc_ind GT nam_ind(k) AND sc_ind LT nam_ind(k+1))
        if offset_flag then off = where(off_ind GT nam_ind(k) AND off_ind LT nam_ind(k+1))
        ;----------------------------
        st = where(st_ind GT nam_ind(k) AND st_ind LT nam_ind(k+1))
        dt = where(typ_ind GT nam_ind(k) AND typ_ind LT nam_ind(k+1)) 
        l = where(len_ind GT nam_ind(k) AND len_ind LT nam_ind(k+1),bitenum) 
        if arrays(0) GT 0 then $
           it = where(is_ind GT nam_ind(k) AND is_ind LT nam_ind(k+1))         
    endif else begin
        ;M.Barker 10/8/99 This is for the last column:
        if scale_flag then sf = where(sc_ind GT nam_ind(k))
        if offset_flag then off = where(off_ind GT nam_ind(k))
        ;------------------------
        st = where(st_ind GT nam_ind(k))
        dt = where(typ_ind GT nam_ind(k))
        l = where(len_ind GT nam_ind(k),bitenum) 
        if arrays(0) GT 0 then $
          it = where(is_ind GT nam_ind(k))         
    endelse

    ;M.Barker 10/8/99, fixed SE 2005 
    if scale_flag then if  sf(0) NE -1 then sf = sf(0)
    if offset_flag then if off(0) NE -1 then  off = off(0)
    ;-------------------------
    st = st(0)
    dt = dt(0)
    elem = 1
    if arrays(0) GT 0 then if it(0) GT -1 then elem = fix(items(it(0)))

; If more than one 'l' find the one that is smallest

    least = l(0)
    for b = 0,bitenum-1 do $
       if v_str2num(length(l(b))) LT v_str2num(length(least)) then least = l(b)
    l = least(0)
    if st LT 0 OR dt LT 0 then message,$
        'ERROR - '+fname+': column parameters missing or out of order.'   
    column = 'column'+strtrim(string(k+1),2)

; Extract column values
    vect=v_btabvect(table,col_start(st),v_str2num(length(l)),data_type(dt),elem)

; Convert dimensions and type, swap if necessary, SE 2005
    vect = reform(vect)     
    Col_type = v_typepds(data_type(dt), length(l), ITYPE = integer_type, Stype = sample_type)
    vect = fix(vect, type=Col_type)
      CASE sample_type OF
        'MSB': V_swapData, vect, SILENT = silent
        'LSB': V_swapData, vect, /LSB, SILENT = silent
        'IEEE': V_swapData, vect, SILENT = silent
        'PC': V_swapData, vect, /LSB, SILENT = silent
        'VAX': v_vaxtoIEEE, vect     ; always floats
          else: begin 
                  message,'WARNING - Unrecognized SAMPLE_TYPE ('$
                          +data_type(dt)+'), no conversion performed', /INF
                end
      ENDCASE

     ; Convert signed bytes, not an IDL type
      if (Col_type EQ 1 AND integer_type EQ 'SIGNED') then begin
        ; Allocate an array of 2-byte integers to hold the final values:
        vect = fix(vect)
        fixitlist = WHERE(vect GT 127)
        if fixitlist[0] GT -1 then begin
          vect[fixitlist] = vect[fixitlist] - 256
        endif
      endif

;	Check that data type is of the right sign

;    if strpos(data_type(dt),'UNSIGNED') GT -1 then vect = abs(vect)

;M.Barker 10/13/99:
;if scale and/or offset factors are present, we must perform the necessary
;operation(s) on the vector:
    if scale_flag then $
       if sf NE -1 then vect = vect * double(scale(sf))
    if offset_flag then $
       if off NE -1 then vect = vect + double(offset(off))
;-----------------------------------

    vect = fix(vect, type=Col_type)
    If k EQ 0 then begin
         data = CREATE_STRUCT(column,vect) 
     endif else $
         data = CREATE_STRUCT(data,column,vect) 
    vect = 0
 endfor
 if not (SILENT) then help, /STRUCTURE, data

; Return data table in IDL structure form
 return, data  

 end 
