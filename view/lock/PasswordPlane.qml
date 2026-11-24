pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property LockLook look
    required property bool reducedMotion
    required property int maskLength
    required property int attempts
    // Negative between rejections; the host supplies elapsed time from the latest rejection.
    required property real rejectionMs
    readonly property bool failed: rejectionMs >= (reducedMotion ? 0 : 320)

    Item {
        id: field
        width: root.look.fluid ? 320 : 376
        height: 56
        x: (parent.width - width) / 2 + offset
        y: root.look.fluid ? 392 : 389
        readonly property real phase: Math.min(1, Math.max(0, root.rejectionMs / 320))
        readonly property real offset: root.reducedMotion ? 0 : (root.look.fluid ? 6 : 10) * Math.sin(phase * (root.look.fluid ? 2 : 3) * Math.PI * 2) * (1 - phase)
        Canvas {
            anchors.fill: parent
            property bool failed: root.failed
            property bool fluid: root.look.fluid
            onFluidChanged: requestPaint()
            onFailedChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.lineWidth = 1.5;
                c.fillStyle = root.look.fluid ? root.look.plate : root.look.plate;
                c.strokeStyle = failed ? root.look.alert : root.look.accent;
                c.beginPath();
                if (root.look.fluid)
                    c.roundedRect(1, 1, width - 2, height - 2, 27, 27);
                else {
                    c.moveTo(14, 1);
                    c.lineTo(width - 1, 1);
                    c.lineTo(width - 15, height - 1);
                    c.lineTo(1, height - 1);
                    c.closePath();
                }
                c.fill();
                c.stroke();
            }
        }
        LockGlyph {
            x: 23
            anchors.verticalCenter: parent.verticalCenter
            width: 21
            height: 21
            mark: "lock"
            ink: root.look.accent
        }
        LockText {
            look: root.look
            x: 58
            anchors.verticalCenter: parent.verticalCenter
            text: root.maskLength > 0 ? "•".repeat(Math.min(root.maskLength, 64)) : qsTr("Password")
            width: parent.width - 118
            elide: Text.ElideRight
            font.letterSpacing: root.maskLength > 0 ? 4 : 0
        }
        LockGlyph {
            anchors.right: parent.right
            anchors.rightMargin: 23
            anchors.verticalCenter: parent.verticalCenter
            width: 21
            height: 21
            mark: "enter"
            ink: root.look.accent
        }
    }
    Rectangle {
        visible: root.failed
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.look.fluid ? 455 : 453
        width: Math.max(188, message.implicitWidth + 20)
        height: 26
        radius: root.look.fluid ? 13 : 0
        color: root.look.alertPlate
        LockText {
            id: message
            look: root.look
            technical: true
            anchors.centerIn: parent
            color: root.look.alert
            text: "> AUTH FAILED · " + root.attempts
        }
    }
}
