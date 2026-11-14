import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.view.rooms
import qs.view.shell
import qs.view.ui

// Confluence Home: a continuous day surface with a quieter calendar/media column.
GridLayout {
    id: root
    required property HomeSession session
    readonly property bool compact: width < 740
    columns: compact ? 1 : 2
    columnSpacing: FluidTokens.sectionGap
    rowSpacing: FluidTokens.sectionGap

    component Rule: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: FluidTokens.rule
    }
    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption }

    ColumnLayout {
        objectName: "home.main"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: root.width * 0.62
        spacing: FluidTokens.unit * 3
        ColumnLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.unit
            Caption { text: Qt.formatDate(Clock.date, "dddd, d MMMM"); font.capitalization: Font.AllUppercase }
            FluidText {
                objectName: "home.clock"
                Layout.fillWidth: true
                text: Clock.hourStr + ":" + Clock.minuteStr
                font.pixelSize: FluidTokens.clock
                font.weight: Font.Light
                font.features: ({"tnum":1})
                font.letterSpacing: -2
            }
            FluidText { text: "A clear view of your day."; font.pixelSize: FluidTokens.heading }
            Caption {
                Layout.fillWidth: true
                text: (root.session.tasksAvailable ? root.session.openTasks.length + " open tasks" : "Tasks offline")
                    + " / " + (root.session.host.notifications.available ? root.session.host.notifications.unread + " unread notices" : "Inbox offline")
                elide: Text.ElideRight
            }
        }
        RowLayout {
            Layout.fillWidth: true
            FluidButton {
                objectName: "home.focus"
                text: root.session.core?.timers.pomodoroRunning ? "Pause focus" : "Start focus"
                enabled: root.session.core?.timers.available ?? false
                onClicked: root.session.toggleFocus()
            }
            FluidButton { objectName: "home.timers"; text: "Open timers"; onClicked: root.session.navigate("timers") }
            Item { Layout.fillWidth: true }
        }
        Rule {}
        ColumnLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.unit
            RowLayout {
                Caption { text: "NEXT UP"; Layout.fillWidth: true }
                FluidButton { objectName: "home.tasks"; text: "All tasks →"; onClicked: root.session.navigate("tasks") }
            }
            Repeater {
                model: root.session.upcoming
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: FluidTokens.unit
                    RowLayout {
                        Layout.fillWidth: true
                        FluidButton {
                            objectName: "home.task." + modelData.id
                            implicitWidth: FluidTokens.controlHeight
                            text: "○"
                            Accessible.name: "Complete task: " + modelData.text
                            onClicked: root.session.finishTask(modelData.id)
                        }
                        FluidText { Layout.fillWidth: true; Layout.minimumWidth: 0; text: modelData.text; elide: Text.ElideRight }
                        Caption { text: root.session.taskDue(modelData) }
                    }
                    Rule {}
                }
            }
            FluidText {
                Layout.fillWidth: true
                Layout.preferredHeight: FluidTokens.controlHeight
                visible: root.session.upcoming.length === 0
                text: root.session.tasksAvailable ? "Nothing waiting. Space for what comes next." : "Tasks will return when the core reconnects."
                color: FluidTokens.secondary
                wrapMode: Text.Wrap
            }
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: FluidTokens.unit }
        RowLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.gap
            ColumnLayout {
                Layout.fillWidth: true
                Caption { text: "INBOX" }
                FluidActionRow {
                    objectName: "home.notifications"
                    Layout.fillWidth: true
                    text: root.session.host.notifications.available ? root.session.host.notifications.unread + " unread" : "Offline"
                    detail: root.session.host.notifications.dnd ? "Quiet" : "Open →"
                    onClicked: root.session.navigate("notifications")
                }
            }
            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: FluidTokens.rule }
            ColumnLayout {
                Layout.fillWidth: true
                Caption { text: "WORKSPACE" }
                FluidActionRow {
                    objectName: "home.workspaces"
                    Layout.fillWidth: true
                    text: "Desk " + root.session.host.workspaces.activeId
                    detail: "Open →"
                    onClicked: root.session.navigate("workspaces")
                }
            }
        }
        Rule {}
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: FluidTokens.gap
            rowSpacing: 0
            Caption { text: "UPKEEP" }
            Caption { text: "DESK" }
            FluidActionRow { objectName: "home.checkUpdates"; Layout.fillWidth: true; text: root.session.updates.checking ? "Checking…" : "Check updates"; detail: root.session.updates.available ? root.session.updates.count + " waiting" : "Unavailable"; enabled: !root.session.updates.checking; onClicked: root.session.checkUpdates() }
            FluidActionRow { objectName: "home.wallpapers"; Layout.fillWidth: true; text: "Wallpaper"; detail: "→"; onClicked: root.session.openHost("wallpapers") }
            FluidActionRow { objectName: "home.updates"; Layout.fillWidth: true; text: "Host updates"; detail: "→"; onClicked: root.session.openHost("updates") }
            FluidActionRow { objectName: "home.themes"; Layout.fillWidth: true; text: "Presets"; detail: "→"; onClicked: root.session.openHost("themes") }
            FluidActionRow { objectName: "home.updateFart"; Layout.fillWidth: true; text: "Update FART"; detail: "Git"; onClicked: root.session.updateFart() }
            FluidActionRow { objectName: "home.settings"; Layout.fillWidth: true; text: "Settings"; detail: "→"; onClicked: root.session.openHost("settings") }
        }
    }
    ColumnLayout {
        objectName: "home.aside"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: root.width * 0.32
        spacing: FluidTokens.gap
        FluidCalendar { Layout.fillWidth: true; month: root.session.calendarMonth; onShift: months => root.session.shiftMonth(months) }
        Caption {
            Layout.fillWidth: true
            visible: !!root.session.sky?.sun
            text: "Sunrise " + (root.session.sky?.sun?.rise ? Qt.formatTime(new Date(root.session.sky.sun.rise), "HH:mm") : "—")
                + " · Sunset " + (root.session.sky?.sun?.set ? Qt.formatTime(new Date(root.session.sky.sun.set), "HH:mm") : "—")
            elide: Text.ElideRight
        }
        Rule {}
        ColumnLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.unit * 2
            RowLayout {
                Caption { text: root.session.player?.playing ? "NOW PLAYING" : root.session.player ? "PAUSED" : "MEDIA"; Layout.fillWidth: true }
                FluidButton { objectName: "home.media"; text: "Open →"; onClicked: root.session.navigate("media") }
            }
            FluidText { Layout.fillWidth: true; text: root.session.player?.title || "The room is quiet."; font.pixelSize: FluidTokens.heading; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight }
            Caption { Layout.fillWidth: true; text: root.session.player?.artist || "Nothing needs to fill the silence."; elide: Text.ElideRight }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 2
                color: FluidTokens.rule
                Rectangle { width: parent.width * root.session.progress; height: parent.height; color: FluidTokens.accent }
            }
            RowLayout {
                Layout.fillWidth: true
                FluidButton { objectName: "home.previous"; text: "‹"; implicitWidth: FluidTokens.controlHeight; Accessible.name: "Previous track"; enabled: root.session.player?.canPrevious ?? false; onClicked: root.session.previous() }
                FluidButton { objectName: "home.play"; text: root.session.player?.playing ? "Pause" : "Play"; primary: true; enabled: root.session.player?.canToggle ?? false; onClicked: root.session.togglePlaying() }
                FluidButton { objectName: "home.next"; text: "›"; implicitWidth: FluidTokens.controlHeight; Accessible.name: "Next track"; enabled: root.session.player?.canNext ?? false; onClicked: root.session.next() }
                Item { Layout.fillWidth: true }
                Caption { text: Clock.formatSeconds(root.session.host.media.position); technical: true }
            }
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: FluidTokens.unit }
        Rule {}
        ColumnLayout {
            Layout.fillWidth: true
            spacing: FluidTokens.unit
            Caption { text: "RESIDENT" }
            FluidText { Layout.fillWidth: true; text: Config.options.profile.displayName || root.session.host.system.user; font.pixelSize: FluidTokens.heading; elide: Text.ElideRight }
            Caption { text: "Up for " + Math.floor(root.session.uptimeMinutes / 60) + "h " + root.session.uptimeMinutes % 60 + "m" }
            RowLayout {
                FluidButton { objectName: "home.profile"; text: "Edit profile"; onClicked: root.session.editProfile() }
                FluidButton { objectName: "home.lock"; text: "Lock"; onClicked: root.session.lock() }
            }
        }
    }
}
