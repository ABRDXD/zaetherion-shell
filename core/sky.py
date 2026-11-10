"""The sky over the user, for the astronomical clock (M10) and discovery's sky events. Pure and stdlib only.

Algorithms from Jean Meeus, *Astronomical Algorithms* (2nd ed., 1998): the sun (ch. 25, low accuracy), the moon
(ch. 47, the larger terms of tables 47.A/B), sidereal time (ch. 12), coordinates (ch. 13), rising and setting
(ch. 15's standard altitudes), the moon's illumination (ch. 48). The planets use JPL's approximate Keplerian
elements for 1800–2050 (E. M. Standish, "Approximate Positions of the Planets", Table 1), solved with Kepler's
equation and corrected for light time and precession of the equinox. Accuracy against JPL Horizons
(tests/test_sky.py): the sun and planets within ~0.1°, the moon within ~0.1° and its altitude with parallax.

Angles are degrees, distances astronomical units (the moon's also km), times aware UTC datetimes or Julian days (UT).
Longitude is east-positive, azimuth measured from north through east. Altitudes are geometric (airless); refraction
is only in the standard altitudes used for rising and setting.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import math

J2000 = 2451545.0
AU_KM = 149597870.7
EARTH_RADIUS_KM = 6378.14
PLANETS = ("mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune")
BODIES = ("sun", "moon") + PLANETS

# Standard altitudes for rising and setting (Meeus ch. 15): the sun's upper limb with refraction; a star or planet's
# centre with refraction. The moon's depends on its parallax, so it is computed.
SUN_H0 = -0.8333
PLANET_H0 = -0.5667

# Standish Table 1: a (au), e, I, L, longitude of perihelion, longitude of the node (deg), each with its rate per
# Julian century. Mean ecliptic and equinox of J2000. "earth" is the Earth-Moon barycentre.
ELEMENTS = {
    "mercury": ((0.38709927, 0.00000037), (0.20563593, 0.00001906), (7.00497902, -0.00594749),
                (252.25032350, 149472.67411175), (77.45779628, 0.16047689), (48.33076593, -0.12534081)),
    "venus": ((0.72333566, 0.00000390), (0.00677672, -0.00004107), (3.39467605, -0.00078890),
              (181.97909950, 58517.81538729), (131.60246718, 0.00268329), (76.67984255, -0.27769418)),
    "earth": ((1.00000261, 0.00000562), (0.01671123, -0.00004392), (-0.00001531, -0.01294668),
              (100.46457166, 35999.37244981), (102.93768193, 0.32327364), (0.0, 0.0)),
    "mars": ((1.52371034, 0.00001847), (0.09339410, 0.00007882), (1.84969142, -0.00813131),
             (-4.55343205, 19140.30268499), (-23.94362959, 0.44441088), (49.55953891, -0.29257343)),
    "jupiter": ((5.20288700, -0.00011607), (0.04838624, -0.00013253), (1.30439695, -0.00183714),
                (34.39644051, 3034.74612775), (14.72847983, 0.21252668), (100.47390909, 0.20469106)),
    "saturn": ((9.53667594, -0.00125060), (0.05386179, -0.00050991), (2.48599187, 0.00193609),
               (49.95424423, 1222.49362201), (92.59887831, -0.41897216), (113.66242448, -0.28867794)),
    "uranus": ((19.18916464, -0.00196176), (0.04725744, -0.00004397), (0.77263783, -0.00242939),
               (313.23810451, 428.48202785), (170.95427630, 0.40805281), (74.01692503, 0.04240589)),
    "neptune": ((30.06992276, 0.00026291), (0.00859048, 0.00005105), (1.77004347, 0.00035372),
                (-55.12002969, 218.45945325), (44.96476227, -0.32241464), (131.78422574, -0.00508664)),
}

# Meeus table 47.A, the terms of 0.002° (longitude) or 1 km (distance) and more: D, M, M', F, Σl (1e-6 °), Σr (m).
MOON_LR = (
    (0, 0, 1, 0, 6288774, -20905355), (2, 0, -1, 0, 1274027, -3699111), (2, 0, 0, 0, 658314, -2955968),
    (0, 0, 2, 0, 213618, -569925), (0, 1, 0, 0, -185116, 48888), (0, 0, 0, 2, -114332, -3149),
    (2, 0, -2, 0, 58793, 246158), (2, -1, -1, 0, 57066, -152138), (2, 0, 1, 0, 53322, -170733),
    (2, -1, 0, 0, 45758, -204586), (0, 1, -1, 0, -40923, -129620), (1, 0, 0, 0, -34720, 108743),
    (0, 1, 1, 0, -30383, 104755), (2, 0, 0, -2, 15327, 10321), (0, 0, 1, 2, -12528, 0),
    (0, 0, 1, -2, 10980, 79661), (4, 0, -1, 0, 10675, -34782), (0, 0, 3, 0, 10034, -23210),
    (4, 0, -2, 0, 8548, -21636), (2, 1, -1, 0, -7888, 24208), (2, 1, 0, 0, -6766, 30824),
    (1, 0, -1, 0, -5163, -8379), (1, 1, 0, 0, 4987, -16675), (2, -1, 1, 0, 4036, -12831),
    (2, 0, 2, 0, 3994, -10445), (4, 0, 0, 0, 3861, -11650), (2, 0, -3, 0, 3665, 14403),
    (0, 1, -2, 0, -2689, -7003), (2, 0, -1, 2, -2602, 0), (2, -1, -2, 0, 2390, 10056),
    (1, 0, 1, 0, -2348, 6322), (2, -2, 0, 0, 2236, -9884), (0, 1, 2, 0, -2120, 5751),
    (0, 2, 0, 0, -2069, 0), (2, -2, -1, 0, 2048, -4950), (2, 0, 1, -2, -1773, 4130),
    (2, 0, 0, 2, -1595, 0), (4, -1, -1, 0, 1215, -3958), (0, 0, 2, 2, -1110, 0),
    (3, 0, -1, 0, -892, 3258), (2, 1, 1, 0, -810, 2616), (4, -1, -2, 0, 759, -1897),
    (0, 2, -1, 0, -713, -2117), (2, 2, -1, 0, -700, 2354), (2, 1, -2, 0, 691, 0),
    (2, -1, 0, -2, 596, 0), (4, 0, 1, 0, 549, -1423), (0, 0, 4, 0, 537, -1117),
    (4, -1, 0, 0, 520, -1571), (1, 0, -2, 0, -487, -1739), (2, 1, 0, -2, -399, 0),
    (0, 0, 2, -2, -381, -4421), (1, 1, 1, 0, 351, 0), (3, 0, -2, 0, -340, 0),
    (4, 0, -3, 0, 330, 0), (2, -1, 2, 0, 327, 0), (0, 2, 1, 0, -323, 1165),
    (1, 1, -1, 0, 299, 0), (2, 0, 3, 0, 294, 0), (2, 0, -1, -2, 0, 8752),
)
# Meeus table 47.B: D, M, M', F, Σb (1e-6 °).
MOON_B = (
    (0, 0, 0, 1, 5128122), (0, 0, 1, 1, 280602), (0, 0, 1, -1, 277693), (2, 0, 0, -1, 173237),
    (2, 0, -1, 1, 55413), (2, 0, -1, -1, 46271), (2, 0, 0, 1, 32573), (0, 0, 2, 1, 17198),
    (2, 0, 1, -1, 9266), (0, 0, 2, -1, 8822), (2, -1, 0, -1, 8216), (2, 0, -2, -1, 4324),
    (2, 0, 1, 1, 4200), (2, 1, 0, -1, -3359), (2, -1, -1, 1, 2463), (2, -1, 0, 1, 2211),
    (2, -1, -1, -1, 2065), (0, 1, -1, -1, -1870), (4, 0, -1, -1, 1828), (0, 1, 0, 1, -1794),
    (0, 0, 0, 3, -1749), (0, 1, -1, 1, -1565), (1, 0, 0, 1, -1491), (0, 1, 1, 1, -1475),
    (0, 1, 1, -1, -1410), (0, 1, 0, -1, -1344), (1, 0, 0, -1, -1335), (0, 0, 3, 1, 1107),
    (4, 0, 0, -1, 1021), (4, 0, -1, 1, 833), (0, 0, 1, -3, 777), (4, 0, -2, 1, 671),
    (2, 0, 0, -3, 607), (2, 0, 2, -1, 596), (2, -1, 1, -1, 491), (2, 0, -2, 1, -451),
    (0, 0, 3, -1, 439), (2, 0, 2, 1, 422), (2, 0, -3, -1, 421), (2, 1, -1, 1, -366),
    (2, 1, 0, 1, -351), (4, 0, 0, 1, 331), (2, -1, 1, 1, 315), (2, -2, 0, -1, 302),
    (0, 0, 1, 3, -283), (2, 1, 1, -1, -229), (1, 1, 0, -1, 223), (1, 1, 0, 1, 223),
)


def _sin(x):
    return math.sin(math.radians(x))


def _cos(x):
    return math.cos(math.radians(x))


def _norm(x):
    return x % 360.0


def _signed(x):
    """An angle in (-180, 180]."""
    x = _norm(x)
    return x - 360.0 if x > 180.0 else x


# Time

def julian_day(when: datetime) -> float:
    """The Julian day (UT) of an aware datetime."""
    if when.tzinfo is None:
        raise ValueError("an aware datetime is required")
    return J2000 + (when.astimezone(timezone.utc) - datetime(2000, 1, 1, 12, tzinfo=timezone.utc)) / timedelta(days=1)


def from_julian_day(jd: float) -> datetime:
    return datetime(2000, 1, 1, 12, tzinfo=timezone.utc) + timedelta(days=jd - J2000)


def delta_t(jd: float) -> float:
    """TT − UT in seconds: Espenak and Meeus's polynomials (NASA, 2006), good to seconds for 1900–2050."""
    y = 2000.0 + (jd - J2000) / 365.25
    if y < 1900:
        u = (y - 1820) / 100
        return -20 + 32 * u * u
    if y < 1920:
        t = y - 1900
        return -2.79 + 1.494119 * t - 0.0598939 * t ** 2 + 0.0061966 * t ** 3 - 0.000197 * t ** 4
    if y < 1941:
        t = y - 1920
        return 21.20 + 0.84493 * t - 0.076100 * t ** 2 + 0.0020936 * t ** 3
    if y < 1961:
        t = y - 1950
        return 29.07 + 0.407 * t - t ** 2 / 233 + t ** 3 / 2547
    if y < 1986:
        t = y - 1975
        return 45.45 + 1.067 * t - t ** 2 / 260 - t ** 3 / 718
    if y < 2005:
        t = y - 2000
        return 63.86 + 0.3345 * t - 0.060374 * t ** 2 + 0.0017275 * t ** 3 + 0.000651814 * t ** 4 + 0.00002373599 * t ** 5
    if y < 2050:
        t = y - 2000
        return 62.92 + 0.32217 * t + 0.005589 * t ** 2
    u = (y - 1820) / 100
    return -20 + 32 * u * u - 0.5628 * (2150 - y)


