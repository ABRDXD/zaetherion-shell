import QtQuick

Text {
    required property LockLook look
    property bool technical: false
    textFormat: Text.PlainText
    color: look.ink
    font.family: technical ? "DejaVu Sans Mono" : "Inter"
    font.pixelSize: technical ? look.small : look.body
    font.letterSpacing: technical ? 1.5 : 0
}
