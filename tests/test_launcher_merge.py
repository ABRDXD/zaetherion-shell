"""view/shell/LauncherMerge.js: the core's inline rows above DMS's engine, the core's apps whenever DMS can't answer."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def rows(text, core, host, limit=6):
    body = "\n".join(l for l in (ROOT / "view/shell/LauncherMerge.js").read_text().splitlines() if not l.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify(rows({json.dumps(text)}, {json.dumps(core)}, {json.dumps(host)}, {limit})));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


CORE = [{"kind": "calc", "id": "calc", "name": "2+2 = 4"}, {"kind": "app", "id": "steam", "name": "Steam", "blocked": True},
        {"kind": "app", "id": "firefox", "name": "Firefox", "blocked": False}]
DMS = {"available": True, "results": [{"key": 0, "id": "steam", "kind": "app", "name": "Steam"},
                                      {"key": 1, "id": "", "kind": "setting", "name": "Wi-Fi"}]}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Merge(unittest.TestCase):
    def names(self, *args, **kw):
        return [r["name"] for r in rows(*args, **kw)]

    def test_inline_rows_sit_above_the_engine_and_core_apps_step_aside(self):
        self.assertEqual(self.names("st", CORE, DMS), ["2+2 = 4", "Steam", "Wi-Fi"])

    def test_the_core_answers_when_the_engine_cannot(self):
        core = self.names("st", CORE, {"available": False, "results": DMS["results"]})
        self.assertEqual(core, ["2+2 = 4", "Steam", "Firefox"])
        self.assertEqual(self.names("", CORE, DMS), ["2+2 = 4", "Steam", "Firefox"])  # nothing typed: frecent apps
        self.assertEqual(self.names(">ls", CORE, DMS), ["2+2 = 4", "Steam", "Firefox"])
        self.assertEqual(self.names("?x", CORE, DMS), ["2+2 = 4", "Steam", "Firefox"])

    def test_session_blocklist_marks_engine_apps_and_keys_become_ids(self):
        out = rows("st", CORE, DMS)
        self.assertTrue(out[1]["blocked"])
        self.assertEqual((out[2]["id"], out[2]["source"], out[2]["ready"]), ("host:1", "host", True))

    def test_key_changes_only_with_what_shows(self):
        body = "\n".join(l for l in (ROOT / "view/shell/LauncherMerge.js").read_text().splitlines() if not l.startswith(".pragma"))
        script = body + "\nconst a=[{kind:'app',id:'x',name:'X'}], b=[{kind:'app',id:'x',name:'X',score:2}], c=[{kind:'app',id:'y',name:'Y'}];" \
            "process.stdout.write(JSON.stringify([key(a)===key(b), key(a)===key(c), key([])===key(null)]));"
        out = json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)
        self.assertEqual(out, [True, False, True])

    def test_limit(self):
        self.assertEqual(len(rows("st", CORE, DMS, 2)), 2)


if __name__ == "__main__":
    unittest.main()
