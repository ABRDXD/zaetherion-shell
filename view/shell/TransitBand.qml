import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import qs.view.fluid
import qs.view.ui
import qs.view.cues

// Timer, timer completion and track change share one shallow island face.
AbstractButton {
    id: root
    required property string kind
    required property var payload
    property var privacy: []
    property bool bottomEdge: false
    property int lift: 0
    signal openRoom(string room)
    signal dismiss()
    readonly property bool done: kind === "done"
    readonly property bool track: kind === "track"
    readonly property string caption: String(payload.phase ?? "").toLowerCase()
    readonly property string phase: caption === "done" ? "Timer done" : caption.charAt(0).toUpperCase() + caption.slice(1)
    readonly property string title: track ? payload.title || payload.artist || "" : phase
    readonly property string detail: track ? (payload.title ? payload.artist ?? "" : "") : payload.task ?? ""
    readonly property string actionLabel: done ? "Dismiss" : track ? "Media ↗" : "Timers ↗"
    readonly property string family: Design.fluid ? FluidTokens.sans : Design.sans
    readonly property color eventInk: done ? "#121820" : Design.ink
    readonly property bool compact: width < 320
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: [title, payload.remaining, detail, actionLabel].filter(Boolean).join(", ")
    Keys.onReturnPressed: click()
    Keys.onEnterPressed: click()
    onClicked: {
        Feedback.play("ui.click");
        if (done) dismiss();
        else openRoom(track ? "media" : "timers");
    }

    // Use the island's real silhouette for the amber field, including the bottom-edge flare.
    background: Item {
        Shape {
            id: seam
            visible: root.done && !Design.fluid
            anchors.right: amber.left
            width: height * Math.abs(Design.shear)
            height: parent.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Design.warm
                startX: seam.width
                startY: 0
                PathLine { x: 0; y: root.bottomEdge ? 0 : root.height }
                PathLine { x: seam.width; y: root.height }
            }
        }
        Item {
            id: amber
            visible: root.done
            x: contentRow.x + divider.x + divider.width
            width: Math.max(0, parent.width - x)
            height: parent.height
            clip: true
            IslandFrame {
                x: -amber.x
                width: root.width
                height: root.height
                bottomEdge: root.bottomEdge
                fill: Design.warm
            }
        }
    }
    contentItem: Item {
        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: root.compact ? 14 : 24
            anchors.rightMargin: anchors.leftMargin
            anchors.topMargin: root.bottomEdge ? root.lift * 2 : 0
            anchors.bottomMargin: root.bottomEdge ? 0 : root.lift * 2
            spacing: root.compact ? Design.baseline : 3 * Design.baseline
            Text {
                text: Clock.hourStr + ":" + Clock.minuteStr
                font.family: Design.mono
                font.pixelSize: Design.control
                color: Design.muted
            }
            IslandGlyph {
                visible: root.privacy.length > 0
                glyph: root.privacy.some(stream => stream.kind === "camera") ? "videocam" : "mic"
                description: root.privacy.map(stream => stream.app).join(", ")
                signalDot: true
                onClicked: root.openRoom("devices")
            }
            Rectangle {
                id: divider
                opacity: root.done ? 0 : 1
                Layout.preferredWidth: 1
                Layout.preferredHeight: 28
                color: Design.line
            }
            Item {
                visible: !root.done && !root.compact
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                clip: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.track ? Design.mediaAccent : Design.warm
                }
                Rectangle {
                    x: 7
                    y: root.track ? 7 : -3
                    width: root.track ? 14 : 31
                    height: width
                    radius: width / 2
                    color: root.track ? "transparent" : Design.islandFill
                    border.width: root.track ? 1 : 0
                    border.color: Design.islandFill
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.track
                    width: 4; height: 4; radius: 2
                    color: Design.islandFill
                }
                Image {
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: root.track ? root.payload.artUrl ?? "" : ""
                    sourceSize: Qt.size(28, 28)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {
                visible: root.kind === "timer"
                text: root.payload.remaining ?? ""
                color: Design.warm
                font.family: root.family
                font.pixelSize: Design.fluid ? FluidTokens.heading : Design.readout
                font.bold: true
            }
            Column {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Text {
                    width: parent.width
                    text: root.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: root.family
                    font.pixelSize: root.kind === "timer" && root.detail ? (Design.fluid ? FluidTokens.caption : Design.caption)
                        : Design.fluid ? FluidTokens.heading : Design.readout
                    font.weight: root.kind === "timer" && root.detail ? Font.Normal : Font.DemiBold
                    color: root.kind === "timer" && root.detail ? Design.muted : root.eventInk
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    text: root.detail
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: root.family
                    font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
                    color: root.track ? Design.muted : Design.ink
                }
            }
            Text {
                text: root.actionLabel
                font.family: root.family
                font.pixelSize: Design.fluid ? FluidTokens.body : Design.control
                font.weight: Font.DemiBold
                font.underline: root.hovered || root.visualFocus || root.pressed
                color: root.eventInk
            }
        }
    }
}
