import qs.view.contract

// Inert host for offscreen tests: contract defaults plus fixed sample data. Methods only log calls.
HostAdapter {
    name: "fixture"
    media: MediaDomain {
        recordCalls: true
        available: true
        players: [active]
        active: ({ id: "org.mpris.MediaPlayer2.fixture", identity: "Fixture Player", desktopEntry: "fixture",
            title: "Fixture Signal", artist: "Test Pattern", album: "Calibration", artUrl: "", length: 200, playing: false,
            canToggle: true, canNext: true, canPrevious: true, canSeek: true, canRaise: false,
            shuffle: false, shuffleSupported: true, loop: "none", loopSupported: true })
        position: 42
    }
    audio: AudioDomain {
        recordCalls: true
        available: true
        // As the contract says: levels exist only while a "mixer" lease is held.
        output: holds("mixer") ? ({ id: "1", name: "Fixture Speakers", volume: 0.4, muted: false }) : null
        input: holds("mixer") ? ({ id: "2", name: "Fixture Microphone", volume: 0.6, muted: true }) : null
        outputs: [{ id: "1", name: "Fixture Speakers", isDefault: true }]
        inputs: [{ id: "2", name: "Fixture Microphone", isDefault: true }]
        streams: holds("mixer") ? [{ id: "3", app: "Fixture Player", volume: 0.8, muted: false }] : []
        equalizer: EqualizerDomain { recordCalls: true; available: true; presets: ["Flat", "Vocal"]; preset: "Vocal"; bands: [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0] }
    }
    network: NetworkDomain {
        recordCalls: true; available: true; wifiEnabled: true; kind: "wifi"; connected: true; name: "FIXTURE-NET"; ipAddress: "192.0.2.10"
        networks: holds("scan") ? [
            { id: "FIXTURE-NET", ssid: "FIXTURE-NET", strength: 0.82, secured: true, known: true, connected: true },
            { id: "FIXTURE-CAFE", ssid: "FIXTURE-CAFE", strength: 0.55, secured: false, known: true, connected: false },
            { id: "FIXTURE-NEIGHBOUR", ssid: "FIXTURE-NEIGHBOUR", strength: 0.3, secured: true, known: false, connected: false }
        ] : []
    }
    bluetooth: BluetoothDomain {
        recordCalls: true
        available: true
        enabled: true
        devices: [{ id: "00:00:5E:00:53:01", name: "Fixture Headset", kind: "audio-headset", connected: true, paired: true, battery: 0.7 },
                  { id: "00:00:5E:00:53:02", name: "Fixture Keyboard", kind: "input-keyboard", connected: false, paired: true, battery: -1 }]
        primary: devices[0]
    }
    notifications: NotificationsDomain {
        recordCalls: true
        available: true
        items: [{ id: "1", appName: "Fixture", summary: "Calibration notice", body: "Fixture body text.", time: 1767225600000, urgency: "normal", read: false, hasActions: true }]
        unread: 1
    }
    keybinds: KeybindsDomain {
        available: true
        binds: [{ mods: ["SUPER"], key: "V", section: "Utilities", description: "Clipboard history" },
                { mods: ["SUPER", "SHIFT"], key: "S", section: "Utilities", description: "Screen snip" },
                { mods: ["SUPER"], key: "Q", section: "Window", description: "Close" },
                { mods: ["SUPER"], key: "RETURN", section: "Apps", description: "Terminal" },
                { mods: ["CTRL"], key: "Print", section: "Utilities", description: "Screenshot to file" }]
    }
    workspaces: WorkspacesDomain {
        recordCalls: true
        available: true
        focusedScreen: "FIXTURE-1"
        activeId: "1"
        workspaces: [{ id: "1", name: "1", monitor: "FIXTURE-1", active: true, windowCount: 3 },
                     { id: "3", name: "3", monitor: "FIXTURE-1", active: false, windowCount: 1 }]
        windows: [{ id: "0xfixture", title: "Fixture Window", appId: "fixture", workspaceId: "1", monitor: "FIXTURE-1",
            x: 0, y: 48, width: 960, height: 1032, floating: false, fullscreen: false, focused: true },
            { id: "0xfixture2", title: "Fixture Terminal", appId: "fixture-term", workspaceId: "1", monitor: "FIXTURE-1",
            x: 960, y: 48, width: 960, height: 516, floating: false, fullscreen: false, focused: false },
            { id: "0xfixture3", title: "Fixture Notes", appId: "fixture-notes", workspaceId: "1", monitor: "FIXTURE-1",
            x: 960, y: 564, width: 960, height: 516, floating: false, fullscreen: false, focused: false },
            { id: "0xfixture4", title: "Fixture Browser", appId: "fixture-browser", workspaceId: "3", monitor: "FIXTURE-1",
            x: 300, y: 200, width: 1200, height: 700, floating: true, fullscreen: false, focused: false }]
        monitors: [{ name: "FIXTURE-1", x: 0, y: 0, width: 1920, height: 1080, scale: 1, reservedTop: 48, reservedBottom: 0 }]
    }
    power: PowerDomain {
        recordCalls: true
        available: true
        battery: ({ available: true, level: 0.64, charging: false, pluggedIn: false })
        profile: "balanced"
        profiles: ["power-saver", "balanced", "performance"]
        brightness: ({ available: true, level: 0.5 })
    }
    palette: PaletteDomain { available: true; colors: ({ background: "#123456", text: "#f0f0f0" }); opacity: 0.62; radius: 6 }
    // FART's default motion (docs/CUES.md §15).
    motion: MotionDomain {}
    hostActions: HostActionsDomain {
        recordCalls: true
        available: true
        name: "fixture"
        targets: ["launcher", "settings", "power", "notifications", "wifi", "bluetooth", "music", "updates"]
        recording: ({ available: true, active: false, startedAt: 0 })
    }
    sfx: SfxDomain { recordCalls: true; available: true }
    clockGeometry: ClockGeometryDomain { recordCalls: true; available: true }
    lyrics: LyricsDomain {
        recordCalls: true
        available: true
        status: "ok"
        source: "fixture"
        trackKey: "Test Pattern - Fixture Signal"
        lines: [{ time: 0, end: 40, text: "First fixture line", words: [] }, { time: 40, end: 200, text: "Second fixture line", words: [] }]
    }
    system: SystemDomain {
        available: true
        user: "fixture"
        hostname: "fixture-host"
        cpuModel: "Fixture CPU"
        uptime: 3720
        cpu: ({ available: true, usage: 0.25, history: [0.2, 0.25], temperature: 48 })
        memory: ({ available: true, total: 16777216, used: 8388608, history: [0.5], swapTotal: 4194304, swapUsed: 0 })
        disk: ({ available: true, total: 500000000, used: 250000000, free: 250000000 })
        gpu: ({ available: true, failed: false, usage: 0.1, temperature: 40, vramUsed: null, vramTotal: null, source: "fixture", error: "", history: [0.1] })
    }
    clipboard: ClipboardDomain {
        recordCalls: true
        available: true
        entries: [{ id: "2", text: "fixture clip text", isImage: false }, { id: "1", text: "[[ binary data 1 KiB png 8x8 ]]", isImage: true }]
    }
}
