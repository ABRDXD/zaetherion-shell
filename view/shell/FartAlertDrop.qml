import QtQuick
import qs.view.cues
import qs.view.ui

// Z161: while FART is grown from the island it covers the island, so a critical event shows inside FART:
// the header flashes red once and the event's card drops down from under the header. Nothing leaves FART.
Item {
    id: root
    // The critical event the island hands over, or null.
    property var event: null
    // The header strip the card drops from, in this item's coordinates (Shell.headerBottom).
    property real headerHeight: 0
    property bool systemVoice: true
    signal dismissed(string id)
    signal notificationAction(string id, string action, string reply)

    // The card keeps the last event while it slides back up.
    property var shown: null
    onEventChanged: {
        if (event) {
            shown = event;
            flash.fire();
        }
    }
    Cue {
        id: drop
        on: !!root.event
        scope: root
        name: "fart.alert"
        enter: Motion.navigate
        exit: Motion.feedback
        onSettled: if (!on) root.shown = null
    }
    CriticalFlash {
        id: flash
        still: Motion.navigate === 0
    }

    // The header flashes red once.
    Rectangle {
        width: root.width
        height: root.headerHeight
        color: Design.danger
        visible: flash.value > 0
        opacity: flash.value * 0.55
    }

    // The card drops from under the header, clipped so it never shows above it.
    Item {
        id: well
        y: root.headerHeight
        width: root.width
        height: card.height + 16
        clip: true
        visible: !!root.shown
        Item {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            width: face.item?.implicitWidth ?? 0
            height: face.item?.implicitHeight ?? 0
            y: (drop.value - 1) * (height + 16)
            IslandFrame {
                anchors.fill: parent
                fill: Design.islandFill
            }
            // A red rule along the top marks it critical for as long as it shows.
            Rectangle {
                width: parent.width
                height: 2
                color: Design.danger
            }
            Loader {
                id: face
                active: !!root.shown
                sourceComponent: IslandExpansion {
                    event: root.shown
                    systemVoice: root.systemVoice
                    onDismiss: if (root.shown) root.dismissed(String(root.shown.id))
                    onNotificationAction: (id, action, reply) => root.notificationAction(id, action, reply)
                }
            }
        }
    }
}
