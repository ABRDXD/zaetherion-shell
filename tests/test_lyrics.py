"""Lyrics lookup against fixtures; no network."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("lyrics", ROOT / "tools/lyrics/lyrics.py")
lyrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lyrics)


class LyricsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.cache = Path(temp.name) / "lyrics"
        self.calls = []

    def fetcher(self, result):
        def fetch(title, artist, duration):
            self.calls.append((title, artist, duration))
            return result
        return fetch

    def test_key_matches_the_host_cache(self):
        self.assertEqual(lyrics.cache_key(" Title ", "Artist "), hashlib.md5(b"Artist - Title").hexdigest())

    def test_fetch_is_cached_then_served_from_cache(self):
        first = lyrics.lookup("Title", "Artist", 200, self.cache, [self.fetcher([{"time": 1.5, "text": "line"}])])
        self.assertEqual(first, {"status": "ok", "source": "fetch", "lines": [{"time": 1.5, "text": "line", "words": []}]})
        second = lyrics.lookup("Title", "Artist", 200, self.cache, [self.fetcher([])])
        self.assertEqual(second["source"], "fart-cache")
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(list(self.cache.iterdir()), [self.cache / f"{lyrics.cache_key('Title', 'Artist')}.json"])

    def test_falls_through_fetchers_and_caches_nothing_on_a_miss(self):
        result = lyrics.lookup("Title", "Artist", 0, self.cache, [self.fetcher([]), self.fetcher([])])
        self.assertEqual(result, {"status": "none", "lines": []})
        self.assertEqual(len(self.calls), 2)
        self.assertFalse(self.cache.exists())

    def test_missing_artist_is_no_track_without_fetching(self):
        self.assertEqual(lyrics.lookup("Title", " ", 0, self.cache, [self.fetcher([{"time": 0, "text": "x"}])])["status"], "no-track")
        self.assertEqual(self.calls, [])

    def test_corrupt_cache_is_refetched(self):
        self.cache.mkdir(parents=True)
        (self.cache / f"{lyrics.cache_key('Title', 'Artist')}.json").write_text("{not json")
        result = lyrics.lookup("Title", "Artist", 0, self.cache, [self.fetcher([{"time": 0, "text": "x"}])])
        self.assertEqual(result["source"], "fetch")
        self.assertEqual(json.loads((self.cache / f"{lyrics.cache_key('Title', 'Artist')}.json").read_text())[0]["text"], "x")

    def test_fetched_word_timing_is_kept(self):
        words = [{"time": 1.5, "end": 2.0, "text": "line"}]
        result = lyrics.lookup("Title", "Artist", 0, self.cache, [self.fetcher([{"time": 1.5, "text": "line", "words": words}])])
        self.assertEqual(result["lines"][0]["words"], words)


class LrcTests(unittest.TestCase):
    def test_plain_lines_are_sorted_with_metadata_skipped(self):
        lines = lyrics.parse_lrc("[ar:Someone]\n[ti:Song]\n[00:05.20] second \n[00:01.00]first\nno stamp\n")
        self.assertEqual([(l["time"], l["text"], l["words"]) for l in lines], [(1.0, "first", []), (5.2, "second", [])])

    def test_repeated_stamps_repeat_the_line(self):
        lines = lyrics.parse_lrc("[00:10.00][01:10.50]chorus")
        self.assertEqual([(l["time"], l["text"]) for l in lines], [(10.0, "chorus"), (70.5, "chorus")])

    def test_enhanced_words_end_at_the_next_stamp(self):
        line = lyrics.parse_lrc("[00:12.50]<00:12.50>Hello <00:13.10>bright <00:13.80>world<00:14.60>")[0]
        self.assertEqual(line["text"], "Hello bright world")
        self.assertEqual(line["words"], [{"time": 12.5, "end": 13.1, "text": "Hello"},
                                         {"time": 13.1, "end": 13.8, "text": "bright"},
                                         {"time": 13.8, "end": 14.6, "text": "world"}])

    def test_an_open_last_word_is_held_until_the_next_line_or_the_cap(self):
        lines = lyrics.parse_lrc("[00:01.00]<00:01.00>one <00:01.50>two\n[00:02.80]next\n[00:10.00]<00:10.00>alone")
        self.assertEqual(lines[0]["words"][-1]["end"], 2.8)
        self.assertEqual(lines[2]["words"][-1]["end"], 10.0 + lyrics.LAST_WORD_HOLD)

    def test_a2_inline_square_stamps_are_words(self):
        line = lyrics.parse_lrc("[00:01.00]Up [00:01.40]and [00:01.90]away[00:02.50]")[0]
        self.assertEqual(line["text"], "Up and away")
        # The text before the first inline stamp is opened by the line's own stamp.
        self.assertEqual(line["words"], [{"time": 1.0, "end": 1.4, "text": "Up"},
                                         {"time": 1.4, "end": 1.9, "text": "and"},
                                         {"time": 1.9, "end": 2.5, "text": "away"}])

    def test_offset_moves_everything_earlier_and_clamps_at_zero(self):
        lines = lyrics.parse_lrc("[offset:+500]\n[00:00.20]start\n[00:03.00]<00:03.00>a <00:03.40>b<00:04.00>")
        self.assertEqual(lines[0]["time"], 0.0)
        self.assertEqual(lines[1]["time"], 2.5)
        self.assertEqual(lines[1]["words"], [{"time": 2.5, "end": 2.9, "text": "a"}, {"time": 2.9, "end": 3.5, "text": "b"}])

    def test_colon_hundredths_and_repeated_words_shift_together(self):
        lines = lyrics.parse_lrc("[00:01:50][00:11:50]<00:01:50>la <00:02:00>la<00:02:50>")
        self.assertEqual(lines[0]["time"], 1.5)
        self.assertEqual(lines[1]["words"], [{"time": 11.5, "end": 12.0, "text": "la"}, {"time": 12.0, "end": 12.5, "text": "la"}])

    def test_cjk_lines_keep_their_text(self):
        line = lyrics.parse_lrc("[00:01.00]<00:01.00>夜<00:01.40>空<00:02.00>")[0]
        self.assertEqual(line["text"], "夜 空")
        self.assertEqual([w["text"] for w in line["words"]], ["夜", "空"])


class TtmlTests(unittest.TestCase):
    TTML = """<?xml version="1.0"?><tt xmlns="http://www.w3.org/ns/ttml"><body><div>
      <p begin="00:12.500" end="00:14.6"><span begin="12.5s" end="13.1s">Hello</span> <span begin="00:13.100" end="00:13.800">bright</span>
         <span begin="13800ms" end="14.6">world</span></p>
      <p begin="0:01.0" end="0:02.0">plain line</p>
      <p begin="20.0" end="22.0"><span begin="20.0" end="21.0">lead</span><span ttm:role="x-bg" xmlns:ttm="http://www.w3.org/ns/ttml#metadata"><span begin="21.0" end="22.0">(echo)</span></span></p>
    </div></body></tt>"""

    def test_spans_become_words(self):
        lines = lyrics._parse_ttml(self.TTML)
        self.assertEqual([(l["time"], l["text"]) for l in lines], [(1.0, "plain line"), (12.5, "Hello bright world"), (20.0, "lead(echo)")])
        self.assertEqual(lines[0]["words"], [])
        self.assertEqual(lines[1]["words"], [{"time": 12.5, "end": 13.1, "text": "Hello"},
                                             {"time": 13.1, "end": 13.8, "text": "bright"},
                                             {"time": 13.8, "end": 14.6, "text": "world"}])
        # A background-vocal group contributes its timed words, not itself.
        self.assertEqual([w["text"] for w in lines[2]["words"]], ["lead", "(echo)"])

    def test_local_files_by_sniffing(self):
        with tempfile.TemporaryDirectory() as temp:
            lrc, ttml, broken = Path(temp) / "a.lrc", Path(temp) / "b.ttml", Path(temp) / "c.ttml"
            lrc.write_text("\ufeff[00:01.00]hi", encoding="utf-8")
            ttml.write_text(self.TTML)
            broken.write_text("<tt><p begin=")
            self.assertEqual(lyrics.parse_file(lrc)[0]["text"], "hi")
            self.assertEqual(len(lyrics.parse_file(ttml)), 3)
            self.assertEqual(lyrics.parse_file(broken), [])


if __name__ == "__main__":
    unittest.main()
