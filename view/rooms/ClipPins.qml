import QtQuick
import qs.view.contract
import qs.view.shell

// FART's clipboard pins. They live in FART settings and can outlive the host history's retention.
QtObject {
    id: root
    required property ClipboardDomain clipboard
    readonly property var pins: Config.options.search.clipboardPins ?? []
    function indexOf(entry) {
        return pins.findIndex(pin => pin.id === entry.id || (!entry.isImage && pin.text !== "" && pin.text === entry.text));
    }
    function isPinned(entry) { return indexOf(entry) !== -1; }
    function toggle(entry) {
        const next = pins.slice();
        const index = indexOf(entry);
        if (index !== -1) next.splice(index, 1);
        else next.push({ id: entry.id, text: entry.isImage ? "" : entry.text, content: "" });
        Config.options.search.clipboardPins = next;
        if (index === -1 && !entry.isImage) clipboard.fetchText(entry.id);
    }
    function missing(entries, search) {
        const ids = new Set(entries.map(e => e.id));
        const texts = new Set(entries.map(e => e.text));
        const query = (search ?? "").trim().toLowerCase();
        return pins.filter(pin => pin.text && !ids.has(pin.id) && !texts.has(pin.text) && (query === "" || pin.text.toLowerCase().includes(query)));
    }
    function remove(pin) { Config.options.search.clipboardPins = pins.filter(item => item.id !== pin.id); }
    property Connections fetched: Connections {
        target: root.clipboard
        function onTextFetched(id, text) {
            Config.options.search.clipboardPins = root.pins.map(pin => pin.id === id ? { id: pin.id, text: pin.text, content: text } : pin);
        }
    }
}
