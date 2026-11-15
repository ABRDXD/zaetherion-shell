import QtQuick
import Quickshell
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.fluid

// The room and its readings survive presentation changes; only the renderer is replaced (as Home, Media, Timers).
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    PerformanceSession {
        id: session
        host: root.host
        shell: root.shell
        shown: root.visible && (root.QsWindow.window?.visible ?? false)
    }
    readonly property PerformanceSession controller: session
    readonly property PresentationHost presentation: renderer
    // Kept on the room for the tools that read it (tools/cuetest/PerformanceTest.qml).
    readonly property var readings: controller.readings
    property alias weather: session.weather   // writable: the test and the room set it as the core reports
    readonly property var barograph: controller.barograph
    readonly property string weatherDetail: controller.weatherDetail
    PresentationHost {
        id: renderer
        anchors.fill: parent
        presentation: Design.fluid ? fluid : angular
    }
    Component { id: angular; AngularPerformance { controller: root.controller } }
    Component { id: fluid; FluidPerformance { controller: root.controller } }
}
