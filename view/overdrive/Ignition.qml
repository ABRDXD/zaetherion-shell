import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick

// The ignition and the spin-down (docs/OVERDRIVE.md §2), laid over the Shell.
// Ignition, when the lease turns the engine on while the panel is seen:
// - one flash of the signal colour (a FlashGate grant; denied, it is dropped);
// - the montage breaks: the header jumps up along 78° and the field down, then they slam back past each other
//   and settle (`jolt`, which the Shell applies);
// - a shockwave runs out from the ignite plate and bends the panel as it passes (a GPU stratum).
// The spin-down, when it turns off: a cold band leaning at 78° sweeps down the panel with the engine's fall.
Item {
    id: root
    // What the shockwave bends (the Shell's content), a sibling of this item, so in the same coordinates.
    property Item target: null
    // The ignite plate's centre, in this item's coordinates.
    property point origin: Qt.point(40, 40)
    readonly property real jolt: joltPulse.value
    property bool waving: false
    readonly property bool spinningDown: !Motion.driving && Motion.drive > 0

    Pulse {
        id: joltPulse
        name: "overdrive.jolt"
        scope: root
        attack: Motion.scaled(60)
        release: Motion.scaled(760)
        attackEasing: Easing.OutCubic
        releaseEasing: Easing.OutBack
        overshoot: 3.4
    }
    Pulse {
        id: flashPulse
        name: "overdrive.flash"
        scope: root
        flash: true
        attack: Motion.scaled(30)
        release: Motion.scaled(360)
        releaseEasing: Easing.OutQuad
    }
    Connections {
        target: Motion
        function onDrivingChanged() { if (Motion.driving) root.ignite(); else root.waving = false; }
    }
    // Tests: everything at rest now.
    function settle() {
        joltPulse.cancel();
        flashPulse.cancel();
        root.waving = false;
    }
    function ignite() {
        if (!Motion.live(root))
            return;
        joltPulse.trigger();
        flashPulse.trigger();
        root.waving = true;
    }
    Rectangle {
        anchors.fill: parent
        radius: Design.radiusPanel
        color: Design.accent
        opacity: 0.42 * flashPulse.value
        visible: opacity > 0.001
    }
    Item {
        anchors.fill: parent
        clip: true
        visible: root.spinningDown
        Rectangle {
            readonly property real fall: 1 - Motion.drive
            width: root.width * 1.5
            height: 160
            x: -root.width * 0.25
            y: -height + (root.height + 2 * height) * fall
            rotation: -12
            opacity: Math.sin(Math.PI * fall)
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.82; color: Qt.alpha(Design.accent, 0.10) }
                GradientStop { position: 0.97; color: Qt.alpha(Design.accent, 0.32) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Stratum {
        name: "shockwave"
        wanted: root.waving
        x: root.target?.x ?? 0
        y: root.target?.y ?? 0
        width: root.target?.width ?? 0
        height: root.target?.height ?? 0
        sourceComponent: Shockwave {
            target: root.target
            origin: Qt.point(root.origin.x - (root.target?.x ?? 0), root.origin.y - (root.target?.y ?? 0))
            onFinished: root.waving = false
        }
    }
}
