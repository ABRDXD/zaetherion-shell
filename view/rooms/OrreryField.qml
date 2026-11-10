import qs.core.client
import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Shapes
import "Orrery.js" as O

// The telemetry orrery (M12, docs/OVERDRIVE.md §15): Performance's Overdrive layer. The machine's processes are
// bodies orbiting the halo's centre on rings that lean at the house's 78°, crossing the halo like an armillary.
// The laws are in Orrery.js: mass is memory, speed is CPU, depth is memory's history (a leak spirals in and is torn
// apart at the Roche limit), new processes fall in, ended ones leave their ring, forks rain in as meteors, and
// the busiest body trails a comet tail away from the sun. Every figure printed is a real reading.
//
// Mounted by Performance as a Stratum (`performance.orrery`), so it exists only in Overdrive, while the room
// shows, and its requests stop with it. The core samples /proc only when asked (`orrery.sample`, once a second)
// and only under an active lease. The bodies' clock is an idle loop, so the engine's spin-down slows them to rest.
Item {
    id: root
    property CoreClient core: null
    // The stratum asks the core itself; harnesses without a core switch this off and call ingest().
    property bool asking: true
    property var orbits: ({ slots: [], rings: [], meteors: [] })
    property var last: null
    readonly property var g: O.geometry(width, height)
    // The orrery's own seconds: they run with the engine, so a release slows every body to a stop.
    readonly property real now: (clock.turns + clock.phase) * clock.period / 1000
    readonly property real level: clock.level
    // The bodies named in the callout list (slot indexes): the comet and any torn body first, then the heaviest
    // (CPU weighs as memory, as in the core's ranking), seven in all.
    property var named: []

    function ingest(sample) {
        root.last = sample;
        root.orbits = O.merge(root.orbits, sample, root.now);
        const live = [];
        root.orbits.slots.forEach((b, i) => { if (b && b.gone === null) live.push(i); });
        const slot = i => root.orbits.slots[i];
        const urgent = i => (slot(i).comet ? 2 : 0) + (O.roche(O.altAt(slot(i), root.now)) ? 1 : 0);
        live.sort((i, j) => urgent(j) - urgent(i) || (slot(j).cpu * 40 + slot(j).rss) - (slot(i).cpu * 40 + slot(i).rss));
        root.named = live.slice(0, 7);
    }
    function megabytes(mib) { return mib >= 1024 ? (mib / 1024).toFixed(1) + "G" : Math.round(mib) + "M"; }

    IdleLoop { id: clock; scope: root; name: "performance.orrery"; period: 60000 }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.asking && root.core !== null
        // An answer can land after a release has destroyed the stratum: then there is no root to give it to.
        onTriggered: root.core.request("orrery.sample", {}, (ok, result) => { if (ok && result && root) root.ingest(result); })
    }

    // The armature: the outer ring (altitude 1), the middle one, and the Roche limit (altitude 0), where a body
    // that sinks any further is torn apart. Drawn once per size.
    Repeater {
        model: [1, 0.5, 0]
        Shape {
            id: ring
            required property real modelData
            readonly property real major: O.radiusAt(root.g, modelData)
            x: root.g.cx
            y: root.g.cy
            rotation: root.g.lean * 180 / Math.PI
            opacity: root.level
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: ring.modelData === 0 ? Qt.alpha(Design.danger, 0.5) : Qt.alpha(Design.line, ring.modelData === 1 ? 0.9 : 0.5)
                strokeWidth: 1
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: ring.modelData === 0 ? [4, 4] : [1, 5]
                PathAngleArc {
                    radiusX: ring.major * root.g.aspect
                    radiusY: ring.major
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }
    FText {
        readonly property var at: O.place(root.g, 0, Math.PI / 2)
        x: at.x + 8
        y: at.y - height / 2
        opacity: root.level * 0.8
        text: "ROCHE LIMIT"
        technical: true
        font.pixelSize: Design.caption
        color: Design.danger
    }

    // Ended processes: their ring stays, fading, with their name where they were last.
    Repeater {
        model: root.orbits.rings
        Item {
            id: scar
            required property var modelData
            readonly property real remaining: Math.max(0, 1 - (root.now - modelData.at) / 8)
            readonly property real major: O.radiusAt(root.g, modelData.alt)
            readonly property var at: O.place(root.g, modelData.alt, modelData.theta)
            opacity: remaining * root.level
            visible: remaining > 0
            Shape {
                x: root.g.cx
                y: root.g.cy
                rotation: root.g.lean * 180 / Math.PI
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Design.warm
                    strokeWidth: 1
                    fillColor: "transparent"
                    PathAngleArc {
                        radiusX: scar.major * root.g.aspect
                        radiusY: scar.major
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }
            FText {
                x: scar.at.x + 6
                y: scar.at.y - height / 2
                text: "ENDED · " + scar.modelData.name
                technical: true
                font.pixelSize: Design.caption
                color: Design.warm
            }
        }
    }

    // Forks: each one a meteor falling into the sun.
    Repeater {
        model: 24
        Item {
            id: meteor
            required property int index
            readonly property var m: root.orbits.meteors[index] ?? null
            readonly property var p: m ? O.meteorAt(root.g, m, root.now) : null
            visible: p !== null
            x: p?.x ?? 0
            y: p?.y ?? 0
            opacity: p ? root.level * Math.min(1, 4 * (1 - p.life)) : 0
            rotation: p ? p.angle * 180 / Math.PI + 180 : 0
            // Head at the item's origin, the streak trailing back the way it came.
            Rectangle {
                y: -0.75
                width: 10 + 18 * (meteor.p?.life ?? 0)
                height: 1.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Design.accent }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }

    // The bodies. Each keeps its slot for life (Orrery.merge), so a delegate never swaps one process for another.
    Repeater {
        id: bodies
        model: 24
        Item {
            id: body
            required property int index
            readonly property var b: root.orbits.slots[index] ?? null
            readonly property real alt: b ? O.altAt(b, root.now) : 0
            readonly property real theta: b ? O.angleAt(b, root.now) : 0
            readonly property var p: b ? O.place(root.g, alt, theta) : ({ x: 0, y: 0, depth: 0 })
            readonly property bool torn: b !== null && O.roche(alt)
            readonly property real r: b?.size ?? 0
            readonly property color ink: torn ? Design.danger : b?.comet ? Design.warm : b && b.capture && root.now - b.altSince < 2 ? Design.accent : Design.ink
            visible: b !== null
            x: p.x
            y: p.y
            z: p.depth
            opacity: b ? O.presence(b, root.now) * (0.42 + 0.58 * p.depth) * root.level : 0
            // The comet's tail, straight away from the sun, as long as the process is busy.
            Rectangle {
                readonly property var t: body.b?.comet ? O.tail(root.g, body.p, body.b.cpu) : null
                visible: t !== null
                y: -1.25
                width: t?.length ?? 0
                height: 2.5
                transformOrigin: Item.Left
                rotation: (t?.angle ?? 0) * 180 / Math.PI
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Design.warm }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            // The body: a small plane leaning on the house's shear, its size the process's memory.
            Rectangle {
                visible: !body.torn
                x: -body.r
                y: -body.r
                width: body.r * 2
                height: body.r * 2
                scale: 0.7 + 0.3 * body.p.depth
                antialiasing: true
                color: body.ink
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * body.r, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
            }
            // Inside the Roche limit: torn into five fragments strung along its orbit.
            Repeater {
                model: body.torn ? 5 : 0
                Rectangle {
                    required property int index
                    readonly property var q: O.place(root.g, body.alt, body.theta - 0.11 * index)
                    readonly property real s: Math.max(2, body.r * (0.6 - 0.09 * index))
                    x: q.x - body.p.x - s / 2
                    y: q.y - body.p.y - s / 2
                    width: s
                    height: s
                    rotation: 17 * index
                    color: Design.danger
                    opacity: 1 - 0.15 * index
                }
            }
        }
    }

    // The callouts: the named bodies listed in the instrument's quiet lower-left corner, under the halo's ring, each
    // with a hairline leader to its body, so names never sit on the halo's figures.
    Repeater {
        model: 7
        Item {
            id: callout
            required property int index
            readonly property int slot: root.named[index] ?? -1
            readonly property var b: slot >= 0 ? root.orbits.slots[slot] ?? null : null
            readonly property Item target: slot >= 0 ? bodies.itemAt(slot) : null
            readonly property bool torn: target?.torn ?? false
            readonly property color ink: torn ? Design.danger : b?.comet ? Design.warm : Design.muted
            visible: b !== null && target !== null
            x: 20
            y: root.height - (7 - index) * 15
            opacity: root.level
            FText {
                id: tag
                text: !callout.b ? "" : (callout.torn ? "ROCHE · " : "") + callout.b.name + "  " + root.megabytes(callout.b.rss)
                      + (callout.b.cpu >= 1 ? " · " + Math.round(callout.b.cpu) + "%" : "")
                technical: true
                font.pixelSize: Design.caption
                color: callout.ink
            }
            // The leader, from the tag's end to the body, as faint as the body is far.
            Rectangle {
                readonly property real fromX: tag.width + 6
                readonly property real fromY: tag.height / 2
                readonly property real dx: (callout.target?.x ?? 0) - callout.x - fromX
                readonly property real dy: (callout.target?.y ?? 0) - callout.y - fromY
                x: fromX
                y: fromY
                width: Math.max(0, Math.hypot(dx, dy) - (callout.b?.size ?? 0) - 3)
                height: 1
                transformOrigin: Item.Left
                rotation: Math.atan2(dy, dx) * 180 / Math.PI
                color: callout.ink
                opacity: 0.25 + 0.35 * (callout.target?.p.depth ?? 0)
            }
        }
    }

    // The plate caption: the laws, and the real counts behind this frame.
    Column {
        x: 20
        y: 2
        spacing: 2
        opacity: root.level
        FText {
            text: "ORRERY · MASS = MEMORY · SPEED = CPU · DEPTH = MEMORY'S HISTORY"
            technical: true
            font.pixelSize: Design.caption
            color: Design.accent
        }
        FText {
            text: root.last?.running ? root.last.total.count + " PROCESSES · " + root.orbits.slots.filter(b => b && b.gone === null).length + " SHOWN · "
                                       + (root.last.forks ?? 0) + " FORKS/S · " + root.megabytes(root.last.total.rss) + " RESIDENT"
                                     : "ORRERY · WAITING FOR THE CORE"
            technical: true
            font.pixelSize: Design.caption
            color: Design.faint
        }
    }
}
