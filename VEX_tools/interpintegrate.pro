;+
; NAME:
;       interpIntegrate
;
; PURPOSE:
;       Resample a dataset (x,y) onto a new grid (NewX) by calculating
;       the binned average value. This is the IDL equivalent of the
;       provided MATLAB function.
;
; CATEGORY:
;       Interpolation, Integration
;
; CALLING SEQUENCE:
;       NewY = interpIntegrate(x, y, Ind1, Ind2, NewX)
;
; INPUTS:
;       x:      The independent variable vector of the original data.
;       y:      The dependent variable vector of the original data.
;       Ind1:   The starting index of NewX to process.
;       Ind2:   The ending index of NewX to process.
;       NewX:   The new x-axis grid onto which y will be resampled.
;
; OUTPUTS:
;       NewY:   The resulting vector of integrated/averaged values. The size
;               is (Ind2 - Ind1 + 1).
;
; ALGORITHM:
;       For each point NewX(i), a bin is defined from the midpoint between
;       NewX(i-1) and NewX(i) to the midpoint between NewX(i) and NewX(i+1).
;       The function y(x) is numerically integrated over this bin using the
;       trapezoidal rule, with linear interpolation used to find the function
;       values at the precise bin boundaries. The final output value is the
;       total integral divided by the bin width (i.e., the mean value).
;
; AUTHOR:
;       Translation of a MATLAB routine.
;
; MODIFICATION HISTORY:
;       Oct 2025 - Written.
;-
FUNCTION interpIntegrate, x, y, Ind1, Ind2, NewX, DO_CHECK=do_check

  COMPILE_OPT IDL2

  ; Get the number of points in the input arrays
  nbx = N_ELEMENTS(x)
  nbNewx = N_ELEMENTS(NewX)

  ; Pre-allocate the output array with double precision for accuracy
  NewY = DBLARR(Ind2 - Ind1 + 1)

  ; --- Handle edge case where NewX is completely outside the range of x ---
  ; If so, the result is all zeros, and we can return early.
  IF (NewX[Ind1] GE x[nbx-1]) OR (NewX[Ind2] LE x[0]) THEN BEGIN
    RETURN, NewY
  ENDIF

  jLower = 0L ; Initialize the lower index search hint

  ; --- Main loop over the specified range of NewX ---
  FOR i = Ind1, Ind2 DO BEGIN

    ; ===================================================================
    ; 1. Define the integration bin boundaries (Lower and Higher)
    ; ===================================================================
    ; For the first point, extrapolate the lower boundary
    IF i EQ 0 THEN BEGIN
      Lower = (3.0 * NewX[i] - NewX[i+1]) / 2.0
    ENDIF ELSE BEGIN
      Lower = (NewX[i] + NewX[i-1]) / 2.0
    ENDELSE

    ; For the last point, extrapolate the higher boundary
    IF i EQ (nbNewx-1) THEN BEGIN
      Higher = (3.0 * NewX[i] - NewX[i-1]) / 2.0
    ENDIF ELSE BEGIN
      Higher = (NewX[i] + NewX[i+1]) / 2.0
    ENDELSE

    ; ===================================================================
    ; 2. Find bracketing indices and interpolate y-values at boundaries
    ; ===================================================================
    ; --- Lower boundary processing ---
    IF Lower LT x[0] THEN BEGIN
      jLower = 0
      ; The y-value is effectively zero outside the original data range
      YLower = 0.0
    ENDIF ELSE BEGIN
      ; Find the index in x that is just below 'Lower'
      ; Start the search from the last known jLower for efficiency
      WHILE (jLower LT nbx-1) AND (x[jLower+1] LT Lower) DO jLower = jLower + 1

      ; Linearly interpolate to find the y-value at the 'Lower' position
      YLower = y[jLower] + (y[jLower+1] - y[jLower]) * (Lower - x[jLower]) / (x[jLower+1] - x[jLower])
    ENDELSE

    ; --- Higher boundary processing ---
    IF Higher GT x[nbx-1] THEN BEGIN
      jHigher = nbx - 1
      ; The y-value is effectively zero outside the original data range
      YHigher = 0.0
    ENDIF ELSE BEGIN
      ; Find the index in x that is just below 'Higher'
      ; Start the search from our current jLower
      j = jLower
      WHILE (j LT nbx-1) AND (x[j+1] LT Higher) DO j = j + 1
      jHigher = j


      ; Linearly interpolate to find the y-value at the 'Higher' position
      YHigher = y[jHigher] + (y[jHigher+1] - y[jHigher]) * (Higher - x[jHigher]) / (x[jHigher+1] - x[jHigher])
    ENDELSE

    ; ===================================================================
    ; 3. Integrate over the bin using the trapezoidal rule
    ; ===================================================================
    IF jLower EQ jHigher THEN BEGIN
      ; If the entire bin is between two original x-points, the result
      ; is simply the average of the interpolated boundary values.
      NewY[i-Ind1] = (YLower + YHigher) / 2.0
    ENDIF ELSE BEGIN
      ; --- Sum the areas of all trapezoids within the [Lower, Higher] bin ---

      ; First partial interval: from Lower to the next x-point
      DeltaX = x[jLower+1] - Lower
      XSum = DeltaX
      YSum = (YLower + y[jLower+1]) * DeltaX

      ; Last partial interval: from the last internal x-point to Higher
      DeltaX = Higher - x[jHigher]
      XSum = XSum + DeltaX
      YSum = YSum + (YHigher + y[jHigher]) * DeltaX

      ; Intermediate full intervals
      IF (jHigher - jLower) GT 1 THEN BEGIN
        FOR j = jLower+1, jHigher-1 DO BEGIN
          DeltaX = x[j+1] - x[j]
          XSum = XSum + DeltaX
          YSum = YSum + (y[j+1] + y[j]) * DeltaX
        ENDFOR
      ENDIF

      ; --- Calculate the final average value ---
      IF XSum EQ 0.0 THEN BEGIN
        NewY[i-Ind1] = 0.0
      ENDIF ELSE BEGIN
        ; The total integral is YSum/2. Divide by the total width (XSum)
        ; to get the average value.
        NewY[i-Ind1] = YSum / XSum / 2.0
      ENDELSE
    ENDELSE

  ENDFOR

  IF KEYWORD_SET(do_check) THEN BEGIN
  ; 4. Calculate the integral of the original and new datasets
  ;    We use the built-in INT_TABULATED for a simple trapezoidal integration
    original_integral = INT_TABULATED(x, y)
    new_integral = INT_TABULATED(NewX, NewY)

  ; 5. Compare the integrals and report the result
    PRINT, 'Original Integral: ', original_integral
    PRINT, 'New Integral:      ', new_integral

    relative_diff = (original_integral - new_integral) / original_integral
    PRINT, 'Relative Difference: ', relative_diff

  ENDIF

  RETURN, NewY
