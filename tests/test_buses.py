"""view/rooms/Buses.js: Devices' bus schematic (atlas #21): rows, columns, speeds and the session's port memory."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Buses.js"
READING = {
    "controllers": [{"pci": "0000:06:00.3", "hubs": [{"bus": 1, "speed": 480, "ports": 3}, {"bus": 2, "speed": 10000, "ports": 2}]},
                    {"pci": "0000:08:00.4", "hubs": [{"bus": 3, "speed": 480, "ports": 1}]}],
    "devices": [{"path": "1-1", "bus": 1, "parent": "usb1", "port": 1, "kind": "INPUT", "speed": 12, "product": "Receiver", "ports": 0},
                {"path": "1-2", "bus": 1, "parent": "usb1", "port": 2, "kind": "HUB", "speed": 480, "product": "Hub", "ports": 2},
                {"path": "1-2.2", "bus": 1, "parent": "1-2", "port": 2, "kind": "STORAGE", "speed": 480, "product": "Stick", "ports": 0}],
}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class BusesTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nconst R = {json.dumps(READING)};\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_speeds(self):
        self.assertEqual(self.js('[12, 480, 5000, 10000, 0].map(speedTag)'), ["12M", "480M", "5G", "10G", ""])
        self.assertEqual(self.js('[12, 480, 10000].map(weight)'), [1, 1.5, 2.5])
        self.assertEqual(self.js('[portPath("usb1", 3), portPath("1-3", 2), portPath("1-3.2", 1)]'), ["1-3", "1-3.2", "1-3.2.1"])

    def test_rows_follow_the_wiring(self):
        cols = self.js('columns(R)')
        self.assertEqual([c["pci"] for c in cols], ["0000:06:00.3", "0000:08:00.4"])
        self.assertEqual(cols[0]["rails"], [480, 10000])
        got = [(r["rail"], r["depth"], r["path"], r["device"]["kind"] if r["device"] else None) for r in cols[0]["rows"]]
        self.assertEqual(got, [(0, 0, "1-1", "INPUT"), (0, 0, "1-2", "HUB"), (0, 1, "1-2.1", None), (0, 1, "1-2.2", "STORAGE"),
                               (0, 0, "1-3", None), (1, 0, "2-1", None), (1, 0, "2-2", None)])
        self.assertEqual(len(cols[1]["rows"]), 1)
        self.assertEqual(self.js('columns(null)'), [])

    def test_the_session_remembers_each_port(self):
        got = self.js('''(() => {
            let m = remember({}, R.devices, 1000);
            const first = ["1-1", "1-3"].map(p => state({ path: p, device: R.devices.find(d => d.path === p) ?? null }, m, 1000, 1000));
            // The stick is pulled out, a camera plugged into 1-3.
            const later = R.devices.filter(d => d.path !== "1-2.2").concat([{ path: "1-3", kind: "VIDEO", product: "Cam", speed: 480 }]);
            m = remember(m, later, 60000);
            const cam = state({ path: "1-3", device: later[later.length - 1] }, m, 61000, 1000);
            const stick = state({ path: "1-2.2", device: null }, m, 61000, 1000);
            const old = state({ path: "1-3", device: later[later.length - 1] }, m, 80000, 1000);
            return [first, cam, stick, m["1-2.2"].out, old, state({ path: "2-1", device: null }, m, 80000, 1000)];
        })()''')
        self.assertEqual(got, [["device", "open"], "fresh", "ghost", 60000, "device", "open"])

    def test_a_device_at_the_first_look_is_not_fresh(self):
        self.assertEqual(self.js('state({ path: "1-1", device: R.devices[0] }, remember({}, R.devices, 5000), 6000, 5000)'), "device")

    def test_the_bluetooth_island_hangs_off_the_radio(self):
        got = self.js('(() => { const r = { controllers: [{ pci: "x", hubs: [{ bus: 1, speed: 480, ports: 2 }] }],'
                      ' devices: [{ path: "1-1", parent: "usb1", port: 1, kind: "RADIO", speed: 12, product: "Radio", ports: 0 }] };'
                      ' const bt = [{ id: "a", name: "Headset", connected: true }, { id: "b", name: "Keyboard", connected: false }];'
                      ' return all(r, bt, [], [], [], {}).map(c => c.rows.map(x => [x.path, x.depth, !!x.wireless])); })()')
        self.assertEqual(got, [[["1-1", 0, False], ["bt:a", 1, True], ["1-2", 0, False]]])

    def test_the_audio_column(self):
        got = self.js('audio([{ id: "1", name: "Speakers", isDefault: true }, { id: "3", name: "HDMI", isDefault: false }],'
                      ' [{ id: "2", name: "Mic", isDefault: true }], [{}, {}])')
        self.assertEqual(got["pci"], "AUDIO")
        self.assertEqual([(r["device"]["kind"], r["device"]["product"]) for r in got["rows"]],
                         [("OUT ●", "Speakers · 2 PLAYING"), ("OUT", "HDMI"), ("IN ●", "Mic")])
        self.assertIsNone(self.js('audio([], [], [])'))

    def test_a_headset_that_drops_leaves_its_ghost(self):
        got = self.js('(() => { let m = remember({}, present(null, [{ id: "a", name: "Headset", connected: true }], [], []), 1000);'
                      ' m = remember(m, present(null, [{ id: "a", name: "Headset", connected: false }], [], []), 5000);'
                      ' const rows = island([{ path: "1-1", depth: 0, rail: 0, device: { kind: "RADIO" } }], [{ id: "a", name: "Headset", connected: false }], m);'
                      ' return [state({ path: "bt:a", device: null }, m, 6000, 1000), rows.length, rows[1].device]; })()')
        self.assertEqual(got, ["ghost", 2, None])


if __name__ == "__main__":
    unittest.main()
