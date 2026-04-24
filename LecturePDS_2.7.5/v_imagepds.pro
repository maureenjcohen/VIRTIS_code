function V_IMAGEPDS, filename,label, NOSCALE = noscale, SILENT = silent

;+ $Id: v_imagepds.pro,v 1.12 2008/10/10 13:41:32 erard Exp $
;
; NAME:
;	V_IMAGEPDS
; PURPOSE:
;	Read a PDS image file into an IDL data variable.
;
; CALLING SEQUENCE:
;	Result=V_IMAGEPDS (Filename,Label[,/NOSCALE,/SILENT] )
;
; INPUTS:
;	FILENAME = Scalar string containing the name of the PDS data file 
;		to be read.
;	Label = String array containing the "header" from the PDS file.
;
; OUTPUTS:
;	Result = image (2D) data array read from file, according to format described in label.
;              Returns a structure if several images are present in the file.
;
; OPTIONAL INPUT KEYWORDS:
;	NOSCALE - If present and non-zero, then the ouput data will not be
;		scaled using the optional SCALING_FACTOR and OFFSET keywords 
;		in the PDS header.   Default is to scale.
;
;	SILENT - Suppresses console messages.
;
; EXAMPLE:
;	Read a PDS file TEST.PDS into an IDL image array, im. Do not scale 
;	the data with BSCALE and BZERO.
;
;		IDL> im = V_IMAGEPDS( 'TEST.PDS', lbl, /NOSCALE)
;
;
; PROCEDURES USED:
;	Functions: V_PDSPAR, V_STR2NUM, V_swapData, v_vaxtoIEEE...
;
; MODIFICATION HISTORY:
;	Adapted by John D. Koch from READFITS by Wayne Landsman,December,1994
;       25 Sep 1998, a.c.raugh: fixed bug which expected negative SAMPLE_BITS
;                               values to indicate real sample, causing a lonarr
;                               to be created rather than a fltarr; Fixed 
;                               calculation of byte offsets in detached PDS
;                               labels; Added lines to close and free logical
;                               units before return.
;       02 Oct 1998, a.c.raugh: Analyzed code and added comments throughout;
;                               Added code to deal properly with unsigned 
;                               integers and signed bytes; Re-wrote pointer
;                               parsing code to improve robustness;
;       27 July 1999, M. Barker: fixed bug that produced a negative skip when
;                               there was no offset provided in file pointer
;
;   Oct. 99          Modified for VIRTIS, Stephane Erard, IAS
;   Sept. 2000    Updated from SBNIDL 2.0, Stephane Erard
;          + added tests on offset and scaling factor
;          + fixed file path for any system
;          + convert to LSB architecture is needed
;   Nov. 2000     Fixed conversion to MSB, SE
;   Dec. 2000     Handles non-conformity in VIRTIS H DM files 
;            written before dec 2000, SE
;   Updated, June 2005 (SE, LESIA):
;          - Use modern swapping methods, much faster
;          (now process Vax floats and LSB integers independently)
;          - Now support all PDS data types, including PC_REAL
;
;  Updated, Oct 2005 (SE, LESIA):
;          - Added support for embeded browse images 
;          (independently from images; this function can be used to read both types)
;          - Object pointer parsing now in v_pointpds (+ fixed object pointers given in bytes)
;          - Now can read images mixed with other objects correctly
;          - Implemented basic bitmasking (in v_bmaskpds.pro)
;
; Updated, Dec 2005 (SE, LESIA):
;          - Fix bitmask reading if not provided between "
; Updated, Feb 2006 (SE, LESIA):
;          - Fixed structure length for I/O (solves rare EOF errors depending on dimensions)
; Updated, March 2006 (SE, LESIA):
;          - No longer tries to read data from label directory for detached labels (requires 6.0)
; Updated, June 2006 (SE):
;          - Now performs IEEE float swapping (required to read floats on Intel)
; Updated, Jan. 2007 (SE):
;          - Fixed to close all files when multiple images with attached label 
; Stephane Erard, LESIA, Feb 2007:
;          - New handling of detached labels (OK from IDL 5.5)
;          - Fixed for basic reading when multiple images are present 
;          (only objects IMAGE and BROWSE_IMAGE are read).
; Alejandro Cardesin, IASF, June 2007:
;          Fix for absent files error on Windows
; Stephane Erard, LESIA, Oct 2008:
;          - Removed shortcircuit logical operators for compatibility with older versions
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

  On_error,2                    ;2 =Return to user    0= debug
							
