import QtQuick
import qs.core.client
import qs.view.contract

// The HostAdapter of the ZÆTHERION session on DMS (docs/DMS_ADAPTER.md §0). One per process: the resident and
// the panel each create their own, with their own connections and leases. Only adapters know DMS.
HostAdapter {
    id: root
    // The notification mirror lives in the core.
    required property CoreClient core
    // The DMS socket, given by the session (DMS_SOCKET by default, §7). The entry may bind it.
    property alias socketPath: link.socketPath
    readonly property DmsLink dms: DmsLink { id: link; clientId: "zaetherion-" + root.role }
    property string role: "shell"
    name: "dms"
    network: DmsNetwork {
        link: link
        // Passwords live in settings (Z95).
        onUnknownNetwork: root.hostActions.open("wifi")
    }
}
