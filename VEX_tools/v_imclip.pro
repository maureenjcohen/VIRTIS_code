;+
; NAME:
;     v_imclip
;
; PURPOSE:
;     Obtain histogram clipping values for a given image using a certain percent value
;
; CALLING SEQUENCE:
;     IMCLIP, IMAGE, PERCENT=percent
;
; INPUTS:
;      Image : input image (2D array)
;
; OUTPUTS:
;     [min, max] : 2 element Array with the minimum and maximum clipping values
;
; KEYWORDS:
;     PERCENT : percent value used for the histogram clipping (by default, 2% is used)
;
; EXAMPLE:
;          IDL> range = imclip(image)
;          IDL> tv, bytscl(image, min=range[0], max=range[1]) 
;
; REQUIRED FILES:
;     none
;
; COMMENTS / RESTRICTIONS:
;     Routine taken from Liam Gumley's book: http://www.gumley.com/
;     More info: http://groups.google.com/group/comp.lang.idl-pvwave/search?q=imclip
;
; MODIFICATION HISTORY:
;     Written by Liam Gumley: IMCLIP.PRO (http://www.gumley.com/)
;     Commented by A. Cardesin, IASF-INAF, June 2008, Alejandro.Cardesin @ iasf-roma.inaf.it
;
;-

FUNCTION V_IMCLIP, IMAGE, PERCENT=PERCENT

;- Check arguments
if (n_params() ne 1) then $
   message, 'Usage: RESULT = IMCLIP(IMAGE)'
if (n_elements(image) eq 0) then $
   message, 'Argument IMAGE is undefined'

;- Check keywords
if (n_elements(percent) eq 0) then percent = 2.0

;- Get image minimum and maximum
min_value = min(image, max=max_value)

;- Compute histogram
nbins = 100.
binsize = float(float(max_value) - float(min_value)) / float(nbins)
hist = histogram(float(image), binsize=binsize)
bins = lindgen(nbins + 1) * binsize + min_value

;- Compute normalized cumulative sum
sum = fltarr(n_elements(hist))
sum[0] = hist[0]
for i = 1L, n_elements(hist) - 1L do $
   sum[i] = sum[i - 1] + hist[i]
sum = 100.0 * (sum / float(n_elements(image)))

;- Find and return the range
range = [min_value, max_value]
index = where((sum ge percent) and $
   (sum le (100.0 - percent)), count)
if (count ge 2) then $
   range = [bins[index[0]], bins[index[count - 1]]]
return, range

END