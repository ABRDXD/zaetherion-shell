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
        note: root.note
        prominent: root.prominent
        compact: root.compact
        expanded: root.expanded
        enabled: root.enabled && root.options.length > 0
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

                Repeater {
                    model: root.options

                    FButton {
                        required property var modelData

                        objectName: root.choiceNamePrefix + String(modelData[0])
                        label: modelData[1]
                        hint: root.label + ": " + modelData[1]
                        width: Math.min(implicitWidth, root.width)
                        selected: root.value === modelData[0]
                        enabled: root.enabled
                        implicitHeight: Design.minHit + Design.baseline * 2
                        onClicked: {
                            if (root.value !== modelData[0])
                                root.picked(modelData[0]);

                            root.dismiss();
                        }
                    }
                }
            }
        }
    }
}
