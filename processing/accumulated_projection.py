"""
Multi-file accumulated grid projections for VIRTIS-M IR data.
Ported from VEX_tools/accumulated_projection_*.pro (Cardesin, IASF-INAF 2008).
"""

import warnings
import numpy as np
from pathlib import Path

from pds.virtispds import virtispds
from processing.v_geo_grid import v_geo_grid, make_co_resample
from processing.time_utils import scet2jul

_REFERENCE_DATE = 2453846  # Julian date ~= orbit 0 epoch


# ── Label helpers ─────────────────────────────────────────────────────────────

def _get_science_case(lbl):
    try:
        return int(lbl['VEX:SCIENCE_CASE_ID'])
    except (KeyError, TypeError, ValueError):
        return None


def _get_exptime(lbl):
    try:
        fp  = list(lbl['FRAME_PARAMETER'])
        fpd = list(lbl['FRAME_PARAMETER_DESC'])
        idx = next(i for i, d in enumerate(fpd) if 'EXPOSURE_DURATION' in str(d).upper())
        return float(fp[idx])
    except (KeyError, StopIteration, TypeError, ValueError):
        return None


# ── Core accumulation loop ────────────────────────────────────────────────────

def accumulated_projection(
    cal_files,
    geo_files,
    v_geo_grid_kwargs,
    spectral_resamples_fn=None,
    exclude_ids=None,
    min_science_case=1,
    max_science_case=3,
    min_exptime=0.0,
    max_exptime=20.0,
    verbose=True,
):
    """
    Accumulate v_geo_grid results across multiple CAL/GEO file pairs.

    Parameters
    ----------
    cal_files : list of str or Path
    geo_files : list of str or Path
    v_geo_grid_kwargs : dict
        Fixed kwargs forwarded to v_geo_grid for every cube.
    spectral_resamples_fn : callable(wl) → list, optional
        Called per cube with wl in µm; result injected as spectral_resamples.
    exclude_ids : frozenset of str, optional
        CAL filenames containing any of these substrings are skipped.
    min_science_case, max_science_case : int
    min_exptime, max_exptime : float  (seconds)
    verbose : bool

    Returns
    -------
    dict : grid (ny,nx), total (ny,nx), count (ny,nx, int64),
           x_axis, y_axis, x_edges, y_edges, fnamelist, fdatelist
    """
    exclude_ids = exclude_ids or frozenset()
    geo_files   = list(geo_files)

    total_grid = None
    count_grid = None
    axes       = None
    fnamelist  = []
    fdatelist  = []

    for cal_file in cal_files:
        cal_path = Path(cal_file)

        # ── exclude list ──────────────────────────────────────────────────────
        if any(eid in cal_path.name for eid in exclude_ids):
            if verbose:
                print(f'SKIP (excluded): {cal_path.name}')
            continue

        # ── find matching GEO ─────────────────────────────────────────────────
        stem9    = cal_path.stem[:9]
        geo_path = next((Path(g) for g in geo_files if stem9 in Path(g).name), None)
        if geo_path is None:
            if verbose:
                print(f'SKIP (no GEO): {cal_path.name}')
            continue

        # ── read data ─────────────────────────────────────────────────────────
        try:
            cal = virtispds(str(cal_path))
            geo = virtispds(str(geo_path))
        except Exception as exc:
            if verbose:
                print(f'SKIP (read error {exc}): {cal_path.name}')
            continue

        # ── pre-filters from label ────────────────────────────────────────────
        lbl = cal['label']

        sc = _get_science_case(lbl)
        if sc is None or not (min_science_case <= sc <= max_science_case):
            if verbose:
                print(f'SKIP (science_case={sc}): {cal_path.name}')
            continue

        et = _get_exptime(lbl)
        if et is None or not (min_exptime <= et <= max_exptime):
            if verbose:
                print(f'SKIP (exptime={et}): {cal_path.name}')
            continue

        # ── per-cube spectral resampling ──────────────────────────────────────
        kwargs = dict(v_geo_grid_kwargs)
        if spectral_resamples_fn is not None:
            wl = cal['suffix']['bottom'][:, 0, 0]
            kwargs['spectral_resamples'] = spectral_resamples_fn(wl)

        # ── call v_geo_grid ───────────────────────────────────────────────────
        try:
            result = v_geo_grid(cal, geo, **kwargs)
        except RuntimeError as exc:
            if verbose:
                print(f'SKIP (v_geo_grid: {exc}): {cal_path.name}')
            continue
        except Exception as exc:
            if verbose:
                print(f'SKIP (error: {exc}): {cal_path.name}')
            continue

        # ── accumulate ────────────────────────────────────────────────────────
        g = result['grid']
        if total_grid is None:
            total_grid = np.zeros(g.shape, dtype=np.float64)
            count_grid = np.zeros(g.shape, dtype=np.int64)
            axes = {k: result[k] for k in ('x_axis', 'y_axis', 'x_edges', 'y_edges')}

        mask = np.isfinite(g)
        total_grid[mask] += g[mask]
        count_grid       += mask

        # ── metadata ──────────────────────────────────────────────────────────
        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            date = scet2jul(str(lbl['SPACECRAFT_CLOCK_START_COUNT'])) - _REFERENCE_DATE
        fnamelist.append(cal_path.name)
        fdatelist.append(date)

        if verbose:
            n_cells = int(mask.sum())
            print(f'OK: {cal_path.name}  ({n_cells} non-NaN cells)')

    if total_grid is None:
        raise RuntimeError('No files were successfully processed')

    avg_grid = np.where(count_grid > 0, total_grid / count_grid, np.nan)

    return {
        'grid':      avg_grid,
        'total':     total_grid,
        'count':     count_grid,
        'fnamelist': fnamelist,
        'fdatelist': np.asarray(fdatelist),
        **axes,
    }


