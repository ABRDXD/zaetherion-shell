import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.core.client
import qs.view.ui

// The wallpaper section of FART's settings (Z177). Hover or arrows show a wallpaper in the large plane; the desktop
// changes only on click or Enter, through the host (the core's wallpaper.choose). Nothing to undo on close.
// Thumbnails decode small and only for tiles in view; they are dropped when the section closes.
ColumnLayout {
    id: root
    required property CoreClient core
    property bool active: false
    property var listing: ({ folder: "", exists: true, entries: [] })
    property string query: ""
    property string error: ""
    property string highlighted: ""
    readonly property var wall: core.wallpaperData ?? ({})
    readonly property var filtered: (listing.entries ?? []).filter(entry => entry.file.toLowerCase().includes(query.toLowerCase()))
    readonly property var shown: filtered.find(entry => entry.path === highlighted) ?? filtered.find(entry => entry.path === wall.current) ?? null
    readonly property bool canApply: wall.available === true && wall.perScreen !== true
    readonly property string blocked: wall.available !== true ? (wall.error || "The desktop can't set wallpapers right now")
        : wall.perScreen === true ? "Your desktop keeps one wallpaper per screen; FART sets one for all" : ""
    signal closeRequested()
    spacing: Design.baseline * 2

    function url(path: string): string { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }
    function name(path: string): string { return path.substring(path.lastIndexOf("/") + 1); }
    function load(): void {
        core.request("wallpaper.list", {}, (ok, result) => {
            if (!ok) { root.error = result.message; return; }
            root.listing = result;
            root.error = "";
            grid.currentIndex = root.filtered.findIndex(entry => entry.path === root.wall.current);
            grid.positionViewAtIndex(Math.max(0, grid.currentIndex), GridView.Contain);
            root.highlighted = "";
            if (root.active && root.filtered.length) grid.forceActiveFocus();
            else if (root.active) search.forceActiveFocus();
        });
    }
    function send(op: string, args: var): void {
        core.request(op, args, (ok, result) => { root.error = ok ? "" : result.message; });
    }
    function previewIndex(index: int): void {
        if (!active || index < 0 || index >= filtered.length) return;
        grid.currentIndex = index;
        highlighted = filtered[index].path;
        send("wallpaper.preview", { name: highlighted });
    }
    function applyCurrent(): void {
        if (!active || grid.currentIndex < 0 || grid.currentIndex >= filtered.length) return;
        if (!canApply) { error = blocked; return; }
        const path = filtered[grid.currentIndex].path;
        core.request("wallpaper.choose", { name: path }, (ok, result) => {
            root.error = ok ? "" : result.message;
            if (ok) root.highlighted = "";
            else root.load();  // the file may have gone
        });
    }
    function cancel(): void { highlighted = ""; send("wallpaper.cancel", {}); }
    onActiveChanged: {
        if (active) { load(); return; }
        cancel();
        listing = ({ folder: listing.folder, exists: listing.exists, entries: [] });  // drop the thumbnails
        query = "";
        search.text = "";
    }
    // A preview another client asked for (the CLI, a preset) shows here too; the latest one wins (Z163's rule).
    readonly property string corePreview: wall.preview ?? ""
    onCorePreviewChanged: {
        if (!active || !corePreview || corePreview === highlighted) return;
        const index = filtered.findIndex(entry => entry.path === corePreview);
        if (index < 0) return;
        highlighted = corePreview;
        grid.currentIndex = index;
        grid.positionViewAtIndex(index, GridView.Contain);
    }
    Component.onDestruction: if (active) cancel()
    Connections {
        target: root.core
        function onConnectedChanged() { if (root.active && root.core.connected) root.load(); }
    }

    FText { text: "WALLPAPER"; technical: true; color: Design.accent }
    FText {
        Layout.fillWidth: true
        text: root.highlighted && root.highlighted !== root.wall.current ? "Preview · " + root.name(root.highlighted)
            : root.wall.current ? "On the desktop · " + root.name(root.wall.current) : "On the desktop · no image"
        elide: Text.ElideMiddle
    }
    TextField {
        id: search
        objectName: "wallpaperSearch"
        Layout.fillWidth: true
        visible: root.listing.exists && (root.listing.entries ?? []).length > 0
        implicitHeight: Design.minHit + Design.baseline * 2
        placeholderText: "Find a wallpaper…"
        color: Design.ink
        placeholderTextColor: Design.muted
        selectionColor: Design.accent
        selectedTextColor: Design.background
        font.family: Design.sans
        font.pixelSize: Design.body
        onTextChanged: root.query = text
        background: Rectangle { color: Design.background; border.color: Design.line; border.width: 1 }
        Keys.onDownPressed: { grid.forceActiveFocus(); root.previewIndex(Math.max(0, grid.currentIndex)); }
        Keys.onReturnPressed: { grid.forceActiveFocus(); root.previewIndex(0); }
        Keys.onEscapePressed: { if (text) text = ""; else root.closeRequested(); }
    }

    // No folder, or nothing in it: say so and let the folder be pointed elsewhere, inside FART.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.listing.exists || (root.listing.entries ?? []).length === 0
        spacing: Design.baseline * 2
        FText {
            Layout.fillWidth: true
            text: (root.listing.exists ? "NO WALLPAPERS IN " : "NO FOLDER AT ") + root.listing.folder
            wrapMode: Text.Wrap
        }
        FText { Layout.fillWidth: true; aside: true; text: "Point FART at the folder that holds them."; color: Design.muted }
        TextField {
            id: folderField
            objectName: "wallpaperFolder"
            Layout.fillWidth: true
            implicitHeight: Design.minHit + Design.baseline * 2
            text: root.listing.folder
            color: Design.ink
            selectionColor: Design.accent
            selectedTextColor: Design.background
            font.family: Design.mono
            font.pixelSize: Design.body
            background: Rectangle { color: Design.background; border.color: Design.line; border.width: 1 }
            onAccepted: root.core.request("wallpaper.folder", { folder: text }, (ok, result) => {
                root.error = ok ? "" : result.message;
                if (ok) root.load();
            })
            Keys.onEscapePressed: root.closeRequested()
        }
        Item { Layout.fillHeight: true }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.listing.exists && (root.listing.entries ?? []).length > 0
        spacing: Design.baseline * 3
        GridView {
            id: grid
            objectName: "wallpaperGrid"
            readonly property int columns: 4
            Layout.preferredWidth: cellWidth * columns + Design.baseline * 3
            Layout.fillHeight: true
            cellWidth: 124
            cellHeight: 84
            clip: true
            model: root.filtered
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: -1
            ScrollBar.vertical: ScrollBar {}
            onCurrentIndexChanged: if (activeFocus && currentIndex >= 0 && root.filtered[currentIndex]?.path !== root.highlighted) root.previewIndex(currentIndex)
            Keys.onReturnPressed: root.applyCurrent()
            Keys.onEnterPressed: root.applyCurrent()
            Keys.onEscapePressed: { if (search.text) search.text = ""; else root.closeRequested(); }
            // Typing goes to the filter, as anywhere else in FART types into a field.
            Keys.onPressed: event => {
                if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                    search.forceActiveFocus();
                    search.insert(search.cursorPosition, event.text);
                    event.accepted = true;
                }
            }
            delegate: ItemDelegate {
                id: tile
                required property var modelData
                required property int index
                width: grid.cellWidth - Design.baseline * 2
                height: grid.cellHeight - Design.baseline * 2
                hoverEnabled: true
                padding: 0
                Accessible.name: modelData.file
                onHoveredChanged: if (hovered && root.active) root.previewIndex(index)
                onClicked: { grid.currentIndex = index; root.applyCurrent(); }
                background: Rectangle {
                    color: Design.surface
                    border.width: grid.currentIndex === tile.index ? 2 : 1
                    border.color: grid.currentIndex === tile.index ? Design.accent : Design.line
                }
                contentItem: Item {
                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: tile.modelData.kind === "image" && status === Image.Ready
                        source: tile.modelData.kind === "image" ? root.url(tile.modelData.path) : ""
                        sourceSize: Qt.size(240, 160)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                    FText {
                        anchors.centerIn: parent
                        visible: !thumb.visible
                        text: tile.modelData.kind === "video" ? "VIDEO" : thumb.status === Image.Error ? "UNREADABLE" : ""
                        technical: true
                        color: Design.muted
                    }
                    FText {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Design.baseline
                        text: root.wall.current === tile.modelData.path ? "●" : ""
                        color: Design.accent
                    }
                }
            }
        }
        // The large plane: what the highlighted wallpaper would look like, under FART's own palette.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Design.baseline
            // The screen's shape, so the crop is the one the desktop will show.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16
                Layout.maximumHeight: width * 9 / 16
                color: Design.background
                border.width: 1
                border.color: Design.line
                clip: true
                Image {
                    id: large
                    objectName: "wallpaperPreview"
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: root.shown?.kind === "image"
                    source: root.shown?.kind === "image" ? root.url(root.shown.path) : ""
                    sourceSize: Qt.size(1280, 720)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                FText {
                    anchors.centerIn: parent
                    visible: !large.visible || large.status !== Image.Ready
                    text: root.shown?.kind === "video" ? "VIDEO · NO PREVIEW" : large.status === Image.Loading ? "LOADING" : !root.shown ? "NOTHING SHOWN" : "UNREADABLE"
                    technical: true
                    color: Design.muted
                }
            }
            FText {
                Layout.fillWidth: true
                text: root.shown ? root.shown.file + " · " + (root.shown.size / 1048576).toFixed(1) + " MB" : ""
                technical: true
                color: Design.muted
                elide: Text.ElideMiddle
            }
            // Z179: off by default. On, the highlighted image also previews a palette made from it; setting saves both.
            FButton {
                objectName: "wallpaperColours"
                Layout.fillWidth: true
                label: root.wall.colours === true ? "Colours from this wallpaper: on" : "Colours from this wallpaper: off"
                selected: root.wall.colours === true
                onClicked: root.send("wallpaper.colours", { on: root.wall.colours !== true })
            }
            FText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.wall.coloursError ? "No colours: " + root.wall.coloursError
                    : root.wall.colours === true && root.shown?.kind === "video" ? "Videos keep the current colours" : ""
                color: root.wall.coloursError ? Design.danger : Design.muted
                font.pixelSize: Design.caption
                wrapMode: Text.Wrap
            }
            Item { Layout.fillHeight: true }
        }
    }
    FText {
        Layout.fillWidth: true
        visible: root.error !== "" || (root.listing.entries ?? []).length > 0
        text: root.error || root.blocked || "Hover or arrows preview · click or Enter sets it · typing filters"
        color: root.error ? Design.danger : Design.muted
        font.pixelSize: Design.caption
        wrapMode: Text.Wrap
    }
    RowLayout {
        visible: (root.listing.entries ?? []).length > 0
        FButton {
            objectName: "wallpaperApply"
            label: "Set as wallpaper"
            Layout.fillWidth: true
            enabled: root.canApply && grid.currentIndex >= 0 && root.filtered[grid.currentIndex]?.path !== root.wall.current
            onClicked: root.applyCurrent()
        }
        FButton { label: "Back to current"; enabled: root.highlighted !== ""; onClicked: { root.cancel(); root.load(); } }
    }
}
