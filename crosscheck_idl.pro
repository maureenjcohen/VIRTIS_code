;+
; VIRTIS Python/IDL cross-check report (IDL side).
;
; SETUP
;   Run this script from the VIRTIS_code directory (or adjust PATH_CODE below).
;   IDL must have access to VEX_tools/ and LecturePDS_2.7.5/ routines.
;
; RUN
;   .COMPILE crosscheck_idl.pro
;   crosscheck_idl
;
;   Output is written to  report_idl.txt  in the current directory.
;
; COMPARE
;   diff report_python.txt report_idl.txt
;
; NOTES ON KNOWN DIFFERENCES
;   correct_ia_ea:
;     IDL's incidence_angle_correction_mine.pro does not expose an EAband
;     keyword; when called from the command line the emission-angle array
;     defaults to 0.  The cross-check therefore passes IAband=inc120 and
;     relies on EAband=0 (undefined -> 0 in IDL), so both sides compute
;     R / cos(INC) / cos(0)^0.25  and should agree.
;
;   planck / brightness_temperature:
;     IDL often operates in float32; Python uses float64.
;     Up to 1-unit differences in the last printed decimal digit are normal.
;
;   vgeo_grid:
;     IDL returns grid[x_bin, y_bin] (longitude-first); Python returns
;     grid[y_bin, x_bin] (latitude-first).  The key uses j=lat-bin, i=lon-bin
;     so Python grid[j,i] == IDL grid[i,j].
;-

; ── print-value helper ────────────────────────────────────────────────────────
PRO pv, key, value
  IF FINITE(value) THEN $
    PRINT, key + ' = ' + STRTRIM(STRING(value, FORMAT='(E14.6)'), 2) $
  ELSE $
    PRINT, key + ' = NaN'
END


