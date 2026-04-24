function V_QUBEPDS, filename, label, NOSCALE = noscale, Ddir= Ddir, SILENT = silent, SUFFIX = suffix

;+ $Id: v_qubepds.pro,v 1.14 2008/11/24 15:59:25 erard Exp $
;
; NAME:
;	V_QUBEPDS
;
; PURPOSE:
;	Read a PDS qube file into an IDL data variable.
;  Intended for use with VIRTIS (Rosetta and VEx) data files
;
; CALLING SEQUENCE:
;	Result=V_QUBEPDS (Filename,Label[,/NOSCALE,/SILENT] )
;
; INPUTS:
;	FILENAME = Scalar string containing the name of the PDS data file (used only
;     with attached labels).
;	Label = String array containing the PDS label itself (as read by v_headpds)
;
; OUTPUTS:
;	Result = qube (3D) data array read from file, according to format described in label.
;     Returns a structure if several qubes are present in the file.
;
; OPTIONAL OUTPUT KEYWORDS:
;	SUFFIX - A named variable that will contain the suffixes in the Qubes.
;
; OPTIONAL KEYWORDS:
;	Ddir - If present, indicates a directory where the data file is
;               Default is to look in current directory or in label directory.
;               (useful only when using detached labels located in a different directory
;               e.g., when labels are in LABEL and data files are in data directories)
;
;	NOSCALE - If present and non-zero, then the ouput data (core and suffix)
;		will not be scaled using the parameters in the PDS label.
;		  Default is to scale if parameters are present in label.
;
;	SILENT - Skip console messages
;
; EXAMPLE:
;	Read a PDS file TEST.PDS into an IDL array, im. Do not scale
;	the data with BSCALE and BZERO.
;
;		IDL> im = V_QUBEPDS( 'TEST.PDS', lbl, [SUFFIX = suf], [/NOSCALE] )
;
; RESTRICTIONS
;  - Assume Qubes with 3-axes among the 6 possible axes
;  (spectral image-cubes, no images).
;  - Extra data can be contained in the sideplane, backplane or bottomplane,
;     but only some associations are supported:
;     SUFFIX_ITEMS = '(b,s,0)'  or  '(b,0,l)'
;  - BSQ storage handled only when no suffix present
;  - All parameters are assumed to have the same variable type
;     inside a given suffix (the first type in the list *_SUFFIX_ITEM_TYPE)
;  - Unsigned integers are stored in signed integers variables in IDL < 5.2
;      (but core data are always handled correctly).
;
; FURTHER COMMENTS
;     - Suffix tags are apparently OK only for BIP order (should be inverted otherwise)
;     - V_QUBEPDS handles both MSB and LSB architectures
;     - Assume that all objects containing QUBE in their name are
;          actual QUBEs (and not associated data, which occurs e.g. for images)
;     - Handle ISM Qubes correctly (the suffix is actually a prefix).
;     - Suffixes are converted to real if they need scaling with a floating coefficient.
;          (can result in double array size).
;     - If the file contains an empty qube core, only one suffix is allowed and
;          the qube dimensions are used to define two of the suffix dimensions:
;          X = 0 => Y and Z NE 0, and SX NE 0
;          Y = 0 => X and Z NE 0, and SY NE 0
;               (two cases are exclusive)
;          Ex:
;               CORE_ITEMS = (0,25,24)      Core is empty
;               SUFFIX_ITEMS = (14,0,0)     Suffix is a backplane (14,25,24)
;
; ROUTINES USED:
;        V_PDSPAR, V_STR2NUM, V_LISTPDS, V_swapData,
;        v_vaxtoIEEE, V_TYPEPDS...
;
; MODIFICATION HISTORY:
;	Sept 2000 : Stephane Erard, IAS.
;      Adapted from IMAGEPDS by John D. Koch
;     (from version in SBNIDL 2.0, last modif 27 July 1999 by M. Barker)
;        Updated, Nov 2000 (SE):
;          - accepts suffixes with a single plane
;          - Fixed suffix type (from SUFFIX_BYTES)
;          - Fixed suffix reading, transfer to correct integer type
;                    (from *_SUFFIX_ITEM_BYTES)
;          - Reads VIMS flight qubes correctly
;          - Reads qubes with empty core and one suffix (ISM coordinate files)
;        Updated, March 2001 (SE):
;          - now reads qube with no suffix at all (as written by vv_writepds.pro)
;        Updated, Sept 2001 (SE):
;          - Fixed pb with suffix dimensions (now returns 1D suffix as cube, not array)
;        Updated, Oct 2002 (SE):
;          - Now reads BSQ Qube with no suffix (THEMIS)
;          - In this case, does not require the SUFFIX_ITEM keyword
;        Updated, Oct 2003 (SE):
;          - Now returns both suffixes in a structure when present (OMEGA, VIMS)
;          - Small fix related to Band suffix type
;        Updated, June 2005 (SE, LESIA):
;          - Use modern swapping methods, much faster
;          - Now support PC_REAL types
;          - Now process Vax floats and LSB integers independently!
;        Updated, Oct 2005 (SE, LESIA):
;          - Object pointer parsing now in v_pointpds (+ fixed object pointers given in bytes)
;          - Now can read qubes mixed with other objects correctly
;          - Data file must still contain either Qubes or Spectral_Qubes
;          - Implemented basic bitmasking (in v_bmaskpds.pro)
;        Updated, Nov 2005 (F. Henry, LESIA):
;          - Passes SILENT option systematically to subroutines
;        Updated, Dec 2005 (SE, LESIA):
;          - Fix bitmask reading if not provided between "
;        Updated, Feb 2006 (SE, LESIA):
;          - Fixed bitmask handling (applied to cube core only)
;          - Fixed structure length for I/O (solves rare EOF errors depending on dimensions)
;          - Second thought: changed reading scheme (assoc replaced by readu). This should
;               make it possible to read gizep files ~as fast as previously.
;          - Optimized memory handling a bit.
;        Updated, May 2006 (SE, LESIA):
;          - Now returns scalar suffix (0B) if no suffix present (previously returned an ambiguous structure)
;        Updated, June 2006 (SE):
;          - Now performs IEEE float swapping (required to read floats on Intel)
;        Updated, August 2006 (SE):
;          - Fixed reading of suffices if multiple cubes in a single file (VEx M-calibrated files).
;               Beware that it still does not parse individual suffix types (should be equal).
;        Updated, Jan. 2007 (SE):
;          - Can now read Qubes defined with composite names, allowing several qubes with
;               different object names in the same file
;               (includes SPECTRAL_QUBE, but also REF_QUBE, QUBE_1, etc...
;               Apparently all/only names such as prefix_QUBE are alllowed)
;          - Fixed to close all files when multiple cubes with attached label
;        Stephane Erard, LESIA, Feb 2007:
;	      - New handling of detached labels (OK from IDL 5.5)
;          - Fixed multiple cubes, each with suffix (ISM)
;        Stephane Erard, LESIA, Feb 2008:
;	      - Tentative support for bottomplanes in BIP and BIL storage
;            Pb: suffix_byte is apparently expected to be uniform in PDS (not really stated...) 
;               so the code is expecting this
;            Application to virtis : the suffix is half empty...
;        Stephane Erard, LESIA, Oct 2008:
;	      - Fixed opening from detached label (as suggested by AC)
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


  On_error,0                    ;2 = Return to user   0 = debug

