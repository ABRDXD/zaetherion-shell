import qs.view.cues
import qs.view.ui
import QtQuick
import "../rooms/Kinetic.js" as K

// The title wedge in Overdrive (M9, docs/OVERDRIVE.md §6): while the Media room is shown and something plays, its
// title blade becomes a poster of the track's name, cut on the beat. The words themselves are the room's own stage
// (view/rooms/KineticStage.qml), so the two never sing the same word.
// - Beats: Kinetic.detector on the spectrum (the bass weighted double, an adaptive threshold). Each onset cuts to the
//   title's next word, slammed in along the blade's 78° edge; a beat sooner than a third of a second after the last
//   cut punches the word instead (M9's cap: ≤ 3 cuts a second).
// - Every other cut swaps the blade between ink and the signal colour, if FlashGate allows (a flash, D17).
// - CJK titles stand upright down the blade.
// Mounted by the Shell as a Stratum ("lyrics"), so it exists only in Overdrive; the spectrum lease is held here for
// as long as it exists. The name and inputs are the mount's (side, span, align, cut: Shell.cuts).
Item {
    id: root
    required property var host
    property string side: "right"
    property real span: 1
    property string align: "top"
    property real cut: 150
    readonly property bool leftSide: side === "left"
    readonly property real bladeHeight: Math.round(height * Math.max(0.3, Math.min(1, span)))
    readonly property real bladeY: align === "top" ? 0 : height - bladeHeight
    readonly property real pad: 10

    readonly property var media: host?.media ?? null
    readonly property var player: media?.active ?? null
    HostLease { domain: root.media; feature: "spectrum"; active: true }

    readonly property var title: (player?.title ?? "").split(/\s+/).filter(w => w !== "").map(w => K.vertical(w) ? w : w.toUpperCase())
    property int titleIndex: 0
    property string shown: title[0] ?? "♪"
    onTitleChanged: { titleIndex = 0; shown = title[0] ?? "♪"; }

    property var detector: K.detector()
    property double lastCut: 0
    property int cuts: 0
    property string blade: "ink"
    Connections {
        target: root.media
        function onSpectrumChanged() {
            const strength = root.detector.push(root.media.spectrum, Date.now() / 1000);
            if (strength <= 0) return;
            const t = Date.now();
            if (t - root.lastCut < 1000 / 3 || root.title.length === 0) { punch.trigger(); return; }
            root.lastCut = t;
            root.titleIndex = (root.titleIndex + 1) % root.title.length;
            root.shown = root.title[root.titleIndex];
            root.cuts++;
            slam.trigger();
            if (root.cuts % 2 === 0 && FlashGate.request("lyrics.cut"))
                root.blade = root.blade === "ink" ? "signal" : "ink";
        }
    }

    Pulse { id: slam; name: "lyrics.slam"; scope: root; attack: Motion.scaled(30); release: Motion.scaled(260); attackEasing: Easing.OutCubic; releaseEasing: Easing.OutBack; overshoot: 2.2 }
    Pulse { id: punch; name: "lyrics.punch"; scope: root; attack: Motion.scaled(40); release: Motion.scaled(220) }

    readonly property bool upright: K.vertical(shown)

    Item {
        x: root.leftSide ? 0 : root.width - root.cut
        y: root.bladeY
        width: root.cut
        height: root.bladeHeight
        clip: true
        opacity: Motion.drive
        Plane {
            id: plate
            anchors.fill: parent
            role: root.blade
            slant: root.leftSide ? 1 : 2
        }
        TextMetrics {
            id: metrics
            font.family: Design.sans
            font.pixelSize: 100 // scale: the reference size the fit is measured at
            font.weight: Font.Black
            text: root.shown
        }
        // Along the outer edge, as the room's name is set: fitted to the blade, never wider than it.
        readonly property real fit: metrics.advanceWidth > 0 ? 100 * (height - 2 * root.pad) / metrics.advanceWidth : 0
        // The word enters along the edge: from further down the blade, settling with the slam's overshoot.
        FText {
            visible: !root.upright
            x: root.leftSide ? root.pad : parent.width - root.pad
            y: (root.leftSide ? parent.height - root.pad : root.pad) + (root.leftSide ? -1 : 1) * 40 * slam.value
            transformOrigin: Item.TopLeft
            rotation: root.leftSide ? -78 : 102
            text: root.shown
            headline: true
            sheared: false
            elide: Text.ElideNone
            font.pixelSize: Math.max(Design.readout, Math.min(root.cut * 0.86, parent.fit)) // scale: the word fitted to the blade
            font.weight: Font.Black
            font.capitalization: Font.MixedCase
            lineHeight: 0.8
            color: plate.textColor
            scale: 1 + 0.3 * slam.value + 0.1 * punch.value
        }
        Column {
            visible: root.upright
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.pad
            scale: 1 + 0.3 * slam.value + 0.1 * punch.value
            Repeater {
                model: root.upright ? K.tokens(root.shown).slice(0, 8) : []
                FText {
                    required property string modelData
                    text: modelData
                    headline: true
                    sheared: false
                    font.pixelSize: Math.min(root.cut * 0.7, (root.bladeHeight - 2 * root.pad) / Math.max(1, Math.min(8, K.tokens(root.shown).length))) // scale: CJK glyphs fitted down the blade
                    font.weight: Font.Black
                    color: plate.textColor
                }
            }
        }
    }
}
