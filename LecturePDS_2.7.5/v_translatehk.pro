function v_translatehk, $
	id, $
	value, $
	mission, $
	instrument
	
;+ $Id: v_translatehk.pro,v 1.5 2007/05/01 06:32:15 flo Exp $
;
; NAME:
;   v_translatehk
;
; PURPOSE:
;   Translates housekeeping values from byte (as read in the suffix) to physical units
;
; CALLING SEQUENCE:
;   translated_value = v_translatehk(id, value, mission, instrument)
;
; INPUT PARAMETER:
;   id = index of the hk value in the suffix table
;   value = value read in the suffix table
;   mission = mission name : "ROSETTA" or "VENUSEXPRESS"
;   instrument = instrument name : "Virtis-H" or "Virtis-M"
;
; PROCEDURES USED:
;   v_transfunchk
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


	valid = where(value ne 'FFFF'X)
	invalid = where(value eq 'FFFF'X)
	if (valid[0] eq -1) then return, value
	
	res_value = replicate(float('FFFF'X), n_elements(value))
	num_valid = n_elements(valid)

	mission_tab = ["ROSETTA", "VENUSEXPRESS"]
	mission_num = where(mission_tab eq mission)

	instrument_tab = ["Virtis-H", "Virtis-M"]
	instrument_num = where(instrument_tab eq instrument)

	num = id
	if (id gt 17) then $ 
		num += 100*(instrument_num+1)

	;;; Valeus de fonctions de transfert : Rosetta en 0 et Vex en 1
	HKRQ_BIAS = 			[[0, 1.443e-02, 0],				[0, 0.0146, -0.001]]
	HKRQ_I_LAMP = 			[[0, 9.062e-02, 0],				[0, 0.09046, 0.005]]
	HKRQ_I_SHUTTER = 		[[0, 5.031e-01, 0],				[0, 5.031e-1, 0]]
	HKMS_V_LINE_REF =		[[0, 3.09045e-4, 5.3e-2],		[0, 3.09025e-4, 0.0025]]
	HKMS_VDET_DIG = 		[[0, 3.783e-4, -1.113], 		[0, 3.795e-4, -1.1134]]
	HKMS_VDET_ANA = 		[[0, 1.079e-2, -169.2], 		[0, 1.321e-2, -208.39]]
	hKMS_V_DETCOM =		[[0, 5.000e-4, -1.97], 			[0, 1.0e-3, -7.146]]
	HKMS_V_DETADJ = 		[[0, 3.091e-4, 3.5e-3], 		[0, 3.093e-4, 5.0e-3]]
	HKMS_VPLUS5 = 			[[0, 3.117e-4, 8.5e-3], 		[0, 3.11e-4, 3e-2]]
	HKMS_VPLUS12 = 		[[0, 7.83e-4, 0.116], 			[0, 7.8375e-4, 0.111]]
	HKMS_VPLUS21 = 		[[0, 1.248e-3, 0.083], 			[0, 1.2512e-3, 1.5e-2]] 
		;;; erreur dans VIR-GAL-IC-048 1.248e-4 au lieu de 1.248e-3, mais OK dans l'EGSE
	HKMS_VMOINS12 = 		[[0, 7.82e-4, 5e-3], 			[0, 7.82e-4 , 1e-3]]
	HKMS_TEMP_VREF = 		[[0, 7.8e-4, 0.015], 			[0, 7.829e-4, 0.106]]
	HKMS_DET_TEMP =		[[-1.79e-6, 7.9e-3, 291.4],	[0, -0.03495, 546]]
	HKMS_I_VDET_ANA = 	[[0, 6.65e-3, 0.02], 			[0, 6.64e-3, 0.088]]
	HKMS_I_VDET_DIG = 	[[0, 3.100e-3, 0.037], 			[0, 3.11e-3, 0.022]]
	HKMS_I_PLUS5 = 		[[0, 3.130e-1, 7], 				[0, 0.307, 3.4]]
	HKMS_I_PLUS12 = 		[[0, 1.568e-1, -6.53], 			[0, 0.1554, -1.95]]
	HKMS_I_LAMP = 			[[0, 3.31e-2, -1.30e-1],		[0, 0.03292, -1.73]]
	HKMS_I_SHUTTER_HEATER =[[0, 0.149, -1.94e+1],		[0, 0.1489, -6.4]]
	HKMS_TEMP_PRISM = 	[[1.97e-7, 0.0244, 49.8],		[1.97e-7, 0.0244, 49.3]]
	HKMS_TEMP_CAL_S = 	[[1.96e-7, 0.0245, 47.6],		[2e-7, 0.0243, 49.3]]
	HKMS_TEMP_CAL_T = 	[[1.98e-7, 0.0244, 49.6],	 	[2e-7, 0.0243, 49.1]]
	HKMS_TEMP_SHUT = 		[[1.95e-7, 0.0238,  7.3], 		[2e-7, 0.0237, 6.6]]
	HKMS_TEMP_GRATING =	[[1.96e-7, 0.0244, 49], 		[2e-7, 0.0243, 48.3]]
	HKMS_TEMP_OBJECTIVE =[[2e-7, 0.0244, 50], 			[2e-7, 0.0243, 49.2]]
	HKMS_TEMP_FPA = 		[[2e-7, 0.0244, 49.4], 			[2e-7, 0.0244, 48.6]]
	HKMS_TEMP_PEM = 		[[-2.44e-6, 0.0783, -496.6],	[3.364e-6, -2.95260e-02, 0]]

	ME_PS_TEMP = 			[[0, 0.244, 0], 					[0, 0.244, 0]]
	ME_DPU_TEMP = 			[[0, 0.244, 0], 					[0, 0.244, 0]]
	ME_DHSU_VOLT = 		[[0, 0.002442, 0], 				[0, 0.002442, 0]]
	ME_DHSU_CURR = 		[[0, 0.9768, 0], 					[0, 0.002442, 0]]
	IFE_ELECTR_VOLT = 	[[0, 0.002442, 0], 				[0, 0.002442, 0]]
	EEPROM_VOLT = 			[[0, 0.002442, 0], 				[0, 0.002442, 0]]

	M_COOL_TIP_TEMP = 	[[0, 9.768e-3, 60], 				[0, 9.768e-3, 60]]
	M_COOL_MOT_VOLT = 	[[0, 0.004884, 0], 				[0, 0.004884, 0]]
	M_COOL_MOT_CURR = 	[[0, 0.0004884, 0], 				[0, 0.0004884, 0]]
	M_CCE_SEC_VOLT = 		[[0, 0.004884 , 0], 				[0, 0.004884 , 0]]

	H_COOL_TIP_TEMP = 	[[0, 9.768e-3, 60], 				[0, 9.768e-3, 60]]
	H_COOL_MOT_VOLT = 	[[0, 0.004884, 0], 				[0, 0.004884, 0]]
	H_COOL_MOT_CURR = 	[[0, 0.0004884, 0], 				[0, 0.0004884, 0]]
	H_CCE_SEC_VOLT = 		[[0, 0.004884, 0], 				[0, 0.004884, 0]]

	M_CCD_VDR_HK = 		[[0, 7.554E-04, -2.475E+01], 	[0, 7.554E-04, -2.475E+01]]
	M_CCD_VDD_HK = 		[[0, 1.221E-03, -4.0E+01], 	[0, 1.231E-03, -4.032E+01]]
	M_PLUS5_VOLT = 		[[0, 3.061E-04, -1.003E+01], 	[0, 3.080E-04, - 1.009E+01]]
	M_PLUS12_VOLT = 		[[0, 6.1528E-04, -2.0162E+01],[0, 6.165E-04, - 2.020E+01]]
	M_MOINS12_VOLT = 		[[0, 6.1405E-04, -2.0121E+01],[0, 6.178E-04, - 2.024E+01]]
	M_PLUS20_VOLT = 		[[0, 1.2207E-03, -4.0001E+01],[0, 1.231E-03, - 4.032E+01]]
	M_PLUS21_VOLT = 		[[0, 1.2207E-03, -4.0001E+01],[0, 1.226E-03, - 4.016E+01]]
	M_CCD_LAMP_VOLT = 	[[0, 7.6486E-04, -2.5063E+01],[0, 7.668E-04, - 2.513E+01]]
	M_CCD_TEMP_OFFSET = 	[[0, 1.5274E-04, -5.0051], 	[0, 1.527E-04, - 5.005]]
	M_CCD_TEMP = 			[[0, 3.0549E-02, -1.001E+03], [0, 3.052E-02, - 1.000E+03]]
	M_CCD_TEMP_RES = 		[[0, 1.5313E-06, -5.0176E-02],[0, 1.527E-06, - 5.005E-02]]
	M_RADIATOR_TEMP =		[[0, 3.0549E-02, -1.001E+03], [0, 3.052E-02, - 1.000E+03]]
	M_LEDGE_TEMP = 		[[0, 3.0549E-02, -1.001E+03 ],[0, 3.052E-02, - 1.000E+03]]
	OM_BASE_TEMP = 		[[0, 3.0549E-02, -1.001E+03], [0, 3.052E-02, - 1.000E+03]]
	H_COOLER_TEMP = 		[[0, 3.0549E-02, -1.001E+03], [0, 3.052E-02, - 1.000E+03]]
	M_COOLER_TEMP = 		[[0, 3.0549E-02, -1.001E+03], [0, 3.052E-02, - 1.000E+03]]
	M_CCD_DELAY = 			[[0, 1.0E-01 , 0], 				[0, 2.0E-02, 0]]
	M_CCD_EXPO = 			[[0, 1.0E-01 , 0], 				[0, 2.0E-02, 0]]

	M_IR_VDETCOM_HK = 	[[0, 3.061E-04, -1.0028E+01],	[0, 3.052E-04, - 9.994]]
	M_IR_VDETADJ_HK = 	[[0, 3.061E-04, -1.0028E+01], [0, 3.061E-04, - 1.003E+01]]
	M_IR_VPOS = 			[[0, 3.0579E-04, -1.0018E+01],[0, 3.058E-04, - 1.002E+01]]
	M_IR_VDP = 				[[0, 3.061E-04, -1.0028E+01], [0, 3.058E-04, - 1.002E+01]]
	M_IR_TEMP_OFFSET = 	[[0, 1.5305E-04, -5.0151], 	[0, 1.527E-04, - 5.005E+00]]
	M_IR_TEMP = 			[[0, 6.1405E-05, -2.0121], 	[0, 6.128E-05, - 2.008E+00]]
	M_IR_TEMP_RES = 		[[0, 7.6525E-07, -2.5076E-02],[0, 7.645E-07, - 2.505E-02]]
	M_SHUTTER_TEMP = 		[[0, 3.0579E-02, -1.002E+03], [0, 3.055E-02, - 1.001E+03]]
	M_GRATING_TEMP = 		[[0, 3.0579E-02, -1.002E+03], [0, 3.055E-02, - 1.001E+03]]
	M_SPECT_TEMP = 		[[0, 3.0579E-02, -1.002E+03], [0, 3.055E-02, - 1.001E+03]]
	M_TELE_TEMP = 			[[0, 3.0579E-02, -1.002E+03], [0, 3.055E-02, - 1.001E+03]]
	M_SU_MOTOR_TEMP = 	[[0, 3.0579E-02, -1.002E+03], [0, 3.055E-02, - 1.001E+03]]
	M_IR_LAMP_VOLT = 		[[0, 7.6679E-04, -2.5126E+01],[0, 7.649E-04, - 2.506E+01]]
	M_SU_MOTOR_CURR = 	[[0, 1.5305E-06, -5.0151E-02],[0, 6.113E-06, - 2.003E-01]]
	M_IR_DELAY = 			[[0, 1.0E-01 , 0], 				[0, 2.0E-02, 0]]
	M_IR_EXPO = 			[[0, 1.0E-01 , 0], 				[0, 2.0E-02, 0]]
	
	M_MIRROR_SIN_HK = 	[[0, 2.442E-04 , 0], 				[0, 2.442E-04, 0]]
	M_MIRROR_COS_HK = 	[[0, 2.442E-04 , 0], 				[0, 2.442E-04, 0]]

	M_IR_LAMP_SHUTTER_1 =	[[0, 0 , 9.4E+01], 				[0, 0 , 9.4E+01]]
	M_IR_LAMP_SHUTTER_2 =	[[0, 0 , 4.1E+01], 				[0, 0 , 4.5E+01]]

	num_res = 1
	case num of		
		3 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0]	)
		end
		4 : begin
			num_res = 2
			bits = [[7,8], [15,8]]
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits[0,*]-1)) AND 2^bits[1,*]-1
		end
		5 : begin
			num_res = 6
			bits = [[0,1], [1,1], [2,1], [5,3], [7,2], [15,8]]
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits[0,*]-1)) AND 2^bits[1,*]-1
		end
		10 : begin
			num_res = 3
			bits = [[3,4], [9,6], [15,6]]
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits[0,*]-1)) AND 2^bits[1,*]-1
		end
		11 : begin
			num_res = 7
			bits = [15,14,13,12,11,10,0]
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		12 : begin
			  res_value[valid] = v_transfunchk(value[valid], ME_PS_TEMP[*,mission_num])
		end
		13 : begin
			  res_value[valid] = v_transfunchk(value[valid], ME_DPU_TEMP[*,mission_num])
		end
		14 : begin
			  res_value[valid] = v_transfunchk(value[valid], ME_DHSU_VOLT[*,mission_num])
		end
		15 : begin
			  res_value[valid] = v_transfunchk(value[valid], ME_DHSU_CURR[*,mission_num])
		end
		16 : begin
			  res_value[valid] = v_transfunchk(value[valid], EEPROM_VOLT[*,mission_num])
		end
		17 : begin
			  res_value[valid] = v_transfunchk(value[valid], IFE_ELECTR_VOLT[*,mission_num])
		end
		122 : begin
			bits = [15,7]
			num_res = 2
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		123 : begin
			bits = [15,11,7]
			num_res = 3
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		124 : begin
			  res_value[valid] = v_transfunchk(value[valid], H_COOL_TIP_TEMP[*,mission_num])
		end
		125 : begin
			  res_value[valid] = v_transfunchk(value[valid], H_COOL_MOT_VOLT[*,mission_num])
		end
		126 : begin
			  res_value[valid] = v_transfunchk(value[valid], H_COOL_MOT_CURR[*,mission_num])
		end
		127 : begin
			  res_value[valid] = v_transfunchk(value[valid], H_CCE_SEC_VOLT[*,mission_num])
		end
		134 : begin
			res_value[valid] = v_transfunchk(value[valid], HKRQ_BIAS[*,mission_num])
		end
		135 : begin
			res_value[valid] = v_transfunchk(value[valid], HKRQ_I_LAMP[*,mission_num])
		end
		136 : begin
			res_value[valid] = v_transfunchk(value[valid], HKRQ_I_SHUTTER[*,mission_num])
		end
		137 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0]	)
		end
		138 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0]	)
		end
		139 : begin
		   bits = [15,14,13,12,11,10,9,8,7]
			num_res = 9
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		140 : begin
		   bits = [[15,1], [14,1], [13,1], [12,7]]
			num_res = 4
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits[0,*]-1)) AND 2^bits[1,*]-1
		end
		141 : begin
			bits = [15,14,13,12,11,10]
			num_res = 6
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		142 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_V_LINE_REF[*,mission_num],/signed)
		end
		143 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_VDET_DIG[*,mission_num],/signed)
		end
		144 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_VDET_ANA[*,mission_num],/signed)
		end
		145 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_V_DETCOM[*,mission_num],/signed)
		end
		146 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_V_DETADJ[*,mission_num])
		end
		147 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_VPLUS5[*,mission_num], /signed)
		end
		148 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_VPLUS12[*,mission_num], /signed)
		end
		149 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_VPLUS21[*,mission_num],/signed)
		end
		150 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_VMOINS12[*,mission_num], /signed)
		end
		151 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_VREF[*,mission_num], /signed)
		end
		152 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_DET_TEMP[*,mission_num], /signed)
		end
		153 : begin
			 res_value[valid] = v_transfunchk(value[valid], [0, 1, 0], /signed)
		end
		154 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_I_VDET_ANA[*,mission_num], /signed)
		end
		155 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_I_VDET_DIG[*,mission_num], /signed)
		end
		156 : begin
			 res_value[valid] = v_transfunchk(value[valid], HKMS_I_PLUS5[*,mission_num], /signed)
		end
		157 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_I_PLUS12[*,mission_num], /signed)
		end
		158 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_I_LAMP[*,mission_num], /signed)
		end
		159 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_I_SHUTTER_HEATER[*,mission_num], /signed)
		end
		160 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_PRISM[*,mission_num], /signed)
		end
		161 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_CAL_S[*,mission_num], /signed)
		end
		162 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_CAL_T[*,mission_num], /signed)
		end
		163 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_SHUT[*,mission_num], /signed)
		end
		164 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_GRATING[*,mission_num], /signed)
		end
		165 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_OBJECTIVE[*,mission_num], /signed)
		end
		166 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_FPA[*,mission_num], /signed)
		end
		167 : begin
			  res_value[valid] = v_transfunchk(value[valid], HKMS_TEMP_PEM[*,mission_num])
		end
		; "M_SCIENCE_TM_PACKET_COUNTER" : begin
		; 	  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		; end
		168 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		169 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		222 : begin
			bits = [15,7]
			num_res = 2
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		223 : begin
			bits = [15,11,7]
			num_res = 3
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		224 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_COOL_TIP_TEMP[*,mission_num])
		end
		225 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_COOL_MOT_VOLT[*,mission_num])
		end
		226 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_COOL_MOT_CURR[*,mission_num])
		end
		227 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCE_SEC_VOLT[*,mission_num])
		end
		; "H_SCIENCE_TM_PACKET_COUNTER" : begin
		; 	  res_value[valid] = v_transfunchk(value[valid], [0, 1, O])
		; end
		232 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_VDR_HK[*,mission_num])
		end
		233 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_VDD_HK[*,mission_num])
		end
		234 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_PLUS5_VOLT[*,mission_num])
		end
		235 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_PLUS12_VOLT[*,mission_num])
		end
		236 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_MOINS12_VOLT[*,mission_num])
		end
		237 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_PLUS20_VOLT[*,mission_num])
		end
		238 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_PLUS21_VOLT[*,mission_num])
		end
		239 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_LAMP_VOLT[*,mission_num])
		end
		240 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_TEMP_OFFSET[*,mission_num])
		end
		241 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		242 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_TEMP_RES[*,mission_num])
		end
		243 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_RADIATOR_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		244 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_LEDGE_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		245 : begin
			  res_value[valid] = v_transfunchk(value[valid], OM_BASE_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		246 : begin
			  res_value[valid] = v_transfunchk(value[valid], H_COOLER_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		247 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_COOLER_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		248 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		249 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		250 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		251 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		252 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_DELAY[*,mission_num])
		end
		253 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_CCD_EXPO[*,mission_num])
		end
		254 : begin
			bits = [[15,12], [3,1]]
			HK_bit = fix(value[valid] / 2^(16-bits[0,0]-1)) AND 2^bits[1,0]-1
			HK_sign = fix(value[valid] / 2^(16-bits[0,1]-1)) AND 1
			res_value[valid] = v_transfunchk(HK_bit * HK_sign, M_MIRROR_SIN_HK[*,mission_num])
		end
		255 : begin
			bits = [[15,12]]
			HK_bit = fix(value[valid] / 2^(16-bits[0,0]-1)) AND 2^bits[1,0]-1
			res_value[valid] = v_transfunchk(HK_bit, M_MIRROR_COS_HK[*,mission_num])
		end
		256 : begin
			bits = [15,14,13,12,11,7]
			num_res = 6
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		261 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_VDETCOM_HK[*,mission_num])
		end
		262 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_VDETADJ_HK[*,mission_num])
		end
		263 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_VPOS[*,mission_num])
		end
		264 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_VDP[*,mission_num])
		end
		265 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_TEMP_OFFSET[*,mission_num])
		end
		266 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_TEMP[*,mission_num], /conv_VoltToKelvin)
		end
		267 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_TEMP_RES[*,mission_num])
		end
		268 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_SHUTTER_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		269 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_GRATING_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		270 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_SPECT_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		271 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_TELE_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		272 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_SU_MOTOR_TEMP[*,mission_num], /conv_OhmToKelvin)
		end
		273 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_LAMP_VOLT[*,mission_num])
		end
		274 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_SU_MOTOR_CURR[*,mission_num])
		end
		275 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		276 : begin
			  res_value[valid] = v_transfunchk(value[valid], [0, 1, 0])
		end
		277 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_DELAY[*,mission_num])
		end
		278 : begin
			  res_value[valid] = v_transfunchk(value[valid], M_IR_EXPO[*,mission_num])
		end
		279 : begin
			bits = [[15,4], [11,1], [7,4], [3,1]]
			num_res = 4
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits[0,*]-1)) AND 2^bits[1,*]-1
			res_value[*, valid] = [v_transfunchk(res_value[0, valid], M_IR_LAMP_SHUTTER_1[*,mission_num]), $
					res_value[1, valid], $
					v_transfunchk(res_value[2, valid], M_IR_LAMP_SHUTTER_2[*,mission_num]), $
					res_value[3, valid]]
		end
		280 : begin
			bits = [15,14,13,12,11,10,9,6,3,2,1]
			num_res = 11
			res_value = fltarr(num_res, n_elements(value)) + 'FFFF'X
			for i = 0L, num_valid-1 do $
				res_value[*, valid[i]] = fix(value[valid[i]] / 2^(16-bits-1)) AND 1
		end
		else : 
	endcase
	res_value = reform(res_value, [num_res, size(value, /dim)])
	;;; help, res_value
	;;; stop

	;;; if (invalid[0] ne -1) then res_value[*, invalid] = 'FFFF'X

return, res_value

end
