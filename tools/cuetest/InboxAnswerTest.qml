import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.rooms
import qs.view.shell

// The Inbox answering notifications (S4, view/rooms/InboxAnswer.qml) in the real room with synthetic items: a live
// item's actions and reply go to the adapter, a restored one offers nothing, a mirrored one points at the host's
// centre. With INBOX_SHOTS set, frames.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function all(item, test, found) {
        found = found ?? [];
        if (!item) return found;
        if (test(item) && !found.includes(item)) found.push(item);
        for (const child of item.children ?? []) all(child, test, found);
        for (const child of item.contentItem?.children ?? []) all(child, test, found);
        return found;
    }
    function shown(test) { return all(room, i => i.visible && test(i)); }
    function buttons(label) { return shown(i => i.label === label && i.clicked !== undefined); }
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
    function n(id, more) {
        return Object.assign({ id: id, appName: "Demo app", summary: "Synthetic " + id, body: "Synthetic body", time: Date.now(),
                               urgency: "normal", read: false, hasActions: false, actions: [], reply: "", image: "", live: true }, more);
    }
    // A plain 8 px square, inline so the run needs no file.
    readonly property string picture: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM4YWODFTEMLQkAZZlQAVIPr1MAAAAASUVORK5CYII="
    readonly property var answerable: [
        n("live", { hasActions: true, actions: [{ id: "view", label: "View" }, { id: "default", label: "" }], reply: "Say something",
                    image: root.picture }),
        n("restored", { hasActions: true, actions: [{ id: "view", label: "Stale" }], reply: "Say something", live: false }),
        n("urgent", { urgency: "critical", appName: "Pager" })
    ]
    function calls(method) { return fixture.notifications.calls.filter(c => c.method === method).map(c => c.args); }

    Component.onCompleted: after(300, () => {
        fixture.notifications.source = "server";
        fixture.notifications.items = answerable;
        // The reading panel shows one notice (Z211): read the live one, as a click on its comet would.
        room.selectedId = "live";
        after(300, () => {
            const view = buttons("View"), open = buttons("Open"), field = shown(i => i.placeholderText === "Say something");
            check("inbox.live.offers", view.length === 1 && open.length === 1 && field.length === 1 && buttons("Stale").length === 0,
                  { view: view.length, open: open.length, field: field.length });
            check("inbox.server.no-host-links", buttons("Actions in host center").length === 0 && buttons("Open notification center").length === 0);
            view[0].clicked();
            field[0].text = "Synthetic answer";
            field[0].accepted();
            check("inbox.live.answers", JSON.stringify(calls("action")) === JSON.stringify([["live", "view", ""], ["live", "", "Synthetic answer"]])
                  && field[0].text === "", calls("action"));
            check("inbox.picture.kept", JSON.stringify(calls("keepImage")) === JSON.stringify([["live"]]), calls("keepImage"));
            shot("inbox-answer", () => {
                fixture.notifications.source = "mirror";
                fixture.notifications.items = [n("mirrored", { hasActions: true, actions: [{ id: "view", label: "View" }], live: false })];
                after(200, () => {
                    check("inbox.mirror.points-at-host", buttons("View").length === 0 && buttons("Actions in host center").length === 1
                          && buttons("Open notification center").length === 1);
                    shot("inbox-mirrored", () => {
                        console.log("CUE_DONE");
                        Qt.exit(0);
                    });
                });
            });
        });
    });
}
