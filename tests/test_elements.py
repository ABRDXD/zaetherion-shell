"""The periodic table's data (view/ui/Elements.js), under Node: every element, in its place, with the right electrons."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = """
const fs = require('fs');
const code = fs.readFileSync(process.argv[1], 'utf8').replace('.pragma library', '');
const E = new Function(code + '; return { ELEMENTS, shells, ofDay };')();
console.log(JSON.stringify({ all: E.ELEMENTS, day: E.ofDay(new Date(1794200000000)).z }));
"""


@unittest.skipUnless(shutil.which("node"), "node is not installed")
class ElementsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        done = subprocess.run(["node", "-e", SCRIPT, str(ROOT / "view/ui/Elements.js")], capture_output=True, text=True, check=True)
        cls.data = json.loads(done.stdout)
        cls.all = cls.data["all"]
        cls.by = {e["symbol"]: e for e in cls.all}

    def test_all_118_in_order(self):
        self.assertEqual([e["z"] for e in self.all], list(range(1, 119)))
        self.assertEqual(len(self.by), 118)

    def test_every_element_has_its_own_cell(self):
        cells = [(e["col"], e["row"]) for e in self.all]
        self.assertEqual(len(set(cells)), 118)
        self.assertTrue(all(1 <= c <= 18 and 1 <= r <= 9 for c, r in cells))

    def test_known_places(self):
        for symbol, cell in {"H": (1, 1), "He": (18, 1), "Fe": (8, 4), "La": (3, 6), "Ce": (4, 8), "Lu": (17, 8), "Hf": (4, 6), "Ac": (3, 7),
                             "Th": (4, 9), "Rf": (4, 7), "Og": (18, 7)}.items():
            self.assertEqual((self.by[symbol]["col"], self.by[symbol]["row"]), cell, symbol)

    def test_electrons_add_up(self):
        for e in self.all:
            self.assertEqual(sum(e["shells"]), e["z"], e["symbol"])

    def test_known_shells(self):
        for symbol, shells in {"H": [1], "C": [2, 4], "Fe": [2, 8, 14, 2], "Cr": [2, 8, 13, 1], "Au": [2, 8, 18, 32, 18, 1], "Og": [2, 8, 18, 32, 32, 18, 8]}.items():
            self.assertEqual(self.by[symbol]["shells"], shells, symbol)

    def test_categories(self):
        for symbol, kind in {"Na": "alkali", "Cl": "halogen", "Ne": "noble", "Si": "metalloid", "Fe": "transition", "U": "actinide", "Nd": "lanthanide"}.items():
            self.assertEqual(self.by[symbol]["kind"], kind, symbol)

    def test_the_element_of_the_day_is_real(self):
        self.assertTrue(1 <= self.data["day"] <= 118)
