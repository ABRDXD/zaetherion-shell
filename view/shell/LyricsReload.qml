import QtQuick
import QtQuick.Layouts
import qs.view.contract
import qs.view.fluid
import qs.view.ui

// Settings → Palette: the current track's lyrics and a way to ask again (Side column, owner's pick B; Z223).
// Opening Settings asks nothing: the row reads what the lyrics domain already knows for the track playing now.
// Reload holds the "lyrics" lease and runs the domain's fresh lookup (Z220: past a remembered miss); the lease ends
// when the section closes. Without a track the label stays and the action is off.
SettingsSideRow {
    id: root
    required property MediaDomain media
    required property LyricsDomain lyrics
    property bool active: false
    property bool asked: false
    readonly property var track: media.active
    readonly property bool hasTrack: !!(track && track.title)
    readonly property bool current: lyrics.currentKey !== "" && lyrics.trackKey === lyrics.currentKey

    HostLease { domain: root.lyrics; feature: "lyrics"; active: root.active && root.asked }
    onActiveChanged: if (!active) asked = false
    function reload() {
        asked = true;
        Qt.callLater(() => root.lyrics.reload()); // after the lease reaches the domain
    }
    function state() {
        if (!hasTrack) return "Nothing playing";
        if (!current) return asked ? "Looking for lyrics" : "Not looked up yet";
        return { loading: "Looking for lyrics", ok: "Lyrics found", none: "No lyrics found", "no-track": "Nothing playing" }[lyrics.status]
            ?? "Not looked up yet";
    }

    SettingsText {
        technical: !Design.fluid
        font.pixelSize: Design.fluid ? FluidTokens.caption : Design.caption
        color: Design.muted
        text: Design.fluid ? "Lyrics" : "LYRICS"
    }
    SettingsText {
        objectName: "lyricsTrack"
        Layout.fillWidth: true
        elide: Text.ElideRight
        font.family: Design.fluid ? FluidTokens.sans : Design.sans
        font.capitalization: Font.MixedCase
        font.pixelSize: Design.fluid ? FluidTokens.heading : Design.readout
        font.weight: Design.fluid ? Font.Normal : Font.Bold
        font.letterSpacing: 0
        color: root.hasTrack ? Design.ink : Design.faint
        text: root.hasTrack ? root.track.title : "No track"
    }
    SettingsText {
        objectName: "lyricsState"
        Layout.fillWidth: true
        technical: !Design.fluid
        font.capitalization: Font.MixedCase
        font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
        color: Design.muted
        text: root.state()
    }
    actions: [
        SettingsAction {
            objectName: "lyricsReload"
            label: "Reload lyrics"
            leads: true
            underline: false
            enabled: root.hasTrack && root.lyrics.available && !(root.asked && root.lyrics.status === "loading")
            onActivated: root.reload()
        }
    ]
}
