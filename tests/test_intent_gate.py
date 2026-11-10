"""view/shell/IntentGate.js: the intent gate's rules (atlas #62, docs/OVERDRIVE.md §52)."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/shell/IntentGate.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class IntentGateRules(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_what_is_gated(self):
        self.assertEqual(self.js('gate("wifi off")'), {"verb": "wifi", "arg": "off", "room": "devices", "what": "THE NETWORK"})
        self.assertEqual(self.js('gate("  WiFi   0 ")?.verb'), "wifi")
        self.assertEqual(self.js('gate("bluetooth no")?.verb'), "bt")
        self.assertEqual(self.js('gate("session end")?.room'), "timers")
        self.assertEqual(self.js('gate("lock")?.room'), "home")
        # A prefix the core resolved.
        self.assertEqual(self.js('gate("wi off", "wifi")?.verb'), "wifi")
        # Nothing that turns something on, opens a room or adjusts it.
        for line in ("wifi on", "wifi", "bt yes", "session pyq 2h", "lock now", "vol 0", "", "power save"):
            self.assertIsNone(self.js(f'gate({json.dumps(line)})'), line)
        self.assertIsNone(self.js('gate(null)'))

    def test_registering(self):
        self.assertEqual(self.js('[sequence(4), sequence(0), sequence(12)]'), ["04", "00", "12"])
        # Right digits close the planes a notch at a time; a wrong one throws them apart again.
        self.assertEqual(self.js('[step("04", 0, "0"), step("04", 1, "4"), step("04", 1, "5"), step("04", 2, "9")]'), [1, 2, 0, 2])
        self.assertEqual(self.js('[notches("04", 0), notches("04", 1), notches("04", 2)]'), [2, 1, 0])
        self.assertEqual(self.js('[registered("04", 1), registered("04", 2), registered("", 0)]'), [False, True, False])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class IntentGateOnTheCommandLine(unittest.TestCase):
    """The real CommandLine on a stand-in core (tools/cuetest/GateTest.qml), offscreen: nothing is actuated."""

    def test_silent_gate_wrong_register_escape_release(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("GateTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("gate.silent", "gate.split", "gate.wrong", "gate.registered", "gate.ran", "gate.escape", "gate.release", "gate.plain"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
