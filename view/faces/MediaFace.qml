import qs.view.contract
import QtQuick

// Media as a planet: whether something plays, what it is and who made it. The player's own state;
// no lease (the spectrum is the Media room's, and the position is never shown here).
Face {
    id: root
    required property HostAdapter host
    readonly property var player: host.media.active
    readonly property bool playing: player?.playing ?? false

    brief: !player ? "QUIET" : playing ? "PLAYING" : "PAUSED"
    figure: brief
    note: player ? (player.title || "UNTITLED") : "NOTHING PLAYING"
    detail: player ? (player.artist || player.identity || "") : ""

    Accessible.role: Accessible.StaticText
    Accessible.name: !player ? "Nothing playing" : (playing ? "Playing " : "Paused ") + (player.title || "")
}
