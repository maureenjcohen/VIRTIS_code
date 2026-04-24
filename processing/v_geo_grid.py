"""
Grid VIRTIS-M IR calibrated radiance into a lat/lon or lat/local-time map.
Ported from VEX_tools/v_geo_grid.pro (Cardesin, IASF-INAF 2008).

Main function
-------------
v_geo_grid(cal, geo, ...)

Spectral resampling helpers
---------------------------
make_co_resample(wl)   – CO 2.3-µm window preset
make_h2o_resample(wl)  – H2O 2.5-µm window preset
"""

import warnings
import numpy as np
from scipy.interpolate import griddata as scipy_griddata

from processing.v_crop_cube import v_crop_cube
from processing.emission_angle_correction import (
    correct_general,
    correct_1_27, correct_1_31, correct_1_74, correct_2_3, correct_3_8, correct_5_0,
)
from processing.incidence_angle_correction import correct_ia_ea
from processing.rad_to_rayleigh import rad_to_rayleigh
from processing.planck import brightness_temperature
from processing.phase_angle_correction import correct_phase_angle
from processing.interpintegrate import interp_integrate_cube
from processing.filters import amedian


# ── GEO band indices ──────────────────────────────────────────────────────────

_GEO_LAT       = 25   # cloud latitude
_GEO_LON       = 24   # cloud longitude
_GEO_LT        = 15   # local time
_GEO_EMERGENCE = 27   # emergence (emission) angle on cloud layer
_GEO_INCIDENCE = 26   # incidence angle on cloud layer
_GEO_ELEVATION = 13   # elevation on surface layer
_GEO_DISTANCE  = 14   # slant distance


# ── Helpers ───────────────────────────────────────────────────────────────────

def _spectrometer_temperature(cal):
    """Return the SPECTROMETER entry from MAXIMUM_INSTRUMENT_TEMPERATURE."""
    lbl = cal.get('label')
    if lbl is None:
        return None
    try:
        points = list(lbl['INSTRUMENT_TEMPERATURE_POINT'])
        values = list(lbl['MAXIMUM_INSTRUMENT_TEMPERATURE'])
        idx = next(i for i, p in enumerate(points) if 'SPECTROMETER' in str(p).upper())
        return float(values[idx])
    except (KeyError, StopIteration, TypeError, ValueError):
        return None


def _geo_band(geo, band_idx):
    """Extract and scale one GEO band → (samples, lines) float64."""
    coeff = float(geo['qube_coeff'][band_idx])
    return geo['qube'][band_idx].astype(np.float64) * coeff


def make_co_resample(wl, mode=1):
    """
    Return a spectral_resamples entry for the CO 2.3-µm window.

    Parameters
    ----------
    wl : array-like, shape (bands,)
        Wavelength array in µm (from cal['suffix']['bottom'][:, 0, 0]).
    mode : {1, 2}
        Mode 1 : bands 132-137 (6 bands), interior knots at 2.29-2.32 µm.
        Mode 2 : bands 130-139 (10 bands).
    """
    wl = np.asarray(wl, dtype=np.float64)
    if mode == 1:
        b1, b2 = 132, 137
    else:
        b1, b2 = 130, 139
    n = b2 - b1 + 1
    new_x = np.linspace(wl[b1], wl[b2], n)
    return {'band_range': (b1, b2), 'new_x': new_x}


def make_h2o_resample(wl, mode=1):
    """
    Return a spectral_resamples entry for the H2O 2.5-µm window.

    Parameters
    ----------
    wl : array-like, shape (bands,)
        Wavelength array in µm (from cal['suffix']['bottom'][:, 0, 0]).
    mode : {1, 2}
        Mode 1 : bands 159-164 (6 bands), interior knots at 2.53-2.56 µm.
        Mode 2 : bands 157-166 (10 bands).
    """
    wl = np.asarray(wl, dtype=np.float64)
    if mode == 1:
        b1, b2 = 159, 164
    else:
        b1, b2 = 157, 166
    n = b2 - b1 + 1
    new_x = np.linspace(wl[b1], wl[b2], n)
    return {'band_range': (b1, b2), 'new_x': new_x}


# ── Main function ─────────────────────────────────────────────────────────────

