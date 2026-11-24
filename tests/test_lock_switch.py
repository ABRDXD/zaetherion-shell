"""Switching the session's locker (docs/LOCK.md §6): tools/lock_switch.py touches only DMS's customPowerActionLock,
written as DMS writes it, keeps one backup, and refuses `on` unless the running core has FART_LOCK=own (otherwise
`zaetherion lock` would ask DMS, which would run it again). tools/live-restart takes FART_NAME=value / FART_NAME=."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("lock_switch", ROOT / "tools/lock_switch.py")
lock_switch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lock_switch)


class LockSwitch(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name) / "settings.json"
        self.original = {"currentThemeName": "dark", "barConfigs": [{"id": "default", "enabled": False}], "fontScale": 1.0}
        self.path.write_text(json.dumps(self.original, indent=2))
        self.path.chmod(0o640)

    def test_on_and_off_touch_only_the_one_key_and_keep_one_backup(self):
        self.assertTrue(lock_switch.write(self.path, lock_switch.COMMAND))
        on = json.loads(self.path.read_text())
        self.assertEqual(on.pop(lock_switch.KEY), f"{ROOT}/zaetherion lock")
        self.assertEqual(on, self.original)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)
        self.assertFalse(lock_switch.write(self.path, lock_switch.COMMAND))  # already on: untouched
        self.assertTrue(lock_switch.write(self.path, None))
        self.assertEqual(json.loads(self.path.read_text()), self.original)
        backup = self.path.with_name("settings.json.pre-lock-switch")
        self.assertEqual(json.loads(backup.read_text()), self.original)
        self.assertFalse(lock_switch.write(self.path, None))  # already off

    def test_on_is_refused_unless_the_core_runs_its_own_lock(self):
        for state in (None, False):
            with patch.object(lock_switch, "core_lock_own", return_value=state), \
                 patch.object(lock_switch, "settings_path", return_value=self.path):
                self.assertEqual(lock_switch.main(["x", "on"]), 1)
        self.assertNotIn(lock_switch.KEY, json.loads(self.path.read_text()))
        with patch.object(lock_switch, "core_lock_own", return_value=True), \
             patch.object(lock_switch, "settings_path", return_value=self.path):
            self.assertEqual(lock_switch.main(["x", "on"]), 0)
            self.assertEqual(json.loads(self.path.read_text())[lock_switch.KEY], lock_switch.COMMAND)
            self.assertEqual(lock_switch.main(["x", "off"]), 0)  # off never needs the core
        self.assertNotIn(lock_switch.KEY, json.loads(self.path.read_text()))


class AtLogin(unittest.TestCase):
    def test_is_on_follows_the_dms_setting_and_session_start_reads_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "settings.json"
            path.write_text(json.dumps({"a": 1}))
            with patch.object(lock_switch, "settings_path", return_value=path):
                self.assertEqual(lock_switch.main(["x", "is-on"]), 1)
                lock_switch.write(path, lock_switch.COMMAND)
                self.assertEqual(lock_switch.main(["x", "is-on"]), 0)
                lock_switch.write(path, None)
                self.assertEqual(lock_switch.main(["x", "is-on"]), 1)
                path.write_text("{broken")
                self.assertEqual(lock_switch.main(["x", "is-on"]), 1)
        script = (ROOT / "tools/session-start").read_text()
        self.assertLess(script.index("lock_switch.py\" is-on"), script.index('"$ROOT/zaetherion" start'))
        self.assertIn("export FART_LOCK=own", script)


class LiveRestartArguments(unittest.TestCase):
    def test_it_parses_and_refuses_before_stopping_anything(self):
        script = (ROOT / "tools/live-restart").read_text()
        self.assertEqual(subprocess.run(["sh", "-n", str(ROOT / "tools/live-restart")]).returncode, 0)
        # The argument loop comes before the stop.
        self.assertLess(script.index('for arg in "$@"'), script.index('run "$ROOT/zaetherion" stop'))
        self.assertIn("refused:", script)


if __name__ == "__main__":
    unittest.main()
