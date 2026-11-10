"""The GPU sampler's parsing, and that it never asks a sleeping NVIDIA card."""
from pathlib import Path
import tempfile
import unittest

from tools.measure.gpu import card_awake, card_busy, engine_time, parse_fdinfo

AMD = "pos:\t0\ndrm-driver:\tamdgpu\ndrm-pdev:\t0000:05:00.0\ndrm-client-id:\t7\ndrm-engine-gfx:\t1000 ns\ndrm-engine-compute:\t500 ns\ndrm-engine-capacity-gfx:\t2\n"


class GpuTests(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(parse_fdinfo(AMD), ("0000:05:00.0", "7", 1500))
        self.assertIsNone(parse_fdinfo("pos:\t0\nflags:\t02\n"))

    def test_one_client_on_several_descriptors_counts_once(self):
        with tempfile.TemporaryDirectory() as temp:
            fd = Path(temp) / "1/fdinfo"
            fd.mkdir(parents=True)
            (fd / "5").write_text(AMD)
            (fd / "6").write_text(AMD)
            self.assertEqual(engine_time(1, Path(temp)), {"0000:05:00.0": 1500})

    def test_the_nvidia_card_is_never_asked(self):
        with tempfile.TemporaryDirectory() as temp:
            power = Path(temp) / "device/power"
            power.mkdir(parents=True)
            (power / "runtime_status").write_text("active\n")
            self.assertIsNone(card_busy("nvidia", Path(temp)))
            self.assertTrue(card_awake(Path(temp)))
            (power / "runtime_status").write_text("suspended\n")
            self.assertFalse(card_awake(Path(temp)))
        self.assertNotIn("nvidia-smi --", Path("tools/measure/gpu.py").read_text())
