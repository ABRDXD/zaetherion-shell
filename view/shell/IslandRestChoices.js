.pragma library

// What the island shows at rest (Z201), for FART's Island tab. The presets and modes are the core's
// (core/island.py REST_PRESETS, REST_MODES); tests/test_island_settings.py fails if these drift from them.
const PRESETS = {
    today: { power: "always", network: "always", battery: "always", inbox: "always" },
    a: { power: "hover", network: "matters", battery: "matters", inbox: "matters" },
    b: { power: "hover", network: "always", battery: "always", inbox: "dot" },
    c: { power: "hover", network: "matters", battery: "always", inbox: "unread" }
};
const MODES = {
    power: ["always", "matters", "hover"],
    network: ["always", "matters", "hover"],
    battery: ["always", "matters", "hover"],
    inbox: ["always", "matters", "unread", "dot", "hover"]
};
// What each preset looks like, in a line.
const PRESET_NOTES = {
    today: "Everything",
    a: "Only what needs you",
    b: "Wi-Fi, battery, dot",
    c: "Battery, unread bell"
};
const MODE_LABELS = { always: "Always", matters: "When it matters", unread: "While unread", dot: "As a dot", hover: "On hover" };
// What "when it matters" means for each item (Z201).
const MATTERS = { power: "never at rest", network: "offline", battery: "20 % unplugged", inbox: "critical unread" };

// The preset the rest equals, or "" for a mix of its own.
function presetOf(rest) {
    if (!rest)
        return "";
    for (const name of Object.keys(PRESETS)) {
        const p = PRESETS[name];
        if (Object.keys(p).every(item => rest[item] === p[item]))
            return name;
    }
    return "";
}

// One item's choices for a SettingChoices row: [[mode, label], …].
function options(item) {
    return (MODES[item] ?? []).map(mode => [mode, MODE_LABELS[mode]]);
}
