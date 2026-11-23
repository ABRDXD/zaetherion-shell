import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell

// Inbox's attention band (view/rooms/AttentionBand.qml, docs/OVERDRIVE.md §23) in the real room with synthetic
// notifications: a slab per source with unread items, a tick per arrival in the last day, the debt's overhang; reading
// everything clears the slabs and cuts the overhang; nothing of a message's text is used. With INBOX_SHOTS set, frames.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) { const f = find(child, test); if (f) return f; }
        return null;
    }
    readonly property string shots: Quickshell.env("INBOX_SHOTS") || ""
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        stage.grabToImage(r => { r.saveToFile(shots + "/" + name + ".png"); fn(); });
    }
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1000; implicitHeight: 640; visible: true
        color: "#0d1218"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#0d1218" }
            Inbox { id: room; anchors.fill: parent; anchors.margins: 24; host: fixture; shell: context }
        }
    }
    function n(id, app, hoursAgo, read, urgency) {
        return { id: String(id), appName: app, summary: "PRIVATE " + id, body: "PRIVATE BODY", time: Date.now() - hoursAgo * 3600000,
                 urgency: urgency ?? "normal", read: read, hasActions: false };
    }
    Component.onCompleted: after(300, () => {
        const items = [n(1, "Mail", 20, false), n(2, "Mail", 3, false), n(3, "Chat", 1, false), n(4, "Chat", 0.5, true),
                       n(5, "Pager", 6, false, "critical"), n(6, "News", 30, false), n(7, "Chat", 0.2, false)];
        fixture.notifications.items = items;
        after(100, () => {
            const band = find(room, i => i.slabs !== undefined && i.hang !== undefined);
            const ticks = band.ticks;
            const json = JSON.stringify({ slabs: band.slabs, ticks: ticks });
            check("inbox.band", band.slabs.length === 4 && band.slabs[0].app === "News" && ticks.length === 6 && ticks.filter(t => t.urgent).length === 1
                  && band.hang > 30 && !json.includes("PRIVATE"), { slabs: band.slabs.map(s => [s.app, s.unread]), ticks: ticks.length, hang: band.hang });
            shot("inbox-debt", () => {
                fixture.notifications.items = items.map(i => Object.assign({}, i, { read: true }));
                after(100, () => {
                    check("inbox.read", band.slabs.length === 0 && band.hang === 0 && band.ticks.every(t => !t.unread) && band.ticks.length === 6,
                          { slabs: band.slabs.length, hang: band.hang });
                    shot("inbox-clear", () => {
                        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                        console.log("CUE_DONE");
                        Qt.exit(0);
                    });
                });
            });
        });
    });
}
