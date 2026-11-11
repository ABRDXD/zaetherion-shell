import QtQuick
import QtQuick.Controls
import Quickshell
import qs.view.ui

Item {
    id: root
    required property var event
    readonly property var payload: event?.data ?? ({})
    signal notificationAction(string id, string action, string reply)
    signal replyEdited(string text)
    signal dismiss()
    signal openLog(string url)
    signal pinMemory()
    property bool memoryPinned: false
    property bool systemVoice: true
    property string replyDraft: ""

    function voice(line: string): string {
        if (systemVoice) return line;
        const clean = line.replace(/^>\s*/, "").replace(/ · /g, " — ").toLowerCase();
        return clean.charAt(0).toUpperCase() + clean.slice(1);
    }

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
    implicitWidth: shape(event?.kind ?? "").width
    implicitHeight: shape(event?.kind ?? "").height

    Loader {
        anchors.fill: parent
        anchors.margins: 12
        sourceComponent: {
            switch (root.event?.kind) {
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

    Component {
        id: notice
        Item {
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.notificationAction(String(root.payload.id), "default", "");
                    root.dismiss();
                }
            }
            FText {
                text: root.systemVoice ? "> INBOX · " + (root.payload.appName ?? "") : "Inbox — " + (root.payload.appName ?? "")
                font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                technical: true
                color: Design.accent
            }
            Plane {
                y: 22
                width: 32
                height: 40
                role: root.event.kind === "critical" ? "signal" : "ink"
                slant: 3
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "notifications"
                    iconSize: Design.readout
                    color: Design.islandFill
                }
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.right: illustration.visible ? illustration.left : parent.right
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: Design.baseline
                FText {
                    width: parent.width
                    font.pixelSize: Design.control
                    text: root.payload.summary ?? ""
                }
                FText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    font.capitalization: Font.MixedCase
                    text: root.payload.body ?? ""
                }
            }
            Image {
                id: illustration
                visible: source.toString() !== ""
                anchors.right: parent.right
                y: 20
                width: 40
                height: width
                source: root.payload.image ?? ""
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Row {
                anchors.bottom: parent.bottom
                spacing: Design.baseline
                Repeater {
                    model: root.payload.actions ?? []
                    FButton {
                        required property var modelData
                        height: Design.minHit
                        label: modelData.label
                        onClicked: root.notificationAction(String(root.payload.id), modelData.id, "")
                    }
                }
                FField {
                    id: reply
                    visible: !!root.payload.reply
                    width: 144
                    height: Design.minHit
                    placeholderText: "Reply…"
                    text: root.replyDraft
                    onTextEdited: root.replyEdited(text)
                    onAccepted: send.submit()
                }
                FButton {
                    id: send
                    visible: reply.visible
                    enabled: reply.text.trim() !== ""
                    height: Design.minHit
                    label: "Send"
                    function submit(): void {
                        if (!enabled) return;
                        root.notificationAction(String(root.payload.id), String(root.payload.reply), reply.text);
                        root.replyEdited("");
                    }
                    onClicked: submit()
                }
            }
        }
    }

    Component {
        id: osd
        Item {
            FText {
                text: root.voice("> " + (root.payload.kind === "mic" ? "MICROPHONE" : root.payload.kind ?? ""))
                font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                color: Design.accent
                technical: true
            }
            FText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                headline: true
                sheared: true
                font.pixelSize: Design.readout
                text: root.payload.muted ? "MUTED" : Math.round((root.payload.level ?? 0) * 100) + "%"
            }
            Row {
                id: meter
                readonly property int blades: 24
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 80
                anchors.bottom: parent.bottom
                spacing: 3
                Repeater {
                    model: meter.blades
                    Plane {
                        required property int index
                        width: (meter.width - meter.spacing * (meter.blades - 1)) / meter.blades
                        height: Design.baseline * 2
                        role: !root.payload.muted && (index + 1) / meter.blades <= (root.payload.level ?? 0) ? "signal" : "ink"
                        opacity: role === "signal" ? 1 : 0.22
                        slant: 3
                    }
                }
            }
        }
    }

    Component {
        id: track
        Item {
            Plane {
                width: 48
                height: width
                role: "paper"
                Image {
                    anchors.fill: parent
                    source: root.payload.artUrl ?? ""
                    sourceSize.width: 48
                    sourceSize.height: 48
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 60
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Design.baseline
                FText {
                    width: parent.width
                    font.pixelSize: Design.control
                    text: root.payload.title ?? ""
                }
                FText {
                    width: parent.width
                    text: root.payload.artist ?? ""
                    technical: true
                    color: Design.muted
                }
            }
        }
    }

    Component {
        id: workspaces
        Row {
            spacing: Design.baseline
            Repeater {
                model: root.payload.ids ?? []
                Plane {
                    required property string modelData
                    width: Math.min(40, (root.width - 24) / Math.max(1, root.payload.ids?.length ?? 1) - Design.baseline)
                    height: Design.minHit
                    role: modelData === root.payload.active ? "signal" : "paper"
                    slant: 3
                    FText {
                        anchors.centerIn: parent
                        color: modelData === root.payload.active ? Design.islandFill : Design.ink
                        text: modelData
                        technical: true
                    }
                }
            }
        }
    }

    Component {
        id: memory
        Item {
            FText {
                text: root.voice("> MEMORY · PRESSURE")
                font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                technical: true
                color: Design.accent
            }
            FButton {
                anchors.right: parent.right
                height: Design.minHit
                label: root.memoryPinned ? "Unpin" : "Pin"
                onClicked: root.pinMemory()
            }
            FText {
                y: 18
                technical: true
                text: (Number(root.payload.used ?? 0) / 1048576).toFixed(1) + " / "
                    + (Number(root.payload.total ?? 0) / 1048576).toFixed(1) + " GiB"
            }
            Rectangle {
                y: 36
                height: Design.baseline
                width: parent.width
                color: Design.line
                Rectangle {
                    height: parent.height
                    width: parent.width * Math.min(1, (root.payload.used ?? 0) / Math.max(1, root.payload.total ?? 1))
                    color: Design.accent
                }
            }
            Column {
                y: 48
                width: parent.width
                spacing: Design.baseline
                FText { text: "TOP PROCESSES · PSS"; technical: true; color: Design.muted }
                Repeater {
                    model: (root.payload.processes ?? []).slice().sort((a, b) => b.pss - a.pss).slice(0, 3)
                    Row {
                        required property var modelData
                        width: parent.width
                        FText { width: parent.width - 100; text: modelData.name ?? ""; technical: true }
                        FText {
                            width: 100
                            horizontalAlignment: Text.AlignRight
                            text: (Number(modelData.pss ?? 0) / 1024).toFixed(0) + " MiB"
                            technical: true
                        }
                    }
                }
            }
        }
    }

    Component {
        id: status
        Item {
            readonly property bool inverse: ["done", "low-battery"].includes(root.event?.kind)
            Plane {
                anchors.fill: parent
                role: "signal"
                slant: 3
                visible: parent.inverse
            }
            MouseArea {
                anchors.fill: parent
                enabled: parent.inverse
                onClicked: root.dismiss()
            }
            Column {
                x: Design.baseline * 2
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (log.visible ? log.width + 8 : 0) - (dismissButton.visible ? dismissButton.width : 0)
                FText {
                    width: parent.width
                    text: root.voice(root.payload.label ?? "")
                    font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                    color: parent.parent.inverse ? Design.islandFill : Design.accent
                }
                FText {
                    width: parent.width
                    visible: text !== ""
                    technical: true
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
        FText {
            anchors.verticalCenter: parent.verticalCenter
            color: Design.accent
            font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
            text: root.voice("> RECORDING · ") + Clock.formatSeconds(wall.date.getTime() / 1000 - (root.payload.startedAt ?? 0))
            SystemClock { id: wall; precision: SystemClock.Seconds }
        }
    }
}
