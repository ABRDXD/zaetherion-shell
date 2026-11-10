"""The view reaches the host only through the typed adapter contract (docs/ADAPTER_CONTRACT.md)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
VIEW = sorted((ROOT / "view").rglob("*.qml"))
CONTRACT = ROOT / "view/contract"
ADAPTER_DIRS = (ROOT / "adapters/serpantinum", ROOT / "adapters/common")

# Contract domain -> its Serpantinum implementation.
SERPANTINUM = {
    "MediaDomain": "serpantinum/SerpantinumMedia.qml",
    "AudioDomain": "serpantinum/SerpantinumAudio.qml",
    "EqualizerDomain": "serpantinum/SerpantinumEqualizer.qml",
    "NetworkDomain": "serpantinum/SerpantinumNetwork.qml",
    "BluetoothDomain": "serpantinum/SerpantinumBluetooth.qml",
    "NotificationsDomain": "serpantinum/SerpantinumNotifications.qml",
    "WorkspacesDomain": "serpantinum/SerpantinumWorkspaces.qml",
    "PowerDomain": "serpantinum/SerpantinumPower.qml",
    "PaletteDomain": "serpantinum/SerpantinumPalette.qml",
    "MotionDomain": "serpantinum/SerpantinumMotion.qml",
    "HostActionsDomain": "serpantinum/SerpantinumHostActions.qml",
    "SfxDomain": "serpantinum/SerpantinumSfx.qml",
    "ClockGeometryDomain": "serpantinum/SerpantinumClockGeometry.qml",
    "LyricsDomain": "common/LyricsSource.qml",
    "SystemDomain": "common/LinuxSystem.qml",
    "ClipboardDomain": "common/CliphistClipboard.qml",
}
# Host-facing modules and commands. Overlay keeps the Hyprland focus grab (a compositor feature, not a host one).
FORBIDDEN_IMPORTS = re.compile(r"^import (qs\.adapters\b|Quickshell\.Services\b|Quickshell\.Bluetooth\b|Quickshell\.Networking\b|Quickshell\.Hyprland\b)", re.M)
IMPORT_ALLOWED = {"view/shell/Overlay.qml": {"Quickshell.Hyprland"}}
HOST_STRINGS = ("serpantinum", "qs_colors", "cliphist", "canberra-gtk-play", "pw-play", "wl-copy", "gdbus", "hyprctl")
# The only view file that may start a process (the read-only update report).
PROCESS_ALLOWED = {"view/shell/FartCommands.qml", 'view/shell/HeavyLayer.qml'}  # FART's own second process, never the host's
# What each tree may import from qs.* (docs/CORE.md §9).
QS_IMPORTS = {"view": re.compile(r"^qs\.(view|core\.client)\b"),
              "adapters": re.compile(r"^qs\.(view\.contract|core\.client|adapters)\b"),
              "core/client": re.compile(r"$^"),
              # Cues are loadable alone: Overlay binds Motion.reduced (docs/CUES.md §2).
              "view/cues": re.compile(r"$^")}
# Motion goes through view/cues and shaders only through view/strata (docs/CUES.md §4.3).
RAW_MOTION = re.compile(r"\b(SequentialAnimation|ParallelAnimation|ScriptAction|PauseAnimation)\b|^\s*Behavior\s+on\b|loops:\s*Animation\.Infinite", re.M)
SHADERS = re.compile(r"\b(ShaderEffect|ShaderEffectSource|MultiEffect)\b")
SPRING_IN_TWEEN = re.compile(r"Tween on \w+\s*\{\s*(?:scope:[^\n]*\s*)?SpringAnimation\b")
CUE_IDS = re.compile(r"\b(?:Cue|Pulse|Timeline)\s*\{\s*id:\s*(\w+)")
# Host knowledge stays in adapters/<host>/core.py; core/ itself is host-agnostic.
CORE_HOST_STRINGS = ("serpantinum", "qs_colors", "cliphist", "pw-play", "notify-send", "canberra")


def functions(text):
    return dict(re.findall(r"^\s*function (\w+)\(([^)]*)\)", text, re.M))


def params(signature):
    return [p.split(":")[0].strip() for p in signature.split(",") if p.strip()]


class ContractTests(unittest.TestCase):
    def test_view_does_not_import_host_modules(self):
        for qml in VIEW:
            rel = str(qml.relative_to(ROOT))
            for match in FORBIDDEN_IMPORTS.finditer(qml.read_text()):
                self.assertIn(match.group(1), IMPORT_ALLOWED.get(rel, set()), f"{rel}: import {match.group(1)}")

    def test_view_names_no_host_paths_or_binaries(self):
        for qml in VIEW:
            text = qml.read_text().lower()
            for needle in HOST_STRINGS:
                self.assertNotIn(needle, text, f"{qml.relative_to(ROOT)}: {needle}")

    def test_view_starts_processes_only_where_allowed(self):
        for qml in VIEW:
            rel = str(qml.relative_to(ROOT))
            if re.search(r"execDetached|\bProcess\s*\{|\bProcess\b\s*$", qml.read_text(), re.M):
                self.assertIn(rel, PROCESS_ALLOWED, rel)

    def test_qs_imports_stay_within_their_layer(self):
        for tree, allowed in QS_IMPORTS.items():
            for qml in sorted((ROOT / tree).rglob("*.qml")):
                for module in re.findall(r"^import (qs\.[\w.]+)", qml.read_text(), re.M):
                    self.assertRegex(module, allowed, f"{qml.relative_to(ROOT)}: import {module}")

    def test_motion_goes_through_cues(self):
        for qml in VIEW:
            rel = str(qml.relative_to(ROOT))
            text = qml.read_text()
            if not rel.startswith("view/cues/"):
                self.assertIsNone(RAW_MOTION.search(text), f"{rel}: raw animation outside view/cues")
                self.assertEqual(text.count("SpringAnimation"), len(SPRING_IN_TWEEN.findall(text)), f"{rel}: spring outside a Tween")
            if not rel.startswith("view/strata/"):
                self.assertIsNone(SHADERS.search(text), f"{rel}: shader outside view/strata")
            # Input never waits for motion: no control is gated on a running cue.
            for cue in CUE_IDS.findall(text):
                gate = re.search(rf"\b(enabled|visible)\s*:[^\n;}}]*\b{cue}\.running\b", text)
                self.assertIsNone(gate, f"{rel}: enabled/visible gated on {cue}.running")

    def test_core_names_no_host(self):
        for source in sorted((ROOT / "core").rglob("*")):
            if source.suffix in (".py", ".qml"):
                text = source.read_text().lower()
                for needle in CORE_HOST_STRINGS:
                    self.assertFalse(needle in text, f"{source.relative_to(ROOT)}: {needle}")

    def test_serpantinum_implements_every_contract_method(self):
        for domain, impl in SERPANTINUM.items():
            contract = functions((CONTRACT / f"{domain}.qml").read_text())
            implemented = functions((ROOT / "adapters" / impl).read_text())
            self.assertRegex((ROOT / "adapters" / impl).read_text(), re.compile(rf"^{domain} \{{", re.M), f"{impl} must derive from {domain}")
            for name, signature in contract.items():
                if name in ("record", "holds", "acquire", "release"):
                    continue
                self.assertIn(name, implemented, f"{impl}: {name}() not implemented")
                self.assertEqual(params(implemented[name]), params(signature), f"{impl}: {name}() signature")

    def test_adapters_fill_every_domain(self):
        domains = re.findall(r"^    property (\w+Domain) (\w+):", (CONTRACT / "HostAdapter.qml").read_text(), re.M)
        self.assertEqual(len(domains), 16)
        for adapter in ("serpantinum/SerpantinumAdapter.qml", "fixture/FixtureAdapter.qml"):
            text = (ROOT / "adapters" / adapter).read_text()
            for _, name in domains:
                # Filled where declared, or by loadDeferred() (root.<name> = …).
                self.assertRegex(text, re.compile(rf"^    {name}: \w+|root\.{name} = \w+", re.M), f"{adapter}: {name}")

    def test_every_view_lease_is_honoured_by_an_adapter(self):
        held = set()
        for directory in ADAPTER_DIRS:
            for qml in directory.glob("*.qml"):
                held |= set(re.findall(r'holds\("(\w+)"\)', qml.read_text()))
        for qml in VIEW:
            for feature in re.findall(r'HostLease \{[^}]*feature: "(\w+)"', qml.read_text()):
                self.assertIn(feature, held, f"{qml.relative_to(ROOT)}: lease {feature}")


if __name__ == "__main__":
    unittest.main()
