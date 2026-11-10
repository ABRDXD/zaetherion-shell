import qs.view.cues
import qs.view.ui
import QtQuick
import QtQuick.Shapes
import "../rooms/TaskEntry.js" as TaskEntry

// Every room's own system out in space around the main one (docs/ORBIT.md §0, "other systems"): the
// room's things as moons around a sun that carries its headline reading. Moons act — they are controls,
// not pictures — and a sun dives into its room. OrbitSystem places them (systemCentre) and joins each to
// its planet; this file says what is in each. Readings that need sampling (Performance, Clips) hold their
// lease only while the overview is open. Nothing moves at rest; Timers' readings step when a shown second
// changes, and only while one runs.
Item {
    id: root
    // The OrbitSystem these belong to (its geometry, its camera's tilt and rise, and choose()).
    required property Item orbit
    property var host: null
    property var core: null
    // The ShellContext: night light closes the shell first, as the Devices room does.
    property var shell: null
    // Readings that need sampling are leased while this is true (the overview is open and at rest).
    property bool live: false
    signal acted(string id)
    // Every moon's foot on the plane, for the fabric under them (OrbitSystem): [{ x, y }].
    // A raised system's moons press the fabric under the system's place, so their feet come down by its height.
    // A function, not a binding: as one it was rebuilt for every system's every move, dozens of times a frame in Overdrive.
    function moonFeet() {
        return [].concat(...[mediaSystem, perfSystem, deskSystem, devicesSystem, tasksSystem, timersSystem, clipsSystem, codexSystem, inboxSystem]
            .map(s => (s?.feet() ?? []).map(f => ({ x: f.x, y: f.y + s.altitude }))));
    }

    readonly property var systems: ({
        media: mediaSystem, performance: perfSystem, workspaces: deskSystem, devices: devicesSystem,
        tasks: tasksSystem, timers: timersSystem, clipboard: clipsSystem, notifications: inboxSystem, codex: codexSystem
    })
    function act(id, sound) {
        Feedback.play(sound ?? "ui.click");
        acted(id);
    }
    function percent(on, ratio) { return on ? Math.round(Math.max(0, Math.min(1, ratio)) * 100) + "%" : "—"; }
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds)), h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : String(m).padStart(2, "0")) + ":" + String(s % 60).padStart(2, "0");
    }
    function title(id) {
        const k = orbit.rooms.findIndex(p => p.id === id);
        return String(k + 1).padStart(2, "0") + "  " + (orbit.rooms[k]?.name ?? "").toUpperCase();
    }

    // One system per room, all the same make: on the orbit's plane and tilt, risen with it.
    component RoomSystem: SpaceSystem {
        required property string room
        readonly property var c: root.orbit.systemCentre(room)
        // Overdrive: the system bobs over its height and its moons circle (0 in Silent).
        readonly property real altitude: root.orbit.systemAltitude(room) + root.orbit.systemBob(room)
        anchors.fill: parent
        cx: c.x
        cy: c.y - altitude
        spin: root.orbit.moonSpin(room)
        outer: root.orbit.systemOuter
        // At rest: they are never built during a flight, so the tilt's swing and the rise never reach them.
        elevation: 45
        rise: 1
        interactive: root.orbit.interactive
        // Moons a little under a planet, large enough for a readable name beside or under the symbol.
        tileW: Math.round(root.orbit.tileW * 0.82)
        sunW: Math.round(root.orbit.tileW * 1.4)
        sunH: Math.round(root.orbit.tileH * 1.4)
        onSunClicked: root.orbit.choose(root.orbit.indexOf(room))
    }

    // The tethers: from each system's place on the plane (where its route arrives) up to the raised system,
    // a dashed hairline with a node on the plane. Still in Silent; in Overdrive they stretch as the systems bob.
    Shape {
        id: tethers
        z: -0.5
        preferredRendererType: Shape.CurveRenderer
        Instantiator {
            model: Object.keys(root.systems)
            delegate: ShapePath {
                required property string modelData
                readonly property var c: root.orbit.systemCentre(modelData)
                readonly property real up: root.orbit.systemAltitude(modelData) + root.orbit.systemBob(modelData)
                strokeColor: Qt.alpha(Design.accent, 0.5)
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 4]
                fillColor: "transparent"
                startX: c.x
                startY: c.y
                PathLine { x: c.x; y: c.y - up }
            }
            onObjectAdded: (index, object) => tethers.data.push(object)
        }
    }
    Repeater {
        model: Object.keys(root.systems)
        Rectangle {
            required property string modelData
            readonly property var c: root.orbit.systemCentre(modelData)
            x: c.x - 4
            y: c.y - 4
            z: -0.5
            width: 8
            height: 8
            rotation: 45
            color: Design.accent
            opacity: 0.7
        }
    }

    // 01 Media: what is playing on the sun; the transport and each player around it.
    readonly property var media: host?.media ?? null
    readonly property var player: media?.active ?? null
    RoomSystem {
        id: mediaSystem
        room: "media"
        sunW: Math.round(root.orbit.tileW * 1.9)
        moons: [
            // One ring: the Media sun is wide, and an inner ring would pass under it.
            { number: "", name: "PREVIOUS", symbol: "skip_previous" },
            { number: "", name: root.player?.playing ? "PAUSE" : "PLAY", symbol: root.player?.playing ? "pause" : "play_arrow", current: root.player?.playing ?? false },
            { number: "", name: "NEXT", symbol: "skip_next" },
            ...(root.media?.players ?? []).map(p => ({ number: "", name: p.identity || p.id, symbol: "graphic_eq", current: p.id === root.player?.id }))
        ]
        onActivated: index => {
            if (!root.media)
                return;
            root.act("media");
            if (index === 0) root.media.previous();
            else if (index === 1) root.media.togglePlaying();
            else if (index === 2) root.media.next();
            else root.media.select((root.media.players ?? [])[index - 3]?.id ?? "");
        }
        // The cover, square and plainly clipped: a Shape-cut disc escapes the clip under the camera's scale.
        Rectangle {
            x: parent.run + 4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 14
            height: width
            color: Design.surface
            clip: true
            Image {
                anchors.fill: parent
                source: root.player?.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(128, 128)
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: !(root.player?.artUrl)
                text: "music_note"
                iconSize: parent.width * 0.5
                color: Design.faint
            }
        }
        Column {
            x: parent.height + parent.run
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 10
            spacing: 2
            FText {
                width: parent.width
                text: root.title("media")
                technical: true
                font.weight: Font.Bold
                color: parent.parent.ink
            }
            FText {
                width: parent.width
                text: root.player?.title || "Nothing playing"
                headline: true
                font.pixelSize: Design.control
                font.weight: Font.Black
                elide: Text.ElideRight
                color: parent.parent.ink
            }
            FText {
                width: parent.width
                text: root.player?.artist ?? ""
                technical: true
                elide: Text.ElideRight
                color: parent.parent.ink
                opacity: 0.8
            }
        }
    }

    // 02 Performance: the load on the sun; each reading a moon.
    readonly property var sys: host?.system ?? null
    HostLease { domain: root.sys; feature: "resources"; active: root.live }
    readonly property var cpu: sys?.cpu ?? ({})
    readonly property var memory: sys?.memory ?? ({})
    readonly property var disk: sys?.disk ?? ({})
    RoomSystem {
        id: perfSystem
        room: "performance"
        moons: [
            { number: root.percent(root.cpu.available, root.cpu.usage), name: "CPU", symbol: "memory" },
            { number: root.percent(root.memory.available, root.memory.used / Math.max(1, root.memory.total)), name: "MEMORY", symbol: "memory_alt" },
            { number: root.percent(root.disk.available, root.disk.used / Math.max(1, root.disk.total)), name: "DISK", symbol: "hard_drive" },
            { number: root.cpu.temperature != null ? Math.round(root.cpu.temperature) + "°" : "—", name: "CPU TEMP", symbol: "thermostat" },
            { number: root.sys?.uptime > 0 ? Math.floor(root.sys.uptime / 3600) + "H" : "—", name: "UPTIME", symbol: "schedule" }
        ]
        onActivated: root.orbit.choose(root.orbit.indexOf("performance"))
        SunFace {
            title: root.title("performance")
            value: "CPU " + root.percent(root.cpu.available, root.cpu.usage)
            footer: (root.sys?.hostname || "THIS MACHINE").toUpperCase()
        }
    }

    // 03 Workspaces: the desks, with their window counts; the current one ink. A click goes to that desk.
    readonly property var wm: host?.workspaces ?? null
    readonly property int deskCount: Math.max(7, Math.min(12, Config.options.bar.workspaces.shown))
    readonly property int activeDesk: Number(wm?.activeId) || 1
    readonly property var deskWindows: {
        const out = [];
        for (let i = 1; i <= deskCount; i++)
            out.push((wm?.windows ?? []).filter(w => Number(w.workspaceId) === i).length);
        return out;
    }
    RoomSystem {
        id: deskSystem
        room: "workspaces"
        moons: root.deskWindows.map((n, i) => ({
            number: String(i + 1).padStart(2, "0"),
            name: n === 0 ? "EMPTY" : n + (n === 1 ? " WINDOW" : " WINDOWS"),
            symbol: "",
            current: i + 1 === root.activeDesk,
            ring: root.deskCount > 8 && i < Math.ceil(root.deskCount / 2) ? 0 : 1
        }))
        onActivated: index => {
            root.act("workspaces", "ui.switch");
            root.wm?.switchTo(String(index + 1));
        }
        SunFace {
            title: root.title("workspaces")
            value: "DESK " + String(root.activeDesk).padStart(2, "0")
            footer: root.deskWindows.reduce((a, n) => a + n, 0) + " WINDOWS · " + root.deskCount + " DESKS"
        }
    }

    // 04 Devices: each switch a moon (lit when on). A click flips it, as the room's own switches do.
    readonly property var net: host?.network ?? null
    readonly property var bt: host?.bluetooth ?? null
    readonly property var audio: host?.audio ?? null
    readonly property var power: host?.power ?? null
    // output and input are valid only while "mixer" is held (ADAPTER_CONTRACT): the sink and source bound.
    HostLease { domain: root.audio; feature: "mixer"; active: root.live }
    readonly property var output: audio?.output ?? null
    readonly property var input: audio?.input ?? null
    RoomSystem {
        id: devicesSystem
        room: "devices"
        moons: [
            { number: "", name: !root.net?.wifiEnabled ? "WI-FI OFF" : root.net?.connected ? (root.net.name || "WI-FI") : "WI-FI ON", symbol: root.net?.wifiEnabled ? "wifi" : "wifi_off", current: root.net?.wifiEnabled ?? false },
            { number: "", name: !root.bt?.available ? "NO BLUETOOTH" : root.bt.enabled ? (root.bt.primary?.name || "BLUETOOTH") : "BLUETOOTH OFF", symbol: root.bt?.available && root.bt.enabled ? "bluetooth" : "bluetooth_disabled", current: (root.bt?.available && root.bt.enabled) ?? false, enabled: root.bt?.available ?? false },
            { number: root.output ? root.percent(true, root.output.volume) : "—", name: root.output?.muted ? "MUTED" : "OUTPUT", symbol: root.output?.muted ? "volume_off" : "volume_up", current: !!root.output && !root.output.muted },
            { number: "", name: !root.input ? "NO MIC" : root.input.muted ? "MIC OFF" : "MIC ON", symbol: root.input && !root.input.muted ? "mic" : "mic_off", current: !!root.input && !root.input.muted },
            { number: "", name: "NIGHT LIGHT", symbol: "nightlight", current: root.power?.nightLight ?? false },
            { number: "", name: "STAY AWAKE", symbol: "coffee", current: root.power?.idleInhibited ?? false }
        ]
        onActivated: index => {
            root.act("devices");
            if (index === 0) root.net?.setWifiEnabled(!root.net.wifiEnabled);
            else if (index === 1 && root.bt?.available) root.bt.setEnabled(!root.bt.enabled);
            else if (index === 2 && root.output) root.audio.setMuted(root.output.id, !root.output.muted);
            else if (index === 3 && root.input) root.audio.setMuted(root.input.id, !root.input.muted);
            else if (index === 4 && root.power) {
                // The host may open its own panel for this, which would come up behind the orbit.
                const on = !root.power.nightLight;
                root.shell?.close();
                root.power.setNightLight(on);
            }
            else if (index === 5) root.power?.setIdleInhibited(!root.power.idleInhibited);
        }
        SunFace {
            readonly property var battery: root.power?.battery ?? ({})
            title: root.title("devices")
            value: battery.available ? Math.round(battery.level * 100) + "%" + (battery.charging ? " ↑" : "") : (root.net?.connected ? (root.net.kind === "ethernet" ? "ETHERNET" : "ONLINE") : "OFFLINE")
            footer: (root.net?.connected ? (root.net.name || root.net.kind) : "NO NETWORK").toUpperCase() + (root.power?.profile ? " · " + root.power.profile.toUpperCase() : "")
        }
    }

    // 05 Tasks: the open tasks of every list as moons, the late ones first; a click ticks one off. Due
    // dates are read against the day the overview last opened, as the face does; no timer.
    readonly property var tasks: core?.tasks ?? null
    property date today: new Date()
    readonly property var openTasks: {
        const open = (tasks?.all ?? []).filter(t => !t.done);
        return open.filter(t => root.isLate(t)).concat(open.filter(t => !root.isLate(t)));
    }
    function isLate(t) { return TaskEntry.state(t.due, today) === "overdue"; }
    readonly property int lateTasks: openTasks.filter(t => isLate(t)).length
    RoomSystem {
        id: tasksSystem
        room: "tasks"
        moons: root.openTasks.slice(0, 8).map(t => ({ number: "", name: t.text, symbol: root.isLate(t) ? "event_busy" : "check_box_outline_blank" }))
        onActivated: index => {
            const task = root.openTasks[index];
            if (!task)
                return;
            root.act("tasks");
            root.tasks.setDone(task.id, true);
        }
        SunFace {
            readonly property int done: (root.tasks?.all ?? []).length - root.openTasks.length
            readonly property string more: root.openTasks.length > 8 ? " · " + (root.openTasks.length - 8) + " MORE INSIDE" : ""
            title: root.title("tasks")
            value: !root.tasks?.available ? "OFFLINE" : root.openTasks.length === 0 ? "ALL DONE" : root.openTasks.length + " OPEN"
            // The room's plate counts the selected list; these are every list's, and say so.
            footer: !root.tasks?.available ? "" : root.lateTasks > 0 ? root.lateTasks + " LATE · ALL LISTS" + more : "ALL LISTS · " + done + " DONE" + more
            alarm: (root.tasks?.available ?? false) && root.lateTasks > 0
        }
    }

    // 06 Timers: the three instruments; a click starts or pauses one (a stopped countdown starts at 5 min),
    // or clears its DONE. Readings are in whole seconds, rounded down; the sun shows what ends soonest,
    // as the planet face does. They step by a single shot armed for the next shown second, never late.
    readonly property var timers: core?.timers ?? null
    readonly property var snap: timers?.snap ?? null
    property double now: Date.now()
    onLiveChanged: { now = Date.now(); if (live) today = new Date(); armStep(); }
    onSnapChanged: { now = Date.now(); armStep(); }
    function elapsed(kind) {
        const t = snap?.[kind];
        return !t ? 0 : t.elapsed + (t.running ? Math.max(0, (now - snap.at) / 1000) : 0);
    }
    readonly property real pomodoroLeft: Math.max(0, (timers?.pomodoroLapDuration ?? 0) - elapsed("pomodoro"))
    readonly property real stopwatchTime: elapsed("stopwatch")
    readonly property real countdownLeft: Math.max(0, (timers?.countdownDuration ?? 0) - elapsed("countdown"))
    readonly property bool pomodoroDone: !!timers?.pomodoroDone
    readonly property bool countdownDone: timers?.countdownDone ?? false
    readonly property bool timersRunning: timers?.anyRunning ?? false
    // What each moon reads: { seconds, running }.
    readonly property var readings: [
        { seconds: (timers?.pomodoroLapDuration ?? 0) > 0 ? pomodoroLeft : (timers?.focusTime ?? 1500), running: timers?.pomodoroRunning ?? false },
        { seconds: stopwatchTime, running: timers?.stopwatchRunning ?? false },
        { seconds: (timers?.countdownDuration ?? 0) > 0 ? countdownLeft : 300, running: timers?.countdownRunning ?? false }
    ]
    function reading(i) { return clock(readings[i].seconds); }
    // The milliseconds until any running reading's shown second changes, a few ms past the boundary.
    function armStep() {
        if (!live || !timersRunning) {
            timerStep.stop();
            return;
        }
        // Shown rounded down: a reading counting down (pomodoro, countdown) changes when it falls to
        // its whole second, the stopwatch when it reaches the next one.
        let left = Infinity;
        readings.forEach((r, i) => {
            if (!r.running)
                return;
            const s = r.seconds, frac = s - Math.floor(s);
            left = Math.min(left, i === 1 ? 1 - frac : frac > 1e-3 ? frac : 1);
        });
        timerStep.interval = Math.max(20, Math.round((isFinite(left) ? left : 1) * 1000) + 4);
        timerStep.restart();
    }
    onTimersRunningChanged: armStep()
    Timer {
        id: timerStep
        repeat: false
        onTriggered: { root.now = Date.now(); root.armStep(); }
    }
    // The sun: a DONE first, then whichever countdown or focus ends soonest, then the stopwatch.
    readonly property var timersShown: {
        if (!timers?.available)
            return { value: "OFFLINE", note: "CORE OFFLINE", alarm: false };
        if (countdownDone || pomodoroDone)
            return { value: "DONE", note: countdownDone ? "COUNTDOWN DONE" : (timers.pomodoroDone.phase === "focus" ? "FOCUS" : "REST") + " DONE", alarm: true };
        const down = [0, 2].filter(i => readings[i].running).sort((a, b) => readings[a].seconds - readings[b].seconds);
        const i = down.length ? down[0] : readings[1].running ? 1 : 0;
        const names = ["POMODORO", "STOPWATCH", "COUNTDOWN"];
        return { value: reading(i), note: timersRunning ? names[i] + " · RUNNING" : "ALL STILL", alarm: false };
    }
    RoomSystem {
        id: timersSystem
        room: "timers"
        moons: [
            { number: root.pomodoroDone ? "DONE" : root.reading(0), name: root.timers?.pomodoroRunning ? (root.timers.pomodoroBreak ? "REST" : "FOCUS") : "POMODORO", symbol: root.timers?.pomodoroRunning ? "pause" : "play_arrow", current: root.pomodoroDone || (root.timers?.pomodoroRunning ?? false) },
            { number: root.reading(1), name: "STOPWATCH", symbol: root.timers?.stopwatchRunning ? "pause" : "play_arrow", current: root.timers?.stopwatchRunning ?? false },
            { number: root.countdownDone ? "DONE" : root.reading(2), name: "COUNTDOWN", symbol: root.timers?.countdownRunning ? "pause" : "play_arrow", current: root.countdownDone || (root.timers?.countdownRunning ?? false) }
        ]
        onActivated: index => {
            if (!root.timers?.available)
                return;
            root.act("timers");
            if (index === 0 && root.pomodoroDone) root.timers.ack("pomodoro");
            else if (index === 0) root.timers.toggle("pomodoro");
            else if (index === 1) root.timers.toggle("stopwatch");
            else if (root.countdownDone) root.timers.ack("countdown");
            else if ((root.timers.countdownDuration ?? 0) > 0) root.timers.toggle("countdown");
            else root.timers.startCountdown(300);
        }
        SunFace {
            title: root.title("timers")
            value: root.timersShown.value
            footer: root.timersShown.note
            alarm: root.timersShown.alarm
        }
    }

    // 07 Clips: the latest clips as moons, by kind only (never their contents); a click copies one again.
    readonly property var clipboard: host?.clipboard ?? null
    HostLease { domain: root.clipboard; feature: "history"; active: root.live }
    readonly property var clips: (clipboard?.entries ?? []).slice(0, 8)
    RoomSystem {
        id: clipsSystem
        room: "clipboard"
        moons: root.clips.map((e, i) => {
            const link = !e.isImage && /^\s*https?:\/\//.test(e.text ?? "");
            return { number: String(i + 1).padStart(2, "0"), name: e.isImage ? "IMAGE" : link ? "LINK" : "TEXT", symbol: e.isImage ? "image" : link ? "link" : "notes" };
        })
        onActivated: index => {
            const entry = root.clips[index];
            if (!entry)
                return;
            root.act("clipboard");
            root.clipboard.copy(entry.id);
        }
        SunFace {
            title: root.title("clipboard")
            value: (root.clipboard?.entries ?? []).length + " CLIPS"
            footer: "A CLICK COPIES ONE AGAIN"
        }
    }

    // 08 Inbox: quiet hours and mark-read as moons, then each app with something to say.
    readonly property var notifications: host?.notifications ?? null
    readonly property var apps: {
        const counts = {};
        for (const n of notifications?.items ?? [])
            counts[n.appName || "?"] = (counts[n.appName || "?"] ?? 0) + (n.read ? 0 : 1);
        return Object.keys(counts).filter(a => counts[a] > 0).sort((a, b) => counts[b] - counts[a]).slice(0, 6).map(a => ({ app: a, count: counts[a] }));
    }
    RoomSystem {
        id: inboxSystem
        room: "notifications"
        moons: [
            { number: "", name: root.notifications?.dnd ? "QUIET" : "ALERTS ON", symbol: root.notifications?.dnd ? "notifications_off" : "notifications_active", current: root.notifications?.dnd ?? false },
            { number: "", name: "MARK ALL READ", symbol: "done_all" },
            ...root.apps.map(a => ({ number: String(a.count), name: a.app.toUpperCase(), symbol: "apps" }))
        ]
        onActivated: index => {
            if (!root.notifications)
                return;
            root.act("notifications");
            if (index === 0) root.notifications.setDnd(!root.notifications.dnd);
            else if (index === 1) root.notifications.markAllRead();
            else root.orbit.choose(root.orbit.indexOf("notifications"));
        }
        SunFace {
            title: root.title("notifications")
            value: (root.notifications?.unread ?? 0) + " UNREAD"
            footer: (root.notifications?.items ?? []).length + " THIS SESSION" + (root.notifications?.dnd ? " · QUIET" : "")
        }
    }

    // 09 The Codex: its two sheets and today's element. A click opens the room on that sheet.
    readonly property var todayElement: Periodic.ofDay(new Date())
    readonly property int bindCount: host?.keybinds?.binds?.length ?? 0
    RoomSystem {
        id: codexSystem
        room: "codex"
        moons: [
            { number: "", name: "KEYS", symbol: "keyboard", current: ViewState.codexTab === "keys" },
            { number: "", name: "ELEMENTS", symbol: "science", current: ViewState.codexTab === "elements" },
            { number: root.todayElement.symbol, name: root.todayElement.name.toUpperCase(), symbol: "", current: false }
        ]
        onActivated: index => {
            root.act("codex", "ui.switch");
            ViewState.codexTab = index === 0 ? "keys" : "elements";
            root.orbit.choose(root.orbit.indexOf("codex"));
        }
        SunFace {
            title: root.title("codex")
            value: "118 ELEMENTS"
            footer: root.bindCount > 0 ? root.bindCount + " KEYBINDS" : "YOUR KEYS"
        }
    }
}
