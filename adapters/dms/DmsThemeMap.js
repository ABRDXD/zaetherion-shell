.pragma library

// DMS's settings.json → its current theme id, and the commands that switch theme (Z180). Pure.
// An installed theme is DMS's "custom" theme pointed at <config>/dms/themes/<id>/theme.json, which is what DMS's own
// theme picker does. Its `settings set` IPC runs the key's change hook on every set, so setting currentThemeName
// to "custom" after the file reloads the theme: DMS writes its own file, we never do.
function currentFrom(text) {
    let data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        data = null;
    }
    if (!data || typeof data !== "object" || Array.isArray(data))
        return "";
    const name = typeof data.currentThemeName === "string" ? data.currentThemeName : "";
    if (name !== "custom")
        return name;
    const file = typeof data.customThemeFile === "string" ? data.customThemeFile : "";
    const match = file.match(/\/themes\/([^/]+)\/theme\.json$/);
    return match ? match[1] : "";
}

function validId(id) {
    return typeof id === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(id) && id !== "." && id !== "..";
}

// Two argv, to run in order; [] for an invalid id.
function setCommands(configDir, id) {
    if (!validId(id))
        return [];
    return [["dms", "ipc", "call", "settings", "set", "customThemeFile", configDir + "/dms/themes/" + id + "/theme.json"],
            ["dms", "ipc", "call", "settings", "set", "currentThemeName", "custom"]];
}
