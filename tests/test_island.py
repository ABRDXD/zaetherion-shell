"""Render the island frame with the inert adapter and exercise palette changes."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from smoke import prepare


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class IslandFrameTests(unittest.TestCase):
    def test_frame_and_palette_changes_offscreen(self):
        self.run_fixture("FrameTest.qml", ("fixture palette", "darkest blue role",
            "darkest role without blue", "empty palette fallback"))

    def test_island_faces_hover_and_queue(self):
        self.run_fixture("SurfaceTest.qml", ("preemption saves dwell", "resume and hover pause",
            "hover resumes remaining time", "critical interrupts held face", "panel holds ordinary event",
            "critical shows over panel", "ordinary event resumes after panel", "rest frame", "idle has no leases",
            "hover delay and playing lease", "hover shows wings", "leases released",
            "track face", "workspace flash", "memory face", "osd face", "notification face", "offscreen capture",
            "docked hands critical to FART", "docked holds ordinary", "events resume after fold"))

    def test_osd_shows_in_fart_header_while_covered(self):
        """Z174: covered by FART, the OSD goes to the header at once and is never banked for the fold."""
        self.run_fixture("HeaderOsdTest.qml", ("covered osd shows in header", "repeat updates in place",
            "readout sits on the header row", "muted reads MUTED", "dwell follows the last change", "leaves after its dwell", "header readout gone",
            "fold replays no stale osd", "uncovered osd on island", "dock lifts osd into header", "fold hands it back"))

    def test_workspace_instrument(self):
        """Z199: the edge-on system: transit, symmetry, crescents, window counts, the short way round, settling."""
        self.run_fixture("WorkspaceTransitTest.qml", ("current world on the star's face", "a transit, never an eclipse", "worlds mirror about the axis",
            "crescents face the star", "window counts reach the worlds", "readout", "one step back turns back", "turn settles",
            "the short way round the wrap", "new world in transit"))

    def test_status_faces(self):
        self.run_fixture("EventTest.qml", ("recording status", "charging notice", "DND suppresses ordinary battery warning",
            "critical battery passes DND", "backend comeback", "resident restart", "timer status", "timer done", "session debrief"))

    def test_notices_follow_their_inbox_item(self):
        self.run_fixture("NoticeTest.qml", ("the sender's showing time", "a live item can be answered",
            "replace-id refreshes the card", "a sender's never-expire gets our time", "a change that is not an arrival shows nothing",
            "our own showing time", "the adapter's default is 1 s and honours the sender",
            "the island caps a sender's long time at 1 s", "a shorter sender time is kept", "critical is not capped",
            "a restored item cannot be answered", "closed elsewhere leaves the island"))

    def test_right_click_dismisses_and_card_hover_pauses(self):
        self.run_fixture("DismissTest.qml", ("right-click is idle without a notification", "default showing time is 1 s",
            "right-click takes only the right button", "right-click removes it from the island",
            "right-click dismisses it in the Inbox", "critical stays until dismissed",
            "right-click dismisses a critical notification", "pointer off the card",
            "island hover does not pause a notification", "second notification shown", "card hover pauses a notification",
            "leaving the card resumes the countdown"))

    def test_reply_draft_keeps_keyboard(self):
        self.run_fixture("ReplyTest.qml", ("rest takes no keyboard", "notice offers keyboard",
            "OSD over a notice without a draft releases keyboard", "notice resumes", "draft holds keyboard through OSD",
            "draft survives pre-emption", "focus claim when inactive", "claim is released",
            "island waits for docked panel", "island claims after panel lets go"))

    def test_fluid_form(self):
        self.run_fixture("FluidTest.qml", ("fluid rests compact", "fluid shows media while playing",
            "right-click switches to the clock",
            "fluid hover shows the row", "fluid notification face"))

    def run_fixture(self, filename, checks):
        harness = (ROOT / "tests/fixtures/island" / filename).read_text()
        with tempfile.TemporaryDirectory(prefix="zaetherion-island-") as tmp:
            base = Path(tmp)
            env, _, _ = prepare(base, harness)
            runtime = base / "runtime"
            runtime.mkdir(mode=0o700)
            shot = base / "frame.png"
            env.update(XDG_RUNTIME_DIR=str(runtime), ISLAND_FRAME_SHOT=str(shot))
            result = subprocess.run(
                ["qs", "--no-color", "--log-rules", "qml.debug=true", "-p", env["FART_VIEW_ENTRY"]],
                env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertNotIn("ISLAND_FAIL", output)
            for name in (*checks, "offscreen capture"):
                self.assertIn("ISLAND_PASS " + name, output)
            self.assertTrue(shot.is_file(), output)
            for error in ("Binding loop", "ReferenceError", "TypeError", "Unable to assign"):
                self.assertNotIn(error, output)
