import QtQuick

// One (domain, DMS service) subscription (docs/DMS_ADAPTER.md §3). It is the only way to be subscribed:
// it registers on creation, follows `wanted`, and unregisters on destruction.
//   wanted: root.holds("brightness")        a lease expression
//   wanted: true                            un-leased state, for as long as the domain exists
QtObject {
    id: feed
    required property DmsLink link
    property string service: ""
    property string capability: ""
    property bool wanted: false
    property string key: ""

    // The link is ready and DMS offers the capability.
    readonly property bool usable: link.phase === "ready" && link.capabilities.indexOf(capability) >= 0
    // The last snapshot, or null while unwanted or unusable.
    readonly property var data: wanted && usable ? (link.snapshots[service] ?? null) : null
    // The last "<service>.update" event (S9a), for services that send changes that way (brightness), or null.
    readonly property var update: wanted && usable ? (link.snapshots[service + ".update"] ?? null) : null

    function register() { link.addFeed(key, service, capability, wanted); }
    onWantedChanged: if (key !== "") register()
    Component.onCompleted: { key = link.newFeedKey(); register(); }
    Component.onDestruction: if (link && key !== "") link.removeFeed(key)
}
