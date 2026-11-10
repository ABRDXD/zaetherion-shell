import qs.view.contract
import qs.view.cues
import qs.view.shell
import qs.view.strata
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// The signal room as an editorial spread (MONTAGE.md §5): the round cover inside its audio ring on the
// left, the track set large on the right under an ink tag with the artist, then the lyrics with the
// current line in the accent, the seek band and the transport. The ring's ticks follow the spectrum and
// carry the position, so the cover is also the track's clock.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    readonly property var media: host.media
    readonly property var player: media.active
    readonly property bool compact: width < 740
    property bool lyrics: false
    property bool petActive: false
    readonly property bool active: visible && (QsWindow.window?.visible ?? false) && shell.panelOpen
    readonly property bool lyricsReady: host.lyrics.status === "ok" && host.lyrics.lines.length > 0
    readonly property real length: player?.length ?? 0
    readonly property real progress: player && length > 0 ? Math.max(0, Math.min(1, media.position / length)) : 0
    readonly property bool reactive: active && ViewState.ambientEnabled && Motion.overdrive && (player?.playing ?? false)
    // The cover takes what the height allows, under the head and over the transport.
    // Fullscreen (a tall room) lets it grow to fill the column.
    readonly property real discSide: Math.max(160, Math.min(compact ? 250 : height > 800 ? 480 : 340, height - head.height - 165, width * 0.42))
    // Unless the room is narrow, the foot (player, lyrics, the cat) sits in the cover's column under the
    // transport, where there is room, and the spread runs to the bottom: the spread is what fills first.
    readonly property bool sideFoot: !compact && discSide >= 300
    // A short room (the panel, not fullscreen) gives the title and the visualiser a smaller share.
    readonly property bool tall: height > 800
    onActiveChanged: if (!active) { petTimer.stop(); petActive = false; }
    HostLease { domain: root.media; feature: "position"; active: root.active }
    // The visualiser listens only while something plays in the open room (the host runs its spectrum
    // source only under the lease); Overdrive's audio ring on the cover shares it.
    readonly property bool visualising: active && ViewState.visualiserEnabled && !Motion.reduced && (player?.playing ?? false)
    HostLease { domain: root.media; feature: "spectrum"; active: root.visualising || (root.active && ViewState.ambientEnabled && Motion.overdrive) }
    // Overdrive brings the words itself (the user, 8 November 2026): while it is engaged and something plays, the
    // lyrics are leased and the kinetic stage shows whether or not the Lyrics switch is on. The switch is Silent's
    // and is never flipped, so a release returns the room to it.
    readonly property bool kineticWanted: active && (player?.playing ?? false) && Motion.engaged && !Motion.reduced
    readonly property bool kineticOn: kineticWanted && lyricsReady
    // The words' share of the spread: the switch's, or Overdrive's while it shows them.
    readonly property bool wordsShown: lyrics || kineticOn
    HostLease { domain: root.host.lyrics; feature: "lyrics"; active: root.active && (root.lyrics || root.kineticWanted) }
    LyricsTimeline {
        id: timeline
        active: root.active && root.lyrics && root.lyricsReady
        lines: root.host.lyrics.lines
        position: root.media.position
        positionStamp: root.media.positionStamp
        playing: root.player?.playing ?? false
    }

    // The head: the room's file line, ruled out to the carrier's state.
    RowLayout {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10
        FText { text: "01   ·   SIGNAL ROOM"; technical: true; color: Design.muted }
        Hairline { Layout.fillWidth: true; color: Design.line }
        FStatusDot { pulse: root.player?.playing ?? false; color: pulse ? Design.accent : Design.faint }
        FText { text: root.player?.playing ? "ON AIR" : root.player ? "SIGNAL HELD" : "AWAITING SIGNAL"; technical: true; color: Design.accent }
    }

    // Overdrive: the room stands on columns the music composes (SpectralArchitecture, atlas #67), behind everything.
    Stratum {
        name: "media.architecture"
        gpu: false
        scope: root
        z: -1
        anchors.fill: parent
        wanted: root.kineticWanted
        sourceComponent: SpectralArchitecture { spectrum: root.media.spectrum }
    }
    // Overdrive: the title re-set at each section of the song (HarmonicType, atlas #13, docs/OVERDRIVE.md §39).
    Stratum {
        name: "media.typesetter"
        gpu: false
        scope: root
        wanted: root.kineticWanted
        sourceComponent: HarmonicType { target: title; spectrum: root.media.spectrum }
    }

    // The cover in its audio ring, with the transport centred under it.
    CoverDisc {
        id: disc
        anchors.left: parent.left
        anchors.top: head.bottom
        anchors.topMargin: 22
        width: root.discSide
        height: root.discSide
        source: root.player?.artUrl ?? ""
        bars: 64
        spectrum: root.media.spectrum
        reactive: root.reactive
        progress: root.progress
        offsetFrame: true
        spinning: root.player?.playing ?? false
    }
    FText {
        anchors.top: disc.top
        anchors.right: disc.right
        anchors.rightMargin: -6
        text: Math.round(root.progress * 100) + "%"
        voice: "media"
        technical: true
        color: Design.accent
    }
    RowLayout {
        id: transport
        anchors.horizontalCenter: disc.horizontalCenter
        anchors.top: disc.bottom
        anchors.topMargin: 20
        spacing: 8
        FButton { symbol: "shuffle"; selected: root.player?.shuffle ?? false; enabled: root.player?.shuffleSupported ?? false; hint: "Shuffle"; onClicked: root.media.setShuffle(!root.player.shuffle) }
        FButton { symbol: "skip_previous"; iconSize: 28; hint: "Previous"; enabled: root.player?.canPrevious ?? false; onClicked: root.media.previous() }
        FButton {
            implicitWidth: 70; implicitHeight: 54; iconSize: 34
            symbol: root.player?.playing ? "pause" : "play_arrow"
            primary: true
            hint: root.player?.playing ? "Pause" : "Play"
            enabled: root.player?.canToggle ?? false
            onClicked: root.media.togglePlaying()
        }
        FButton { symbol: "skip_next"; iconSize: 28; hint: "Next"; enabled: root.player?.canNext ?? false; onClicked: root.media.next() }
        FButton { symbol: root.player?.loop === "track" ? "repeat_one" : "repeat"; selected: (root.player?.loop ?? "none") !== "none"; enabled: root.player?.loopSupported ?? false; hint: "Repeat"; onClicked: root.media.setLoop(root.player.loop === "none" ? "playlist" : "none") }
    }

    // The spread: the artist's tag, the title large, the album, then lyrics or the source, then seek.
    ColumnLayout {
        id: spread
        x: disc.width + (root.compact ? 24 : 36)
        width: root.width - x
        anchors.top: head.bottom
        anchors.topMargin: 22
        anchors.bottom: root.sideFoot ? parent.bottom : foot.top
        anchors.bottomMargin: root.sideFoot ? 4 : 10
        spacing: 10
        // The artist's tag, and on the same line the source: its name, or the choice when several play.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Item {
                id: tag
                Layout.preferredWidth: Math.min(spread.width * 0.6, artist.implicitWidth + 34)
                Layout.preferredHeight: 30
                Plane { anchors.fill: parent; role: "ink"; slant: 3; backing: true }
                FText {
                    id: artist
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    width: parent.width - 28
                    text: root.player?.artist || "THE ROOM IS QUIET"
                    font.pixelSize: Design.control
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    color: Design.onInk ?? Design.background
                }
            }
            Item { Layout.fillWidth: true }
            FText {
                visible: root.media.players.length <= 1
                text: "VIA " + (root.player?.identity || "NO CARRIER").toUpperCase()
                technical: true
                color: Design.faint
            }
            FChoice {
                visible: root.media.players.length > 1
                Layout.preferredWidth: Math.min(220, spread.width * 0.35)
                model: root.media.players.map(p => p.identity)
                currentIndex: root.media.players.findIndex(p => p.id === root.player?.id)
                onActivated: index => root.media.select(root.media.players[index].id)
            }
        }
        FText {
            id: title
            Layout.fillWidth: true
            text: root.player?.title || "Nothing needs\nto fill the silence."
            // The title is the spread's poster: as large as two lines of the column allow.
            Layout.preferredHeight: root.compact ? 120 : Math.min(200, spread.height * (root.tall ? 0.42 : root.wordsShown ? 0.22 : 0.3))
            headline: true
            font.pixelSize: root.compact ? 64 : 112 // scale: the largest the fit may choose
            minimumPixelSize: Design.figure
            fontSizeMode: Text.Fit
            font.weight: Font.Black
            font.letterSpacing: -1.5
            lineHeight: 0.86
            wrapMode: Text.Wrap
            maximumLineCount: 3
            verticalAlignment: Text.AlignTop
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle { width: 18; height: 2; color: Design.accent }
            FText { Layout.fillWidth: true; text: root.player?.album || root.player?.identity || "NO CARRIER"; font.pixelSize: Design.control; color: Design.muted }
        }
        // The visualiser: the spectrum as 78° bars on a hairline (a stratum, on the GPU); a still comb
        // when nothing plays.
        SpectrumBand {
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 56 : Math.max(40, Math.min(150, spread.height * (root.tall ? (root.wordsShown ? 0.16 : 0.24) : root.wordsShown ? 0.09 : 0.15)))
            Layout.topMargin: 4
            visible: ViewState.visualiserEnabled
            spectrum: root.visualising ? root.media.spectrum : []
        }
        // Lyrics: the line before, the current one in the accent, then what follows as far as the room
        // allows. The source lives on the tag's line, so this space is the words'.
        Item {
            id: words
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 60
            clip: true
            // Overdrive: the words as a music video of type (KineticStage, M9), while something plays, Lyrics switch
            // on or off. Silent's roll (or the remark) below gives way to it as the engine spins up, and is back when it goes.
            Stratum {
                id: kinetic
                anchors.fill: parent
                name: "lyrics.stage"
                gpu: false
                scope: words
                wanted: root.kineticOn
                sourceComponent: KineticStage {
                    media: root.media
                    lines: root.host.lyrics.lines
                }
            }
            Column {
                id: lyricLines
                visible: root.lyrics && (!kinetic.item || Motion.drive < 1)
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                // A new line: the lines start one step lower and fainter and settle up into place, so the
                // words roll on rather than jump. Runs only as a line changes, and never with reduced motion.
                property real roll: 0
                transform: Translate { y: lyricLines.roll }
                opacity: (1 - lyricLines.roll / 80) * (kinetic.item ? 1 - Motion.drive : 1)
                readonly property int lineIndex: timeline.index
                onLineIndexChanged: {
                    if (!Motion.live(words) || Motion.settle === 0 || !root.lyricsReady)
                        return;
                    rollIn.stop();
                    lyricLines.roll = lineIndex > 0 ? 26 : 0;
                    rollIn.start();
                }
                NumberAnimation { id: rollIn; target: lyricLines; property: "roll"; to: 0; duration: Motion.scaled(320); easing.type: Easing.OutCubic }
                Activity { name: "media.lyrics"; running: rollIn.running }
                Repeater {
                    // One line before, the current, and up to four after: as many as fit.
                    model: [-1, 0, 1, 2, 3, 4].slice(0, Math.max(2, Math.min(6, Math.floor((words.height + 8) / 34))))
                    FText {
                        required property int modelData
                        readonly property int line: timeline.index + modelData
                        readonly property var entry: root.host.lyrics.lines[line]
                        readonly property bool current: modelData === 0
                        width: parent.width
                        visible: root.lyricsReady ? (current || entry !== undefined) : current
                        text: !root.lyricsReady ? (root.host.lyrics.status === "loading" ? "Listening for the words…" : "No lyrics for this one.")
                            : current && timeline.index < 0 ? "…" : (entry?.text || "♪")
                        aside: !current
                        headline: current
                        font.pixelSize: current ? Design.readout : Design.control
                        font.weight: current ? Font.Bold : Font.Normal
                        font.capitalization: Font.MixedCase
                        wrapMode: Text.Wrap
                        maximumLineCount: current ? 2 : 1
                        elide: Text.ElideRight
                        color: current ? Design.accent : modelData < 0 ? Design.faint : Design.muted
                        Tween on color { scope: words; ColorAnimation { duration: Motion.settle } }
                    }
                }
            }
            // Without lyrics: the room's remark.
            FText {
                visible: !root.lyrics && (!kinetic.item || Motion.drive < 1)
                opacity: kinetic.item ? 1 - Motion.drive : 1
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                text: root.player?.playing ? "yes, this counts as a soundtrack." : "silence. a bold choice."
                aside: true
                wrapMode: Text.Wrap
                color: Design.muted
            }
        }
        FWaveform {
            id: seek
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spectrum: []
            enabled: (root.player?.canSeek ?? false) && root.length > 0
            from: 0
            to: Math.max(1, root.length)
            value: root.media.position
            onMoved: root.media.seek(value)
            // Overdrive: the track's own groove, cut as you listen (GrooveLine, atlas #12).
            Stratum {
                name: "media.groove"
                gpu: false
                scope: seek
                anchors.fill: parent
                wanted: root.kineticWanted
                sourceComponent: GrooveLine { media: root.media }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            FText { text: Clock.formatSeconds(root.player ? root.media.position : 0); technical: true; font.pixelSize: Design.control; voice: "media" }
            FText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: seek.enabled ? "DRAG TO SEEK" : "SEEK UNAVAILABLE"; technical: true; color: Design.faint; font.pixelSize: Design.caption }
            FText { text: root.length > 0 ? Clock.formatSeconds(root.length) : root.player ? "LIVE" : "—"; technical: true; font.pixelSize: Design.control; color: Design.muted; voice: "media" }
        }
    }

    // The foot: the player and the lyrics switch, the remark, and the cat keeping time. Under the cover
    // (sideFoot), or across the room when it is narrow.
    Item {
        id: foot
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.sideFoot ? root.discSide : root.width
        height: 58
        RowLayout {
            id: footButtons
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            FButton {
                symbol: "open_in_new"; label: "Open player"
                enabled: root.player?.canRaise ?? false
                onClicked: { root.media.raise(); root.shell.close(); }
            }
            FButton { symbol: "lyrics"; label: "Lyrics"; selected: root.lyrics; onClicked: root.lyrics = !root.lyrics }
        }
        FText {
            anchors.right: root.sideFoot ? undefined : cat.left
            anchors.rightMargin: 12
            anchors.left: root.sideFoot ? parent.left : undefined
            anchors.verticalCenter: root.sideFoot ? undefined : parent.verticalCenter
            anchors.bottom: root.sideFoot ? parent.top : undefined
            // Under the cover, it sits over the buttons, if the transport leaves it room.
            visible: !root.compact && (!root.sideFoot || foot.y - (transport.y + transport.height) > height + 16)
            text: "someone is keeping time."
            aside: true
            color: Design.muted
        }
        AnimatedImage {
            id: cat
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.sideFoot || foot.width >= footButtons.width + width + 8
            width: 78; height: 58
            source: Quickshell.shellPath("assets/caelestia/bongocat.gif")
            cache: false; asynchronous: true
            fillMode: Image.PreserveAspectFit
            playing: root.active && Motion.live(root) && ViewState.ambientEnabled && Motion.overdrive && ((root.player?.playing ?? false) || root.petActive)
            MouseArea { anchors.fill: parent; onClicked: { root.petActive = true; petTimer.restart(); } }
        }
        Timer { id: petTimer; interval: 1200; onTriggered: root.petActive = false }
        Activity { name: "media.cat"; running: cat.playing }
    }
}