def v_geo_grid(
    cal,
    geo,
    # --- band selection ---
    index_band=None,
    index_ratio=None,
    geo_band=None,
    average=True,
    # --- grid axes ---
    use_lt=True,
    x_range=None,
    y_range=(-90.0, 90.0),
    x_delta=None,
    y_delta=None,
    x_size=None,
    y_size=None,
    # --- pixel filters ---
    min_emergence=0.0,
    max_emergence=90.0,
    min_incidence=0.0,
    max_incidence=180.0,
    min_elevation=-999.0,
    max_elevation=999.0,
    min_distance=0.0,
    max_distance=1e6,
    nightside=False,
    dayside=False,
    only_positive=True,
    min_value=-999.0,
    max_value=1e6,
    min_input=-999.0,
    max_input=1e6,
    min_temperature=-999.0,
    max_temperature=999.0,
    # --- corrections (applied in order) ---
    spectral_resamples=None,
    thermal_brightness=False,
    emission_angle=None,
    post_ema=True,
    index_continuum=None,
    index_thermal=None,
    index_cont_thermal=None,
    thermal_ratio=None,
    rayleigh=False,
    incidence_angle=False,
    phase_angle=False,
    median_filter=False,
):
    """
    Grid VIRTIS-M radiance into a 2-D latitude/longitude or latitude/local-time map.

    Ported from VEX_tools/v_geo_grid.pro (Cardesin, IASF-INAF 2008).

    Parameters
    ----------
    cal : dict
        Output of virtispds() for a .CAL file.
    geo : dict
        Output of virtispds() for the matching .GEO file.
    index_band : int or array-like of int
        Band index/indices to select from the calibrated cube.
        If multiple indices, the selected bands are averaged (average=True)
        or summed (average=False) before gridding.
    index_ratio : int or array-like of int, optional
        Band index/indices for a ratio denominator: output = band / ratio.
    geo_band : int, optional
        If set, grid this GEO channel instead of radiance (all other band
        selection parameters are ignored).
    average : bool
        True (default) → mean across index_band; False → sum.
    use_lt : bool
        True (default) → X-axis is local time [-12, 12].
        False → X-axis is cloud longitude [0, 360].
    x_range, y_range : (lo, hi)
        Axis extents.  y_range defaults to (-90, 90).
        x_range defaults to data extent when None.
    x_delta, y_delta : float, optional
        Grid spacing.  Computed from size/range if not given.
    x_size, y_size : int, optional
        Number of grid cells.  Defaults to 512 when no other axis param given.
    min/max_emergence : float
        Pixel emergence angle filter (degrees, 0–90).
    min/max_incidence : float
        Pixel incidence angle filter (degrees, 0–180).
    min/max_elevation : float
        Pixel elevation filter (km).
    min/max_distance : float
        Pixel slant-distance filter (km).
    nightside : bool
        Shorthand for min_incidence = 95.
    dayside : bool
        Shorthand for max_incidence = 85.
    only_positive : bool
        Ignore pixels with radiance ≤ 0 (default True).
    min_value, max_value : float
        Output radiance filter after all corrections.
    min_input, max_input : float
        Input radiance filter applied before corrections.
    min_temperature, max_temperature : float
        Skip this observation if spectrometer temperature is outside range (K).
    spectral_resamples : list of dict, optional
        Each dict must have 'band_range': (b1, b2) and 'new_x': ndarray.
        Applied to the full cube before band selection.
        Use make_co_resample(wl) / make_h2o_resample(wl) to build entries.
    thermal_brightness : bool
        Convert radiance to brightness temperature (K) using the inverse
        Planck function before averaging/gridding.  When True, `average`
        is forced to True and continuum subtraction is skipped (matching
        IDL behaviour).
    emission_angle : str or None
        Emission-angle correction to apply.  One of:
        'general', '1.27', '1.31', '1.74', '2.3', '3.8', '5.0', or None.
    post_ema : bool
        True (default) → apply EMA correction after Rayleigh/continuum.
        False → apply before.
    index_continuum : int or array-like of int, optional
        Band index/indices for continuum subtraction.
    index_thermal : int or array-like of int, optional
        Band index/indices for thermal contribution.
    index_cont_thermal : int or array-like of int, optional
        Band index/indices for thermal continuum subtraction.
    thermal_ratio : float, optional
        Scaling factor for thermal subtraction.
    rayleigh : bool
        Convert radiance to Rayleigh (MR) before gridding.
    incidence_angle : bool
        Apply cos(IA)/cos(EA)^0.25 correction.
    phase_angle : bool
        Divide by sin(phase angle).
    median_filter : bool
        Apply 3-pixel median filter to each band and to the final grid.

    Returns
    -------
    dict with keys:
        'grid'    : ndarray (n_lat, n_x) — gridded 2-D map, NaN for empty cells
        'x_axis'  : ndarray — bin-centre X values (LT or longitude)
        'y_axis'  : ndarray — bin-centre latitudes
        'x_edges' : ndarray — bin-edge X values
        'y_edges' : ndarray — bin-edge Y values
        'count'   : ndarray (n_lat, n_x) — number of valid pixels per cell

    Raises
    ------
    ValueError
        If a spectral_resamples entry has mismatched new_x length.
    RuntimeError
        With a message code if no valid pixels are found (codes match IDL):
        '-2' no pixels pass geometry filter, '-3' all values outside min/max.
    NotImplementedError
        TRIGRID path is not ported (IDL itself marks it untested).
    """

    # ── Temperature gate ──────────────────────────────────────────────────────
    spec_temp = _spectrometer_temperature(cal)
    if spec_temp is not None:
        if spec_temp < min_temperature or spec_temp > max_temperature:
            raise RuntimeError(
                f'-5: spectrometer temperature {spec_temp:.1f} K outside '
                f'[{min_temperature}, {max_temperature}] K'
            )

    # ── Convenience shorthands ────────────────────────────────────────────────
    if nightside:
        min_incidence = max(min_incidence, 95.0)
    if dayside:
        max_incidence = min(max_incidence, 85.0)
    if only_positive:
        min_value = max(min_value, 0.0)

    # ── Load and crop GEO arrays ──────────────────────────────────────────────
    geo_cube     = geo['qube']                          # (33, ns, nl)
    scan_mode_id = _get_scan_mode(geo)

    # Crop geo cube; get fixed spatial dimensions
    geo_cropped, ns, nl = v_crop_cube(geo_cube, scan_mode_id=scan_mode_id)

    lat  = _geo_band_cropped(geo, _GEO_LAT,       scan_mode_id)  # (ns, nl)
    lon  = _geo_band_cropped(geo, _GEO_LON,       scan_mode_id)
    lt   = _geo_band_cropped(geo, _GEO_LT,        scan_mode_id)
    ema  = _geo_band_cropped(geo, _GEO_EMERGENCE, scan_mode_id)
    inc  = _geo_band_cropped(geo, _GEO_INCIDENCE, scan_mode_id)
    elev = _geo_band_cropped(geo, _GEO_ELEVATION, scan_mode_id)
    dist = _geo_band_cropped(geo, _GEO_DISTANCE,  scan_mode_id)

    # ── Geometry pixel filter ─────────────────────────────────────────────────
    valid_mask = (
        (ema  >= min_emergence) & (ema  <= max_emergence) &
        (inc  >= min_incidence) & (inc  <= max_incidence) &
        (elev >= min_elevation) & (elev <= max_elevation) &
        (dist >= min_distance ) & (dist <= max_distance ) &
        np.isfinite(lat)
    )
    if not valid_mask.any():
        raise RuntimeError('-2: no pixels pass the geometry filter')

    # ── GEO-band-only path (grid a geometry channel instead of radiance) ──────
    if geo_band is not None:
        radiance = _geo_band_cropped(geo, geo_band, scan_mode_id)  # (ns, nl)
    else:
        # ── Load and crop CAL cube ────────────────────────────────────────────
        cube = cal['qube'].astype(np.float64)           # (nb, ns, nl)
        cube, _, _ = v_crop_cube(cube, scan_mode_id=scan_mode_id)
        nb = cube.shape[0]

        wl = cal['suffix']['bottom'][:, 0, 0].astype(np.float64)  # (nb,)

        # ── Spectral resampling (CO / H2O windows or generic) ────────────────
        if spectral_resamples:
            for rs in spectral_resamples:
                b1, b2  = rs['band_range']
                new_x   = np.asarray(rs['new_x'], dtype=np.float64)
                n_bands = b2 - b1 + 1
                if len(new_x) != n_bands:
                    raise ValueError(
                        f"spectral_resamples entry band_range ({b1},{b2}) "
                        f"has {n_bands} bands but new_x has {len(new_x)} points; "
                        "they must be equal to preserve cube shape"
                    )
                cube[b1:b2+1] = interp_integrate_cube(
                    wl[b1:b2+1], cube[b1:b2+1], new_x
                )

        # ── Band index rescaling (if cube has fewer than 432 bands) ──────────
        iband = _rescale_indices(index_band, nb)

        # ── Input value clipping ──────────────────────────────────────────────
        sel = cube[iband]                               # (nsel, ns, nl)
        invalid_input = (sel < min_input) | (sel > max_input)
        sel = sel.copy()
        sel[invalid_input] = np.nan

        # ── Pre-EMA correction (post_ema=False) ───────────────────────────────
        if not post_ema and emission_angle is not None:
            sel = _apply_ema(sel, ema, emission_angle)

        # ── Rayleigh conversion ───────────────────────────────────────────────
        if rayleigh:
            sel_wl = wl[iband]
            sel    = rad_to_rayleigh(sel, sel_wl)

        # ── Thermal brightness (inverse Planck) ───────────────────────────────
        if thermal_brightness:
            sel_wl = wl[iband]
            sel    = brightness_temperature(sel, sel_wl)
            average = True   # IDL forces average when thermal_brightness is set

        # ── Median filter per band ────────────────────────────────────────────
        if median_filter:
            for b in range(sel.shape[0]):
                sel[b] = amedian(sel[b], 3)

        # ── Collapse bands → 2D radiance ─────────────────────────────────────
        if average:
            count2d  = np.nansum(np.isfinite(sel).astype(np.float64), axis=0)
            radiance = np.nansum(sel, axis=0) / np.where(count2d > 0, count2d, np.nan)
        else:
            radiance = np.nansum(sel, axis=0)
            # restore NaN where all bands were NaN
            all_nan = np.all(~np.isfinite(sel), axis=0)
            radiance[all_nan] = np.nan

        # ── Ratio ─────────────────────────────────────────────────────────────
        if index_ratio is not None:
            iratio    = _rescale_indices(index_ratio, nb)
            ratio_sel = cube[iratio].copy()
            if not post_ema and emission_angle is not None:
                ratio_sel = _apply_ema(ratio_sel, ema, emission_angle)
            if average:
                cnt  = np.nansum(np.isfinite(ratio_sel).astype(np.float64), axis=0)
                ratio = np.nansum(ratio_sel, axis=0) / np.where(cnt > 0, cnt, np.nan)
            else:
                ratio = np.nansum(ratio_sel, axis=0)
            radiance = radiance / ratio

        # ── Continuum subtraction ─────────────────────────────────────────────
        if index_continuum is not None and not thermal_brightness:
            icont     = _rescale_indices(index_continuum, nb)
            cont_sel  = cube[icont].copy()
            if median_filter:
                for b in range(cont_sel.shape[0]):
                    cont_sel[b] = amedian(cont_sel[b], 3)
            cnt_cont  = np.nansum(np.isfinite(cont_sel).astype(np.float64), axis=0)
            avg_cont  = np.nansum(cont_sel, axis=0) / np.where(cnt_cont > 0, cnt_cont, np.nan)
            tot_cont  = avg_cont if average else avg_cont * len(np.atleast_1d(index_band))
            radiance  = radiance - tot_cont

        # ── Thermal subtraction ───────────────────────────────────────────────
        if index_thermal is not None:
            ith       = _rescale_indices(index_thermal, nb)
            th_sel    = cube[ith].copy()
            if median_filter:
                for b in range(th_sel.shape[0]):
                    th_sel[b] = amedian(th_sel[b], 3)
            cnt_th    = np.nansum(np.isfinite(th_sel).astype(np.float64), axis=0)
            th_rad    = np.nansum(th_sel, axis=0) / np.where(cnt_th > 0, cnt_th, np.nan)
            if not average:
                th_rad = th_rad   # already summed
            if (index_cont_thermal is not None
                    and thermal_ratio is not None):
                ithc      = _rescale_indices(index_cont_thermal, nb)
                thc_sel   = cube[ithc].copy()
                cnt_thc   = np.nansum(np.isfinite(thc_sel).astype(np.float64), axis=0)
                thc_avg   = np.nansum(thc_sel, axis=0) / np.where(cnt_thc > 0, cnt_thc, np.nan)
                tot_thc   = thc_avg if average else thc_avg * len(np.atleast_1d(index_thermal))
                th_rad    = th_rad - tot_thc
            if thermal_ratio is not None:
                radiance  = radiance - thermal_ratio * th_rad

        # ── Post-EMA correction ───────────────────────────────────────────────
        if post_ema and emission_angle is not None:
            # radiance is 2D (ns, nl); wrap in fake band axis for correction fns
            radiance = _apply_ema(radiance[np.newaxis], ema, emission_angle)[0]

        # ── Incidence / phase corrections ─────────────────────────────────────
        if incidence_angle:
            radiance = correct_ia_ea(
                radiance[np.newaxis],
                inc_band=inc,
                ema_band=ema,
            )[0]
        if phase_angle:
            pa = _geo_band_cropped(geo, 28, scan_mode_id)
            radiance = correct_phase_angle(radiance[np.newaxis], pa)[0]

    # ── X coordinate (LT or longitude) ───────────────────────────────────────
    if use_lt:
        x_coord = ((lt + 12.0) % 24.0) - 12.0   # rescale to [-12, 12]
    else:
        x_coord = lon

    # ── Apply geometry mask and output value filter ───────────────────────────
    valid_mask &= np.isfinite(radiance)
    if only_positive:
        valid_mask &= (radiance > 0.0)
    valid_mask &= (radiance >= min_value) & (radiance <= max_value)

    if not valid_mask.any():
        raise RuntimeError('-3: all pixel values are outside min/max limits')

    x_pts = x_coord[valid_mask]
    y_pts = lat[valid_mask]
    z_pts = radiance[valid_mask]

    # ── Build grid axes ───────────────────────────────────────────────────────
    x_edges, y_edges, x_axis, y_axis, nx, ny = _build_axes(
        x_pts, y_pts, x_range, y_range, x_delta, y_delta, x_size, y_size
    )

    # ── Bin-average into regular grid ─────────────────────────────────────────
    grid, count = _bin_average(x_pts, y_pts, z_pts, x_edges, y_edges)

    # ── Median filter on final grid ───────────────────────────────────────────
    if median_filter:
        finite_mask = np.isfinite(grid)
        if finite_mask.any():
            from scipy.ndimage import median_filter as mf
            grid_filled = np.where(finite_mask, grid, 0.0)
            grid_smooth = mf(grid_filled, size=3, mode='nearest')
            grid = np.where(finite_mask, grid_smooth, np.nan)

    return {
        'grid'   : grid,
        'x_axis' : x_axis,
        'y_axis' : y_axis,
        'x_edges': x_edges,
        'y_edges': y_edges,
        'count'  : count,
    }


