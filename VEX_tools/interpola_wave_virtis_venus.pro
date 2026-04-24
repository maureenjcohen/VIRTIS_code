pro interpola_wave_virtis_venus

    nrighe=5266			;numero di righe

    var=dblarr(2,nrighe-1)
    a=strarr(1)
    filename='C:\pro\routines\cell3.txt'
    OPENR, unit, filename, /GET_LUN
    readf,unit,a
    readf,unit,var
    free_lun,unit
    wave=reform(var(0,*))
    radiance=reform(var(1,*))

readcol,'C:\pro\routines\venus_VIRTIS_M_ITF_VIS.txt',lambda,itf, skipline=1

linterp,wave,radiance,lambda,radiance_interp

    var=[[lambda],[radiance_interp]]
    var=transpose(var,[1,0])
    filename='C:\pro\routines\cell3_interp_vis.txt'
    OPENW, unit, filename, /GET_LUN
    printf,unit,a+' !!! interpolated on the VIRTIS wavelengths !!!'
    printf,unit,var
    free_lun,unit

readcol,'C:\pro\routines\venus_VIRTIS_M_ITF_IR.txt',lambda,itf, skipline=1

linterp,wave,radiance,lambda,radiance_interp

    var=[[lambda],[radiance_interp]]
    var=transpose(var,[1,0])
    filename='C:\pro\routines\cell3_interp_ir.txt'
    OPENW, unit, filename, /GET_LUN
    printf,unit,a+' !!! interpolated on the VIRTIS wavelengths !!!'
    printf,unit,var
    free_lun,unit

end
