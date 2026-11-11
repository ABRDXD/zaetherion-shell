"""Nested Hyprland test fixtures (Z109). The live check is `tools/nested_hypr.py selftest`."""
import shutil
import subprocess
import unittest
from pathlib import Path

FIX = Path(__file__).resolve().parent / "fixtures" / "nested"


class NestedFixtures(unittest.TestCase):
    def test_fake_pam_only_permits_or_denies(self):
        # The fake PAM must never reach a real module (pam_unix etc.).
        self.assertEqual((FIX / "pam" / "zt-permit").read_text().split(), ["auth", "required", "pam_permit.so"])
        self.assertEqual((FIX / "pam" / "zt-deny").read_text().split(), ["auth", "required", "pam_deny.so"])
        self.assertEqual(sorted(p.name for p in (FIX / "pam").iterdir()), ["zt-deny", "zt-permit"])

    def test_nested_config_has_no_autostart_or_binds(self):
        text = (FIX / "nested.lua").read_text()
        for word in ("exec_cmd", "hl.bind", "dofile", "require"):
            self.assertNotIn(word, text)
        self.assertIn("allow_session_lock_restore = true", text)

    @unittest.skipUnless(shutil.which("Hyprland"), "Hyprland not installed")
    def test_nested_config_verifies(self):
        r = subprocess.run(["Hyprland", "--verify-config", "-c", str(FIX / "nested.lua")],
                           capture_output=True, text=True, timeout=30)
        self.assertIn("config ok", r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
