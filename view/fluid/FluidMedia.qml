import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.view.rooms
import qs.view.shell
import qs.view.cues
import qs.view.ui

// A continuous listening surface. Actions, player state and leases belong to MediaSession.
ColumnLayout {
    id: root
    required property MediaSession session
    readonly property bool compact: width < 740
    readonly property real coverSide: Math.min(width * (compact ? 0.38 : 0.4), height * 0.42)
    spacing: FluidTokens.gap
    RowLayout {
        Layout.fillWidth: true
        FluidText { text: root.session.player?.playing ? "Now playing" : root.session.player ? "Paused" : "No player"; color: FluidTokens.secondary }
        Item { Layout.fillWidth: true }
        FluidChoice {
            objectName: "media.player"
            Layout.preferredWidth: Math.min(420, root.width * 0.65)
            label: "Media player"
            model: root.session.media.players.map(p => p.identity)
            currentIndex: root.session.media.players.findIndex(p => p.id === root.session.player?.id)
            onActivated: index => root.session.selectIndex(index)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        spacing: FluidTokens.sectionGap
        ColumnLayout {
            Layout.preferredWidth: root.coverSide
            Layout.maximumWidth: root.coverSide
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: FluidTokens.gap
            Rectangle {
                objectName: "media.cover"
                Layout.fillWidth: true
                Layout.preferredHeight: root.coverSide
                Layout.minimumHeight: 0
                radius: FluidTokens.imageRadius
                color: FluidTokens.control
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: FluidTokens.gap
                    source: root.session.player?.artUrl ?? ""
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectFit
                }
                FluidText {
                    anchors.centerIn: parent
                    visible: !root.session.player?.artUrl
                    text: "♪"
                    font.pixelSize: Design.display
                    color: FluidTokens.accent
                }
            }
            FluidText {
                Layout.fillWidth: true
                text: root.session.player?.title || "The room is quiet."
                font.pixelSize: FluidTokens.title
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            FluidText { Layout.fillWidth: true; text: root.session.player?.artist || ""; color: FluidTokens.secondary; elide: Text.ElideRight }
            FluidText { Layout.fillWidth: true; text: root.session.player?.album || ""; color: FluidTokens.secondary; elide: Text.ElideRight }
            Item { Layout.fillHeight: true }
            RowLayout {
                FluidButton { objectName: "media.open"; text: "Open player"; enabled: root.session.player?.canRaise ?? false; onClicked: root.session.openPlayer() }
                FluidButton { objectName: "media.lyrics"; text: "Lyrics"; selected: root.session.lyrics; onClicked: root.session.toggleLyrics() }
            }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: FluidTokens.rule }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            objectName: "media.lyricBody"
            Layout.fillHeight: true
            spacing: FluidTokens.gap
            FluidText { text: root.session.wordsShown ? "Lyrics" : "Listening"; color: FluidTokens.secondary }
            Item { Layout.fillHeight: true }
            Repeater {
                model: root.session.wordsShown && root.session.lyricsReady ? [-1, 0, 1, 2] : []
                FluidText {
                    required property int modelData
                    readonly property var entry: root.session.host.lyrics.lines[root.session.lyricIndex + modelData]
                    readonly property bool current: modelData === 0
                    Layout.fillWidth: true
                    visible: entry !== undefined || modelData === 0
                    text: entry?.text || "…"
                    font.pixelSize: current && Motion.overdrive ? FluidTokens.lyricEmphasis : FluidTokens.lyric
                    font.weight: modelData === 0 ? Font.Medium : Font.Normal
                    color: modelData === 0 ? FluidTokens.accent : FluidTokens.secondary
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            FluidText {
                Layout.fillWidth: true
                visible: !root.session.wordsShown || !root.session.lyricsReady
                text: !root.session.wordsShown ? "Space for the sound." : root.session.host.lyrics.status === "loading" ? "Listening for the words…" : "No lyrics for this track."
                font.pixelSize: FluidTokens.lyric
                wrapMode: Text.Wrap
                color: FluidTokens.secondary
            }
            Item { Layout.fillHeight: true }
            AnimatedImage {
                objectName: "media.pet"
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 78
                Layout.preferredHeight: 58
                Layout.maximumWidth: 78
                Layout.maximumHeight: 58
                source: Quickshell.shellPath("assets/caelestia/bongocat.gif")
                cache: false; asynchronous: true
                fillMode: Image.PreserveAspectFit
                playing: root.session.active && Motion.live(root) && ViewState.ambientEnabled && Motion.overdrive && ((root.session.player?.playing ?? false) || root.session.petActive)
                MouseArea { anchors.fill: parent; onClicked: root.session.tapPet() }
            }
        }
    }
    // Data-driven spectrum only: no idle timer, interpolation loop or full-surface effect.
    Row {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? FluidTokens.controlHeight : 0
        visible: root.session.visualising
        spacing: FluidTokens.unit
        Repeater {
            model: root.session.visualising ? root.session.media.spectrum : []
            Rectangle {
                required property real modelData
                width: Math.max(1, (parent.width - (root.session.media.spectrum.length - 1) * parent.spacing) / Math.max(1, root.session.media.spectrum.length))
                height: Math.max(1, Math.max(0, Math.min(1, modelData)) * parent.height)
                y: parent.height - height
                radius: FluidTokens.unit / 2
                color: FluidTokens.accent
            }
        }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: FluidTokens.rule }
    RowLayout {
        Layout.fillWidth: true
        FluidText { technical: true; text: Clock.formatSeconds(root.session.player ? root.session.media.position : 0); color: FluidTokens.secondary }
        Slider {
            id: seek
            objectName: "media.seek"
            Layout.fillWidth: true
            enabled: (root.session.player?.canSeek ?? false) && root.session.length > 0
            Accessible.name: "Track position"
            from: 0; to: Math.max(1, root.session.length)
            value: root.session.media.position
            onMoved: root.session.seek(value)
            background: Rectangle {
                x: seek.leftPadding
                y: seek.topPadding + seek.availableHeight / 2 - height / 2
                width: seek.availableWidth; height: FluidTokens.unit / 2
                color: FluidTokens.rule
                Rectangle { width: seek.visualPosition * parent.width; height: parent.height; color: FluidTokens.accent }
            }
            handle: Rectangle {
                x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                y: seek.topPadding + seek.availableHeight / 2 - height / 2
                width: FluidTokens.unit * 3; height: width; radius: width / 2
                color: FluidTokens.accent
                border.width: seek.activeFocus ? 2 : 0; border.color: FluidTokens.ink
            }
        }
        FluidText { technical: true; text: root.session.length > 0 ? Clock.formatSeconds(root.session.length) : root.session.player ? "Live" : "—"; color: FluidTokens.secondary }
    }
    RowLayout {
        Layout.fillWidth: true
        FluidButton { objectName: "media.shuffle"; text: "Shuffle"; selected: root.session.player?.shuffle ?? false; enabled: root.session.player?.shuffleSupported ?? false; onClicked: root.session.toggleShuffle() }
        Item { Layout.fillWidth: true }
        FluidButton { objectName: "media.previous"; text: "Previous"; enabled: root.session.player?.canPrevious ?? false; onClicked: root.session.previous() }
        FluidButton { objectName: "media.play"; text: root.session.player?.playing ? "Pause" : "Play"; primary: true; enabled: root.session.player?.canToggle ?? false; onClicked: root.session.togglePlaying() }
        FluidButton { objectName: "media.next"; text: "Next"; enabled: root.session.player?.canNext ?? false; onClicked: root.session.next() }
        Item { Layout.fillWidth: true }
        FluidButton { objectName: "media.loop"; text: root.session.player?.loop === "track" ? "Repeat track" : "Repeat"; selected: (root.session.player?.loop ?? "none") !== "none"; enabled: root.session.player?.loopSupported ?? false; onClicked: root.session.toggleLoop() }
    }
}
