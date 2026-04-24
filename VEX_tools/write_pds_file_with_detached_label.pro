;+
; NAME:
;     write_pds_file_with_detached_label
;
; PURPOSE:
;     Write pds cube file (3-D) with a detached PDS label in a separate file with extension ".LBL"
;     The routine detects automatically the format of the cube to write: Float, Integer or Long.
;     Output file can be read with VirtisPDS SW package or a similar PDS reader.
;     Optionally an ENVI header can also be created so that file is also readable directly from ENVI
;
; CALLING SEQUENCE:
;     write_pds_file_with_detached_label [,QUBE=input_cube][,FILENAME=filename][,/ENVI_HEADER]
;                                        [,BNAMES=bnames][,WL=wl][,WAVELENGTH_UNIT=wavelength_unit][,UNIT=unit][,NAME=name]
;                                        [,/FORCE_FLOAT][,/FORCE_INTEGER][,/FORCE_LONG][,DISPLAY_LABEL=0][,/OPEN_ENVI]
;
; INPUTS:
;     none
;
; OPTIONAL KEYWORDS:
;     QUBE: variable containing cube (3-D array). Format must be [BAND,SAMPLES,LINES] in either integer or floating point
;           If not given, the routine prompst to select a cube from ENVI
;
;     FILENAME: path and filename for the output pds file. Detached label will have same filename with extension ".LBL"
;               By default the routine prompts for the output filename
;
;     BNAMES: band names to be written in the label
;             In PDS label it is written as BAND_NAME keyword
;
;     WL: wavelength values to be associated to each band
;         In PDS label it is written as BAND_BIN_CENTER keyword
;
;     UNIT: unit of the cube contents (e.g. "W/m^2/sr/um", "KELVIN") to be written in the label
;           In PDS label it is written as CORE_UNIT keyword ("UNK" is used by default)
;
;     NAME: name of the cube contents (e.g. RADIANCE, RAW_DATA_NUMBER) to be written in the label
;           In PDS label it is written as CORE_NAME keyword ("UNK" is used by default)
;
;     WAVELENGTH_UNIT: unit of the wavelength to be written when wavelengths are given
;                      In PDS label it is written as BAND_BIN_UNIT keyword (MICROMETER is used by default)
;
;     ENVI_HEADER: set to create an ENVI header so that file is also readable directly from ENVI
;
;     OPEN_ENVI: open file in ENVI once file writing is completed (ignored if ENVI_HEADER is disabled)
;
;     FORCE_FLOAT: the routine detects automatically the format Float or Integer. Set this to force writing in FLOAT format(4B).
;
;     FORCE_LONG : the routine detects automatically the format Float or Integer. Set this to force writing in LONG format (4B).
;
;     FORCE_INTEGER: the routine detects automatically the format Float or Integer. Set this to force writing in INT format (2B).
;
;     DISPLAY_LABEL: by default the routine shows a popup window with the PDS label created. Set to 0 to cancel popup.
;
; OUTPUTS:
;     In filename: output file written in binary format, either float or integer
;     In filename with extension ".LBL" : detached PDS label with parameters of the cube file
;     In filename with extension ".HDR" : detached ENVI header with parameters of the cube file (optional)
;
; EXAMPLE:
;     See example procedure at the bottom of this file. Run "write_pds_file_with_detached_label_EXAMPLE"
;
; PROCEDURE:
;     Needs external function "select_cube_from_envi.pro" if no input cube is given
;     Uses external function "idl_envi_setup_head" to write ENVI header
;
; RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;     Output file can be read with VirtisPDS SW package or a similar PDS readed.
;
; MODIFICATION HISTORY:
;     Written by Alejandro Cardesin, IASF-INAF, July 2008, alejandro.cardesin @ iasf-roma.inaf.it
;     Modified 29 Jul 2008, AC, corrected problem with WL=-1
;     Modified 28 Nov 2008, AC, solved bug with invalid Band Name characters ",{}="
;     Modified 03 Dec 2008, AC, now uses external routine "idl_envi_setup_head" to write ENVI header
;                               added OPEN_ENVI
;-
pro write_pds_file_with_detached_label, QUBE=input_cube, FILENAME=filename, $
                                        ENVI_HEADER=envi_header  , $
                                        BNAMES=bnames,$
                                        WL=wl,$
                                        WAVELENGTH_UNIT=wavelength_unit,$
                                        UNIT=unit,$
                                        NAME=name,$
                                        DISPLAY_LABEL=display_label, $
                                        OPEN_ENVI=open_envi,$
                                        FORCE_FLOAT=force_float  ,$
                                        FORCE_LONG=force_long    ,$
                                        FORCE_INTEGER=force_int

	;;--------------------------------------------------------------------------
	;; Select cube from ENVI if no cube is given
	;;--------------------------------------------------------------------------
	IF N_ELEMENTS(input_cube) EQ 0 THEN input_cube = select_cube_from_envi(/BSL,bnames=bnames,WL=wl) ;use [B,S,L] format
	if n_elements(input_cube) eq 1 && input_cube eq -1 then return

	if SIZE(input_cube,/N_DIM) lt 2 then message, "ERROR: input cube must be at least a 2-D array"


	;;--------------------------------------------------------------------------
	;; Select ouput filepath if not given
	;;--------------------------------------------------------------------------
	if N_elements(filename) eq 0 then begin
		if !version.os_family eq "Windows" then path_in="dummy" ;set dummy file for windows machine (just to read last open directory)
		filename=dialog_pickfile(path=path_in,/WRITE, /OVERWRITE_PROMPT, FILE="FILENAME.DAT", FILTER=['*.QUB','*.CAL','*.DAT'])
	endif
	if filename eq "" then return

	; keep input variable
	cube = input_cube


	;;--------------------------------------------------------------------------
	;; GET QUBE DIMENSIONS
	;;--------------------------------------------------------------------------
	; cube format must be (B,S,L)
	ndims= size(cube, /N_DIM)
	if ndims eq 3 then begin
		dims  = size(cube, /DIM)
		nb = dims[0] ; number of bands
		ns = dims[1] ; number of samples
		nl = dims[2] ; number of lines
	endif else begin
		dims  = size(cube, /DIM)
		nb = 1       ; number of bands
		ns = dims[0] ; number of samples
		nl = dims[1] ; number of lines
	endelse
	; total number of elements
	cube_size = nb*ns*nl


	;;--------------------------------------------------------------------------
	;; SET FILE TYPE
	;;--------------------------------------------------------------------------
	if keyword_set(force_float) then cube = float(cube) 	; FORCE FLOAT   (4 bytes)
	if keyword_set(force_int  ) then cube = fix  (cube)   	; FORCE INTEGER (2 bytes)
	if keyword_set(force_long ) then cube = long (cube)   	; FORCE LONG    (4 bytes)


	;;--------------------------------------------------------------------------
	;; SET PROPER CORE ITEMS
	;;--------------------------------------------------------------------------
	type = size(cube, /TNAME)
	case type of
		"FLOAT" : begin
		            CORE_ITEM_BYTES='4'
		            CORE_ITEM_TYPE ='REAL'
		          end
		"DOUBLE": begin
		            cube = float(cube)	; DOUBLE is always converted to float
		            CORE_ITEM_BYTES='4'
		            CORE_ITEM_TYPE ='REAL'
		          end
		"INT"   : begin
		            CORE_ITEM_BYTES='2'
		            CORE_ITEM_TYPE ='MSB_INTEGER'
		          end
		"LONG"  : begin
		            CORE_ITEM_BYTES='4'
		            CORE_ITEM_TYPE ='MSB_INTEGER'
		          end
		else : message, "ERROR: cube type "+type+" is not valid. (Must be either LONG, FLOAT, DOUBLE or INT)"
	endcase

	; Number of bytes per record (fixed value)
	record_size = 512
	; Calculate file records
	file_records = cube_size * CORE_ITEM_BYTES / record_size



	;;--------------------------------------------------------------------------
	;; SET FILE NAMES AND DATE
	;;--------------------------------------------------------------------------
	; Extract extension of the filename
	Extension = strmid(FILE_BASENAME(filename),3,4,/REVERSE)
	; Set filename for the detached label (same with different extension)
	label_file = FILE_DIRNAME(filename,/MARK)+FILE_BASENAME(filename,Extension)+'.LBL'
	; Set filename for the ENVI header (same with different extension)
	envi_hdr_file = FILE_DIRNAME(filename,/MARK)+FILE_BASENAME(filename,Extension)+'.HDR'

	; Get creation time and date
	datetime=string(FORMAT='(C(CYI,"-",CMOI2.2,"-",CDI2.2,"T",CHI2.2,":",CMI2.2,":",CSI2.2))',systime(/jul, /utc))

	EOL = string([13b,10b])      ; standard PDS end of line marker (CR+LF)

	;;--------------------------------------------------------------------------
	;; WRITE QUBE FILE
	;;--------------------------------------------------------------------------
	openw, lun, filename, /get_lun, /swap_if_little_endian, ERROR=err
	if err ne 0 then message, "ERROR cannot write to file: "+filename
	writeu, lun, cube
	close, lun
	free_lun, lun



	;;--------------------------------------------------------------------------
	;; WRITE PDS LABEL
	;;--------------------------------------------------------------------------
	openw, lbl_lun, label_file, /get_lun, ERROR=err
	if err ne 0 then message, "ERROR cannot write to file: "+label_file

	; set band names
	if n_elements(bnames) ne 0 then begin
		bnamesPDS=bnames
		for b=0,nb-1 do bnamesPDS[b]=STRJOIN(STRSPLIT(bnamesPDS[b],",}{=",/EXTRACT)) ;remove special characters
		if nb gt 1 then $
		bnamesPDS[0:nb-2] = '"'+bnamesPDS[0:nb-2] + '",'
		bnamesPDS[  nb-1] = '"'+bnamesPDS[  nb-1] + '")'
	endif

	; set wavelengths
	if n_elements(wl) ne 0 && wl[0] ne -1 then begin
		wlPDS= strtrim(wl,2)
		if nb gt 1 then $
		wlPDS[0:nb-2] = wlPDS[0:nb-2] + ","
		wlPDS[  nb-1] = wlPDS[  nb-1] + ")"
	endif

	; set core values (Unknown by default)
	if n_elements(unit           ) eq 0 then unitPDS    ="NULL" else    unitPDS=unit
	if n_elements(name           ) eq 0 then namePDS    ="NULL" else    namePDS=name
	if n_elements(wavelength_unit) eq 0 then wl_unitPDS ="NULL" else wl_unitPDS=wavelength_unit

	writeu, lbl_lun, 'PDS_VERSION_ID       = PDS3'+EOL
	writeu, lbl_lun, 'LABEL_REVISION_NOTE  = "A.CARDESIN, 25/06/2008"'+EOL
	writeu, lbl_lun, ''+EOL
	writeu, lbl_lun, 'PRODUCT_ID     = "'+FILE_BASENAME(filename)+'"'+EOL
	writeu, lbl_lun, 'RECORD_TYPE    = FIXED_LENGTH'+EOL
	writeu, lbl_lun, 'RECORD_BYTES   = '+strtrim(record_size ,2)+EOL
	writeu, lbl_lun, 'FILE_RECORDS   = '+strtrim(file_records,2)+EOL
	writeu, lbl_lun, ''+EOL
	writeu, lbl_lun, '^QUBE          = "'+FILE_BASENAME(filename)+'"'+EOL
	writeu, lbl_lun, ''+EOL
	writeu, lbl_lun, 'DATA_SET_ID           = "NULL"'   +EOL
	writeu, lbl_lun, 'INSTRUMENT_ID         = "VIRTIS"' +EOL
	writeu, lbl_lun, 'INSTRUMENT_NAME       = "VISIBLE AND INFRARED THERMAL IMAGING SPECTROMETER"' +EOL
	writeu, lbl_lun, 'INSTRUMENT_HOST_ID    = "VEX"'    +EOL
	writeu, lbl_lun, 'INSTRUMENT_HOST_NAME  = "VENUS_EXPRESS"'+EOL
	writeu, lbl_lun, 'PRODUCT_CREATION_TIME = '+datetime+EOL
	writeu, lbl_lun, 'STANDARD_DATA_PRODUCT_ID  = "VIRTIS DERIVED DATA"
	writeu, lbl_lun, ''+EOL
	if n_elements(bnames) ne 0 then begin
	writeu, lbl_lun, 'BAND_NAME = ('+EOL
	writeu, lbl_lun, transpose(bnamesPDS)+EOL
	endif
	writeu, lbl_lun, ''+EOL
	writeu, lbl_lun, 'OBJECT  = QUBE'+EOL
	writeu, lbl_lun, ' AXES                        = 3'+EOL
	writeu, lbl_lun, ' AXIS_NAME                   = (BAND, SAMPLE, LINE)'+EOL
	writeu, lbl_lun, ' CORE_ITEMS                  = ('+strtrim(nb,2)+','+strtrim(ns,2)+','+strtrim(nl,2)+')'+EOL
	writeu, lbl_lun, ' CORE_ITEM_BYTES             = '+CORE_ITEM_BYTES+EOL
	writeu, lbl_lun, ' CORE_ITEM_TYPE              = '+CORE_ITEM_TYPE +EOL
	writeu, lbl_lun, ' CORE_BASE                   = 0.0'   +EOL
	writeu, lbl_lun, ' CORE_MULTIPLIER             = 1.0'   +EOL
	writeu, lbl_lun, ' CORE_VALID_MINIMUM          = "NULL"'+EOL
	writeu, lbl_lun, ' CORE_NULL                   = "NULL"'+EOL
	writeu, lbl_lun, ' CORE_LOW_REPR_SATURATION    = "NULL"'+EOL
	writeu, lbl_lun, ' CORE_LOW_INSTR_SATURATION   = "NULL"'+EOL
	writeu, lbl_lun, ' CORE_HIGH_REPR_SATURATION   = "NULL"'+EOL
	writeu, lbl_lun, ' CORE_HIGH_INSTR_SATURATION  = "NULL"'+EOL
	writeu, lbl_lun, ' CORE_NAME                   = "'+strupcase(namePDS)+'"'+EOL
	writeu, lbl_lun, ' CORE_UNIT                   = "'+strupcase(unitPDS)+'"'+EOL
	writeu, lbl_lun, ' SUFFIX_BYTES                = 4'+EOL  ;PDS mandatory (?) in any case it is not used here
	writeu, lbl_lun, ' SUFFIX_ITEMS                = (0,0,0)'+EOL
	writeu, lbl_lun, ''+EOL
	if n_elements(wl) ne 0 && wl[0] ne -1 then begin
		writeu, lbl_lun, 'BAND_BIN_UNIT = "'+STRUPCASE(wl_unitPDS)+'"'+EOL
		writeu, lbl_lun, 'BAND_BIN_CENTER = ('+EOL
		writeu, lbl_lun, transpose(wlPDS)+EOL
	endif
	writeu, lbl_lun, ''+EOL
	writeu, lbl_lun, 'END_OBJECT  = QUBE'+EOL
	writeu, lbl_lun, ''+EOL
	writeu, lbl_lun, 'END'+EOL
	writeu, lbl_lun, ''+EOL

	close   , lbl_lun
	free_lun, lbl_lun

	IF KEYWORD_SET(display_label) || N_ELEMENTS(display_label) eq 0 THEN $
	  xdisplayfile, label_file, TITLE="PDS Label View", FONT="Courier*10",  HEIGHT=40, WIDTH=80, /EDIT


	;;--------------------------------------------------------------------------
	;; WRITE ENVI HEADER (optional)
	;;--------------------------------------------------------------------------

	IF N_elements(envi_header) eq 0 || keyword_Set(envi_header) then begin

		;get data type
		if core_item_bytes eq 2 then data_type = 2 else $
		if core_item_type  eq "REAL" then data_type = 4 else data_type = 3

		idl_envi_setup_head, $
                  FNAME           = filename,  $
                  bnames          = bnames,    $
                  WL              = wl,        $
                  DATA_TYPE       = data_type, $
                  BYTE_ORDER      = 1         ,$ ;windows (little_endian)
                  interleave      = 2         ,$ ;BIP
                  OFFSET          = 0,         $
                  wavelength_unit = wavelength_unit,$
                  NB              = nb,        $
                  NS              = ns,        $
                  NL              = nl,        $
                  descrip         = name,      $
                  OPEN            = OPEN_ENVI, $
                  ZPLOT_TITLES    = zplot_titles


		IF KEYWORD_SET(display_label) || N_ELEMENTS(display_label) eq 0 THEN $
		  xdisplayfile, envi_hdr_file, TITLE="ENVI Header View", FONT="Courier*10",  HEIGHT=30, WIDTH=50, /EDIT
	ENDIF

