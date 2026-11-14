"""view/shell/NetWords.js: what the Wi-Fi, VPN and Bluetooth settings say (docs/NET_BT.md §3 point 5), under Node."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
PHASES = ["working", "lost", "done", "wrong-secret", "timeout", "cancelled", "failed"]


def run(expression):
    body = "\n".join(l for l in (ROOT / "view/shell/NetWords.js").read_text().splitlines() if not l.startswith(".pragma"))
    out = subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expression}));"],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def a(phase, action="join", reason=""):
    return json.dumps({"target": "net-x", "action": action, "phase": phase, "reason": reason})


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Words(unittest.TestCase):
    def test_every_phase_says_something_and_only_settled_failures_offer_a_retry(self):
        for kind, action in (("wifi", "join"), ("vpn", "vpn:on"), ("bt", "pair")):
            for phase in PHASES:
                got = run(f"attempt({a(phase, action)}, 'Name', '{kind}')")
                self.assertTrue(got["line"], (kind, phase))
                self.assertIn("Name", got["line"] + ("Name" if phase == "cancelled" else ""), (kind, phase))
                self.assertEqual(got["busy"], phase in ("working", "lost", "wrong-secret"), (kind, phase))
                self.assertEqual(got["retry"], phase in ("timeout", "failed"), (kind, phase))
                self.assertEqual(got["ok"], phase == "done", (kind, phase))
        self.assertIsNone(run("attempt(null, 'x', 'wifi')"))

    def test_the_messages_people_read(self):
        self.assertEqual(run(f"attempt({a('wrong-secret')}, 'Cafe', 'wifi').line"), "Wrong password for Cafe. Type it again.")
        self.assertEqual(run(f"attempt({a('timeout', reason='no-answer')}, 'Cafe', 'wifi').line"), "DMS didn't answer. Couldn't join Cafe.")
        self.assertIn("enterprise", run(f"attempt({a('failed', reason='enterprise')}, 'Work', 'wifi').line"))
        self.assertEqual(run(f"attempt({a('failed', reason='fake raw')}, 'Cafe', 'wifi').detail"), "fake raw")
        self.assertEqual(run(f"attempt({a('cancelled', reason='prompt-timeout')}, 'Cafe', 'wifi').retry"), True)
        self.assertEqual(run(f"attempt({a('done', 'connect')}, 'Phone', 'bt').line"), "Connected Phone.")

    def test_prompts_and_pairing(self):
        self.assertEqual(run("prompt({ssid: 'Cafe', name: 'Cafe', kind: 'psk', reason: ''})"), "Cafe needs its password.")
        self.assertIn("more than a password", run("prompt({ssid: 'Work', name: 'Work', kind: 'unsupported'})"))
        got = run("['confirm', 'display-passkey', 'authorize', 'pin', 'passkey', 'odd'].map(k => pairing({kind: k, deviceName: 'Phone', passkey: '042137'}))")
        self.assertEqual([g["field"] for g in got], ["", "", "", "PIN", "Passkey", ""])
        self.assertIn("042137", got[0]["line"])
        self.assertEqual(got[1]["yes"], "")              # nothing to answer: the device is where the code is typed
        self.assertEqual(run("[percent(-1), percent(0.804), band(''), band('5')]"), ["", "80 %", "", "5 GHz"])
