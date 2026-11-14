import QtQuick
import Quickshell
import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui
import qs.view.fluid

Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property CoreClient core: null
    signal navigate(string page)
    signal editProfile()
    readonly property HomeSession session: HomeSession {
        host: root.host
        shell: root.shell
        core: root.core
        surface: root
        shown: root.visible && (root.QsWindow.window?.visible ?? false)
        onNavigate: page => root.navigate(page)
        onEditProfile: root.editProfile()
    }
    readonly property var frontPage: session.frontPage
    readonly property PresentationHost presentation: renderer
    implicitHeight: renderer.implicitHeight
    PresentationHost {
        id: renderer
        anchors.fill: parent
        presentation: Design.fluid ? fluid : angular
    }
    Component { id: angular; AngularHome { session: root.session } }
    Component { id: fluid; FluidHome { session: root.session } }
}
