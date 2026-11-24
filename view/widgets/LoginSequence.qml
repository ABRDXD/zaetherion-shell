pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.view.cues
import qs.view.ui
import "ClockWords.js" as Words
import "LoginWords.js" as Voice

// The Angular login (Z55, Z108; Astra's Register → Day index, owner's pick 23 Nov, motion 59c34af; Impression copy).
// Four type-on log lines seat the slices of the Æ; the last row pulls back, sweeps left, turns edge-on into the
// date and docks in today's slot of the desktop clock; the log sheet is cut away along the 78° seam; the clock's
// planes draw in and the Æ stamps its shoulder. 1.5 s; any key lands at once. Timing is FoldMotion.qml's.
// The study's 1120 × 630 board is mapped onto the clock's real box, so the tab docks where the clock is.
// With a window on the workspace there is no clock: the sheet is cut away to the windows and the pieces fade.
Item {
    id: root
    required property rect clockRect
    property int angle: 0
    property bool occupied: false
    property date now: Clock.date
    property bool systemVoice: true
    property var face: ({})
    property int elapsed: 0
    readonly property bool landed: elapsed >= 1500
    readonly property var lines: systemVoice ? Voice.lines : ["", "", "", ""]
    signal finished()

    function skip() {
        play.stop();
        elapsed = 1500;
    }
    function start() { play.restart(); }
    function stop() { play.stop(); }
    onLandedChanged: if (landed) Qt.callLater(root.finished)

    readonly property var starts: [0, 215, 445, 682]
    readonly property int lineIndex: elapsed < starts[1] ? 0 : elapsed < starts[2] ? 1 : elapsed < starts[3] ? 2 : 3
    readonly property int letters: Math.floor((elapsed - starts[lineIndex]) / 12)
    readonly property real impression: (lineIndex + Math.min(1, letters / Math.max(1, lines[lineIndex].length))) / 4
    FoldMotion { id: cue; elapsed: root.elapsed }

    // Board → screen: the study's clock box (170, 105.5, 780 × 209) onto the real one.
    readonly property real boardScale: clockRect.width / 780
    readonly property real boardX: clockRect.x - 170 * boardScale
    readonly property real boardY: clockRect.y - 105.5 * boardScale
    // The cut's 78° edge in screen pixels, and where it crosses the board's own x axis.
    readonly property real slope: 0.21255656
    readonly property real edge: (width + slope * height) * (1 - cue.cut)
    readonly property real boardEdge: (edge - slope * boardY - boardX) / boardScale
    readonly property var week: Words.week(now)
    readonly property bool briefDate: face.date === "short"
    // Where the travelling tab docks: today's slot (DayIndexFace: x 40 + 42 per day, y 150, 144 or 90 wide).
    readonly property real dockX: 170 + 40 + 42 * week.today
    readonly property real dockWidth: briefDate ? 90 : 144
    readonly property color sheetInk: "#20232a"
    readonly property color sheetPaper: "#f2efdf"
    readonly property color backdrop: "#16191e"
    readonly property int stampSize: 14
    readonly property int logSize: 21
    readonly property int tabSize: 26
    readonly property int dateSize: 16
    readonly property int skipSize: 15

    // The outgoing layer: the whole screen dark, and the log sheet, cut away from the right along the seam.
    Canvas {
        id: outgoing
        anchors.fill: parent
        visible: cue.cut < 1
        property real edge: root.edge
        onEdgeChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.beginPath();
            c.moveTo(0, 0); c.lineTo(edge, 0);
            c.lineTo(edge - root.slope * height, height); c.lineTo(0, height);
            c.closePath(); c.clip();
            c.fillStyle = root.backdrop;
            c.fillRect(0, 0, width, height);
            c.translate(root.clockRect.x + root.clockRect.width / 2, root.clockRect.y + root.clockRect.height / 2);
            c.rotate(root.angle * Math.PI / 180);
            c.translate(-(root.clockRect.x + root.clockRect.width / 2), -(root.clockRect.y + root.clockRect.height / 2));
            c.translate(root.boardX, root.boardY);
            c.scale(root.boardScale, root.boardScale);
            c.fillStyle = root.sheetInk;
            c.fillRect(148, 174 + 48 * cue.cut, 824, 258 - 96 * cue.cut);
        }
    }

    // Everything else in the study's board coordinates, turned with the clock about its centre.
    Item {
        id: board
        x: root.boardX; y: root.boardY
        width: 1120; height: 630
        transformOrigin: Item.TopLeft
        scale: root.boardScale
        transform: Rotation {
            origin.x: 170 + 390; origin.y: 105.5 + 104.5
            angle: root.angle
        }

        DesktopClock {
            objectName: "loginClock"
            visible: cue.leftPull > 0 && !root.occupied
            x: 170; y: 105.5; width: 780; height: 209
            now: root.now; face: root.face; fluid: false
            leftPull: cue.leftPull; rightPull: cue.rightPull
            dateInFlight: !root.landed; stamp: false
        }

        Repeater {
            model: cue.cut < 1 ? root.lineIndex : 0
            Item {
                id: row
                required property int index
                x: 592 + (3 - index) * 20 * cue.cut
                y: 198 + 54 * index
                width: Math.max(0, Math.min(363, root.boardEdge - root.slope * (y + 24) - x))
                height: 48
                clip: true
                Text {
                    x: 21; anchors.verticalCenter: parent.verticalCenter
                    text: root.starts[row.index] + " ms"
                    font.family: "JetBrains Mono"; font.pixelSize: root.stampSize; color: "#aeb5bd"
                }
                Text {
                    x: 116; anchors.verticalCenter: parent.verticalCenter
                    text: root.lines[row.index]
                    font.family: "Roboto Condensed"; font.pixelSize: root.logSize; color: root.sheetPaper
                }
            }
        }
        Text {
            x: 560 - width / 2; y: 630 - 36 - height
            visible: cue.cut < 1
            opacity: 1 - Math.min(1, 6 * cue.cut)
            text: "Press any key to skip"
            font.family: "Roboto Condensed"; font.pixelSize: root.skipSize; color: "#aeb5bd"
        }

        // The Register wedge: the Æ assembles slice by slice, then shrinks onto the clock's shoulder.
        PressMark {
            objectName: "loginWedge"
            visible: !root.occupied || !root.landed
            readonly property real position: root.occupied ? 0 : cue.strike
            readonly property real lift: root.occupied ? 0 : cue.lift * (1 - position)
            x: 148 + 65 * position + 5 * lift
            y: 150 - 34.5 * position - 24 * lift + 5 * cue.stamp
            width: 425 - 369 * position
            height: width * 306 / 425
            opacity: root.occupied ? 1 - cue.cut : 1
            progress: root.impression; line: root.lineIndex
        }

        // The last row: it breaks free, sweeps left, turns over into the date and climbs the seam into today's slot.
        Item {
            id: shuttle
            objectName: "loginTab"
            visible: !root.landed
            readonly property bool toClock: !root.occupied
            readonly property real sideways: toClock ? cue.throwTab : 0
            readonly property real upward: toClock ? cue.climb : 0
            readonly property real rowY: 198 + 54 * root.lineIndex
            // The study lands at Wednesday's slot (x 294); today's slot moves the sweep, not its shape.
            readonly property real sweep: 592 - 21 - root.dockX
            x: 592 - sweep * sideways - 21 * upward + (toClock ? 12 * cue.unlock * (1 - sideways) : 0)
            width: 363 - (363 - root.dockWidth) * sideways + (toClock ? 38 * cue.compression : 0)
            height: 48 - 15 * upward
            y: rowY - (rowY - 255.5) * upward + (toClock ? 3 * cue.contact : 0)
            opacity: toClock ? 1 : 1 - cue.cut
            clip: true
            transform: Scale {
                origin.y: shuttle.height / 2
                yScale: shuttle.toClock ? Math.max(.075, Math.abs(Math.cos(Math.PI * cue.turnover))) : 1
            }
            Canvas {
                anchors.fill: parent
                property bool gold: cue.compression > .9
                property bool rim: cue.turnover < .5
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onGoldChanged: requestPaint()
                onRimChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const inset = height * .21;
                    c.fillStyle = gold ? "#ffd064" : root.sheetPaper;
                    c.beginPath(); c.moveTo(inset, 3); c.lineTo(width, 3);
                    c.lineTo(width - inset, height - 3); c.lineTo(1, height - 3);
                    c.closePath(); c.fill();
                    c.fillStyle = rim ? "#ffd064" : root.sheetPaper;
                    c.fillRect(inset, 0, width - inset, 1);
                    c.fillRect(0, height - 1, width - inset, 1);
                }
            }
            Row {
                x: 21; anchors.verticalCenter: parent.verticalCenter
                visible: !shuttle.toClock || cue.turnover < .5
                Text {
                    width: 95; anchors.verticalCenter: parent.verticalCenter
                    text: root.starts[root.lineIndex] + " ms"
                    font.family: "JetBrains Mono"; font.pixelSize: root.stampSize; color: root.sheetInk
                }
                Text {
                    text: root.lines[root.lineIndex].slice(0, root.letters)
                    font.family: "Roboto Condensed"; font.bold: true; font.pixelSize: root.tabSize; color: root.sheetInk
                }
            }
            Text {
                objectName: "loginDate"
                anchors.centerIn: parent
                visible: shuttle.toClock && cue.turnover >= .5
                text: Words.dateLabel(root.now, false, root.briefDate)
                font.family: poppins.status === FontLoader.Ready ? poppins.name : Design.sans
                font.weight: Font.DemiBold; font.pixelSize: root.dateSize; color: root.sheetInk
            }
        }
    }
    // Poppins for the date, from the owner's Modern Clock plugin, as the clock takes it.
    FontLoader { id: poppins; source: "file://" + (Quickshell.env("HOME") ?? "") + "/.config/dms/plugins/modernClock/fonts/Poppins.ttf" }

    Activity { name: "login.play"; running: play.running }
    NumberAnimation {
        id: play
        target: root; property: "elapsed"; from: 0; to: 1500; duration: 1500
    }
}