; If there is no input file name, abort:

  if N_params() LT 2 then begin		
    print,'Syntax - result = V_IMAGEPDS(filename,label[,/NOSCALE,/SILENT])'
    return, -1
  endif

; Save the input parameters:

  fname   = filename 
  noscale = keyword_Set(NOSCALE)
  silent  = keyword_set(SILENT)

; Read the "OBJECT =" line from the label to determine the data type.
; The 'v_pdspar' routine will search for all "OBJECT =" lines, returning
; the type (from the statement value field) of the first OBJECT, plus a
; count of the number of "OBJECT =" lines encountered (in 'objects') and
; an array containing the line indices for each "OBJECT =" line (in 'obj_ind'),
; if there is more than one.

  object = v_pdspar(label,'OBJECT',COUNT=objects,INDEX=obj_ind)
  if !ERR EQ -1 then message, $
        'ERROR - '+fname+' missing required OBJECT keyword'

; We also retrieve the pointer string (from the "^IMAGE =" line) for the first
; IMAGE object:

  Bid = 0
  pointer = v_pdspar(label,'^IMAGE')	
  if !ERR EQ -1 then Bid = 1
  pointBr = v_pdspar(label,'^BROWSE_IMAGE')
  CASE 1 of 
     (!ERR EQ -1) and (Bid EQ 1): message, 'ERROR - No pointers to image data found in '+fname
     (!ERR EQ -1) and (Bid NE 1):  ; OK (images, but no browse image)
     (!ERR NE -1) and (Bid EQ 1): pointer = pointBr     ; browse images only
     (!ERR NE -1) and (Bid NE 1): pointer = [pointBr,pointer]     ; both types present
     ELSE: ; OK
  ENDCASE
 

; If we've made it this far, we know we have an IMAGE object to process, so we
; collect the required keywords which we expect to be in the file:

; ...Instrument...
; (fix bug in early virtis H DM files)

  VIRTISH = 0
  VIRTISOUPS = 0
  Instru = v_pdspar(label,'INSTRUMENT_NAME')
  If strmid(strupcase(instru(0)),1,8) EQ 'VIRTIS_H' then VIRTISH = 1
  Date = (v_pdspar(label,'PRODUCT_CREATION_TIME', count = Nc))(0)
  If Nc EQ 0 then if not(SILENT) then message, fname+' missing PRODUCT_CREATION_TIME keyword', /cont $
   else begin 
    annee = fix(strmid(date,0,4))
    If annee LE 2000 and VIRTISH EQ 1 then VIRTISOUPS=1
   endelse

; ...RECORD_BYTES...

  record_bytes = long(v_pdspar(label,'RECORD_BYTES'))
  if !ERR EQ -1 then begin
     Print, 'ERROR - '+fname+' missing required RECORD_BYTES keyword'
     Print, 'ERROR - '+fname+'Trying 512...'     ; useful in some cases
     record_bytes = 512
   endif

; ...IMAGE parameters (these should appear once for each image, thus the 
;    various COUNTs returned should always be equal):

  Xvar = v_pdspar( label,'line_samples',COUNT=xcount,INDEX=x_ind) 
  Yvar = v_pdspar( label,'lines',COUNT=ycount,INDEX=y_ind)
  if xcount(0) NE ycount(0) then message, $
  	'ERROR - '+fname+': LINE_SAMPLES and LINES count discrepancy.'

  bitpix = v_pdspar( label, 'SAMPLE_BITS',COUNT=pixes,INDEX=pix_ind)
  if pixes(0) NE xcount(0) then message, $
  	'ERROR - '+fname+': LINE_SAMPLES and SAMPLE_BITS count discrepancy.'

  smp_type = v_pdspar(label, 'sample_type', COUNT=smpcount, INDEX=smp_ind)
  Bmask = v_pdspar(label,'SAMPLE_BIT_MASK',COUNT=maskcount,INDEX=bmk_ind, /nonum)

  bscale = float(v_pdspar(label, 'scaling_factor',INDEX=scl_ind))
  if (scl_ind(0) eq -1) then bscale = 1.
  bzero  = float(v_pdspar(label, 'offset', INDEX=zer_ind))
  if (zer_ind(0) eq -1) then bzero = 0.
  if (bzero(0) EQ 0. and bscale(0) EQ 1.) then Noscale =1

