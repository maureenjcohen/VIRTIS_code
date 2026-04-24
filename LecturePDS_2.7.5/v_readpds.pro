function V_READPDS, input_filename, label, INFO=info, NOSCALE = noscale, $
                      SILENT =silent, SUFFIX = suf, ListObj = object, Ddir = Ddir

;+ $Id: v_readpds.pro,v 1.11 2008/10/10 13:41:32 erard Exp $
;
; NAME:
;          V_READPDS
;
; PURPOSE:
;          Reads a PDS file into IDL data and label variables
;          Currently should read any combination of image, qube and table + first array and collection.
;
; CALLING SEQUENCE:
;          Result=V_READPDS (Filename,[ Label,INFO=info,/NOSCALE,/SILENT] )
;
; INPUTS:
;          Filename = Name of the PDS file to be read
;               (in case of detached labels, this the label file, rather than the data file).
;
; OUTPUTS:
;          Result = Variable constructed from PDS objects.
;               If single object, result can be an array (if image or qube)
;                    or a structure (table, with column names and columns)
;               If several objects, result is a structure with tags:
;                    <object type>S: total number of such objects
;                    COLUMN_NAMES#: column names for the #th table
;                    <object>#: #th object ot this type (structure of columns if table)
;                         # is not added to tag name if only one object of this type is present
;          Columns can be accesssed as result.tableN.(P)     where N is the table # and P is the column #
;
; OPTIONAL OUTPUT:
;          Label = String array containing the PDS label
;
; OPTIONAL INPUT KEYWORDS:
;          NOSCALE - If present and non-zero, then the ouput data will not be
;               scaled using the optional SCALING_FACTOR and OFFSETkeywords
;               in the PDS header.   Default is to scale.
;
;          SILENT - Suppress console messages.
;
;          DDIR - If present, indicates a directory where the data file is located.
;               Default is to look in current directory then in label directory.
;               (useful only when using detached labels located in a different directory
;               e.g., when labels are in LABEL and data files are in data directories)
;               OBSOLETE, no longer used
;
; OPTIONAL OUTPUT KEYWORDS:
;        SUFFIX - A named variable that will contain Qubes suffixes if present.
;
;       LISTOBJ - A named variable that will contain the list of all PDS objects in the file.
;
;       INFO - A scalar string giving information about the name(s) and
;              size of the output. Used only if the data is a Table (or any
;              variation on Table object). A nested bracket notation is used, see
;              V_ARBINPDS or ARASCPDS for example.
;
; EXAMPLE:
;          Read a PDS file TEST.PDS into an IDL image array (IM) and PDS
;          header array (lbl). Do not scale data.
;
;                    IDL> im = V_READPDS( 'TEST.PDS', lbl, /NOSCALE)
;
; RETRICTIONS:
;          This version of V_READPDS only read objects of type:
;          IMAGE (IMAGE and BROWSE_IMAGE),
;          QUBE (QUBE, SPECTRAL_QUBE + derived names),
;          tables (TABLE, DATA_TABLE and INDEX_TABLE, SERIES, PALETTE, and SPECTRUM),
;          ARRAY,
;          COLLECTION
;          All IMAGE, QUBE, and TABLE present are read.
;          IMAGE with derived object names (IMAGE_1É) are not read (owing to the difficulty to identify
;               non-image objects with such names. Those should be filtered both here and in v_imagepds)
;          Only the first ARRAY and COLLECTION are read (untested)
;
;          Data swapping (from MSB to LSB or reverse) is supported only for
;          Image, Qube and binary Table(s).
;
; PROCEDURES USED:
;          Functions:  complete library v_readpds
;
; FURTHER COMMENTS
;     This library is dedicated to VIRTIS support on Rosetta and Venus-Express.
;     Handles some non-conformity relative to PDS standard
;          (some of this is done in subroutines):
;     - Reads ISM Qubes (the suffix is actually a prefix)
;     - Reads early VIMS flight data files (non-standard end of line marker in labels)
;     - Handles empty Qube objects with suffixes (not defined in PDS doc)
;     - If the file contains an empty qube, only one suffix is allowed and
;          the qube dimensions are used to define two of the suffix dimensions:
;          X = 0 => Y and Z NE 0, and SX NE 0
;          Y = 0 => X and Z NE 0, and SY NE 0
;               (the two cases are exclusive)
;    Ex:
;       CORE_ITEMS = (0,25,24)      Core is empty
;       SUFFIX_ITEMS = (14,0,0)     Suffix is backplane (14,25,24)
;
;     - Handles bugs in VIRTIS H DM image labels written before dec 2000
;            (stated as UNSIGNED_INTEGER, ie MSB, whereas byte order is actually LSB).
;     - Tables are transferred as structures to preserve different data types in different columns
;             (eg, a table may contain both char and integers in PDS standard)
;     - Does not support CONTAINER object in tables.
;
; For future updates:
;     - Update object count. ReadObj is the number of major objects expected to be read Ñ 
;          depends on object parsing routines. Tottables is the number of tables present 
;          (objects returned with table structure), etc...
;     - If ReadObj = 1, returns a simple array whenever possible (image, cube) or the 
;          simplest possible structure
;          (including name tag  + array for tables, if all columns have the same type).
;     - Otherwise, returns a structure with Object count for each type
;     - In the loop, just after reading:
;          If several objects of the kind, append object number
;          If several objects, append count tag to the first one of this type
;     - Images and qubes are handled differently (all objects read inside parsing routine, 
;          count tag appended if more than one).
;
;
; MODIFICATION HISTORY:
;        Adapted by John D. Koch from READFITS by Wayne Landsman,August,1994
;       Modified by Michael E. Haken April-May, 1996
;
;       Modified for VIRTIS, Stephane Erard, oct. 99
;       Updated from SBNIDL 2.0, Stephane Erard, sept. 2000
;          + added processing of Qube objects.
;          + implemented LSB architectures for images and qubes.
;       Updated, SE Oct 2002:
;           Skip all Tables for two reasons (temporary?):
;               - the original routine does not handle the structure object
;               - it looks for a DATA_TYPE keyword which is not required
;       Updated, SE July 2004:
;          Turned on Tables again for Virtis, but support is limited (only the first one is read)
;               Tables are returned as structures (one vector/column).
;       SE, LESIA, Dec 2005:
;          Cleaned up code a bit...
;          Now returns a structure if more than 1 type of object found (e.g., table and image,
;               table and qube...). Qube suffices are still passed through keyword SUFFIX.
;          Stops if table format not found (if format provided in external file)
;       SE, LESIA, 23 Dec 2005:
;          Fixed image/qube storing when history object present
;       SE, LESIA, 15 Feb 2006:
;          Now read all objects present in sequence (images and cubes read in one pass).
;          This will allow to read any combination of objects, given the appropriate object subroutines.
;       SE, LESIA, April 2006:
;          Small fix to preserve cubes last dimension if degenerated.
;       SE, LESIA, Feb 2007:
;          Inserted new mechanism to read data with detached label from another directory.
;               Implemented only for Tables so far (should first try with no Dirstring, then with it)
;       AC, IASF,  Oct 2008:
;          Read detached PDS label (*.LBL) if it exists
;-
;
;###########################################################################
;
; LICENSE
;
;  Copyright (c) 1999-2008, Stephane Erard, CNRS - Observatoire de Paris
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


  On_error,2                   ; 2 = Return to user      (debug is 0)

 if N_params() LT 1 then begin
    print,'Syntax - result = V_READPDS( filename,[ label, INFO=info, /NOSCALE, /SILENT])'
    return, -1
 endif
 silent = keyword_set( SILENT )
 Noscale = keyword_set( NOSCALE )
 filename = input_filename ; make sure input filename is not changed
 fname = filename

