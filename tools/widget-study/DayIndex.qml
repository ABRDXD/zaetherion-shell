pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: clock
    required property string dayFamily
    required property string detailFamily
    // A preview can carry the selected tab in from another surface.
    property bool dateInFlight: false
    property real leftPull: 1
    property real rightPull: 1
    readonly property color paper: "#20232a"
    readonly property color ink: "#f2efdf"
    property int trackingOffset: 0
    property bool briefDate: false
    property string timeLabel: "– 07:24 –"
    property color signal: "#ffd064"

    Item {
        id: sheet
        width: 780
        height: 209
        anchors.centerIn: parent
        scale: Math.min(1, clock.width / width, clock.height / height)

        component Plate: Canvas {
            required property color fill
            required property var points
            anchors.fill: parent
            onFillChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = fill;
                c.beginPath();
                c.moveTo(points[0], points[1]);
                for (let i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i + 1]);
                c.closePath(); c.fill();
            }
        }
        component Day: Text {
            font.family: clock.dayFamily
            font.pixelSize: 76
            font.letterSpacing: 14 + clock.trackingOffset
        }
        SlantedReveal {
            width: 512; height: sheet.height
            amount: clock.leftPull
            x: -24 * (1 - amount)
            Plate { fill: clock.paper; points: [42,50, 511,50, 491,144, 474,144, 463,196, 11,196] }
            Day { x: 56 - Math.max(0, clock.trackingOffset) * 2; y: 51; text: "WEDNES"; color: clock.ink }
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
                        visible: today || !clock.briefDate
                        width: today ? (clock.briefDate ? 90 : 144) : 35
                        height: 33
                        opacity: today && clock.dateInFlight ? 0 : 1
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
                            text: tab.today ? (clock.briefDate ? "18 SEP" : "18 SEP 2030") : String(16 + tab.index)
                            color: tab.today ? clock.paper : "#bdc1bd"
                            font.family: tab.today ? clock.detailFamily : "JetBrains Mono"
                            font.pixelSize: tab.today ? 16 : 14
                            font.weight: tab.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
        SlantedReveal {
            x: 492; width: 288; height: sheet.height
            amount: Math.min(1, clock.rightPull * 1.6)
            fromRight: true
            Plate { fill: clock.signal; points: [23,48, 272,48, 249,156, 0,156] }
        }
        SlantedReveal {
            x: 492 + 32 * (1 - amount); width: 288; height: sheet.height
            amount: clock.rightPull
            fromRight: true
            Plate { fill: clock.ink; points: [43,16, 222,16, 216,44, 275,44, 253,147, 15,147] }
            Day { x: 34; y: 51; text: "DAY"; color: clock.paper }
            Text {
                x: 61; y: 17
                text: clock.timeLabel
                font.family: clock.detailFamily
                font.pixelSize: 19
                color: clock.paper
            }
        }
    }
}
