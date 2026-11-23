import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.fluid

// The room and its state survive presentation changes; only the renderer is replaced (as Home and Media do).
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    readonly property TimersSession controller: TimersSession {
        host: root.host
        shell: root.shell
        core: root.core
        shown: root.visible && (root.QsWindow.window?.visible ?? true)
    }
    readonly property PresentationHost presentation: renderer
    // Kept on the room for the tools that read it (tools/cuetest/TemporalTest.qml, SessionTest.qml).
    readonly property bool running: controller.running
    readonly property var sources: controller.sources
    readonly property string eventKey: controller.eventKey
    readonly property string completionKey: controller.completionKey
    readonly property bool fieldLoaded: renderer.item?.fieldLoaded ?? false
    readonly property int staticPaints: renderer.item?.staticPaints ?? 0
    PresentationHost {
        id: renderer
        anchors.fill: parent
        presentation: Design.fluid ? fluid : angular
    }
    Component { id: angular; AngularTimers { controller: root.controller } }
    Component { id: fluid; FluidTimers { controller: root.controller } }
}
