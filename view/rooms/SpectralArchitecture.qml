import qs.view.cues
import qs.view.ui
import QtQuick
import "Architecture.js" as A

// Spectral architecture (atlas #67, docs/OVERDRIVE.md §20): in Overdrive, while something plays, Media stands on
// columns the music composes. The spectrum is folded into bass, middle and treble; at each section boundary (when what
// is playing parts from the section's own average, at most every 6 s) the room is re-cut: bass-heavy music stands as
// one massive column, a dense bright passage fractures into narrow cuts, and the planes slide from the old layout to the
// new over 0.6 s. Between sections nothing moves but the ink column's tone, which follows the bass. Near-silence held
// for 1.2 s snaps the room into exact registration, twelve equal square columns on the grid (atlas #70), and sound
// lets it go back to the section's composition. Behind the room's content (it takes no input); its planes stay faint
// so the text over them keeps its contrast.
Item {
    id: root
    property var spectrum: []
    readonly property var detector: A.sections()
    readonly property var quiet: A.hush()
    // Near-silence held: the room in exact registration (atlas #70) until sound comes back.
    property bool hushed: false
    // The section's own composition, kept while hushed so the release returns to it.
    property var composed: []
    property var from: []
    property var to: []
    property real morph: 1
    property var section: null
    property real bass: 0
    readonly property real eased: 1 - Math.pow(1 - morph, 3)
    readonly property var columns: A.between(from, to, eased)
    readonly property int pool: 11
    onSpectrumChanged: feed(spectrum, Date.now() / 1000)
    // One frame of the spectrum at time t (s); tests feed a whole song in synthetic time.
    function feed(bins, t) {
        const b = A.bands(bins);
        bass += (b[0] - bass) * 0.25;
        const s = detector.push(bins, t);
        if (s) {
            composed = A.compose(s.shares, s.index);
            section = s;
        }
        const h = quiet.push(bins, t);
        const target = h ? A.registered() : composed;
        if (h !== hushed || s) {
            hushed = h;
            from = columns;
            to = target;
            morph = 0;
        }
    }
    // The re-cut, frame by frame, only while it is under way.
    FrameAnimation {
        id: cutting
        running: root.morph < 1 && Motion.engaged
        onTriggered: root.morph = Math.min(1, root.morph + frameTime * Motion.drive / 0.6)
    }
    Activity { name: "media.architecture"; running: cutting.running }
    Repeater {
        model: root.pool
        Plane {
            required property int index
            readonly property var column: root.columns[index] ?? null
            visible: !!column
            x: (column?.x ?? 0) * root.width
            width: Math.max(1, (column?.w ?? 0) * root.width)
            height: root.height
            role: column?.role ?? "paper"
            slant: column?.slant ?? 0
            opacity: Motion.drive * (role === "ink" ? 0.05 + 0.07 * root.bass : role === "signal" ? 0.07 : 0.3)
        }
    }
    // The section's figures, small, at the head of the widest column, in the gap under the room's file line.
    FText {
        readonly property var widest: root.to.reduce((best, c) => !best || c.w > best.w ? c : best, null)
        visible: !!root.section && !!widest
        x: Math.min(root.width - implicitWidth - 4, (widest?.x ?? 0) * root.width + 12)
        y: 26
        text: root.hushed ? "SILENCE · IN REGISTER" : root.section ? "SECTION " + String(root.section.index).padStart(2, "0") + " · BASS " + Math.round(root.section.shares[0] * 100)
                             + " · TREBLE " + Math.round(root.section.shares[2] * 100) + " · " + root.to.length + (root.to.length === 1 ? " COLUMN" : " CUTS") : ""
        technical: true
        font.pixelSize: 9   // scale: a section's figures, under a caption
        color: Design.faint
        opacity: Motion.drive * 0.8
    }
}
