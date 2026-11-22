"""Capture (S9, Z221) with stand-in tools: nothing grabs the screen, records, copies or opens anything."""
import asyncio
import json
from pathlib import Path
import signal
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from core.capture import Capture, geometry  # noqa: E402
from core.errors import OpError  # noqa: E402
from core.verbs.base import Usage  # noqa: E402
from core.verbs.capture import parse_shot  # noqa: E402

MONITORS = [{"name": "DP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1, "focused": True,
             "activeWorkspace": {"id": 1}}]


class FakeProcess:
    def __init__(self, code=0):
        self.code, self.signals, self.done = code, [], asyncio.Event()
        self.killed = False

    def send_signal(self, sig):
        self.signals.append(sig)
        self.done.set()

    def kill(self):
        self.killed = True
        self.done.set()

    async def wait(self):
        await self.done.wait()
        return self.code


class Tools:
    """Answers each program as configured and records every call."""
    def __init__(self, monitors=MONITORS, slurp=b"10,20 300x200\n", clients=(), tesseract=b"hello world\n",
                 zbar=b"https://example.org\n", grim_code=0, selector=None):
        self.calls, self.stdin, self.spawned, self.alerts = [], {}, [], []
        # What the frozen selector writes to its answer file ("x,y wxh" or "cancel"); None writes nothing.
        self.selector, self.specs = selector, []
        self.monitors, self.slurp, self.clients = monitors, slurp, list(clients)
        self.tesseract, self.zbar, self.grim_code = tesseract, zbar, grim_code
        self.recorder = FakeProcess()

    async def run(self, argv, stdin=None, timeout=None, env=None):
        self.calls.append(argv)
        self.stdin[argv[0]] = stdin
        name = argv[0]
        if name == "qs":
            spec = json.loads(Path(env["ZAE_SELECTOR_SPEC"]).read_text())
            self.specs.append(spec)
            if self.selector is None:
                return 255, b"", b"No PanelWindow backend loaded."
            Path(spec["out"]).write_text(self.selector + "\n")
            return 0, b"", b""
        if name == "hyprctl":
            return 0, json.dumps(self.monitors if argv[1] == "monitors" else self.clients).encode(), b""
        if name == "grim":
            if self.grim_code:
                return self.grim_code, b"", b"no output"
            Path(argv[-1]).write_bytes(b"FROZEN")
            return 0, b"", b""
        if name == "slurp":
            return (0, self.slurp, b"") if self.slurp else (1, b"", b"selection cancelled")
        if name == "magick":
            Path(argv[-1]).write_bytes(b"CUT")
            return 0, b"", b""
        if name == "tesseract":
            return 0, self.tesseract, b""
        if name == "zbarimg":
            return (0, self.zbar, b"") if self.zbar else (4, b"", b"")
        return 0, b"", b""

    async def spawn(self, argv):
        self.spawned.append(argv)
        return self.recorder

    def names(self):
        return [c[0] for c in self.calls]

    def notes(self):
        return [summary for summary, _ in self.alerts]

    def alert(self, summary, body, image=None):
        self.alerts.append((summary, image))


def make(tools, tmp, uploads=None, selector=None, missing=()):
    upload = (lambda path: uploads.append(path.read_bytes()) or "https://lens.example/results") if uploads is not None else None
    return Capture(Path(tmp) / "run", pictures=Path(tmp) / "Pictures", videos=Path(tmp) / "Videos", run=tools.run,
                   spawn=tools.spawn, upload=upload or (lambda path: "https://lens.example/results"),
                   clock=lambda: 1795000000.0, which=lambda tool: None if tool in missing else "/usr/bin/" + tool,
                   alert=tools.alert, selector=selector)


ENTRY = ROOT / "shell-selector.qml"


async def settle(capture):
    while capture.tasks:
        await asyncio.gather(*list(capture.tasks))


