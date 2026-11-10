pragma Singleton
import QtQuick
import Quickshell
import qs.view.contract

// View-wide open/page state and the route to the host. The entry file injects the adapter.
Singleton {
    id: root
    property HostAdapter adapter: null
    property bool panelOpen: false
    property string page: "home"
    readonly property bool wide: Config.options.bar.dynamicIsland.layoutStyle === "wide"
    function toggleLayout() { Config.options.bar.dynamicIsland.layoutStyle = wide ? "clock" : "wide"; }
    signal openRequested(string page)
    signal closeRequested()

    function open(page) { openRequested(page || "home"); }
    function close() { closeRequested(); }
    // A host surface takes over: FART closes first so focus moves cleanly.
    function openHost(target) {
        close();
        adapter?.hostActions.open(target);
    }
}
