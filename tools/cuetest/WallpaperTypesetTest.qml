import QtQuick
import Quickshell
import qs.core.client
import qs.view.shell
import qs.view.ui as UI

// The wallpaper picker's Typeset button (Z215), offscreen on a fake core: shown for a photo, hidden for a plate (which
// gets its note), busy while the core typesets, and a click asks the core for the shown picture.
Scope {
    id: root
    property var calls: []
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function named(name, from) {
        const walk = i => { if (!i) return null; if (i.objectName === name) return i; for (const c of i.children ?? []) { const f = walk(c); if (f) return f; } return null; };
        return walk(from ?? picker);
    }
    function texts() {
        const out = [];
        const walk = i => { if (!i) return; if (i.visible && typeof i.text === "string" && i.text) out.push(i.text); for (const c of i.children ?? []) walk(c); };
        walk(picker);
        return out;
    }
    readonly property var listing: ({ folder: "/w", exists: true, entries: [
        { name: "rain", file: "rain.jpg", path: "/w/rain.jpg", kind: "image", size: 1, mtime: 0, plate: false },
        { name: "zg-01-torii", file: "zg-01-torii.png", path: "/w/zg-01-torii.png", kind: "image", size: 1, mtime: 0, plate: true }] })
    CoreClient {
        id: core
        path: ""
        connected: true
        wallpaperData: ({ folder: "/w", exists: true, recent: [], preview: null, available: true, current: "/w/rain.jpg",
                          perScreen: false, error: "", colours: false, coloursError: "", typesetting: "", typesetError: "" })
        function request(op, args, callback) {
            root.calls = root.calls.concat([{ op: op, args: args }]);
            if (callback) callback(true, op === "wallpaper.list" ? root.listing : wallpaperData);
        }
    }
    FloatingWindow {
        implicitWidth: 1100; implicitHeight: 700; visible: true; color: "#000000"
        WallpaperPicker { id: picker; anchors.fill: parent; anchors.margins: 20; core: core }
    }
    Timer {
        interval: 400; running: true
        onTriggered: {
            picker.active = true;
            picker.load();
            Qt.callLater(() => {
                const button = root.named("wallpaperTypeset");
                root.check("shown.for.a.photo", !!button && button.visible && button.enabled && button.label === "Typeset this picture",
                           { label: button?.label, visible: button?.visible });
                button.clicked();
                const call = root.calls.find(c => c.op === "wallpaper.typeset");
                root.check("asks.for.the.shown.picture", !!call && call.args.name === "/w/rain.jpg", root.calls);
                core.wallpaperData = Object.assign({}, core.wallpaperData, { typesetting: "/w/rain.jpg" });
                root.check("busy.while.typesetting", !button.enabled && button.label.startsWith("Typesetting"), { label: button.label });
                core.wallpaperData = Object.assign({}, core.wallpaperData, { typesetting: "", typesetError: "typesetting failed: x" });
                root.check("failure.said", root.texts().some(t => t === "Not typeset: typesetting failed: x"), root.texts());
                picker.highlighted = "/w/zg-01-torii.png";
                Qt.callLater(() => {
                    root.check("hidden.for.a.plate", !button.visible, {});
                    root.check("plate.note", root.texts().some(t => t.startsWith("A typeset plate")), root.texts());
                    console.log("CUE_DONE");
                    Qt.quit();
                });
            });
        }
    }
}
