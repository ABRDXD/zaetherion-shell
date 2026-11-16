"""The Inbox as the day's sky (Z211): the layout maths under Node, and the room offscreen on the fixture."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import cuetest  # noqa: E402

CHECKS = ("one.comet.each", "starts.on.newest.unread", "urgent.flies.high", "newer.nearer.now", "click.reads",
          "dismiss.names.it", "falls.back")
H = 3600000


def run(expr):
    body = "\n".join(l for l in (ROOT / "view/rooms/InboxSky.js").read_text().splitlines() if not l.startswith(".pragma"))
    return json.loads(subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expr}));"],
                                     capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class SkyLayout(unittest.TestCase):
    def test_span_is_six_hours_to_a_day(self):
        now = 1_800_000_000_000
        self.assertEqual(run(f"span([], {now})"), {"from": now - 6 * H, "to": now})
        self.assertEqual(run(f"span([{{time: {now - 10 * H}}}], {now})")["from"], now - 10 * H)
        self.assertEqual(run(f"span([{{time: {now - 40 * H}}}], {now})")["from"], now - 24 * H)
        self.assertEqual(run(f"span([{{time: {(now - 10 * H) // 1000}}}], {now})")["from"], now - 10 * H)

    def test_along_runs_old_to_now_and_pins_older(self):
        now = 1_800_000_000_000
        s = f"{{from: {now - 6 * H}, to: {now}}}"
        self.assertEqual(run(f"[along({now - 6 * H}, {s}), along({now - 3 * H}, {s}), along({now}, {s}), along({now - 9 * H}, {s})]"),
                         [0, 0.5, 1, 0])

    def test_urgent_is_higher_than_quiet(self):
        crit, normal, low, other = run('[height("critical", 0), height("normal", 0), height("low", 0), height("weird", 0)]')
        self.assertLess(crit, normal)
        self.assertLess(normal, low)
        self.assertEqual(other, normal)
        self.assertNotEqual(run('height("normal", 1)'), normal)

    def test_hours_fall_inside_and_thin_out(self):
        now = 1_800_000_000_000
        short = run(f"hours({{from: {now - 6 * H}, to: {now}}})")
        long = run(f"hours({{from: {now - 24 * H}, to: {now}}})")
        self.assertTrue(all(0 <= h["at"] <= 1 for h in short + long))
        self.assertTrue(all(h["hour"] % 3 == 0 for h in long))
        self.assertGreaterEqual(len(short), 5)

    def test_initial_and_unread_line(self):
        self.assertEqual(run('initial([{id:"a",read:false},{id:"b",read:false},{id:"c",read:true}])'), "b")
        self.assertEqual(run('initial([{id:"a",read:true},{id:"b",read:true}])'), "b")
        self.assertIsNone(run("initial([])"))
        self.assertEqual(run('unreadLine([{appName:"Mail",read:false},{appName:"Chat",read:true},{appName:"Mail",read:false},{appName:"Pager",read:false}])'),
                         "Mail, Pager")
        self.assertEqual(run('unreadLine([{appName:"Mail",read:true}])'), "all caught up")


class SkyRoom(unittest.TestCase):
    def test_room(self):
        output = cuetest.run("InboxSkyTest.qml", timeout=90)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
