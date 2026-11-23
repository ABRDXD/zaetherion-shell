// Players and transport. Player: { id, identity, desktopEntry, title, artist, album, artUrl,
// length, playing, canToggle, canNext, canPrevious, canSeek, canRaise, shuffle, shuffleSupported,
// loop ("none" | "track" | "playlist"), loopSupported }.
HostDomain {
    property var players: []
    property var active: null
    property string selection: ""
    property string preferredPlayer: ""
    // Lease "position": seconds, sampled at positionStamp (epoch ms); extrapolate while playing.
    property real position: 0
    property real positionStamp: 0
    // Lease "spectrum": 56 bins 0..1, empty unless the active player is playing.
    property var spectrum: []

    function select(playerId: string) { record("select", [playerId]); }
    function togglePlaying() { record("togglePlaying", []); }
    function next() { record("next", []); }
    function previous() { record("previous", []); }
    function seek(seconds: real) { record("seek", [seconds]); }
    function setShuffle(on: bool) { record("setShuffle", [on]); }
    function setLoop(mode: string) { record("setLoop", [mode]); }
    function raise() { record("raise", []); }
}