; If there is no input file name, abort:

  if N_params() LT 2 then begin
    print,'Syntax - result = V_QUBEPDS(filename,label[,/NOSCALE,/SILENT])'
    return, -1
  endif

; Save the input parameters:

  fname   = filename
  noscale = keyword_Set(NOSCALE)
  silent  = keyword_set(SILENT)

; Get all object names, plus object number (in 'objects') and
; an array containing the line indices for each "OBJECT =" line (in 'obj_ind'),
; if there is more than one.

  object = v_pdspar(label,'OBJECT',COUNT=objects,INDEX=obj_ind)
  if !ERR EQ -1 then message, $
        'ERROR - '+fname+' missing required OBJECT keyword'


; Identify Qube objects present from the object names in previous list, allowing for
;  variations on the names (all Qube objects must contains "QUBE" in their name)
; Pointer contains the data pointer for all QUBE objects

Qlist = where(strpos(object,'QUBE') GT -1, Qcount)
If Qcount EQ 0 then message, 'ERROR - No pointers to QUBE data found in '+fname
for Qi= 0, Qcount-1 do begin
 temp = v_pdspar(label,'^'+object(Qlist(Qi)))
 If Qi EQ 0 then pointer = temp else pointer = [pointer,temp]
endfor

;  pointer = v_pdspar(label,'^QUBE')
;  if !ERR EQ -1 then   pointer = v_pdspar(label,'^SPECTRAL_QUBE')
;  if !ERR EQ -1 then message, $
;        'ERROR - No pointers to QUBE data found in '+fname

; If we've made it this far, we know we have a QUBE object to process, so we
; collect the required keywords which we expect to be in the file:

; ...Instrument...
; (handles non conformity in ISM qubes)

  ISM = 0
  Instru = v_pdspar(label,'INSTRUMENT_ID')
  If strupcase(instru(0)) EQ 'ISM' then ISM = 1

; ...RECORD_BYTES...

  record_bytes = long(v_pdspar(label,'RECORD_BYTES'))
  if !ERR EQ -1 then message, $
        'ERROR - '+fname+' missing required RECORD_BYTES keyword'

; ...QUBE parameters (these should appear once for each qube, thus the
;    various COUNTs returned should always be equal):

  Nvar = v_pdspar( label,'AXIS_NAME',COUNT=Vcount,INDEX=V_ind)
  Naxes = v_pdspar( label,'AXES',COUNT=Ncount,INDEX=N_ind)
  if Vcount(0) NE Ncount(0) then message, $
  	'ERROR - '+fname+': AXIS_NAME and AXES count discrepancy.'

  Xvar = v_pdspar( label,'CORE_ITEMS',COUNT=xcount,INDEX=x_ind)
  if xcount(0) NE Ncount(0) then message, $
  	'ERROR - '+fname+': CORE_ITEMS and AXES count discrepancy.'

  bitpix = v_pdspar( label, 'CORE_ITEM_BYTES',COUNT=pixes,INDEX=pix_ind)
  if pixes(0) NE Ncount(0) then message, $
  	'ERROR - '+fname+': CORE_ITEM_BYTES and AXES count discrepancy.'

  smp_type = v_pdspar(label, 'CORE_ITEM_TYPE', COUNT=smpcount, INDEX=smp_ind)
  Bmask = v_pdspar(label,'SAMPLE_BIT_MASK',COUNT=maskcount,INDEX=bmk_ind, /nonum)

  bscale = float(v_pdspar(label, 'CORE_MULTIPLIER',INDEX=scl_ind))
  if (scl_ind(0) eq -1) then bscale = 1.
  bzero  = float(v_pdspar(label, 'CORE_BASE', INDEX=zer_ind))
  if (zer_ind(0) eq -1) then bzero = 0.
  if (bzero(0) EQ 0. and bscale(0) EQ 1.) then Noscale =1


; Check suffix parameters

  Svar = v_pdspar( label,'SUFFIX_ITEMS',COUNT=Scount,INDEX=suff_ind)

  SSbyte = v_pdspar( label, 'SAMPLE_SUFFIX_ITEM_BYTES',COUNT=Spixes,INDEX=Spix_ind)
  SBbyte = v_pdspar( label, 'BAND_SUFFIX_ITEM_BYTES',COUNT=SBpixes,INDEX= Bpix_ind)
  SLbyte = v_pdspar( label, 'LINE_SUFFIX_ITEM_BYTES',COUNT=SLpixes,INDEX= Lpix_ind)
  Sbyte = v_pdspar( label, 'SUFFIX_BYTES',COUNT= temp, INDEX=Suffb_ind)

