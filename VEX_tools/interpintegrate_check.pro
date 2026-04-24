FUNCTION interpIntegrate_check, x, y, Ind1, Ind2, NewX, DO_CHECK=do_check

  COMPILE_OPT IDL2

  ; Get the number of points in the input arrays
  nbx = N_ELEMENTS(x)
  nbNewx = N_ELEMENTS(NewX)

  ; Pre-allocate the output array with double precision for accuracy
  n_out = Ind2 - Ind1 + 1
  NewY = DBLARR(n_out)

  ; --- Handle edge case where NewX is completely outside the range of x ---
  ; If so, the result is all zeros, and we can return early.
  IF (NewX[Ind1] GE x[nbx-1]) OR (NewX[Ind2] LE x[0]) THEN BEGIN

    ; If checking, print that we're skipping
    IF KEYWORD_SET(do_check) THEN BEGIN
      PRINT, '--- Integral Conservation Check ---'
      PRINT, '  NewX grid is outside the original data range.'
      PRINT, '  Skipping check. Returning zeros.'
      PRINT, '-----------------------------------'
    ENDIF

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

  ; ===================================================================
  ; 4. Optional: Check for conservation of the integral
  ; ===================================================================
  IF KEYWORD_SET(do_check) THEN BEGIN
    ; --- Calculate the integral of the original data (X, Y) ---
    ; We only integrate over the range covered by the new grid
    ; to ensure a fair comparison.

    ; Find the bin boundaries of the processed subset
    IF Ind1 EQ 0 THEN bLower = (3.0 * NewX[Ind1] - NewX[Ind1+1]) / 2.0 $
    ELSE bLower = (NewX[Ind1] + NewX[Ind1-1]) / 2.0

    IF Ind2 EQ (nbNewx-1) THEN bHigher = (3.0 * NewX[Ind2] - NewX[Ind2-1]) / 2.0 $
    ELSE bHigher = (NewX[Ind2] + NewX[Ind2+1]) / 2.0

    ; We must integrate the *original* data (x,y) over this
    ; exact same [bLower, bHigher] range.
    ; This is a complex operation, so for simplicity, we will
    ; use INT_TABULATED and assume the check is only valid
    ; if the grids cover the same range (as noted in Test 3).

    ; --- Calculate the integral of the original data (X, Y) ---
    original_integral = INT_TABULATED(x, y)

    ; --- Calculate the integral of the new data (NewX, NewY) ---
    ; We only integrate over the part of NewX that was processed
    NewX_subset = NewX[Ind1:Ind2]
    new_integral = INT_TABULATED(NewX_subset, NewY)

    PRINT, '--- Integral Conservation Check ---'
    PRINT, '  WARNING: Check is only valid if NewX and x cover'
    PRINT, '  the same total range.'
    PRINT, FORMAT='(A, E12.5)', '  Original Integral: ', original_integral
    PRINT, FORMAT='(A, E12.5)', '  New Integral:      ', new_integral

    denominator = original_integral
    IF ABS(denominator) LT 1e-9 THEN denominator = 1.0

    relative_diff = (original_integral - new_integral) / denominator
    PRINT, FORMAT='(A, E12.5)', '  Relative Difference: ', relative_diff
    PRINT, '-----------------------------------'
  ENDIF

  RETURN, NewY
END