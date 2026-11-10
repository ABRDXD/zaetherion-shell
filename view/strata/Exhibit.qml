import QtQuick
import qs.view.overdrive
import qs.view.ui

Item {
    id: root
    required property var score
    required property var core
    signal closed
    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        core.request("exhibit.start", {}, (ok, result) => { if(ok) film.start(); else root.closed(); });
    }
    Component.onDestruction: core.notify("exhibit.stop", {})
    Keys.onPressed: event => { if(event.key===Qt.Key_Escape) root.closed(); event.accepted=true; }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: event => event.accepted=true }
    ExhibitFilm { id: film; anchors.fill: parent; score: root.score; onFinished: root.closed() }
    Rectangle {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 60
        width: 90; height: 32; color: Design.background; border.color: Design.line
        Text { anchors.centerIn: parent; text: "ESC / EXIT"; color: Design.ink; font.pixelSize: Design.body }
        MouseArea { anchors.fill: parent; onClicked: root.closed() }
    }
}
