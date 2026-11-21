import QtQuick
import qs.view.fluid
import qs.view.ui

// Settings keeps each reading's role while switching its typeface and scale.
FText {
    font.family: Design.fluid ? FluidTokens.sans : headline ? Design.sans : Design.mono
    font.capitalization: Design.fluid || aside ? Font.MixedCase : Font.AllUppercase
    font.pixelSize: Design.fluid ? (technical ? FluidTokens.caption : FluidTokens.body)
        : technical ? Design.caption : Design.body
    font.letterSpacing: Design.fluid ? 0 : headline ? -0.8 : 0.7
    font.italic: !Design.fluid && aside && !technical && !containsCjk && Design.italic
    sheared: !Design.fluid && !aside && font.pixelSize >= Design.figure && /[0-9]/.test(text)
}
