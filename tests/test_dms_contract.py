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
    "BluetoothDomain": "DmsBluetooth.qml",
    "ClipboardDomain": "DmsClipboard.qml",
}
# Leases the DMS-backed domains serve, per file.
LEASES = {"DmsNetwork.qml": {"details", "scan", "saved"}, "DmsBluetooth.qml": {"scan"}, "DmsClipboard.qml": {"history", "config"}}


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
            # DmsLauncher is the bridge's client (Z197): its own socket to DMS's launcher engine, not DMS's server.
            self.assertEqual(bool(uses), qml.name in ("DmsLink.qml", "DmsLauncher.qml"), qml.name)

    def test_only_the_link_imports_quickshell_io(self):
        for qml in sorted(DMS.glob("*.qml")):
            if qml.name not in ("DmsLink.qml", "DmsLauncher.qml"):
                self.assertNotIn("Quickshell.Io", qml.read_text(), qml.name)

    def test_only_the_clipboard_domain_names_the_clipboard_service_and_only_under_its_lease(self):
        # §8, Z202: DMS's clipboard history is FART's. Only DmsClipboard may name the service or its methods; its
        # subscription follows the "history" lease, and every call that names an entry goes through dmsId(), which
        # answers nothing without the lease. The history's settings (no content) only under the "config" lease.
        named = re.compile(r"""["']clipboard|clipboard\.(get|set|clear|delete|pin|copy|send|paste)""", re.I)
        for source in sorted(DMS.iterdir()):
            if source.suffix in (".qml", ".js") and source.name != "DmsClipboard.qml":
                self.assertIsNone(named.search(source.read_text()), source.name)
        text = (DMS / "DmsClipboard.qml").read_text()
        self.assertIn('readonly property bool reading: holds("history")', text)
        self.assertIn('service: "clipboard"; capability: "clipboard"; wanted: root.reading', text)
        self.assertIn("function dmsId(id) { return reading ? dmsIds[id] : undefined; }", text)
        for method in ("copyEntry", "deleteEntry", "pinEntry", "getEntry"):
            for call in re.finditer(rf'"clipboard\.{method}"', text):
                before = text[:call.start()]
                self.assertIn("dmsId(", before[before.rindex("function "):], method)
        self.assertIn('readonly property bool configuring: holds("config")', text)
        for method in ("getConfig", "setConfig"):
            for call in re.finditer(rf'"clipboard\.{method}"', text):
                before = text[:call.start()]
                body = before[before.rindex("function "):]
                self.assertTrue("configuring" in body or "readConfig" in body[:body.index("(")], method)

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
