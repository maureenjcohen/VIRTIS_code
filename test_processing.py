"""
Validation tests for processing utility functions.
Run with:  conda run -n virtis python test_processing.py
"""

import numpy as np
from pathlib import Path

from pds.virtispds import virtispds
from processing.planck import planck
from processing.v_crop_cube import v_crop_cube
from processing.rad_to_rayleigh import rad_to_rayleigh
from processing.emission_angle_correction import (
    correct_general, correct_1_27, correct_1_31,
    correct_1_74, correct_2_3, correct_3_8, correct_5_0,
)
from processing.interpintegrate import interp_integrate
from processing.incidence_angle_correction import (
    correct_incidence, ia_corr, correct_ia_ea,
)
from processing.phase_angle_correction import correct_phase_angle
from processing.filters import amedian, hv_filter
from processing.time_utils import jul2scet, scet2jul, jul2utc, utc2jul, orbit2mtp
from processing.planck import brightness_temperature
from processing.v_geo_grid import (
    v_geo_grid, make_co_resample, make_h2o_resample,
    _build_axes, _bin_average,
)
from processing.accumulated_projection import (
    accumulated_projection,
    co_230232_longitude_nightside_5x5,
    co_ratio229_interp,
)

CAL  = Path('test_data/cubes/VIR0093/CALIBRATED/VI0093_00.CAL')
GEO  = Path('test_data/cubes/VIR0093/GEOMETRY/VI0093_00.GEO')
CAL1 = Path('test_data/cubes/VIR0093/CALIBRATED/VI0093_01.CAL')
GEO1 = Path('test_data/cubes/VIR0093/GEOMETRY/VI0093_01.GEO')


def check(condition, msg):
    print(f'  [{"PASS" if condition else "FAIL"}] {msg}')
    return condition


# ── planck ────────────────────────────────────────────────────────────────────
def test_planck():
    print('\n=== planck ===')
    # At 2.3 µm (2.3e-6 m), 250 K: should be a small positive number
    R = planck(250, 2.3e-6)
    check(R > 0, f'planck(250 K, 2.3 µm) > 0  [got {R:.4e}]')

    # At 6000 K (solar), peak near 0.5 µm → should be much larger at 0.5 µm than 5 µm
    R_vis = planck(6000, 0.5e-6)
    R_ir  = planck(6000, 5.0e-6)
    check(R_vis > R_ir, f'solar peak: B(0.5µm) > B(5µm)  [{R_vis:.3e} vs {R_ir:.3e}]')

    # Vienna (2.898e-3 / T) peaks should match Wien's law
    T    = 300.0
    wl   = np.linspace(1e-6, 20e-6, 10000)
    R    = planck(T, wl)
    peak = wl[np.argmax(R)] * 1e6  # µm
    expected = 2.898e-3 / T * 1e6   # µm
    check(abs(peak - expected) / expected < 0.01,
          f"Wien peak at {peak:.2f} µm  [expected {expected:.2f} µm]")


# ── v_crop_cube ───────────────────────────────────────────────────────────────
def test_crop_cube():
    print('\n=== v_crop_cube ===')
    cal = virtispds(CAL)
    cube = cal['qube']   # (432, 256, 289)

    cropped, ns, nl = v_crop_cube(cube, scan_mode_id=1)

    # First line removed, then lines clamped to min(256,289)-1 = 255
    # First 6 samples removed → 250 samples
    check(cropped.shape == (432, 250, 255),
          f'cropped shape == (432, 250, 255)  [got {cropped.shape}]')
    check(ns == 250, f'returned n_samples == 250  [got {ns}]')
    check(nl == 255, f'returned n_lines   == 255  [got {nl}]')

    # Content check: cropped[b, 0, 0] should equal original[b, 6, 1]
    check(np.allclose(cropped[0, 0, 0], cube[0, 6, 1], equal_nan=True),
          'cropped[0,0,0] == original[0,6,1]  (correct offset)')


# ── rad_to_rayleigh ───────────────────────────────────────────────────────────
def test_rad_to_rayleigh():
    print('\n=== rad_to_rayleigh ===')
    cal = virtispds(CAL)
    cube = cal['qube']                           # (432, 256, 289)
    wl   = cal['suffix']['bottom'][:, 0, 0]     # wavelengths from bottomplane (µm)

    rayleigh = rad_to_rayleigh(cube, wl)

    check(rayleigh.shape == cube.shape,
          f'output shape preserved  [{rayleigh.shape}]')
    check(rayleigh.dtype == np.float64,
          f'output dtype float64  [{rayleigh.dtype}]')

    # Factor for band 135 (~2.3 µm):
    #   1.9864867 * pi * 2.3 * 1e9 * 9.46673e-3 * 1e-6 ≈ 0.1364
    import math
    expected_factor = 1.9864867 * math.pi * float(wl[135]) * 1e9 * 9.46673e-3 * 1e-6
    ratio = float(rayleigh[135, 128, 144]) / float(cube[135, 128, 144]) if cube[135, 128, 144] != 0 else np.nan
    check(abs(ratio - expected_factor) / expected_factor < 1e-6,
          f'conversion factor at band 135  [got {ratio:.6f}, expected {expected_factor:.6f}]')


