"""
Remove artefact lines and samples from a VIRTIS calibrated cube.
Ported from VEX_tools/v_crop_cube.pro (Cardesin, IASF-INAF).

The IDL routine modifies its argument in-place; here we return a view/copy
so callers are not surprised by mutation.
"""

import math
import numpy as np


def v_crop_cube(cube, scan_mode_id=1):
    """
    Crop a VIRTIS calibrated cube.

    Removes:
    - The first scan line (always contaminated).
    - Repeated trailing lines when scan_mode_id == 1 (default), truncating
      to min(samples, lines) − 1 lines so the spatial grid is square.
    - The first ceil(6 × samples / 256) samples (detector edge artefact).

    Parameters
    ----------
    cube : ndarray, shape (bands, samples, lines)
    scan_mode_id : int, optional
        Scan mode from the PDS label (VEX:SCAN_MODE_ID).  Pass 1 (default)
        to remove repeated lines; any other value skips that step.

    Returns
    -------
    cropped : ndarray, shape (bands, samples′, lines′)
        A slice of the input array (no data copy unless the input is not
        C-contiguous).
    n_samples : int
        Number of samples in the cropped cube.
    n_lines : int
        Number of lines in the cropped cube.
    """
    cube = np.asarray(cube)
    if cube.ndim == 2:
        cube = cube[np.newaxis, :, :]   # treat as single-band cube
        squeeze = True
    else:
        squeeze = False

    n_bands, n_samples, n_lines = cube.shape

    # Always drop the first line
    cube = cube[:, :, 1:]

    # Drop repeated lines to make the cube square (scan_mode_id == 1)
    if scan_mode_id == 1:
        n_keep = min(n_samples, n_lines) - 1
        cube = cube[:, :, :n_keep]

    # Drop the first few samples (detector edge)
    n_skip = math.ceil(6 * n_samples / 256)
    cube = cube[:, n_skip:, :]

    if squeeze:
        cube = cube[0]

    return cube, cube.shape[-2], cube.shape[-1]
