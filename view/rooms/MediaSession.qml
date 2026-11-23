import QtQuick
import qs.view.contract
import qs.view.shell
import qs.view.cues
import qs.view.ui

// One owner for state, actions, timing and leases, shared by both Media presentations.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property bool shown: false
    property bool lyrics: false
    property bool petActive: false
    property bool followAutomaticLyrics: false
    readonly property var media: host.media
    readonly property var player: media.active
    readonly property bool active: shown && shell.panelOpen
    readonly property bool lyricsReady: host.lyrics.status === "ok" && host.lyrics.lines.length > 0
    readonly property real length: player?.length ?? 0
    readonly property real progress: player && length > 0 ? Math.max(0, Math.min(1, media.position / length)) : 0
    readonly property bool reactive: active && ViewState.ambientEnabled && Motion.overdrive && (player?.playing ?? false)
    readonly property bool visualising: active && ViewState.visualiserEnabled && !Motion.reduced && (player?.playing ?? false)
    readonly property bool kineticWanted: active && (player?.playing ?? false) && Motion.engaged && !Motion.reduced
    readonly property bool kineticOn: kineticWanted && lyricsReady
    readonly property bool wordsShown: lyrics || kineticOn
    readonly property int lyricIndex: timeline.index
    onActiveChanged: if (!active) { petTimer.stop(); petActive = false; }

    HostLease { domain: root.media; feature: "position"; active: root.active }
    HostLease { domain: root.media; feature: "spectrum"; active: root.visualising || (root.active && ViewState.ambientEnabled && Motion.overdrive) }
    HostLease { domain: root.host.lyrics; feature: "lyrics"; active: root.active && (root.lyrics || root.kineticWanted) }
    LyricsTimeline {
        id: timeline
        active: root.active && (root.lyrics || (root.followAutomaticLyrics && root.kineticOn)) && root.lyricsReady
        lines: root.host.lyrics.lines
        position: root.media.position
        positionStamp: root.media.positionStamp
        playing: root.player?.playing ?? false
    }
    Timer { id: petTimer; interval: 1200; onTriggered: root.petActive = false }
    function tapPet() { petActive = true; petTimer.restart(); }
    function toggleLyrics() { lyrics = !lyrics; }
    function togglePlaying() { if (player?.canToggle) media.togglePlaying(); }
    function previous() { if (player?.canPrevious) media.previous(); }
    function next() { if (player?.canNext) media.next(); }
    function toggleShuffle() { if (player?.shuffleSupported) media.setShuffle(!player.shuffle); }
    function toggleLoop() { if (player?.loopSupported) media.setLoop(player.loop === "none" ? "playlist" : "none"); }
    function seek(seconds) { if (player?.canSeek && length > 0 && Number.isFinite(seconds)) media.seek(Math.max(0, Math.min(length, seconds))); }
    function selectIndex(index) { if (index >= 0 && index < media.players.length) media.select(media.players[index].id); }
    function openPlayer() { if (player?.canRaise) { media.raise(); shell.close(); } }
}
