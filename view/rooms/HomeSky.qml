import qs.core.client
import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick

// The astronomical clock (M10), behind Home's numerals: the local sky as a band. The horizon is a hairline,
// each body's path across these 24 hours a faint arc, and each body a small plane where it stands now:
// the sun warm, the moon a square lit by its phase, the planets accent. Verticals lean to 78°, like the orbit's
// stalks. Above the horizon is up the band; below it, compressed and fainter, is what is under the floor.
//
// Silent: the core is asked (`sky.now`) once a minute while Home shows, and the band is drawn once per answer.
// Nothing moves. Overdrive: the day runs as a time-lapse (24 s for 24 h), every body sweeping its real path, the
// band lit by the sun's height at the cursor, the cursor's time beside it (a Stratum, destroyed on release). The
// lapse is scaled by the engine's level, so a release glides every body back to now.
Item {
    id: root
    property CoreClient core: null
    property bool active: false
    property var sky: null
    readonly property var tracks: sky?.tracks ?? null
    // Centre the band on the sun's side of the sky: south in the northern hemisphere.
    readonly property bool south: (sky?.place?.lat ?? 0) >= 0
    readonly property real horizon: Math.round(height * 0.66)
    readonly property real lean: -Design.shear
    // Left of this x the band is quieter, so the numerals in front of it stay the hero.
    property real quietTo: 0
    // Hours from now that the bodies show: 0 in Silent, −12 → 12 while the time-lapse runs, eased by the engine.
    readonly property real lapse: sweep.running ? sweep.level * (-12 + 24 * sweep.phase) : 0
    readonly property var labels: ({ sun: "SUN", moon: "MOON", mercury: "MER", venus: "VEN", mars: "MAR",
                                     jupiter: "JUP", saturn: "SAT", uranus: "URA", neptune: "NEP" })
    // The bodies with a drawn path; Uranus and Neptune are marks only (not to the naked eye).
    readonly property var traced: ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"]

    function ask() {
        if (!active || !core || !core.connected) return;
        core.request("sky.now", { tracks: true }, (ok, result) => { if (ok && result) root.sky = result; });
    }
    onActiveChanged: ask()
    Connections { target: Clock; enabled: root.active; function onMinuteStrChanged() { root.ask(); } }
    Connections { target: root.core; enabled: root.active; function onConnectedChanged() { root.ask(); } }

    function signedAngle(a) {
        a = ((a % 360) + 360) % 360;
        return a > 180 ? a - 360 : a;
    }
    // Sky to band: azimuth across (the centre on the sun's side), altitude up on a square-root scale (the low sky,
    // where most of the day happens, gets the room); verticals sheared to 78°.
    function point(az, alt) {
        const x = width * (0.5 + signedAngle(az - (south ? 180 : 0)) / 360);
        const y = alt >= 0 ? horizon - Math.sqrt(alt / 90) * (horizon - 4)
                           : horizon + Math.sqrt(Math.min(90, -alt) / 90) * (height - horizon - 2);
        return { x: x + (horizon - y) * lean, y: y };
    }
    // A body's place `hours` from now, interpolated along its track.
    function sample(body, hours) {
        const path = tracks?.paths?.[body];
        if (!path || path.length < 2) {
            const b = sky?.bodies?.[body];
            return b ? { az: b.azimuth, alt: b.altitude } : null;
        }
        const f = Math.max(0, Math.min(path.length - 1, (hours - tracks.from) * 60 / tracks.step));
        const i = Math.min(path.length - 2, Math.floor(f));
        const u = f - i;
        return { az: path[i][0] + signedAngle(path[i + 1][0] - path[i][0]) * u, alt: path[i][1] + (path[i + 1][1] - path[i][1]) * u };
    }
    // Label rows: marks sorted across the band, each label on the lowest row its left edge clears, so close
    // bodies (the sun, Mercury, Venus and a new moon, say) stack instead of overprinting.
    readonly property var slots: {
        const marks = [];
        for (const body of ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"]) {
            const place = sample(body, lapse);
            if (!place || (place.alt < 0 && body !== "sun" && body !== "moon")) continue;
            const p = point(place.az, place.alt);
            marks.push({ body: body, x: p.x, w: (labels[body].length + (body === "moon" ? 4 : 0)) * 8 + 14 });
        }
        marks.sort((a, b) => a.x - b.x);
        const rows = [];
        const out = {};
        for (const m of marks) {
            let r = 0;
            while (rows[r] !== undefined && rows[r] > m.x) r++;
            rows[r] = m.x + m.w;
            out[m.body] = r;
        }
        return out;
    }
    function ink(body) {
        return body === "sun" ? Design.warm : body === "moon" ? Design.ink : Design.accent;
    }

    Canvas {
        id: paths
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onSkyChanged() { paths.requestPaint(); }
            function onQuietToChanged() { paths.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.lineWidth = 1;
            // The horizon, and the compass points on it.
            ctx.strokeStyle = Qt.alpha(Design.line, 0.35);
            ctx.beginPath(); ctx.moveTo(0, root.horizon + 0.5); ctx.lineTo(root.quietTo, root.horizon + 0.5); ctx.stroke();
            ctx.strokeStyle = Qt.alpha(Design.line, 0.9);
            ctx.beginPath(); ctx.moveTo(root.quietTo, root.horizon + 0.5); ctx.lineTo(width, root.horizon + 0.5); ctx.stroke();
            ctx.fillStyle = Qt.alpha(Design.faint, 0.8);
            ctx.font = Design.caption + "px '" + Design.mono + "'";
            for (const [name, az] of [["N", 0], ["E", 90], ["S", 180], ["W", 270]]) {
                const p = root.point(az, 0);
                ctx.fillRect(p.x, root.horizon - 3, 1, 7);
                ctx.fillText(name, p.x + 4, root.horizon + Design.caption + 2);
            }
            if (!root.tracks) return;
            // Each traced body's path; under the floor drawn fainter. A jump across the band's seam breaks the line.
            for (const body of root.traced) {
                const path = root.tracks.paths[body];
                if (!path) continue;
                const strong = body === "sun" || body === "moon";
                let previous = null;
                for (const [az, alt] of path) {
                    const p = root.point(az, alt);
                    if (previous && Math.abs(p.x - previous.x) < width / 3) {
                        const up = alt >= 0 && previous.alt >= 0;
                        const quiet = p.x < root.quietTo ? 0.35 : 1;
                        ctx.strokeStyle = Qt.alpha(root.ink(body), (strong ? 0.42 : 0.2) * (up ? 1 : 0.35) * quiet);
                        ctx.beginPath(); ctx.moveTo(previous.x, previous.y); ctx.lineTo(p.x, p.y); ctx.stroke();
                    }
                    previous = { x: p.x, y: p.y, alt: alt };
                }
            }
        }
    }

    // The bodies where they stand (or where the time-lapse has them).
    Repeater {
        model: ["neptune", "uranus", "saturn", "jupiter", "mars", "mercury", "venus", "moon", "sun"]
        delegate: Item {
            id: mark
            required property string modelData
            readonly property var place: root.sample(modelData, root.lapse)
            readonly property var p: place ? root.point(place.az, place.alt) : null
            readonly property bool up: (place?.alt ?? -1) >= 0
            readonly property int size: modelData === "sun" ? 10 : modelData === "moon" ? 10 : modelData === "uranus" || modelData === "neptune" ? 3 : 5
            visible: !!p
            x: p ? p.x - size / 2 : 0
            y: p ? p.y - size / 2 : 0
            width: size
            height: size
            opacity: up ? 1 : 0.38
            // A sheared square, the house's tile in miniature.
            Rectangle {
                id: body
                anchors.fill: parent
                color: mark.modelData === "moon" ? "transparent" : root.ink(mark.modelData)
                border.width: mark.modelData === "moon" ? 1 : 0
                border.color: Design.ink
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -root.lean, 0, root.lean * mark.size / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                // The moon's phase: its lit part, on the side the sun lights (right while waxing, from the north).
                Rectangle {
                    visible: mark.modelData === "moon"
                    readonly property real lit: root.sky?.moon?.illumination ?? 0
                    readonly property bool fromRight: (root.sky?.moon?.waxing ?? true) === root.south
                    width: Math.round(parent.width * lit)
                    height: parent.height
                    x: fromRight ? parent.width - width : 0
                    color: Design.ink
                }
            }
            FText {
                visible: mark.size >= 5 && (mark.up || mark.modelData === "sun" || mark.modelData === "moon")
                readonly property int row: root.slots[mark.modelData] ?? 0
                x: mark.size + 3
                y: -height + 2 - row * (Design.caption + 1)
                text: root.labels[mark.modelData] + (mark.modelData === "moon" ? " " + Math.round(100 * (root.sky?.moon?.illumination ?? 0)) + "%" : "")
                technical: true
                font.pixelSize: Design.caption
                color: mark.modelData === "sun" ? Design.warm : Design.faint
            }
        }
    }

    // Overdrive: the band lit by the sun at the cursor (day bright, twilight warm), and the cursor's time at the foot.
    Stratum {
        z: -1
        anchors.fill: parent
        name: "home.sky"
        gpu: false
        scope: root
        wanted: root.active && !!root.tracks
        sourceComponent: Item {
            Rectangle {
                anchors.fill: parent
                readonly property real sunAlt: root.sample("sun", root.lapse)?.alt ?? -90
                color: sunAlt > 0 ? Design.accent : Design.warm
                opacity: sweep.level * (sunAlt > 0 ? 0.04 + 0.06 * Math.min(1, sunAlt / 40) : Math.max(0, 0.07 * (1 + sunAlt / 12)))
            }
            FText {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                opacity: sweep.level
                text: {
                    const minutes = Math.round(root.lapse * 60);
                    const at = new Date(Clock.date.getTime() + minutes * 60000);
                    const m = Math.abs(minutes);
                    return (minutes >= 0 ? "+" : "−") + Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") + " · " + Qt.formatTime(at, "HH:mm");
                }
                technical: true
                font.pixelSize: Design.caption
                color: Design.accent
            }
        }
    }

    IdleLoop { id: sweep; scope: root; name: "home.sky"; period: 24000; enabled: root.active && !!root.tracks }
}
