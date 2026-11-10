import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract
import qs.view.cues

// The satellites (DAILY_DRIVER §5, D18): timer or session, DONE and track change. One surface,
// loaded only while some kind is due; inside it, one Loader per kind, active only while due.
// Idle, there is no surface, timer or animation (the "zero FART surfaces" budget).
Scope {
    id: root
    required property CoreClient core
    required property HostAdapter host
    property bool panelOpen: false
    // A click on the timer or track card opens that room (Overlay opens the panel).
    signal openRoom(string page)
    // The surface: Overlay passes a SatelliteWindow (a layer surface); the offscreen harness a
    // FloatingWindow. Referencing PanelWindow here would make this type unloadable offscreen.
    required property Component surface
    readonly property SatelliteState state: SatelliteState { core: root.core; host: root.host; panelOpen: root.panelOpen }
    // FART surfaces this process holds for satellites (0 or 1), for the idle check.
    readonly property int surfaces: window.active && window.item ? 1 : 0
    readonly property var shown: [timer.active ? "timer" : "", done.active ? "done" : "", track.active ? "track" : ""].filter(k => k)

    Loader {
        id: window
        active: root.state.anyDue
        sourceComponent: root.surface
        onLoaded: cards.parent = item.contentItem
    }
    Column {
        id: cards
        spacing: 6
        Loader {
            id: done
            active: root.state.doneDue
            sourceComponent: SatelliteCard {
                value: root.state.doneText
                inverted: true
                flash: true
                onActivated: root.state.ack()
            }
        }
        Loader {
            id: timer
            active: root.state.timerDue
            sourceComponent: SatelliteCard {
                label: root.state.timerLabel
                value: root.state.timerText
                detail: root.state.taskText
                onActivated: root.openRoom("timers")
            }
        }
        Loader {
            id: track
            active: root.state.trackDue
            sourceComponent: SatelliteCard {
                value: root.state.trackText
                fade: true
                onActivated: root.openRoom("media")
            }
        }
    }
}
