import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell

// Every room's tile on the orbit takes the pointer (the Codex, room 09, came last and once didn't): with the orbit
// open and settled, the topmost item under each tile's centre must belong to that tile; framed as a galaxy, the same
// holds for each system's sun (the compass once sat on Media's); and a click on tile 09 reaches the Codex. Offscreen,
// on the fixture; HIT_W and HIT_H size the window, HIT_OD turns Overdrive on.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    // The topmost visible, enabled item at a point in `item`, as the pointer would find it.
    function topAt(item, x, y) {
        const kids = (item.children ?? []).slice().map((c, i) => ({ c: c, i: i })).sort((a, b) => (a.c.z - b.c.z) || (a.i - b.i));
        for (let k = kids.length - 1; k >= 0; k--) {
            const c = kids[k].c;
            // Pass-through areas (the Shell's pointer watcher) hand the press on.
            if (!c.visible || c.opacity === 0 || !c.enabled || c.propagateComposedEvents === true)
                continue;
            const p = item.mapToItem(c, x, y);
            if (!c.clip || (p.x >= 0 && p.y >= 0 && p.x < c.width && p.y < c.height)) {
                const deeper = topAt(c, p.x, p.y);
                if (deeper)
                    return deeper;
                if ((c.acceptedButtons !== undefined || (c.pressed !== undefined && c.checkable !== undefined)) && p.x >= 0 && p.y >= 0 && p.x < c.width && p.y < c.height)
                    return c;
            }
        }
        return null;
    }
    function inside(a, b) {
        for (let p = a; p; p = p.parent) if (p === b) return true;
        return false;
    }
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: Number(Quickshell.env("HIT_W") || 1120); implicitHeight: Number(Quickshell.env("HIT_H") || 760); visible: true
        Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
    }
    Component.onCompleted: after(800, () => {
        if (Quickshell.env("HIT_OD")) { Motion.overdrive = true; Motion.settleDrive(); dashboard.ignition.settle(); }
        dashboard.toggleOrbit();
        after(3500, () => {
            const orbit = dashboard.orbit;
            if (!orbit) { check("orbit.hit", false, { orbit: false }); return finish(); }
            const misses = [];
            for (let i = 1; i < dashboard.navigationPages.length; i++) {
                const tile = orbit.tileAt(i);
                const c = tile.mapToItem(window.contentItem, tile.width / 2, tile.height / 2);
                const top = topAt(window.contentItem, c.x, c.y);
                const id = dashboard.navigationPages[i].id;
                console.log("ORBIT_HIT", i, id, Math.round(c.x), Math.round(c.y), tile.visible, tile.enabled, top ? (inside(top, tile) ? "tile" : String(top) + " parent " + String(top.parent)) : "nothing");
                if (!top || !inside(top, tile))
                    misses.push(id);
            }
            check("orbit.hit", misses.length === 0, { misses: misses });
            // The systems' suns, framed all at once (the galaxy).
            orbit.galaxy();
            after(2500, () => {
                const sunMisses = [];
                for (const id in orbit.systems) {
                    const sys = orbit.systems[id];
                    const r = sys?.sunRect ?? null;
                    if (!r || !(r.w > 0)) { console.log("SUN_HIT", id, "no sun"); sunMisses.push(id); continue; }
                    const c = sys.mapToItem(window.contentItem, r.x + r.w / 2, r.y + r.h / 2);
                    const top = topAt(window.contentItem, c.x, c.y);
                    console.log("SUN_HIT", id, Math.round(c.x), Math.round(c.y), top ? (inside(top, sys) ? "system" : String(top) + " in " + String(top.parent)) : "nothing");
                    if (top && !inside(top, sys)) {
                        const chain = [];
                        for (let q = top; q && chain.length < 12; q = q.parent) { const g = q.mapToItem(window.contentItem, 0, 0); chain.push(String(q).split("(")[0] + (q.name ? ":" + q.name : "") + (q.objectName ? "#" + q.objectName : "") + "@" + Math.round(g.x) + "," + Math.round(g.y) + " " + Math.round(q.width) + "x" + Math.round(q.height) + " z" + q.z); }
                        console.log("SUN_CHAIN", chain.join(" < "));
                    }
                    if (!top || !inside(top, sys)) sunMisses.push(id);
                }
                check("orbit.suns", sunMisses.length === 0, { misses: sunMisses });
                // A click on room 09's tile flies to the Codex.
                orbit.recentre();
                after(1500, () => {
                    orbit.tileAt(9).clicked();
                    after(3000, () => {
                        console.log("CLICK_09", dashboard.currentPage, dashboard.shownPageId, dashboard.orbitOpen);
                        check("orbit.click09", dashboard.currentPage === "codex" && dashboard.shownPageId === "codex", { current: dashboard.currentPage, shown: dashboard.shownPageId });
                        finish();
                    });
                });
            });
        });
    })
    function finish() {
        console.log("CUE_DONE");
        Qt.exit(0);
    }
}
