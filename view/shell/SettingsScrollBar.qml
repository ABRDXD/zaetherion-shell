import QtQuick
import QtQuick.Controls
import qs.view.ui

// Settings' scroll bar (Z219): a hairline track and a short ink bar, shown only when there is more to see.
ScrollBar {
    id: root
    property Flickable flick: null
    policy: flick && flick.contentHeight > flick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    width: Design.baseline * 2
    background: Rectangle { x: root.width - 1; width: 1; color: Design.line }
    contentItem: Rectangle { implicitWidth: Design.baseline / 2; x: root.width - width; color: Design.ink }
}
