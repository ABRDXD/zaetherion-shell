import QtQuick
import Quickshell
import qs.view.cues

// Cue component tests (docs/CUES.md §10.1). Prints CUE_PASS/CUE_FAIL lines, then CUE_DONE.
// Motion.timeScale is 10, so a 16 ms frame is under 1% of any cue.
Scope {
    id: root
    // Largest believable step between two samples at timeScale 10; a restart or snap is ≥ 0.3.
    readonly property real maxStep: 0.1
    // Timing tolerance: three frames plus 5%.
    function within(actual, expected) { return Math.abs(actual - expected) <= 50 + expected * 0.05; }
    function pass(name) { console.log("CUE_PASS", name); }
    function fail(name, detail) { console.log("CUE_FAIL", name, detail); }
    function check(name, ok, detail) { ok ? pass(name) : fail(name, JSON.stringify(detail)); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function make(source, parent) {
        return Qt.createQmlObject("import QtQuick; import qs.view.cues; " + source, parent ?? stage);
    }
    // Records every value change: the largest step, the samples and the time it settled.
    function watch(target) {
        const w = { last: target.value, step: 0, samples: [], settledAt: 0 };
        target.valueChanged.connect(() => {
            w.step = Math.max(w.step, Math.abs(target.value - w.last));
            w.last = target.value;
            w.samples.push([Date.now(), target.value]);
        });
        return w;
    }
    function untilStopped(target, fn) {
        if (!target.running) { fn(Date.now()); return; }
        const poll = () => target.running ? after(10, poll) : fn(Date.now());
        after(10, poll);
    }
    function monotonic(samples, rising) {
        for (let i = 1; i < samples.length; i++)
            if (rising ? samples[i][1] < samples[i - 1][1] - 1e-9 : samples[i][1] > samples[i - 1][1] + 1e-9) return false;
        return true;
    }

    property var tests: [
        // Retrigger in the same direction is a no-op: no restart, monotonic, same settle time.
        done => {
            const cue = make("Cue { name: 'test.retrigger'; enter: Motion.unfold; exit: Motion.fold }");
            const w = watch(cue);
            const t0 = Date.now();
            cue.on = true;
            after(Motion.unfold / 2, () => {
                cue.on = true;
                cue.on = false;
                cue.on = true;
                untilStopped(cue, t => {
                    check("cue.retrigger", cue.value === 1 && root.monotonic(w.samples, true) && w.step <= root.maxStep,
                          { step: w.step, value: cue.value, ms: t - t0 });
                    cue.destroy();
                    done();
                });
            });
        },
        ...[0.25, 0.5, 0.75].map(at => done => {
            const cue = make("Cue { name: 'test.reverse'; enter: Motion.unfold; exit: Motion.fold }");
            const w = watch(cue);
            cue.on = true;
            after(Motion.unfold * at, () => {
                const reached = cue.value;
                const t0 = Date.now();
                cue.on = false;
                untilStopped(cue, t => {
                    const expected = Motion.fold * Math.min(1, reached);
                    check("cue.reverse." + at, cue.value === 0 && w.step <= root.maxStep && root.within(t - t0, expected),
                          { step: w.step, reached: reached, ms: t - t0, expected: expected });
                    cue.destroy();
                    done();
                });
            });
        }),
        done => {
            const base = Motion.active;
            const cue = make("Cue { name: 'test.cancel'; enter: Motion.unfold }");
            cue.on = true;
            after(Motion.unfold / 2, () => {
                cue.on = false;
                cue.settle();
                check("cue.cancel", cue.value === 0 && !cue.running && Motion.active === base, { value: cue.value, active: Motion.active });
                cue.destroy();
                done();
            });
        },
        // Hidden scope settles at once; showing it again replays nothing.
        done => {
            const holder = make("Item { width: 10; height: 10 }");
            const cue = make("Cue { name: 'test.scope'; enter: Motion.unfold }", holder);
            cue.scope = holder;
            cue.on = true;
            after(Motion.unfold / 2, () => {
                holder.visible = false;
                const settled = cue.value === 1 && !cue.running;
                holder.visible = true;
                after(50, () => {
                    check("cue.scope", settled && cue.value === 1 && !cue.running, { settled: settled, running: cue.running });
                    holder.destroy();
                    done();
                });
            });
        },
        done => {
            const cue = make("Cue { name: 'test.reduced'; enter: Motion.unfold }");
            cue.on = true;
            after(Motion.unfold / 2, () => {
                Motion.reduced = true;
                const settled = cue.value === 1 && !cue.running;
                cue.on = false;
                const cut = cue.value === 0 && !cue.running;
                Motion.reduced = false;
                check("cue.reduced", settled && cut, { settled: settled, cut: cut });
                cue.destroy();
                done();
            });
        },
        done => {
            const base = Motion.active;
            const cue = make("Cue { name: 'test.destroy'; enter: Motion.unfold }");
            cue.on = true;
            after(Motion.unfold / 4, () => {
                const counted = Motion.activeNames.includes("test.destroy");
                cue.destroy();
                after(20, () => {
                    check("cue.destroy", counted && Motion.active === base, { counted: counted, active: Motion.activeNames });
                    done();
                });
            });
        },
        // Twenty triggers in one turn: one animation toward the last state.
        done => {
            const cue = make("Cue { name: 'test.burst'; enter: Motion.unfold }");
            for (let i = 0; i < 20; i++) cue.on = i % 2 === 0;
            cue.on = true;
            const one = Motion.activeNames.filter(n => n === "test.burst").length === 1;
            untilStopped(cue, () => {
                check("cue.burst", one && cue.value === 1, { one: one, value: cue.value });
                cue.destroy();
                done();
            });
        },
        // Replay starts new content from rest, but never restarts a cue in flight.
        done => {
            const cue = make("Cue { name: 'test.replay'; on: true; enter: Motion.navigate }");
            const atStart = cue.value === 1;
            cue.replay();
            after(Motion.navigate / 2, () => {
                const mid = cue.value;
                cue.replay();
                const kept = cue.value === mid && cue.running;
                untilStopped(cue, () => {
                    check("cue.replay", atStart && mid > 0 && mid < 1 && kept && cue.value === 1, { mid: mid, kept: kept });
                    cue.destroy();
                    done();
                });
            });
        },
        // A cue created on, and bindings settling during creation, never animate.
        done => {
            const holder = make("Item { id: h; property bool open: true; width: 10; height: 10; Cue { name: 'test.created'; on: h.open; enter: Motion.unfold } }");
            const cue = holder.resources[0];
            check("cue.created", cue.value === 1 && !cue.running && !Motion.activeNames.includes("test.created"), { value: cue.value, running: cue.running });
            holder.destroy();
            done();
        },
        // A loop turned off falls back to rest from where it is, within one release.
        done => {
            const pulse = make("Pulse { name: 'test.loop.off'; repeat: true; attack: Motion.breath; attackEasing: Motion.linear }");
            after(Motion.breath / 2, () => {
                const mid = pulse.value;
                const t0 = Date.now();
                pulse.repeat = false;
                const falling = !pulse.rising;
                untilStopped(pulse, t => {
                    check("pulse.repeat.off", falling && pulse.value === 0 && within(t - t0, Motion.breath * mid), { mid: mid, falling: falling, ms: t - t0 });
                    pulse.destroy();
                    done();
                });
            });
        },
        // Pulse: retrigger while rising is a no-op; while falling it rises again from where it is.
        done => {
            const pulse = make("Pulse { name: 'test.pulse'; attack: Motion.swap; release: Motion.swap; attackEasing: Motion.linear }");
            const w = watch(pulse);
            pulse.trigger();
            after(Motion.swap / 2, () => {
                pulse.trigger();
                const rising = root.monotonic(w.samples, true);
                after(Motion.swap, () => {
                    const falling = pulse.value;
                    pulse.trigger();
                    untilStopped(pulse, () => {
                        const peak = Math.max(...w.samples.map(s => s[1]));
                        check("pulse.retrigger", rising && falling > 0 && falling < 1 && peak <= 1 && w.step <= root.maxStep && pulse.value === 0,
                              { rising: rising, falling: falling, peak: peak, step: w.step });
                        pulse.destroy();
                        done();
                    });
                });
            });
        },
        done => {
            const base = Motion.active;
            const pulse = make("Pulse { name: 'test.pulse.cancel'; attack: Motion.swap }");
            pulse.trigger();
            after(Motion.swap / 2, () => {
                pulse.cancel();
                check("pulse.cancel", pulse.value === 0 && !pulse.running && Motion.active === base, { value: pulse.value });
                pulse.destroy();
                done();
            });
        },
        // A repeating pulse runs only while live; shown again, it restarts.
        done => {
            const holder = make("Item { width: 10; height: 10 }");
            const pulse = make("Pulse { name: 'test.breath'; repeat: true; attack: Motion.breath; attackEasing: Motion.linear }", holder);
            pulse.scope = holder;
            after(Motion.breath * 1.5, () => {
                const looping = pulse.running;
                holder.visible = false;
                const stopped = !pulse.running && pulse.value === 0;
                holder.visible = true;
                const restarted = pulse.running;
                Motion.reduced = true;
                const reduced = !pulse.running && pulse.value === 0;
                Motion.reduced = false;
                check("pulse.repeat", looping && stopped && restarted && reduced, { looping: looping, stopped: stopped, restarted: restarted, reduced: reduced });
                holder.destroy();
                done();
            });
        },
        // FlashGate: 3 per 1000 ms, dropped not deferred, none when reduced.
        done => {
            let clock = 0;
            const now = FlashGate.now;
            FlashGate.now = () => clock;
            FlashGate.grants = [];
            let granted = 0;
            for (let i = 0; i < 10; i++) { clock = i * 20; if (FlashGate.request("test")) granted++; }
            clock = 1000;
            const again = FlashGate.request("test");
            clock = 1100;
            const fourth = FlashGate.request("test");
            Motion.reduced = true;
            clock = 5000;
            const reduced = FlashGate.request("test");
            Motion.reduced = false;
            clock = -100000;
            const backwards = FlashGate.request("test");
            FlashGate.now = now;
            FlashGate.grants = [];
            check("flash.gate", granted === 3 && again && fourth === true && !reduced && backwards,
                  { granted: granted, again: again, fourth: fourth, reduced: reduced, backwards: backwards });
            done();
        },
        // A flash pulse over the cap does nothing.
        done => {
            FlashGate.grants = [];
            const pulse = make("Pulse { name: 'test.flash'; flash: true; attack: 1; release: 1 }");
            let started = 0;
            pulse.runningChanged.connect(() => { if (pulse.running && pulse.rising) started++; });
            const tick = n => {
                if (n === 0) {
                    after(50, () => {
                        check("flash.pulse", started === 3, { started: started });
                        pulse.destroy();
                        FlashGate.grants = [];
                        done();
                    });
                    return;
                }
                pulse.trigger();
                after(30, () => tick(n - 1));
            };
            tick(8);
        },
        // Timeline: reversing retraces every track; the later track leaves first.
        done => {
            const timeline = make("Timeline { name: 'test.timeline'; enter: Motion.unfold; Track { start: 0; end: 0.6 } Track { start: 0.3; end: 1 } }");
            const back = timeline.tracks[0], front = timeline.tracks[1];
            const wb = watch(back), wf = watch(front);
            let frontZero = 0, backZero = 0;
            timeline.on = true;
            after(Motion.unfold * 0.8, () => {
                const both = back.value > 0 && front.value > 0;
                timeline.on = false;
                const poll = () => {
                    if (!frontZero && front.value === 0) frontZero = Date.now();
                    if (!backZero && back.value === 0) backZero = Date.now();
                    if (timeline.running) after(5, poll);
                    else {
                        check("timeline.reverse", both && frontZero > 0 && frontZero < backZero && wb.step <= root.maxStep && wf.step <= root.maxStep,
                              { both: both, order: backZero - frontZero, sb: wb.step, sf: wf.step });
                        timeline.destroy();
                        done();
                    }
                };
                poll();
            });
        },
        // Tween: a new value retargets from the current one; not live, changes jump.
        done => {
            const holder = make("Item { width: 10; height: 10; Tween on x { NumberAnimation { duration: Motion.swap } } }");
            const xs = [];
            holder.xChanged.connect(() => xs.push(holder.x));
            holder.x = 100;
            after(Motion.swap / 2, () => {
                const mid = holder.x;
                holder.x = 0;
                after(Motion.swap * 1.2, () => {
                    let step = 0;
                    for (let i = 1; i < xs.length; i++) step = Math.max(step, Math.abs(xs[i] - xs[i - 1]));
                    const settled = holder.x === 0;
                    Motion.reduced = true;
                    holder.x = 50;
                    const jumped = holder.x === 50;
                    Motion.reduced = false;
                    check("tween.retarget", mid > 0 && mid < 100 && step <= 10 && settled && jumped,
                          { mid: mid, step: step, settled: settled, jumped: jumped });
                    holder.destroy();
                    done();
                });
            });
        }
    ]
    property int index: -1
    function next() {
        index++;
        if (index >= tests.length) {
            after(50, () => {
                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                console.log("CUE_DONE");
                Qt.quit();
            });
            return;
        }
        tests[index](() => after(20, next));
    }
    FloatingWindow {
        implicitWidth: 200; implicitHeight: 200; visible: true
        Item { id: stage; anchors.fill: parent }
    }
    Component.onCompleted: {
        Motion.timeScale = 10;
        after(100, next);
    }
}
