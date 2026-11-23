import QtQuick
import QtQuick.Layouts
import qs.view.fluid
import qs.view.ui

// Side column (owner's pick B, 22 November 2026; Astra's tools/settings-action-study): a reading on the left, a fine
// vertical rule, and its actions starting in one right-hand column shared by every row. On a narrow panel the
// actions move underneath the reading. The reading goes in the default slot; the actions in `actions`.
GridLayout {
    id: root
    default property alias reading: readingSlot.data
    property alias actions: actionSlot.data
    // Narrow below this width: the right column would squeeze the reading.
    readonly property int narrowBelow: Design.baseline * 120
    // Read from the space the row is given (its parent), not its own width, which the column count changes.
    readonly property bool narrow: (parent ? parent.width : width) < narrowBelow
    readonly property int actionWidth: Design.baseline * 64
    columns: narrow ? 1 : 3
    columnSpacing: Design.baseline * 5
    rowSpacing: Design.baseline * 2

    ColumnLayout {
        id: readingSlot
        Layout.fillWidth: true
        // A layout's maximum is its children's unless lifted: short readings would stop the actions' column short.
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        Layout.alignment: Qt.AlignTop
        spacing: 0
    }
    Rectangle {
        visible: !root.narrow
        // As tall as the row's content; filling the height would make the whole row claim spare height.
        Layout.preferredHeight: Math.max(readingSlot.implicitHeight, actionSlot.implicitHeight)
        Layout.preferredWidth: 1
        color: Design.fluid ? FluidTokens.rule : Design.line
    }
    ColumnLayout {
        id: actionSlot
        Layout.preferredWidth: root.narrow ? -1 : root.actionWidth
        Layout.fillWidth: root.narrow
        Layout.maximumWidth: root.narrow ? Number.POSITIVE_INFINITY : root.actionWidth
        Layout.alignment: Qt.AlignTop
        spacing: 0
    }
}
