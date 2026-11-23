.pragma library

// MIME taxonomy (atlas #31, docs/OVERDRIVE.md §27): the kind of a clip from what Clips already shows of it, in memory
// only (nothing is stored or sent), so each kind can carry its own editorial mark. Pure; tests run it under Node
// (tests/test_clip_kinds.py). Kinds: IMAGE, LINK, PATH, COLOUR, NUMBER, CODE, TEXT.
function kind(entry) {
    if (!entry)
        return "TEXT";
    if (entry.isImage)
        return "IMAGE";
    const t = String(entry.text || "").trim();
    if (/^(https?:\/\/|www\.)\S+$/i.test(t))
        return "LINK";
    if (/^(~|\.{0,2})\/[^\s]*$/.test(t) || /^[A-Za-z]:\\\S*$/.test(t))
        return "PATH";
    if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t) || /^rgba?\(\s*\d/.test(t))
        return "COLOUR";
    if (/^[+\-]?[\d\s.,:/()+\-]+$/.test(t) && /\d/.test(t) && t.replace(/\D/g, "").length >= 2)
        return "NUMBER";
    if (/[{};]\s*$|=>|\bfunction\b|\bdef\b|\bimport\b|\bconst\b|^\s*[<$#]\s?\w|\w\(.*\)\s*[;{]?$/m.test(t) && !/^[A-Z][a-z]+( [a-z]+)+[.!?]$/.test(t))
        return "CODE";
    return "TEXT";
}
// A colour clip's colour, for its swatch; "" for anything else.
function colour(entry) {
    return kind(entry) === "COLOUR" ? String(entry.text).trim() : "";
}
