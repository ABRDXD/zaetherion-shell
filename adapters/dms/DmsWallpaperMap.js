.pragma library

// DMS's session.json (~/.local/state/dms) → the wallpaper domain's state (Z177). Pure.
// DMS keeps wallpaperPath on the current mode's wallpaper when perModeWallpaper is on, so it is the one applied.
// A plain colour ("#rrggbb", DMS's setWallpaperColor) is not a file: current "".
// Returns { current, perScreen }; text that isn't a JSON object gives { current: "", perScreen: false }.
function fromSession(text) {
    let data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        data = null;
    }
    if (!data || typeof data !== "object" || Array.isArray(data))
        return { current: "", perScreen: false };
    const path = typeof data.wallpaperPath === "string" ? data.wallpaperPath : "";
    return { current: path.startsWith("/") ? path : "", perScreen: data.perMonitorWallpaper === true };
}

// The argv that sets one wallpaper for every screen (DMS's IPC; it writes session.json and re-runs its theme).
function setCommand(path) {
    return ["dms", "ipc", "call", "wallpaper", "set", path];
}