# ── emission angle corrections ────────────────────────────────────────────────
def test_emission_angle_corrections():
    print('\n=== emission_angle_corrections ===')
    geo = virtispds(GEO)
    ema = geo['qube'][27] * geo['qube_coeff'][27]   # emergence angle (samples, lines)

    cube = np.ones((5, *ema.shape), dtype=np.float64)   # flat radiance = 1.0

    # ── 1.27 µm: R * cos(θ) / (1 + 1.75*cos(θ)) ─────────────────────────
    c27 = correct_1_27(cube, ema)
    cos_val = float(np.cos(np.radians(ema[0, 0])))
    expected = cos_val / (1 + 1.75 * cos_val)
    check(abs(float(c27[0, 0, 0]) - expected) < 1e-10,
          f'correct_1_27: value at [0,0,0]  [got {float(c27[0,0,0]):.6f}, '
          f'expected {expected:.6f}]')
    check(c27.shape == cube.shape, f'correct_1_27: shape preserved')

    # ── 1.74 µm: R / (0.34 + 0.66*cos(θ)) ───────────────────────────────
    c174 = correct_1_74(cube, ema)
    expected = 1.0 / (0.34 + 0.66 * cos_val)
    check(abs(float(c174[0, 0, 0]) - expected) < 1e-10,
          f'correct_1_74: value at [0,0,0]  [got {float(c174[0,0,0]):.6f}, '
          f'expected {expected:.6f}]')

    # ── 2.3 µm: R / (0.232 + 0.768*cos(θ)) ──────────────────────────────
    c23 = correct_2_3(cube, ema)
    expected = 1.0 / (0.232 + 0.768 * cos_val)
    check(abs(float(c23[0, 0, 0]) - expected) < 1e-10,
          f'correct_2_3:  value at [0,0,0]  [got {float(c23[0,0,0]):.6f}, '
          f'expected {expected:.6f}]')

    # ── 3.8 µm: R / (0.13 + 0.87*cos(θ)) ────────────────────────────────
    c38 = correct_3_8(cube, ema)
    expected = 1.0 / (0.13 + 0.87 * cos_val)
    check(abs(float(c38[0, 0, 0]) - expected) < 1e-10,
          f'correct_3_8:  value at [0,0,0]  [got {float(c38[0,0,0]):.6f}, '
          f'expected {expected:.6f}]')

    # ── 5.0 µm: R / (0.20 + 0.80*cos(θ)) ────────────────────────────────
    c50 = correct_5_0(cube, ema)
    expected = 1.0 / (0.20 + 0.80 * cos_val)
    check(abs(float(c50[0, 0, 0]) - expected) < 1e-10,
          f'correct_5_0:  value at [0,0,0]  [got {float(c50[0,0,0]):.6f}, '
          f'expected {expected:.6f}]')

    # ── 1.31 µm: R * cos(θ) / (0.31 + 0.69*cos(θ)) ─────────────────────────
    c131 = correct_1_31(cube, ema)
    expected = cos_val / (0.31 + 0.69 * cos_val)
    check(abs(float(c131[0, 0, 0]) - expected) < 1e-10,
          f'correct_1_31: value at [0,0,0]  [got {float(c131[0,0,0]):.6f}, '
          f'expected {expected:.6f}]')
    check(c131.shape == cube.shape, f'correct_1_31: shape preserved')

    # ── general: R / cos(θ) * cos(min_θ per scan line) ───────────────────
    c_gen = correct_general(cube, ema)
    min_ema_line0 = float(np.nanmin(np.radians(ema[:, 0])))
    cos_min_0 = float(np.cos(min_ema_line0))
    expected_gen = (1.0 / cos_val) * cos_min_0
    check(abs(float(c_gen[0, 0, 0]) - expected_gen) < 1e-10,
          f'correct_general: value at [0,0,0]  [got {float(c_gen[0,0,0]):.6f}, '
          f'expected {expected_gen:.6f}]')
    check(c_gen.shape == cube.shape, 'correct_general: shape preserved')
    # pixel at the per-line minimum ema should equal cos_min/cos_min = 1.0
    min_s = int(np.nanargmin(ema[:, 0]))
    check(np.allclose(c_gen[:, min_s, 0], 1.0, atol=1e-10),
          'correct_general: pixel at min-ema of line 0 equals 1.0')

    # All corrections should leave ema=0 unchanged (cos=1 → identity at 1.27µm → not 1)
    # but for ema=0 the 2.3µm correction = 1/(0.232+0.768) = 1.0 exactly
    cube_zero = np.ones((3, 10, 10))
    result = correct_2_3(cube_zero, np.zeros((10, 10)))
    check(np.allclose(result, 1.0),
          'correct_2_3 at ema=0°: output == 1.0  (0.232+0.768=1)')


# ── interp_integrate ──────────────────────────────────────────────────────────
def test_interp_integrate():
    print('\n=== interp_integrate ===')

    # Test 1: linear y=x — bin averages should reproduce new_x values exactly
    x     = np.linspace(0, 10, 11)
    y     = x.copy()
    new_x = np.linspace(1, 9, 9)
    result = interp_integrate(x, y, new_x)
    check(np.allclose(result, new_x, atol=1e-9),
          'linear y=x: bin-averaged values == new_x')

    # Test 2: outside-range returns zeros
    out = interp_integrate(x, y, np.array([20.0, 21.0, 22.0]))
    check(np.allclose(out, 0.0),
          'outside range: result == 0')

    # Test 3: 2-D input — all rows resampled consistently
    y2d = np.vstack([x, 2*x, 3*x])   # (3, 11)
    result2d = interp_integrate(x, y2d, new_x)
    check(result2d.shape == (3, len(new_x)),
          f'2-D input: output shape == (3, {len(new_x)})  [got {result2d.shape}]')
    check(np.allclose(result2d[0], new_x, atol=1e-9) and
          np.allclose(result2d[1], 2*new_x, atol=1e-9) and
          np.allclose(result2d[2], 3*new_x, atol=1e-9),
          '2-D linear: each row scales correctly')

    # Test 4: integral conservation for a Gaussian (coarse grid)
    x_fine  = np.linspace(-10, 10, 1001)
    y_fine  = np.exp(-x_fine**2 / 8)   # Gaussian σ=2
    x_coarse = np.linspace(-10, 10, 51)
    y_coarse = interp_integrate(x_fine, y_fine, x_coarse)
    integral_orig   = np.trapezoid(y_fine,   x_fine)
    integral_coarse = np.trapezoid(y_coarse, x_coarse)
    rel_err = abs(integral_orig - integral_coarse) / integral_orig
    check(rel_err < 1e-4,
          f'Gaussian integral conservation: rel error {rel_err:.2e} < 1e-4')

    # Test 5: ind1/ind2 subsetting
    sub = interp_integrate(x, y, new_x, ind1=2, ind2=5)
    check(len(sub) == 4,
          f'ind1=2, ind2=5: output length == 4  [got {len(sub)}]')
    check(np.allclose(sub, new_x[2:6], atol=1e-9),
          'ind1/ind2 subset: values match full call subset')

    # Test 6: do_check — integral conservation flag (matches IDL interpIntegrate_check.pro)
    x_c   = np.array([1.0, 2.0, 3.0, 4.0, 5.0])
    y_c   = x_c.copy()
    nx_c  = np.array([2.0, 3.0, 4.0])
    # do_check=True returns (result, rel_diff) for 1-D input
    out_c, rel_diff = interp_integrate(x_c, y_c, nx_c, do_check=True)
    check(np.allclose(out_c, interp_integrate(x_c, y_c, nx_c)),
          'do_check: result array unchanged vs normal call')
    check(np.isfinite(rel_diff),
          f'do_check: rel_diff is finite [{rel_diff}]')
    # original: trapz([1,2,3,4,5]) = 12.0; new: trapz([2,3,4]) = 6.0 → rel_diff = 0.5
    check(np.isclose(rel_diff, 0.5),
          f'do_check: rel_diff ≈ 0.5 for partial new_x [{rel_diff:.4f}]')
    # full-range new_x on same linear data → conservation close to zero
    _, rel_diff_full = interp_integrate(x_c, y_c, x_c, do_check=True)
    check(abs(rel_diff_full) < 0.01,
          f'do_check: full-range rel_diff near zero [{rel_diff_full:.2e}]')


