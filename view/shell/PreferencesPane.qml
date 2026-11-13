import QtQuick
import QtQuick.Layouts
import qs.core.client
import qs.view.ui
import qs.view.cues

// Settings are drawn and clipped inside FART. Opening grows this section; closing folds it back.
Item {
    id: root
    required property CoreClient core
    property bool expanded: false
    property bool wideLayout: false
    property real reveal: expanded ? 1 : 0
    signal closed()
    signal archiveRequested()
    signal toggleExterior()
    width: Math.min(760, parent.width - 80)
    height: Math.min(480, parent.height - 80) * reveal
    x: 40
    y: Math.max(20, parent.height - height - 40)
    visible: reveal > 0
    clip: true
    z: 10
    Behavior on reveal { NumberAnimation { duration: root.expanded ? Motion.unfold : Motion.fold; easing.type: Easing.OutCubic } }
    Rectangle {
        anchors.fill: parent
        color: Design.surface
        border.width: 1
        border.color: Design.line
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Design.baseline * 4
        spacing: Design.baseline * 3
        RowLayout {
            FText { text: "INSTRUMENT SETTINGS"; technical: true; color: Design.accent; Layout.fillWidth: true }
            FButton { symbol: "close"; hint: "Close preferences"; implicitHeight: Design.minHit; onClicked: root.closed() }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Design.baseline * 5
            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.alignment: Qt.AlignTop
                spacing: Design.baseline * 2
                StylePicker { Layout.fillWidth: true; core: root.core }
                FButton {
                    Layout.fillWidth: true
                    label: Design.italic ? "Shell asides: italic" : "Shell asides: upright"
                    selected: Design.italic
                    onClicked: Config.options.appearance.fonts.italicMain = !Design.italic
                }
                FButton {
                    Layout.fillWidth: true
                    label: ViewState.motionEnabled ? "Motion: full" : "Motion: reduced"
                    selected: ViewState.motionEnabled
                    onClicked: ViewState.motionEnabled = !ViewState.motionEnabled
                }
                FButton {
                    Layout.fillWidth: true
                    label: ViewState.fullscreen ? "Size: fullscreen" : "Size: panel"
                    selected: ViewState.fullscreen
                    onClicked: ViewState.fullscreen = !ViewState.fullscreen
                }
                FButton {
                    Layout.fillWidth: true
                    label: ViewState.visualiserEnabled ? "Visualiser: on" : "Visualiser: off"
                    selected: ViewState.visualiserEnabled
                    onClicked: ViewState.visualiserEnabled = !ViewState.visualiserEnabled
                }
                FButton {
                    Layout.fillWidth: true; visible: Motion.overdrive
                    label: ViewState.ambientEnabled ? "Ambient detail: on" : "Ambient detail: off"
                    selected: ViewState.ambientEnabled
                    onClicked: ViewState.ambientEnabled = !ViewState.ambientEnabled
                }
                FButton { Layout.fillWidth: true; label: "Optional field archive"; symbol: "folder_special"; onClicked: root.archiveRequested() }
                FButton { Layout.fillWidth: true; label: root.wideLayout ? "Exterior: wide → clock" : "Exterior: clock → wide"; onClicked: root.toggleExterior() }
            }
            PalettePicker {
                Layout.fillWidth: true
                Layout.fillHeight: true
                core: root.core
                active: root.expanded
                onCloseRequested: root.closed()
            }
        }
    }
}
