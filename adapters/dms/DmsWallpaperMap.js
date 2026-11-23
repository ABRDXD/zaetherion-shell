.pragma library

// DMS's session.json (~/.local/state/dms) → the wallpaper domain's state (Z178, Z210). Pure.
// DMS keeps wallpaperPath on the current mode's wallpaper when perModeWallpaper is on, so it is the one applied.
// With perMonitorWallpaper on, each screen shows its own entry in monitorWallpapers (also the current mode's), and
// wallpaperPath is stale: current is the first listed screen's entry, falling back to wallpaperPath.
// A plain colour ("#rrggbb", DMS's setWallpaperColor) is not a file: current "".
// Returns { current, perScreen }; text that isn't a JSON object gives { current: "", perScreen: false }.
function fromSession(text, screens) {
    let data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        data = null;
    }
    if (!data || typeof data !== "object" || Array.isArray(data))
        return { current: "", perScreen: false };
    const perScreen = data.perMonitorWallpaper === true;
    let path = typeof data.wallpaperPath === "string" ? data.wallpaperPath : "";
    const byScreen = data.monitorWallpapers;
    if (perScreen && byScreen && typeof byScreen === "object" && !Array.isArray(byScreen)) {
        const own = (screens ?? []).map(name => byScreen[name]).find(value => typeof value === "string" && value !== "");
        if (own !== undefined)
            path = own;
    }
    return { current: path.startsWith("/") ? path : "", perScreen: perScreen };
}

// The argv that sets one wallpaper for every screen (DMS's IPC; it writes session.json and re-runs its theme).
function setCommand(path) {
    return ["dms", "ipc", "call", "wallpaper", "set", path];
}

// The argvs that set one wallpaper for every screen in either DMS mode (Z210). DMS refuses `set` while it keeps a
// wallpaper per screen, so then each screen gets `setFor`; no screens, nothing to run.
function setCommands(path, perScreen, screens) {
    if (!perScreen)
        return [setCommand(path)];
    return (screens ?? []).filter(name => typeof name === "string" && name !== "")
        .map(name => ["dms", "ipc", "call", "wallpaper", "setFor", name, path]);
}