# ── incidence_angle_correction ────────────────────────────────────────────────
def test_incidence_angle_correction():
    print('\n=== incidence_angle_correction ===')
    cal = virtispds(CAL)
    geo = virtispds(GEO)
    cube = cal['qube'].astype(np.float64)   # (432, 256, 289)
    ema  = geo['qube'][27] * geo['qube_coeff'][27]
    inc  = geo['qube'][26] * geo['qube_coeff'][26]

    # ── correct_incidence: min of samples 8–30 per (band, line) → 0 ──────
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', RuntimeWarning)
        corrected = correct_incidence(cube)
        ref_min   = np.nanmin(corrected[:, 8:31, :], axis=1)   # (nb, nl); NaN where all-NaN slice
    check(corrected.shape == cube.shape, 'correct_incidence: shape preserved')
    check(corrected.dtype == np.float64,  'correct_incidence: dtype float64')
    finite_ref = ref_min[np.isfinite(ref_min)]
    check(len(finite_ref) > 0 and np.all(finite_ref <= 1e-12),
          'correct_incidence: min(samples 8–30) ≤ 0 for all finite (band,line) slices')

    # ── ia_corr: single-band, shape (samples, lines) ──────────────────────
    result = ia_corr(cal, geo, band=291)
    check(result.shape == (cube.shape[1], cube.shape[2]),
          f'ia_corr: shape == (256, 289)  [got {result.shape}]')
    check(result.dtype == np.float64, 'ia_corr: dtype float64')

    # ── correct_ia_ea: formula check at a known valid pixel (s=66, l=101) ──
    S, L = 66, 101
    c_ia_ea = correct_ia_ea(cube, inc, ema)
    check(c_ia_ea.shape == cube.shape, 'correct_ia_ea: shape preserved')
    cos_ia   = float(np.cos(np.radians(inc[S, L])))
    cos_ea   = float(np.cos(np.radians(ema[S, L])))
    expected = float(cube[135, S, L]) / cos_ia / (cos_ea ** 0.25)
    check(abs(float(c_ia_ea[135, S, L]) - expected) < 1e-10,
          f'correct_ia_ea: value at [135,{S},{L}]  '
          f'[got {float(c_ia_ea[135,S,L]):.6f}, expected {expected:.6f}]')


# ── phase_angle_correction ────────────────────────────────────────────────────
def test_phase_angle_correction():
    print('\n=== phase_angle_correction ===')
    cal = virtispds(CAL)
    geo = virtispds(GEO)
    cube = cal['qube'].astype(np.float64)
    pa   = geo['qube'][28] * geo['qube_coeff'][28]   # phase angle (samples, lines)

    result = correct_phase_angle(cube, pa)
    check(result.shape == cube.shape, 'correct_phase_angle: shape preserved')
    check(result.dtype == np.float64,  'correct_phase_angle: dtype float64')

    S, L = 66, 101
    sin_pa   = float(np.sin(np.radians(pa[S, L])))
    expected = float(cube[135, S, L]) / sin_pa
    check(abs(float(result[135, S, L]) - expected) < 1e-10,
          f'correct_phase_angle: value at [135,{S},{L}]  '
          f'[got {float(result[135,S,L]):.6f}, expected {expected:.6f}]')


# ── filters ───────────────────────────────────────────────────────────────────
def test_filters():
    print('\n=== filters ===')

    # ── amedian: 1-D ──────────────────────────────────────────────────────
    arr1d = np.array([1., 5., 2., 8., 3., 7., 4.])
    out1d = amedian(arr1d, 3)
    check(out1d.shape == arr1d.shape, 'amedian 1-D: shape preserved')
    check(out1d.dtype == np.float64,   'amedian 1-D: dtype float64')
    # constant array → unchanged
    const = np.full(20, 3.0)
    check(np.allclose(amedian(const, 5), 3.0),
          'amedian: constant array unchanged')

    # ── amedian: 2-D ──────────────────────────────────────────────────────
    rng   = np.random.default_rng(0)
    arr2d = rng.standard_normal((30, 40))
    out2d = amedian(arr2d, 3)
    check(out2d.shape == arr2d.shape, 'amedian 2-D: shape preserved')
    # interior pixels should equal a standard median filter
    from scipy.ndimage import median_filter
    ref2d = median_filter(arr2d, size=3, mode='mirror')
    check(np.allclose(out2d, ref2d),
          'amedian 2-D: matches scipy median_filter(mode="mirror")')

    # ── hv_filter ─────────────────────────────────────────────────────────
    # flat (constant) cube → zero gradient → zero output
    flat = np.ones((5, 20, 20))
    out_flat = hv_filter(flat)
    check(out_flat.shape == flat.shape, 'hv_filter: shape preserved')
    check(out_flat.dtype == np.float64,  'hv_filter: dtype float64')
    check(np.allclose(out_flat, 0.0),
          'hv_filter: constant input → zero output')

    # non-constant input → non-trivially different from input
    cal  = virtispds(CAL)
    band = cal['qube'][[135]].astype(np.float64)   # (1, 256, 289)
    out_band = hv_filter(band)
    check(not np.allclose(out_band, band),
          'hv_filter: non-constant input produces non-trivial output')


