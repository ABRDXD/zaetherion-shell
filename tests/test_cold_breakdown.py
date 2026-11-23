"""The cold-open phase parser (tools/measure/cold_breakdown.py), from log excerpts."""
from datetime import datetime
import unittest

from tools.measure.cold_breakdown import parse_warm, parse, summary


def local(ms: float, sep: str = ".") -> str:
    """A log timestamp (local time, whole ms) for wall-clock ms."""
    return datetime.fromtimestamp(ms / 1000).strftime("%Y-%m-%d %H:%M:%S") + f"{sep}{int(ms % 1000):03d}"


class ColdBreakdownTests(unittest.TestCase):
    def logs(self, sent):
        core = f"{local(sent + 2, ',')} INFO fart.view: view spawned (pid 42)\n"
        view = "\n".join([
            f"{local(sent + 60)}  INFO: Launching config: \"/x/FixtureView.qml\"",
            f"{local(sent + 300)} DEBUG qml: FART_COLD created {sent + 300}",
            f"{local(sent + 303)} DEBUG qml: FART_COLD command {sent + 303}",
            f"{local(sent + 350)} DEBUG qml: FART_COLD shell {sent + 350}",
            f"{local(sent + 352)} DEBUG qml: FART_COLD handled {sent + 352}",
            f"{local(sent + 355)} DEBUG qml: FART_CMDLINE ready {sent + 355}",
        ])
        return core, view

    def test_phases_add_up_to_the_total(self):
        sent = 1_794_000_000_000.0
        phases = parse(sent, *self.logs(sent))
        self.assertEqual({k: round(v) for k, v in phases.items()},
                         dict(core=2, exec=58, load=240, hello=3, open=49, frame=3, **{"open.shell": 47}, total=355))

    def test_the_frame_phase_splits_after_handled(self):
        sent = 1_794_000_000_000.0
        core, view = self.logs(sent)
        view = view.replace("DEBUG qml: FART_CMDLINE ready", f"DEBUG qml: FART_COLD swap {sent + 353}\n"
                            f"x DEBUG qml: FART_COLD focus {sent + 354}\nx DEBUG qml: FART_CMDLINE ready")
        phases = parse(sent, core, view)
        self.assertEqual((round(phases["frame.swap"]), round(phases["frame.focus"])), (1, 2))
        self.assertNotIn("frame.active", phases)

    def test_a_warm_open_splits_into_relay_handle_and_frame(self):
        sent = 1_794_000_000_000.0
        log = "\n".join(f"x DEBUG qml: {line}" for line in (
            f"FART_COLD command {sent + 1:.0f}", f"FART_COLD handled {sent + 3:.0f}", f"FART_COLD swap {sent + 9:.0f}",
            f"FART_COLD active {sent + 60:.0f}", f"FART_CMDLINE ready {sent + 61:.0f}"))
        phases = parse_warm(sent, log)
        self.assertEqual({k: round(v) for k, v in phases.items()},
                         {"relay": 1, "handle": 2, "frame": 58, "frame.swap": 6, "frame.active": 57, "total": 61})
        self.assertIsNone(parse_warm(sent, log.replace("FART_CMDLINE ready", "later")))

    def test_a_missing_marker_gives_no_result(self):
        sent = 1_794_000_000_000.0
        core, view = self.logs(sent)
        self.assertIsNone(parse(sent, core, view.replace("FART_CMDLINE ready", "FART_CMDLINE later")))
        self.assertIsNone(parse(sent, "", view))

    def test_summary_takes_median_min_and_max(self):
        rows = [dict(total=t) for t in (300, 100, 200)]
        self.assertEqual(summary(rows), {"total": dict(median=200, min=100, max=300)})


if __name__ == "__main__":
    unittest.main()
