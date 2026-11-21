import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.core.client
import qs.view.ui
import qs.view.cues
import qs.view.contract

// Settings are drawn and clipped inside FART. Opening grows this section; closing folds it back.
Item {
    id: root
    required property CoreClient core
    required property HostAdapter host
    property bool expanded: false
    property bool wideLayout: false
    // palette · wallpaper · presets (Z177) · island (Z201) · notifications (Z207) · clips (Z184, Z202) · Wi-Fi · Bluetooth (Z194).
    // A section is active only while it is shown.
    property string section: "palette"
    readonly property var sections: [["palette", "PALETTE"], ["wallpaper", "WALLPAPER"], ["presets", "PRESETS"], ["island", "ISLAND"], ["notifications", "NOTIFICATIONS"], ["clips", "CLIPS"], ["wifi", "WI-FI"], ["bluetooth", "BLUETOOTH"]]
    signal sectionPicked(string section)
    readonly property real openHeight: Math.max(0, Math.min(620, parent.height - Design.baseline * 20))
    readonly property real reveal: arrival.value
    signal closed
    signal archiveRequested
    signal toggleExterior
    width: Math.min(1080, parent.width - Design.baseline * 20)
    height: openHeight * reveal
    x: 40
    y: Math.max(20, parent.height - height - 40)
    visible: reveal > 0
    clip: true
    z: 10
    // Gated by the panel, not this pane: the pane is invisible when it starts to grow.
    Cue {
        id: arrival
        name: "settings.arrival"
        on: root.expanded
        scope: root.parent
        enter: Design.fluid ? Motion.unfold : Motion.cutDuration(root.openHeight, 1, false)
        exit: Design.fluid ? Motion.fold : Motion.cutDuration(root.openHeight, 1, true)
        easing: Design.fluid ? Easing.OutCubic : Motion.cutIn
        exitEasing: Design.fluid ? Easing.OutCubic : Motion.cutOut
    }
    Rectangle {
        anchors.fill: parent
        color: Design.surface
        border.width: 1
        border.color: Design.line
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: Design.baseline * 4
        spacing: Design.baseline * 6
        SettingsNavigation {
            Layout.preferredWidth: Design.baseline * 46
            Layout.maximumWidth: Design.baseline * 46
            Layout.fillHeight: true
            sections: root.sections
            section: root.section
            onPicked: section => root.sectionPicked(section)
            onClosed: root.closed()
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Design.baseline * 3
            FText {
                Layout.fillWidth: true
                text: root.sections.find(section => section[0] === root.section)?.[1] ?? "SETTINGS"
                headline: true
                font.pixelSize: Design.figure
                font.weight: Font.DemiBold
            }
            FRule {
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Design.baseline * 4
                // FART's own switches sit beside the palette; the wallpaper and presets take the whole width.
                Flickable {
                    id: paletteScroll
                    Layout.preferredWidth: Design.baseline * 60
                    Layout.maximumWidth: Design.baseline * 60
                    Layout.fillHeight: true
                    visible: root.section === "palette"
                    clip: true
                    contentWidth: width
                    contentHeight: paletteOptions.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: SettingsScrollBar { flick: paletteScroll }
                    ColumnLayout {
                        id: paletteOptions
                        width: parent.width - Design.baseline * 4
                        spacing: Design.baseline * 3
                        StylePicker {
                            Layout.fillWidth: true
                            core: root.core
                        }
                        SettingChoices {
                            Layout.fillWidth: true
                            compact: true
                            label: "SHELL ASIDES"
                            options: [[false, "Upright"], [true, "Italic"]]
                            value: Design.italic
                            onPicked: value => Config.options.appearance.fonts.italicMain = value
                        }
                        SettingChoices {
                            Layout.fillWidth: true
                            compact: true
                            label: "MOTION"
                            options: [[true, "Full"], [false, "Reduced"]]
                            value: ViewState.motionEnabled
                            onPicked: value => ViewState.motionEnabled = value
                        }
                        SettingChoices {
                            Layout.fillWidth: true
                            compact: true
                            label: "SIZE"
                            options: [[true, "Fullscreen"], [false, "Panel"]]
                            value: ViewState.fullscreen
                            onPicked: value => ViewState.fullscreen = value
                        }
                        SettingChoices {
                            Layout.fillWidth: true
                            compact: true
                            label: "VISUALISER"
                            options: [[true, "On"], [false, "Off"]]
                            value: ViewState.visualiserEnabled
                            onPicked: value => ViewState.visualiserEnabled = value
                        }
                        SettingChoices {
                            Layout.fillWidth: true
                            compact: true
                            label: "AMBIENT DETAIL"
                            options: [[true, "On"], [false, "Off"]]
                            value: ViewState.ambientEnabled
                            visible: Motion.overdrive
                            onPicked: value => ViewState.ambientEnabled = value
                        }
                        SettingChoices {
                            Layout.fillWidth: true
                            compact: true
                            label: "EXTERIOR"
                            options: [[true, "Wide"], [false, "Clock"]]
                            value: root.wideLayout
                            onPicked: value => root.toggleExterior()
                        }
                        FButton {
                            Layout.fillWidth: true
                            label: "Field archive"
                            symbol: "folder_special"
                            onClicked: root.archiveRequested()
                        }
                    }
                }
                PalettePicker {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.section === "palette"
                    core: root.core
                    active: root.expanded && visible
                    onCloseRequested: root.closed()
                }
                WallpaperPicker {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.section === "wallpaper"
                    core: root.core
                    active: root.expanded && visible
                    onCloseRequested: root.closed()
                }
                PresetPicker {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.section === "presets"
                    core: root.core
                    active: root.expanded && visible
                    onCloseRequested: root.closed()
                }
                Flickable {
                    id: settingScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: ["island", "notifications", "clips"].includes(root.section)
                    clip: true
                    contentWidth: width
                    contentHeight: settingsColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: SettingsScrollBar { flick: settingScroll }
                    Connections {
                        target: root
                        function onSectionChanged() {
                            settingScroll.contentY = 0;
                        }
                        function onExpandedChanged() {
                            if (!root.expanded)
                                settingScroll.contentY = 0;
                        }
                    }
                    ColumnLayout {
                        id: settingsColumn
                        width: Math.max(0, settingScroll.width - Design.baseline * 4)
                        spacing: Design.baseline * 5
                        IslandSettings {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            visible: root.section === "island"
                            core: root.core
                            active: root.expanded && visible
                        }
                        NotificationsSettings {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            visible: root.section === "notifications"
                            core: root.core
                            notifications: root.host.notifications
                            active: root.expanded && visible
                        }
                        ClipsSettings {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            visible: root.section === "clips"
                            core: root.core
                            clipboard: root.host.clipboard
                            active: root.expanded && visible
                        }
                    }
                }
                WifiSettings {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.section === "wifi"
                    network: root.host.network
                    active: root.expanded && visible
                }
                BluetoothSettings {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.section === "bluetooth"
                    bluetooth: root.host.bluetooth
                    active: root.expanded && visible
                }
            }
        }
    }
}
