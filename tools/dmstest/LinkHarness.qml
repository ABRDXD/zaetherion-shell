import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.dms

// A bare link with test feeds, driven over `qs ipc` (tests/test_dms_adapter.py). Against the stand-in DMS only.
ShellRoot {
    id: root
    DmsLink { id: theLink; clientId: "zaetherion-test" }
    property var feeds: ({})
    Component {
        id: feedFactory
        DmsFeed { link: theLink }
    }
    IpcHandler {
        target: "t"
        function state(): string {
            return JSON.stringify({ phase: theLink.phase, problem: theLink.problem, events: theLink.eventsState, subscribed: theLink.subscribed,
                available: false, feeds: Object.keys(root.feeds) });
        }
        function feed(service: string, on: string): void {
            if (on === "true" && !root.feeds[service]) {
                root.feeds = Object.assign({}, root.feeds, { [service]: feedFactory.createObject(root, { service: service, capability: service, wanted: true }) });
            } else if (on !== "true" && root.feeds[service]) {
                root.feeds[service].destroy();
                const next = Object.assign({}, root.feeds);
                delete next[service];
                root.feeds = next;
            }
        }
        function want(service: string, on: string): void { if (root.feeds[service]) root.feeds[service].wanted = on === "true"; }
        function hasData(service: string): string { return String(root.feeds[service] ? root.feeds[service].data !== null : false); }
    }
}
