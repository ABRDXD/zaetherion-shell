import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property string number: "01"
    property string title: ""
    property string subtitle: ""
    spacing: 6
    RowLayout {
        spacing: 12
        FText { text: number; technical: true; color: Design.muted }
        FText { text: "·"; technical: true; color: Design.muted }
        FText { text: subtitle.toUpperCase(); technical: true; color: Design.muted }
    }
    FText {
        text: parent.title
        headline: true
        sheared: true
        font.pixelSize: Design.headline
        font.weight: Font.Black
        font.letterSpacing: -0.8
        font.wordSpacing: 2
        Layout.fillWidth: true
    }
}
