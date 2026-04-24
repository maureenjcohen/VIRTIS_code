;+
; NAME:
;       interpIntegrate_3D
;
; PURPOSE:
;       Resample a dataset (x,y) onto a new grid (NewX) by calculating
;       the binned average value. This version is generalized to handle
;       1D, 2D, or 3D 'y' arrays.
;
; CATEGORY:
;       Interpolation, Integration
;
; CALLING SEQUENCE:
;       NewY = interpIntegrate_3D(x, y, Ind1, Ind2, NewX, [, DO_CHECK=1])
;
; INPUTS:
;       x:      The independent variable vector of the original data. Must be 1D.
;       y:      The dependent variable data. Can be a 1D, 2D, or 3D array.
;               The first dimension of 'y' MUST have the same length as 'x'.
;               e.g., (N_x), (N_x, D2), or (N_x, D2, D3).
;       Ind1:   The starting index of NewX to process.
;       Ind2:   The ending index of NewX to process.
;       NewX:   The new x-axis grid onto which y will be resampled.
;
; KEYWORD PARAMETERS:
;       DO_CHECK: If set, the function will perform a check to verify that
;                 the total integrated area under the curve is conserved
;                 between the original and the resampled data. It will
;                 print the results of this check to the console.
;
; OUTPUTS:
;       NewY:   The resulting array of integrated/averaged values. The output
;               dimensions will match the input 'y' dimensions, except
;               the first dimension will have length K = Ind2 - Ind1 + 1.
;
; MODIFICATION HISTORY:
;       Oct 2025 - Added DO_CHECK keyword for integral conservation verification.
;-
FUNCTION interpIntegrate_3D, x, y, Ind1, Ind2, NewX, DO_CHECK=do_check

  COMPILE_OPT IDL2

  ; ===================================================================
  ; 1. Handle input dimensions and pre-allocate output
  ; ===================================================================
  nbx = N_ELEMENTS(x)
  nbNewx = N_ELEMENTS(NewX)
  s_y = SIZE(y, /DIMENSIONS)
  n_dims_y = N_ELEMENTS(s_y)

  IF s_y[0] NE nbx THEN MESSAGE, 'The first dimension of y must match the length of x.'

  CASE n_dims_y OF
    1: BEGIN ; 1D input (Nx) -> Reshape to (Nx, 1, 1)
      D2 = 1L & D3 = 1L
      y_3d = REFORM(y, nbx, 1, 1)
    END
    2: BEGIN ; 2D input (Nx, D2) -> Reshape to (Nx, D2, 1)
      D2 = s_y[1] & D3 = 1L
      y_3d = REFORM(y, nbx, D2, 1)
    END
    3: BEGIN ; 3D input (Nx, D2, D3)
      D2 = s_y[1] & D3 = s_y[2]
      y_3d = y
    END
    ELSE: MESSAGE, 'Input y must have 1, 2, or 3 dimensions.'
  ENDCASE

  n_out = Ind2 - Ind1 + 1
  NewY = DBLARR(n_out, D2, D3)

  IF (NewX[Ind1] GE x[nbx-1]) OR (NewX[Ind2] LE x[0]) THEN BEGIN
    final_dims = s_y & final_dims[0] = n_out
    RETURN, REFORM(NewY, final_dims)
  ENDIF

  jLower = 0L

  ; ===================================================================
  ; 2. Main Resampling Loop
  ; ===================================================================
  FOR i = Ind1, Ind2 DO BEGIN

    IF i EQ 0 THEN Lower = (3.0 * NewX[i] - NewX[i+1]) / 2.0 $
    ELSE Lower = (NewX[i] + NewX[i-1]) / 2.0

    IF i EQ (nbNewx-1) THEN Higher = (3.0 * NewX[i] - NewX[i-1]) / 2.0 $
    ELSE Higher = (NewX[i] + NewX[i+1]) / 2.0

    IF Lower LT x[0] THEN BEGIN
      jLower = 0 & YLower = DBLARR(D2, D3)
    ENDIF ELSE BEGIN
      WHILE (jLower LT nbx-1) AND (x[jLower+1] LT Lower) DO jLower = jLower + 1
      factor = (Lower - x[jLower]) / (x[jLower+1] - x[jLower])
      slice1 = y_3d[jLower, *, *] & slice2 = y_3d[jLower+1, *, *]
      YLower = slice1 + (slice2 - slice1) * factor
    ENDELSE

    IF Higher GT x[nbx-1] THEN BEGIN
      jHigher = nbx - 1 & YHigher = DBLARR(D2, D3)
    ENDIF ELSE BEGIN
      j = jLower
      WHILE (j LT nbx-1) AND (x[j+1] LT Higher) DO j = j + 1
      jHigher = j
      factor = (Higher - x[jHigher]) / (x[jHigher+1] - x[jHigher])
      slice1 = y_3d[jHigher, *, *] & slice2 = y_3d[jHigher+1, *, *]
      YHigher = slice1 + (slice2 - slice1) * factor
    ENDELSE

    IF jLower EQ jHigher THEN BEGIN
      NewY[i-Ind1, *, *] = (YLower + YHigher) / 2.0
    ENDIF ELSE BEGIN
      DeltaX = x[jLower+1] - Lower
      XSum = DeltaX
      YSum = (YLower + y_3d[jLower+1, *, *]) * DeltaX

      DeltaX = Higher - x[jHigher]
      XSum = XSum + DeltaX
      YSum = YSum + (YHigher + y_3d[jHigher, *, *]) * DeltaX

      IF (jHigher - jLower) GT 1 THEN BEGIN
        FOR j = jLower+1, jHigher-1 DO BEGIN
          DeltaX = x[j+1] - x[j]
          XSum = XSum + DeltaX
          YSum = YSum + (y_3d[j+1, *, *] + y_3d[j, *, *]) * DeltaX
        ENDFOR
      ENDIF

      IF XSum NE 0.0 THEN NewY[i-Ind1, *, *] = YSum / XSum / 2.0
    ENDELSE
  ENDFOR

  ; ===================================================================
  ; 3. Optional: Check for conservation of the integral
  ; ===================================================================
  IF KEYWORD_SET(do_check) THEN BEGIN
    ; --- Calculate the integral of the original data (X, Y) ---
    original_integral = DBLARR(D2, D3)
    FOR j = 0, nbx - 2 DO BEGIN
      trapezoid = (y_3d[j+1,*,*] + y_3d[j,*,*]) * (x[j+1] - x[j]) / 2.0
      original_integral += trapezoid
    ENDFOR

    ; --- Calculate the integral of the new data (NewX, NewY) ---
    new_integral = DBLARR(D2, D3)
    NewX_subset = NewX[Ind1:Ind2]
    FOR i = 0, n_out - 2 DO BEGIN
      trapezoid = (NewY[i+1,*,*] + NewY[i,*,*]) * (NewX_subset[i+1] - NewX_subset[i]) / 2.0
      new_integral += trapezoid
    ENDFOR

    ; --- Compare the two integrals and print the results ---
    PRINT, '--- Integral Conservation Check ---'
    denominator = original_integral
    zero_idx = WHERE(ABS(denominator) LT 1e-9, count)
    IF count GT 0 THEN denominator[zero_idx] = 1.0 ; Avoid division by zero

    relative_diff = (original_integral - new_integral) / denominator

    PRINT, FORMAT='(A, E12.5)', '  Min Relative Difference:  ', MIN(relative_diff)
    PRINT, FORMAT='(A, E12.5)', '  Max Relative Difference:  ', MAX(relative_diff)
    PRINT, FORMAT='(A, E12.5)', '  Mean Relative Difference: ', MEAN(relative_diff)
    PRINT, '-----------------------------------'
  ENDIF

  ; ===================================================================
  ; 4. Reshape output and return
  ; ===================================================================
  final_dims = s_y
  final_dims[0] = n_out
  RETURN, REFORM(NewY, final_dims)
