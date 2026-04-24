FUNCTION interpIntegrate_2D, x, y, Ind1, Ind2, NewX, DO_CHECK=do_check

  COMPILE_OPT IDL2

  ; ===================================================================
  ; 1. Handle input dimensions and pre-allocate output
  ; ===================================================================
  nbx = N_ELEMENTS(x)
  nbNewx = N_ELEMENTS(NewX)
  s_y = SIZE(y, /DIMENSIONS)

  y_was_1d = (N_ELEMENTS(s_y) EQ 1)

  IF y_was_1d THEN BEGIN
    ; If y is 1D, promote it to a 2D array of size (1, N)
    ; This allows the rest of the code to work uniformly.
    M = 1
    IF s_y[0] NE nbx THEN MESSAGE, 'Input y vector must match the length of x.'
    y_2d = REFORM(y, 1, nbx)
  ENDIF ELSE BEGIN
    M = s_y[0]
    IF s_y[1] NE nbx THEN MESSAGE, 'The 2nd dimension of y must match the length of x.'
    y_2d = y
  ENDELSE

  ; Pre-allocate the output array
  n_out = Ind2 - Ind1 + 1
  NewY = DBLARR(M, n_out)

  ; --- Handle edge case where NewX is completely outside the range of x ---
  IF (NewX[Ind1] GE x[nbx-1]) OR (NewX[Ind2] LE x[0]) THEN BEGIN

    ; If checking, print that we're skipping
    IF KEYWORD_SET(do_check) THEN BEGIN
      PRINT, '--- Integral Conservation Check ---'
      PRINT, '  NewX grid is outside the original data range.'
      PRINT, '  Skipping check. Returning zeros.'
      PRINT, '-----------------------------------'
    ENDIF

    IF y_was_1d THEN RETURN, REFORM(NewY) ELSE RETURN, NewY
  ENDIF

  jLower = 0L ; Initialize the lower index search hint

  ; --- Main loop over the specified range of NewX ---
  FOR i = Ind1, Ind2 DO BEGIN

    ; --- Define integration bin boundaries (Lower and Higher) ---
    IF i EQ 0 THEN Lower = (3.0 * NewX[i] - NewX[i+1]) / 2.0 $
    ELSE Lower = (NewX[i] + NewX[i-1]) / 2.0

    IF i EQ (nbNewx-1) THEN Higher = (3.0 * NewX[i] - NewX[i-1]) / 2.0 $
    ELSE Higher = (NewX[i] + NewX[i+1]) / 2.0

    ; --- Find bracketing indices and interpolate y-values at boundaries ---
    IF Lower LT x[0] THEN BEGIN
      jLower = 0
      YLower = DBLARR(M) ; Vector of zeros
    ENDIF ELSE BEGIN
      WHILE (jLower LT nbx-1) AND (x[jLower+1] LT Lower) DO jLower = jLower + 1
      ; Perform vector interpolation
      factor = (Lower - x[jLower]) / (x[jLower+1] - x[jLower])
      YLower = y_2d[*, jLower] + (y_2d[*, jLower+1] - y_2d[*, jLower]) * factor
    ENDELSE

    IF Higher GT x[nbx-1] THEN BEGIN
      jHigher = nbx - 1
      YHigher = DBLARR(M) ; Vector of zeros
    ENDIF ELSE BEGIN
      j = jLower
      WHILE (j LT nbx-1) AND (x[j+1] LT Higher) DO j = j + 1
      jHigher = j
      ; Perform vector interpolation
      factor = (Higher - x[jHigher]) / (x[jHigher+1] - x[jHigher])
      YHigher = y_2d[*, jHigher] + (y_2d[*, jHigher+1] - y_2d[*, jHigher]) * factor
    ENDELSE

    ; ===================================================================
    ; 3. Integrate over the bin using the trapezoidal rule
    ; ===================================================================
    IF jLower EQ jHigher THEN BEGIN
      NewY[*, i-Ind1] = (YLower + YHigher) / 2.0
    ENDIF ELSE BEGIN
      ; --- Sum the areas of all trapezoids within the [Lower, Higher] bin ---
      ; All operations on y and YSum are now vector operations of size M.

      ; First partial interval
      DeltaX = x[jLower+1] - Lower
      XSum = DeltaX
      YSum = (YLower + y_2d[*, jLower+1]) * DeltaX ; YSum is now a vector

      ; Last partial interval
      DeltaX = Higher - x[jHigher]
      XSum = XSum + DeltaX
      YSum = YSum + (YHigher + y_2d[*, jHigher]) * DeltaX

      ; Intermediate full intervals
      IF (jHigher - jLower) GT 1 THEN BEGIN
        FOR j = jLower+1, jHigher-1 DO BEGIN
          DeltaX = x[j+1] - x[j]
          XSum = XSum + DeltaX
          YSum = YSum + (y_2d[*, j+1] + y_2d[*, j]) * DeltaX
        ENDFOR
      ENDIF

      ; --- Calculate the final average value ---
      IF XSum EQ 0.0 THEN BEGIN
        NewY[*, i-Ind1] = DBLARR(M)
      ENDIF ELSE BEGIN
        NewY[*, i-Ind1] = YSum / XSum / 2.0
      ENDELSE
    ENDELSE

  ENDFOR

  ; ===================================================================
  ; 4. Optional: Check for conservation of the integral
  ; ===================================================================
  IF KEYWORD_SET(do_check) THEN BEGIN
    ; --- Calculate the integral of the original data (X, Y) ---
    original_integral = DBLARR(M)
    FOR j = 0, nbx - 2 DO BEGIN
      trapezoid = (y_2d[*,j+1] + y_2d[*,j]) * (x[j+1] - x[j]) / 2.0
      original_integral += trapezoid
    ENDFOR

    ; --- Calculate the integral of the new data (NewX, NewY) ---
    new_integral = DBLARR(M)
    NewX_subset = NewX[Ind1:Ind2]
    FOR i = 0, n_out - 2 DO BEGIN
      trapezoid = (NewY[*,i+1] + NewY[*,i]) * (NewX_subset[i+1] - NewX_subset[i]) / 2.0
      new_integral += trapezoid
    ENDFOR

    ; --- Compare the two integrals and print the results ---
    PRINT, '--- Integral Conservation Check ---'
    PRINT, '  WARNING: Check is only valid if NewX and x cover'
    PRINT, '  the same total range.'

    denominator = original_integral
    zero_idx = WHERE(ABS(denominator) LT 1e-9, count)
    IF count GT 0 THEN denominator[zero_idx] = 1.0 ; Avoid division by zero

    relative_diff = (original_integral - new_integral) / denominator

    PRINT, FORMAT='(A, E12.5)', '  Min Relative Difference:  ', MIN(relative_diff)
    PRINT, FORMAT='(A, E12.5)', '  Max Relative Difference:  ', MAX(relative_diff)
    PRINT, FORMAT='(A, E12.5)', '  Mean Relative Difference: ', MEAN(relative_diff)
    PRINT, '-----------------------------------'
  ENDIF

  ; If the original y was 1D, return a 1D vector for consistency.
  IF y_was_1d THEN RETURN, REFORM(NewY) ELSE RETURN, NewY
END