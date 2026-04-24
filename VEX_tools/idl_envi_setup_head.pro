;+
; NAME:
;   IDL_ENVI_SETUP_HEAD
;
; PURPOSE:
;   Create ENVI header without using ENVI routines.
;   (Mimics use of ENVI_SETUP_HEAD routine)
;
;   See ENVI help for "envi_setup_head" for details.
;
; EXAMPLE:
;   IDL> IDL_ENVI_SETUP_HEAD, fname=fname, ns=256, nl=256, nb=1, interleave=0, data_type=1
;
; RESTRICTIONS:
;   Some keywords of "envi_setup_head" are not allowed here. Only basic ones have been implemented
;
; MODIFICATION HISTORY:
;   Written by Alejandro Cardesin, INAF-ESA, December 2008, alejandro.cardesin @ iasf-roma.inaf.it
;-

 PRO idl_envi_setup_head, $
                  FNAME           = fname,     $
                  bnames          = bnames,    $
                  WL              = wl,        $
                  DATA_TYPE       = data_type, $
                  BYTE_ORDER      = byte_order,$
                  interleave      = interleave,$
                  OFFSET          = offset,    $
                  wavelength_unit = wl_unit,   $
                  NB              = nb,        $
                  NS              = ns,        $
                  NL              = nl,        $
                  descrip         = descrip,   $
                  OPEN            = open,      $
                  ZPLOT_TITLES    = zplot_titles

		; Get creation time and date
		datetime=string(FORMAT='(C(CYI,"-",CMOI2.2,"-",CDI2.2,"T",CHI2.2,":",CMI2.2,":",CSI2.2))',systime(/jul, /utc))

		; Set filename for the ENVI header (same with different extension)
		Extension = strmid(FILE_BASENAME(fname),3,4,/REVERSE)
		envi_hdr_file = FILE_DIRNAME(fname,/MARK)+FILE_BASENAME(fname,Extension)+'.HDR'

		openw, hdr_lun, envi_hdr_file, /get_lun, ERROR=err
		if err ne 0 then message, "ERROR cannot write to file: "+envi_hdr_file

		; set band names
		if n_elements(bnames) ne 0 then begin
			bnamesENVI=bnames
			for b=0,nb-1 do bnamesENVI[b]=STRJOIN(STRSPLIT(bnamesENVI[b],",}{=",/EXTRACT)) ;remove special characters
			if nb gt 1 then $
			bnamesENVI[0:nb-2] = bnamesENVI[0:nb-2] + ","
			bnamesENVI[  nb-1] = bnamesENVI[  nb-1] + "}"
		endif

		; set z plot titles
		if n_elements(zplot_titles) eq 2 then begin
			for i=0,1 do zplot_titles[i]=STRJOIN(STRSPLIT(zplot_titles[i],",}{=",/EXTRACT)) ;remove special characters
			zplot_titles[0] = zplot_titles[0] + ","
			zplot_titles[1] = zplot_titles[1] + "}"
		endif

		; set wavelengths
		if n_elements(wl) ne 0 && wl[0] ne -1 then begin
			wlENVI= strtrim(wl,2)
			if nb gt 1 then $
			wlENVI[0:nb-2] = wlENVI[0:nb-2] + ","
			wlENVI[  nb-1] = wlENVI[  nb-1] + "}"
		endif

		if N_elements(descrip) eq 0 then descrip="Created with idl_envi_setup_head.pro"
		if N_elements(offset ) eq 0 then offset =0
		if N_elements(interleave ) eq 0 then interleave = 0
		if N_elements(wl_unit ) eq 0 then wl_unit = 6 ;unknown
		if N_elements(byte_order ) eq 0 then byte_order = 0 ; windows (Little_endian)

		case interleave of
		   0: interleave_type="bsq"
		   1: interleave_type="bil"
		   2: interleave_type="bip"
		end

		case wl_unit of
		   0: wl_unit="Micrometers"
		   1: wl_unit="Nanometers"
		   2: wl_unit="Wavenumber"
		   3: wl_unit="GHz"
		   4: wl_unit="MHz"
		   5: wl_unit="Index"
		   6: wl_unit="Unknown"
		end

		EOL = string([13b,10b])      ; standard PDS end of line marker (CR+LF)

		writeu, hdr_lun, 'ENVI'+EOL
		writeu, hdr_lun, 'description = {'+EOL
	  	writeu, hdr_lun, descrip+EOL
	  	writeu, hdr_lun, '   ENVI File, Created '+datetime+'}'+EOL
		writeu, hdr_lun, 'samples = '+strtrim(ns,2) +EOL
		writeu, hdr_lun, 'lines   = '+strtrim(nl,2) +EOL
		writeu, hdr_lun, 'bands   = '+strtrim(nb,2) +EOL
		writeu, hdr_lun, 'header offset = '+strtrim(offset,2) +EOL
		writeu, hdr_lun, 'file type = ENVI Standard'+EOL
		writeu, hdr_lun, 'data type = '+strtrim(data_type,2)+EOL
		writeu, hdr_lun, 'interleave = '+interleave_type+EOL
		writeu, hdr_lun, 'sensor type = Unknown'+EOL
		writeu, hdr_lun, 'byte order = '+strtrim(byte_order,2)+EOL
		writeu, hdr_lun, 'wavelength units = '+wl_unit+EOL
		if n_elements(wl) ne 0 && wl[0] ne -1 then begin
		writeu, hdr_lun, 'wavelength = {'+EOL
		writeu, hdr_lun, transpose(wlENVI)+EOL
		endif
		if n_elements(zplot_titles) eq 2 then begin
		writeu, hdr_lun, 'z plot titles = {'+EOL
		writeu, hdr_lun, transpose(zplot_titles)+EOL
		endif
		if n_elements(bnames) ne 0 then begin
		writeu, hdr_lun, 'band names = {'+EOL
		writeu, hdr_lun, transpose(bnamesENVI)+EOL
		endif

		writeu, hdr_lun, ''+EOL

		close   , hdr_lun
		free_lun, hdr_lun

	IF keyword_set(open) then begin
		 ;Run ENVI if it is not running yet
 		help,name='envi_open_file',/procedures, output=help_envi_compiled
 		IF N_ELEMENTS(help_envi_compiled) LE 1 THEN ENVI

		ENVI_OPEN_FILE, fname

	endif


END