;  if SBpixes * Spixes NE 0 then begin     ; back & side planes
;     Spix_ind = [Spix_ind,T_ind]
;     ind = sort(Spix_ind)
;     Spix_ind = Spix_ind(ind)
;     SSbyte = SSbyte(ind)
;   endif
;  if SBpixes * SLpixes NE 0 then begin     ; back & bottom planes
;     Spix_ind = [T_ind,U_ind]
;     ind = sort(Spix_ind)
;     Spix_ind = Spix_ind(ind)
;     SSbyte = SSbyte(ind)
;   endif
;  if Spixes EQ 0 and SBpixes NE 0 then begin              ; band suffix only
;     SSbyte = SBbyte
;     Spix_ind = T_ind
;   endif
;   Spixes = Spixes + SBpixes
;  if Spixes EQ 0 and SLpixes NE 0 then begin              ; bottom suffix only
;     SSbyte = SLbyte
;     Spix_ind = U_ind
;   endif
;   Spixes = Spixes + SBpixes + SLpixes

;  if Spixes(0) NE Scount(0) or temp(0) NE Scount(0) then message, $
;  	'ERROR - '+fname+': SUFFIX_ITEMS and *_SUFFIX_ITEM_BYTES count discrepancy.'
  if temp(0) NE Scount(0) then message, $
  	'ERROR - '+fname+': SUFFIX_ITEMS and SUFFIX_BYTES count discrepancy.'

  Ssmp_type = v_pdspar(label, 'SAMPLE_SUFFIX_ITEM_TYPE', $
          COUNT=Ssmpcount, INDEX=Ssmp_ind)
  SBsmp_type = v_pdspar(label, 'BAND_SUFFIX_ITEM_TYPE', $
          COUNT=SBsmpcount, INDEX=SBsmp_ind)
  SLsmp_type = v_pdspar(label, 'LINE_SUFFIX_ITEM_TYPE', $
          COUNT=SLsmpcount, INDEX=SLsmp_ind)

;  if Ssmpcount * SBsmpcount NE 0 then $
;     Ssmp_ind = ([Ssmp_ind,T_ind])(sort([Ssmp_ind,T_ind]))
;  if Ssmpcount EQ 0 then Ssmp_ind = T_ind

  Sbscale =(v_pdspar(label, 'SAMPLE_SUFFIX_MULTIPLIER',INDEX=Sscl_ind,$
           COUNT = sccount))
  SBbscale =(v_pdspar(label, 'BAND_SUFFIX_MULTIPLIER',INDEX= Bscl_ind,$
           COUNT = SBccount))
  SLbscale =(v_pdspar(label, 'LINE_SUFFIX_MULTIPLIER',INDEX= Lscl_ind,$
           COUNT = SLccount))
;  if sccount * SBccount NE 0 then $
;     Sscl_ind = ([Sscl_ind,T_ind])(sort([Sscl_ind,T_ind]))
;  if sccount EQ 0 then Sscl_ind = T_ind

  Sbzero  =(v_pdspar(label, 'SAMPLE_SUFFIX_BASE', INDEX=Szer_ind,$
           COUNT = sccount))
  SBbzero  =(v_pdspar(label, 'BAND_SUFFIX_BASE', INDEX= Bzer_ind,$
           COUNT = SBccount))
  SLbzero  =(v_pdspar(label, 'LINE_SUFFIX_BASE', INDEX= Lzer_ind,$
           COUNT = SLccount))


; We can now infer the number of QUBEs.  If there is >1, we'll need a
; structure to hold them:

  qubes = xcount(0)
  if qubes GT 1 then begin
    data = CREATE_STRUCT('qubes',qubes)
    if not (SILENT) then message,'Return type will be a structure with '$
        +strtrim(string(qubes+1),2)+' elements',/INFORM
  endif

  if scount(0) GT 0 then begin
    suffix = CREATE_STRUCT('suffixes',scount(0))
  endif else suffix = 0B


;___________________________________
;
; Now we're ready to read in the data for each QUBE described in the label.
; Recall that the obj_ind array contains an index into the "OBJECT =" lines
; in the PDS label array:

  iter = 0                    ; 'iter' is the number of processed cubes
  for i=0,objects(0)-1 do begin

     ; Next if this is not the right type of object...