class FrozenSelector(unittest.IsolatedAsyncioTestCase):
    """Z48: a shot's area is chosen over the frozen grab (Eclipse), not over the live screen."""
    MONITORS = [{"name": "A", "x": -1920, "y": 0, "width": 1920, "height": 1080, "scale": 1, "activeWorkspace": {"id": 1}},
                {"name": "B", "x": 0, "y": 0, "width": 3840, "height": 2160, "scale": 2, "focused": True,
                 "activeWorkspace": {"id": 2}}]

    def test_the_entry_exists(self):
        self.assertTrue(ENTRY.is_file())

    async def test_a_region_is_chosen_over_the_frozen_grab_and_cut_from_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(monitors=self.MONITORS, selector="10,20 300x200")
            capture = make(tools, tmp, selector=ENTRY)
            capture.shoot("region", "copy")
            await settle(capture)
            names = tools.names()
            self.assertLess(names.index("grim"), names.index("qs"), "the screen freezes before the selection")
            self.assertNotIn("slurp", names)
            self.assertEqual(tools.calls[names.index("qs")], ["qs", "-n", "--no-color", "-p", str(ENTRY)])
            spec = tools.specs[0]
            grab = next(c for c in tools.calls if c[0] == "grim")[-1]
            self.assertEqual(spec["frozen"], grab, "the selector shows the very grab that is cut")
            self.assertEqual((spec["origin"], spec["scale"], spec["mode"], spec["screens"], spec["active"], spec["windows"]),
                             ({"x": -1920, "y": 0}, 2.0, "region", ["A", "B"], "B", []))
            crop = next(c for c in tools.calls if c[0] == "magick")
            self.assertEqual(crop[3], "600x400+3860+40")
            self.assertEqual(tools.notes(), ["Screenshot copied"])
            self.assertEqual(list((Path(tmp) / "run/capture").iterdir()), [], "no grab, spec or answer stays")

    async def test_window_mode_hands_the_selector_the_shown_windows(self):
        clients = [{"at": [0, 0], "size": [800, 600], "workspace": {"id": 1}, "mapped": True}]
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(clients=clients, selector="0,0 800x600")
            capture = make(tools, tmp, selector=ENTRY)
            capture.shoot("window")
            await settle(capture)
            self.assertEqual(tools.specs[0]["mode"], "window")
            self.assertEqual(tools.specs[0]["windows"], [{"x": 0, "y": 0, "width": 800, "height": 600}])
            self.assertNotIn("slurp", tools.names())

    async def test_dismissing_the_selector_does_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(selector="cancel")
            capture = make(tools, tmp, selector=ENTRY)
            capture.shoot("region", "copy")
            await settle(capture)
            self.assertNotIn("slurp", tools.names())
            self.assertNotIn("wl-copy", tools.names())
            self.assertEqual(tools.notes(), [])
            self.assertEqual(list((Path(tmp) / "run/capture").iterdir()), [])

    async def test_a_selector_that_cannot_show_falls_back_to_slurp(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(selector=None)
            capture = make(tools, tmp, selector=ENTRY)
            with self.assertLogs("fart.capture", "WARNING"):
                capture.shoot("region", "copy")
                await settle(capture)
            self.assertLess(tools.names().index("qs"), tools.names().index("slurp"))
            self.assertEqual(tools.notes(), ["Screenshot copied"])

    async def test_without_quickshell_slurp_chooses(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(selector="10,20 300x200")
            capture = make(tools, tmp, selector=ENTRY, missing=("qs",))
            capture.shoot("region", "copy")
            await settle(capture)
            self.assertNotIn("qs", tools.names())
            self.assertIn("slurp", tools.names())

    async def test_a_recording_region_is_chosen_over_the_live_screen(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(slurp=b"100,50 640x480\n", selector="1,1 2x2")
            capture = make(tools, tmp, selector=ENTRY)
            await capture.record_start("region")
            self.assertNotIn("qs", tools.names(), "nothing is frozen for a recording")
            await capture.record_stop()
            await settle(capture)


class Shots(unittest.IsolatedAsyncioTestCase):
    async def test_a_region_is_cut_from_the_frozen_grab_copied_and_saved(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools, changes = Tools(), []
            capture = make(tools, tmp)
            capture.on_change = lambda: changes.append(capture.busy)
            self.assertEqual(capture.shoot("region", "copy"), "selecting")
            await settle(capture)
            names = tools.names()
            self.assertLess(names.index("grim"), names.index("slurp"), "the screen freezes before the selection")
            crop = next(c for c in tools.calls if c[0] == "magick")
            self.assertEqual(crop[3], "300x200+10+20")
            saved = list((Path(tmp) / "Pictures/Screenshots").iterdir())
            self.assertEqual(len(saved), 1)
            self.assertEqual(saved[0].read_bytes(), b"CUT")
            self.assertEqual(tools.stdin["wl-copy"], b"CUT")
            self.assertEqual(tools.notes(), ["Screenshot copied"])
            self.assertEqual(tools.alerts[0][1], str(saved[0]), "the notice shows the saved picture")
            self.assertEqual(list((Path(tmp) / "run/capture").iterdir()), [], "frozen grabs never stay")
            self.assertEqual(changes, [True, False])
            self.assertFalse(capture.busy)

    async def test_a_dismissed_selection_does_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(slurp=b"")
            capture = make(tools, tmp)
            capture.shoot("region", "copy")
            await settle(capture)
            self.assertNotIn("wl-copy", tools.names())
            self.assertEqual(tools.notes(), [])
            self.assertFalse((Path(tmp) / "Pictures/Screenshots").exists())

    async def test_full_takes_the_whole_grab_without_a_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools()
            capture = make(tools, tmp)
            self.assertEqual(capture.shoot("full"), "captured")
            await settle(capture)
            self.assertNotIn("slurp", tools.names())
            self.assertNotIn("magick", tools.names())
            self.assertEqual(tools.stdin["wl-copy"], b"FROZEN")

    async def test_monitor_cuts_the_focused_monitor_at_its_scale_and_place(self):
        monitors = [{"name": "A", "x": -1920, "y": 0, "width": 1920, "height": 1080, "scale": 1, "activeWorkspace": {"id": 1}},
                    {"name": "B", "x": 0, "y": 0, "width": 3840, "height": 2160, "scale": 2, "focused": True,
                     "activeWorkspace": {"id": 2}}]
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(monitors=monitors)
            capture = make(tools, tmp)
            capture.shoot("monitor")
            await settle(capture)
            crop = next(c for c in tools.calls if c[0] == "magick")
            # B is 1920x1080 logical at x 0; the layout starts at -1920 and renders at scale 2.
            self.assertEqual(crop[3], "3840x2160+3840+0")

    async def test_window_offers_only_the_windows_on_shown_workspaces(self):
        clients = [{"at": [0, 0], "size": [800, 600], "workspace": {"id": 1}, "mapped": True},
                   {"at": [5, 5], "size": [100, 100], "workspace": {"id": 9}, "mapped": True},
                   {"at": [9, 9], "size": [50, 50], "workspace": {"id": 1}, "hidden": True}]
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(clients=clients)
            capture = make(tools, tmp)
            capture.shoot("window")
            await settle(capture)
            slurp = next(c for c in tools.calls if c[0] == "slurp")
            self.assertEqual(slurp, ["slurp", "-r"])
            self.assertEqual(tools.stdin["slurp"], b"0,0 800x600\n")

    async def test_text_copies_what_tesseract_reads_and_keeps_no_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools()
            capture = make(tools, tmp)
            capture.shoot("region", "text")
            await settle(capture)
            self.assertEqual(tools.stdin["wl-copy"], b"hello world")
            self.assertEqual(tools.notes(), ["Text copied"])
            self.assertFalse((Path(tmp) / "Pictures/Screenshots").exists())

    async def test_text_with_nothing_readable_says_so(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(tesseract=b"  \n")
            capture = make(tools, tmp)
            capture.shoot("region", "text")
            await settle(capture)
            self.assertNotIn("wl-copy", tools.names())
            self.assertEqual(tools.notes(), ["No text found"])

    async def test_qr_copies_the_code_or_says_there_is_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools()
            capture = make(tools, tmp)
            capture.shoot("region", "qr")
            await settle(capture)
            self.assertEqual(tools.stdin["wl-copy"], b"https://example.org")
            tools2 = Tools(zbar=b"")
            capture2 = make(tools2, tmp)
            capture2.shoot("region", "qr")
            await settle(capture2)
            self.assertEqual(tools2.notes(), ["No QR code found"])

    async def test_lens_uploads_the_cut_and_opens_the_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools, uploads = Tools(), []
            capture = make(tools, tmp, uploads)
            capture.shoot("region", "lens")
            await settle(capture)
            self.assertEqual(uploads, [b"CUT"])
            self.assertIn(["xdg-open", "https://lens.example/results"], tools.calls)

    async def test_edit_opens_satty_on_the_saved_picture(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools()
            capture = make(tools, tmp)
            capture.shoot("region", "edit")
            await settle(capture)
            satty = tools.spawned[0]
            self.assertEqual(satty[0], "satty")
            saved = satty[satty.index("--filename") + 1]
            self.assertTrue(saved.endswith(".png") and "Screenshots" in saved)
            self.assertEqual(satty[satty.index("--copy-command") + 1], "wl-copy")

    async def test_a_failure_is_told_and_frees_the_next_shot(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(grim_code=1)
            capture = make(tools, tmp)
            capture.shoot("full")
            await settle(capture)
            self.assertEqual(tools.notes(), ["Capture failed"])
            self.assertFalse(capture.busy)

    async def test_one_shot_at_a_time(self):
        with tempfile.TemporaryDirectory() as tmp:
            capture = make(Tools(), tmp)
            capture.shoot("region")
            with self.assertRaises(OpError):
                capture.shoot("full")
            await settle(capture)

    async def test_unknown_modes_and_actions_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            capture = make(Tools(), tmp)
            with self.assertRaises(OpError):
                capture.shoot("everything")
            with self.assertRaises(OpError):
                capture.shoot("region", "print")


class Recording(unittest.IsolatedAsyncioTestCase):
    async def test_monitor_recording_with_sound_and_mic_then_stop(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools, changes = Tools(), []
            capture = make(tools, tmp)
            capture.on_change = lambda: changes.append(bool(capture.recording))
            state = await capture.record_start("monitor", sound=True, mic=True)
            argv = tools.spawned[0]
            self.assertEqual(argv[:3], ["gpu-screen-recorder", "-w", "DP-1"])
            self.assertEqual(argv[argv.index("-a") + 1], "default_output|default_input")
            self.assertTrue(state["active"] and state["startedAt"] == 1795000000.0)
            self.assertEqual(capture.snapshot()["recording"]["mode"], "monitor")
            Path(state["file"]).write_bytes(b"MP4")      # the recorder finishes its file
            out = await capture.record_stop()
            await settle(capture)
            self.assertEqual(out["status"], "stopped")
            self.assertEqual(tools.recorder.signals, [signal.SIGINT])
            self.assertIsNone(capture.recording)
            self.assertEqual(tools.notes(), ["Recording saved"])
            self.assertEqual(changes, [True, False])

    async def test_region_recording_uses_the_selection_and_no_audio_by_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(slurp=b"100,50 640x480\n")
            capture = make(tools, tmp)
            await capture.record_start("region")
            argv = tools.spawned[0]
            self.assertEqual(argv[1:5], ["-w", "region", "-region", "640x480+100+50"])
            self.assertNotIn("-a", argv)
            await capture.record_stop()
            await settle(capture)

    async def test_a_dismissed_region_records_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools(slurp=b"")
            capture = make(tools, tmp)
            out = await capture.record_start("region")
            self.assertEqual(out["status"], "cancelled")
            self.assertEqual(tools.spawned, [])
            self.assertIsNone(capture.recording)

    async def test_a_recorder_that_dies_clears_the_state_and_says_so(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools()
            tools.recorder = FakeProcess(code=1)
            capture = make(tools, tmp)
            await capture.record_start("monitor")
            tools.recorder.done.set()
            await settle(capture)
            self.assertIsNone(capture.recording)
            self.assertEqual(tools.notes(), ["Recording failed"])

    async def test_only_one_recording(self):
        with tempfile.TemporaryDirectory() as tmp:
            capture = make(Tools(), tmp)
            await capture.record_start("monitor")
            with self.assertRaises(OpError):
                await capture.record_start("monitor")
            await capture.record_stop()
            await settle(capture)

    async def test_the_cores_stop_finishes_a_recording(self):
        with tempfile.TemporaryDirectory() as tmp:
            tools = Tools()
            capture = make(tools, tmp)
            await capture.record_start("monitor")
            await capture.stop()
            await settle(capture)
            self.assertEqual(tools.recorder.signals, [signal.SIGINT])


class Words(unittest.TestCase):
    def test_shot_words(self):
        self.assertEqual(parse_shot([]), ("region", "copy"))
        self.assertEqual(parse_shot(["full", "edit"]), ("full", "edit"))
        self.assertEqual(parse_shot(["window", "ocr"]), ("window", "text"))
        self.assertEqual(parse_shot(["search"]), ("region", "lens"))
        with self.assertRaises(Usage):
            parse_shot(["everything"])

    def test_geometry(self):
        self.assertEqual(geometry("10,20 300x200\n"), (10, 20, 300, 200))
        with self.assertRaises(ValueError):
            geometry("10,20 0x200")
        with self.assertRaises(ValueError):
            geometry("garbage")


if __name__ == "__main__":
    unittest.main()


@unittest.skipUnless(all(__import__("shutil").which(t) for t in ("magick", "tesseract")), "magick and tesseract are not installed")
class RealTools(unittest.IsolatedAsyncioTestCase):
    """The real crop and OCR on a made-up picture. The screen grab and the clipboard stay fakes."""
    async def test_real_crop_then_ocr(self):
        from core.capture import run_process
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "screen.png"
            code, _, err = await run_process(["magick", "-size", "1200x400", "xc:white", "-fill", "black", "-pointsize", "72",
                                              "-annotate", "+620+220", "HELLO 42", str(source)], timeout=30)
            self.assertEqual(code, 0, err)
            copied = []

            async def run(argv, stdin=None, timeout=None, env=None):
                if argv[0] == "hyprctl":
                    return 0, json.dumps(MONITORS).encode(), b""
                if argv[0] == "grim":
                    Path(argv[-1]).write_bytes(source.read_bytes())
                    return 0, b"", b""
                if argv[0] == "slurp":
                    return 0, b"600,120 560x160\n", b""
                if argv[0] == "wl-copy":
                    copied.append(stdin)
                    return 0, b"", b""
                return await run_process(argv, stdin, timeout)

            alerts = []
            capture = Capture(Path(tmp) / "run", pictures=Path(tmp) / "P", videos=Path(tmp) / "V", run=run,
                              spawn=None, alert=lambda s, b, image=None: alerts.append(s))
            capture.shoot("region", "text")
            await settle(capture)
            self.assertEqual(alerts, ["Text copied"])
            self.assertIn(b"HELLO 42", copied[0])
