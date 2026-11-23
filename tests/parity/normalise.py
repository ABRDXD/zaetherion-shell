"""What two cores may legitimately differ in, masked so their observations can be compared.

Times, process ids and memory change from run to run; they become a type tag ("<int>", "<float>"), so a core
that writes 1 where Python writes 1.0 still shows up. Random ids (tasks t1a2b3c4d, lists l…) become aliases in
order of first sight (t#1, l#1), so two runs that made the same things in the same order compare equal.
"""
from __future__ import annotations

import re

# Keys whose values are clocks, pids or measurements. A null stays null: "no time yet" must match.
VOLATILE = {"pid", "startedAt", "rssKiB", "uptime", "at", "since", "created", "doneAt", "closedSince", "elapsed",
            "until", "start", "end", "hour", "laps", "boot", "real", "bootId"}
LONG_NUMBER = re.compile(r"-?\d{6,}(\.\d+)?(e[+-]?\d+)?|\d+\.\d{6,}")
RANDOM_ID = re.compile(r"\b([tl])[0-9a-f]{8}\b")


def tag(value) -> str:
    return "<float>" if isinstance(value, float) else "<int>" if isinstance(value, int) else f"<{type(value).__name__}>"


class Normaliser:
    def __init__(self):
        self.aliases: dict[str, str] = {}

    def _alias(self, match: re.Match) -> str:
        raw = match.group(0)
        if raw not in self.aliases:
            n = sum(1 for a in self.aliases.values() if a[0] == raw[0]) + 1
            self.aliases[raw] = f"{raw[0]}#{n}"
        return self.aliases[raw]

    def __call__(self, value, key: str | None = None):
        if key in VOLATILE and value is not None and not isinstance(value, bool):
            if isinstance(value, list):
                return [tag(v) for v in value]
            if isinstance(value, str):
                return "<str>"
            return tag(value) if not isinstance(value, dict) else self(value)
        if isinstance(value, dict):
            return {k: self(v, k) for k, v in value.items()}
        if isinstance(value, list):
            return [self(v) for v in value]
        if isinstance(value, str):
            return RANDOM_ID.sub(self._alias, value)
        return value

    def text(self, data: bytes) -> str:
        """A file's text with random ids aliased and long numbers (times, anchors) masked: its style stays visible."""
        text = RANDOM_ID.sub(self._alias, data.decode("utf-8", errors="backslashreplace"))
        return LONG_NUMBER.sub("<n>", text)