;;
;; Modified A. Cardesin October 2008
;; (Force using detached PDS label file *.LBL if it exists)
;;

; determine the extension that was actually used
sNamesplit = STR_SEP(filename, '.')
sExtension = sNamesplit [N_ELEMENTS (sNamesplit) - 1]
sExtension = STRUPCASE(sExtension)

IF sExtension NE 'LBL' THEN BEGIN
    ;; if its not a '.LBL', change it and see if it exists
    sNamesplit [N_ELEMENTS (sNamesplit) - 1]='LBL'
    sFilechanged = STRJOIN(sNamesplit,'.',/SINGLE)

    ;; if .LBL doesnt exist, then try also with .lbl
    IF FINDFILE(sFilechanged) EQ '' THEN BEGIN
        sNamesplit [N_ELEMENTS (sNamesplit) - 1]='lbl'
        sFilechanged = STRJOIN(sNamesplit,'.',/SINGLE)
    ENDIF
    IF FINDFILE(sFilechanged) NE '' THEN BEGIN
        filename = sFilechanged
		print, 'Label file found. Changing selection... '
    ENDIF
ENDIF

; Read PDS label
 label = v_headpds(filename, silent=silent)
 data = 0
 suf = 0

; get path to label under IDL ³ 5.4
 DirName = v_getpath(filename, FBname)


