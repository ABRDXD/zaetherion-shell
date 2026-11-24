pragma ComponentBehavior: Bound
import QtQuick
import qs.view.cues
import qs.view.ui

// Karaoke on the lock (owner, 24 Nov: "no animations for the karaoke lyrics, barely visible; look at the previous shell's lock
// screen"). After the previous shell's lyrics view: the line before and after, dimmed and smaller, around the current one,
// bold; the stack scrolls to each new line (650 ms, out-cubic); word-timed lines fill word by word in the accent as
// they are sung. On a dark plate so it reads on any wallpaper. Reduced motion: no scroll travel.
Item {
    id: root
    property var lines: []
    property int index: -1
    property var clock: null      // LyricsTimeline: now() is the play position
    property real unit: 1
    readonly property real step: 46 * unit
    readonly property int bigSize: Design.readout
    readonly property var current: index >= 0 && index < lines.length ? lines[index] : null
    readonly property bool wordTimed: (current?.words?.length ?? 0) > 0
    implicitHeight: 3 * step + 28 * unit

    // The stack's position in lines; it travels to each new index.
    property real scroll: index
    onIndexChanged: { travel.to = index; travel.restart(); }
    NumberAnimation {
        id: travel
        target: root; property: "scroll"
        duration: Motion.reduced ? 0 : 650
        easing.type: Easing.OutCubic
    }
    Activity { name: "lock.lyrics"; running: travel.running }

    // The sung position for the word fill, sampled only while a word-timed line is up.
    property real sung: 0
    Timer {
        interval: 80
        repeat: true
        running: root.wordTimed && root.visible && !!root.clock
        onTriggered: root.sung = root.clock.now()
    }
    function filled(line) {
        const words = line.words;
        const done = Qt.alpha(Design.accent, 1).toString(), ahead = Qt.alpha(Design.ink, 0.5).toString();
        let html = "";
        for (let i = 0; i < words.length; i++) {
            const w = words[i];
            const text = String(w.text).replace(/&/g, "&amp;").replace(/</g, "&lt;");
            html += `<font color="${w.time <= root.sung ? done : ahead}">${text}</font>`;
            if (i < words.length - 1 && !String(w.text).endsWith(" ") && !String(words[i + 1].text).startsWith(" "))
                html += " ";
        }
        return html;
    }

    Rectangle {
        objectName: "lyricsPlate"
        anchors.fill: parent
        color: Qt.alpha(Design.islandFill, 0.62)
        radius: Design.fluid ? 22 * root.unit : 0
        border.width: 1
        border.color: Qt.alpha(Design.accent, 0.22)
    }
    Item {
        anchors.fill: parent
        anchors.margins: 14 * root.unit
        clip: true
        Repeater {
            // The window around the current line: one before, the line, two after (one scrolling in).
            model: root.index >= 0 ? 4 : 0
            Text {
                id: lineText
                required property int index
                readonly property int line: root.index - 1 + index
                readonly property real distance: Math.abs(line - root.scroll)
                readonly property bool isCurrent: line === root.index
                visible: line >= 0 && line < root.lines.length && distance < 1.6
                width: parent.width
                y: (parent.height - height) / 2 + (line - root.scroll) * root.step
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: isCurrent && root.wordTimed ? Text.StyledText : Text.PlainText
                text: !visible ? "" : isCurrent && root.wordTimed ? root.filled(root.lines[line])
                    : (root.lines[line].text || "♪")
                color: isCurrent && !root.wordTimed ? Design.accent : Design.ink
                font.family: Design.sans
                font.weight: isCurrent ? Font.Bold : Font.Medium
                font.pixelSize: root.bigSize
                opacity: Math.max(0, 1 - 0.58 * Math.min(1, distance) - 0.6 * Math.max(0, distance - 1))
                scale: 1 - 0.12 * Math.min(1, distance) - 0.08 * Math.max(0, Math.min(1, distance - 1))
            }
        }
    }
}