# ── Internal helpers ──────────────────────────────────────────────────────────

def _get_scan_mode(geo):
    """Extract scan_mode_id from the GEO label (default 1)."""
    try:
        return int(geo['label']['VEX:SCAN_MODE_ID'])
    except (KeyError, TypeError, ValueError):
        return 1


def _geo_band_cropped(geo, band_idx, scan_mode_id):
    """Extract, scale, and crop one GEO band → (ns, nl) float64."""
    coeff = float(geo['qube_coeff'][band_idx])
    band2d = geo['qube'][band_idx].astype(np.float64) * coeff  # (ns, nl)
    # v_crop_cube expects (bands, ns, nl); wrap and unwrap
    cropped, _, _ = v_crop_cube(band2d[np.newaxis], scan_mode_id=scan_mode_id)
    return cropped[0]


def _rescale_indices(index, nb):
    """Rescale band index/indices to the actual cube band count."""
    idx = np.atleast_1d(np.asarray(index, dtype=np.int64))
    return (idx * nb / 432).astype(np.int64)


_EMA_FUNCS = {
    'general': correct_general,
    '1.27':    correct_1_27,
    '1.31':    correct_1_31,
    '1.74':    correct_1_74,
    '2.3':     correct_2_3,
    '3.8':     correct_3_8,
    '5.0':     correct_5_0,
}


