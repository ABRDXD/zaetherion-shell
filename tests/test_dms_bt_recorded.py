"""DmsBluetoothMap.js against a real DMS 2.1.0 `bluetooth.getState` (recorded 15 November 2026, scrubbed; OPEN F2-7,
NET_BT §7 step 1). Real DMS sends null, not [], for empty device lists."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
RECORDED = ROOT / "tests/fixtures/dms/bluetooth-v2.1.0-recorded.json"


def run(expression):
    body = "\n".join(l for l in (ROOT / "adapters/dms/DmsBluetoothMap.js").read_text().splitlines() if not l.startswith(".pragma"))
    state = json.loads(RECORDED.read_text())["reply"]["result"]
    out = subprocess.run(["node", "-e", body + f"\nconst data = {json.dumps(state)};\nprocess.stdout.write(JSON.stringify({expression}));"],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class RecordedBluetooth(unittest.TestCase):
    def test_the_recording_has_the_shape_the_synthetic_fixture_assumed(self):
        state = json.loads(RECORDED.read_text())["reply"]["result"]
        synthetic = json.loads((ROOT / "tests/fixtures/dms/bluetooth-synthetic.json").read_text())["state"]
        self.assertEqual(sorted(state), sorted(synthetic))
        self.assertEqual(sorted(state["adapters"][0]), sorted(synthetic["adapters"][0]))

    def test_null_lists_read_as_on_with_nothing(self):
        self.assertEqual(run("[enabled(data), discovering(data), adapterPath(data), devices(data, () => -1), nearby(data, () => -1)]"),
                         [True, False, "<path-1>", [], []])


if __name__ == "__main__":
    unittest.main()
