import QtQuick
import QtQuick.Layouts
import qs.view.contract
import qs.view.rooms
import qs.view.cues
import qs.view.ui
import "TasksAtlasLayout.js" as Atlas
import "../rooms/TaskEntry.js" as TaskEntry

// Confluence Tasks (owner's pick "B · Star atlas", 15 November 2026). The selected list is the constellation at the
// centre (TasksAtlas). Hierarchy: the open count is the room's one primary reading (left); the next task, secondary
// (right), with focus beside it; the other lists are small distant constellations along the top; the entry line and
// its reading sit under the chart. State and actions are the controller's (TasksSession), shared with Angular.
Item {
    id: root
    required property TasksSession controller
    readonly property bool editing: input.activeFocus
    readonly property date today: controller.today
    readonly property var stars: controller.visibleTasks.map(t => ({
        id: t.id, text: t.text, done: t.done, days: t.due ? TaskEntry.daysUntil(t.due, today) : null,
        due: t.due ? TaskEntry.label(t.due, today) : "" }))
    readonly property var next: Atlas.order(stars.filter(t => !t.done))[0] ?? null

    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption; font.capitalization: Font.AllUppercase; font.letterSpacing: 2 }

    TasksAtlas {
        objectName: "tasks.atlas"
        anchors.fill: parent
        anchors.topMargin: FluidTokens.sectionGap * 2.2
        anchors.bottomMargin: FluidTokens.sectionGap * 3.2
        tasks: root.stars
        listId: root.controller.list.id
        onToggled: task => { const t = root.controller.inList.find(x => x.id === task.id); if (t) root.controller.toggle(t); }
        onRemoved: task => { const t = root.controller.inList.find(x => x.id === task.id); if (t) root.controller.remove(t); }
    }

    // The other lists: distant constellations along the top, the shown one bright.
    Row {
        objectName: "tasks.lists"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: FluidTokens.sectionGap
        Repeater {
            model: root.controller.lists
            Item {
                id: chip
                required property var modelData
                readonly property bool selected: modelData.id === root.controller.list.id
                readonly property int open: root.controller.openCount(modelData.id)
                objectName: "tasks.list." + modelData.id
                width: Math.max(84, name.implicitWidth); height: 60
                opacity: selected ? 1 : hover.containsMouse ? 0.85 : 0.5
                // Its little figure: one dot per open task (up to seven), in the list's own shape.
                Repeater {
                    model: Atlas.place(Array.from({ length: Math.min(7, chip.open) }, (_, i) => ({ id: i, days: i, done: false })), chip.modelData.id)
                    Rectangle {
                        required property var modelData
                        readonly property var p: Atlas.project(modelData.r * 0.9, modelData.a, chip.width / 2, 16, 34)
                        x: p.x - 2; y: p.y - 2; width: 4; height: 4; radius: 2
                        color: chip.selected ? Design.coldCore : Design.coldStar
                    }
                }
                FluidText {
                    id: name
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: chip.modelData.name + "  " + String(chip.open).padStart(2, "0")
                    font.pixelSize: FluidTokens.caption
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                    color: chip.selected ? FluidTokens.ink : FluidTokens.secondary
                }
                Rectangle { visible: chip.selected; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: name.bottom; anchors.topMargin: 4; width: 18; height: 1; color: FluidTokens.ink }
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ViewState.taskList = chip.modelData.id }
            }
        }
    }

    // Primary: what is open in this list.
    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: FluidTokens.sectionGap * 1.5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.08
        spacing: FluidTokens.unit
        Caption { text: "Open · " + root.controller.list.name }
        RollingDigits {
            objectName: "tasks.open"
            text: String(root.controller.remaining).padStart(2, "0")
            font.family: FluidTokens.sans
            font.pixelSize: FluidTokens.clock * 1.5 // scale: the room's one primary reading
            font.weight: Font.ExtraLight
        }
        Row {
            spacing: FluidTokens.sectionGap * 0.75
            Repeater {
                model: [["Today", root.controller.dueToday, false], ["Late", root.controller.overdue, root.controller.overdue > 0],
                        ["Done", root.controller.finished, false]]
                Column {
                    required property var modelData
                    spacing: 2
                    Caption { text: modelData[0]; color: modelData[2] ? Design.warm : FluidTokens.secondary }
                    FluidText {
                        text: String(modelData[1]).padStart(2, "0")
                        font.pixelSize: FluidTokens.heading
                        font.weight: Font.Light
                        color: modelData[2] ? Design.warm : FluidTokens.ink
                    }
                }
            }
        }
    }

    // Secondary: the next task, and focus on it.
    ColumnLayout {
        anchors.right: parent.right
        anchors.rightMargin: FluidTokens.sectionGap * 1.5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.08
        width: 260
        spacing: FluidTokens.unit
        Caption { Layout.alignment: Qt.AlignRight; text: "Next" }
        FluidText {
            objectName: "tasks.next"
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: 260
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.Wrap
            maximumLineCount: 3
            text: root.next ? root.next.text : root.controller.core.tasks.available ? "Nothing pending." : "The core is offline."
            font.pixelSize: FluidTokens.title * 0.85 // scale: secondary to the open count
            font.weight: Font.Light
        }
        FluidText {
            Layout.alignment: Qt.AlignRight
            visible: !!root.next
            text: root.next?.due ? root.next.due : "No date"
            font.pixelSize: FluidTokens.body
            color: root.next && root.next.days !== null && root.next.days < 0 ? Design.warm : FluidTokens.secondary
        }
        FluidButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: FluidTokens.gap
            text: root.controller.core.timers.pomodoroRunning ? "Pause focus" : "Begin focus"
            enabled: root.controller.core.timers.available
            onClicked: root.controller.focus()
        }
    }

    // The entry line, its reading, and undo, under the chart.
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: FluidTokens.unit * 1.5
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.controller.removedTask !== null
            spacing: FluidTokens.gap
            Caption { text: "Task removed" }
            FluidButton { objectName: "tasks.undo"; text: "Undo"; onClicked: root.controller.undo() }
        }
        FField {
            id: input
            objectName: "tasks.entry"
            Layout.preferredWidth: Math.min(560, root.width * 0.5)
            Layout.alignment: Qt.AlignHCenter
            text: root.controller.draft
            placeholderText: "A new star   @list   !due"
            onTextEdited: root.controller.setDraft(text)
            onAccepted: root.controller.addTask()
        }
        Caption {
            Layout.alignment: Qt.AlignHCenter
            text: root.controller.entryHint
            color: root.controller.entry.error ? Design.warm : root.controller.draft.trim() === "" ? FluidTokens.secondary : FluidTokens.accent
            font.capitalization: Font.MixedCase
        }
        Caption {
            Layout.alignment: Qt.AlignHCenter
            text: "Click a star to finish it · right-click to remove"
            opacity: 0.6
        }
    }
}