# ── time_utils ───────────────────────────────────────────────────────────────
def test_time_utils():
    import warnings
    print('\n=== time_utils ===')

    # ── jul2utc / utc2jul round-trip ──────────────────────────────────────
    # J2000 epoch: JD 2451545.0 = 2000-01-01T12:00:00.000
    jd_j2000 = 2451545.0
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        utc = jul2utc(jd_j2000)
    check(utc.startswith('2000-01-01T12:00:00'),
          f'jul2utc: J2000 → "2000-01-01T12:00:00..."  [got "{utc}"]')

    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        jd_rt = utc2jul(utc)
    check(abs(jd_rt - jd_j2000) < 1e-9,
          f'utc2jul(jul2utc(J2000)) round-trip  [Δ = {abs(jd_rt - jd_j2000):.2e} days]')

    # utc2jul with trailing Z
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        jd_z = utc2jul('2000-01-01T12:00:00.000Z')
    check(abs(jd_z - jd_j2000) < 1e-9,
          'utc2jul: accepts trailing Z')

    # utc2jul with bad string returns 0.0
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        jd_bad = utc2jul('not-a-date')
    check(jd_bad == 0.0, 'utc2jul: bad string returns 0.0')

    # ── jul2scet / scet2jul round-trip (VEX) ─────────────────────────────
    # VEX epoch: 2005-03-01T00:00:00 → SCET 0.  Pick a date ~2 years later.
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        jd_test  = utc2jul('2007-05-01T06:30:00.000')
        scet_str = jul2scet(jd_test, mission='VEX')
        jd_back  = scet2jul(scet_str, mission='VEX')

    # SCET string should start with "0" (year 2, seconds ~68M)
    check(scet_str[0].isdigit(),
          f'jul2scet: returns digit string  [got "{scet_str}"]')
    # Format: 11 integer digits + '.' + 5 fractional digits
    parts = scet_str.split('.')
    check(len(parts) == 2 and len(parts[0]) == 11 and len(parts[1]) == 5,
          f'jul2scet: OBET format "SSSSSSSSSSS.TTTTT"  [got "{scet_str}"]')
    # Round-trip within one SCET tick (1/65536 s ≈ 1.8e-10 days)
    check(abs(jd_back - jd_test) < 2 / 65536 / 86400,
          f'scet round-trip error  [Δ = {abs(jd_back - jd_test)*86400:.2e} s]')

    # VEX epoch itself → SCET "00000000000.00000"
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        jd_vex_orig = utc2jul('2005-03-01T00:00:00.000')
        scet_orig   = jul2scet(jd_vex_orig, mission='VEX')
    check(scet_orig == '00000000000.00000',
          f'jul2scet: VEX epoch → "00000000000.00000"  [got "{scet_orig}"]')

    # partition keyword prepends "1/"
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        scet_p = jul2scet(jd_vex_orig, mission='VEX', partition=1)
    check(scet_p.startswith('1/'),
          f'jul2scet: partition=1 prepends "1/"  [got "{scet_p}"]')

    # scet2jul: partition prefix is stripped
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        jd_p = scet2jul(scet_p, mission='VEX')
    check(abs(jd_p - jd_vex_orig) < 2 / 65536 / 86400,
          'scet2jul: partition-prefixed string round-trips correctly')

    # as_string=False returns a float
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        scet_f = jul2scet(jd_vex_orig, as_string=False)
    check(isinstance(scet_f, float) and scet_f == 0.0,
          f'jul2scet: as_string=False at epoch → 0.0  [got {scet_f}]')

    # ── orbit2mtp ─────────────────────────────────────────────────────────
    check(orbit2mtp(0)    == -1, 'orbit2mtp(0) == -1  (VOI)')
    check(orbit2mtp(5)    == -2, 'orbit2mtp(5) == -2  (VOCP)')
    check(orbit2mtp(16)   ==  1, 'orbit2mtp(16) == 1  (MTP001, first normal orbit)')
    check(orbit2mtp(43)   ==  1, 'orbit2mtp(43) == 1  (MTP001, last orbit)')
    check(orbit2mtp(44)   ==  2, 'orbit2mtp(44) == 2  (MTP002, first orbit)')
    check(orbit2mtp(93)   ==  3, 'orbit2mtp(93) == 3  (orbit-93 test data)')
    check(orbit2mtp(9999) == -3, 'orbit2mtp(9999) == -3  (CRUISE)')
    check(orbit2mtp(-1)   == -4, 'orbit2mtp(-1) == -4  (invalid)')

    check(orbit2mtp(0,    as_string=True) == 'VOI',    'orbit2mtp(0,    str) == "VOI"')
    check(orbit2mtp(5,    as_string=True) == 'VOCP',   'orbit2mtp(5,    str) == "VOCP"')
    check(orbit2mtp(16,   as_string=True) == 'MTP001', 'orbit2mtp(16,   str) == "MTP001"')
    check(orbit2mtp(9999, as_string=True) == 'CRUISE', 'orbit2mtp(9999, str) == "CRUISE"')
    check(orbit2mtp(-1,   as_string=True) == '',       'orbit2mtp(-1,   str) == ""')

    # array input
    arr = orbit2mtp(np.array([0, 16, 44, 9999]), as_string=True)
    check(list(arr) == ['VOI', 'MTP001', 'MTP002', 'CRUISE'],
          f'orbit2mtp array  [got {list(arr)}]')


# ── brightness_temperature ────────────────────────────────────────────────────
def test_brightness_temperature():
    print('\n=== brightness_temperature ===')
    # Roundtrip: brightness_temperature(planck(T, wl), wl_um) should recover T
    from processing.planck import planck
    T_in = 280.0
    wl_um = np.array([1.74, 2.30, 3.80])
    wl_m  = wl_um * 1e-6
    R = planck(T_in, wl_m)   # (3,) W/m²/µm/sr
    cube = R[:, np.newaxis, np.newaxis] * np.ones((3, 4, 5))
    T_out = brightness_temperature(cube, wl_um)
    check(T_out.shape == (3, 4, 5), f'shape {T_out.shape} == (3,4,5)')
    check(np.allclose(T_out, T_in, rtol=1e-5),
          f'roundtrip T: max err {np.abs(T_out - T_in).max():.4f} K')
    # R=0 → T_B = 0 K (log1p(inf) = inf; numerator/inf = 0)
    bad = np.zeros((1, 2, 2))
    T_bad = brightness_temperature(bad, np.array([2.3]))
    check(np.all(T_bad == 0.0), f'R=0 → T_B=0 K  [got min={T_bad.min()}, max={T_bad.max()}]')


