;+
; NAME:
;   V_MAP_PROJECTION
;
; PURPOSE:
;   Display a map projection of a selected band with respect to Latitude and Longitude (or Local Time)
;   Procedure can be called either from ENVI or from IDL code.
;   The routine can display a popup dialog to select manually some options for mapping and display (QUERY keyword)
;
; INPUT:
;   If no inputs are given procedure shows an ENVI dialog to select the bands for display.
;
; OPTIONAL KEYWORDS:
;
;   Z          : 2D array with Z values to plot (typically a Radiance band)
;
;   LATITUDE   : 1D array with Latitude  values (between -90 and +90) for each COLUMN of the image, or
;                2D array with Latitude  values (between -90 and +90) for each PIXEL  of the image
;
;   LONGITUDE  : 1D array with Longitude values (between   0 and 360, or -180 and +180) for each ROW   of the image, or
;                2D array with Longitude values (between   0 and 360, or -180 and +180) for each PIXEL of the image
;
;   LOCAL_TIME : 1D array with Local Time values (between   0 and 24, or  -12 and  +12) for each ROW   of the image, or
;                2D array with Local Time values (between   0 and 24, or  -12 and  +12) for each PIXEL of the image
;
;                *Note: LOCAL_TIME and LONGITUDE cannot be given simultaneously
;
;   SOUTH_POLE : set to center the projection around the south pole (-90 latitude) showing all southern hemisphere
;   SOUTH_ZOOM : set to ZOOM the projection in the south pole (-90 latitude). SOUTH_POLE and CENTER_xx keywords are ignored in this case.
;   CENTER_LATITUDE  : use this to center the map in a certain latitude
;   CENTER_LONGITUDE : use this to center the map in a certain longitude  (ignored if longitude  is not given)
;   CENTER_LOCAL_TIME: use this to center the map in a certain local_time (ignored if local time is not given)
;                      *Note: if centers are not given, routine calculates the centers automatically from the image
;   PROJECTION_NAME: Set this keyword to a string indicating the projection that you wish to use. (Default is Orthographic)
;                    *Note: A list of available projections can be found using MAP_PROJ_INFO, PROJ_NAMES=names
;   RANGE      : range of Z values to be considered (image is scaled using this given range)
;   PERCENT    : percent value used for the histogram clipping and stretching (default is 1%)
;   IMAGE_TOOL : (set by default) display Map projection using iImage tool (for advanced stretching options, etc)
;   MAP_TOOL   : (TO BE TESTED) display Map projection using iMap tool,  (for advanced interactive map options, etc)
;   TITLE      : set title for the image
;   CROP_IMAGE : select to crop the image
;                  0 (default) keeps original size
;                  1 uses square dimensions and 6 first columns, typical for VIRTIS
;                  2 cuts first line
;                  3 cuts first 2 lines and last one
;   COLOR_TABLE: color table index as used for LOADCT
;   RGB_TABLE  : 3x256 array containing RGB color table
;   INVERTED_BACKGROUND : set this keyword to display the background as White and the foreground color (grid/text) as Black
;   CHARSIZE   : size of the font used (default is 1.2)
;   COLORBAR_TITLE: title of color bar (e.g. "Radiance [W/m2/microns/sr]")
;   DIVISIONS  : number of divisions displayed in the color bar (default is 10)
;   RESOLUTION : 2-element array containing the resolution [X,Y] of the output image ([900,750] by default)
;   QUERY      : set this keyword to display a popup dialog with some map and display options
;   _EXTRA: this routine uses keyword inheritance so you can pass any extra keyword to the MAP_SET procedure
;
; EXAMPLE:
;   If no inputs are given the procedure shows ENVI dialog to select bands
;       > v_map_projection
;
;   The routine can also show a dialog query to select manually some display/mapping options
;       > v_map_projection, /QUERY
;
;   Bands can be passed directly through command line
;       > v_map_projection, Z=band77, LATITUDE=latitude, LOCAL_TIME=local_time, RANGE=[0.01, 0.14], TITLE="Sample Projection"
;
;   Bands and dialog query can also be specified
;       > v_map_projection, Z=band77, LATITUDE=latitude, LONGITUDE=longitude, /QUERY
;
;   Other options for nicer display:
;       > v_map_projection, CENTER_LATITUDE=0, CENTER_LOCAL_TIME=0, CHARSIZE=2, RANGE=[0,1.2],$
;       >                   COLORBAR_TITLE= "Emission Rate [MR]", TITLE="Venus Nightside, Latitude vs Local Time"
;
;   Can use single image instead of iTool to save output into an image file
;       > v_map_projection, Z=band77, LATITUDE=latitude, LONGITUDE=longitude, IMAGE_TOOL=0
;       > filename=dialog_pickfile(/WRITE,/OVER,FILE="filename.png", FILTER="*.png")
;       > write_png,filename,TVRD(/TRUE)
;
;   Any extra keyword can also be passed forward to MAP_SET (see help):
;       > v_map_projection, PROJECTION_NAME="Satellite", /SAT_P=[10,3,30]
;
; PROCEDURE:
;   The routine uses the "v_crop_cube.pro" routine (from VIRTIS VEX library) in order to remove repeated parts of an image
;   The routine uses the "v_imclip.pro" routine (same as imclip.pro from Liam Gumley http://www.gumley.com/)
;   The routine uses the "colorbar.pro" routine from David Fanning (http://www.dfanning.com/programs/colorbar.pro)
;   This file includes a function to calculate the approximate mode of a distribution (v_map_mode)
;   This file includes a procedure to pop up a query window to select options (v_map_projection_options_query)
;
; RESTRICTIONS:
;   Problems using MAP_TOOL, sometimes it does not work at all (?)
;   Sometimes an IMAP iTool splash screen is shown for image registration.
;   The user must click "Next" and then "Finish" to see the final projection.
;
; MODIFICATION HISTORY:
;   Written by Alejandro Cardesin, IASF-INAF, March 2007, alejandro.cardesin @ iasf-roma.inaf.it
;   Modified June 2008 by A.Cardesin: Added v_imclip and PERCENT keyword for better stretching
;                                     Added SOUTH_POLE, CENTER_LONGITUDE/LATITUDE/LOCAL_TIME keywords
;                                     Calculate mode value for longitude/local time center
;                                     Added RESOLUTION, SOUTH_ZOOM, _EXTRA, QUERY and other minor things
;                                     Changed the way LONGITUDE and LOCAL_TIME are passed (corrected bug)
;                                     Added Charsize, improved char format of colortable
;   Modified Nov.. 2009 by A.Cardesin: Modified to allow reloading the image after query
;                                     Modified query buttons and settings (improved)
;                                     Added keywords COLOR_TABLE and CROP_IMAGE
;                                     Solved minor bug with CENTER_LOCAL_TIME, back to QUERY on error
;                                     Improved error handling. Solved minor bug in CW_FORM. CROP_IMAGE=0 by default
;                                     Added DIVISIONS, PROJECTION_NAME and SAT_POSITION (in query)
;                                     Added INVERTED_BACKGROUND keyword  and improved legend format.
;                                     Other minor bugs and comments
;-

; Simple function to calculate mode of distribution (approximate value) ---------------------
; (return -9999 if mode cannot be found)
FUNCTION v_map_mode, array
  nbins = (max(array)-min(array)) < 1000 ; at least 1000 bins
  hist    = Histogram(array,/NaN, LOCATIONS=locations, REVERSE_IND=r_ind, NBINS=nbins)
  maxfreq = Max(hist, imode)
  if imode[0] ne -1 then $
    ;mode = locations[imode[0]]           $; approximated value (dependent on binsize)
    mode = array[R_ind[R_ind[imode[0]]]]  $; value taken from the original array
  else mode = -9999
  return, mode
END
; -------------------------------------------------------------------------------------------

; Simple function to pop up a query window to select options --------------------------------
function v_map_projection_options_query, CENTER_LONGITUDE   = center_longitude  ,$
  CENTER_LATITUDE    = center_latitude   ,$
  CENTER_LOCAL_TIME  = center_local_time ,$
  PROJECTION_NAME    = projection_name   ,$
  RESOLUTION         = resolution        ,$
  CHARSIZE           = charsize          ,$
  FONTNAME           = fontname          ,$
  LINETHICK          = linethick         ,$
  LINESTYLE          = linestyle         ,$
  LABLON             = lablon            ,$
  LABLAT             = lablat            ,$
  DELLON             = dellon            ,$
  DELLAT             = dellat            ,$
  LABALIGN           = labalign          ,$
  CROP_IMAGE         = crop_image        ,$
  PERCENT            = percent           ,$
  SAT_POSITION       = sat_position      ,$
  COLOR_TABLE        = color_table       ,$
  COLORBAR_TITLE     = colorbar_title    ,$
  INVERTED_BACKGROUND=inverted_background,$
  DIVISIONS          = divisions         ,$
  TITLE              = title             ,$
  RANGE              = range             ,$
  SOUTH_ZOOM         = south_zoom        ,$
  SAVEPNG            = savePNG           ,$
  IMAGE_TOOL         = image_tool        ,$
  MAP_TOOL           = map_tool


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; error handling lines, if an error is detected, notify and return 0
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  catch, error_stat
  if error_stat ne 0 then begin
    catch, /cancel
    Help, /Last_Message, OUTPUT=errormessage
    print, transpose(errormessage)
    ok = DIALOG_MESSAGE("ERROR: cannot project image."+string(errormessage[0]))
    return, 0
  endif

  ; Define radius of the planet in KM (default for Venus)
  Planet_radius=6051d

  if N_elements(percent) gt 0 && percent ne "" then range=["",""]

  if N_elements(center_latitude) gt 0 then center_latitude = string(center_latitude   ,F='(I3)') else center_latitude='0'

  if N_elements(center_local_time) gt 0 then $
    Center_LonLct_String='0, FLOAT, '+string(center_local_time ,F='(F4.1)')+', LABEL_LEFT=Center Local Time:   , WIDTH=5, TAG=LonLct0' $
  else if N_elements(center_longitude) gt 0 then $
    Center_LonLct_String='0, FLOAT, '+string(center_longitude  ,F='(I4)')  +', LABEL_LEFT=Center Longitude  :  , WIDTH=5, TAG=LonLct0'

  if N_elements(crop_image ) eq 0 then crop_image  =0
  if N_elements(percent    ) eq 0 then percent     =1
  if N_elements(range      ) eq 0 then range       =['','']
  if N_elements(color_table) eq 0 then color_table =39 ;Rainbow+White
  if N_elements(divisions  ) eq 0 then divisions   =5       ;10
  if N_elements(charsize   ) eq 0 then charsize    =3     ;1.2
  if N_elements(fontname   ) eq 0 then fontname    ="Arial" ;""
  if N_elements(linethick  ) eq 0 then linethick   =2.0
  if N_elements(linestyle  ) eq 0 then linestyle   =2       ;1
  if N_elements(lablon     ) eq 0 then lablon      =0       ;center_latitude
  if N_elements(dellon     ) eq 0 then dellon      =45
  if N_elements(dellat     ) eq 0 then dellat      =20      ;0
  if N_elements(labalign   ) eq 0 then labalign    =-0.1    ;0.0
  if N_elements(title      ) eq 0 then title       =""
  if N_elements(colorbar_title) eq 0 then colorbar_title=""
  if N_elements(Center_LonLct_String) eq 0 then Center_LonLct_String='0'

  if N_elements(lablat     ) eq 0 then	lablat=(abs(float(Center_LonLct_String)) gt 90)? 180:0


  ; Get list of Color Tables
  loadct, GET_NAMES=Color_Table_List
  Color_Table_List = STRJOIN (Color_Table_List, "|")

  ; Get list of Available Map Projection names
  MAP_PROJ_INFO, PROJ_NAMES=Projection_Name_List
  Projection_Name_List=Projection_Name_List[1:(N_elements(Projection_Name_List)-2)]

  if n_elements(projection_name) eq 0 then projection_name="ORTHOGRAPHIC"

  current_projection = where(strupcase(Projection_name_List) eq strupcase(projection_name))


  ; Set current Satellite position if not given
  If n_elements(sat_position) lt 3 then sat_position=[1.1,0,0]

  ; Set format of Form Query
  description = [ $
    '0, LABEL, Set Map Projection Options, CENTER', $
    '1, BASE,, COLUMN, CENTER', $
    '1, BASE,, ROW, CENTER', $
    '1, BASE,, COLUMN', $
    '1, BASE,, COLUMN, FRAME', $
    '0, BASE,, COLUMN, CENTER', $
    '0, LABEL,Select Map Projection: , CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, DROPLIST,'+STRJOIN(Projection_Name_list, "|")+',SET_VALUE='+strtrim(current_projection,2)+',LABEL_LEFT=,TAG=projection',$
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '2, BASE,, COLUMN, CENTER', $
    ; REMOVED ;'2, BUTTON, Show whole planet|Zoom South Pole (test),EXCLUSIVE,,SET_VALUE='+string(keyword_set(south_zoom))+',TAG=Bmap',$
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '1, BASE,, COLUMN,FRAME', $
    '0, LABEL,Geographic Coordinates: , CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, FLOAT, '+center_latitude  +', LABEL_LEFT=Center Latitude     :, WIDTH=5, TAG=lat0', $
    '0, BASE,, COLUMN, CENTER', $
    Center_LonLct_String, $
    '2,BASE,,,', $
    '2,BASE,,,', $
    '0, BASE,, COLUMN, CENTER', $
    '1, BASE,,COLUMN, ', $
    '1, BASE,, COLUMN, FRAME', $
    '0, LABEL,Image Options: , CENTER', $
    '0, FLOAT, '+string(crop_image,F='(I2)')+', LABEL_LEFT=Crop Image (0-4), WIDTH=4, TAG=crop_image',$
    '0, LABEL, (0 none; 1 square;), CENTER', $
    '0, LABEL, (2 first line; 3 both first+last), CENTER', $
    '2, LABEL, (4 nightside no poles), CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '0, BASE,, COLUMN, CENTER', $
    '1, BASE,, COLUMN, FRAME, CENTER', $
    '0, LABEL,Stretching Options: , CENTER', $
    '0, FLOAT, '+string(percent,F='(I2)')+', LABEL_LEFT=Percent Stretching:, WIDTH=4, TAG=percent', $
    '1, BASE,, ROW', $
    '0, LABEL,Fix Range : , CENTER', $
    '0, TEXT,'+string(range[0])+', LABEL_LEFT=, WIDTH=3, TAG=minrange', $
    '2, TEXT,'+string(range[1])+', LABEL_LEFT=, WIDTH=3, TAG=maxrange', $
    '2,BASE,,', $
    '2,BASE,,', $
    '2,BASE,,', $
    '2,BASE,,', $
    '1, BASE,, COLUMN, FRAME, CENTER', $
    '0, LABEL,Satellite Position (for Satellite Projection): , CENTER', $
    '1, BASE,, ROW,CENTER', $
    '0, FLOAT, '+string((sat_position[0]-1.)*Planet_radius,F='(F8.1)')+', LABEL_LEFT=Altitude (km) :, WIDTH=7, TAG=sat_position1', $
    '0, BASE,, COLUMN, CENTER', $
    '0, FLOAT, '+string(sat_position[1],F='(F5.1)')+', LABEL_LEFT=Pitch (deg) :, WIDTH=4, TAG=sat_position2', $
    '0, BASE,, COLUMN, CENTER', $
    '2, FLOAT, '+string(sat_position[2],F='(F5.1)')+', LABEL_LEFT=Rotation (deg) :, WIDTH=4, TAG=sat_position3', $
    '2, BASE,, COLUMN', $
    '0, BASE,, COLUMN', $
    '0, BASE,, COLUMN', $
    '0, BASE,, COLUMN', $
    '0, BASE,, COLUMN', $
    '0, BASE,, COLUMN', $
    '1, BASE,, COLUMN, FRAME, CENTER', $
    '0, LABEL,Display Options: , CENTER', $
    '1, BASE,, ROW,CENTER', $
    '2, DROPLIST,'+Color_Table_List+',SET_VALUE='+strtrim(color_table,2)+',,LABEL_LEFT=Select Color Table    :,TAG=colortable',$
    '1, BASE,, ROW,CENTER', $
    '2, DROPLIST,Black Background - White Color|White Background - Black Color,SET_VALUE='+strtrim(inverted_background,2)+',,LABEL_LEFT=Invert White/Black   :,TAG=inverted_background',$
    '1, BASE,, ROW,CENTER', $
    '2, FLOAT, '+string(divisions,F='(I3)')+', LABEL_LEFT=Color Bar Divisions   :, WIDTH=2, TAG=divisions', $
    '0, BASE,, COLUMN, CENTER', $
    '1, BASE,, ROW, CENTER', $
    '0, FLOAT, '+string(charsize ,F='(F3.1)')+', LABEL_LEFT=Font Size :, WIDTH=3, TAG=charsize', $
    '2, FLOAT, '+string(labalign, F='(F4.1)')+', LABEL_LEFT=Align Labels (0.0-1.0) :, WIDTH=4, TAG=labalign', $
    '0, BASE,, COLUMN, CENTER', $
    '0, TEXT, '+fontname      +', LABEL_LEFT=Font  :, WIDTH=41, TAG=fontname',$
    '1, BASE,, ROW,CENTER', $
    '0, FLOAT, '+string(linethick,F='(I2)'  )+', LABEL_LEFT=Line Thickness : , WIDTH=2, TAG=linethick',$
    '2, FLOAT, '+string(linestyle,F='(I2)'  )+', LABEL_LEFT=Line Style (0-5):, WIDTH=3, TAG=linestyle',$
    '1, BASE,, COLUMN,CENTER', $
    '0, FLOAT, '+string(lablon,   F='(I3)'  )+', LABEL_LEFT=Long/LT Labels (-90 90):, WIDTH=5, TAG=lablon', $
    '0, FLOAT, '+string(lablat,   F='(I3)'  )+', LABEL_LEFT=Latitude Labels (0-360):, WIDTH=5, TAG=lablat', $
    '2, BASE,, COLUMN', $
    '1, BASE,, COLUMN,CENTER', $
    '0, FLOAT, '+string(dellon,   F='(I3)'  )+', LABEL_LEFT=Long/LT Delta :, WIDTH=5, TAG=dellon', $
    '0, FLOAT, '+string(dellat,   F='(I3)'  )+', LABEL_LEFT=Latitude Delta:, WIDTH=5, TAG=dellat', $
    '2, BASE,, COLUMN', $
    '1, BASE,, COLUMN,CENTER', $
    '0, FLOAT, '+string(resolution[0], F='(I5)'  )+', LABEL_LEFT=Window Size X:, WIDTH=6, TAG=resolutionX', $
    '0, FLOAT, '+string(resolution[1], F='(I5)'  )+', LABEL_LEFT=Window Size Y:, WIDTH=6, TAG=resolutionY', $
    '2, BASE,, COLUMN', $
    '0, BASE,, COLUMN', $
    '1, BASE,, COLUMN,CENTER', $
    '0, TEXT, '+title         +', LABEL_LEFT=Title :, WIDTH=41, TAG=title', $
    '2, TEXT, '+colorbar_title+', LABEL_LEFT=Units : , WIDTH=41, TAG=units', $
    '2, BASE,, COLUMN, CENTER', $
    '1, BASE,, ROW, CENTER', $
    '0, BUTTON, Reload Image, QUIT, TAG=Breload',$
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BUTTON,Save PNG, QUIT,TAG=BsavePNG',$
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BUTTON,iTool, QUIT,TAG=BiTool',$
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '0, BASE,, COLUMN,, CENTER', $
    '2, BUTTON, QUIT, QUIT,TAG=Bquit']

  ; Launch Query
  query = CW_FORM(description, /COLUMN, TITLE="Map Projection Options", /TAB_MODE)

  ; Consider range only if values are given
  if query.minrange ne "" && query.maxrange ne "" then range = float([query.minrange, query.maxrange]) else dummy=temporary(range) ;delete variable

  ; Consider sat_position only if values are given
  if strupcase(projection_name_list[query.projection]) eq "SATELLITE" then $
    if string(query.sat_position1) ne "" &&   $
    string(query.sat_position2) ne "" &&   $
    string(query.sat_position3) ne "" then $
    sat_position = float([(query.sat_position1/planet_radius +1.),$
    query.sat_position2                   ,$
    query.sat_position3])                  $
  else dummy=temporary(sat_position) ;delete variabl

  ; Read center coordinates
  CENTER_LATITUDE  = query.lat0
  if N_elements(center_local_time) gt 0 then $
    CENTER_LOCAL_TIME= query.LonLct0       $
  else                                       $
    CENTER_LONGITUDE = query.LonLct0


  ; Other options
  CHARSIZE            = query.charsize
  FONTNAME            = query.fontname
  LINETHICK           = query.linethick
  LINESTYLE           = query.linestyle
  LABLON              = query.lablon
  LABLAT              = query.lablat
  DELLON              = query.dellon
  DELLAT              = query.dellat
  LABALIGN            = query.labalign
  CROP_IMAGE          = query.crop_image
  PERCENT             = query.percent
  COLOR_TABLE         = query.colortable
  PROJECTION_NAME     = projection_name_list[query.projection]
  COLORBAR_TITLE      = query.units
  INVERTED_BACKGROUND = query.inverted_background
  DIVISIONS           = query.divisions
  TITLE               = query.title
  RANGE               = range
  ;SOUTH_ZOOM         = query.Bmap
  IMAGE_TOOL          = (query.BiTool    eq 1)
  SAVEPNG             = (query.BsavePNG  eq 1)
  RESOLUTION          = [query.resolutionX , query.resolutionY]
  reload              = (query.Bquit eq 0) && ((query.BiTool eq 1) || (query.Breload eq 1) || (query.BsavePNG eq 1))

  return, reload
end
; -------------------------------------------------------------------------------------------


; ===========================================================================================
; ===========================================================================================
; Main V_MAP_PROJECTION procedure
; ===========================================================================================
; ===========================================================================================

PRO v_map_projection, event, output_file,$ ; used only for ENVI
  Z=z_in, LONGITUDE=longitude_in, LATITUDE=Latitude_in, LOCAL_TIME=Local_Time_in, $
  IMAGE_TOOL=IMAGE_TOOL, MAP_TOOL=MAP_TOOL, SOUTH_POLE=south_pole, INVERTED_BACKGROUND=inverted_background,$
  CENTER_LATITUDE=center_latitude, CENTER_LONGITUDE=center_longitude, CENTER_LOCAL_TIME=center_local_time,$
  FONTNAME=fontname,LINESTYLE = linestyle, LABLON = lablon, LABLAT = lablat, DELLON = dellon, DELLAT = dellat, LABALIGN = labalign ,$
  RANGE=range, PERCENT=percent, Colorbar_Title=Colorbar_Title, TITLE=title, RGB_TABLE=RGB_Table_in, COLOR_TABLE=Color_Table, CHARSIZE=charsize,LINETHICK=linethick,$
  RESOLUTION=resolution, SOUTH_ZOOM=SOUTH_ZOOM,_EXTRA=extraKeywords, QUERY=query, CROP_IMAGE=crop_image, DIVISIONS=divisions, SAVEPNG=savePNG, $
  PROJECTION_NAME=projection_name

;  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  ;; Default settings for Thermal Brightness
;  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  QUERY=1
;  RANGE= [220,240]
;  CENTER_LATITUDE  =0
;  CENTER_LONGITUDE =0
;  CENTER_LOCAL_TIME=0
;  Colorbar_Title="Thermal Brightness [kelvin]"
;  COLOR_TABLE=4
;  DIVISIONS=4
;  CROP_IMAGE=3
;  DELLON=45

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; SAVE GRAPHICS DISPLAY
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  mydevice = !D.NAME ; ; Save current device
  DEVICE, GET_DECOMPOSED=decomposed ; save original decomposed state
  TVLCT, R1, G1, B1, /GET           ; save original color table

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; error handling lines, if an error is detected, notify and return
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  catch, error_stat
  if error_stat ne 0 then begin
    catch, /cancel
    SET_PLOT, mydevice ; reset device
    DEVICE, DECOMPOSED=decomposed ; restore original decomposed state
    TVLCT, R1, G1, B1             ; restore original color table
    Help, /Last_Message, OUTPUT=errormessage
    print, transpose(errormessage)
    ok = DIALOG_MESSAGE("ERROR: cannot project image."+string(errormessage[0]))

    return

  endif

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; SELECT BANDS FROM ENVI (if no inputs are given)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF N_ELEMENTS(Z_in) EQ 0 THEN BEGIN

    ; Let IDL know that I'm using ENVI functions (otherwise it doesn't compile)
    FORWARD_FUNCTION ENVI_GET_DATA

    ;Run ENVI if it is not running yet
    help,name='envi_open_file',/procedures, output=help_envi_compiled
    IF N_ELEMENTS(help_envi_compiled) LE 1 THEN ENVI

    envi_select, dims=dimsZ, fid=fidZ, pos=posZ,/BAND_ONLY,TITLE="Select radiance band to plot" ;,/MASK,/ROI
    if (fidZ eq -1) then return

    envi_select, dims=dimsX, fid=fidX, pos=posX,/BAND_ONLY,TITLE="Select Latitude band";,/MASK,/ROI
    if (fidX eq -1) then return

    envi_select, dims=dimsY, fid=fidY, pos=posY,/BAND_ONLY,TITLE="Select Longitude or Local Time band";,/MASK,/ROI
    if (fidY eq -1) then return

    envi_file_query, fidZ, fname=fnameZ, bnames=bnameZ, WL=wavelengthZ, data_type=data_type
    envi_file_query, fidX, fname=fnameX, bnames=bnameX
    envi_file_query, fidY, fname=fnameY, bnames=bnameY

    bnameZ = bnameZ[posZ]
    bnameX = bnameX[posX]
    bnameY = bnameY[posY]

    Z_in        = float(envi_get_data(FID=fidZ, pos=posZ, dims=dimsZ))
    Latitude_in = float(envi_get_data(FID=fidX, pos=posX, dims=dimsX))
    temp        = float(envi_get_data(FID=fidY, pos=posY, dims=dimsY)) 	; Read either Local Time or Longitude

    IF STRPOS(STRUPCASE(bnameY), "LOCAL TIME") GE 0 THEN Local_Time_in = temporary(temp) ELSE Longitude_in = temporary(temp)

    IF N_ELEMENTS(Colorbar_Title) EQ 0 THEN BEGIN
      IF STRPOS(STRUPCASE(bnameZ), "MEAN VALUE") GE 0 THEN Colorbar_Title = "Radiance [W/m2/µm/sr]"
      IF STRPOS(STRUPCASE(bnameZ), "STDEV"     ) GE 0 THEN Colorbar_Title = "Standard Deviation"
      IF STRPOS(STRUPCASE(bnameZ), "COUNTER"   ) GE 0 THEN Colorbar_Title = "Counts"
    ENDIF

    IF N_ELEMENTS(Title) EQ 0 THEN title = file_basename(fnameZ,".DAT")

  ENDIF

  RESTART:

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; error handling lines, if an error is detected, notify and return
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  catch, error_stat
  if error_stat ne 0 then begin
    SET_PLOT, mydevice ; reset device
    DEVICE, DECOMPOSED=decomposed ; restore original decomposed state
    TVLCT, R1, G1, B1             ; restore original color table
    Help, /Last_Message, OUTPUT=errormessage
    print, transpose(errormessage)
    ok = DIALOG_MESSAGE("ERROR: cannot project image."+string(errormessage[0]))

    if keyword_set(query) then GOTO, QUERY else return

  endif

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; CHECK INPUT KEYWORDS
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF N_ELEMENTS(Local_Time_in        ) GT 0 && $
    N_ELEMENTS(Longitude_in         ) GT 0 THEN message, "ERROR: either Local_Time or Longitude must be given, not both."
  IF N_ELEMENTS(IMAGE_TOOL           ) EQ 0 THEN IMAGE_TOOL      = 0
  IF N_ELEMENTS(resolution           ) NE 2 THEN resolution      = [1000, 800]
  IF N_ELEMENTS(Colorbar_Title       ) EQ 0 THEN Colorbar_Title  = 'Radiance [W/m2/µm/sr]'
  IF N_ELEMENTS(Inverted_Background  ) EQ 0 THEN inverted_background = 1
  IF N_ELEMENTS(divisions            ) EQ 0 THEN divisions       = 5
  IF N_ELEMENTS(Projection_name      ) EQ 0 THEN projection_name = "Orthographic"
  IF N_ELEMENTS(Title                ) EQ 0 THEN Title           = 'VIRTIS Venus Express Radiance Map'
  IF N_ELEMENTS(Charsize             ) EQ 0 THEN Charsize        = 3.0
  IF N_ELEMENTS(linethick            ) EQ 0 THEN linethick       = 2
  IF N_ELEMENTS(fontname             ) EQ 0 THEN fontname        = "Arial"
  if N_ELEMENTS(linestyle            ) EQ 0 THEN linestyle       = 2       ;1
  if N_ELEMENTS(lablon               ) EQ 0 THEN lablon          = 0       ;center_latitude
  if N_ELEMENTS(dellon               ) EQ 0 THEN dellon          = 20
  if N_ELEMENTS(dellat               ) EQ 0 THEN dellat          = 20      ;0
  if N_ELEMENTS(labalign             ) EQ 0 THEN labalign        = -0.2    ;0.0
  IF N_ELEMENTS(color_table          ) EQ 0 THEN COLOR_TABLE     = 39      ; default color_table: "Rainbow+white"

  IF KEYWORD_SET(SOUTH_ZOOM          )      THEN BEGIN
    IF N_elements(center_latitude  ) GT 0 THEN dummmy = temporary(center_latitude  ) ;ignore variable
    IF N_elements(center_longitude ) GT 0 THEN dummmy = temporary(center_longitude ) ;ignore variable
    IF N_elements(center_local_time) GT 0 THEN dummmy = temporary(center_local_time) ;ignore variable
  ENDIF ELSE $
    IF N_elements(limit            ) GT 0 THEN dummmy = temporary(limit            ) ;ignore previously defined limit

  IF N_ELEMENTS(RGB_TABLE_in         ) EQ 0 THEN BEGIN
    DEVICE, DECOMPOSED=0
    LOADCT, color_table & TVLCT, R,G,B,/GET ; get RGB of color_table palette
    RGB_table=[[R],[G],[B]]
    DEVICE, DECOMPOSED=decomposed ; restore original decomposed state
    TVLCT, R1, G1, B1             ; restore original color table
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Original variables are always reused
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  Z          = Z_in
  Latitude   = Latitude_in
  IF N_ELEMENTS(Local_Time_in ) GT 0 THEN Local_Time = Local_Time_in $
  ELSE Longitude  = Longitude_in

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Crop image (optional)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; 0 - NO CROP
  IF N_ELEMENTS(CROP_IMAGE) EQ 0 THEN CROP_IMAGE=0 ;(default)

  ; 1 - SQUARE
  IF CROP_IMAGE EQ 1 THEN BEGIN
    v_crop_cube, Z
    v_crop_cube, Latitude
    IF N_ELEMENTS(Local_Time) GT 0 THEN v_crop_cube, Local_Time ELSE v_crop_cube, Longitude
  ENDIF

  ; 2 - REMOVE FIRST LINE
  IF CROP_IMAGE EQ 2 THEN BEGIN
	lines   = long((size(Z,/DIM))[1])
    Z        = Z       [*,1:lines-1]
	Latitude = Latitude[*,1:lines-1]
    IF N_ELEMENTS(Local_Time) GT 0 THEN Local_Time = Local_Time[*,1:lines-1]  ELSE Longitude = Longitude[*,1:lines-1]
  ENDIF

  ; 3 - REMOVE FIRST 2 LINES AND LAST ONE
  IF CROP_IMAGE EQ 3 THEN BEGIN
	lines   = long((size(Z,/DIM))[1])
    Z        = Z       [*,2:lines-2]
	Latitude = Latitude[*,2:lines-2]
    IF N_ELEMENTS(Local_Time) GT 0 THEN Local_Time = Local_Time[*,2:lines-2]  ELSE Longitude = Longitude[*,2:lines-2]
  ENDIF

  ; 4 - REMOVE FIRST 2 LINES, LAST ONE AND USE ONLY NIGHTSIDE
  IF CROP_IMAGE LT 0 THEN BEGIN
	lines   = long((size(Z,/DIM))[1])
    Z        = Z       [*,2:lines-2]
	Latitude = Latitude[*,2:lines-2]
    IF N_ELEMENTS(Local_Time) GT 0 THEN Local_Time = Local_Time[*,2:lines-2]  ELSE Longitude = Longitude[*,2:lines-2]

	marginLT = -1*CROP_IMAGE ;use this value as the margin for terminator

	samples  = long((size(Z,/DIM))[0])
    Z        = Z       [ (samples/24*(6+marginLT)):(samples/24*(18-marginLT)) , *]
	Latitude = Latitude[ (samples/24*(6+marginLT)):(samples/24*(18-marginLT)) , *]
    IF N_ELEMENTS(Local_Time) GT 0 THEN Local_Time = Local_Time[ (samples/24*(6+marginLT)):(samples/24*(18-marginLT)) , *]  ELSE Longitude = Longitude[ (samples/24*(6+marginLT)):(samples/24*(18-maxLT)) , *]
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Find Valid Values
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  indValid =where(FINITE(Z) AND (Z NE 0.0), countVALID)
  IF countVALID eq 0 then BEGIN
    ok=dialog_message("ERROR: Input image has all pixels to NaN value or Zero", /ERROR)
    return
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Define RANGE using given percent (default is 1%)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF N_ELEMENTS(Range) EQ 0 THEN BEGIN
    IF N_ELEMENTS(percent) EQ 0 THEN $
      IF N_ELEMENTS(Colorbar_Title) EQ 1 && Colorbar_Title EQ "Counts" THEN percent=0 $
    ELSE percent = 1

    ; Use "v_imclip.pro" routine to get range values using Percent
    Range = v_imclip( Z[indValid], PERCENT=percent )
    ; Source code of imclip can be found here:
    ; http://groups.google.com/group/comp.lang.idl-pvwave/browse_thread/thread/fe813e33cb681621/253fb215cd24a008?lnk=gst&q=imclip#253fb215cd24a008
  ENDIF ELSE percent=""

  IF Range[1] EQ Range[0] THEN BEGIN
    ok=dialog_message("ERROR: Image range cannot be displayed."+string(10B)+"MaxValue = MinValue. Check input image.", /ERROR)
    return
  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Convert Local Time into a "fake" Longitude to pass it to MAP_PATCH (it works only with lat/lon values)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF N_ELEMENTS(Local_Time) GT 0 THEN BEGIN
    Longitude = (360. - Local_Time * 360. / 24.) mod 360.
    xtitle = "LOCAL TIME"
    ; Set local time values and labels for map grid
    LONNAMES=[0,-2,-4,-6,-8,-10,12,10,8,6,4,2,0];[0,22,20,18,16,14,12,10,8,6,4,2,0];(24-indgen(13)*2) mod 24
    LONS=indgen(13)*30

    ; Ignore any given center_longitude if local time is used
    If N_elements(center_longitude ) gt 0 then dummmy= temporary(center_longitude)
    ; Convert also center_local_time into a "fake" center_longitude
    If N_elements(center_local_time) gt 0 then center_longitude = (360. - center_local_time * 360. / 24.) mod 360.

  ENDIF ELSE $
    xtitle = "LONGITUDE"

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Input Longitude and Latitude
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  Lat = Latitude
  Lon = longitude ; note that this can be a "fake" local time (see above)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Sort and Average pixels with same coordinates (DOESNT WORK)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;grid_input, Lon, Lat, Z, Lon_sorted, Lat_sorted, Z_sorted, DUPLICATES="AVG"

  ;Lat = Lat_sorted
  ;Lon = Lon_sorted
  ;Z   = Z_sorted
  ; Grid input doesn't work with MAP_SET

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Scale input radiance band
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  image_copy= BYTSCL(Z, min=range[0],max=range[1],/NAN) < 254; max is 254 because IDL sets 255 as black (sometimes)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Define Central position of the map
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ind=where(image_copy gt 0 AND image_copy lt 254)
  if ind[0] eq -1 then ind = indVALID

  if Keyword_set(south_pole) then begin
    Center_Latitude = -89.9
    Center_Longitude = 180
  endif else begin

    ; LATITUDE: Use Median value
    If N_elements(center_latitude ) eq 0 then center_latitude = median(Lat[ind])

    ; However, the following projections must be centered at equator
    If MAX(STRUPCASE(projection_name) EQ ["MERCATOR","AITOFF","HAMMERAITOFF","LAMBERTCONIC",$
      "CYLINDRICAL","MOLLWEIDE","SINUSOIDAL"           ,$
      "ALBERSEQUALAREACONIC","LAMBERTCONICELLIPSOID"]) GT 0 THEN center_latitude=0

    ; LONGITUDE: Use Mode value or center value (median doesn't work here)
    If ((N_elements(center_longitude) eq 0) || (string(center_longitude) eq '' )) then begin
      center_longitude = v_map_mode(Lon[ind])
      if center_longitude EQ -9999 THEN center_longitude = (Lon[ind])[N_elements(ind)/2] ; center of the image
    endif

    IF N_ELEMENTS(Local_Time) GT 0 THEN BEGIN
      If N_elements(center_local_time) eq 0 then center_local_time = (24. - center_longitude * 24. / 360.) mod 24.
    ENDIF

  endelse


  ;place latitude labels either on 180 or 0 depending on longitude center
  if n_elements(lablat) EQ 0 then	lablat=(abs(center_longitude) gt 90)? 180:0

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Define limits to Zoom south pole
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  last_sample = (size(Z,/DIM))[0]-1
  last_line   = (size(Z,/DIM))[1]-1


  IF KEYWORD_SET(SOUTH_ZOOM   ) THEN $
    ;limit = [min(latitude), center_longitude, max(latitude), (center_longitude+180) mod 360]
    ;  limit=[latitude[0],longitude[0],$
    ;         latitude[0],longitude[n_elements(longitude)-1],$
    ;         latitude[n_elements(latitude)-1],longitude[0] ,$
    ;         latitude[n_elements(latitude)-1],longitude[n_elements(longitude)-1]]
    ;  limit=[latitude[0,0],longitude[0,0],$
    ;         latitude[0,last_line],longitude[0,last_line],$
    ;         latitude[last_sample,last_line],longitude[last_sample,last_line],$
    ;         latitude[last_sample,0],longitude[last_sample,0]]
    limit=[-45,0,-45,90,-45,180,-45,270]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; DISPLAY MAP (by default)
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF ~keyword_set(MAP_TOOL) THEN BEGIN

    ;Use Z-Buffer to avoid diplaying the empty map
    SET_PLOT, "Z"
    DEVICE, SET_RESOLUTION=resolution
    if n_elements(fontname) gt 0 && fontname ne "" then begin
      !P.FONT=1
      DEVICE, SET_FONT=FONTNAME, /TT_FONT
    end else !P.FONT=-1

    IF KEYWORD_SET(INVERTED_BACKGROUND) THEN BEGIN
      !P.BACKGROUND=255
      !P.COLOR=0
    ENDIF ELSE BEGIN
      !P.BACKGROUND=0
      !P.COLOR=255
    ENDELSE

    ; Define Map
    Map_set, center_latitude, center_longitude,$
      limit=limit,$
      name=projection_name  ,$
      /isotropic, noborder=1,$
      position=[0.15,0.05,.98,.97], xmargin=3,ymargin=3,$
      SAT_P=sat_position,$
      _EXTRA=extraKeywords ;extra keywords passed by the user

    ; Project image on the map
    map_v=map_patch(image_copy, lon, lat, Xstart=Startx, Ystart=Starty, xsize=xsize, ysize=ysize, triangulate=0, MAX_VALUE=254.9,MISSING=!P.BACKGROUND)

    ; Display projected image
    tv, map_v, Startx, Starty

    if n_elements(lablat) eq 0 then if abs(center_longitude) gt 90 then lablat = 180 else lablat = 0

    ; Add map grid
    map_grid, CLIP_TEXT=0,/horizon, /label, charsize=charsize, GLINETHICK=linethick,LINESTYLE=linestyle,LONLAB=lablon,LATLAB=lablat,LONDEL=dellon,LATDEL=dellat,LONALIGN=labalign,LATALIGN=labalign,$
      LONNAMES=lonnames,LONS=lons         ;lonnames and lons are given if Local Time is used (see above)

    ; set best format depending on range
    if (range[1]-range[0]) lt 1     then format='(F5.2)'
    if (range[1]-range[0]) lt .1    then format='(F6.3)'
    if (range[1]-range[0]) lt .01   then format='(F8.4)'
    if (range[1]-range[0]) lt .001  then format='(F8.5)'
    if (range[1]-range[0]) lt .0001 then format='(E10.2)'
    if (range[1]-range[0]) ge 1     then format='(F4.1)'
    if (range[1]-range[0]) ge 10    then format='(I4)'
    if (range[1]-range[0]) ge 1000  then format='(I)'
    if (range[1]-range[0]) ge 1e6   then format='(E10.2)'
    ; Set Colorbar and title (uses colorbar routine from http://www.dfanning.com/programs/colorbar.pro)
    colorbar,/VERTICAL,/LEFT,position=[0.12, 0.05, 0.14, 0.9], TITLE=colorbar_title, RANGE=range, format=format, charsize=charsize,DIVISIONS=divisions
    if n_elements(title) Gt 0 then XYOUTS, .55, .02,title, /NORMAL,charsize=charsize,color=col_txt, ALIGNMENT=0.5

    ; Read projected image with grid
    IMG=TVRD()

    ; Display image either on iTool or single window
    SET_PLOT, mydevice ; reset device

    IF KEYWORD_SET(IMAGE_TOOL) THEN iimage, IMG,TITLE=title, RGB_TABLE=RGB_Table $
    ELSE BEGIN

      ; check if my window is not yet created or was closed
      device, window_state=allwindows

      IF n_elements(mywindow) eq 0 || allwindows[mywindow] eq 0 THEN BEGIN
        WINDOW, /FREE, XSIZE=resolution[0],YSIZE=resolution[1]
        mywindow=!D.WINDOW
      ENDIF

      WSET ,mywindow
      WSHOW,mywindow


      DEVICE, DECOMPOSED=0
      LOADCT, color_table

	  ;------------------------------------------------
	  ; FORCE BLACK and WHITE
	  TVLCT, R,G,B,/GET ; get RGB of color_table palette
	  ; Make White White
      R[255]=255
      G[255]=255
      B[255]=255
      R[0]=0
      G[0]=0
      B[0]=0
	  TVLCT, R, G, B
      ;-----------------------------------------------

      TV, IMG

    ENDELSE

  ENDIF

  IF keyword_set(MAP_TOOL) THEN BEGIN

    ; Invert IMAGE if LOCAL TIME (as it is opposite direction wrt longitude)
    IF N_ELEMENTS(Local_Time) GT 0 THEN BEGIN
      xdim = (size(image_copy,/DIM))[0]
      image_copy = image_copy[xdim-indgen(xdim)-1,*]
    ENDIF

    IMAP, image_copy,Lon, Lat,MAP_PROJECTION=Projection_Name,$
      CENTER_LATITUDE=center_latitude, CENTER_LONGITUDE=center_longitude

    ;; I Have some problems working with IMAP, here some of the keywords tested
    ;	   IMAGE_LOCATION=[-90,180];Lon, Lat,,$;,GRID_UNITS=2,$
    ;	   RGB_TABLE=RGB_TABLE, Sphere_Radius=6051800.,$
    ;	; IMAGE_TRANSPARENCY=10, /DISABLE_SPLASH_SCREEN,$
    ;	; BACKGROUND_COLOR=255, XGRIDSTYLE=2, YGRIDSTYLE=2, $
    ;	; XTITLE="xtitle", YTITLE="LATITUDE", /NO_SAVEPROMPT, $
    ;	;IMAGE_DIMENSIONS=[360,180];[(SIZE(image_copy,/DIM))[0],(SIZE(image_copy,/DIM))[1]];, $
    ;	;IMAGE_LOCATION=[-90,0]

    ;;IMAP, image_copy, findgen(240)*360/240.-180, findgen(180)-90, $;reform(Lon[*,0]),reform(Lat[0,*]) ,$;LIMIT=[-90,-180,90,180], $
    ;;IMAP, zsorted, xsorted,ysorted,$
    ;;IMAP, image_copy,Lon, Lat,$

  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; SAVEPNG
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  IF KEYWORD_SET(SAVEPNG) THEN BEGIN

	; Read output path
    if n_elements(output_file) eq 0 || output_file eq "" then output_file = title+".png"

    output_file = dialog_pickfile(/WRITE,FILE=output_file,PATH="path",FILTER=["*.png"],/OVERWRITE,$
                                                                       TITLE="Select filename for output file. Click CANCEL to ignore output.")
    if ~file_test(file_dirname(output_file)) || output_file eq "" then begin
            print, 'WARNING: output path "'+output_file+'" cannot be found and will be ignored.'
            output_file = ""
    endif

    if output_file NE "" then begin
       img = TVRD(/TRUE)
       WRITE_PNG, output_file, img
	endif

  ENDIF

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; RESTORE GRAPHICS DISPLAY
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  DEVICE, DECOMPOSED=decomposed ; restore original decomposed state
  TVLCT, R1, G1, B1             ; restore original color table


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Launch options dialog if QUERY keyword is set
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  QUERY:

  IF KEYWORD_SET(query) then begin
    reload = v_map_projection_options_query(CENTER_LONGITUDE   = center_longitude  ,$
      CENTER_LATITUDE    = center_latitude   ,$
      CENTER_LOCAL_TIME  = center_local_time ,$
      PROJECTION_NAME    = projection_name   ,$
      RESOLUTION         = resolution        ,$
      CHARSIZE           = charsize          ,$
      FONTNAME           = fontname          ,$
      LINETHICK          = linethick         ,$
      LINESTYLE          = linestyle         ,$
      LABLON             = lablon            ,$
      LABLAT             = lablat            ,$
      DELLON             = dellon            ,$
      DELLAT             = dellat            ,$
      LABALIGN           = labalign          ,$
      CROP_IMAGE         = crop_image        ,$
      PERCENT            = percent           ,$
      COLOR_TABLE        = color_table       ,$
      COLORBAR_TITLE     = colorbar_title    ,$
      INVERTED_BACKGROUND=inverted_background,$
      DIVISIONS          = divisions         ,$
      TITLE              = title             ,$
      SAT_POSITION       = sat_position      ,$
      RANGE              = range             ,$
      SOUTH_ZOOM         = south_zoom        ,$
      SAVEPNG            = savePNG           ,$
      IMAGE_TOOL         = image_tool        ,$
      MAP_TOOL           = map_tool)

    if reload eq 1 then GOTO, RESTART

  ENDIF

END

