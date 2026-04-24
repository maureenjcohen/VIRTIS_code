;+
; NAME:
;   ACCUMULATED_PROJECTION
;
; PURPOSE:
;   Obtain global accumulated projections of a given band from all cubes found in a given directory.
;   The projections can be done for Latitude vs Longitude or Latitude vs Local Time
;
;   Several options: RAYLEIGH, THERMAL_BRIGHTNESS, CONTINUUM SUBTRACTION, EM_ANGLE_CORRECTION, etc
;   Geometrical filtering is also possible using Emission/Incidence angles, elevation, etc
;
;   See source code for details.
;
; INPUT:
;   none, options are setup directly in the source code
;
; KEYWORDS:
;   DEBUG: set to stop on errors (debugging mode)
;   NO_DISPLAY: set to prevent from using any display, useful for servers withou Display
;               (progress_bars, pop up windows and device commands are disabled)
;
; EXAMPLE:
;   simply edit the options in the source code below and run the routine without any parameters
;
; PROCEDURE:
;   Uses the VIRTISPDS/LecturePDS package and the following routines:
;         "v_geo_grid.pro" "v_map_projection", "v_scet2jul", "write_pds_file_with_detached_label", "idl_envi_setup_head"
;   Uses also the "colorbar.pro" and "progressbar__define.pro" routines from David Fanning (http://www.dfanning.com/programs/)
;
; MODIFICATION HISTORY:
;   Written by Alejandro Cardesin, IASF-INAF, July 2008, alejandro.cardesin @ iasf-roma.inaf.it
;   Modified December 2008 by AC, adapted to work on a linux server without any use of ENVI
;-

PRO ACCUMULATED_PROJECTION_H2O_BANDS_INTERP, DEBUG=debug, NO_DISPLAY=no_display,PATH_IN=path_in,SEARCH_KEY = search_key

  NO_DISPLAY=1
  INVERTED=0
  QUERY=1
  savePNGmap=1


  ;;==================================================================
  ;;==================================================================
  ;;|||   PARAMETER DEFINITION   ## SET YOUR VALUES HERE BELOW ##  |||
  ;;==================================================================
  ;;==================================================================

  ;;==================================================================
  ;; Define PATHs
  ;;==================================================================

  path_in    = "E:\venus\VEX-V-VIRTIS-2-3-EXT1-V2.0\"
  IF N_ELEMENTS(search_key) EQ 0 THEN search_key = "VI0" ; filter key (e.g. "VI" for all infrared, "VI0345" full orbit 345, "VI0[0-3]" orbits 0-399 , "VI0345_00" one single cube, "VI0345_0[0-7]" cubes 00 to 07 from this orbit)

  ; Path to save the IDL variables and ENVI images (if needed)
  path_save  = "E:\venus\accumulated_results\"

  ; Path to save the PNG image of the final map (if needed)
  ; path_png_map=path_save+"\..\"+search_key+"_ALL_Ratiob229b232_interpol1_150-165K_ALLexp.png"

  ; Path to save the PNG image of each grid (if needed)
  path_png   = ""

  ;;==================================================================
  ;; Define Suffix of output files
  ;;==================================================================

  ;suffix              = 'CO_bandratio_2.302.32um_920Orbits_LEFT_NIGHTSIDE_LONGITUDE_ExpsGT0.1_maxEM80_minINC100_5x5_values0-3_onlynadirs' ;suffix for the PNG files, IDL save files and ENVI image files
  ;suffix              = 'CO_band_2.30' ;suffix for the PNG files, IDL save files and ENVI image files
  suffix               = 'CO_band_2.29_all_LST_interp1' ;suffix for the PNG files, IDL save files and ENVI image files

  ;;==================================================================
  ;; SELECT INPUT BANDS
  ;;==================================================================
  ; index_band is mandatory, the rest is optional. Indexes can be a single value or an array
  ;index_band       = 70+indgen(10)  ; WINDOW 1.7um
  ;index_continuum  = [70,79]        ; WINDOW 1.7um
  ;index_band       = 122+indgen(35) ; WINDOW 2.3um
  ;index_band       = 122+indgen(14)  ; WINDOW 2.3um LEFT  (2.19,2.32)
  ;index_band       = 122+indgen(4)   ; WINDOW 2.3um RIGHT (2.32,2.36)

  ;index_band        = 160 ; 2.53
  ; index_band       = 163 ; 2.56
  index_band         = 133  ; 2.29
  ;index_band       = 136  ; 2.32

  ;index_continuum  = [121,157]      ; WINDOW 2.3um
  ;index_band       = 22+indgen(8)   ; Airglow O2 1.27um
  ;index_continuum  = [22,29]        ; Airglow O2 1.27um
  ;index_thermal     = 13+indgen(8)  ; Airglow O2 1.27um THERMAL Contribution (1.18um)
  ;index_cont_thermal= [13,20]       ; Airglow O2 1.27um THERMAL Continuum    (1.18um)
  ;thermal_ratio     = 0.3           ; ratio Airglow/Thermal (varies from 0.25 to 0.35. From Radiance to Rayleigh there's a difference of 1.27/1.18)
  ;index_band       = 55+indgen(6)   ; Airglow O2 1.58um
  ;index_continuum  = [54,61]        ; Airglow O2 1.58um
  ;index_band       = 186+indgen(5)  ; Airglow OH 2.8um
  ;index_continuum  = [185,191]      ; Airglow OH 2.8um
  ;index_band       = [0,1,2]        ; SURFACE 1um
  ;index_continuum  = [3,4]          ; SURFACE 1um
  ;index_band       = 419+indgen(6)*2; TERMIC 5um
  ;index_band       = 285+indgen(10) ; TERMIC 3.8um
  ;index_band       = 330+indgen(45) ; DAYSIDE CO2 NON-LTE
  ;index_continuum  = [330,331,332,333,375,376,377,378]        ; DAYSIDE CO2 NON-LTE
  ;index_band       = 337+indgen(9)  ; CO2 Absorption (90-93km height)
  ;index_band       = 339+indgen(5)  ; CO2 Absorption (93km height)
  ;index_band       = 323+indgen(9)  ; Thermal Inversion LEFT
  ;index_band       = 364+indgen(9)  ; Thermal Inversion RIGHT


  ;;==================================================================
  ;; SELECT INPUT GEO BAND (optional)
  ;;==================================================================
  ; Setting a geo band ignores the previous radiance selected
  ; It can be used instead of a radiance band to create a cube of geometry parameters (for checking)
  ;index_GEO        =  8 ;Surf longit, center
  ;index_GEO        =  9 ;Surf latit, center
  ;index_GEO        = 10 ;Incidence at surf
  ;index_GEO        = 11 ;Emergence at surf
  ;index_GEO        = 12 ;Phase at surf
  ;index_GEO        = 13 ;Elevation on surf layer
  ;index_GEO        = 14 ;Slant distance
  ;index_GEO        = 15 ;Local time
  ;index_GEO        = 24 ;Cloud longit, center
  ;index_GEO        = 25 ;Cloud latit, center
  ;index_GEO        = 26 ;Incidence on clouds
  ;index_GEO        = 27 ;Emergence on clouds
  ;index_GEO        = 28 ;Phase on clouds
  ;index_GEO        = 29 ;Elevation below clouds
  ;index_GEO        = 30 ;Right ascension
  ;index_GEO        = 31 ;Declination
  ;index_GEO        = 32 ;M-common frame


  ;;==================================================================
  ;; SELECT THE PARAMETERS TO USE
  ;;==================================================================
  Thermal_Brightness  =  0 ; set to transform Radiance into Thermal Brightness (Note: continuum subtraction is not performed)
  Rayleigh            =  0 ; set to convert Radiance into Rayleigh (MR)

  Post_EMA_Correction =  1 ; set to correct for Emission angle after other corrections and conversion to Thermal Brightness

  EMA_Correction_1_27 =  0 ; set to correct for Emission angle and backscatter (for nightglow)
  EMA_Correction_1_74 =  0 ; set to correct for Emission angle (for 1.74 um)
  EMA_Correction_2_3  =  0 ; set to correct for Emission angle (for 2.3  um)
  EMA_Correction_3_8  =  0 ; set to correct for Emission angle (for 3.8  um)

  median_filter       =  1 ; set to apply a median filter 3x3 to remove noise from the image (spikes, stripes, etc)
  interpolate_co      =  1 ; set to apply CO interpolation to bands 2.29, 2.30, 2.31, 2.32.  Set to 2 to do extended interpolation (11 bands instead of 6)
  interpolate_h2o     = 0 ; set to apply H2O interpolation to bands 2.53, 2.54, 2.55, 2.56. Set to 2 to do extended interpolation (11 bands instead of 6)
  average             =  1 ; 1 to average all selected bands (default), 0 to integrate bands (average is performed when Thermal Brightness is set)
  only_positive       =  1 ; set to consider only positive values (RECOMMENDED for most bands, only needed for some geometry bands, e.g. Elevation)

  min_value           = -999 ; set minimum output radiance value to be considered (to ignore bad pixels)
  max_value           = 999  ; (3~5 nightside, 150~200 dayside) set maximum output radiance value to be considered (to ignore bad/saturated pixels)

  min_input           = 0.02 ; min input Radiance for CO (based on Tsang 2009)
  max_input           = 999  ;

  min_temperature     =  150 ; 150  ;Kelvin
  max_temperature     =  165 ; 160  ;Kelvin

  min_expTime         =  0 ; set to consider only qubes that have a exposure time longer  than this value (in seconds)
  max_expTime         = 20.; set to consider only qubes that have a exposure time shorter than this value (in seconds)

  min_science_case_id = 2  ; set to use only nadirs (cases 1,2,3) or limbs (5/7)
  max_science_case_id = 3  ; set to use only nadirs (cases 1,2,3) or limbs (5/7)

  min_emergence_angle =  0.; min emergence angle to be considered,  0 for all, ~85 to consider only limb data
  max_emergence_angle = 85.; max emergence angle to be considered, 90 for all, ~80 to avoid limbs, 40~60 to avoid emergence angle variations
  min_incidence_angle =100.; min incidence angle to be considered,  0 for all, ~95 for only nightside
  max_incidence_angle =180.; max emergence angle to be considered,180 for all, ~85 for only dayside
  min_elevation       =-999; min elevation to be considered, -999 for all, 100 for Limb data (+100 offset for limb data)
  max_elevation       = 100; max elevation to be considered,  999 for all, 100 for NON-Limb data (limb data has an offset of +100)
  nightside           =  0 ; to see only nightside (equivalent to min incidence angle = 95)
  dayside             =  0 ; to see only   dayside (equivalent to max incidence angle = 85)

  longitude           =  0 ; set to 0 to plot with respect to Local Time, set to 1 to use Longitude instead

  only_coverage       =  0 ; 1 to get only the coverage from the geometry without looking at the data

  debug               =  0 ; 1 for debug mode, stop for errors

  ;;==================================================================
  ;; SELECT THE DISPLAY PARAMETERS (ignored if NO_DISPLAY is used)
  ;;==================================================================
  Color_Table     = 13 ; Rainbow ; 15 Stern ; 4 ; color table for the plot/contour/map; LOADCT, GET_NAMES=CT_names & print, transpose(CT_names)
  disp_ENVI       = 0 ; (recommended) use ENVI to display averaged grids and results (ENVI files are created in any case)
  disp_MAP        = 0 ; (recommended) use MAP projection to display averaged grid (it can be done later from ENVI)
  disp_IMAP       = 0 ; use iMAP projection to display averaged grid (it can be done later from ENVI)
  display_all     = 0 ; 1 to display the contour of each processed file (and save PNG image in path_PNG)
  disp_iContour   = 0 ; use iContour to display averaged grid
  disp_iImage     = 0 ; use iImage to display averaged grid
  savefile        = 1 ; save final results (in path_save) as IDL variables that can be recovered by IDL with "RESTORE"

  ;define image range for display (optional, can be done later manually)
  ;range=[200 , 270] ;typical for thermal brightness
  ;range=[0   ,1000] ;typical for coverage
  ;range=[0   ,0.45] ;typical for nightside 1.7um
  ;range=[0.01, 0.3] ;typical for thermal 3.8um
  ;range=[0.01,0.06] ;typical for airglow
  ;range=[2   ,3.5 ] ;typical for CO band ratio
  range=[1.5   ,3.5] ;typical for CO band ratio accumulated TBC
  ;range=[0   ,0.07] ;typical for CO band 2.30


  ;;==================================================================
  ;; SELECT THE GRIDDING PARAMETERS
  ;;==================================================================
  ; Current values are set for a grid of resolution 1 degree (lat/long) or 0.1 hours (local time)
  ; Changing the resolution of the grid might cause problems specially if the resolution is too high
  ; See v_geo_grid source code for details using GRIDDATA

  ; Y dimension LATITUDE
  Ysize    =   180    ;  90 ;36  ; number of elements of the grid on the Y dimension
  Ydelta   =    1     ;       5  ; grid spacing on the Y dimension
  YRange   = [-90, 90]; [-90, 0] ; start and stop of the Yaxis used for the grid

  If longitude then begin
    ; X dimension LONGITUDE
    Xsize   =  360   ; 72   ; number of elements of the grid on the X dimension
    XRange  = [0,360]       ; start and stop of the Xaxis used for the grid
    Xdelta  =   1    ; 5    ; grid spacing on the X dimension
  endif else begin
    ; X dimension LOCAL_TIME
    Xsize   =  240     ; 48      ; number of elements of the grid on the X dimension
    XRange  = [-12, 12]; start and stop of the Xaxis used for the grid
    Xdelta  =   0.1    ;0.5      ; grid spacing on the X dimension
  endelse

  trigrid_function = 0  ; (NOT RECOMMENDED) use of Trigrid (1) is more efficient and accurate although currently it doesnt work fine
  ;  see v_geo_grid source code for details


  ;;==================================================================
  ;;==================================================================
  ;;|||   ROUTINE   ## YOU SHOULD NOT MODIFY VALUES HERE BELOW ##  |||
  ;;==================================================================
  ;;==================================================================

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Check input paths
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  IF ~FILE_TEST(path_in  ,/DIR) THEN message, "## ERROR ## Input path does not exist"
  IF ~FILE_TEST(path_save,/DIR) THEN FILE_MKDIR, path_save
  IF ~FILE_TEST(path_png ,/DIR) && display_all THEN FILE_MKDIR, path_png

  IF ~FILE_TEST(path_save,/DIR) THEN message, "## ERROR ## Could not create path_save : "+path_save
  IF ~FILE_TEST(path_png ,/DIR) && display_all THEN message, "## ERROR ## Could not create path_png  : "+path_save

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Get RGB Table vectors (ignore if NO_DISPLAY is set)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  IF ~KEYWORD_SET(NO_DISPLAY) THEN BEGIN

    DEVICE, GET_DECOMPOSED=decomposed ; save original decomposed state
    TVLCT, R1, G1, B1, /GET           ; save original color table
    DEVICE, DECOMPOSED=0
    LOADCT, color_table & TVLCT, R,G,B,/GET ; get RGB of STD-GAMMA palette
    RGB_table=[[R],[G],[B]]
    TVLCT, R1, G1, B1 ;restore original color table

  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Disable display if NO_DISPLAY is used
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  IF KEYWORD_SET(NO_DISPLAY) THEN BEGIN
    disp_ENVI       = 0
    disp_MAP        = 0
    disp_IMAP       = 0
    display_all     = 0
    disp_iContour   = 0
    disp_iImage     = 0
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Get list of Raw and Geo files
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  filter    = "*"+search_key+"*.CAL*"
  qube_list = FILE_SEARCH(path_in, filter, count=countqubes)
  IF countqubes EQ 0 THEN BEGIN
    print, "ERROR: no CAL qubes found matching key"
    return
  ENDIF

  filter    = "*"+search_key+"*.GEO"
  geo_list  = FILE_SEARCH(path_in, filter, count=countgeos)
  IF countgeos  EQ 0 THEN BEGIN
    print, "ERROR: no GEO qubes found matching key"
    return
  ENDIF

  Ytitle = "LATITUDE"
  if longitude then xtitle="LONGITUDE" else Xtitle = "LOCAL TIME"

  accumulated_grid = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN'))
  if keyword_set(only_coverage) then $
    accumulated_grid = MAKE_ARRAY(Xsize,Ysize,/BYTE, VALUE=0)

  ; Initialise variables
  fnamelist = ""          ; list of filenames
  fdatelist = 0.          ; list of dates for each file

  Reference_date = 2453846 ;reference date which would correspond to start of orbit 0 (theoretical reference value considering that orbit period is 24H)
  ; Reference_Date = 2453683.6 ; Julian date of launch used for reference (UTC 2005-11-09T03:33:34)

  ; Set output filename
  outfilepath = path_save+'Accumulated_Grids_'+FILE_BASENAME(path_in)+'_'+strjoin(strsplit(search_key,"[]",/EXTRACT))+'_'+suffix+'.DAT'

  ; Delete file in case it already existed
  FILE_DELETE, outfilepath,/ALLOW_NONEXISTENT

  ; create progress bar
  IF ~KEYWORD_SET(NO_DISPLAY) THEN $
    progressbar = Obj_New('progressbar', Color='Red', Text='Processing... 0 '+'%',$
    /NOCANCEL,/start,title='Accumulated projection process',xsize=300,ysize=20)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Define planes
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  TOTAL_grid      = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN'))
  AVG_grid        = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN'))
  COUNT_grid      = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=0L)
  ;STDEV_grid      = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN')) ; are not calculated now, TBD
  ;STDEV_norm_grid = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN')) ; are not calculated now, TBD
  XPlane          = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN'))
  YPlane          = MAKE_ARRAY(Xsize,Ysize,/FLOAT, VALUE=float('NaN'))

  ;======================================================================
  ;; LOOP for each file
  ;======================================================================
  FOR i=0,countqubes-1 DO BEGIN

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; error handling lines, if an error is detected, report and go on with next qubes
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    IF ~keyword_set(debug) then begin
      catch, error_stat
      if error_stat ne 0 then begin
        catch, /cancel
        Help, /Last_Message, OUTPUT=errormessage
        IF N_ELEMENTS(qube_file) GT 0 THEN print, "ERROR processing file "+qube_file
        print, transpose(errormessage)
        CONTINUE
      endif
    ENDIF

    qube_file=qube_list[i]
    label = v_headpds(qube_file, /SILENT)

    ; Update progress bar
    IF ~KEYWORD_SET(NO_DISPLAY) THEN $
      progressbar -> Update, fix(i*100./countqubes), Text='Processing ' +FILE_BASENAME(qube_file)+'... ('+ StrTrim(fix(i*100./countqubes),2)+'%)'

    ;exclude these files that cannot be read or have some problem
    IF (STRPOS(qube_file,'0042_00') GE 0) || $
      (STRPOS(qube_file,'0040_00') GE 0) || $
      (STRPOS(qube_file,'0044_02') GE 0) || $
      (STRPOS(qube_file,'0276_02') GE 0) || $
      (STRPOS(qube_file,'0276_05') GE 0) || $
      (STRPOS(qube_file,'0292_07') GE 0) || $
      (STRPOS(qube_file,'0520_04') GE 0) || $
      (STRPOS(qube_file,'0520_06') GE 0) || $
      (STRPOS(qube_file,'0385_07') GE 0) || $
      (STRPOS(qube_file,'0444_08') GE 0) || $
      (STRPOS(qube_file,'0505_05') GE 0) || $
      (STRPOS(qube_file,'0503_07') GE 0) || $  _
      (STRPOS(qube_file,'0024_00') GE 0) || $   ;
      (STRPOS(qube_file,'0027_00') GE 0) || $   ;
      (STRPOS(qube_file,'0076_18') GE 0) || $   ;
      (STRPOS(qube_file,'0095_18') GE 0) || $   ;
      (STRPOS(qube_file,'0096_18') GE 0) || $   ; TB3.8 north weird
      (STRPOS(qube_file,'0098_18') GE 0) || $   ;
      (STRPOS(qube_file,'0108_02') GE 0) || $   ;
      (STRPOS(qube_file,'0139_16') GE 0) || $   ;
      (STRPOS(qube_file,'0453_08') GE 0) || $   ;
      (STRPOS(qube_file,'0458_09') GE 0) || $   ;
      (STRPOS(qube_file,'0459_09') GE 0) || $   ;
      (STRPOS(qube_file,'0463_08') GE 0) || $   ;
      (STRPOS(qube_file,'0600_02') GE 0) || $   ;
      (STRPOS(qube_file,'0602_02') GE 0) || $  _;
      (STRPOS(qube_file,'0521_04') GE 0) || $   ;
      (STRPOS(qube_file,'0521_05') GE 0) || $   ;
      (STRPOS(qube_file,'0757_00') GE 0) || $   ;
      (STRPOS(qube_file,'0871_04') GE 0) || $   ;
      (STRPOS(qube_file,'0875_04') GE 0) || $   ;
      (STRPOS(qube_file,'0344_03') GE 0) || $   ;
      (STRPOS(qube_file,'0339_06') GE 0) || $   ;
      (STRPOS(qube_file,'0333_00') GE 0) || $   ;
      (STRPOS(qube_file,'0342_04') GE 0) || $   ; Occultations
      (STRPOS(qube_file,'0390_10') GE 0) || $   ;
      (STRPOS(qube_file,'0390_09') GE 0) || $   ;
      (STRPOS(qube_file,'0332_03') GE 0) || $  _;
      (STRPOS(qube_file,'0341_06') GE 0) || $   ;
      (STRPOS(qube_file,'0340_06') GE 0) || $   ;
      (STRPOS(qube_file,'0331_03') GE 0) || $   ;
      (STRPOS(qube_file,'0342_06') GE 0) || $   ;
      (STRPOS(qube_file,'0346_05') GE 0) || $   ;
      (STRPOS(qube_file,'0343_06') GE 0) || $   ;
      (STRPOS(qube_file,'0300_04') GE 0) || $   ;
      (STRPOS(qube_file,'0380_02') GE 0) || $   ;
      (STRPOS(qube_file,'0325_03') GE 0) || $   ;
      (STRPOS(qube_file,'0579_04') GE 0) || $   ;
      (STRPOS(qube_file,'0302_00') GE 0) || $   ;
      (STRPOS(qube_file,'0479_03') GE 0) || $   ;
      (STRPOS(qube_file,'0112_01') GE 0) || $   ;
      (STRPOS(qube_file,'0102_15') GE 0) || $   ;
      (STRPOS(qube_file,'0366_03') GE 0) || $   ;
      (STRPOS(qube_file,'0307_02') GE 0) || $   ;
      (STRPOS(qube_file,'0335_00') GE 0) || $   ;
      (STRPOS(qube_file,'0345_06') GE 0) || $   ; Files with spikes
      (STRPOS(qube_file,'0347_06') GE 0) || $   ;  or wrong values
      (STRPOS(qube_file,'0349_06') GE 0) || $   ; that make my map ugly
      (STRPOS(qube_file,'0348_04') GE 0) || $   ;(they should be double checked)
      (STRPOS(qube_file,'0381_05') GE 0) || $   ;
      (STRPOS(qube_file,'0380_06') GE 0) || $   ;
      (STRPOS(qube_file,'0476_03') GE 0) || $   ;
      (STRPOS(qube_file,'0479_05') GE 0) || $   ;
      (STRPOS(qube_file,'0298_03') GE 0) || $   ;
      (STRPOS(qube_file,'0332_06') GE 0) || $   ;
      (STRPOS(qube_file,'0334_03') GE 0) || $   ;
      (STRPOS(qube_file,'0335_06') GE 0) || $   ;
      (STRPOS(qube_file,'0337_06') GE 0) || $   ;
      (STRPOS(qube_file,'0337_04') GE 0) || $   ;
      (STRPOS(qube_file,'0336_07') GE 0) || $   ;
      (STRPOS(qube_file,'0137_15') GE 0) || $   ;
      (STRPOS(qube_file,'0467_02') GE 0) || $   ;
      (STRPOS(qube_file,'0337_03') GE 0) || $   ;
      (STRPOS(qube_file,'0374_05') GE 0) || $  _;
      (STRPOS(qube_file,'0090_06') GE 0) || $ <-;  makes map ugly in the north
      (STRPOS(qube_file,'0094_18') GE 0) || $ <-;  makes map ugly in the north
      (STRPOS(qube_file,'0097_19') GE 0) || $ <-;  makes map ugly in the north
      (STRPOS(qube_file,'0100_15') GE 0) || $ <-;  makes map ugly in the north
      (STRPOS(qube_file,'0317_')GE 0)                || $ <-;  orbit with weird values
      (STRPOS(qube_file,'0567_')GE 0)                || $ <-;  makes map ugly
      (STRPOS(qube_file,'0501_')GE 0)                || $ <-;  makes map ugly
      (STRPOS(qube_file,'0000_')GE 0)                || $ <-;  VOI
      (STRPOS(qube_file,'0005_')GE 0)                || $ <-;  VOCP
      (STRPOS(qube_file,'0420_')GE 0)                || $ <-;  software upload
      (STRPOS(qube_file,'0422_04')GE 0)                || $ <-;  144 bands
      (STRPOS(qube_file,'0155_01') GE 0) THEN CONTINUE

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; READ LABEL VALUES (SCIENCE_CASE_ID)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    Science_case_id = v_pdspar(label, "SCIENCE_CASE_ID")
    IF Science_case_id lt min_science_case_id THEN CONTINUE
    IF Science_case_id gt max_science_case_id THEN CONTINUE

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; READ LABEL VALUES (EXP time)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    Frame_Param        = STRSPLIT(v_pdspar(label, "FRAME_PARAMETER"     ),'{}(),',/EXTRACT)
    Frame_Param_desc   = STRSPLIT(v_pdspar(label, "FRAME_PARAMETER_DESC"),'{}(),',/EXTRACT)
    LBL_Exptime  = Frame_Param[where(strpos(Frame_Param_desc,"EXPOSURE_DURATION"    ) GE 0)]
    IF LBL_Exptime lt Min_ExpTime THEN CONTINUE
    IF LBL_Exptime gt Max_ExpTime THEN CONTINUE

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; READ LABEL VALUES (TEMPERATURE limits)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    Temperatures  = STRSPLIT(v_pdspar(label, "MAXIMUM_INSTRUMENT_TEMPERATURE"),'{}(),',/EXTRACT)
    Inst_Temps    = STRSPLIT(v_pdspar(label, "INSTRUMENT_TEMPERATURE_POINT"  ),'{}(),',/EXTRACT)
    LBL_Temp_Spec = Temperatures[where(strpos(Inst_Temps, "SPECTROMETER") GE 0)]

    if LBL_Temp_Spec GT max_temperature || LBL_Temp_Spec LT min_temperature then begin

      print, "SKIPPED "+FILE_BASENAME(qube_file)+": Spectrometer Temperature "+strtrim(LBL_Temp_Spec,2)+" outside limits ["+strtrim(min_temperature,2)+","+strtrim(max_temperature,2)+"]"
      CONTINUE

    endif


    ;find associated geo file, if it doesn't exist, skip file
    file_noext = STRMID(FILE_BASENAME(qube_file),0,9)
    findgeo = where(STRPOS(geo_list, file_noext, /REVERSE_SEARCH) NE -1)
    if findgeo[0] ne -1 then geo_file = geo_list[findgeo[0]] else CONTINUE

    ;read qube dimensions
    Qube_items      = v_pdspar(label, "CORE_ITEMS")
    Qube_items      = v_listpds(Qube_items[N_ELEMENTS(Qube_items)-1])
    Qube_bands   = qube_items[0]
    Qube_samples = qube_items[1]
    Qube_lines   = qube_items[2]

    ; Get date of each cube and save in list
    scet = v_pdspar(label,"SPACECRAFT_CLOCK_START_COUNT")
    date = v_scet2jul(scet,/NO_WARNING)-Reference_Date ;Days from launch

    IF only_coverage then $
      ; If only coverage is needed, build a fake band with value 1
      Band = MAKE_ARRAY(qube_samples,qube_lines,VALUE=1.,/FLOAT) $
    else $
      ; otherwise set a dummy band 0, so that correct band is read from the qube
      Band=0

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GRID DATA
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    grid=v_geo_grid( qube_file, geo_file                      ,$
      ;QUBE = qube, GEO = geo                  ,$
      INDEX_BAND          = index_band         ,$
      INDEX_RATIO         = index_ratio        ,$
      INDEX_CONTINUUM     = index_continuum    ,$
      INDEX_THERMAL       = index_thermal      ,$
      INDEX_CONT_THERMAL  = index_cont_thermal ,$
      THERMAL_RATIO       = thermal_ratio      ,$
      INDEX_GEO           = index_GEO          ,$
      BAND                = band               ,$
      LONGITUDE           = longitude          ,$
      ONLY_POSITIVE       = only_positive      ,$
      AVERAGE             = average            ,$
      MEDIAN_FILTER       = median_filter      ,$
      THERMAL_BRIGHTNESS  = thermal_brightness ,$
      POST_EMA_CORRECTION = post_ema_correction,$
      EMA_CORRECTION_1_27 =EMA_CORRECTION_1_27 ,$
      EMA_CORRECTION_1_74 =EMA_CORRECTION_1_74 ,$
      EMA_CORRECTION_2_3  =EMA_CORRECTION_2_3  ,$
      EMA_CORRECTION_3_8  =EMA_CORRECTION_3_8  ,$
      EMA_CORRECTION_5_0  =EMA_CORRECTION_5_0  ,$
      INTERPOLATE_CO      = interpolate_co     ,$
      INTERPOLATE_H2O     = interpolate_h2o    ,$
      RAYLEIGH            = Rayleigh           ,$
      NIGHTSIDE           = nightside          ,$
      DAYSIDE             = dayside            ,$
      MIN_EMERGENCE_ANGLE = min_emergence_angle,$
      MAX_EMERGENCE_ANGLE = max_emergence_angle,$
      MAX_INCIDENCE_ANGLE = max_incidence_angle,$
      MIN_INCIDENCE_ANGLE = min_incidence_angle,$
      MAX_ELEVATION       = max_elevation      ,$
      MIN_ELEVATION       = min_elevation      ,$
      MAX_TEMPERATURE     = max_temperature    ,$
      MIN_TEMPERATURE     = min_temperature    ,$
      MAX_INPUT           = max_input          ,$
      MIN_INPUT           = min_input          ,$
      MAX_VALUE           = max_value          ,$
      MIN_VALUE           = min_value          ,$
      TRIGRID_FUNCTION    = trigrid_function   ,$
      XSIZE =xsize , YSIZE =ysize              ,$
      XDELTA=xdelta, YDELTA=ydelta             ,$
      XRANGE=xrange, YRANGE=yrange             ,$
      XAXIS =xaxis , YAXIS=Yaxis               ,$
      DEBUG=debug, NO_POPUPS=no_display)

    if N_ELEMENTS(grid) eq 1 then continue ;if grid could not be generated, skip cube

    if keyword_set(only_coverage) then grid = byte(grid) $
    else grid = float(grid) ; in case output is given in double

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Display each grid with CONTOUR (optional if "display_all" is set)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    IF display_all then begin

      TVLCT, R, G, B ;load color table

      CONTOUR, grid, xAxis, yAxis                    ,$
        YTITLE=yTitle, XTITLE=xtitle                  ,$
        TITLE="Contour Grid "+FILE_BASENAME(qube_file),$
        NLEVELS=128, C_COLORS=indgen(128)*2           ,$
        /YSTYLE, /XSTYLE                              ,$
        POSITION=[0.08, 0.05, 0.9, 0.95]              ,$
        BACKGROUND=255, COLOR=0

      colorbar, COLOR=0, POSITION=[0.95, 0.05, 0.99, 0.95], /VERTICAL

      IF longitude THEN gridtype="lat-long" ELSE gridtype = "lat-loct"

      img = TVRD(/TRUE)
      WRITE_PNG, path_png+FILE_BASENAME(qube_file)+"_"+gridtype+"_"+suffix+".png", img

      TVLCT, R1, G1, B1 ;restore original color table

    ENDIF

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Save Date and FileName
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    fnamelist = [fnamelist,file_basename(qube_file)]
    fdatelist = [fdatelist,date]

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Append each grid in the accumulated binary file
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Radiance
    openw   , lun, outfilepath, /get_lun, /SWAP_IF_BIG_ENDIAN, /APPEND
    writeu  , lun, grid
    close   , lun
    free_lun, lun

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Calculate statistics
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    TOTAL_grid = TOTAL([[[TOTAL_grid]],[[grid]]],3,/NAN) ; Add pixel values
    COUNT_grid = COUNT_GRID+FINITE(grid) ; Count pixels with valid radiance

  ENDFOR ;end of loop
  ;======================================================================

  catch, /cancel ; cancel error catching

  IF ~KEYWORD_SET(NO_DISPLAY) THEN progressbar -> Destroy

  ; remove first dummy element of the variables
  IF N_ELEMENTS(fnamelist) GT 1 THEN BEGIN
    ;	accumulated_grid = accumulated_grid[*,*,1:*]
    fnamelist = fnamelist[1:*]
    fdatelist=fdatelist[1:*]
  ENDIF ELSE BEGIN
    print, "ERROR: no file was processed"
    return
  ENDELSE

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Create X/Y planes
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  for i=0, xsize-1 do begin
    for j=0, ysize-1 do begin
      XPlane[i,j] = xAxis[i]
      YPlane[i,j] = yAxis[j]
    endfor
  endfor

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Compute statistics
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  AVG_grid = TOTAL_grid / float(COUNT_grid) ; Average value

  ; ### OLD ###
  ; for i=0, xsize-1 do begin
  ;	for j=0, ysize-1 do begin
  ;		ind=where(accumulated_grid[i,j,*] GT 0,countfinite)
  ;		Count_grid[i,j]=countfinite
  ;		if countfinite eq 0 then CONTINUE
  ;		TOTAL_grid[i,j]=  TOTAL(accumulated_grid[i,j,*],/NAN) ; Total Value
  ;		AVG_grid[i,j]  =   MEAN(accumulated_grid[i,j,*],/NAN) ; Mean Value
  ;		if countfinite eq 1 then STDEV_grid[i,j] = 0 else $
  ;		STDEV_grid[i,j] =STDDEV(accumulated_grid[i,j,*],/NAN);Standard Deviation
  ;		STDEV_norm_grid[i,j] = STDEV_grid[i,j]/AVG_grid[i,j]  ;Normalized Stdev
  ;	endfor
  ; endfor

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; SAVE RESULTS
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  IF savefile THEN BEGIN
    date=string(FORMAT='(C(CYI,CMOI2.2,CDI2.2,"T",CHI2.2,CMI2.2))',systime(/jul, /utc))
    SAVE, filename=path_save+'IDLsavefile_'+date+'_'+FILE_BASENAME(path_in)+'_'+strjoin(strsplit(search_key,"[]",/EXTRACT))+'_'+suffix+".dat"
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Display with iIMAGE
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  IF disp_iImage then begin
    IIMAGE, AVG_grid, $;xAxis, yAxis, $
      YTITLE=yTitle, XTITLE=xtitle      ,$
      TITLE="Grid "+FILE_BASENAME(qube_file),$
      ; NLEVELS=128, C_COLORS=indgen(128)*2   ,$
      /YSTYLE, /XSTYLE                      ,$
      POSITION=[0.08, 0.05, 0.9, 0.95]     ,$
      BACKGROUND=255, COLOR=0, RGB_TABLE=RGB_table
    ; Display COLORBAR (see  http://www.ittvis.com/services/techtip.asp?ttid=3812 )
    void = itgetcurrent(TOOL=oTool)
    void = oTool->DoAction(oTool->FindIdentifiers('*INSERT/COLORBAR'))
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Display with iCONTOUR
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF disp_iContour then begin
    iCONTOUR, AVG_grid, xAxis, yAxis, $
      YTITLE=yTitle, XTITLE=xtitle  ,$
      TITLE="Grid "+FILE_BASENAME(qube_file), VIEW_TITLE=FILE_BASENAME(qube_file),$
      N_LEVELS=128, RGB_TABLE=RGB_table
    ; Display COLORBAR (see  http://www.ittvis.com/services/techtip.asp?ttid=3812 )
    void = itgetcurrent(TOOL=oTool)
    void = oTool->DoAction(oTool->FindIdentifiers('*INSERT/COLORBAR'))

  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Set TITLE
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  if keyword_set(only_coverage     ) then ZTitle = "Number of observations"      else $
    if keyword_set(thermal_brightness) then ZTitle = "Thermal Brightness [kelvin]" else $
    if keyword_set(Rayleigh          ) then ZTitle = "Rayleigh [MR]" else $
    if n_elements(index_ratio        ) then ZTitle = "Ratio" else $
    ZTitle = "Radiance [W/m2/microns/sr]"

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Create ENVI files
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; Create ENVI header for file with accumulated grids
  idl_envi_setup_head, FNAME=outfilepath, bnames=fnamelist, WL=fdatelist, DATA_TYPE=4, $
    interleave = 0, NB = N_elements(fnamelist),NS = Xsize ,NL = Ysize , $ OFFSET = 0 ,$
    descrip='Accumulated Grids "'+path_in+'" [*'+search_key+'*.CAL]',$
    ZPLOT_TITLES=["Orbit Number",ZTitle], $
    OPEN=keyword_set(disp_ENVI) ; open in ENVI if disp_ENVI is set

  ; Create ENVI file with accumulated results
  accumulated_qube=[[[AVG_grid]],[[TOTAL_grid]],[[Count_grid]],[[XPlane]],[[YPlane]]]
  accumulated_qube=transpose(accumulated_qube,[2,0,1])

  write_pds_file_with_detached_label, QUBE=accumulated_qube,$ ; [[STDEV_grid]],[[STDEV_norm_grid]], ## TBD ##
    bnames=["Mean value","Total value","Counter",XTitle,YTitle]       ,$ ;"Stdev",       "Stdev normalised",
    NAME='Accumulated Results "'+path_in+' '+suffix+' ['+search_key+']',$
    FILENAME=path_save+'Accumulated_Results_'+FILE_BASENAME(path_in)+'_'+strjoin(strsplit(search_key,"[]",/EXTRACT))+'_'+suffix+'.DAT',$
    DISPLAY_LABEL=0,OPEN_ENVI=keyword_set(disp_ENVI); open in ENVI if disp_ENVI is set

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Display using Map Projection
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF disp_MAP || disp_iMAP then begin

    ; If coverage was selected, plot counts instead of average
    if keyword_set(only_coverage) then z= TOTAL_grid else z= AVG_grid

    ; Pass plane with local_time or longitude
    if keyword_set(longitude) then Long_plane=Xplane else Loct_plane = XPlane

    v_map_projection, event, path_png_map, Z=Z, RANGE=range,CENTER_LONG=0,CENTER_LATITUDE=-90,$
      Lat=YPlane, Lon=Long_plane, LOCAL_TIME=Loct_plane,$
      DELLON = 45, DELLAT = 15, RESOLUTION = [800, 600],$
      PROJECTION_NAME="Stereographic",$
      ;TITLE='Averaged MAP "'+path_in+'" [*'+strjoin(strsplit(search_key,"[]",/EXTRACT))+'*.CAL] '+suffix,$
      TITLE=suffix+' '+search_key,$
      COLORBAR_TITLE=ZTitle, RGB_TABLE=RGB_Table, COLOR_TABLE=color_table,$
      IMAGE_TOOL=disp_iMap, QUERY=query, INVERTED=inverted, SAVEPNG=savePNGmap

  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; RESTORE DISPLAY STATUS
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF ~KEYWORD_SET(NO_DISPLAY) THEN BEGIN
    DEVICE, DECOMPOSED=decomposed ; restore original decomposed state
    TVLCT, R1, G1, B1             ; restore original color table
  ENDIF

END