import qs.view.contract
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Controls

// The Codex: what everything is called. Two sheets: your keys, drawn as the keyboard itself (hold or click a modifier and the
// board shows what it does), and the elements. [ and ] change rooms as everywhere; Tab reaches the two tabs.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    readonly property var keybinds: host.keybinds
    readonly property var tabs: [{ id: "keys", name: "KEYS" }, { id: "elements", name: "ELEMENTS" }]
    Component.onCompleted: keybinds.refresh()
    function showTab(id) { ViewState.codexTab = id; }

    FText {
        id: heading
        text: ViewState.codexTab === "elements" ? "ELEMENTS" : "KEYS"
        headline: true
        font.pixelSize: Design.headline
        font.weight: Font.Black
        font.letterSpacing: -2
    }
    Row {
        id: tabRow
        anchors.right: parent.right
        anchors.bottom: heading.bottom
        anchors.bottomMargin: 8
        spacing: 4
        Repeater {
            model: root.tabs
            AbstractButton {
                id: tab
                required property var modelData
                readonly property bool chosen: ViewState.codexTab === modelData.id
                implicitWidth: label.implicitWidth + 44
                implicitHeight: 34
                activeFocusOnTab: true
                hoverEnabled: true
                Accessible.name: modelData.name
                onClicked: {
                    ViewState.codexTab = modelData.id;
                    Feedback.play("ui.switch");
                }
                background: Plane {
                    id: tabPlane
                    role: tab.chosen ? "ink" : tab.hovered || tab.activeFocus ? "paper" : "clear"
                    slant: 3
                }
                contentItem: FText {
                    id: label
                    z: 10
                    text: tab.modelData.name
                    technical: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: tabPlane.textColor
                }
            }
        }
    }
    Hairline {
        id: rule
        anchors.top: heading.bottom
        anchors.topMargin: 8
        width: parent.width
        node: 2
    }
    Loader {
        anchors.top: rule.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sourceComponent: ViewState.codexTab === "elements" ? elementsSheet : keysSheet
    }
    Component { id: keysSheet; CodexKeys { keybinds: root.keybinds } }
    Component { id: elementsSheet; CodexElements {} }
}
