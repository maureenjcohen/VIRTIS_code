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
    correct_1_27, correct_1_74, correct_2_3, correct_3_8, correct_5_0,
)
from processing.interpintegrate import interp_integrate

CAL = Path('test_data/cubes/VIR0093/CALIBRATED/VI0093_00.CAL')
GEO = Path('test_data/cubes/VIR0093/GEOMETRY/VI0093_00.GEO')


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


if __name__ == '__main__':
    test_planck()
    test_crop_cube()
    test_rad_to_rayleigh()
    test_emission_angle_corrections()
    test_interp_integrate()
    print()
