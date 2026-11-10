"""view/rooms/Ports.js: phantom ports in Devices (atlas #23): what was linked when last seen and isn't now."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Ports.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class PortsTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_a_disconnect_leaves_a_phantom_until_it_links_again(self):
        got = self.js("""(() => {
            const a = {id: "h", name: "Headset", connected: true}, k = {id: "k", name: "Keyboard", connected: false};
            let s = sight({}, [a, k], 100);
            const first = phantoms(s);
            s = sight(s, [Object.assign({}, a, {connected: false}), k], 200);
            const left = phantoms(s);
            s = sight(s, [Object.assign({}, a, {connected: false}), k], 300);   // looked again: still since 200
            const still = phantoms(s);
            s = sight(s, [a, k], 400);
            return [first, left, still, phantoms(s)];
        })()""")
        self.assertEqual(got[0], {"left": {}, "gone": []})
        self.assertEqual(got[1], {"left": {"h": 200}, "gone": []})
        self.assertEqual(got[2], {"left": {"h": 200}, "gone": []})
        self.assertEqual(got[3], {"left": {}, "gone": []})

    def test_a_linked_device_that_vanishes_is_a_gone_socket_and_a_never_linked_one_is_not(self):
        got = self.js("""(() => {
            let s = sight({}, [{id: "h", name: "Headset", connected: true}, {id: "k", name: "Keyboard", connected: false}], 100);
            s = sight(s, [], 250);
            return phantoms(s);
        })()""")
        self.assertEqual(got, {"left": {}, "gone": [{"id": "h", "name": "Headset", "lost": 250, "phantom": True, "connected": False}]})

    def test_a_left_device_that_then_vanishes_keeps_its_time(self):
        got = self.js("""(() => {
            let s = sight({}, [{id: "h", name: "Headset", connected: true}], 100);
            s = sight(s, [{id: "h", name: "Headset", connected: false}], 200);
            s = sight(s, [], 300);
            return phantoms(s);
        })()""")
        self.assertEqual([(g["id"], g["lost"]) for g in got["gone"]], [("h", 200)])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class DevicesPorts(unittest.TestCase):
    """Phantom ports in the real Devices room (tools/cuetest/DevicesTest.qml)."""

    def test_left_gone_and_back(self):
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("DevicesTest.qml", timeout=60)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("ports.left", "ports.gone", "ports.back", "ledger.entries", "press.deboss"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
