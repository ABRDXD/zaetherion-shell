import qs.view.ui
import QtQuick

// The field archive's paper: a photocopy's grain, faint scanlines, a few dropout streaks and darkened
// edges, laid over the archive. Painted once per size, from a fixed seed, so it is the same sheet every
// time and nothing moves: an artifact of the copy, not a fault of the system.
Canvas {
    id: root
    property int seed: 1729
    enabled: false
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        let s = seed;
        const rand = () => (s = (s * 16807) % 2147483647) / 2147483647;
        // Scanlines.
        ctx.fillStyle = Qt.rgba(0, 0, 0, 0.16);
        for (let y = 0; y < height; y += 3)
            ctx.fillRect(0, y, width, 1);
        // Grain: light and dark specks.
        const specks = Math.round(width * height / 900);
        for (let i = 0; i < specks; i++) {
            const light = rand() < 0.5;
            ctx.fillStyle = light ? Qt.rgba(1, 1, 1, 0.03 + rand() * 0.05) : Qt.rgba(0, 0, 0, 0.08 + rand() * 0.1);
            ctx.fillRect(rand() * width, rand() * height, 1 + Math.round(rand()), 1);
        }
        // Dropouts: a few thin horizontal streaks where the copier lost the line.
        for (let i = 0; i < 7; i++) {
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.025 + rand() * 0.03);
            ctx.fillRect(rand() * width * 0.6, rand() * height, width * (0.1 + rand() * 0.4), 1 + Math.round(rand()));
        }
        // The edges darken, as a copy does where the lid didn't close.
        const edge = ctx.createLinearGradient(0, 0, width, 0);
        edge.addColorStop(0, Qt.rgba(0, 0, 0, 0.32));
        edge.addColorStop(0.06, Qt.rgba(0, 0, 0, 0));
        edge.addColorStop(0.94, Qt.rgba(0, 0, 0, 0));
        edge.addColorStop(1, Qt.rgba(0, 0, 0, 0.32));
        ctx.fillStyle = edge;
        ctx.fillRect(0, 0, width, height);
    }
}
