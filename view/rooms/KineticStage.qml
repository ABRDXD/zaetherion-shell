import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Shapes
import "Kinetic.js" as K

// Kinetic lyrics (M9): in Overdrive, the Media room's lyrics become a music video of type. Mounted by Media as a
// Stratum over its lyrics area, so it exists only while Overdrive is engaged, something plays and lyrics are on;
// Silent's karaoke roll returns when it goes.
//
// - A phrase (Kinetic.frames) builds word by word. Each word slams in along 78° at its own size: how long it is
//   sung (Kinetic.scaleFor). A held word swells while it lasts and is left as an outline once sung.
// - A cut (the next phrase) throws the last one out along 78°; every other cut inverts the stage, if FlashGate
//   allows (a large role swap is a flash, ≤ 3 a second). Phrases never cut faster than 3 a second (frames).
// - Bass onsets (Kinetic.detector, on the spectrum Media already leases) kick the phrase and flash the rule.
// - CJK lines run in columns, top to bottom, right to left. A chorus that returns carries the ghosts of its
//   earlier times. Between lines, the next line waits faint while a rule counts in.
// Everything is a function of the playback position, so a seek or a burst of input never queues or jumps.
Item {
    id: root
    required property var media
    required property var lines
    // The lines that are sung: credits some sources time at the start ("作曲 : …") would slam in over an intro.
    readonly property var sungLines: (lines ?? []).filter(l => !K.credit(l?.text))
    readonly property bool playing: media?.active?.playing ?? false
    readonly property real base: Math.max(Design.readout, Math.min(72, height * 0.3))
    readonly property real cosLean: 0.2079   // cos 78°
    readonly property real sinLean: 0.9781   // sin 78°

    // The clock: the sampled position, carried forward each frame while playing.
    property double now: Date.now()
    FrameAnimation { id: ticks; running: root.visible && root.playing; onTriggered: root.now = Date.now() }
    Activity { name: "lyrics.stage"; running: ticks.running }
    readonly property real position: (media?.position ?? 0) + (playing ? Math.max(0, now - (media?.positionStamp ?? now)) / 1000 : 0)

    function lineAt(pos) {
        let low = 0, high = sungLines.length - 1, result = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            if (sungLines[mid].time <= pos) { result = mid; low = mid + 1; } else high = mid - 1;
        }
        return result;
    }
    readonly property int lineIndex: lineAt(position + 0.08)
    property var words: []
    property var phrases: []
    property bool upright: false
    property int echo: 0
    function load() {
        const line = lineIndex >= 0 ? sungLines[lineIndex] : null;
        words = K.timeWords(line);
        upright = K.vertical(line?.text ?? "");
        const across = Math.max(8, Math.floor(width / (base * 0.55)));
        phrases = K.frames(words, upright ? Math.max(4, Math.floor(height / base)) * 2 : Math.round(across * 1.5));
        echo = lineIndex >= 0 ? K.echoes(sungLines, lineIndex) : 0;
    }
    onLineIndexChanged: load()
    onSungLinesChanged: load()
    onWidthChanged: load()
    onHeightChanged: load()
    Component.onCompleted: load()

    readonly property int wordIndex: K.wordAt(words, position + 0.05)
    readonly property int phraseIndex: {
        if (wordIndex < 0) return -1;
        for (let i = 0; i < phrases.length; i++)
            if (phrases[i].first <= wordIndex && wordIndex <= phrases[i].last) return i;
        return -1;
    }
    // Between lines: past the last word's end (with a breath) or before the first word. Resting is a cut too.
    readonly property bool resting: phraseIndex < 0 || (words.length > 0 && position > words[words.length - 1].end + 0.6)
    readonly property int staged: resting ? -1 : phraseIndex

    // The shown phrase and the one being thrown out, each { words, layout, start, line }.
    property var shown: null
    property var leaving: null
    property real cutAt: 0
    property int cuts: 0
    property bool inverted: false
    FontMetrics { id: metrics; font.family: Design.sans; font.weight: Font.Black; font.pixelSize: 100 } // scale: the reference size words are measured at
    function display(text, standing) { return standing ? text : text.toUpperCase(); }
    function measure(text, px) { return metrics.advanceWidth(display(text, upright)) * px / 100; }
    function cut() {
        leaving = shown;
        cutAt = position;
        if (staged < 0) { shown = null; return; }
        const p = phrases[staged];
        const list = words.slice(p.first, p.last + 1);
        shown = { words: list, layout: K.layoutFrame(list, root.measure, width - 24, height - 24, base, upright), start: p.time, line: lineIndex, upright: upright };
        cuts++;
        // Every other cut swaps the stage's roles: a flash, so only when the gate allows; denied, the roles stay.
        if (cuts % 2 === 0 && FlashGate.request("lyrics.cut")) inverted = !inverted;
    }
    onStagedChanged: cut()
    onPhrasesChanged: cut()

    // Beats.
    property var detector: K.detector()
    property double beatAt: 0
    property real beatStrength: 0
    Connections {
        target: root.media
        function onSpectrumChanged() {
            const s = root.detector.push(root.media.spectrum, Date.now() / 1000);
            if (s > 0) { root.beatAt = Date.now(); root.beatStrength = s; }
        }
    }
    readonly property real kick: beatStrength * Math.max(0, 1 - (now - beatAt) / 140)

    function outBack(p) {
        const c1 = 2.2, c3 = c1 + 1, q = p - 1;
        return 1 + c3 * q * q * q + c1 * q * q;
    }
    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    opacity: Motion.drive
    // The stage: clear, or ink when a cut has inverted it.
    Plane {
        anchors.fill: parent
        role: root.inverted ? "ink" : "clear"
        slant: 3
        opacity: root.inverted ? 1 : 0
    }
    readonly property color sung: root.inverted ? Design.background : Design.ink
    readonly property color singing: root.inverted ? Design.background : Design.accent

    // One phrase on the stage: its words, entering or leaving.
    component Phrase: Item {
        id: phrase
        property var frame: null
        property bool exiting: false
        property real ghost: 0           // > 0: an echo's ghost, this many steps back along 78°
        anchors.fill: parent
        readonly property real exitP: exiting ? root.clamp01((root.position - root.cutAt) / 0.2) : 0
        visible: !!frame && (!exiting || exitP < 1)
        readonly property bool standing: frame?.upright ?? false
        // A ghost: its earlier time, a step further back along 78° for each, and fainter.
        opacity: ghost > 0 ? 0.3 / ghost : 1 - exitP
        transform: Translate {
            x: 12 + root.cosLean * (8 * root.kick + 34 * phrase.ghost + phrase.exitP * 90) - 22 * phrase.ghost
            y: 12 - root.sinLean * (8 * root.kick + 34 * phrase.ghost + phrase.exitP * 90)
        }
        Repeater {
            model: phrase.frame ? phrase.frame.words.length : 0
            FText {
                id: word
                required property int index
                readonly property var w: phrase.frame.words[index]
                readonly property var at: phrase.frame.layout.items[index]
                readonly property real age: root.position - w.time
                readonly property real length: Math.max(0.05, w.end - w.time)
                readonly property real enter: phrase.exiting || phrase.ghost > 0 ? 1 : root.clamp01(age / 0.16)
                readonly property real eased: root.outBack(enter)
                readonly property bool held: length >= 0.9
                readonly property bool singingNow: !phrase.exiting && phrase.ghost === 0 && age >= 0 && age < length
                readonly property real slam: (1 - eased) * at.size * 0.9
                visible: phrase.exiting || phrase.ghost > 0 || age >= -0.02
                x: at.x - root.cosLean * slam
                y: at.y + root.sinLean * slam
                width: at.width
                height: at.height
                text: root.display(w.text, phrase.standing)
                headline: true
                sheared: !phrase.standing
                elide: Text.ElideNone
                wrapMode: phrase.standing ? Text.WrapAnywhere : Text.NoWrap
                lineHeight: phrase.standing ? 1.04 : 0.86
                font.pixelSize: Math.max(1, at.size) // scale: each word at its sung size (Kinetic.layoutFrame)
                font.weight: Font.Black
                font.letterSpacing: phrase.standing ? 0 : -0.02 * at.size
                font.capitalization: Font.MixedCase
                opacity: root.clamp01(enter * 3)
                scale: (1 + 0.45 * (1 - eased)) * (held && singingNow ? 1 + 0.1 * root.clamp01(age / length) : 1)
                transformOrigin: Item.Center
                // A held word, once sung, is left as its outline; a ghost is only ever an outline.
                readonly property bool hollow: held && age >= length && !phrase.exiting
                readonly property bool outlined: hollow || phrase.ghost > 0
                color: outlined ? "transparent" : singingNow ? root.singing : root.sung
                // The outline: the word's own glyphs stroked (Text.Outline only fattens a fill). A child of the
                // text, so it takes the word's shear, scale and opacity; PathText sets the glyphs' top at y.
                FontMetrics { id: wordMetrics; font: word.font }
                Shape {
                    visible: word.outlined
                    y: word.baselineOffset + wordMetrics.tightBoundingRect(word.text).y
                    ShapePath {
                        strokeColor: root.sung
                        strokeWidth: Math.max(1, word.font.pixelSize / 48)
                        fillColor: "transparent"
                        PathText { x: 0; y: 0; text: word.outlined ? word.text : ""; font: word.font }
                    }
                }
            }
        }
    }
    // Echoes behind (a returning chorus), then the phrase leaving, then the phrase now.
    Repeater {
        model: Math.min(2, root.echo)
        Phrase { required property int index; frame: root.shown; ghost: index + 1 }
    }
    Phrase { frame: root.leaving; exiting: true }
    Phrase { frame: root.shown }

    // The beat: the rule under the stage flashes its width with each kick.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * root.kick
        height: 2
        color: root.singing
    }

    // Between lines: the next line waits faint, and a rule counts in to it.
    Item {
        id: countIn
        anchors.fill: parent
        readonly property var next: root.sungLines[root.lineIndex + 1] ?? null
        readonly property real from: root.words.length > 0 ? root.words[root.words.length - 1].end : (root.sungLines[root.lineIndex]?.time ?? 0)
        visible: root.resting && !!next
        FText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 12
            text: countIn.next?.text ?? ""
            aside: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            font.pixelSize: Design.readout
            color: Design.faint
        }
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            height: 1
            width: parent.width * (countIn.next ? root.clamp01(1 - (countIn.next.time - root.position) / Math.max(0.5, countIn.next.time - countIn.from)) : 0)
            color: Design.accent
        }
    }
}
