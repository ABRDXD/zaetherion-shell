import QtQuick
import QtQuick.Controls
import qs.view.ui
import qs.view.fluid

// One settings action and handler through either visual form.
Loader {
    id: root
    property string label: ""
    property string hint: ""
    property string symbol: ""
    property bool selected: false
    property bool primary: false
    signal clicked()
    sourceComponent: Design.fluid ? fluid : angular
    Component {
        id: angular
        FButton {
            label: root.label
            hint: root.hint
            symbol: root.symbol
            selected: root.selected
            primary: root.primary
            onClicked: root.clicked()
        }
    }
    Component {
        id: fluid
        FluidButton {
            text: root.label || root.hint
            selected: root.selected
            primary: root.primary
            ToolTip.visible: hovered && root.hint !== ""
            ToolTip.text: root.hint
            ToolTip.delay: 600
            background: Rectangle {
                radius: height / 2
                color: root.primary ? FluidTokens.accent : Qt.tint(FluidTokens.base,
                    Qt.alpha(FluidTokens.ink, parent.hovered || parent.down ? 0.18 : 0.10))
                border.width: parent.visualFocus || root.selected ? 1 : 0
                border.color: FluidTokens.accent
            }
            onClicked: root.clicked()
        }
    }
}
