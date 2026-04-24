pro readcol,file,lambda,itf, skipline=flag

    var=dblarr(2,432)
    a=strarr(1)
    filename=file
    OPENR, unit, filename, /GET_LUN
    IF KEYWORD_SET(flag) then readf,unit,a
    readf,unit,var
    free_lun,unit
    lambda=reform(var(0,*))
    itf=reform(var(1,*))
end