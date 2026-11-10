import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell

// MIME taxonomy in Clips (view/rooms/ClipKinds.js, KindMark; docs/OVERDRIVE.md §27): each synthetic entry is shown with
// its kind and that kind's mark; a colour shows its swatch. With CLIPS_SHOTS set, a frame.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function all(item, test, out) {
        if (test(item)) out.push(item);
        for (const child of item.children ?? []) all(child, test, out);
        return out;
    }
    readonly property string shots: Quickshell.env("CLIPS_SHOTS") || ""
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1000; implicitHeight: 760; visible: true
        color: "#0d1218"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#0d1218" }
            Clips { id: room; anchors.fill: parent; anchors.margins: 24; host: fixture; shell: context }
        }
    }
    Component.onCompleted: after(300, () => {
        fixture.clipboard.entries = [
            { id: "7", text: "https://example.org/fixture", isImage: false }, { id: "6", text: "~/fixture/notes.md", isImage: false },
            { id: "5", text: "#7e9cd8", isImage: false }, { id: "4", text: "482913", isImage: false },
            { id: "3", text: "const fixture = 1;", isImage: false }, { id: "2", text: "[[ binary data 1 KiB png 8x8 ]]", isImage: true },
            { id: "1", text: "A fixture sentence.", isImage: false }];
        after(300, () => {
            const marks = all(room, i => i.paths !== undefined && i.swatch !== undefined, []).map(m => m.kind);
            const swatch = all(room, i => i.paths !== undefined && i.kind === "COLOUR", [])[0]?.swatch;
            check("clips.kinds", JSON.stringify(marks) === JSON.stringify(["LINK", "PATH", "COLOUR", "NUMBER", "CODE", "IMAGE", "TEXT"]) && swatch === "#7e9cd8",
                  { marks: marks, swatch: swatch });
            const done = () => { console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames)); console.log("CUE_DONE"); Qt.exit(0); };
            // Photocopy generations (Overdrive, §49): the newest crisp, the older ones thinner, slipped and speckled.
            const silent = all(room, i => i.gen !== undefined && i.slip !== undefined, []).length;
            Motion.overdrive = true;
            Motion.settleDrive();
            after(400, () => {
                const layers = all(room, i => i.gen !== undefined && i.slip !== undefined, []).sort((a, b) => a.gen - b.gen);
                const first = layers[0], last = layers[layers.length - 1];
                check("clips.copies", silent === 0 && layers.length === 6 && first.gen === 1 && last.gen === 6
                      && last.target.opacity < first.target.opacity && first.target.opacity < 1 && last.slip.x > first.slip.x,
                      { silent: silent, layers: layers.map(l => [l.gen, l.target.opacity]) });
                const finish = () => {
                    Motion.overdrive = false;
                    Motion.settleDrive();
                    after(300, () => {
                        const left = all(room, i => i.gen !== undefined && i.slip !== undefined, []).length;
                        const texts = all(room, i => typeof i.text === "string" && i.text === "A fixture sentence.", []);
                        check("clips.copies.release", left === 0 && texts.every(t => t.opacity === 1), { left: left, opacity: texts.map(t => t.opacity) });
                        done();
                    });
                };
                if (shots) stage.grabToImage(r => { r.saveToFile(shots + "/clips-copies.png"); finish(); }); else finish();
            });
            return;
        });
    });
}
