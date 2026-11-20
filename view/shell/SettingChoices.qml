import QtQuick
import QtQuick.Layouts
import qs.view.ui

// The core/domain remains authoritative. Opening and dismissing never writes.
ColumnLayout {
    id: root

    property string label: ""
    property string note: ""
    property string unlistedLabel: "—"
    property var options: []
    property var value
    property bool prominent: false
    property bool compact: false
    property bool expanded: false
    // false when the source is gone (offline); an unknown value then reads OFFLINE, otherwise READING (Z219).
    property bool available: true
    readonly property bool unknown: value === undefined || value === null && !options.some(o => o[0] === null)
    readonly property string key: label.toLowerCase().replace(/[^a-z0-9]+/g, "-")
    property string choiceNamePrefix: "choice-" + key + "-"
    readonly property int currentIndex: options.findIndex(option => {
        return option[0] === value;
    })
    readonly property string currentLabel: currentIndex >= 0 ? String(options[currentIndex][1]) : unlistedLabel

    signal picked(var value)

    function dismiss() {
        expanded = false;
        if (visible && enabled)
            reading.forceActiveFocus();
    }

    Layout.preferredWidth: 1
    Layout.minimumWidth: 0
    Layout.alignment: Qt.AlignTop
    spacing: Design.baseline
    onVisibleChanged: {
        if (!visible)
            expanded = false;
    }
    onEnabledChanged: {
        if (!enabled)
            expanded = false;
    }
    onValueChanged: expanded = false
    Keys.onEscapePressed: event => {
        if (root.expanded) {
            root.dismiss();
            event.accepted = true;
        } else {
            event.accepted = false;
        }
    }

    FText {
        Layout.fillWidth: true
        text: root.label
        technical: true
        horizontalAlignment: root.compact ? Text.AlignLeft : Text.AlignHCenter
        color: Design.muted
    }

    SettingReadout {
        id: reading

        objectName: "current-" + root.key
        Layout.alignment: root.compact ? Qt.AlignLeft : Qt.AlignHCenter
        Layout.maximumWidth: root.width
        Layout.preferredWidth: Math.min(root.width, implicitWidth)
        label: root.label
        valueLabel: root.currentLabel
        missing: root.unknown ? (root.available ? "READING" : "OFFLINE") : ""
        note: root.note
        prominent: root.prominent
        compact: root.compact
        expanded: root.expanded
        enabled: root.enabled && root.options.length > 0 && !root.unknown
        onClicked: root.expanded = !root.expanded
    }

    FText {
        Layout.fillWidth: true
        visible: root.note !== ""
        text: root.note
        technical: true
        color: Design.muted
        wrapMode: Text.WordWrap
        horizontalAlignment: root.compact ? Text.AlignLeft : Text.AlignHCenter
    }

    Loader {
        id: alternatives

        Layout.fillWidth: true
        active: root.expanded
        visible: active

        sourceComponent: Component {
            Flow {
                width: alternatives.width
                spacing: Design.baseline * 2

                // The current choice takes focus on open; arrows, Home and End move between them (Z219).
                Component.onCompleted: Qt.callLater(() => chips.itemAt(Math.max(0, root.currentIndex))?.forceActiveFocus())
                function step(from, by) {
                    const n = chips.count;
                    chips.itemAt(by === "home" ? 0 : by === "end" ? n - 1 : (from + by + n) % n)?.forceActiveFocus();
                }

                Repeater {
                    id: chips
                    model: root.options

                    SettingChip {
                        required property var modelData
                        required property int index

                        objectName: root.choiceNamePrefix + String(modelData[0])
                        label: modelData[1]
                        width: Math.min(implicitWidth, root.width)
                        selected: root.value === modelData[0]
                        enabled: root.enabled
                        onClicked: {
                            if (root.value !== modelData[0])
                                root.picked(modelData[0]);

                            root.dismiss();
                        }
                        Keys.onLeftPressed: parent.step(index, -1)
                        Keys.onUpPressed: parent.step(index, -1)
                        Keys.onRightPressed: parent.step(index, 1)
                        Keys.onDownPressed: parent.step(index, 1)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Home) { parent.step(index, "home"); event.accepted = true; }
                            else if (event.key === Qt.Key_End) { parent.step(index, "end"); event.accepted = true; }
                        }
                    }
                }
            }
        }
    }
}
