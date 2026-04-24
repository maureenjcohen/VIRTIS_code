PRO join_ptm

; this routine is able to join different PTM files from single subsessions into one file
; this is useful when the file is used for the trend file generation in the CSWS without to load a large number of single files

;---------------------------------
path_in_ptm='R:\Sessions\Cruise-VOCP-VOI_skip\'
file_out_ptm='C:\VVX Data Archive\PTM_Files\cooler\MTP\Cruise-VOCP-VOI_HSK.PTM'
key_search='HKSTREAM.PTM'
;---------------------------------

subsessions = FILE_SEARCH(path_in_ptm,key_search)
file_in=''
for i=0,N_ELEMENTS(subsessions)-1 do begin
	file_in=file_in+'"'+subsessions[i]+'"'+' + '
endfor
file_in=strmid(file_in,0,strlen(file_in)-3)
var_spawn = 'copy /B ' + file_in + ' ' + '"' + file_out_ptm + '"'

SPAWN, var_spawn

print,var_spawn

end
