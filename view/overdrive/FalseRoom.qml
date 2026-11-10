import qs.view.cues
import qs.view.shell
import qs.view.ui
import QtQuick
import "FalseRoom.js" as F
import "../shell/Orbit.js" as Orbit
import "../rooms/Survey.js" as Survey

// The False Room on the orbit (docs/OVERDRIVE_IDEAS.md W1, docs/OVERDRIVE.md §53; rules in FalseRoom.js). Drawn only
// once the surveyor's errors have outlined its place (three of them, weeks of use), out past the outermost room on
// the bearing they point to: a frame lying flat on the plane, numbered −1, that answers nothing. While every
// condition holds at once (its sidereal hour, the machine on battery, nothing playing, and the last two hops through
// the rooms rare in a long history) and that set hasn't been spent, it rises on one hairline stalk and opens.
Item {
    id: root
    // view/shell/OrbitSystem.qml
    property Item orbit: null
    property var book: null
    property var journey: null
    property var battery: null
    property bool playing: false
    property var spent: []
    // The sky: degrees east. The timezone's own meridian stands in when the core's sky hasn't said.
    property real longitude: -new Date().getTimezoneOffset() / 4
    signal entered(string signature)

    readonly property bool sighted: F.sighted(book)
    readonly property var at: F.place(Survey.locus(book?.seed ?? 0))
    readonly property real lst: { Clock.minuteStr; return F.sidereal(Date.now(), root.longitude); }
    readonly property var conds: F.conditions({
        lst: root.lst, seed: book?.seed ?? 0, battery: root.battery, playing: root.playing,
        recent: journey?.recent ?? [], edges: journey?.edges ?? {}
    })
    readonly property bool open: sighted && F.open(conds, spent)
    // It rises as it opens, at the engine's pace.
    property real rise: 0
    onOpenChanged: { lift.to = open ? 1 : 0; lift.restart(); }
    Component.onCompleted: rise = open ? 1 : 0
    NumberAnimation { id: lift; target: root; property: "rise"; duration: Motion.scaled(1400); easing.type: Motion.standard }
    readonly property var p: orbit ? Orbit.project(orbit.outer * at.r, at.theta, orbit.cx, orbit.cy, orbit.camView, orbit.lift * rise) : null
    readonly property real w: orbit && p ? orbit.tileW * 0.82 * p.scale : 0
    readonly property real h: orbit && p ? orbit.tileH * 0.82 * p.scale : 0
    visible: sighted && p !== null
    opacity: Motion.drive * (p?.opacity ?? 1)

    // The stalk: one hairline from the plane up to the frame, only while it is open.
    Rectangle {
        visible: root.rise > 0.01
        x: root.p?.gx ?? 0
        y: Math.min(root.p?.y ?? 0, root.p?.gy ?? 0)
        width: 1
        height: Math.abs((root.p?.gy ?? 0) - (root.p?.y ?? 0))
        color: Design.accent
    }
    // Its foot: a mark on the plane where the survey errors keep landing.
    Repeater {
        model: 2
        Rectangle {
            required property int index
            x: (root.p?.gx ?? 0) - (index === 0 ? 5 : 0)
            y: (root.p?.gy ?? 0) - (index === 0 ? 0 : 5)
            width: index === 0 ? 11 : 1
            height: index === 0 ? 1 : 11
            color: Qt.alpha(Design.danger, 0.7)
        }
    }
    Item {
        id: frame
        x: (root.p?.x ?? 0) - root.w / 2
        y: (root.p?.y ?? 0) - root.h
        width: root.w
        height: root.h
        // Lying flat, it is foreshortened onto the plane; standing, it faces you as the rooms do.
        transform: Scale { origin.y: frame.height; yScale: 0.28 + 0.72 * root.rise }
        Rectangle {
            anchors.fill: parent
            color: root.open ? Qt.alpha(Design.background, 0.85) : "transparent"
            border.width: 1
            border.color: root.open ? Design.accent : Qt.alpha(Design.faint, 0.6)
        }
        // Dashed: the outline the survey drew, not a room's.
        Repeater {
            model: root.open ? 0 : 6
            Rectangle {
                required property int index
                x: frame.width * (index + 0.5) / 6 - 2
                y: -1
                width: 4
                height: frame.height + 2
                color: "transparent"
                border.width: 0
                Rectangle { width: 4; height: 1; color: Design.background }
                Rectangle { y: parent.height - 1; width: 4; height: 1; color: Design.background }
            }
        }
        FText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            text: "−1"
            headline: true
            font.pixelSize: Design.readout
            font.weight: Font.Black
            color: root.open ? Design.accent : Design.faint
        }
        FText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 5
            visible: root.open
            text: "UNSURVEYED"
            technical: true
            color: Design.muted
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.open && root.rise > 0.95
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.entered(root.conds.signature)
        }
    }
}
