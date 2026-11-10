import QtQuick
import Quickshell
import qs.view.cues

// The command line end to end (DAILY_DRIVER §7, "Verbs" and "Queued input"): the real core and
// grammar, and the desktop fixture view (FixtureView.qml, the same PanelBody as Overlay) offscreen.
// The first open starts a self-driving scenario; each check prints CMD_PASS or CMD_FAIL, then CMD_DONE.
// Keys are the command line's own handlers (run, cancel, older, newer, complete, typeIn): offscreen
// Qt has no keyboard, so the Keys → handler mapping is covered by the desktop check instead.
ShellRoot {
    id: root
    property bool started: false
    property var steps: []
    readonly property var line: view.body.shell?.commandLine ?? null
    function check(name, ok, detail) { ok ? console.log("CMD_PASS", name) : console.log("CMD_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    // Polls `test` every 10 ms; `fn(true)` once it holds, `fn(false)` after `ms`.
    function until(test, ms, fn) {
        const deadline = Date.now() + ms;
        const poll = () => test() ? fn(true) : Date.now() > deadline ? fn(false) : after(10, poll);
        poll();
    }
    function next() {
        const step = steps.shift();
        if (step) step(); else console.log("CMD_DONE");
    }
    function typeChars(text, fn) {
        let i = 0;
        const one = () => { if (i < text.length) { line.typeIn(text[i++]); after(5, one); } else fn(); };
        one();
    }
    function settled() {
        for (const l of line.lines()) if (l.endsWith("→ …")) return false;
        return true;
    }
    function openState(open, fn) { until(() => view.opened === open && Motion.active === 0, 3000, fn); }
    function request(op, args, fn) { view.client.request(op, args, (ok, result) => fn ? fn(ok, result) : null); }

    FixtureView { id: view }
    property int interactiveCount: 0
    Connections {
        target: view.body
        function onInteractive() { root.interactiveCount++; }
    }
    Connections {
        target: view
        function onOpenedChanged() {
            if (view.opened && !root.started) {
                root.started = true;
                Qt.callLater(root.next);
            }
        }
    }

    Component.onCompleted: steps = [
        // Queued input: characters typed during the unfold all land, in order; Enter runs at once.
        () => {
            const unfolding = view.unfold.running;
            check("cmdline.focus.open", line.inputFocused, { focused: line.inputFocused });
            typeChars("tim 25", () => {
                check("queued.type.during.unfold", unfolding && line.text === "tim 25", { unfolding: unfolding, text: line.text });
                const stillUnfolding = view.unfold.running;
                line.run();
                const immediate = line.lines();
                check("queued.enter.at.once", immediate.length === 1 && immediate[0] === "tim 25 → …" && line.text === "",
                      { lines: immediate, unfolding: stillUnfolding });
                until(settled, 3000, ok => {
                    const t = view.client.timersData?.countdown;
                    check("verb.tim.ran", ok && t?.running && t?.duration === 1500, { lines: line.lines(), countdown: t });
                    next();
                });
            });
        },
        // Enter ×5 within 100 ms: five lines in order, each with its own entry; nothing waits.
        () => {
            const t0 = Date.now();
            for (let i = 1; i <= 5; i++) { line.typeIn("task q" + i); line.run(); }
            const lines = line.lines();
            check("queued.enter.x5", Date.now() - t0 < 100 && lines.length === 3 && lines.every(l => l.endsWith("→ …")),
                  { ms: Date.now() - t0, lines: lines });
            until(() => settled() && (view.client.tasksData?.tasks ?? []).filter(t => /^q\d$/.test(t.text)).length === 5, 3000, ok => {
                const order = (view.client.tasksData?.tasks ?? []).filter(t => /^q\d$/.test(t.text)).map(t => t.text);
                check("queued.enter.x5.order", ok && order.join() === "q1,q2,q3,q4,q5" && line.lines()[2].startsWith("task q5 → "),
                      { order: order, lines: line.lines() });
                next();
            });
        },
        // History: Up and Down browse, prefix-filtered by what was typed.
        () => until(() => line.history.length >= 6, 2000, ok => {
            line.older();
            const a = line.text;
            line.older();
            const b = line.text;
            line.newer();
            line.newer();
            const c = line.text;
            line.typeIn("tim");
            line.older();
            const d = line.text;
            line.cancel();
            check("history.browse", ok && a === "task q5" && b === "task q4" && c === "" && d === "tim 25", { a: a, b: b, c: c, d: d, history: line.history });
            next();
        }),
        // The live hint shows the verb's grammar while it is typed.
        () => {
            line.typeIn("tim");
            until(() => (line.hint?.usage ?? "").startsWith("tim"), 2000, ok => {
                check("hint.usage", ok, { hint: line.hint });
                line.cancel();
                next();
            });
        },
        // An ambiguous prefix lists its candidates and keeps the text for refining. (`t` would now
        // run `task`: five uses against one of `tim` passes the 2× rule.)
        () => {
            line.typeIn("se");
            line.run();
            until(settled, 2000, ok => {
                const last = line.lines().slice(-1)[0] ?? "";
                check("ambiguous.candidates", ok && last.includes("session") && last.includes("settings") && line.text === "se", { last: last, text: line.text });
                line.cancel();
                next();
            });
        },
        // `?` is generated from the registry, one line per domain.
        () => {
            line.typeIn("?");
            line.run();
            until(settled, 2000, ok => {
                const last = line.lines().slice(-1)[0] ?? "";
                check("help.registry", ok && last.includes("timers: tim") && last.split("\n").length >= 6, { last: last });
                next();
            });
        },
        // A failed verb names the problem and is coloured as an error.
        () => {
            line.typeIn("tim banana");
            line.run();
            until(settled, 2000, ok => {
                const tone = line.log.get(line.log.count - 1).tone;
                check("verb.error.tone", ok && tone === "error", { tone: tone, lines: line.lines() });
                next();
            });
        },
        // Escape clears a line first, and folds the panel only on an empty one.
        () => {
            line.typeIn("x");
            line.cancel();
            const cleared = line.text === "" && view.opened;
            line.cancel();
            openState(false, ok => {
                // The kept Shell (Q2) survives the fold; its line, log and room are cleared.
                check("escape.clear.then.fold", cleared && ok && line.text === "" && line.log.count === 0 && !view.body.shell.shownSlot.item,
                      { cleared: cleared, open: view.opened, lines: line.lines() });
                next();
            });
        },
        // Reopening from a clock rect: the origin follows the rect, focus returns to the line, the
        // panel reports interactive once per open, and a new rect while open moves nothing.
        () => {
            const before = root.interactiveCount;
            request("view.open", { from: { x: 0, y: 0, width: 40, height: 40 } });
            until(() => view.opened && root.line?.inputFocused, 3000, ok => {
                const origin = view.body.origin;
                check("open.focus.again", ok, {});
                request("view.open", { from: { x: 4000, y: 0, width: 40, height: 40 } });
                after(100, () => {
                    check("origin.from.rect", origin.x >= 0 && origin.x < view.body.width / 2 && origin.y === 0 && view.body.origin.x === origin.x,
                          { origin: [origin.x, origin.y], after: view.body.origin.x, width: view.body.width });
                    until(() => root.interactiveCount > before, 2000, interactive => {
                        check("interactive.reported", interactive, { count: root.interactiveCount, active: view.body.Window.active });
                        next();
                    });
                });
            });
        },
        // Q7: Super+` (key down) on a focused, empty line folds the panel; the core decides from view.state.
        () => openState(true, () => request("key.down", {}, (ok, result) => {
            openState(false, folded => {
                check("ignite.fold.idle", ok && result.action === "fold" && folded, { ok: ok, result: result, open: view.opened });
                request("key.up", {}, () => next());
            });
        })),
        // The ignite plate (docs/OVERDRIVE.md §2): a tap does nothing; a 600 ms hold on the open panel requests
        // Overdrive for it without folding (the core times it, as for Super+`); the same hold again cuts it.
        () => {
            request("view.open", {});
            until(() => view.opened && view.body.shell?.loadedPage === view.page, 3000, () => {
                const lease = view.body.shell.lease;
                lease.holdDown();
                after(120, () => {
                    lease.holdUp();
                    after(800, () => {
                        const tapped = lease.mode;
                        lease.holdDown();
                        until(() => lease.mode === "panel", 2000, lit => {
                            const follows = Motion.overdrive === (lease.effective === "active");
                            lease.holdUp();
                            after(100, () => {
                                const kept = lease.mode === "panel" && view.opened;
                                lease.holdDown();
                                until(() => lease.mode === "off", 2000, cut => {
                                    lease.holdUp();
                                    until(() => !lease.holding, 1000, ended => {
                                        check("ignite.plate", tapped === "off" && lit && follows && kept && cut && ended && !Motion.overdrive && view.opened,
                                              { tapped: tapped, lit: lit, follows: follows, kept: kept, cut: cut, ended: ended, open: view.opened });
                                        // Leave the panel folded, as the next step expects.
                                        request("view.close", {});
                                        openState(false, () => next());
                                    });
                                });
                            });
                        });
                    });
                });
            });
        },
        // Escape during the unfold folds from the current value, without a jump.
        () => {
            request("view.open", {});
            until(() => view.unfold.value > 0.2 && root.line?.inputFocused, 2000, ok => {
                const from = view.unfold.value;
                let jump = 0, last = from;
                const watch = () => { jump = Math.max(jump, Math.abs(view.unfold.value - last)); last = view.unfold.value; };
                view.unfold.valueChanged.connect(watch);
                line.cancel();
                openState(false, folded => {
                    view.unfold.valueChanged.disconnect(watch);
                    check("escape.during.unfold", ok && folded && from < 1 && jump <= 0.25, { from: from, jump: jump });
                    next();
                });
            });
        },
        // An unrecognised first word folds the panel and opens the host launcher once.
        () => {
            request("view.open", {});
            // The core folds only a panel it knows is open; the fixture view reports open once the room loads.
            until(() => view.opened && root.line?.inputFocused && view.body.shell?.loadedPage === view.page, 3000, () => {
                const before = view.fixture.hostActions.calls.length;
                line.typeIn("zzfoo bar");
                line.run();
                openState(false, folded => {
                    const calls = view.fixture.hostActions.calls.slice(before);
                    check("fallthrough.launcher", folded && calls.length === 1 && calls[0].method === "openLauncher" && calls[0].args[0] === "zzfoo bar",
                          { folded: folded, calls: calls });
                    next();
                });
            });
        },
    ]
}
