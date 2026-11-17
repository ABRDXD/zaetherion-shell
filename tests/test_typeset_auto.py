"""tools/typeset/glyph.py's auto mode (Z213 step 2): its judgements on synthetic pictures, and the layer split."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    Image = None


def glyph():
    spec = importlib.util.spec_from_file_location("glyph", ROOT / "tools/typeset/glyph.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["glyph"] = module
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(Image, "needs Pillow")
class AutoJudgement(unittest.TestCase):
    def setUp(self):
        self.g = glyph()
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)

    def picture(self, name, ground, shapes=(), size=(640, 360)):
        img = Image.new("RGB", size, ground)
        d = ImageDraw.Draw(img)
        for box, colour in shapes:
            d.rectangle(box, fill=colour)
        path = self.dir / name
        img.save(path)
        return path

    def test_a_contrasty_dark_picture_is_set_by_light_and_not_inverted(self):
        p = self.picture("night.png", "#050505", [((100, 100, 300, 300), "#f0f0f0"), ((350, 50, 600, 200), "#808080")])
        cfg = self.g.auto_config(p)
        self.assertFalse(cfg["invert"])
        self.assertEqual(cfg["edges"], 0)
        cuts = [b[0] for b in cfg["bands"]]
        self.assertEqual(cuts, sorted(cuts))

    def test_a_bright_picture_is_inverted_so_its_dark_shapes_become_type(self):
        p = self.picture("sky.png", "#e8eef4", [((200, 200, 260, 360), "#101010")])
        self.assertTrue(self.g.auto_config(p)["invert"])

    def test_a_flat_picture_is_set_by_its_edges(self):
        p = self.picture("fog.png", "#404850", [((100, 100, 400, 300), "#4a525a")])
        self.assertGreater(self.g.auto_config(p)["edges"], 0)

    def test_an_accent_is_a_minority_colour(self):
        eyes = self.picture("wolves.png", "#101010", [((300, 150, 340, 190), "#e01010"), ((360, 150, 400, 190), "#e01010"),
                                                     ((100, 100, 250, 300), "#c0c0c0")])
        cfg = self.g.auto_config(eyes)
        self.assertIsNotNone(cfg["warm"])
        self.assertTrue(cfg["warm"][1] > 300 or cfg["warm"][2] < 60)   # a red hue band
        sky = self.picture("blue.png", "#3a7bd5", [((0, 250, 640, 360), "#101010")])
        self.assertIsNone(self.g.auto_config(sky)["warm"])            # a blue sky is not an accent

    def test_compose_is_ink_plus_accent_times_mask(self):
        ink = Image.new("RGB", (2, 1), (64, 64, 64))
        mask = Image.new("L", (2, 1), 0)
        mask.putpixel((1, 0), 255)
        out = self.g.compose(ink, mask, "#ff5a00")
        self.assertEqual(out.getpixel((0, 0)), (64, 64, 64))
        self.assertEqual(out.getpixel((1, 0)), (255, 154, 64))


if __name__ == "__main__":
    unittest.main()
