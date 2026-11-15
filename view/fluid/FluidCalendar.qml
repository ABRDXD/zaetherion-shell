import QtQuick
import QtQuick.Layouts
import qs.view.ui

// Calendar navigation is owned by HomeSession, so replacing this view keeps the month.
ColumnLayout {
    id: root
    required property date month
    signal shift(int months)
    spacing: FluidTokens.unit * 2
    readonly property int first: (new Date(month.getFullYear(), month.getMonth(), 1).getDay() + 6) % 7
    readonly property int days: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    RowLayout {
        Layout.fillWidth: true
        FluidText { Layout.fillWidth: true; text: Qt.formatDate(root.month, "MMMM yyyy"); color: FluidTokens.secondary }
        FluidButton { objectName: "home.month.previous"; text: "‹"; implicitWidth: FluidTokens.controlHeight; Accessible.name: "Previous month"; onClicked: root.shift(-1) }
        FluidButton { objectName: "home.month.next"; text: "›"; implicitWidth: FluidTokens.controlHeight; Accessible.name: "Next month"; onClicked: root.shift(1) }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: FluidTokens.unit
        rowSpacing: FluidTokens.unit
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            FluidText {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                font.pixelSize: FluidTokens.caption
                color: FluidTokens.secondary
            }
        }
        Repeater {
            model: 42
            Rectangle {
                required property int index
                readonly property int day: index - root.first + 1
                readonly property bool inMonth: day > 0 && day <= root.days
                readonly property bool today: inMonth && day === Clock.date.getDate() && root.month.getMonth() === Clock.date.getMonth() && root.month.getFullYear() === Clock.date.getFullYear()
                Layout.fillWidth: true
                Layout.minimumWidth: 24
                Layout.preferredHeight: 25
                radius: FluidTokens.controlRadius
                color: today ? FluidTokens.accent : "transparent"
                FluidText {
                    anchors.centerIn: parent
                    text: parent.inMonth ? String(parent.day) : ""
                    font.pixelSize: FluidTokens.caption
                    color: parent.today ? FluidTokens.base : FluidTokens.ink
                }
            }
        }
    }
}
