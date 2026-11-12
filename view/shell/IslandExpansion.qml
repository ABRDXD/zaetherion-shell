import QtQuick
import QtQuick.Controls
import Quickshell
import qs.view.ui

Item {
    id: root
    required property var event
    readonly property var payload: event?.data ?? ({})
    readonly property string kind: event?.kind ?? ""
    signal notificationAction(string id, string action, string reply)
    signal replyEdited(string text)
    signal replyFocused(bool focused)
    property bool restoreReplyFocus: false
    signal dismiss()
    signal openLog(string url)
    signal pinMemory()
    property bool memoryPinned: false
    property bool systemVoice: true
    property bool bottomEdge: false
    property string replyDraft: ""

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
        case "track": return Qt.size(420, 72);
        default: return Qt.size(420, 56);
        }
    }
    readonly property bool noticeKind: kind === "notification" || kind === "critical"
    // Content keeps clear of the 84° shoulders at the deepest row, and of the 4 px facet.
    readonly property real shoulderSlope: 1 / Math.tan(84 * Math.PI / 180)
    // A notice is sized by its text, so its inset uses the deepest notice, not its own depth.
    readonly property real sideInset: Math.ceil(12 + (noticeKind ? 140 : shape(kind).height) * shoulderSlope)
    readonly property int edgePad: 10
    readonly property int facet: 4
    readonly property real noticeContent: noticeKind && face.item ? face.item.implicitHeight : 0
    implicitWidth: shape(kind).width
    implicitHeight: noticeKind
        ? Math.max(shape(kind).height, Math.ceil((noticeContent + 2 * edgePad + facet) / Design.baseline) * Design.baseline)
        : shape(kind).height

    Loader {
        id: face
        anchors.fill: parent
        anchors.leftMargin: root.sideInset
        anchors.rightMargin: root.sideInset
        anchors.topMargin: root.edgePad + (root.bottomEdge ? root.facet : 0)
        anchors.bottomMargin: root.edgePad + (root.bottomEdge ? 0 : root.facet)
        sourceComponent: {
            switch (root.kind) {
            case "notification":
            case "critical": return notice;
            case "osd": return osd;
            case "track": return track;
            case "workspace": return workspaces;
            case "memory": return memory;
            case "recording": return recording;
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

    Component {
        id: notice
        Item {
            id: card
            readonly property bool critical: root.kind === "critical"
            readonly property var actions: root.payload.actions ?? []
            readonly property bool replies: !!root.payload.reply
            implicitHeight: column.implicitHeight

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
                    }
                }
                FRule {
                    visible: actionRow.visible
                    width: parent.width
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
            FText {
                id: reading
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                horizontalAlignment: Text.AlignRight
                headline: true
                sheared: true
                font.weight: Font.Bold
                font.pixelSize: Design.readout
                text: root.payload.muted ? "MUTED" : Math.round((root.payload.level ?? 0) * 100) + "%"
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
        id: track
        Item {
            Plane {
                id: tile
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                role: "signal"
                slant: 3
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "music_note"
                    iconSize: Design.readout
                    color: tile.textColor
                }
                Image {
                    id: cover
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    source: root.payload.artUrl ?? ""
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.left: tile.right
                anchors.leftMargin: 3 * Design.baseline
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                FText {
                    technical: true
                    color: Design.accent
                    font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                    text: root.voice("> NOW PLAYING")
                }
                FText {
                    width: parent.width
                    headline: true
                    font.weight: Font.Bold
                    font.pixelSize: Design.readout
                    font.capitalization: Font.MixedCase
                    text: root.payload.title ?? ""
                }
                FText {
                    width: parent.width
                    visible: text !== ""
                    text: root.payload.artist ?? ""
                    technical: true
                    color: Design.muted
                }
            }
        }
    }

    Component {
        id: workspaces
        Item {
            Row {
                anchors.centerIn: parent
                spacing: Design.baseline
                Repeater {
                    model: root.payload.ids ?? []
                    Plane {
                        required property string modelData
                        width: Math.min(40, (root.width - 2 * root.sideInset) / Math.max(1, root.payload.ids?.length ?? 1) - Design.baseline)
                        height: Design.minHit
                        role: modelData === root.payload.active ? "signal" : "paper"
                        slant: 3
                        FText {
                            anchors.centerIn: parent
                            color: parent.textColor
                            text: modelData
                            technical: true
                        }
                    }
                }
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
                sheared: true
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
            readonly property bool inverse: ["done", "low-battery"].includes(root.event?.kind)
            Plane {
                id: backing
                anchors.fill: parent
                role: "signal"
                slant: 3
                visible: statusFace.inverse
            }
            MouseArea {
                anchors.fill: parent
                enabled: statusFace.inverse
                onClicked: root.dismiss()
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
            Plane {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3 * Design.baseline
                height: 4 * Design.baseline
                role: "signal"
                slant: 3
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
