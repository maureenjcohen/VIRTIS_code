pro  v_vaxtoieee, variable, SWAP_INT = swap_int

;+ $Id: v_vaxtoieee.pro,v 1.3 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;      V_VAXTOIEEE
;
; PURPOSE:
;      Converts VAX floats data to IEEE (MSB)
;      Optionally convert VAX integers (LSB) to machine architecture
;
; EXPLANATION:
;      Generally used on non-Vax machines to parse data created on Vaxes.
;      Relies on IDL variable type (should match VAX data type).
;
; CALLING SEQUENCE:
;      v_vaxtoieee, var_vax
;
; INPUT PARAMETER:
;      var_vax - The data variable to be converted.  This may be a scalar
;            or an array (structures are handled recursively).  
;            All VAX datatypes are handled, except G and H floats.
;            The IDL type of var_vax must reflect the VAX type.
;
; OPTIONAL INPUT KEYWORD:  
;      SWAP_INT - Force integer conversion from LSB (VAX) to machine architecture 
;      (with no swap performed if machine is LSB). Default is not to process integers.
;
; EXAMPLE:
;      Read a 100 by 100 matrix of floating point numbers from a data
;      file created on a VAX. Then convert the matrix values into IEEE format:
;
;      IDL> openr,1,'vax_float.dat'
;      IDL> data = fltarr(100,100)
;      IDL> readu,1,data
;      IDL> v_vaxtoieee, data
;
;       Check data type from PDS label and possibly convert to IEEE:
;
;       Core_type = v_typepds(Stype,bits,ITYPE = int_type, Stype = sample_type)
;       if sample_type EQ 'VAX' then v_vaxtoIEEE, core
;
; NOTE:
;       Prior to IDL V5.1, the architecture "alpha" was ambiguous, since VMS 
;       alpha IDL used VAX D-float while OSF/1 alpha IDL uses little-endian 
;       IEEE.   
;
; MODIFICATION HISTORY:
;       Written   Stephane Erard, LESIA, June 2005
;          (adapted from a previous function v_conv_vax_unix)
;-                                   
;
;###########################################################################
;
; LICENSE
;
;  Copyright (c) 1999-2008, Stéphane Erard, CNRS - Observatoire de Paris
;  All rights reserved.
;  Non-profit redistribution and non-profit use in source and binary forms, 
;  with or without modification, are permitted provided that the following 
;  conditions are met:
; 
;        Redistributions of source code must retain the above copyright
;        notice, this list of conditions, the following disclaimer, and
;        all the modifications history.
;        Redistributions in binary form must reproduce the above copyright
;        notice, this list of conditions, the following disclaimer and all the
;        modifications history in the documentation and/or other materials 
;        provided with the distribution.
;        Neither the name of the CNRS and Observatoire de Paris nor the
;        names of its contributors may be used to endorse or promote products
;        derived from this software without specific prior written permission.
; 
; THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
;*************************************************************
;
;  Check to see if VARIABLE is defined.

 if N_params() LT 1 then $
      message,'Syntax - V_vaxToIEEE, variable

 svar = size( variable )
 var_type = svar[svar[0]+1]
 

 CASE var_type OF

  1:                                                    ; byte (no processing)

  2: if keyword_set( SWAP_INT ) then V_swapData, variable, /LSB   ; integer

  3: if keyword_set( SWAP_INT ) then V_swapData, variable, /LSB    ; longword

  4: byteorder,variable,/VAXtoF                       ; floating point

  5: byteorder,variable,/VAXtoD                       ; double precision
 
  6: BEGIN                                                      ; complex
     temp1 = float( variable )
     temp2 = imaginary( variable )
     v_vaxtoIEEE, temp1
     v_vaxtoIEEE, temp2
     variable = complex( temp1, temp2 )
     END

  7:                                  ; string (no processing)

  8: BEGIN                        ; structure
      var_out = variable
      Ntag = N_tags( variable )
      for t=0,Ntag-1 do  begin
    	    temp = var_out.(t)
    	    v_vaxtoIEEE, temp
    	    var_out.(t) = temp
    endfor
       variable = var_out
       END

  9: BEGIN                                                      ; double complex
     temp1 = double( variable )
     temp2 = imaginary( variable )
     v_vaxtoIEEE, temp1
     v_vaxtoIEEE, temp2
     variable = dcomplex( temp1, temp2 )
     END
     
  12: if keyword_set( SWAP_INT ) then V_swapData, variable, /LSB   ; unsigned integer

  13: if keyword_set( SWAP_INT ) then V_swapData, variable, /LSB   ; unsigned longword

 else: message,'*** Data type ' + strtrim(var_type,2) + ' unknown', /CONT

  ENDCASE

end