;     If object(i) NE 'QUBE' and object(i) NE 'SPECTRAL_QUBE' then continue
      If where(Qlist EQ i) EQ -1 then continue     ; skip if not in identified Qube list

    ; Set the local OBJECT pointers (obj_now = current, obj_nxt = next):

    obj_now = obj_ind(i)
    if i LT objects(0)-1 then begin
      obj_nxt = obj_ind(i+1)
    endif else begin
      lblsz = size(label)     ; Retrieves the dimension sizes of 'label'
      obj_nxt = lblsz(1)      ; Sets obj_next = number of lines in 'label'
    endelse

    ; We need to gather the parameters (lines, samples, data type) for this
    ; particular QUBE (there may be more than one!).  To do this, we use
    ; the pointers into the 'label' array gathered when doing the initial
    ; check for parameters existence.  We select the parameter lines that
    ; fall between the pointer for the current OBJECT and that for the
    ; next OBJECT (or end of the 'label' array).  This should always return
    ; a single positive scalar for each parameter (although we check this):

    ap = where(V_ind GT obj_now AND V_ind LT obj_nxt(0))         ; AXIS_NAME
    xp = where(x_ind GT obj_now AND x_ind LT obj_nxt(0))         ; CORE_ITEMS
    bp = where(pix_ind GT obj_now AND pix_ind LT obj_nxt(0))  ; CORE_ITEM_BYTES
    sp = where(smp_ind GT obj_now AND smp_ind LT obj_nxt(0)) ; CORE_ITEM_TYPE
    sfp= where(scl_ind GT obj_now AND scl_ind LT obj_nxt(0))    ; CORE_MULTIPLIER
    zp = where(zer_ind GT obj_now AND zer_ind LT obj_nxt(0))   ; CORE_BASE
    Sxp = where(Suff_ind GT obj_now AND Suff_ind LT obj_nxt(0))   ; SUFFIX_ITEMS
    Sb = where(Suffb_ind GT obj_now AND Suffb_ind LT obj_nxt(0)) ; SUFFIX_BYTES

    Sbp = where(Spix_ind GT obj_now AND Spix_ind LT obj_nxt(0)) ; S_S_ITEM_BYTES
    SBbp = where(Bpix_ind GT obj_now AND Bpix_ind LT obj_nxt(0)) ; B_S_ITEM_BYTES
    SLbp = where(Lpix_ind GT obj_now AND Lpix_ind LT obj_nxt(0)) ; L_S_ITEM_BYTES
    Ssp = where(Ssmp_ind GT obj_now AND Ssmp_ind LT obj_nxt(0)) ; S_S_ITEM_TYPE
    SBsp = where(SBsmp_ind GT obj_now AND SBsmp_ind LT obj_nxt(0)) ; B_S_ITEM_TYPE
    SLsp = where(SLsmp_ind GT obj_now AND SLsmp_ind LT obj_nxt(0)) ; L_S_ITEM_TYPE
    Ssfp= where(Sscl_ind GT obj_now AND Sscl_ind LT obj_nxt(0))  ; S_S_MULTIPLIER
    Szp = where(Szer_ind GT obj_now AND Szer_ind LT obj_nxt(0))  ; S_S_BASE
    Bsfp= where(Bscl_ind GT obj_now AND Bscl_ind LT obj_nxt(0))  ; B_S_MULTIPLIER
    Bzp = where(Bzer_ind GT obj_now AND Bzer_ind LT obj_nxt(0))  ; B_S_BASE
    Lsfp= where(Lscl_ind GT obj_now AND Lscl_ind LT obj_nxt(0))  ; L_S_MULTIPLIER
    Lzp = where(Lzer_ind GT obj_now AND Lzer_ind LT obj_nxt(0))  ; L_S_BASE
    Bm = where(bmk_ind GT obj_now AND bmk_ind LT obj_nxt(0))  ; BIT MASK

    if xp(0) GT -1 AND bp(0) GT -1 AND sp(0) GT -1 then begin


;      Extract the three dimension sizes from CORE_ITEMS

     temp = (Nvar(ap(0)))(0)
     axes_N=v_listpds(temp, count=as, silent = silent)
    if as NE 3 then message,'ERROR - Qube should have exactly 3 dimensions'

  Case 1 of
    axes_N(0) eq 'BAND' and axes_N(1) eq 'SAMPLE' and axes_N(2) eq 'LINE': order=0     ; BIP (ISM, VIRTIS)
    axes_N(0) eq 'SAMPLE' and axes_N(1) eq 'BAND' and axes_N(2) eq 'LINE': order=1     ; BIL (VIMS, OMEGA)
    axes_N(0) eq 'SAMPLE' and axes_N(1) eq 'LINE' and axes_N(2) eq 'BAND': order=2     ; BSQ (Themis)
  Else: message, 'ERROR - '+fname+' has non-standard interleave mode'
  EndCase
     if order EQ 2 then begin
      ;message, 'ERROR - BSQ mode not handled so far'
      message, 'INFO - BSQ mode handled with no suffix only (so far), trying', /cont
      nosuffix =1
     endif

     Dimen = (Xvar(xp(0)))(0)
     X=v_listpds(Dimen, count=cs, silent = silent)
     if cs NE 3 then message,'ERROR - Qube core is not 3D'
     Z=long(X(2))
     Y=long(X(1))
     X=long(X(0))

      ; If we're not running in SILENT mode, we print the array dimensions:

      nocube = 0
      if X*Y*Z NE 0 then begin     ; if one dimension is zero, no cube
        if not (SILENT) then begin
          text = string(X,Y,Z, format='(I4, " by",I4," by",I4," Qube")')
          message,'Now reading ' + text ,/INFORM
        endif
       endif else begin
          message, "INFO - "+fname+" has an empty qube core",/CON
          nocube = 1
          noscale = 1     ; inhibits core scaling
      endelse


      ; Grab the appropriate value for CORE_ITEM_BYTES and convert it to a scalar:

      bits = v_str2num(bitpix(bp(0)))
      bits = bits(0)     ; warning : this is given in BYTES for Qubes

      ; Determine the byte ordering by checking the CORE_ITEM_TYPE value:

      sample_type = smp_type(sp(0))
      Stype = sample_type(0)

      Core_type = v_typepds(Stype, bits, ITYPE = integer_type, $
          Stype = sample_type)


      ; retrieve bitmask if present
      if bm(0) GT -1 then Mask = Bmask(bm(0))


      ;==================================================================
      ; Now look at suffix area

;       Suffix = 0
     if Sxp(0) GT -1 then begin

;      Extract  dimensions from SUFFIX_ITEMS

       nosuffix = 0
       Dimen = (Svar(xp(0)))(0)
       SX=v_listpds(Dimen, count=cs, silent = silent)
       if cs NE 3 then message,'ERROR - Inconsistent suffix dimensions'
       SZ=long(SX(2))  ; bottome plane
       SY=long(SX(1))  ; sideplane
       SX=long(SX(0))  ; backplane
;       If SZ NE 0 then $
;          message,fname+' Ñ Bottom plane present, not read', /INFO
       If nocube then $
          If Z EQ 0 or (X EQ 0 and SX*Y EQ 0) or (Y EQ 0 and X*SY EQ 0) then $
               message,'ERROR - Inconsistent suffix dimensions for an empty core'

        If SZ EQ 0 and SY EQ 0 and SX EQ 0 then nosuffix = 1     ; no suffix in the file

       if SX GE 0 then begin
        if not (SILENT) then begin
          text = string(SX,SY,SZ, format='(I4, " by",I4," by",I4)')
          message,'Suffix area is ' + text,/INFORM
        endif
       endif else begin
          message,fname+" has improper suffix dimensions, no data array read"
       endelse

      if nosuffix NE 1 then begin

       ; Grab the appropriate value for SUFFIX_BYTES
        ; and convert it to scalar:

       Sbits = v_str2num(Sbyte(Sb(0)))
       temp = Sbits(0)                              ; warning : this is given in BYTES for Qubes
       Sbits=(v_listpds(temp, count=cs, silent = silent))(0)     ; keep only the first element so far...
       if cs EQ -1 then Sbits = temp(0)     ; if only one value
       If Sbits NE 2 and Sbits NE 4 then $
           message,fname+" has non-standard suffix bytes", /info

