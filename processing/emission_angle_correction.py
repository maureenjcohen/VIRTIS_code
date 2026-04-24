"""
Emission-angle (limb-darkening) corrections for VIRTIS-M IR spectral windows.
Ported from VEX_tools/emission_angle_correction.pro and
VEX_tools/emission_angle_correction_*.pro (Politi / Cardesin, IASF-INAF).

Each function accepts a radiance cube (bands, samples, lines) and a 2-D
emergence-angle map (samples, lines) in degrees and returns a corrected cube
of the same shape.  All corrections are fully vectorised over bands via numpy
broadcasting — no per-band loop is needed.

References
----------
General – Politi, IASF-INAF (2008): geometric normalisation to min-ema per scan line.
1.27 µm – Crisp et al. (1996), JGR 101, 4577–4594.
1.31 µm – Mueller et al. (2008), JGR 113, E00B17.
1.74 µm – Longobardo et al. (2012), PSS 62–75  (Carlson 1993 in comments).
2.3  µm – Carlson et al. (1993), PSS 41, 477–485.
3.8  µm – Longobardo et al. (2012), PSS 62–75  (Grinspoon 1993 value).
5.0  µm – Longobardo et al. (2012), PSS 62–75  (Table 7, lat 0–40°).
"""

import numpy as np


def _cos_ema(emergence_angle_deg):
    """Return cos of emission angle, broadcasting-ready shape (1, S, L)."""
    ema = np.asarray(emergence_angle_deg, dtype=np.float64)
    return np.cos(np.radians(ema))[np.newaxis, :, :]   # (1, samples, lines)


def correct_general(cube, emergence_angle_deg):
    """
    General geometric emission-angle correction (Politi 2008).

    Normalises every pixel to the minimum emergence angle in its scan line,
    accounting for the curvature of the observed surface.

    Formula: R_corr[b, s, l] = R[b, s, l] / cos(θ[s,l]) × cos(min_s θ[:,l])

    Parameters
    ----------
    cube : ndarray (bands, samples, lines)
        Radiance in W / (m² sr µm).
    emergence_angle_deg : ndarray (samples, lines)
        Per-pixel emergence angle in degrees.

    Returns
    -------
    ndarray, same shape as cube
    """
    ema = np.asarray(emergence_angle_deg, dtype=np.float64)   # (ns, nl)
    ema_rad = np.radians(ema)
    cos_ema = np.cos(ema_rad)                                  # (ns, nl)
    # cos of the minimum emergence angle for each scan line
    cos_of_min = np.cos(np.nanmin(ema_rad, axis=0))            # (nl,)
    return (cube / cos_ema[np.newaxis]
            * cos_of_min[np.newaxis, np.newaxis, :])


def correct_1_27(cube, emergence_angle_deg):
    """
    Emission-angle + backscatter correction for the 1.27 µm O₂ airglow window.

    Formula: R_corr = R × cos(θ) / (1 + 2 × 0.875 × cos(θ))

    Parameters
    ----------
    cube : ndarray (bands, samples, lines)
        Radiance in W / (m² sr µm) or MR.
    emergence_angle_deg : ndarray (samples, lines)
        Per-pixel emergence angle in degrees.

    Returns
    -------
    ndarray, same shape as cube
    """
    c = _cos_ema(emergence_angle_deg)
    return cube * c / (1.0 + 1.75 * c)


def correct_1_31(cube, emergence_angle_deg):
    """
    Emission-angle correction for the 1.31 µm surface thermal window
    (Mueller et al. 2008, JGR 113, E00B17).

    Formula: R_corr = R × cos(θ) / (0.31 + 0.69 × cos(θ))
    """
    c = _cos_ema(emergence_angle_deg)
    return cube * c / (0.31 + 0.69 * c)


def correct_1_74(cube, emergence_angle_deg):
    """
    Emission-angle correction for the 1.74 µm window (Longobardo 2012).

    Formula: R_corr = R / (0.34 + 0.66 × cos(θ))
    """
    c = _cos_ema(emergence_angle_deg)
    return cube / (0.34 + 0.66 * c)


def correct_2_3(cube, emergence_angle_deg):
    """
    Emission-angle correction for the 2.3 µm window (Carlson 1993).

    Formula: R_corr = R / (0.232 + 0.768 × cos(θ))
    """
    c = _cos_ema(emergence_angle_deg)
    return cube / (0.232 + 0.768 * c)


def correct_3_8(cube, emergence_angle_deg):
    """
    Emission-angle correction for the 3.8 µm window (Grinspoon 1993 via
    Longobardo 2012 Table 7).

    Formula: R_corr = R / (0.13 + 0.87 × cos(θ))
    """
    c = _cos_ema(emergence_angle_deg)
    return cube / (0.13 + 0.87 * c)


def correct_5_0(cube, emergence_angle_deg):
    """
    Emission-angle correction for the 5.0 µm window (Longobardo 2012,
    Table 7, latitudes 0–40°).

    Formula: R_corr = R / (0.20 + 0.80 × cos(θ))
    """
    c = _cos_ema(emergence_angle_deg)
    return cube / (0.20 + 0.80 * c)
