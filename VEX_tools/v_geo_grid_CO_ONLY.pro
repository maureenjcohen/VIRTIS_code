;+
; NAME:
;     V_GEO_GRID
;
; PURPOSE:
;     Reads selected band(s) from an input VIRTIS calibrated qube and returns the
;     radiance distribution in a grid of either Latitude/Longitude or Latitude/LocalTime.
;
;     It is possible to substract the continuum and the thermal contribution.
;     It is possible to return the grid of given geometrical parameter instead of a radiance.
;
; OPTIONAL INPUTS:
;     qube_file : input path to read calibrated qube (not needed if QUBE or BAND keyword is used)
;     geo_file  : input path to read geometry   qube (not needed if GEO  keyword is used)
;
; OPTIONAL KEYWORDS:
;     QUBE: by default the routine reads the qube from the given qube_file path.
;           If the qube is already in memory, it can be passed directly as a variable (to increase speed)
;           This variable is the output of the virtispds routine, i.e. a qube structure (result)
;
;           Note: if this keyword is used, qube_file is ignored. Either qube_file or QUBE must be used.
;
;     GEO:  by default the routine reads the geo qube from the given geo_file path.
;           If the geometry qube is already in memory, it can be passed directly as a variable (to increase speed)
;           This variable is the output of the virtispds routine, i.e. a qube structure (result)
;
;           Note: if this keyword is used, geo_file is ignored. Either geo_file or GEO must be used.
;
;     INDEX_BAND : index of the band or bands to consider for the grid. (*)
;            This keyword is needed unless the BAND keywordx is used
;
;     INDEX_RATIO : index of the band or bands to be considered for the ratio (BAND/RATIO)
;
;     INDEX_CONTINUUM : index of the band or bands to consider for the continuum. (*)
;            This keyword is ignored if THERMAL_BRIGHTNESS is used
;
;     INDEX_THERMAL : index of the bands to be considered for the thermal contribution. (*)
;            This keyword is ignored if THERMAL_BRIGHTNESS is used
;
;     INDEX_CONT_THERMAL : index of the bands to be considered for the continuum of the thermal contribution. (*)
;            This keyword is ignored if THERMAL_BRIGHTNESS is used
;
;     THERMAL_RATIO: ratio to be considered for the thermal constribution subtraction. The formula used is :
;                          RESULT = (BAND-CONTINUUM) - THERMAL_RATIO x (THERMAL-THERMAL_CONTINUUM)
;
;     INDEX_GEO : index of the geo band to be used INSTEAD of the radiance band. (*)
;             If this keyword is used, QUBE, qube_file and all the other indexes (Index_Band, etc) are ignored.
;
;     (*) Note all indices start counting from 0.
;     (*) Note all indices can be a scalar or a 1-D array. In case of an array, the indexed bands are averaged.
;
;     AVERAGE: 1 to average all indexed bands (default), 0 to do the integration (if ThermalBrightness is set, average is used)
;
;     BAND: by default the routine reads the band from the input qube or qube_file.
;           Use this keyword to pass directly the band to consider for the grid.
;           If this keyword is used, QUBE, qube_file and all the indexes (Index_Band, etc) are ignored
;           If this keyword is used THERMAL_BRIGHTNESS cannot be computed and is ignored
;
;     THERMAL_BRIGHTNESS: convert radiance into thermal brightness (K) before processing.
;                         If this keyword is set, continuum subtraction is not allowed, and bands are always averaged (not integrated)
;
;     RAYLEIGH: convert radiance into rayleigh (MR) before processing.
;
;     POST_EMA_CORRECTION: set by default to perform emission angle correction after other corrections/conversions (rayleigh, thermal brightness)
;                          set to 0 to perform before applying corrections and convertions
;
;     EMA_CORRECTION_1_27: set to perform emission angle correction (see emission_angle_correction_1_27.pro)
;
;     EMA_CORRECTION_1_74: set to perform emission angle correction (see emission_angle_correction_1_74.pro)
;
;     EMA_CORRECTION_2_3 : set to perform emission angle correction (see emission_angle_correction_2_3.pro)
;
;     EMA_CORRECTION_3_8 : set to perform emission angle correction (see emission_angle_correction_3_8.pro)
;
;     EMA_CORRECTION_5_0 : set to perform emission angle correction (see emission_angle_correction_5_0.pro)
;
;     LONGITUDE: by default, the grid used is Latitude - Local Time. Set this keyword to use Latitude-Longitude.
;
;     MIN_EMERGENCE_ANGLE: Minimum emergence angle to be considered. Pixels below this value are ignored.
;                          It must be a value between 0 and 90 degrees (0 by default).
;
;     MAX_EMERGENCE_ANGLE: Maximum emergence angle to be considered. Pixels over this value are ignored.
;                         It must be a value between 0 and 90 degrees (90 by default).
;
;     MIN_INCIDENCE_ANGLE: Minimum incidence angle to be considered. Pixels below this value are ignored.
;                         It must be a value between 0 and 180 degrees (0 by default).
;
;     MAX_INCIDENCE_ANGLE: Maximum incidence angle to be considered. Pixels over this value are ignored.
;                         It must be a value between 0 and 180 degrees (180 by default).
;
;     MIN_ELEVATION: Minimum elevation to be considered. Pixels below this value are ignored.
;                    Pixels not intercepting surface have an offset of 100. (-999 by default).
;
;     MAX_ELEVATION: Maximum elevation to be considered. Pixels above this value are ignored.
;                    Pixels not intercepting surface have an offset of 100. (+999 by default).
;
;     MIN_DISTANCE: Minimum slant distance (in Km) to be considered. Pixels below this value are ignored.
;
;     MAX_DISTANCE: Maximum slant distance (in Km) to be considered. Pixels above this value are ignored.
;
;     MIN_TEMPERATURE: Minimum spectrometer temperature (in K) to be considered. Observations below this value are ignored.
;
;     MAX_TEMPERATURE: Maximum spectrometer temperature (in K) to be considered. Observations above this value are ignored.
;
;     MIN_VALUE:    Minimum output value to be considered. Pixels below this value are ignored.
;
;     MAX_VALUE:    Maximum output value to be considered. Pixels above this value are ignored.
;
;     MIN_INPUT:    Minimum input value to be considered. Pixels below this value are ignored.
;
;     MAX_INPUT:    Maximum input value to be considered. Pixels above this value are ignored.
;
;     NIGHTSIDE : consider only nightside pixels
;                 (This is equivalent to MIN_INCIDENCE_ANGLE = 95)
;
;     DAYSIDE   : consider only dayside pixels
;                 (This is equivalent to MAX_INCIDENCE_ANGLE = 85)
;
;     ONLY_POSITIVE: consider only positive pixel values (otherwise the minimum is set to -999)
;
;     TRIGRID_FUNCTION: set this keyword to use TRIGRID function instead of classic GRIDDATA
;                       Trigrid is more efficient and accurate although it has problems in the boundaries for data centered at the pole
;                       GRIDDATA extends the grid borders a little bit and might leave some empty spaces in the grid.
;
;     * Trigrid is not fully tested so it is not recommeded for the moment. Future versions shall fix this.
;
;     [XY]SIZE : number of elements of the grid along X/Y dimension (default 512)
;
;     [XY]RANGE: range of the grid along X/Y dimension (uses range of the image by default)
;
;     [XY]DELTA: delta step of the grid along X/Y dimension
;
;     * If only one or two of the previous keywords (size, delta, range) are given, the rest are automatically calculated
;
;     [XY]AXIS: Output variable to store the X/Y Axis values of the generated grid
;
;     NO_POPUPS: do not show any dialog or progress bars
;
; OUTPUTS:
;     grid: 2-D grid with the values of radiance distributed Latitude-Longitude or Latitude-LocalTime
;           Empty grid elements are set to the IDL value NaN (not a number).
;
; ERROR CODES:
;     If the grid cannot be performed, one of the following error codes is returned
;      -1 : error with input parameters
;      -2 : no pixels where found matching the geometry constraints
;      -3 : all pixel values are outside the given Max/Min limits
;      -4 : other errors
;      -5 : out of temperature
;
; EXAMPLES:
;     See an example of routine at the end of this file.
;          EXAMPLE_geo_grid
;
;     Simple call of the function, index_band 76:
;          grid=v_geo_grid(qube_file, geo_file, INDEX_BAND=76)
;
;     Qube files are already in memory, do an average of several bands:
;          qube = virtispds()
;          geo  = virtispds()
;          grid = v_geo_grid(QUBE=qube, GEO=geo, INDEX_BAND=[128,130,132,134,136,138,140]), /AVERAGE
;
;     Build grid using Longitude (-180,180) instead of LocalTime, consider only emergence angle below 50,
;     integrate bands from 26 to 28
;          grid=v_geo_grid(qube_file, geo_file, INDEX_BAND=[26,27,28], AVERAGE=0,$
;                          MAX_EMERGENCE_ANGLE=50, /LONGITUDE)
;
; COMMENTS / RESTRICTIONS:
;     Only tested on IDL 6.2 for Windows.
;     Uses the VIRTIS Lecture_PDS package and the "v_crop_cube.pro" routine
;     Use of TRIGRID_FUNCTION keyword is not fully tested so it is not recommended for the moment. Future versions shall fix this.
;
; MODIFICATION HISTORY:
;     Written by Alejandro Cardesin, IASF-INAF, February 2008, alejandro.cardesin @ iasf-roma.inaf.it
;     Modified April 2008, A.Cardesin : Added INDEX_GEO keyword, modified comments
;     Modified April 2008, A.Cardesin : Added keywords for user-defined X/Y Axis: [XY]SIZE, [XY]DELTA, [XY]RANGE
;     Modified June  2008, A.Cardesin : Added Rayleigh conversion, Thermal Brigthness computed when cube is loaded
;                                       Changed keyword EM_ANGLE_CORRECTION into AIRGLOW_EMA_CORRECTION
;                                       Introduced EMA_CORRECTION for 1_27 (changed name), 1_74 and 2_3
;                                       Added TRIGRID, removed Epsilon keyword, solved bugs with XY axis, added v_crop_cube
;     Modified Dec   2008, A.Cardesin : Added keyword NO_POPUPS
;     Modified July  2009, A.Cardesin : Improved TRIGRID for images crossing noon or prime meridian. Still problems with Poles.
;                                       Improved comments
;     Modified Jan   2010, A.Cardesin : Added MAX/MIN_DISTANCE
;-