def _apply_ema(cube, ema, key):
    """Dispatch to the appropriate emission-angle correction function."""
    key = str(key).lower()
    if key not in _EMA_FUNCS:
        raise ValueError(
            f"Unknown emission_angle key '{key}'. "
            f"Choose from: {list(_EMA_FUNCS)}"
        )
    return _EMA_FUNCS[key](cube, ema)


def _build_axes(x_pts, y_pts, x_range, y_range, x_delta, y_delta, x_size, y_size):
    """
    Resolve axis parameters (range, delta, size) following IDL logic:
    if none are given default to size=512; if one of (range, delta, size)
    is missing compute it from the other two.
    """
    n_given_x = sum(v is not None for v in [x_range, x_delta, x_size])
    n_given_y = sum(v is not None for v in [y_range, y_delta, y_size])

    if n_given_x == 0:
        x_size  = 512
        x_range = (float(np.nanmin(x_pts)), float(np.nanmax(x_pts)))
    if n_given_y == 0:
        y_size  = 512
        # y_range already has a default of (-90, 90)

    if x_range is None:
        x_range = (float(np.nanmin(x_pts)), float(np.nanmax(x_pts)))
    if y_range is None:
        y_range = (float(np.nanmin(y_pts)), float(np.nanmax(y_pts)))

    if x_size  is None and x_delta is not None:
        x_size  = int(round((x_range[1] - x_range[0]) / x_delta))
    if y_size  is None and y_delta is not None:
        y_size  = int(round((y_range[1] - y_range[0]) / y_delta))
    if x_delta is None:
        x_size  = x_size or 512
        x_delta = (x_range[1] - x_range[0]) / x_size
    if y_delta is None:
        y_size  = y_size or 512
        y_delta = (y_range[1] - y_range[0]) / y_size

    x_size = x_size or int(round((x_range[1] - x_range[0]) / x_delta))
    y_size = y_size or int(round((y_range[1] - y_range[0]) / y_delta))

    x_edges = np.linspace(x_range[0], x_range[1], x_size + 1)
    y_edges = np.linspace(y_range[0], y_range[1], y_size + 1)
    x_axis  = 0.5 * (x_edges[:-1] + x_edges[1:])
    y_axis  = 0.5 * (y_edges[:-1] + y_edges[1:])
    return x_edges, y_edges, x_axis, y_axis, x_size, y_size


