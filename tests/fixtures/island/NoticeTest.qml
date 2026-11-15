import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.adapters.quickshell
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
                root.check(root.entry("a").remaining === 2000, "a sender's never-expire gets our time");
                queue.remove("notification:a");
                // Read elsewhere: the same arrival, so the dismissed card does not come back.
                fixture.notifications.items = [root.item("a", 2, { live: true, timeout: 0, read: true }),
                                               root.item("b", 3, { live: false })];
                break;
            case 3:
                root.check(root.entry("a") === null, "a change that is not an arrival shows nothing");
                root.check(root.entry("b")?.remaining === events.durations.notification && events.durations.notification === 2000, "our own showing time");
                root.check(NotificationTiming.showMs(-1, "normal") === 2000 && NotificationTiming.showMs(-1, "low") === 2000
                    && NotificationTiming.showMs(-1, "critical") === 0 && NotificationTiming.showMs(8000, "normal") === 8000,
                    "the adapter's default is 2 s and honours the sender");
                root.check(events.showTime({ timeout: 10000, urgency: "normal" }) === 3500
                    && events.showTime({ timeout: 6000, urgency: "low" }) === 3500, "the island caps a sender's long time at 3.5 s");
                root.check(events.showTime({ timeout: 3000, urgency: "normal" }) === 3000, "a shorter sender time is kept");
                root.check(events.showTime({ timeout: 10000, urgency: "critical" }) === 10000
                    && events.showTime({ timeout: 0, urgency: "critical" }) === null
                    && events.showTime({ timeout: -1, urgency: "critical" }) === null, "critical is not capped");
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
