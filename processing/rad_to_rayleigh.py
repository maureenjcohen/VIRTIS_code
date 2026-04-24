"""
Convert VIRTIS radiance cubes from W/m²/sr/µm to MegaRayleigh.
Ported from VEX_tools/rad_to_rayleigh.pro (Migliorini/Cardesin, IASF-INAF).

One MegaRayleigh = 10¹² photons cm⁻² s⁻¹ (4π sr)⁻¹.
"""

import numpy as np

_DLAMBDA_IR = 9.46673e-3   # IR spectel width in µm (instrument constant)


def rad_to_rayleigh(cube, wavelengths):
    """
    Convert a radiance cube to MegaRayleigh.

    Parameters
    ----------
    cube : ndarray, shape (bands, samples, lines)
        Radiance in W / (m² sr µm).
    wavelengths : array-like, length bands
        Wavelength of each spectral band in µm.

    Returns
    -------
    ndarray, same shape as cube
        Radiance in MegaRayleigh (MR).
    """
    cube = np.asarray(cube, dtype=np.float64)
    wl   = np.asarray(wavelengths, dtype=np.float64)   # (bands,)

    # Conversion factor per band: shape (bands,)
    factor = 1.9864867 * np.pi * wl * 1e9 * _DLAMBDA_IR * 1e-6

    # Broadcast over (samples, lines)
    return cube * factor[:, np.newaxis, np.newaxis]
