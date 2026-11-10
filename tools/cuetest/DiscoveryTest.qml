import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell

// Discovery in the real Shell (M15; core/discovery.py, view/shell/Whisper.qml, the archive's margins), offscreen, on a
// snapshot written straight into the client: the whisper shows once, low in the room, says it was seen and goes;
// the archive lists the fragment. Nothing is sent to a core. With DISCOVERY_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("DISCOVERY_SHOTS") || ""
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function shot(name, then) {
        if (root.shots === "") { then(); return; }
        stage.grabToImage(r => { r.saveToFile(root.shots + "/" + name + ".png"); then(); });
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const c of item.children ?? []) { const f = find(c, test); if (f) return f; }
        return null;
    }
    property var seenIds: []
    readonly property var fragment: ({ id: "full-moon", at: Date.now(), whisper: "the moon is full",
                                       text: "Full moon. The surveyor measured its shadow at midnight and again at one." })
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1120; implicitHeight: 760; visible: true
        Item { id: stage; anchors.fill: parent
            Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core } }
    }
    Component.onCompleted: after(1200, () => {
        const w = dashboard.discoveryWhisper;
        w.seen.connect(id => root.seenIds = root.seenIds.concat([id]));
        core.discoveryData = { found: [root.fragment], latest: root.fragment, total: 12, whisper: { id: "full-moon", text: "the moon is full" } };
        after(300, () => {
            check("whisper.shown", w.showing && w.text === "the moon is full" && root.seenIds.length === 1 && root.seenIds[0] === "full-moon",
                  { showing: w.showing, text: w.text, seen: root.seenIds });
            shot("whisper", () => {
                // The core clears it once seen; the same pending sent again is not shown twice meanwhile.
                core.discoveryData = { found: [root.fragment], latest: root.fragment, total: 12, whisper: null };
                after(1400, () => {
                    check("whisper.gone", !w.showing && w.text === "", { showing: w.showing });
                    ViewState.loreEnabled = true;
                    dashboard.archiveOpen = true;
                    after(900, () => {
                        const label = find(dashboard, i => typeof i.text === "string" && i.text.indexOf("FOUND IN THE MARGINS / 1 OF 12") === 0);
                        const body = find(dashboard, i => typeof i.text === "string" && i.text === root.fragment.text);
                        check("archive.margins", !!label && !!body, { label: !!label, body: !!body });
                        shot("archive", () => {
                            dashboard.archiveOpen = false;
                            context.panelOpen = false;
                            core.discoveryData = { found: [root.fragment], latest: root.fragment, total: 12, whisper: { id: "new-moon", text: "no moon tonight" } };
                            after(300, () => {
                                const closed = !w.showing;
                                context.panelOpen = true;
                                after(900, () => {
                                    check("whisper.waits.for.open", closed && w.showing && w.text === "no moon tonight", { closed: closed, showing: w.showing });
                                    console.log("CUE_DONE");
                                    Qt.exit(0);
                                });
                            });
                        });
                    });
                });
            });
        });
    })
}