def _centuries(jde: float) -> float:
    return (jde - J2000) / 36525.0


def sidereal_time(jd: float) -> float:
    """Greenwich mean sidereal time (Meeus 12.4), degrees."""
    t = _centuries(jd)
    return _norm(280.46061837 + 360.98564736629 * (jd - J2000) + 0.000387933 * t * t - t ** 3 / 38710000)


def _nutation(t: float) -> tuple[float, float]:
    """The main terms of nutation (Meeus ch. 22, to 0.5″ and 0.1″): Δψ and Δε in degrees."""
    omega = 125.04452 - 1934.136261 * t
    sun = 280.4665 + 36000.7698 * t
    moon = 218.3165 + 481267.8813 * t
    dpsi = -17.20 * _sin(omega) - 1.32 * _sin(2 * sun) - 0.23 * _sin(2 * moon) + 0.21 * _sin(2 * omega)
    deps = 9.20 * _cos(omega) + 0.57 * _cos(2 * sun) + 0.10 * _cos(2 * moon) - 0.09 * _cos(2 * omega)
    return dpsi / 3600, deps / 3600


def obliquity(t: float) -> float:
    """The true obliquity of the ecliptic (Meeus 22.2 plus nutation), degrees."""
    mean = 23.0 + 26.0 / 60 + 21.448 / 3600 - (46.8150 * t + 0.00059 * t * t - 0.001813 * t ** 3) / 3600
    return mean + _nutation(t)[1]