; suffix items are now processed independently
;       SSbits = v_str2num(SSbyte(Sbp(0)), silent = silent)     ; UNCHECKED, SE 11/2000
;       temp = Ssbits(0)                              ; warning : this is given in BYTES for Qubes
;       Ssbits=(v_listpds(temp, count=cs, silent = silent))(0)     ; keep only the first element so far...
;       if cs EQ -1 then Ssbits = temp(0)     ; if only one value
;       If Ssbits GT Sbits then begin
;           message,fname+" has inconsistent suffix bytes", /info
;           Ssbits = sbits
;       endif

      ; Determine the byte ordering by checking the S_ITEM_TYPE value + scaling

       if SY GT 0 then begin
        case order of
          0:   SSbits = v_str2num(SSbyte(Sbp(0)), silent = silent)
          1:   SSbits = v_str2num(SBbyte(SBbp(0)), silent = silent)
        endcase
        temp = Ssbits(0)                              ; warning : this is given in BYTES for Qubes
        Ssbits=(v_listpds(temp, count=cs, silent = silent))(0)     ; keep only the first element so far...
        if cs EQ -1 then Ssbits = temp(0)     ; if only one value
        If SSbits GT Sbits then begin
            message,fname+" has inconsistent suffix bytes", /info
            Ssbits = sbits
        endif

        case order of
          0:   SSuffix_type = Ssmp_type(Ssp(0))
          1:   SSuffix_type = SBsmp_type(SBsp(0))
          2:   message, 'BSQ with suffix, not implemented'
        endcase

        Stype = (v_listpds(SSuffix_type, count=cs, silent = silent))(0) ;use only first element, should be all the same
        if cs EQ -1 then Stype = Ssuffix_type(0)     ; if only one value
        Ssuffix_type = v_typepds(Stype, Sbits, ITYPE = Sinteger_type, $
           Stype = SSample_type)

        case order of
          0:   bid =  Sbscale(Ssfp(0))
          1:   bid =  SBbscale(Bsfp(0))
        endcase
         SSscale = (v_listpds(bid, count=cs, silent = silent))
         If cs EQ 1 then SSscale = replicate(SSscale(0),SY) ;use only first element, should be all the same
         If cs EQ 0 then SSscale = replicate(1.,SY)                  ;no scaling
        case order of
          0:   bid =  Sbzero(Szp(0))
          1:   bid =  SBbzero(Bzp(0))
        endcase
         SSzero = (v_listpds(bid, count=cs, silent = silent))
         If cs EQ 1 then SSzero = replicate(SSzero(0),SY) ;use only first element, should be all the same
         If cs EQ 0 then SSzero = replicate(0., SY)                 ;no scaling
       endif

       if SX GT 0 then begin
        case order of
          0:   SBbits = v_str2num(SBbyte(SBbp(0)), silent = silent)
          1:   SBbits = v_str2num(SSbyte(Sbp(0)), silent = silent)
        endcase
        temp = SBbits(0)                              ; warning : this is given in BYTES for Qubes
        SBbits=(v_listpds(temp, count=cs, silent = silent))(0)     ; keep only the first element so far...
        if cs EQ -1 then SBbits = temp(0)     ; if only one value
        If SBbits GT Sbits then begin
            message,fname+" has inconsistent suffix bytes", /info
            SBbits = sbits
        endif

        case order of
          0:   BSuffix_type = SBsmp_type(SBsp(0))
          1:   BSuffix_type = Ssmp_type(Ssp(0))
          2:   message, 'BSQ with suffix, not implemented'
        endcase

         Stype = (v_listpds(Bsuffix_type, count=cs, silent = silent))(0) ;use only first element, should be all the same
         if cs EQ -1 then Stype = Bsuffix_type(0)     ; if only one value
         Bsuffix_type = v_typepds(Stype, Sbits, ITYPE = Binteger_type, $
            Stype = Bsample_type)

        case order of
          0:   bid =  SBbscale(BSfp(0))
          1:   bid =  Sbscale(Ssfp(0))
        endcase
         BSscale = (v_listpds(bid, count=cs, silent = silent))
         If cs EQ 1 then BSscale = replicate(BSscale(0), SX) ;use only first element, should be all the same
         If cs EQ 0 then BSscale = replicate(1., SX)               ;no scaling
        case order of
          0:   bid =  SBbzero(Bzp(0))
          1:   bid =  Sbzero(Szp(0))
        endcase
         BSzero = (v_listpds(bid, count=cs, silent = silent))
         If cs EQ 1 then BSzero = replicate(BSzero(0),SX) ;use only first element, should be all the same
         If cs EQ 0 then BSzero = replicate(0., SX)               ;no scaling
       endif


       if SZ GT 0 then begin
        case order of
          0:   SLbits = v_str2num(SLbyte(SLbp(0)), silent = silent)
          1:   SLbits = v_str2num(SLbyte(SLbp(0)), silent = silent)
        endcase
        temp = SLbits(0)                              ; warning : this is given in BYTES for Qubes
        SLbits=(v_listpds(temp, count=cs, silent = silent))(0)     ; keep only the first element so far...
        if cs EQ -1 then SLbits = temp(0)     ; if only one value
        If SLbits GT Sbits then begin
            message,fname+" has inconsistent suffix bytes", /info
            SLbits = sbits
        endif

        case order of
          0:   LSuffix_type = SLsmp_type(SLsp(0))     ; = bottom plane in both cases
          1:   LSuffix_type = SLsmp_type(SLsp(0))
          2:   message, 'BSQ with suffix, not implemented'
        endcase

         Stype = (v_listpds(Lsuffix_type, count=cs, silent = silent))(0) ;use only first element, should be all the same
         if cs EQ -1 then Stype = Lsuffix_type(0)     ; if only one value
         Lsuffix_type = v_typepds(Stype, Sbits, ITYPE = Linteger_type, $
            Stype = Lsample_type)

        case order of
          0:   bid =  SLbscale(LSfp(0))
          1:   bid =  SLbscale(Lsfp(0))
        endcase
         LSscale = (v_listpds(bid, count=cs, silent = silent))
         If cs EQ 1 then LSscale = replicate(LSscale(0), SZ) ;use only first element, should be all the same
         If cs EQ 0 then LSscale = replicate(1., SZ)               ;no scaling
        case order of
          0:   bid =  SLbzero(Lzp(0))
          1:   bid =  SLbzero(Lzp(0))
        endcase
         LSzero = (v_listpds(bid, count=cs, silent = silent))
         If cs EQ 1 then LSzero = replicate(LSzero(0),SZ) ;use only first element, should be all the same
         If cs EQ 0 then LSzero = replicate(0., SZ)               ;no scaling
       endif


      endif else suffix = 0B     ; reset return value

     endif else begin

     nosuffix = 1
     SX = (SY = (SZ = 0 ))
     suffix = 0B     ; reset return value

     endelse

