import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.ui

// What the island takes from an Inbox item (S4): its showing time, a replace-id, its leaving, and whether it can
// still be answered. Synthetic items only.
ShellRoot {
    id: root
    property int step: 0
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function item(id: string, time: int, more: var): var {
        return Object.assign({ id, time, appName: "DEMO APP", summary: "Synthetic", body: "Synthetic line",
            urgency: "normal", actions: [{ id: "view", label: "View" }], reply: "Reply" }, more);
    }
    function entry(id: string): var { return queue.entries.find(e => e.id === "notification:" + id) ?? null; }

    FixtureAdapter { id: fixture }
    CoreClient { id: core; path: "" }
    IslandQueue { id: queue }
    IslandEvents { id: events; host: fixture; core: core; queue: queue }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 520
        implicitHeight: 152
        Item {
            id: scene
            anchors.fill: parent
            Loader {
                anchors.fill: parent
                active: !!queue.current
                sourceComponent: IslandExpansion { event: queue.current }
            }
        }
    }

    Timer {
        repeat: true
        interval: 100
        running: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                fixture.notifications.items = [root.item("a", 1, { live: true, timeout: 1500 })];
                break;
            case 1:
                root.check(queue.current?.id === "notification:a" && root.entry("a").remaining === 1500, "the sender's showing time");
                root.check(queue.current.data.actions.length === 1 && queue.current.data.reply === "Reply", "a live item can be answered");
                fixture.notifications.items = [root.item("a", 2, { live: true, timeout: 0, summary: "Changed" })];
                break;
            case 2:
                root.check(queue.entries.length === 1 && queue.current.data.summary === "Changed", "replace-id refreshes the card");
                root.check(root.entry("a").remaining === null, "zero stays until dismissed");
                queue.remove("notification:a");
                // Read elsewhere: the same arrival, so the dismissed card does not come back.
                fixture.notifications.items = [root.item("a", 2, { live: true, timeout: 0, read: true }),
                                               root.item("b", 3, { live: false })];
                break;
            case 3:
                root.check(root.entry("a") === null, "a change that is not an arrival shows nothing");
                root.check(root.entry("b")?.remaining === events.durations.notification, "our own showing time");
                root.check(root.entry("b").data.actions.length === 0 && root.entry("b").data.reply === "", "a restored item cannot be answered");
                fixture.notifications.items = [root.item("a", 2, { live: true, timeout: 0, read: true })];
                break;
            case 4:
                root.check(queue.entries.length === 0, "closed elsewhere leaves the island");
                running = false;
                scene.grabToImage(result => {
                    root.check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture");
                    Qt.quit();
                });
                break;
            }
        }
    }
}
