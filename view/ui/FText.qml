import QtQuick
import QtQuick.Layouts

Text {
    id: root
    // Only the shell's aside voice is italic. Even asides keep CJK upright;
    // disabling the whole mixed run avoids synthesized oblique fallback glyphs.
    property bool technical: false
    property bool editorial: false
    property bool aside: false
    property bool headline: false
    property bool sheared: !aside && font.pixelSize >= 32 && /[0-9]/.test(text)
    // Registration voices (atlas #45, docs/OVERDRIVE.md §24): where a figure comes from, set a pixel off the line,
    // unnoticed until noticed. "kernel" (the machine's own counters) sits 1 px low, "media" (the player) 1 px high;
    // the user's own data, and everything else, on the line.
    property string voice: ""
    readonly property real voiceShift: voice === "kernel" ? 1 : voice === "media" ? -1 : 0
    // Set from outside by Overdrive's typesetters (view/rooms/HarmonicType, docs/OVERDRIVE.md §39): a horizontal
    // stretch from the left edge and an extra lean (a shear, like Design.shear). 1 and 0 leave the text as it is.
    property real stretch: 1
    property real slant: 0
    readonly property bool containsCjk: /[\u2e80-\u9fff\uac00-\ud7af\uf900-\ufaff\uff00-\uffef]/.test(text)
    Layout.minimumWidth: 0
    color: Design.ink
    font.weight: Font.Normal
    font.italic: aside && !technical && !containsCjk && Design.italic
    font.styleName: ""
    font.features: ({ "tnum": 1 })
    font.family: headline ? Design.sans : Design.mono
    font.capitalization: aside ? Font.MixedCase : Font.AllUppercase
    font.pixelSize: technical ? Design.caption : Design.body
    font.letterSpacing: headline ? -0.8 : 0.7
    textFormat: Text.PlainText
    renderType: Text.QtRendering
    elide: Text.ElideRight
    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(root.stretch, (root.sheared && !root.containsCjk ? Design.shear : 0) + root.slant, 0,
                            -((root.sheared && !root.containsCjk ? Design.shear : 0) + root.slant) * root.height / 2,
                            0, 1, 0, root.voiceShift,
                            0, 0, 1, 0,
                            0, 0, 0, 1)
    }
}
