import QtQuick
import qs.view.contract

// Holds one lease on a host domain feature while active, and always releases it on destruction.
QtObject {
    id: root
    property HostDomain domain: null
    property string feature: ""
    property bool active: true
    property HostDomain heldDomain: null
    readonly property string owner: "lease:" + String(root)
    function sync() {
        const want = active && domain && feature !== "" ? domain : null;
        if (want === heldDomain) return;
        if (heldDomain) heldDomain.release(feature, owner);
        if (want) want.acquire(feature, owner);
        heldDomain = want;
    }
    onActiveChanged: sync()
    onDomainChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (heldDomain) heldDomain.release(feature, owner)
}
