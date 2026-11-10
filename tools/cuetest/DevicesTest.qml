import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell

// Phantom ports in Devices (view/rooms/Ports.js, LinkRow; docs/OVERDRIVE.md §25), against the fixture's devices: the
// linked headset disconnects and its row says when it left; it vanishes and an inert empty socket says when it went;
// it links again and the phantom is gone. With DEVICES_SHOTS set, frames.
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
    readonly property string shots: Quickshell.env("DEVICES_SHOTS") || ""
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        stage.grabToImage(r => { r.saveToFile(shots + "/" + name + ".png"); fn(); });
    }
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1300; implicitHeight: 760; visible: true
        color: "#0d1218"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#0d1218" }
            Devices { id: room; anchors.fill: parent; anchors.margins: 24; host: fixture; shell: context }
        }
    }
    function row(name) { return find(room, i => i.label === name && i.gone !== undefined); }
    Component.onCompleted: after(400, () => {
        const original = fixture.bluetooth.devices;
        const headset = original.find(d => d.connected);
        const others = original.filter(d => d !== headset);
        const start = JSON.stringify(room.phantoms);
        fixture.bluetooth.devices = [Object.assign({}, headset, { connected: false }), ...others];
        after(100, () => {
            const left = row(headset.name);
            check("ports.left", start === JSON.stringify({ left: {}, gone: [] }) && !!left && left.lost > 0 && !left.gone && left.enabled, { start: start, lost: left?.lost });
            fixture.bluetooth.devices = others;
            after(100, () => {
                const gone = row(headset.name);
                const label = find(gone, i => typeof i.text === "string" && i.text.startsWith("GONE "));
                check("ports.gone", !!gone && gone.gone && !gone.enabled && gone.verb === "" && !!label && label.visible, { gone: !!gone, enabled: gone?.enabled });
                shot("devices-gone", () => {
                    fixture.bluetooth.devices = original;
                    after(100, () => {
                        const back = row(headset.name);
                        const phantoms = room.phantoms;
                        room.weather = { ledger: [{ span: 3600, battery: 80, drain: 18 }, { span: 1200, battery: 90, drain: -30 }, { span: 5400, battery: 70, drain: 6 }] };
                        const ledger = find(room, i => i.book !== undefined && i.entries !== undefined);
                        check("ledger.entries", !!ledger && ledger.book.length === 3 && ledger.book[1].credit && ledger.book[0].depth > ledger.book[2].depth,
                              { book: ledger?.book });
                        check("ports.back", !!back && back.lost === 0 && !back.gone && phantoms.gone.length === 0 && Object.keys(phantoms.left).length === 0,
                              { lost: back?.lost, phantoms: phantoms });
                        shot("devices-ledger", () => {
                            // The letterpress, in Overdrive (fed directly; the core is absent here).
                            Motion.overdrive = true;
                            Motion.settleDrive();
                            after(300, () => {
                                const press = find(room, i => i.heldUntil !== undefined && i.take !== undefined);
                                const plane = find(room, i => i.press !== undefined && i.label === "Wi-Fi");
                                press?.take({ net: { rx: 800000, tx: 2000 } });
                                const deboss = press ? press.press : 0, shown = plane ? plane.press : 0;
                                press?.take({ net: { rx: 0, tx: 0 } });
                                const held = press ? press.press : 0;
                                if (press) press.heldUntil = 0;
                                press?.take({ net: { rx: 0, tx: 0 } });
                                check("press.deboss", deboss < -0.7 && shown === deboss && held === deboss && press.press === 0,
                                      { found: !!press, deboss: deboss, shown: shown, held: held, after: press?.press });
                                // The bus schematic (fed directly): a stick on a hub, then pulled out, and a camera plugged in.
                                const buses = find(room, i => i.columns !== undefined && i.memory !== undefined && i.take !== undefined);
                                const hubs = [{ pci: "0000:06:00.3", hubs: [{ bus: 1, speed: 480, ports: 3 }, { bus: 2, speed: 10000, ports: 2 }] },
                                              { pci: "0000:08:00.4", hubs: [{ bus: 3, speed: 480, ports: 1 }] }];
                                const base = [{ path: "3-1", bus: 3, parent: "usb3", port: 1, kind: "RADIO", speed: 12, product: "Bluetooth Radio", ports: 0 },
                                              { path: "1-1", bus: 1, parent: "usb1", port: 1, kind: "INPUT", speed: 12, product: "Receiver", ports: 0 },
                                              { path: "1-2", bus: 1, parent: "usb1", port: 2, kind: "HUB", speed: 480, product: "Hub", ports: 2 }];
                                const t0 = Date.now();
                                if (buses) {
                                    buses.autonomous = false;
                                    buses.take({ running: true, controllers: hubs, devices: base.concat([{ path: "1-2.2", bus: 1, parent: "1-2", port: 2, kind: "STORAGE", speed: 480, product: "Stick", ports: 0 }]) }, t0);
                                    buses.take({ running: true, controllers: hubs, devices: base.concat([{ path: "1-3", bus: 1, parent: "usb1", port: 3, kind: "VIDEO", speed: 480, product: "Camera", ports: 0 }]) }, t0 + 60000);
                                }
                                after(100, () => {
                                    const states = {};
                                    const walk = i => { if (i.state !== undefined && i.modelData?.path !== undefined) states[i.modelData.path] = i.state; for (const c of i.children ?? []) walk(c); };
                                    if (buses) walk(buses);
                                    const cam = find(buses, i => typeof i.text === "string" && i.text.startsWith("VIDEO 480M"));
                                    const ghost = find(buses, i => typeof i.text === "string" && i.text.startsWith("STORAGE · OUT "));
                                    const headset = fixture.bluetooth.devices.find(d => d.connected);
                                    const audio = buses ? buses.columns[buses.columns.length - 1] : null;
                                    check("buses.wired", !!buses && buses.columns.length === 3 && states["1-1"] === "device" && states["1-3"] === "fresh"
                                          && states["1-2.2"] === "ghost" && states["2-1"] === "open" && !!cam?.visible && !!ghost?.visible,
                                          { found: !!buses, states: states, cam: cam?.text, ghost: ghost?.text });
                                    check("buses.island", !!headset && states["bt:" + headset.id] === "device" && audio?.pci === "AUDIO"
                                          && audio.rows.length === fixture.audio.outputs.length + fixture.audio.inputs.length,
                                          { states: states, audio: audio });
                                    shot("devices-buses", () => {
                                Motion.overdrive = false;
                                Motion.settleDrive();
                                after(200, () => {
                                    check("buses.release", !find(room, i => i.columns !== undefined && i.memory !== undefined && i.take !== undefined), {});
                                    console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                                    console.log("CUE_DONE");
                                    Qt.exit(0);
                                });
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    });
}