;==================================================================
      ; Open file, retrieve offset to object

      PtObj =  V_POINTPDS(pointer(iter),record_bytes)
      datafile_found = (PtObj.filename NE '')

      if datafile_found NE 0 then begin               ; detached label

          fname = file_search(PtObj.filename, /fold)        ; works from IDL 5.5 and up
          temp = file_info(fname)
          ; If not found in current directory, try in label directory
          if not(temp.exists) or fname eq "" then begin
               DirName = v_getpath(filename, FBname)     ; get path to label under IDL ³ 5.4
               fname = file_search(Dirname+PtObj.filename, /fold)
               temp = file_info(fname)
          endif
          if not(temp.exists) or (fname eq "") then  message, 'ERROR - Could not open file: '+ PtObj.filename
          openr, unit, fname, ERROR=err, /GET_LUN, /Compress

      endif else begin          ; attached label

        openr, unit, fname, ERROR=err, /GET_LUN, /Compress
        if err NE 0 then begin
          message, 'ERROR - Could not re-open '+fname
        endif
      endelse


;       PtObj =  V_POINTPDS(pointer(iter),record_bytes)

      ; If datafile name found, assume it is in the same directory as the label
      ; Retrieve possible indication of directory in label filename.

;      datafile_found = (PtObj.filename NE '')
;      if datafile_found NE 0 then begin
;;            requires IDL 6.0!
;;          dir = File_DirName(fname, /mark)     ; look in label directory if set
;;          cd, current = bid
;;          Probably does not work Ñ SE Feb 2006
 ;     CASE !version.os_family OF
;       'unix' :Pathsep="/"
;       'MacOS' :Pathsep =":"
;       'Win' :Pathsep ="\"
;       ELSE: Pathsep =""     ; assumes data in the same directory
;      ENDCASE

;          dir = ''
;          if keyword_set(Ddir) then dir = Ddir+ pathsep    ; look in directory passed by keyword

;        fname = dir + PtObj.filename
;        openr, unit, fname, ERROR=err, /GET_LUN, /Compress

;        ; If the exact file name didn't work, try change case:

;        if err NE 0 then begin
;          fname = dir + strlowcase(PtObj.filename)
;          ; requires IDL 5.5
;          fname = dir + file_search(fname, /fold)
;          openr, unit, fname, ERROR=err, /GET_LUN, /Compress
;        endif

        ; If we still haven't successfully opened a file, signal an error and
        ; give up:

;        if err NE 0 then begin
;          message, 'ERROR - could not open data file: '+dir+ PtObj.filename
;        endif

;      endif else begin

        ; If there was no data file name, then we must have an offset from the
        ; beginning of the input file.  In this case we just re-open the input
        ; file, the name of which is still in 'fname':

;        openr, unit, fname, ERROR=err, /GET_LUN, /BLOCK, /Compress
;        if err NE 0 then begin
;          message, 'ERROR - Could not re-open '+fname
;        endif
;      endelse

      ;====================================================================

      ; OK, now we're ready to read the QUBE data.  We'll associate the opened
      ; data file unit with an array of the appropriate type based on BYTES per
      ; pixel, in 'bits', and the sample type, in 'sample_type':
      ; (SE warning: type length is given in bytes, not bits, in the Qube object -
      ;      the variable name 'bits' is inherited from Imagepds.pro).



       ; check that this IDL can handle unsigned integer types

       If core_type GE 12 and !version.release LT 5.2 then  $
             core_type = core_type -10
       If SX GT 0 then $
       If Bsuffix_type GE 12 and !version.release LT 5.2 then $
             Bsuffix_type = Bsuffix_type -10
       If SY GT 0 then $
       If Ssuffix_type GE 12 and !version.release LT 5.2 then $
             Ssuffix_type = Ssuffix_type -10


     ; Declare a single structure for any suffix configuration
     ; Set suffix to zero (some bytes are not used)
     ; + adjust ISM files configuration (suffix is a prefix)


     If nocube then begin     ; Qube core empty

        If SX NE 0 then begin
          S_line = Make_array(SX, Type = BSuffix_type)
          F_line = {S_line: S_line}
          F_frame = {F_line:replicate(F_line,Y)}
          S_line = 0B
          F_line = 0B
       endif
;else F_line = {C_line: C_line}


        If SY NE 0 then begin
          SS_frame = reform(Make_array(X, SY, Type = SSuffix_type), X, SY)
          F_frame = {SS_frame: SS_frame}
          SS_frame = 0B
        endif
