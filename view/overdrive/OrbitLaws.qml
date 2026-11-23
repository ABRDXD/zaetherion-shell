import qs.view.cues
import qs.view.ui
import QtQuick
import "../shell/Orbit.js" as Orbit

// The orbit's laws (docs/OVERDRIVE.md §5, OVERDRIVE_IDEAS.md): in Overdrive the system takes its shape from how it
// has been used (the core's journey). Nothing here is decoration: each part is caused by a real habit.
// - Lagrange shelves: two rooms you bounce between grow a small plate at the balance point between their orbits,
//   pushing the fabric up there and saying how often.
// - Dark matter routes: a habit bends the two rooms' stalks towards each other before anything is drawn; once
//   it is strong enough, a hairline appears between them.
// - Proper motion: a room you use more than last week moves ahead of its old place, one you use less falls behind.
//   A ghost tick marks where it used to stand.
// - Resonance: three rooms visited in a repeating loop lock into line along the house's 78° for a few seconds.
// - Tidal locking: the room you spend most time in stops drifting (Claude A's idea).
// - The barycentre: Home is pulled a little towards where your time goes (Claude A's idea).
// - Transits: a tile crossing another's stalk swaps its name for the crossing's readout for 300 ms. No flash.
// - Redshift: moving the keyboard focus tints the tiles it nears cool, and the ones it leaves warm.
// - The folded ephemeris: hold E on a room to unfold its day, hour by hour, as an accordion on the plane.
// A Stratum in the orbit's scene, so all of it exists only in Overdrive; every amount scales with the engine.
Item {
    id: root
    required property Item orbit
    property var journey: null
    readonly property var rooms: orbit.rooms
    function indexOf(id) { return rooms.findIndex(p => p.id === id); }
    readonly property var trend: journey?.trend ?? ({})
    readonly property int lockedIndex: indexOf(journey?.favourite ?? "")
    readonly property var pairs: (journey?.pairs ?? []).map(p => ({ a: indexOf(p.a), b: indexOf(p.b), weight: p.weight })).filter(p => p.a >= 0 && p.b >= 0)
    readonly property int shelfAt: 3      // weight at which two rooms grow a shelf
    readonly property int routeAt: 8      // weight at which a hairline appears
    readonly property var shelves: pairs.filter(p => p.weight >= shelfAt).slice(0, 3)
    readonly property var routes: pairs.filter(p => p.weight >= routeAt)
    // A new shelf is pinned in place, with a sound; the ones already there at creation are not new.
    property int shelvesSeen: -1
    onShelvesChanged: {
        if (shelvesSeen >= 0 && shelves.length > shelvesSeen)
            Feedback.play("foley.pin");
        shelvesSeen = shelves.length;
    }

    // Called by OrbitSystem.driftOf. `spin` is the tile's own orbital offset.
    function isLocked(k) { return k === lockedIndex; }
    function properOf(k) { return (trend[rooms[k]?.id] ?? 0) * 0.35; }
    function resonanceOf(k, offset) {
        if (lock.value <= 0 || !resonant.includes(rooms[k]?.id))
            return 0;
        return lock.value * orbit.wrapSigned(Math.PI / 2 - ((orbit.placed[k] ?? 0) + offset));
    }
    // A tile's stalk leans towards the rooms it is bound to, in scene pixels.
    function pullOf(k) {
        let x = 0, y = 0;
        const here = orbit.place(k);
        for (const p of pairs) {
            if (p.a !== k && p.b !== k)
                continue;
            const there = orbit.place(p.a === k ? p.b : p.a);
            const dx = there.gx - here.gx, dy = there.gy - here.gy, d = Math.max(1, Math.hypot(dx, dy));
            const pull = Math.min(1, p.weight / routeAt) * 9 * Motion.drive;
            x += dx / d * pull;
            y += dy / d * pull;
        }
        return Qt.point(x, y);
    }
    // Home's shift towards where the time goes.
    readonly property point barycentre: {
        const seconds = journey?.seconds ?? {};
        let total = 0, x = 0, y = 0;
        for (let k = 0; k < rooms.length; k++) {
            const s = seconds[rooms[k].id] ?? 0;
            const p = orbit.place(k);
            total += s;
            x += s * (p.gx - orbit.cx);
            y += s * (p.gy - orbit.cy);
        }
        return total > 0 ? Qt.point(x / total * 0.12 * Motion.drive, y / total * 0.12 * Motion.drive) : Qt.point(0, 0);
    }
    function shelfPoint(pair) {
        const ta = (orbit.placed[pair.a] ?? 0) + orbit.driftOf(pair.a), tb = (orbit.placed[pair.b] ?? 0) + orbit.driftOf(pair.b);
        const theta = Math.atan2(Math.sin(ta) + Math.sin(tb), Math.cos(ta) + Math.cos(tb));
        const r = ((orbit.radii[pair.a] ?? 0) + (orbit.radii[pair.b] ?? 0)) / 2;
        return Orbit.project(r, Orbit.wrap(theta), orbit.cx, orbit.cy, orbit.camView, orbit.lift * 0.55);
    }
    // Each shelf pushes the fabric up where it stands.
    readonly property var fabricMasses: shelves.map(s => {
        const p = shelfPoint(s);
        return { x: p.gx, y: p.gy, depth: -orbit.tileH * 0.55 * Motion.drive, radius: orbit.tileW * 0.5 };
    })

    // Resonance: a few seconds of lock each time the orbit opens on a repeating loop.
    readonly property var resonant: journey?.resonance ?? []
    Cue {
        id: lock
        name: "orbit.resonance"
        scope: root
        enter: Motion.scaled(900)
        exit: Motion.scaled(1100)
        easing: Motion.standard
    }
    Timer {
        id: lockHold
        interval: Motion.scaled(3200)
        onTriggered: lock.on = false
    }
    function engageLock() {
        if (resonant.length === 3 && Motion.driving) {
            Feedback.play("foley.relay");
            lock.on = true;
            lockHold.restart();
        }
    }
    onResonantChanged: engageLock()
    Component.onCompleted: {
        previousFocus = orbit.focusIndex;
        engageLock();
    }

    // Transits: which tile, in front, is crossing which stalk.
    readonly property string crossing: {
        if (Motion.drive <= 0)
            return "";
        for (let i = 0; i < rooms.length; i++) {
            const front = orbit.place(i), r = orbit.rectOf(rooms[i].id);
            for (let j = 0; j < rooms.length; j++) {
                if (i === j)
                    continue;
                const stalk = orbit.place(j);
                const mx = (stalk.x + stalk.gx) / 2, my = (stalk.y + stalk.gy) / 2;
                if (front.z > stalk.z && mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h)
                    return i + ":" + j;
            }
        }
        return "";
    }
    property int transitTile: -1
    property string transitText: ""
    function two(n) { return String(n).padStart(2, "0"); }
    onCrossingChanged: {
        if (crossing === "")
            return;
        const [i, j] = crossing.split(":").map(Number);
        const seconds = orbit.orbitTime * orbit.driftPeriod / 1000;
        transitTile = i;
        transitText = two(i + 1) + " × " + two(j + 1) + "  T+" + Math.floor(seconds / 60) + ":" + two(Math.floor(seconds % 60));
        transitHold.restart();
    }
    Timer {
        id: transitHold
        interval: Motion.scaled(300) || 1
        onTriggered: root.transitTile = -1
    }
    function substituteFor(k) { return k === transitTile ? transitText : ""; }

    // Redshift: the tiles the keyboard focus moves towards turn cool; the ones it leaves, warm.
    // Set once at creation and on each move: a binding here would already hold the new focus when the move is seen.
    property int previousFocus: 0
    property var shifts: []
    function focusPoint(i) {
        const r = orbit.rectOf(orbit.pages[i]?.id ?? "home");
        return Qt.point(r.x + r.w / 2, r.y + r.h / 2);
    }
    Connections {
        target: root.orbit
        function onFocusIndexChanged() {
            const a = root.focusPoint(root.previousFocus), b = root.focusPoint(root.orbit.focusIndex);
            root.previousFocus = root.orbit.focusIndex;
            root.shifts = root.rooms.map((p, k) => {
                const q = root.focusPoint(k + 1);
                return Math.max(-1, Math.min(1, (Math.hypot(q.x - a.x, q.y - a.y) - Math.hypot(q.x - b.x, q.y - b.y)) / 200));
            });
            doppler.trigger();
        }
    }
    Pulse {
        id: doppler
        name: "orbit.doppler"
        scope: root
        attack: Motion.scaled(50)
        release: Motion.scaled(620)
    }
    function tintOf(k) {
        const s = shifts[k] ?? 0;
        return s === 0 || doppler.value <= 0 ? "transparent" : Qt.alpha(s > 0 ? Design.accent : Design.warm, Math.min(0.85, Math.abs(s) * doppler.value));
    }

    // The folded ephemeris of `foldRoom`, while E is held.
    property string foldRoom: ""
    // The day unfolding is paper shearing under tension (#47); letting go is silent, and a held key's repeat changes nothing.
    function hold(id) { if (foldRoom === "") Feedback.play("foley.paper"); foldRoom = id; }
    function letGo() { foldRoom = ""; }
    Cue {
        id: fold
        name: "orbit.ephemeris"
        scope: root
        on: root.foldRoom !== ""
        enter: Motion.scaled(320)
        exit: Motion.scaled(200)
        easing: Motion.standard
    }
    property string foldShown: ""
    onFoldRoomChanged: if (foldRoom !== "") foldShown = foldRoom

    // Ghost ticks: where each room used to stand, on its orbit.
    Repeater {
        model: root.rooms.length
        Item {
            id: ghost
            required property int index
            readonly property var p: Orbit.project(root.orbit.radii[index] ?? 0, root.orbit.placed[index] ?? 0, root.orbit.cx, root.orbit.cy, root.orbit.camView, 0)
            opacity: Motion.drive * 0.75
            Rectangle {
                x: ghost.p.gx
                y: ghost.p.gy - height / 2
                width: 1
                height: 11
                rotation: 12
                color: Design.muted
            }
            FText {
                x: ghost.p.gx + 3
                y: ghost.p.gy - 13
                text: root.two(ghost.index + 1)
                technical: true
                font.pixelSize: Design.caption
                color: Design.line
            }
        }
    }
    // A hairline from one point to another.
    component Hairline: Rectangle {
        property point from
        property point to
        readonly property real len: Math.hypot(to.x - from.x, to.y - from.y)
        x: from.x
        y: from.y - height / 2
        width: len
        height: 1
        transformOrigin: Item.Left
        rotation: Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI
    }
    // Dark matter routes, once they have earned a line: foot to foot.
    Repeater {
        model: root.routes
        Hairline {
            required property var modelData
            readonly property var a: root.orbit.place(modelData.a)
            readonly property var b: root.orbit.place(modelData.b)
            from: Qt.point(a.gx, a.gy)
            to: Qt.point(b.gx, b.gy)
            color: Design.accent
            opacity: Math.min(0.75, 0.2 + (modelData.weight - root.routeAt) * 0.05) * Motion.drive
        }
    }
    // Lagrange shelves.
    Repeater {
        model: root.shelves
        Item {
            id: shelf
            required property var modelData
            readonly property var p: root.shelfPoint(modelData)
            readonly property var a: root.orbit.place(modelData.a)
            readonly property var b: root.orbit.place(modelData.b)
            opacity: Motion.drive
            Hairline { from: Qt.point(shelf.p.x, shelf.p.y); to: Qt.point(shelf.a.x, shelf.a.y); color: Qt.alpha(Design.warm, 0.7) }
            Hairline { from: Qt.point(shelf.p.x, shelf.p.y); to: Qt.point(shelf.b.x, shelf.b.y); color: Qt.alpha(Design.warm, 0.7) }
            Plane {
                readonly property real w: root.orbit.tileW * 0.72 * shelf.p.scale
                x: shelf.p.x - w / 2
                y: shelf.p.y - height / 2
                width: w
                height: Math.max(18, root.orbit.tileH * 0.46 * shelf.p.scale)
                role: "signal"
                slant: 3
                FText {
                    anchors.centerIn: parent
                    text: root.two(shelf.modelData.a + 1) + " ⇄ " + root.two(shelf.modelData.b + 1) + "  " + Math.round(shelf.modelData.weight) + "×"
                    technical: true
                    font.pixelSize: Design.caption
                    color: parent.textColor
                }
            }
        }
    }
    // The tidal lock's mark, at the foot of the room that has stopped.
    FText {
        visible: root.lockedIndex >= 0
        readonly property var p: root.lockedIndex >= 0 ? root.orbit.place(root.lockedIndex) : ({ gx: 0, gy: 0 })
        x: p.gx + 8
        y: p.gy + 3
        text: "TIDALLY LOCKED"
        technical: true
        font.pixelSize: Design.caption
        color: Design.warm
        opacity: Motion.drive
    }
    // The folded ephemeris: 24 hours as an accordion running back along the plane from the room's tile, the hour
    // now in the signal colour. A fold is one sheared strip, its height the share of visits in that hour.
    Item {
        id: ephemeris
        visible: fold.value > 0.01
        readonly property var r: root.orbit.rectOf(root.foldShown || "home")
        readonly property var hours: root.journey?.hours?.[root.foldShown] ?? []
        x: r.x + r.w / 2
        y: r.y
        z: 3
        Repeater {
            model: 24
            Rectangle {
                required property int index
                readonly property real level: ephemeris.hours[index] ?? 0
                readonly property bool now: index === (root.journey?.hour ?? -1)
                x: index * 9 * fold.value - 4
                y: -index * 4 * fold.value - height
                width: 8
                height: (5 + 54 * level) * fold.value
                color: now ? Design.accent : index % 2 ? Qt.tint(Design.surface, Qt.alpha(Design.muted, 0.35 + 0.5 * level)) : Qt.tint(Design.hover, Qt.alpha(Design.muted, 0.2 + 0.5 * level))
                border.width: 1
                border.color: Design.line
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Design.shear, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            }
        }
        FText {
            x: 24 * 9 * fold.value
            y: -24 * 4 * fold.value - 12
            opacity: fold.value
            text: "24H  " + root.foldShown.toUpperCase()
            technical: true
            font.pixelSize: Design.caption
            color: Design.ink
        }
    }
}
