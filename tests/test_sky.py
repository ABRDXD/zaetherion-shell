"""core/sky.py against reference values for fixed dates (M10: positions within 1°).

References:
- Jean Meeus, *Astronomical Algorithms* (2nd ed.), worked examples 12.a, 15.a, 25.a, 33.a, 47.a, 48.a and 49.a.
- NASA JPL Horizons (ssd.jpl.nasa.gov, DE441), queried 8 November 2026: observer tables at the geocentre
  (quantities 2, 20, 31: apparent RA/Dec, distance, apparent ecliptic of date) and at Greenwich
  (51.4769 N, 0 E; quantity 4, airless azimuth and elevation; and rise/transit/set with refraction).
"""
from datetime import datetime, timezone
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core import sky  # noqa: E402

GREENWICH = (51.4769, 0.0)
# Horizons, geocentric: jd (UT): body: (ra, dec, ecliptic longitude, latitude, distance au)
GEO = {
    2448976.5: {
        "sun": (268.2088, -23.4296, 268.3565, -0.0002, 0.983824),
        "moon": (215.8969, -18.0078, 219.478, -3.5448, 0.00253),
        "mercury": (248.498, -20.8923, 249.9711, 1.0647, 1.215809),
        "venus": (316.1735, -18.8878, 313.0821, -2.0848, 0.910943),
        "mars": (117.1471, 24.5928, 114.5593, 3.4381, 0.648325),
        "jupiter": (191.7902, -3.6987, 192.2858, 1.2562, 5.599099),
        "saturn": (317.9244, -17.2613, 315.1489, -1.0136, 10.514408),
        "uranus": (288.4527, -22.7703, 286.9694, -0.4111, 20.500034),
        "neptune": (289.3104, -21.5709, 287.9115, 0.676, 31.113318),
    },
    2451545.0: {
        "sun": (281.2784, -23.0324, 280.3689, 0.0002, 0.983328),
        "moon": (222.4522, -10.9007, 223.3238, 5.1707, 0.00269),
        "mercury": (272.0746, -24.4189, 271.8893, -0.9948, 1.415469),
        "venus": (239.8928, -18.4489, 241.5658, 2.0664, 1.137579),
        "mars": (330.5168, -13.1825, 327.9633, -1.0678, 1.849688),
        "jupiter": (23.8678, 8.5943, 25.2531, -1.2622, 4.621175),
        "saturn": (38.7654, 12.6148, 40.3956, -2.4449, 8.652797),
        "uranus": (317.4748, -17.0203, 314.8092, -0.6583, 20.727171),
        "neptune": (305.4328, -19.2132, 303.193, 0.235, 31.024498),
    },
    2461352.5: {
        "sun": (223.1255, -16.5076, 225.5911, -0.0001, 0.990959),
        "moon": (206.9467, -15.9358, 210.7025, -4.5073, 0.002632),
        "mercury": (215.9602, -13.4783, 218.0752, 0.7616, 0.701866),
        "venus": (200.6683, -12.0608, 203.6026, -3.1194, 0.29988),
        "mars": (145.0168, 15.8102, 142.0636, 1.7508, 1.374895),
        "jupiter": (147.6399, 13.8222, 145.1152, 0.7144, 5.392427),
        "saturn": (9.2023, 1.066, 8.8744, -2.6669, 8.611004),
        "uranus": (62.4679, 20.875, 64.4115, -0.1506, 18.493736),
        "neptune": (2.3472, -0.5211, 1.9466, -1.4115, 29.152555),
    },
    2464500.25: {
        "sun": (90.236, 23.4319, 90.2165, 0.0, 1.016205),
        "moon": (280.9573, -18.7939, 280.3952, 4.2438, 0.002713),
        "mercury": (66.372, 18.4143, 67.6125, -3.2008, 0.865833),
        "venus": (75.7167, 22.2964, 76.8042, -0.484, 1.670831),
        "mars": (344.7304, -10.234, 342.0006, -3.4372, 0.706261),
        "jupiter": (39.6775, 14.3402, 41.7721, -1.0731, 5.579291),
        "saturn": (126.352, 19.789, 123.9013, 0.5316, 9.928558),
        "uranus": (101.0158, 23.3736, 100.1021, 0.3269, 19.859595),
        "neptune": (23.0739, 7.8766, 24.2594, -1.6412, 30.235309),
    },
}
# Horizons, Greenwich: jd (UT): body: (azimuth from north, airless elevation)
TOPO = {
    2448976.5: {"sun": (1.212, -61.95), "moon": (71.36, -37.553), "mars": (130.398, 55.501)},
    2451545.0: {"sun": (179.217, 15.485), "moon": (237.784, 9.248), "mars": (130.211, 12.174)},
    2461352.5: {"sun": (6.799, -54.882), "moon": (31.896, -51.531), "mars": (74.069, 7.563)},
    2464500.25: {"sun": (284.764, 18.406), "moon": (93.504, -22.33), "mars": (21.969, -46.967)},
}
# Horizons, Greenwich, refracted rise and set (to the minute), 8–9 November 2026 UT.
RISE_SET = {
    "sun": [("rise", "2026-11-08 07:06"), ("set", "2026-11-08 16:22"), ("rise", "2026-11-09 07:08"), ("set", "2026-11-09 16:20")],
    "moon": [("rise", "2026-11-08 06:24"), ("set", "2026-11-08 15:25"), ("rise", "2026-11-09 07:40"), ("set", "2026-11-09 15:46")],
}


