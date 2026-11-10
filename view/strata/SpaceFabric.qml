import qs.view.cues
import qs.view.ui
import QtQuick

// The spacetime fabric (docs/ORBIT.md §0), the first stratum: OrbitSystem creates it with the orbit and
// it is destroyed with it, never just hidden. A grid on a plane a little under the orbit's, pressed down
// by every mass on it: Home deepest, each room by its tile, the other systems by their suns, and each
// of their moons a little. A choice
// sends a ripple across it. It is a GPU mesh (shaders/fabric.*, compiled by tools/make_shaders.py): the
// tilt, the masses and the ripple are uniforms, so a flight's tilt swing costs the CPU nothing. Nothing
// moves at rest. The software renderer draws no shaders, so there it is simply absent.
ShaderEffect {
    id: root
    // Home's point on the scene, the tilt (degrees), the fabric's half-size and how far it lies under
    // the orbit's plane, in scene pixels.
    property real centreX: 0
    property real centreY: 0
    property real elevation: 45
    property real halfSize: 2000
    property real depthUnder: 40
    property real gridStep: 48
    // [{ x, y, depth, radius }]: on the scene, where the mass stands on the orbit's plane. At most 80
    // (wellCount, the shader's w0–w79); the rest are dropped, so list the heaviest first.
    property var masses: []
    readonly property int wellCount: 80
    property color line: Design.line
    // The house shear (tan 12°), as Orbit.js has it.
    readonly property real houseShear: Math.tan(12 * Math.PI / 180)
    property color signal: Design.accent

    // The plane's coordinates of a scene point on the orbit's plane (the inverse of the shader's map).
    function onPlane(x, y) {
        const s = Math.max(0.05, Math.sin(elevation * Math.PI / 180));
        return { x: x - centreX + (y - centreY) * root.houseShear, y: (y - centreY) / s };
    }
    function wellAt(i) {
        const m = masses[i];
        if (!m)
            return Qt.vector4d(0, 0, 0, 1);
        const p = onPlane(m.x, m.y);
        return Qt.vector4d(p.x, p.y, m.depth, Math.max(1, m.radius));
    }
    // A ripple out from a scene point (a choice): the wavefront runs across the fabric and dies away.
    function rippleFrom(x, y, height) {
        const p = onPlane(x, y);
        rippleX = p.x;
        rippleY = p.y;
        rippleHeight = height ?? gridStep * 0.5;
        if (Motion.live(root))
            rippleRun.restart();
    }
    // Overdrive (docs/OVERDRIVE.md §5): the engine (0 in Silent, so none of this shows), a slow phase the
    // fabric breathes on and sends waves out from Home with, and the bass level that deepens and quickens them.
    property real alive: 0
    property real breath: 0
    property real bass: 0
    readonly property vector4d life: Qt.vector4d(breath, alive, bass, 0)
    property real rippleX: 0
    property real rippleY: 0
    property real rippleHeight: 0
    property real rippleT: 1
    NumberAnimation {
        id: rippleRun
        target: root
        property: "rippleT"
        from: 0
        to: 1
        duration: Motion.transfer
        easing.type: Easing.OutQuad
    }
    Activity { name: "orbit.ripple"; running: rippleRun.running }

    x: 0
    y: 0
    width: halfSize * 2
    height: halfSize * 2
    blending: true
    mesh: GridMesh { resolution: Qt.size(180, 180) }
    vertexShader: Qt.resolvedUrl("shaders/fabric.vert.qsb")
    fragmentShader: Qt.resolvedUrl("shaders/fabric.frag.qsb")

    // The uniforms (shaders/fabric.vert's block).
    readonly property real cx: centreX
    readonly property real cy: centreY
    readonly property real sinE: Math.sin(elevation * Math.PI / 180)
    readonly property real cosE: Math.cos(elevation * Math.PI / 180)
    readonly property real shear: root.houseShear
    readonly property real extent: halfSize
    readonly property real drop: depthUnder
    readonly property real spacing: gridStep
    readonly property color lineColor: Qt.alpha(line, 0.17)
    readonly property color glowColor: signal
    readonly property vector4d ripple: Qt.vector4d(rippleX, rippleY, rippleT * halfSize * 1.2, rippleRun.running ? rippleHeight * (1 - rippleT) : 0)
    readonly property vector4d w0: wellAt(0)
    readonly property vector4d w1: wellAt(1)
    readonly property vector4d w2: wellAt(2)
    readonly property vector4d w3: wellAt(3)
    readonly property vector4d w4: wellAt(4)
    readonly property vector4d w5: wellAt(5)
    readonly property vector4d w6: wellAt(6)
    readonly property vector4d w7: wellAt(7)
    readonly property vector4d w8: wellAt(8)
    readonly property vector4d w9: wellAt(9)
    readonly property vector4d w10: wellAt(10)
    readonly property vector4d w11: wellAt(11)
    readonly property vector4d w12: wellAt(12)
    readonly property vector4d w13: wellAt(13)
    readonly property vector4d w14: wellAt(14)
    readonly property vector4d w15: wellAt(15)
    readonly property vector4d w16: wellAt(16)
    readonly property vector4d w17: wellAt(17)
    readonly property vector4d w18: wellAt(18)
    readonly property vector4d w19: wellAt(19)
    readonly property vector4d w20: wellAt(20)
    readonly property vector4d w21: wellAt(21)
    readonly property vector4d w22: wellAt(22)
    readonly property vector4d w23: wellAt(23)
    readonly property vector4d w24: wellAt(24)
    readonly property vector4d w25: wellAt(25)
    readonly property vector4d w26: wellAt(26)
    readonly property vector4d w27: wellAt(27)
    readonly property vector4d w28: wellAt(28)
    readonly property vector4d w29: wellAt(29)
    readonly property vector4d w30: wellAt(30)
    readonly property vector4d w31: wellAt(31)
    readonly property vector4d w32: wellAt(32)
    readonly property vector4d w33: wellAt(33)
    readonly property vector4d w34: wellAt(34)
    readonly property vector4d w35: wellAt(35)
    readonly property vector4d w36: wellAt(36)
    readonly property vector4d w37: wellAt(37)
    readonly property vector4d w38: wellAt(38)
    readonly property vector4d w39: wellAt(39)
    readonly property vector4d w40: wellAt(40)
    readonly property vector4d w41: wellAt(41)
    readonly property vector4d w42: wellAt(42)
    readonly property vector4d w43: wellAt(43)
    readonly property vector4d w44: wellAt(44)
    readonly property vector4d w45: wellAt(45)
    readonly property vector4d w46: wellAt(46)
    readonly property vector4d w47: wellAt(47)
    readonly property vector4d w48: wellAt(48)
    readonly property vector4d w49: wellAt(49)
    readonly property vector4d w50: wellAt(50)
    readonly property vector4d w51: wellAt(51)
    readonly property vector4d w52: wellAt(52)
    readonly property vector4d w53: wellAt(53)
    readonly property vector4d w54: wellAt(54)
    readonly property vector4d w55: wellAt(55)
    readonly property vector4d w56: wellAt(56)
    readonly property vector4d w57: wellAt(57)
    readonly property vector4d w58: wellAt(58)
    readonly property vector4d w59: wellAt(59)
    readonly property vector4d w60: wellAt(60)
    readonly property vector4d w61: wellAt(61)
    readonly property vector4d w62: wellAt(62)
    readonly property vector4d w63: wellAt(63)
    readonly property vector4d w64: wellAt(64)
    readonly property vector4d w65: wellAt(65)
    readonly property vector4d w66: wellAt(66)
    readonly property vector4d w67: wellAt(67)
    readonly property vector4d w68: wellAt(68)
    readonly property vector4d w69: wellAt(69)
    readonly property vector4d w70: wellAt(70)
    readonly property vector4d w71: wellAt(71)
    readonly property vector4d w72: wellAt(72)
    readonly property vector4d w73: wellAt(73)
    readonly property vector4d w74: wellAt(74)
    readonly property vector4d w75: wellAt(75)
    readonly property vector4d w76: wellAt(76)
    readonly property vector4d w77: wellAt(77)
    readonly property vector4d w78: wellAt(78)
    readonly property vector4d w79: wellAt(79)
}
