"""
Bin-averaged spectral resampling using trapezoidal integration.
Ported from VEX_tools/interpintegrate.pro, interpintegrate_2D.pro, and
interpIntegrate_3D.pro.

interp_integrate resamples a 1-D or 2-D dataset (x, y) onto a new grid
(new_x) by computing, for each output point, the area-averaged integral
over the bin defined by the midpoints between adjacent new_x values.

interp_integrate_cube is a thin wrapper for full (bands, samples, lines)
VIRTIS cubes, matching interpIntegrate_3D.pro.
"""

import numpy as np


def interp_integrate(x, y, new_x, ind1=None, ind2=None):
    """
    Resample y(x) onto new_x by bin-averaged trapezoidal integration.

    Matches the behaviour of IDL interpIntegrate / interpIntegrate_2D.

    Parameters
    ----------
    x : array-like, shape (N,)
        Original independent variable (monotonically increasing).
    y : array-like, shape (N,) or (M, N)
        Dependent variable(s).  If 2-D, each row is resampled independently.
    new_x : array-like, shape (K,)
        Target x grid (monotonically increasing).
    ind1 : int, optional
        First index of new_x to compute (default 0).
    ind2 : int, optional
        Last index of new_x to compute, inclusive (default K−1).

    Returns
    -------
    ndarray, shape (K_out,) or (M, K_out)
        Resampled values where K_out = ind2 − ind1 + 1.
        Shape matches the input y dimensionality.
    """
    x     = np.asarray(x,     dtype=np.float64)
    new_x = np.asarray(new_x, dtype=np.float64)
    y     = np.asarray(y,     dtype=np.float64)

    squeeze = y.ndim == 1
    if squeeze:
        y = y[np.newaxis, :]   # (1, N)

    M, N = y.shape
    K    = len(new_x)

    if ind1 is None:
        ind1 = 0
    if ind2 is None:
        ind2 = K - 1

    n_out  = ind2 - ind1 + 1
    result = np.zeros((M, n_out), dtype=np.float64)

    # Early exit when new_x lies entirely outside x
    if new_x[ind1] >= x[-1] or new_x[ind2] <= x[0]:
        return result[0] if squeeze else result

    for i_out, i in enumerate(range(ind1, ind2 + 1)):

        # ── Bin boundaries ────────────────────────────────────────────────
        lower  = (3*new_x[i] - new_x[i+1]) / 2 if i == 0     else (new_x[i] + new_x[i-1]) / 2
        higher = (3*new_x[i] - new_x[i-1]) / 2 if i == K - 1 else (new_x[i] + new_x[i+1]) / 2

        # ── Interpolated y at lower boundary ─────────────────────────────
        if lower < x[0]:
            j_lo   = 0
            y_lo   = np.zeros(M)
        else:
            j_lo   = max(0, np.searchsorted(x, lower,  side='right') - 1)
            j_lo   = min(j_lo, N - 2)
            t      = (lower  - x[j_lo]) / (x[j_lo + 1] - x[j_lo])
            y_lo   = y[:, j_lo] + (y[:, j_lo + 1] - y[:, j_lo]) * t

        # ── Interpolated y at higher boundary ─────────────────────────────
        if higher > x[-1]:
            j_hi   = N - 2
            y_hi   = np.zeros(M)
        else:
            j_hi   = max(0, np.searchsorted(x, higher, side='right') - 1)
            j_hi   = min(j_hi, N - 2)
            t      = (higher - x[j_hi]) / (x[j_hi + 1] - x[j_hi])
            y_hi   = y[:, j_hi] + (y[:, j_hi + 1] - y[:, j_hi]) * t

        # ── Trapezoidal integration over the bin ──────────────────────────
        if j_lo == j_hi:
            result[:, i_out] = (y_lo + y_hi) / 2.0
        else:
            dx_first = x[j_lo + 1] - lower
            dx_last  = higher - x[j_hi]
            x_sum    = dx_first + dx_last
            y_sum    = (y_lo + y[:, j_lo + 1]) * dx_first + \
                       (y_hi + y[:, j_hi])     * dx_last

            if j_hi > j_lo + 1:
                dx  = np.diff(x[j_lo + 1: j_hi + 1])          # (j_hi - j_lo - 1,)
                x_sum += dx.sum()
                y_sum += ((y[:, j_lo + 1: j_hi] +
                           y[:, j_lo + 2: j_hi + 1]) * dx).sum(axis=1)

            result[:, i_out] = (y_sum / x_sum / 2.0) if x_sum > 0 else 0.0

    return result[0] if squeeze else result


def interp_integrate_cube(x, cube, new_x, ind1=None, ind2=None):
    """
    Resample a spectral cube along the band axis.

    Thin wrapper around interp_integrate for VIRTIS cubes.
    Matches the behaviour of IDL interpIntegrate_3D.

    Parameters
    ----------
    x : array-like, shape (N,)
        Original spectral axis (e.g. wavelength array, length == cube.shape[0]).
    cube : array-like, shape (bands, samples, lines)
        Spectral cube; the first axis must match x.
    new_x : array-like, shape (K,)
        Target spectral grid.
    ind1 : int, optional
        First index of new_x to compute (default 0).
    ind2 : int, optional
        Last index of new_x to compute, inclusive (default K−1).

    Returns
    -------
    ndarray, shape (K_out, samples, lines)
        Resampled cube where K_out = ind2 − ind1 + 1.
    """
    cube = np.asarray(cube, dtype=np.float64)
    nb, ns, nl = cube.shape
    y2d = cube.reshape(nb, ns * nl).T          # (ns*nl, nb)
    out2d = interp_integrate(x, y2d, new_x, ind1=ind1, ind2=ind2)  # (ns*nl, K)
    K = out2d.shape[1]
    return out2d.T.reshape(K, ns, nl)
