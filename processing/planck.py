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
