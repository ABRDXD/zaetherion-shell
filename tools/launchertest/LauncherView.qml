import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.contract
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

    function frames(name, count, every, done) {
        let n = 0;
        const grab = () => scene.grabToImage(result => {
            result.saveToFile(shots + "/" + name + "-" + String(n).padStart(2, "0") + ".png");
            if (++n < count) after(every, grab); else done();
        });
        grab();
    }
    function lastRun() {
        const runs = fixture.apps.calls.filter(call => call.method === "run");
        return runs.length ? runs[runs.length - 1].args[0] : null;
    }
    function inline(text, kind, name, done, picture) {
        island.openLauncher();
        until(() => !!root.input, 2000, () => type(text, () => {
            check(name + ".row", root.face.results[0].kind === kind, root.face.results);
            shot(picture, () => {
                root.face.launch(0);
                until(() => !island.launcherOpen && done(), 2000, ok => { check(name, ok, fixture.apps.calls); next(); });
            });
        }));
    }

    PaletteDomain {
        id: larimar
        available: true
        colors: ({ background: "#0a181c", surface: "#152d36", surfaceRaised: "#20424f", text: "#e6f9fc", textMuted: "#a0dbe6",
                   textFaint: "#589dbb", line: "#2b5768", accent: "#42c8d9", warm: "#f9e2af", danger: "#b4befe",
                   highlight: "#42c8d9", success: "#94e2d5", islandBackground: "#071114" })
    }
    // A stand-in for DMS's launcher engine (Z197): one result of each kind, answering any text at once.
    LauncherDomain {
        id: engine
        recordCalls: true
        available: false
        function search(text: string) {
            record("search", [text]);
            query = text;
            results = [{ key: 0, id: "sample-browser", kind: "app", name: "Sample Browser", description: "Web Browser", icon: "", glyph: "", source: "" },
                       { key: 1, id: "", kind: "setting", name: "Wi-Fi", description: "Network", icon: "", glyph: "wifi", source: "" },
                       { key: 2, id: "", kind: "file", name: "wish-list.md", description: "Documents", icon: "", glyph: "", source: "" },
                       { key: 3, id: "", kind: "plugin", name: "Weather", description: "Plugin", icon: "", glyph: "cloud", source: "" },
                       { key: 4, id: "", kind: "clip", name: "Sample clip", description: "Clipboard", icon: "", glyph: "", source: "" }];
        }
    }
    CoreClient { id: client }
    FixtureAdapter { id: fixture }
    Component.onCompleted: {
        // Captures for the owner use their palette's colours (Larimar); the checks don't depend on it.
        Design.source = root.shots ? larimar : fixture.palette;
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
            // The orbit (Z196): bodies mirror each other about the island's axis, and the selection wraps both ways.
            () => {
                const orbit = root.find(island, "launcherOrbit");
                const bodies = [];
                const walk = node => { if (!node) return; if (node.objectName === "launcherBody") bodies.push(node); for (const c of node.children) walk(c); };
                walk(orbit);
                const cx = orbit.cx;
                const mirrored = bodies.every(b => b.eclipse > 0.99 || bodies.some(o => o !== b && Math.abs((o.x - cx) + (b.x - cx)) < 1 && Math.abs(o.y - b.y) < 1)
                                                 || Math.abs(b.x - cx) < 1);
                check("orbit.symmetric", bodies.length === 6 && mirrored, bodies.map(b => [Math.round(b.x), Math.round(b.y)]));
                const pick = bodies.find(b => b.eclipse > 0.99);
                check("orbit.pick.at.perigee", !!pick && Math.abs(pick.x - cx) < 1 && Math.abs(pick.y - orbit.perigeeY) < 1, pick ? [pick.x, pick.y] : null);
                root.face.move(-1);
                check("orbit.wraps.back", root.face.selected === 5 && root.face.turn === -1, [root.face.selected, root.face.turn]);
                root.face.move(1);
                after(Math.max(400, 2 * 320), () => {
                    check("orbit.settles", Math.abs(orbit.spin - orbit.turn) < 1e-6, [orbit.spin, orbit.turn]);
                    next();
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
            // Captures only: the orbit drawing in on open, then one swing, frame by frame.
            () => {
                if (!root.shots) { next(); return; }
                if (island.launcherOpen) island.toggleLauncher();
                until(() => !island.launcherOpen, 1000, () => {
                    island.openLauncher();
                    root.frames("open", 12, 70, () => until(() => !!root.face && root.face.results.length > 5, 2000, () => {
                        root.face.move(1);
                        root.frames("swing", 10, 60, () => { island.toggleLauncher(); until(() => !island.launcherOpen, 1000, next); });
                    }));
                });
            },
            // The host's engine (Z197): its results show under the core's inline rows, and Enter runs them there.
            () => {
                fixture.launcher = engine;
                engine.available = true;
                island.openLauncher();
                until(() => !!root.input, 2000, () => {
                    root.input.text = "wi";
                    until(() => root.face.results.length === 5, 2000, ok => {
                        check("engine.rows", ok && root.face.results.map(r => r.kind).join() === "app,setting,file,plugin,clip", root.face.results);
                        check("engine.opened", engine.calls.some(c => c.method === "open"), engine.calls);
                        root.face.move(1);
                        root.shot("10-engine", () => {
                            root.face.launch(root.face.selected);
                            until(() => engine.calls.some(c => c.method === "execute"), 2000, ran => {
                                const call = engine.calls.find(c => c.method === "execute");
                                check("engine.executes", ran && call.args[0] === 1, engine.calls);
                                until(() => !island.launcherOpen, 1000, closed => {
                                    check("engine.closes", closed && engine.calls.some(c => c.method === "close"), engine.calls);
                                    engine.available = false;
                                    fixture.launcher = null;
                                    next();
                                });
                            });
                        });
                    });
                });
            },
            // Inline rows (Z195): each opens the launcher, types, checks the top row and presses Enter on it.
            () => root.inline("6*7", "calc", "inline.calc", () => {
                const last = fixture.clipboard.calls[fixture.clipboard.calls.length - 1];
                return last?.method === "copyText" && last.args[0] === "42";
            }, "05-calc"),
            () => root.inline("10 km to mi", "convert", "inline.convert", () => {
                const last = fixture.clipboard.calls[fixture.clipboard.calls.length - 1];
                return last?.method === "copyText" && last.args[0] === "6.21371";
            }, "06-convert"),
            () => root.inline(">echo hi", "command", "inline.command", () => {
                const argv = root.lastRun();
                return !!argv && argv[0] === "kitty" && argv[argv.length - 1] === "echo hi";
            }, "07-command"),
            () => root.inline("?cats", "search", "inline.search", () => {
                const argv = root.lastRun();
                return !!argv && argv[0] === "xdg-open" && argv[1] === "https://search.brave.com/search?q=cats";
            }, "08-search"),
            () => root.inline("task buy milk", "verb", "inline.verb", () => true, "09-verb"),
            () => until(() => JSON.stringify(client.tasksData ?? {}).indexOf("buy milk") >= 0, 2000, ok => {
                check("inline.verb.ran", ok, client.tasksData);
                next();
            }),
            () => {
                island.openLauncher();
                until(() => !!root.input, 2000, () => type(">", () => {
                    const before = fixture.apps.calls.length;
                    root.face.launch(0);
                    after(300, () => {
                        check("inline.empty.waits", root.face.results[0].ready === false && fixture.apps.calls.length === before && island.launcherOpen, root.face.results);
                        island.toggleLauncher();
                        until(() => !island.launcherOpen, 1000, next);
                    });
                }));
            },
        ];
        next();
    }

    FloatingWindow {
        implicitWidth: 1040
        implicitHeight: 640
        color: "#02060a"
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
