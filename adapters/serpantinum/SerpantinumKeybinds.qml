import QtQuick
import Quickshell.Io
import qs.view.contract

// The keybinds as Hyprland reports them (`hyprctl binds -j`, read-only). A description reads "Section: what it does".
KeybindsDomain {
    id: root
    available: true
    readonly property var masks: [[64, "SUPER"], [1, "SHIFT"], [4, "CTRL"], [8, "ALT"]]
    function parse(text) {
        let list = [];
        try {
            list = JSON.parse(text);
        } catch (error) {
            return;
        }
        const seen = {};
        const out = [];
        for (const bind of list) {
            if (!bind.has_description || !bind.description)
                continue;
            const colon = bind.description.indexOf(":");
            const section = colon > 0 ? bind.description.slice(0, colon).trim() : "Other";
            const description = colon > 0 ? bind.description.slice(colon + 1).trim() : bind.description;
            const entry = { mods: masks.filter(m => bind.modmask & m[0]).map(m => m[1]), key: bind.key, section: section, description: description };
            const id = entry.mods.join("+") + "|" + entry.key + "|" + description;
            if (!seen[id]) {
                seen[id] = true;
                out.push(entry);
            }
        }
        binds = out;
    }
    function refresh() { reader.running = true; }
    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
}
