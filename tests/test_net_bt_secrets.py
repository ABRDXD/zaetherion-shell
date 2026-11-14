"""S10: passwords, PINs and passkeys are never logged or kept (docs/NET_BT.md §4, Z193). Static checks.

The adapter test (tests/test_net_bt_adapter.py) types a fake password and checks the view's output for it; these
checks catch the ways a secret could be kept or printed without that run noticing."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [p for d in ("adapters", "core", "view") for p in (ROOT / d).rglob("*") if p.suffix in (".qml", ".js", ".py")]
# "pin" and "code" are left out: clipboard pins and exit codes use them. The adapters name a PIN `code` only as a
# parameter, which test_the_contract_never_records_a_secret_in_its_call_log and the adapter tests cover.
SECRET = r"(secrets?|password|psk|passkey)"
LOGGING = re.compile(r"(console\.(log|warn|info|debug|error)|print|log(ger)?\.(info|warn|warning|debug|error))\s*\(([^;\n]*)")
# Where a value would outlive the field: our view state, settings, the core, a file.
KEPT = re.compile(rf"(ViewState|Config\.options|core\.(send|call|request)|writeFile|FileView)[^\n]*\b{SECRET}\b", re.I)


def text(path):
    return path.read_text(errors="replace")


class Secrets(unittest.TestCase):
    def test_no_log_line_names_a_secret(self):
        for path in SOURCES:
            for match in LOGGING.finditer(text(path)):
                args = match.group(5)
                self.assertNotRegex(args, rf"\b{SECRET}\b", f"{path.relative_to(ROOT)}: logs {args[:60]}")

    def test_no_secret_is_kept_in_view_state_settings_the_core_or_a_file(self):
        for path in SOURCES:
            for line in text(path).splitlines():
                self.assertIsNone(KEPT.search(line), f"{path.relative_to(ROOT)}: {line.strip()[:80]}")

    def test_the_contract_never_records_a_secret_in_its_call_log(self):
        for name, methods in (("NetworkDomain", ("join", "answerPrompt")), ("BluetoothDomain", ("answerPairing",))):
            body = text(ROOT / "view/contract" / f"{name}.qml")
            for method in methods:
                line = next(l for l in body.splitlines() if f"function {method}(" in l)
                recorded = line.split("record(", 1)[1]
                self.assertNotRegex(recorded, r"\b(secret|code)\b", f"{name}.{method} records its secret")

    def test_password_fields_are_masked_by_default(self):
        # Every text field in the settings sections that takes a secret starts masked (echoMode Password).
        for path in (ROOT / "view").rglob("*.qml"):
            body = text(path)
            for field in re.finditer(r"(TextField|TextInput|FField)\s*\{[^{}]*\bsecret: true[^{}]*\}", body, re.S):
                self.assertRegex(field.group(0), r"echoMode:\s*[^\n]*TextInput\.Password", f"{path.relative_to(ROOT)}")
