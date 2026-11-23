import qs.view.contract
import qs.view.shell
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

// Angular Performance (MONTAGE.md §5): the halo holds the machine. The selected reading is large in the centre,
// the others orbit it; choosing one swaps it in. Beside the halo, the selected reading's record: its
// trace (or its share, for disk and swap) and its figures.
ColumnLayout {
    id: root
    // Today's look, unchanged: everything it reads comes from the controller (PerformanceSession).
    required property PerformanceSession controller
    readonly property var host: controller.host
    readonly property var shell: controller.shell
    readonly property var active: controller.active
    readonly property var system: controller.system
    readonly property var cpu: controller.cpu
    readonly property var memory: controller.memory
    readonly property var disk: controller.disk
    readonly property var sensor: controller.sensor
    readonly property var memoryPressure: controller.memoryPressure
    readonly property var diskUsed: controller.diskUsed
    readonly property var diskCritical: controller.diskCritical
    readonly property var diskWarning: controller.diskWarning
    readonly property var temperatureAvailable: controller.temperatureAvailable
    readonly property var gpuTemperature: controller.gpuTemperature
    readonly property var readings: controller.readings
    readonly property var weather: controller.weather
    readonly property var barograph: controller.barograph
    readonly property var weatherDetail: controller.weatherDetail
    function gigabytes(kb) { return controller.gigabytes(kb); }
    function percent(available, value) { return controller.percent(available, value); }
    readonly property var reading: readings[halo.currentIndex] ?? readings[0]
    readonly property color readingInk: reading.hot ? Design.danger : reading.warm ? Design.warning : Design.ink
    spacing: 12

    // The sheet's head: the selected reading on an inverted ink bar, ruled out to the edge.
    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Item {
            implicitWidth: tag.implicitWidth + 44
            implicitHeight: 30
            Plane {
                id: tagPlane
                anchors.fill: parent
                role: "ink"
                slant: 3
            }
            Row {
                id: tag
                anchors.centerIn: parent
                spacing: 12
                FText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(halo.currentIndex + 1).padStart(2, "0") + " / " + String(root.readings.length).padStart(2, "0")
                    technical: true
                    color: tagPlane.textColor
                }
                FText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.reading.name
                    headline: true
                    font.pixelSize: Design.readout
                    font.weight: Font.Black
                    font.capitalization: Font.AllUppercase
                    color: tagPlane.textColor
                }
            }
        }
        Hairline {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 14
            color: Design.line
        }
        // The machine's weather since you last looked (core/weather.py, atlas #75): a barograph of the last reports
        // and the latest sentence. Before the first report, the old promise.
        Item {
            visible: root.width >= 720 && root.barograph.length >= 2
            implicitWidth: 64
            implicitHeight: 14
            Layout.rightMargin: 10
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Design.muted
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathPolyline { path: root.barograph }
                }
            }
        }
        FText {
            visible: root.width >= 720
            Layout.maximumWidth: root.width * 0.62
            text: root.weather?.latest ? (root.weather.latest.sentence + " · " + root.weather.latest.values.hpa + " hPa").toUpperCase() : "NO SYNTHETIC READINGS"
            technical: true
            elide: Text.ElideRight
            voice: root.weather?.latest ? "kernel" : ""
            color: root.weather?.latest ? Design.muted : Design.faint
            HoverHandler { id: weatherHover }
            ToolTip.visible: weatherHover.hovered && !!root.weather?.latest
            ToolTip.text: root.weatherDetail
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 28
        // The instrument: the orbit around the reading, set as a poster numeral, with the sheet's marks.
        Item {
            id: left
            Layout.preferredWidth: Math.min(root.width * (root.width < 700 ? 0.65 : 0.6), 620)
            Layout.minimumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            Repeater {
                model: 4
                Register {
                    required property int index
                    x: (index % 2 ? left.width - width : 0)
                    y: (index > 1 ? left.height - height : 0)
                }
            }
            FText {
                x: 20
                y: 0
                text: "ORBIT " + String(root.readings.length).padStart(2, "0") + " · TILT " + halo.tilt.toFixed(2)
                technical: true
                color: Design.faint
            }
            // Overdrive: the interrupts falling on a baseline (InterruptRain, atlas #17), along the halo's foot.
            Stratum {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.rightMargin: 64
                anchors.bottomMargin: 18
                height: 34
                name: "performance.rain"
                gpu: false
                scope: left
                wanted: root.active
                sourceComponent: InterruptRain { core: root.shell.core }
            }
            // Thermal strata (atlas #16): the weather's reports as sediment, above the sample line.
            ThermalStrata {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                height: Math.min(120, parent.height * 0.3)
                strata: root.weather?.strata ?? []
            }
            FText {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                text: "SAMPLE " + (root.system.sampleInterval / 1000).toFixed(1) + " S"
                technical: true
                color: Design.faint
            }
            // Overdrive: the telemetry orrery (M12, OrreryField) behind the halo, sharing its centre. The processes
            // orbit the reading; the halo's plate dims those passing behind it.
            Stratum {
                id: orrery
                anchors.fill: parent
                anchors.topMargin: 18
                anchors.bottomMargin: 18
                name: "performance.orrery"
                gpu: false
                scope: left
                wanted: root.active
                sourceComponent: OrreryField { core: root.shell.core }
            }
            Halo {
                id: halo
                anchors.fill: parent
                anchors.topMargin: 18
                anchors.bottomMargin: 18
                model: root.readings
                // The selected reading: its share at display size, and its one line.
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.reading.text
                        headline: true
                        font.pixelSize: left.width < 460 ? Design.headline : Design.display // scale: halo size
                        font.weight: Font.ExtraLight
                        font.letterSpacing: -3
                        color: root.readingInk
                        voice: "kernel"
                        Palimpsest { pressure: root.memoryPressure }
                    }
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, halo.rx * 1.4)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.reading.available ? root.reading.line : root.reading.unavailable
                        technical: true
                        color: Design.muted
                    }
                }
            }
        }
        // The record: the trace plotted on the bare sheet, between registration marks and a ruler.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            spacing: 8
            FText {
                Layout.fillWidth: true
                text: !record.traced ? "SHARE OF THE WHOLE" : record.width < 320 ? "TRACE  ·  0–100%" : "TRACE  ·  0–100%  ·  NEWEST → RIGHT"
                technical: true
                elide: Text.ElideRight
                color: Design.muted
            }
            Item {
                id: record
                readonly property bool traced: root.reading.key !== "disk" && root.reading.key !== "swap"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120
                Repeater {
                    model: 4
                    Register {
                        required property int index
                        x: (index % 2 ? record.width - width : 0)
                        y: (index > 1 ? record.height - height : 0)
                    }
                }
                // The ruler: ten divisions down the left edge, every fifth one long.
                Repeater {
                    model: 11
                    Rectangle {
                        required property int index
                        x: 20
                        y: 14 + (record.height - 28) * index / 10
                        width: index % 5 === 0 ? 12 : 6
                        height: 1
                        color: Design.faint
                    }
                }
                // Overdrive: the reading's machinery under the trace. CPU: the scheduler's ground, the cores as plates and
                // the switches as a weave (SchedPlates, docs/OVERDRIVE.md §37). MEM: the processes as spectral lines
                // (Spectrograph, §40), from the orrery's samples. DISK: a tide (§44). GPU: a chart recorder (§45). SWAP: silt (§46).
                Stratum {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.rightMargin: 18
                    name: "performance.plates"
                    gpu: false
                    scope: record
                    wanted: root.active && root.reading.key === "cpu"
                    sourceComponent: SchedPlates { core: root.shell.core }
                }
                Stratum {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.rightMargin: 18
                    name: "performance.spectrograph"
                    gpu: false
                    scope: record
                    wanted: root.active && root.reading.key === "memory"
                    sourceComponent: Spectrograph { sample: orrery.item?.last ?? null }
                }
                // DISK: the disks as a tide (DiskTide, §44).
                Stratum {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.rightMargin: 18
                    name: "performance.tide"
                    gpu: false
                    scope: record
                    wanted: root.active && root.reading.key === "disk"
                    sourceComponent: DiskTide { core: root.shell.core }
                }
                // GPU: a chart recorder (GpuRecorder, §45).
                Stratum {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.rightMargin: 18
                    name: "performance.recorder"
                    gpu: false
                    scope: record
                    wanted: root.active && root.reading.key === "gpu"
                    sourceComponent: GpuRecorder { core: root.shell.core }
                }
                // SWAP: silt (SwapSilt, §46).
                Stratum {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.rightMargin: 18
                    name: "performance.silt"
                    gpu: false
                    scope: record
                    wanted: root.active && root.reading.key === "swap"
                    sourceComponent: SwapSilt { core: root.shell.core }
                }
                FTrace {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    anchors.rightMargin: 6
                    visible: record.traced
                    values: root.reading.available ? root.reading.history : []
                    unavailable: !root.reading.available && !/^sampling/i.test(root.reading.unavailable)
                    ink: root.reading.hot ? Design.danger : Design.accent
                }
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 40
                    anchors.rightMargin: 18
                    spacing: 12
                    visible: !record.traced
                    FText {
                        width: parent.width
                        text: root.reading.available ? root.reading.line : root.reading.unavailable
                        headline: true
                        font.pixelSize: Design.figure
                        font.weight: Font.Black
                        wrapMode: Text.Wrap
                        color: root.readingInk
                    }
                    // The share as a 78° bar: the used part in signal, the rest as a faint track.
                    Item {
                        width: parent.width
                        height: 40
                        Plane {
                            anchors.fill: parent
                            slant: 3
                            role: "ink"
                            opacity: 0.12
                        }
                        Plane {
                            width: Math.max(height * -Design.shear * 2, parent.width * Math.max(0, Math.min(1, root.reading.available ? root.reading.value : 0)))
                            height: parent.height
                            visible: root.reading.available
                            slant: 3
                            role: "signal"
                        }
                    }
                    FText {
                        text: root.reading.available ? root.reading.text + " used" : ""
                        technical: true
                        color: root.readingInk === Design.ink ? Design.muted : root.readingInk
                    }
                }
            }
        }
    }
    // The figures, ruled like an instrument's data plate, and the volume's remark beside them.
    RowLayout {
        Layout.fillWidth: true
        spacing: 22
        Repeater {
            model: root.reading.facts
            ColumnLayout {
                id: fact
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                spacing: 4
                Row {
                    spacing: 7
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        color: Design.accent
                    }
                    FText {
                        text: fact.modelData[0]
                        technical: true
                        font.capitalization: Font.AllUppercase
                        color: Design.muted
                    }
                }
                FText {
                    Layout.fillWidth: true
                    text: fact.modelData[1]
                    headline: true
                    font.pixelSize: Design.readout
                    font.weight: Font.Light
                    elide: Text.ElideRight
                    voice: "kernel"
                    Palimpsest { pressure: root.memoryPressure }
                }
                Hairline {
                    Layout.fillWidth: true
                    color: Design.line
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            Layout.minimumWidth: 0
            spacing: 4
            FText {
                text: root.diskCritical ? "ROOT VOLUME · CRITICAL" : "ROOT VOLUME"
                technical: true
                color: root.diskCritical ? Design.danger : Design.muted
            }
            FText {
                Layout.fillWidth: true
                text: root.diskCritical ? "Free space now." : root.diskWarning ? "you said you’d clean it up." : "room to breathe. for now."
                aside: !root.diskCritical
                font.pixelSize: Design.readout
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: root.diskCritical ? Design.danger : Design.ink
            }
            Hairline {
                Layout.fillWidth: true
                startNode: true
                color: root.diskCritical ? Design.danger : Design.line
            }
        }
    }
}
