"""
Incidence-angle and background corrections for VIRTIS-M IR data.
Ported from VEX_tools/incidence_angle_correction.pro (Politi 2008),
VEX_tools/ia_corr.pro (Politi 2008), and
VEX_tools/incidence_angle_correction_mine.pro (Cardesin 2008).
"""

import numpy as np


def correct_incidence(cube):
    """
    Remove solar-scatter background per scan line.

    For each (band, line), subtracts the minimum radiance found in
    samples 8–30 (inclusive), which are assumed to represent the solar
    scattering reference.

    Ported from VEX_tools/incidence_angle_correction.pro (Politi 2008).

    Parameters
    ----------
    cube : ndarray (bands, samples, lines)
        Calibrated radiance in W / (m² sr µm).

    Returns
    -------
    ndarray (bands, samples, lines), float64
    """
    cube = np.asarray(cube, dtype=np.float64)
    ref = np.nanmin(cube[:, 8:31, :], axis=1, keepdims=True)  # (nb, 1, nl)
    return cube - ref


def ia_corr(cal, geo, band):
    """
    Single-band emission-angle normalisation + solar background subtraction.

    Step 1: normalise each pixel to the minimum emergence angle in its scan
    line — R[s,l] → R[s,l] / cos(θ[s,l]) × cos(min_s θ[:,l]).
    Step 2: subtract per-line background (min over samples 8–30) and
    re-level to the global minimum.

    Ported from VEX_tools/ia_corr.pro (Politi 2008).

    Parameters
    ----------
    cal : dict
        Output of virtispds() for a CAL file ('qube' shape: bands×samples×lines).
    geo : dict
        Output of virtispds() for a GEO file ('qube' shape: 33×samples×lines,
        'qube_coeff' shape: (33,)).
    band : int
        Band index to correct.

    Returns
    -------
    ndarray (samples, lines), float64
    """
    newcb = cal['qube'][band].astype(np.float64)              # (ns, nl)
    ema   = geo['qube'][27] * geo['qube_coeff'][27]           # (ns, nl) degrees
    cos_ema    = np.cos(np.radians(ema))                      # (ns, nl)
    cos_of_min = np.cos(np.nanmin(np.radians(ema), axis=0))  # (nl,)

    newcb = (newcb / cos_ema) * cos_of_min[np.newaxis, :]

    mean_v = np.nanmin(newcb[8:31, :], axis=0)                # (nl,)
    return newcb - mean_v[np.newaxis, :] + np.nanmin(mean_v)


def correct_ia_ea(cube, inc_band, ema_band):
    """
    Cosine-law correction for incidence and emission angles.

    Formula: R_corr = R / cos(IA) / cos(EA)^0.25

    Ported from VEX_tools/incidence_angle_correction_mine.pro (Cardesin 2008).

    Parameters
    ----------
    cube : ndarray (bands, samples, lines)
        Calibrated radiance.
    inc_band : ndarray (samples, lines)
        Per-pixel incidence angle in degrees (GEO band 26).
    ema_band : ndarray (samples, lines)
        Per-pixel emergence angle in degrees (GEO band 27).

    Returns
    -------
    ndarray (bands, samples, lines), float64
    """
    cos_ia = np.cos(np.radians(np.asarray(inc_band, dtype=np.float64)))[np.newaxis]
    cos_ea = np.cos(np.radians(np.asarray(ema_band, dtype=np.float64)))[np.newaxis]
    return np.asarray(cube, dtype=np.float64) / cos_ia / (cos_ea ** 0.25)
