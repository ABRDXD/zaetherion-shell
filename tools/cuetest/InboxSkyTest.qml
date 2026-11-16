import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.ui as UI

// The Inbox as the day's sky (Z210), offscreen on the fixture: one comet per notice, the panel starts on the newest
// unread, a comet's click reads it, Dismiss dismisses the one read and the panel falls back; urgent comets fly
// higher than quiet ones and newer ones sit nearer NOW.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function comets() {
        const out = [];
        const walk = i => { if (!i) return; if (i.urgent !== undefined && i.chosen !== undefined) out.push(i); for (const c of i.children ?? []) walk(c); };
        walk(room);
        return out;
    }
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        implicitWidth: 1000; implicitHeight: 640; visible: true; color: "#000000"
        Item {
            anchors.fill: parent
            Inbox { id: room; anchors.fill: parent; anchors.margins: 24; host: fixture; shell: context }
        }
    }
    function n(id, hoursAgo, read, urgency) {
        return { id: id, appName: "App " + id, summary: "Summary " + id, body: "", time: Date.now() - hoursAgo * 3600000,
                 urgency: urgency, read: read, hasActions: false, actions: [], reply: "", image: "", live: true };
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            fixture.notifications.items = [n("old", 5, false, "low"), n("hot", 3, false, "critical"), n("new", 1, false, "normal"), n("seen", 0.5, true, "normal")];
            Qt.callLater(() => {
                const c = root.comets();
                root.check("one.comet.each", c.length === 4, c.length);
                root.check("starts.on.newest.unread", room.selected.id === "new", room.selected?.id);
                const at = id => c.find(x => x.summary === "Summary " + id).parent;
                root.check("urgent.flies.high", at("hot").y < at("old").y, { hot: at("hot").y, old: at("old").y });
                root.check("newer.nearer.now", at("new").x > at("old").x);
                c.find(x => x.summary === "Summary old").clicked();
                root.check("click.reads", room.selected.id === "old" && c.find(x => x.summary === "Summary old").chosen);
                room.inbox.dismiss(room.selected.id);
                const call = fixture.notifications.calls.filter(k => k.method === "dismiss").pop();
                root.check("dismiss.names.it", call && call.args[0] === "old", call);
                fixture.notifications.items = fixture.notifications.items.filter(k => k.id !== "old");
                Qt.callLater(() => {
                    root.check("falls.back", room.selected.id === "new", room.selected?.id);
                    console.log("CUE_DONE"); Qt.quit();
                });
            });
        }
    }
}
