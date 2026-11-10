"""view/rooms/Kinetic.js: the timing under Overdrive's kinetic lyrics (M9).

Run under Node with the QML `.pragma` line stripped; the module takes every time as an argument."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Kinetic.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class KineticTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def words(self, line: dict):
        return self.js(f"timeWords({json.dumps(line, ensure_ascii=False)})")

    # Direction and units

    def test_vertical_only_when_most_of_the_line_is_cjk(self):
        self.assertEqual(self.js('["夜空に光る", "君の name", "I love 東京 so much", "hello", "", "…！", "사랑해요"].map(vertical)'),
                         [True, True, False, False, False, False, True])

    def test_tokens_split_cjk_by_character_and_latin_by_word(self):
        self.assertEqual(self.js('tokens("夜空、光る!")'), ["夜", "空、", "光", "る!"])
        self.assertEqual(self.js('tokens("  Hello,   world …  ")'), ["Hello,", "world…"])
        self.assertEqual(self.js('tokens("「君の」 love")'), ["「君", "の」", "love"])
        self.assertEqual(self.js('tokens("♪")'), [])

    # Word timing

    def test_real_word_timing_is_kept_and_put_in_order(self):
        got = self.words({"time": 10, "end": 14, "text": "a b c", "words": [
            {"time": 11, "end": 13, "text": " b"},   # overlaps the next word
            {"time": 10, "end": 0, "text": "a "},    # no end: runs to the next word
            {"time": 12, "endTime": 0, "text": "c"},  # the host's key, no end: runs to the line's end
            {"time": 12.5, "end": 13, "text": "  "},  # empty: dropped
        ]})
        self.assertEqual([(w["text"], w["time"], w["end"], w["timed"]) for w in got],
                         [("a", 10, 11, True), ("b", 11, 12, True), ("c", 12, 14, True)])

    def test_fallback_weights_by_characters_and_fills_the_line(self):
        got = self.words({"time": 2, "end": 6, "text": "a bbbb", "words": []})
        self.assertFalse(any(w["timed"] for w in got))
        # Weights 1.5 and 4.5 over the line's 4 s (the pace cap, 6 × 0.3 = 1.8 s, would be shorter: 4 s
        # holds only when the pace allows it).
        span = min(4, max(0.8, 6 * 0.3))
        self.assertAlmostEqual(got[0]["time"], 2)
        self.assertAlmostEqual(got[0]["end"], 2 + span * 1.5 / 6)
        self.assertAlmostEqual(got[1]["time"], got[0]["end"])
        self.assertAlmostEqual(got[1]["end"], 2 + span)

    def test_fallback_does_not_stretch_across_an_instrumental(self):
        got = self.words({"time": 0, "end": 40, "text": "short line", "words": []})
        self.assertLess(got[-1]["end"], 4)
        # A one-letter line still holds the minimum span.
        self.assertAlmostEqual(self.words({"time": 5, "end": 40, "text": "o", "words": []})[-1]["end"], 5.8)

    def test_fallback_cjk_characters_weigh_more_than_letters(self):
        got = self.words({"time": 0, "end": 100, "text": "夜 night", "words": []})
        self.assertEqual([w["weight"] for w in got], [2.5, 5.5])
        self.assertEqual([w["cjk"] for w in got], [True, False])

    def test_a_line_with_no_end_or_text(self):
        self.assertEqual(self.words({"time": 3, "text": "", "words": []}), [])
        got = self.words({"time": 3, "text": "hey", "words": []})
        self.assertAlmostEqual(got[0]["end"], 3.8)
        self.assertEqual(self.js("timeWords(null)"), [])

    def test_credit_lines_are_not_sung(self):
        # NetEase-style credits timed at 0:00 before an intro (seen in the host's cache), and their Latin forms.
        credits = ["作词 : 中村未来", "作曲：眞塩 楓", " 编曲 : someone", "Composer: X", "Lyrics by: Y", "Written by : Z", "MIX: W"]
        sung = ["運命に理由などないのさ", "Listen now", "I said: hold on", "時: 今", "", "Musical: chairs", "曲がり角"]
        self.assertEqual(self.js(f"{json.dumps(credits, ensure_ascii=False)}.map(credit)"), [True] * len(credits))
        self.assertEqual(self.js(f"{json.dumps(sung, ensure_ascii=False)}.map(credit)"), [False] * len(sung))

    def test_word_at(self):
        self.assertEqual(self.js("[0.5, 1, 2.5, 9].map(t => wordAt([{time: 1}, {time: 2}, {time: 3}], t))"), [-1, 0, 1, 2])
        self.assertEqual(self.js("wordAt([], 4)"), -1)

    def test_scale_grows_with_the_sung_length_within_bounds(self):
        got = self.js("[0, 0.1, 0.35, 1, 3, 30].map(scaleFor)")
        self.assertEqual(got[0], 0.7)
        self.assertEqual(got[2], 1)
        self.assertEqual(got[-1], 2.6)
        self.assertEqual(got, sorted(got))

    # Frames and the cut cap

    def test_frames_never_cut_faster_than_three_a_second(self):
        # A rap: twenty one-syllable words, 0.1 s apart, each long enough to fill a frame on its own.
        line = {"time": 0, "end": 2, "text": "", "words": [{"time": i / 10, "end": (i + 1) / 10, "text": "wordword"} for i in range(20)]}
        got = self.js(f"frames(timeWords({json.dumps(line)}), 8)")
        starts = [f["time"] for f in got]
        self.assertTrue(all(b - a >= 1 / 3 - 1e-9 for a, b in zip(starts, starts[1:])), starts)
        # Every word is in exactly one frame, in order.
        covered = [i for f in got for i in range(f["first"], f["last"] + 1)]
        self.assertEqual(covered, list(range(20)))

    def test_frames_close_on_width_and_on_a_held_word(self):
        line = {"time": 0, "end": 8, "text": "", "words": [
            {"time": 0, "end": 0.5, "text": "one"}, {"time": 0.5, "end": 1, "text": "two"},
            {"time": 1, "end": 1.5, "text": "three"}, {"time": 1.5, "end": 3.5, "text": "hold"},
            {"time": 3.5, "end": 4, "text": "end"}]}
        got = self.js(f"frames(timeWords({json.dumps(line)}), 8)")
        self.assertEqual([(f["first"], f["last"]) for f in got], [(0, 1), (2, 2), (3, 4)])
        # CJK characters count double toward the width.
        cjk = {"time": 0, "end": 8, "text": "", "words": [{"time": i, "end": i + 1, "text": "夜"} for i in range(6)]}
        self.assertEqual([(f["first"], f["last"]) for f in self.js(f"frames(timeWords({json.dumps(cjk, ensure_ascii=False)}), 8)")],
                         [(0, 3), (4, 5)])

    # Echoes and layout

    def test_a_returning_chorus_counts_its_echoes(self):
        lines = [{"text": "Hold on"}, {"text": "verse"}, {"text": "hold ON!"}, {"text": "Hold on"}, {"text": ""}, {"text": ""}]
        self.assertEqual(self.js(f"[0, 1, 2, 3, 4, 5].map(i => echoes({json.dumps(lines)}, i))"), [0, 0, 1, 2, 0, 0])

    MEASURE = "(t, px) => [...t].length * px * 0.55"

    def layout(self, words, width, height, base, upright=False):
        return self.js(f"layoutFrame({json.dumps(words, ensure_ascii=False)}, {self.MEASURE}, {width}, {height}, {base}, {str(upright).lower()})")

    def test_words_are_sized_by_their_sung_length_and_kept_inside(self):
        words = [{"text": "short", "time": 0, "end": 0.2}, {"text": "held", "time": 0.2, "end": 2.0}]
        got = self.layout(words, 600, 300, 40)
        a, b = got["items"]
        self.assertGreater(b["size"], a["size"] * 2)
        for it in got["items"]:
            self.assertGreaterEqual(it["x"], -0.5)
            self.assertLessEqual(it["x"] + it["width"], 600.5)
            self.assertGreaterEqual(it["y"], -0.5)
            self.assertLessEqual(it["y"] + it["height"], 300.5)
        # One run, the small word sitting on the big word's baseline.
        self.assertAlmostEqual(a["y"] + a["height"], b["y"] + b["height"], places=6)
        self.assertLess(a["x"], b["x"])

    def test_runs_wrap_and_a_crowded_frame_shrinks_to_fit(self):
        words = [{"text": "wordword", "time": i, "end": i + 0.35} for i in range(6)]
        got = self.layout(words, 300, 400, 40)
        self.assertEqual(got["fit"], 1)
        self.assertGreater(len({round(it["y"]) for it in got["items"]}), 1)
        crowded = self.layout(words, 300, 60, 40)
        self.assertLess(crowded["fit"], 1)
        self.assertLessEqual(crowded["height"], 60.5)
        self.assertLessEqual(crowded["width"], 300.5)

    def test_upright_columns_run_right_to_left(self):
        words = [{"text": "夜", "time": 0, "end": 0.35}, {"text": "空", "time": 0.35, "end": 0.7}, {"text": "に", "time": 0.7, "end": 1.05}]
        tall = self.layout(words, 400, 300, 40, upright=True)
        self.assertEqual(len({round(it["x"]) for it in tall["items"]}), 1)
        self.assertEqual([it["y"] for it in tall["items"]], sorted(it["y"] for it in tall["items"]))
        short = self.layout(words, 400, 90, 40, upright=True)
        xs = [it["x"] for it in short["items"]]
        self.assertGreater(xs[0], xs[-1])  # the first column is the rightmost
        for it in short["items"]:
            self.assertLessEqual(it["y"] + it["height"], 90.5)

    # Beats

    def run_detector(self, frames, step=1 / 43, **options):
        return self.js(f"(() => {{ const d = detector({json.dumps(options)}); return {json.dumps(frames)}.map((b, i) => d.push(b, i * {step})); }})()")

    def test_a_kick_on_a_steady_bed_is_an_onset_and_the_bed_is_not(self):
        bed = [0.2] * 56
        kick = [0.9] * 14 + [0.2] * 42
        frames = [bed] * 40 + [kick] + [bed] * 10
        got = self.run_detector(frames)
        self.assertEqual([i for i, s in enumerate(got) if s > 0], [40])
        self.assertGreater(got[40], 0)
        self.assertLessEqual(got[40], 1)

    def test_bass_weighs_double(self):
        bed = [0.2] * 56
        # Small rises, so neither strength saturates at 1: the same rise in the bass passes, in the treble not.
        low = [0.25] * 14 + [0.2] * 42
        high = [0.2] * 42 + [0.25] * 14
        self.assertGreater(self.run_detector([bed] * 20 + [low])[-1], 0)
        self.assertEqual(self.run_detector([bed] * 20 + [high])[-1], 0)

    def test_refractory_and_silence(self):
        bed, kick = [0.1] * 56, [1.0] * 56
        # Kicks every other frame (~46 ms): only one per refractory window counts.
        frames = [bed] * 20 + [kick, bed] * 8
        hits = [i for i, s in enumerate(self.run_detector(frames)) if s > 0]
        self.assertTrue(all((b - a) / 43 >= 0.12 for a, b in zip(hits, hits[1:])), hits)
        # An empty spectrum (paused) resets the comparison: the first frame back is not a jump from nothing.
        self.assertEqual(self.run_detector([[]] * 3 + [kick]), [0, 0, 0, 0])

    def test_a_steady_beat_is_found_each_time(self):
        bed, kick = [0.15] * 56, [0.8] * 14 + [0.3] * 42
        # 120 bpm at ~43 frames a second: a kick every 21–22 frames, for 4 s.
        frames = [kick if i % 21 == 0 and i > 0 else bed for i in range(172)]
        hits = [i for i, s in enumerate(self.run_detector(frames)) if s > 0]
        self.assertEqual(hits, [i for i in range(1, 172) if i % 21 == 0])


if __name__ == "__main__":
    unittest.main()
