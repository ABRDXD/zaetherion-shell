.pragma library

// DMS `brightness` snapshot → one OSD sample (docs/DMS_ADAPTER.md §5). Pure.
// The screen's own backlight first (class "backlight"); an external monitor (DDC) only if there is no backlight.
// Takes the snapshot ({devices}) or a `brightness.update` ({device}, S9a).
// Returns { kind: "brightness", node, level, muted: false } or null.
function sample(data) {
    const devices = (data && Array.isArray(data.devices)) ? data.devices : (data && data.device ? [data.device] : []);
    const usable = devices.filter(d => d && typeof d.id === "string" && typeof d.currentPercent === "number");
    const device = usable.find(d => d.class === "backlight") || usable.find(d => d.class === "ddc") || null;
    if (!device)
        return null;
    return { kind: "brightness", node: device.id, level: Math.max(0, Math.min(1, device.currentPercent / 100)), muted: false };
}
