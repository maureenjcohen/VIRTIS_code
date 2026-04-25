"""
VIRTIS Python/IDL cross-check report (Python side).

Run:
    conda run -n virtis python crosscheck_python.py > report_python.txt

Then compare against the IDL output:
    diff report_python.txt report_idl.txt

Each line is:  key = value   (scientific notation, 6 decimal places).
NaN cells are printed as:  key = NaN

NOTES ON KNOWN DIFFERENCES
---------------------------
correct_ia_ea:
    IDL's incidence_angle_correction_mine.pro does not expose an EAband
    keyword; when called from the command line the emission-angle array
    defaults to 0.  The cross-check therefore passes ema=0 to correct_ia_ea
    so that both sides compute  R / cos(INC) / cos(0)^0.25  and should agree.

planck / brightness_temperature:
    IDL often operates in float32 by default; Python uses float64.
    Up to 1-unit differences in the last printed decimal digit are normal.

vgeo_grid:
    IDL returns grid[x_bin, y_bin] (longitude-first); Python returns
    grid[y_bin, x_bin] (latitude-first).  The key uses j=lat-bin, i=lon-bin
    so Python grid[j,i] == IDL grid[i,j].
"""

import warnings
from datetime import datetime

import numpy as np

from pds.virtispds import virtispds
from processing.planck import planck, brightness_temperature
from processing.emission_angle_correction import (
    correct_general, correct_1_27, correct_1_31,
    correct_1_74, correct_2_3, correct_3_8, correct_5_0,
)
from processing.rad_to_rayleigh import rad_to_rayleigh
from processing.interpintegrate import interp_integrate
from processing.incidence_angle_correction import ia_corr, correct_ia_ea
from processing.phase_angle_correction import correct_phase_angle
from processing.filters import amedian
from processing.time_utils import scet2jul
from processing.v_geo_grid import v_geo_grid


# ── helpers ───────────────────────────────────────────────────────────────────

def p(key, value):
    if np.isfinite(value):
        print(f'{key} = {value:.6E}')
    else:
        print(f'{key} = NaN')


# ── header ────────────────────────────────────────────────────────────────────

print('# VIRTIS cross-check report')
print('# Script: Python')
print(f'# Date: {datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")} UTC')
print()

# ── shared test inputs ────────────────────────────────────────────────────────
# Single-pixel arrays: (bands=1, samples=1, lines=1)
R     = 0.05       # radiance  W m-2 um-1 sr-1
EMA   = 45.0       # emission angle  degrees
INC   = 120.0      # incidence angle  degrees
PHA   = 60.0       # phase angle  degrees
WL_M  = 2.3e-6     # wavelength  metres
WL_UM = 2.3        # wavelength  microns
T     = 300.0      # temperature  K

cube  = np.full((1, 1, 1), R)                    # (1 band, 1 sample, 1 line)
ema2d = np.full((1, 1), EMA)                     # (1 sample, 1 line)
ema0  = np.zeros((1, 1))                         # zero emission angle (matches IDL default)
inc2d = np.full((1, 1), INC)
pha2d = np.full((1, 1), PHA)

# ── planck ────────────────────────────────────────────────────────────────────

p('planck.T300K_wl2300nm',       planck(T, WL_M))
p('bright_temp.roundtrip_300K',  brightness_temperature(
                                     np.full((1,1,1), planck(T, WL_M)), [WL_UM])[0,0,0])

# ── emission-angle corrections ────────────────────────────────────────────────
# All called with cube=(1,1,1), ema=45 degrees
# IDL: emission_angle_correction_X, QUBE=cube, EMband=ema, CORRECTED_QUBE=result, /NO_POPUPS
# IDL input cube is [B,S,L]; functions transpose it internally; result is back in [B,S,L]

p('ema_1_27.R0.05_ema45',    correct_1_27(cube, ema2d)[0,0,0])
p('ema_1_31.R0.05_ema45',    correct_1_31(cube, ema2d)[0,0,0])
p('ema_1_74.R0.05_ema45',    correct_1_74(cube, ema2d)[0,0,0])
p('ema_2_3.R0.05_ema45',     correct_2_3 (cube, ema2d)[0,0,0])
p('ema_3_8.R0.05_ema45',     correct_3_8 (cube, ema2d)[0,0,0])
p('ema_5_0.R0.05_ema45',     correct_5_0 (cube, ema2d)[0,0,0])
# correct_general on 1×1: min_ema_per_line == pixel itself → result == R unchanged
p('ema_general.R0.05_ema45', correct_general(cube, ema2d)[0,0,0])