; We can now infer the number of IMAGEs.  If there is >1, we'll need a 
; structure to hold them:

  images = xcount(0)
  if images GT 1 then begin
    data = CREATE_STRUCT('images',images)
    if not (SILENT) then message,'Return type will be a structure with '$
        +strtrim(string(images+1),2)+' elements',/INFORM      
  endif

;___________________________________
;
; Now we're ready to read in the data for each IMAGE described in the label.
; Recall that the obj_ind array contains an index into the "OBJECT =" lines
; in the PDS label array:
 
  iter = 0                    ; 'iter' points on object of interest only
  for i=0,objects(0)-1 do begin     ; Loop on all objects

     ; Next if this is not the right type of object...
     If object(i) NE 'BROWSE_IMAGE' and object(i) NE 'IMAGE' then continue

    ; Set the local OBJECT pointers (obj_now = current, obj_nxt = next):

    obj_now = obj_ind(i)
    if i LT objects(0)-1 then begin
      obj_nxt = obj_ind(i+1) 
    endif else begin
      lblsz = size(label)     ; Retrieves the dimension sizes of 'label'
      obj_nxt = lblsz(1)      ; Sets obj_next = number of lines in 'label'
    endelse

    ; We need to gather the parameters (lines, samples, data type) for this
    ; particular IMAGE (there may be more than one!).  To do this, we use 
    ; the pointers into the 'label' array gathered when doing the initial
    ; check for parameters existence.  We select the parameter lines that
    ; fall between the pointer for the current OBJECT and that for the 
    ; next OBJECT (or end of the 'label' array).  This should always return
    ; a single positive scalar for each parameter (although we check this):

    xp = where(x_ind GT obj_now AND x_ind LT obj_nxt(0))      ; LINE_SAMPLES
    yp = where(y_ind GT obj_now AND y_ind LT obj_nxt(0))      ; LINES
    bp = where(pix_ind GT obj_now AND pix_ind LT obj_nxt(0))  ; SAMPLE_BITS
    sp = where(smp_ind GT obj_now AND smp_ind LT obj_nxt(0))  ; SAMPLE_TYPE
    sfp= where(scl_ind GT obj_now AND scl_ind LT obj_nxt(0))  ; SCALING_FACTOR
    zp = where(zer_ind GT obj_now AND zer_ind LT obj_nxt(0))  ; OFFSET
    Bm = where(bmk_ind GT obj_now AND bmk_ind LT obj_nxt(0))  ; BIT MASK

    if xp(0) GT -1 AND yp(0) GT -1 AND bp(0) GT -1 AND sp(0) GT -1 then begin
      X = long(Xvar(xp(0)))
      Y = long(Yvar(yp(0)))

      ; If we're not running in SILENT mode, we print the array dimensions:

      if not (SILENT) then begin
        if X GT 0 then if Y GT 0 then begin
          text = string(X)+' by'+string(Y)
          message,'Now reading ' + text + ' array',/INFORM    
 	endif else begin
          message,fname+" has X or Y = 0, no data array read",/CON
        endelse
      endif

      ; Grab the appropriate value for SAMPLE_BITS and convert it to a scalar:
     
      bits = v_str2num(bitpix(bp(0)))
      bits = bits(0)

      ; Determine the byte ordering by checking the SAMPLE_TYPE value:

      sample_type = smp_type(sp(0))
      Stype = sample_type(0)

     If VIRTISOUPS then Stype = 'LSB_'+Stype

     ; second argument is the number of bytes, not bits
     ; fct result (IDL_type) is the type of variable to be used 
      IDL_type = v_typepds(Stype, bits/8, ITYPE = integer_type, $
          Stype = sample_type)

     ; retrieve bitmask if present
    if bm(0) GT -1 then Mask = Bmask(bm(0))



;==================================================================
      ; Open file, retrieve offset to object

      PtObj =  V_POINTPDS(pointer(iter),record_bytes)
      datafile_found = (PtObj.filename NE '')

      if datafile_found NE 0 then begin               ; detached label

          fname = file_search(PtObj.filename, /fold)        ; works from IDL 5.5 and up
          temp = file_info(fname)
          ; If not found in current directory, try in label directory
          if fname EQ "" or not(temp.exists) then begin
;          if not(temp.exists) then begin
               DirName = v_getpath(filename, FBname)     ; get path to label under IDL ³ 5.4
               fname = file_search(Dirname+PtObj.filename, /fold)
               temp = file_info(fname)
          endif