# ── v_geo_grid Stage 2: per-pixel corrections ─────────────────────────────────
def test_v_geo_grid_corrections():
    print('\n=== v_geo_grid corrections ===')
    cal = virtispds(CAL1)
    geo = virtispds(GEO1)
    wl  = cal['suffix']['bottom'][:, 0, 0]

    # Helper: small grid, single band, no frills
    def grid0(**kw):
        return v_geo_grid(cal, geo, index_band=76, x_size=12, y_size=9, **kw)

    base = grid0()
    base_vals = base['grid'][np.isfinite(base['grid'])]

    check(base['grid'].shape == (9, 12), f'base grid shape {base["grid"].shape}')
    check(len(base_vals) > 0, f'base has {len(base_vals)} finite cells')

    # ── Each EMA key produces a different result ──────────────────────────────
    for key in ('general', '1.27', '1.31', '1.74', '2.3', '3.8', '5.0'):
        r = grid0(emission_angle=key)
        vals = r['grid'][np.isfinite(r['grid'])]
        check(len(vals) > 0 and not np.allclose(vals, base_vals, equal_nan=True),
              f"emission_angle='{key}' differs from uncorrected")

    # ── post_ema=False path — must produce a valid grid ───────────────────────
    # For single-band linear corrections, pre and post EMA are mathematically
    # identical; we only verify the path runs without error and the count
    # matches the post-EMA equivalent.
    r_pre  = grid0(emission_angle='general', post_ema=False)
    r_post = grid0(emission_angle='general', post_ema=True)
    pre_v  = r_pre ['grid'][np.isfinite(r_pre ['grid'])]
    post_v = r_post['grid'][np.isfinite(r_post['grid'])]
    check(len(pre_v) > 0, f'post_ema=False: {len(pre_v)} finite cells')
    check(np.allclose(pre_v, post_v, equal_nan=True),
          'single-band linear EMA: pre == post (expected for linear correction)')

    # ── Rayleigh conversion ───────────────────────────────────────────────────
    r_ray = grid0(rayleigh=True)
    ray_v = r_ray['grid'][np.isfinite(r_ray['grid'])]
    check(len(ray_v) > 0 and not np.allclose(ray_v, base_vals, equal_nan=True),
          'rayleigh=True differs from uncorrected')
    # Rayleigh values are MR and should be much larger than W/m²/µm/sr
    check(ray_v.mean() > base_vals.mean(),
          f'rayleigh mean {ray_v.mean():.3e} > base mean {base_vals.mean():.3e}')

    # ── Continuum subtraction ─────────────────────────────────────────────────
    # band 60 (~1.94 µm) as a continuum near the 2.3-µm window (band 76)
    r_cont = grid0(index_continuum=60)
    cont_v = r_cont['grid'][np.isfinite(r_cont['grid'])]
    check(len(cont_v) > 0 and not np.allclose(cont_v, base_vals, equal_nan=True),
          'index_continuum=60 differs from uncorrected')

    # ── Thermal subtraction ───────────────────────────────────────────────────
    # Use band 60 as thermal, ratio=0.5
    r_th = grid0(index_thermal=60, thermal_ratio=0.5)
    th_v = r_th['grid'][np.isfinite(r_th['grid'])]
    check(len(th_v) > 0 and not np.allclose(th_v, base_vals, equal_nan=True),
          'index_thermal+thermal_ratio differs from uncorrected')

    # ── average=False (integration) ───────────────────────────────────────────
    r_sum = grid0(average=False)
    sum_v = r_sum['grid'][np.isfinite(r_sum['grid'])]
    # sum of one band equals mean — should be identical
    check(np.allclose(sum_v, base_vals, equal_nan=True),
          'average=False with single band equals average=True')

    # ── Multi-band averaging ──────────────────────────────────────────────────
    r_multi = v_geo_grid(cal, geo, index_band=[74, 75, 76, 77, 78],
                         x_size=12, y_size=9)
    multi_v = r_multi['grid'][np.isfinite(r_multi['grid'])]
    check(len(multi_v) > 0 and not np.allclose(multi_v, base_vals, equal_nan=True),
          'multi-band average differs from single band')

    # ── Band ratio ────────────────────────────────────────────────────────────
    r_ratio = v_geo_grid(cal, geo, index_band=76, index_ratio=60,
                         x_size=12, y_size=9)
    ratio_v = r_ratio['grid'][np.isfinite(r_ratio['grid'])]
    check(len(ratio_v) > 0 and not np.allclose(ratio_v, base_vals, equal_nan=True),
          'index_ratio=60 differs from uncorrected')

    # ── Median filter ─────────────────────────────────────────────────────────
    r_med = grid0(median_filter=True)
    med_v = r_med['grid'][np.isfinite(r_med['grid'])]
    check(len(med_v) > 0, f'median_filter has {len(med_v)} finite cells')

    # ── Spectral resamples (CO window) ────────────────────────────────────────
    co_rs  = make_co_resample(wl, mode=1)
    r_co   = v_geo_grid(cal, geo, index_band=134,
                        spectral_resamples=[co_rs], x_size=12, y_size=9)
    co_v   = r_co['grid'][np.isfinite(r_co['grid'])]
    r_base = v_geo_grid(cal, geo, index_band=134, x_size=12, y_size=9)
    base_co_v = r_base['grid'][np.isfinite(r_base['grid'])]
    check(len(co_v) > 0 and not np.allclose(co_v, base_co_v, equal_nan=True),
          'CO spectral_resamples changes values vs no resampling')

    # ── H2O spectral resamples ────────────────────────────────────────────────
    h2o_rs = make_h2o_resample(wl, mode=1)
    r_h2o  = v_geo_grid(cal, geo, index_band=161,
                        spectral_resamples=[h2o_rs], x_size=12, y_size=9)
    h2o_v  = r_h2o['grid'][np.isfinite(r_h2o['grid'])]
    r_baseh = v_geo_grid(cal, geo, index_band=161, x_size=12, y_size=9)
    base_h2o_v = r_baseh['grid'][np.isfinite(r_baseh['grid'])]
    check(len(h2o_v) > 0 and not np.allclose(h2o_v, base_h2o_v, equal_nan=True),
          'H2O spectral_resamples changes values vs no resampling')

    # ── Thermal brightness ────────────────────────────────────────────────────
    r_tb = grid0(thermal_brightness=True)
    tb_v = r_tb['grid'][np.isfinite(r_tb['grid'])]
    check(len(tb_v) > 0, f'thermal_brightness: {len(tb_v)} finite cells')
    # Brightness temperature at 2.3 µm for Venus nightside ~200-300 K
    check(100.0 < tb_v.mean() < 600.0,
          f'thermal_brightness mean {tb_v.mean():.1f} K in (100, 600)')
    check(not np.allclose(tb_v, base_vals, equal_nan=True),
          'thermal_brightness differs from radiance')

    # ── geo_band path (grid a geometry channel) ───────────────────────────────
    r_geo = v_geo_grid(cal, geo, geo_band=25, x_size=12, y_size=9)  # cloud latitude
    geo_v = r_geo['grid'][np.isfinite(r_geo['grid'])]
    check(len(geo_v) > 0, f'geo_band=25 has {len(geo_v)} finite cells')
    # Gridded cloud latitude should be in [-90, 90]
    check(geo_v.min() >= -90.0 and geo_v.max() <= 90.0,
          f'geo_band lat in [-90,90]: [{geo_v.min():.1f}, {geo_v.max():.1f}]')

    # ── Longitude grid ────────────────────────────────────────────────────────
    r_lon = v_geo_grid(cal, geo, index_band=76, use_lt=False, x_size=36, y_size=18)
    check(r_lon['grid'].shape == (18, 36), f'longitude grid shape {r_lon["grid"].shape}')

    # ── Pixel filters: nightside / dayside ───────────────────────────────────
    # Orbit 93 may be fully dayside so nightside can legitimately return no pixels.
    try:
        r_night     = grid0(nightside=True)
        night_count = r_night['count'].sum()
    except RuntimeError:
        night_count = 0
    try:
        r_day     = grid0(dayside=True)
        day_count = r_day['count'].sum()
    except RuntimeError:
        day_count = 0
    total_count = base['count'].sum()
    check(night_count + day_count <= total_count,
          f'nightside({night_count}) + dayside({day_count}) ≤ total({total_count})')

    # ── count array sums to number of valid pixels ────────────────────────────
    check(base['count'].sum() == base['count'][base['count'] > 0].sum(),
          'count.sum() is consistent')
    # verify count matches grid finite cells
    check((base['count'] > 0).sum() == np.isfinite(base['grid']).sum(),
          'count>0 cells == finite grid cells')


