function V_TYPEPDS, chaine, Nbyte, ITYPE = itype, Stype = Stype

;+ $Id: v_typepds.pro,v 1.6 2007/02/20 16:15:34 flo Exp $
;
; NAME:
;          V_TYPEPDS
;
; PURPOSE:
;     Identify the IDL variable type best adapted to accommodate a PDS type
;     Further processing required is described through keywords
;
; CALLING SEQUENCE:
;      Result=V_TYPEPDS (String, Nbyte)
;
; INPUTS:
;      Chaine = Scalar string, a PDS term defining a variable type.
;	(value of a keyword similar to CORE_ITEM_TYPE)
;      Nbyte = scalar, number of BYTES to code the variable
;           (value of a keyword similar to CORE_ITEM_BYTE). Beware
;           that this parameter is given in BITS for image objects
;
; OUTPUTS:
;      Result = IDL variable type (from version 6.1). 
;          Include long / long64 + signed /unsigned integer types
;
; OPTIONAL OUTPUT KEYWORDS:
;      STYPE - returns the "sample type" in a string, more or less the 
;          root of the PDS variable type: 
;          MSB: standard byte-order integer (Sun, Mac, HP)
;          LSB: byte-swapped integer (Alpha, Intel, Vax)
;          IEEE: standard floating point number, assumed MSB
;          PC: swapped (LSB) IEEE floating point number
;          VAX:  VAX format floating point (only F/D types are supported by IDL)
;          This value is used to trigger further processing (byte swapping, 
;          Vax floats conversion...)
;      ITYPE - returns additional type description in a string:
;          SIGNED or UNSIGNED for integers
;          REAL or COMPLEX for floats
;
; RESTRICTIONS:    
;     Supports all PDS formats except:
;       10 bytes float defined in PDS (returns 0)
;       VAX formats G (described as VAX D) and H (returns 0) 
;       Bitstrings
;     Defaults to IEEE REAL (MSB).
;
; PRECAUTIONS:    
;     A signed byte type exists in PDS, not in IDL (to be translated in short 
;      integers in v_imagepds and other routines)
;     Usual unsigned bytes should be introduced as MSB_UNSIGNED_INTEGER in the labels
;
; MODIFICATION HISTORY:
;     Adapted by Stephane Erard, IAS, from IMAGEPDS by John D. Koch 
;       (from version in SBNIDL 2.0, last modif 27 July 1999 by M. Barker)
;     Completely revised and udapted, SE, LESIA, June 2005.
;          Now supports usual PDS formats + uses all IDL variable types
;
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

  On_error,2                    ;Return to user            

      ; Look for integers (always specified in type string)

Ntype = strupcase(chaine)

IF (strpos(Ntype,'INTEGER') GT -1) THEN BEGIN     ; integers

      ; Look for endianness 

     Stype = 'MSB'
     if (strpos(Ntype,'LSB') GT -1) or (strpos(Ntype,'PC') GT -1) or $
          (strpos(Ntype,'VAX') GT -1) then Stype = 'LSB'

      ; Look for 'SIGNED' vs 'UNSIGNED' integers

     itype = 'SIGNED'     ; default
     if (strpos(Ntype,'UNSIGNED') GT -1) then Itype = 'UNSIGNED'

ENDIF ELSE BEGIN

     Stype = 'IEEE'
     itype = 'REAL'

      ; Look for alternatives

     if (strpos(Ntype,'PC') GT -1) then Stype = 'PC'
     if (strpos(Ntype,'VAX') GT -1) then Stype = 'VAX'

     IF (strpos(Ntype,'COMPLEX') GT -1) then itype ='COMPLEX'     ; complexes

ENDELSE 


     CASE Nbyte OF 
        1: IDL_type = 1
        2: IDL_type = 2
        4: if Stype EQ 'MSB'  OR Stype EQ 'LSB' $ 
               then  IDL_type = 3 else IDL_type = 4
        8: if Stype EQ 'MSB'  OR Stype EQ 'LSB' $ 
               then  IDL_type = 14 else IDL_type = 5 
        16: IDL_type = 9
         else: IDL_TYPE = 0
     ENDCASE 

     if !version.release GE 5.2 then begin
        If IDL_Type EQ 2 and Itype EQ 'UNSIGNED' then IDL_Type = 12
        If IDL_Type EQ 3 and Itype EQ 'UNSIGNED' then IDL_Type = 13
        If IDL_Type EQ 14 and Itype EQ 'UNSIGNED' then IDL_Type = 15
     endif
     If Nbyte EQ 8 and Itype EQ 'COMPLEX' then IDL_Type = 6
     If Nbyte EQ 16 and Itype EQ 'REAL' then IDL_Type = 0  ; unsupported Vax H format

     return, IDL_TYPE

 end 
