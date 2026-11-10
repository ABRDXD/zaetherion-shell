import qs.view.cues
import QtQuick
import Quickshell

Rectangle {
    id: root
    property bool pulse: false
    implicitWidth: 8
    implicitHeight: 8
    radius: 0
    color: Design.ink
    // Breathes 1 → 0.3 → 1 while pulsing and live, in Overdrive only (it kept the window drawing at 145 fps
    // while music played); rests at 1 otherwise.
    opacity: 1 - 0.7 * breath.value
    Pulse {
        id: breath
        name: "status.breath"
        scope: root
        repeat: root.pulse && Motion.overdrive
        attack: Motion.breath
        attackEasing: Motion.linear
    }
}