def _bin_average(x_pts, y_pts, z_pts, x_edges, y_edges):
    """
    Bin-average scattered (x, y, z) points onto a regular lat/X grid.

    Points outside [x_edges[0], x_edges[-1]] × [y_edges[0], y_edges[-1]]
    are silently ignored.  Values exactly on the right boundary are
    included in the last bin (matching numpy.histogram2d convention).

    Returns
    -------
    grid  : (n_lat, n_x) float64, NaN where count == 0
    count : (n_lat, n_x) int64
    """
    nx = len(x_edges) - 1
    ny = len(y_edges) - 1

    # searchsorted(..., side='right') - 1 maps value → bin index 0…nx-1
    xi = np.searchsorted(x_edges, x_pts, side='right') - 1
    yi = np.searchsorted(y_edges, y_pts, side='right') - 1

    # Include values exactly on the right boundary in the last bin
    xi = np.where(x_pts == x_edges[-1], nx - 1, xi)
    yi = np.where(y_pts == y_edges[-1], ny - 1, yi)

    in_bounds = (xi >= 0) & (xi < nx) & (yi >= 0) & (yi < ny)
    xi = xi[in_bounds]
    yi = yi[in_bounds]
    z  = z_pts[in_bounds]

    count = np.zeros((ny, nx), dtype=np.int64)
    total = np.zeros((ny, nx), dtype=np.float64)

    np.add.at(count, (yi, xi), 1)
    np.add.at(total, (yi, xi), z)

    with np.errstate(invalid='ignore'):
        grid = np.where(count > 0, total / count, np.nan)

    return grid, count
