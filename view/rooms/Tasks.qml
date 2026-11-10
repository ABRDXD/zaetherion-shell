import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "TaskEntry.js" as TaskEntry
import "SurveyorNotes.js" as Notes

// Tasks (MONTAGE §5): a ruled sheet per list. The head names the lists, the selected one inverted;
// the entry line reads "@list" and "!due" as the `task` verb does; overdue lines read in signal.
// Beside the sheet, its plate: what is open, due and done, and the surveyor.
ColumnLayout {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    readonly property bool editing: input.activeFocus
    readonly property bool narrow: width < 730
    property var removedTask: ViewState.removedTask
    onRemovedTaskChanged: ViewState.removedTask = removedTask
    property string creatureNote: "surveyor asleep. work may proceed."
    // The day the room reads due dates against: refreshed whenever the room is shown, no timer.
    property date today: new Date()
    onVisibleChanged: if (visible) today = new Date()

    readonly property var lists: core.tasks.lists
    readonly property var list: lists.find(l => l.id === ViewState.taskList) ?? lists[0] ?? ({ id: "default", name: "Tasks" })
    readonly property var all: core.tasks.all
    readonly property var inList: all.filter(t => t.list === list.id)
    readonly property int remaining: inList.filter(t => !t.done).length
    readonly property int finished: inList.length - remaining
    readonly property int overdue: inList.filter(t => !t.done && TaskEntry.state(t.due, today) === "overdue").length
    readonly property int dueToday: inList.filter(t => !t.done && TaskEntry.state(t.due, today) === "today").length
    // The open list keeps today's finished tasks in their places as empty cut-outs (TaskRow.vanished, atlas #26).
    readonly property var shown: inList.filter(t => ViewState.taskFilter === "all" || (ViewState.taskFilter === "done") === t.done
                                                || ViewState.taskFilter === "active" && TaskEntry.vanishedToday(t, today))
    // Line numbers count only the tasks still there.
    readonly property var numbers: { let n = 0; return shown.map(t => ViewState.taskFilter === "active" && t.done ? 0 : ++n); }
    readonly property var entry: TaskEntry.parse(input.text, today)
    readonly property var entryList: entry.list === null ? list
        : lists.find(l => l.name.toLowerCase() === entry.list.toLowerCase() || l.id === entry.list) ?? null

    function openCount(id) {
        return all.filter(t => t.list === id && !t.done).length;
    }
    function addTask() {
        const parsed = entry;
        if (!parsed.text || parsed.error || !core.tasks.available)
            return;
        const target = entryList;
        if (target) {
            core.tasks.add(parsed.text, target.id, parsed.due);
            ViewState.taskList = target.id;
        } else {
            // "@name" for a list that does not exist yet makes it; the hint line says so first.
            core.tasks.addList(parsed.list, created => {
                core.tasks.add(parsed.text, created.id, parsed.due);
                ViewState.taskList = created.id;
            });
        }
        ViewState.taskDraft = "";
        ViewState.taskFilter = "active";
    }
    spacing: 10

    // The head: the lists as tabs, the selected one inverted, ruled out to the edge, then the date.
    RowLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: root.lists
            SheetTab {
                required property var modelData
                large: true
                label: modelData.name
                count: String(root.openCount(modelData.id)).padStart(2, "0")
                selected: modelData.id === root.list.id
                onClicked: ViewState.taskList = modelData.id
            }
        }
        Hairline {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 12
            Layout.minimumWidth: 24
        }
        FText {
            visible: !root.narrow
            text: Qt.formatDate(root.today, "ddd dd MMM")
            technical: true
            color: Design.faint
        }
    }

    // The entry line and, under it, how it will be read.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            FField {
                id: input
                Layout.fillWidth: true
                text: ViewState.taskDraft
                placeholderText: "NEW TASK   @LIST   !DUE"
                onTextEdited: ViewState.taskDraft = text
                onAccepted: root.addTask()
            }
            FButton {
                symbol: "add"
                hint: "Add task"
                primary: true
                implicitHeight: 40
                implicitWidth: 40
                enabled: root.entry.text.length > 0 && !root.entry.error && root.core.tasks.available
                onClicked: root.addTask()
            }
        }
        FText {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            text: root.entry.error ? root.entry.error
                : input.text.trim() === "" ? "@LIST  ·  !TODAY  !FRI  !+3D  !2026-11-12"
                : "→ " + (root.entryList ? root.entryList.name : "new list " + root.entry.list)
                    + (root.entry.due ? "  ·  due " + TaskEntry.label(root.entry.due, root.today) : "")
            technical: true
            color: root.entry.error ? Design.warm : input.text.trim() === "" ? Design.faint : Design.accent
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: root.narrow ? 18 : 28
        // The sheet: the filter, the ruled lines, and undo.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: [["active", "In progress", root.remaining], ["done", "Finished", root.finished],
                            ["all", "Everything", root.inList.length]]
                    SheetTab {
                        required property var modelData
                        label: root.narrow && modelData[0] === "active" ? "Open" : modelData[1]
                        count: String(modelData[2]).padStart(2, "0")
                        selected: ViewState.taskFilter === modelData[0]
                        onClicked: ViewState.taskFilter = modelData[0]
                    }
                }
                Item { Layout.fillWidth: true }
            }
            Item {
                id: sheet
                Layout.fillWidth: true
                Layout.fillHeight: true
                Repeater {
                    model: 2
                    Register {
                        required property int index
                        x: index ? sheet.width - width : 0
                        y: sheet.height - height
                    }
                }
                ListView {
                    id: lines
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.bottomMargin: 18
                    clip: true
                    model: root.shown
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: TaskRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        task: modelData
                        number: root.numbers[index] ?? index + 1
                        vanished: modelData.done && ViewState.taskFilter === "active"
                        today: root.today
                        onToggled: root.core.tasks.setDone(modelData.id, !modelData.done)
                        onRemoved: root.core.tasks.remove(modelData.id, removed => root.removedTask = removed)
                    }
                }
                Column {
                    anchors.centerIn: parent
                    visible: root.shown.every(t => t.done && ViewState.taskFilter === "active")
                    spacing: 6
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !root.core.tasks.available ? "CORE OFFLINE" : ViewState.taskFilter === "done"
                            ? "NO FINISHED TASKS" : root.inList.length === 0 ? "AN EMPTY SHEET" : "NO PENDING TASKS"
                        technical: true
                        color: Design.muted
                    }
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.core.tasks.available
                        text: ViewState.taskFilter === "done" ? "nothing crossed out yet." : "type above. or don't."
                        aside: true
                        color: Design.faint
                    }
                }
            }
            RowLayout {
                visible: root.removedTask !== null
                spacing: 10
                FText {
                    text: "TASK REMOVED"
                    technical: true
                    color: Design.muted
                }
                FButton {
                    label: "Undo"
                    symbol: "undo"
                    implicitHeight: 30
                    onClicked: {
                        root.core.tasks.restore(root.removedTask);
                        root.removedTask = null;
                    }
                }
            }
        }

        // The plate: the open count large, then due, late and done, ruled; the voice; the surveyor.
        ColumnLayout {
            Layout.preferredWidth: root.narrow ? 185 : root.width > 1000 ? 280 : 236
            Layout.maximumWidth: root.narrow ? 185 : root.width > 1000 ? 280 : 236
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: 6
            FText {
                text: "OPEN · " + root.list.name
                technical: true
                color: Design.accent
                Layout.fillWidth: true
            }
            FText {
                text: String(root.remaining).padStart(2, "0")
                headline: true
                font.pixelSize: Design.display
                font.weight: Font.ExtraLight
                font.letterSpacing: -4
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: [["Today", root.dueToday, false], ["Late", root.overdue, root.overdue > 0],
                            ["Done", root.finished, false]]
                    ColumnLayout {
                        id: fact
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        spacing: 3
                        Row {
                            spacing: 6
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 5
                                color: fact.modelData[2] ? Design.accent : Design.line
                            }
                            FText {
                                text: fact.modelData[0]
                                technical: true
                                color: Design.muted
                            }
                        }
                        FText {
                            text: String(fact.modelData[1]).padStart(2, "0")
                            headline: true
                            font.pixelSize: Design.readout
                            font.weight: Font.Light
                            color: fact.modelData[2] ? Design.accent : Design.ink
                        }
                        Hairline {
                            Layout.fillWidth: true
                            node: 3
                        }
                    }
                }
            }
            FText {
                Layout.fillWidth: true
                Layout.topMargin: 10
                text: !root.core.tasks.available ? "the ledger is elsewhere." : root.overdue > 0
                    ? "some of this was due. it still is." : root.remaining === 0
                    ? "nothing pending. suspicious." : "attention is a finite resource."
                aside: true
                font.pixelSize: Design.readout
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
            Item { Layout.fillHeight: true }
            FCreature {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 84
                progress: root.inList.length ? root.finished / root.inList.length : 0
                // Each poke, the next thing it has to say (SurveyorNotes.js).
                property int pokes: 0
                onDiscovered: root.creatureNote = Notes.POKES[pokes++ % Notes.POKES.length]
            }
            FText {
                Layout.fillWidth: true
                aside: true
                text: root.creatureNote
                font.pixelSize: Design.caption
                wrapMode: Text.Wrap
                color: Design.faint
            }
            FButton {
                Layout.fillWidth: true
                label: root.core.timers.pomodoroRunning ? "Pause focus" : "Begin focus"
                symbol: root.core.timers.pomodoroRunning ? "pause" : "play_arrow"
                enabled: root.core.timers.available
                onClicked: {
                    root.shell.engagedTimerKind = "pomodoro";
                    root.core.timers.toggle("pomodoro");
                }
            }
        }
    }
}
