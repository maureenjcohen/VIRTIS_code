"""
Read VIRTIS Venus Express PDS3 data files (.CAL and .GEO).

Ported from LecturePDS_2.7.5/virtispds.pro and v_qubepds.pro by
Erard/Cardesin (LESIA/IASF-INAF).

Supports:
  - VIRTIS-M calibrated cubes (.CAL): 432-band radiance + SCET backplane
    + wavelength/FWHM/uncertainty bottomplane
  - VIRTIS-M geometry cubes (.GEO): 33-band geometry, no suffix

Returns a dict with the same fields as the IDL structure so that
downstream code (v_geo_grid etc.) can reference fields by the same names.
"""

import numpy as np
import pvl
from pathlib import Path


# ── Geometry band metadata (virtispds.pro lines 314-348) ─────────────────────

_GEO_BAND_NAMES = [
    'Surf longit, corner1', 'Surf longit, corner2',
    'Surf longit, corner3', 'Surf longit, corner4',
    'Surf latit, corner1',  'Surf latit, corner2',
    'Surf latit, corner3',  'Surf latit, corner4',
    'Surf longit, center',  'Surf latit, center',
    'Incidence at surf',    'Emergence at surf',    'Phase at surf',
    'Elevation on surf layer', 'Slant distance',    'Local time',
    'Cloud longit, corner1', 'Cloud longit, corner2',
    'Cloud longit, corner3', 'Cloud longit, corner4',
    'Cloud latit, corner1',  'Cloud latit, corner2',
    'Cloud latit, corner3',  'Cloud latit, corner4',
    'Cloud longit, center',  'Cloud latit, center',
    'Incidence on clouds',   'Emergence on clouds',  'Phase on clouds',
    'Elevation below clouds', 'Right ascension',     'Declination',
    'M-common frame',
]

# Scaling coefficients to physical units: degrees, km, local hours
# (virtispds.pro lines 412-424)
_GEO_COEFF = np.array([
    *[1e-4] * 13,   # bands  0-12: longitude/latitude/angles (degrees)
    *[1e-3] * 2,    # bands 13-14: elevation and slant distance (km)
    1e-5,           # band  15:    local time (hours)
    *[1e-4] * 13,   # bands 16-28: cloud longit/latit/angles (degrees)
    1e-3,           # band  29:    elevation below clouds (km)
    *[1e-4] * 2,    # bands 30-31: right ascension, declination (degrees)
    1.0,            # band  32:    M-common frame (dimensionless)
], dtype=np.float64)


# ── PDS3 type → numpy dtype (v_typepds.pro) ──────────────────────────────────

def _pds_dtype(item_type: str, item_bytes: int) -> np.dtype:
    """Map a PDS3 CORE_ITEM_TYPE string and byte-count to a numpy dtype."""
    t = item_type.upper().replace('"', '').strip()
    if 'INTEGER' in t:
        endian = '<' if ('LSB' in t or 'PC' in t or 'VAX' in t) else '>'
        kind   = 'u' if 'UNSIGNED' in t else 'i'
        return np.dtype(f'{endian}{kind}{item_bytes}')
    else:
        # REAL / IEEE_REAL / PC_REAL  (plain "REAL" → IEEE = big-endian)
        endian = '<' if 'PC' in t else '>'
        return np.dtype(f'{endian}f{item_bytes}')


# ── Label helpers ─────────────────────────────────────────────────────────────

def _load_label(filepath: Path) -> pvl.PVLModule:
    """Parse the embedded PDS3 label at the start of a file."""
    # pvl.load stops at the END token and ignores binary data that follows
    return pvl.load(str(filepath))


def _qube_offset(label: pvl.PVLModule) -> int:
    """Return byte offset to the start of the QUBE data block."""
    record_bytes = int(label['RECORD_BYTES'])
    ptr = label['^QUBE']
    # pvl may return an int, or a pvl.quantities.Units object
    record_num = int(ptr.value) if hasattr(ptr, 'value') else int(ptr)
    return (record_num - 1) * record_bytes


def _scalar_int(val) -> int:
    """Safely convert a pvl value (possibly a list) to a plain int."""
    return int(val[0]) if hasattr(val, '__len__') else int(val)


# ── Core reader ───────────────────────────────────────────────────────────────

