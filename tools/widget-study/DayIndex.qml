pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: clock
    required property string dayFamily
    required property string detailFamily
    readonly property color paper: "#20232a"
    readonly property color ink: "#f2efdf"
    readonly property color signal: "#ffd064"

    Item {
        id: sheet
        width: 780
        height: 209
        anchors.centerIn: parent
        scale: Math.min(1, clock.width / width, clock.height / height)

        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.reset();
                function plate(colour, points) {
                    c.fillStyle = colour;
                    c.beginPath();
                    c.moveTo(points[0], points[1]);
                    for (let i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i + 1]);
                    c.closePath();
                    c.fill();
                }
                plate(clock.paper, [42,50, 511,50, 491,144, 474,144, 463,196, 11,196]);
                plate(clock.signal, [515,48, 764,48, 741,156, 492,156]);
                plate(clock.ink, [535,16, 714,16, 708,44, 767,44, 745,147, 507,147]);
            }
        }
        component Day: Text {
            font.family: clock.dayFamily
            font.pixelSize: 76
            font.letterSpacing: 14
        }
        Day { x: 56; y: 51; text: "WEDNES"; color: clock.ink }
        Day { x: 526; y: 51; text: "DAY"; color: clock.paper }
        Text {
            x: 553; y: 17
            text: "– 07:24 –"
            font.family: clock.detailFamily
            font.pixelSize: 19
            color: clock.paper
        }

        // FART's index ribbon repurposed as the fixture week (Mon 16–Sun 22).
        // The inverted tab expands to reveal the complete date.
        Row {
            x: 40; y: 150
            spacing: 7
            Repeater {
                model: 7
                Item {
                    id: tab
                    required property int index
                    readonly property bool today: index === 2
                    width: today ? 144 : 35
                    height: 33
                    Canvas {
                        anchors.fill: parent
                        visible: tab.today
                        onPaint: {
                            const c = getContext("2d");
                            c.fillStyle = clock.ink;
                            c.beginPath();
                            c.moveTo(7, 3); c.lineTo(width, 3);
                            c.lineTo(width - 6, height - 3); c.lineTo(1, height - 3);
                            c.closePath(); c.fill();
                            c.fillRect(7, 0, width - 7, 1);
                            c.fillRect(0, height - 1, width - 6, 1);
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: tab.today ? "18 SEP 2030" : String(16 + tab.index)
                        color: tab.today ? clock.paper : "#bdc1bd"
                        font.family: tab.today ? clock.detailFamily : "JetBrains Mono"
                        font.pixelSize: tab.today ? 16 : 14
                        font.weight: tab.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
