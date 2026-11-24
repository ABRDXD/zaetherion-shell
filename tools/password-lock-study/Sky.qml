import QtQuick

// Original fixture wallpaper. All contours use a fixed seed, including the sky cuts.
Canvas {
    id: sky
    property bool fluid: false
    onFluidChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 1280, height / 720)
        const night = c.createLinearGradient(0, 0, 0, 720)
        night.addColorStop(0, fluid ? "#191b35" : "#192a36")
        night.addColorStop(0.50, fluid ? "#696181" : "#667581")
        night.addColorStop(0.77, fluid ? "#bc9da4" : "#c89f86")
        night.addColorStop(1, "#383d4c")
        c.fillStyle = night
        c.fillRect(0, 0, 1280, 720)
        let seed = 8231
        function random() {
            seed = (seed * 16807) % 2147483647
            return seed / 2147483647
        }
        for (let i = 0; i < 260; i++) {
            const x = random() * 1280, y = random() * 330
            c.fillStyle = "rgba(254,247,235," + ((1 - y / 340) * random() * 0.65) + ")"
            const r = random() < 0.93 ? 1 : 2
            c.fillRect(x, y, r, r)
        }
        // Thin cloud banks catch the last light on their upper edge.
        for (let i = 0; i < 48; i++) {
            const x = random() * 1480 - 180, y = 260 + random() * 250
            const span = 45 + random() * 360
            c.fillStyle = "rgba(255,217,196," + (0.025 + random() * 0.07) + ")"
            c.beginPath()
            c.moveTo(x, y)
            c.bezierCurveTo(x + span * 0.3, y - 3, x + span * 0.7, y - 6, x + span, y - 5)
            c.lineTo(x + span * 0.38, y + 1)
            c.fill()
        }
        const mx = fluid ? 968 : 303, my = fluid ? 245 : 228
        c.fillStyle = fluid ? "#dfccdb" : "#ecdbc4"
        c.beginPath()
        c.arc(mx, my, fluid ? 28 : 21, 0, Math.PI * 2)
        c.fill()
        const tones = fluid ? ["#827489", "#655e78", "#49475f", "#313448", "#202436"]
                            : ["#998a8c", "#797782", "#535e6b", "#354652", "#22323d"]
        for (let j = 0; j < tones.length; j++) {
            c.beginPath()
            c.moveTo(-5, 720)
            let noise = 0
            for (let x = -5; x <= 1285; x += 5) {
                noise = noise * 0.83 + (random() - 0.5) * 6
                const y = 455 + j * 39 + 42 * Math.sin(x / 193 + j * 1.63)
                        + 21 * Math.sin(x / 64 + j * 2.71) + 8 * Math.sin(x / 27 + j) + noise
                c.lineTo(x, y)
            }
            c.lineTo(1285, 720)
            c.fillStyle = tones[j]
            c.fill()
        }
        c.fillStyle = "rgba(12,18,28,0.18)"
        c.beginPath()
        if (fluid) {
            c.moveTo(0, 0)
            c.lineTo(330, 0)
            c.bezierCurveTo(15, 205, 105, 465, 0, 593)
        } else {
            c.moveTo(0, 0)
            c.lineTo(322, 0)
            c.lineTo(66, 720)
            c.lineTo(0, 720)
        }
        c.closePath()
        c.fill()
    }
}