; Read object list
 object = v_pdspar(label,'OBJECT',COUNT=objects,INDEX=obindex)
 if !ERR EQ -1 then begin
    if (not silent) then print,'ERROR - '+filename+' missing required OBJECT keyword'
    return, -1
 endif


; ------ Object count

Obj_def =  V_OBJPDS(label, /all)
;Obj_num = (size(obj_def, /dim))(0)      ; number of objects present
record_bytes = long(v_pdspar(label,'RECORD_BYTES'))
PtObj =  V_POINTPDS(Obj_def.pointer,record_bytes)

Nobj = 0
nimages = 0
nqubes = 0
ntables = 0
narrays = 0
ncollections = 0

Tottables = 0          ; count total number of tables present
temp = total(strpos(object,'TABLE') GT -1)     ; include derived names
Tottables = Tottables + temp
temp = total(strpos(object,'SERIES') GT -1)
Tottables = Tottables + temp
temp = total(strpos(object,'PALETTE') GT -1)
Tottables = Tottables + temp
temp = total(strpos(object,'SPECTRUM') GT -1)
Tottables = fix(Tottables + temp)

      ; count total number of images present
; Do not include all derived names - some are not images (IMAGE_MAP_*)
bid = v_pdspar(label,'^IMAGE',COUNT=temp)
Totima = temp
bid = v_pdspar(label,'^BROWSE_IMAGE',COUNT=temp)
Totima = Totima + temp


      ; count total number of qubes present
Totqube = total(strpos(object,'QUBE') GT -1)  ; include derived names

; read only one such object so far
Totarray = 0
If  total(strpos(object,'ARRAY') GT -1) GT 0 then Totarray = 1
Totcollect = 0
If  total(strpos(object,'COLLECTION') GT -1) GT 0 then Totcollect = 1

; Overall number of objects to be read
ReadObj = fix(Tottables + Totima + Totqube + Totarray + Totcollect)

 ; ----- Loop on all objects present, read only supported major types (not sub-objects)

 i = fix(0)
 For i =0, objects(0)-1 do begin
Ndelta = 1

   if strpos(object(i),'IMAGE') GT -1 then begin                      ; process both IMAGE and BROWSE_IMAGE
     if nimages EQ 0 then begin                               ; read all images at once when first image is encountered
        data = v_imagepds(fname,label, NOSCALE= noscale, SILENT= silent)
       if n_tags(data) eq 0 then nimages=1 else nimages= data.images     ; number of images read
       Rtag = 'images'
       If ReadObj GT 1 and nimages EQ 1 then $          ; add image number tag if several objects
          data = CREATE_STRUCT(RTag, 1, 'image', data)
       Nobj = Nobj +nimages	; Number of objects actually read
     endif else Ndelta =0


   endif else if strpos(object(i),'QUBE') GT -1 then begin     ; process both QUBE, SPECTRAL_QUBE and other derived names
     if nqubes EQ 0 then begin                               ; read all qubes at once when first qube is encountered
       data = v_qubepds(fname,label, SUFFIX=suf, Ddir= DirName, NOSCALE= noscale, SILENT= silent)
       if n_tags(data) eq 0 then nqubes=1 else nqubes = data.qubes     ; number of qubes read
       Rtag = 'qubes'
       If ReadObj GT 1 and nqubes EQ 1 then $          ; add qube number tag if several objects
          data = CREATE_STRUCT(RTag, 1, 'qube', data)
       Nobj = Nobj +Nqubes	; Number of objects actually read
     endif else Ndelta =0


   endif else if strpos(object(i),'TABLE') GT -1 or $             ; process TABLE, DATA_TABLE, INDEX_TABLE ++
        strpos(object(i),'SERIES') GT -1 or $
        strpos(object(i),'PALETTE') GT -1 or $
        strpos(object(i),'SPECTRUM') GT -1 then begin
     inform = v_pdspar( label, 'INTERCHANGE_FORMAT', INDEX = index )
     if !ERR EQ -1 then $
          if (not silent) then message, 'ERROR - '+fname+' missing required INTERCHANGE_FORMAT keyword', /cont
     w= where(index GT obindex(i))
;      May occur whenever table is described through ^Structure keyword - Fixed in v_headpds
     if w(0) EQ -1 then message, 'ERROR - table interchange format not found '

