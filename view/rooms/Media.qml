import QtQuick
import Quickshell
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.fluid

// The room and its subscriptions survive presentation changes. Only the renderer is replaced.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    readonly property MediaSession session: MediaSession {
        id: controller
        host: root.host
        shell: root.shell
        shown: root.visible && (root.QsWindow.window?.visible ?? false)
        followAutomaticLyrics: Design.fluid
    }
    property alias lyrics: controller.lyrics
    readonly property PresentationHost presentation: renderer
    PresentationHost {
        id: renderer
        anchors.fill: parent
        presentation: Design.fluid ? fluid : angular
    }
    Component { id: angular; AngularMedia { session: root.session } }
    Component { id: fluid; FluidMedia { session: root.session } }
}
