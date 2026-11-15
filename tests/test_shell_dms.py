"""shell-dms.qml is shell.qml with DmsAdapter in place of SerpantinumAdapter, and nothing else (S2 step 6, Z159)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def body(text):
    """The code only: comments and blank lines dropped, so wording can differ."""
    return [l for l in text.splitlines() if l.strip() and not l.strip().startswith("//") or l.startswith("//@")]


# DMS's socket follows the core's supervisor topic (it changes with every DMS restart); DMS_SOCKET without a core.
# The OSD and the clipboard live where the island lives (Z172, S3).
ADAPTER = """    DmsAdapter {
        id: adapter
        core: client
        role: "shell"
        osdWanted: root.islandWanted
        clipsWanted: root.islandWanted
        socketPath: client.connected ? (client.supervisorData?.children?.dms?.socket ?? "") : (Quickshell.env("DMS_SOCKET") ?? "")
    }"""


class ShellDms(unittest.TestCase):
    def test_it_differs_from_shell_qml_only_in_the_adapter(self):
        legacy = "\n".join(body((ROOT / "shell.qml").read_text()))
        legacy = legacy.replace("import qs.adapters.serpantinum", "import qs.adapters.dms")
        adapter = "\n".join(l for l in ADAPTER.splitlines())
        legacy = legacy.replace("    SerpantinumAdapter { id: adapter; core: client }", adapter)
        self.assertEqual(legacy, "\n".join(body((ROOT / "shell-dms.qml").read_text())))

    def test_pragmas_stay_at_the_top(self):
        lines = (ROOT / "shell-dms.qml").read_text().splitlines()
        pragmas = [i for i, l in enumerate(lines) if l.startswith("//@ pragma")]
        self.assertEqual(pragmas, list(range(len(pragmas))))

    def test_it_names_no_legacy_adapter_and_no_socket_path(self):
        text = (ROOT / "shell-dms.qml").read_text()
        self.assertNotRegex(text.replace("in place of SerpantinumAdapter", ""), r"(?i)serpantinum")
        self.assertNotRegex(text, r"\.sock\b|/run/")  # a hard-coded socket file


if __name__ == "__main__":
    unittest.main()
