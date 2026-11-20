import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.core.client
import qs.view.ui

ColumnLayout {
    id: root
    required property CoreClient core
    property bool active: false
    property var entries: []
    property string query: ""
    property string error: ""
    readonly property var filtered: entries.filter(entry =>
        (entry.name + " " + entry.source).toLowerCase().includes(query.toLowerCase()))
    readonly property string currentName: entries.find(entry => entry.id === core.paletteData?.effective)?.name ?? "Amoled Black"
    signal closeRequested()
    spacing: Design.baseline * 2

    function load(): void {
        core.request("palette.list", {}, (ok, result) => {
            if (!ok) { root.error = result.message; return; }
            root.entries = result;
            root.error = "";
            list.currentIndex = root.filtered.findIndex(entry => entry.id === core.paletteData?.name);
            list.positionViewAtIndex(Math.max(0, list.currentIndex), ListView.Contain);
            if (root.active) list.forceActiveFocus();
        });
    }
    function send(op: string, name: string): void {
        core.request(op, name ? {name} : {}, (ok, result) => { root.error = ok ? "" : result.message; });
    }
    function previewIndex(index: int): void {
        if (index < 0 || index >= filtered.length) return;
        list.currentIndex = index;
        list.positionViewAtIndex(index, ListView.Contain);
        preview(filtered[index].id);
    }
    function moveSelection(direction: int): void {
        list.forceActiveFocus();
        previewIndex(Math.max(0, Math.min(filtered.length - 1, list.currentIndex + direction)));
    }
    function chooseCurrent(): void {
        if (list.currentIndex >= 0 && list.currentIndex < filtered.length) choose(filtered[list.currentIndex].id);
    }
    function preview(name: string): void { if (active) send("palette.preview", name); }
    function choose(name: string): void { if (active) send("palette.choose", name); }
    function cancel(): void { send("palette.cancel", ""); }
    onActiveChanged: { if (active) load(); else cancel(); }
    Component.onDestruction: if (active) cancel()
    Connections {
        target: root.core
        function onConnectedChanged() { if (root.active && root.core.connected) root.load(); }
    }
    FText {
        Layout.fillWidth: true
        text: (root.core.paletteData?.preview ? "Preview · " : "Saved · ") + root.currentName
        headline: true
        font.pixelSize: Design.figure
        elide: Text.ElideRight
    }
    TextField {
        id: search
        Layout.fillWidth: true
        implicitHeight: Design.minHit + Design.baseline * 2
        placeholderText: "Find a palette…"
        color: Design.ink
        placeholderTextColor: Design.muted
        selectionColor: Design.accent
        selectedTextColor: Design.background
        font.family: Design.sans
        font.pixelSize: Design.body
        onTextChanged: root.query = text
        background: Rectangle { color: Design.background; border.color: Design.line; border.width: 1 }
        Keys.onDownPressed: { list.forceActiveFocus(); root.previewIndex(Math.max(0, list.currentIndex)); }
        Keys.onEscapePressed: root.closeRequested()
    }
    ListView {
        id: list
        objectName: "paletteList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: root.filtered
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: Design.baseline
        ScrollBar.vertical: ScrollBar {}
        Keys.onDownPressed: root.moveSelection(1)
        Keys.onUpPressed: root.moveSelection(-1)
        Keys.onReturnPressed: root.chooseCurrent()
        Keys.onEnterPressed: root.chooseCurrent()
        Keys.onEscapePressed: root.closeRequested()
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: ListView.view.width
            height: Design.minHit + Design.baseline * 3
            hoverEnabled: true
            Accessible.name: modelData.name + ", " + modelData.source
            onHoveredChanged: if (hovered && root.active) {
                root.previewIndex(index);
            }
            onClicked: root.choose(modelData.id)
            background: Rectangle {
                color: Design.surface
                border.width: 1
                border.color: list.currentIndex === index ? Design.accent : Design.line
            }
            contentItem: RowLayout {
                spacing: Design.baseline * 2
                Rectangle { width: Design.body; height: width; color: modelData.accent }
                FText { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                FText { text: modelData.study ? "STUDY" : modelData.source; technical: true; color: Design.muted }
                FText { text: root.core.paletteData?.name === modelData.id ? "●" : ""; color: Design.accent }
            }
        }
    }
    FText {
        Layout.fillWidth: true
        text: root.error || "Hover or ↑ ↓ previews · click or Enter saves"
        color: root.error ? Design.danger : Design.muted
        font.pixelSize: Design.caption
        wrapMode: Text.Wrap
    }
    RowLayout {
        FButton {
            label: "Use palette"
            Layout.fillWidth: true
            enabled: list.currentIndex >= 0
            onClicked: root.chooseCurrent()
        }
        FButton { label: "Undo preview"; enabled: root.core.paletteData?.preview ?? false; onClicked: root.cancel() }
    }
}
