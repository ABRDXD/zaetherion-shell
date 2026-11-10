import QtQuick
import Quickshell
import qs.view.cues
import qs.view.ui
import qs.view.overdrive

// The clock occultation (view/overdrive/ClockOccultation.qml; docs/OVERDRIVE.md §50, atlas #51), offscreen. Silent:
// an event changes nothing. Overdrive: a countdown's end splits the clock and widens it, with the room number between;
// a device doesn't take the clock from it, but crosses in front once it has closed; a track passes behind; a release
// clears the event mid-crossing and leaves the plain clock. With OCC_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("OCC_SHOTS") || ""
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
    property real base: 0

    FloatingWindow {
        implicitWidth: 360; implicitHeight: 80; visible: true
        color: "black"
        Rectangle {
            id: stage
            width: 360
            height: 80
            color: Design.background
            Row {
                x: 40
                y: 24
                spacing: 12
                Rectangle { width: 30; height: 30; color: Design.surface }
                ClockOccultation {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    hours: "21"
                    minutes: "47"
                }
                Rectangle { width: 1; height: 18; color: Design.line; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Component.onCompleted: after(300, () => {
        root.base = clock.implicitWidth;
        clock.occult("timer", 6);
        check("clock.silent", clock.event === null && clock.implicitWidth === root.base && root.base > 40, { event: clock.event, w: clock.implicitWidth, base: root.base });
        overdrive(true);
        clock.occult("timer", 6);
        after(1300, () => {
            check("clock.split", clock.plane === "split" && clock.open > 0.99 && clock.implicitWidth > root.base + 20,
                  { plane: clock.plane, open: clock.open, w: clock.implicitWidth, base: root.base });
            clock.occult("device", 4);
            check("clock.priority", clock.event.kind === "timer", { kind: clock.event?.kind });
            shot("split", () => after(1500, () => {
                check("clock.closed", clock.event === null && clock.implicitWidth === root.base, { event: clock.event, w: clock.implicitWidth });
                clock.occult("device", 4);
                after(850, () => {
                    check("clock.front", clock.plane === "front" && clock.implicitWidth === root.base, { plane: clock.plane, w: clock.implicitWidth });
                    shot("front", () => after(1000, () => {
                        clock.occult("media", 1);
                        after(1100, () => {
                            check("clock.behind", clock.plane === "behind", { plane: clock.plane });
                            shot("behind", () => {
                                clock.occult("timer", 6);
                                after(400, () => {
                                    overdrive(false);
                                    after(50, () => {
                                        check("clock.release", clock.event === null && clock.plane === "" && clock.implicitWidth === root.base,
                                              { event: clock.event, plane: clock.plane, w: clock.implicitWidth });
                                        shot("released", finish);
                                    });
                                });
                            });
                        });
                    }));
                });
            }));
        });
    })
    function finish() {
        console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
        console.log("CUE_DONE");
        Qt.exit(0);
    }
}
