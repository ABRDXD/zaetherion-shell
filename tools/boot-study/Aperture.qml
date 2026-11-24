import QtQuick

// A four-part exposure dial. One arc develops for each fixture log entry.
Canvas {
    id: dial
    required property real progress
    required property bool fluid
    required property color accent
    onProgressChanged: requestPaint()

    onPaint: {
        const c = getContext("2d");
        c.reset();
        const tau = 2 * Math.PI;
        const radius = width / 2 - 8;
        c.translate(width / 2, height / 2);
        for (let tick = 0; tick < 60; ++tick) {
            const angle = tau * tick / 60 - tau / 4;
            const length = tick % 5 === 0 ? 8 : 3;
            c.beginPath();
            c.moveTo(radius * Math.cos(angle), radius * Math.sin(angle));
            c.lineTo((radius - length) * Math.cos(angle), (radius - length) * Math.sin(angle));
            c.lineWidth = 1;
            c.strokeStyle = "#6c797b";
            c.stroke();
        }
        c.lineCap = fluid ? "round" : "butt";
        for (let i = 0; i < 4; ++i) {
            const start = tau * (i - 1) / 4 + .045;
            const span = tau / 4 - .09;
            const done = Math.max(0, Math.min(1, progress * 4 - i));
            c.beginPath();
            c.arc(0, 0, radius - 17, start, start + span);
            c.lineWidth = 3;
            c.strokeStyle = "#354147";
            c.stroke();
            if (done > 0) {
                c.beginPath();
                c.arc(0, 0, radius - 17, start, start + done * span);
                c.strokeStyle = accent;
                c.stroke();
            }
        }
        // A shaded disc registers at centre as the exposure opens.
        const r = radius * .68;
        c.save();
        c.beginPath();
        c.arc(0, 0, r, 0, tau);
        c.clip();
        const g = c.createLinearGradient(-r, -r, r, r);
        g.addColorStop(0, fluid ? "#819e9e" : "#c6a683");
        g.addColorStop(.56, fluid ? "#394e58" : "#615d60");
        g.addColorStop(1, "#222932");
        c.fillStyle = g;
        c.fillRect(-r, -r, 2 * r, 2 * r);
        c.fillStyle = "#182128";
        c.beginPath();
        c.arc(r * (.08 + .65 * progress), -r * .35, r * .91, 0, tau);
        c.fill();
        c.restore();
    }
}