;      Should skip object if CONTAINER present inside table

;      Append Directory name in case of detached label read from another directory
 ;    obj_def(i).pointer = '"'+Dirname + strmid(obj_def(i).pointer, 1, strlen(obj_def(i).pointer)-1)

     if strpos(inform(w(0)),'ASCII') GT -1 then begin
	data = V_ATABPDS(fname, label, Obj_def(i), C_name= colNames, SILENT = silent)
     endif else if strpos(inform(w(0)),'BINARY') GT -1 then begin
            data = V_BTABPDS(fname,label, Obj_def(i), C_name= colNames, SILENT= silent)
     endif else message, 'ERROR - Invalid PDS table interchange format '+inform(0)

     Rtag = 'tables'
     Ttab = 'table'
     Tname= 'column_names'
     If TotTables GT 1 then begin          ; add table number if more than one table
         L_tag=tag_names(data)+'_'+string(Ntables, f='(I0)')     ; unused
         Ttab=Ttab+string(Ntables, f='(I0)')
         Tname= Tname+string(Ntables, f='(I0)')
     endif
     If ReadObj GT 1 and  Ntables EQ 0 then $          ; add table number tag to first table only, if several objects
          data = CREATE_STRUCT(RTag, Tottables, Tname, colNames, Ttab, data) $
          else data = CREATE_STRUCT(Tname, colNames, Ttab, data)
     Ntables =Ntables+1      ; Table current number, used for tags
     Nobj = Nobj +1	; Number of objects actually read


   endif else if strpos(object(i),'ARRAY') GT -1 then begin
     inform = v_pdspar( label, 'INTERCHANGE_FORMAT',INDEX = index )
     if !ERR EQ -1 then $
        if (not silent)  then message, 'ERROR - '+fname+' missing required INTERCHANGE_FORMAT keyword'
     w = where(index GT obindex(i))
     if strpos(inform(w(0)),'ASCII') GT -1 then begin
	 data = v_arascpds(fname,label,info=info,silent=silent)
      endif else if strpos(inform(w(0)),'BINARY') GT -1 then begin
	 data = v_arbinpds(fname,label,info=info,silent=silent)
      endif else if (not silent)  then message,$
	'ERROR - Invalid PDS table interchange format '+inform(0)
;      i = objects(0)+10	; if viable object found, increment i to escape loop
     Narrays = 1           ; read only 1 such object so far
     Rtag = 'array'
     Nobj = Nobj + 1	; Number of objects actually read


   endif else if strpos(object(i),'COLLECTION') GT -1 then begin
      inform = v_pdspar( label, 'INTERCHANGE_FORMAT',INDEX = index )
      if !ERR EQ -1 then  $
        if (not silent) then message,'ERROR - '+fname+' missing required INTERCHANGE_FORMAT keyword'
      w = where(index GT obindex(i))
      if strpos(inform(w(0)),'ASCII') GT -1 then begin
        data = v_colaspds(fname,label,info=info,silent=silent)
      endif else $
      if strpos(inform(w(0)),'BINARY') GT -1 then begin
        data = v_colbipds(fname,label,info=info,silent=silent)
      endif else message,$
       'ERROR - Invalid PDS table interchange format '+inform(0)
;      i = objects(0)+10	; if viable object found, increment i to escape loop
     Ncollections = 1           ; read only 1 such object so far
     Nobj = Nobj +1	; Number of objects actually read
     Rtag = 'collection'

   endif else Ndelta = 0

   ; skip other objects, in particular HISTORY and COLUMN (sub-object)


; ======== Store new object in a structure

 if Ndelta EQ 1 then begin         ; update only if new object(s) found

  if readObj EQ 1 then begin     ; If only one object present (may be a structure)
;     data2 = data
     data2 = reform(data, size(data, /dim))     ; preserve dimensions
     data = 0     ; release space

  endif else begin                ; Tags already attached, stack structures

     if size(data2, /type) EQ 0 then begin
;      data2 = data
     data2 = reform(data, size(data, /dim))     ; preserve dimensions
     endif else begin
      data2 = CREATE_STRUCT(data2,data)
      data = 0     ; release space
    endelse
  endelse

 endif

; ------- End object loop

 endfor



 if Nobj LT 1 then begin
    if (not silent) then print,'No valid data type [image,qube,tables,array,colection] found in ' + fname
    return, -1
 endif

; Return file data and exit program
 return, data2
 end