# ── v_geo_grid Stage 3: axis resolution and bin-average arithmetic ────────────
def test_v_geo_grid_axes():
    print('\n=== v_geo_grid axes (_build_axes) ===')

    # Synthetic data points that span a known range
    x_pts = np.array([1.0, 2.0, 3.0, 4.0, 5.0])
    y_pts = np.array([10.0, 20.0, 30.0, 40.0, 50.0])

    # ── No parameters given: size=512, range = data extent ────────────────────
    xe, ye, xa, ya, nx, ny = _build_axes(
        x_pts, y_pts, None, None, None, None, None, None
    )
    check(nx == 512 and ny == 512, f'no params: size=512 [{nx}x{ny}]')
    check(xe[0] == x_pts.min() and xe[-1] == x_pts.max(),
          f'no params: x_edges span data [{xe[0]}, {xe[-1]}]')
    check(len(xa) == nx and len(ya) == ny,
          f'no params: axis lengths match size [{len(xa)}, {len(ya)}]')

    # ── size only: range = data extent, delta = range/size ───────────────────
    xe, ye, xa, ya, nx, ny = _build_axes(
        x_pts, y_pts, None, None, None, None, 10, 5
    )
    check(nx == 10 and ny == 5, f'size-only: [{nx}x{ny}]')
    check(np.isclose(xe[-1] - xe[0], x_pts.max() - x_pts.min()),
          f'size-only: x_range spans data [{xe[0]:.3f}, {xe[-1]:.3f}]')
    expected_xdelta = (x_pts.max() - x_pts.min()) / 10
    check(np.isclose(xe[1] - xe[0], expected_xdelta),
          f'size-only: x_delta = range/size [{xe[1]-xe[0]:.4f} vs {expected_xdelta:.4f}]')

    # ── range + size: delta computed ──────────────────────────────────────────
    xe, ye, xa, ya, nx, ny = _build_axes(
        x_pts, y_pts, (0.0, 6.0), (-90.0, 90.0), None, None, 6, 18
    )
    check(nx == 6 and ny == 18, f'range+size: [{nx}x{ny}]')
    check(np.isclose(xe[0], 0.0) and np.isclose(xe[-1], 6.0),
          f'range+size: x_edges [{xe[0]}, {xe[-1]}]')
    check(np.isclose(xe[1] - xe[0], 1.0),
          f'range+size: x_delta = 6/6 = 1.0 [{xe[1]-xe[0]:.4f}]')
    check(np.isclose(ye[0], -90.0) and np.isclose(ye[-1], 90.0),
          f'range+size: y_edges [{ye[0]}, {ye[-1]}]')
    check(np.isclose(ye[1] - ye[0], 10.0),
          f'range+size: y_delta = 180/18 = 10.0 [{ye[1]-ye[0]:.4f}]')

    # ── range + delta: size computed ──────────────────────────────────────────
    xe, ye, xa, ya, nx, ny = _build_axes(
        x_pts, y_pts, (0.0, 24.0), (-90.0, 90.0), 2.0, 5.0, None, None
    )
    check(nx == 12, f'range+delta: nx = 24/2 = 12 [{nx}]')
    check(ny == 36, f'range+delta: ny = 180/5 = 36 [{ny}]')
    check(np.isclose(xe[1] - xe[0], 2.0),
          f'range+delta: x_delta preserved [{xe[1]-xe[0]:.4f}]')
    check(np.isclose(ye[1] - ye[0], 5.0),
          f'range+delta: y_delta preserved [{ye[1]-ye[0]:.4f}]')

    # ── delta only: range = data extent, size computed ────────────────────────
    xe, ye, xa, ya, nx, ny = _build_axes(
        x_pts, y_pts, None, None, 1.0, 10.0, None, None
    )
    expected_nx = int(round((x_pts.max() - x_pts.min()) / 1.0))
    check(nx == expected_nx, f'delta-only: nx = round(range/delta)={expected_nx} [{nx}]')
    check(np.isclose(xe[0], x_pts.min()),
          f'delta-only: x_edges start at data min [{xe[0]:.3f}]')

    # ── axis midpoint property: x_axis = midpoints of x_edges ────────────────
    xe, ye, xa, ya, nx, ny = _build_axes(
        x_pts, y_pts, (0.0, 10.0), (-5.0, 5.0), None, None, 5, 4
    )
    expected_xa = 0.5 * (xe[:-1] + xe[1:])
    expected_ya = 0.5 * (ye[:-1] + ye[1:])
    check(np.allclose(xa, expected_xa), 'x_axis are midpoints of x_edges')
    check(np.allclose(ya, expected_ya), 'y_axis are midpoints of y_edges')

    # ── edge lengths are size+1 ───────────────────────────────────────────────
    check(len(xe) == nx + 1 and len(ye) == ny + 1,
          f'edge arrays are size+1 [{len(xe)}, {len(ye)}]')


