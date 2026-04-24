function VIRTISPDS, input_filename, silent = silent, debug=debug

;+ $Id: virtispds.pro,v 1.19 2008/10/10 13:41:32 erard Exp $
;
; NAME
;   VIRTISPDS
;
; PURPOSE
;   Read a PDS-formatted VIRTIS data file in a structure.
;   - For image data returns label, number of images and images in a single structure.
;   - For Qubes data: returns label, data, suffix and HK list in a structure.
;    HK are grouped in elemental structures relative to each acquisition.
;    - If not VIRTIS data, return label + error code !err = -1
;
; CALLING SEQUENCE:
;   result=VIRTISPDS('filename')
;
; INPUTS:
; FILENAME = Scalar string containing the name of the PDS file to be read.
;                   (if not present, selection is made through an interactive dialog)
;
; OUTPUTS:
; result: structure containing the label and data
; For image data:
;   result.label : label of the PDS file
;   result.nimages : number of images in the file
;   result.images : a 3D array containing all the images of the file with size:
;        (nbimages,nbcolums,nbrows)
;
; For QUBE data:
;   result.label: label of the PDS file
;   result.qube_name: string array with cube name and unit (if data),
;                         or parameter names (if geometry)
;   result.qube_coeff: array providing scaling coefficient for geometry cubes (size=# of bands)
;   result.qube_dim: 3 or 2-elt array with cube dimensions
;   result.qube: data qube in the file (size=# of bands, # of lines, # of frames)
;   result. suf_name: list of HK names for H or M Ñ these tags are only indicative, and should not
;               be used as data pointers (may change in the future; the order is permanent, though)
;   result.suf_dim: 3 or 2-elt array with suffix dimensions
;   result.suffix: suffix of the data qube, reformatted (the first dimension contains
;               a complete group of HK) Size = # of HK, # of HK structure/frame, # of frames
;
;  An HK structure (for a given spectrum) is plotted with: plot (or tvscl), result.suffix(*,n,p)
;  A given HK is plotted against time with: plot, result.suffix(m,*,*)
;  VEx H calibrated cubes & suffices are reformed to 2D arrays.
;  VEx M calibrated files suffices are reformed to 2D (1 single Scet per frame)
;
; For table data:
;   result.label : label of the PDS file
;   result.column_names : names of columns
;   result.table : a 2D array containing the table
;
; KEYWORDS:
;    SILENT = suppresses messsages.
;    DEBUG = checks file length
;
; EXAMPLE
;   tt=virtispds('AMI_EAE1_001327_00001_00100.IMG')
;   If !err EQ -1 then  message, 'Not a VIRTIS file'      ; must be checked immediately
;
; PROCEDURES USED:
;   V_READPDS library routines. Probably requires IDL 5.4 (works under 5.5)
;
; MODIFICATION HISTORY:
; 	Written by:	Yann Hello, sept 1999 (for H test images)
;  Updated: S. Erard, sept 2000 (works under IDL 5.1)
;  Handles M and H Qubes + suffixes: S. Erard, Sept 2001-Jan 2002
;  Minor corrections to suffix names: S. Erard, July 2005
;  S. Erard, LESIA, Nov 2005:
;          Now returns structure with only label + error code if data are not from VIRTIS
;  F. Henry, LESIA, Dec 2005:
;          Added keyword SILENT, filter messages
;  S. Erard, LESIA, Dec 2005:
;          Tentative fix for new labels, including various objects
;           (may change with future calibrated M format)
;          Added flexibility to read some VIRTIS calibration files
;           (using non-compliant instrument names)
;          Implemented H individual spectra and calibrated cubes formats.
;  S. Erard, LESIA, Jan 2006:
;          Only accepts plain VIRTIS files, again
;          Files must be generated from the integrated instrument through the ME
;          Those include VVEx M-calibration files, that use non-compliant instrument ID
;             Otherwise returns !err = -1 + label alone in structure
;  S. Erard, LESIA, Feb 2006:
;          Support for (future) multitable files, including calibration files.
;          Added field QUBE_NAME in result.
;  SE, LESIA, April 2006:
;          Added fields QUBE_DIM and SUF_DIM in result to store qube/suffix dimensions
;          Ñ used to preserve last dimension if degenerated (forcing array dimensions
;          apparently does not work inside structures... ).
;  SE, LESIA, June 2006:
;         Implemented support for geometry cubes.
;         Also returns a list of geometrical parameters
;          + a vector of scaling coefficients to standard units (in km, degreees, h of local time)
;  SE, LESIA, July 2006:
;         Updated geometry cubes format (41 frames for H).
;         Now handles calibrated H qubes with SCET in backplane. Data is (#channels, #spectra)
;         SCET array is (3, #spectra). Still supports previous format.
;  SE, LESIA, August 2006:
;         Now handles calibrated M qubes with SCET in backplane. Data is (#channels, #lines, # frames).
;          SCET array is (3, #frame)
;  SE, LESIA, Sept 2006: Added option DEBUG to check file length
;  SE, LESIA, Jan 2007: Fixed for "2D" cubes and suffices (H calibrated with degenerated 2nd dim)
;  SE, LESIA, Feb 2007: Extended default dialogue to all possible types of Virtis file
;  SE, LESIA, Nov 2007: Tentative fix for uncorrect VEx geometry files with inverted local time.
;                       Cannot insure that all situations are handled properly, though
;                       (local time should increase westward, i.e. with decreasing longitude)
;                       Added support for Rosetta geometry files (Mars and Earth)
;  SE, LESIA, Jan 2008: Fix for inverted local time in updated files.
;  SE, LESIA, Feb 2008: 1) Filter older VEx H geometry files in nominal mode
;                           (generated with new EGSE and geovirtis < 3.3)
;                         Those have inaccurate SCET interpolation and are off by up to 1 repetition time.
;                       2) Now supports possible future format for M calibrated files (1 qube+back/bottom planes)
;  AC, IASF,  Oct 2008: Read detached PDS label (*.LBL) if it exists
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


On_error, 2                    ;2: Return to user, 0: debug

silent = keyword_set(silent)
debug = keyword_set(debug)

; Check for filename input

if N_params() LT 1 then begin
   filename = DIALOG_PICKFILE(/READ, /MUST_EXIST, FILTER = ['*.QUB','*.CAL','*.PRE','*.GEO', '*.*'])
   if filename eq "" then return, -1
endif else filename = input_filename ; make sure input_filename is not changed

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

;if (not silent) then print, filename
; Read the label
lbl=v_headpds(filename, silent=silent)
data=create_struct('label',lbl)

;	Use V_READPDS to extract all objects

; First check this is a Virtis file...
  VIRTIS = 0
  Instru = v_pdspar(lbl,'INSTRUMENT_ID')
  Instru = strcompress(Instru, /rem)     ; filter spaces
  Instru = (strsplit(Instru, '"', /extract))(0)     ; filter possible quotes
;  Instru = strmid(strupcase(instru(0)),0,6)     ; allows for some variations...
  If strupcase(instru(0)) EQ 'VIRTIS' then VIRTIS = 1
;         Accepts VVEx M ground calibrations (integrated instrument)
  If strupcase(instru(0)) EQ 'VIRTISFORVENUS' then VIRTIS = 1
  If VIRTIS EQ 0 then begin
    Instru = v_pdspar(lbl,'INSTRUMENT_NAME')
    Instru = strcompress(Instru, /rem)     ; filter spaces
    Instru = (strsplit(Instru, '"', /extract))(0)     ; filter possible quotes
;    Instru = strmid(strupcase(instru(0)),0,6)     ; allows for some variations...
    If strupcase(instru(0)) EQ 'VIRTIS' then VIRTIS = 1
    If VIRTIS EQ 0 then begin
        if (not silent) then message, $
          'This function handles only plain VIRTIS data files', /cont
       !err = -1
       return, data
     endif
  endif
  Scraft = v_pdspar(lbl,'MISSION_ID')    ; could be VEX or ROSETTA Ñ uppercase, no quotes
  Scraft = strcompress(Scraft, /rem)     ; filter spaces
  Scraft = (strsplit(Scraft, '"', /extract))(0)     ; filter possible quotes

  VH = 0
  Instru = v_pdspar(lbl,'CHANNEL_ID')
  Instru = strsplit(Instru, '"', /extract)     ; filter possible quotes
  If strupcase(instru(0)) EQ 'VIRTIS_H' then VH = 1     ; identifies channel
  QubeType = v_pdspar(lbl,'STANDARD_DATA_PRODUCT_ID')     ; identifies data vs geometry
  QubeType = strsplit(QubeType, '"', /extract)     ; filter possible quotes
  QubeType = strupcase(QubeType)     ; either VIRTIS DATA or VIRTIS GEOMETRY
  ProcLev = v_pdspar(lbl, 'PROCESSING_LEVEL_ID')     ; identifies raw (2) versus calibrated (³ 3) data
  If ProcLev EQ "" then ProcLev = 2      ; (older labels)

; ... then read the file (only if Virtis)
  r = v_readpds(filename, listobj = listo, suffix=suf, /silent)

Qdone = 0
; Possible list of objects in Virtis files:
; listo(0) = QUBE - ground calibration+early flight format, up to late 2005
; listo(0) = HISTORY
;  + listo(1) = QUBE with sideplane - final flight format, in EGSE 2006
; listo(0) = HISTORY
;  +listo(1) = TABLE (binary)
;  +listo(2) = QUBE - Calibrated H format, late 2005 (preliminary)
; listo(0) = HISTORY
;  +listo(1) = TABLE (binary)
;  +listo(2) = QUBE with backplane - Calibrated H format, late 2006
; listo(0) = HISTORY
;  +listo(1) = QUBE, no suffix
;  +listo(2) = QUBE with backplane - Calibrated M format, late 2006
; listo(0) = HISTORY
;  +listo(1) = QUBE with backplane+bottomplane - Potential calibrated M format, Feb 2008
; listo(0) = HISTORY
;  +listo(1) = TABLE (ascii) - Extracted H spectrum, late 2005
; listo(0) = QUBE, no suffix - geometry files, 2006
; listo(0:N) = TABLE - H-Calibration files, 2006 (TBD)

Nobj = (size(listo, /dim))(0)     ; # of objects present, scalar
If Nobj EQ 0 then Nobj =1     ; if only one object, listo is scalar & size returns 0
if (not silent) then print, 'Number of objects found: ', Nobj
Ntab = 0      ; table count

for ii = 0, Nobj-1 do begin     ; loop on present objects

If Qdone then continue     ; all cubes are processed on first pass

CASE listo(ii) OF      ; Process found objects in sequence

'HISTORY':           ; if history present, don't store it (should be empty)

'COLUMN':           ; Should appear only as subobjects of TABLE

'TABLE': begin           ; if table present, group columns in one array

; Handles any # of tables in r, any dimension
 Ttab='TABLE'     ; default is a single table
 if where(tag_names(r) EQ 'TABLES') NE -1 then  $
     if r.tables NE 1 then Ttab='TABLE'+string(Ntab, f='(I0)')
 iTab = where(tag_names(r) EQ Ttab)
 data=create_struct(data,(tag_names(r))(iTab-1),r.(iTab-1))
 Ncol= n_tags(r.(iTab))
 Nrow = size(r.(iTab).(0), /dim)
 Table = fltarr(Ncol, Nrow)
 for ij = 0, Ncol-1 do Table(ij,*) = r.(iTab).(ij)
 data=create_struct(data,(tag_names(r))(iTab),Table)
 Ntab = Ntab +1

end


'IMAGE': begin           ; if images, stack them into a single structure
                         ; (older H-subsystem format, should not arrive here)
if n_tags(r) eq 0 then begin
 nimages=1
 s=size(r)
endif else begin
 nimages=r.images
 s=size(r.image0)
endelse

nbcol=s(1)
nblig=s(2)
If !version.release ge 5.2 then im=uintarr(nimages,nbcol,nblig) $
 else im=lonarr(nimages,nbcol,nblig)
if nimages eq 1 then im(0,*,*)=r else for i=0,nimages-1 do im(i,*,*)=r.(i+1)
data=create_struct(data,'nimages',nimages)
data=create_struct(data,'images',im)
end


'QUBE': begin           ; if file contains qubes, arrange everything in a structure
Qdone = 1

if QubeType EQ "VIRTIS GEOMETRY" then begin    ; preprocess geometry cubes

GEOM_nam=['Surf longit, corner1',$     ; common to M and H
'Surf longit, corner2',$
'Surf longit, corner3',$
'Surf longit, corner4',$
'Surf latit, corner1',$
'Surf latit, corner2',$
'Surf latit, corner3',$
'Surf latit, corner4',$
'Surf longit, center',$
'Surf latit, center',$
'Incidence at surf',$
'Emergence at surf',$
'Phase at surf',$
'Elevation on surf layer',$
'Slant distance',$
'Local time',$
'Cloud longit, corner1',$
'Cloud longit, corner2',$
'Cloud longit, corner3',$
'Cloud longit, corner4',$
'Cloud latit, corner1',$
'Cloud latit, corner2',$
'Cloud latit, corner3',$
'Cloud latit, corner4',$
'Cloud longit, center',$
'Cloud latit, center',$
'Incidence on clouds',$
'Emergence on clouds',$
'Phase on clouds',$
'Elevation below clouds',$
'Right ascension',$
'Declination']

If  not(VH) then begin
GEOM_nam= [GEOM_nam,['M-common frame']]

endif else begin
bid = ['Data SCET, 1',$
'Data SCET, 2',$
'UTC, 1',$
'UTC, 2',$
'Sub S/C longit',$
'Sub S/C latit',$
'Slit orientation',$
'Sun-boresight angle, X',$
'Sun-boresight angle, Y']
GEOM_nam= [GEOM_nam,bid]
endelse


If Scraft NE 'VEX' then begin         ; Rosetta geometry (Mars and Earth at least)

GEOM_nam=['Surf longit, corner1',$     ; common to M and H
'Surf longit, corner2',$
'Surf longit, corner3',$
'Surf longit, corner4',$
'Surf latit, corner1',$
'Surf latit, corner2',$
'Surf latit, corner3',$
'Surf latit, corner4',$
'Surf longit, center',$
'Surf latit, center',$
'Incidence vs local normal',$
'Emergence vs local normal',$
'Phase',$
'Incidence vs ellipsoid normal',$
'Emergence vs ellipsoid normal',$
'Incidence vs Mars center',$
'Emergence vs Mars center',$
'Elevation on surf layer',$
'Slant distance',$
'Local time',$
'Right ascension',$
'Declination']

If  not(VH) then begin
GEOM_nam= [GEOM_nam,['M-common frame']]

endif else begin
bid = ['Data SCET, 1',$
'Data SCET, 2',$
'UTC, 1',$
'UTC, 2',$
'Sub S/C longit',$
'Sub S/C latit',$
'Slit orientation',$
'Sun-boresight angle, X',$
'Sun-boresight angle, Y']
GEOM_nam= [GEOM_nam,bid]
endelse

endif

data = create_struct(data,'qube_name',geom_nam)


; provides coefficients to convenient units (degrees, km, local h)     ; VEx
Geo_coef = fltarr(41)     ; maximum length
Geo_coef(0:12) = replicate(0.0001, 13)
Geo_coef(13:14) = replicate(0.001, 2)
Geo_coef(15) = 0.00001
Geo_coef(16:28) = replicate(0.0001, 13)
Geo_coef(29) = 0.001
Geo_coef(30:31) = replicate(0.0001, 2)
Geo_coef(32) = 1

If VH then  begin
 Geo_coef(33:35) = 1
 Geo_coef(36:40) = replicate(0.0001, 5)
endif
Geo_coef = Geo_coef(0:N_elements(Geom_nam)-1)     ; retain current length


If Scraft NE 'VEX' then begin                ; Rosetta coefficients
; provides coefficients to convenient units (degrees, km, local h)
Geo_coef = fltarr(31)     ; maximum length
Geo_coef(0:16) = replicate(0.0001, 17)
Geo_coef(17:18) = replicate(0.001, 2)
Geo_coef(19) = 0.00001
Geo_coef(20:21) = replicate(0.0001, 2)
Geo_coef(22) = 1

If VH then  begin
 Geo_coef(23:25) = 1
 Geo_coef(26:30) = replicate(0.0001, 5)
endif
Geo_coef = Geo_coef(0:N_elements(Geom_nam)-1)     ; retain current length
endif

data = create_struct(data,'qube_coeff',geo_coef)

endif     ; done with geometry vectors


;if size(r, /type) EQ 8 then begin              ; if not single qube (calibrated files)

If ProcLev GE 3 then begin                    ; calibrated data file
 CASE VH of
 0: begin                ; Store M spectral reference to table, preserve 3D
    if size(r, /type) EQ 8 then begin   ; Initial M-calibrated format, 2 qubes+backplane
     szq = size(r.qube1, /dim)          ; M spectral reference cube
     data=create_struct(data,'table',r.qube1)
     bid= v_pdspar(lbl, 'CORE_NAME')
     bid1= v_pdspar(lbl, 'CORE_UNIT')
     data = create_struct(data,'qube_name',[bid(1), bid1(1)])     ; data only
     szq = size(r.qube2, /dim)     ; data cube
     data = create_struct(data,'qube_dim', szq)
     data=create_struct(data,'qube',r.qube2)
    endif else begin                    ; Possible new format, 1 qube+backplane/bottomplane
     szq = size(suf.L_suf, /dim)          ; M spectral reference cube
     data=create_struct(data,'table',suf.L_suf)
     bid= v_pdspar(lbl, 'CORE_NAME')
     bid1= v_pdspar(lbl, 'CORE_UNIT')
     data = create_struct(data,'qube_name',[bid(0), bid1(0)])     ; data only
     szq = size(r, /dim)     ; data cube
     data = create_struct(data,'qube_dim', szq)
     data=create_struct(data,'qube',r)
     suf=create_struct('b_suf2',Uint(suf.B_suf))     ; change SCET suffix name for later
    endelse
 end
 1: begin                ; Convert H calibrated qubes to 2D
     bid= v_pdspar(lbl, 'CORE_NAME')
     bid1= v_pdspar(lbl, 'CORE_UNIT')
     data = create_struct(data,'qube_name',[bid, bid1])
     szq = size(r.qube, /dim)
     data = create_struct(data,'qube_dim', [szq(0), szq(1)*szq(2)])
     data=create_struct(data,'qube',reform(r.qube,szq(0), szq(1)*szq(2)))
 end
 endcase

endif else begin                              ; raw data and geometry
     data = create_struct(data,'qube_dim', size(r, /dim))
     data=create_struct(data,'qube',reform(r,size(r, /dim)))      ; if qube alone
endelse

; corrects bugs in some VEx geometry files
if QubeType EQ "VIRTIS GEOMETRY" and Scraft EQ 'VEX' then begin
  Ctime = v_pdspar(LBL, 'PRODUCT_CREATION_TIME')
  temp = v_listpds(v_pdspar(LBL, 'SOFTWARE_VERSION_ID'))
  temp0 = strpos(temp, 'GEOVIRTIS')
;  Gind = (where(temp0 GE 0))(0)     ; first occurence
  Gind = (where(temp0 GE 0))
  szz = size(Gind, /dim)
  Gind = (Gind)(szz-1)     ; last occurence of geovirtis string
  Gvers = (strsplit(temp(Gind), '"', /extract))(0)      ; filter quotes
  Gvers1 = (strsplit(Gvers, '_', /extract))(1)      ; filter quotes
;  Chann = (strsplit(v_pdspar(LBL, "CHANNEL_ID"), '"', /extract))(0)

; Block VT files with uncorrect SCET interpolation
  If ctime GT '2007-05-01T00' and Gvers1 LT 3.3 and VH EQ 1 then begin
    if not(DEBUG) then begin
     print, ' '
     message, 'CORRUPTED VEx VT GEOMETRY FILE Ñ please download updated version ***'
    endif
  endif

  If ctime GT '2007-05-01T00' and Gvers1 LT 3.0 then begin
    data.qube(15, *,*) = 24./data.qube_coeff(15) - data.qube(15, *,*)
    if (not silent) then begin
     print, ' '
     message, 'VEx geometry fixed for local time, but you should download updated version ***', /info
    endif
  endif

endif

sz = size(suf)
If sz(0) NE 0 then begin     ; PROCESS SUFFIX IF PRESENT

;If sz(1) EQ 3 then begin     ; H calibrated data file
If ProcLev GE 3 then begin     ; calibrated data file

HK_nam=['Data SCET-1',$
'Data SCET-2',$
'Data SCET-3']

; Reform SCET suffix
if VH then begin              ; expected to be 2D
If sz(0) EQ 3 then sz(2) =sz(2)*sz(3)
 data=create_struct(data,'suf_name',HK_nam)
 data=create_struct(data,'suf_dim', [sz(1), sz(2)])
 data=create_struct(data,'suffix',reform(suf, sz(1), sz(2)))
endif else begin
 sz = size(suf.b_suf2)
 data=create_struct(data,'suf_name',HK_nam)
 data=create_struct(data,'suf_dim', [3,sz(3)])
 data=create_struct(data,'suffix',reform(suf.b_suf2(0,0:2,*), 3, sz(3)))
endelse

; can be turned to SCET with      sc3 = v_scet(data.suffix(0,*,*),data.suffix(1,*,*),data.suffix(2,*,*))



endif else begin     ; Regular raw data file

LstHK = 82                           ; length of HK structure for M
If VH eq 1 then LstHK = 72  ; and for H
Neff = ( sz(1) / LstHK ) * LstHK  - 1 ; # of HK in one sideplane row
NStruct = ( sz(1) / LstHK ) * sz(2)  ; # of HK structures per frame
suf1 = reform(suf(0:Neff,*,*), LstHK, NStruct, sz(3)) ; filter the empty ends of row

If !version.release ge 5.2 then suf1 = Uint(suf1)     ; corrects an initial error in M labels
; keep only non-empty HK structures
temp=fltarr(Nstruct)
for j=0, NStruct-1 do temp(j)=TOTAL(ABS(float(suf1(*,j,*))))
tempp = where(temp EQ 0)
if tempp(0) EQ -1 then tempp(0) = Nstruct
if (not silent) then print, format='("Keeping", I4, " HK blocks per frame")', tempp(0)
if tempp(0) LE 0 then suf1=0 else suf1 = reform(suf1(*,0:tempp(0)-1,*),LstHK,tempp(0),sz(3))

;r=swap_endian(r)          ; TEMPORARY, swap data core
;               (corrects a bug of the EGSE in the formatting of the early calibration files)


If VH then begin
HK_nam=['Data SCET-1',$
'Data SCET-2',$
'Data SCET-3',$
'Acquisition ID',$
'# of subslices + 1st serial #',$
'Data Type',$
'SPARE',$
'ME_default HK SCET-1',$
'ME_default HK SCET-2',$
'ME_default HK SCET-3',$
'V_MODE',$
'ME_PWR_STAT',$
'ME_PS_TEMP',$
'ME_DPU_TEMP',$
'ME_DHSU_VOLT',$
'ME_DHSU_CURR',$
'EEPROM_VOLT',$
'IF_ELECTR_VOLT',$
'SPARE',$
'H_ME_general HK SCET-1',$
'H_ME_general HK SCET-2',$
'H_ME_general HK SCET-3',$
'H_ECA_STAT',$
'H_COOL_STAT',$
'H_COOL_TIP_TEMP',$
'H_COOL_MOT_VOLT',$
'H_COOL_MOT_CURR',$
'H_CCE_SEC_VOLT',$
'SPARE',$
'H_HK_report SCET-1',$
'H_HK_report SCET-2',$
'H_HK_report SCET-3',$
'HKRq_Int_Num2',$
'HKRq_Int_Num1',$
'HKRq_Bias',$
'HKRq_I_Lamp',$
'HKRq_I_Shutter',$
'HKRq_PEM_Mode',$
'HKRq_Test_Init',$
'HK_Rq_Device/On',$
'HKRq_Cover',$
'HKMs_Status',$
'HKMs_V_Line_Ref',$
'HKMs_Vdet_Dig',$
'HKMs_Vdet_Ana',$
'HKMs_V_Detcom',$
'HKMs_V_Detadj',$
'HKMs_V+5',$
'HKMs_V+12',$
'HKMs_V+21',$
'HKMs_V-12',$
'HKMs_Temp_Vref',$
'HKMs_Det_Temp',$
'HKMs_Gnd',$
'HKMs_I_Vdet_Ana',$
'HKMs_I_Vdet_Dig',$
'HKMs_I_+5',$
'HKMs_I_+12',$
'HKMs_I_Lamp',$
'HKMs_I_Shutter/Heater',$
'HKMs_Temp_Prism',$
'HKMs_Temp_Cal_S',$
'HKMs_Temp_Cal_T',$
'HKMs_Temp_Shut',$
'HKMs_Temp_Grating',$
'HKMs_Temp_Objective',$
'HKMs_Temp_FPA',$
'HKMs_Temp_PEM',$
'HKDH_Last_Sent_Request',$
'HKDH_Stop_Readout_Flag',$
'SPARE',$
'SPARE']

endif else $
HK_nam=['Data SCET-1',$
'Data SCET-2',$
'Data SCET-3',$
'Acquisition ID',$
'# of subslices + 1st serial #',$
'Data Type',$
'SPARE',$
'ME_default HK SCET-1',$
'ME_default HK SCET-2',$
'ME_default HK SCET-3',$
'V_MODE',$
'ME_PWR_STAT',$
'ME_PS_TEMP',$
'ME_DPU_TEMP',$
'ME_DHSU_VOLT',$
'ME_DHSU_CURR',$
'EEPROM_VOLT',$
'IF_ELECTR_VOLT',$
'SPARE',$
'M_ME_general HK SCET-1',$
'M_ME_general HK SCET-2',$
'M_ME_general HK SCET-3',$
'M_ECA_STAT',$
'M_COOL_STAT',$
'M_COOL_TIP_TEMP',$
'M_COOL_MOT_VOLT',$
'M_COOL_MOT_CURR',$
'M_CCE_SEC_VOLT',$
'SPARE',$
'MVIS_HK_report SCET-1',$
'MVIS_HK_report SCET-2',$
'MVIS_HK_report SCET-3',$
'M_CCD_VDR_HK',$
'M_CCD_VDD_HK',$
'M_+5_VOLT',$
'M_+12_VOLT',$
'M_-12_VOLT',$
'M_+20_VOLT',$
'M_+21_VOLT',$
'M_CCD_LAMP_VOLT',$
'M_CCD_TEMP_OFFSET',$
'M_CCD_TEMP',$
'M_CCD_TEMP_RES',$
'M_RADIATOR_TEMP',$
'M_LEDGE_TEMP',$
'OM_BASE_TEMP',$
'H_COOLER_TEMP',$
'M_COOLER_TEMP',$
'M_CCD_WIN_X1',$
'M_CCD_WIN_Y1',$
'M_CCD_WIN_X2',$
'M_CCD_WIN_Y2',$
'M_CCD_DELAY',$
'M_CCD_EXPO',$
'M_MIRROR_SIN_HK',$
'M_MIRROR_COS_HK',$
'M_VIS_FLAG_ST',$
'SPARE',$
'MIR_HK_report SCET-1',$
'MIR_HK_report SCET-2',$
'MIR_HK_report SCET-3',$
'M_IR_VDETCOM_HK',$
'M_IR_VDETADJ_HK',$
'M_IR_VPOS',$
'M_IR_VDP',$
'M_IR_TEMP_OFFSET',$
'M_IR_TEMP',$
'M_IR_TEMP_RES',$
'M_SHUTTER_TEMP',$
'M_GRATING_TEMP',$
'M_SPECT_TEMP',$
'M_TELE_TEMP',$
'M_SU_MOTOR_TEMP',$
'M_IR_LAMP_VOLT',$
'M_SU_MOTOR_CURR',$
'M_IR_WIN_Y1',$
'M_IR_WIN_Y2',$
'M_IR_DELAY',$
'M_IR_EXPO',$
'M_IR_LAMP_SHUTTER',$
'M_IR_FLAG_ST',$
'SPARE']

data=create_struct(data,'suf_name',HK_nam)
data=create_struct(data,'suf_dim',size(suf1, /dim))
data=create_struct(data,'suffix',suf1)

endelse
endif

end

ENDCASE

endfor

; 	Return file data and exit program

if (not silent) then begin
  print, ' '
  message, 'File in use: '+filename, /info
  help, /struc, data
endif
if keyword_set(debug) and not(silent) then begin
  FRec = v_pdspar(lbl, 'file_records') * 512LL
  Finfo = file_info(filename)
  Fsize = Finfo.size
  print, 'File size from label:', FRec
  print, 'File size on disk:', Fsize
  print, 'Label - Actual (should be > 0 < 512):', Frec-Fsize
endif
return, data
end
