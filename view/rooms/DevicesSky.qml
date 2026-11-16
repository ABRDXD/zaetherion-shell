import qs.view.ui
import qs.view.cues
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "DevicesSkyLayout.js" as L

// Devices' signal map (Z212, owner's pick "B · The signal map", 16 November 2026). The laptop is a planet lit by
// its battery (the lit side reaches further the fuller it is; warm while charging). Round it, three tilted rings
// fill with its levels: output volume (outermost), microphone, screen brightness; a muted one goes dim. The joined
// Wi-Fi network is a satellite, nearer the stronger its signal; other networks the host already lists are faint
// stars beyond it, brighter when stronger, and a click joins one (as the Nearby list does). Connected Bluetooth
// devices are moons close in. Stars show while the host lists networks (the Nearby page's scan); no scan of its own. The levels are changed with the room's meters; the map only shows them. In Overdrive
// the satellite sends out a slow ping (one IdleLoop); Silent is still.
Item {
    id: root
    required property var network
    required property var bluetooth
    required property var audio
    required property var power
    signal join(string id)
    // The rings are seen from a little above: their height is this share of their width.
    readonly property real tilt: 0.64
    readonly property real half: Math.min(width / 2, height / 2 / tilt)
    readonly property point centre: Qt.point(width / 2, height / 2)
    readonly property real planetSize: half * 0.6
    readonly property var battery: power.battery ?? ({ available: false, level: 0, charging: false })
    readonly property bool linked: network.connected && network.kind !== "ethernet"
    // The joined network's strength when the host lists it (the list fills while the Nearby page scans); else unknown.
    readonly property var linkStrength: (network.networks.find(n => n.connected) ?? {}).strength ?? null
    readonly property var levels: [
        { label: "OUTPUT", level: audio.output?.volume ?? 0, available: audio.output !== null, muted: audio.output?.muted ?? false, tone: Design.ink },
        { label: "MIC", level: audio.input?.volume ?? 0, available: audio.input !== null, muted: audio.input?.muted ?? false, tone: Design.warm },
        { label: "SCREEN", level: power.brightness?.level ?? 0, available: power.brightness?.available ?? false, muted: false, tone: Design.coldStar }
    ]
    IdleLoop { id: ping; scope: root; name: "devices.ping"; period: 2600; enabled: root.linked }

    // Orbits and rings.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(Design.line, 0.35)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 6]
            fillColor: "transparent"
            PathAngleArc { centerX: root.centre.x; centerY: root.centre.y; radiusX: root.half * 0.84; radiusY: root.half * 0.84 * root.tilt; startAngle: 0; sweepAngle: 360 }
        }
    }
    Repeater {
        model: root.levels
        Shape {
            id: ringShape
            required property var modelData
            required property int index
            readonly property real r: root.half * L.ring(index)
            readonly property var arc: L.arc(modelData.level)
            readonly property real stroke: 10 - 2 * index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: modelData.available ? 1 : 0.35
            ShapePath {
                strokeColor: Qt.alpha(Design.line, 0.4)
                strokeWidth: ringShape.stroke
                fillColor: "transparent"
                PathAngleArc { centerX: root.centre.x; centerY: root.centre.y; radiusX: ringShape.r; radiusY: ringShape.r * root.tilt; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: ringShape.modelData.muted ? Qt.alpha(ringShape.modelData.tone, 0.3) : ringShape.modelData.tone
                strokeWidth: ringShape.stroke
                capStyle: ShapePath.FlatCap
                fillColor: "transparent"
                PathAngleArc { centerX: root.centre.x; centerY: root.centre.y; radiusX: ringShape.r; radiusY: ringShape.r * root.tilt; startAngle: ringShape.arc.start; sweepAngle: ringShape.arc.sweep }
            }
        }
    }
    // Each ring's label where its arc ends.
    Repeater {
        model: root.levels
        FText {
            required property var modelData
            required property int index
            readonly property var end: L.arcEnd(modelData.level)
            readonly property real r: root.half * L.ring(index) + 14
            x: root.centre.x + r * end.x + (end.x < 0 ? -width - 4 : 4)
            y: root.centre.y + r * root.tilt * end.y - height / 2
            text: modelData.label + " " + L.percent(modelData.level, modelData.available) + (modelData.muted ? " · MUTED" : "")
            technical: true
            color: modelData.muted ? Design.faint : modelData.tone
        }
    }

    // The laptop, lit by its battery.
    Rectangle {
        id: planet
        x: root.centre.x - width / 2
        y: root.centre.y - height / 2
        width: root.planetSize
        height: width
        radius: width / 2
        border.width: 1
        border.color: Qt.alpha(Design.coldRim, 0.35)
        readonly property color light: root.battery.charging ? Design.warm : Design.coldCore
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.battery.available ? planet.light : Qt.alpha(Design.coldRim, 0.35) }
            GradientStop { position: L.lit(root.battery.available ? root.battery.level / (root.battery.level > 1 ? 100 : 1) : 0.4); color: Design.coldBody }
            GradientStop { position: 1; color: Design.coldBody }
        }
    }
    Column {
        anchors.horizontalCenter: planet.horizontalCenter
        anchors.top: planet.bottom
        anchors.topMargin: root.half * 0.42 * root.tilt
        z: 2
        FText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.battery.available ? L.percent(root.battery.level > 1 ? root.battery.level / 100 : root.battery.level) + "%" : "AC"
            headline: true
            font.pixelSize: Design.figure
            font.weight: Font.Black
        }
        FText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !root.battery.available ? "NO BATTERY" : root.battery.charging ? "CHARGING" : root.battery.pluggedIn ? "PLUGGED IN" : "ON BATTERY"
            technical: true
            color: root.battery.charging ? Design.warm : Design.muted
        }
    }

    // Connected Bluetooth devices: moons close in.
    Repeater {
        model: root.bluetooth.enabled ? root.bluetooth.devices.filter(d => d.connected) : []
        Item {
            required property var modelData
            required property int index
            readonly property real a: -Math.PI * 0.75 + index * 0.6
            x: root.centre.x + root.planetSize * 0.78 * Math.cos(a)
            y: root.centre.y + root.planetSize * 0.78 * root.tilt * Math.sin(a)
            Rectangle { x: -4; y: -4; width: 8; height: 8; radius: 4; color: Design.accent }
            FText { x: 8; y: -height / 2; text: modelData.name; technical: true; color: Design.accent }
        }
    }

    // Other networks: stars beyond the satellite. A click joins (known) or asks the host for a password (new).
    Repeater {
        model: root.network.wifiEnabled ? L.stars(root.network.networks) : []
        AbstractButton {
            id: star
            required property var modelData
            x: root.centre.x + root.half * modelData.r * Math.cos(modelData.angle) - width / 2
            y: root.centre.y + root.half * modelData.r * root.tilt * Math.sin(modelData.angle) - height / 2
            width: 44
            height: 44
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.name: "Join " + modelData.ssid + (modelData.known ? ", known" : ", new")
            onClicked: { Feedback.play("ui.click"); root.join(modelData.id); }
            background: Rectangle {
                x: (star.width - width) / 2
                y: (star.height - height) / 2
                width: star.modelData.size + (star.hovered || star.activeFocus ? 4 : 0)
                height: width
                radius: width / 2
                color: star.hovered || star.activeFocus ? Design.ink : star.modelData.known ? Design.coldStar : Design.muted
            }
            contentItem: Item {
                FText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 + 8
                    text: star.modelData.ssid
                    technical: true
                    color: star.hovered || star.activeFocus ? Design.ink : Design.faint
                }
            }
        }
    }

    // The joined network: a satellite, nearer the stronger.
    Item {
        id: satellite
        visible: root.linked
        readonly property real a: -0.55
        readonly property real r: root.half * L.satellite(root.linkStrength ?? 0.5)
        x: root.centre.x + r * Math.cos(a)
        y: root.centre.y + r * root.tilt * Math.sin(a)
        z: 3
        Rectangle {
            x: -width / 2; y: -height / 2
            width: 30; height: 30; radius: 15
            color: "transparent"
            border.width: 1
            border.color: Design.accent
            opacity: ping.level * (1 - ping.phase)
            scale: 0.6 + 1.2 * ping.phase
        }
        Rectangle { x: -8; y: -8; width: 16; height: 16; radius: 8; color: Design.accent }
        FText {
            x: 14
            y: -height - 6
            text: root.network.name + (root.linkStrength === null ? "" : " · " + Math.round(L.unit(root.linkStrength) * 100) + "%")
            technical: true
            color: Design.accent
        }
    }
    Rectangle {
        visible: root.linked
        x: root.centre.x
        y: root.centre.y
        width: Math.hypot(satellite.x - root.centre.x, satellite.y - root.centre.y)
        height: 1
        transformOrigin: Item.Left
        rotation: Math.atan2(satellite.y - root.centre.y, satellite.x - root.centre.x) * 180 / Math.PI
        color: Qt.alpha(Design.accent, 0.35)
        z: -1
    }
}
