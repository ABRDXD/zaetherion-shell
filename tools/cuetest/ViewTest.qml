import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.adapters.serpantinum
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.strata
import qs.view.ui as Fart

// Adopted cues in place, queued input and idle cost (docs/CUES.md §10.2–10.4).
// The real Shell runs against the fixture adapter in a FloatingWindow: the offscreen platform has no
// PanelWindow, so the Overlay's Unfold timeline is exercised here on its own.
Scope {
    id: root
    readonly property real maxStep: 0.1
    readonly property var pages: ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications"]
    function within(actual, expected) { return Math.abs(actual - expected) <= 50 + expected * 0.05; }
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail)); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function untilStopped(target, fn) {
        const poll = () => target.running ? after(10, poll) : fn(Date.now());
        poll();
    }
    // Settled: no cue running and the requested room shown (rooms incubate asynchronously).
    function untilIdle(fn) {
        const poll = () => Motion.active > 0 || dashboard.loadedPage !== dashboard.currentPage ? after(10, poll) : fn(Date.now());
        poll();
    }
    // The room has swapped in (a switch holds the room left until it has shrunk away, docs/ORBIT.md §4).
    function untilShown(page, fn) {
        const poll = () => dashboard.loadedPage !== page ? after(10, poll) : fn(Date.now());
        poll();
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        // Cues are QtObjects, so they sit in resources rather than children.
        for (const child of [...(item.children ?? []), ...(item.resources ?? [])]) {
            const found = find(child, test);
            if (found) return found;
        }
        return null;
    }
    function watch(target) {
        const w = { last: target.value, step: 0 };
        target.valueChanged.connect(() => { w.step = Math.max(w.step, Math.abs(target.value - w.last)); w.last = target.value; });
        return w;
    }
    function count(name) { return Motion.activeNames.filter(n => n === name).length; }
    // Overdrive on or off at once: the engine at its target and the ignition at rest, for the checks that
    // measure idle loops alone (docs/OVERDRIVE.md §3). The overdrive.* cases below exercise the real ramp.
    function overdrive(on) {
        Motion.overdrive = on;
        Motion.settleDrive();
        dashboard.ignition.settle();
    }
    // overdrive.guards: Motion.overdrive follows the fixture core's topic, as Overlay binds it.
    property bool coreDrives: false
    Binding { target: Motion; property: "overdrive"; value: core.overdriveData?.effective === "active"; when: root.coreDrives }
    function idleNames() { return Motion.activeNames.filter(n => n.startsWith("idle.")); }
    // Settled but for the idle loops (Overdrive's own, which run by design while it drives).
    function untilLoopsOnly(fn) {
        const poll = () => Motion.activeNames.some(n => !n.startsWith("idle.")) ? after(10, poll) : fn(Date.now());
        poll();
    }
    function cue(name) { return find(dashboard, i => i.name === name && i.value !== undefined); }

    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1120; implicitHeight: 760; visible: true
        Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
    }
    // The Overlay's unfold (view/shell/Unfold.qml), and the host profile it reads (pure data).
    Unfold { id: unfold; on: false }
    SerpantinumMotion { id: serpantinum }

    property var tests: [
        // Nine navigations within ~100 ms: each lands on its turn, one entrance at a time,
        // and everything settles within one camera travel (plus one incubation) of the last request.
        done => {
            let sameTurn = true, single = true;
            const step = i => {
                if (i === root.pages.length) {
                    const t0 = Date.now();
                    root.untilIdle(t => {
                        check("view.navigate.burst", sameTurn && single && t - t0 <= Math.max(Motion.navigate, Motion.transfer) + 50 && dashboard.loadedPage === "notifications",
                              { sameTurn: sameTurn, single: single, ms: t - t0, page: dashboard.loadedPage });
                        done();
                    });
                    return;
                }
                dashboard.navigate(root.pages[i]);
                // The page changes on the turn; its room is shown or is the one pending (never a queue).
                const page = root.pages[i];
                sameTurn = sameTurn && dashboard.currentPage === page && (dashboard.loadedPage === page || dashboard.pendingPage === page);
                single = single && root.count("shell.entrance") <= 1;
                after(11, () => step(i + 1));
            };
            step(0);
        },
        // The orbit camera (docs/ORBIT.md §4): a switch keeps the room left live while it shrinks into its tile,
        // shows the orbit with the streak crossing it, and a room chosen mid-flight retargets from where the
        // camera is (no jump, one cue). It lands with the room filling the field and the orbit gone; opening the
        // orbit zooms out to the system, Escape zooms back in.
        done => {
            root.untilIdle(() => {
                const field = root.find(dashboard, i => typeof i.fly === "function" && i.lensRect !== undefined);
                const old = dashboard.shownPageId;
                dashboard.navigate("media");
                // A switch's length follows the hop (Shell.hop): read it from the cue.
                const length = dashboard.orbitTransfer.enter;
                after(length * 0.2, () => {
                    const held = dashboard.shownPageId === old;
                    const shrinking = field.lensRect.w > 0 && field.lensRect.w < field.width;
                    after(length * 0.3, () => {
                        const orbit = dashboard.orbit;
                        const wide = orbit !== null && field.orbitCam.s < 1.2 && orbit.streak > 0 && orbit.streak < 1 && field.roomOpacity === 0;
                        const before = { x: field.orbitCam.x, y: field.orbitCam.y, s: field.orbitCam.s };
                        dashboard.navigate("devices");
                        const now = field.orbitCam;
                        const still = Math.abs(before.x - now.x) < 0.5 && Math.abs(before.y - now.y) < 0.5 && Math.abs(before.s - now.s) < 0.01;
                        const single = root.count("orbit.transfer") <= 1;
                        root.untilIdle(() => {
                            const landed = dashboard.shownPageId === "devices" && dashboard.orbit === null && !field.flying && field.lensRect.w === field.width;
                            dashboard.toggleOrbit();
                            after(Motion.zoom / 2, () => {
                                const opening = field.flying && field.lensRect.w < field.width;
                                root.untilIdle(() => {
                                    const open = dashboard.orbitOpen && dashboard.orbit !== null && field.roomOpacity === 0 && Math.abs(field.orbitCam.s - 1) < 1e-6;
                                    dashboard.escapeKey();
                                    root.untilIdle(() => {
                                        const closed = !dashboard.orbitOpen && dashboard.orbit === null && field.roomOpacity === 1 && dashboard.currentPage === "devices";
                                        check("orbit.transfer", held && shrinking && wide && still && single && landed && opening && open && closed && Motion.active === 0,
                                              { held: held, shrinking: shrinking, wide: wide, still: still, single: single, landed: landed, opening: opening, open: open, closed: closed });
                                        done();
                                    });
                                });
                            });
                        });
                    });
                });
            });
        },
        // Short hops fly faster (Shell.hop): a switch between neighbouring tiles is shorter than one across
        // the system, never under 0.55 of Motion.transfer and never over it.
        done => {
            dashboard.navigate("home");
            root.untilIdle(() => {
                dashboard.navigate("media");
                const near = dashboard.orbitTransfer.enter;
                root.untilIdle(() => {
                    const orbitTiles = ["performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications"];
                    // The farthest tile from Media, measured the way the Shell does.
                    dashboard.toggleOrbit();
                    root.untilIdle(() => {
                        const o = dashboard.orbit, m = o.rectOf("media");
                        const far = orbitTiles.reduce((a, b) => {
                            const ra = o.rectOf(a), rb = o.rectOf(b);
                            return Math.hypot(rb.x - m.x, rb.y - m.y) > Math.hypot(ra.x - m.x, ra.y - m.y) ? b : a;
                        });
                        dashboard.escapeKey();
                        root.untilIdle(() => {
                            dashboard.navigate(far);
                            const long = dashboard.orbitTransfer.enter;
                            root.untilIdle(() => {
                                const floor = Math.round(Motion.transfer * 0.55);
                                check("orbit.transfer.hop", near >= floor && near < long && long <= Motion.transfer && dashboard.shownPageId === far,
                                      { near: near, far: far, long: long, floor: floor, ceiling: Motion.transfer });
                                done();
                            });
                        });
                    });
                });
            });
        },
        // Dragging through space (docs/ORBIT.md §4): a short pull of a room follows the pointer and springs
        // back; a long pull opens the orbit there; in the orbit a pan moves the camera and stays, a release
        // with speed glides on and stops; Escape dives back into the room.
        done => {
            dashboard.navigate("tasks");
            root.untilIdle(() => {
                const field = root.find(dashboard, i => typeof i.fly === "function" && i.lensRect !== undefined);
                dashboard.orbitPan(20, 0);
                const pulled = dashboard.orbit !== null && field.lensRect.w < field.width;
                const follows = Math.abs(field.lensRect.x + field.lensRect.w / 2 - (field.width / 2 + 20)) < 1;
                dashboard.orbitRelease(0, 0);
                root.untilIdle(() => {
                    const back = !dashboard.orbitOpen && dashboard.orbit === null && field.lensRect.w === field.width;
                    for (let i = 0; i < 20; i++) dashboard.orbitPan(30, 10);
                    const far = field.pull > 0.3;
                    dashboard.orbitRelease(0, 0);
                    root.untilIdle(() => {
                        const opened = dashboard.orbitOpen && Math.abs(field.orbitCam.s - 1) < 1e-6;
                        const x0 = field.orbitCam.x;
                        dashboard.orbitPan(-100, 0);
                        const panned = Math.abs(field.orbitCam.x - (x0 + 100)) < 0.5;
                        dashboard.orbitRelease(-2000, 0);
                        const gliding = root.count("orbit.fling") === 1;
                        root.untilIdle(() => {
                            const glided = field.orbitCam.x > x0 + 120;
                            const kept = dashboard.orbitDragging && dashboard.orbitOpen;
                            dashboard.escapeKey();
                            root.untilIdle(() => {
                                const home = !dashboard.orbitOpen && dashboard.orbit === null && field.lensRect.w === field.width && dashboard.currentPage === "tasks";
                                check("orbit.drag", pulled && follows && back && far && opened && panned && gliding && glided && kept && home && Motion.active === 0,
                                      { pulled: pulled, follows: follows, back: back, far: far, opened: opened, panned: panned, gliding: gliding, glided: glided, kept: kept, home: home });
                                done();
                            });
                        });
                    });
                });
            });
        },
        // The other systems (docs/ORBIT.md §0): every room has one out in space, none overlapping another or
        // the main system; a desk switches to that workspace and a Devices moon flips its switch (the fixture's Bluetooth);
        // G frames every system and stays free; "." comes home; the zoom glides; zooming far enough into a
        // room's tile dives into that room.
        done => {
            dashboard.navigate("tasks");
            root.untilIdle(() => {
                const field = root.find(dashboard, i => typeof i.fly === "function" && i.lensRect !== undefined);
                dashboard.toggleOrbit();
                root.untilIdle(() => {
                    const orbit = dashboard.orbit;
                    const ids = orbit.rooms.map(p => p.id);
                    const eight = ids.every(id => !!orbit.systems[id]) && Object.keys(orbit.systems).length === 9;
                    const meet = (a, b) => a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;
                    const boxes = ids.map(id => orbit.systemBox(id));
                    const apart = boxes.every((a, i) => !meet(a, orbit.mainBox) && boxes.every((b, j) => i === j || !meet(a, b)));
                    const desks = orbit.deskSystem, media = orbit.mediaSystem, count = orbit.roomSystems.deskCount;
                    const deskCount = desks.moons.length === count && desks.moonTiles.count === count;
                    const active = desks.moons.filter(m => m.current).length === 1;
                    const mediaMoons = media.moons.length === 3 + (fixture.media.players ?? []).length;
                    const calls = fixture.workspaces.calls.length;
                    desks.moonTiles.itemAt(1).clicked();
                    const last = fixture.workspaces.calls[fixture.workspaces.calls.length - 1];
                    const switched = fixture.workspaces.calls.length === calls + 1 && last.method === "switchTo" && last.args[0] === "2";
                    // Bluetooth: the suite's closing check wants no power, audio or media calls at all.
                    const btCalls = fixture.bluetooth.calls.length;
                    orbit.systems.devices.moonTiles.itemAt(1).clicked();
                    const flip = fixture.bluetooth.calls[fixture.bluetooth.calls.length - 1];
                    const flipped = fixture.bluetooth.calls.length === btCalls + 1 && flip?.method === "setEnabled";
                    // The sound moons read the mixer's endpoints, so the systems hold "mixer" while open.
                    const dm = orbit.systems.devices.moons;
                    const mixer = dm[2]?.number === "40%" && dm[3]?.name === "MIC OFF";
                    // The fabric has a well for Home, each room, each sun and every moon, within its uniforms.
                    const moonCount = Object.keys(orbit.systems).reduce((a, k) => a + orbit.systems[k].moons.length, 0);
                    const wellsN = orbit.fabric.masses.length;
                    const wells = moonCount > 0 && wellsN === 1 + 2 * orbit.rooms.length + moonCount && wellsN <= orbit.fabric.wellCount;
                    orbit.galaxy();
                    root.untilIdle(() => {
                        const b = orbit.galaxyBounds(), c = field.orbitCam;
                        const framed = dashboard.orbitDragging && c.s < 0.9
                            && field.width / 2 + (b.x0 - c.x) * c.s >= orbit.systemLeft - 1 && field.width / 2 + (b.x1 - c.x) * c.s <= field.width + 1
                            && (b.y1 - b.y0) * c.s <= field.height;
                        orbit.recentre();
                        root.untilIdle(() => {
                            const home = !dashboard.orbitDragging && Math.abs(field.orbitCam.s - 1) < 1e-6;
                            orbit.zoomStep(1.5);
                            root.untilIdle(() => {
                                const glided = Math.abs(field.orbitCam.s - 1.5) < 1e-3;
                                // Into the Timers tile, from where the camera is.
                                const r = orbit.screenRect(orbit.rectOf("timers"));
                                field.orbitZoom(r.x + r.w / 2, r.y + r.h / 2, 8, true);
                                root.untilIdle(() => {
                                    const entered = dashboard.currentPage === "timers" && !dashboard.orbitOpen;
                                    root.untilShown("timers", () => root.untilIdle(() => {
                                        check("orbit.space", eight && apart && deskCount && active && mediaMoons && switched && flipped && mixer && wells && framed && home
                                              && glided && entered && dashboard.orbit === null && Motion.active === 0,
                                              { eight: eight, apart: apart, deskCount: deskCount, active: active, mediaMoons: mediaMoons, switched: switched,
                                                flipped: flipped, mixer: mixer, wells: wellsN + "/" + moonCount, framed: framed, home: home, glided: glided, entered: entered });
                                        done();
                                    }));
                                });
                            });
                        });
                    });
                });
            });
        },
        // A room loaded during the entrance continues it: no restart, no dip.
        done => {
            root.untilIdle(() => {
                dashboard.navigate("home");
                root.untilShown("home", () => after(Motion.navigate / 2, () => {
                    const entrance = root.cue("shell.entrance");
                    const mid = entrance.value;
                    // Only jumps the eye can see count: the next room's entrance starts again while it is still
                    // hidden in its tile (the flight, docs/ORBIT.md §4), which is the point of the flight.
                    const field = root.find(dashboard, i => typeof i.fly === "function" && i.lensRect !== undefined);
                    const watcher = { last: entrance.value, step: 0 };
                    entrance.valueChanged.connect(() => {
                        if (field.roomOpacity > 0) watcher.step = Math.max(watcher.step, Math.abs(entrance.value - watcher.last));
                        watcher.last = entrance.value;
                    });
                    dashboard.navigate("tasks");
                    const kept = entrance.value === mid;
                    root.untilIdle(() => {
                        check("view.entrance.interrupt", mid > 0 && mid < 1 && kept && watcher.step <= root.maxStep, { mid: mid, kept: kept, step: watcher.step });
                        done();
                    });
                }));
            });
        },
        // Reduced motion mid-entrance settles it; the next room cuts in.
        done => {
            dashboard.navigate("timers");
            after(Motion.navigate / 3, () => {
                const entrance = root.cue("shell.entrance");
                Motion.reduced = true;
                const settled = entrance.value === 1 && Motion.active === 0;
                dashboard.navigate("devices");
                const cut = entrance.value === 1 && Motion.active === 0;
                Motion.reduced = false;
                check("view.entrance.reduced", settled && cut, { settled: settled, cut: cut, active: Motion.activeNames });
                done();
            });
        },
        // The host profile replaces FART's roles field by field; FART-only motion stays.
        done => {
            const breath = Motion.breath;
            Motion.profile = ({ navigate: { duration: 400 } });
            const partial = Motion.navigate === 4000 && Motion.roles.navigate.easing === Easing.OutCubic && Motion.roles.navigate.travel === 6;
            Motion.profile = serpantinum.roles;
            const full = Motion.unfold === 10000 && Motion.fold === 1600 && Motion.navigate === 4000 && Motion.roles.navigate.axis === "y"
                && Motion.feedback === 1500 && Motion.breath === breath && unfold.spec.header.overshoot === 1.2;
            Motion.profile = ({});
            const reset = Motion.unfold === 2400 && Motion.roles.navigate.axis === "x";
            check("motion.profile", partial && full && reset, { partial: partial, full: full, reset: reset });
            done();
        },
        // Serpantinum's popup intro: body first, then the header, then the room; closing
        // retraces it within one fold, room first, without a jump.
        done => {
            Motion.profile = serpantinum.roles;
            unfold.on = true;
            after(Motion.unfold * 0.15, () => {
                const order = unfold.body.value > unfold.header.value && unfold.header.value > 0 && unfold.room.value === 0;
                after(Motion.unfold * 0.9, () => {
                    const opened = unfold.value === 1 && unfold.body.value === 1 && unfold.room.value === 1;
                    let roomZero = 0, bodyZero = 0;
                    const w = root.watch(unfold);
                    const r0 = Date.now();
                    unfold.on = false;
                    const poll = () => {
                        if (!roomZero && unfold.room.value === 0) roomZero = Date.now();
                        if (!bodyZero && unfold.body.value === 0) bodyZero = Date.now();
                        if (unfold.running) { after(5, poll); return; }
                        const ms = Date.now() - r0;
                        Motion.profile = ({});
                        check("overlay.unfold.stagger", order && opened && roomZero > 0 && roomZero <= bodyZero && root.within(ms, 1600) && w.step <= root.maxStep,
                              { order: order, opened: opened, leave: bodyZero - roomZero, ms: ms, step: w.step });
                        done();
                    };
                    poll();
                });
            });
        },
        // Overlay unfold: open/close five times within 100 ms; the final state wins at once
        // and settles within one fold; reversal mid-unfold takes the time covered.
        done => {
            const commands = [true, false, true, false, true, false, true, false, true, false];
            let i = 0;
            const send = () => {
                unfold.on = commands[i++];
                if (i < commands.length) { after(10, send); return; }
                const t0 = Date.now();
                root.untilStopped(unfold, t => {
                    check("overlay.unfold.burst", unfold.value === 0 && t - t0 <= Motion.fold + 50, { value: unfold.value, ms: t - t0 });
                    unfold.on = true;
                    after(Motion.unfold / 2, () => {
                        const reached = unfold.value;
                        const r0 = Date.now();
                        const w = root.watch(unfold);
                        unfold.on = false;
                        root.untilStopped(unfold, t2 => {
                            check("overlay.unfold.reverse", w.step <= root.maxStep && root.within(t2 - r0, Motion.fold * reached),
                                  { reached: reached, ms: t2 - r0, expected: Motion.fold * reached, step: w.step });
                            done();
                        });
                    });
                });
            };
            send();
        },
        // Calendar: five week shifts in 100 ms move the week at once, with one swap cue.
        done => {
            dashboard.navigate("home");
            root.untilIdle(() => {
                const calendar = root.find(dashboard, i => typeof i.shiftWeek === "function");
                const start = calendar.week;
                const weeks = () => Math.round((calendar.week - start) / (7 * 86400000));
                let immediate = true, single = true;
                const shift = n => {
                    if (n === 5) {
                        const moved = weeks();
                        root.untilIdle(() => {
                            check("calendar.shift.burst", immediate && single && moved === 5, { immediate: immediate, single: single, weeks: moved });
                            done();
                        });
                        return;
                    }
                    const before = weeks();
                    calendar.shiftWeek(1);
                    immediate = immediate && weeks() === before + 1;
                    single = single && root.count("calendar.swap") <= 1;
                    after(20, () => shift(n + 1));
                };
                shift(0);
            });
        },
        // Halo: a chosen satellite takes the centre at once; only it and the old centre trade places,
        // through one swap cue; a burst of choices settles with a permutation of the slots.
        done => {
            dashboard.navigate("performance");
            root.untilIdle(() => {
                const halo = root.find(dashboard, i => typeof i.select === "function" && i.slots !== undefined);
                const before = halo.slots.slice();
                const from = halo.currentIndex;
                halo.select(2);
                const immediate = halo.currentIndex === 2;
                const single = root.count("halo.swap") === 1;
                const traded = halo.slots[2] === -1 && halo.slots[from] === before[2]
                    && before.every((slot, i) => i === 2 || i === from || halo.slots[i] === slot);
                root.untilIdle(() => {
                    const settled = halo.incoming === -1 && halo.outgoing === -1;
                    // The keyboard stays in place: the old centre, now in the chosen slot, takes the focus.
                    const satellite = n => root.find(halo, i => i.entry !== undefined && i.index === n);
                    const held = halo.currentIndex;
                    satellite(3).forceActiveFocus();
                    halo.select(3);
                    const focusKept = satellite(held).activeFocus === true;
                    [1, 3, 4, 0].forEach((n, k) => after(k * 10, () => halo.select(n)));
                    after(60, () => root.untilIdle(() => {
                        const sorted = halo.slots.slice().sort((a, b) => a - b);
                        const permutation = JSON.stringify(sorted) === JSON.stringify([-1, 0, 1, 2, 3]) && halo.slots[0] === -1;
                        check("halo.swap", immediate && single && traded && settled && focusKept && permutation && Motion.active === 0,
                              { immediate: immediate, single: single, traded: traded, settled: settled, focusKept: focusKept, slots: halo.slots, active: Motion.activeNames });
                        done();
                    }));
                });
            });
        },
        // A control clicked during the entrance acts on the same turn.
        done => {
            dashboard.navigate("media");
            root.untilShown("media", () => after(Motion.navigate / 4, () => {
                const inFlight = root.count("shell.entrance") === 1;
                const button = root.find(dashboard, i => i.label === "Lyrics" && typeof i.clicked === "function");
                const before = button.selected;
                button.clicked();
                const acted = button.selected !== before;
                button.clicked();
                check("view.click.during.entrance", inFlight && acted, { inFlight: inFlight, acted: acted });
                root.untilIdle(done);
            }));
        },
        // A button's wipe retargets on every state change; the last state wins.
        done => {
            const button = root.find(dashboard, i => i.label === "Lyrics" && typeof i.clicked === "function");
            for (let i = 0; i < 10; i++) after(i * 16, () => { button.selected = !button.selected; });
            after(16 * 10 + Motion.feedback * 1.5, () => {
                const expected = button.selected || button.hovered ? 1 : 0;
                check("button.fill.retarget", Math.abs(button.wipeProgress - expected) < 0.001, { wipe: button.wipeProgress, expected: expected });
                button.selected = false;
                done();
            });
        },
        // The creature's press: retrigger while it springs back rises again, without a jump.
        done => {
            dashboard.navigate("tasks");
            root.untilIdle(() => {
                const creature = root.find(dashboard, i => typeof i.discovered === "function" && i.progress !== undefined);
                const pulse = root.find(creature, i => i.name === "creature.press");
                const w = root.watch(pulse);
                pulse.trigger();
                after(Motion.feedback + Motion.navigate / 2, () => {
                    const falling = !pulse.rising && pulse.running;
                    pulse.trigger();
                    const rising = pulse.rising;
                    root.untilStopped(pulse, () => {
                        check("creature.press.retrigger", falling && rising && w.step <= root.maxStep && pulse.value === 0, { falling: falling, rising: rising, step: w.step });
                        done();
                    });
                });
            });
        },
        // Idle: every room settles to zero running animations with the fixture paused.
        done => {
            let busy = [];
            const visit = i => {
                if (i === root.pages.length) {
                    check("view.idle.rooms", busy.length === 0, busy);
                    done();
                    return;
                }
                dashboard.navigate(root.pages[i]);
                after(Math.max(Motion.navigate, Motion.transfer) + 300, () => {
                    if (Motion.active !== 0) busy.push([root.pages[i], Motion.activeNames]);
                    visit(i + 1);
                });
            };
            visit(0);
        },
        // Idle life (MONTAGE.md §4.5): with ambient detail on, the shown room's loops run while visible and
        // all stop when the window hides; with it off, none run.
        done => {
            dashboard.navigate("home");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                after(100, () => {
                    // Cut (8 November 2026): without Overdrive nothing idles, even with ambient detail on.
                    const cut = Motion.active;
                    root.overdrive(true);
                after(100, () => {
                    const idle = Motion.activeNames.filter(n => n.startsWith("idle."));
                    window.visible = false;
                    after(100, () => {
                        const hidden = Motion.active;
                        window.visible = true;
                        ViewState.ambientEnabled = false;
                        after(100, () => {
                            root.overdrive(false);
                            check("view.idle.ambient", cut === 0 && idle.includes("idle.field.scan") && idle.includes("idle.field.motes") && idle.includes("idle.home.clock") && hidden === 0 && Motion.activeNames.filter(n => n.startsWith("idle.")).length === 0,
                                  { cut: cut, idle: idle, hidden: hidden, off: Motion.activeNames });
                            done();
                        });
                    });
                });
                });
            });
        },
        // The astronomical clock (HomeSky, M10): Silent draws the sky as it is now and nothing moves; Overdrive runs
        // the day as a time-lapse (the sun leaves its now-place); releasing it stops the loop and puts every body
        // back; under reduced motion nothing runs even in Overdrive. No core here, so the sky is a small fixture.
        done => {
            dashboard.navigate("home");
            root.untilIdle(() => {
                const sky = root.find(dashboard, i => i.hasOwnProperty("lapse") && i.hasOwnProperty("tracks"));
                if (!sky) { check("home.sky", false, "no HomeSky"); done(); return; }
                sky.sky = { place: { lat: 51.5, lon: 0, name: "Fixture", source: "host" },
                            moon: { illumination: 0.5, waxing: true, phase: "first quarter" }, next: [], sun: {},
                            bodies: { sun: { azimuth: 180, altitude: 20 }, moon: { azimuth: 100, altitude: 10 } },
                            tracks: { from: -12, to: 12, step: 360, paths: {
                                sun: [[0, -60], [90, -10], [180, 20], [270, -10], [0, -60]],
                                moon: [[280, -40], [10, -20], [100, 10], [190, 30], [280, -5]] } } };
                const sunMark = root.find(sky, i => i.modelData === "sun" && i.hasOwnProperty("place"));
                ViewState.ambientEnabled = true;
                after(100, () => {
                    const silent = { idle: Motion.activeNames.filter(n => n === "idle.home.sky"), lapse: sky.lapse, x: sunMark.x };
                    const centre = sky.point(180, 20).x - sunMark.size / 2;
                    root.overdrive(true);
                    after(400, () => {
                        const lit = { idle: Motion.activeNames.filter(n => n === "idle.home.sky"), lapse: sky.lapse, x: sunMark.x,
                                      stratum: Strata.live.includes("panel:home.sky") };
                        root.overdrive(false);
                        after(100, () => {
                            const released = { idle: Motion.activeNames.filter(n => n === "idle.home.sky"), lapse: sky.lapse, x: sunMark.x,
                                               stratum: Strata.live.includes("panel:home.sky") };
                            Motion.reduced = true;
                            root.overdrive(true);
                            after(100, () => {
                                const reduced = Motion.activeNames.filter(n => n === "idle.home.sky");
                                root.overdrive(false);
                                Motion.reduced = false;
                                ViewState.ambientEnabled = false;
                                sky.sky = null;
                                root.untilIdle(() => {
                                    check("home.sky", silent.idle.length === 0 && silent.lapse === 0 && Math.abs(silent.x - centre) < 1
                                          && lit.idle.length === 1 && lit.lapse !== 0 && Math.abs(lit.x - centre) > 1 && lit.stratum
                                          && released.idle.length === 0 && released.lapse === 0 && Math.abs(released.x - centre) < 1 && !released.stratum
                                          && reduced.length === 0,
                                          { silent: silent, lit: lit, released: released, reduced: reduced, centre: centre });
                                    done();
                                });
                            });
                        });
                    });
                });
            });
        },
        // The telemetry orrery (M12, OrreryField): nothing in Silent; in Overdrive a busy body turns and an idle one
        // stands still, a born one falls in from outside, an ended one leaves its ring and forks rain in; a release
        // destroys it and its clock, and under reduced motion it never exists. No core here, so samples are injected.
        done => {
            dashboard.navigate("performance");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                const live = () => Strata.live.includes("panel:performance.orrery");
                const silent = { stratum: live(), loop: root.count("idle.performance.orrery") };
                root.overdrive(true);
                const field = () => root.find(dashboard, i => i.hasOwnProperty("orbits") && i.hasOwnProperty("ingest"));
                const poll = () => field() ? lit() : after(10, poll);
                const body = (f, id) => root.find(f, i => i.hasOwnProperty("theta") && i.b?.id === id);
                const b = (id, cpu, born) => ({ id: id, pid: 1, name: id, cpu: cpu, rss: 300, growth: 0, age: born ? 0.5 : 900, born: born });
                const lit = () => {
                    const f = field();
                    f.asking = false;
                    f.ingest({ running: true, warm: true, at: 1, forks: 0, exits: [], total: { cpu: 100, rss: 600, count: 2 },
                               bodies: [b("busy", 100, false), b("idle", 0, false)] });
                    const t0 = { busy: body(f, "busy").theta, idle: body(f, "idle").theta };
                    f.ingest({ running: true, warm: true, at: 2, forks: 5, exits: [], total: { cpu: 100, rss: 900, count: 3 },
                               bodies: [b("busy", 100, false), b("idle", 0, false), b("fresh", 0, true)] });
                    const born = { alt: body(f, "fresh").alt, target: body(f, "fresh").b.alt };
                    after(500, () => {
                        const moved = { busy: body(f, "busy").theta - t0.busy, idle: body(f, "idle").theta - t0.idle,
                                        loop: root.count("idle.performance.orrery"), stratum: live(), meteors: f.orbits.meteors.length };
                        f.ingest({ running: true, warm: true, at: 3, forks: 0, exits: [{ id: "busy", name: "busy" }],
                                   total: { cpu: 0, rss: 600, count: 2 }, bodies: [b("idle", 0, false), b("fresh", 0, false)] });
                        const ended = { rings: f.orbits.rings.map(r => r.name), busy: !!body(f, "busy") };
                        root.overdrive(false);
                        after(100, () => {
                            const released = { stratum: live(), loop: root.count("idle.performance.orrery"), field: !!field() };
                            Motion.reduced = true;
                            root.overdrive(true);
                            after(200, () => {
                                const reduced = { stratum: live(), field: !!field() };
                                root.overdrive(false);
                                Motion.reduced = false;
                                ViewState.ambientEnabled = false;
                                root.untilIdle(() => {
                                    check("performance.orrery", !silent.stratum && silent.loop === 0
                                          && moved.stratum && moved.loop === 1 && moved.busy > 0.2 && moved.idle === 0 && moved.meteors === 5
                                          && born.alt > 1.5 && born.target < 1.2
                                          && ended.rings.length === 1 && ended.rings[0] === "busy" && !ended.busy
                                          && !released.stratum && released.loop === 0 && !released.field
                                          && !reduced.stratum && !reduced.field,
                                          { silent: silent, moved: moved, born: born, ended: ended, released: released, reduced: reduced });
                                    done();
                                });
                            });
                        });
                    });
                };
                poll();
            });
        },
        // The heat's scale (docs/OVERDRIVE.md §8): it differs between what Home and the orbit really cost, and doesn't peg.
        done => {
            const heat = Qt.createQmlObject("import qs.view.overdrive; Heat {}", root);
            const home = heat.level(30.6), orbit = heat.level(135.5);
            check("heat.scale", heat.level(0) === 0 && heat.level(500) === 1 && home > 0.2 && home < 0.5 && orbit > 0.9 && orbit < 1,
                  { home: home, orbit: orbit });
            heat.destroy();
            done();
        },
        // The contact sheet (M14): every desk in use, the current one and the first free one; outlines in Silent; a drag sends the
        // window and a same-desk drop does nothing; the shared fixture has desks 1 and 3, so 2 is the free one.
        done => {
            const before = fixture.workspaces.calls.length;
            dashboard.sheetOpen = true;
            after(150, () => {
                const sheet = dashboard.sheet;
                sheet.shell = null;
                const desks = JSON.stringify(sheet.desks);
                const window = sheet.windows[0];
                const stayed = sheet.sendTo(window, window.workspaceId) === false;
                sheet.sendTo(window, "2");
                sheet.go("3");
                sheet.cursor = 0;
                sheet.walk("right");
                const walked = sheet.cursor === 1;
                const calls = fixture.workspaces.calls.slice(before);
                const outline = !sheet.capturing && sheet.windows.length === 4;
                dashboard.closeSheet();
                after(50, () => {
                    check("desks.sheet", desks === '["1","2","3"]' && stayed && walked && outline && dashboard.sheet === null
                          && calls.length === 2 && calls[0].method === "moveWindow" && calls[0].args[1] === "2" && calls[1].method === "switchTo" && calls[1].args[0] === "3",
                          { desks: desks, stayed: stayed, walked: walked, outline: outline, calls: calls });
                    done();
                });
            });
        },
        // Quiet telemetry's sounds can be looked up afterwards (core/quiet.py): only an audible one of its own is kept.
        done => {
            const lease = dashboard.lease;
            core.cue({ cue: "ui.click", audible: true, at: 1 });
            const other = lease.heard;
            core.cue({ cue: "quiet.burst", audible: false, at: 2 });
            const unheard = lease.heard;
            core.cue({ cue: "quiet.burst", audible: true, at: 3 });
            check("quiet.heard", other === null && unheard === null && lease.heard?.cue === "quiet.burst" && lease.heard?.at === 3,
                  { other: other, unheard: unheard, heard: lease.heard });
            lease.heard = null;
            done();
        },
        // The clock occultation in the real header (atlas #51, docs/OVERDRIVE.md §50): a countdown's end in Overdrive splits
        // the clock with Timers' number; a release clears it.
        done => {
            const clock = dashboard.headerClock;
            core.cue({ cue: "timer.done", audible: false, at: 4 });
            const silent = clock ? clock.event : "missing";
            root.overdrive(true);
            core.cue({ cue: "timer.done", audible: false, at: 5 });
            after(500, () => {
                const split = clock?.plane === "split" && clock.open > 0.9 && clock.event.room === dashboard.navigationPages.findIndex(p => p.id === "timers");
                root.overdrive(false);
                after(50, () => {
                    check("clock.occultation", silent === null && split && clock.event === null && clock.plane === "",
                          { silent: silent, plane: clock?.plane, event: clock?.event });
                    done();
                });
            });
        },
        // The archive match cut in the real Shell (atlas #40, docs/OVERDRIVE.md §51): closing the archive in Overdrive runs
        // the cut exactly when an archive label on screen holds the shown room's number, and closes the archive either way.
        done => {
            root.overdrive(true);
            dashboard.archiveOpen = true;
            after(900, () => {
                const stratum = find(dashboard, i => i.name === "archive.matchcut" && i.sourceComponent !== undefined);
                const archive = find(dashboard, i => typeof i.closeRequested === "function" && i.spans !== undefined);
                const number = String(Math.max(0, dashboard.navigationPages.findIndex(p => p.id === dashboard.shownPageId))).padStart(2, "0");
                const expected = !!(stratum?.item && archive && stratum.item.pivotIn(archive, number));
                archive?.closeRequested();
                const running = stratum?.item?.running ?? false;
                after(1000, () => {
                    const after1 = stratum?.item?.running ?? false;
                    root.overdrive(false);
                    after(50, () => {
                        check("archive.matchcut", !!stratum && !!archive && !dashboard.archiveOpen && running === expected && !after1,
                              { stratum: !!stratum, archive: !!archive, expected: expected, running: running, number: number });
                        done();
                    });
                });
            });
        },
        // The orbit at rest (docs/ORBIT.md §6): in Overdrive with ambient detail on, once the orbit has opened only
        // its own three loops run (the drift, the bob and the stars' twinkle, docs/OVERDRIVE.md §5), the header's
        // heat shimmer (§8) and the surveyor on the footer rule (§7); the hidden room's stop, and closing the orbit
        // brings the room's back.
        done => {
            dashboard.navigate("home");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                root.overdrive(true);
                dashboard.toggleOrbit();
                root.untilStopped(root.cue("orbit.transfer"), () => {
                    after(100, () => {
                        const open = Motion.activeNames.slice();
                        const built = dashboard.orbit !== null;
                        dashboard.toggleOrbit();
                        root.untilStopped(root.cue("orbit.transfer"), () => {
                            after(100, () => {
                                const back = Motion.activeNames.filter(n => n.startsWith("idle."));
                                ViewState.ambientEnabled = false;
                                root.overdrive(false);
                                root.untilIdle(() => {
                                    check("orbit.rest", built && JSON.stringify(open.sort()) === JSON.stringify(["idle.heat", "idle.orbit.bob", "idle.orbit.drift", "idle.orbit.twinkle", "idle.surveyor"]) && back.includes("idle.field.scan") && dashboard.orbit === null,
                                          { open: open, back: back, built: built });
                                    done();
                                });
                            });
                        });
                    });
                });
            });
        },
        // Media while playing: exactly the breathing dot and the cat (D12's ≤ 2); hidden, nothing. In Overdrive, kinetic
        // lyrics (docs/OVERDRIVE.md §6) with the Lyrics switch left off (Overdrive brings the words itself): the words on
        // the room's stage (its own frame clock), the title on the wedge; paused, neither exists (M9: no stratum when
        // paused, hidden or in Silent); and the switch is still off afterwards.
        done => {
            const paused = fixture.media.active;
            fixture.media.active = Object.assign({}, paused, { playing: true });
            fixture.media.players = [fixture.media.active];
            ViewState.ambientEnabled = true;
            dashboard.navigate("media");
            after(Math.max(Motion.navigate, Motion.transfer) + 300, () => {
                const room = root.find(dashboard, i => i.hasOwnProperty("lyricsReady") && i.hasOwnProperty("visualising"));
                const switchBefore = room.lyrics;
            root.untilIdle(() => {
                const cut = Motion.activeNames.slice();
                const silentStage = Strata.live.includes("panel:lyrics.stage");
                root.overdrive(true);
            after(300, () => {
                const lyrics = Strata.live.includes("panel:lyrics") && Strata.live.includes("panel:lyrics.stage") && Motion.activeNames.includes("lyrics.stage");
                const names = Motion.activeNames.filter(n => !n.startsWith("idle.") && !n.startsWith("lyrics.")).sort();
                fixture.media.active = Object.assign({}, paused, { playing: false });
                fixture.media.players = [fixture.media.active];
            after(100, () => {
                const stopped = !Strata.live.includes("panel:lyrics.stage") && !Strata.live.includes("panel:lyrics");
                fixture.media.active = Object.assign({}, paused, { playing: true });
                fixture.media.players = [fixture.media.active];
                root.overdrive(false);
                ViewState.ambientEnabled = false;
                window.visible = false;
                after(100, () => {
                    const hidden = Motion.active;
                    const switchAfter = room.lyrics;
                    window.visible = true;
                    fixture.media.active = paused;
                    fixture.media.players = [paused];
                    root.untilIdle(() => {
                        check("view.idle.playing", cut.length === 0 && !silentStage && lyrics && stopped && !switchBefore && !switchAfter && JSON.stringify(names) === JSON.stringify(["media.cat", "status.breath"]) && hidden === 0 && Motion.active === 0 && Strata.count === 0,
                              { cut: cut, silentStage: silentStage, lyrics: lyrics, stopped: stopped, switchBefore: switchBefore, switchAfter: switchAfter, names: names, hidden: hidden, after: Motion.activeNames, strata: Strata.live });
                        done();
                    });
                });
            });
            });
            });
            });
        },
        // The orbit alive (docs/OVERDRIVE.md §5): in Overdrive the tiles drift (the inner orbit faster, as Kepler has
        // it) and the systems bob; a release winds the engine down and every tile and system is back at its stored
        // place, with nothing running and no eclipse.
        done => {
            Motion.timeScale = 1;
            dashboard.navigate("home");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                root.overdrive(true);
                dashboard.toggleOrbit();
                root.untilStopped(root.cue("orbit.transfer"), () => {
                    const o = dashboard.orbit;
                    after(1500, () => {
                        const moved = o.rooms.map((p, k) => o.driftOf(k));
                        const inner = Math.abs(moved[0]), far = Math.abs(moved[moved.length - 1]);
                        const bob = o.rooms.filter(p => Math.abs(o.systemBob(p.id)) > 0).length, rooms = o.rooms.length;
                        const loops = root.idleNames().sort();
                        Motion.overdrive = false;
                        root.untilIdle(() => {
                            const back = o.rooms.every((p, k) => o.driftOf(k) === 0) && o.rooms.every(p => o.systemBob(p.id) === 0 && o.moonSpin(p.id) === 0);
                            const rest = { eclipse: o.eclipse, active: Motion.activeNames.slice(), loops: Motion.idleLoops };
                            dashboard.toggleOrbit();
                            root.untilStopped(root.cue("orbit.transfer"), () => {
                                ViewState.ambientEnabled = false;
                                Motion.timeScale = 10;
                                check("orbit.alive", inner > 0 && inner > far && bob === rooms && loops.includes("idle.orbit.drift") && loops.includes("idle.orbit.bob")
                                      && back && rest.eclipse === 0 && rest.active.length === 0 && rest.loops === 0,
                                      { moved: moved, bob: bob, loops: loops, back: back, rest: rest });
                                done();
                            });
                        });
                    });
                });
            });
        },
        // The orbit's laws (OrbitLaws, OVERDRIVE_IDEAS.md): in Silent a history changes nothing; in Overdrive a pair grows
        // a shelf and a route and bends its stalks, the room you live in stops drifting, a loop locks into line, Home
        // shifts towards your time, a focus move tints the tiles, E unfolds a day; a release undoes all of it.
        done => {
            Motion.timeScale = 1;
            dashboard.navigate("home");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                const day = Array.from({ length: 24 }, (_, h) => h === 10 ? 1 : 0.2);
                core.journeyData = { pairs: [{ a: "tasks", b: "timers", weight: 12 }, { a: "media", b: "devices", weight: 1 }], favourite: "tasks",
                                     trend: { media: 1, devices: -1 }, seconds: { tasks: 1000, media: 10 }, visits: { tasks: 9 }, hours: { tasks: day }, hour: 10,
                                     resonance: ["media", "tasks", "timers"] };
                dashboard.toggleOrbit();
                root.untilStopped(root.cue("orbit.transfer"), () => {
                    const o = dashboard.orbit;
                    const silent = { laws: o.laws, drift: o.rooms.every((p, k) => o.driftOf(k) === 0), home: o.homePoint.x };
                    root.overdrive(true);
                    const deadline = Date.now() + 5000;
                    const poll = () => {
                        if (!o.laws && Date.now() < deadline) { after(30, poll); return; }
                        after(300, () => {
                            const laws = o.laws;
                            const idx = id => o.rooms.findIndex(p => p.id === id);
                            const tasks = idx("tasks"), media = idx("media");
                            const seen = { strata: Strata.live.includes("panel:laws"), shelves: laws.shelves.length, routes: laws.routes.length,
                                           locked: laws.isLocked(tasks), proper: laws.properOf(media), pull: laws.pullOf(tasks).x !== 0 || laws.pullOf(tasks).y !== 0,
                                           bary: o.homePoint.x !== silent.home, lock: root.cue("orbit.resonance").on, masses: laws.fabricMasses.length };
                            o.focusIndex = (o.focusIndex + 3) % o.pages.length;
                            const shifted = laws.shifts.some(v => v !== 0);
                            laws.hold("tasks");
                            after(450, () => {
                                const folded = root.cue("orbit.ephemeris").value > 0.5;
                                laws.letGo();
                                Motion.overdrive = false;
                                root.untilIdle(() => {
                                    const back = !o.laws && o.rooms.every((p, k) => o.driftOf(k) === 0) && o.homePoint.x === silent.home && !Strata.live.includes("panel:laws");
                                    core.journeyData = null;
                                    dashboard.toggleOrbit();
                                    root.untilStopped(root.cue("orbit.transfer"), () => {
                                        ViewState.ambientEnabled = false;
                                        Motion.timeScale = 10;
                                        check("orbit.laws", silent.laws === null && silent.drift && seen.strata && seen.shelves === 1 && seen.routes === 1 && seen.locked
                                              && seen.proper > 0 && seen.pull && seen.bary && seen.lock && seen.masses === 1 && shifted && folded && back,
                                              { silent: silent.drift, seen: seen, shifted: shifted, folded: folded, back: back });
                                        done();
                                    });
                                });
                            });
                        });
                    };
                    poll();
                });
            });
        },
        // Rooms as a language (OVERDRIVE_IDEAS.md #59–61): a chord opens the plane of that pair and an unknown pair says so,
        // a quick stroke along the ruler goes to its station and a slow one doesn't, and the command line's candidates
        // fly out as a ray. Nothing here acts on the host unless a button is clicked (CUE_CALLS stays zero).
        done => {
            Motion.timeScale = 1;
            dashboard.navigate("home");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                root.overdrive(true);
                dashboard.toggleOrbit();
                root.untilStopped(root.cue("orbit.transfer"), () => {
                    const o = dashboard.orbit;
                    o.chordPair = ["timers", "tasks"];
                    after(400, () => {
                        const plane = root.find(o, i => i.grammar !== undefined && i.pair !== undefined);
                        const known = { strata: Strata.live.includes("panel:chord"), title: plane?.entry?.title };
                        o.chordPair = ["clipboard", "workspaces"];
                        after(60, () => {
                            const unknown = plane?.entry === null;
                            o.chordPair = [];
                            dashboard.toggleOrbit();
                            root.untilStopped(root.cue("orbit.transfer"), () => {
                                after(200, () => {
                                    const ruler = root.find(dashboard, i => i.ruleY !== undefined && i.rooms !== undefined);
                                    const slow = () => { ruler.points = [Qt.point(10, 44), Qt.point(ruler.width - 20, 44)]; ruler.started = Date.now() - 2000; ruler.finish(); };
                                    slow();
                                    const stayed = dashboard.currentPage === "home";
                                    ruler.points = [Qt.point(10, 44), Qt.point(ruler.width * 0.5, 44)];
                                    ruler.started = Date.now();
                                    ruler.finish();
                                    const went = dashboard.currentPage === root.pages[ruler.station(ruler.width * 0.5)];
                                    const reading = ruler.reading;
                                    dashboard.navigate("home");
                                    dashboard.commandLine.hint = { candidates: [{ name: "alpha" }, { name: "beta" }] };
                                    dashboard.focusCommandLine();
                                    after(400, () => {
                                        const ray = root.find(dashboard, i => i.reach !== undefined && i.candidates !== undefined);
                                        const flying = { strata: Strata.live.includes("panel:ballistic"), n: ray?.candidates?.length ?? 0 };
                                        dashboard.commandLine.hint = null;
                                        root.overdrive(false);
                                        ViewState.ambientEnabled = false;
                                        Motion.timeScale = 10;
                                        root.untilIdle(() => {
                                            check("overdrive.language", known.strata && known.title === "WORK THE NEXT TASK" && unknown && stayed && went && reading !== "" && flying.strata && flying.n === 2,
                                                  { known: known, unknown: unknown, stayed: stayed, went: went, reading: reading, flying: flying });
                                            done();
                                        });
                                    });
                                });
                            });
                        });
                    });
                });
            });
        },
        // M8 (docs/OVERDRIVE.md §2–4): the lease turning active ignites (the jolt and one flash; the GPU shockwave is
        // wanted but, under the software renderer, never loads), the engine spins up, the idle loops run; a release
        // winds the engine down with the loops still turning, and at rest nothing runs and no stratum exists.
        done => {
            Motion.timeScale = 1;
            dashboard.navigate("home");
            root.untilIdle(() => {
                ViewState.ambientEnabled = true;
                Motion.overdrive = true;
                after(40, () => {
                    const lit = { jolt: root.count("overdrive.jolt"), flash: root.count("overdrive.flash"), drive: Motion.drive,
                                  spinning: root.count("overdrive.drive"), loops: root.idleNames().length, waving: dashboard.ignition.waving,
                                  strata: Strata.live.slice(), chip: dashboard.headerChip.state };
                    root.untilLoopsOnly(() => {
                        const full = Motion.drive === 1 && Motion.engaged;
                        Motion.overdrive = false;
                        after(Motion.spinDown / 2, () => {
                            const mid = { drive: Motion.drive, engaged: Motion.engaged, loops: root.idleNames().length, chip: dashboard.headerChip.state };
                            root.untilIdle(() => {
                                const rest = { drive: Motion.drive, engaged: Motion.engaged, loops: Motion.idleLoops, strata: Strata.count, active: Motion.activeNames };
                                ViewState.ambientEnabled = false;
                                Motion.timeScale = 10;
                                check("overdrive.ignite.release",
                                      lit.jolt === 1 && lit.flash === 1 && lit.spinning === 1 && lit.drive > 0 && lit.drive < 1 && lit.loops > 0 && lit.waving
                                      && !lit.strata.includes("panel:shockwave") && full
                                      && mid.drive > 0 && mid.drive < 1 && mid.engaged && mid.loops > 0 && mid.chip === "SPINNING DOWN"
                                      && rest.drive === 0 && !rest.engaged && rest.loops === 0 && rest.strata === 0 && rest.active.length === 0,
                                      { lit: lit, full: full, mid: mid, rest: rest });
                                done();
                            });
                        });
                    });
                });
            });
        },
        // The guards, fixture-driven (M8): an active lease drives; a guard suspending it is Silent (the engine winds
        // down to rest) and the header says why; the guard clearing resumes it; reduced motion with the lease held
        // keeps everything still; released, the chip reads SILENT. The countdown's clock formats as m:ss or h:mm:ss.
        done => {
            Motion.timeScale = 1;
            ViewState.ambientEnabled = true;
            root.coreDrives = true;
            const guards = { dgpu: "available", fullscreen: "available", battery: "available", session: "available" };
            core.overdriveData = { requested: { mode: "sticky", until: null }, effective: "active", reasons: [], guards: guards };
            after(40, () => {
                const on = { driving: Motion.driving, chip: dashboard.headerChip.state };
                core.overdriveData = { requested: { mode: "sticky", until: null }, effective: "suspended", reasons: ["battery"], guards: guards };
                after(40, () => {
                    const suspended = { driving: Motion.driving, chip: dashboard.headerChip.state, reason: dashboard.lease.reason() };
                    root.untilIdle(() => {
                        const silent = { drive: Motion.drive, loops: Motion.idleLoops, strata: Strata.count };
                        core.overdriveData = { requested: { mode: "sticky", until: null }, effective: "active", reasons: [], guards: guards };
                        after(40, () => {
                            const resumed = Motion.driving && root.count("overdrive.jolt") === 1;
                            Motion.reduced = true;
                            after(40, () => {
                                const reduced = { driving: Motion.driving, drive: Motion.drive, loops: Motion.idleLoops, chip: dashboard.headerChip.state, active: Motion.activeNames.slice() };
                                Motion.reduced = false;
                                core.overdriveData = { requested: { mode: "off", until: null }, effective: "off", reasons: [], guards: guards };
                                root.untilIdle(() => {
                                    const off = { chip: dashboard.headerChip.state, drive: Motion.drive };
                                    root.coreDrives = false;
                                    ViewState.ambientEnabled = false;
                                    Motion.timeScale = 10;
                                    const clocks = [dashboard.headerChip.clock(65000), dashboard.headerChip.clock(3725000)];
                                    check("overdrive.guards",
                                          on.driving && on.chip === "OVERDRIVE · STICKY"
                                          && !suspended.driving && suspended.chip === "SUSPENDED · ON BATTERY" && suspended.reason === "on battery"
                                          && silent.drive === 0 && silent.loops === 0 && silent.strata === 0 && resumed
                                          && !reduced.driving && reduced.drive === 0 && reduced.loops === 0 && reduced.chip === "OVERDRIVE · REDUCED MOTION" && reduced.active.length === 0
                                          && off.chip === "SILENT" && off.drive === 0 && clocks[0] === "01:05" && clocks[1] === "1:02:05",
                                          { on: on, suspended: suspended, silent: silent, resumed: resumed, reduced: reduced, off: off, clocks: clocks });
                                    done();
                                });
                            });
                        });
                    });
                });
            });
        }
    ]
    // FART_VIEWTEST_FROM=n starts at case n (0-based), to iterate on the last cases without the whole walk.
    property int index: Number(Quickshell.env("FART_VIEWTEST_FROM") || 0) - 1
    function next() {
        index++;
        if (index >= tests.length) {
            after(50, () => {
                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                console.log("CUE_CALLS", JSON.stringify([fixture.media, fixture.audio, fixture.hostActions, fixture.power].map(d => d.calls.length)));
                console.log("CUE_DONE");
                Qt.quit();
            });
            return;
        }
        tests[index](() => after(20, next));
    }
    Component.onCompleted: {
        // Idle loops run at rest by design; the cue checks below measure cues alone, and view.idle.ambient
        // turns ambient detail on for its own check.
        ViewState.ambientEnabled = false;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
        Motion.timeScale = 10;
        after(500, next);
    }
}
