import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.fluid

// The room and its state survive presentation changes; only the renderer is replaced (as Timers and Performance do).
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    required property CoreClient core
    readonly property TasksSession controller: TasksSession {
        host: root.host
        shell: root.shell
        core: root.core
        shown: root.visible && (root.QsWindow.window?.visible ?? true)
    }
    readonly property PresentationHost presentation: renderer
    // The shell's typing check (Shell.editingText) asks whether the entry line has focus.
    readonly property bool editing: renderer.item?.editing ?? false
    PresentationHost {
        id: renderer
        anchors.fill: parent
        presentation: Design.fluid ? fluid : angular
    }
    Component { id: angular; AngularTasks { controller: root.controller } }
    Component { id: fluid; FluidTasks { controller: root.controller } }
}
