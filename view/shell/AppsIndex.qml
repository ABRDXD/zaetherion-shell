import QtQuick
import qs.core.client
import qs.view.contract

// Hands the installed apps to the core for ranking (S6, Z185): when the list changes and whenever the core
// (re)connects, since a restarted core starts with no list.
QtObject {
    id: root
    property CoreClient core: null  // an island without a core indexes nothing
    required property AppsDomain apps
    readonly property bool ready: (core?.connected ?? false) && apps.available
    function send(): void {
        if (ready) core.request("apps.index", { entries: apps.entries }, (ok, reply) => {});
    }
    onReadyChanged: send()
    readonly property Connections changes: Connections {
        target: root.apps
        function onEntriesChanged() { root.send(); }
    }
}
