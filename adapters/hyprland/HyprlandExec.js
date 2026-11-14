.pragma library

// Hyprland's exec runs a shell line with the compositor's environment, so an app started from the shell gets what
// a keybind would give it, not the view's own settings (FART_*, ZAETHERION_*). One single-quoted word per argument;
// Quickshell has already expanded the desktop entry's field codes. Hyprland 0.57 with a Lua config reads a
// dispatch as Lua (`hl.dispatch(<arg>)`), so the line goes in as `hl.dsp.exec_cmd("<line>")`, as the owner's
// keybinds do.

function quote(word) {
    return "'" + String(word).replace(/'/g, "'\\''") + "'";
}

function line(argv, workingDirectory) {
    const run = "exec " + argv.map(quote).join(" ");
    return workingDirectory ? "cd " + quote(workingDirectory) + " && " + run : run;
}

// A Lua string literal: backslash and quote escaped, control characters as decimal escapes.
function luaString(text) {
    return '"' + String(text).replace(/[\\"\x00-\x1f\x7f]/g, ch => ch === "\\" || ch === '"' ? "\\" + ch : "\\" + String(ch.charCodeAt(0)).padStart(3, "0")) + '"';
}

function dispatch(argv, workingDirectory) {
    return "hl.dsp.exec_cmd(" + luaString(line(argv, workingDirectory)) + ")";
}