;================================================================================
; V_GEO_GRID
;================================================================================

FUNCTION v_geo_grid, qube_file, geo_file                     ,$
  QUBE=qube, GEO=geo , BAND=band          ,$
  INDEX_BAND         = index_band         ,$
  INDEX_RATIO        = index_ratio        ,$
  INDEX_CONTINUUM    = index_continuum    ,$
  INDEX_THERMAL      = index_thermal      ,$
  INDEX_CONT_THERMAL = index_cont_thermal ,$
  THERMAL_RATIO      = thermal_ratio      ,$
  INDEX_GEO          = index_geo          ,$
  LONGITUDE          = longkey            ,$
  ONLY_POSITIVE      = only_positive      ,$
  AVERAGE            = average            ,$
  MEDIAN_FILTER      = median_filter      ,$
  THERMAL_BRIGHTNESS = thermal_brightness ,$
  POST_EMA_CORRECTION= post_ema_correction,$
  EMA_CORRECTION_1_27=EMA_CORRECTION_1_27 ,$
  EMA_CORRECTION_1_74=EMA_CORRECTION_1_74 ,$
  EMA_CORRECTION_2_3 =EMA_CORRECTION_2_3  ,$
  EMA_CORRECTION_3_8 =EMA_CORRECTION_3_8  ,$
  EMA_CORRECTION_5_0 =EMA_CORRECTION_5_0  ,$
  RAYLEIGH           = Rayleigh           ,$
  NIGHTSIDE          = nightside          ,$
  DAYSIDE            = dayside            ,$
  MIN_EMERGENCE_ANGLE= min_emergence      ,$
  MAX_EMERGENCE_ANGLE= max_emergence      ,$
  MAX_INCIDENCE_ANGLE= max_incidence      ,$
  MIN_INCIDENCE_ANGLE= min_incidence      ,$
  MAX_ELEVATION      = max_elevation      ,$
  MIN_ELEVATION      = min_elevation      ,$
  MAX_DISTANCE       = max_distance       ,$
  MIN_DISTANCE       = min_distance       ,$
  MAX_TEMPERATURE    = max_temperature    ,$
  MIN_TEMPERATURE    = min_temperature    ,$
  MAX_VALUE          = max_value          ,$
  MIN_VALUE          = min_value          ,$
  MAX_INPUT          = max_input          ,$
  MIN_INPUT          = min_input          ,$
  TRIGRID_FUNCTION   = trigrid_function   ,$
  XSIZE =xsize , YSIZE =ysize             ,$
  XDELTA=xdelta, YDELTA=ydelta            ,$
  XRANGE=xrange, YRANGE=yrange            ,$
  XAXIS=xaxis, YAXIS=Yaxis, DEBUG=debug   ,$
  NO_POPUPS=no_popups

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; error handling lines, if an error is detected, notify and return
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF ~keyword_set(debug) then begin
    catch, error_stat
    if error_stat ne 0 then begin
      catch, /cancel
      Help, /Last_Message, OUTPUT=errormessage
      IF N_ELEMENTS(qube_file) GT 0 THEN print, "ERROR building grid for file "+qube_file
      print, transpose(errormessage)
      ;ok = DIALOG_MESSAGE("ERROR computing grid:"+string(errormessage[0]))
      return, -4
    endif
  ENDIF

  ; KEYWORDS ----------------------------------------------------------------------
  IF N_ELEMENTS(qube_file) EQ 0 && N_ELEMENTS(qube) EQ 0 && N_ELEMENTS(BAND) EQ 0 THEN BEGIN
    print, "ERROR: either qube_filename, qube variable or band must be given."
    return, -1
  ENDIF
  IF N_ELEMENTS(BAND) EQ 0 && N_ELEMENTS(INDEX_BAND) EQ 0 THEN BEGIN
    print, "ERROR: either BAND or INDEX_BAND must be defined."
    return, -1
  ENDIF
  IF N_ELEMENTS(geo_file) EQ 0 && N_ELEMENTS(geo) EQ 0 THEN BEGIN
    print, "ERROR: either geo_filename or geo qube must be given."
    return, -1
  ENDIF
  IF N_ELEMENTS(index_continuum) NE 0 && N_ELEMENTS(qube_file) EQ 0 && N_ELEMENTS(qube) EQ 0 THEN BEGIN
    print, "ERROR: either qube_filename or qube variable must be given to read continuum."
    return, -1
  ENDIF

  IF (N_ELEMENTS(Xsize ) NE 0) + (N_ELEMENTS(Xdelta ) NE 0) + (N_ELEMENTS(Xrange ) NE 0) EQ 3 THEN $
    IF XRange[0]+Xsize*Xdelta NE XRange[1] THEN message, "Error: Xsize, Xdelta and Xrange are not consistent"
  IF (N_ELEMENTS(Ysize ) NE 0) + (N_ELEMENTS(Ydelta ) NE 0) + (N_ELEMENTS(Yrange ) NE 0) EQ 3 THEN $
    IF YRange[0]+Ysize*Ydelta NE YRange[1] THEN message, "Error: Ysize, Ydelta and Yrange are not consistent"

  ;Set default variables
  LONGKEY              = KEYWORD_SET(longkey    )

  ;Set default values
  IF N_ELEMENTS(Average        ) EQ 0 THEN Average        = 1
  IF N_ELEMENTS(Only_positive  ) EQ 0 THEN Only_positive  = 1
  IF N_ELEMENTS(Min_Emergence  ) EQ 0 THEN Min_Emergence  = 0
  IF N_ELEMENTS(Max_Emergence  ) EQ 0 THEN Max_Emergence  = 90
  IF N_ELEMENTS(Max_Incidence  ) EQ 0 THEN Max_Incidence  = 180
  IF N_ELEMENTS(Min_Incidence  ) EQ 0 THEN Min_Incidence  = 0
  IF N_ELEMENTS(Max_Elevation  ) EQ 0 THEN Max_Elevation  = 999
  IF N_ELEMENTS(Min_Elevation  ) EQ 0 THEN Min_Elevation  = -999
  IF N_ELEMENTS(Max_Distance   ) EQ 0 THEN Max_Distance   = 1e6
  IF N_ELEMENTS(Min_Distance   ) EQ 0 THEN Min_Distance   = 0
  IF N_ELEMENTS(Max_Value      ) EQ 0 THEN Max_Value      = 1e6
  IF N_ELEMENTS(Min_Value      ) EQ 0 THEN Min_Value      = -999
  IF N_ELEMENTS(Max_Input      ) EQ 0 THEN Max_Input      = 1e6
  IF N_ELEMENTS(Min_Input      ) EQ 0 THEN Min_Input      = -999
  IF N_ELEMENTS(max_temperature) EQ 0 THEN max_temperature= 999
  IF N_ELEMENTS(min_temperature) EQ 0 THEN min_temperature= -999
  IF KEYWORD_SET(nightside     ) EQ 1 THEN Min_Incidence  = 95
  IF KEYWORD_SET(dayside       ) EQ 1 THEN Max_Incidence  = 85
  IF N_ELEMENTS(post_ema_correction) EQ 0 THEN post_ema_correction =1

  ;--------------------------------------------------------------------------------


  ;; CHECK TEMPERATURE LIMITS -----------------------------------------------------
  label         = v_headpds(qube_file,/silent)
  Temperatures  = STRSPLIT(v_pdspar(label, "MAXIMUM_INSTRUMENT_TEMPERATURE"),'{}(),',/EXTRACT)
  Inst_Temps    = STRSPLIT(v_pdspar(label, "INSTRUMENT_TEMPERATURE_POINT"  ),'{}(),',/EXTRACT)
  Temp_Spec     = Temperatures[where(strpos(Inst_Temps, "SPECTROMETER") GE 0)]

  if Temp_Spec GT max_temperature || Temp_Spec LT min_temperature then begin

    print, "v_geo_grid.pro SKIPPED "+FILE_BASENAME(qube_file)+": Spectrometer Temperature "+strtrim(Temp_Spec,2)+" outside limits ["+strtrim(min_temperature,2)+","+strtrim(max_temperature,2)+"]"
    return, -5

  endif


  ; GEOMETRY ----------------------------------------------------------------------
  if N_ELEMENTS(geo) EQ 0 THEN geo = virtispds(geo_file, /SILENT)
  ;;Print band names
  ;print, transpose([[string(indgen(33))],[geo.qube_name]])
  geo_qube = geo.qube
  geo_coef = geo.qube_coeff

  samples = long((size(geo_qube,/DIM))[1])
  lines   = long((size(geo_qube,/DIM))[2])

  ; REMOVE PROBLEMATIC COLUMNS/LINES -----------------------------------------------

  v_crop_cube, geo_qube, SCAN_MODE_ID=v_pdspar(geo.label, "SCAN_MODE_ID"), LINES=fixedlines, SAMPLES=fixedsamples

  ;---------------------------------------------------------------------------------

  ; GET GEOMETRY INFORMATION FROM GEO CUBE -----------------------------------------
  Latitude  = reform((geo_qube)[25,*,*])*(geo_coef)[25] ; latitude  on cloud layer
  Longitude = reform((geo_qube)[24,*,*])*(geo_coef)[24] ; longitude on cloud layer
  LocalTime = reform((geo_qube)[15,*,*])*(geo_coef)[15] ; local time
  Emergence = reform((geo_qube)[27,*,*])*(geo_coef)[27] ; emergence angle on cloud layer
  Incidence = reform((geo_qube)[26,*,*])*(geo_coef)[26] ; incidence angle on cloud layer
  Elevation = reform((geo_qube)[13,*,*])*(geo_coef)[13] ; elevation on surf layer
  Distance  = reform((geo_qube)[14,*,*])*(geo_coef)[14] ; slant distance
  ;--------------------------------------------------------------------------------

  ; Check Geometrical values (if emergence/incidence planes are given)-------------
  IF N_ELEMENTS(Emergence) GT 0 && N_ELEMENTS(Incidence) GT 0 THEN BEGIN
    ValidGeometryIndex = where( Emergence LE Max_Emergence AND $
      Emergence GE Min_Emergence AND $
      Incidence LE Max_Incidence AND $
      Incidence GE Min_Incidence AND $
      Elevation LE Max_Elevation AND $
      Elevation GE Min_Elevation AND $
      Distance  LE Max_Distance  AND $
      Distance  GE Min_Distance     ,$
      ValidGeometryCount)
  ENDIF ELSE BEGIN
    ValidGeometryCount = N_ELEMENTS(Latitude)       ;if emergence/incidence planes are not defined
    ValidGeometryIndex = indgen(ValidGeometryCount) ;consider all pixels of the plane
  ENDELSE

  IF ValidGeometryCount EQ 0 THEN return, -2
  ; -------------------------------------------------------------------------------

  ; INDEX_GEO (If defined use Geometrical Band instead of Radiance) ---------------
  IF N_ELEMENTS(index_geo) GT 0 THEN BEGIN
    band = reform((geo_qube)[index_geo,*,*])*(geo_coef)[index_geo]
  ENDIF
  ; -------------------------------------------------------------------------------

  ; RADIANCE (if given) -----------------------------------------------------------
  IF SIZE(band,/N_DIM) EQ 2 THEN BEGIN
    ; if radiance is passed as an input variable simply get it and fix its dimensions

    Radiance = band

    ; Remove wrong lines/samples
    IF N_ELEMENTS(Radiance) NE fixedsamples*fixedlines THEN BEGIN

      v_crop_cube, Radiance, SCAN_MODE_ID=v_pdspar(geo.label, "SCAN_MODE_ID"), LINES=fixedlines, SAMPLES=fixedsamples

    ENDIF

  ENDIF ELSE BEGIN

    ; READ CUBE --------------------------------------------
    IF N_ELEMENTS(qube) EQ 0 THEN qube = virtispds(qube_file, /SILENT)

    ; Filter NaN and Missing values
    cubefiltered = qube.qube
    v_fcode, cubefiltered, Filter=2

    ; Remove wrong lines/samples
    v_crop_cube, cubefiltered, SCAN_MODE_ID=v_pdspar(geo.label, "SCAN_MODE_ID"), LINES=fixedlines, SAMPLES=fixedsamples

	dims = SIZE(cubefiltered, /DIMENSIONS)
	FOR line = 0, dims[2]-1  DO BEGIN
		print, qube.table[133:139,line,0]
		cubefiltered[133:139,*,line] = interpIntegrate_3D((qube.table)[133:139,line,0], cubefiltered[133:139,*,line], 0, 6, [qube.table[133,line,0], 2.2900, 2.3000, 2.3050, 2.3100, 2.3200, qube.table[139,line,0]],/DO_CHECK)
	ENDFOR

    ;Convert band index in case total bands are not 432
    iband  = index_band *(qube.qube_dim)[0]/432.
    ; Get bands and wavelengths from qube fitlered -----------------
    BANDS      = cubefiltered[iband ,*,*]

    if n_elements (index_ratio) GT 0 then begin
    iratio = index_ratio*(qube.qube_dim)[0]/432.
    RATIOBANDS = cubefiltered[iratio,*,*]
    endif

    WAVELENGTHS=(qube.table)[iband,0,0]

    ; Ignore input values beyond min/max_input (set to NaN)
    invalidInputIndex=where((BANDS LT min_input) OR (BANDS GT max_input), inValidInputCount)
    if inValidInputCount GT 0 then BANDS[invalidInputIndex] = !values.F_Nan


    ; IF POST_EMA_CORRECTION=0
    ; DO EMISSION ANGLE CORRECTION NOW (before converting to Rayleigh or Thermal Brightness and before Continuum Subt) ---
    IF POST_EMA_CORRECTION EQ 0 then begin
      If Keyword_Set(EMA_correction_1_27) Then begin
        emission_angle_correction_1_27, QUBE=BANDS, EM=Emergence, CORRECTED=corrected_BANDS, NO_POPUPS=no_popups
        BANDS = corrected_BANDS
      endif
      If Keyword_Set(EMA_CORRECTION_1_74) Then begin
        emission_angle_correction_1_74, QUBE=BANDS, EM=Emergence, CORRECTED=corrected_BANDS, NO_POPUPS=no_popups
        BANDS = corrected_BANDS
      endif
      If Keyword_Set(EMA_CORRECTION_2_3 ) Then begin
        emission_angle_correction_2_3,  QUBE=BANDS, EM=Emergence, CORRECTED=corrected_BANDS, NO_POPUPS=no_popups
        BANDS = corrected_BANDS
      endif
      If Keyword_Set(EMA_CORRECTION_3_8 ) Then begin
        emission_angle_correction_3_8,  QUBE=BANDS, EM=Emergence, CORRECTED=corrected_BANDS, NO_POPUPS=no_popups
        BANDS = corrected_BANDS
      endif
      If Keyword_Set(EMA_CORRECTION_5_0 ) Then begin
        emission_angle_correction_5_0,  QUBE=BANDS, EM=Emergence, CORRECTED=corrected_BANDS, NO_POPUPS=no_popups
        BANDS = corrected_BANDS
      endif
    endif
    ;--------------------------------------------------------------------------------

    ; IF POST_EMA_CORRECTION=0
    ; DO EMISSION ANGLE CORRECTION NOW (before converting to Rayleigh or Thermal Brightness and before Continuum Subt) ---
    IF POST_EMA_CORRECTION EQ 0 then begin
      If Keyword_Set(EMA_correction_1_27) Then begin
        emission_angle_correction_1_27, QUBE=RATIOBANDS, EM=Emergence, CORRECTED=corrected_ratiobands, NO_POPUPS=no_popups
        ratiobands = corrected_ratiobands
      endif
      If Keyword_Set(EMA_CORRECTION_1_74) Then begin
        emission_angle_correction_1_74, QUBE=ratiobands, EM=Emergence, CORRECTED=corrected_ratiobands, NO_POPUPS=no_popups
        ratiobands = corrected_ratiobands
      endif
      If Keyword_Set(EMA_CORRECTION_2_3 ) Then begin
        emission_angle_correction_2_3,  QUBE=ratiobands, EM=Emergence, CORRECTED=corrected_ratiobands, NO_POPUPS=no_popups
        ratiobands = corrected_ratiobands
      endif
      If Keyword_Set(EMA_CORRECTION_3_8 ) Then begin
        emission_angle_correction_3_8,  QUBE=ratiobands, EM=Emergence, CORRECTED=corrected_ratiobands, NO_POPUPS=no_popups
        ratiobands = corrected_ratiobands
      endif
      If Keyword_Set(EMA_CORRECTION_5_0 ) Then begin
        emission_angle_correction_5_0,  QUBE=ratiobands, EM=Emergence, CORRECTED=corrected_ratiobands, NO_POPUPS=no_popups
        ratiobands = corrected_ratiobands
      endif
    endif
    ;--------------------------------------------------------------------------------

    ; Rayleigh: convert to rayleigh
    If Keyword_Set(Rayleigh) Then Begin
      rad_to_rayleigh, QUBE=BANDS, WL=WAVELENGTHS, Rayleigh=rayleigh_cube, NO_POPUPS=no_popups
      BANDS = rayleigh_cube
    endif

    ; Thermal Brightness: convert to thermal brightness
    If Keyword_Set(Thermal_Brightness) Then Begin
      compute_thermal_brightness, QUBE=BANDS, WL=WAVELENGTHS, TB=TB, NO_POPUPS=no_popups
      BANDS = TB
    endif

    ; Median Filter for each single Band
    If Keyword_Set(Median_Filter) Then $
      for b=0,N_ELEMENTS(iband)-1 do BANDS[b,*,*]=MEDIAN(reform(BANDS[b,*,*]),3)

    ; Calculate Total Radiance
    Radiance = total(BANDS,1,/NAN)
    I_short = total(BANDS,1,/NAN)
    I_long = total(ratiobands,1,/NAN)
    ; Calculate Total ratiobands
    if N_ELEMENTS(ratiobands) GT 0 then Radiance = Radiance / total(ratiobands,1,/NAN)
	;if N_ELEMENTS(ratiobands) GT 0 then Radiance = 35 * EXP((I_long - 738.57*(I_short^2) - 0.31681*I_short - 9.8043e-9)/(-417.62 * (I_short^2) - 0.22764*I_short + 8.9506e-9))

    If Average || Keyword_Set(Thermal_Brightness) then begin
      counter  = float(total(FINITE(BANDS),1,/NAN))
      Radiance = Radiance/counter ;Total radiance divided by counter is the mean value

      if e_elements(ratio) GT 0 then begin
      	counter_ratio  = float(total(FINITE(ratiobands),1,/NAN))
      	ratiobands    = ratiobands/counter_ratio ;Total ratiobands divided by counter is the mean value
      	Radiance = Radiance / total(RATIO,1,/NAN)
      endif

    endif

    band = radiance ;for output
    ;----------------------------------------------------------


    ; SUBSTRACT CONTINUUM if defined (ignore if thermal brightness is used)
    IF N_ELEMENTS(index_continuum) NE 0 && ~KEYWORD_SET(Thermal_Brightness) THEN BEGIN

      icontinuum = index_continuum*(qube.qube_dim)[0]/432.
      contBANDS  = cubefiltered[icontinuum,*,*]

      If Keyword_Set(Median_Filter) Then $
        for b=0,N_ELEMENTS(icontinuum)-1 do contBANDS[b,*,*]=MEDIAN(reform(contBANDS[b,*,*]),3)

      SUMContinuum= total(contBANDS,1,/NAN)
      counterCONT = float(total(FINITE(contBANDS),1,/NAN))
      AVGContinuum = SUMContinuum/counterCONT ;Average continuum is the sum divided by counter

      ; Integrate continuum all along the given bands (unless Average was set)
      IF Average THEN TOTContinuum = AVGContinuum $
      ELSE TOTContinuum = AVGContinuum * N_ELEMENTS(index_band)

      Radiance = Radiance - TOTcontinuum
    ENDIF
    ;----------------------------------------------------------

    ; THERMAL RADIANCE ----------------------------------------
    IF N_ELEMENTS(index_thermal) NE 0 THEN BEGIN

      ithermal = index_thermal*(qube.qube_dim)[0]/432.
      thBANDS = cubefiltered[ithermal,*,*]

      ; Median Filter for each single Band
      If Keyword_Set(Median_Filter) Then $
        for b=0,N_ELEMENTS(ithermal)-1 do thBANDS[b,*,*]=MEDIAN(reform(thBANDS[b,*,*]),3)

      ; Calculate Total Thermal Radiance
      thRadiance = total(thBANDS,1,/NAN)
      If Average then begin
        counter  = float(total(FINITE(thBANDS),1,/NAN))
        thRadiance = thRadiance/counter ;Total radiance divided by counter is the mean value
      endif

    ENDIF
    ;----------------------------------------------------------

    ; SUBSTRACT THERMAL CONTINUUM if defined (ignore if thermal brightness is used)  -------
    IF N_ELEMENTS(index_cont_thermal) NE 0 && N_ELEMENTS(thermal_ratio) NE 0 && N_ELEMENTS(index_thermal) NE 0 && ~KEYWORD_SET(Thermal_Brightness) THEN BEGIN

      ithCONT = index_cont_thermal*(qube.qube_dim)[0]/432.
      thermCONT  = cubefiltered[ithCONT,*,*]

      If Keyword_Set(Median_Filter) Then $
        for b=0,N_ELEMENTS(ithCONT)-1 do thermCONT[b,*,*]=MEDIAN(reform(thermCONT[b,*,*]),3)

      SUMthCONT= total(thermCONT,1,/NAN)
      counterthCONT = float(total(FINITE(thermCONT),1,/NAN))
      AVGthCONT = SUMthCONT/counterthCONT ;Average thCONT is the sum divided by counter

      ; Integrate thCONT all along the given bands (unless Average was set)
      IF Average THEN TOTthCONT = AVGthCONT $
      ELSE TOTthCONT = AVGthCONT * N_ELEMENTS(index_thermal)

      ; SUBSTRACT THERMAL CONTINUUM
      thRadiance = thRadiance-TOTthCONT

    ENDIF
    ;----------------------------------------------------------

    ; SUBSTRACT THERMAL CONTRIBUTION if defined  --------------
    IF N_ELEMENTS(index_thermal) NE 0 THEN BEGIN
      Radiance = Radiance - thermal_ratio*thRadiance
    ENDIF
    ;----------------------------------------------------------

  ENDELSE ;if radiance is not given)
  ;--------------------------------------------------------------------------------

  ; IF POST_EMA_CORRECTION=1
  ; DO EMISSION ANGLE CORRECTION AFTER --------------------------------------------
  IF Keyword_set(POST_EMA_CORRECTION) then begin
    If Keyword_Set(EMA_correction_1_27) Then begin
      emission_angle_correction_1_27, QUBE=radiance, EM=Emergence, CORRECTED=corrected_radiance, NO_POPUPS=no_popups
      radiance = corrected_radiance
    endif
    If Keyword_Set(EMA_CORRECTION_1_74) Then begin
      emission_angle_correction_1_74, QUBE=radiance, EM=Emergence, CORRECTED=corrected_radiance, NO_POPUPS=no_popups
      radiance = corrected_radiance
    endif
    If Keyword_Set(EMA_CORRECTION_2_3 ) Then begin
      emission_angle_correction_2_3, QUBE=radiance, EM=Emergence, CORRECTED=corrected_radiance, NO_POPUPS=no_popups
      radiance = corrected_radiance
    endif
    If Keyword_Set(EMA_CORRECTION_3_8 ) Then begin
      emission_angle_correction_3_8, QUBE=radiance, EM=Emergence, CORRECTED=corrected_radiance, NO_POPUPS=no_popups
      radiance = corrected_radiance
    endif
    If Keyword_Set(EMA_CORRECTION_5_0 ) Then begin
      emission_angle_correction_5_0, QUBE=radiance, EM=Emergence, CORRECTED=corrected_radiance, NO_POPUPS=no_popups
      radiance = corrected_radiance
    endif
  endif
  ;--------------------------------------------------------------------------------

  ; Check Value within Min/Max range and Negative Pixels --------------------------
  IF only_positive THEN min_value = 0 > min_value ; if only_positive is selected, use 0 as threshold at least
  ValidDataIndex=where((Radiance[ValidGeometryIndex] GE min_value) AND (Radiance[ValidGeometryIndex] LE max_value), ValidDataCount)
  if ValidDataCount eq 0 then return, -3
  ;--------------------------------------------------------------------------------

  ; Z is always RADIANCE ----------------------------------------------------------
  Zin = (Radiance[ValidGeometryIndex])[ValidDATAIndex]
  ;--------------------------------------------------------------------------------

  ; Y is always LATITUDE ----------------------------------------------------------
  Yin = (Latitude[ValidGeometryIndex])[ValidDATAIndex]
  ;--------------------------------------------------------------------------------

  ; X can be LONGITUDE or LOCAL_TIME ----------------------------------------------
  IF longkey THEN Xin = (Longitude[ValidGeometryIndex])[ValidDataIndex] $
  ELSE           	Xin = (LocalTime[ValidGeometryIndex])[ValidDataIndex]
  ;--------------------------------------------------------------------------------

  ; RESCALE Local Time to range ([-12,12]) ----------------------------------------
  IF ~longkey THEN Xin = ( (Xin+12) mod 24 ) - 12
  ;--------------------------------------------------------------------------------


  ; Define AXIS Parameters --------------------------------------------------------

  ; If no parameters were given, fix grid size : 512x512
  IF (N_ELEMENTS(Xsize ) NE 0) + (N_ELEMENTS(Xdelta ) NE 0) + (N_ELEMENTS(Xrange ) NE 0) EQ 0 THEN Xsize  = 512.
  IF (N_ELEMENTS(Ysize ) NE 0) + (N_ELEMENTS(Ydelta ) NE 0) + (N_ELEMENTS(Yrange ) NE 0) EQ 0 THEN Ysize  = 512.

  ; If only one parameter is given, fix another one
  IF (N_ELEMENTS(Xsize ) NE 0) + (N_ELEMENTS(Xdelta ) NE 0) + (N_ELEMENTS(Xrange ) NE 0) EQ 1 THEN $
    IF N_ELEMENTS(Xrange) EQ 0 THEN Xrange = [min(Xin,/NAN),max(Xin,/NAN)] ELSE Xsize = 512. ;Xrange = [min(Xin,/NAN)-0.1*abs(min(Xin,/NAN)),max(Xin,/NAN)+0.1*abs(max(Xin,/NAN))] ELSE Xsize = 512.
  IF (N_ELEMENTS(Ysize ) NE 0) + (N_ELEMENTS(Ydelta ) NE 0) + (N_ELEMENTS(Yrange ) NE 0) EQ 1 THEN $
    IF N_ELEMENTS(Yrange) EQ 0 THEN Yrange = [min(Yin,/NAN),max(Yin,/NAN)] ELSE Ysize = 512. ;Yrange = [min(Yin,/NAN)-0.1*abs(min(Yin,/NAN)),max(Yin,/NAN)+0.1*abs(max(Yin,/NAN))] ELSE Ysize = 512.

  ; Calculate the missing parameter
  IF N_ELEMENTS(Xsize        ) EQ 0 THEN Xsize  = (Xrange[1]-XRange[0])/float(Xdelta)
  IF N_ELEMENTS(Ysize        ) EQ 0 THEN Ysize  = (Yrange[1]-YRange[0])/float(Ydelta)
  IF N_ELEMENTS(Xdelta       ) EQ 0 THEN Xdelta = (Xrange[1]-XRange[0])/float(Xsize )
  IF N_ELEMENTS(Ydelta       ) EQ 0 THEN Ydelta = (Yrange[1]-YRange[0])/float(Ysize )
  IF N_ELEMENTS(Xrange       ) EQ 0 THEN Xrange = min(Xin,/NAN)+[0, (Xsize-1)*float(Xdelta)]
  IF N_ELEMENTS(Yrange       ) EQ 0 THEN Yrange = min(Yin,/NAN)+[0, (Ysize-1)*float(Ydelta)]

  ; Create AXIS
  Xaxis = indgen(Xsize)*float(Xdelta)+Xrange[0]
  Yaxis = indgen(Ysize)*float(Ydelta)+Yrange[0]


  ; SHIFT Xaxis (if the image is centered around noon or prime meridian)

  Xshifted = ((Xin + Xrange[1]-Xrange[0]) mod (Xrange[1]-Xrange[0])) - ((Xrange[1]-Xrange[0])/2)

  if (max(Xshifted)-min(Xshifted))*1.1 lt (max(Xin)-min(Xin)) then begin
    Xin = Xshifted
    shifted = 1         ; flag to remember that Xaxis was shifted
  endif

  ;--------------------------------------------------------------------------------

  ;starttime = systime(/seconds) ; debugging


  ; Prepare for the GRIDDING ------------------------------------------------------

  ; AVERAGE pixels with same coordinates
  ; (basically aggregates pixels within EPSILON/5 distance, to make process faster)
  grid_input, Xin, Yin, Zin, Xsorted, Ysorted, Zsorted, EPSILON=0.2*min([Xdelta, Ydelta]), DUPLICATES="AVG"


  ; TRIANGULATE averaged pixels and obtain image boundaries
  triangulate, Xsorted, Ysorted, triangles, boundaries ;, FVALUE=Zsorted,SPHERE=sphere,/DEGREES

  ;--------------------------------------------------------------------------------


  ;===================================================================================
  ;=============== Perform GRIDDING using GRIDDATA OR TRIGRID   ======================
  ;===================================================================================

  IF keyword_Set(trigrid_function) THEN BEGIN

    ; TRIGRID is more efficient and accurate although it has some problems in the boundaries
    ; ###TO BE CORRECTED### There is a problem with images centered in the poles.

    Zsorted[boundaries]=-1e7 ; remove boundaries to avoid problems of triangulation in the borders
    grid = TRIGRID(Xsorted, Ysorted, Zsorted, triangles, $
      [Xdelta, Ydelta], [Xrange[0],Yrange[0], Xrange[1],Yrange[1]],$
      NX=xSize, NY=ySize, MISSING=float('NaN'),MIN_VALUE=-1e6) ;, SPHERE=sphere, /DEGREES)

  ENDIF ELSE BEGIN

    ; GRIDDATA is quite complex but it is working fine now. Ellipse and other options might be changed to obtain better results.
    ; There is a small problem when using high resolution grids, as the grid might have empty points whithin the image.
    ; For the moment we use low resolution grids so it's OK, but this should be solved in the future (hopefully using Trigrid)

    ellipse = 1.*[Xdelta,Ydelta] ; define distance to search values for each pixel of the grid
    grid = griddata(Xsorted, Ysorted, Zsorted,$
      /INVERSE_DISTANCE, SEARCH_ELLIPSE=ellipse,$
      START=[Xrange[0],Yrange[0]], DELTA=[Xdelta,Ydelta], DIMENSION=[xSize,ySize],$
      MISSING=float('NaN'), TRIANGLES=triangles, MAX_PER_SECTOR=1)

  ENDELSE

  ;print, "Grid completed in "+strtrim(systime(/seconds)-starttime, 2)+" seconds"



  ; MEDIAN FILTER also to final grid obtained -------------------------------------
  If keyword_set(median_filter) then	grid = median(grid, 3)
  ;--------------------------------------------------------------------------------


  ; RECOVER XAXIS if it was shifted before ----------------------------------------
  if keyword_set(shifted)       then  grid = shift(grid, Xsize/2)
  ;--------------------------------------------------------------------------------


  return, grid

