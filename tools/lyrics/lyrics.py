#!/usr/bin/env python3
import argparse
import hashlib
import os
from pathlib import Path
import sys
import tempfile
import urllib.request
import urllib.parse
import json
import re
import xml.etree.ElementTree as ET

# A line's leading stamps; inline word stamps as <mm:ss.xx> (enhanced LRC) or a later [mm:ss.xx] (the A2 variant).
_LINE_STAMP = re.compile(r"\[(\d+):(\d{1,2}(?:[.:]\d+)?)\]")
_WORD_STAMP = re.compile(r"<(\d+):(\d{1,2}(?:[.:]\d+)?)>|\[(\d+):(\d{1,2}(?:[.:]\d+)?)\]")
_OFFSET = re.compile(r"^\[offset:\s*([+-]?\d+)\s*\]$", re.I)
# A last word with no closing stamp is held at most this long (seconds).
LAST_WORD_HOLD = 2.0


def _stamp_seconds(minutes: str, seconds: str) -> float:
    # Some writers use mm:ss:xx for hundredths.
    whole, _, frac = seconds.replace(":", ".").partition(".")
    return int(minutes) * 60 + int(whole) + (float("0." + frac) if frac else 0.0)


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _lrc_words(body: str, line_start: float) -> list:
    """Enhanced-LRC words: each stamp opens the word after it; a trailing stamp closes the last one.
    Text before the first word stamp is a word opened by the line's own stamp."""
    marks = list(_WORD_STAMP.finditer(body))
    words = []
    if marks and body[:marks[0].start()].strip():
        words.append({"time": line_start, "end": None, "text": body[:marks[0].start()].strip()})
    for i, m in enumerate(marks):
        start = _stamp_seconds(m[1] or m[3], m[2] or m[4])
        text = body[m.end():marks[i + 1].start() if i + 1 < len(marks) else len(body)]
        if words and words[-1]["end"] is None:
            words[-1]["end"] = start
        if text.strip():
            words.append({"time": start, "end": None, "text": text.strip()})
    return words


def parse_lrc(lrc_text: str) -> list:
    """LRC and enhanced LRC as lines of {time, text, words: [{time, end, text}]}, sorted, in seconds.

    Handles several stamps on one line (a repeated chorus), [offset:±ms] (positive shows the words
    earlier, as the format defines) and metadata tags, which are skipped."""
    offset = 0.0
    entries = []
    for raw in lrc_text.splitlines():
        raw = raw.strip()
        if m := _OFFSET.match(raw):
            offset = int(m[1]) / 1000
            continue
        stamps, pos = [], 0
        while m := _LINE_STAMP.match(raw, pos):
            stamps.append(_stamp_seconds(m[1], m[2]))
            pos = m.end()
        if not stamps:
            continue
        body = raw[pos:]
        words = _lrc_words(body, stamps[0])
        text = _clean(_WORD_STAMP.sub(" ", body))
        for stamp in stamps:
            # Word stamps are absolute; a repeat of the line moves its words with it.
            shift = stamp - stamps[0]
            entries.append({"time": stamp, "text": text,
                            "words": [dict(w, time=w["time"] + shift, end=None if w["end"] is None else w["end"] + shift)
                                      for w in words]})
    entries.sort(key=lambda x: x["time"])
    for i, line in enumerate(entries):
        following = entries[i + 1]["time"] if i + 1 < len(entries) else None
        for j, word in enumerate(line["words"]):
            if word["end"] is None:
                nxt = line["words"][j + 1]["time"] if j + 1 < len(line["words"]) else word["time"] + LAST_WORD_HOLD
                word["end"] = min(nxt, following) if following is not None and following > word["time"] else nxt
    for line in entries:
        line["time"] = round(max(0.0, line["time"] - offset), 3)
        for word in line["words"]:
            word["time"] = round(max(0.0, word["time"] - offset), 3)
            word["end"] = round(max(word["time"], word["end"] - offset), 3)
    return entries


_parse_lrc = parse_lrc

def _is_match(d: dict, title: str, artist: str) -> bool:
    if not d.get("syncedLyrics"):
        return False
    r_title  = (d.get("trackName")  or "").lower()
    r_artist = (d.get("artistName") or "").lower()
    t = title.lower()
    a = artist.lower()
    title_match = (t in r_title or r_title in t or
                   any(word in r_title for word in t.split() if len(word) > 3))
    artist_match = (a in r_artist or r_artist in a or
                    any(word in r_artist for word in a.split() if len(word) > 3))
    return title_match and artist_match

def fetch_lrclib(title: str, artist: str, duration: float) -> list:
    urls = [
        f"https://lrclib.net/api/get?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}&duration={int(duration)}",
        f"https://lrclib.net/api/search?track_name={urllib.parse.quote(title)}&artist_name={urllib.parse.quote(artist)}",
        f"https://lrclib.net/api/search?q={urllib.parse.quote(title + ' ' + artist)}",
    ]
    for url in urls:
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                data = json.loads(r.read().decode())
            if isinstance(data, list):
                data = next((d for d in data if _is_match(d, title, artist)), None)
            if data and _is_match(data, title, artist):
                lines = _parse_lrc(data["syncedLyrics"])
                if lines:
                    return lines
        except Exception:
            continue
    return []

