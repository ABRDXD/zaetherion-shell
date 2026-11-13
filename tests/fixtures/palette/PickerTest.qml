import QtQuick
import QtQuick.Window
import Quickshell
import qs.core.client
import qs.view.ui
import qs.view.shell

ShellRoot {
    id: root
    property var saved: ({ name: "dms:amoledBlack", effective: "dms:amoledBlack", preview: false,
        colors: {background: "#000000", accent: "#ffffff"}, savedColors: {background: "#000000", accent: "#ffffff"} })
    property var choices: [
        {id: "dms:amoledBlack", name: "Amoled Black", source: "DMS", accent: "#ffffff"},
        {id: "amoled:ice", name: "Ice", source: "AMOLED studies", accent: "#8edfff"}
    ]
    property int stage: 0
    function check(ok: bool, label: string): void {
        console.log((ok ? "PALETTE_PASS " : "PALETTE_FAIL ") + label);
        if (!ok) Qt.quit();
    }
    CoreClient {
        id: client
        path: ""
        connected: true
        paletteData: root.saved
        function request(op, args, callback) {
            if (op === "palette.list") { callback(true, root.choices); return; }
            if (op === "palette.cancel") paletteData = root.saved;
            else {
                const entry = root.choices.find(item => item.id === args.name);
                const colors = {background: "#000000", accent: entry.accent};
                paletteData = {name: root.saved.name, effective: entry.id, preview: true,
                    colors, savedColors: root.saved.colors};
                if (op === "palette.choose") {
                    root.saved = {name: entry.id, effective: entry.id, preview: false, colors, savedColors: colors};
                    paletteData = root.saved;
                }
            }
            if (callback) callback(true, paletteData);
        }
    }
    PaletteBinding { core: client }
    Window {
        visible: true
        width: 440
        height: 400
        color: Design.background
        PalettePicker { id: picker; anchors.fill: parent; core: client }
    }
    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            switch (root.stage++) {
            case 0: picker.active = true; break;
            case 1:
                root.check(Design.accent.toString() === "#ffffff", "initial stored palette");
                picker.moveSelection(1); break;
            case 2:
                root.check(Design.accent.toString() === "#8edfff", "arrow navigation previews Design");
                picker.active = false; break;
            case 3:
                root.check(Design.accent.toString() === "#ffffff", "closing cancels preview");
                picker.active = true; break;
            case 4: picker.previewIndex(1); picker.chooseCurrent(); break;
            case 5:
                root.check(root.saved.name === "amoled:ice" && Design.accent.toString() === "#8edfff", "choose changes Design and selection");
                picker.active = false; break;
            case 6:
                root.check(Design.accent.toString() === "#8edfff", "close preserves chosen palette");
                picker.active = true; break;
            case 7: picker.preview("dms:amoledBlack"); break;
            case 8:
                client.connected = false; break;
            case 9:
                root.check(Design.accent.toString() === "#8edfff", "disconnect restores committed colours");
                console.log("PALETTE_DONE"); Qt.quit(); break;
            }
        }
    }
}
