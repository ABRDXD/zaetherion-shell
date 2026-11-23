import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.core.client
import qs.view.fluid
import qs.view.ui

// The presets section of FART's settings (Z180). A look is a wallpaper, a palette, the island's form and the
// desktop's own theme. Hover or arrows preview the palette and the island live (the core's presets.preview) and
// show the wallpaper here; the desktop changes only on click or Enter. Closing, folding or Esc restores.
ColumnLayout {
    id: root
    required property CoreClient core
    property bool active: false
    property string error: ""
    property string notice: ""
    readonly property var presets: core.presetsData ?? ({ looks: [], preview: null })
    readonly property var looks: presets.looks ?? []
    readonly property var shown: list.currentIndex >= 0 && list.currentIndex < looks.length ? looks[list.currentIndex] : null
    readonly property var parts: ({ palette: "palette", islandForm: "island", wallpaper: "wallpaper", hostTheme: "desktop theme" })
    signal closeRequested()
    spacing: Design.baseline * 2

    function url(path: string): string { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""; }
    function fileName(path: string): string { return path.substring(path.lastIndexOf("/") + 1); }
    function send(op: string, args: var, done: var): void {
        core.request(op, args, (ok, result) => {
            root.error = ok ? "" : result.message;
            if (ok && done) done(result);
        });
    }
    function previewIndex(index: int): void {
        if (!active || index < 0 || index >= looks.length) return;
        list.currentIndex = index;
        if (presets.preview !== looks[index].name) send("presets.preview", { name: looks[index].name });
    }
    function applyCurrent(): void {
        if (!active || !shown) return;
        send("presets.apply", { name: shown.name }, result => {
            root.notice = result.skipped.length ? "Skipped " + result.skipped.map(p => root.parts[p]).join(", ") : "";
        });
    }
    function cancel(): void { send("presets.cancel", {}); }
    // Z210: a blank name still saves, as the first free "Look N", so the button never looks dead.
    function freeName(): string {
        const taken = looks.map(look => look.name.toLowerCase());
        let n = 1;
        while (taken.includes("look " + n)) n++;
        return "Look " + n;
    }
    function save(): void {
        const name = nameField.text.trim() || freeName();
        send("presets.save", { name: name }, () => { nameField.text = ""; root.notice = "Saved " + name; });
    }
    onActiveChanged: {
        notice = "";
        if (active) {
            list.currentIndex = -1;
            if (looks.length) list.forceActiveFocus(); else nameField.forceActiveFocus();
        } else {
            cancel();
        }
    }
    // A preview another client started (look <name> previews nothing, but a second view or a test may) shows here too.
    readonly property string corePreview: presets.preview ?? ""
    onCorePreviewChanged: {
        const index = looks.findIndex(look => look.name === corePreview);
        if (active && index >= 0 && index !== list.currentIndex) list.currentIndex = index;
    }
    Component.onDestruction: if (active) cancel()

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.baseline * 2
        TextField {
            id: nameField
            objectName: "presetName"
            Layout.fillWidth: true
            implicitHeight: Design.minHit + Design.baseline * 2
            placeholderText: "Name the look you have now (or leave blank)…"
            maximumLength: 48
            color: Design.ink
            placeholderTextColor: Design.muted
            selectionColor: Design.accent
            selectedTextColor: Design.background
            font.family: Design.fluid ? FluidTokens.sans : Design.sans
            font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
            background: Rectangle { radius: Design.fluid ? FluidTokens.controlRadius : 0; color: Design.background; border.color: Design.line; border.width: 1 }
            onAccepted: if (text.trim() !== "") root.save()
            Keys.onDownPressed: { list.forceActiveFocus(); root.previewIndex(Math.max(0, list.currentIndex)); }
            Keys.onEscapePressed: { if (text) text = ""; else root.closeRequested(); }
        }
        SettingsButton {
            id: saveButton
            objectName: "presetSave"
            label: "Save current look"
            onClicked: root.save()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Design.baseline * 3
        ListView {
            id: list
            objectName: "presetList"
            Layout.preferredWidth: 460
            Layout.fillHeight: true
            clip: true
            model: root.looks
            currentIndex: -1
            spacing: Design.baseline
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            Keys.onDownPressed: root.previewIndex(Math.min(root.looks.length - 1, currentIndex + 1))
            Keys.onUpPressed: { if (currentIndex <= 0) nameField.forceActiveFocus(); else root.previewIndex(currentIndex - 1); }
            Keys.onReturnPressed: root.applyCurrent()
            Keys.onEnterPressed: root.applyCurrent()
            Keys.onDeletePressed: if (root.shown) root.send("presets.delete", { name: root.shown.name })
            Keys.onEscapePressed: root.closeRequested()
            SettingsText {
                anchors.centerIn: parent
                visible: root.looks.length === 0
                width: parent.width - Design.baseline * 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                aside: true
                color: Design.muted
                text: "No saved looks yet. Set a wallpaper and a palette, then name the look above."
            }
            delegate: ItemDelegate {
                id: card
                required property var modelData
                required property int index
                width: ListView.view.width - Design.baseline * 3
                height: 72
                hoverEnabled: true
                padding: Design.baseline * 2
                Accessible.name: modelData.name
                onHoveredChanged: if (hovered) root.previewIndex(index)
                onClicked: { root.previewIndex(index); root.applyCurrent(); }
                background: Rectangle {
                    radius: Design.fluid ? FluidTokens.controlRadius : 0
                    color: Design.surface
                    border.width: list.currentIndex === card.index ? 2 : 1
                    border.color: list.currentIndex === card.index ? Design.accent : Design.line
                }
                contentItem: RowLayout {
                    spacing: Design.baseline * 3
                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 54
                        color: Design.background
                        border.width: 1
                        border.color: Design.line
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: card.modelData.missing.includes("wallpaper") ? "" : root.url(card.modelData.wallpaper)
                            sourceSize: Qt.size(192, 108)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        SettingsText {
                            anchors.centerIn: parent
                            visible: !card.modelData.wallpaper || card.modelData.missing.includes("wallpaper")
                            text: card.modelData.wallpaper ? "MISSING" : "KEEP"
                            technical: true
                            color: Design.muted
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Design.baseline
                        SettingsText { Layout.fillWidth: true; text: card.modelData.name; elide: Text.ElideRight }
                        RowLayout {
                            spacing: Design.baseline
                            Repeater {
                                model: card.modelData.swatch
                                Rectangle {
                                    required property var modelData
                                    width: Design.body; height: width
                                    color: modelData
                                    border.width: 1
                                    border.color: Design.line
                                }
                            }
                            SettingsText {
                                Layout.fillWidth: true
                                text: [card.modelData.paletteName, card.modelData.islandForm.toUpperCase(), card.modelData.hostTheme]
                                    .filter(t => t).join(" · ")
                                technical: true
                                color: Design.muted
                                elide: Text.ElideRight
                            }
                        }
                        SettingsText {
                            visible: card.modelData.missing.length > 0
                            text: "MISSING · " + card.modelData.missing.map(p => root.parts[p]).join(", ").toUpperCase()
                            technical: true
                            color: Design.danger
                        }
                    }
                    SettingsButton {
                        symbol: "delete"
                        hint: "Delete this look"
                        Layout.preferredHeight: Design.minHit
                        onClicked: root.send("presets.delete", { name: card.modelData.name })
                    }
                }
            }
        }
        // The highlighted look's wallpaper, in the screen's shape; the palette and island already show it live.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Design.baseline
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
                    objectName: "presetPreview"
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.shown && !root.shown.missing.includes("wallpaper") ? root.url(root.shown.wallpaper) : ""
                    sourceSize: Qt.size(1280, 720)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                SettingsText {
                    anchors.centerIn: parent
                    visible: large.status !== Image.Ready
                    text: !root.shown ? "HOVER A LOOK TO PREVIEW IT" : !root.shown.wallpaper ? "KEEPS THE CURRENT WALLPAPER" : "WALLPAPER MISSING"
                    technical: true
                    color: Design.muted
                }
            }
            SettingsText {
                Layout.fillWidth: true
                visible: root.shown !== null
                text: root.shown ? (root.shown.wallpaper ? root.fileName(root.shown.wallpaper) : "current wallpaper") : ""
                technical: true
                color: Design.muted
                elide: Text.ElideMiddle
            }
            Item { Layout.fillHeight: true }
        }
    }
    SettingsText {
        Layout.fillWidth: true
        text: root.error || root.notice || "Hover or ↑ ↓ previews · click or Enter uses the look · Delete removes it"
        color: root.error ? Design.danger : Design.muted
        font.pixelSize: Design.fluid ? FluidTokens.caption : Design.caption
        wrapMode: Text.Wrap
    }
    RowLayout {
        visible: root.looks.length > 0
        SettingsButton {
            objectName: "presetApply"
            label: "Use this look"
            Layout.fillWidth: true
            enabled: root.shown !== null
            onClicked: root.applyCurrent()
        }
        SettingsButton { label: "Undo preview"; enabled: root.presets.preview !== null && root.presets.preview !== undefined; onClicked: { root.cancel(); list.currentIndex = -1; } }
    }
}
