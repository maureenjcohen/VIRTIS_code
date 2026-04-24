"""
Phase-angle correction for VIRTIS-M IR data.
Ported from VEX_tools/phase_angle_correction.pro (Cardesin 2008).
"""

import numpy as np


def correct_phase_angle(cube, phase_angle_deg):
    """
    Divide radiance by sin(phase angle).

    Formula: R_corr = R / sin(φ)

    Ported from VEX_tools/phase_angle_correction.pro (Cardesin 2008).

    Parameters
    ----------
    cube : ndarray (bands, samples, lines)
        Calibrated radiance.
    phase_angle_deg : ndarray (samples, lines)
        Per-pixel phase angle in degrees (GEO band 28).

    Returns
    -------
    ndarray (bands, samples, lines), float64
    """
    sin_pa = np.sin(np.radians(np.asarray(phase_angle_deg, dtype=np.float64)))
    return np.asarray(cube, dtype=np.float64) / sin_pa[np.newaxis]
