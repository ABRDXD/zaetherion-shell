#!/usr/bin/env python3
"""Keyboard reach in every room (MONTAGE.md §1, §3.3), offscreen against the fixture adapter and a private core.

For each of the nine rooms it collects the visible, enabled tab stops (Shell.focusables) and checks:
- tab: the window's focus chain passes through every one of them;
- spatial: every one is reachable from the first by FocusMap moves in the four directions;
- reticle: with the reticle shown, its rect equals the focused control's rect (motion reduced);
- shown: the reticle is visible after keyboard navigation and hidden after a typed letter;
- escape: Escape from a room control focuses the command line;
- index / command: a move with no candidate goes towards the ribbon's edge into the index (the selected tab), back into
  the room, and up to the command line;
- band: only the room's own index band is selected and fully revealed as the title plane;
- rows: in every list with two or more rows, Down from row 0 stays in the list, the row only grows, and the
  focused row is scrolled into the list's view (up to 30 rows; Clips gets 40 synthetic entries, Tasks 35).
Then the orbit (docs/ORBIT.md): it opens on the current room, every tile is reachable by arrow moves, Tab
order wraps, no tile overlaps another or Home, choosing a tile lands in that room and closes it, Escape returns
to the room it came from, and closed it is not instantiated. Then every room's own system (RoomSystems): S on a
planet steps in (the sun keyed, the planet's highlight aside), arrow moves and Tab each reach the sun and every
moon whose control works, the keyed moon is highlighted, Esc steps back out to the planet, and Enter acts as a
click (a Performance moon and a sun land in their rooms).
It also instantiates each Plane renderer once. Offscreen Qt has no keyboard, so keys are the Shell's own
handlers (navigationKey, moveFocus); the Keys → handler mapping belongs to the desktop check.
Uses tools/smoke.py's private tree: no real host shell or system action is touched.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import smoke  # noqa: E402

PAGES = ['home', 'media', 'performance', 'workspaces', 'devices', 'tasks', 'timers', 'clipboard', 'notifications', 'codex']

HARNESS = '''import QtQuick
import QtQuick.Window
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui as Fart
import "view/ui/FocusMap.js" as FocusMap
Scope {
    id: scope
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    Component.onCompleted: {
        Host.adapter = fixture; Fart.Design.source = fixture.palette; Motion.reduced = true;
        // A long synthetic clip list, so the rows check scrolls past the delegates the list has created.
        fixture.clipboard.entries = Array.from({ length: 40 }, (_, i) => ({ id: String(40 - i), text: "keytest row " + i, isImage: false }));
    }
    property var pages: %s
    property int cursor: -1
    // After the rooms: "" until the orbit checks, then the steps that wait for the systems to build.
    property var after: []
    property int waited: 0
    function check(name, ok, detail) { console.log(ok ? "KEY_PASS" : "KEY_FAIL", name, ok ? "" : JSON.stringify(detail ?? {})); }
    function label(item) { return (item.objectName || item.text || item.label || String(item)).toString().slice(0, 40); }
    function same(a, b) { return Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5 && Math.abs(a.width - b.width) < 0.5 && Math.abs(a.height - b.height) < 0.5; }
    function walk(page) {
        const room = dashboard.shownSlot.item;
        // The title plane: only the selected band is revealed, and it carries the room's name.
        const own = dashboard.navigationPages.findIndex(entry => entry.id === page);
        const wrongBands = [];
        for (let i = 0; i < dashboard.bands.count; i++) {
            const band = dashboard.bands.itemAt(i);
            if (band.selected !== (i === own) || band.reveal !== (i === own ? 1 : 0) || band.height !== (i === own ? band.titleHeight : band.restHeight))
                wrongBands.push({ band: i, selected: band.selected, reveal: band.reveal, height: band.height });
        }
        check(page + ".band", wrongBands.length === 0, wrongBands);
        const items = dashboard.focusables(room, []);
        console.log("KEY_ROOM", page, items.length);
        if (items.length === 0) return;
        // Tab: follow the focus chain from the first stop until it comes round again.
        const seen = new Set();
        let at = items[0];
        for (let i = 0; i < 2000 && at; i++) {
            seen.add(at);
            at = at.nextItemInFocusChain(true);
            if (at === items[0]) break;
        }
        const missedTab = items.filter(item => !seen.has(item)).map(label);
        check(page + ".tab", missedTab.length === 0, missedTab);
        // Spatial: breadth-first over FocusMap moves.
        const rects = items.map(dashboard.rectIn);
        const reached = new Set([0]);
        const queue = [0];
        while (queue.length) {
            const from = queue.shift();
            for (const direction of ["left", "right", "up", "down"]) {
                const next = FocusMap.pick(rects[from], rects, direction);
                if (next >= 0 && !reached.has(next)) { reached.add(next); queue.push(next); }
            }
        }
        const missedSpatial = items.filter((item, i) => !reached.has(i)).map(label);
        check(page + ".spatial", missedSpatial.length === 0, { unreached: missedSpatial.length, of: items.length, items: missedSpatial.slice(0, 8) });
        // Reticle: focus each stop with the reticle shown and compare rects.
        dashboard.keyboardNav = true;
        const reticle = dashboard.focusReticle;
        const wrong = [];
        for (const item of items) {
            item.forceActiveFocus(Qt.TabFocusReason);
            reticle.place();
            const want = dashboard.rectIn(item);
            const got = { x: reticle.x, y: reticle.y, width: reticle.width, height: reticle.height };
            if (reticle.target !== item || !same(want, got)) wrong.push({ item: label(item), targeted: reticle.target === item, want: want, got: got });
        }
        check(page + ".reticle", wrong.length === 0, wrong.slice(0, 4));
        check(page + ".shown", reticle.visible, {});
        dashboard.keyboardNav = false;
        check(page + ".hidden", !reticle.visible, {});
        // Escape: from a room control back to the command line.
        items[0].forceActiveFocus(Qt.TabFocusReason);
        check(page + ".escape", dashboard.escapeKey() && dashboard.commandLine.inputFocused, { focused: label(dashboard.focusedItem()) });
        // Fallbacks: towards the ribbon's edge from the outermost control reaches the index, the other way comes
        // back, up reaches the command line.
        const toward = dashboard.ribbonSide;
        const away = toward === "left" ? "right" : "left";
        const outer = items.reduce((a, b, i) => (toward === "left" ? rects[i].x < rects[a].x : rects[i].x + rects[i].width > rects[a].x + rects[a].width) ? i : a, 0);
        items[outer].forceActiveFocus(Qt.TabFocusReason);
        for (let i = 0; i < 40 && dashboard.zoneOf(dashboard.focusedItem()) === "room"; i++) dashboard.moveFocus(toward);
        const band = dashboard.focusedItem();
        check(page + ".index", dashboard.zoneOf(band) === "index" && band.selected === true, { zone: dashboard.zoneOf(band), side: toward, focused: label(band) });
        dashboard.moveFocus(away);
        check(page + ".index.back", dashboard.zoneOf(dashboard.focusedItem()) === "room", { focused: label(dashboard.focusedItem()) });
        const topmost = items.reduce((a, b, i) => rects[i].y < rects[a].y ? i : a, 0);
        items[topmost].forceActiveFocus(Qt.TabFocusReason);
        for (let i = 0; i < 40 && !dashboard.commandLine.inputFocused && dashboard.zoneOf(dashboard.focusedItem()) === "room"; i++) dashboard.moveFocus("up");
        check(page + ".command", dashboard.commandLine.inputFocused, { focused: label(dashboard.focusedItem()) });
        // Rows: lists move by row inside themselves first, scrolling as they go.
        const lists = [];
        for (const item of items) { const list = dashboard.listOf(item); if (list && list.count >= 2 && !lists.includes(list)) lists.push(list); }
        const badRows = [];
        const walked = [];
        for (const list of lists) {
            const first = dashboard.focusables(list, []).find(item => dashboard.rowOf(list, item) === 0);
            if (!first) continue;
            first.forceActiveFocus(Qt.TabFocusReason);
            let row = 0;
            for (let i = 0; i < Math.min(list.count - 1, 30); i++) {
                dashboard.moveFocus("down");
                const at = dashboard.focusedItem();
                const next = dashboard.listOf(at) === list ? dashboard.rowOf(list, at) : -1;
                const top = next >= 0 ? at.mapToItem(list, 0, 0).y : -1;
                const inView = top >= -0.5 && top + at.height <= list.height + 0.5;
                if (next <= row || !inView) { badRows.push({ list: label(list), step: i, row: row, next: next, top: top, focused: label(at) }); break; }
                row = next;
            }
            walked.push(row + "/" + (list.count - 1));
        }
        console.log("KEY_LISTS", page, lists.length, walked.join(" "));
        check(page + ".rows", badRows.length === 0, badRows);
    }
    function overlaps(a, b) { return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height; }
    function orbitChecks() {
        const from = dashboard.currentPage;
        dashboard.toggleOrbit();
        const orbit = dashboard.orbit;
        check("orbit.open", dashboard.orbitOpen && orbit !== null && orbit.pages[orbit.focusIndex].id === from,
              { open: dashboard.orbitOpen, focus: orbit ? orbit.focusIndex : -1 });
        if (!orbit) return;
        // Reach: every tile from Home by arrow moves.
        const reached = new Set([0]);
        const queue = [0];
        while (queue.length) {
            const at = queue.shift();
            for (const direction of ["left", "right", "up", "down"]) {
                orbit.focusIndex = at;
                orbit.move(direction);
                if (!reached.has(orbit.focusIndex)) { reached.add(orbit.focusIndex); queue.push(orbit.focusIndex); }
            }
        }
        check("orbit.reach", reached.size === orbit.pages.length, { reached: reached.size, of: orbit.pages.length });
        orbit.focusIndex = orbit.pages.length - 1;
        orbit.step(1);
        const wrapped = orbit.focusIndex;
        orbit.step(-1);
        check("orbit.tab", wrapped === 0 && orbit.focusIndex === orbit.pages.length - 1, { wrapped: wrapped, back: orbit.focusIndex });
        // Layout: tiles (scaled by depth) clear of each other and of Home, and inside the field.
        const rects = orbit.pages.map((p, i) => { const t = orbit.tileAt(i); return t.mapToItem(orbit, 0, 0, t.width, t.height); });
        const clashes = [];
        for (let i = 0; i < rects.length; i++) {
            const r = rects[i];
            if (r.x < 0 || r.y < 0 || r.x + r.width > orbit.width || r.y + r.height > orbit.height) clashes.push({ outside: i });
            for (let j = i + 1; j < rects.length; j++) if (overlaps(r, rects[j])) clashes.push({ a: i, b: j });
        }
        check("orbit.layout", clashes.length === 0, clashes.slice(0, 6));
        // Escape: back to the room it came from.
        check("orbit.escape", dashboard.escapeKey() && !dashboard.orbitOpen && dashboard.currentPage === from && dashboard.orbit === null,
              { open: dashboard.orbitOpen, page: dashboard.currentPage });
        // Landing: choosing a tile goes to that room and closes the orbit.
        dashboard.toggleOrbit();
        const target = dashboard.orbit.pages.findIndex(p => p.id === "tasks");
        dashboard.orbit.choose(target);
        check("orbit.land", dashboard.currentPage === "tasks" && !dashboard.orbitOpen && dashboard.orbit === null,
              { page: dashboard.currentPage, open: dashboard.orbitOpen });
        dashboard.toggleOrbit();
        after = [systemChecks, moonAct, () => dashboard.toggleOrbit(), sunAct, () => dashboard.flyTo("stopwatch"), flyChecks];
    }
    // The systems build asynchronously once the orbit is open and still.
    function systemsReady() {
        const orbit = dashboard.orbit;
        return !!orbit && !!orbit.roomSystems && Object.keys(orbit.systems).every(id => !!orbit.systems[id]);
    }
    function systemChecks() {
        const orbit = dashboard.orbit;
        const counts = [];
        for (let i = 1; i < orbit.pages.length; i++) {
            const id = orbit.pages[i].id;
            orbit.focusIndex = i;
            const entered = orbit.enterSystem();
            const s = orbit.keySystem;
            check("system." + id + ".enter", entered && orbit.systemFocus === id && s === orbit.systems[id] && s.keyIndex === -1
                  && !orbit.tileAt(i).highlighted, { entered: entered, focus: orbit.systemFocus, key: s ? s.keyIndex : null });
            if (!s) continue;
            const targets = orbit.keyTargets(s);
            counts.push(id + ":" + (targets.length - 1));
            // Arrows: breadth-first from the sun.
            const reached = new Set([-1]);
            const queue = [-1];
            while (queue.length) {
                const at = queue.shift();
                for (const direction of ["left", "right", "up", "down"]) {
                    s.keyIndex = at;
                    orbit.walkSystem(direction);
                    if (!reached.has(s.keyIndex)) { reached.add(s.keyIndex); queue.push(s.keyIndex); }
                }
            }
            const missed = targets.filter(k => !reached.has(k));
            check("system." + id + ".reach", missed.length === 0, { missed: missed, of: targets.length });
            // Tab: round every target and back to the sun.
            s.keyIndex = -1;
            const tabbed = new Set();
            for (let n = 0; n < targets.length; n++) { orbit.stepSystem(1); tabbed.add(s.keyIndex); }
            check("system." + id + ".tab", tabbed.size === targets.length && s.keyIndex === -1, { tabbed: tabbed.size, of: targets.length, at: s.keyIndex });
            // The mark: the keyed moon is highlighted.
            if (targets.length > 1) {
                s.keyIndex = targets[1];
                const tile = s.moonTiles.itemAt(targets[1]);
                check("system." + id + ".mark", !!tile && tile.highlighted && orbit.keyName !== "", { key: s.keyIndex, name: orbit.keyName });
            }
            orbit.exitSystem();
            check("system." + id + ".exit", orbit.systemFocus === "" && orbit.focusIndex === i && s.keyIndex === -2 && orbit.tileAt(i).highlighted,
                  { focus: orbit.systemFocus, index: orbit.focusIndex, key: s.keyIndex });
        }
        console.log("KEY_SYSTEMS", counts.join(" "));
        // Home has no system: S there stays put.
        orbit.focusIndex = 0;
        check("system.home", !orbit.enterSystem() && orbit.systemFocus === "", { focus: orbit.systemFocus });
    }
    // Enter on a moon acts as its click: a Performance reading lands in Performance.
    function moonAct() {
        const orbit = dashboard.orbit;
        orbit.focusIndex = orbit.indexOf("performance");
        orbit.enterSystem();
        orbit.keySystem.keyIndex = 0;
        orbit.actSystem();
        check("system.act.moon", dashboard.currentPage === "performance" && !dashboard.orbitOpen, { page: dashboard.currentPage, open: dashboard.orbitOpen });
    }
    // Type to fly (go <moon>): from a closed orbit, the named moon is keyed once the systems are built; a leading
    // room word narrows the search; a name that matches nothing says so and keys nothing.
    function flyChecks() {
        const orbit = dashboard.orbit;
        const s = orbit.keySystem;
        check("fly.moon", dashboard.orbitOpen && orbit.systemFocus === "timers" && s && s.moons[s.keyIndex]?.name === "STOPWATCH",
              { open: dashboard.orbitOpen, focus: orbit.systemFocus, key: s ? s.keyIndex : null });
        dashboard.flyTo("workspaces 3");
        const d = orbit.keySystem;
        check("fly.room.number", orbit.systemFocus === "workspaces" && d && d.moons[d.keyIndex]?.number === "03",
              { focus: orbit.systemFocus, key: d ? d.keyIndex : null });
        dashboard.flyTo("cpu");
        const c = orbit.keySystem;
        check("fly.exact", orbit.systemFocus === "performance" && c && c.moons[c.keyIndex]?.name === "CPU", { focus: orbit.systemFocus });
        orbit.exitSystem();
        dashboard.flyTo("no such moon here");
        check("fly.missed", orbit.systemFocus === "" && orbit.missed === "no such moon here", { focus: orbit.systemFocus, missed: orbit.missed });
    }
    function sunAct() {
        const orbit = dashboard.orbit;
        orbit.focusIndex = orbit.indexOf("timers");
        orbit.enterSystem();
        orbit.actSystem();
        check("system.act.sun", dashboard.currentPage === "timers" && !dashboard.orbitOpen, { page: dashboard.currentPage, open: dashboard.orbitOpen });
    }
    FloatingWindow {
        id: window
        implicitWidth: 1120; implicitHeight: 760; visible: true
        Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
        Fart.Plane { id: planeSheared; width: 120; height: 40; slant: 3; visible: false }
        Fart.Plane { id: planeCut; width: 120; height: 40; slant: 1; cut: 6; role: "ink"; backing: true; visible: false }
        Fart.Plane { id: planeClear; width: 120; height: 40; role: "clear"; backing: true; visible: false }
    }
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            if (after.length) {
                // A step that needs the orbit's systems waits for them (up to 12 s, for a loaded machine); the others run at once.
                const step = after[0];
                const needs = [systemChecks, moonAct, sunAct, flyChecks].includes(step);
                if (needs && !systemsReady() && ++waited < 40) return;
                if (needs && !systemsReady()) check("system.built", false, { orbit: !!dashboard.orbit });
                else step();
                after.shift();
                waited = 0;
                if (!after.length) { console.log("KEY_DONE"); Qt.quit(); }
                return;
            }
            if (cursor === -1) {
                // Ctrl+1 to Ctrl+9: one shortcut per room after Home, the Codex's (09) included.
                const shortcuts = [];
                const findShortcuts = item => {
                    if (!item) return;
                    if (typeof item.objectAt === "function" && typeof item.count === "number")
                        for (let i = 0; i < item.count; i++) { const o = item.objectAt(i); if (o && typeof o.sequence === "string") shortcuts.push(o.sequence); }
                    for (const c of [...(item.children ?? []), ...(item.resources ?? [])]) findShortcuts(c);
                };
                findShortcuts(dashboard);
                const want = dashboard.pages.slice(0, 9).map((p, i) => "Ctrl+" + (i + 1));
                check("keys.rooms", want.length === 9 && want.every(k => shortcuts.includes(k)), { found: shortcuts, want: want });
                check("plane.sheared", planeSheared.sheared && planeSheared.polygon.length === 4, { sheared: planeSheared.sheared });
                check("plane.cut", !planeCut.sheared && planeCut.polygon.length === 8 && Qt.colorEqual(planeCut.textColor, Fart.Design.onInk ?? Fart.Design.background),
                      { sheared: planeCut.sheared, points: planeCut.polygon.length });
                check("plane.backing.opaque", planeClear.effectiveRole === "paper", { role: planeClear.effectiveRole });
            } else if (dashboard.loadedPage === pages[cursor]) {
                walk(pages[cursor]);
            } else {
                check(pages[cursor] + ".loaded", false, { loaded: dashboard.loadedPage });
            }
            cursor++;
            if (cursor >= pages.length) { orbitChecks(); if (!after.length) { console.log("KEY_DONE"); Qt.quit(); } return; }
            dashboard.navigate(pages[cursor]);
        }
    }
}
''' % json.dumps(PAGES)

ERRORS = ('ReferenceError:', 'TypeError:', 'Cannot assign', 'Unable to assign', 'is not a type', 'Failed to load configuration')


def main():
    # --size WxH walks the rooms at another panel size (the default is 1120 x 760).
    size = sys.argv[sys.argv.index('--size') + 1] if '--size' in sys.argv else '1120x760'
    width, height = (int(n) for n in size.lower().split('x'))
    harness = HARNESS.replace('implicitWidth: 1120; implicitHeight: 760', f'implicitWidth: {width}; implicitHeight: {height}')
    with tempfile.TemporaryDirectory(prefix='fart-next-keytest-') as tmp:
        base = Path(tmp)
        env, state, view_log = smoke.prepare(base, harness)
        smoke.seed_tasks(state, {'lists': [{'id': 'default', 'name': 'Tasks'}, {'id': 'l-b', 'name': 'Second'}],
                                 'tasks': [{'id': f't{i}', 'list': 'default', 'text': f'keytest task {i}',
                                            'due': ['-1', '+0', '+3', None][i % 4]} for i in range(35)]})
        runtime = Path(env['FART_RUNTIME_DIR'])
        core = subprocess.Popen([sys.executable, '-I', str(smoke.ROOT / 'core/fartd.py')], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = smoke.run_view(runtime / 'core.sock')
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ''
    lines = [line.split('qml: ', 1)[-1] for line in output.splitlines() if 'KEY_' in line]
    for line in lines:
        print(line)
    errors = [line for line in output.splitlines() if any(e in line for e in ERRORS)]
    for line in errors:
        print('KEY_ERROR', line.strip())
    failed = sum(line.startswith('KEY_FAIL') for line in lines)
    passed = sum(line.startswith('KEY_PASS') for line in lines)
    done = exited and any(line.startswith('KEY_DONE') for line in lines)
    print(f'keytest: {passed} passed, {failed} failed, {len(errors)} runtime errors' + ('' if done else ', did not finish'))
    return 0 if done and failed == 0 and not errors else 1


if __name__ == '__main__':
    raise SystemExit(main())
