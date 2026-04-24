PRO read_cooler_power, DISPLAY=display, PLOT=plot, SAVE_OUTPUT=save_output
; NOTE:  PROCESS MIGHT TAKE A VERY LONG TIME (up to an hour)

;Select whether you want to display results, plot them or save them as a file "power_output.sav"
display=0
plot=0
save_output=1

; Select the cycle time you want to consider
;cycletime=3000  ; seconds first cycle :fast increase ( / ) H
;cycletime=3600  ; seconds first cycle :fast increase ( / ) M
cycletime=5000 ; seconds first cycle :fast increase + shoulder ( /` ) (both M & H)

;SELECT WHICH FILE YOU WANT TO READ
cooler_times_file  = "C:\doc\Cooler_Problems\lifetime\FullMission_coolertimes\Mcoolertimes.txt"
;cooler_times_file  = "C:\doc\Cooler_Problems\lifetime\FullMission_coolertimes\Hcoolertimes.txt"

;SELECT WHICH FILE YOU WANT TO READ
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-FULLuptoSep2007_Mcool_clean.txt"
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-FULLuptoAug2007_Hcool_clean.txt"
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-2006_Mcool_clean.txt"
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-2007_Mcool_clean.txt"
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-2006_Hcool_clean.txt"
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-2007_Hcool_clean.txt"
cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-AugSep07_Mcool_clean.txt"
;cooler_values_file = "C:\doc\Cooler_Problems\lifetime\FullMission_coolervalues\VEXVIR-AugSep07_Hcool_clean.txt"

; Set path of template files (to read ascii files)
template_path = "C:\doc\Cooler_Problems\lifetime\IDL_templates"

; Initial time
inittime=systime(/SECONDS)

 ;;---------------------------------------------------------------
 ;; Restore Templates to read ASCII files
 ;;---------------------------------------------------------------

 Print, "Restoring Templates to read ASCII files ... " & EMPTY

 ; Search "cooler_times_template.sav"
 template_file = file_search(template_path, "cooler_times_template.sav")
 IF (template_file EQ '') THEN template_file=dialog_pickfile(TITLE="Restore file: cooler_times_template.sav", FILTER="*.sav", PATH=template_path)
 Restore,template_file

 ; Search "cooler_values_template.sav"
 template_file = file_search(template_path, "cooler_values_template.sav")
 IF (template_file EQ '') THEN template_file=dialog_pickfile(TITLE="Restore file: cooler_times_template.sav", FILTER="*.sav", PATH=template_path)
 Restore,template_file

 ;;---------------------------------------------------------------
 ;; Read cooler values
 ;;---------------------------------------------------------------

 print, 'Reading cooler values from file "'+file_basename(cooler_values_file)+'" ...'& EMPTY

 struct = READ_ASCII(cooler_values_file, TEMPLATE=cooler_values_template)

 SCET    = TEMPORARY(struct.scet   )
 COLDTIP = TEMPORARY(struct.COLDTIP)
 VOLTAGE = TEMPORARY(struct.voltage)
 CURRENT = TEMPORARY(struct.current)

 ;;---------------------------------------------------------------
 ;; Read cooler times
 ;;---------------------------------------------------------------

 print, 'Reading cooler times from file "'+file_basename(cooler_times_file)+'" ...' & EMPTY

 struct = READ_ASCII(cooler_times_file, TEMPLATE=cooler_times_template)

 T_START  = TEMPORARY(struct.start)
 T_STOP   = TEMPORARY(struct.stop )

 struct = 0b ;release memory

 ;;---------------------------------------------------------------
 ;; PROCESS TIMES and VALUES
 ;;---------------------------------------------------------------

 print, "Processing cooler times and values ..." & EMPTY

 power  = 0d
 scet2  = 0ULL

  FOR i=0,N_ELEMENTS(T_START)-1 DO BEGIN

    ;consider only values that are after the first cycle)
    ind = where((SCET GE (T_START[i]+cycletime)) AND (SCET LE T_STOP[i]))

    IF ind[0] EQ -1 THEN CONTINUE ;not found, skip

    power = [power, current[ind] * voltage[ind]]
    scet2 = [scet2, scet[ind]]

  ENDFOR

 power = power[1:*] ;remove first dummy value
 scet2 = scet2[1:*] ;remove first dummy value

 ;;---------------------------------------------------------------
 ;; DONE, display output results
 ;;---------------------------------------------------------------

 print, "Process Completed in "+string((systime(/SECONDS)-inittime)/60.,F='(F5.2)')+" minutes!!!"
 print, ''
 print, "Displaying output results..." & EMPTY

IF KEYWORD_SET(display) THEN xdisplayfile, dummy, text=string(scet2)+string(power), /EDIT

IF KEYWORD_SET(plot) THEN iplot, scet2, power, NAME="Power", COLOR=[255,29,29], LINESTYLE=6, SYM_INDEX=3, SYM_SIZE=0.8

IF KEYWORD_SET(save_output) THEN save, power, scet2, $
                                       T_start, T_stop, $
                                       scet, voltage, current, coldtip, $
                                       filename=FILE_DIRNAME(cooler_values_file, /MARK)+"power_output.sav"

result = MOMENT(power, /DOUBLE)


PRINT, 'CYCLE TIME used: '+strtrim(cycletime,2)
PRINT, '   Mean    : ', strtrim(result[0],2)
PRINT, '   Variance: ', strtrim(result[1],2)
;PRINT, '   Skewness: ', strtrim(result[2],2)
;PRINT, '   Kurtosis: ', strtrim(result[3],2)

END