def _ttml_seconds(value: str) -> float:
    value = value.strip()
    if value.endswith("ms"):
        return float(value[:-2]) / 1000
    total = 0.0
    for part in value.rstrip("s").split(":"):
        total = total * 60 + float(part)
    return total


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _parse_ttml(ttml: str) -> list:
    """TTML <p> lines; their timed <span>s (word-synced TTML) become the words."""
    root = ET.fromstring(ttml)
    lines = []
    for p in root.iter():
        if _local(p.tag) != "p" or p.get("begin") is None:
            continue
        text = _clean("".join(p.itertext()))
        try:
            start = _ttml_seconds(p.get("begin"))
            words = []
            for span in p.iter():
                if span is p or _local(span.tag) != "span" or span.get("begin") is None:
                    continue
                word = _clean("".join(span.itertext()))
                # A span wrapping timed spans (a background-vocal group) is not itself a word.
                if word and not any(_local(c.tag) == "span" and c.get("begin") for c in span):
                    begin = _ttml_seconds(span.get("begin"))
                    end = _ttml_seconds(span.get("end")) if span.get("end") else begin
                    words.append({"time": round(begin, 3), "end": round(max(begin, end), 3), "text": word})
        except ValueError:
            continue
        lines.append({"time": round(start, 3), "text": text, "words": sorted(words, key=lambda w: w["time"])})
    return sorted(lines, key=lambda x: x["time"])


def parse_file(path: Path) -> list:
    """A local lyrics file: TTML if it looks like XML, otherwise LRC."""
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    if text.lstrip().startswith(("<?xml", "<tt")):
        try:
            return _parse_ttml(text)
        except ET.ParseError:
            return []
    return parse_lrc(text)

BOIDU_BASES = ["https://api.betterlyrics.org", "https://lyrics-api.boidu.dev"]

def fetch_boidu(title: str, artist: str, duration: float) -> list:
    query = f"/getLyrics?s={urllib.parse.quote(title)}&a={urllib.parse.quote(artist)}"
    if duration > 0:
        query += f"&d={int(duration)}"
    for base in BOIDU_BASES:
        try:
            req = urllib.request.Request(base + query, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = json.loads(r.read().decode())
            lines = _parse_ttml(data.get("ttml") or "")
            if len(lines) >= 3:
                return lines
        except Exception:
            continue
    return []

def cache_key(title: str, artist: str) -> str:
    """Same key as Serpantinum's lyrics cache: md5("Artist - Title")."""
    return hashlib.md5(f"{artist.strip()} - {title.strip()}".encode()).hexdigest()


def read_cache(directory: Path, key: str) -> list:
    try:
        lines = json.loads((directory / f"{key}.json").read_text())
    except (OSError, ValueError):
        return []
    return lines if isinstance(lines, list) and lines else []


def write_cache(directory: Path, key: str, lines: list) -> None:
    """Atomic write; a failed write only costs a refetch."""
    try:
        directory.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=directory, prefix=f".{key}.")
        with os.fdopen(fd, "w") as handle:
            json.dump(lines, handle, ensure_ascii=False)
        os.replace(tmp, directory / f"{key}.json")
    except OSError:
        pass


def lookup(title: str, artist: str, duration: float, cache_dir: Path | None, fetchers=None) -> dict:
    if not title.strip() or not artist.strip():
        return {"status": "no-track", "lines": []}
    key = cache_key(title, artist)
    if cache_dir:
        cached = read_cache(cache_dir, key)
        if cached:
            return {"status": "ok", "source": "fart-cache", "lines": cached}
    for fetch in fetchers or (fetch_lrclib, fetch_boidu):
        lines = [{"time": l["time"], "text": l["text"], "words": l.get("words") or []} for l in fetch(title, artist, duration)]
        if lines:
            if cache_dir:
                write_cache(cache_dir, key, lines)
            return {"status": "ok", "source": "fetch", "lines": lines}
    return {"status": "none", "lines": []}


def main():
    parser = argparse.ArgumentParser(description="Synced lyrics for one track, as one JSON line.")
    parser.add_argument("title", nargs="?", default="")
    parser.add_argument("artist", nargs="?", default="")
    parser.add_argument("duration", type=float, nargs="?", default=0)
    parser.add_argument("--cache-dir", type=Path)
    parser.add_argument("--file", type=Path, help="parse a local .lrc or .ttml file instead (no network, no cache)")
    args = parser.parse_args()
    if args.file:
        try:
            lines = parse_file(args.file)
        except OSError:
            lines = []
        print(json.dumps({"status": "ok" if lines else "none", "source": "local", "lines": lines}, ensure_ascii=False), flush=True)
        return
    print(json.dumps(lookup(args.title, args.artist, args.duration, args.cache_dir), ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
