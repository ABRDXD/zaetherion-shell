.pragma library
// The week as a ledger (docs/OVERDRIVE.md §42; Claude B's own idea). Pure: no Qt, so Node tests run it
// (tests/test_week_ledger.py). The journey keeps each day's visits per room for thirty days (`days`: {"2026-11-09":
// {tasks: 12, …}}). In Overdrive each day of Home's week strip is inked from the bottom by how much FART was used that
// day, against the busiest day kept, and carries the number of the room it was spent in most. Future days stay blank.

// The rooms in the panel's order: their numbers are their places (00 Home … 09 Codex).
const ROOMS = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"];

function total(day) {
    let n = 0;
    for (const k in day ?? {})
        n += Math.max(0, day[k] || 0);
    return n;
}
// A day's share (0–1) of the busiest day kept.
function share(days, key) {
    let most = 0;
    for (const k in days ?? {})
        most = Math.max(most, total(days[k]));
    return most > 0 ? total((days ?? {})[key]) / most : 0;
}
// The room a day was spent in most, as its number ("05"), or "".
function dominant(days, key) {
    const day = (days ?? {})[key] ?? {};
    let best = "", most = 0;
    for (const r of ROOMS)
        if ((day[r] ?? 0) > most) { most = day[r]; best = r; }
    return best ? String(ROOMS.indexOf(best)).padStart(2, "0") : "";
}
