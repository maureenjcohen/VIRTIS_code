;+
; NAME:
;   v_orbit2mtp
;
; PURPOSE:
;   Returns the corresponding MTP number for a given orbit number
;
; INPUT:
;   input_orbit: variable containing orbit number (can also be an array)
;
; OUTPUT:
;   MTP number either as a number or as a string (optional)
;     returns -1 or string "VOCP"   if orbit number is between 0 and 16
;     returns -2 or string "VOI"    if orbit number is 0
;     returns -3 or string "CRUISE" if orbit number is 9999
;     error if orbit number is greater than 9999
;
; OPTIONAL KEYWORDS:
;   STR        : Set to return MTP as a string, e.g. "MTP001", "MTP026" or "VOI", "VOCP", "CRUISE"
;   NO_WARNING : Set to avoid warning messages for non MTP orbits (VOI, VOCP, etc)
;
; EXAMPLE:
;   print, v_orbit2mtp(126)
;   print, v_orbit2mtp([0, 5, 43, 144, 999, 9999],/STR)
;
;   *See also example procedure at the end of this routine "v_orbit2mtp_EXAMPLE"
;
; MODIFICATION HISTORY:
;   Written by Alejandro Cardesin, IASF-INAF, April 2008, alejandro.cardesin @ iasf-roma.inaf.it
;   Modified July  2008, AC : Added VOI, VOCP, CRUISE and comments. Added v_orbit2mtp_EXAMPLE
;   Modified Sept  2008, AC : Modified handling of invalid orbits
;
;-
FUNCTION v_orbit2mtp, input_orbit, STR=str, NO_WARNING=no_warning

   orbit_num = input_orbit ;do not modify original variable (just in case)

 ;----------------------------------------------------------------------------
 ; CONVERT ORBIT TO MTP
 ;----------------------------------------------------------------------------

  MTP = (orbit_num-16)/28 + 1


 ;----------------------------------------------------------------------------
 ; Check for orbits that do not correspond to any MTP, i.e. CRUISE, VOI, VOCP
 ;----------------------------------------------------------------------------

 i_VOI     = where(orbit_num eq  0   AND strtrim(orbit_num,2) ne "" )
 i_VOCP    = where(orbit_num gt  0   AND orbit_num lt 16 )
 i_CRUISE  = where(orbit_num eq 9999                     )
 i_invalid = where(orbit_num gt 9999 OR orbit_num lt  0 OR $
                   strtrim(orbit_num,2) eq ""   OR stregex(strtrim(orbit_num,2),"[^0-9]",/extract) ne "")

 if i_VOI    [0] NE -1 then MTP[i_VOI    ] = -1
 if i_VOCP   [0] NE -1 then MTP[i_VOCP   ] = -2
 if i_CRUISE [0] NE -1 then MTP[i_CRUISE ] = -3
 if i_invalid[0] NE -1 then MTP[i_invalid] = -4

 ; Notify Warnings
 if ~keyword_set(no_warning) AND ( i_VOI[0] NE -1 || i_VOCP[0] NE -1 || i_CRUISE[0] NE -1) then $
    print, "### WARNING ### Orbit does not have a valid MTP, either CRUISE, VOI or VOCP.

 ; Notify Errors
 if i_invalid[0] NE -1 then $
 	print, "### ERROR ### Cannot recognise orbit number: "+strtrim(orbit_num[i_invalid],2)

 ;----------------------------------------------------------------------------
 ; CONVERT TO STRING (optional)
 ;----------------------------------------------------------------------------

 if keyword_set(str) then begin

 	MTP="MTP"+string(MTP,F='(I03)')

 	if i_VOI    [0] NE -1 then MTP[i_VOI    ] = "VOI"
 	if i_VOCP   [0] NE -1 then MTP[i_VOCP   ] = "VOCP"
 	if i_CRUISE [0] NE -1 then MTP[i_CRUISE ] = "CRUISE"
	if i_invalid[0] NE -1 then MTP[i_invalid] = ""

 endif

 return, MTP

END

;============================================================================
; EXAMPLE PROCEDURE TO PRINT ALL ORBITS AND MTP NUMBERS
;============================================================================

PRO v_orbit2mtp_EXAMPLE

	;----------------------------------------------------------------------------
	; PRINT ALL ORBITS WITH MTP
	;----------------------------------------------------------------------------
	for orbit=0,1000 do print, "Orbit "+string(orbit, F="(I04)")+"	->	"+v_orbit2mtp(orbit, /STR, /NO_WARNING)

	;----------------------------------------------------------------------------
 	; PRINT FIRST ORBIT OF EACH MTP
 	;----------------------------------------------------------------------------
 	orbit = ((indgen(100))*28)+16
 	print, transpose("Orbit "+string(orbit, F="(I04)")+"	->	"+v_orbit2mtp(orbit, /STR, /NO_WARNING))

END