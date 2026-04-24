"""
Spatial filters for VIRTIS-M IR data cubes.
Ported from VEX_tools/amedian.pro (Thompson 1993) and
VEX_tools/hv_filter.pro (Cardesin 2008).
"""

import numpy as np
from scipy.ndimage import median_filter, convolve


_KERNEL_H = np.array([[-1, -1, -1],
                       [ 0,  0,  0],
                       [ 1,  1,  1]], dtype=np.float64)

_KERNEL_V = np.array([[-1,  0,  1],
                       [-1,  0,  1],
                       [-1,  0,  1]], dtype=np.float64)


def amedian(arr, width):
    """
    Edge-tapered median filter.

    Applies a median filter using mirror-reflection padding so that the
    filter effect tapers off at array edges rather than producing artefacts.
    Works on 1-D or 2-D arrays.

    Ported from VEX_tools/amedian.pro (Thompson 1993).

    Parameters
    ----------
    arr : array-like, 1-D or 2-D
        Input array.
    width : int
        Width of the median filter box (odd values recommended).

    Returns
    -------
    ndarray, same shape as arr, float64
    """
    arr = np.asarray(arr, dtype=np.float64)
    return median_filter(arr, size=width, mode='mirror')


def hv_filter(cube):
    """
    Double directional (horizontal + vertical) Prewitt-style filter.

    Applies a horizontal gradient kernel followed by a vertical gradient
    kernel to each spectral band independently, enhancing spatial detail.
    Equivalent to computing a mixed second-order directional derivative.

    Ported from VEX_tools/hv_filter.pro (Cardesin 2008).

    Parameters
    ----------
    cube : array-like (bands, samples, lines)
        Input cube.

    Returns
    -------
    ndarray (bands, samples, lines), float64
    """
    cube   = np.asarray(cube, dtype=np.float64)
    result = np.empty_like(cube)
    for b in range(cube.shape[0]):
        grad_h    = convolve(cube[b], _KERNEL_H, mode='nearest')
        result[b] = convolve(grad_h,  _KERNEL_V, mode='nearest')
    return result
