"""
Planck blackbody radiance function.
Ported from VEX_tools/planck.pro (Cardesin, IASF-INAF).
"""

import numpy as np

_H = 6.626e-34   # J·s
_C = 299_792_458  # m/s
_K = 1.38e-23    # J/K


def planck(T, wavelength):
    """
    Planck blackbody radiance.

    Parameters
    ----------
    T : float or array
        Temperature in Kelvin.
    wavelength : float or array
        Wavelength in metres.

    Returns
    -------
    ndarray
        Spectral radiance in W / (m² µm sr).
    """
    L = np.asarray(wavelength, dtype=np.float64)
    T = np.asarray(T, dtype=np.float64)
    R = 2 * _H * _C**2 / (L**5 * (np.exp(_H * _C / (L * _K * T)) - 1))
    return R * 1e-6   # W/(m³ sr) → W/(m² µm sr)


def brightness_temperature(cube, wavelengths):
    """
    Convert radiance to brightness temperature (inverse Planck).

    Inverts the Planck function per band: given R in W/(m² µm sr) and λ in µm,
    returns T_B such that planck(T_B, λ·1e-6) == R.

    Parameters
    ----------
    cube : ndarray, shape (bands, samples, lines)
        Radiance in W / (m² µm sr).
    wavelengths : array-like, length bands
        Wavelength of each band in µm.

    Returns
    -------
    ndarray, same shape as cube
        Brightness temperature in K.  Pixels where R ≤ 0 return NaN.
    """
    cube = np.asarray(cube, dtype=np.float64)
    wl   = np.asarray(wavelengths, dtype=np.float64) * 1e-6   # µm → m
    wl   = wl[:, np.newaxis, np.newaxis]                       # broadcast over (s, l)
    # R is in W/m²/µm/sr; planck() multiplies by 1e-6 so we divide R by 1e-6
    # to get back to W/m³/sr before inverting.
    with np.errstate(divide='ignore', invalid='ignore'):
        T = (_H * _C / (_K * wl)) / np.log1p(
            2 * _H * _C**2 / (wl**5 * cube * 1e6)
        )
    return T
