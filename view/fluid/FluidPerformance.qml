import QtQuick
import QtQuick.Layouts
import qs.view.rooms
import qs.view.cues
import qs.view.ui
import "PerformanceStarLayout.js" as Star

// Confluence Performance (owner's pick "A · The star", 15 November 2026): the machine as a star at the centre of the
// room (PerformanceStar), the processor's reading on its left and memory's on its right, mirrored; the verdict and
// disk/swap quietly under it. The core-shell and planet layers come from samplers that only run in Overdrive
// (`telemetry.sched`, `orrery.sample`), asked once a second while the room shows; in Silent the star alone.
Item {
    id: root
    required property PerformanceSession controller
    readonly property var cpu: controller.cpu
    readonly property var memory: controller.memory
    readonly property var gpu: controller.sensor
    readonly property real memoryShare: memory.available && memory.total > 0 ? memory.used / memory.total : 0
    readonly property var heat: Star.heat(controller.temperatureAvailable ? cpu.temperature : null)

    component Caption: FluidText { color: FluidTokens.secondary; font.pixelSize: FluidTokens.caption; font.capitalization: Font.AllUppercase; font.letterSpacing: 2 }

    // Overdrive's layers: each core's load and the heaviest processes, while the room shows in Overdrive.
    property var cores: []
    property var planets: []
    readonly property bool sampling: controller.active && Motion.overdrive
    onSamplingChanged: if (!sampling) { cores = []; planets = []; }
    Timer {
        interval: Star.sampleMs
        repeat: true
        triggeredOnStart: true
        running: root.sampling
        onTriggered: {
            const core = root.controller.shell.core;
            core?.request("telemetry.sched", {}, (ok, result) => { if (ok && result?.running && root) root.cores = result.cores ?? []; });
            core?.request("orrery.sample", {}, (ok, result) => {
                if (!ok || !result?.running || !root) return;
                root.planets = (result.bodies ?? []).slice().sort((a, b) => (b.rss ?? 0) - (a.rss ?? 0)).slice(0, Star.planetCount);
            });
        }
    }

    PerformanceStar {
        objectName: "performance.star"
        anchors.fill: parent
        load: root.cpu.available ? root.cpu.usage : 0
        temperature: root.controller.temperatureAvailable ? root.cpu.temperature : null
        memory: root.memoryShare
        history: root.cpu.history ?? []
        gpuAvailable: root.gpu.available
        gpuLoad: root.gpu.available ? root.gpu.usage : 0
        gpuTemperature: root.controller.gpuTemperature ? root.gpu.temperature : null
        cores: root.cores
        planets: root.planets
    }

    // The processor, left of the star.
    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: FluidTokens.sectionGap * 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.12
        spacing: FluidTokens.unit
        Caption { text: "Processor" + (root.cores.length ? " · " + root.cores.length + " cores" : "") }
        Row {
            RollingDigits {
                objectName: "performance.cpu"
                text: root.cpu.available ? String(Math.round(root.cpu.usage * 100)) : "—"
                font.family: FluidTokens.sans
                font.pixelSize: FluidTokens.clock * 1.5 // scale: the room's one primary reading
                font.weight: Font.ExtraLight
            }
            FluidText { text: "%"; font.pixelSize: FluidTokens.title; font.weight: Font.Light; color: FluidTokens.secondary; anchors.bottom: parent.bottom; anchors.bottomMargin: FluidTokens.unit * 3 }
        }
        FluidText {
            objectName: "performance.temperature"
            text: root.controller.temperatureAvailable
                ? Math.round(root.cpu.temperature) + "°C · the star burns " + Star.colourName(root.heat)
                : "No temperature sensor; the colour follows the load."
            font.pixelSize: FluidTokens.heading
            font.weight: Font.Light
            color: FluidTokens.secondary
        }
    }

    // Memory, right of the star, mirrored.
    ColumnLayout {
        anchors.right: parent.right
        anchors.rightMargin: FluidTokens.sectionGap * 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.12
        spacing: FluidTokens.unit
        Caption { Layout.alignment: Qt.AlignRight; text: "Memory · the star's size" }
        Row {
            Layout.alignment: Qt.AlignRight
            RollingDigits {
                objectName: "performance.memory"
                text: root.memory.available ? (root.memory.used / 1048576).toFixed(1) : "—"
                font.family: FluidTokens.sans
                font.pixelSize: FluidTokens.clock * 0.7 // scale: secondary to the processor
                font.weight: Font.ExtraLight
            }
            FluidText { text: " GiB"; font.pixelSize: FluidTokens.title; font.weight: Font.Light; color: FluidTokens.secondary; anchors.bottom: parent.bottom; anchors.bottomMargin: FluidTokens.unit * 3 }
        }
        FluidText {
            Layout.alignment: Qt.AlignRight
            text: "of " + (root.memory.total / 1048576).toFixed(0) + " GiB"
                + (root.gpu.available ? " · GPU " + Math.round(root.gpu.usage * 100) + "%" + (root.controller.gpuTemperature ? ", " + Math.round(root.gpu.temperature) + "°C" : "") : "")
            font.pixelSize: FluidTokens.heading
            font.weight: Font.Light
            color: FluidTokens.secondary
        }
    }

    // The verdict, then the quiet instruments: GPU, temperature, disk and swap, each a figure over a thin gauge.
    component Instrument: Column {
        id: instrument
        property string label: ""
        property string value: ""
        property real share: 0          // 0–1, the gauge
        property bool warn: false
        spacing: FluidTokens.unit
        width: 168
        Caption { text: instrument.label }
        FluidText { text: instrument.value; font.pixelSize: FluidTokens.heading; font.weight: Font.Light; color: instrument.warn ? FluidTokens.accent : FluidTokens.ink }
        Rectangle {
            width: parent.width; height: 2; radius: 1; color: FluidTokens.rule
            Rectangle { width: parent.width * Math.max(0, Math.min(1, instrument.share)); height: parent.height; radius: 1
                        color: instrument.warn ? FluidTokens.accent : Qt.alpha(FluidTokens.ink, 0.6) }
        }
    }
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: FluidTokens.gap
        spacing: FluidTokens.gap
        FluidText {
            objectName: "performance.verdict"
            Layout.alignment: Qt.AlignHCenter
            readonly property real load: root.cpu.available ? root.cpu.usage : 0
            text: !root.cpu.available ? "Sampling the star…"
                : load < 0.3 ? "A quiet star." : load < 0.7 ? "Working steadily."
                : "Burning hot" + (root.planets.length ? ". " + root.planets[0].name + " is the heaviest planet." : ".")
            font.pixelSize: FluidTokens.heading
            font.weight: Font.Light
        }
        Row {
            objectName: "performance.instruments"
            Layout.alignment: Qt.AlignHCenter
            spacing: FluidTokens.sectionGap * 1.5
            Instrument {
                label: "GPU"
                value: root.gpu.available ? Math.round(root.gpu.usage * 100) + "%" + (root.controller.gpuTemperature ? " · " + Math.round(root.gpu.temperature) + "°C" : "") : "None"
                share: root.gpu.available ? root.gpu.usage : 0
            }
            Instrument {
                label: "Surface"
                value: root.controller.temperatureAvailable ? Math.round(root.cpu.temperature) + "°C" : "No sensor"
                share: root.heat ?? 0
                warn: (root.heat ?? 0) > 0.85
            }
            Instrument {
                label: "Disk"
                value: root.controller.disk.available ? root.controller.gigabytes(root.controller.disk.free) + " free" : "Pending"
                share: root.controller.diskUsed
                warn: root.controller.diskWarning
            }
            Instrument {
                label: "Swap"
                value: root.memory.swapTotal > 0 ? root.controller.gigabytes(root.memory.swapUsed) : "None"
                share: root.memory.swapTotal > 0 ? root.memory.swapUsed / root.memory.swapTotal : 0
            }
        }
        Caption {
            Layout.alignment: Qt.AlignHCenter
            visible: !Motion.overdrive
            text: "Overdrive shows each core and the heaviest processes"
            opacity: 0.7
        }
    }
}