def to_equatorial(lon: float, lat: float, eps: float) -> tuple[float, float]:
    """Ecliptic to right ascension and declination (Meeus 13.3, 13.4)."""
    ra = math.degrees(math.atan2(_sin(lon) * _cos(eps) - math.tan(math.radians(lat)) * _sin(eps), _cos(lon)))
    dec = math.degrees(math.asin(_sin(lat) * _cos(eps) + _cos(lat) * _sin(eps) * _sin(lon)))
    return _norm(ra), dec


def to_horizontal(ra: float, dec: float, jd: float, lat: float, lon: float) -> tuple[float, float]:
    """Azimuth (from north, through east) and altitude (Meeus 13.5, 13.6)."""
    h = _norm(sidereal_time(jd) + lon - ra)
    az = math.degrees(math.atan2(_sin(h), _cos(h) * _sin(lat) - math.tan(math.radians(dec)) * _cos(lat)))
    alt = math.degrees(math.asin(_sin(lat) * _sin(dec) + _cos(lat) * _cos(dec) * _cos(h)))
    return _norm(az + 180.0), alt


# Bodies: each gives apparent ecliptic longitude and latitude of date, and its distance

def sun(jde: float) -> tuple[float, float, float]:
    """The sun's apparent longitude, latitude (0) and distance in au (Meeus ch. 25)."""
    t = _centuries(jde)
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
    e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * _sin(m) + (0.019993 - 0.000101 * t) * _sin(2 * m)
         + 0.000289 * _sin(3 * m))
    nu = m + c
    r = 1.000001018 * (1 - e * e) / (1 + e * _cos(nu))
    omega = 125.04 - 1934.136 * t
    return _norm(l0 + c - 0.00569 - 0.00478 * _sin(omega)), 0.0, r


