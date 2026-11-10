import qs.view.ui
import QtQuick
import "../ui/TitleType.js" as TT

// Counter windows (docs/OVERDRIVE.md §35; atlas #43), the Stratum `title.counters` inside LiveTitle, GPU only: the
// counters of the drawn title are found from the type itself (the glyphs grabbed, then every transparent pixel the
// outside can't reach), and become windows onto the room's content one fold away (`shift`: below the fold while
// there is more below, otherwise above). Found again whenever the title settles into a new shape.
Item {
    id: root
    required property Item glyphs
    required property Item frame
    property Item viewport: null
    property bool settled: true
    property real shift: 0
    // How many counters the last search found (for tests), and the mask's resolution.
    property int found: -1
    readonly property real resolution: 0.5
    readonly property int maskW: Math.max(1, Math.round(width * resolution))
    readonly property int maskH: Math.max(1, Math.round(height * resolution))
    // The grab waiting to be traced, and the counters found in the last one: row runs [x, y, length] at runsW × runsH.
    property string grabbed: ""
    property var runs: []
    property int runsW: 1
    property int runsH: 1
    readonly property Canvas maskCanvas: mask

    function search() {
        if (!settled || width <= 0 || height <= 0)
            return;
        glyphs.grabToImage(result => {
            if (!root)
                return;
            root.grabbed = result.url;
            mask.loadImage(result.url);
            // A grab can already be loaded (no imageLoaded then), and a paint asked for too early is dropped.
            mask.requestPaint();
        }, Qt.size(maskW, maskH));
    }
    onSettledChanged: if (settled) again.restart()
    onWidthChanged: again.restart()
    Component.onCompleted: again.restart()
    Timer { id: again; interval: 400; onTriggered: root.search() }

    Canvas {
        id: mask
        width: root.maskW
        height: root.maskH
        renderTarget: Canvas.Image
        onImageLoaded: requestPaint()
        onAvailableChanged: if (available) requestPaint()
        // Trace a fresh grab when there is one; then draw the last counters found, at this canvas's size (a resize
        // repaints, and must not lose them).
        onPaint: {
            const ctx = getContext("2d");
            const url = root.grabbed;
            if (url !== "" && isImageLoaded(url)) {
                const w = width, h = height;
                ctx.clearRect(0, 0, w, h);
                ctx.drawImage(url, 0, 0, w, h);
                const src = ctx.getImageData(0, 0, w, h).data;
                const alpha = new Uint8Array(w * h);
                for (let i = 0; i < w * h; i++)
                    alpha[i] = src[i * 4 + 3];
                const inside = TT.counters(alpha, w, h, 12);
                const found = [];
                for (let y = 0; y < h; y++)
                    for (let x = 0; x < w; x++) {
                        if (!inside[y * w + x])
                            continue;
                        let end = x;
                        while (end < w && inside[y * w + end])
                            end++;
                        found.push([x, y, end - x]);
                        x = end;
                    }
                root.runs = found;
                root.runsW = w;
                root.runsH = h;
                root.found = TT.count(inside, w, h);
                unloadImage(url);
                root.grabbed = "";
            }
            // Drawn as filled runs: Qt's putImageData doesn't keep written pixels.
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            ctx.scale(width / root.runsW, height / root.runsH);
            ctx.fillStyle = "white";
            for (const r of root.runs)
                ctx.fillRect(r[0], r[1], r[2], 1);
            ctx.restore();
        }
    }
    ShaderEffectSource {
        id: maskTexture
        sourceItem: mask
        hideSource: true
        smooth: true
    }
    // The room's content laid over the title's frame, one fold away.
    ShaderEffectSource {
        id: content
        readonly property point at: root.viewport?.contentItem ? root.frame.mapToItem(root.viewport.contentItem, 0, 0) : Qt.point(0, 0)
        sourceItem: root.viewport?.contentItem ?? null
        sourceRect: Qt.rect(at.x, at.y + root.shift, root.frame.width, root.frame.height)
        live: true
        hideSource: false
        smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        // This item's px to the content's texture: three points mapped into the frame.
        readonly property point o: root.mapToItem(root.frame, 0, 0)
        readonly property point px: root.mapToItem(root.frame, 1, 0)
        readonly property point py: root.mapToItem(root.frame, 0, 1)
        property size size: Qt.size(width, height)
        property point ax: Qt.point((px.x - o.x) / Math.max(1, root.frame.width), (px.y - o.y) / Math.max(1, root.frame.height))
        property point ay: Qt.point((py.x - o.x) / Math.max(1, root.frame.width), (py.y - o.y) / Math.max(1, root.frame.height))
        property point b: Qt.point(o.x / Math.max(1, root.frame.width), o.y / Math.max(1, root.frame.height))
        property color ground: Qt.tint(Design.background, Qt.alpha(Design.surface, 0.18))
        property color tint: Qt.alpha(Design.accent, 0.12)
        property var mask: maskTexture
        property var content: content
        visible: root.found > 0
        fragmentShader: Qt.resolvedUrl("shaders/counters.frag.qsb")
    }
}