def utc(text: str) -> datetime:
    return datetime.strptime(text, "%Y-%m-%d %H:%M").replace(tzinfo=timezone.utc)


class MeeusExamples(unittest.TestCase):
    def test_julian_day_and_sidereal_time(self):
        self.assertAlmostEqual(sky.julian_day(utc("2000-01-01 12:00")), 2451545.0, places=9)
        self.assertAlmostEqual(sky.julian_day(utc("1987-04-10 00:00")), 2446895.5, places=9)
        # 12.a: 13h10m46.3668s at 0h UT on 1987 April 10.
        self.assertAlmostEqual(sky.sidereal_time(2446895.5), 197.693195, places=5)
        self.assertEqual(sky.from_julian_day(2451545.0), utc("2000-01-01 12:00"))
        with self.assertRaises(ValueError):
            sky.julian_day(datetime(2000, 1, 1))

    def test_sun_25a(self):
        lon, lat, r = sky.sun(2448908.5)
        self.assertAlmostEqual(lon, 199.90895, delta=0.0005)
        self.assertAlmostEqual(r, 0.99766, delta=0.0001)
        ra, dec = sky.to_equatorial(lon, lat, 23.43999 + 0.00256 * sky._cos(125.04 - 1934.136 * sky._centuries(2448908.5)))
        self.assertAlmostEqual(ra, 198.38083, delta=0.002)
        self.assertAlmostEqual(dec, -7.78507, delta=0.002)

    def test_moon_47a(self):
        lon, lat, dist = sky.moon(2448724.5)
        self.assertAlmostEqual(lon, 133.167265, delta=0.001)
        self.assertAlmostEqual(lat, -3.229126, delta=0.001)
        self.assertAlmostEqual(dist * sky.AU_KM, 368409.7, delta=2)

    def test_illumination_48a(self):
        jd = 2448724.5 - sky.delta_t(2448724.5) / 86400   # 1992 April 12, 0h TD
        self.assertAlmostEqual(sky.illumination(jd), 0.6786, delta=0.001)

    def test_venus_33a(self):
        p = sky.position("venus", 2448976.5 - sky.delta_t(2448976.5) / 86400)  # 1992 December 20, 0h TD
        self.assertAlmostEqual(p.ra, 316.17273, delta=0.01)
        self.assertAlmostEqual(p.dec, -18.88801, delta=0.01)

    def test_new_moon_49a(self):
        jd = sky.next_phase(2443180.0, "new")
        self.assertAlmostEqual(jd + sky.delta_t(jd) / 86400, 2443192.65118, delta=2 / 1440)

    def test_venus_rises_and_sets_at_boston_15a(self):
        start = sky.julian_day(utc("1988-03-20 00:00"))
        got = sky.crossings("venus", start, start + 1, 42.3333, -71.0833)
        self.assertEqual([k for k, _ in got], ["set", "rise"])
        self.assertLess(abs(sky.from_julian_day(got[0][1]) - utc("1988-03-20 02:55")).total_seconds(), 120)
        self.assertLess(abs(sky.from_julian_day(got[1][1]) - utc("1988-03-20 12:25")).total_seconds(), 120)


class HorizonsReference(unittest.TestCase):
    def test_every_body_within_a_degree_on_four_dates(self):
        worst = 0.0
        for jd, bodies in GEO.items():
            for body, (ra, dec, lon, lat, dist) in bodies.items():
                with self.subTest(body=body, jd=jd):
                    p = sky.position(body, jd)
                    on_sky = sky.separation(p, sky.Position(body, lon, lat, ra, dec, dist))
                    self.assertLess(on_sky, 1.0)
                    self.assertLess(abs(sky._signed(p.lon - lon)), 1.0)
                    self.assertLess(abs(p.lat - lat), 1.0)
                    self.assertLess(abs(p.distance - dist) / dist, 0.005)
                    worst = max(worst, on_sky)
        # What the algorithms give today (Saturn's, the largest, is Standish's own error): a regression bound.
        self.assertLess(worst, 0.2)

    def test_azimuth_and_altitude_at_greenwich_with_the_moon_s_parallax(self):
        for jd, bodies in TOPO.items():
            for body, (az, el) in bodies.items():
                with self.subTest(body=body, jd=jd):
                    p = sky.position(body, jd, *GREENWICH)
                    self.assertLess(abs(sky._signed(p.azimuth - az)), 0.1)
                    self.assertLess(abs(p.altitude - el), 0.1)

    def test_rise_and_set_at_greenwich_within_two_minutes(self):
        start = sky.julian_day(utc("2026-11-08 00:00"))
        for body, expected in RISE_SET.items():
            with self.subTest(body=body):
                got = sky.crossings(body, start, start + 2, *GREENWICH)
                self.assertEqual([k for k, _ in got], [k for k, _ in expected])
                for (_, t), (_, when) in zip(got, expected):
                    self.assertLess(abs(sky.from_julian_day(t) - utc(when)).total_seconds(), 120, (body, when))


