import QtQuick
import qs.view.cues
import qs.view.ui

// Only the decorative field enters the shader. Text and controls are solid QML planes above it.
ShaderEffect {
    id: root
    property var sources: []
    property real remainingFraction: 1
    property string eventKey: ""
    property string completionKey: ""
    property bool flowing: false
    property bool ready: false
    onEventKeyChanged: if (ready) ripple.trigger()
    property string previousCompletion: ""
    onCompletionKeyChanged: {
        const old = previousCompletion.split("/");
        if (ready && completionKey.split("/").some(key => key && !old.includes(key))) done.trigger();
        previousCompletion = completionKey;
    }
    Component.onCompleted: { ready = true; if (flowing) ripple.trigger(); }
    IdleLoop { id: flow; name: "timers.field"; scope: root; enabled: root.flowing; period: 24000 }
    Pulse { id: ripple; name: "timers.ripple"; scope: root; attack: Motion.navigate; release: Motion.unfold * 2 }
    Pulse { id: done; name: "timers.done"; scope: root; flash: true; attack: Motion.feedback; release: Motion.unfold }
    readonly property vector2d sheetSize: Qt.vector2d(width,height)
    readonly property real drive: Motion.drive
    readonly property real phase: flow.turns + flow.phase
    readonly property real fraction: remainingFraction
    readonly property real impulse: ripple.value * Motion.drive
    readonly property real completion: done.value * Motion.drive
    readonly property real count: sources.length
    function packed(i) {
        const a = sources[i];
        return a ? Qt.vector4d(a.x,a.y,a.deadline ? a.seconds : -(a.seconds % 60),a.deadline && a.running ? 1 : 0) : Qt.vector4d(0,0,0,0);
    }
    readonly property vector4d anchor0: packed(0)
    readonly property vector4d anchor1: packed(1)
    readonly property vector4d anchor2: packed(2)
    readonly property color inkColor: Design.ink
    readonly property color signalColor: Design.accent
    fragmentShader: Qt.resolvedUrl("shaders/temporal.frag.qsb")
}
