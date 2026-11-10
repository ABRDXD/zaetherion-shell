import qs.view.cues
import qs.view.faces
import qs.view.overdrive
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "Orbit.js" as Orbit
import "../overdrive/FalseRoom.js" as F
import "../ui/FocusMap.js" as FocusMap

// The overview (docs/ORBIT.md): every room at once, as a system in space. Home floats at the centre and
// rooms 01–08 ride concentric orbits around it in index order, on a plane seen through a perspective
// camera from 45° above (Orbit.js), sheared to FART's 78°. Each tile floats over its orbit on a stalk, with its
// shadow on the plane; the near half of every orbit is drawn stronger than the far half. The solar system
// is the layout's metaphor, not its look: rooms are FART tiles, orbits are hairlines. Each room keeps its
// place (stored angles). Nothing moves at rest: hover and focus only rebind, through short Tweens.
FocusScope {
    id: root
    // Shell.navigationPages: Home first, then rooms 01–08.
    required property var pages
    property string current: "home"
    // { id: radians } from ViewState; rooms without one take the default spiral.
    property var angles: null
    // The highlighted tile: keyboard focus, or the pointer while it hovers one.
    property int focusIndex: 0
    property int hoverIndex: -1
    readonly property int highlightIndex: hoverIndex >= 0 ? hoverIndex : focusIndex
    readonly property var highlighted: pages[highlightIndex] ?? null
    readonly property Repeater tiles: tileRepeater
    readonly property Item homeTile: home

    signal chosen(string id)
    // Asks the Shell to glide the camera back to the whole main system, to frame every system at once (the
    // galaxy), or to zoom about the field's centre.
    signal recentre()
    signal galaxy()
    signal zoomStep(real factor)
    // Asks the Shell to glide the camera until a box of the scene ({ x0, y0, x1, y1 }) fills the field
    // beside the readout: a room's system, as the keyboard steps into it.
    signal frameBox(var box)
    // Every room's own system (RoomSystems), by room id; Workspaces' and Media's by name for the tests.
    // They are built once the orbit is open and still, or dragged through (`spacious`), never during a
    // flight (a switch never shows them, and building eight systems mid-open dropped frames). Once built
    // they stay until the orbit closes; they build across frames (asynchronous) and fade in.
    property bool spacious: true
    property bool systemsWanted: false
    onSpaciousChanged: if (spacious) systemsWanted = true
    readonly property Item roomSystems: systemsLoader.item
    readonly property var systems: roomSystems?.systems ?? ({})
    readonly property Item deskSystem: systems.workspaces ?? null
    readonly property Item mediaSystem: systems.media ?? null
    readonly property Item fabric: fabric
    // The main system's extent in the scene, and a room system's: { x0, y0, x1, y1 }.
    readonly property var mainBox: ({ x0: cx - outer * 1.1 - tileW * 0.6, y0: cy - outer * 0.8 - lift - tileH, x1: cx + outer * 1.1 + tileW * 0.6, y1: cy + outer * 1.05 + tileH * 0.3 })
    // Each system floats at its own height over its place on the plane, held by a tether (the user: "varying
    // heights … more dynamic"). Fixed per room, so a system is always found at the same height.
    readonly property var altitudes: [0.08, 0.72, 0.3, 0.92, 0.18, 0.56, 0.82, 0.42]
    function systemAltitude(id) {
        const k = roomAt(id);
        return k < 0 ? 0 : Math.round(systemOuter * altitudes[k % altitudes.length]);
    }
    // The box covers the raised system and its tether down to the plane.
    function systemBox(id) {
        const c = systemCentre(id), up = systemAltitude(id);
        return { x0: c.x - systemHalfW, y0: c.y - up - systemHalfH * 1.1, x1: c.x + systemHalfW, y1: c.y + Math.max(systemHalfH * 0.9 - up, 12) };
    }
    // Every system's extent at once (the galaxy).
    function galaxyBounds() {
        return rooms.map(p => systemBox(p.id)).reduce((a, b) => ({ x0: Math.min(a.x0, b.x0), y0: Math.min(a.y0, b.y0), x1: Math.max(a.x1, b.x1), y1: Math.max(a.y1, b.y1) }), mainBox);
    }
    // The host and the core, for the systems' readings and controls.
    property var host: null
    property var core: null
    // The ShellContext, for the moons that must close the shell first (Devices' night light).
    property var shell: null

    // Off while the Shell flies its camera through the orbit (a switch, an open, a close): no hover, no
    // clicks, no readout.
    property bool interactive: true
    // The camera (docs/ORBIT.md §4): the orbit point at the field's centre, and the scale. The rest
    // position is the whole system; the Shell zooms it into a room's tile and out again.
    property real camX: width / 2
    property real camY: height / 2
    property real camS: 1
    readonly property Item scene: scene
    // The plane's tilt, in degrees above it; the Shell swings it during a flight, and it rests at 45.
    property real elevation: Orbit.ELEVATION
    // The tiles rising out of the plane (0 flat on it, 1 floating), one orbit after another: the Shell
    // drives it while the orbit opens, and it rests at 1.
    property real rise: 1
    // The streak of a switch: from one room's tile to the next one's, around Home; `streak` 0–1 is the
    // head's place on the arc, and outside (0, 1) nothing is drawn.
    property string streakFrom: ""
    property string streakTo: ""
    property real streak: 0

    // Each room's face on its tile (view/faces), by room id; a face whose service is missing is left out.
    readonly property var faces: {
        const out = {};
        if (host)
            Object.assign(out, { media: mediaFace, performance: performanceFace, workspaces: workspacesFace, devices: devicesFace,
                                 clipboard: clipboardFace, notifications: notificationsFace, codex: codexFace });
        if (core)
            Object.assign(out, { tasks: tasksFace, timers: timersFace });
        return out;
    }
    Component { id: mediaFace; MediaFace { host: root.host } }
    Component { id: performanceFace; PerformanceFace { host: root.host } }
    Component { id: workspacesFace; WorkspacesFace { host: root.host } }
    Component { id: devicesFace; DevicesFace { host: root.host } }
    Component { id: tasksFace; TasksFace { core: root.core } }
    Component { id: timersFace; TimersFace { core: root.core } }
    Component { id: clipboardFace; ClipboardFace { host: root.host } }
    Component { id: notificationsFace; NotificationsFace { host: root.host } }
    Component { id: codexFace; CodexFace {} }

    // Narrow panels lay the readout under the system instead of beside it.
    readonly property bool compact: width < 1000
    readonly property real cardWidth: compact ? 0 : 236
    // Tile sizes at scale 1: rooms with more in them a little larger, the two counters smaller.
    readonly property real tileW: Math.round(Math.max(88, Math.min(140, height * 0.145)))
    readonly property real tileH: Math.round(tileW * 0.54)
    readonly property var weights: ({ media: 1.12, workspaces: 1.12, tasks: 1.12, clipboard: 0.88, notifications: 0.88, codex: 0.88 })
    readonly property var rooms: pages.slice(1)
    readonly property var sizes: rooms.map(p => ({ w: Math.round(tileW * (weights[p.id] ?? 1)), h: Math.round(tileH * (weights[p.id] ?? 1)) }))
    readonly property real homeW: Math.round(tileW * 1.6)
    readonly property real homeH: Math.round(tileH * 1.8)
    readonly property real pad: 8
    // How high the tiles float over the plane, and Home.
    readonly property real lift: Math.round(tileH * 0.75)
    readonly property real homeLift: Math.round(tileH * 0.3)
    // The system's size and centre, fitted at rest beside the readout (perspective makes it lopsided, so
    // the fit also says how far to shift it to sit centred).
    readonly property real systemLeft: cardWidth > 0 ? cardWidth + 48 : 0
    // The band along the bottom the compass takes when Home is in view (a framed galaxy keeps its suns out of it).
    readonly property real systemBottom: 16 + 28 + 8
    readonly property var fitted: Orbit.fit((width - systemLeft) / 2 - 16, (compact ? height - 64 : height) / 2 - 12,
                                            tileW * 0.56, tileH * 0.56, lift, Orbit.ELEVATION)
    readonly property real outer: fitted.r
    readonly property real cx: systemLeft + (width - systemLeft) / 2 + fitted.dx
    readonly property real cy: (compact ? height - 64 : height) / 2 + fitted.dy
    readonly property var restView: Orbit.view(Orbit.ELEVATION, outer)
    readonly property var camView: Orbit.view(elevation, outer)
    readonly property var homeBox: {
        const p = Orbit.point(0, homeLift, 0, restView);
        return { x: p.x, y: p.y - homeH * p.k / 2, hw: homeW * p.k / 2, hh: homeH * p.k / 2 };
    }
    readonly property real inner: Math.min(outer, homeW / 2 + tileW * 0.62 + pad)
    readonly property var radii: Orbit.radii(rooms.length, inner, outer)
    // Each room's angle: its stored one, else the spiral's; then nudged clear of its neighbours at rest.
    readonly property var placed: {
        const base = Orbit.spread(rooms.length);
        const stored = angles ?? {};
        const start = rooms.map((p, k) => Number.isFinite(stored[p.id]) ? stored[p.id] : base[k]);
        return Orbit.separate(start, radii, sizes, homeBox, pad, restView, lift);
    }
    // Tile k's rise, staggered from the inner orbit out, with a small overshoot as it arrives.
    function riseOf(k) {
        const x = Math.max(0, Math.min(1, rise * (1 + 0.06 * rooms.length) - 0.06 * k));
        const c1 = 1.7, c3 = c1 + 1;
        return x <= 0 ? 0 : 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
    }
    function placeNow(k) {
        return Orbit.project(radii[k] ?? 0, (placed[k] ?? 0) + driftOf(k), cx, cy, camView, lift * riseOf(k) * (1 + 0.32 * beat.value));
    }
    // Every room's place, worked out once per change and shared: the tiles, the laws (a transit check alone asked
    // for a hundred) and the fabric all read it, where each used to project its own every frame in Overdrive.
    readonly property var places: rooms.map((p, k) => placeNow(k))
    function place(k) {
        return places[k] ?? placeNow(k);
    }
    // A room's index by id (-1 if it isn't one): the per-frame laws look rooms up by name.
    readonly property var roomIndex: {
        const m = {};
        rooms.forEach((p, k) => m[p.id] = k);
        return m;
    }
    function roomAt(id) { return roomIndex[id] ?? -1; }

    // Overdrive: the orbit alive (docs/OVERDRIVE.md §5). In Silent every one of these is 0 and nothing runs.
    // - The tiles drift along their orbits at Kepler's speeds (the inner one round in `driftPeriod` at full drive,
    //   each further one slower by (r / r_inner)^1.5). Their offset from the stored angle is scaled by the engine,
    //   so a release winds them back to where they belong (the shortest way) as it spins down.
    // - The systems bob at their heights, each in its own phase, and their moons circle their suns.
    // - The fabric breathes, the bass presses it and sends waves out from Home, and a beat makes the tiles hop
    //   and rings the fabric (the spectrum is leased only while Overdrive drives, the orbit is shown and
    //   something plays).
    // - The pointer has mass: it dents the fabric where it hovers.
    // - A tile drifting in front of Home eclipses it: Home dims and a corona shows round it.
    readonly property int driftPeriod: 45000
    IdleLoop { id: drift; scope: root; name: "orbit.drift"; period: root.driftPeriod }
    IdleLoop { id: bobLoop; scope: root; name: "orbit.bob"; period: 7400 }
    // Inner periods since the engine engaged; reset at rest, so each ignition starts from the stored places.
    readonly property real orbitTime: drift.turns + drift.phase
    Connections {
        target: Motion
        function onEngagedChanged() {
            if (!Motion.engaged) {
                drift.turns = 0;
                drift.phase = 0;
            }
        }
    }
    function wrapSigned(a) {
        const t = Orbit.wrap(a);
        return t > Math.PI ? t - 2 * Math.PI : t;
    }
    // The laws of the orbit (view/overdrive/OrbitLaws.qml): its shape comes from how it has been used.
    readonly property Item laws: lawsLayer.item
    function driftOf(k) {
        if (Motion.drive <= 0 || !(radii[k] > 0))
            return 0;
        // The room you live in is tidally locked: it keeps its place on the orbit.
        const spin = laws?.isLocked(k) ? 0 : wrapSigned(2 * Math.PI * orbitTime * Math.pow((radii[0] ?? 1) / radii[k], 1.5));
        const moved = spin + (laws?.properOf(k) ?? 0);
        return (moved + (laws?.resonanceOf(k, moved) ?? 0)) * Motion.drive;
    }
    // A system's float above its height, in px (RoomSystems adds it), and its moons' turn (SpaceSystem.spin).
    function systemBob(id) {
        if (Motion.drive <= 0)
            return 0;
        const k = Math.max(0, roomAt(id));
        return Math.sin(2 * Math.PI * (bobLoop.phase + k / rooms.length)) * tileH * 0.22 * Motion.drive * (1 + 0.6 * beat.value);
    }
    function moonSpin(id) {
        if (Motion.drive <= 0)
            return 0;
        const k = Math.max(0, roomAt(id));
        return wrapSigned(2 * Math.PI * orbitTime * (1.6 + 0.15 * k) * (k % 2 === 0 ? 1 : -1)) * Motion.drive;
    }
    // The music (Overdrive only): the bass level (0..1, quick attack, slow decay) and a beat on its onsets.
    readonly property var media: host?.media ?? null
    readonly property bool listening: Motion.driving && root.visible && ViewState.ambientEnabled && (media?.active?.playing ?? false)
    HostLease { domain: root.media; feature: "spectrum"; active: root.listening }
    property real bass: 0
    property real bassAverage: 0
    property double lastBeat: 0
    readonly property var spectrum: root.listening ? (media?.spectrum ?? []) : []
    onSpectrumChanged: {
        const bins = root.spectrum;
        if (!bins || bins.length === 0) {
            root.bass = 0;
            root.bassAverage = 0;
            return;
        }
        let sum = 0;
        const n = Math.min(6, bins.length);
        for (let i = 0; i < n; i++) sum += bins[i];
        const level = sum / n;
        root.bass = level > root.bass ? level : root.bass * 0.86 + level * 0.14;
        root.bassAverage = root.bassAverage * 0.94 + level * 0.06;
        const now = Date.now();
        if (level > root.bassAverage + 0.16 && level > 0.3 && now - root.lastBeat > 240) {
            root.lastBeat = now;
            beat.trigger();
            fabric.rippleFrom(root.cx, root.cy, root.tileH * (0.35 + 0.5 * level));
        }
    }
    Pulse {
        id: beat
        name: "orbit.beat"
        scope: root
        attack: Motion.scaled(45)
        release: Motion.scaled(300)
        attackEasing: Easing.OutCubic
        releaseEasing: Easing.OutQuad
    }
    // The pointer as a mass, in the scene's coordinates (null while it isn't over the orbit or in Silent).
    HoverHandler {
        id: pointer
        enabled: Motion.engaged
    }
    readonly property var pointerMass: pointer.hovered && Motion.drive > 0
        ? { x: camX + (pointer.point.position.x - width / 2) / camS, y: camY + (pointer.point.position.y - height / 2) / camS }
        : null
    // The pointer pulls the tiles near it towards it a little (0 in Silent).
    function leanOf(px, py) {
        const m = pointerMass;
        if (!m)
            return Qt.point(0, 0);
        const dx = m.x - px, dy = m.y - py, d = Math.max(1, Math.hypot(dx, dy));
        const pull = 9 * Motion.drive * Math.exp(-(d * d) / (2 * 150 * 150));
        return Qt.point(dx / d * pull, dy / d * pull);
    }
    // The eclipse: how much of Home the nearest tile drifting in front of it covers (0..1).
    readonly property real eclipse: {
        if (Motion.drive <= 0)
            return 0;
        const h = rectOf("home");
        let most = 0;
        for (let k = 0; k < rooms.length; k++) {
            const p = place(k);
            if (p.z <= 0)
                continue;
            const r = rectOf(rooms[k].id);
            const w = Math.min(h.x + h.w, r.x + r.w) - Math.max(h.x, r.x);
            const v = Math.min(h.y + h.h, r.y + r.h) - Math.max(h.y, r.y);
            if (w > 0 && v > 0)
                most = Math.max(most, (w * v) / (h.w * h.h));
        }
        return Math.min(1, most * 2.2);
    }
    readonly property var homePoint: {
        const p = Orbit.point(0, homeLift * Math.min(1, rise * 2), 0, camView);
        const b = laws?.barycentre ?? Qt.point(0, 0);
        return { x: cx + p.x + b.x, y: cy + p.y + b.y, k: p.k };
    }
    // The other systems (docs/ORBIT.md §0): one per room, on a ring of eight slots around the main system,
    // each in the slot nearest the direction from Home out through its own planet (the rooms sorted by
    // that direction, the ring turned to fit them best), so the routes out stay short and do not cross.
    // The diagonal slots reach a little further, round the main system's corners.
    readonly property real systemOuter: Math.round(outer * 0.48) // wide enough that the back moons clear the sun
    readonly property real systemHalfW: systemOuter + tileW * 0.55
    readonly property real systemHalfH: systemOuter * 0.75 + tileH * 1.25
    function outward(id) {
        const k = roomAt(id);
        const g = Orbit.project(radii[k] ?? 0, placed[k] ?? 0, 0, 0, restView, 0);
        const len = Math.hypot(g.x, g.y) || 1;
        return { x: g.x / len, y: g.y / len };
    }
    readonly property var systemAngles: {
        const phi = rooms.map(p => { const o = outward(p.id); return Math.atan2(o.y, o.x); });
        const order = rooms.map((p, k) => k).sort((a, b) => phi[a] - phi[b]);
        const step = 2 * Math.PI / Math.max(1, order.length);
        let sx = 0, sy = 0;
        order.forEach((k, j) => { sx += Math.cos(phi[k] - j * step); sy += Math.sin(phi[k] - j * step); });
        const turn = Math.atan2(sy, sx), out = {};
        order.forEach((k, j) => out[rooms[k].id] = turn + j * step);
        return out;
    }
    function systemCentre(id) {
        const t = systemAngles[id] ?? 0, bulge = 1 + 0.3 * Math.abs(Math.sin(2 * t));
        const rx = (outer * 1.1 + tileW * 0.6 + systemHalfW + 40) * bulge;
        const ry = (outer * 0.92 + lift + systemHalfH + 30) * bulge;
        // A raised system below the main one stands further down, so its height doesn't bring it closer.
        return { x: cx + Math.cos(t) * rx, y: cy + Math.sin(t) * ry + systemAltitude(id) * Math.max(0, Math.sin(t)) };
    }
    // Where the main system's centre is on screen, through the camera, and whether it is out of sight.
    readonly property real homeScreenX: width / 2 + (cx - camX) * camS
    readonly property real homeScreenY: height / 2 + (cy - camY) * camS
    readonly property bool lost: homeScreenX < -40 || homeScreenX > width + 40 || homeScreenY < -40 || homeScreenY > height + 40 || camS < 0.6

    // A room's tile as drawn, in orbit coordinates: { x, y, w, h }. A tile stands on its stalk, so its
    // bottom edge is at the stalk's top.
    // Worked out once per change, like `places`: the camera, the lens, the eclipse and the laws ask for these many
    // times a frame in flight. Home's rect also stands for an id that isn't a room.
    readonly property var homeRect: {
        const h = homePoint;
        return { x: h.x - homeW * h.k / 2, y: h.y - homeH * h.k, w: homeW * h.k, h: homeH * h.k };
    }
    function roomRectNow(k) {
        const p = place(k), size = sizes[k];
        return { x: p.x - size.w * p.scale / 2, y: p.y - size.h * p.scale, w: size.w * p.scale, h: size.h * p.scale };
    }
    readonly property var roomRects: places.map((p, k) => roomRectNow(k))
    function rectOf(id) {
        const k = roomAt(id);
        return k < 0 ? homeRect : (roomRects[k] ?? roomRectNow(k));
    }

    function indexOf(id) {
        return roomAt(id) + 1;
    }
    function tileAt(i) {
        return i === 0 ? home : tileRepeater.itemAt(i - 1);
    }
    function choose(i) {
        const entry = pages[i];
        if (!entry)
            return;
        rippleAt(entry.id);
        chosen(entry.id);
    }
    // A ripple across the fabric from a room's place on the plane (a choice, a switch's start).
    function rippleAt(id) {
        const k = rooms.findIndex(p => p.id === id);
        const p = k < 0 ? { gx: cx, gy: cy } : place(k);
        fabric.rippleFrom(p.gx, p.gy, tileH * (k < 0 ? 0.6 : 0.45));
    }
    onStreakToChanged: if (streakTo !== "") rippleAt(streakTo)

    // Zooming in to enter: the tile (a room's, Home's or a system's sun) under the zoom's point, and how
    // far the zoom has gone towards entering it: 0 at a third of the field's width, 1 at three fifths,
    // where the Shell dives in. { id, name, progress } or null.
    property point zoomPoint: Qt.point(width / 2, height / 2)
    function screenRect(r) {
        return { x: width / 2 + (r.x - camX) * camS, y: height / 2 + (r.y - camY) * camS, w: r.w * camS, h: r.h * camS };
    }
    readonly property var enterCandidate: {
        if (camS < 1.3)
            return null;
        const ids = pages.map(p => p.id);
        const rects = ids.map(id => ({ id: id, r: screenRect(rectOf(id)) }));
        for (const id of ids.slice(1)) {
            const sun = systems[id]?.sunRect;
            if (sun)
                rects.push({ id: id, r: screenRect(sun) });
        }
        const px = zoomPoint.x, py = zoomPoint.y;
        let best = null, bestD = Infinity;
        for (const c of rects) {
            const r = c.r;
            const inside = px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h;
            const d = inside ? 0 : Math.hypot(r.x + r.w / 2 - px, r.y + r.h / 2 - py);
            if (r.w > width / 3 * 0.75 && d < bestD) { best = c; bestD = d; }
        }
        if (!best || bestD > best.r.w)
            return null;
        const progress = Math.max(0, Math.min(1, (best.r.w / width - 1 / 3) / (0.6 - 1 / 3)));
        const k = indexOf(best.id);
        return progress > 0 ? { id: best.id, name: String(k).padStart(2, "0") + "  " + (pages[k]?.name ?? "").toUpperCase(), progress: progress } : null;
    }
    // The nearest of `rects` from rects[from] in `direction` (FocusMap, the shell's own picker); a system is
    // round, so a 45° cone can come up empty, and then it takes the nearest one ahead at all. -1: none.
    function pickAhead(rects, from, direction) {
        const next = FocusMap.pick(rects[from], rects, direction);
        if (next >= 0)
            return next;
        const d = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] }[direction];
        const c = r => ({ x: r.x + r.width / 2, y: r.y + r.height / 2 });
        const o = c(rects[from]);
        let best = Infinity, found = -1;
        rects.forEach((r, i) => {
            const p = c(r), along = (p.x - o.x) * d[0] + (p.y - o.y) * d[1];
            const distance = Math.hypot(p.x - o.x, p.y - o.y);
            if (i !== from && along > 0 && distance < best) { best = distance; found = i; }
        });
        return found;
    }
    function rectIn(item) {
        return item ? item.mapToItem(root, 0, 0, item.width, item.height) : Qt.rect(0, 0, 0, 0);
    }
    // Arrows move to the nearest tile on screen in that direction.
    function move(direction) {
        const next = pickAhead(pages.map((p, i) => rectIn(tileAt(i))), focusIndex, direction);
        if (next >= 0)
            focusIndex = next;
        hoverIndex = -1;
    }

    // The keyboard inside a room's own system (M6: the keyboard reaches every control). From a highlighted
    // room tile, S steps into that room's system: the camera frames it, the arrows (and Tab) walk its sun and
    // moons, Enter or Space acts as a click, and Esc steps back out to the planet. "" when not in one.
    property string systemFocus: ""
    readonly property Item keySystem: systemFocus !== "" ? (systems[systemFocus] ?? null) : null
    // What the keyboard is on inside the system, in words, for the readout.
    readonly property string keyName: {
        const s = keySystem;
        if (!s || s.keyIndex < -1)
            return "";
        return s.keyIndex === -1 ? "THE SUN  ·  ENTERS THE ROOM" : String(s.moons[s.keyIndex]?.name ?? "").toUpperCase();
    }
    // The tiles a key can reach in the system: the sun (-1), then each moon whose control works here.
    function keyTargets(s) {
        const out = [-1];
        for (let i = 0; i < s.moons.length; i++)
            if (s.moonEnabled(i))
                out.push(i);
        return out;
    }
    function keyItem(s, k) {
        return k === -1 ? s.sunItem : s.moonTiles.itemAt(k);
    }
    function enterSystem() {
        const id = pages[focusIndex]?.id ?? "";
        const s = focusIndex > 0 ? (systems[id] ?? null) : null;
        if (!s)
            return false;
        if (keySystem && keySystem !== s)
            keySystem.keyIndex = -2;
        systemFocus = id;
        hoverIndex = -1;
        s.keyIndex = -1;
        Feedback.play("orbit.hover");
        frameBox(systemBox(id));
        return true;
    }
    function exitSystem() {
        const s = keySystem;
        if (s)
            s.keyIndex = -2;
        if (systemFocus !== "")
            focusIndex = indexOf(systemFocus);
        systemFocus = "";
        recentre();
    }
    function walkSystem(direction) {
        const s = keySystem;
        if (!s)
            return;
        const targets = keyTargets(s);
        const from = Math.max(0, targets.indexOf(s.keyIndex));
        const next = pickAhead(targets.map(k => rectIn(keyItem(s, k))), from, direction);
        if (next >= 0 && targets[next] !== s.keyIndex) {
            s.keyIndex = targets[next];
            Feedback.play("orbit.hover");
        }
    }
    function stepSystem(delta) {
        const s = keySystem;
        if (!s)
            return;
        const targets = keyTargets(s);
        const at = Math.max(0, targets.indexOf(s.keyIndex));
        s.keyIndex = targets[(at + delta + targets.length) % targets.length];
        Feedback.play("orbit.hover");
    }
    function actSystem() {
        keySystem?.keyAct();
    }
    // Type to fly: the moon named by `words` ("wifi", "timers stopwatch", "ws 3"), or null. A leading room word
    // (its id, name or number) keeps the search to that room's system; then a moon's name matches exactly,
    // by prefix, then anywhere, or by its number. The first room in index order wins a tie. { room, key }.
    function findMoon(words) {
        const q = String(words).trim().toLowerCase();
        const first = q.split(/\s+/)[0], rest = q.slice(first.length).trim();
        const room = rooms.find(p => p.id === first || p.name.toLowerCase() === first || String(indexOf(p.id)) === String(Number(first)) && /^\d+$/.test(first));
        const ids = room && rest !== "" ? [room.id] : rooms.map(p => p.id);
        const want = room && rest !== "" ? rest : q;
        let best = null;
        for (const id of ids) {
            const s = systems[id];
            if (!s)
                continue;
            s.moons.forEach((m, i) => {
                if (!s.moonEnabled(i))
                    return;
                const name = String(m.name ?? "").toLowerCase(), number = String(m.number ?? "").toLowerCase();
                // A number names a numbered moon (a desk, a clip) before any name containing it.
                const numbered = /^\d+$/.test(want) && /^\d+$/.test(number) && Number(number) === Number(want);
                const score = numbered || name === want ? 0 : name.startsWith(want) ? 1 : name.includes(want) ? 2 : 9;
                if (score < 9 && (!best || score < best.score))
                    best = { room: id, key: i, score: score };
            });
        }
        return best;
    }
    // A search waits for the systems (built once the orbit is open and still); `missed` says what found nothing.
    property string seeking: ""
    property string missed: ""
    function seek(words) {
        seeking = words;
        missed = "";
        trySeek();
    }
    function trySeek() {
        if (seeking === "" || !roomSystems)
            return;
        const found = findMoon(seeking);
        if (!found) {
            missed = seeking;
            Feedback.play("ui.error");
        } else {
            focusIndex = indexOf(found.room);
            enterSystem();
            keySystem.keyIndex = found.key;
        }
        seeking = "";
    }
    // Later in the same turn: `systems` follows `roomSystems` by a binding that may not have run yet.
    onRoomSystemsChanged: Qt.callLater(trySeek)
    function step(delta) {
        focusIndex = (focusIndex + delta + pages.length) % pages.length;
        hoverIndex = -1;
    }
    // Opening starts on the room you came from.
    function reset() {
        if (keySystem)
            keySystem.keyIndex = -2;
        systemFocus = "";
        focusIndex = indexOf(current);
        hoverIndex = -1;
    }
    onVisibleChanged: if (visible) reset()
    // In flight the highlight follows the room being flown to.
    onCurrentChanged: if (!interactive) reset()
    Component.onCompleted: {
        reset();
        if (spacious)
            systemsWanted = true;
    }
    // A new highlight ticks (at most every 60 ms, so a sweep of the pointer is not a buzz) and slides the
    // readout in.
    property real lastTick: 0
    onHighlightIndexChanged: {
        missed = "";
        if (!interactive)
            return;
        const now = Date.now();
        if (now - lastTick > 60) {
            Feedback.play("orbit.hover");
            lastTick = now;
        }
        if (Motion.live(root))
            slideIn.restart();
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_E && !event.isAutoRepeat)
            root.laws?.letGo();
        if (event.key === Qt.Key_C && !event.isAutoRepeat) {
            root.chording = false;
            root.chordFirst = "";
        }
    }
    // What each room stands on, for its error bracket on the tile (OrbitTile.doubt).
    function sourcesOf(room) {
        const h = root.host, c = root.core;
        if (!h) return [];
        return ({ media: [h.media?.available], performance: [h.system?.cpu?.available, h.system?.memory?.available], workspaces: [h.workspaces?.available],
                  devices: [h.network?.available, h.bluetooth?.available, h.power?.battery?.available], tasks: [c?.connected], timers: [c?.connected],
                  clipboard: [h.clipboard?.available], notifications: [h.notifications?.available] })[room] ?? [];
    }
    signal sheet()
    // The False Room was entered with this set of conditions (W1).
    signal falseRoom(string signature)
    // The heavy layer is drawing the sky, so the panel stops drawing one over it.
    property bool spaceBelow: false
    property bool chording: false
    property string chordFirst: ""
    property var chordPair: []
    Stratum {
        name: "chord"
        gpu: false
        scope: root
        wanted: root.chording || root.chordPair.length === 2
        anchors.fill: parent
        z: 30
        sourceComponent: ChordPlane {
            host: root.host
            core: root.core
            first: root.chordFirst
            pair: root.chordPair
            chording: root.chording
            names: root.pages.reduce((all, p) => { all[p.id] = p.name; return all; }, ({}))  // no Object.fromEntries in Qt's JS engine
            onClosed: root.chordPair = []
        }
    }
    Keys.onPressed: event => {
        const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        const arrows = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" };
        const letters = { h: "left", j: "down", k: "up", l: "right" };
        const direction = arrows[event.key] ?? (plain ? letters[event.text] : undefined);
        // Inside a room's system the walking keys stay in it; the rest (0–8, G, F, zoom) still work.
        if (keySystem) {
            let used = true;
            if (direction) walkSystem(direction);
            else if (event.key === Qt.Key_Tab || (plain && event.text === "]")) stepSystem(1);
            else if (event.key === Qt.Key_Backtab || (plain && event.text === "[")) stepSystem(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) actSystem();
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Home || (plain && ["s", "S", "."].includes(event.text))) exitSystem();
            else used = false;
            if (used) {
                event.accepted = true;
                return;
            }
        }
        // The contact sheet (M14): every desk at a glance.
        if (plain && (event.text === "w" || event.text === "W")) {
            root.sheet();
            event.accepted = true;
            return;
        }
        // Chords (Overdrive): hold C and tap two rooms (ChordPlane); Esc closes the plane.
        if (root.laws && plain && (event.text === "c" || event.text === "C")) {
            if (!event.isAutoRepeat) {
                root.chording = true;
                root.chordFirst = "";
            }
            event.accepted = true;
            return;
        }
        if (root.chording && plain && event.text >= "0" && event.text <= "9" && Number(event.text) < pages.length) {
            const chosenRoom = pages[Number(event.text)].id;
            if (root.chordFirst === "")
                root.chordFirst = chosenRoom;
            else if (chosenRoom !== root.chordFirst) {
                root.chordPair = [root.chordFirst, chosenRoom];
                root.chordFirst = "";
                Feedback.play("foley.relay");
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape && root.chordPair.length > 0) {
            root.chordPair = [];
            event.accepted = true;
            return;
        }
        if (direction) {
            move(direction);
        } else if (event.key === Qt.Key_Tab || (plain && event.text === "]")) {
            step(1);
        } else if (event.key === Qt.Key_Backtab || (plain && event.text === "[")) {
            step(-1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            choose(focusIndex);
        } else if (plain && event.text >= "0" && event.text <= "9" && Number(event.text) < pages.length) {
            choose(Number(event.text));
        } else if ((plain && event.text === ".") || event.key === Qt.Key_Home) {
            recentre();
        } else if (plain && (event.text === "f" || event.text === "F")) {
            ViewState.fullscreen = !ViewState.fullscreen;
        } else if (plain && (event.text === "s" || event.text === "S")) {
            enterSystem();
        } else if (plain && (event.text === "g" || event.text === "G")) {
            galaxy();
        } else if (plain && (event.text === "e" || event.text === "E") && root.laws) {
            // Held: the highlighted room's day, unfolded (the release is below).
            if (!event.isAutoRepeat)
                root.laws.hold(root.highlighted?.id ?? "home");
        } else if (plain && event.text === "-") {
            zoomStep(1 / 1.3);
        } else if (plain && (event.text === "=" || event.text === "+")) {
            zoomStep(1.3);
        } else {
            // Escape and the rest go up to the Shell (Escape leaves the overview).
            return;
        }
        event.accepted = true;
    }

    // Overdrive's deep space behind everything: parallax stars that follow the camera and twinkle (a GPU stratum).
    IdleLoop { id: twinkle; scope: root; name: "orbit.twinkle"; period: 9000 }
    Stratum {
        name: "starfield"
        scope: root
        wanted: !root.spaceBelow
        anchors.fill: parent
        z: -10
        sourceComponent: Starfield {
            camX: root.camX
            camY: root.camY
            camS: root.camS
            twinklePhase: twinkle.phase
        }
    }
    // Comets (docs/OVERDRIVE.md §8): a new notification, while Overdrive drives and the orbit is shown, crosses
    // space as a comet that bends round Home and falls into the Inbox tile, which rings the fabric. It carries
    // nothing of the notification: only the count going up is read, never its text or its app.
    readonly property int notificationCount: host?.notifications?.items?.length ?? 0
    property int lastNotificationCount: notificationCount
    onNotificationCountChanged: {
        const more = notificationCount > lastNotificationCount;
        lastNotificationCount = notificationCount;
        if (more && Motion.driving && Motion.live(root))
            comet.launch();
    }
    // The comet's path, in the scene: from beyond the galaxy's edge, bowed past Home, to the Inbox tile.
    QtObject {
        id: comet
        property real t: 0
        property real fromAngle: 0
        readonly property bool flying: cometRun.running
        function launch() {
            fromAngle = Math.random() * 2 * Math.PI;
            cometRun.restart();
        }
        function at(u) {
            const g = root.galaxyBounds();
            const reach = Math.max(g.x1 - g.x0, g.y1 - g.y0) * 0.75;
            const a = { x: root.cx + Math.cos(fromAngle) * reach, y: root.cy + Math.sin(fromAngle) * reach * 0.7 };
            const r = root.rectOf("notifications");
            const b = { x: r.x + r.w / 2, y: r.y + r.h / 2 };
            // The control point passes Home on the far side of the line, so the path bends round the main well.
            const c = { x: root.cx + (root.cx - (a.x + b.x) / 2) * 0.35, y: root.cy - root.outer * 0.5 };
            const v = 1 - u;
            return { x: v * v * a.x + 2 * v * u * c.x + u * u * b.x, y: v * v * a.y + 2 * v * u * c.y + u * u * b.y };
        }
    }
    NumberAnimation {
        id: cometRun
        target: comet
        property: "t"
        from: 0
        to: 1
        duration: Motion.scaled(1900)
        easing.type: Easing.InQuad
        onFinished: {
            const k = root.rooms.findIndex(p => p.id === "notifications");
            if (k >= 0) {
                root.rippleAt("notifications");
                beat.trigger();
            }
        }
    }
    Activity { name: "orbit.comet"; running: cometRun.running }

    // The fabric's masses (below): Home, the pointer, each room, each system's sun and moons, the laws' shelves.
    function fabricMasses() {
        return [
            { x: root.cx, y: root.cy, depth: root.outer * 0.6 * (1 + 0.45 * root.bass * Motion.drive), radius: root.outer * 0.5 },
            ...(root.pointerMass ? [{ x: root.pointerMass.x, y: root.pointerMass.y, depth: root.tileH * 0.9 * Motion.drive, radius: root.tileW * 0.7 }] : []),
            ...root.rooms.map((p, k) => {
                const at = root.place(k), own = p.id === root.current;
                return { x: at.gx, y: at.gy, depth: root.tileH * (own ? 1.2 : 0.8), radius: root.tileW * 0.65 };
            }),
            ...root.rooms.map(p => {
                const c = root.systemCentre(p.id);
                return { x: c.x, y: c.y, depth: root.outer * 0.32, radius: root.systemOuter * 0.7 };
            }),
            ...(root.roomSystems?.moonFeet() ?? []).map(f => ({ x: f.x, y: f.y, depth: root.tileH * 0.6 * systemsLoader.shown, radius: root.tileW * 0.45 })),
            ...(root.laws?.fabricMasses ?? [])
        ];
    }
    property var frameMasses: []
    FrameAnimation {
        running: Motion.drive > 0 && root.visible
        onRunningChanged: if (!running) root.frameMasses = []
        onTriggered: root.frameMasses = root.fabricMasses()
    }
    // The scene, through the camera: everything but the readout, which stays put while the camera pans.
    // Its coordinates are the system's (rectOf, place): the camera maps them to the field.
    Item {
        id: scene
        width: root.width
        height: root.height
        transform: [
            Translate { x: -root.camX; y: -root.camY },
            Scale { xScale: root.camS; yScale: root.camS },
            Translate { x: root.width / 2; y: root.height / 2 }
        ]
    // The spacetime fabric under the plane, pressed by every mass: Home, each room, each system's sun,
    // and each of their moons, a little, deepening as the systems fade in.
    SpaceFabric {
        id: fabric
        z: -1
        readonly property var galaxy: root.galaxyBounds()
        centreX: root.cx
        centreY: root.cy
        elevation: root.elevation
        gridStep: Math.max(24, Math.round(root.outer / 6))
        depthUnder: root.lift * 0.5
        halfSize: Math.max(galaxy.x1 - root.cx, root.cx - galaxy.x0, (galaxy.y1 - root.cy) / 0.7, (root.cy - galaxy.y0) / 0.7) * 1.7
        opacity: Math.min(1, root.rise)
        breath: bobLoop.phase
        alive: Motion.drive
        bass: root.bass
        // In Overdrive everything here moves every frame, and as a binding the list was rebuilt (with its 80 wells) once
        // for each loop's tick, about nine times a frame; so there it is taken once a frame instead.
        masses: Motion.drive > 0 && root.frameMasses.length > 0 ? root.frameMasses : root.fabricMasses()
    }

    // The orbit's laws: shelves, routes, ghosts, the ephemeris; only in Overdrive.
    Stratum {
        id: lawsLayer
        name: "laws"
        gpu: false
        scope: root
        z: 1.5
        width: scene.width
        height: scene.height
        sourceComponent: OrbitLaws {
            orbit: root
            journey: root.core?.journeyData ?? null
        }
    }
    // The False Room (W1, view/overdrive/FalseRoom.qml): out past the outermost room where the survey errors point.
    Stratum {
        name: "falseroom"
        gpu: false
        scope: root
        z: 1.6
        width: scene.width
        height: scene.height
        wanted: F.sighted(ViewState.fieldBook)
        sourceComponent: FalseRoom {
            orbit: root
            book: ViewState.fieldBook
            journey: root.core?.journeyData ?? null
            battery: root.host?.power?.battery ?? null
            playing: root.host?.media?.active?.playing ?? false
            spent: ViewState.falseRoomSpent
            onEntered: signature => root.falseRoom(signature)
        }
    }
    // The comet: a hot head and a tail of fading dots behind it along its path.
    Item {
        z: 6
        visible: comet.flying
        Repeater {
            model: comet.flying ? 22 : 0
            Rectangle {
                required property int index
                readonly property real u: Math.max(0, comet.t - index * 0.012)
                readonly property var q: comet.at(u)
                readonly property real size: (index === 0 ? 9 : Math.max(1.5, 7 - index * 0.28)) / Math.max(0.3, root.camS)
                x: q.x - size / 2
                y: q.y - size / 2
                width: size
                height: size
                radius: size / 2
                color: index === 0 ? Design.ink : index < 6 ? Design.accent : Design.warm
                opacity: (index === 0 ? 1 : 0.85 * (1 - index / 22)) * Math.min(1, comet.t * 8)
            }
        }
    }

    // The orbits on the plane, through the camera: the far half faint and dashed, the near half stronger.
    // The current room's orbit is in the signal colour, the highlighted one's in ink. Each fades in with
    // its tile's rise.
    // Drawn round (0, 0) and moved to the centre. The tilt swings in flight, so the outlines are rebuilt every frame
    // there: at half the steps (5° a segment, under a pixel off a true ellipse at these radii), and full again at rest.
    Shape {
        id: orbits
        x: root.cx
        y: root.cy
        z: 0
        preferredRendererType: Shape.CurveRenderer
        readonly property int steps: root.elevation === Orbit.ELEVATION ? 72 : 36
        readonly property var outlines: root.radii.map(r => Orbit.outline(r, 0, 0, root.camView, steps))
        Instantiator {
            model: root.rooms.length
            delegate: ShapePath {
                required property int index
                readonly property bool own: root.rooms[index]?.id === root.current
                readonly property bool lit: root.highlightIndex === index + 1
                readonly property real shown: Math.min(1, root.riseOf(index))
                strokeColor: Qt.alpha(own ? Design.accent : lit ? Design.ink : Design.line, (own || lit ? 0.55 : 0.4) * shown)
                strokeWidth: own ? 1.5 : 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 5]
                fillColor: "transparent"
                PathPolyline { path: (orbits.outlines[index]?.back ?? []).map(p => Qt.point(p.x, p.y)) }
            }
            onObjectAdded: (index, object) => orbits.data.push(object)
        }
        Instantiator {
            model: root.rooms.length
            delegate: ShapePath {
                required property int index
                readonly property bool own: root.rooms[index]?.id === root.current
                readonly property bool lit: root.highlightIndex === index + 1
                readonly property real shown: Math.min(1, root.riseOf(index))
                strokeColor: Qt.alpha(own ? Design.accent : lit ? Design.ink : Design.line, shown)
                strokeWidth: own ? 2.5 : lit ? 2 : 1.25
                strokeStyle: own || lit ? ShapePath.SolidLine : ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: "transparent"
                PathPolyline { path: (orbits.outlines[index]?.front ?? []).map(p => Qt.point(p.x, p.y)) }
            }
            onObjectAdded: (index, object) => orbits.data.push(object)
        }
    }

    // Shadows on the plane and the stalks up to the tiles. A stalk draws just under its own tile, so a
    // nearer tile still covers a farther tile's stalk.
    Repeater {
        model: root.rooms.length
        Item {
            id: post
            required property int index
            readonly property var p: root.place(index)
            readonly property var size: root.sizes[index] ?? ({ w: 0, h: 0 })
            readonly property Item tile: tileRepeater.itemAt(index)
            readonly property real hover: tile ? tile.lit : 0
            // Overdrive: a habit bends the stalk towards the rooms it binds this one to.
            readonly property point pull: root.laws ? root.laws.pullOf(index) : Qt.point(0, 0)
            readonly property real topX: p.x + pull.x
            readonly property real topY: p.y - 6 * hover + pull.y
            z: 2 + p.depth - 0.001
            opacity: p.opacity * Math.min(1, root.riseOf(index))
            Rectangle {
                // The shadow: a flattened ellipse at the foot, sized by the tile and the tilt.
                readonly property real w: post.size.w * 0.62 * post.p.scale
                x: post.p.gx - width / 2
                y: post.p.gy - height / 2
                width: w
                height: w * root.camView.sin * 0.5
                radius: height / 2
                color: Qt.alpha("black", 0.3 + 0.15 * post.hover)
            }
            Rectangle {
                // The stalk, from the foot up to the tile, leaning to 78° as the tiles' edges do.
                readonly property real len: Math.hypot(post.topX - post.p.gx, post.topY - post.p.gy)
                x: post.p.gx - width / 2
                y: post.p.gy - len
                width: post.hover > 0.5 ? 2 : 1.5
                height: len
                transformOrigin: Item.Bottom
                rotation: Math.atan2(post.topX - post.p.gx, post.p.gy - post.topY) * 180 / Math.PI
                color: post.hover > 0.5 ? Design.accent : Qt.alpha(Design.line, 0.9)
            }
            Rectangle {
                // The foot: a small square node on the orbit.
                x: post.p.gx - width / 2
                y: post.p.gy - height / 2
                width: 5
                height: 5
                rotation: 45
                color: post.hover > 0.5 || root.rooms[post.index]?.id === root.current ? Design.accent : Design.line
            }
        }
    }

    // Home, at the centre: the clock and the resident, on ink, floating over its shadow.
    Rectangle {
        readonly property real w: root.homeW * 0.7 * root.homePoint.k
        readonly property var foot: Orbit.point(0, 0, 0, root.camView)
        x: root.cx + foot.x - width / 2
        y: root.cy + foot.y - height / 2
        z: 1
        width: w
        height: w * root.camView.sin * 0.5
        radius: height / 2
        color: Qt.alpha("black", 0.35)
    }
    AbstractButton {
        id: home
        // The same sweep and lift as a room's tile (OrbitTile), on ink.
        property real lit: root.highlightIndex === 0 ? 1 : 0
        Tween on lit {
            scope: home
            NumberAnimation { duration: Motion.settle; easing.type: Easing.OutCubic }
        }
        readonly property color ink: lit > 0.5 ? (Design.onSignal ?? Design.background) : homePlane.textColor
        transform: [
            Scale { origin.x: home.width / 2; origin.y: home.height / 2; xScale: 1 + 0.05 * home.lit + 0.04 * beat.value; yScale: 1 + 0.05 * home.lit + 0.04 * beat.value },
            Translate { y: -5 * home.lit }
        ]
        // An eclipse: a tile drifting in front of Home dims it, and its corona shows (docs/OVERDRIVE.md §5).
        opacity: 1 - 0.45 * root.eclipse
        Rectangle {
            z: -1
            visible: root.eclipse > 0.01
            anchors.centerIn: parent
            width: parent.width * (1.18 + 0.12 * root.eclipse)
            height: parent.height * (1.3 + 0.2 * root.eclipse)
            radius: height / 2
            color: "transparent"
            border.width: 2 + 4 * root.eclipse
            border.color: Qt.alpha(Design.warm, 0.85 * root.eclipse)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.16
                height: parent.height * 1.22
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Design.accent, 0.5 * root.eclipse)
            }
        }
        readonly property var r: root.rectOf("home")
        x: r.x + r.w / 2 - width / 2
        y: r.y + r.h / 2 - height / 2
        scale: root.homePoint.k
        z: 2.5
        width: root.homeW
        height: root.homeH
        enabled: root.interactive
        focusPolicy: Qt.NoFocus
        hoverEnabled: true
        padding: 0
        Accessible.name: "00 Home"
        onHoveredChanged: root.hoverIndex = hovered ? 0 : (root.hoverIndex === 0 ? -1 : root.hoverIndex)
        onClicked: root.choose(0)
        background: Item {
            Plane {
                id: homePlane
                anchors.fill: parent
                role: "ink"
                slant: 3
                backing: true
            }
            Plane {
                visible: home.lit > 0
                width: homePlane.run + home.lit * (parent.width - homePlane.run)
                height: parent.height
                role: "signal"
                slant: 3
            }
        }
        contentItem: Item {
            readonly property real run: height * Math.tan(12 * Math.PI / 180)
            FText {
                x: parent.run + 8
                y: 6
                text: "00  HOME"
                technical: true
                font.weight: Font.Bold
                color: home.ink
            }
            FText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 2
                text: Clock.hourStr + ":" + Clock.minuteStr
                headline: true
                font.pixelSize: Math.round(home.height * 0.42) // scale: the clock fills the Home tile, which grows with the field
                font.weight: Font.Black
                color: home.ink
            }
            FText {
                x: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width - 20 - parent.run
                text: Qt.formatDate(Clock.date, "ddd d MMM")
                technical: true
                color: home.ink
                opacity: 0.8
            }
        }
    }

    Repeater {
        id: tileRepeater
        model: root.rooms.length
        OrbitTile {
            required property int index
            readonly property var p: root.place(index)
            entry: root.rooms[index]
            number: String(index + 1).padStart(2, "0")
            width: root.sizes[index]?.w ?? 0
            height: root.sizes[index]?.h ?? 0
            // Standing on the stalk: the scaled tile's bottom edge at the stalk's top.
            x: p.x - width / 2
            y: p.y - height / 2 - height * p.scale / 2
            scale: p.scale
            opacity: p.opacity * Math.min(1, root.riseOf(index) * 1.5)
            z: 2 + p.depth + lit
            current: entry?.id === root.current
            enabled: root.interactive
            highlighted: root.highlightIndex === index + 1 && root.systemFocus === ""
            // Faces are made once the overview is open and still, as the systems are: never for a switch's flight.
            lean: {
                const pointer = root.leanOf(x + width / 2, y + height / 2);
                const habit = root.laws ? root.laws.pullOf(index) : Qt.point(0, 0);
                return Qt.point(pointer.x + habit.x, pointer.y + habit.y);
            }
            doubt: Orbit.errorBudget(root.sourcesOf(entry?.id))
            steepness: 1 - Math.sin(root.elevation * Math.PI / 180)
            substitute: root.laws ? root.laws.substituteFor(index) : ""
            shiftTint: root.laws ? root.laws.tintOf(index) : "transparent"
            face: root.systemsWanted ? (root.faces[entry?.id] ?? null) : null
            faceLive: root.visible && root.interactive
            onHoveredChanged: root.hoverIndex = hovered ? index + 1 : (root.hoverIndex === index + 1 ? -1 : root.hoverIndex)
            onClicked: root.choose(index + 1)
        }
    }

    // The routes out to the other systems: a dashed line from each planet's foot to its system's sun.
    Shape {
        id: routes
        z: 0
        visible: systemsLoader.status === Loader.Ready
        opacity: systemsLoader.shown
        preferredRendererType: Shape.CurveRenderer
        Instantiator {
            model: root.rooms.map(p => p.id)
            delegate: ShapePath {
                required property string modelData
                readonly property int k: root.rooms.findIndex(p => p.id === modelData)
                readonly property var from: root.place(k)
                readonly property var to: root.systemCentre(modelData)
                strokeColor: Qt.alpha(Design.accent, 0.45 * Math.min(1, root.rise))
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [1, 6]
                fillColor: "transparent"
                startX: from.gx
                startY: from.gy
                PathLine { x: to.x; y: to.y }
            }
            onObjectAdded: (index, object) => routes.data.push(object)
        }
    }
    Loader {
        id: systemsLoader
        anchors.fill: parent
        active: root.systemsWanted
        asynchronous: true
        // Faded in once built (a Tween, so only as they arrive).
        property real shown: status === Loader.Ready ? 1 : 0
        Tween on shown {
            scope: systemsLoader
            NumberAnimation { duration: Motion.settle; easing.type: Easing.OutCubic }
        }
        opacity: shown
        sourceComponent: Component {
            RoomSystems {
                orbit: root
                host: root.host
                core: root.core
                shell: root.shell
                live: root.visible && root.interactive
                onActed: id => {
                    const c = root.systemCentre(id);
                    fabric.rippleFrom(c.x, c.y, root.tileH * 0.4);
                }
            }
        }
    }

    // The streak: an arc from the room left to the room chosen, bowed away from Home, with a signal head
    // riding it. Drawn only mid-switch.
    Item {
        id: streakLayer
        readonly property bool shown: root.streak > 0 && root.streak < 1 && root.streakFrom !== "" && root.streakTo !== ""
        readonly property var a: { const r = root.rectOf(root.streakFrom); return Qt.point(r.x + r.w / 2, r.y + r.h / 2); }
        readonly property var b: { const r = root.rectOf(root.streakTo); return Qt.point(r.x + r.w / 2, r.y + r.h / 2); }
        // The control point: out from Home through the chord's middle (or square to the chord when the
        // middle sits on Home), far enough that the arc clears Home's tile.
        readonly property var c: {
            const mx = (a.x + b.x) / 2 - root.cx, my = (a.y + b.y) / 2 - root.cy;
            let dx = mx, dy = my, len = Math.hypot(dx, dy);
            if (len < 24) { dx = -(b.y - a.y); dy = b.x - a.x; len = Math.hypot(dx, dy) || 1; }
            const reach = Math.max(Math.hypot(a.x - root.cx, a.y - root.cy), Math.hypot(b.x - root.cx, b.y - root.cy), root.homeW) * 1.3;
            return Qt.point(root.cx + dx / len * reach, root.cy + dy / len * reach);
        }
        function at(u) {
            const v = 1 - u;
            return Qt.point(v * v * a.x + 2 * v * u * c.x + u * u * b.x, v * v * a.y + 2 * v * u * c.y + u * u * b.y);
        }
        readonly property var head: at(root.streak)
        visible: shown
        z: 4
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.accent, 0.55)
                strokeWidth: 2
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]
                fillColor: "transparent"
                startX: streakLayer.a.x
                startY: streakLayer.a.y
                PathQuad { x: streakLayer.b.x; y: streakLayer.b.y; controlX: streakLayer.c.x; controlY: streakLayer.c.y }
            }
            // The trail: the arc up to the head, solid, as a polyline of 24 samples (rebuilt per frame only
            // while the streak flies).
            ShapePath {
                strokeColor: Design.accent
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathPolyline {
                    path: {
                        if (!streakLayer.shown) return [];
                        const out = [];
                        const from = Math.max(0, root.streak - 0.35);
                        for (let k = 0; k <= 24; k++)
                            out.push(streakLayer.at(from + (root.streak - from) * k / 24));
                        return out;
                    }
                }
            }
        }
        Plane {
            x: streakLayer.head.x - width / 2
            y: streakLayer.head.y - height / 2
            width: 30
            height: 16
            role: "signal"
            slant: 3
        }
    }

    }

    // Double-click empty space to glide home. Under the scene's tiles, so they keep their clicks.
    TapHandler {
        enabled: root.interactive
        onDoubleTapped: root.recentre()
    }
    // The way home: when the camera has wandered off (or zoomed far out), a chip on the field's edge points
    // back at Home; click it (or ".", Home, a double-click) to glide back to the whole system.
    Item {
        id: compass
        readonly property real dx: root.homeScreenX - root.width / 2
        readonly property real dy: root.homeScreenY - root.height / 2
        readonly property real angle: Math.atan2(dy, dx)
        // On the edge of the field, inset, along the line towards Home.
        readonly property real reach: Math.min((root.width / 2 - 90) / Math.max(0.001, Math.abs(Math.cos(angle))),
                                               (root.height / 2 - 40) / Math.max(0.001, Math.abs(Math.sin(angle))))
        readonly property bool homeVisible: !(root.homeScreenX < -40 || root.homeScreenX > root.width + 40 || root.homeScreenY < -40 || root.homeScreenY > root.height + 40)
        readonly property bool hovered: compassMouse.containsMouse
        readonly property color ink: hovered ? (Design.onSignal ?? Design.background) : (Design.onInk ?? Design.background)
        visible: root.interactive && root.lost
        z: 10
        x: homeVisible ? root.width / 2 - width / 2 : root.width / 2 + Math.cos(angle) * reach - width / 2
        y: homeVisible ? root.height - height - 16 : root.height / 2 + Math.sin(angle) * reach - height / 2
        width: label.implicitWidth + 46
        height: 28
        Accessible.role: Accessible.Button
        Accessible.name: "Back to Home"
        Plane {
            anchors.fill: parent
            role: compass.hovered ? "signal" : "ink"
            slant: 3
            backing: true
        }
        MaterialSymbol {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "navigation"
            iconSize: 16
            rotation: compass.angle * 180 / Math.PI + 90
            color: compass.ink
        }
        FText {
            id: label
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            text: "HOME  ·  " + Math.round(Math.hypot(compass.dx, compass.dy) / Math.max(0.1, root.camS)) + " LY"
            technical: true
            color: compass.ink
        }
        MouseArea {
            id: compassMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.recentre()
        }
    }

    // Zooming in on a tile: a chip at the top says which room the zoom will enter, filling as it nears.
    Item {
        id: enterHint
        readonly property var c: root.enterCandidate
        visible: root.interactive && c !== null
        z: 10
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: enterLabel.implicitWidth + 40
        height: 28
        Plane {
            anchors.fill: parent
            role: "ink"
            slant: 3
            backing: true
        }
        Plane {
            width: height * Math.tan(12 * Math.PI / 180) + (parent.width - height * Math.tan(12 * Math.PI / 180)) * (enterHint.c?.progress ?? 0)
            height: parent.height
            role: "signal"
            slant: 3
        }
        FText {
            id: enterLabel
            anchors.centerIn: parent
            text: "ZOOM IN TO ENTER  ·  " + (enterHint.c?.name ?? "")
            technical: true
            color: (enterHint.c?.progress ?? 0) > 0.5 ? (Design.onSignal ?? Design.background) : (Design.onInk ?? Design.background)
        }
    }
    // The zoom, on screen: out, the level, in, and the whole galaxy. Bottom right, out of the readout's way.
    Row {
        id: zoomBar
        visible: root.interactive
        z: 10
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 4
        Repeater {
            model: [
                { key: "out", symbol: "remove", label: "Zoom out" },
                { key: "level", symbol: "", label: "Back to the main system" },
                { key: "in", symbol: "add", label: "Zoom in" },
                { key: "all", symbol: "zoom_out_map", label: "Show every system" }
            ]
            Item {
                id: zoomKey
                required property var modelData
                readonly property bool hovered: zoomMouse.containsMouse
                readonly property color ink: hovered ? (Design.onSignal ?? Design.background) : (Design.onInk ?? Design.background)
                width: modelData.key === "level" ? 64 : 34
                height: 28
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Plane {
                    anchors.fill: parent
                    role: zoomKey.hovered ? "signal" : "ink"
                    slant: 3
                    backing: true
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: zoomKey.modelData.symbol !== ""
                    text: zoomKey.modelData.symbol
                    iconSize: 16
                    color: zoomKey.ink
                }
                FText {
                    anchors.centerIn: parent
                    visible: zoomKey.modelData.key === "level"
                    text: Math.round(root.camS * 100) + "%"
                    technical: true
                    color: zoomKey.ink
                }
                MouseArea {
                    id: zoomMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const key = zoomKey.modelData.key;
                        if (key === "out") root.zoomStep(1 / 1.5);
                        else if (key === "in") root.zoomStep(1.5);
                        else if (key === "all") root.galaxy();
                        else root.recentre();
                    }
                }
            }
        }
    }

    // The readout: the highlighted room in words, beside the system (under it when narrow). A new
    // highlight slides it in from the left along 78°.
    Item {
        id: readout
        property real shift: 0
        NumberAnimation {
            id: slideIn
            target: readout
            property: "shift"
            from: 1
            to: 0
            duration: Motion.settle
            easing.type: Easing.OutCubic
        }
        visible: root.interactive
        x: root.compact ? 16 : 24
        y: root.compact ? root.height - height - 8 : (root.height - height) / 2
        width: root.compact ? root.width - 32 : root.cardWidth
        height: root.compact ? 52 : column.implicitHeight
        opacity: 1 - 0.6 * shift
        transform: Translate { x: -24 * readout.shift; y: 24 * readout.shift * Math.tan(12 * Math.PI / 180) }
        // The other systems lie out on every side, so something can always pass behind the readout: its
        // column of the field is backed, top to bottom, with a hairline on its right edge.
        Rectangle {
            visible: !root.compact
            x: -readout.x
            y: -readout.y
            width: readout.x + parent.width + 24
            height: root.height
            color: Design.background
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Qt.alpha(Design.line, 0.5)
            }
        }
        Plane {
            visible: !root.compact
            x: -8
            width: 6
            height: column.implicitHeight
            role: "signal"
            slant: 3
        }
        Column {
            id: column
            visible: !root.compact
            width: parent.width
            spacing: 6
            FText {
                text: String(root.highlightIndex).padStart(2, "0")
                headline: true
                font.pixelSize: Design.display
                font.weight: Font.Black
                color: Design.accent
            }
            FText {
                width: parent.width
                text: root.highlighted?.name ?? ""
                headline: true
                font.pixelSize: Design.headline
                font.weight: Font.Black
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Design.readout
            }
            FText {
                width: parent.width
                text: root.highlighted?.voice ?? ""
                aside: true
                font.pixelSize: Design.readout
                wrapMode: Text.Wrap
                color: Design.muted
            }
            FText {
                width: parent.width
                text: root.highlighted?.about ?? ""
                technical: true
                wrapMode: Text.Wrap
                color: Design.faint
            }
            Item { width: 1; height: 14 }
            FRule { width: parent.width }
            FText {
                width: parent.width
                visible: root.highlighted?.id === root.current
                text: "YOU ARE HERE"
                technical: true
                color: Design.accent
            }
            FText {
                width: parent.width
                visible: root.missed !== ""
                text: "NO MOON CALLED " + root.missed.toUpperCase()
                technical: true
                wrapMode: Text.Wrap
                color: Design.danger
            }
            FText {
                width: parent.width
                visible: root.systemFocus !== ""
                text: "IN ITS SYSTEM  ·  " + root.keyName
                technical: true
                wrapMode: Text.Wrap
                color: Design.accent
            }
            FText {
                width: parent.width
                text: root.systemFocus !== "" ? "ENTER ACTS  ·  ESC STEPS OUT" : "ENTER LANDS  ·  ESC RETURNS"
                technical: true
                color: Design.muted
            }
            FText {
                width: parent.width
                text: root.systemFocus !== "" ? "ARROWS · TAB WALK THE MOONS" : "ARROWS MOVE  ·  0—9 GO  ·  W THE DESKS"
                technical: true
                color: Design.faint
            }
            FText {
                width: parent.width
                text: root.systemFocus !== "" ? "DRAG · WHEEL · G ALL" : "S SYSTEM · G ALL · . HOME"
                technical: true
                color: Design.faint
            }
            FText {
                width: parent.width
                text: "DRAG · WHEEL ZOOMS"
                technical: true
                color: Design.faint
            }
        }
        // Narrow: one line under the system.
        FText {
            visible: root.compact
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: String(root.highlightIndex).padStart(2, "0") + "  " + (root.highlighted?.name ?? "").toUpperCase()
                + (root.systemFocus !== "" ? "  ·  " + root.keyName + "  ·  ENTER ACTS  ·  ESC STEPS OUT"
                   : "  ·  " + (root.highlighted?.about ?? "") + "  ·  ENTER LANDS  ·  S ITS SYSTEM  ·  ESC RETURNS")
            technical: true
            color: Design.ink
        }
    }
}