; ── main cross-check procedure ────────────────────────────────────────────────
PRO crosscheck_idl

  ; Capture all output to file
  JOURNAL, 'report_idl.txt'

  ; ── path setup ─────────────────────────────────────────────────────────────
  ; Run from VIRTIS_code/ or adjust these paths
  !PATH = EXPAND_PATH('+VEX_tools') + ':' + EXPAND_PATH('+LecturePDS_2.7.5') + ':' + !PATH

  ; ── header ─────────────────────────────────────────────────────────────────
  PRINT, '# VIRTIS cross-check report'
  PRINT, '# Script: IDL'
  date_str = STRING(FORMAT='(C(CYI4.4,"-",CMOI2.2,"-",CDI2.2,"T",CHI2.2,":",CMI2.2,":",CSI2.2))', SYSTIME(/JULIAN, /UTC))
  PRINT, '# Date: ' + date_str + ' UTC'
  PRINT, ''

  ; ── shared test inputs ──────────────────────────────────────────────────────
  R     = 0.05       ; radiance  W m-2 um-1 sr-1
  EMA   = 45.0       ; emission angle  degrees
  INC   = 120.0      ; incidence angle  degrees
  PHA   = 60.0       ; phase angle  degrees
  WL_M  = 2.3e-6     ; wavelength  metres
  WL_UM = 2.3        ; wavelength  microns
  T     = 300.0      ; temperature  K

  ; Single-pixel cube: [B=1, S=1, L=1] (BSL format, same as Python)
  cube        = FLTARR(1, 1, 1)  &  cube[0,0,0]  = R
  ema2d       = FLTARR(1, 1)     &  ema2d[0,0]   = EMA
  ema0        = FLTARR(1, 1)                        ; zero emission angle
  inc2d       = FLTARR(1, 1)     &  inc2d[0,0]   = INC
  pha2d       = FLTARR(1, 1)     &  pha2d[0,0]   = PHA

  ; ── planck ──────────────────────────────────────────────────────────────────
  pv, 'planck.T300K_wl2300nm',   planck(T, WL_M)

  ; Brightness temperature roundtrip: planck(300K) → brightness_temp → expect 300K
  ; IDL does not have a brightness_temperature routine; implement the inverse Planck inline.
  H = 6.626e-34D  &  C = 299792458.0D  &  K = 1.38e-23D
  lam_m = DOUBLE(WL_UM) * 1e-6D          ; µm → m
  R_planck = DOUBLE(planck(T, WL_M))     ; W m-2 um-1 sr-1
  T_bright = (H*C / (lam_m*K)) / ALOG(1.0D + 2.0D*H*C^2 / (lam_m^5 * R_planck * 1e6D))
  pv, 'bright_temp.roundtrip_300K', T_bright

  ; ── emission-angle corrections ───────────────────────────────────────────────
  ; QUBE is [B,S,L]; IDL transposes it internally and returns [B,S,L]
  emission_angle_correction_1_27, QUBE=cube, EMband=ema2d, CORRECTED_QUBE=res127, /NO_POPUPS
  pv, 'ema_1_27.R0.05_ema45', res127[0,0,0]

  emission_angle_correction_1_31, QUBE=cube, EMband=ema2d, CORRECTED_QUBE=res131, /NO_POPUPS
  pv, 'ema_1_31.R0.05_ema45', res131[0,0,0]

  emission_angle_correction_1_74, QUBE=cube, EMband=ema2d, CORRECTED_QUBE=res174, /NO_POPUPS
  pv, 'ema_1_74.R0.05_ema45', res174[0,0,0]

  emission_angle_correction_2_3,  QUBE=cube, EMband=ema2d, CORRECTED_QUBE=res23,  /NO_POPUPS
  pv, 'ema_2_3.R0.05_ema45',  res23[0,0,0]

  emission_angle_correction_3_8,  QUBE=cube, EMband=ema2d, CORRECTED_QUBE=res38,  /NO_POPUPS
  pv, 'ema_3_8.R0.05_ema45',  res38[0,0,0]

  emission_angle_correction_5_0,  QUBE=cube, EMband=ema2d, CORRECTED_QUBE=res50,  /NO_POPUPS
  pv, 'ema_5_0.R0.05_ema45',  res50[0,0,0]

  ; correct_general: 1×1 pixel → min_ema_per_line == pixel itself → result == R
  emission_angle_correction, QUBE=cube, EMband=ema2d, CORRECTED_QUBE=resgen, /NO_POPUPS
  pv, 'ema_general.R0.05_ema45', resgen[0,0,0]

  ; ── rad_to_rayleigh ──────────────────────────────────────────────────────────
  WL_ARR = [WL_M]   ; 1-element wavelength array in metres
  rad_to_rayleigh, QUBE=cube, WL=WL_ARR, RAYLEIGH=res_r2r, /NO_POPUPS
  pv, 'rad_rayleigh.R0.05_wl2300nm', res_r2r[0,0,0]

  ; ── interp_integrate ─────────────────────────────────────────────────────────
  ; interpIntegrate(x, y, Ind1, Ind2, NewX) — same argument order as Python
  x_ii     = [1.0, 2.0, 3.0, 4.0, 5.0]
  y_ii     = [1.0, 2.0, 3.0, 4.0, 5.0]
  new_x_ii = [2.0, 3.0, 4.0]
  out_ii   = interpIntegrate(x_ii, y_ii, 0, 2, new_x_ii)
  pv, 'interp_integrate.linear_newx2', out_ii[0]
  pv, 'interp_integrate.linear_newx3', out_ii[1]
  pv, 'interp_integrate.linear_newx4', out_ii[2]

  ; ── correct_ia_ea ────────────────────────────────────────────────────────────
  ; IDL: incidence_angle_correction_mine, QUBE=cube, IAband=inc (EAband defaults to 0)
  ; formula: R / cos(INC) / cos(0)^0.25 = R / cos(INC)
  incidence_angle_correction_mine, QUBE=cube, IAband=inc2d, CORRECTED_QUBE=res_ia, /NO_POPUPS
  pv, 'correct_ia_ea.R0.05_inc120_ema0', res_ia[0,0,0]

  ; ── correct_phase_angle ──────────────────────────────────────────────────────
  ; IDL parameter is named IAband but accepts phase angle values
  phase_angle_correction, QUBE=cube, IAband=pha2d, CORRECTED_QUBE=res_pa, /NO_POPUPS
  pv, 'correct_phase.R0.05_phase60', res_pa[0,0,0]

  ; ── amedian ──────────────────────────────────────────────────────────────────
  ; 3x3 array: all 3.0 except centre = 7.0
  ; arr33[1,1] = centre element (matches Python arr33[1,1])
  arr33        = FLTARR(3, 3) + 3.0
  arr33[1, 1]  = 7.0
  out33        = AMEDIAN(arr33, 3)
  pv, 'amedian_3x3.center',   out33[1, 1]
  pv, 'amedian_3x3.corner00', out33[0, 0]
  pv, 'amedian_3x3.corner22', out33[2, 2]

  ; ── scet2jul ─────────────────────────────────────────────────────────────────
  pv, 'scet2jul.orbit93', v_scet2jul('1/00043946888.29290', /VEX, /NO_WARNING)

  ; ── ia_corr ──────────────────────────────────────────────────────────────────
  ; Requires real PDS structures — load orbit-93 test data
  cal_file = 'test_data/cubes/VIR0093/CALIBRATED/VI0093_01.CAL'
  geo_file = 'test_data/cubes/VIR0093/GEOMETRY/VI0093_01.GEO'
  cal = virtispds(cal_file)
  geo = virtispds(geo_file)

  ia_corr, cal, geo, 76, res_ia_corr   ; result is (samples, lines) = (ns, nl)
  pv, 'ia_corr.orbit93_band76_s0_l0',  res_ia_corr[0,  0]
  pv, 'ia_corr.orbit93_band76_s10_l5', res_ia_corr[10, 5]

  ; ── v_geo_grid ───────────────────────────────────────────────────────────────
  ; 4x4 longitude/latitude grid, band 76, orbit-93 data.
  ; IDL returns grid[i_lon, j_lat]; Python returns grid[j_lat, i_lon].
  ; Key uses j=lat-bin, i=lon-bin; access: IDL grid[i,j], Python grid[j,i].
  grid = v_geo_grid(cal_file, geo_file, $
                    INDEX_BAND=76, LONGITUDE=1,  $
                    XSIZE=4,  YSIZE=4,           $
                    XRANGE=[0.0, 360.0],         $
                    YRANGE=[-90.0, 90.0],        $
                    /NO_POPUPS)

  IF N_ELEMENTS(grid) EQ 1 THEN BEGIN
    PRINT, '# ERROR: v_geo_grid returned scalar (no valid pixels)'
  ENDIF ELSE BEGIN
    FOR j=0,3 DO BEGIN
      FOR i=0,3 DO BEGIN
        key = 'vgeo.band76_4x4_j' + STRTRIM(j,2) + '_i' + STRTRIM(i,2)
        pv, key, grid[i, j]   ; IDL: grid[lon_bin, lat_bin]
      ENDFOR
    ENDFOR
  ENDELSE

  ; ── close journal ─────────────────────────────────────────────────────────────
  JOURNAL

  PRINT, 'Done. Report written to report_idl.txt'

END