;else F_frame = {F_line:replicate(F_line,Y)}
        F_Qube= replicate(F_frame,Z)
        F_frame = 0B

     endif else begin

        C_line = Make_array(X, Type = Core_type, /nozero)

        If SX NE 0 then begin
          S_line = Make_array(SX, Type = BSuffix_type, /nozero)
          If ISM then F_line = {S_line: S_line, C_line: C_line} else $
               F_line = {C_line: C_line, S_line: S_line}
        endif else F_line = {C_line: C_line}
        S_line = 0B

        If SY NE 0 then begin
          SS_frame = reform(Make_array(X, SY, Type = SSuffix_type, /nozero), X, SY)
          F_frame = {F_line:replicate(F_line,Y), SS_frame: SS_frame}
        endif else F_frame = {F_line:replicate(F_line,Y)}
        SS_frame = 0B
        F_line = 0B
        F_Qube= replicate(F_frame,Z)
        F_frame = 0B
;       Bottom plane shoud be appended here

     endelse


      ; Read data, place core and suffix in different qubes, release space

;       file = assoc(unit, F_Qube, PtObj.offset, /packed)
;       F_Qube = 0B
;       element = file(0)
;       free_lun, unit
;       file =0B

       If PtObj.offset NE 0 then temp = bytarr(PtObj.offset)
       If PtObj.offset NE 0 then readu, unit, temp
       temp = 0B
       readu, unit, F_qube

       If SZ NE 0 then begin     ; read bottom plane if present
         LSuffix = reform(Make_array(X, Y, SZ, Type = LSuffix_type, /nozero), X, Y, SZ)
         readu, unit, LSuffix
       endif


;help, /mem

; removed in Feb 2008, seems to duplicate V_swapData
       If not(nocube) then Core = F_Qube.F_line.C_line else core = 0B
       If SX NE 0 then begin
          BSuffix = F_Qube.F_line.S_line
;          If Sbits EQ 2 and Sbbits EQ 1 then BSuffix = BSuffix / 256
;          If Sbits EQ 4 and Sbbits EQ 2 then BSuffix = BSuffix / 256L^2
       endif
       If SY NE 0 then begin
          SSuffix = reform(F_Qube.SS_frame, X, SY,Z)
;          If Sbits EQ 2 and Ssbits EQ 1 then SSuffix = SSuffix / 256
;          If Sbits EQ 4 and Ssbits EQ 2 then SSuffix = SSuffix / 256L^2
       endif
       If SZ NE 0 then begin
;          If Sbits EQ 2 and SLbits EQ 1 then LSuffix = LSuffix / 256
;          If Sbits EQ 4 and SLbits EQ 2 then LSuffix = LSuffix / 256L^2
       endif

;       element = 0B
        F_Qube = 0B
;help, /mem

      ; If we didn't get a data type we can work with, convert it:

      CASE sample_type OF
        'MSB': V_swapData, core, SILENT = silent
        'LSB': V_swapData, core, /LSB, SILENT = silent
        'IEEE': V_swapData, core, SILENT = silent
        'PC': V_swapData, core, /LSB, SILENT = silent
        'VAX': v_vaxtoIEEE, core     ; always floats
          else: begin
                  message,'WARNING - Unrecognized SAMPLE_TYPE ('$
                          +smp_type(sp(0))+'), no conversion performed', /INF
                end
      ENDCASE

      If SX NE 0 then begin
      CASE  Bsample_type OF
        'MSB': V_swapData, Bsuffix, SILENT = silent
        'LSB': V_swapData, Bsuffix, /LSB, SILENT = silent
        'IEEE': V_swapData, Bsuffix, SILENT = silent
        'PC': V_swapData, Bsuffix, /LSB, SILENT = silent
        'VAX': v_vaxtoIEEE, Bsuffix     ; always floats
          else: begin
                  message,'WARNING - Unrecognized SUFFIX_TYPE ('$
                          +Bsample_type+'), no conversion performed', /INF
                end
      ENDCASE
      endif

      If SY NE 0 then begin
      CASE  Ssample_type OF
        'MSB': V_swapData, SSuffix, SILENT = silent
        'LSB': V_swapData, SSuffix, /LSB, SILENT = silent
        'IEEE': V_swapData, SSuffix, SILENT = silent
        'PC': V_swapData, SSuffix, /LSB, SILENT = silent
        'VAX': v_vaxtoIEEE, SSuffix     ; always floats
          else: begin
                  message,'WARNING - Unrecognized SUFFIX_TYPE ('$
                          +Ssample_type+'), no conversion performed', /INF
                end
      ENDCASE
      endif

      If SZ NE 0 then begin
      CASE  Lsample_type OF
        'MSB': V_swapData, LSuffix, SILENT = silent
        'LSB': V_swapData, LSuffix, /LSB, SILENT = silent
        'IEEE': V_swapData, LSuffix, SILENT = silent
        'PC': V_swapData, LSuffix, /LSB, SILENT = silent
        'VAX': v_vaxtoIEEE, LSuffix     ; always floats
          else: begin
                  message,'WARNING - Unrecognized SUFFIX_TYPE ('$
                          +Lsample_type+'), no conversion performed', /INF
                end
      ENDCASE
      endif


      ; Performs bit masking before conversions if required
      ; (may cause problems with unconventional IDL types)

        if bm(0) GT -1 then begin
          core = v_bmaskpds( core, mask)
        endif


     ; Convert signed bytes, not an IDL type in 5.3

      if (core_type EQ 1 AND integer_type EQ 'SIGNED') then begin

        ; Allocate an array of 2-byte integers to hold the final values:

        core = fix(core)
        fixitlist = WHERE(core GT 127)
        if fixitlist[0] GT -1 then begin
          core[fixitlist] = core[fixitlist] - 256
        endif

      endif


     ; Perform conversion to unsigned integers in IDL versions < 5.2

      if (!version.release LT 5.2) then begin

      if (core_type EQ 2  AND integer_type EQ 'UNSIGNED') then begin

        core = long(core)
        fixitlist = WHERE(core LT 0)
        if fixitlist[0] GT -1 then begin
          core[fixitlist] = core[fixitlist] + 65536
        endif

      endif else if (core_type EQ 3  AND  integer_type EQ 'UNSIGNED') then begin

        ; These must be converted to real numbers.  In order to preserve as
        ; much precision as possible, we convert to double-precision reals:
          ; (should now convert to long64)

        core = double(core)
        fixitlist = WHERE(core LT 0.D0)
        if fixitlist[0] GT -1 then begin
          core[fixitlist] = core[fixitlist] + 4.294967296D+9
        endif

      endif

      endif

      ; Now we scale the data we've read in using the corresponding
      ;  CORE_MULTIPLIER and CORE_BASE values from the label, unless the
      ; user has indicated /NOSCALE. Use fast function if IDL permits.


      if NOT keyword_set(NOSCALE) then begin

        if (!version.release GE 5.2) then begin      ; supposed to be faster

        if sfp(0) GT -1 then begin
          zero =  replicate(float(bzero(zp(0))), X, Y, Z)
          scl = bscale(sfp(0))
          if zero(0) NE 0. or scl(0) NE 1. then $
               blas_axpy, zero, scl, core
          core = zero
          zero = 0B
        endif

        if SX GT 0 then begin
        bid = total(fix(bsscale) EQ bsscale) ; if floating scaling factor
        if bid NE N_elements(BSscale) then Bsuffix = float(Bsuffix)
         for ij = 0, SX-1 do begin
          if BSzero(ij) NE 0. then Bsuffix(ij,*,*) = temporary(Bsuffix(ij,*,*)) + BSzero(ij)
          if BSscale(ij) NE 1. then Bsuffix(ij,*,*) = temporary(Bsuffix(ij,*,*)) * BSscale(ij)
         endfor
        endif

        if SY GT 0 then begin
        bid = total(fix(SSscale) EQ SSscale)  ; if floating scaling factor
        if bid NE N_elements(SSscale) then Ssuffix = float(Ssuffix)
         for ij = 0, SY-1 do begin
          if SSzero(ij) NE 0. then Ssuffix(ij,*,*) = temporary(Ssuffix(ij,*,*)) + SSzero(ij)
          if SSscale(ij) NE 1. then Ssuffix(ij,*,*) = temporary(Ssuffix(ij,*,*)) * SSscale(ij)
         endfor
        endif

        if SZ GT 0 then begin
        bid = total(fix(LSscale) EQ LSscale)  ; if floating scaling factor
        if bid NE N_elements(LSscale) then Lsuffix = float(Lsuffix)
         for ij = 0, SZ-1 do begin
          if LSzero(ij) NE 0. then Lsuffix(ij,*,*) = temporary(Lsuffix(ij,*,*)) + LSzero(ij)
          if LSscale(ij) NE 1. then Lsuffix(ij,*,*) = temporary(Lsuffix(ij,*,*)) * LSscale(ij)
         endfor
        endif

       endif else begin

        if sfp(0) GT -1 then begin
          scl = bscale(sfp(0))
          if scl NE 1.0 then core = temporary(core)*scl
        endif

        if zp(0) GT -1 then begin
          zero = bzero(zp(0))
          if zero NE 0 then core = temporary(core)+zero
        endif

       endelse

     endif

      ; Add the element read into the data structure, creating if needed:

      if qubes GT 1 then begin
        Stag = strtrim(string(iter+1),2)
        qube = 'qube'+Stag
        core = reform(core, X, Y, Z)
        data = CREATE_STRUCT(data,qube,core)
        core = 0B
