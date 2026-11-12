"""Static checks on adapters/dms (docs/DMS_ADAPTER.md §9.4): contract shape, leases, the one socket file, privacy."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
DMS = ROOT / "adapters/dms"
CONTRACT = ROOT / "view/contract"

# Contract domain -> DMS-backed implementation in adapters/dms. Extended as domains arrive.
DOMAINS = {
    "NetworkDomain": "DmsNetwork.qml",
    "PowerDomain": "DmsPower.qml",
    "NotificationsDomain": "DmsNotifications.qml",
}
# Leases the DMS-backed domains serve, per file.
LEASES = {"DmsNetwork.qml": {"details", "scan"}}


def functions(text):
    return dict(re.findall(r"^\s*function (\w+)\(([^)]*)\)", text, re.M))


def params(signature):
    return [p.split(":")[0].strip() for p in signature.split(",") if p.strip()]


class DmsContract(unittest.TestCase):
    def test_each_domain_derives_from_its_contract_type_and_overrides_every_method(self):
        for domain, file in DOMAINS.items():
            text = (DMS / file).read_text()
            self.assertRegex(text, re.compile(rf"^{domain} \{{", re.M), f"{file} must derive from {domain}")
            contract = functions((CONTRACT / f"{domain}.qml").read_text())
            implemented = functions(text)
            for name, signature in contract.items():
                if name in ("record", "holds", "acquire", "release"):
                    continue
                self.assertIn(name, implemented, f"{file}: {name}() not implemented")
                self.assertEqual(params(implemented[name]), params(signature), f"{file}: {name}() signature")

    def test_each_lease_is_checked_by_holds(self):
        for file, features in LEASES.items():
            text = (DMS / file).read_text()
            for feature in features:
                self.assertIn(f'holds("{feature}")', text, f"{file}: lease {feature}")

    def test_session_actions_are_exactly_the_decided_commands(self):
        # Z158: systemctl for suspend, reboot and power off; Hyprland's exit for logout; lock is the session's own bind.
        text = (DMS / "DmsPower.qml").read_text()
        self.assertEqual(sorted(re.findall(r"execDetached\((\[[^\]]*\])\)", text)),
                         sorted(['["dms", "ipc", "call", "lock", "lock"]', '["systemctl", "suspend"]',
                                 '["systemctl", "reboot"]', '["systemctl", "poweroff"]']))
        self.assertIn('Hyprland.dispatch("hl.dsp.exit()")', text)

    def test_notifications_read_the_core_mirror_and_start_no_host_command_but_the_sessions_own(self):
        text = (DMS / "DmsNotifications.qml").read_text()
        self.assertIn("core.notificationsData", text)
        self.assertEqual(re.findall(r"execDetached\((\[[^\]]*\])\)", text), ['["dms", "ipc", "call", "notifications", "toggle"]'])

    def test_only_the_link_uses_a_socket(self):
        for qml in sorted(DMS.glob("*.qml")):
            uses = re.search(r"\bSocket\b", qml.read_text())
            self.assertEqual(bool(uses), qml.name == "DmsLink.qml", qml.name)

    def test_only_the_link_imports_quickshell_io(self):
        for qml in sorted(DMS.glob("*.qml")):
            if qml.name != "DmsLink.qml":
                self.assertNotIn("Quickshell.Io", qml.read_text(), qml.name)

    def test_the_clipboard_service_is_never_named(self):
        # DMS's clipboard history is off for this owner (cliphist records, F2-4). Only a DMS-backed clipboard domain,
        # inside a holds("history") guard, may name the service or its methods; none exists, so nothing here may.
        # (The cliphist clipboard domain is wired by DmsAdapter under its own name; that is not DMS's service.)
        named = re.compile(r"""["']clipboard|clipboard\.(get|set|clear|delete|pin)""", re.I)
        for source in sorted(DMS.iterdir()):
            if source.suffix in (".qml", ".js"):
                self.assertIsNone(named.search(source.read_text()), source.name)

    def test_a_subscribe_is_only_built_by_the_machine_and_always_with_services(self):
        for source in sorted(DMS.iterdir()):
            if source.suffix in (".qml", ".js") and source.name != "DmsLinkMachine.js":
                self.assertNotIn('"subscribe"', source.read_text(), source.name)
        machine = (DMS / "DmsLinkMachine.js").read_text()
        self.assertEqual(machine.count('"subscribe"'), 1)
        self.assertIn("services: want", machine)

    def test_the_machine_has_no_side_effects(self):
        machine = (DMS / "DmsLinkMachine.js").read_text()
        for needle in ("Date.now", "setTimeout", "console.", "Qt.", "Math.random"):
            self.assertNotIn(needle, machine)

    def test_pure_javascript_files_are_libraries(self):
        for js in sorted(DMS.glob("*.js")):
            self.assertTrue(js.read_text().startswith(".pragma library"), js.name)

    def test_the_two_version_constants_are_in_the_machine(self):
        machine = (DMS / "DmsLinkMachine.js").read_text()
        self.assertRegex(machine, r"var MIN_API = 38;")
        self.assertRegex(machine, r"var CHECKED_API = 38;")

    def test_dms_names_no_serpantinum_or_host_paths(self):
        for source in sorted(DMS.iterdir()):
            if source.suffix in (".qml", ".js"):
                text = source.read_text().lower()
                self.assertNotIn("serpantinum", text, source.name)
                self.assertNotIn("/home/", text, source.name)


if __name__ == "__main__":
    unittest.main()