def test_v_geo_grid_binning():
    print('\n=== v_geo_grid binning (_bin_average) ===')

    # Synthetic: 3 x-bins [0,1,2,3], 2 y-bins [0,1,2]
    x_edges = np.array([0.0, 1.0, 2.0, 3.0])
    y_edges = np.array([0.0, 1.0, 2.0])

    # Two points in the same bin → mean
    x_pts = np.array([0.5, 0.5, 1.5, 2.5])
    y_pts = np.array([0.5, 0.5, 1.5, 0.5])
    z_pts = np.array([10.0, 20.0, 7.0, 5.0])
    grid, count = _bin_average(x_pts, y_pts, z_pts, x_edges, y_edges)

    check(grid.shape == (2, 3),  f'shape (2,3) [{grid.shape}]')
    check(count.shape == (2, 3), f'count shape (2,3) [{count.shape}]')
    check(np.isclose(grid[0, 0], 15.0), f'bin(0,0) mean(10,20)=15 [{grid[0,0]}]')
    check(count[0, 0] == 2,             f'bin(0,0) count=2 [{count[0,0]}]')
    check(np.isclose(grid[1, 1], 7.0),  f'bin(1,1) = 7 [{grid[1,1]}]')
    check(count[1, 1] == 1,             f'bin(1,1) count=1 [{count[1,1]}]')
    check(np.isclose(grid[0, 2], 5.0),  f'bin(0,2) = 5 [{grid[0,2]}]')
    check(count[0, 2] == 1,             f'bin(0,2) count=1 [{count[0,2]}]')

    # Empty bins are NaN with count=0
    empty_cells = [(0,1),(1,0),(1,2)]
    for yi, xi in empty_cells:
        check(not np.isfinite(grid[yi, xi]),
              f'bin({yi},{xi}) empty → NaN [{grid[yi,xi]}]')
        check(count[yi, xi] == 0,
              f'bin({yi},{xi}) empty → count=0 [{count[yi,xi]}]')

    # Out-of-bounds points are silently ignored
    x_oob = np.array([-0.5,  3.5])
    y_oob = np.array([ 0.5,  0.5])
    z_oob = np.array([999.0, 999.0])
    g2, c2 = _bin_average(x_oob, y_oob, z_oob, x_edges, y_edges)
    check(c2.sum() == 0, f'out-of-bounds ignored: total count={c2.sum()}')

    # Single point in every bin: grid == z, count == 1 everywhere
    nx, ny = 4, 3
    xe = np.linspace(0, 4, nx + 1)
    ye = np.linspace(0, 3, ny + 1)
    xc = 0.5 * (xe[:-1] + xe[1:])   # centres
    yc = 0.5 * (ye[:-1] + ye[1:])
    xg, yg = np.meshgrid(xc, yc)    # (ny, nx) grids of centres
    z_known = np.arange(nx * ny, dtype=np.float64).reshape(ny, nx)
    g3, c3 = _bin_average(xg.ravel(), yg.ravel(), z_known.ravel(), xe, ye)
    check(np.allclose(g3, z_known), 'single-point bins: grid == input values')
    check(np.all(c3 == 1),          'single-point bins: all counts == 1')

    # count > 0 ↔ finite grid
    check(np.all((c3 > 0) == np.isfinite(g3)),
          'count>0 ↔ finite grid (no discrepancy)')


def test_v_geo_grid_axis_integration():
    print('\n=== v_geo_grid axis integration ===')
    cal = virtispds(CAL1)
    geo = virtispds(GEO1)

    # ── x_delta + y_delta ────────────────────────────────────────────────────
    r = v_geo_grid(cal, geo, index_band=76, x_delta=2.0, y_delta=5.0)
    xe = r['x_edges']
    ye = r['y_edges']
    expected_nx = int(round((xe[-1] - xe[0]) / 2.0))
    check(len(r['x_axis']) == expected_nx,
          f'x_delta=2.0: nx=round(range/delta)={expected_nx} [got {len(r["x_axis"])}]')
    check(np.isclose(ye[1] - ye[0], 5.0),
          f'y_delta=5.0 preserved [{ye[1]-ye[0]:.4f}]')

    # ── explicit x_range + y_range, no size/delta → defaults to 512 ──────────
    r = v_geo_grid(cal, geo, index_band=76,
                   x_range=(-12.0, 12.0), y_range=(-90.0, 90.0))
    check(r['grid'].shape == (512, 512),
          f'range-only → 512×512 [{r["grid"].shape}]')
    check(np.isclose(r['x_edges'][0], -12.0) and np.isclose(r['x_edges'][-1], 12.0),
          f'x_edges span given range [{r["x_edges"][0]:.1f}, {r["x_edges"][-1]:.1f}]')

    # ── x_size + y_size → axis lengths and shape ──────────────────────────────
    r = v_geo_grid(cal, geo, index_band=76, x_size=24, y_size=18)
    check(r['grid'].shape == (18, 24),
          f'x_size=24, y_size=18: shape {r["grid"].shape}')
    check(len(r['x_axis']) == 24 and len(r['y_axis']) == 18,
          f'axis lengths [{len(r["x_axis"])}, {len(r["y_axis"])}]')
    check(len(r['x_edges']) == 25 and len(r['y_edges']) == 19,
          f'edge lengths [{len(r["x_edges"])}, {len(r["y_edges"])}]')

    # ── x_axis are midpoints ───────────────────────────────────────────────────
    xe = r['x_edges']
    check(np.allclose(r['x_axis'], 0.5 * (xe[:-1] + xe[1:])),
          'x_axis == midpoints of x_edges')
    ye = r['y_edges']
    check(np.allclose(r['y_axis'], 0.5 * (ye[:-1] + ye[1:])),
          'y_axis == midpoints of y_edges')

    # ── count/grid consistency ─────────────────────────────────────────────────
    check(np.all((r['count'] > 0) == np.isfinite(r['grid'])),
          'count>0 ↔ finite grid cells')
    check(r['count'].sum() > 0, f'total pixel count = {r["count"].sum()}')

    # ── y_range default (-90, 90) is respected ────────────────────────────────
    r2 = v_geo_grid(cal, geo, index_band=76, x_size=12, y_size=9)
    check(np.isclose(r2['y_edges'][0], -90.0) and np.isclose(r2['y_edges'][-1], 90.0),
          f'default y_range = (-90,90) [{r2["y_edges"][0]:.1f}, {r2["y_edges"][-1]:.1f}]')

    # ── longitude grid uses [0,360] range by default when use_lt=False ────────
    r3 = v_geo_grid(cal, geo, index_band=76, use_lt=False, x_size=36, y_size=18)
    check(r3['grid'].shape == (18, 36),
          f'longitude grid shape {r3["grid"].shape}')