def moon(jde: float) -> tuple[float, float, float]:
    """The moon's apparent longitude, latitude and distance in au (Meeus ch. 47)."""
    t = _centuries(jde)
    lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t + t ** 3 / 538841 - t ** 4 / 65194000
    d = 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t + t ** 3 / 545868 - t ** 4 / 113065000
    m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t + t ** 3 / 24490000
    mp = 134.9633964 + 477198.8675055 * t + 0.0087414 * t * t + t ** 3 / 69699 - t ** 4 / 14712000
    f = 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t - t ** 3 / 3526000 + t ** 4 / 863310000
    a1 = 119.75 + 131.849 * t
    a2 = 53.09 + 479264.290 * t
    a3 = 313.45 + 481266.484 * t
    e = 1 - 0.002516 * t - 0.0000074 * t * t
    sl = sr = sb = 0.0
    for cd, cm, cmp, cf, lc, rc in MOON_LR:
        arg = cd * d + cm * m + cmp * mp + cf * f
        scale = e ** abs(cm)
        sl += lc * scale * _sin(arg)
        sr += rc * scale * _cos(arg)
    for cd, cm, cmp, cf, bc in MOON_B:
        sb += bc * e ** abs(cm) * _sin(cd * d + cm * m + cmp * mp + cf * f)
    sl += 3958 * _sin(a1) + 1962 * _sin(lp - f) + 318 * _sin(a2)
    sb += (-2235 * _sin(lp) + 382 * _sin(a3) + 175 * _sin(a1 - f) + 175 * _sin(a1 + f)
           + 127 * _sin(lp - mp) - 115 * _sin(lp + mp))
    dpsi = _nutation(t)[0]
    km = 385000.56 + sr / 1000
    return _norm(lp + sl / 1e6 + dpsi), sb / 1e6, km / AU_KM


