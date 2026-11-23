import QtQuick
import QtQuick.Controls
import Quickshell
import qs.view.cues
import qs.view.ui
import qs.core.client
import qs.view.contract
import "LauncherLayout.js" as LauncherLayout
import "WorkspaceLayout.js" as WorkspaceLayout

Item {
    id: root
    required property var event
    readonly property var payload: event?.data ?? ({})
    // Notices waiting behind the shown one (after Sonner): drawn as card edges under it, listed when it is hovered.
    property var waiting: []
    readonly property string kind: event?.kind ?? ""
    signal notificationAction(string id, string action, string reply)
    // A notification's picture is on screen: the adapter may want to keep it (NotificationsDomain.keepImage).
    signal pictureShown(string id, Item picture)
    signal replyEdited(string text)
    signal replyFocused(bool focused)
    property bool restoreReplyFocus: false
    property var privacy: []
    signal openRoom(string room)
    signal dismiss()
    signal openLog(string url)
    signal pinMemory()
    property bool memoryPinned: false
    property bool systemVoice: true
    property bool bottomEdge: false
    // Optical shift towards the screen edge for a flush notch (IslandSurface.lift).
    property int lift: 0
    property string replyDraft: ""
    // A tray item's menu, grown from the island (Z157).
    property var trayEntries: []
    signal trayClose()
    signal trayChoose(string entryId)
    readonly property bool trayKind: kind === "tray"
    // The session card (Z158): lock on a click, the rest on a 1 s hold, as host power menus confirm them.
    // FART's settings at a section: a prompt event's click (docs/NET_BT.md §5).
    signal openSettings(string section)
    signal sessionAction(string action)
    // Quick paste (S3): the clipboard grown from the island, a held face like the session card. Its clipboard is the
    // launcher's `clipboard` below.
    property var clipSettings: ({})
    readonly property bool clipsKind: kind === "clips"
    signal clipPaste(string id)
    signal clipCopy(string id)
    signal clipRoom(string query)
    readonly property int holdMs: 1000
    readonly property int deepest: 160
    // The launcher (S6): the core that ranks, the apps it starts, and how many rows it shows.
    property CoreClient core: null
    property AppsDomain apps: null
    property ClipboardDomain clipboard: null
    property LauncherDomain launcherEngine: null
    property int launcherRows: 6
    signal launcherClose()

    function voice(line: string): string {
        if (systemVoice) return line;
        const clean = line.replace(/^>\s*/, "").replace(/ · /g, " — ").toLowerCase();
        return clean.charAt(0).toUpperCase() + clean.slice(1);
    }

    // Width and resting depth of each face. A notification grows by a line when its body wraps.
    function shape(kind: string): size {
        switch (kind) {
        case "notification":
        case "critical": return Qt.size(496, 124);
        case "memory": return Qt.size(448, 140);
        case "osd": return Qt.size(444, 56);
        case "workspace": return Qt.size(WorkspaceLayout.width, WorkspaceLayout.depth);
        case "timer":
        case "done":
        case "track": return Qt.size(438, 49);
        case "launcher": return Qt.size(LauncherLayout.contentWidth + 2 * launcherInset, LauncherLayout.depth(launcherRows, edgePad));
        case "session": return Qt.size(5 * 88 + 2 * 16 + (Design.fluid ? 0 : 2 * Math.ceil(12 + 76 / Math.tan(84 * Math.PI / 180))), 76);
        default: return Qt.size(420, 56);
        }
    }
    readonly property bool transitKind: ["timer", "done", "track"].includes(kind)
    readonly property bool noticeKind: kind === "notification" || kind === "critical"
    // The pointer is over the notification card itself (Z175); the island pauses a notification's countdown only then.
    readonly property bool noticeHovered: noticeKind && (face.item?.cardHovered ?? false)
    // Content keeps clear of the 84° shoulders at the deepest row. The frame is matte, with no facet to clear.
    readonly property real shoulderSlope: 1 / Math.tan(84 * Math.PI / 180)
    // A notice is sized by its text, so its inset uses the deepest notice, not its own depth.
    // The launcher's inset is its own depth's, worked out without shape() (which needs the inset for its width).
    readonly property real launcherInset: Design.fluid ? 16 : Math.ceil(12 + LauncherLayout.depth(launcherRows, edgePad) * shoulderSlope)
    readonly property real sideInset: Design.fluid ? 16 : kind === "launcher" ? launcherInset
        : Math.ceil(12 + (noticeKind ? 140 : clipsKind ? implicitHeight : shape(kind).height) * shoulderSlope)
    readonly property int edgePad: LauncherLayout.edgePad
    readonly property int facet: 0
    readonly property real noticeContent: noticeKind && face.item ? face.item.implicitHeight : 0
    implicitWidth: trayKind ? 248 + 2 * sideInset : clipsKind ? (face.item?.implicitWidth ?? 600) + 2 * sideInset : shape(kind).width
    implicitHeight: clipsKind ? (face.item?.implicitHeight ?? 0) + 2 * edgePad : trayKind ? Math.min(deepest, Math.max(shape(kind).height, (face.item?.implicitHeight ?? 0) + 2 * edgePad))
        : noticeKind
        ? Math.max(shape(kind).height, Math.ceil((noticeContent + 2 * edgePad + facet) / Design.baseline) * Design.baseline)
        : shape(kind).height

    readonly property var faceItem: face.item
    Loader {
        id: face
        anchors.fill: parent
        anchors.leftMargin: root.transitKind ? 0 : root.sideInset
        anchors.rightMargin: root.transitKind ? 0 : root.sideInset
        anchors.topMargin: root.transitKind ? 0 : root.edgePad + (root.bottomEdge ? root.facet + root.lift : -root.lift)
        anchors.bottomMargin: root.transitKind ? 0 : root.edgePad + (root.bottomEdge ? -root.lift : root.facet + root.lift)
        sourceComponent: {
            switch (root.kind) {
            case "notification":
            case "critical": return notice;
            case "osd": return osd;
            case "timer":
            case "done":
            case "track": return transit;
            case "workspace": return workspaces;
            case "memory": return memory;
            case "recording": return recording;
            case "tray": return tray;
            case "session": return session;
            case "launcher": return launcher;
            case "clips": return clips;
            default: return status;
            }
        }
    }

    // A primary action: the sheet's inversion, as a tag. Hover and focus turn it to signal.
    component TagAction: AbstractButton {
        id: action
        property string label: ""
        implicitWidth: Math.max(Design.minHit * 2, tag.implicitWidth)
        implicitHeight: Design.minHit
        padding: 0
        hoverEnabled: true
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        onClicked: Feedback.play("ui.click")
        contentItem: FTag {
            id: tag
            text: action.label
            role: action.hovered || action.activeFocus || action.down ? "signal" : "ink"
        }
    }

    // One session action. The hold is timed by a plain Timer, never by motion, so reduced or no motion cannot
    // shorten it; the fill only shows it.
    component SessionAction: AbstractButton {
        id: act
        property string glyph: ""
        property string label: ""
        property string verb: ""
        property bool needsHold: true
        property bool keyHeld: false
        readonly property bool holding: needsHold && (pressed || keyHeld)
        implicitWidth: 88
        implicitHeight: 56
        padding: 0
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: needsHold ? "Hold to " + label.toLowerCase() : label
        onClicked: if (!needsHold) root.sessionAction(verb)
        function confirmKey(event): bool {
            return event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space;
        }
        // Left and right step along the row (wrapping); the row is not a focus scope, so each action moves itself.
        function step(by: int): void {
            const row = parent.children.filter(item => item.verb !== undefined);
            row[(row.indexOf(act) + by + row.length) % row.length].forceActiveFocus();
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                event.accepted = true;
                keyHeld = false;
                step(event.key === Qt.Key_Right ? 1 : -1);
                return;
            }
            if (!confirmKey(event)) return;
            event.accepted = true;
            if (event.isAutoRepeat) return;
            if (needsHold) keyHeld = true;
            else root.sessionAction(verb);
        }
        Keys.onReleased: event => {
            if (!confirmKey(event) || event.isAutoRepeat) return;
            event.accepted = true;
            keyHeld = false;
        }
        onActiveFocusChanged: if (!activeFocus) keyHeld = false
        // The rising charge sounds while the hold runs and is cut the moment it is released early.
        onHoldingChanged: {
            if (holding) Feedback.play("hold.charge");
            else Feedback.stop("hold.charge");
        }
        Timer {
            running: act.holding
            interval: root.holdMs
            onTriggered: {
                act.keyHeld = false;
                Feedback.stop("hold.charge");
                Feedback.play("hold.confirm");
                root.sessionAction(act.verb);
            }
        }
        Cue {
            id: fill
            on: act.holding
            scope: act
            name: "island.hold"
            enter: root.holdMs
            exit: 0
            easing: Easing.Linear
        }
        readonly property bool lit: hovered || activeFocus || holding
        contentItem: Item {
            MaterialSymbol {
                id: actGlyph
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                fill: Design.iconFill
                weight: Design.iconWeight
                text: act.glyph
                iconSize: 5 * Design.baseline
                color: act.lit ? (act.needsHold ? Design.danger : Design.ink) : Design.muted
            }
            FText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: actGlyph.bottom
                anchors.topMargin: 2
                technical: true
                font.pixelSize: Design.caption
                text: act.holding ? root.voice("> HOLD") : root.voice(act.label)
                color: act.lit ? Design.ink : Design.muted
            }
        }
        background: Item {
            Rectangle {
                anchors.fill: parent
                radius: Design.fluid ? Design.roundSmall : 0
                color: Design.hover
                visible: act.hovered || act.activeFocus
            }
            Rectangle {
                anchors.bottom: parent.bottom
                height: 2
                width: parent.width * fill.value
                color: Design.danger
            }
        }
    }

    Component {
        id: launcher
        LauncherFace {
            core: root.core
            apps: root.apps
            clipboard: root.clipboard
            engine: root.launcherEngine
            rows: root.launcherRows
            onClose: root.launcherClose()
        }
    }

    Component {
        id: session
        Row {
            anchors.centerIn: parent
            spacing: 0
            Component.onCompleted: lockAction.forceActiveFocus()
            Keys.onEscapePressed: root.dismiss()
            SessionAction { id: lockAction; glyph: "lock"; label: "> LOCK"; verb: "lock"; needsHold: false }
            SessionAction { glyph: "bedtime"; label: "> SUSPEND"; verb: "suspend" }
            SessionAction { glyph: "logout"; label: "> LOG OUT"; verb: "logout" }
            SessionAction { glyph: "restart_alt"; label: "> REBOOT"; verb: "reboot" }
            SessionAction { glyph: "power_settings_new"; label: "> POWER OFF"; verb: "powerOff" }
        }
    }

    Component {
        id: clips
        IslandClips {
            clipboard: root.clipboard
            systemVoice: root.systemVoice
            rows: root.clipSettings.rows ?? 6
            enterPastes: root.clipSettings.enterPastes ?? false
            showImages: root.clipSettings.showImages ?? true
            onDismiss: root.dismiss()
            onPaste: id => root.clipPaste(id)
            onCopy: id => root.clipCopy(id)
            onOpenRoom: query => root.clipRoom(query)
        }
    }

    Component {
        id: tray
        IslandTrayMenu {
            framed: false
            maximumHeight: root.deepest - 2 * root.edgePad
            entries: root.trayEntries
            onCloseRequested: root.trayClose()
            onChoose: entryId => root.trayChoose(entryId)
            Component.onCompleted: forceActiveFocus()
        }
    }

    Component {
        id: notice
        Item {
            id: card
            objectName: "noticeCard"
            readonly property bool critical: root.kind === "critical"
            readonly property var actions: root.payload.actions ?? []
            readonly property bool replies: !!root.payload.reply
            implicitHeight: column.implicitHeight + stack.height
            readonly property bool cardHovered: cardHover.hovered
            // Whether the waiting notices are fanned out under the card: while it is hovered.
            property bool fan: cardHovered
            HoverHandler { id: cardHover }

            // A sideways flick sends the card off the island (after Sonner); the Inbox keeps it. Short of the
            // threshold it springs back. Right-click still dismisses it from the Inbox too.
            property real flick: 0
            x: flick
            opacity: 1 - Math.min(0.8, Math.abs(flick) / Math.max(1, width))
            DragHandler {
                id: flicker
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onTranslationChanged: if (active) card.flick = translation.x
                onActiveChanged: if (!active) card.release()
            }
            // Let go: past 30 % of the card's width it flies off and leaves the island, else it springs back.
            function release(): void {
                const away = Math.abs(flick) > width * 0.3;
                settle.to = away ? Math.sign(flick) * width * 1.1 : 0;
                settle.away = away;
                if (!Motion.live(card)) { flick = 0; if (away) root.dismiss(); return; }
                settle.restart();
            }
            NumberAnimation {
                id: settle
                property bool away: false
                target: card
                property: "flick"
                duration: Motion.scaled(220)
                easing.type: away ? Easing.InCubic : Easing.OutBack
                onFinished: if (away) { card.flick = 0; root.dismiss(); }
            }
            Activity { name: "island.settle"; running: settle.running }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.notificationAction(String(root.payload.id), "default", "");
                    root.dismiss();
                }
            }
            Column {
                id: column
                width: parent.width
                spacing: Design.baseline

                Item {
                    width: parent.width
                    height: appTag.height
                    // The app's own name, inverted (Z144; SURFACES §1 "app tag").
                    FTag {
                        id: appTag
                        width: Math.min(implicitWidth, parent.width - voiceLine.implicitWidth - 3 * Design.baseline)
                        symbol: card.critical ? "priority_high" : "notifications"
                        text: root.payload.appName || "NOTICE"
                        role: card.critical ? "signal" : "ink"
                    }
                    FText {
                        id: voiceLine
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        technical: true
                        color: card.critical ? Design.accent : Design.muted
                        font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                        text: root.voice(card.critical ? "> INBOX · URGENT" : "> INBOX")
                    }
                }
                Item {
                    width: parent.width
                    height: Math.max(copy.implicitHeight, illustration.visible ? illustration.height : 0)
                    Column {
                        id: copy
                        anchors.left: parent.left
                        anchors.right: illustration.visible ? illustration.left : parent.right
                        anchors.rightMargin: illustration.visible ? 3 * Design.baseline : 0
                        spacing: 2
                        FText {
                            width: parent.width
                            font.pixelSize: Design.control
                            text: root.payload.summary ?? ""
                        }
                        FText {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            color: Design.muted
                            font.capitalization: Font.MixedCase
                            text: root.payload.body ?? ""
                        }
                    }
                    Image {
                        id: illustration
                        visible: source.toString() !== ""
                        anchors.right: parent.right
                        width: 40
                        height: width
                        source: root.payload.image ?? ""
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        onStatusChanged: if (status === Image.Ready) root.pictureShown(String(root.payload.id), illustration)
                    }
                }
                // The sheet's notched rule in Angular; a plain hairline in Fluid.
                FRule {
                    visible: actionRow.visible && !Design.fluid
                    width: parent.width
                    color: card.critical ? Design.accent : Design.line
                }
                Rectangle {
                    visible: actionRow.visible && Design.fluid
                    width: parent.width
                    height: 1
                    color: card.critical ? Design.accent : Design.line
                }
                Row {
                    id: actionRow
                    visible: card.actions.length > 0 || card.replies
                    width: parent.width
                    height: Design.minHit
                    spacing: 2 * Design.baseline

                    Repeater {
                        model: card.actions.slice(0, 1)
                        TagAction {
                            required property var modelData
                            label: modelData.label
                            onClicked: root.notificationAction(String(root.payload.id), modelData.id, "")
                        }
                    }
                    Repeater {
                        model: card.actions.slice(1, 3)
                        FButton {
                            required property var modelData
                            height: Design.minHit
                            label: modelData.label
                            onClicked: root.notificationAction(String(root.payload.id), modelData.id, "")
                        }
                    }
                    Item {
                        visible: card.replies
                        height: Design.minHit
                        width: actionRow.width - x
                        FField {
                            id: reply
                            anchors.fill: parent
                            implicitHeight: Design.minHit
                            rightPadding: send.width + 2 * Design.baseline
                            font.pixelSize: Design.body
                            placeholderText: root.systemVoice ? "REPLY…" : "Reply…"
                            // The sheet's cut-corner field in Angular; a rounded one in Fluid.
                            background: Item {
                                FFrame {
                                    anchors.fill: parent
                                    visible: !Design.fluid
                                    fillColor: Design.surface
                                    lineColor: reply.activeFocus ? Design.accent : Design.line
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: Design.fluid
                                    radius: height / 2
                                    color: Design.surface
                                    border.width: 1
                                    border.color: reply.activeFocus ? Design.accent : Design.line
                                }
                            }
                            text: root.replyDraft
                            onTextEdited: root.replyEdited(text)
                            onAccepted: send.submit()
                            onActiveFocusChanged: root.replyFocused(activeFocus)
                            Component.onCompleted: {
                                // The field returns from a pre-emption with the caret where the owner left it.
                                if (root.restoreReplyFocus)
                                    Qt.callLater(() => { if (reply.visible) reply.forceActiveFocus(); });
                            }
                        }
                        AbstractButton {
                            id: send
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: sendLabel.implicitWidth + 4 * Design.baseline
                            enabled: reply.text.trim() !== ""
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            Accessible.name: "Send reply"
                            function submit(): void {
                                if (!enabled) return;
                                root.notificationAction(String(root.payload.id), String(root.payload.reply), reply.text);
                                root.replyEdited("");
                                root.dismiss();
                            }
                            onClicked: submit()
                            contentItem: FText {
                                id: sendLabel
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                technical: true
                                text: "SEND"
                                color: send.enabled && send.hovered ? Design.accent : send.enabled ? Design.ink : Design.faint
                                opacity: send.enabled ? 1 : 0.6
                            }
                        }
                    }
                }
            }
            // The waiting notices: card edges under this one (one per waiting notice, at most two, each narrower), and
            // while the card is hovered, who they are from.
            Column {
                id: stack
                objectName: "noticeStack"
                anchors.top: column.bottom
                anchors.topMargin: root.waiting.length ? Design.baseline : 0
                width: parent.width
                height: root.waiting.length ? implicitHeight + Design.baseline : 0
                spacing: Design.baseline / 2
                visible: root.waiting.length > 0
                Repeater {
                    model: Math.min(2, root.waiting.length)
                    Rectangle {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: stack.width * (0.94 - 0.06 * index)
                        height: 2
                        radius: 1
                        color: Qt.alpha(Design.ink, 0.28 - 0.1 * index)
                    }
                }
                FText {
                    objectName: "noticeWaiting"
                    anchors.right: parent.right
                    visible: !card.fan
                    technical: true
                    font.pixelSize: Design.caption
                    color: Design.muted
                    text: "+" + root.waiting.length + (root.systemVoice ? " WAITING" : " waiting")
                }
                Repeater {
                    model: card.fan ? root.waiting.slice(0, 3) : []
                    Row {
                        required property var modelData
                        objectName: "noticeFan"
                        width: stack.width
                        spacing: 2 * Design.baseline
                        FText {
                            technical: true
                            font.pixelSize: Design.caption
                            color: Design.ink
                            text: modelData.data?.appName || "NOTICE"
                        }
                        FText {
                            width: parent.width - x
                            elide: Text.ElideRight
                            font.pixelSize: Design.caption
                            color: Design.muted
                            text: modelData.data?.summary ?? ""
                        }
                    }
                }
                FText {
                    visible: card.fan && root.waiting.length > 3
                    technical: true
                    font.pixelSize: Design.caption
                    color: Design.faint
                    text: "+" + (root.waiting.length - 3) + " more"
                }
            }
        }
    }

    Component {
        id: osd
        Item {
            readonly property string glyph: {
                const kind = root.payload.kind ?? "";
                if (kind === "mic") return root.payload.muted ? "mic_off" : "mic";
                if (kind === "brightness") return "brightness_medium";
                if (kind === "volume") return root.payload.muted ? "volume_off" : "volume_up";
                return "tune";
            }
            MaterialSymbol {
                fill: Design.iconFill
                weight: Design.iconWeight
                id: osdGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: parent.glyph
                iconSize: Design.readout
                color: Design.ink
            }
            FText {
                anchors.left: blades.left
                anchors.top: parent.top
                text: root.voice("> " + (root.payload.kind === "mic" ? "MICROPHONE" : root.payload.kind ?? ""))
                font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                color: Design.accent
                technical: true
            }
            // The level rolls as it moves (RollingDigits, after NumberFlow): up as the volume rises, down as it falls.
            Item {
                id: reading
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: level.implicitHeight
                RollingDigits {
                    id: level
                    objectName: "osdLevel"
                    anchors.right: parent.right
                    width: implicitWidth
                    height: implicitHeight
                    text: root.payload.muted ? "MUTED" : Math.round((root.payload.level ?? 0) * 100) + "%"
                    font.family: Design.sans
                    font.weight: Font.Bold
                    font.pixelSize: Design.readout
                    font.letterSpacing: -0.8
                    font.capitalization: Font.AllUppercase
                    font.features: ({ "tnum": 1 })
                    sheared: !Design.fluid
                    color: Design.ink
                }
            }
            FBlades {
                id: blades
                anchors.left: osdGlyph.right
                anchors.leftMargin: 3 * Design.baseline
                anchors.right: reading.left
                anchors.rightMargin: 3 * Design.baseline
                anchors.bottom: parent.bottom
                level: root.payload.level ?? 0
                muted: !!root.payload.muted
            }
        }
    }

    Component {
        id: transit
        TransitBand {
            kind: root.kind
            payload: root.payload
            privacy: root.privacy
            bottomEdge: root.bottomEdge
            lift: root.lift
            onOpenRoom: room => root.openRoom(room)
            onDismiss: root.dismiss()
        }
    }

    Component {
        id: workspaces
        Item {
            // The cold edge-on system (Z199). It takes the island's full depth (the face is inset by edgePad), and its
            // orbit runs past the face's sides on purpose: a slot onto a larger system.
            WorkspaceTransit {
                y: -root.edgePad
                width: parent.width
                height: root.height
                ids: root.payload.ids ?? []
                active: root.payload.active ?? ""
                windows: root.payload.windows ?? ({})
            }
        }
    }

    Component {
        id: memory
        Item {
            id: pressure
            readonly property real used: Number(root.payload.used ?? 0)
            readonly property real total: Math.max(1, Number(root.payload.total ?? 1))
            function gib(kib: real): string { return (kib / 1048576).toFixed(1); }
            FText {
                anchors.left: parent.left
                anchors.verticalCenter: reading.verticalCenter
                text: root.voice("> MEMORY · PRESSURE")
                font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                technical: true
                color: Design.accent
            }
            FText {
                id: reading
                anchors.right: parent.right
                headline: true
                sheared: !Design.fluid
                font.weight: Font.Bold
                font.pixelSize: Design.readout
                font.capitalization: Font.MixedCase
                voice: "kernel"
                text: pressure.gib(pressure.used) + " / " + pressure.gib(pressure.total) + " GiB"
            }
            FBlades {
                id: meter
                anchors.top: reading.bottom
                anchors.topMargin: Design.baseline
                width: parent.width
                level: pressure.used / pressure.total
            }
            Item {
                id: heading
                anchors.top: meter.bottom
                anchors.topMargin: Design.baseline
                width: parent.width
                height: Design.minHit
                FText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TOP PROCESSES"
                    technical: true
                    color: Design.muted
                }
                IslandGlyph {
                    anchors.right: pssLabel.left
                    anchors.rightMargin: Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "keep"
                    description: root.memoryPinned ? "Unpin memory" : "Pin memory"
                    signalDot: root.memoryPinned
                    onClicked: root.pinMemory()
                }
                FText {
                    id: pssLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PSS"
                    technical: true
                    color: Design.muted
                }
            }
            Column {
                anchors.top: heading.bottom
                width: parent.width
                Repeater {
                    model: (root.payload.processes ?? []).slice().sort((a, b) => b.pss - a.pss).slice(0, 3)
                    Item {
                        required property var modelData
                        width: parent.width
                        height: 5 * Design.baseline
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Design.line
                        }
                        FText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 100
                            text: modelData.name ?? ""
                            technical: true
                        }
                        FText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Number(modelData.pss ?? 0) / 1048576).toFixed(1) + " GiB"
                            font.capitalization: Font.MixedCase
                            technical: true
                            voice: "kernel"
                        }
                    }
                }
            }
        }
    }

    Component {
        id: status
        Item {
            id: statusFace
            readonly property bool inverse: root.kind === "low-battery"
            FPlate {
                id: backing
                anchors.fill: parent
                role: "signal"
                radius: Design.roundPlate
                visible: statusFace.inverse
            }
            // A prompt (a password or a pairing asked for) opens FART's settings where it is answered.
            readonly property bool prompt: root.event?.kind === "prompt"
            MouseArea {
                anchors.fill: parent
                enabled: statusFace.inverse || statusFace.prompt
                cursorShape: statusFace.prompt ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (statusFace.prompt) root.openSettings(root.payload.section ?? "");
                    else root.dismiss();
                }
            }
            Column {
                x: Design.baseline * 3
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (log.visible ? log.width + 8 : 0) - (dismissButton.visible ? dismissButton.width : 0)
                FText {
                    width: parent.width
                    text: root.voice(root.payload.label ?? "")
                    font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                    font.weight: statusFace.inverse ? Font.Bold : Font.Normal
                    color: statusFace.inverse ? backing.textColor : Design.accent
                }
                FText {
                    width: parent.width
                    visible: text !== ""
                    elide: Text.ElideRight
                    technical: true
                    color: statusFace.inverse ? backing.textColor : Design.ink
                    text: root.event?.kind === "debrief"
                        ? Clock.formatSeconds(root.payload.seconds ?? 0) + " · TASKS " + (root.payload.tasks ?? 0)
                            + " · STREAK " + (root.payload.streak ?? 0)
                        : root.payload.task ?? ""
                }
            }
            FButton {
                id: log
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Design.minHit
                visible: root.event?.kind === "resident"
                label: "Log"
                onClicked: root.openLog(root.payload.log ?? "")
            }
            FButton {
                id: dismissButton
                anchors.right: log.visible ? log.left : parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Design.minHit
                visible: log.visible || root.event?.kind === "debrief"
                symbol: "close"
                hint: "Dismiss"
                onClicked: root.dismiss()
            }
        }
    }

    Component {
        id: recording
        Item {
            FPlate {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3 * Design.baseline
                height: Design.fluid ? width : 4 * Design.baseline
                role: "signal"
                radius: width / 2
            }
            FText {
                anchors.left: mark.right
                anchors.leftMargin: 2 * Design.baseline
                anchors.verticalCenter: parent.verticalCenter
                color: Design.accent
                font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                text: root.voice("> RECORDING · ") + Clock.formatSeconds(wall.date.getTime() / 1000 - (root.payload.startedAt ?? 0))
                SystemClock { id: wall; precision: SystemClock.Seconds }
            }
        }
    }
}