def test_accumulated_projection():
    print('=== accumulated_projection ===')
    cal = virtispds(CAL1)
    geo = virtispds(GEO1)

    # ── basic call with permissive filters (no incidence/nightside restriction) ──
    r = accumulated_projection(
        [CAL1], [GEO1],
        v_geo_grid_kwargs=dict(
            index_band=76,
            use_lt=False,
            x_size=36,
            y_size=18,
        ),
        min_science_case=1,
        max_science_case=99,
        min_exptime=0.0,
        max_exptime=999.0,
        verbose=False,
    )
    check(r['grid'].shape  == (18, 36),  f'grid shape  {r["grid"].shape}')
    check(r['count'].shape == (18, 36),  f'count shape {r["count"].shape}')
    check(r['count'].min() >= 0,         'count >= 0')
    check(np.all(np.isfinite(r['grid']) == (r['count'] > 0)),
          'isfinite(grid) ↔ count>0')
    check(len(r['fnamelist']) == 1,      f'fnamelist length [{len(r["fnamelist"])}]')
    check(len(r['fdatelist']) == 1,      f'fdatelist length [{len(r["fdatelist"])}]')
    check(r['fdatelist'][0] > 0,         f'fdatelist > 0 [{r["fdatelist"][0]:.1f}]')
    check(len(r['x_axis'])  == 36,       f'x_axis length [{len(r["x_axis"])}]')
    check(len(r['y_axis'])  == 18,       f'y_axis length [{len(r["y_axis"])}]')
    check(len(r['x_edges']) == 37,       f'x_edges length [{len(r["x_edges"])}]')
    check(len(r['y_edges']) == 19,       f'y_edges length [{len(r["y_edges"])}]')

    # ── double-file: count doubles, average unchanged ──────────────────────────
    r2 = accumulated_projection(
        [CAL1, CAL1], [GEO1, GEO1],
        v_geo_grid_kwargs=dict(index_band=76, use_lt=False, x_size=36, y_size=18),
        min_science_case=1, max_science_case=99,
        min_exptime=0.0, max_exptime=999.0,
        verbose=False,
    )
    check(np.array_equal(r2['count'], 2 * r['count']),
          'double file → count doubles')
    check(np.allclose(r2['grid'], r['grid'], equal_nan=True),
          'double file → avg unchanged')
    check(len(r2['fnamelist']) == 2, f'double file fnamelist [{len(r2["fnamelist"])}]')

    # ── exclude list ───────────────────────────────────────────────────────────
    try:
        accumulated_projection(
            [CAL1], [GEO1],
            v_geo_grid_kwargs=dict(index_band=76, use_lt=False, x_size=36, y_size=18),
            exclude_ids=frozenset({'VI0093'}),
            min_science_case=1, max_science_case=99,
            min_exptime=0.0, max_exptime=999.0,
            verbose=False,
        )
        check(False, 'exclude list: should have raised')
    except RuntimeError:
        check(True, 'exclude list raises RuntimeError when all files excluded')

    # ── science case filter ────────────────────────────────────────────────────
    # orbit 93 has science_case=3; filter to only case 1 should skip it
    try:
        accumulated_projection(
            [CAL1], [GEO1],
            v_geo_grid_kwargs=dict(index_band=76, use_lt=False, x_size=36, y_size=18),
            min_science_case=1, max_science_case=2,
            min_exptime=0.0, max_exptime=999.0,
            verbose=False,
        )
        check(False, 'science_case filter: should have raised')
    except RuntimeError:
        check(True, 'science_case filter skips orbit 93 (case=3, max=2)')

    # ── exptime filter ─────────────────────────────────────────────────────────
    # orbit 93 has exptime=3.3 s; filter max=1.0 should skip it
    try:
        accumulated_projection(
            [CAL1], [GEO1],
            v_geo_grid_kwargs=dict(index_band=76, use_lt=False, x_size=36, y_size=18),
            min_science_case=1, max_science_case=99,
            min_exptime=0.0, max_exptime=1.0,
            verbose=False,
        )
        check(False, 'exptime filter: should have raised')
    except RuntimeError:
        check(True, 'exptime filter skips orbit 93 (exptime=3.3, max=1.0)')

    # ── co_230232 wrapper: orbit 93 is nightside (inc 118-180°) → succeeds ──────
    r_co = co_230232_longitude_nightside_5x5([CAL1], [GEO1], verbose=False)
    check(r_co['grid'].shape == (36, 72),
          f'co_230232 grid shape {r_co["grid"].shape}')
    check(len(r_co['fnamelist']) == 1,
          f'co_230232 fnamelist [{r_co["fnamelist"]}]')
    check(r_co['count'].max() > 0, 'co_230232 has non-empty cells')

    # ── co_ratio229_interp wrapper: orbit 93 passes all filters → succeeds ──────
    r_i = co_ratio229_interp([CAL1], [GEO1], verbose=False)
    check(r_i['grid'].shape == (180, 360),
          f'co_ratio229 grid shape {r_i["grid"].shape}')
    check(len(r_i['fnamelist']) == 1,
          f'co_ratio229 fnamelist [{r_i["fnamelist"]}]')
    check(r_i['count'].max() > 0, 'co_ratio229 has non-empty cells')


if __name__ == '__main__':
    test_planck()
    test_crop_cube()
    test_rad_to_rayleigh()
    test_emission_angle_corrections()
    test_interp_integrate()
    test_incidence_angle_correction()
    test_phase_angle_correction()
    test_filters()
    test_time_utils()
    test_brightness_temperature()
    test_v_geo_grid_corrections()
    test_v_geo_grid_axes()
    test_v_geo_grid_binning()
    test_v_geo_grid_axis_integration()
    test_accumulated_projection()
    print()