class Events(unittest.TestCase):
    def test_the_great_conjunction_of_2020(self):
        start = sky.julian_day(utc("2020-12-15 00:00"))
        found = [e for e in sky.events(start, start + 12, *GREENWICH) if e["kind"] == "conjunction" and e["bodies"] == ["jupiter", "saturn"]]
        self.assertEqual(len(found), 1)
        # 0.10° at about 18:20 UT on 21 December. The two slow planets close at ~0.1° a day, so their 0.1–0.16°
        # errors move the moment by hours: within a day, the separation within 0.03°.
        self.assertAlmostEqual(found[0]["separation"], 0.10, delta=0.03)
        self.assertLess(abs(sky.from_julian_day(found[0]["jd"]) - utc("2020-12-21 18:20")).total_seconds(), 86400)

    def test_a_month_has_each_phase_once_and_events_are_in_order(self):
        start = sky.julian_day(utc("2026-11-01 00:00"))
        got = sky.events(start, start + 29.5, *GREENWICH)
        self.assertEqual(sorted(e["kind"] for e in got if e["kind"].startswith("moon.")), ["moon.first", "moon.full", "moon.last", "moon.new"])
        self.assertEqual([e["jd"] for e in got], sorted(e["jd"] for e in got))
        self.assertTrue(all(start <= e["jd"] < start + 29.5 for e in got))
        # Greenwich in November: a sunrise every morning, 1 to 30 November (the span ends at noon on the 30th).
        self.assertEqual(sum(e["kind"] == "sun.rise" for e in got), 30)
        self.assertEqual(sum(e["kind"] == "sun.set" for e in got), 29)

    def test_phases_and_their_names(self):
        jd = sky.next_phase(sky.julian_day(utc("2026-11-01 00:00")), "full")
        self.assertAlmostEqual(sky.elongation(jd), 180, delta=0.001)
        self.assertGreater(sky.illumination(jd), 0.99)
        self.assertEqual([sky.phase_name(e) for e in (0, 3, 45, 90, 135, 180, 200, 270, 300, 357)],
                         ["new", "new", "waxing crescent", "first quarter", "waxing gibbous", "full",
                          "waning gibbous", "last quarter", "waning crescent", "new"])

    def test_the_polar_night_has_no_sunrise(self):
        start = sky.julian_day(utc("2026-12-21 00:00"))
        self.assertEqual(sky.crossings("sun", start, start + 1, 78.22, 15.65), [])   # Longyearbyen


class Tracks(unittest.TestCase):
    def test_a_day_of_paths_matches_direct_positions(self):
        jd = sky.julian_day(utc("2026-11-08 00:00"))
        got = sky.tracks(jd, *GREENWICH)
        self.assertEqual((got["from"], got["to"], got["step"]), (-12.0, 12.0, 15.0))
        self.assertEqual(set(got["paths"]), set(sky.BODIES))
        for body, path in got["paths"].items():
            self.assertEqual(len(path), 97)
            for i in range(0, 97, 12):
                with self.subTest(body=body, i=i):
                    p = sky.position(body, jd + (-12 + i * 0.25) / 24, *GREENWICH)
                    self.assertLess(abs(p.altitude - path[i][1]), 0.2)
                    self.assertLess(abs(sky._signed(p.azimuth - path[i][0])) * math.cos(math.radians(p.altitude)), 0.2)


class Snapshot(unittest.TestCase):
    def test_what_the_clock_draws(self):
        snap = sky.snapshot(utc("2026-11-08 12:00"), *GREENWICH)
        self.assertEqual(set(snap["bodies"]), set(sky.BODIES))
        self.assertEqual(snap["moon"]["phase"], "waning crescent")
        self.assertFalse(snap["moon"]["waxing"])
        self.assertEqual(snap["sun"], {"rise": "2026-11-08T07:05:40+00:00", "set": "2026-11-08T16:21:10+00:00"})
        noon_sun = snap["bodies"]["sun"]
        self.assertGreater(noon_sun["altitude"], 20)
        self.assertAlmostEqual(noon_sun["azimuth"], 180, delta=5)


if __name__ == "__main__":
    unittest.main()
