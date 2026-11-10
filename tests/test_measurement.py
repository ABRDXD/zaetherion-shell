import json
import os
from pathlib import Path
import socket
import tempfile
import unittest
from unittest.mock import patch

from tools.measure.budgets import BUDGETS
from tools.measure import desktop_nav
from tools.measure.desktop_nav import combined, exit_code, wait_marker
from tools.measure.frames import (cmdline_markers, desktop_checks, desktop_stats, frame_stats, missed_presentations,
                                  open_checks, open_stats)
from tools.measure.interaction import FOCUS, Interaction
from tools.measure.smaps import window


class MeasurementTests(unittest.TestCase):
    def test_recorded_qt_612_software_lines(self):
        lines = """ DEBUG qt.scenegraph.time.renderloop: Frame rendered with 'software' renderloop in 9ms, polish=0, sync=2, render=7, swap=0, frameDelta=0
 DEBUG qt.scenegraph.time.renderloop: Frame rendered with 'software' renderloop in 0ms, polish=0, sync=0, render=0, swap=0, frameDelta=2
 DEBUG qt.scenegraph.time.renderloop: Frame rendered with 'software' renderloop in 4ms, polish=0, sync=1, render=2, swap=0, frameDelta=296
 DEBUG qt.scenegraph.time.renderloop: [window 0x1][gui thread] syncAndRender: last retrieved GPU frame time was 20.0 ms"""
        self.assertEqual(frame_stats(lines.splitlines(), 6.9),
                         dict(count=3, median_ms=4, p95_ms=9, p99_ms=9, budget_ms=6.9, missed_frames=1,
                              p99_note="fewer than 100 frames: p99 is the slowest frame"))

    def test_empty_and_threaded_timings(self):
        self.assertIsNone(frame_stats([], 6.9)["p99_ms"])
        lines = ["qt.scenegraph.time.renderloop: [window 0x1][render thread 0x2] "
                 f"syncAndRender: frame rendered in {n}ms, sync=0, render=1, swap=0" for n in range(1, 101)]
        result = frame_stats(lines, 6.9)
        self.assertIsNone(result["p99_note"])
        self.assertEqual((result["median_ms"], result["p95_ms"], result["p99_ms"]), (50.5, 95, 99))

    def test_desktop_stats_per_room(self):
        rt = "qt.scenegraph.time.renderloop: [window 0x1][render thread 0x2] syncAndRender: "
        gui = "qt.scenegraph.time.renderloop: [window 0x1][gui thread] Frame prepared, polish={} ms, lock=0 ms, blockedForSync=6 ms, animations=0 ms"
        probe = [["home", 6.9], ["home", 7.0], ["media", 30.2], ["media", 6.9], ["media", 12.0], ["tasks", 9.0], ["tasks", 7.1]]
        lines = [
            " DEBUG qml: FART_PAGE home 0", " DEBUG qml: FART_LOAD home 40",
            rt + "frame rendered in 50ms, sync=40, render=4, swap=6",  # segment 0: first open, excluded
            " DEBUG qml: FART_PAGE media 2", " DEBUG qml: FART_LOAD media 21", gui.format(3), gui.format(1),
            rt + "frame rendered in 7ms, sync=0, render=1, swap=6",
            rt + "frame rendered in 6ms, sync=0, render=-3, swap=9",  # skipped frame
            rt + "last retrieved GPU frame time was 0.25 ms",
            " DEBUG qml: FART_PAGE tasks 5", " DEBUG qml: FART_LOAD tasks 2",
            rt + "frame rendered in 7ms, sync=1, render=0, swap=6",
            " DEBUG qml: FART_FRAMES " + json.dumps(probe)]
        result = desktop_stats(lines, 6.9, 144.0)
        self.assertEqual(result["navigations"], 2)
        self.assertAlmostEqual(result["missed_threshold_ms"], 1.5 * 1000 / 144)
        media, tasks = result["rooms"]["media"], result["rooms"]["tasks"]
        self.assertNotIn("home", result["rooms"])
        self.assertEqual(media["load_frames_in_order_ms"], [30.2])
        self.assertEqual((media["interval_ms"]["count"], media["interval_ms"]["over"]), (2, 1))
        self.assertEqual((media["create_ms_in_order"], media["polish_max_ms_in_order"]), ([21], [3]))
        self.assertEqual(media["render_thread_work_ms"]["max"], 1)  # vsync wait excluded, skipped frame ignored
        self.assertEqual(media["vsync_wait_ms"]["max"], 6)
        self.assertEqual(media["gpu_ms"]["max"], 0.25)
        self.assertEqual((tasks["load_frame_ms"]["over"], tasks["interval_ms"]["count"]), (0, 1))
        self.assertEqual(result["intervals"]["count"], 5)
        self.assertEqual((media["missed_steady"], media["missed_per_load_max"]), (1, 3))  # 12.0 ms skips one, 30.2 ms three
        self.assertEqual((tasks["missed_steady"], tasks["missed_per_load_max"]), (0, 0))
        checks = desktop_checks(result, BUDGETS["desktop_navigate"])
        self.assertEqual({k: c["status"] for k, c in checks.items()},
                         dict(missed_steady="fail", missed_per_load="fail", gpu_p99_ms="pass", render_thread_p99_ms="pass"))
        self.assertEqual(checks["missed_per_load"]["measured"], 3)

    def test_missed_presentations(self):
        period = 1000 / 144
        self.assertEqual([missed_presentations(ms, period) for ms in (6.9, 10.3, 10.5, 13.9, 17.5, 21.0)], [0, 0, 1, 1, 2, 2])

    def test_proc_window(self):
        proc = window(os.getpid(), .02)[0]
        self.assertGreaterEqual(proc["memory_kib"]["Rss"], proc["memory_kib"]["Pss"])
        self.assertGreater(proc["voluntary_switches"], 0)

    def test_cmdline_ready_markers(self):
        lines = [" DEBUG qml: FART_PAGE home 0", " DEBUG qml: FART_CMDLINE ready 1793970325657",
                 " DEBUG qml: FART_CMDLINE done", "  INFO qml: FART_CMDLINE ready 1793970330001.5", "FART_CMDLINE ready soon"]
        self.assertEqual(cmdline_markers(lines), [1793970325657.0, 1793970330001.5])

    def test_open_stats_and_checks(self):
        cold = open_stats([310.0, 452.5, 300.0], 144.0)
        self.assertEqual((cold["count"], cold["median_ms"], cold["max_ms"]), (3, 310.0, 452.5))
        warm = open_stats([5.0, 7.5], 144.0)
        self.assertEqual((warm["median_frames"], warm["max_frames"]), (0.9, 1.08))
        checks = open_checks(cold, warm, BUDGETS["desktop_open"])
        self.assertEqual({k: v["status"] for k, v in checks.items()}, {"cold_ms": "fail", "warm_frames": "fail"})
        checks = open_checks(open_stats([300.0], 144.0), None, BUDGETS["desktop_open"])
        self.assertEqual(checks, {"cold_ms": {"measured": 300.0, "limit": 450, "status": "pass"}})  # warm not run
        self.assertEqual(open_checks(open_stats([], 144.0), None, BUDGETS["desktop_open"])["cold_ms"]["status"], "insufficient")

    def test_wait_marker_takes_the_next_new_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = type("F", (), {"log": Path(tmp) / "view.log"})()
            with self.assertRaises(RuntimeError):
                wait_marker(fixture, 0, timeout=0.05)  # no log yet
            fixture.log.write_text(" DEBUG qml: FART_CMDLINE ready 100\n DEBUG qml: FART_CMDLINE ready 250\n")
            self.assertEqual((wait_marker(fixture, 0), wait_marker(fixture, 1)), (100.0, 250.0))
            with self.assertRaises(RuntimeError):
                wait_marker(fixture, 2, timeout=0.05)

    def test_an_open_that_never_becomes_interactive_is_interrupted(self):
        class Quiet:
            status = "quiet"
            def __init__(self, *_, **__): pass
            def __enter__(self): return self
            def __exit__(self, *_): pass
        with tempfile.TemporaryDirectory() as tmp, patch.object(desktop_nav, "Interaction", Quiet), \
                patch.object(desktop_nav, "wait_marker", side_effect=lambda f, seen: wait_marker(f, seen, timeout=0.05)):
            log = Path(tmp) / "view.log"
            log.write_text(" DEBUG qml: FART_CMDLINE ready 100\n")  # an earlier open's marker
            def request(op, **_):
                if marker:
                    log.write_text(log.read_text() + f" DEBUG qml: FART_CMDLINE ready {marker}\n")
            fixture = type("F", (), {"log": log, "request": staticmethod(request)})()
            marker = None
            self.assertEqual(desktop_nav.timed_open(fixture), (None, "interrupted"))  # the old marker is not this open's
            marker = 10 ** 13
            latency, status = desktop_nav.timed_open(fixture)
            self.assertEqual(status, "quiet")
            self.assertGreater(latency, 0)

    def test_open_exit_codes(self):
        passing = {"cold_ms": {"status": "pass"}}
        self.assertEqual(exit_code(combined(["quiet", "quiet"]), passing), 0)
        self.assertEqual(exit_code(combined(["quiet", "interrupted"]), passing), 2)
        self.assertEqual(exit_code(combined(["unknown"]), passing), 3)
        self.assertEqual(exit_code(combined([]), passing), 3)
        self.assertEqual(exit_code("quiet", {"cold_ms": {"status": "fail"}}), 1)
        self.assertEqual(exit_code("quiet", {"cold_ms": {"status": "insufficient"}}), 3)

    def test_observer_can_ignore_its_own_focus_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp) / "hypr/mock"
            directory.mkdir(parents=True)
            env = dict(XDG_RUNTIME_DIR=tmp, HYPRLAND_INSTANCE_SIGNATURE="mock")
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(directory / ".socket2.sock"))
                server.listen()
                for event, expected in ((b"activewindow>>fixture,FART\nactivewindowv2>>abc\n", "quiet"),
                                        (b"workspacev2>>2,two\n", "interrupted")):
                    with self.subTest(event=event), patch("tools.measure.interaction.cursor", return_value=(1, 1)):
                        with Interaction(env, ignore=FOCUS) as observer:
                            with server.accept()[0] as peer:
                                peer.sendall(event)
                                observer.thread.join(0.4)  # long enough for several reads
                                self.assertEqual(observer.status, expected)

    def test_observer(self):
        with Interaction({}) as observer:
            self.assertEqual(observer.status, "unknown")
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp) / "hypr/mock"
            directory.mkdir(parents=True)
            env = dict(XDG_RUNTIME_DIR=tmp, HYPRLAND_INSTANCE_SIGNATURE="mock")
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(directory / ".socket2.sock"))
                server.listen()
                for case in ("quiet", "event", "motion", "lost"):
                    pos = [1, 1]
                    with self.subTest(case=case), patch("tools.measure.interaction.cursor", side_effect=lambda _: tuple(pos)):
                        with Interaction(env) as observer:
                            with server.accept()[0] as peer:
                                if case == "motion":
                                    pos[0] += 1
                                elif case == "event":
                                    peer.sendall(b"unrelated>>x\nwork")
                                    peer.sendall(b"spacev2>>fixture\n")
                                elif case == "lost":
                                    peer.shutdown(socket.SHUT_RDWR)
                                if case != "quiet":
                                    observer.thread.join(2)
                                expected = {"motion": "interrupted", "event": "interrupted", "lost": "unknown"}
                                self.assertEqual(observer.status, expected.get(case, "quiet"))
