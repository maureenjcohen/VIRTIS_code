;+
; NAME:
;    v_browse_html_generator
;
; PURPOSE:
;    Generate HTML index for JPEG browse directories
;
; INPUTS:
;    path : full path of the folder where browse JPGs are located and
;           INDEX_XXXX.HTM will be saved (XXXX is the name of the output folder)
;
; KEYWORD PARAMETERS:
;    DISPLAY  : set to display INDEX_XXXXX.HTM page when finished
;    PDS_LABEL: set to write also a PDS label file
;
; MODIFICATION HISTORY:
;    Written by A.Cardesin, September 2008, Alejandro.Cardesin @ iasf-roma.inaf.it
;-
PRO v_browse_html_generator, path, display=display,PDS_LABEL=pds_label

if n_elements(path) eq 0 then path = dialog_pickfile(path="V:\BROWSE\",/DIR)
if path eq "" then return
if STRMID(path,0,1,/REVERSE) ne path_sep() then path=path+path_sep()

filelist = file_search(path, "VV[0-9][0-9][0-9][0-9]_[0-9][0-9]_A.JPG", COUNT=nfiles)

if nfiles eq 0 then message, "ERROR: no files were found in input path: "+path

indexfilepath=path+"BROWSE_INDEX_"+file_basename(path)+".HTM"
indexfilename=file_basename(indexfilepath,'.HTM')
openw, lun,indexfilepath, /GET_LUN

EOL = string([13b,10b])      ; standard PDS end of line marker (CR+LF)

datetime=string(FORMAT='(C(CYI,"-",CMOI2.2,"-",CDI2.2,"T",CHI2.2,":",CMI2.2,":",CSI2.2))',systime(/jul, /utc))
date=(STRSPLIT(datetime,"T",/EXTRACT))[0]

if keyword_set(pds_label) then begin

	labelfilepath=path+"BROWSE_INDEX_"+file_basename(path)+".LBL"
	labelfilename=file_basename(indexfilepath,'.LBL')
	openw,  lbllun,labelfilepath, /GET_LUN

	writeu, lbllun,'PDS_VERSION_ID            = PDS3'                     +EOL
	writeu, lbllun,'RECORD_TYPE               = UNDEFINED'                +EOL
	writeu, lbllun,'PRODUCT_CREATION_TIME     = '+date                    +EOL
	writeu, lbllun,'PRODUCT_ID                = "'+indexfilename+'"'      +EOL
	writeu, lbllun,'^HTML_DOCUMENT            = "'+indexfilename+'.HTM"'  +EOL
	writeu, lbllun,''                                                     +EOL
	writeu, lbllun,'OBJECT                    = HTML_DOCUMENT'            +EOL
	writeu, lbllun,'  DOCUMENT_FORMAT         = "HTML" '                  +EOL
	writeu, lbllun,'  DOCUMENT_NAME           = "'+indexfilename+'"'      +EOL
	writeu, lbllun,'  DOCUMENT_TOPIC_TYPE     = "N/A"'                    +EOL
	writeu, lbllun,'  INTERCHANGE_FORMAT      = "ASCII"'                  +EOL
	writeu, lbllun,'  PUBLICATION_DATE        = '+date                    +EOL
	writeu, lbllun,'  DESCRIPTION             = "JPEG BROWSE INDEX FILE"' +EOL
	writeu, lbllun,'END_OBJECT                = HTML_DOCUMENT'            +EOL
	writeu, lbllun,''                                                     +EOL
	writeu, lbllun,'END'                                                  +EOL
	writeu, lbllun,''                                                     +EOL
	close,  lbllun
	free_lun, lbllun
endif

printf, lun,'<table border=1>'
printf, lun,'   <tr>'
printf, lun,'     <td align="center">Data Product Label</td>'
printf, lun,'     <td align="center">M-IR<BR>Near-IR surface band 1.02um (equalized)</td>'
printf, lun,'     <td align="center">M-IR<BR>Infrared airglow band 1.27um (equalized)</td>'
printf, lun,'     <td align="center">M-IR<BR>Infrared atmospheric window at 1.74um (equalized)</td>'
printf, lun,'     <td align="center">M-IR<BR>Summing of bands 3.67um to 3.96um (equalized)</td>'
printf, lun,'     <td align="center">M-IR<BR>Summing of thermic bands 5um to 5.12um (equalized)</td>'
printf, lun,'     <td align="center">M-IR<BR>Summing of bands 2.23-2.44um (filtered)</td>'
printf, lun,'     <td align="center">Surface elevation from Magellan geometric data</td>'
printf, lun,'     <td align="center">M-VIS<BR>Visible band at 370nm (equalized)</td>'
printf, lun,'     <td align="center">M-VIS<BR>Near-IR surface bands 978nm to 1032nm (equalized)</td>'
printf, lun,'     <td align="center">M-VIS<BR>Summing of bands 383nm to 402nm (filtered)</td>'
printf, lun,'   </tr>'

FOR i=0, nfiles-1 DO BEGIN

 subsession = strtrim(stregex(filelist[i],"[0-9][0-9][0-9][0-9]_[0-9][0-9]",/EXTRACT),2)

 dummy=query_JPEG(filelist[i], info)
 if (info.dimensions)[0] EQ 256 then width ='110' else width =' 80'

 printf, lun,'<tr>'
 if file_test(path+"VI"+subsession+"_LABEL.TXT") then begin
 printf, lun,' <td align="right"><a href="VI'+subsession+'_LABEL.TXT"> VI'+subsession+'</a> <a href="VV'+subsession+'_LABEL.TXT"> VV'+subsession+'</a></td>'
 printf, lun,' <td align="center"><a href="VI'+subsession+'_A.JPG"> <img width='+width+' border=0 src="VI'+subsession+'_A.JPG" alt="not available" title="VI'+subsession+'_A.JPG Near-IR surface band 1.02um (equalized)"                     ></a> </td>'
 printf, lun,' <td align="center"><a href="VI'+subsession+'_B.JPG"> <img width='+width+' border=0 src="VI'+subsession+'_B.JPG" alt="not available" title="VI'+subsession+'_B.JPG Infrared airglow band 1.27um (equalized)"                    ></a> </td>'
 printf, lun,' <td align="center"><a href="VI'+subsession+'_C.JPG"> <img width='+width+' border=0 src="VI'+subsession+'_C.JPG" alt="not available" title="VI'+subsession+'_C.JPG Infrared atmospheric window at 1.74um (equalized)"           ></a> </td>'
 printf, lun,' <td align="center"><a href="VI'+subsession+'_E.JPG"> <img width='+width+' border=0 src="VI'+subsession+'_E.JPG" alt="not available" title="VI'+subsession+'_E.JPG Summing of bands 3.67um to 3.96um (equalized)"               ></a> </td>'
 printf, lun,' <td align="center"><a href="VI'+subsession+'_F.JPG"> <img width='+width+' border=0 src="VI'+subsession+'_F.JPG" alt="not available" title="VI'+subsession+'_F.JPG Summing of thermic bands 5um to 5.12um (equalized)"          ></a> </td>'
 printf, lun,' <td align="center"><a href="VI'+subsession+'_G.JPG"> <img width='+width+' border=0 src="VI'+subsession+'_G.JPG" alt="not available" title="VI'+subsession+'_G.JPG Summing of bands 2.23-2.44um (masked and filtered)"          ></a> </td>'
 endif else begin
 printf, lun,' <td align="right"><a href="VV'+subsession+'_LABEL.TXT"> VV'+subsession+'</a></td>'
 printf, lun,' <td align="center">Only Visible</td>'
 printf, lun,' <td align="center">Only Visible</td>'
 printf, lun,' <td align="center">Only Visible</td>'
 printf, lun,' <td align="center">Only Visible</td>'
 printf, lun,' <td align="center">Only Visible</td>'
 printf, lun,' <td align="center">Only Visible</td>'
 endelse
 printf, lun,' <td align="center"><a href="VV'+subsession+'_D.JPG"> <img width='+width+' border=0 src="VV'+subsession+'_D.JPG" alt="not available" title="VV'+subsession+'_D.JPG Surface elevation from Magellan geometric data"               ></a> </td>'
 printf, lun,' <td align="center"><a href="VV'+subsession+'_A.JPG"> <img width='+width+' border=0 src="VV'+subsession+'_A.JPG" alt="not available" title="VV'+subsession+'_A.JPG Visible band at 370nm (masked and equalized)"                 ></a> </td>'
 printf, lun,' <td align="center"><a href="VV'+subsession+'_B.JPG"> <img width='+width+' border=0 src="VV'+subsession+'_B.JPG" alt="not available" title="VV'+subsession+'_B.JPG Near-IR surface bands 978nm to 1032nm (masked and equalized)" ></a> </td>'
 printf, lun,' <td align="center"><a href="VV'+subsession+'_C.JPG"> <img width='+width+' border=0 src="VV'+subsession+'_C.JPG" alt="not available" title="VV'+subsession+'_C.JPG Summing of bands 383nm to 402nm (masked and filtered)"        ></a> </td>'
 printf, lun,'</tr>'

ENDFOR

printf, lun,'</table>'

close, lun
free_lun, lun

print,'Process completed.'
print,'Created: "'+indexfilepath+'"'

if keyword_set(display) then begin
	;xdisplayfile, labelfilepath, FONT="courier*10", /EDIT
	ONLINE_HELP, BOOK=indexfilepath
endif

END
