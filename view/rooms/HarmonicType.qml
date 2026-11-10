import qs.view.cues
import qs.view.ui
import QtQuick
import "Harmonic.js" as H

// The harmonic typesetter (docs/OVERDRIVE.md §39; atlas #13), the Stratum `media.typesetter` while something plays in
// Overdrive: the track's title is re-set at each section change of the song (an energy shift between two four-second
// windows), from the spectrum's six-second envelope: bass broadens it, brightness leans it, loudness thickens it, dense
// mids tighten it. It takes 700 ms to re-set and holds until the next section. The sections are counted (§ 1, § 2 …)
// in the title's corner. Released, the title is as it was (the Bindings restore it).
Item {
    id: root
    required property FText target
    property var spectrum: []
    // False only in tests, which call feed() themselves.
    property bool autonomous: true
    property var envelope: null
    property var history: []
    property real seconds: 0
    property real lastChange: 0
    property int section: 0
    property var set: H.typeset(null)
    property double previous: 0
    readonly property real drive: Motion.drive

    // One frame of spectrum at `t` seconds.
    function feed(frame, t) {
        const b = H.bands(frame);
        envelope = H.ease(envelope, b, envelope ? t - seconds : 0);
        history = H.keep(history, t, b.energy);
        seconds = t;
        if (section === 0 || H.boundary(history, t, lastChange)) {
            set = H.typeset(envelope);
            section += 1;
            lastChange = t;
        }
    }
    onSpectrumChanged: {
        if (!autonomous || !spectrum || !spectrum.length)
            return;
        const now = Date.now() / 1000;
        if (previous === 0)
            previous = now;
        feed(spectrum, seconds + Math.min(0.5, now - previous));
        previous = now;
    }

    // The set, eased in over 700 ms, and scaled by the engine so a release glides back.
    property real stretch: set.stretch
    property real slant: set.slant
    property real tracking: set.tracking
    Tween on stretch { scope: root.target; NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Tween on slant { scope: root.target; NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Tween on tracking { scope: root.target; NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    // Broadened no further than the title's free width, so it never runs past the room's edge.
    readonly property real room: root.target.contentWidth > 0 ? root.target.width / root.target.contentWidth : 1
    Binding { target: root.target; property: "stretch"; value: 1 + (Math.min(root.stretch, Math.max(1, root.room)) - 1) * root.drive }
    Binding { target: root.target; property: "slant"; value: root.slant * root.drive }
    Binding { target: root.target; property: "font.letterSpacing"; value: -1.5 + (root.tracking + 1.5) * root.drive }
    Binding { target: root.target; property: "font.weight"; value: root.drive > 0.5 ? root.set.weight : Font.Black }

    // The section, in the title's corner, in the player's voice.
    FText {
        parent: root.target
        visible: root.section > 0
        x: root.target.width - width
        y: -height - 2
        text: "§ " + root.section
        technical: true
        voice: "media"
        color: Design.accent
        opacity: root.drive
    }
}
