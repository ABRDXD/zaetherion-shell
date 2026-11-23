import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// Z199: the workspace instrument. The current world sits on the star's face, the others mirror each other about the
// island's axis, a switch turns the system the short way round and settles, and the readout names the workspace.
// With WS_SHOTS set, frames of a turn are saved there for the owner.
ShellRoot {
    id: root
    readonly property string shots: Quickshell.env("WS_SHOTS") ?? ""
    readonly property var ids: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
    readonly property var windows: ({ "1": 2, "2": 0, "3": 1, "4": 3, "5": 0, "6": 1, "7": 0, "8": 0, "9": 0, "10": 1 })
    function check(ok: bool, name: string, detail): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name + (ok ? "" : " " + JSON.stringify(detail ?? null)));
    }
    function planets(): var {
        const out = [];
        const walk = node => { if (node.objectName === "workspacePlanet") out.push(node); for (const c of node.children) walk(c); };
        walk(transit);
        return out;
    }
    function after(ms: int, fn): void {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function frames(n: int, every: int, done): void {
        if (!shots) { done(); return; }
        let k = 0;
        const grab = () => scene.grabToImage(result => {
            result.saveToFile(shots + "/turn-" + String(k).padStart(2, "0") + ".png");
            if (++k < n) after(every, grab); else done();
        });
        grab();
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 600
        implicitHeight: 118
        color: Design.voidFill
        Item {
            id: scene
            anchors.fill: parent
            WorkspaceTransit {
                id: transit
                anchors.fill: parent
                ids: root.ids
                active: "4"
                windows: root.windows
            }
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            const all = root.planets();
            const here = all.find(p => p.modelData === "4");
            root.check(Math.abs(here.x - transit.cx) < 0.5 && here.crossing > 0.99 && here.z > 1, "current world on the star's face",
                       [here.x, transit.cx, here.crossing]);
            root.check(here.size <= 2 * 24 * 0.6 + 0.01, "a transit, never an eclipse", here.size);
            const mirrored = all.every(p => p === here || p.modelData === "9"   // 10 worlds: the one opposite is alone, behind the star
                || all.some(o => o !== p && Math.abs((o.x - transit.cx) + (p.x - transit.cx)) < 0.5 && Math.abs(o.y - p.y) < 0.5));
            root.check(all.length === 10 && mirrored, "worlds mirror about the axis", all.map(p => [p.modelData, Math.round(p.x)]));
            const left = all.find(p => p.modelData === "3"), right = all.find(p => p.modelData === "5");
            root.check(left.litRight && !right.litRight && left.lit > 0.5 && here.lit < 0.01, "crescents face the star",
                       [left.litRight, right.litRight, left.lit, here.lit]);
            const fourWindows = all.find(p => p.modelData === "4"), none = all.find(p => p.modelData === "2");
            root.check(fourWindows.windows === 3 && none.windows === 0, "window counts reach the worlds");
            const readout = root.find(transit, "workspaceReadout");
            root.check(readout.text.startsWith("04 / 10") && readout.text.endsWith("3 WINDOWS"), "readout", readout.text);
            const before = transit.turn;
            transit.active = "3";
            root.check(transit.turn === before - 1, "one step back turns back", [before, transit.turn]);
            root.frames(10, 90, () => root.after(1400, () => {
                root.check(Math.abs(transit.spin - transit.turn) < 1e-6, "turn settles", [transit.spin, transit.turn]);
                const t = transit.turn;
                transit.active = "10";  // from 3 to 10: three steps back round the wrap, not seven forward
                root.check(transit.turn === t - 3, "the short way round the wrap", [t, transit.turn]);
                root.after(1400, () => {
                    const now = root.planets().find(p => p.modelData === "10");
                    root.check(Math.abs(now.x - transit.cx) < 0.5, "new world in transit", now.x);
                    scene.grabToImage(result => {
                        const path = Quickshell.env("ISLAND_FRAME_SHOT");
                        root.check(!path || result.saveToFile(path), "offscreen capture");
                        Qt.quit();
                    });
                });
            }));
        }
    }
    function find(item, name: string): var {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
}
