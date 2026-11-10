import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "Orbit.js" as Orbit

// A smaller system out in space beside the main one (docs/ORBIT.md §0, "other systems"): a room's own
// things as moons around a sun. Workspaces' desks orbit it, and Media's transport and players orbit what
// is playing. It sits on the same plane, through the same tilt, with tiles on stalks over shadows like the
// main system, and is reached by dragging through space. Its moons act: they are controls, not pictures.
// Nothing moves at rest.
Item {
    id: root
    // The sun's centre on the plane, in the scene's coordinates, and the outer ring's radius.
    property real cx: 0
    property real cy: 0
    property real outer: 160
    property real elevation: Orbit.ELEVATION
    property real rise: 1
    property bool interactive: true
    // Overdrive: how far the moons have turned round the sun (radians; OrbitSystem.moonSpin, 0 in Silent). The
    // inner ring turns faster, as Kepler has it.
    property real spin: 0
    // The sun: its tile size, and its content (the default property).
    property real sunW: 150
    property real sunH: 84
    default property alias sun: sunContent.data
    property string role: "ink"
    // [{ number, name, symbol, current, ring (0 inner, 1 outer), enabled (false: faint, no click) }]. A moon with no number shows its symbol large.
    property var moons: []
    property real tileW: 74
    readonly property real tileH: Math.round(tileW * 0.6)
    readonly property real lift: Math.round(tileH * 0.7)
    readonly property var view: Orbit.view(elevation, outer)
    // The moons' rings alone, so the geometry follows the layout, not every reading a moon carries
    // (Performance rewrites its moons each sample).
    readonly property string ringKey: moons.map(m => m.ring ?? 0).join(",")
    readonly property var ringOrder: ringKey === "" ? [] : ringKey.split(",").map(Number)
    readonly property bool twoRings: ringOrder.includes(1) && ringOrder.includes(0)
    readonly property Repeater moonTiles: moonRepeater
    readonly property Item sunItem: sunTile
    // The keyboard inside this system (OrbitSystem walks it): -2 nobody, -1 the sun, 0… a moon. The mark is
    // the moon's own highlight, or a signal rim round the sun; nothing moves while it rests.
    property int keyIndex: -2
    function moonEnabled(i) { return (moons[i]?.enabled ?? true) !== false; }
    // Enter on the keyed tile: what a click on it does.
    function keyAct() {
        if (keyIndex === -1)
            sunClicked();
        else if (keyIndex >= 0 && keyIndex < moons.length && moonEnabled(keyIndex))
            activated(keyIndex);
    }

    signal activated(int index)
    // The sun itself was clicked (the host goes to the room the system belongs to).
    signal sunClicked()

    function ringOf(i) { return twoRings ? ringOrder[i] : 1; }
    function radius(i) { return ringOf(i) === 0 ? outer * 0.58 : outer; }
    // Moons share their ring evenly, from the front-left; the outer ring is turned half a step. The share is
    // fixed by the layout; only the spin turns them.
    readonly property var angleBase: ringOrder.map((r, i) => {
        const ring = ringOf(i);
        const same = ringOrder.map((q, k) => k).filter(k => ringOf(k) === ring);
        const k = same.indexOf(i), n = Math.max(1, same.length);
        return Math.PI * 0.62 + 2 * Math.PI * (k + (ring === 1 && twoRings ? 0.5 : 0)) / n;
    })
    function angleOf(i) {
        return (angleBase[i] ?? 0) + spin * (ringOf(i) === 0 ? 2.26 : 1);
    }
    function placeNow(i) {
        return Orbit.project(radius(i), angleOf(i), cx, cy, view, lift * Math.min(1, rise));
    }
    // Every moon's place once per move, shared by its stalk, its tile and the fabric (Overdrive moves them every frame).
    readonly property var places: ringOrder.map((r, i) => placeNow(i))
    function place(i) {
        return places[i] ?? placeNow(i);
    }
    // Where each moon stands on the plane (its stalk's foot), for the fabric's wells: [{ x, y }].
    function feet() {
        return places.map(p => ({ x: p.gx, y: p.gy }));
    }
    readonly property var sunPoint: {
        const p = Orbit.point(0, lift * 0.35, 0, view);
        return { x: cx + p.x, y: cy + p.y, k: p.k };
    }
    // The sun's tile as drawn, in the scene's coordinates: { x, y, w, h }.
    readonly property var sunRect: ({ x: sunTile.x + sunW * (1 - sunPoint.k) / 2, y: sunTile.y + sunH * (1 - sunPoint.k) / 2, w: sunW * sunPoint.k, h: sunH * sunPoint.k })

    // The rings, near half stronger. Drawn round the sun at (0, 0) and moved there as a whole, so a system that
    // bobs (Overdrive) moves its rings without rebuilding and re-tessellating them every frame.
    Shape {
        id: rings
        x: root.cx
        y: root.cy
        z: 0
        preferredRendererType: Shape.CurveRenderer
        readonly property var radii: root.twoRings ? [root.outer * 0.58, root.outer] : [root.outer]
        readonly property var outlines: radii.map(r => Orbit.outline(r, 0, 0, root.view, 64))
        Instantiator {
            model: rings.radii.length
            delegate: ShapePath {
                required property int index
                strokeColor: Qt.alpha(Design.line, 0.4 * root.rise)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 5]
                fillColor: "transparent"
                PathPolyline { path: (rings.outlines[index]?.back ?? []).map(p => Qt.point(p.x, p.y)) }
            }
            onObjectAdded: (index, object) => rings.data.push(object)
        }
        Instantiator {
            model: rings.radii.length
            delegate: ShapePath {
                required property int index
                strokeColor: Qt.alpha(Design.line, root.rise)
                strokeWidth: 1.25
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: "transparent"
                PathPolyline { path: (rings.outlines[index]?.front ?? []).map(p => Qt.point(p.x, p.y)) }
            }
            onObjectAdded: (index, object) => rings.data.push(object)
        }
    }

    // Shadows, stalks and nodes under the moons.
    Repeater {
        model: root.moons.length
        Item {
            id: post
            required property int index
            readonly property var p: root.place(index)
            readonly property Item tile: moonRepeater.itemAt(index)
            readonly property real hover: tile ? tile.lit : 0
            readonly property real topY: p.y - 6 * hover
            z: 2 + p.depth - 0.001
            opacity: p.opacity * root.rise
            Rectangle {
                readonly property real w: root.tileW * 0.6 * post.p.scale
                x: post.p.gx - width / 2
                y: post.p.gy - height / 2
                width: w
                height: w * root.view.sin * 0.5
                radius: height / 2
                color: Qt.alpha("black", 0.3 + 0.15 * post.hover)
            }
            Rectangle {
                readonly property real len: Math.hypot(post.p.x - post.p.gx, post.topY - post.p.gy)
                x: post.p.gx - width / 2
                y: post.p.gy - len
                width: post.hover > 0.5 ? 2 : 1.5
                height: len
                transformOrigin: Item.Bottom
                rotation: Math.atan2(post.p.x - post.p.gx, post.p.gy - post.topY) * 180 / Math.PI
                color: post.hover > 0.5 ? Design.accent : Qt.alpha(Design.line, 0.9)
            }
            Rectangle {
                x: post.p.gx - width / 2
                y: post.p.gy - height / 2
                width: 5
                height: 5
                rotation: 45
                color: post.hover > 0.5 || (root.moons[post.index]?.current ?? false) ? Design.accent : Design.line
            }
        }
    }

    // The sun: an ink tile floating over its shadow, carrying the system's own content.
    Rectangle {
        readonly property real w: root.sunW * 0.7 * root.sunPoint.k
        readonly property var foot: Orbit.point(0, 0, 0, root.view)
        x: root.cx + foot.x - width / 2
        y: root.cy + foot.y - height / 2
        z: 1
        width: w
        height: w * root.view.sin * 0.5
        radius: height / 2
        color: Qt.alpha("black", 0.35)
        opacity: root.rise
    }
    Item {
        id: sunTile
        x: root.sunPoint.x - width / 2
        y: root.sunPoint.y - height / 2 - height * root.sunPoint.k / 2
        z: 2.5
        width: root.sunW
        height: root.sunH
        scale: root.sunPoint.k
        opacity: root.rise
        // The keyboard's mark on the sun: a signal rim, shaped like the tile.
        Plane {
            visible: root.keyIndex === -1
            x: -5
            y: -5
            width: parent.width + 10
            height: parent.height + 10
            role: "signal"
            slant: 3
        }
        Plane {
            id: sunPlane
            anchors.fill: parent
            role: root.role
            slant: 3
            backing: true
        }
        Item {
            id: sunContent
            anchors.fill: parent
            readonly property color ink: sunPlane.textColor
            readonly property color fill: sunPlane.fillColor
            readonly property real run: height * Math.tan(12 * Math.PI / 180)
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sunClicked()
        }
    }

    Repeater {
        id: moonRepeater
        model: root.moons.length
        OrbitTile {
            required property int index
            readonly property var m: root.moons[index] ?? ({})
            readonly property var p: root.place(index)
            entry: ({ name: m.name ?? "", symbol: m.symbol ?? "", about: m.about ?? "" })
            number: m.number ?? ""
            width: root.tileW
            height: root.tileH
            x: p.x - width / 2
            y: p.y - height / 2 - height * p.scale / 2
            scale: p.scale
            // A moon whose switch can't work here (no Bluetooth adapter) is shown faint and takes no click.
            opacity: p.opacity * root.rise * (m.enabled === false ? 0.45 : 1)
            z: 2 + p.depth + lit
            current: m.current ?? false
            enabled: root.interactive && m.enabled !== false
            highlighted: hovered || root.keyIndex === index
            onClicked: root.activated(index)
        }
    }
}
