import qs.view.contract
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

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
    readonly property var page: matches.slice(0, limit)
    readonly property var retainedPins: ViewState.clipFilter === "pinned"
        ? pins.missing(clipboard.entries, search).slice(0, 3) : []
    spacing: 10

    GridLayout {
        Layout.fillWidth: true
        columns: root.width < 520 ? 1 : 2
        rowSpacing: 4
        columnSpacing: 16
        FField {
            id: query
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: ViewState.clipQuery
            placeholderText: "Search archive"
            background: Rectangle {
                color: "transparent"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: query.activeFocus ? 2 : 1
                    color: query.activeFocus ? Design.accent : Design.line
                }
            }
            onTextEdited: {
                ViewState.clipQuery = text;
                debounce.restart();
            }
        }
        Row {
            spacing: 4
            Repeater {
                model: ["all", "pinned", "images"]
                SettingChip {
                    required property string modelData
                    label: modelData === "all" ? "All" : modelData === "pinned" ? "Pinned" : "Images"
                    selected: ViewState.clipFilter === modelData
                    onClicked: ViewState.clipFilter = modelData
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        FText {
            readonly property int total: root.matches.length + root.retainedPins.length
            text: total + (total === 1 ? " RECORD" : " RECORDS")
            technical: true
            color: Design.muted
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Design.line }
    }
    GridView {
        id: sheet
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        reuseItems: true
        cellWidth: Math.max(1, Math.floor(width / (width >= 680 ? 2 : 1)))
        cellHeight: 154
        model: root.page.concat(root.retainedPins)
        ScrollBar.vertical: ScrollBar {}
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: sheet.cellWidth
            height: sheet.cellHeight
            ClipPlate {
                anchors.fill: parent
                anchors.rightMargin: 6
                anchors.bottomMargin: 8
                record: cell.modelData
                position: cell.index
                retained: cell.index >= root.page.length
                pinned: retained || pins.isPinned(record)
                copied: root.copied === record.id
                onCopyRequested: {
                    if (retained)
                        root.clipboard.copyText(record.content || record.text);
                    else
                        root.clipboard.copy(record.id);
                    root.copied = record.id;
                    copiedTimer.restart();
                }
                onPinRequested: {
                    if (retained) pins.remove(record);
                    else pins.toggle(record);
                }
                onDeleteRequested: root.clipboard.remove(record.id)
            }
        }
        footer: FButton {
            visible: root.matches.length > root.limit
            width: sheet.width
            height: visible ? implicitHeight : 0
            label: "Load another 100 records"
            onClicked: root.limit += 100
        }
        FText {
            anchors.centerIn: parent
            visible: sheet.count === 0
            text: root.search ? "NO MATCHES" : "ARCHIVE EMPTY"
            color: Design.muted
        }
    }
    FText {
        text: root.copied ? "COPIED " + root.copied : "LOCAL ARCHIVE · PINS RETAINED"
        technical: true
        color: Design.faint
    }
}