def virtispds(filepath) -> dict:
    """
    Read a VIRTIS-M Venus Express PDS3 file.

    Parameters
    ----------
    filepath : str or Path
        Path to a .CAL or .GEO file (embedded label, no separate .LBL needed).

    Returns
    -------
    dict with keys:
        label      : pvl.PVLModule  – parsed PDS3 label
        qube       : ndarray shape (bands, samples, lines)
        qube_dim   : [bands, samples, lines]
        qube_name  : list of str – band names (geometry) or [core_name, unit]
        qube_coeff : 1-D ndarray  – scaling coefficients (geometry) or ones
        suffix     : dict with 'scet' and 'bottom' arrays (CAL) or {}  (GEO)
        suf_name   : list of str
        suf_dim    : list of int
    """
    filepath = Path(filepath)
    label    = _load_label(filepath)
    qube_obj = label['QUBE']

    record_bytes = int(label['RECORD_BYTES'])
    data_offset  = _qube_offset(label)

    # Cube dimensions in PDS/IDL convention: (bands, samples, lines)
    ci       = qube_obj['CORE_ITEMS']
    n_bands, n_samples, n_lines = int(ci[0]), int(ci[1]), int(ci[2])

    item_bytes = int(qube_obj['CORE_ITEM_BYTES'])
    core_dtype = _pds_dtype(str(qube_obj['CORE_ITEM_TYPE']), item_bytes)

    # Suffix dimensions: (backplane, sideplane, bottomplane)
    si = qube_obj.get('SUFFIX_ITEMS', [0, 0, 0])
    sx, sy, sz = int(si[0]), int(si[1]), int(si[2])

    # Identify geometry vs calibrated data
    std_id     = str(label.get('STANDARD_DATA_PRODUCT_ID', '')).upper()
    is_geometry = 'GEOMETRY' in std_id

    with open(filepath, 'rb') as fh:
        fh.seek(data_offset)

        if sx == 0 and sy == 0:
            # ── GEO file: pure core, no band or sample suffix ─────────────
            n_core_bytes = n_bands * n_samples * n_lines * item_bytes
            raw  = np.frombuffer(fh.read(n_core_bytes), dtype=core_dtype)
            # BIP storage: band varies fastest → reshape in C-order as
            # (lines, samples, bands) then transpose to (bands, samples, lines)
            core = raw.reshape(n_lines, n_samples, n_bands).transpose(2, 1, 0)
            suffix_data, suf_name, suf_dim = {}, [], []

        else:
            # ── CAL file: BIP core + band-suffix backplane (SCET) ─────────
            #
            # Each sample on disk:
            #   432 × float32  (core radiance)     = 1728 bytes
            #   1   × uint16   (SCET backplane)     =    2 bytes
            #   2 bytes padding (SUFFIX_BYTES=4)    =    2 bytes
            #                                    total 1732 bytes / sample
            #
            bs_bytes = _scalar_int(qube_obj.get('BAND_SUFFIX_ITEM_BYTES', 2))
            pad_bytes = 4 - bs_bytes   # SUFFIX_BYTES=4, item is 2 bytes → 2 pad

            bs_type  = str(qube_obj.get('BAND_SUFFIX_ITEM_TYPE',
                                        'MSB_UNSIGNED_INTEGER'))
            bs_dtype = _pds_dtype(bs_type, bs_bytes)

            sample_dt = np.dtype([
                ('core', core_dtype,  (n_bands,)),
                ('bsuf', bs_dtype,    (sx,)),
                ('_pad', np.uint8,    (pad_bytes,)),
            ])

            n_samples_total = n_lines * n_samples
            raw = np.frombuffer(
                fh.read(sample_dt.itemsize * n_samples_total),
                dtype=sample_dt,
            ).reshape(n_lines, n_samples)

            # core: (lines, samples, bands) → (bands, samples, lines)
            core = raw['core'].transpose(2, 1, 0).copy()
            # bsuf: (lines, samples, sx) → (sx, samples, lines)
            bsuf = raw['bsuf'].transpose(2, 1, 0).copy()

            # ── Bottomplane (wavelength, FWHM, uncertainty) ───────────────
            if sz > 0:
                ls_bytes = _scalar_int(
                    qube_obj.get('LINE_SUFFIX_ITEM_BYTES', 4))
                ls_type  = str(qube_obj.get('LINE_SUFFIX_ITEM_TYPE', 'REAL'))
                ls_dtype = _pds_dtype(ls_type, ls_bytes)

                n_bottom = n_bands * n_samples * sz
                bottom   = np.frombuffer(
                    fh.read(n_bottom * ls_bytes), dtype=ls_dtype,
                ).reshape(sz, n_samples, n_bands).transpose(2, 1, 0)
                # shape: (bands, samples, sz=3)
                # bottom[..., 0] = wavelength, [1] = FWHM, [2] = uncertainty
            else:
                bottom = None

            suffix_data = {'scet': bsuf, 'bottom': bottom}
            suf_name    = ['Data SCET-1', 'Data SCET-2', 'Data SCET-3']
            suf_dim     = [3, n_lines]

    # ── Metadata ──────────────────────────────────────────────────────────────
    if is_geometry:
        qube_name  = _GEO_BAND_NAMES[:n_bands]
        qube_coeff = _GEO_COEFF[:n_bands].copy()
    else:
        qube_name  = [
            str(qube_obj.get('CORE_NAME', 'RADIANCE')),
            str(qube_obj.get('CORE_UNIT', 'W/m**2/sr/micron')),
        ]
        qube_coeff = np.ones(n_bands, dtype=np.float64)

    # Replace special fill values with NaN (CORE_HIGH_INSTR_SATURATION = -1000)
    if not is_geometry:
        core = core.astype(np.float32)
        core[core <= -999] = np.nan

    return {
        'label':      label,
        'qube':       core,
        'qube_dim':   [n_bands, n_samples, n_lines],
        'qube_name':  qube_name,
        'qube_coeff': qube_coeff,
        'suffix':     suffix_data,
        'suf_name':   suf_name,
        'suf_dim':    suf_dim,
    }
