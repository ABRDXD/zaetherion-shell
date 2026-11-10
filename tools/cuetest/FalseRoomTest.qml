import QtQuick
import Quickshell
import qs.view.cues
import qs.view.overdrive
import qs.view.ui
import "view/overdrive/FalseRoom.js" as F
import "view/shell/Orbit.js" as Orbit

// The False Room (view/overdrive/FalseRoom.qml and FalseRoomSheet.qml; docs/OVERDRIVE.md §53, atlas W1), offscreen,
// on a stand-in for the orbit's geometry. Two survey errors: nothing. Three: the frame lies on the plane, shut. Every
// condition at once (the sky is turned to its hour by the longitude): it rises on its stalk and opens; entering shows
// the reconstruction and spends the set, so it shuts again; a release takes it away. With FALSE_SHOTS set, frames are
// saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("FALSE_SHOTS") || ""
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
    readonly property var rooms: ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]
    property var spent: []
    property string entered: ""

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 640; visible: true
        color: "black"
        Rectangle {
            id: stage
            width: 900
            height: 640
            color: Design.background
            // The orbit's geometry, as OrbitSystem exposes it.
            Item {
                id: orbit
                anchors.fill: parent
                readonly property real outer: 200
                readonly property real cx: 450
                readonly property real cy: 300
                readonly property var camView: Orbit.view(Orbit.ELEVATION, outer)
                readonly property real tileW: 110
                readonly property real tileH: 60
                readonly property real lift: 44
                // Two of its orbits, for bearings.
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const g = getContext("2d");
                        g.strokeStyle = Design.line;
                        for (const r of [0.55, 1]) {
                            const o = Orbit.outline(orbit.outer * r, orbit.cx, orbit.cy, orbit.camView, 72);
                            g.beginPath();
                            o.back.concat(o.front).forEach((p, i) => i ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y));
                            g.stroke();
                        }
                    }
                }
            }
            FalseRoom {
                id: room
                anchors.fill: parent
                orbit: orbit
                book: ({ seed: 7, errors: [1, 2] })
                battery: ({ available: true, charging: false })
                playing: false
                spent: root.spent
                journey: ({ recent: [["home", 1], ["codex", 2], ["clipboard", 3]],
                            edges: { "home>media": 30, "media>home": 20, "home>codex": 1, "codex>clipboard": 0 } })
                // Off its hour until the test turns the sky.
                longitude: (F.hour(7) + 12.5 - F.sidereal(Date.now(), 0)) * 15
                onEntered: signature => { root.entered = signature; root.spent = F.spend(root.spent, signature); sheet.active = true; }
            }
            Loader {
                id: sheet
                anchors.fill: parent
                active: false
                sourceComponent: FalseRoomSheet {
                    rooms: root.rooms
                    names: ({ home: "Home", media: "Media", codex: "Codex", clipboard: "Clips" })
                    journey: ({ seconds: { home: 30000, media: 4000, performance: 300, codex: 1200, clipboard: 90 },
                                visits: { home: 60, media: 12, performance: 3, codex: 7, clipboard: 2 },
                                hours: { home: [0, 0, 0, 0, 0, 0, 0, 0, 0.2, 0.6, 1, 0.8, 0.4, 0.3, 0.5, 0.7, 0.9, 0.6, 0.3, 0.2, 0.4, 0.8, 0.6, 0.1] },
                                recent: [["home", 1762750000], ["media", 1762750300], ["home", 1762751000], ["codex", 1762752000], ["clipboard", 1762752600]] })
                    devices: 3
                    pressure: "II"
                    signature: root.entered
                }
            }
        }
    }
    Component.onCompleted: after(300, () => {
        overdrive(true);
        after(100, () => {
            check("false.unseen", !room.visible && !room.sighted, { visible: room.visible });
            room.book = { seed: 7, errors: [1, 2, 3] };
            after(100, () => {
                check("false.sighted", room.visible && room.sighted && !room.open && room.rise === 0 && !room.conds.sky && room.conds.battery && room.conds.quiet && room.conds.rare,
                      { visible: room.visible, open: room.open, conds: room.conds });
                shot("shut", () => {
                    room.longitude = (F.hour(7) + 0.5 - F.sidereal(Date.now(), 0)) * 15;
                    after(1800, () => {
                        const area = find(room, i => i.cursorShape !== undefined && i.pressed !== undefined);
                        check("false.open", room.open && room.rise > 0.99 && !!area && area.enabled, { open: room.open, rise: room.rise, conds: room.conds, area: !!area });
                        shot("open", () => {
                            room.entered(room.conds.signature);
                            after(300, () => {
                                const s = sheet.item;
                                check("false.entered", !!s && s.model.spokes.length === 10 && s.model.path.length === 5 && root.entered === room.conds.signature,
                                      { sheet: !!s, spokes: s?.model.spokes.length, path: s?.model.path.length });
                                check("false.spent", !room.open && root.spent.length === 1, { open: room.open, spent: root.spent });
                                shot("inside", () => {
                                    sheet.active = false;
                                    overdrive(false);
                                    after(50, () => {
                                        check("false.release", room.opacity === 0, { opacity: room.opacity });
                                        finish();
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    })
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) { const f = find(child, test); if (f) return f; }
        return null;
    }
    function finish() {
        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
        console.log("CUE_DONE");
        Qt.exit(0);
    }
}
