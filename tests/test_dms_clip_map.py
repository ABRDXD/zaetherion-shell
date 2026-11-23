"""adapters/dms/DmsClipMap.js under Node: DMS's clipboard history in the contract's shape (Z202). Made-up entries."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(expression):
    body = "\n".join(l for l in (ROOT / "adapters/dms/DmsClipMap.js").read_text().splitlines() if not l.startswith(".pragma"))
    out = subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expression}));"],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


HISTORY = json.dumps([
    {"id": 7, "preview": "older words", "isImage": False, "pinned": True, "timestamp": "2026-11-15T10:00:00Z"},
    {"id": 9, "preview": "[[ image/png 8x8 ]]", "isImage": True, "pinned": False, "timestamp": "2026-11-15T12:00:00Z", "mimeType": "image/png"},
    {"id": 8, "preview": "same time, lower id", "isImage": False, "timestamp": "2026-11-15T12:00:00Z"},
    None, {"preview": "no id"},
])


@unittest.skipUnless(shutil.which("node"), "needs Node")
class ClipMap(unittest.TestCase):
    def test_entries_are_the_contracts_newest_first(self):
        self.assertEqual(run(f"entries({HISTORY})"), [
            {"id": "9", "text": "[[ image/png 8x8 ]]", "isImage": True, "pinned": False},
            {"id": "8", "text": "same time, lower id", "isImage": False, "pinned": False},
            {"id": "7", "text": "older words", "isImage": False, "pinned": True},
        ])
        self.assertEqual(run("[entries(null), entries({}), entries([])]"), [[], [], []])

    def test_ids_keep_dmss_own_numbers(self):
        self.assertEqual(run(f"ids({HISTORY})"), {"7": 7, "9": 9, "8": 8})

    def test_an_image_becomes_a_data_url_only_from_clean_base64(self):
        self.assertEqual(run("imageUrl({data: 'iVBO\\nRw0K', mimeType: 'image/jpeg'})"), "data:image/jpeg;base64,iVBORw0K")
        self.assertEqual(run("imageUrl({data: 'iVBORw0K'})"), "data:image/png;base64,iVBORw0K")
        self.assertEqual(run("imageUrl({data: 'iVBORw0K', mimeType: 'text/html'})"), "data:image/png;base64,iVBORw0K")
        self.assertEqual(run("[imageUrl(null), imageUrl({data: ''}), imageUrl({data: 'a\"b'})]"), ["", "", ""])

    def test_utf8_text_from_either_atob(self):
        self.assertEqual(run("utf8(Buffer.from('héllo ✓', 'utf8').toString('binary'))"), "héllo ✓")
        self.assertEqual(run("utf8(new Uint8Array(Buffer.from('ünï', 'utf8')).buffer)"), "ünï")
        self.assertEqual(run("[utf8(''), utf8(null)]"), ["", ""])


if __name__ == "__main__":
    unittest.main()
