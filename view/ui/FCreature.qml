import qs.view.cues
import QtQuick
import QtQuick.Shapes
import Quickshell

// Original creature: Mote, a badly supervised surveying instrument.
Item {
    id: root
    property real progress: 0
    property bool awake: false
    // The line it stands on. The wandering surveyor stands on the room's own edges instead (view/overdrive/Wanderer).
    property bool ground: true
    signal discovered
    // The press reaction alone, for a poke handled outside (the wanderer's own hit area).
    function press() { reaction.trigger(); }
    implicitWidth: 180
    implicitHeight: 120
    Item {
        id: body
        width: 130
        height: 66
        anchors.centerIn: parent
        rotation: root.awake ? -8 : 0
        scale: 1 - 0.07 * reaction.value
        transform: Translate {
            y: root.awake ? -8 : 0
        }
        Tween on rotation {
            scope: root
            SpringAnimation {
                spring: 4
                damping: 0.35
                epsilon: 0.2
                duration: Motion.pressOut
            }
        }
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: Design.ink
                strokeWidth: 1.5
                fillColor: Design.surface
                startX: 8
                startY: 36
                PathLine {
                    x: 30
                    y: 18
                }
                PathLine {
                    x: 34
                    y: 0
                }
                PathLine {
                    x: 47
                    y: 15
                }
                PathLine {
                    x: 106
                    y: 15
                }
                PathLine {
                    x: 122
                    y: 31
                }
                PathLine {
                    x: 108
                    y: 49
                }
                PathLine {
                    x: 20
                    y: 49
                }
                PathLine {
                    x: 8
                    y: 36
                }
            }
            ShapePath {
                strokeColor: Design.muted
                strokeWidth: 1.5
                fillColor: "transparent"
                startX: 34
                startY: 50
                PathLine {
                    x: 26
                    y: 63
                }
                PathLine {
                    x: 42
                    y: 63
                }
                PathMove {
                    x: 91
                    y: 50
                }
                PathLine {
                    x: 102
                    y: 63
                }
                PathLine {
                    x: 116
                    y: 63
                }
            }
        }
        Rectangle {
            x: 77
            y: 25
            width: 23
            height: root.awake ? 12 : 3
            color: Design.accent
            Tween on height {
                scope: root
                NumberAnimation {
                    duration: Motion.feedback
                    easing.type: Motion.roles.feedback.easing
                }
            }
        }
        Rectangle {
            x: 39
            y: 31
            width: 3
            height: 3
            color: Design.ink
        }
        Rectangle {
            x: 45
            y: 31
            width: 3
            height: 3
            color: Design.ink
        }
    }
    Rectangle {
        visible: root.ground
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 100 + 30 * root.progress
        height: 1
        color: Design.line
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.awake = true
        onExited: root.awake = false
        onClicked: {
            reaction.trigger();
            root.discovered();
        }
    }
    // Press in to 0.93, spring back with Qt's default OutBack overshoot, as before.
    Pulse {
        id: reaction
        name: "creature.press"
        scope: root
        attack: Motion.pressIn
        release: Motion.pressOut
        attackEasing: Motion.linear
        releaseEasing: Motion.expressive
        overshoot: 1.70158
    }
}
