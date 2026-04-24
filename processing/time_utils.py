"""
Time and orbit conversion utilities for Venus Express / VIRTIS.
Ported from VEX_tools/v_jul2scet.pro, v_scet2jul.pro, v_jul2utc.pro,
v_utc2jul.pro, and v_orbit2mtp.pro (Cardesin, IASF-INAF).

SCET (Spacecraft Event Time) uses ESA's OBET encoding: the integer part
is seconds since the mission epoch and the fractional part encodes
sub-second time in units of 1/65536 seconds (2^-16 s per tick).

Warning: these conversions are approximate.  Use SPICE kernels for
results that require sub-second accuracy.
"""

import warnings
import numpy as np
from astropy.time import Time


# Mission epoch as Julian Day Number
_ORIGINS = {
    'VEX':     Time('2005-03-01T00:00:00', format='isot', scale='utc').jd,
    'ROSETTA': Time('2003-01-01T00:00:00', format='isot', scale='utc').jd,
}

_SCET_WARN = (
    'SCET conversion is approximate. Use SPICE for accurate results.'
)


def jul2scet(jul_date, corr_factor=None, mission='VEX',
             as_string=True, partition=None):
    """
    Convert Julian date(s) to SCET.

    Ported from VEX_tools/v_jul2scet.pro.

    Parameters
    ----------
    jul_date : float or array-like
        Julian Day Number(s).
    corr_factor : float, optional
        Additive correction to the SCET value in seconds.
    mission : {'VEX', 'ROSETTA'}
        Spacecraft mission; determines the epoch origin.
    as_string : bool
        If True (default), return the SCET in OBET string format
        "SSSSSSSSSSS.TTTTT" where TTTTT is in 1/65536-second ticks.
        If False, return the raw SCET as a float (seconds since epoch).
    partition : int or str, optional
        If provided, prepend "<partition>/" to each string result.

    Returns
    -------
    str / ndarray of str   (as_string=True)
    float / ndarray of float  (as_string=False)
    """
    warnings.warn(_SCET_WARN, stacklevel=2)
    orig   = _ORIGINS[mission.upper()]
    scalar = np.ndim(jul_date) == 0
    scet   = (np.atleast_1d(np.asarray(jul_date, dtype=np.float64)) - orig) * 86400.0

    if corr_factor is not None:
        scet = scet + float(corr_factor)

    if not as_string:
        return float(scet[0]) if scalar else scet

    scet_int  = np.floor(scet).astype(np.int64)
    scet_frac = np.floor((scet - np.floor(scet)) * 65536.0).astype(np.int64)
    result    = np.array([f'{si:011d}.{sf:05d}' for si, sf in zip(scet_int, scet_frac)])

    if partition is not None:
        result = np.array([f'{partition}/{r}' for r in result])

    return str(result[0]) if scalar else result


def scet2jul(scet, mission='VEX'):
    """
    Convert SCET value(s) to Julian date.

    Accepts numeric SCETs or OBET strings with optional partition prefix
    ("1/43232323.02014") and fractional ticks in 1/65536-second units.

    Ported from VEX_tools/v_scet2jul.pro.

    Parameters
    ----------
    scet : scalar or array-like of str or float
        SCET value(s) as a number or OBET string.
    mission : {'VEX', 'ROSETTA'}

    Returns
    -------
    float or ndarray of float
        Julian Day Number(s).
    """
    warnings.warn(_SCET_WARN, stacklevel=2)
    orig   = _ORIGINS[mission.upper()]
    scalar = np.ndim(scet) == 0
    scets  = np.atleast_1d(scet)

    result = np.empty(len(scets), dtype=np.float64)
    for i, s in enumerate(scets):
        s = str(s)
        if '/' in s:
            _, s = s.split('/', 1)
        parts = s.split('.')
        int_part  = float(parts[0])
        frac_part = float(parts[1]) / 65536.0 if len(parts) > 1 else 0.0
        result[i] = orig + (int_part + frac_part) / 86400.0

    return float(result[0]) if scalar else result


def jul2utc(jul_date):
    """
    Convert Julian date(s) to UTC ISO string(s).

    Output format: "YYYY-MM-DDTHH:MM:SS.sss" (millisecond precision).
    The IDL original uses centisecond precision; this returns milliseconds.

    Ported from VEX_tools/v_jul2utc.pro.

    Parameters
    ----------
    jul_date : float or array-like
        Julian Day Number(s).

    Returns
    -------
    str or ndarray of str
    """
    scalar = np.ndim(jul_date) == 0
    jds    = np.atleast_1d(np.asarray(jul_date, dtype=np.float64))
    t      = Time(jds, format='jd', scale='utc')
    result = np.array(t.isot)   # shape (N,) of strings

    return str(result[0]) if scalar else result


def utc2jul(utc_string):
    """
    Convert UTC ISO string(s) to Julian date(s).

    Accepts formats like "YYYY-MM-DDTHH:MM:SS[.sss][Z]".

    Ported from VEX_tools/v_utc2jul.pro.

    Parameters
    ----------
    utc_string : str or array-like of str

    Returns
    -------
    float or ndarray of float
        Julian Day Number(s).  Returns 0.0 on parse failure.
    """
    scalar = isinstance(utc_string, str)
    strings = [utc_string] if scalar else list(utc_string)
    result  = np.empty(len(strings), dtype=np.float64)

    for i, s in enumerate(strings):
        try:
            s = s.rstrip('Z')
            t = Time(s, format='isot', scale='utc')
            result[i] = t.jd
        except Exception:
            print(f'FORMAT ERROR: cannot convert UTC time string: {s}')
            result[i] = 0.0

    return float(result[0]) if scalar else result


def orbit2mtp(orbit_num, as_string=False):
    """
    Return the MTP (Medium-Term Plan) number for given VEX orbit number(s).

    Special cases:
      orbit = 0      → -1 / "VOI"    (Venus Orbit Insertion)
      0 < orbit < 16 → -2 / "VOCP"   (Venus Orbit Capture Phase)
      orbit = 9999   → -3 / "CRUISE"
      orbit < 0 or orbit > 9999 → -4 / "" (invalid)

    Ported from VEX_tools/v_orbit2mtp.pro (Cardesin 2008).

    Parameters
    ----------
    orbit_num : int or array-like of int
    as_string : bool
        If True, return strings like "MTP001", "VOI", "VOCP", "CRUISE", "".
        If False (default), return integers.

    Returns
    -------
    int / str   (scalar input)
    ndarray     (array input)
    """
    scalar  = np.ndim(orbit_num) == 0
    orbits  = np.atleast_1d(np.asarray(orbit_num, dtype=np.int64))
    mtp     = (orbits - 16) // 28 + 1

    is_voi     = orbits == 0
    is_vocp    = (orbits > 0) & (orbits < 16)
    is_cruise  = orbits == 9999
    is_invalid = (orbits > 9999) | (orbits < 0)

    if not as_string:
        mtp = mtp.copy()
        mtp[is_voi]     = -1
        mtp[is_vocp]    = -2
        mtp[is_cruise]  = -3
        mtp[is_invalid] = -4
        return int(mtp[0]) if scalar else mtp

    result = np.array([f'MTP{m:03d}' for m in mtp])
    result[is_voi]     = 'VOI'
    result[is_vocp]    = 'VOCP'
    result[is_cruise]  = 'CRUISE'
    result[is_invalid] = ''
    return str(result[0]) if scalar else result
