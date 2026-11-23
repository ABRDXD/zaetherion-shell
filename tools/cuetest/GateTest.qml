import QtQuick
import Quickshell
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui

// The intent gate (view/shell/IntentGate.js in CommandLine.qml; docs/OVERDRIVE.md §52, atlas #62) on the real command
// line, offscreen. Its core is never connected, so a line that is sent only lands in the log as "not connected":
// nothing is ever actuated. Silent runs a cutting line at once; Overdrive holds it as two planes until the room's
// number is typed, a wrong digit throws them apart, Esc and a release put the line back unsent, and a line that cuts
// nothing runs at once. With GATE_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("GATE_SHOTS") || ""
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
    function overdrive(on) { Motion.overdrive = on; Motion.settleDrive(); }
    function type(line) { cmd.typeIn(line); cmd.run(); }

    CoreClient { id: core }
    FloatingWindow {
        implicitWidth: 640; implicitHeight: 140; visible: true
        color: "black"
        Rectangle {
            id: stage
            width: 640
            height: 140
            color: Design.background
            CommandLine {
                id: cmd
                x: 40; y: 30
                width: 560
                height: 32
                core: core
                roomIndexOf: id => ({ home: 0, devices: 4, timers: 6 })[id] ?? 0
            }
        }
    }
    // Opened once the core is assigned, as the Shell does (opening loads the history from it).
    Component.onCompleted: { cmd.panelOpen = true; after(300, start); }
    function start() {
        type("wifi off");
        after(100, () => {
            check("gate.silent", cmd.gate === null && cmd.lines().length === 1 && cmd.lines()[0].startsWith("wifi off → "), { gate: cmd.gate, lines: cmd.lines() });
            overdrive(true);
            type("wifi off");
            after(250, () => {
                check("gate.split", cmd.gate?.seq === "04" && cmd.gateNotches === 2 && cmd.lines().length === 1 && cmd.text === "wifi off",
                      { gate: cmd.gate, notches: cmd.gateNotches, lines: cmd.lines(), text: cmd.text });
                shot("split", () => {
                    cmd.gateKey("0");
                    const one = cmd.gateNotches;
                    cmd.gateKey("5");
                    check("gate.wrong", one === 1 && cmd.gateNotches === 2 && !cmd.gateRegistered, { one: one, notches: cmd.gateNotches });
                    cmd.gateKey("0");
                    cmd.gateKey("4");
                    after(250, () => {
                        check("gate.registered", cmd.gateRegistered && cmd.gateNotches === 0 && cmd.lines().length === 1, { gate: cmd.gate, lines: cmd.lines() });
                        shot("registered", () => {
                            cmd.run();
                            after(100, () => {
                                check("gate.ran", cmd.gate === null && cmd.lines().length === 2 && cmd.lines()[1].startsWith("wifi off → ") && cmd.text === "",
                                      { gate: cmd.gate, lines: cmd.lines(), text: cmd.text });
                                type("bt off");
                                const held = cmd.gate?.seq === "04";
                                cmd.ungate();
                                check("gate.escape", held && cmd.gate === null && cmd.text === "bt off" && cmd.lines().length === 2, { held: held, text: cmd.text, lines: cmd.lines() });
                                cmd.cancel();
                                type("lock");
                                const lock = cmd.gate?.seq === "00";
                                overdrive(false);
                                after(50, () => {
                                    check("gate.release", lock && cmd.gate === null && cmd.text === "lock" && cmd.lines().length === 2, { lock: lock, text: cmd.text, lines: cmd.lines() });
                                    cmd.cancel();
                                    overdrive(true);
                                    type("wifi on");
                                    after(100, () => {
                                        check("gate.plain", cmd.gate === null && cmd.lines().length === 3 && cmd.lines()[2].startsWith("wifi on → "), { gate: cmd.gate, lines: cmd.lines() });
                                        overdrive(false);
                                        after(50, finish);
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    }
    function finish() {
        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
        console.log("CUE_DONE");
        Qt.exit(0);
    }
}
