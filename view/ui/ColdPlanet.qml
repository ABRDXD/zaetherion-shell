import QtQuick

// A planet seen by a cold star's light (Z199): a dark disc with a thin crescent on the side facing the star and a faint
// cold limb, so it reads against black. Centred on its x, y. `lit` 0–1: how much of the crescent shows (none when the
// planet is straight in front of the star); `litRight`: the star is to its right; `depth` 0 (far) – 1 (near).
Rectangle {
    id: root
    property real size: 10
    property real lit: 1
    property bool litRight: false
    property real depth: 1
    x: -size / 2
    y: -size / 2
    width: size
    height: size
    radius: size / 2
    border.width: 1
    border.color: Qt.alpha(Design.coldRim, 0.18 + 0.2 * depth)
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: root.litRight ? Design.coldBody : Qt.alpha(Design.coldRim, root.lit) }
        GradientStop { position: root.litRight ? 0.72 : 0.28; color: Design.coldBody }
        GradientStop { position: 1; color: root.litRight ? Qt.alpha(Design.coldRim, root.lit) : Design.coldBody }
    }
}
