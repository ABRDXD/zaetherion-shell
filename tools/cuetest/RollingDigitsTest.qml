import QtQuick
import Quickshell
import qs.view.ui as UI
import qs.view.cues

// Rolling digits (view/ui/RollingDigits.qml, after NumberFlow), offscreen: changed digits roll, separators stay,
// the direction follows the number, digit slots keep one width, and reduced motion swaps at once. With
// ROLLING_SHOTS set, frames of a 9:59 → 10:00 roll are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("ROLLING_SHOTS") || ""
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function slots() {
        const out = [];
        for (const c of digits.children) if (c.glyph !== undefined) out.push(c);
        return out.sort((a, b) => a.x - b.x);
    }
    function frames(n, every, done) {
        if (!root.shots) { done(); return; }
        let k = 0;
        const grab = () => stage.grabToImage(r => { r.saveToFile(root.shots + "/roll-" + String(k).padStart(2, "0") + ".png"); if (++k < n) after(every, grab); else done(); });
        grab();
    }
    FloatingWindow {
        implicitWidth: 640; implicitHeight: 240; visible: true; color: "#000000"
        Loader {
            id: holder
            sourceComponent: Component {
                Item {
                    property alias readout: inner
                    UI.RollingDigits { id: inner; text: "6" }
                }
            }
        }
        Item {
            id: stage; anchors.fill: parent
            UI.RollingDigits {
                id: digits
                x: 40; y: 20
                text: "9:59"
                font.family: "Inter"; font.pixelSize: UI.Design.display * 2; font.weight: Font.ExtraLight // scale: as large as the Fluid Timers clock
                color: "#eef5fa"
                duration: 600
            }
        }
    }
    Component.onCompleted: after(300, () => {
        const before = slots();
        const digitWidths = before.filter(s => s.digit).map(s => s.width);
        check("digits.share.width", digitWidths.length === 3 && digitWidths.every(w => Math.abs(w - digitWidths[0]) < 0.01), digitWidths);
        digits.text = "10:00";
        after(80, () => {
            const mid = slots();
            const rolling = mid.filter(s => s.t < 1).map(s => s.glyph);
            check("changed.digits.roll", rolling.length === 4 && rolling.join("") === "1000", rolling);   // "1" is new, "0","0","0" changed
            check("separator.stays", mid.some(s => s.glyph === ":" && s.t === 1), {});
            check("rising.rolls.up", mid.filter(s => s.t < 1).every(s => s.dir === 1), mid.map(s => s.dir));
            frames(8, 60, () => after(700, () => {
                check("settles", slots().every(s => s.t === 1 && s.shown === s.glyph), {});
                digits.text = "9:59";
                after(80, () => {
                    check("falling.rolls.down", slots().filter(s => s.t < 1).every(s => s.dir === -1) && slots().some(s => s.t < 1), {});
                    after(700, () => {
                        Motion.reduced = true;
                        digits.text = "9:58";
                        after(30, () => {
                            check("reduced.swaps", slots().every(s => s.t === 1) && digits.text === "9:58", {});
                            Motion.reduced = false;
                            // A readout torn down in the same tick its text changed (a surface unloading): its deferred
                            // step must stay quiet.
                            const doomed = Qt.createQmlObject('import qs.view.ui as UI; UI.RollingDigits { text: "1" }', stage);
                            doomed.destroy();      // deferred: the text change below queues its step behind the deletion
                            doomed.text = "2";
                            holder.item.readout.text = "7";
                            holder.active = false; // the whole surface (and the context its names live in) goes at once
                            after(120, () => {
                                check("teardown.quiet", true, {});   // the run fails on any TypeError in the log
                                console.log("CUE_DONE");
                                Qt.quit();
                            });
                        });
                    });
                });
            }));
        });
    });
}
