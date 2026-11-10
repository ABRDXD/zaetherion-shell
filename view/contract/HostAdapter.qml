import Quickshell

// The single object the view receives. Adapters fill every domain; defaults are "unavailable".
// An adapter may leave a domain the panel's first frame does not show on its default until
// loadDeferred(), which the view calls once the first open has settled (docs/ADAPTER_CONTRACT.md §1).
Scope {
    function loadDeferred() {}
    property string name: ""
    property MediaDomain media: MediaDomain {}
    property AudioDomain audio: AudioDomain {}
    property NetworkDomain network: NetworkDomain {}
    property BluetoothDomain bluetooth: BluetoothDomain {}
    property NotificationsDomain notifications: NotificationsDomain {}
    property WorkspacesDomain workspaces: WorkspacesDomain {}
    property PowerDomain power: PowerDomain {}
    property PaletteDomain palette: PaletteDomain {}
    property MotionDomain motion: MotionDomain {}
    property HostActionsDomain hostActions: HostActionsDomain {}
    property SfxDomain sfx: SfxDomain {}
    property ClockGeometryDomain clockGeometry: ClockGeometryDomain {}
    property LyricsDomain lyrics: LyricsDomain {}
    property SystemDomain system: SystemDomain {}
    property ClipboardDomain clipboard: ClipboardDomain {}
    property KeybindsDomain keybinds: KeybindsDomain {}
}
