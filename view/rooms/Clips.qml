import qs.view.contract
import qs.view.shell
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "ClipKinds.js" as ClipKinds

ColumnLayout {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    readonly property var clipboard: host.clipboard
    HostLease { domain: root.clipboard; feature: "history" }
    ClipPins { id: pins; clipboard: root.clipboard }
    readonly property bool editing: query.activeFocus
    property string search: ViewState.clipQuery
    property string copied: ""
    property int limit: 100
    readonly property var matches: clipboard.entries.filter(e => {
        if (ViewState.clipFilter === "pinned" && !pins.isPinned(e))
            return false;
        if (ViewState.clipFilter === "images" && !e.isImage)
            return false;
        return e.text.toLowerCase().includes(search.toLowerCase());
    })
    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            root.search = query.text;
            root.limit = 100;
        }
    }
    Timer {
        id: copiedTimer
        interval: 1400
        onTriggered: root.copied = ""
    }
    spacing: 14
    RowLayout {
        Layout.fillWidth: true
        FField {
            id: query
            Layout.fillWidth: true
            text: ViewState.clipQuery
            placeholderText: "SEARCH ARCHIVE"
            onTextEdited: {
                ViewState.clipQuery = text;
                debounce.restart();
            }
        }
        Repeater {
            model: ["all", "pinned", "images"]
            FButton {
                required property string modelData
                label: modelData === "all" ? "All" : modelData === "pinned" ? "Pinned" : "Images"
                selected: ViewState.clipFilter === modelData
                onClicked: ViewState.clipFilter = modelData
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        FText {
            text: "REF"
            technical: true
            color: Design.faint
            Layout.preferredWidth: 70
        }
        FText {
            text: "EXCERPT"
            technical: true
            color: Design.faint
            Layout.fillWidth: true
        }
        FText {
            text: root.matches.length + " RECORDS"
            technical: true
            color: Design.faint
        }
    }
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        reuseItems: true
        model: root.matches.slice(0, root.limit)
        ScrollBar.vertical: ScrollBar {}
        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 82
            Rectangle {
                anchors.fill: parent
                color: root.copied === entry.modelData.id ? Design.hover : "transparent"
            }
            FRule {
                anchors.bottom: parent.bottom
                width: parent.width
            }
            RowLayout {
                anchors.fill: parent
                spacing: 14
                ColumnLayout {
                    Layout.preferredWidth: 66
                    spacing: 4
                    FText {
                        text: entry.modelData.id
                        technical: true
                        color: Design.muted
                        font.pixelSize: Design.caption
                    }
                    // Its kind, and the kind's mark (MIME taxonomy, atlas #31).
                    FText {
                        text: ClipKinds.kind(entry.modelData)
                        technical: true
                        color: Design.faint
                        font.pixelSize: Design.caption
                    }
                    KindMark {
                        kind: ClipKinds.kind(entry.modelData)
                        swatch: ClipKinds.colour(entry.modelData)
                    }
                }
                FText {
                    id: preview
                    Layout.fillWidth: true
                    text: entry.modelData.isImage ? entry.modelData.text : entry.modelData.text.slice(0, 450)
                    font.pixelSize: Design.body
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    // Overdrive: set as the photocopy generation its place in the history makes it (§49).
                    Stratum {
                        anchors.fill: parent
                        z: -1
                        name: "clips.copy." + entry.index
                        gpu: false
                        scope: entry
                        wanted: entry.index > 0
                        sourceComponent: PhotocopyLayer { target: preview; index: entry.index; seed: String(entry.modelData.id) }
                    }
                }
                FButton {
                    symbol: pins.isPinned(entry.modelData) ? "keep_off" : "keep"
                    selected: pins.isPinned(entry.modelData)
                    hint: "Pin / unpin"
                    onClicked: pins.toggle(entry.modelData)
                }
                FButton {
                    symbol: root.copied === entry.modelData.id ? "check" : "content_copy"
                    hint: "Copy"
                    onClicked: {
                        root.clipboard.copy(entry.modelData.id);
                        root.copied = entry.modelData.id;
                        copiedTimer.restart();
                    }
                }
                FButton {
                    symbol: "delete_outline"
                    hint: "Delete entry"
                    onClicked: root.clipboard.remove(entry.modelData.id)
                }
            }
        }
        footer: FButton {
            visible: root.matches.length > root.limit
            width: list.width
            label: "Load another 100 records"
            onClicked: root.limit += 100
        }
        FText {
            anchors.centerIn: parent
            visible: root.matches.length === 0
            text: root.search ? "NO MATCHES" :
                                "ARCHIVE EMPTY"
            color: Design.muted
        }
    }
    // Pins can outlive the host history's own retention limit.
    Repeater {
        model: ViewState.clipFilter === "pinned" ? pins.missing(root.clipboard.entries, root.search).slice(0, 3) : []
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            FText {
                text: modelData.text.slice(0, 120)
                Layout.fillWidth: true
            }
            FButton {
                symbol: "content_copy"
                hint: "Copy saved pin"
                onClicked: root.clipboard.copyText(modelData.content || modelData.text)
            }
            FButton {
                symbol: "keep_off"
                hint: "Remove saved pin"
                onClicked: pins.remove(modelData)
            }
        }
    }
    FText {
        text: root.copied ? "COPIED " + root.copied : "LOCAL ARCHIVE · PINS RETAINED"
        technical: true
        font.pixelSize: Design.caption
        color: Design.faint
    }
}
