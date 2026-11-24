import QtQuick

// Original fixture art. The sleeve and architectural print also work without files.
Canvas {
    property string subject: "building"
    property bool fluid: false
    onFluidChanged: requestPaint()
    onSubjectChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 300, height / 180)
        function polygon(points, color) {
            c.fillStyle = color; c.beginPath(); c.moveTo(points[0], points[1])
            for (let i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i+1])
            c.closePath(); c.fill()
        }
        if (subject === "sleeve") {
            c.fillStyle = fluid ? "#9b8daa" : "#ca795e"; c.fillRect(0,0,300,180)
            c.strokeStyle = fluid ? "#f5d8cd" : "#ffde9e"; c.lineWidth = 1.75
            for (let i = 0; i < 36; i++) {
                c.beginPath(); c.moveTo(-6, 16 + i*4.1)
                c.bezierCurveTo(80, 170+i, 99, -92+i*5, 196, 50+i*2.4)
                c.bezierCurveTo(228, 96+i*3, 246, 112+i*0.8, 304, 104+i*2.4); c.stroke()
            }
            return
        }
        const sky = c.createLinearGradient(0, 0, 0, 180)
        sky.addColorStop(0,"#738c94"); sky.addColorStop(1,"#d4d8c0")
        c.fillStyle = sky; c.fillRect(0,0,300,180)
        c.fillStyle = "#f8e2ad"; c.beginPath(); c.arc(220,37,15,0,Math.PI*2); c.fill()
        polygon([0,143,62,108,114,131,190,96,245,118,300,81,300,180,0,180],"#788e8b")
        polygon([45,180,45,59,118,24,118,180],"#e1d8b9")
        polygon([118,24,173,42,173,180,118,180],"#546767")
        for (let i = 0; i < 10; i++) {
            const y = 60+i*13
            polygon([50,y,113,y-30,113,y-24,50,y+5],"#918e7f")
            polygon([123,y-32,168,y-17,168,y-13,123,y-27],"#283e46")
        }
        polygon([4,180,4,135,189,80,189,98,42,147,42,180],"#ecdfbe")
        polygon([42,147,189,98,218,108,42,167],"#354e53")
        polygon([179,103,188,100,188,180,179,180],"#b5b49f")
        polygon([0,178,300,140,300,180,0,180],"#405759")
        // Fine paper grain stays fixed through editor and workspace changes.
        let seed = 1337
        for (let i = 0; i < 3000; i++) {
            seed = seed*16807 % 2147483647; const x = seed % 300
            seed = seed*16807 % 2147483647; const y = seed % 180
            c.fillStyle = i % 2 ? "rgba(255,255,255,0.09)" : "rgba(25,46,63,0.09)"
            c.fillRect(x,y,0.7,0.7)
        }
    }
}
