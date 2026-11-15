import QtQuick
import QtQuick.Layouts
import qs.view.ui

// One setting as a row of choices (Z176): its name, then a button per value; the current value is selected.
// `options` is [[value, label], …]; `value` is the current one (or undefined while unknown, when nothing is selected).
RowLayout {
    id: root
    property string label: ""
    property string note: ""
    property var options: []
    property var value
    signal picked(var value)
    spacing: Design.baseline * 2
    ColumnLayout {
        Layout.preferredWidth: 200
        Layout.maximumWidth: 200
        Layout.alignment: Qt.AlignVCenter
        spacing: 0
        FText { text: root.label; technical: true; color: Design.ink }
        FText {
            visible: root.note !== ""
            Layout.fillWidth: true
            text: root.note
            technical: true
            color: Design.muted
            elide: Text.ElideRight
        }
    }
    Repeater {
        model: root.options
        FButton {
            required property var modelData
            objectName: "choice-" + root.label.toLowerCase().replace(/[^a-z0-9]+/g, "-") + "-" + String(modelData[0])
            label: modelData[1]
            selected: root.value === modelData[0]
            enabled: root.enabled
            implicitHeight: Design.minHit
            onClicked: if (root.value !== modelData[0]) root.picked(modelData[0])
        }
    }
    Item { Layout.fillWidth: true }
}
