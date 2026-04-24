FUNCTION Planck, T,lambda

;lambda is in m
;T is in K
;R is in W/(m2 um sr)

;    N=size(lambda,/N_Elements)
;    R=fltarr(N)

;    L=lambda*1.E-6		; put this line if lambda is in nm

L=lambda

	h=6.626E-34	; js
	c=299792458	; m/s
	k=1.38E-23	; j/K

	R = 2.*h*c^2./((L^5.)*(exp(h*c/(L*k*T))-1))	; R is in W/(m3 sr)
	R = R*1.E-6									; R now is in W/(m2 um sr)

RETURN, R
END
