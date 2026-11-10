import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "WeekLedger.js" as Ledger

// One week of the calendar (Home). Seven day tiles, Monday first. The selected day is a signal plane,
// today carries a signal rule; ‹ › move by a week and the tiles fade and shift in (calendar.swap).
ColumnLayout {
    id: root
    property color accent: Design.calendarAccent
    property date selectedDate: Clock.date
    // The journey ({days: {date: {room: visits}}}): in Overdrive each past day is inked by its use (WeekLedger, §42).
    property var journey: null
    // The Monday of the week shown.
    property date week: monday(Clock.date)
    readonly property bool thisWeek: sameDay(week, monday(Clock.date))
    readonly property int weekNumber: isoWeek(new Date(week.getFullYear(), week.getMonth(), week.getDate() + 3))

    function monday(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - (d.getDay() + 6) % 7);
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    // ISO 8601 week number of a Thursday.
    function isoWeek(thursday) {
        const first = new Date(thursday.getFullYear(), 0, 4);
        return 1 + Math.round(((thursday - first) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7);
    }
    // The week changes on the click; the new tiles then fade and shift in (docs/CUES.md Q2).
    function shiftWeek(delta) {
        root.week = new Date(root.week.getFullYear(), root.week.getMonth(), root.week.getDate() + 7 * delta);
        swap.replay();
    }
    function today() {
        root.week = monday(Clock.date);
        root.selectedDate = Clock.date;
        swap.replay();
    }

    spacing: 8
    Cue {
        id: swap
        name: "calendar.swap"
        on: true
        scope: root
        enter: Motion.swap
        easing: Motion.roles.swap.easing
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        FText {
            Layout.fillWidth: true
            text: "WEEK " + String(root.weekNumber).padStart(2, "0") + "   ·   " + Qt.formatDate(root.week, "MMMM yyyy")
            technical: true
            font.pixelSize: Design.control
            color: Design.muted
        }
        FButton {
            visible: !root.thisWeek
            label: "Today"
            implicitHeight: 26
            onClicked: root.today()
        }
        FButton {
            implicitWidth: 26
            implicitHeight: 26
            symbol: "chevron_left"
            hint: "Previous week"
            onClicked: root.shiftWeek(-1)
        }
        FButton {
            implicitWidth: 26
            implicitHeight: 26
            symbol: "chevron_right"
            hint: "Next week"
            onClicked: root.shiftWeek(1)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        uniformCellSizes: true
        opacity: swap.value
        transform: Translate { y: Motion.nudge * (1 - swap.value) }
        Repeater {
            model: 7
            AbstractButton {
                id: day
                required property int index
                readonly property date date: new Date(root.week.getFullYear(), root.week.getMonth(), root.week.getDate() + index)
                readonly property bool selected: root.sameDay(date, root.selectedDate)
                readonly property bool isToday: root.sameDay(date, Clock.date)
                readonly property bool weekend: index > 4
                Layout.fillWidth: true
                implicitHeight: 54
                hoverEnabled: true
                Accessible.name: Qt.formatDate(date, "dddd d MMMM")
                onClicked: {
                    Feedback.play("ui.click");
                    root.selectedDate = date;
                }
                // A soft filled tile leaning on the −12° shear; the selected day is filled with the accent.
                background: Item {
                    id: tile
                    readonly property color textColor: Design.onSignal ?? Design.background
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        antialiasing: true
                        color: day.selected ? Design.accent : day.hovered || day.down ? Design.hover : Design.surface
                        border.width: day.isToday && !day.selected ? 1 : 0
                        border.color: root.accent
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * day.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }
                    // Overdrive: the day as a ledger, inked from the bottom by how much FART was used that day, with the
                    // number of the room it was spent in most (docs/OVERDRIVE.md §42).
                    Stratum {
                        id: ledger
                        readonly property string key: Qt.formatDate(day.date, "yyyy-MM-dd")
                        readonly property real share: Ledger.share(root.journey?.days, key)
                        anchors.fill: parent
                        name: "week.ledger." + day.index
                        gpu: false
                        scope: day
                        wanted: share > 0
                        sourceComponent: Item {
                            opacity: Motion.drive
                            Rectangle {
                                x: 4
                                y: parent.height - 3 - height
                                width: parent.width - 8
                                height: Math.max(2, (parent.height - 6) * ledger.share)
                                color: Qt.alpha(day.selected ? tile.textColor : root.accent, 0.24)
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * (day.height - 6) / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                }
                            }
                            FText {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                y: 4
                                text: Ledger.dominant(root.journey?.days, ledger.key)
                                technical: true
                                font.pixelSize: Design.caption
                                color: day.selected ? tile.textColor : root.accent
                            }
                        }
                    }
                }
                contentItem: Item {
                    // The day name and the numeral share one baseline-led column that fills the tile.
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        text: Qt.formatDate(day.date, "ddd")
                        technical: true
                        color: day.selected ? tile.textColor : day.weekend ? root.accent : Design.muted
                    }
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 14
                        text: day.date.getDate()
                        headline: true
                        font.pixelSize: Design.figure
                        font.weight: day.selected || day.isToday ? Font.Black : Font.Light
                        color: day.selected ? tile.textColor : Design.ink
                    }
                    // Today, when another day is selected.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 16
                        height: 2
                        visible: day.isToday && !day.selected
                        color: root.accent
                    }
                }
            }
        }
    }
}