# ── Exclude lists ─────────────────────────────────────────────────────────────

_EXCLUDE_BASE = frozenset({
    '0042_00', '0040_00', '0520_04', '0520_06', '0385_07', '0444_08',
    '0505_05', '0503_07', '0024_00', '0027_00', '0076_18', '0095_18',
    '0096_18', '0098_18', '0108_02', '0139_16', '0453_08', '0458_09',
    '0459_09', '0463_08', '0600_02', '0602_02', '0521_04', '0521_05',
    '0757_00', '0871_04', '0875_04', '0344_03', '0339_06', '0333_00',
    '0342_04', '0390_10', '0390_09', '0332_03', '0341_06', '0340_06',
    '0331_03', '0342_06', '0346_05', '0343_06', '0300_04', '0380_02',
    '0325_03', '0579_04', '0302_00', '0479_03', '0112_01', '0102_15',
    '0366_03', '0307_02', '0335_00', '0345_06', '0347_06', '0349_06',
    '0348_04', '0381_05', '0380_06', '0476_03', '0479_05', '0298_03',
    '0332_06', '0334_03', '0335_06', '0337_06', '0337_04', '0336_07',
    '0137_15', '0467_02', '0337_03', '0374_05', '0090_06', '0094_18',
    '0097_19', '0100_15', '0317_',   '0567_',   '0501_',   '0000_',
    '0005_',   '0420_',   '0155_01',
})

# co_ratio229_interp adds a few more problematic files
_EXCLUDE_CO229 = _EXCLUDE_BASE | frozenset({
    '0044_02', '0276_02', '0276_05', '0292_07', '0422_04',
})


# ── Workflow wrappers ─────────────────────────────────────────────────────────

def co_230232_longitude_nightside_5x5(cal_files, geo_files, verbose=True):
    """
    CO band ratio 2.30/2.32 µm, 5°×5° longitude/latitude grid, nightside.

    Parameters match accumulated_projection_CO_230232_longitude_nightside_5x5.pro.
    """
    return accumulated_projection(
        cal_files,
        geo_files,
        v_geo_grid_kwargs=dict(
            index_band=136,
            index_ratio=138,
            use_lt=False,
            x_range=(0.0, 360.0),
            y_range=(-90.0, 90.0),
            x_size=72,
            y_size=36,
            average=False,
            median_filter=True,
            only_positive=True,
            min_emergence=0.0,
            max_emergence=75.0,
            min_incidence=100.0,
            max_incidence=180.0,
            min_elevation=-999.0,
            max_elevation=100.0,
            min_input=0.01,
            max_input=999.0,
            min_value=-999.0,
            max_value=999.0,
        ),
        exclude_ids=_EXCLUDE_BASE,
        min_science_case=1,
        max_science_case=3,
        min_exptime=0.1,
        max_exptime=20.0,
        verbose=verbose,
    )


def co_ratio229_interp(cal_files, geo_files, verbose=True):
    """
    CO ratio 2.29/2.32 µm with CO spectral interpolation, 1°×1° longitude grid.

    Parameters match accumulated_projection_co_ratio229_interp.pro.
    Applies make_co_resample(wl, mode=1) per cube.
    """
    return accumulated_projection(
        cal_files,
        geo_files,
        v_geo_grid_kwargs=dict(
            index_band=133,
            index_ratio=136,
            use_lt=False,
            x_range=(0.0, 360.0),
            y_range=(-90.0, 90.0),
            x_size=360,
            y_size=180,
            average=True,
            median_filter=True,
            only_positive=True,
            min_emergence=0.0,
            max_emergence=85.0,
            min_incidence=100.0,
            max_incidence=180.0,
            min_elevation=-999.0,
            max_elevation=100.0,
            min_input=0.02,
            max_input=999.0,
            min_value=-999.0,
            max_value=999.0,
            min_temperature=150.0,
            max_temperature=165.0,
        ),
        spectral_resamples_fn=lambda wl: [make_co_resample(wl, mode=1)],
        exclude_ids=_EXCLUDE_CO229,
        min_science_case=2,
        max_science_case=3,
        min_exptime=0.0,
        max_exptime=20.0,
        verbose=verbose,
    )
