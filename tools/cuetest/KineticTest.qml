import QtQuick
import Quickshell
import qs.view.cues
import qs.view.rooms
import qs.view.ui

// Kinetic lyrics' stage (M9, view/rooms/KineticStage.qml) against word-timed fixture lyrics. The song position is set
// directly with the player paused, so every step is deterministic: words appear at their times, phrases never cut
// faster than 3 a second, the stage inverts only through FlashGate, CJK stands upright, a returning chorus carries
// its ghosts, and a rest between lines throws the phrase out. With KINETIC_SHOTS set, frames are saved there.
ShellRoot {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    readonly property string shots: Quickshell.env("KINETIC_SHOTS") || ""
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        stage.grabToImage(r => { r.saveToFile(shots + "/" + name + ".png"); fn(); });
    }
    function words(start, list, each) { return list.map((t, i) => ({ time: start + i * each, end: start + (i + 1) * each, text: t })); }
    readonly property var lines: [
        // A credit some sources time at 0:00, over the intro: never staged.
        { time: 0, end: 1, text: "作词 : 中村未来", words: [] },
        { time: 1, end: 5, text: "We were burning brighter than the sun", words: [
            { time: 1.0, end: 1.3, text: "We" }, { time: 1.3, end: 1.6, text: "were" }, { time: 1.6, end: 2.1, text: "burning" },
            { time: 2.1, end: 2.5, text: "brighter" }, { time: 2.5, end: 2.8, text: "than" }, { time: 2.8, end: 3.0, text: "the" },
            { time: 3.0, end: 4.6, text: "sun" }] },
        { time: 6, end: 8.2, text: "rap", words: root.words(6, ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                                                                "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"], 0.1) },
        { time: 9, end: 11, text: "Hold on to the night", words: [] },
        { time: 12, end: 14, text: "夜空に光る星", words: [] },
        { time: 15, end: 17, text: "hold on to the night!", words: [] }
    ]
    QtObject {
        id: media
        property real position: 0
        property double positionStamp: Date.now()
        property var active: ({ playing: false })
        property var spectrum: []
    }
    FloatingWindow {
        id: window
        implicitWidth: 720
        implicitHeight: 260
        visible: true
        color: Design.background
        KineticStage {
            id: stage
            anchors.fill: parent
            media: media
            lines: root.lines
        }
    }
    function at(t) { media.position = t; }
    // For a frame worth looking at: land a quarter second early, so the last phrase has finished leaving.
    function land(t, fn) { at(t - 0.25); after(30, () => { at(t); after(50, fn); }); }
    Component.onCompleted: {
        Motion.overdrive = true;
        Motion.settleDrive();
        after(200, () => {
            // The intro: a credit line is timed, but nothing is sung yet, so nothing slams in.
            at(0.5);
            after(50, () => {
                check("stage.credits", stage.lineIndex === -1 && stage.shown === null && root.visibleWords().length === 0,
                      { line: stage.lineIndex, shown: stage.shown?.words?.map(w => w.text) ?? null, visible: root.visibleWords() });
            // Mid-phrase: the words sung so far are on stage, the rest not yet.
            at(2.2);
            after(50, () => {
                const shown = stage.shown?.words.map(w => w.text) ?? [];
                const items = root.visibleWords();
                check("stage.words", shown.length >= 4 && shown[0] === "We" && items.includes("BRIGHTER") && !items.includes("SUN"),
                      { shown: shown, visible: items });
                shot("1-midphrase", () => {
                    // A held word: bigger than its neighbours, swelling while sung, hollow once sung.
                    root.land(3.8, () => {
                        // A held word opens its own phrase, the last one gone, at well over the base size.
                        const sun = root.wordItem("SUN");
                        const sizeOk = !!sun && sun.font.pixelSize > stage.base * 1.3 && root.wordItem("THAN") === null;
                        const swelling = sun && sun.scale > 1;
                        shot("2-held", () => {
                            at(4.7);
                            after(50, () => { root.shot("2b-hollow", () => {
                                const sunNow = root.wordItem("SUN");
                                const hollow = !!sunNow && sunNow.outlined && sunNow.color.a === 0;
                                check("stage.held", sizeOk && swelling && hollow, { sizeOk: sizeOk, swelling: swelling, hollow: hollow });
                                root.rap();
                            }); });
                        });
                    });
                });
            });
            });
        });
    }
    // The rap: 10 words a second for 2 s, stepped every 20 ms of song time; cuts never exceed 3 in any second.
    function rap() {
        const cutsAt = [];
        let t = 5.9, last = stage.cuts;
        const step = () => {
            if (t > 8.3) {
                const tooFast = cutsAt.some((c, i) => cutsAt.filter(d => d > c - 1 && d <= c).length > 3);
                check("stage.cutcap", cutsAt.length >= 4 && !tooFast, { cuts: cutsAt });
                root.restAndChorus();
                return;
            }
            at(t);
            after(5, () => {
                if (stage.cuts !== last) { cutsAt.push(Math.round(t * 100) / 100); last = stage.cuts; }
                t += 0.02;
                step();
            });
        };
        step();
    }
    function restAndChorus() {
        // Between lines: the phrase has gone, the next line waits.
        at(8.8);
        after(300, () => {
            const rest = stage.resting && stage.shown === null;
            const restDetail = { resting: stage.resting, shown: stage.shown?.words?.map(w => w.text) ?? null };
            at(9.2);
            after(50, () => {
                const first = stage.echo;
                root.land(15.4, () => {
                    const chorus = stage.echo;
                    shot("3-chorus", () => {
                        root.land(12.6, () => {
                            shot("4-vertical", () => {
                                check("stage.rest", rest, restDetail);
                                check("stage.echo", first === 0 && chorus === 1, { first: first, chorus: chorus });
                                check("stage.vertical", stage.upright === true && !!stage.shown, { upright: stage.upright });
                                root.flashes();
                            });
                        });
                    });
                });
            });
        });
    }
    // Inversion goes through FlashGate: with its window full, a cut does not invert.
    function flashes() {
        FlashGate.grants = [Date.now(), Date.now(), Date.now()];
        const before = stage.inverted;
        stage.cuts = 1;  // the next cut is an even one, which asks to invert
        at(1.0); after(30, () => { at(2.9); after(30, () => {
            const denied = stage.inverted === before;
            FlashGate.grants = [];
            stage.cuts = 1;
            at(1.0); after(30, () => { at(3.1); after(30, () => {
                const granted = stage.inverted !== before;
                check("stage.flashgate", denied && granted, { denied: denied, granted: granted });
                // Release: the engine at rest leaves nothing drawn.
                Motion.overdrive = false;
                Motion.settleDrive();
                after(50, () => {
                    check("stage.release", stage.opacity === 0, { opacity: stage.opacity });
                    console.log("CUE_DONE");
                    Qt.quit();
                });
            }); });
        }); });
    }
    function textsIn(item, out) {
        if (!item) return out;
        if (item.text !== undefined && item.visible && item.opacity > 0 && item.font?.weight === Font.Black) out.push({ text: item.text, item: item });
        for (const child of item.children ?? []) textsIn(child, out);
        return out;
    }
    function visibleWords() { return textsIn(stage, []).filter(t => t.item.parent?.visible !== false && t.item.parent?.opacity === 1).map(t => t.text); }
    function wordItem(text) { return textsIn(stage, []).filter(t => t.text === text && t.item.parent?.opacity === 1).map(t => t.item)[0] ?? null; }
}
