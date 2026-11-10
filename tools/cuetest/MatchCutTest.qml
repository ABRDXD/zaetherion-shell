import QtQuick
import Quickshell
import qs.view.cues
import qs.view.overdrive
import qs.view.rooms
import qs.view.shell
import qs.view.ui

// The archive match cut (view/overdrive/MatchCut.qml; docs/OVERDRIVE.md §51, atlas #40) on the real FArchive laid over
// a real RoomSheet, as the Shell lays them. The pivot is found in an archive label on screen and the target is the
// sheet's own number; the cut holds the pivot still, glides its box onto the number and hands over; release mid-cut
// leaves nothing. With MATCH_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("MATCH_SHOTS") || ""
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
    property string number: "05"

    FloatingWindow {
        implicitWidth: 900; implicitHeight: 700; visible: true
        color: "black"
        Rectangle {
            id: stage
            width: 900
            height: 700
            color: Design.background
            RoomSheet {
                id: sheet
                x: 16; y: 12
                width: 868; height: 676
                entry: ({ id: "tasks", name: "Tasks", about: "" })
                plan: ({ side: "left", span: 0.6, align: "top" })
                number: root.number
                cut: 150
            }
            Loader { id: dialog; anchors.fill: parent; active: false; z: 20; source: "view/rooms/FArchive.qml" }
            MatchCut { id: cut; anchors.fill: parent; z: 22 }
        }
    }
    Component.onCompleted: after(400, () => {
        ViewState.visited = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications"];
        ViewState.surveyDays = Array.from({ length: 10 }, (_, i) => "2026-11-" + String(i + 1).padStart(2, "0"));
        ViewState.loreEnabled = true;
        dialog.active = true;
        after(700, run);
    });
    function run() {
        const found = [];
        for (let n = 0; n < 10; n++) {
            const s = "0" + n;
            if (cut.pivotIn(dialog.item, s))
                found.push(s);
        }
        console.log("MATCH_PIVOTS", JSON.stringify(found));
        // The furthest room the archive can pivot on (its labels' numbers grow with the survey).
        root.number = found.length ? found[found.length - 1] : "05";
        after(100, cutTo);
    }
    function cutTo() {
        const from = cut.pivotIn(dialog.item, root.number), to = cut.targetIn(sheet, root.number);
        check("match.found", !!from && !!to && from.w > 4 && from.size < to.size && to.size >= Design.figure - 0.5 && Number(from.text) === Number(root.number),
              { from: from, to: to });
        check("match.absent", cut.pivotIn(dialog.item, "x") === null && cut.targetIn(sheet, "42") === null, {});
        if (!from || !to) return finish();
        overdrive(true);
        shot("archive", () => {
            dialog.active = false;
            cut.start(from, to);
            after(Math.round(820 * 0.12), () => {
                const held = cut.now && Math.abs(cut.now.x - from.x) < 0.5 && Math.abs(cut.now.y - from.y) < 0.5;
                check("match.hold", cut.running && cut.visible && held, { now: cut.now, from: from });
                shot("hold", () => after(Math.max(0, Math.round(820 * 0.5) - 100), () => {
                    shot("glide", () => after(500, () => {
                        check("match.landed", !cut.running && !cut.visible && Math.abs(cut.u - 1) < 1e-6, { running: cut.running, u: cut.u });
                        shot("landed", () => {
                            cut.start(from, to);
                            after(200, () => {
                                overdrive(false);
                                check("match.release", cut.opacity === 0, { opacity: cut.opacity });
                                finish();
                            });
                        });
                    }));
                }));
            });
        });
    }
    function finish() {
        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
        console.log("CUE_DONE");
        Qt.exit(0);
    }
}
