import QtQuick

// A level as a row of −12° blades: signal up to the level, faint ink after it. Static between changes.
Row {
    id: root
    property real level: 0
    property bool muted: false
    property int blades: 24
    readonly property real clamped: Math.max(0, Math.min(1, level))
    height: Design.baseline * 2
    spacing: 3

    Repeater {
        model: root.blades
        Plane {
            required property int index
            width: Math.max(1, (root.width - root.spacing * (root.blades - 1)) / root.blades)
            height: root.height
            role: !root.muted && (index + 1) / root.blades <= root.clamped + 1e-6 ? "signal" : "ink"
            opacity: role === "signal" ? 1 : 0.22
            slant: 3
        }
    }
}
