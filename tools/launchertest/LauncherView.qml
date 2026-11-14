import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.ui

// The launcher end to end (S6): the real core with the fixture host, the island offscreen with the fixture apps.
// Opens the launcher, checks the frecent rows, types, launches, and checks a Session's refusal. Each check prints
// LAUNCHER_PASS or LAUNCHER_FAIL, then LAUNCHER_DONE. With LAUNCHER_SHOTS set, captures go there for the owner.
ShellRoot {
    id: root
    property var steps: []
    readonly property string shots: Quickshell.env("LAUNCHER_SHOTS") ?? ""
    function check(name, ok, detail) { ok ? console.log("LAUNCHER_PASS", name) : console.log("LAUNCHER_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function until(test, ms, fn) {
        const deadline = Date.now() + ms;
        const poll = () => test() ? fn(true) : Date.now() > deadline ? fn(false) : after(10, poll);
        poll();
    }
    function next() {
        const step = steps.shift();
        if (step) step(); else { console.log("LAUNCHER_DONE"); Qt.quit(); }
    }
    function find(node, name) {
        if (!node) return null;
        if (node.objectName === name) return node;
        for (const child of node.children) {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
    readonly property var input: find(island, "launcherInput")
    readonly property var face: input ? input.parent.parent : null
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        after(250, () => scene.grabToImage(result => { result.saveToFile(shots + "/" + name + ".png"); fn(); }));
    }
    function type(text, fn) {
        input.text = text;
        until(() => face.asked > 0 && face.results.length > 0 && face.results[0] !== undefined, 2000, () => after(50, fn));
    }

    CoreClient { id: client }
    FixtureAdapter { id: fixture }
    Component.onCompleted: {
        Design.source = fixture.palette;
        steps = [
            () => until(() => client.connected && !!client.launcherData && client.launcherData.apps === 7, 5000, ok => {
                check("apps.indexed", ok, client.launcherData);
                next();
            }),
            () => {
                island.openLauncher();
                until(() => !!root.input && root.face.results.length > 0, 3000, ok => {
                    check("open.rows", ok && root.face.results.length === 6, root.face?.results);
                    check("open.focus", !!root.input && root.input.activeFocus);
                    check("island.wants.keyboard", island.keyboardRequest === "exclusive", island.keyboardRequest);
                    check("window.deep.enough", island.deepest >= island.height, [island.deepest, island.height]);
                    shot("01-open", next);
                });
            },
            () => type("mon", () => {
                check("type.ranks", root.face.results[0].id === "sample-monitor", root.face.results);
                shot("02-typed", next);
            }),
            () => {
                root.face.move(1);
                root.face.move(-1);
                check("select.wraps", root.face.selected === 0, root.face.selected);
                root.face.launch(root.face.selected);
                until(() => fixture.apps.calls.length > 0, 2000, ok => {
                    check("launch.terminal", ok && JSON.stringify(fixture.apps.calls[0].args) === JSON.stringify(["sample-monitor", "kitty"]), fixture.apps.calls);
                    until(() => !island.launcherOpen, 1000, closed => { check("launch.closes", closed); next(); });
                });
            },
            () => client.request("launcher.query", { text: "", limit: 1 }, (ok, reply) => {
                check("launch.recorded", ok && reply.rows[0].id === "sample-monitor", reply);
                next();
            }),
            () => client.request("session.start", { preset: "deep" }, () => {
                island.openLauncher();
                until(() => !!root.input, 2000, () => type("steam", () => {
                    check("blocked.marked", root.face.results[0].blocked === true, root.face.results[0]);
                    const before = fixture.apps.calls.length;
                    root.face.launch(0);
                    until(() => root.face.refusal !== "", 2000, ok => {
                        check("blocked.refused", ok && root.face.refusal === "> BLOCKED · SESSION" && fixture.apps.calls.length === before, root.face.refusal);
                        check("blocked.stays.open", island.launcherOpen);
                        shot("03-blocked", () => client.request("session.end", {}, next));
                    });
                }));
            }),
            () => {
                island.toggleLauncher();
                until(() => !island.launcherOpen, 1000, ok => { check("toggle.closes", ok); next(); });
            },
            () => {
                island.openLauncher();
                until(() => !!root.input, 2000, () => type("zzzz", () => {}));
                until(() => !!root.face && root.face.asked > 0 && root.face.results.length === 0 && root.input.text === "zzzz", 2000, ok => {
                    check("no.match", ok);
                    shot("04-nomatch", next);
                });
            },
        ];
        next();
    }

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 420
        color: "#202020"
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                core: client
                motionLevel: "off"
                pointerInside: false
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
