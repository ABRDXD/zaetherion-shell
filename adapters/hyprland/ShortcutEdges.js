.pragma library

// Hyprland's global shortcut edges for a key that opens something (S6, Z196). A plain bind (Super+Space) sends press
// then release; a bind on release (the Super tap, `release = true`) sends only the release. Exactly one open per
// keystroke either way: on the press, or on a release that had no press before it.
// edge(down, kind) → { down, open }: `down` is the state to keep, `open` whether this edge opens.
function edge(down, kind) {
    if (kind === "pressed") return { down: true, open: true };
    return { down: false, open: !down };
}
