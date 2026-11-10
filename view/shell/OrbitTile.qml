import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Controls

// One room on the orbit (docs/ORBIT.md §5): a small sheared plane in the house material, not a picture
// of a planet. It carries the room's number, its symbol and its name; the highlighted tile (hovered or
// keyboard-focused) is filled with the signal colour, and the current room is ink. A planet's tile also
// carries its room's face (view/faces) beside the number, in place of the symbol: the room's one live
// fact, loaded only while the overview is open and still. Nothing in it moves; a face ticks only while live.
AbstractButton {
    id: root
    required property var entry
    required property string number
    property bool current: false
    property bool highlighted: false
    // The room's face (a Component of view/faces), and whether it may read and tick (the overview open and
    // at rest). Null: the symbol, as on a moon.
    property Component face: null
    property bool faceLive: false
    readonly property Item faceItem: faceLoader.item
    // The symbol's size as a share of the tile's height: small beside the number, large on a tile with no
    // number (a control on a smaller system, SpaceSystem).
    property real glyphScale: number === "" && !wordy ? 0.5 : 0.3
    // A long name with no number (a task's text): two lines for the words, the symbol small in the corner.
    readonly property bool wordy: number === "" && (entry.name ?? "").length > 11
    readonly property string role: current ? "ink" : "paper"
    // The highlight, eased (a Tween: only while the pointer or the keys move it). It sweeps the signal
    // colour across the tile from the left along 78°, and lifts and grows the tile a little.
    property real lit: highlighted ? 1 : 0
    Tween on lit {
        scope: root
        NumberAnimation { duration: Motion.settle; easing.type: Easing.OutCubic }
    }
    readonly property color ink: lit > 0.5 ? (Design.onSignal ?? Design.background) : plane.textColor
    // Overdrive: the pointer's pull (OrbitSystem.leanOf); nothing in Silent.
    property point lean: Qt.point(0, 0)
    // Overdrive: a transit's readout in the name's place, and a tint on the numeral (OrbitLaws).
    property string substitute: ""
    property color shiftTint: "transparent"
    // Overdrive: how much of this room's data can't be measured now (Orbit.errorBudget), and how steeply the orbit is tilted away (0 face-on, 1 edge-on). The measurement brackets
    // open with the doubt and only appear at a steep view, as a parallax error would.
    property real doubt: 0
    property real steepness: 0
    Repeater {
        model: Motion.driving && root.doubt > 0 ? [-1, 1] : []
        Rectangle {
            required property int modelData
            readonly property real gap: root.height * (0.08 + 0.42 * root.doubt) * Math.min(1, root.steepness * 1.6)
            x: root.width / 2 + modelData * (root.width / 2 + gap) - width / 2
            y: 0
            width: 2
            height: root.height
            color: Design.warm
            opacity: Math.min(1, root.steepness * 2.5) * Motion.drive
            Rectangle { y: 0; x: modelData < 0 ? 0 : -6; width: 8; height: 2; color: parent.color }
            Rectangle { y: parent.height - 2; x: modelData < 0 ? 0 : -6; width: 8; height: 2; color: parent.color }
        }
    }
    transform: [
        Scale { origin.x: root.width / 2; origin.y: root.height / 2; xScale: 1 + 0.08 * root.lit; yScale: 1 + 0.08 * root.lit },
        Translate { y: -6 * root.lit },
        Translate { x: root.lean.x; y: root.lean.y }
    ]
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    padding: 0
    Accessible.name: number + " " + entry.name
    Accessible.description: entry.about ?? ""

    background: Item {
        Plane {
            id: plane
            anchors.fill: parent
            role: root.role
            slant: 3
            backing: true
        }
        // The sweep: a signal parallelogram growing from the left edge, both edges at 78°.
        Plane {
            visible: root.lit > 0
            width: plane.run + root.lit * (parent.width - plane.run)
            height: parent.height
            role: "signal"
            slant: 3
        }
        // The current room keeps an ink strip on its left edge while highlighted.
        Plane {
            visible: root.current && root.lit > 0.5
            width: 6
            height: parent.height
            role: "ink"
            slant: 3
        }
    }
    // Laid out so nothing overlaps at any size: the name keeps a readable floor (caption) and elides past
    // it; a symbol without a number takes the space above the name; a number shrinks to leave its symbol room.
    contentItem: Item {
        readonly property real run: height * Math.tan(12 * Math.PI / 180)
        FText {
            id: numeral
            x: parent.run + 6
            y: 2
            // Clear of its symbol, or of a face (which takes the right half).
            width: Math.max(10, (faceLoader.status === Loader.Ready ? root.width * 0.55 : symbol.x) - x - 4)
            text: root.number
            headline: true
            // Half the tile (48–76 px); a little smaller beside a face, so the fact has room.
            font.pixelSize: Math.round(root.height * (root.face ? 0.4 : 0.5)) // scale: half the tile, less beside a face
            font.weight: Font.Black
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Math.max(Design.caption, Math.round(root.height * 0.28))
            color: Qt.tint(root.ink, root.shiftTint)
        }
        // The face: right of the number, above the name, clear of the sheared right edge.
        Loader {
            id: faceLoader
            active: root.face !== null
            asynchronous: true
            sourceComponent: root.face
            x: numeral.x + numeral.implicitWidth + 4
            y: 3
            width: Math.max(0, root.width - x - parent.run * 0.6 - 5)
            height: Math.max(0, name.y - y - 1)
        }
        Binding { target: faceLoader.item; property: "live"; value: root.faceLive; when: faceLoader.item !== null }
        Binding { target: faceLoader.item; property: "tone"; value: root.ink; when: faceLoader.item !== null }
        Binding { target: faceLoader.item; property: "ground"; value: root.lit > 0.5 ? Design.accent : plane.fillColor; when: faceLoader.item !== null }
        MaterialSymbol {
            id: symbol
            visible: faceLoader.status !== Loader.Ready
            // Top right beside a number; centred in the space above the name on a tile without one.
            readonly property real room: name.y - 4
            readonly property bool centred: root.number === "" && !root.wordy
            x: centred ? (parent.width - width + parent.run) / 2 : parent.width - width - 8
            y: centred ? Math.max(2, (room - height) / 2) : 5
            text: root.entry.symbol ?? ""
            iconSize: Math.round(centred ? Math.min(root.height * root.glyphScale, room - 2) : root.height * (root.wordy ? 0.26 : root.glyphScale))
            color: root.ink
            opacity: 0.8
        }
        FText {
            id: name
            x: 9
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            width: parent.width - 9 - parent.run - 4
            text: root.substitute !== "" ? root.substitute : root.entry.name
            headline: true
            font.pixelSize: Math.max(Design.caption, Math.round(root.height * 0.2)) // scale: a fifth of the tile, never under caption
            font.weight: Font.Black
            fontSizeMode: root.wordy ? Text.FixedSize : Text.HorizontalFit
            minimumPixelSize: Design.caption
            wrapMode: root.wordy ? Text.Wrap : Text.NoWrap
            maximumLineCount: root.wordy ? 2 : 1
            lineHeight: root.wordy ? 0.9 : 1
            elide: Text.ElideRight
            color: root.ink
        }
    }
}
