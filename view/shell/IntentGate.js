.pragma library
// Intent gate (docs/OVERDRIVE_IDEAS.md #62, docs/OVERDRIVE.md §52): in Overdrive, a command that cuts something off
// isn't a dialog away; it is two planes of type out of register. Enter on such a line splits it, and the line runs
// only once the planes are registered: typing the number of the room that holds what the command cuts closes the
// gap a digit at a time; a wrong key throws them apart again. Esc puts the line back. Silent never gates (it moves
// nothing), so every command there runs as it always has. Pure: no Qt (tests/test_intent_gate.py).

// The lines that cut something off, and the room holding what they cut. FART's own power button hands off to the
// host's session menu, which confirms for itself, so it isn't here.
// `args`: the argument words the core reads as that cut (core/verbs/base.py's switch reads off, 0 and no as off).
const GATED = [
    { verb: "wifi", args: ["off", "0", "no"], room: "devices", what: "THE NETWORK" },
    { verb: "bt", args: ["off", "0", "no"], room: "devices", what: "BLUETOOTH" },
    { verb: "session", args: ["end"], room: "timers", what: "THE SESSION" },
    { verb: "lock", args: [""], room: "home", what: "THE DESK" }
];
const ALIASES = { bluetooth: "bt" };

// The gate for a typed line, or null. `resolved` is the verb the core's live hint resolved the first word to (a prefix
// or an alias), if any.
function gate(line, resolved) {
    if (typeof line !== "string")
        return null;
    const words = line.trim().toLowerCase().split(/\s+/).filter(w => w !== "");
    if (words.length === 0)
        return null;
    const arg = words.slice(1).join(" ");
    // The word as typed, its alias, or what the core resolved it to: any of them gates.
    const verbs = [words[0], ALIASES[words[0]], resolved].filter(v => typeof v === "string" && v !== "");
    for (let i = 0; i < GATED.length; i++)
        if (verbs.indexOf(GATED[i].verb) >= 0 && GATED[i].args.indexOf(arg) >= 0)
            return { verb: GATED[i].verb, arg: arg, room: GATED[i].room, what: GATED[i].what };
    return null;
}
// The keys that register it: the room's number as the index ribbon sets it.
function sequence(index) {
    const n = Math.max(0, Math.floor(index));
    return n < 10 ? "0" + n : String(n);
}
// One key against the gate: `typed` digits so far. Returns how many are right after it; a wrong key starts over.
function step(seq, typed, key) {
    if (typed >= seq.length)
        return typed;
    return key === seq.charAt(typed) ? typed + 1 : 0;
}
// How far apart the planes stand: one notch per digit still owed.
function notches(seq, typed) {
    return Math.max(0, seq.length - Math.max(0, typed));
}
function registered(seq, typed) {
    return seq.length > 0 && typed >= seq.length;
}
