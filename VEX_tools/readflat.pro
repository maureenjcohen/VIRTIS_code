pro readflat

    ;CARICAMENTO FILE ITF IR CON FLAT FIELD
    ITF3_IR_MATRIX=DBLARR(432,256)
    OPENR, LUN, 'c:\programmi\rsi\IDL60\products\envi40\save_add\calibration_files_rosetta\rosetta_virtis_m_IR_ITF3_FLAT.DAT', /GET_LUN
    READU, LUN, ITF3_IR_MATRIX
    FREE_LUN, LUN

end