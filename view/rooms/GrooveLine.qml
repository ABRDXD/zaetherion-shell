import qs.view.cues
import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Shapes
import "Groove.js" as G
import "Architecture.js" as A

// Groove geometry (atlas #12, docs/OVERDRIVE.md §29): in Overdrive, while something plays, Media's seek bar carries
// the track's own groove, cut as you listen. Each spectrum frame cuts the cell under the playhead as deep as the music
// is loud there (the loudest heard stays); the played part of the line wiggles by what was cut, cells heard while paused
// or never played stay a dead, straight groove. Kept per track for the session (ViewState.grooves, never saved), so a
// track played again in Overdrive shows its record. Over the seek bar, taking no input.
Item {
    id: root
    property var media: null
    readonly property var player: media?.active ?? null
    readonly property string track: G.key(player)
    readonly property var groove: ViewState.grooves[track] ?? G.empty()
    readonly property real length: player?.length ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, (media?.position ?? 0) / length)) : 0
    Connections {
        target: root.media
        function onSpectrumChanged() { root.cut(); }
    }
    function cut() {
        if (!player || track === "")
            return;
        const b = A.bands(media.spectrum);
        const position = media.position + (player.playing ? Math.max(0, Date.now() - (media.positionStamp || Date.now())) / 1000 : 0);
        const next = G.record(groove, position, length, Math.min(1, (b[0] + b[1] + b[2]) / 1.2), !!player.playing);
        if (next !== groove)
            ViewState.keepGroove(track, next);
    }
    Shape {
        anchors.fill: parent
        opacity: Motion.drive
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            // Cut into the played blades: the background's ink, so it reads as engraved.
            strokeColor: Design.background
            strokeWidth: 1.4
            fillColor: "transparent"
            PathPolyline { path: G.path(root.groove, root.width, root.height, root.progress).map(p => Qt.point(p.x, p.y)) }
        }
    }
}