# ── rad_to_rayleigh ───────────────────────────────────────────────────────────
# IDL: rad_to_rayleigh, QUBE=cube, WL=[wl_m], RAYLEIGH=result, /NO_POPUPS

p('rad_rayleigh.R0.05_wl2300nm', rad_to_rayleigh(cube, [WL_M])[0,0,0])

# ── interp_integrate ──────────────────────────────────────────────────────────
# IDL: interpIntegrate(x, y, Ind1, Ind2, NewX) — same argument order as Python
# Test: y = x (linear), x = [1,2,3,4,5], new_x = [2,3,4]

x_ii    = np.array([1.0, 2.0, 3.0, 4.0, 5.0])
y_ii    = x_ii.copy()
new_x_ii = np.array([2.0, 3.0, 4.0])
out_ii  = interp_integrate(x_ii, y_ii, new_x_ii)

p('interp_integrate.linear_newx2', out_ii[0])
p('interp_integrate.linear_newx3', out_ii[1])
p('interp_integrate.linear_newx4', out_ii[2])

# ── correct_ia_ea ─────────────────────────────────────────────────────────────
# Using ema=0 so Python and IDL results match (see file-level note).
# IDL: incidence_angle_correction_mine, QUBE=cube, IAband=inc, CORRECTED_QUBE=result, /NO_POPUPS
# formula: R / cos(INC) / cos(EMA)^0.25  with EMA=0 → R / cos(INC)

p('correct_ia_ea.R0.05_inc120_ema0', correct_ia_ea(cube, inc2d, ema0)[0,0,0])

# ── correct_phase_angle ───────────────────────────────────────────────────────
# IDL: phase_angle_correction, QUBE=cube, IAband=phase, CORRECTED_QUBE=result, /NO_POPUPS
# formula: R / sin(PHA)

p('correct_phase.R0.05_phase60', correct_phase_angle(cube, pha2d)[0,0,0])

# ── amedian ───────────────────────────────────────────────────────────────────
# 3x3 array: all 3.0 except center = 7.0
# IDL: arr = FLTARR(3,3) + 3.0  &  arr[1,1] = 7.0
# Both arr[1,1] refer to the same center element

arr33       = np.full((3, 3), 3.0)
arr33[1, 1] = 7.0
out33       = amedian(arr33, 3)

p('amedian_3x3.center',   out33[1, 1])
p('amedian_3x3.corner00', out33[0, 0])
p('amedian_3x3.corner22', out33[2, 2])

# ── scet2jul ──────────────────────────────────────────────────────────────────
# IDL: v_scet2jul('1/00043946888.29290', /VEX, /NO_WARNING)

with warnings.catch_warnings():
    warnings.simplefilter('ignore')
    p('scet2jul.orbit93', scet2jul('1/00043946888.29290'))

# ── ia_corr ───────────────────────────────────────────────────────────────────
# Requires real PDS structures.  Uses orbit-93 test data.
# IDL: ia_corr, cal, geo, 76, result   →  result is (samples, lines) float array
# Python: ia_corr(cal, geo, 76)        →  same shape

cal = virtispds('test_data/cubes/VIR0093/CALIBRATED/VI0093_01.CAL')
geo = virtispds('test_data/cubes/VIR0093/GEOMETRY/VI0093_01.GEO')

ia_result = ia_corr(cal, geo, 76)   # (ns, nl)
p('ia_corr.orbit93_band76_s0_l0',  ia_result[0, 0])
p('ia_corr.orbit93_band76_s10_l5', ia_result[10, 5])

# ── v_geo_grid ────────────────────────────────────────────────────────────────
# 4x4 longitude/latitude grid, band 76, orbit-93 data.
# IDL:   grid = v_geo_grid(cal_file, geo_file, INDEX_BAND=76, LONGITUDE=1,
#                          XSIZE=4, YSIZE=4, XRANGE=[0,360], YRANGE=[-90,90], /NO_POPUPS)
#        grid is [4,4] with grid[i_lon, j_lat]
# Python: r['grid'] is (4,4) with grid[j_lat, i_lon]
# → both: print using key j=lat-bin, i=lon-bin; access grid[j,i] in Python, grid[i,j] in IDL

r = v_geo_grid(
    cal, geo,
    index_band=76,
    use_lt=False,
    x_range=(0.0, 360.0),
    y_range=(-90.0, 90.0),
    x_size=4,
    y_size=4,
)
grid = r['grid']

for j in range(4):
    for i in range(4):
        v = grid[j, i]
        key = f'vgeo.band76_4x4_j{j}_i{i}'
        if np.isfinite(v):
            print(f'{key} = {v:.6E}')
        else:
            print(f'{key} = NaN')
