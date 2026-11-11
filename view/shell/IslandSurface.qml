import QtQuick
import Quickshell
import qs.view.contract
import qs.core.client
import qs.view.cues
import qs.view.ui
import "../ui/FocusMap.js" as FocusMap

FocusScope {
    id: root
    required property HostAdapter host
    property bool bottomEdge: false
    property string motionLevel: "all"
    property bool systemVoice: true
    property real maximumWidth: Infinity
    property real dockedWidth: 0
    property bool pointerInside: hover.hovered
    property bool keyboardMode: false
    property bool hoverOpen: false
    property var workspaceIds: []
    property bool overdriveActive: false
    property CoreClient core: null
    property var startupNotice: null
    property bool trayOpen: false
    property var shownEvent: null
    property var outgoingEvent: null
    property var replyDrafts: ({})
    readonly property var expansion: queue.current
    readonly property int draftLength: (replyDrafts[expansion?.id] ?? "").length
    readonly property bool noticeVisible: expansion?.kind === "notification" || expansion?.kind === "critical"
    readonly property bool keyboardFocus: keyboardMode
    readonly property int fadeDuration: motionLevel === "off" ? 0 : Math.min(120, Motion.feedback)
    readonly property bool wings: hoverOpen || keyboardMode || trayOpen
    readonly property bool geometryMotion: motionLevel === "all" || motionLevel === "reduced"
    readonly property int morphDuration: geometryMotion ? Motion.emphasis : 0
    readonly property int morphEasing: motionLevel === "all" ? Motion.roles.emphasis.easing : Easing.OutCubic
    readonly property int centreWidth: 420
    readonly property int restHeight: 36
    readonly property int wingSpan: Math.max(224, 64 + host.tray.items.length * (Design.minHit + 8))
    signal openPanel(string room)
    signal togglePanel(string room)
    signal openPower()
    signal ignite()
    signal openTray(string itemId)
    signal openLog(string url)
    signal notificationAction(string id, string action, string reply)

    implicitWidth: Math.min(maximumWidth, Math.max(dockedWidth, expansion ? (eventPane.item?.implicitWidth ?? centreWidth)
        : centreWidth + (wings ? 2 * wingSpan : 0)))
    implicitHeight: expansion ? (eventPane.item?.implicitHeight ?? restHeight) : restHeight
    width: implicitWidth
    height: implicitHeight

    Tween on width {
        scope: root
        enabled: root.geometryMotion && Motion.live(root)
        NumberAnimation {
            duration: root.morphDuration
            easing.type: root.morphEasing
            easing.overshoot: Motion.roles.emphasis.overshoot
        }
    }

    Tween on height {
        scope: root
        enabled: root.geometryMotion && Motion.live(root)
        NumberAnimation {
            duration: root.morphDuration
            easing.type: root.morphEasing
            easing.overshoot: Motion.roles.emphasis.overshoot
        }
    }

    IslandQueue {
        id: queue
        hovered: root.pointerInside
        onEntriesChanged: {
            const keep = {};
            const ids = entries.map(event => event.id);
            for (const id of Object.keys(root.replyDrafts)) {
                if (ids.includes(id)) keep[id] = root.replyDrafts[id];
            }
            if (Object.keys(keep).length !== Object.keys(root.replyDrafts).length)
                root.replyDrafts = keep;
        }
    }
    IslandEvents {
        id: events
        host: root.host
        queue: queue
        workspaceIds: root.workspaceIds
        core: root.core
        startupNotice: root.startupNotice
    }

    onExpansionChanged: {
        if (expansion?.id === shownEvent?.id && expansion?.kind === shownEvent?.kind) {
            shownEvent = expansion;
            return;
        }
        outgoingEvent = shownEvent;
        shownEvent = expansion;
        eventFade.value = 0;
        eventFade.retarget();
    }
    Cue {
        id: eventFade
        on: true
        scope: root
        name: "island.event"
        enter: root.fadeDuration
        onSettled: root.outgoingEvent = null
    }

    IslandFrame {
        anchors.fill: parent
        bottomEdge: root.bottomEdge
    }
    MouseArea {
        id: gesture
        anchors.fill: parent
        enabled: !root.expansion
        pressAndHoldInterval: 600
        property bool held: false
        onPressed: held = false
        onPressAndHold: {
            held = true;
            root.ignite();
        }
        onClicked: {
            if (held) return;
            root.keyboardMode = false;
            const timers = root.core?.timersData;
            const room = root.host.media.active?.playing ? "media"
                : timers?.countdown?.running || timers?.pomodoro?.running ? "timers" : "home";
            root.togglePanel(room);
        }
    }

    Cue {
        id: ignition
        on: gesture.pressed && !gesture.held
        scope: root
        name: "island.ignite"
        enter: root.motionLevel === "off" ? 0 : 600
        exit: 0
        easing: Easing.Linear
    }
    Rectangle {
        anchors.bottom: root.bottomEdge ? undefined : parent.bottom
        anchors.top: root.bottomEdge ? parent.top : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        width: (parent.width - 12) * (root.overdriveActive ? 1 : root.motionLevel === "off" ? 0 : ignition.value)
        height: 1
        color: Design.accent
    }

    readonly property bool restVisible: !shownEvent || !outgoingEvent && eventFade.value < 1
    Loader {
        anchors.centerIn: parent
        width: Math.min(parent.width, root.centreWidth)
        height: root.restHeight
        active: !root.shownEvent || root.restVisible
        opacity: root.shownEvent ? 1 - eventFade.value : root.outgoingEvent ? eventFade.value : 1
        enabled: !root.expansion
        sourceComponent: IslandRest {
            host: root.host
            wings: root.wings && !root.expansion
            live: !root.expansion
            onOpenPanel: room => {
                root.keyboardMode = false;
                root.openPanel(room);
            }
            onOpenPower: {
                root.keyboardMode = false;
                root.openPower();
            }
        }
    }

    Loader {
        anchors.centerIn: parent
        width: Math.min(parent.width, item?.implicitWidth ?? 0)
        height: item?.implicitHeight ?? 0
        active: !!root.outgoingEvent
        opacity: 1 - eventFade.value
        enabled: false
        sourceComponent: IslandExpansion {
            event: root.outgoingEvent
            systemVoice: root.systemVoice
            replyDraft: root.replyDrafts[event?.id] ?? ""
        }
    }

    Loader {
        id: eventPane
        anchors.centerIn: parent
        width: Math.min(parent.width, item?.implicitWidth ?? 0)
        height: item?.implicitHeight ?? 0
        active: !!root.shownEvent
        opacity: eventFade.value
        sourceComponent: IslandExpansion {
            event: root.shownEvent
            systemVoice: root.systemVoice
            replyDraft: root.replyDrafts[event?.id] ?? ""
            onReplyEdited: text => {
                if (!event) return;
                root.replyDrafts = Object.assign({}, root.replyDrafts, { [event.id]: text });
            }
            memoryPinned: events.memoryPinned
            onPinMemory: events.memoryPinned = !events.memoryPinned
            onDismiss: {
                if (root.expansion?.kind === "done") root.core?.timers.ack();
                if (root.expansion?.kind === "debrief") root.core?.request("session.dismiss", {});
                if (root.expansion) queue.remove(root.expansion.id);
            }
            onOpenLog: url => root.openLog(url)
            onNotificationAction: (id, action, reply) => root.notificationAction(id, action, reply)
        }
    }
    clip: true
    WheelHandler {
        enabled: root.noticeVisible
        onWheel: event => {
            if (root.bottomEdge ? event.angleDelta.y < 0 : event.angleDelta.y > 0)
                queue.remove(root.expansion.id);
        }
    }
    DragHandler {
        enabled: root.noticeVisible
        target: null
        onTranslationChanged: {
            const towardEdge = root.bottomEdge ? translation.y : -translation.y;
            if (active && towardEdge >= Design.minHit && root.noticeVisible)
                queue.remove(root.expansion.id);
        }
    }

    function focusables(item, controls): void {
        if (!item.visible || !item.enabled) return;
        if (item.activeFocusOnTab && item.width > 0 && item.height > 0)
            controls.push(item);
        for (const child of item.children) focusables(child, controls);
    }

    function enterKeyboard(): void {
        keyboardMode = true;
        forceActiveFocus();
        Qt.callLater(() => root.moveFocus("right"));
    }

    function moveFocus(direction: string): void {
        const controls = [];
        focusables(root, controls);
        const active = root.Window.window?.activeFocusItem;
        const rects = controls.map(item => item.mapToItem(root, Qt.rect(0, 0, item.width, item.height)));
        const from = controls.indexOf(active);
        const next = from < 0 ? 0 : FocusMap.pick(rects[from], rects, direction);
        controls[next]?.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (!root.keyboardMode) return;
        const directions = {
            [Qt.Key_Left]: "left", [Qt.Key_H]: "left", [Qt.Key_Right]: "right", [Qt.Key_L]: "right",
            [Qt.Key_Up]: "up", [Qt.Key_K]: "up", [Qt.Key_Down]: "down", [Qt.Key_J]: "down"
        };
        if (event.key === Qt.Key_Escape) {
            root.keyboardMode = false;
            root.focus = false;
        } else if (directions[event.key]) {
            root.moveFocus(directions[event.key]);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const active = root.Window.window?.activeFocusItem;
            if (typeof active?.clicked !== "function") return;
            active.clicked();
        } else {
            return;
        }
        event.accepted = true;
    }

    Loader {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Design.baseline
        active: root.overdriveActive && root.wings && !root.expansion && !!root.core?.overdriveData?.requested?.until
        sourceComponent: FText {
            technical: true
            color: Design.accent
            text: Clock.formatSeconds((root.core.overdriveData.requested.until - leaseClock.date.getTime()) / 1000)
            SystemClock { id: leaseClock; precision: SystemClock.Seconds }
        }
    }
    HoverHandler { id: hover }
    Timer {
        running: root.pointerInside && !root.hoverOpen
        interval: 300
        onTriggered: root.hoverOpen = true
    }
    onPointerInsideChanged: if (!pointerInside) hoverOpen = false

    Cue {
        id: reveal
        on: root.wings && !root.expansion
        scope: root
        name: "island.wings"
        enter: root.fadeDuration
    }
    Loader {
        anchors.fill: parent
        active: (root.wings && !root.expansion) || reveal.value > 0
        opacity: reveal.value
        enabled: root.wings && !root.expansion
        sourceComponent: IslandWings {
            host: root.host
            centreWidth: root.centreWidth
            onOpenDevices: {
                root.keyboardMode = false;
                root.openPanel("devices");
            }
            onOpenTray: itemId => root.openTray(itemId)
        }
    }
}
