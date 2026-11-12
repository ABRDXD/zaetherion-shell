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
    // The panel is open from this island: the island has grown into it (Overlay draws the growth), so its own row
    // fades out and hover stays shut until the panel folds back.
    property bool docked: false
    // Flush against the screen edge (notch), the black island merges with the bezel, so the space on the edge side
    // reads larger than it is. Content sits this much towards the edge to look centred; none when floating.
    property bool notch: true
    readonly property int lift: notch ? 3 : 0
    readonly property int liftOffset: bottomEdge ? lift : -lift
    // The width the island had when the panel took over: it holds it while docked, so the growth starts from and
    // folds back into exactly that shape, then eases to its natural width.
    property real dockWidth: 0
    onDockedChanged: if (docked) dockWidth = width
    property bool pointerInside: hover.hovered
    property bool keyboardMode: false
    property bool hoverOpen: false
    property var workspaceIds: []
    property bool overdriveActive: false
    property string arrangement: "framed"
    property CoreClient core: null
    property var startupNotice: null
    property bool trayOpen: false
    property var shownEvent: null
    property var outgoingEvent: null
    property var replyDrafts: ({})
    readonly property var expansion: queue.current
    readonly property int draftLength: (replyDrafts[expansion?.id] ?? "").length
    readonly property bool noticeVisible: expansion?.kind === "notification" || expansion?.kind === "critical"
    // Keyboard interactivity for the layer. A queued reply draft keeps OnDemand through pre-emption:
    // dropping to None and back strands a resting pointer, so Hyprland never refocuses on click.
    readonly property bool replyHeld: noticeVisible || queue.entries.some(event =>
        (event.kind === "notification" || event.kind === "critical") && !!replyDrafts[event.id])
    property string replyFocusId: ""
    property bool focusClaim: false
    readonly property bool windowActive: Window.active
    // A docked panel holds Exclusive. The island announces that it wants the keyboard, the panel lets go,
    // and the island claims it a moment later: Hyprland does not hand focus to an Exclusive layer that
    // committed while another Exclusive one still held it.
    property bool keyboardPeer: false
    readonly property bool wantsKeyboard: keyboardMode || focusClaim
    property bool peerSettled: true
    onKeyboardPeerChanged: {
        peerSettled = keyboardPeer;
        if (!keyboardPeer) peerSettle.restart();
    }
    Timer {
        id: peerSettle
        interval: 60
        onTriggered: root.peerSettled = true
    }
    readonly property string keyboardRequest: wantsKeyboard && !keyboardPeer && peerSettled ? "exclusive"
        : replyHeld ? "ondemand" : "none"
    onWindowActiveChanged: {
        if (windowActive) focusClaim = false;
        else if (!noticeVisible) replyFocusId = "";
    }
    // The field took Qt focus but the compositor did not hand over the keyboard: claim it once.
    Timer {
        running: root.focusClaim
        interval: 400
        onTriggered: root.focusClaim = false
    }
    function replyFocus(id: string, focused: bool): void {
        if (focused) {
            replyFocusId = id;
            if (!windowActive) focusClaim = true;
        } else if (expansion?.id === id && replyFocusId === id) {
            replyFocusId = "";
        }
    }
    readonly property int fadeDuration: motionLevel === "off" ? 0 : Math.min(120, Motion.feedback)
    readonly property bool wings: !docked && (hoverOpen || keyboardMode || trayOpen)
    readonly property bool geometryMotion: motionLevel === "all" || motionLevel === "reduced"
    readonly property int morphDuration: geometryMotion ? Motion.emphasis : 0
    readonly property int morphEasing: motionLevel === "all" ? Motion.roles.emphasis.easing : Easing.OutCubic
    // Z66 keeps the resting width. Hovered, the centre opens by 40 px a side so the media pill keeps its room
    // when the clock gains seconds; the wings sit outside it.
    // Fluid rests compact (Z145): the clock alone, or the media row while a player plays.
    readonly property bool playing: !!host.media.active?.playing
    readonly property int hoverCentre: 500
    // Fluid at rest shows the clock or, while a player plays, the media (right-click switches).
    property bool preferClock: false
    readonly property int centreWidth: wings && !expansion ? hoverCentre : Design.fluid ? (restPane.item?.compactWidth ?? 100) : 420
    readonly property int restHeight: 36
    // Wide enough for the fuller side of the hovered row, actions at the shoulders included (IslandRest.sideNeed),
    // past half the hovered centre.
    readonly property int wingSpan: Math.max(Design.minHit, Math.ceil((restPane.item?.sideNeed ?? 0) - hoverCentre / 2))
    signal openPanel(string room)
    signal togglePanel(string room)
    signal openPower()
    signal ignite()
    signal openTray(string itemId)
    signal openLog(string url)
    signal notificationAction(string id, string action, string reply)

    implicitWidth: docked && dockWidth > 0 ? dockWidth
        : Math.min(maximumWidth, Math.max(0, expansion ? (eventPane.item?.implicitWidth ?? centreWidth)
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property bool held: false
        onPressed: held = false
        onPressAndHold: mouse => {
            if (mouse.button !== Qt.LeftButton) return;
            held = true;
            root.ignite();
        }
        onClicked: mouse => {
            if (held) return;
            // Fluid: right-click switches the resting view between the media and the clock.
            if (mouse.button === Qt.RightButton) {
                if (Design.fluid) root.preferClock = !root.preferClock;
                return;
            }
            root.keyboardMode = false;
            const timers = root.core?.timersData;
            const room = root.host.media.active?.playing ? "media"
                : timers?.countdown?.running || timers?.pomodoro?.running ? "timers" : "home";
            root.togglePanel(room);
        }
    }

    Cue {
        id: ignition
        on: gesture.pressed && !gesture.held && (gesture.pressedButtons & Qt.LeftButton)
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
        id: restPane
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.liftOffset
        width: Math.min(parent.width, root.centreWidth)
        height: root.restHeight
        active: !root.shownEvent || root.restVisible
        opacity: (root.shownEvent ? 1 - eventFade.value : root.outgoingEvent ? eventFade.value : 1) * undocked.value
        enabled: !root.expansion && !root.docked
        sourceComponent: IslandRest {
            host: root.host
            preferClock: root.preferClock
            arrangement: root.arrangement
            reveal: wingReveal.value
            onOpenTray: itemId => root.openTray(itemId)
            reach: Math.max(0, (root.width - root.centreWidth) / 2)
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
            bottomEdge: root.bottomEdge
            lift: root.lift
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
            bottomEdge: root.bottomEdge
            lift: root.lift
            systemVoice: root.systemVoice
            replyDraft: root.replyDrafts[event?.id] ?? ""
            restoreReplyFocus: !!event && root.replyFocusId === event.id
            onReplyFocused: focused => root.replyFocus(String(event?.id ?? ""), focused)
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
        id: undocked
        on: !root.docked
        scope: root
        name: "island.dock"
        enter: root.fadeDuration
        exit: root.fadeDuration
    }
    Cue {
        id: wingReveal
        on: root.wings && !root.expansion
        scope: root
        name: "island.wings"
        enter: root.fadeDuration
    }
}
