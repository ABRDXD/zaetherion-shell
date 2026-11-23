"""Text matching for the launcher (S6), after DMS's AppSearchService (v2.1.0, MIT; Z161, NOTICE).

Pure functions over lower-cased text: a match kind and its score for one entry, so the launcher and anything
else that ranks typed text agree. The weights are DMS's, so an app ranks where it did in DMS's spotlight.
"""
from __future__ import annotations

import re

# Text scores by how the query meets the entry, best first (DMS's searchApplications).
EXACT, PREFIX, WORD, SUBSTRING = 10000, 5000, 3000, 500
GENERIC_PREFIX, GENERIC, ID = 800, 400, 350
KEYWORD_PREFIX, KEYWORD, COMMENT = 300, 150, 50
FUZZY = 100  # times the fuzzy similarity, 0..1

_SPLIT = re.compile(r"[\s\-_]+")


def tokenize(text: str) -> list[str]:
    return [word for word in _SPLIT.split(text.lower().strip()) if word]


def words_start(text_words: list[str], query_words: list[str]) -> bool:
    """Consecutive words of the text each start with the query's words in order ("vis co" → "Visual Studio Code")."""
    if not query_words or len(query_words) > len(text_words):
        return False
    span = len(query_words)
    return any(all(text_words[i + j].startswith(query_words[j]) for j in range(span))
               for i in range(len(text_words) - span + 1))


def levenshtein(a: str, b: str) -> int:
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def max_typos(length: int) -> int:
    return 0 if length <= 2 else 1 if length == 3 else 2 if length <= 6 else 3


def fuzzy(text: str, query: str, words: list[str]) -> float:
    """Similarity 0..1 of the whole text or its closest word, within a typo budget that grows with the query."""
    budget = max_typos(len(query))
    best = 0.0
    for candidate in (text, *words):
        if abs(len(candidate) - len(query)) > budget:
            continue
        distance = levenshtein(candidate, query)
        if distance <= budget:
            best = max(best, 1 - distance / max(len(candidate), len(query)))
    return best


class Indexed:
    """One entry's lower-cased fields, prepared once when the list changes, not on every key."""
    __slots__ = ("name", "words", "generic", "comment", "id", "keywords")

    def __init__(self, name: str, generic: str = "", comment: str = "", id: str = "", keywords=()):
        self.name = name.lower()
        self.words = tokenize(name)
        self.generic = generic.lower()
        self.comment = comment.lower()
        self.id = id.lower()
        self.keywords = [k.lower() for k in keywords]


def score(entry: Indexed, query: str) -> tuple[str, float] | None:
    """(kind, text score) for a lower-cased, stripped query, or None when it doesn't match."""
    name = entry.name
    if name == query:
        return "exact", EXACT
    if name.startswith(query):
        return "prefix", PREFIX
    if words_start(entry.words, tokenize(query)):
        return "word", WORD
    if query in name:
        return "substring", SUBSTRING
    if entry.generic.startswith(query) and entry.generic:
        return "generic-prefix", GENERIC_PREFIX
    if entry.generic and query in entry.generic:
        return "generic", GENERIC
    if entry.id and query in entry.id:
        return "id", ID
    for keyword in entry.keywords:
        if keyword.startswith(query):
            return "keyword-prefix", KEYWORD_PREFIX
        if query in keyword:
            return "keyword", KEYWORD
    if entry.comment and query in entry.comment:
        return "comment", COMMENT
    similarity = fuzzy(name, query, entry.words)
    if similarity > 0:
        return "fuzzy", similarity * FUZZY
    return None
