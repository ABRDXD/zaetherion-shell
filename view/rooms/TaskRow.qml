import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "TaskEntry.js" as TaskEntry

// One ruled line of the task sheet: its number, a 78° check, the text, the due date and remove.
// Overdue reads in signal, stated and not scolded; finished lines are struck through and muted.
// Neglect patina (atlas #25): a line left undone looks recopied, not alarmed. From its first day late a ghost of the
// text slips half a pixel out of register (a fixed side per task), from the third its rule is doubled, from the tenth a
// second ghost slips the other way. An undated task starts to weather after two weeks. Static: it changes on opening.
// Completion negative space (atlas #26): in the open list a task finished today keeps its exact place as an empty
// cut-out with the time it went, until midnight; nothing in it can be clicked.
Item {
    id: root
    required property var task
    required property int number
    required property date today
    property bool vanished: false
    signal toggled
    signal removed
    readonly property string dueState: TaskEntry.state(task.due, today)
    readonly property bool late: !task.done && dueState === "overdue"
    readonly property bool hot: !vanished && (hover.hovered || check.activeFocus || remove.activeFocus)
    readonly property real patina: vanished ? 0 : TaskEntry.patina(task, today)
    readonly property int side: TaskEntry.patinaSide(task.id)
    readonly property real shift: TaskEntry.patinaShift(patina)
    implicitHeight: Math.max(48, body.implicitHeight + 22)
    HoverHandler { id: hover }
    // The hovered or focused line lifts onto paper; the rule under it stays.
    Plane {
        anchors.fill: parent
        anchors.bottomMargin: 3
        role: root.hot ? "paper" : "clear"
        slant: 3
    }
    // The 78° pointer: the sheet's marker beside the line in hand.
    Plane {
        visible: root.hot
        x: -14
        y: (parent.height - height) / 2
        width: 8
        height: 14
        role: root.late ? "signal" : "ink"
        slant: 1
    }
    RowLayout {
        opacity: root.vanished ? 0 : 1
        enabled: !root.vanished
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 4
        anchors.bottomMargin: 3
        spacing: 12
        FText {
            text: String(root.number).padStart(2, "0")
            technical: true
            color: root.late ? Design.accent : Design.faint
            Layout.preferredWidth: 20
        }
        AbstractButton {
            id: check
            implicitWidth: 28
            implicitHeight: 28
            Accessible.name: root.task.done ? "Mark unfinished: " + root.task.text : "Complete: " + root.task.text
            onClicked: {
                Feedback.play("ui.click");
                root.toggled();
            }
            background: Item {
                // A 78° box: an ink outline (two nested planes), filled with signal once done.
                Plane {
                    anchors.centerIn: parent
                    width: 22
                    height: 18
                    slant: 3
                    role: root.task.done ? "signal" : check.activeFocus || check.hovered ? "ink" : "clear"
                    opacity: root.task.done || check.activeFocus || check.hovered ? 1 : 0
                }
                Rectangle {
                    // The outline at rest, sheared like the box.
                    visible: !root.task.done && !check.hovered && !check.activeFocus
                    anchors.centerIn: parent
                    width: 19
                    height: 18
                    color: "transparent"
                    border.width: 1
                    border.color: root.late ? Design.accent : Design.muted
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * 9, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
            contentItem: MaterialSymbol {
                text: "check"
                visible: root.task.done || check.hovered
                iconSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Design.background
            }
        }
        FText {
            id: body
            Layout.fillWidth: true
            // The user's own words: mixed case and upright (italics are FART's asides).
            text: root.task.text
            headline: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            font.capitalization: Font.MixedCase
            font.pixelSize: Design.readout
            font.letterSpacing: -0.2
            font.strikeout: root.task.done
            color: root.task.done ? Design.faint : Design.ink
            // The patina's copies, under the line, out of register.
            FText {
                z: -1
                visible: root.patina >= 1
                x: root.side * root.shift
                y: -root.side * root.shift * 0.4
                width: body.width
                text: body.text
                font: body.font
                wrapMode: body.wrapMode
                maximumLineCount: body.maximumLineCount
                color: Design.danger
                opacity: 0.3
            }
            FText {
                z: -1
                visible: root.patina >= 10
                x: -root.side * root.shift * 0.8
                y: root.side * root.shift * 0.5
                width: body.width
                text: body.text
                font: body.font
                wrapMode: body.wrapMode
                maximumLineCount: body.maximumLineCount
                color: Design.accent
                opacity: 0.24
            }
        }
        Row {
            visible: !!root.task.due
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.late || root.dueState === "today"
                width: 5
                height: 5
                color: root.late ? Design.accent : Design.ink
            }
            FText {
                // Narrow lines keep how late, not the date.
                text: root.width < 480 && root.late ? TaskEntry.label(root.task.due, root.today).split(" · ").pop()
                    : TaskEntry.label(root.task.due, root.today)
                technical: true
                color: root.task.done ? Design.faint : root.late ? Design.accent : root.dueState === "today" ? Design.ink : Design.muted
            }
        }
        FButton {
            id: remove
            symbol: "close"
            hint: "Remove task"
            iconSize: 16
            implicitWidth: 28
            implicitHeight: 28
            baseColor: "transparent"
            outlineColor: "transparent"
            opacity: root.hot ? 1 : 0.5
            onClicked: root.removed()
        }
    }
    Hairline {
        anchors.bottom: parent.bottom
        width: parent.width
        color: root.late ? Qt.alpha(Design.accent, 0.6) : Design.line
        node: 3
    }
    // The doubled rule, copied a little off.
    Hairline {
        visible: root.patina >= 3
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        x: 3 + root.side * 3
        width: parent.width - 6
        color: Qt.alpha(Design.accent, 0.3)
        node: 3
    }
    // The cut-out a task finished today leaves: its outline, dashed, and when it went.
    Item {
        id: cut
        visible: root.vanished
        anchors.fill: parent
        anchors.bottomMargin: 6
        anchors.topMargin: 3
        readonly property real run: height * Math.abs(Design.shear)
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Design.line
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                fillColor: "transparent"
                startX: cut.run; startY: 0
                PathLine { x: cut.width; y: 0 }
                PathLine { x: cut.width - cut.run; y: cut.height }
                PathLine { x: 0; y: cut.height }
                PathLine { x: cut.run; y: 0 }
            }
        }
        FText {
            anchors.right: parent.right
            anchors.rightMargin: 18 + cut.run
            anchors.verticalCenter: parent.verticalCenter
            text: root.task.doneAt ? "DONE " + Qt.formatTime(new Date(root.task.doneAt), "HH:mm") : "DONE"
            technical: true
            color: Design.faint
        }
    }
}
