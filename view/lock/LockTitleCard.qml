pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property LockLook look
    required property string timeText
    required property string dateText

    Canvas {
        anchors.fill: parent
        property bool fluid: root.look.fluid
        onFluidChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            if (root.look.fluid) {
                // Offset arcs read as the lit limb of the atmosphere.
                const glow = c.createRadialGradient(640, 303, 45, 640, 303, 345);
                glow.addColorStop(0, "rgba(33,29,54,0.72)");
                glow.addColorStop(0.62, "rgba(33,29,54,0.48)");
                glow.addColorStop(1, "rgba(33,29,54,0)");
                c.fillStyle = glow;
                c.fillRect(190, 0, 900, 690);
                c.strokeStyle = "rgba(231,213,250,0.56)";
                c.beginPath();
                c.ellipse(345, 153, 590, 331);
                c.stroke();
                c.strokeStyle = "rgba(231,213,250,0.20)";
                c.beginPath();
                c.ellipse(333, 149, 614, 341);
                c.stroke();
                c.fillStyle = "#e8d4fa";
                c.beginPath();
                c.arc(345, 318, 3, 0, 2 * Math.PI);
                c.fill();
            } else {
                function plane(points, fill) {
                    c.beginPath();
                    c.moveTo(points[0], points[1]);
                    for (let i = 2; i < points.length; i += 2)
                        c.lineTo(points[i], points[i + 1]);
                    c.closePath();
                    c.fillStyle = fill;
                    c.fill();
                }
                plane([439, 190, 859, 190, 819, 342, 780, 342, 774, 366, 408, 366, 420, 321, 404, 321], "#283842");
                plane([439, 190, 859, 190, 853, 211, 434, 211], "#354b56");
                plane([439, 190, 502, 190, 500, 196, 437, 196], "#ffc27a");
                plane([454, 334, 824, 334, 817, 363, 446, 363], "#e9ddc6");
                for (let i = 0; i < 5; i++)
                    plane([809 + i * 7, 198, 812 + i * 7, 198, 810 + i * 7, 204, 807 + i * 7, 204], "#92a0a0");
            }
        }
    }
    Row {
        x: 51
        y: 39
        spacing: 11
        LockGlyph {
            width: 18
            height: 18
            mark: "lock"
            ink: root.look.accent
        }
        LockText {
            look: root.look
            technical: true
            text: "ZÆTHERION"
            font.bold: true
        }
    }
    LockText {
        look: root.look
        technical: true
        anchors.right: parent.right
        anchors.rightMargin: 51
        y: 40
        text: "SESSION LOCK"
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.look.fluid ? 190 : 194
        textFormat: Text.PlainText
        text: root.timeText
        color: root.look.ink
        font.family: root.look.fluid ? "DejaVu Serif" : "Inter Display"
        font.pixelSize: root.look.clockSize
        font.italic: true
        font.weight: root.look.fluid ? Font.Normal : Font.Black
        font.letterSpacing: root.look.fluid ? -4 : -2
    }
    LockText {
        look: root.look
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.look.fluid ? 332 : 334
        text: root.dateText
        color: root.look.fluid ? root.look.ink : "#233139"
        font.family: root.look.fluid ? "DejaVu Serif" : "Inter"
        font.pixelSize: root.look.dateSize
        font.weight: root.look.fluid ? Font.Normal : Font.DemiBold
    }
}
