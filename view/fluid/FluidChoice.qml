import QtQuick
import QtQuick.Controls

// A bounded, in-surface choice strip. Selection belongs to the caller.
FocusScope {
    id: root
    property var model: []
    property int currentIndex: -1
    property string label: "Choose"
    signal activated(int index)
    implicitHeight: FluidTokens.controlHeight
    implicitWidth: Math.min(420, strip.contentWidth)
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: label
    function reveal() {
        const item = choices.itemAt(currentIndex);
        if (!item) return;
        if (item.x < strip.contentX) strip.contentX = item.x;
        else if (item.x + item.width > strip.contentX + strip.width)
            strip.contentX = Math.max(0, item.x + item.width - strip.width);
    }
    function choose(index) {
        if (index >= 0 && index < model.length) activated(index);
    }
    onCurrentIndexChanged: Qt.callLater(reveal)
    onWidthChanged: Qt.callLater(reveal)
    Keys.onLeftPressed: choose(Math.max(0, currentIndex - 1))
    Keys.onRightPressed: choose(Math.min(model.length - 1, currentIndex + 1))
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) { choose(0); event.accepted = true; }
        else if (event.key === Qt.Key_End) { choose(model.length - 1); event.accepted = true; }
    }
    Flickable {
        id: strip
        anchors.fill: parent
        clip: true
        contentWidth: row.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        Row {
            id: row
            spacing: FluidTokens.unit
            Repeater {
                id: choices
                model: root.model
                onItemAdded: Qt.callLater(root.reveal)
                FluidButton {
                    required property var modelData
                    required property int index
                    width: Math.min(220, strip.width, implicitWidth)
                    text: String(modelData)
                    selected: index === root.currentIndex
                    activeFocusOnTab: false
                    Accessible.role: Accessible.ListItem
                    Accessible.selected: selected
                    onClicked: { root.forceActiveFocus(); root.choose(index); }
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.activeFocus
        radius: FluidTokens.controlRadius
        color: "transparent"
        border.width: 2
        border.color: FluidTokens.ink
    }
}
