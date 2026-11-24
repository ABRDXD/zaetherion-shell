pragma ComponentBehavior: Bound
import QtQuick
import "ClockWords.js" as Words

// The Angular desktop clock: Astra's Day index (tools/widget-study/DayIndex.qml, owner's pick 23 Nov), drawn on a
// 780 × 209 sheet that the caller scales. Two 78° planes hold one Anurati weekday ("WEDNES" | "DAY"); the week
// ribbon (Mon–Sun) expands today into the date; the time sits on the upper return. The login (Z55) drives
// leftPull, rightPull and dateInFlight; at rest all three are settled. The Æ stamp seats on the shoulder.
Item {
    id: clock
    required property string dayFamily
    required property string detailFamily
    required property date now
    property var face: ({})
    property bool dateInFlight: false
    property real leftPull: 1
    property real rightPull: 1
    property bool stamp: true
    readonly property int trackingOffset: Words.tracking(face.spacing)
    readonly property bool briefDate: face.date === "short"
    readonly property color signal: Words.ink(face.ink, false)
    readonly property color paper: "#20232a"
    readonly property color ink: "#f2efdf"
    readonly property var week: Words.week(now)
    // The sheet's own type sizes (the study's), at the sheet's 780 px; the caller's scale applies on top.
    readonly property int daySize: 76
    readonly property int dateSize: 16
    readonly property int ribbonSize: 14
    readonly property int timeSize: 19
    // Where the travelling tab docks (the login aims at it): today's tab in sheet coordinates.
    readonly property rect todayTab: Qt.rect(40 + week.today * 42, 150, briefDate ? 90 : 144, 33)
    implicitWidth: 780
    implicitHeight: 209

    Item {
        id: sheet
        width: 780
        height: 209
        anchors.centerIn: parent
        scale: Math.min(clock.width / width, clock.height / height)

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
            font.pixelSize: clock.daySize
            font.letterSpacing: 14 + clock.trackingOffset
        }
        SlantedReveal {
            width: 512; height: sheet.height
            amount: clock.leftPull
            x: -24 * (1 - amount)
            Plate { fill: clock.paper; points: [42,50, 511,50, 491,144, 474,144, 463,196, 11,196] }
            Day { objectName: "weekdayHead"; x: 56 - Math.max(0, clock.trackingOffset) * 2; y: 51; text: Words.weekdayHead(clock.now); color: clock.ink }
            // FART's index ribbon as the week (Monday to Sunday); the inverted tab is today, with the date.
            Row {
                x: 40; y: 150
                spacing: 7
                Repeater {
                    model: 7
                    Item {
                        id: tab
                        required property int index
                        readonly property bool today: index === clock.week.today
                        visible: today || !clock.briefDate
                        width: today ? (clock.briefDate ? 90 : 144) : 35
                        height: 33
                        opacity: today && clock.dateInFlight ? 0 : 1
                        Canvas {
                            anchors.fill: parent
                            visible: tab.today
                            onWidthChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
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
                            objectName: tab.today ? "todayDate" : ""
                            anchors.centerIn: parent
                            text: tab.today ? Words.dateLabel(clock.now, false, clock.briefDate) : String(clock.week.days[tab.index])
                            color: tab.today ? clock.paper : "#bdc1bd"
                            font.family: tab.today ? clock.detailFamily : "JetBrains Mono"
                            font.pixelSize: tab.today ? clock.dateSize : clock.ribbonSize
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
                objectName: "timeLabel"
                x: 61; y: 17
                text: Words.timeLabel(clock.now, clock.face.hours === 12 ? 12 : 24)
                font.family: clock.detailFamily
                font.pixelSize: clock.timeSize
                color: clock.paper
            }
        }
        // The Æ stamp on the shoulder, where the login's wedge settles (tools/login-clock-study, 59c34af).
        PressMark {
            visible: clock.stamp
            x: 43; y: 10; width: 56; height: width * 306 / 425
            progress: 1; line: 3
        }
    }
}
