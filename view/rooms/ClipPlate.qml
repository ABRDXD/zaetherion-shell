import QtQuick
import QtQuick.Controls
import qs.view.cues
import qs.view.strata
import qs.view.ui
import "ClipKinds.js" as ClipKinds

Item {
    id: plate
    required property var record
    required property int position
    required property bool pinned
    required property bool retained
    required property bool copied
    signal copyRequested()
    signal pinRequested()
    signal deleteRequested()

    readonly property string kind: ClipKinds.kind(record)
    readonly property bool monospaced: ["PATH", "CODE", "LINK"].includes(kind)
    readonly property color ink: "#20241f"
    readonly property color rule: "#80867c"
    readonly property real run: -Design.shear * height
    readonly property bool cool: position % 4 === 1 || position % 4 === 2

    // Shear only the paper and its edge marks. The reading and hit targets stay upright.
    Rectangle {
        id: paper
        width: Math.max(0, plate.width - plate.run)
        height: plate.height
        color: plate.cool ? "#c9d1cd" : "#dcdacf"
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, Design.shear, 0, plate.run, 0, 1, 0, 0,
                                 0, 0, 1, 0, 0, 0, 0, 1)
        }
        Rectangle {
            width: plate.pinned ? 5 : 2
            height: parent.height
            color: plate.pinned ? "#44685e" : plate.rule
        }
        Rectangle {
            visible: plate.kind === "COLOUR"
            anchors.right: parent.right
            width: parent.width * 0.24
            height: parent.height - actions.height - 10
            color: mark.swatchColor
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            spacing: 5
            visible: plate.kind !== "COLOUR"
            Repeater {
                model: 3
                Rectangle { width: 1; height: 22; color: plate.rule; opacity: 0.55 }
            }
        }
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.leftMargin: plate.run + 8
        anchors.rightMargin: plate.run + 6
        anchors.topMargin: 8
        anchors.bottomMargin: 5
        spacing: 0

        Row {
            width: parent.width
            height: 20
            spacing: 8
            KindMark {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                kind: plate.kind
                swatch: ClipKinds.colour(plate.record)
                ink: plate.ink
            }
            FText {
                width: Math.max(0, parent.width - mark.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                text: "№ " + plate.record.id + "   " + plate.kind
                      + (plate.retained ? "   · RETAINED PIN" : plate.pinned ? "   · PINNED" : "")
                technical: true
                color: plate.ink
            }
        }
        Item {
            width: parent.width
            height: parent.height - actions.height - 21
            FText {
                id: preview
                readonly property bool compact: width < 300
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (plate.kind === "COLOUR" ? paper.width * 0.20 : 0)
                text: plate.record.isImage ? plate.record.text : plate.record.text.slice(0, 450)
                color: plate.ink
                headline: !plate.monospaced
                sheared: false
                font.weight: plate.monospaced ? Font.Normal : Font.DemiBold
                font.capitalization: Font.MixedCase
                font.pixelSize: plate.monospaced ? Design.control : compact ? Design.readout : Design.figure
                font.letterSpacing: plate.monospaced ? 0 : -0.5
                wrapMode: Text.Wrap
                maximumLineCount: plate.monospaced ? 3 : 2
                Stratum {
                    anchors.fill: parent
                    z: -1
                    name: "clips.copy." + plate.position
                    gpu: false
                    scope: plate
                    wanted: !plate.retained && plate.position > 0
                    sourceComponent: PhotocopyLayer { target: preview; index: plate.position; seed: String(plate.record.id) }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: plate.rule }
        Item {
            id: actions
            width: parent.width
            height: Design.minHit + Design.baseline
            Row {
                spacing: 6
                PlateAction {
                    text: plate.copied ? "Copied" : "Copy"
                    font.bold: true
                    onClicked: plate.copyRequested()
                }
                PlateAction {
                    text: plate.pinned ? "Unpin" : "Pin"
                    onClicked: plate.pinRequested()
                }
            }
            PlateAction {
                anchors.right: parent.right
                visible: !plate.retained
                text: "Delete"
                onClicked: plate.deleteRequested()
            }
        }
    }
    component PlateAction: AbstractButton {
        id: action
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        implicitWidth: Math.max(Design.minHit, label.implicitWidth + 8)
        implicitHeight: Design.minHit + Design.baseline
        Accessible.name: text + " record " + plate.record.id
        onClicked: Feedback.play("ui.click")
        background: Rectangle {
            color: action.down || action.visualFocus ? plate.ink : "transparent"
        }
        contentItem: FText {
            id: label
            text: action.text
            color: action.visualFocus || action.down ? paper.color : plate.ink
            font.weight: action.font.bold ? Font.Bold : Font.Normal
            font.capitalization: Font.MixedCase
            font.underline: action.hovered
            font.letterSpacing: 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