END


; ===================================================================
; TEST ROUTINE
;
; This procedure contains test cases for the interpIntegrate_3D function.
; ===================================================================
PRO TEST_INTERPINTEGRATE_3D

  COMPILE_OPT IDL2

  ; --- Define a common high-resolution original X-grid ---
  ; 1001 points from -10 to 10
  nx = 1001L
  x_data = (DINDGEN(nx) / (nx - 1.0)) * 20.0 - 10.0

  ; --- Define a common low-resolution new X-grid to resample onto ---
  ; 51 points from -8 to 8 (intentionally not covering the full original range)
  n_new = 51L
  new_x_grid = (DINDGEN(n_new) / (n_new - 1.0)) * 16.0 - 8.0

  ; Define the full range to process
  Ind1 = 0
  Ind2 = n_new - 1

  PRINT, '=================================================='
  PRINT, '--- Running interpIntegrate_3D Test 1: 1D Case ---'
  PRINT, '=================================================='

  ; 1. Create 1D test data (a Gaussian curve)
  y_data_1d = EXP(-(x_data - 1.0)^2 / (2.0 * 2.0^2))

  ; 2. Call the function
  new_y_1d = interpIntegrate_3D(x_data, y_data_1d, Ind1, Ind2, new_x_grid, /DO_CHECK)

  PRINT, 'Test 1 Input Y Dims:  ', SIZE(y_data_1d, /DIMENSIONS)
  PRINT, 'Test 1 Output Y Dims: ', SIZE(new_y_1d, /DIMENSIONS)
  PRINT, '' ; New line


  PRINT, '=================================================='
  PRINT, '--- Running interpIntegrate_3D Test 2: 2D Case ---'
  PRINT, '=================================================='

  ; 1. Create 2D test data (e.g., 4 different Gaussian curves)
  D2 = 4L
  y_data_2d = DBLARR(nx, D2)
  FOR j = 0, D2-1 DO BEGIN
    center = (j - 1.5) * 3.0 ; Centers at -4.5, -1.5, 1.5, 4.5
    y_data_2d[*, j] = (j+1) * EXP(-(x_data - center)^2 / (2.0 * 2.0^2))
  ENDFOR

  ; 2. Call the function
  new_y_2d = interpIntegrate_3D(x_data, y_data_2d, Ind1, Ind2, new_x_grid, /DO_CHECK)

  PRINT, 'Test 2 Input Y Dims:  ', SIZE(y_data_2d, /DIMENSIONS)
  PRINT, 'Test 2 Output Y Dims: ', SIZE(new_y_2d, /DIMENSIONS)
  PRINT, '' ; New line


  PRINT, '=================================================='
  PRINT, '--- Running interpIntegrate_3D Test 3: 3D Case ---'
  PRINT, '=================================================='

  ; 1. Create 3D test data (e.g., 4x3 grid of different Gaussians)
  D2 = 4L
  D3 = 3L
  y_data_3d = DBLARR(nx, D2, D3)
  FOR k = 0, D3-1 DO BEGIN
    width = (k + 1.0) ; Widths of 1.0, 2.0, 3.0
    FOR j = 0, D2-1 DO BEGIN
      center = (j - 1.5) * 3.0 ; Centers at -4.5, -1.5, 1.5, 4.5
      y_data_3d[*, j, k] = (j+1) * EXP(-(x_data - center)^2 / (2.0 * width^2))
    ENDFOR
  ENDFOR

  ; 2. Call the function
  new_y_3d = interpIntegrate_3D(x_data, y_data_3d, Ind1, Ind2, new_x_grid, /DO_CHECK)

  PRINT, 'Test 3 Input Y Dims:  ', SIZE(y_data_3d, /DIMENSIONS)
  PRINT, 'Test 3 Output Y Dims: ', SIZE(new_y_3d, /DIMENSIONS)
  PRINT, '' ; New line

END

;; ===================================================================
;; Main-level script execution
;;
;; This block will execute when the file is compiled via .RUN or .RNEW
;; It simply calls the test procedure defined above and times it.
;; ===================================================================
;
PRINT, 'Starting TEST_INTERPINTEGRATE_3D...'
t0 = SYSTIME(1) ; Get start time (in seconds)

TEST_INTERPINTEGRATE_3D

t1 = SYSTIME(1) ; Get end time (in seconds)
PRINT, ''
PRINT, FORMAT='(A, F8.3, A)', '--- Total test duration: ', t1 - t0, ' seconds ---'
PRINT, '=================================================='

END