def _heliocentric(name: str, t: float) -> tuple[float, float, float]:
    """Heliocentric ecliptic x, y, z (au; J2000) from the Keplerian elements at T centuries."""
    (a, da), (e, de), (i, di), (l, dl), (peri, dperi), (node, dnode) = ELEMENTS[name]
    a, e, i, l, peri, node = a + da * t, e + de * t, i + di * t, l + dl * t, peri + dperi * t, node + dnode * t
    m = math.radians(_signed(l - peri))
    big_e = m + e * math.sin(m)
    for _ in range(12):
        step = (big_e - e * math.sin(big_e) - m) / (1 - e * math.cos(big_e))
        big_e -= step
        if abs(step) < 1e-12:
            break
    xp, yp = a * (math.cos(big_e) - e), a * math.sqrt(1 - e * e) * math.sin(big_e)
    w, o, inc = math.radians(peri - node), math.radians(node), math.radians(i)
    x = (math.cos(w) * math.cos(o) - math.sin(w) * math.sin(o) * math.cos(inc)) * xp + \
        (-math.sin(w) * math.cos(o) - math.cos(w) * math.sin(o) * math.cos(inc)) * yp
    y = (math.cos(w) * math.sin(o) + math.sin(w) * math.cos(o) * math.cos(inc)) * xp + \
        (-math.sin(w) * math.sin(o) + math.cos(w) * math.cos(o) * math.cos(inc)) * yp
    z = math.sin(w) * math.sin(inc) * xp + math.cos(w) * math.sin(inc) * yp
    return x, y, z


def planet(name: str, jde: float) -> tuple[float, float, float]:
    """A planet's geocentric longitude and latitude of date, and its distance in au."""
    t = _centuries(jde)
    earth = _heliocentric("earth", t)
    x = y = z = dist = tau = 0.0
    for _ in range(3):  # light time: where the planet was when the light left it
        p = _heliocentric(name, t - tau / 36525.0)
        x, y, z = p[0] - earth[0], p[1] - earth[1], p[2] - earth[2]
        dist = math.sqrt(x * x + y * y + z * z)
        tau = 0.0057755183 * dist
    lon = math.degrees(math.atan2(y, x))
    lat = math.degrees(math.asin(z / dist))
    # J2000 to the equinox of date: the general precession in longitude, plus nutation.
    precession = (5029.0966 * t + 1.11113 * t * t) / 3600
    return _norm(lon + precession + _nutation(t)[0]), lat, dist


def ecliptic(body: str, jde: float) -> tuple[float, float, float]:
    if body == "sun":
        return sun(jde)
    if body == "moon":
        return moon(jde)
    if body in ELEMENTS and body != "earth":
        return planet(body, jde)
    raise ValueError(f"unknown body {body!r}")


@dataclass(frozen=True)
class Position:
    body: str
    lon: float        # apparent ecliptic longitude of date
    lat: float
    ra: float
    dec: float
    distance: float   # au
    azimuth: float | None = None
    altitude: float | None = None   # geometric, topocentric (the moon's parallax included)


def position(body: str, jd: float, lat: float | None = None, lon: float | None = None) -> Position:
    """A body's place at the Julian day (UT); with a location, also where it stands in the sky there."""
    jde = jd + delta_t(jd) / 86400
    elon, elat, dist = ecliptic(body, jde)
    ra, dec = to_equatorial(elon, elat, obliquity(_centuries(jde)))
    if lat is None or lon is None:
        return Position(body, elon, elat, ra, dec, dist)
    az, alt = to_horizontal(ra, dec, jd, lat, lon)
    # Parallax in altitude (Meeus ch. 40, to first order): up to ~1° for the moon, 9″ for the sun.
    parallax = math.degrees(math.asin(min(1.0, EARTH_RADIUS_KM / (dist * AU_KM))))
    return Position(body, elon, elat, ra, dec, dist, az, alt - parallax * _cos(alt))


def separation(a: Position, b: Position) -> float:
    """The angle between two bodies on the sky, degrees."""
    c = _sin(a.dec) * _sin(b.dec) + _cos(a.dec) * _cos(b.dec) * _cos(a.ra - b.ra)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


# The moon's face

def elongation(jd: float) -> float:
    """The moon's longitude east of the sun, 0–360: 0 new, 90 first quarter, 180 full, 270 last quarter."""
    jde = jd + delta_t(jd) / 86400
    return _norm(moon(jde)[0] - sun(jde)[0])


def illumination(jd: float) -> float:
    """The illuminated fraction of the moon's disc, 0–1 (Meeus 48.1 to 48.3)."""
    jde = jd + delta_t(jd) / 86400
    ml, mb, md = moon(jde)
    sl, _, sr = sun(jde)
    psi = math.degrees(math.acos(_cos(mb) * _cos(ml - sl)))
    i = math.degrees(math.atan2(sr * _sin(psi), md - sr * _cos(psi)))
    return (1 + _cos(i)) / 2