;        if SX NE 0 then suffix = CREATE_STRUCT('B_suf'+Stag,Bsuffix)
;        Bsuffix  = 0B
;        if SY NE 0 then suffix = CREATE_STRUCT(suffix,'S_suf'+Stag,Ssuffix)

        Suf_exist = (size(suffix))(0)
        If SX NE 0 then begin
          BSuffT = 'B_suf'+Stag
;          suffix = Bsuffix     ; probably wrong here
          If suf_exist then suffix = CREATE_STRUCT(suffix, BSuffT,Bsuffix) $
               else suffix = CREATE_STRUCT(BSuffT,Bsuffix)
        endif
        If SY NE 0 then begin
          SSuffT = 'S_suf'+Stag
;          suffix = reform(Ssuffix, X, SY, Z)     ; probably wrong here
          If suf_exist then suffix = CREATE_STRUCT(suffix,SSuffT,Ssuffix) $
               else suffix = CREATE_STRUCT(SSuffT,Ssuffix)
        endif
        If SZ NE 0 then begin
          LSuffT = 'L_suf'+Stag
;          suffix = reform(Lsuffix, X, Y, SZ)     ; probably wrong here
          If suf_exist then suffix = CREATE_STRUCT(suffix,LSuffT,Lsuffix) $
               else suffix = CREATE_STRUCT(LSuffT,Lsuffix)
        endif
        Bsuffix  = 0B
        Ssuffix  = 0B
        Lsuffix  = 0B
      endif else begin
        data = reform(core, X, Y, Z)
        core = 0B
        If SX NE 0 then suffix = Bsuffix
        If SY NE 0 then suffix = reform(Ssuffix, X, SY, Z)
        If SZ NE 0 then suffix = reform(Lsuffix, X, Y, SZ)
        If SY*SX NE 0 then suffix = CREATE_STRUCT('B_suf',Bsuffix,'S_suf',Ssuffix)
        If SX*SZ NE 0 then suffix = CREATE_STRUCT('B_suf',Bsuffix,'L_suf',Lsuffix)
        Bsuffix  = 0B
        Ssuffix  = 0B
        Lsuffix  = 0B
      endelse
      iter = iter + 1

      ; End of processing for one qube.

    endif

    ; End of loop through QUBEs.


   close,unit
   free_lun,unit
  endfor

  ; Check to make sure we read as many Qubes as we were expecting:

  if iter(0) NE qubes(0) then message,$
    'ERROR - '+fname+': Number of qubes expected does not equal number found.'

  if qubes GT 1 then if not (SILENT) then help, /STRUCTURE, data

  ; Close the input unit:

  return, data

end
