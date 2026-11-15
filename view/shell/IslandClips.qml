import QtQuick
import QtQuick.Controls
import qs.view.contract
import qs.view.rooms
import qs.view.ui
import "../rooms/ClipKinds.js" as ClipKinds

// Quick paste (S3, Super+V): the clipboard history grown out of the island, keyboard first. The field holds the
// keyboard from the first frame, so whatever is typed while the history is still being read is kept and filters it
// once it lands; an Enter pressed before then is held and acts on the first match (`pendingEnter`).
// Keys follow DMS's clipboard (Z161): Enter and Shift+Enter (paste / copy, which one is a setting), Ctrl+S pin,
// Delete removes, Ctrl+Tab the filter, Up/Down, Tab/Shift+Tab, Ctrl+J/K, Ctrl+N/P move; ours: Ctrl+O the Clips
// room with the query, Esc folds. Contents are drawn only here and in the room (DESIGN_SYSTEM §9).
FocusScope {
    id: root
    required property ClipboardDomain clipboard
    property bool systemVoice: true
    // Settings (Z176, FART's Clips tab).
    property int rows: 6
    // Owner, 14 November: Enter copies, Shift+Enter pastes.
    property bool enterPastes: false
    property bool showImages: true
    signal paste(string id)
    signal copy(string id)
    signal openRoom(string query)
    signal dismiss()

    HostLease { domain: root.clipboard; feature: "history" }
    ClipPins { id: pins; clipboard: root.clipboard }

    property string filter: "all"
    readonly property var filters: ["all", "pinned", "images"]
    readonly property string query: field.text.trim().toLowerCase()
    readonly property var entries: clipboard?.entries ?? []
    readonly property bool loaded: clipboard?.loaded ?? false
    readonly property var matches: entries.filter(entry => {
        if (filter === "pinned" && !pins.isPinned(entry)) return false;
        if (filter === "images" && !entry.isImage) return false;
        if (!showImages && entry.isImage && filter !== "images") return false;
        return query === "" || entry.text.toLowerCase().includes(query);
    })
    property int current: 0
    onMatchesChanged: current = Math.max(0, Math.min(current, matches.length - 1))
    // The adapter fills the list, then says it is loaded: the held Enter acts on that second step.
    onLoadedChanged: if (loaded && pendingEnter) act(pendingShift)
    onQueryChanged: current = 0
    property bool pendingEnter: false
    property bool pendingShift: false

    readonly property int rowHeight: 30
    // An image row is two text rows tall, so the list always ends on a whole row.
    readonly property int imageRowHeight: 2 * rowHeight
    readonly property int listHeight: rows * rowHeight
    implicitWidth: 600
    implicitHeight: header.height + Design.baseline + listHeight + Design.baseline + hints.height

    function voice(line: string): string {
        if (systemVoice) return line;
        const clean = line.replace(/^>\s*/, "").replace(/ · /g, " — ").toLowerCase();
        return clean.charAt(0).toUpperCase() + clean.slice(1);
    }
    function move(step: int): void {
        if (matches.length === 0) return;
        current = (current + step + matches.length) % matches.length;
        list.positionViewAtIndex(current, ListView.Contain);
    }
    function act(shifted: bool): void {
        if (!loaded) {
            pendingEnter = true;
            pendingShift = shifted;
            return;
        }
        pendingEnter = false;
        const entry = matches[current];
        if (!entry) return;
        if (enterPastes !== shifted) paste(entry.id);
        else copy(entry.id);
    }

    Component.onCompleted: field.forceActiveFocus()
    // Tests and captures type through this, as the keyboard would.
    function typeText(text: string): void { field.insert(field.cursorPosition, text); }
    function pressKey(key: int, modifiers: int): bool { return handleKey(key, modifiers, ""); }
    function handleKey(key: int, modifiers: int, text: string): bool {
        const ctrl = (modifiers & Qt.ControlModifier) !== 0;
        const shift = (modifiers & Qt.ShiftModifier) !== 0;
        const current = matches[root.current];
        // Super+V again closes (owner, 15 November 2026). While quick paste holds the keyboard, Hyprland hands the
        // keys to it instead of running the `zaetherion:clips` bind, so the face answers it itself.
        if (key === Qt.Key_V && (modifiers & Qt.MetaModifier) !== 0) dismiss();
        else if (key === Qt.Key_Escape) dismiss();
        else if (key === Qt.Key_Down || (key === Qt.Key_Tab && !ctrl) || (ctrl && (key === Qt.Key_J || key === Qt.Key_N))) move(1);
        else if (key === Qt.Key_Up || (key === Qt.Key_Backtab && !ctrl) || (ctrl && (key === Qt.Key_K || key === Qt.Key_P))) move(-1);
        else if (ctrl && (key === Qt.Key_Tab || key === Qt.Key_Backtab)) {
            const step = key === Qt.Key_Backtab ? -1 : 1;
            filter = filters[(filters.indexOf(filter) + step + filters.length) % filters.length];
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            if (ctrl) openRoom(field.text);
            else act(shift);
        } else if (ctrl && key === Qt.Key_S) {
            if (current) pins.toggle(current);
        } else if (ctrl && key === Qt.Key_O) openRoom(field.text);
        // Delete removes the chosen clip only when the field has nothing after its cursor to delete.
        else if (key === Qt.Key_Delete && !shift && field.cursorPosition === field.length) {
            if (current) clipboard.remove(current.id);
        } else return false;
        return true;
    }
    // The field and the filter: the field is the island's command-line voice, the filters ink tags.
    Item {
        id: header
        width: parent.width
        height: Design.minHit + Design.baseline
        MaterialSymbol {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: "content_paste"
            iconSize: Design.readout
            fill: Design.iconFill
            weight: Design.iconWeight
            color: Design.accent
        }
        TextField {
            id: field
            anchors.left: glyph.right
            anchors.leftMargin: 2 * Design.baseline
            anchors.right: tags.left
            anchors.rightMargin: 2 * Design.baseline
            anchors.verticalCenter: parent.verticalCenter
            padding: 0
            color: Design.ink
            placeholderText: root.voice("> PASTE · TYPE TO FILTER")
            placeholderTextColor: Design.muted
            font.family: Design.mono
            font.pixelSize: Design.control
            selectionColor: Design.accent
            selectedTextColor: Design.background
            // Ahead of the field's own handling, so Enter, Tab and the arrows act on the list.
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => event.accepted = root.handleKey(event.key, event.modifiers, event.text)
            background: Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -Design.baseline
                width: parent.width
                height: 1
                color: field.activeFocus ? Design.accent : Design.line
            }
        }
        Row {
            id: tags
            anchors.right: count.left
            anchors.rightMargin: 3 * Design.baseline
            anchors.verticalCenter: parent.verticalCenter
            spacing: Design.baseline
            Repeater {
                model: root.filters
                FPlate {
                    required property string modelData
                    role: root.filter === modelData ? "ink" : "clear"
                    width: tagText.implicitWidth + 3 * Design.baseline
                    height: Design.readout
                    FText {
                        id: tagText
                        anchors.centerIn: parent
                        technical: true
                        text: root.voice(modelData.toUpperCase())
                        color: root.filter === modelData ? parent.textColor : Design.muted
                    }
                    TapHandler { onTapped: root.filter = modelData }
                }
            }
        }
        FText {
            id: count
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            technical: true
            color: Design.faint
            text: root.loaded ? root.matches.length + "/" + root.entries.length : root.voice("> READING")
        }
    }

    ListView {
        id: list
        y: header.height + Design.baseline
        width: parent.width
        height: root.listHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        model: root.matches
        currentIndex: root.current
        reuseItems: true
        delegate: AbstractButton {
            id: row
            required property var modelData
            required property int index
            readonly property bool chosen: index === root.current
            readonly property string kind: ClipKinds.kind(modelData)
            readonly property bool pinned: pins.isPinned(modelData)
            readonly property bool picture: modelData.isImage && root.showImages
            width: ListView.view.width
            height: picture ? root.imageRowHeight : root.rowHeight
            // The kind marks are curve-rendered shapes, which ignore the list's clip (DESIGN_SYSTEM §3): rows past
            // the list's edge are hidden instead.
            visible: y + height > ListView.view.contentY && y < ListView.view.contentY + ListView.view.height
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            // A picture is decoded only once its row is built, so only the rows on screen cost anything (Z79).
            onPictureChanged: if (picture) root.clipboard?.requestThumbnail(modelData.id)
            Component.onCompleted: if (picture) root.clipboard?.requestThumbnail(modelData.id)
            onHoveredChanged: if (hovered) root.current = index
            onClicked: { root.current = index; root.act(false); }
            background: Item {
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Design.line, 0.5)
                }
                Wipe { id: wipe; anchors.fill: parent; scope: row; on: row.chosen }
            }
            contentItem: Item {
                FText {
                    id: number
                    width: 14 * Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    technical: true
                    text: row.kind
                    color: wipe.inverted ? wipe.ink : Design.faint
                }
                KindMark {
                    id: mark
                    x: number.width
                    anchors.verticalCenter: parent.verticalCenter
                    kind: row.kind
                    swatch: ClipKinds.colour(row.modelData)
                    ink: wipe.inverted ? wipe.ink : Design.faint
                }
                Image {
                    id: thumb
                    visible: row.picture
                    x: mark.x + mark.width + 3 * Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.imageRowHeight - 2 * Design.baseline
                    width: height * 16 / 9
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    source: row.picture ? (root.clipboard.thumbnails?.[row.modelData.id] ?? "") : ""
                    sourceSize.width: width
                    sourceSize.height: height
                }
                FText {
                    x: row.picture ? thumb.x + thumb.width + 3 * Design.baseline : mark.x + mark.width + 3 * Design.baseline
                    width: pin.x - x - 2 * Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    font.capitalization: Font.MixedCase
                    font.pixelSize: Design.body
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: row.modelData.isImage ? row.modelData.text.replace(/^\[\[\s*binary data\s*/, "").replace(/\s*\]\]$/, "").toUpperCase()
                                                : row.modelData.text.replace(/\s+/g, " ")
                    color: wipe.inverted ? wipe.ink : row.modelData.isImage ? Design.muted : Design.ink
                }
                MaterialSymbol {
                    id: pin
                    anchors.right: parent.right
                    anchors.rightMargin: Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    width: Design.control
                    text: "keep"
                    iconSize: Design.control
                    fill: 1
                    visible: row.pinned
                    color: wipe.inverted ? wipe.ink : Design.accent
                }
            }
        }
        FText {
            anchors.centerIn: parent
            visible: root.loaded && root.matches.length === 0
            technical: true
            color: Design.muted
            text: root.voice(root.query ? "> NO MATCH · CTRL+O SEARCHES CLIPS" : root.filter === "pinned" ? "> NO PINS" : "> HISTORY EMPTY")
        }
    }

    FText {
        id: hints
        y: list.y + list.height + Design.baseline
        width: root.implicitWidth - 30 * Design.baseline
        technical: true
        font.pixelSize: Design.caption
        color: Design.faint
        elide: Text.ElideRight
        text: root.voice((root.enterPastes ? "ENTER PASTES · SHIFT+ENTER COPIES" : "ENTER COPIES · SHIFT+ENTER PASTES")
            + " · CTRL+S PIN · DEL")
    }
    FText {
        anchors.right: parent.right
        y: hints.y
        technical: true
        font.pixelSize: Design.caption
        color: Design.muted
        text: root.voice("CTRL+O CLIPS ROOM ›")
    }
}