END



;================================================================================
; EXAMPLE of v_geo_grid usage
;================================================================================

PRO EXAMPLE_geo_grid

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Define parameters
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  Color_Table   =  5 ; color table for the plot/contour

  index_band    = [74,75,76,77,78] ; index of band or bands to use
  average       =  1 ; 1 to average all selected bands (default), 0 to consider total
  only_positive =  1 ; set to consider only positive values (otherwise consider values higher than -999)
  median_filter =  1 ; set to apply a median filter 3x3 to remove noise from the image (spikes, stripes, etc)
  thermal_brightness = 0 ; set to convert radiance in thermal brightness
  Rayleigh           = 1 ; set to convert Radiance into Rayleigh (MR)
  POST_EMA_CORRECTION= 1 ; set to correct after convertions
  EMA_CORRECTION_1_27= 0 ; set to correct for Emission angle and backscatter (for Airglow)
  EMA_CORRECTION_1_74= 0 ; set to correct for Emission angle (for 1.74um)
  EMA_CORRECTION_2_3 = 0 ; set to correct for Emission angle (for 2.3 um)
  EMA_CORRECTION_3_8 = 0 ; set to correct for Emission angle (for 3.8 um)
  EMA_CORRECTION_5_0 = 0 ; set to correct for Emission angle (for 3.8 um)
  longitude     =  0 ; 0 to plot wrt Local Time, 1 wrt Longitude
  min_emergence =  0 ; min angle to consider   0 for all
  max_emergence = 90 ; max angle to consider  90 for all, 85 to avoid limbs, usually between 40-60
  min_incidence =  0 ; min angle to consider   0 for all, 95 to see only nightside
  max_incidence =180 ; max angle to consider 180 for all, 85 to see only dayside
  min_elevation =-999; min elevation to be considered, -999 for all, 100 for Limb data (+100 offset for limb data)
  max_elevation = 100; max elevation to be considered,  999 for all, 100 for NON-Limb data (+100 offset for limb data)
  min_value     =  0.; min value
  max_value     = 1e6; max value
  min_distance  =  0.; min slant distance (in km), 0 for all, 30000-50000 for only apocenter (low-res) observations
  max_distance  = 1e6; max slant distance (in km), 1e6 for all, 10000-20000 for only high-resolution observations
  nightside     =  0 ; to see only nightside (incidence angle higher than 95)
  dayside       =  0 ; to see only   dayside (incidence angle  lower than 85)
  Trigrid_function=0 ; set to use TRIGRID function (test version) instead of classical GRIDDATA
  Xsize   = 240; number of elements of the grid on the X dimension
  Ysize   = 180; number of elements of the grid on the Y dimension
  ;Xdelta  = 0.1; grid spacing on the X dimension
  ;Ydelta  =   1; 0.1 ; grid spacing on the Y dimension
  ;XRange  = [ 0 ,360]; start and stop of the Xaxis used for the grid
  ;XRange  = [-12, 12]; start and stop of the Xaxis used for the grid
  ;YRange  = [-90, 90]; start and stop of the Yaxis used for the grid

  iTool         =  0 ; 0 to plot classical contour, 1 to use iTool
  dispPLOTs     =  1 ; 1 to plot the pixels one by one using PLOTS

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Define file paths
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  qube_file="E:\ARCHIVE\DATA\MTP022\VIR0614\CALIBRATED\VI0614_09.CAL"
  geo_file ="E:\ARCHIVE\DATA\MTP022\VIR0614\GEOMETRY\VI0614_09.GEO"
  ;qube_file="C:\Documents and Settings\acardesin\My Documents\VIRTIS\PDS_Test\VIR0212\CALIBRATED\VI0212_01.CAL"
  ;geo_file ="C:\Documents and Settings\acardesin\My Documents\VIRTIS\PDS_Test\VIR0212\GEOMETRY\VI0212_01.GEO"
  ;qube_file="C:\Documents and Settings\acardesin\My Documents\VIRTIS\PDS_Test\VI0713_02.CAL"
  ;geo_file ="C:\Documents and Settings\acardesin\My Documents\VIRTIS\PDS_Test\VI0713_02.GEO"
  ;qube_file=DIALOG_PICKFILE(path="dummy", TITLE="Select Radiance qube",FILTER="*.CAL")
  ;geo_file =DIALOG_PICKFILE(path="dummy", TITLE="Select Geometry qube",FILTER="*.GEO")
  if qube_file EQ "" || geo_file EQ "" then return

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Load RGB TABLE
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  DEVICE, DECOMPOSED=0
  TVLCT, R1, G1, B1, /GET ; save original color table
  LOADCT, color_table & TVLCT, R,G,B,/GET ; get RGB of STD-GAMMA palette
  RGB_table=[[R],[G],[B]]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; GRID DATA
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  grid=v_geo_grid(qube_file, geo_file, INDEX_BAND=index_band, $
    INDEX_CONTINUUM    = index_continuum    ,$
    INDEX_THERMAL      = index_thermal      ,$
    INDEX_CONT_THERMAL = index_cont_thermal ,$
    THERMAL_RATIO      = thermal_ratio      ,$
    index_GEO = index_geo            ,$
    QUBE=qube, GEO=geo , BAND=band   ,$
    LONGITUDE     = longitude        ,$
    ONLY_POSITIVE = only_positive    ,$
    AVERAGE       = average          ,$
    MEDIAN_FILTER = median_filter    ,$
    THERMAL_BRIGHTNESS     = thermal_brightness ,$
    POST_EMA_CORRECTION= post_ema_correction,$
    EMA_CORRECTION_1_27=EMA_CORRECTION_1_27 ,$
    EMA_CORRECTION_1_74=EMA_CORRECTION_1_74 ,$
    EMA_CORRECTION_2_3 =EMA_CORRECTION_2_3  ,$
    EMA_CORRECTION_3_8 =EMA_CORRECTION_3_8  ,$
    EMA_CORRECTION_5_0 =EMA_CORRECTION_5_0  ,$
    RAYLEIGH      = Rayleigh         ,$
    NIGHTSIDE     = nightside        ,$
    DAYSIDE       = dayside          ,$
    MIN_EMERGENCE_ANGLE=min_emergence,$
    MAX_EMERGENCE_ANGLE=max_emergence,$
    MAX_INCIDENCE_ANGLE=max_incidence,$
    MIN_INCIDENCE_ANGLE=min_incidence,$
    MAX_ELEVATION = max_elevation    ,$
    MIN_ELEVATION = min_elevation    ,$
    TRIGRID_FUNCTION=trigrid_function,$
    XSIZE =xsize , YSIZE =ysize      ,$
    XDELTA=xdelta, YDELTA=ydelta     ,$
    XRANGE=xrange, YRANGE=yrange     ,$
    XAXIS=xaxis, YAXIS=Yaxis, /DEBUG)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Display with CONTOUR
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  if N_ELEMENTS(grid) EQ 1   THEN message, "ERROR: grid could not be performed. Error code: "+strtrim(grid)

  if ~FINITE(max(grid,/NaN)) THEN message, "ERROR: grid could not be performed. All values are NaN."

  IF longitude then xtitle="LONGITUDE" else Xtitle = "LOCAL TIME"

  IF not(iTool) then begin
    window, /FREE
    CONTOUR, grid, xAxis, yAxis, $
      YTITLE="LATITUDE", XTITLE=xtitle      ,$
      TITLE="Contour Grid "+FILE_BASENAME(qube_file),$
      NLEVELS=128, C_COLORS=indgen(128)*2   ,$
      YSTYLE=0, XSTYLE=0                    ,$
      POSITION=[0.08, 0.12, 0.85, 0.92]      ,$
      BACKGROUND=255, COLOR=0

    colorbar, COLOR=0, POSITION=[0.95, 0.05, 0.99, 0.95], /VERTICAL, $
      RANGE=[min(grid,/NaN),max(grid,/NaN)], FORMAT="(F6.2)"
  ENDIF $

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Display with iCONTOUR
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ELSE BEGIN
    iCONTOUR, grid, xAxis, yAxis, $
      YTITLE="LATITUDE", XTITLE=xtitle ,$
      TITLE="Contour Grid "+FILE_BASENAME(qube_file), VIEW_TITLE=FILE_BASENAME(qube_file),$
      N_LEVELS=128, RGB_TABLE=RGB_table;, XGRIDSTYLE=0, YGRIDSTYLE=0

    ; Display COLORBAR (see  http://www.ittvis.com/services/techtip.asp?ttid=3812 )
    void = itgetcurrent(TOOL=oTool)
    void = oTool->DoAction(oTool->FindIdentifiers('*INSERT/COLORBAR'))

  ENDELSE

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Display using PLOTS
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF dispPLOTs then begin
    scaled=BYTSCL(grid,/NaN)

    window, /FREE

    ;fake plot to define axis
    PLOT, [-1000,-1000], YRANGE=YRange,XRANGE=XRange, /XSTYLE, /YSTYLE, LINESTYLE = 1, $
      POSITION=[0.08, 0.12, 0.85, 0.92]      ,$
      TITLE ="Grid Points "+FILE_BASENAME(qube_file), XTITLE = xtitle, YTITLE = 'Latitude', BACKGROUND=255, COLOR=0

    ; Now display the resulting data values with respect to the color table.
    FOR i = 0, Xsize-1 DO $
      FOR j = 0, Ysize-1 DO $
      IF scaled[i,j] gt 0 then $
      PLOTS, Xaxis(i),YAxis(j), PSYM = 3, COLOR = scaled[i,j], SYMSIZE = 0.5

    colorbar, COLOR=0, POSITION=[0.95, 0.05, 0.99, 0.95], /VERTICAL, $
      RANGE=[min(grid,/NaN),max(grid,/NaN)], FORMAT="(F6.2)"


    TVLCT, R1, G1, B1 ;restore original color table
  ENDIF

  v_map_projection, z=grid, local_time=xAxis, latitude=yAxis, IMAGE_TOOL=0, /QUERY

END
