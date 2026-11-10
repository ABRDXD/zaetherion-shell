import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.view.contract

MediaDomain {
    id: root
    readonly property var raw: Mpris.players.values
    property var manual: null
    readonly property var preferredRaw: {
        const wanted = preferredPlayer.toLowerCase();
        return wanted ? raw.find(p => p.identity.toLowerCase().includes(wanted) || (p.desktopEntry ?? "").toLowerCase().includes(wanted)) ?? null : null;
    }
    readonly property var activeRaw: manual && raw.includes(manual) ? manual : (preferredRaw ?? raw.find(p => p.isPlaying) ?? raw[0] ?? null)
    function idOf(p) { return p.dbusName || p.identity; }
    function loopName(state) { return state === MprisLoopState.Track ? "track" : state === MprisLoopState.Playlist ? "playlist" : "none"; }
    function describe(p) {
        return {
            id: idOf(p), identity: p.identity ?? "", desktopEntry: p.desktopEntry ?? "",
            title: p.trackTitle ?? "", artist: p.trackArtist ?? "", album: p.trackAlbum ?? "", artUrl: p.trackArtUrl ?? "",
            length: p.lengthSupported ? p.length : 0, playing: p.isPlaying,
            canToggle: p.canTogglePlaying, canNext: p.canGoNext, canPrevious: p.canGoPrevious,
            canSeek: p.canSeek, canRaise: p.canRaise,
            shuffle: p.shuffle, shuffleSupported: p.shuffleSupported,
            loop: loopName(p.loopState), loopSupported: p.loopSupported
        };
    }
    available: true
    players: raw.map(p => describe(p))
    active: activeRaw ? describe(activeRaw) : null
    selection: manual && raw.includes(manual) ? idOf(manual) : ""

    function samplePosition() {
        position = activeRaw?.position ?? 0;
        positionStamp = Date.now();
    }
    onActiveRawChanged: samplePosition()
    onLeasesChanged: if (holds("position")) samplePosition()
    Connections {
        target: root.activeRaw
        function onPositionChanged() { root.samplePosition(); }
        function onPlaybackStateChanged() { root.samplePosition(); }
        function onTrackTitleChanged() { root.samplePosition(); }
    }
    Timer {
        interval: 500
        repeat: true
        running: root.holds("position") && (root.activeRaw?.isPlaying ?? false)
        onTriggered: root.samplePosition()
    }

    function select(playerId: string) { manual = playerId ? raw.find(p => idOf(p) === playerId) ?? null : null; }
    function togglePlaying() { if (activeRaw?.canTogglePlaying) activeRaw.togglePlaying(); }
    function next() { if (activeRaw?.canGoNext) activeRaw.next(); }
    function previous() { if (activeRaw?.canGoPrevious) activeRaw.previous(); }
    function seek(seconds: real) {
        if (!activeRaw?.canSeek) return;
        activeRaw.position = Math.max(0, seconds);
        samplePosition();
    }
    function setShuffle(on: bool) { if (activeRaw?.shuffleSupported) activeRaw.shuffle = on; }
    function setLoop(mode: string) {
        if (!activeRaw?.loopSupported) return;
        activeRaw.loopState = mode === "track" ? MprisLoopState.Track : mode === "playlist" ? MprisLoopState.Playlist : MprisLoopState.None;
    }
    function raise() { if (activeRaw?.canRaise) activeRaw.raise(); }

    // CAVA runs only while a spectrum lease is held and the active player is playing.
    Process {
        id: cava
        running: root.holds("spectrum") && (root.activeRaw?.isPlaying ?? false)
        command: ["cava", "-p", Quickshell.shellPath("tools/cava.conf")]
        onRunningChanged: if (!running) root.spectrum = []
        stdout: SplitParser {
            onRead: line => {
                const bars = line.trim().split(";").slice(0, 56).map(Number);
                if (bars.length === 56 && bars.every(Number.isFinite)) root.spectrum = bars.map(v => Math.min(1, Math.max(0, v / 1000)));
            }
        }
    }
}
