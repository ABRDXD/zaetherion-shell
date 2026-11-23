import qs.view.cues
import qs.view.ui
import QtQuick

// The ignite hold, drawn as a fuse burning along the header's rule (D16, docs/OVERDRIVE.md §2): from the ignite
// plate to the rule's end over the 600 ms hold, a spark at its head throwing sparks, the burnt length glowing in
// the signal colour behind it. Cutting a running Overdrive burns it in the warm colour. The hold's progress is
// information, not motion (docs/CUES.md §6): under reduced motion the length still follows the hold, with no
// sparks. The frame clock runs only while the key or plate is held, until it fires.
Item {
    id: root
    required property OverdriveLease lease
    // The rule's line, from the top of this item.
    property real lineY: 4
    readonly property bool cutting: lease.requested
    readonly property color burn: cutting ? Design.warm : Design.accent
    visible: lease.holding
    property double now: 0
    property int frame: 0
    FrameAnimation {
        running: root.visible && !root.lease.fired
        onTriggered: { root.now = Date.now(); root.frame++; }
    }
    readonly property real progress: lease.fired ? 1 : Math.max(0, Math.min(1, (now - lease.holdSince) / 600))
    readonly property real head: progress * width
    // A cheap stable hash, so each spark's flight is the same frame to frame.
    function hash(n) { const s = Math.sin(n * 12.9898) * 43758.5453; return s - Math.floor(s); }
    // The burnt length: brightest at the head, fading back towards the plate.
    Rectangle {
        y: root.lineY - 1
        width: root.head
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.burn, 0.25) }
            GradientStop { position: 1; color: root.burn }
        }
    }
    // The head: a hot core in the ink colour inside a glow of the burn colour.
    Rectangle {
        visible: !root.lease.fired
        x: root.head - 7
        y: root.lineY - 7
        width: 14
        height: 14
        radius: 7
        color: Qt.alpha(root.burn, 0.35)
        Rectangle {
            anchors.centerIn: parent
            width: 5
            height: 5
            radius: 2.5
            color: Design.ink
        }
    }
    // Sparks: each lives 14 frames, thrown back and up from where the head was when it was born, falling as it fades.
    Repeater {
        model: Motion.reduced || root.lease.fired ? 0 : 12
        Rectangle {
            id: spark
            required property int index
            readonly property int life: 14
            readonly property int age: (root.frame + spark.index * 5) % life
            readonly property int born: root.frame - age
            readonly property real angle: Math.PI * (1.05 + 0.75 * root.hash(born * 31 + spark.index))
            readonly property real speed: 1.4 + 2.6 * root.hash(born * 17 + spark.index * 3)
            readonly property real bornX: root.head - age * 1.6
            x: bornX + Math.cos(angle) * speed * age
            y: root.lineY + Math.sin(angle) * speed * age + 0.06 * age * age
            width: 2
            height: 2
            color: spark.index % 3 === 0 ? Design.ink : root.burn
            opacity: 1 - age / life
        }
    }
}
