import QtQuick
import qs.view.ui

Text {
    property bool technical: false
    font.family: technical ? Design.mono : FluidTokens.sans
    font.pixelSize: FluidTokens.body
    color: FluidTokens.ink
    renderType: Text.QtRendering
}