end


;;==========================================================================
;; EXAMPLE ROUTINE
;;==========================================================================

pro write_pds_file_with_detached_label_EXAMPLE


	;;--------------------------------------------------------------------------
	;; READ ANY VIRTIS PDS QUBE
	;;--------------------------------------------------------------------------
	;set dummy file for windows machine (just to read last open directory)
	if !version.os_family eq "Windows" then path_in="dummy"

	x=virtispds(dialog_pickfile(path=path_in))
	cube = x.qube
	x=0 ; release memory


	;;--------------------------------------------------------------------------
	;; WRITE PDS FILE AND LABELS
	;;--------------------------------------------------------------------------
	write_pds_file_with_detached_label, QUBE=cube, FILENAME=filename, /DISPLAY_LABEL, /ENVI_HEADER



	;;--------------------------------------------------------------------------
	;; TEST BINARY FILE (checks it is equal to the original qube)
	;;--------------------------------------------------------------------------
	cube_read = cube*0 ; dummy variable with same dimensions
	openr, lun, filename, /get_lun, /swap_if_little_endian
	readu, lun, cube_read
	close, lun
	free_lun, lun

	IF MAX(abs(cube-cube_read)) NE 0 THEN message, "ERROR in the file: cube read is different to original one"



	;;--------------------------------------------------------------------------
	;; TEST PDS FILE
	;;--------------------------------------------------------------------------
	y=virtispds(filename)
	cube_pds = y.qube
	y=0 ; release memory

	IF MAX(abs(cube-cube_pds)) NE 0 THEN message, "ERROR in the pds file: cube read with virtisPDS is different to original one"


	;;--------------------------------------------------------------------------
	;; NOTIFY SUCCESS
	;;--------------------------------------------------------------------------
	print, ""
	print, "PDS file with detached label written SUCCESSFULLY!!!:"
	print, '"'+filename+'"'

	ok = dialog_message(/INFO, TITLE="Process Completed", "PDS file with detached label written SUCCESSFULLY."+string(10B)+string(10B)+'"'+filename+'"')

end
