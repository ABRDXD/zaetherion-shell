pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: menu
    focus: true
    required property bool fluid
    required property string fontFamily
    signal chosen(string label)
    signal dismissed()
    readonly property var labels: ["Edit widgets", "Wallpaper", "Theme", "Settings"]
    readonly property int rowHeight: fluid ? 47 : 44
    readonly property int inset: fluid ? 9 : 8
    readonly property int labelSize: fluid ? 17 : 19
    readonly property color paper: fluid ? "#f3efff" : "#f3efdc"
    property int current: 0
    implicitWidth: fluid ? 232 : 242
    implicitHeight: 2 * inset + labels.length * rowHeight
    Accessible.role: Accessible.PopupMenu
    Accessible.name: "Desktop"

    function step(delta) {
        current = (current + delta + labels.length) % labels.length;
    }
    Keys.onDownPressed: step(1)
    Keys.onUpPressed: step(-1)
    Keys.onEscapePressed: dismissed()
    Keys.onReturnPressed: chosen(labels[current])
    Keys.onEnterPressed: chosen(labels[current])
    Keys.onSpacePressed: chosen(labels[current])

    // Angular follows the control centre's clipped index; Fluid's four stops
    // sit along one arc, with the current action emerging from its left limb.
    function orbitX(t) { return 34 - 12 * Math.sin(Math.PI * t); }
    Canvas {
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d");
            c.clearRect(0, 0, width, height);
            c.beginPath();
            if (menu.fluid) {
                c.moveTo(53, 1);
                c.bezierCurveTo(25, 1, 2, 44, 2, height / 2);
                c.bezierCurveTo(2, height - 41, 24, height - 1, 54, height - 1);
                c.lineTo(width - 27, height - 1);
                c.quadraticCurveTo(width - 1, height - 1, width - 1, height - 28);
                c.lineTo(width - 1, 29);
                c.quadraticCurveTo(width - 1, 1, width - 27, 1);
            } else {
                c.moveTo(0, 0); c.lineTo(width, 0);
                c.lineTo(width, height - 25); c.lineTo(width - 6, height);
                c.lineTo(0, height);
            }
            c.closePath(); c.fillStyle = menu.fluid ? "#2d273e" : "#20232b"; c.fill();
            if (menu.fluid) {
                c.strokeStyle = "#b5a7cf"; c.lineWidth = 1; c.stroke();
                c.beginPath();
                for (let n = 0; n <= 32; ++n) {
                    const t = n / 32;
                    const y = menu.inset + menu.rowHeight * (0.5 + 3 * t);
                    if (!n) c.moveTo(menu.orbitX(t), y); else c.lineTo(menu.orbitX(t), y);
                }
                c.strokeStyle = "#86749f"; c.stroke();
            } else {
                c.fillStyle = "#ffd064"; c.fillRect(0, 0, 49, 3);
                c.fillStyle = "#60616a"; c.fillRect(49, 0, width - 49, 1);
            }
        }
    }

    Repeater {
        model: menu.labels
        Item {
            id: row
            required property string modelData
            required property int index
            readonly property bool selected: menu.current === index
            y: menu.inset + index * menu.rowHeight
            width: menu.width
            height: menu.rowHeight
            objectName: "desktopAction" + index
            Accessible.role: Accessible.MenuItem
            Accessible.name: modelData
            Accessible.onPressAction: menu.chosen(modelData)
            Canvas {
                anchors.fill: parent
                property bool highlighted: row.selected
                onHighlightedChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.clearRect(0, 0, width, height);
                    if (menu.fluid) {
                        const x = menu.orbitX(row.index / 3);
                        if (row.selected) {
                            c.beginPath(); c.moveTo(x + 8, height / 2);
                            c.bezierCurveTo(x + 20, height / 2, 40, 3, 61, 3);
                            c.lineTo(width - 30, 3);
                            c.bezierCurveTo(width - 3, 3, width - 3, height - 3, width - 30, height - 3);
                            c.lineTo(61, height - 3);
                            c.bezierCurveTo(41, height - 3, x + 20, height / 2, x + 8, height / 2);
                            c.fillStyle = "#d5c5ff"; c.fill();
                        }
                        c.beginPath(); c.arc(x, height / 2, row.selected ? 5 : 3, 0, 2 * Math.PI);
                        c.fillStyle = row.selected ? "#f5efff" : "#a197b5"; c.fill();
                    } else if (row.selected) {
                        c.beginPath(); c.moveTo(7, 2); c.lineTo(width - 9, 2);
                        c.lineTo(width - 18, height - 2); c.lineTo(7, height - 2);
                        c.closePath(); c.fillStyle = "#ffd064"; c.fill();
                    } else if (row.index < 3) {
                        c.fillStyle = "#464952"; c.fillRect(19, height - 1, width - 41, 1);
                    }
                }
            }
            Text {
                x: menu.fluid ? 58 : 21
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData
                font.family: menu.fontFamily
                font.pixelSize: menu.labelSize
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                color: row.selected ? "#25232f" : menu.paper
            }
            // A cut-out arrow marks the active Angular index row.
            Canvas {
                visible: !menu.fluid && row.selected
                x: parent.width - 48; anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 12
                onPaint: {
                    const c = getContext("2d");
                    c.clearRect(0, 0, width, height); c.beginPath();
                    c.moveTo(1, 6); c.lineTo(13, 6);
                    c.moveTo(8, 1); c.lineTo(13, 6); c.lineTo(8, 11);
                    c.lineWidth = 2; c.strokeStyle = "#25232f"; c.stroke();
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: menu.current = row.index
                onClicked: menu.chosen(row.modelData)
            }
        }
    }
}