PHASES = ("new", "first", "full", "last")


def phase_name(elong: float) -> str:
    """The phase the eye calls it: the four principal phases hold ±6° (half a day) around their instant."""
    names = ("new", "waxing crescent", "first quarter", "waxing gibbous", "full", "waning gibbous",
             "last quarter", "waning crescent")
    for k, centre in enumerate((0, 90, 180, 270)):
        if abs(_signed(elong - centre)) <= 6:
            return names[2 * k]
    return names[int(_norm(elong) // 90) * 2 + 1]


def _root(f, lo: float, hi: float, tolerance: float = 1e-6) -> float:
    """Bisection on [lo, hi] where f changes sign."""
    flo = f(lo)
    for _ in range(60):
        mid = (lo + hi) / 2
        fm = f(mid)
        if (fm < 0) == (flo < 0):
            lo, flo = mid, fm
        else:
            hi = mid
        if hi - lo < tolerance:
            break
    return (lo + hi) / 2


def next_phase(jd: float, which: str) -> float:
    """The Julian day (UT) of the next principal phase ("new", "first", "full", "last") after jd."""
    target = 90.0 * PHASES.index(which)
    f = lambda x: _signed(elongation(x) - target)
    # The elongation grows ~12.2° a day; step a day at a time until it crosses the target from below.
    lo = jd
    for _ in range(32):
        hi = lo + 1.0
        if f(lo) < 0 <= f(hi):
            return _root(f, lo, hi)
        lo = hi
    raise ArithmeticError("no phase found within a month")


# Rising and setting

def standard_altitude(body: str, jd: float) -> float:
    if body == "sun":
        return SUN_H0
    if body == "moon":
        parallax = math.degrees(math.asin(EARTH_RADIUS_KM / (moon(jd + delta_t(jd) / 86400)[2] * AU_KM)))
        return 0.7275 * parallax - 0.5667
    return PLANET_H0


def _geometric_altitude(body: str, jd: float, lat: float, lon: float) -> float:
    """The geocentric altitude, which Meeus's standard altitudes are defined against."""
    jde = jd + delta_t(jd) / 86400
    elon, elat, _ = ecliptic(body, jde)
    ra, dec = to_equatorial(elon, elat, obliquity(_centuries(jde)))
    return to_horizontal(ra, dec, jd, lat, lon)[1]


def crossings(body: str, start: float, end: float, lat: float, lon: float, step: float = 1 / 48) -> list[tuple[str, float]]:
    """("rise" | "set", Julian day UT) of the body's standard altitude between start and end, in order.
    Sampled every `step` days (30 min) and refined by bisection, so a crossing pair closer than that can be missed."""
    found = []
    f = lambda x: _geometric_altitude(body, x, lat, lon) - standard_altitude(body, x)
    t0, f0 = start, f(start)
    while t0 < end:
        t1 = min(end, t0 + step)
        f1 = f(t1)
        if (f0 < 0) != (f1 < 0):
            found.append(("rise" if f1 > f0 else "set", _root(f, t0, t1)))
        t0, f0 = t1, f1
    return found


# Sky events for discovery

def events(start: float, end: float, lat: float, lon: float, conjunction: float = 3.0) -> list[dict]:
    """The sky's events between two Julian days (UT), in time order, each {kind, body, jd, ...}:
    moon phases ("moon.new", "moon.first", "moon.full", "moon.last"), sunrise and sunset ("sun.rise", "sun.set"),
    and conjunctions ("conjunction": two of the moon and the five naked-eye planets closest, within `conjunction`°,
    with `bodies` and `separation`). Conjunctions are found from a 2-hour sampling, each minimum refined to a minute."""
    out = []
    for which in PHASES:
        t = start
        while True:
            t = next_phase(t, which)
            if t >= end:
                break
            out.append({"kind": f"moon.{which}", "body": "moon", "jd": t})
            t += 1
    for kind, t in crossings("sun", start, end, lat, lon):
        out.append({"kind": f"sun.{kind}", "body": "sun", "jd": t})
    bright = ("moon", "mercury", "venus", "mars", "jupiter", "saturn")
    step = 1 / 12
    times = [start - step + k * step for k in range(int((end - start) / step) + 3)]
    places = [{b: position(b, t) for b in bright} for t in times]
    for i, a in enumerate(bright):
        for b in bright[i + 1:]:
            seps = [separation(p[a], p[b]) for p in places]
            for k in range(1, len(seps) - 1):
                if not (seps[k] <= seps[k - 1] and seps[k] < seps[k + 1]):
                    continue
                gap = lambda t: separation(position(a, t), position(b, t))
                lo, hi = times[k - 1], times[k + 1]
                while hi - lo > 1 / 1440:  # golden-section search for the closest minute
                    m1, m2 = hi - (hi - lo) / 1.618034, lo + (hi - lo) / 1.618034
                    if gap(m1) < gap(m2):
                        hi = m2
                    else:
                        lo = m1
                t, closest = (lo + hi) / 2, gap((lo + hi) / 2)
                if closest <= conjunction and start <= t < end:
                    out.append({"kind": "conjunction", "body": a, "bodies": [a, b], "jd": t, "separation": round(closest, 2)})
    return sorted(out, key=lambda e: e["jd"])


def tracks(jd: float, lat: float, lon: float, hours: float = 12.0, step: float = 15.0) -> dict:
    """Each body's path across the sky from `hours` before jd to `hours` after, every `step` minutes, as
    [[azimuth, altitude], ...] (altitude topocentric). The equatorial place is computed at three instants and
    interpolated (the moon moves ~13° a day, the rest far less), so a day's track costs 27 ephemerides."""
    count = int(round(2 * hours * 60 / step)) + 1
    out = {}
    for body in BODIES:
        anchors = []
        for k in (-1, 0, 1):
            t = jd + k * hours / 24
            jde = t + delta_t(t) / 86400
            elon, elat, dist = ecliptic(body, jde)
            ra, dec = to_equatorial(elon, elat, obliquity(_centuries(jde)))
            anchors.append((ra, dec, dist))
        path = []
        for i in range(count):
            u = -1 + 2 * i / (count - 1)                 # -1 … 1 across the span
            a, b = (anchors[0], anchors[1]) if u < 0 else (anchors[1], anchors[2])
            f = u + 1 if u < 0 else u
            ra = a[0] + _signed(b[0] - a[0]) * f
            dec = a[1] + (b[1] - a[1]) * f
            dist = a[2] + (b[2] - a[2]) * f
            az, alt = to_horizontal(_norm(ra), dec, jd + u * hours / 24, lat, lon)
            parallax = math.degrees(math.asin(min(1.0, EARTH_RADIUS_KM / (dist * AU_KM))))
            path.append([round(az, 1), round(alt - parallax * _cos(alt), 1)])
        out[body] = path
    return {"from": -hours, "to": hours, "step": step, "paths": out}


def snapshot(when: datetime, lat: float, lon: float) -> dict:
    """What the clock draws: every body's place, the moon's face, and today's sun."""
    jd = julian_day(when)
    bodies = {}
    for body in BODIES:
        p = position(body, jd, lat, lon)
        assert p.azimuth is not None and p.altitude is not None
        bodies[body] = {"lon": round(p.lon, 3), "lat": round(p.lat, 3), "ra": round(p.ra, 3), "dec": round(p.dec, 3),
                        "distance": round(p.distance, 6), "azimuth": round(p.azimuth, 2), "altitude": round(p.altitude, 2)}
    elong = elongation(jd)
    day = math.floor(jd - 0.5 + lon / 360) + 0.5 - lon / 360  # local mean midnight before `when`, as a JD
    sun_today = {kind: from_julian_day(t).isoformat(timespec="seconds") for kind, t in crossings("sun", day, day + 1, lat, lon)}
    return {"at": when.astimezone(timezone.utc).isoformat(timespec="seconds"), "jd": round(jd, 6),
            "bodies": bodies, "moon": {"elongation": round(elong, 2), "illumination": round(illumination(jd), 4),
                                       "phase": phase_name(elong), "waxing": elong < 180},
            "sun": sun_today, "sidereal": round(_norm(sidereal_time(jd) + lon), 3)}
