import QtQuick

// The Medium (docs/OVERDRIVE.md §34): a real-time gas, its smoke and about a million grains of dust, simulated entirely on the GPU by three float textures feeding
// back on themselves. It runs in shell-heavy.qml on the NVIDIA card. `emitters` and `strike()` are how the rooms push it (view/shell/mediumLaws.js).
Item {
    id: root
    // { x, y (0..1), r (of the height), push: [vx, vy], force, smoke, heat, second }, at most eight.
    property var emitters: []
    // The hole, in 0..1: { x, y, r, pull, spin }, or null.
    property var well: null
    property real swirl: 0.62
    property real buoyancy: 0.22
    property real ambient: 1
    property real dustBirth: 0.0009
    property real gain: 1
    property bool sky: true
    property point light: Qt.point(0.2, 0)
    property color accent: "#a5cfdf"
    property color second: "#d6bdf0"
    property color hot: "#edf0ed"
    property color deep: "#0a0e13"
    // Sim grid against the panel: the gas is coarse, the smoke finer, the dust one grain to the pixel.
    property real gasScale: 0.5
    property real dyeScale: 1
    property bool running: true
    property real time: 0
    property real step: 1
    readonly property size gasSize: Qt.size(Math.max(2, Math.round(width * gasScale)), Math.max(2, Math.round(height * gasScale)))
    readonly property size dyeSize: Qt.size(Math.max(2, Math.round(width * dyeScale)), Math.max(2, Math.round(height * dyeScale)))
    readonly property size dustSize: Qt.size(Math.max(2, Math.round(width)), Math.max(2, Math.round(height)))
    readonly property real aspectRatio: width / Math.max(1, height)
    readonly property vector2d gasTexel: Qt.vector2d(1 / gasSize.width, 1 / gasSize.height)
    readonly property vector4d zero: Qt.vector4d(0, 0, 0, 0)
    // What the display shows, for the hole to bend.
    readonly property alias sight: view

    function advance(frameTime) {
        time += frameTime;
        // One solver step per frame, scaled so the gas moves at the same speed at 60 and at 144 Hz.
        step = Math.min(2.4, Math.max(0.05, frameTime * 72));
        if (pendingKick) {
            kickNow = pendingKick;
            pendingKick = null;
        } else if (kickNow) {
            kickNow = null;
        }
    }
    property var pendingKick: null
    property var kickNow: null
    // A strike at x, y (0..1): outward, or along dx, dy. What it leaves in the smoke is optional.
    function strike(x, y, radius, strength, dx, dy, smoke, heat, second) {
        pendingKick = { x: x, y: y, r: radius, s: strength, dx: dx ?? 0, dy: dy ?? 0, smoke: smoke ?? 0.6, heat: heat ?? 0.7, second: second ?? 0.3 };
    }
    function em(i) { return emitters && i < emitters.length ? emitters[i] : null; }
    function pos(i) { const e = em(i); return e ? Qt.vector4d(e.x, e.y, e.r, e.force || 0.0001) : zero; }
    function pushOf(i) { const e = em(i); return e && e.push ? Qt.vector4d(e.push[0], e.push[1], 0, 0) : zero; }
    function breath(i) { const e = em(i); return e ? Qt.vector4d(e.smoke || 0, e.heat || 0, e.second || 0, 0) : zero; }
    readonly property vector4d wellSim: well ? Qt.vector4d(well.x, well.y, well.pull ?? 0, well.spin ?? 0) : zero
    readonly property vector4d wellHorizon: well ? Qt.vector4d(well.x, well.y, well.r ?? 0, 0) : zero
    readonly property vector4d kickPos: kickNow ? Qt.vector4d(kickNow.x, kickNow.y, kickNow.r, kickNow.s) : zero

    ShaderEffect {
        id: gas
        width: root.gasSize.width; height: root.gasSize.height
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/medium_gas.frag.qsb")
        readonly property vector2d texel: root.gasTexel
        readonly property real aspect: root.aspectRatio
        readonly property real dt: root.step
        readonly property real swirl: root.swirl
        readonly property real buoyancy: root.buoyancy
        readonly property vector4d well: root.wellSim
        readonly property vector4d kick: root.kickPos
        readonly property vector4d kickDir: root.kickNow ? Qt.vector4d(root.kickNow.dx, root.kickNow.dy, 0, 0) : root.zero
        readonly property vector4d p0: root.pos(0); readonly property vector4d p1: root.pos(1); readonly property vector4d p2: root.pos(2); readonly property vector4d p3: root.pos(3)
        readonly property vector4d p4: root.pos(4); readonly property vector4d p5: root.pos(5); readonly property vector4d p6: root.pos(6); readonly property vector4d p7: root.pos(7)
        readonly property vector4d v0: root.pushOf(0); readonly property vector4d v1: root.pushOf(1); readonly property vector4d v2: root.pushOf(2); readonly property vector4d v3: root.pushOf(3)
        readonly property vector4d v4: root.pushOf(4); readonly property vector4d v5: root.pushOf(5); readonly property vector4d v6: root.pushOf(6); readonly property vector4d v7: root.pushOf(7)
        property variant gas: gasTexture
        property variant dye: dyeTexture
    }
    ShaderEffectSource { id: gasTexture; sourceItem: gas; recursive: true; live: root.running; hideSource: true; format: ShaderEffectSource.RGBA16F; smooth: true; wrapMode: ShaderEffectSource.ClampToEdge; textureSize: root.gasSize; width: 1; height: 1; opacity: 0 }

    ShaderEffect {
        id: dye
        width: root.dyeSize.width; height: root.dyeSize.height
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/medium_dye.frag.qsb")
        readonly property vector2d gasTexel: root.gasTexel
        readonly property real aspect: root.aspectRatio
        readonly property real dt: root.step
        readonly property real time: root.time
        readonly property real ambient: root.ambient
        readonly property vector4d well: root.wellHorizon
        readonly property vector4d kick: root.kickPos
        readonly property vector4d kickDye: root.kickNow ? Qt.vector4d(root.kickNow.smoke, root.kickNow.heat, root.kickNow.second, 0) : root.zero
        readonly property vector4d p0: root.pos(0); readonly property vector4d p1: root.pos(1); readonly property vector4d p2: root.pos(2); readonly property vector4d p3: root.pos(3)
        readonly property vector4d p4: root.pos(4); readonly property vector4d p5: root.pos(5); readonly property vector4d p6: root.pos(6); readonly property vector4d p7: root.pos(7)
        readonly property vector4d c0: root.breath(0); readonly property vector4d c1: root.breath(1); readonly property vector4d c2: root.breath(2); readonly property vector4d c3: root.breath(3)
        readonly property vector4d c4: root.breath(4); readonly property vector4d c5: root.breath(5); readonly property vector4d c6: root.breath(6); readonly property vector4d c7: root.breath(7)
        property variant gas: gasTexture
        property variant dye: dyeTexture
    }
    ShaderEffectSource { id: dyeTexture; sourceItem: dye; recursive: true; live: root.running; hideSource: true; format: ShaderEffectSource.RGBA16F; smooth: true; wrapMode: ShaderEffectSource.ClampToEdge; textureSize: root.dyeSize; width: 1; height: 1; opacity: 0 }

    ShaderEffect {
        id: dust
        width: root.dustSize.width; height: root.dustSize.height
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/medium_dust.frag.qsb")
        readonly property vector2d texel: Qt.vector2d(1 / root.dustSize.width, 1 / root.dustSize.height)
        readonly property real gasScale: root.dustSize.width / root.gasSize.width
        readonly property real dt: root.step
        readonly property real time: root.time
        readonly property real birth: root.dustBirth
        readonly property vector4d well: root.wellHorizon
        readonly property real aspect: root.aspectRatio
        property variant gas: gasTexture
        property variant dust: dustTexture
    }
    ShaderEffectSource { id: dustTexture; sourceItem: dust; recursive: true; live: root.running; hideSource: true; format: ShaderEffectSource.RGBA16F; smooth: false; wrapMode: ShaderEffectSource.ClampToEdge; textureSize: root.dustSize; width: 1; height: 1; opacity: 0 }

    ShaderEffect {
        id: view
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/medium.frag.qsb")
        readonly property vector2d texel: Qt.vector2d(1 / root.dustSize.width, 1 / root.dustSize.height)
        readonly property real aspect: root.aspectRatio
        readonly property real time: root.time
        readonly property real sky: root.sky ? 1 : 0
        readonly property real gain: root.gain
        readonly property point light: root.light
        readonly property color accent: root.accent
        readonly property color second: root.second
        readonly property color hot: root.hot
        readonly property color deep: root.deep
        property variant dye: dyeTexture
        property variant dust: dustTexture
        property variant gas: gasTexture
    }
}
