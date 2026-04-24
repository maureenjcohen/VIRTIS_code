"""
Quick validation of pds/virtispds.py against orbit-93 test data.
Run with:  conda run -n virtis python test_reader.py
"""

import numpy as np
from pathlib import Path
from pds.virtispds import virtispds

CAL = Path('test_data/cubes/VIR0093/CALIBRATED/VI0093_00.CAL')
GEO = Path('test_data/cubes/VIR0093/GEOMETRY/VI0093_00.GEO')


def check(condition, msg):
    status = 'PASS' if condition else 'FAIL'
    print(f'  [{status}] {msg}')
    return condition


def test_cal():
    print('\n=== CAL file ===')
    r = virtispds(CAL)

    check(r['qube'].shape == (432, 256, 289),
          f"qube shape == (432, 256, 289)  [got {r['qube'].shape}]")

    check(r['qube'].dtype == np.float32,
          f"qube dtype == float32  [got {r['qube'].dtype}]")

    check(r['qube_dim'] == [432, 256, 289],
          f"qube_dim == [432, 256, 289]")

    # Radiance values: expect small positive numbers (W/m²/sr/µm)
    # Ignore NaNs introduced for fill values
    finite = r['qube'][np.isfinite(r['qube'])]
    check(finite.size > 0,
          f"qube has finite values  [{finite.size} finite pixels]")
    check(0.0 < float(np.nanmedian(finite)) < 1.0,
          f"median radiance in plausible range (0–1 W/m²/sr/µm)  "
          f"[got {float(np.nanmedian(finite)):.4f}]")

    # Band suffix (SCET)
    check('scet' in r['suffix'],
          "suffix contains 'scet' key")
    check(r['suffix']['scet'].shape == (1, 256, 289),
          f"SCET shape == (1, 256, 289)  [got {r['suffix']['scet'].shape}]")

    # Bottom plane (wavelength, FWHM, uncertainty)
    check(r['suffix']['bottom'] is not None,
          "suffix contains bottom plane")
    check(r['suffix']['bottom'].shape == (432, 256, 3),
          f"bottom shape == (432, 256, 3)  [got {r['suffix']['bottom'].shape}]")

    # Wavelength sanity: VIRTIS-M IR covers ~1–5 µm
    wl = r['suffix']['bottom'][:, 0, 0]   # wavelengths for first sample
    check(0.9 < float(np.nanmin(wl)) < 1.5,
          f"min wavelength ≈ 1 µm  [got {float(np.nanmin(wl)):.3f} µm]")
    check(4.0 < float(np.nanmax(wl)) < 5.5,
          f"max wavelength ≈ 5 µm  [got {float(np.nanmax(wl)):.3f} µm]")

    print(f'\n  qube[135, 128, 144] = {r["qube"][135, 128, 144]:.6f}  '
          f'(band 135 / 2.3 µm window, mid-scene pixel)')


def test_geo():
    print('\n=== GEO file ===')
    r = virtispds(GEO)

    check(r['qube'].shape == (33, 256, 289),
          f"qube shape == (33, 256, 289)  [got {r['qube'].shape}]")

    check(len(r['qube_coeff']) == 33,
          f"qube_coeff length == 33  [got {len(r['qube_coeff'])}]")

    check(r['suffix'] == {},
          "suffix is empty for GEO file")

    # Apply scaling coefficients and check physical ranges
    geo = r['qube'].astype(np.float64) * r['qube_coeff'][:, None, None]

    lat = geo[25]   # Cloud latitude
    lon = geo[24]   # Cloud longitude
    ema = geo[27]   # Emergence (emission) angle
    inc = geo[26]   # Incidence angle
    lt  = geo[15]   # Local time

    check(np.nanmin(lat) >= -90 and np.nanmax(lat) <= 90,
          f"latitude in [-90, 90]  [got {np.nanmin(lat):.1f} to {np.nanmax(lat):.1f}]")
    check(np.nanmin(lon) >= 0 and np.nanmax(lon) <= 360,
          f"longitude in [0, 360]  [got {np.nanmin(lon):.1f} to {np.nanmax(lon):.1f}]")
    check(np.nanmin(ema) >= 0 and np.nanmax(ema) <= 90,
          f"emergence angle in [0, 90]  [got {np.nanmin(ema):.1f} to {np.nanmax(ema):.1f}]")
    check(np.nanmin(inc) >= 0 and np.nanmax(inc) <= 180,
          f"incidence angle in [0, 180]  [got {np.nanmin(inc):.1f} to {np.nanmax(inc):.1f}]")
    check(np.nanmin(lt) >= 0 and np.nanmax(lt) <= 24,
          f"local time in [0, 24] h  [got {np.nanmin(lt):.1f} to {np.nanmax(lt):.1f}]")

    print(f'\n  Orbit 93 coverage: lat [{np.nanmin(lat):.1f}, {np.nanmax(lat):.1f}]°  '
          f'lon [{np.nanmin(lon):.1f}, {np.nanmax(lon):.1f}]°')


if __name__ == '__main__':
    test_cal()
    test_geo()
    print()
