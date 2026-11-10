import QtQuick
import Quickshell
import Quickshell.Io

// The view's half of the core protocol (docs/CORE.md §2 and §9): JSON lines on $FART_CORE_SOCKET.
// Topic snapshots are replaced whole. While disconnected they keep their last value and connected is false.
Scope {
    id: root
    property string path: Quickshell.env("FART_CORE_SOCKET") || ""
    property bool connected: false
    property var timersData: null
    property var tasksData: null
    property var notificationsData: null
    property var overdriveData: null
    property var sessionData: null
    // Which cues exist and are on (core/sfx.py); `cue` carries each one as it happens.
    property var sfxData: null
    // The ignite hold (core/ignite.py): {holding, since, fired, outcome}. The meter binds to it; no timing here.
    property var igniteData: null
    // The last MPRIS track change (core/track.py): {player, artist, title, at}, all null before one.
    property var trackData: null
    // The rooms visited and in what order (core/journey.py): the orbit's laws read it.
    property var journeyData: null
    property var discoveryData: null
    readonly property CoreTimers timers: CoreTimers { core: root }
    readonly property CoreTasks tasks: CoreTasks { core: root }
    // The HostAdapter that core host calls act through (`vol` and friends). Null in harnesses without one.
    property var host: null
    readonly property CoreHostCalls hostCalls: CoreHostCalls { core: root; host: root.host }
    readonly property var topics: ["timers", "tasks", "notifications", "overdrive", "session", "sfx", "ignite", "track", "journey", "discovery"]
    property int nextId: 1
    property var pending: ({})
    property int backoff: 250
    // extra: {screen, focus, query}, each present only when the command carries it.
    signal command(string action, string page, var from, var extra)
    signal hostCall(var data)
    // {cue, seq, at, audible, reason, gain}. The core has already played it; this is for display only.
    signal cue(var data)

    function send(message) {
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }
    // callback(ok, resultOrError)
    function request(op, args, callback) {
        if (!socket.connected) {
            if (callback) callback(false, { code: "unavailable", message: "the core is not connected" });
            return;
        }
        const id = nextId++;
        if (callback) pending[id] = callback;
        send({ id: id, op: op, args: args || {} });
    }
    // A UI moment for the core's sound gate: ui.click, ui.key, ui.switch, ui.error or orbit.out/land/hover. The core plays it.
    function playCue(name) {
        notify("sfx.play", { cue: name });
    }
    // Fire and forget: no reply.
    function notify(op, args) {
        if (socket.connected) send({ op: op, args: args || {} });
    }
    function receive(line) {
        let message;
        try { message = JSON.parse(line); } catch (_) { return; }
        if (message.event === "view.command") {
            const data = message.data || {};
            const extra = {};
            for (const key of ["screen", "focus", "query", "fly"])
                if (data[key] !== undefined) extra[key] = data[key];
            root.command(data.action || "", data.page || "", data.from || null, extra);
        } else if (message.event === "view.host") {
            root.hostCall(message.data || {});
        } else if (message.event === "sfx.cue") {
            root.cue(message.data || {});
        } else if (message.event && topics.includes(message.event)) {
            root[message.event + "Data"] = message.data;
        } else if (message.id !== undefined && pending[message.id]) {
            const callback = pending[message.id];
            delete pending[message.id];
            callback(message.ok === true, message.ok ? message.result : message.error);
        }
    }
    function failPending() {
        const callbacks = pending;
        pending = {};
        for (const callback of Object.values(callbacks))
            callback(false, { code: "unavailable", message: "the core disconnected" });
    }
    function handshake() {
        request("hello", { client: "view", protocol: 1 }, (ok, hello) => {
            if (!ok) { socket.connected = false; return; }
            request("subscribe", { topics: root.topics }, (ok, result) => {
                if (!ok) { socket.connected = false; return; }
                for (const topic of root.topics) root[topic + "Data"] = result.snapshots[topic];
                root.backoff = 250;
                root.connected = true;
            });
        });
    }
    function retry() {
        if (!root.path || socket.connected) return;
        reconnect.interval = root.backoff;
        root.backoff = Math.min(5000, root.backoff * 2);
        reconnect.restart();
    }

    Socket {
        id: socket
        path: root.path
        connected: root.path !== ""
        onConnectionStateChanged: {
            if (connected) {
                root.handshake();
            } else {
                root.connected = false;
                root.failPending();
                root.retry();
            }
        }
        onError: root.retry()
        parser: SplitParser { onRead: line => root.receive(line) }
    }
    // Runs only while disconnected.
    Timer {
        id: reconnect
        onTriggered: socket.connected = true
    }
}
