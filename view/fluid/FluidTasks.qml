import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.contract
import qs.view.rooms
import qs.view.cues
import qs.view.ui
import "TasksAtlasLayout.js" as Atlas
import "../rooms/TaskEntry.js" as TaskEntry

// Confluence Tasks (owner, 15 November 2026: the star chart was "not intuitive enough"; pick "Readable list in space").
// A plain list you can read in a second, grouped Late · Today · This week · Later · No date · Done today, set in a deep
// starfield. Each task has a star whose brightness is its urgency (late burns warm) and a round tick on the right that
// finishes it; hovering a row offers Remove. Left: the lists and the open count, the room's primary reading. The new-
// task line sits on top of the list, where you look for it. State and actions are TasksSession's, shared with Angular.
Item {
    id: root
    required property TasksSession controller
    readonly property bool editing: input.activeFocus
    readonly property date today: controller.today
    readonly property var tasks: controller.visibleTasks.map(t => ({
        id: t.id, text: t.text, done: t.done, days: t.due ? TaskEntry.daysUntil(t.due, today) : null,
        due: t.due ? TaskEntry.label(t.due, today) : "", source: t }))
    readonly property var groups: Atlas.groups(tasks)
    readonly property var stars: Atlas.field(170, 11)

    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption; font.capitalization: Font.AllUppercase; font.letterSpacing: 2 }

    // The deep field: fixed stars, and a faint warm haze while something is late.
    Repeater {
        model: root.stars
        Rectangle {
            required property var modelData
            x: modelData[0] * root.width; y: modelData[1] * root.height
            width: modelData[2]; height: width; radius: width / 2
            color: Design.coldStar
            opacity: modelData[3]
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.controller.overdue > 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Design.warm, 0.06) }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }

    // Left: the open count, then the lists.
    ColumnLayout {
        id: side
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: FluidTokens.sectionGap
        anchors.topMargin: FluidTokens.sectionGap
        width: 240
        spacing: FluidTokens.unit
        Caption { text: "Open · " + root.controller.list.name }
        RollingDigits {
            objectName: "tasks.open"
            text: String(root.controller.remaining).padStart(2, "0")
            font.family: FluidTokens.sans
            font.pixelSize: FluidTokens.clock * 1.4 // scale: the room's one primary reading
            font.weight: Font.ExtraLight
        }
        FluidText {
            Layout.bottomMargin: FluidTokens.sectionGap
            text: root.controller.overdue > 0 ? root.controller.overdue + " late · " + root.controller.dueToday + " due today"
                : root.controller.dueToday > 0 ? root.controller.dueToday + " due today" : root.controller.remaining > 0 ? "Nothing due today." : "All clear."
            color: root.controller.overdue > 0 ? Design.warm : FluidTokens.secondary
        }
        Caption { text: "Lists" }
        Repeater {
            model: root.controller.lists
            Rectangle {
                id: listRow
                required property var modelData
                readonly property bool selected: modelData.id === root.controller.list.id
                objectName: "tasks.list." + modelData.id
                Layout.fillWidth: true
                implicitHeight: FluidTokens.controlHeight + FluidTokens.unit * 2
                radius: FluidTokens.controlRadius
                color: selected ? Qt.alpha(Design.coldStar, 0.10) : listHover.containsMouse ? Qt.alpha(Design.coldStar, 0.05) : "transparent"
                FluidText {
                    anchors.left: parent.left; anchors.leftMargin: FluidTokens.gap
                    anchors.verticalCenter: parent.verticalCenter
                    text: listRow.modelData.name
                    color: listRow.selected ? FluidTokens.ink : FluidTokens.secondary
                }
                FluidText {
                    anchors.right: parent.right; anchors.rightMargin: FluidTokens.gap
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(root.controller.openCount(listRow.modelData.id))
                    color: FluidTokens.secondary
                }
                MouseArea { id: listHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ViewState.taskList = listRow.modelData.id }
            }
        }
        FluidButton {
            Layout.topMargin: FluidTokens.sectionGap
            text: root.controller.core.timers.pomodoroRunning ? "Pause focus" : "Begin focus"
            enabled: root.controller.core.timers.available
            onClicked: root.controller.focus()
        }
    }

    // Centre: the new-task line, then the list.
    ColumnLayout {
        anchors.left: side.right
        anchors.leftMargin: FluidTokens.sectionGap * 1.5
        anchors.right: parent.right
        anchors.rightMargin: FluidTokens.sectionGap * 1.5
        anchors.top: parent.top
        anchors.topMargin: FluidTokens.sectionGap
        anchors.bottom: parent.bottom
        spacing: FluidTokens.unit * 1.5
        FField {
            id: input
            objectName: "tasks.entry"
            Layout.fillWidth: true
            Layout.maximumWidth: 760
            text: root.controller.draft
            placeholderText: "Add a task…   @list to file it   !fri to date it"
            onTextEdited: root.controller.setDraft(text)
            onAccepted: root.controller.addTask()
        }
        FluidText {
            text: root.controller.draft.trim() === "" ? "Press Enter to add." : root.controller.entryHint
            font.pixelSize: FluidTokens.caption
            color: root.controller.entry.error ? Design.warm : root.controller.draft.trim() === "" ? FluidTokens.secondary : FluidTokens.accent
        }
        RowLayout {
            visible: root.controller.removedTask !== null
            spacing: FluidTokens.gap
            FluidText { text: "Task removed."; color: FluidTokens.secondary }
            FluidButton { objectName: "tasks.undo"; text: "Undo"; onClicked: root.controller.undo() }
        }
        Flickable {
            Layout.fillWidth: true
            Layout.maximumWidth: 760
            Layout.fillHeight: true
            Layout.topMargin: FluidTokens.gap
            clip: true
            contentHeight: listColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            Column {
                id: listColumn
                width: parent.width
                spacing: FluidTokens.gap
                FluidText {
                    objectName: "tasks.empty"
                    visible: root.groups.length === 0
                    text: root.controller.core.tasks.available ? "Nothing here yet. Type above to add a task." : "The core is offline."
                    color: FluidTokens.secondary
                }
                Repeater {
                    model: root.groups
                    Column {
                        id: group
                        required property var modelData
                        objectName: "tasks.group." + modelData.key
                        width: listColumn.width
                        spacing: 0
                        // The group's heading, ruled out to the edge.
                        RowLayout {
                            width: parent.width
                            height: FluidTokens.controlHeight
                            spacing: FluidTokens.gap
                            Caption { text: group.modelData.label; color: group.modelData.key === "late" ? Design.warm : FluidTokens.secondary }
                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(FluidTokens.rule, 0.8) }
                            Caption { text: String(group.modelData.tasks.length) }
                        }
                        Repeater {
                            model: group.modelData.tasks
                            Rectangle {
                                id: row
                                required property var modelData
                                readonly property real urgency: Atlas.urgency(modelData)
                                readonly property bool late: !modelData.done && modelData.days !== null && modelData.days < 0
                                readonly property color tone: late ? Design.warm : Design.coldStar
                                objectName: "tasks.row." + modelData.id
                                width: group.width
                                height: FluidTokens.controlHeight + FluidTokens.unit * 3
                                radius: FluidTokens.controlRadius
                                color: rowHover.containsMouse ? Qt.alpha(Design.coldStar, 0.05) : "transparent"
                                MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                // The star: brighter and larger the more urgent.
                                Item {
                                    id: star
                                    anchors.left: parent.left; anchors.leftMargin: FluidTokens.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24; height: 24
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 6 + 16 * row.urgency; height: width; radius: width / 2
                                        color: Qt.alpha(row.tone, 0.18 * row.urgency)
                                    }
                                    Rectangle {
                                        objectName: "tasksStarBody"
                                        anchors.centerIn: parent
                                        width: 3 + 4 * row.urgency; height: width; radius: width / 2
                                        color: row.tone
                                        opacity: 0.35 + 0.65 * row.urgency
                                    }
                                }
                                FluidText {
                                    objectName: "tasks.text"
                                    anchors.left: star.right; anchors.leftMargin: FluidTokens.gap
                                    anchors.right: due.left; anchors.rightMargin: FluidTokens.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: row.modelData.text
                                    font.pixelSize: FluidTokens.heading * 0.8 // scale: list rows read a step above body
                                    font.strikeout: row.modelData.done
                                    color: row.modelData.done ? FluidTokens.secondary : FluidTokens.ink
                                }
                                FluidText {
                                    id: due
                                    anchors.right: remove.left; anchors.rightMargin: FluidTokens.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: row.modelData.due
                                    color: row.late ? Design.warm : FluidTokens.secondary
                                }
                                // Remove: only while the row is hovered, so the list stays calm.
                                FluidButton {
                                    id: remove
                                    objectName: "tasks.remove." + row.modelData.id
                                    anchors.right: tick.left; anchors.rightMargin: FluidTokens.unit
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Remove"
                                    opacity: rowHover.containsMouse || hovered ? 1 : 0
                                    enabled: opacity > 0
                                    onClicked: root.controller.remove(row.modelData.source)
                                }
                                // The tick: an empty ring to finish the task, filled once done.
                                Rectangle {
                                    id: tick
                                    objectName: "tasks.tick." + row.modelData.id
                                    readonly property bool checked: row.modelData.done
                                    anchors.right: parent.right; anchors.rightMargin: FluidTokens.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22; radius: 11
                                    color: checked ? Design.coldStar : tickHover.containsMouse ? Qt.alpha(Design.coldStar, 0.15) : "transparent"
                                    border.width: 1.5
                                    border.color: checked || tickHover.containsMouse ? Design.coldStar : FluidTokens.secondary
                                    FluidText {
                                        anchors.centerIn: parent
                                        visible: tick.checked || tickHover.containsMouse
                                        text: "✓"
                                        font.pixelSize: FluidTokens.caption
                                        color: tick.checked ? Design.voidFill : Design.coldStar
                                    }
                                    MouseArea {
                                        id: tickHover
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.controller.toggle(row.modelData.source)
                                    }
                                    ToolTip.visible: tickHover.containsMouse
                                    ToolTip.text: tick.checked ? "Mark as not done" : "Mark as done"
                                    ToolTip.delay: 500
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
