import QtQuick
import QtQuick.Controls
import qs.view.fluid
import qs.view.ui

// The nav items and their marks use the same circle as the painted limb.
Flickable {
    id: root
    required property var sections
    required property string section
    signal picked(string section)
    clip: true
    contentWidth: width
    contentHeight: Math.max(height, 90 + sections.length * FluidTokens.controlHeight)
    boundsBehavior: Flickable.StopAtBounds
    readonly property real inset: Math.min(32, width * 0.12)
    readonly property real radius: Math.max(contentHeight, contentHeight * contentHeight / Math.max(1, width * 2.6))
    readonly property real centre: width - 10 - radius
    readonly property real pitch: Math.min(51, (contentHeight - 88) / Math.max(1, sections.length))
    function rim(y: real): real {
        const dy = y - contentHeight / 2;
        return centre + Math.sqrt(Math.max(0, radius * radius - dy * dy));
    }
    Canvas {
        width: root.width
        height: root.contentHeight
        readonly property color base: FluidTokens.base
        readonly property color glow: Qt.tint(base, Qt.alpha(FluidTokens.accent, 0.25))
        readonly property color rimColor: Qt.tint(base, Qt.alpha(FluidTokens.ink, 0.45))
        onBaseChanged: requestPaint()
        onGlowChanged: requestPaint()
        onRimColorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const r = root.radius, x = root.centre, y = height / 2;
            const grad = ctx.createRadialGradient(x, y, r * 0.67, x, y, r);
            grad.addColorStop(0, base);
            grad.addColorStop(0.72, Qt.tint(base, Qt.alpha(glow, 0.45)));
            grad.addColorStop(1, glow);
            ctx.fillStyle = grad;
            ctx.strokeStyle = rimColor;
            ctx.beginPath();
            ctx.arc(x, y, r, 0, 2 * Math.PI);
            ctx.fill();
            ctx.stroke();
        }
    }
    FluidText {
        x: root.inset
        y: FluidTokens.gap
        text: "Settings"
        width: parent.width - 2 * root.inset
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: Design.readout
        font.pixelSize: FluidTokens.title
        font.weight: Font.DemiBold
    }
    Repeater {
        model: root.sections
        AbstractButton {
            id: tab
            required property var modelData
            required property int index
            readonly property bool current: root.section === modelData[0]
            x: root.inset / 2
            y: 72 + index * root.pitch
            height: Math.min(38, root.pitch)
            width: root.rim(y + height / 2) - x
            objectName: "section-" + modelData[0]
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.role: Accessible.PageTab
            Accessible.name: modelData[1]
            Accessible.selected: current
            onActiveFocusChanged: if (activeFocus) {
                if (y < root.contentY) root.contentY = y;
                else if (y + height > root.contentY + root.height) root.contentY = y + height - root.height;
            }
            onClicked: { Feedback.play("ui.click"); root.picked(modelData[0]); }
            background: Item {
                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 14
                    radius: height / 2
                    color: tab.current ? Qt.tint(FluidTokens.base, Qt.alpha(FluidTokens.accent, 0.18))
                        : tab.hovered || tab.down ? FluidTokens.control : "transparent"
                    border.width: tab.visualFocus ? 1 : 0
                    border.color: FluidTokens.ink
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width - width / 2
                    width: tab.current ? 14 : 4
                    height: width
                    radius: width / 2
                    color: tab.current ? FluidTokens.base : FluidTokens.secondary
                    border.width: tab.current ? 1 : 0
                    border.color: FluidTokens.accent
                    Rectangle {
                        visible: tab.current
                        anchors.centerIn: parent
                        width: 5; height: 5; radius: 3
                        color: FluidTokens.accent
                    }
                }
            }
            contentItem: FluidText {
                leftPadding: root.inset / 2
                rightPadding: 16
                text: tab.modelData[0] === "wifi" ? "Wi-Fi" : tab.modelData[1][0] + tab.modelData[1].slice(1).toLowerCase()
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.weight: tab.current ? Font.DemiBold : Font.Normal
                color: tab.current ? FluidTokens.ink : FluidTokens.secondary
            }
        }
    }
}