END

; ===================================================================
; TEST ROUTINE
;
; This procedure contains test cases for the interpIntegrate function.
; ===================================================================
PRO TEST_INTERPINTEGRATE

  PRINT, '--- Running interpIntegrate Test 1: Linear Ramp (y=x) ---'
  ; 1. Create original data: y = x from 0 to 10
  ; [cite_start]We use double precision to match the function's internal calculations[cite: 17].
  x_data = DINDGEN(11) ; [0.0, 1.0, 2.0, ..., 10.0]
  y_data = x_data       ; [0.0, 1.0, 2.0, ..., 10.0]

  ; 2. Create new grid to integrate onto
  ; We choose a grid where the midpoints align with the original data
  new_x_grid = DINDGEN(9) + 1.0 ; [1.0, 2.0, ..., 9.0]
  n_new = N_ELEMENTS(new_x_grid)

  ; 3. Call the function to process the entire new grid
  ;    (from index 0 to n_new-1)
  result = interpIntegrate(x_data, y_data, 0, n_new - 1, new_x_grid)

  PRINT, 'Test 1 Input (NewX):', new_x_grid
  PRINT, 'Test 1 Result:      ', result
  PRINT, 'Test 1 Expected:    ', new_x_grid

  ; For a linear ramp y=x, the binned average should be exactly
  ; equal to the center point of the bin, which is NewX itself.
  IF TOTAL(ABS(result - new_x_grid)) LT 1e-9 THEN BEGIN
    PRINT, 'Result: PASSED'
  ENDIF ELSE BEGIN
    PRINT, 'Result: FAILED'
  ENDELSE

  PRINT, '' ; Add a blank line
  PRINT, '--- Running interpIntegrate Test 2: Outside Range Check ---'
  ; 4. Create a new grid that is completely outside the original x_data
  new_x_outside = [20.0, 21.0, 22.0]
  n_out = N_ELEMENTS(new_x_outside)

  ; 5. Call the function
  ;    [cite_start]This should trigger the early return check [cite: 20]
  result_outside = interpIntegrate(x_data, y_data, 0, n_out - 1, new_x_outside)
  expected_outside = DBLARR(n_out) ; Expect [0.0, 0.0, 0.0]

  PRINT, 'Test 2 Input (NewX):', new_x_outside
  PRINT, 'Test 2 Result:      ', result_outside
  PRINT, 'Test 2 Expected:    ', expected_outside

  IF TOTAL(ABS(result_outside - expected_outside)) LT 1e-9 THEN BEGIN
     PRINT, 'Result: PASSED'
  ENDIF ELSE BEGIN
     PRINT, 'Result: FAILED'
  ENDELSE

  PRINT, '' ; Add a blank line
  PRINT, '--- Running interpIntegrate Test 3: Integral Conservation ---'

  ; 1. Define high-resolution original data (a Gaussian curve)
  nx_orig = 1001L
  x_orig = (DINDGEN(nx_orig) / (nx_orig - 1.0)) * 20.0 - 10.0 ; Range -10 to 10
  y_orig = EXP(-(x_orig - 1.0)^2 / (2.0 * 2.0^2)) ; Gaussian centered at 1.0

  ; 2. Define a low-resolution new grid
  ;    To check total conservation, it MUST cover the *same* range
  nx_new = 51L
  x_new = (DINDGEN(nx_new) / (nx_new - 1.0)) * 20.0 - 10.0 ; Range -10 to 10

  ; 3. Call the function to resample the data
  y_new = interpIntegrate(x_orig, y_orig, 0, nx_new - 1, x_new)

  ; 4. Calculate the integral of the original and new datasets
  ;    We use the built-in INT_TABULATED for a simple trapezoidal integration
  original_integral = INT_TABULATED(x_orig, y_orig)
  new_integral = INT_TABULATED(x_new, y_new)

  ; 5. Compare the integrals and report the result
  PRINT, 'Original Integral: ', original_integral
  PRINT, 'New Integral:      ', new_integral

  relative_diff = (original_integral - new_integral) / original_integral
  PRINT, 'Relative Difference: ', relative_diff

  ; A small tolerance is needed for numerical precision differences
  IF ABS(relative_diff) LT 1e-6 THEN BEGIN
    PRINT, 'Result: PASSED'
  ENDIF ELSE BEGIN
    PRINT, 'Result: FAILED'
  ENDELSE

END

; ===================================================================
; Main-level script execution
;
; This block will execute when the file is compiled via .RUN or .RNEW
; It simply calls the test procedure defined above.
; ===================================================================

TEST_INTERPINTEGRATE

END