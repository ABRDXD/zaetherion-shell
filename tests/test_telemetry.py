"""Fixture tests; no live GPU, playback, power or desktop state changes."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('gpu_sample', ROOT / 'tools/gpu_sample.py')
gpu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpu)


class GpuSampleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def write(self, relative, value):
        p = self.root / relative
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(str(value))

    def test_amd_zero_is_available_and_does_not_wake_nvidia(self):
        self.write('class/drm/card1/device/gpu_busy_percent', 0)
        with patch.object(gpu.subprocess, 'run') as probe:
            sample = gpu.sample(self.root)
        self.assertTrue(sample['available'])
        self.assertEqual(sample['gpu'], 0)
        self.assertIsNone(sample['temperature'])
        self.assertIsNone(sample['vramTotal'])
        probe.assert_not_called()

    def test_amd_units_and_connector_directories(self):
        self.write('class/drm/card1/device/gpu_busy_percent', 25)
        self.write('class/drm/card1/device/hwmon/hwmon0/temp1_input', 42000)
        self.write('class/drm/card1/device/mem_info_vram_used', 1048576)
        self.write('class/drm/card1/device/mem_info_vram_total', 2097152)
        self.write('class/drm/card0-HDMI-A-1/device/gpu_busy_percent', 90)
        sample = gpu.sample(self.root)
        self.assertEqual(sample['gpu'], .25)
        self.assertEqual(sample['temperature'], 42)
        self.assertEqual(sample['vramUsed'], 1048576)
        self.assertEqual(sample['source'], 'AMD · card1')

    def test_boot_adapter_has_priority(self):
        self.write('class/drm/card0/device/gpu_busy_percent', 90)
        self.write('class/drm/card1/device/gpu_busy_percent', 10)
        self.write('class/drm/card1/device/boot_vga', 1)
        self.assertEqual(gpu.sample(self.root)['gpu'], .1)

    def test_nvidia_fallback_units_and_timeout(self):
        result = subprocess.CompletedProcess([], 0, '12, 46, 256, 4096\n')
        with patch.object(gpu.subprocess, 'run', return_value=result) as probe:
            sample = gpu.sample(self.root)
        self.assertEqual(sample['gpu'], .12)
        self.assertEqual(sample['vramTotal'], 4096 * 1048576)
        self.assertEqual(probe.call_args.kwargs['timeout'], 2)

    def test_timeout_and_invalid_data_are_unavailable_not_zero(self):
        for result in [subprocess.TimeoutExpired('nvidia-smi', 2), FileNotFoundError(),
                       subprocess.CompletedProcess([], 0, 'N/A, N/A, N/A, N/A')]:
            with self.subTest(result=result):
                kwargs = {'side_effect': result} if isinstance(result, Exception) else {'return_value': result}
                with patch.object(gpu.subprocess, 'run', **kwargs):
                    sample = gpu.sample(self.root)
                self.assertFalse(sample['available'])
                self.assertNotIn('gpu', sample)


class CpuSampleTests(unittest.TestCase):
    def test_qml_math_with_two_samples_guest_iowait_and_reset(self):
        # Run the exact QML JavaScript helper, not a separate Python copy.
        script = (ROOT / 'adapters/common/ResourceMath.js').read_text().replace('.pragma library', '')
        cases = r'''
const assert = require('node:assert/strict');
const before = cpuSample('cpu  100 20 30 800 50 0 0 0 99 99\ncpu0 1 1 1 1');
const after = cpuSample('cpu  120 20 40 850 70 0 0 0 100 100');
assert.equal(before.total, 1000); // guest fields excluded
assert.equal(before.idle, 850); // iowait included in idle
assert.equal(cpuDelta(before, after), 0.3);
assert.equal(cpuDelta(null, after), null);
assert.equal(cpuDelta(before, before), null); // duplicate reads are not zero usage
assert.equal(cpuDelta(after, before), null); // counter reset
assert.equal(cpuDelta({total:100,idle:90},{total:200,idle:190}), 0); // real idle
assert.equal(cpuSample('cpu bad 1 2 3 4 5 6 7'), null);
assert.equal(cpuSample('cpu 1 2 3'), null);
assert.equal(cpuDelta({total:100,idle:50},{total:110,idle:80}), null);
'''
        result = subprocess.run(['node', '-e', script + cases], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
