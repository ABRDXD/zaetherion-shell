import QtQuick
import QtQuick.Layouts
import qs.view.ui

// One line about a Wi-Fi, VPN or Bluetooth action (NetWords.attempt): what happened and what you can do next.
// Hidden when there is nothing to say.
RowLayout {
    id: root
    property var words: null
    signal retry()
    signal dismiss()
    visible: words !== null
    Layout.fillWidth: true
    spacing: Design.baseline * 2
    MaterialSymbol {
        text: root.words?.busy ? "progress_activity" : root.words?.ok ? "check" : "error"
        iconSize: Design.statusIcon
        color: root.words?.busy || root.words?.ok ? Design.accent : Design.warning
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        FText { Layout.fillWidth: true; wrapMode: Text.Wrap; aside: true; text: root.words?.line ?? "" }
        FText {
            visible: (root.words?.detail ?? "") !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            technical: true
            color: Design.faint
            text: root.words?.detail ?? ""
        }
    }
    FButton { visible: root.words?.retry ?? false; label: "Try again"; implicitHeight: Design.minHit + Design.baseline * 2; onClicked: root.retry() }
    FButton { visible: !(root.words?.busy ?? true); symbol: "close"; hint: "Dismiss"; implicitHeight: Design.minHit + Design.baseline * 2; onClicked: root.dismiss() }
}