;          if not(temp.exists) then  message, 'ERROR - Could not re-open '+ PtObj.filename
          if fname EQ "" or not(temp.exists) then  message, 'ERROR - Could not re-open '+ PtObj.filename
          openr, unit, fname, ERROR=err, /GET_LUN, /Compress

      endif else begin          ; attached label

        openr, unit, fname, ERROR=err, /GET_LUN, /Compress
        if err NE 0 then begin
          message, 'ERROR - Could not re-open '+fname
        endif
      endelse

      ;===================================================================
      ; OK, now we're ready to read the image data.  We'll associate the opened
      ; data file unit with an array of the appropriate type 
      ; (retrieved above by v_typepds from bits per pixel, in 'bits', and 
      ;  sample type, in 'sample_type'):

          If IDL_type EQ 0 then message, 'Unknown data type'
        Temp = Make_array(X, Y, Type = IDL_type, /nozero)
         file = assoc(unit, temp, PtObj.offset, /packed)

      ; We now read the image into the 'element' array and free the data unit:

      element = file(0)   
      free_lun, unit


      ; If we didn't get a data type we can work with, convert it:

      CASE sample_type OF
        'MSB': V_swapData, element, SILENT = silent
        'LSB': V_swapData, element, /LSB, SILENT = silent
        'IEEE': V_swapData, element, SILENT = silent
        'PC': V_swapData, element, /LSB, SILENT = silent
        'VAX': v_vaxtoIEEE, element     ; always floats
          else: begin 
                  message,'WARNING - Unrecognized SAMPLE_TYPE ('$
                          +smp_type(sp(0))+'), no conversion performed', /INF
                end
      ENDCASE


      ; Performs bit masking before conversions if required
      ; (may cause problems with unconventional IDL types)    

        if bm(0) GT -1 then begin
          element = v_bmaskpds( element, mask)
        endif



      ; If the native data type is one unsupported by IDL, we need to allocate
      ; new space and perform the appropriate conversion.  Unsupported types
      ; known so far include signed bytes, unsigned integers, and unsigned
      ; long integers:

     ; Convert signed bytes, not an IDL type 

      if (IDL_type EQ 1 AND  integer_type EQ 'SIGNED') then begin

        ; Allocate an array of 2-byte integers to hold the final values:

        element = fix(element)
        fixitlist = WHERE(element GT 127)
        if fixitlist[0] GT -1 then begin
          element[fixitlist] = element[fixitlist] - 256
        endif

      endif 


     ; Perform conversion to unsigned integers in IDL versions < 5.2

      if (!version.release LT 5.2) then begin

      if (IDL_type EQ 2  AND integer_type EQ 'UNSIGNED') then begin

        element = long(element)
        fixitlist = WHERE(element LT 0)
        if fixitlist[0] GT -1 then begin
          element[fixitlist] = element[fixitlist] + 65536
        endif

         endif else if (bits EQ 32  AND  integer_type EQ 'UNSIGNED') then begin

        ; These must be converted to real numbers.  In order to preserve as
        ; much precision as possible, we convert to double-precision reals:
          ; (long64 are not defined in IDL 5.2)

        element = double(element)
        fixitlist = WHERE(element LT 0.D0)
        if fixitlist[0] GT -1 then begin
          element[fixitlist] = element[fixitlist] + 4.294967296D+9
        endif

        endif

      endif

      ; Now we scale the data we've read in using the corresponding
      ; SCALING_FACTOR and OFFSET values from the label, unless the user
      ; has indicated /NOSCALE:


      if NOT keyword_set(NOSCALE) then begin
        if sfp(0) GT -1 then begin
          scl = bscale(sfp(0))
          if scl NE 1.0 then element = temporary(element)*scl
        endif

        if zp(0) GT -1 then begin
          zero = bzero(zp(0))
          if zero NE 0 then element = temporary(element)+zero
        endif
      endif

      ; Add the element read in to the data structure, creating if needed:

      if images GT 1 then begin
        image = 'image'+strtrim(string(i),2)
        data = CREATE_STRUCT(data,image,element)
      endif else data = element
      iter = iter + 1

      ; End of processing for one image.

    endif

    ; End of loop through IMAGEs.

  endfor	

  ; Check to make sure we read as many IMAGEs as we were expecting:

  if iter(0) NE images(0) then begin
     message, 'WARNING - '+fname+': Number of images expected does not equal number found.', /CONT
     data.images = iter(0)
  endif

  if images GT 1 then if not (SILENT) then help, /STRUCTURE, data

  ; Close the input unit:

  close,unit
  free_lun,unit

; Return array


  return, data  

end 
