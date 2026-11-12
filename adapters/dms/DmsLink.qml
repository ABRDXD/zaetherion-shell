import QtQuick
import Quickshell
import Quickshell.Io
import "DmsLinkMachine.js" as Machine

// The only file that touches DMS's socket (docs/DMS_ADAPTER.md §0-§3). DmsLinkMachine.js decides; this file
// owns the two connections and the one timer, and runs the effects the machine returns.
//
//   call(method, params, done, timeoutMs)   done(result, error) runs exactly once; error is "" on success,
//                                            else DMS's own error, "timeout" or "offline". It never throws.
//   snapshots                                service → last snapshot of every subscribed service
//
// Commands are never queued: a call made while not ready fails at once, and nothing is replayed after a
// reconnect. Events that arrive while the machine steps are queued and drained after it, so a callback may call().
Scope {
    id: root

    // Given, never guessed (§7). The shell entry binds it; DMS_SOCKET is the default (Z10).
    property string socketPath: Quickshell.env("DMS_SOCKET") ?? ""
    property string clientId: "zaetherion"

    // Read-only for everyone else: set from the machine's state by publish().
    property string phase: "down"                       // down · connecting · greeting · ready · unsupported
    property string problem: ""                         // "" · no-socket · offline · too-old · protocol
    property int apiVersion: 0
    property string cliVersion: ""
    property var capabilities: []
    property bool untested: false
    property var snapshots: ({})
    readonly property bool ready: phase === "ready"
    // For tests and diagnostics: what the machine believes.
    property string eventsState: "closed"
    property var subscribed: []

    property var machine: Machine.initial("zaetherion")
    property int feedCount: 0
    property bool stepping: false
    property var queue: []
    property int nextToken: 1
    property var callbacks: ({})
    property bool settleQueued: false
    property var requestSocket: null
    property var eventSocket: null

    onSocketPathChanged: if (started) post({ type: "path", path: socketPath })
    property bool started: false
    Component.onCompleted: {
        machine = Machine.initial(clientId);
        started = true;
        post({ type: "path", path: socketPath });
    }
    Component.onDestruction: {
        detach(requestSocket); detach(eventSocket);
        requestSocket = null; eventSocket = null;
    }

    function call(method, params, done, timeoutMs) {
        const token = nextToken++;
        callbacks[token] = done;
        post({ type: "call", token: token, method: method, params: params, timeoutMs: timeoutMs ?? 0 });
    }
    function newFeedKey() { return "feed" + (++feedCount); }
    function addFeed(key, service, capability, wanted) {
        post({ type: "feed", key: key, service: service, capability: capability, wanted: wanted });
    }
    function removeFeed(key) { post({ type: "unfeed", key: key }); }

    function post(event) {
        queue.push(event);
        if (stepping) return;
        stepping = true;
        try {
            while (queue.length > 0) {
                const result = Machine.step(machine, queue.shift(), Date.now());
                machine = result.state;
                publish();
                for (const effect of result.effects) run(effect);
            }
        } finally {
            stepping = false;
        }
    }

    function setIfChanged(name, value) {
        if (JSON.stringify(root[name]) !== JSON.stringify(value)) root[name] = value;
    }
    function publish() {
        const s = machine;
        setIfChanged("phase", s.phase);
        setIfChanged("problem", s.problem);
        setIfChanged("apiVersion", s.apiVersion);
        setIfChanged("cliVersion", s.cliVersion);
        setIfChanged("capabilities", s.capabilities);
        setIfChanged("untested", s.untested);
        setIfChanged("eventsState", s.ev);
        setIfChanged("subscribed", s.subscribed);
    }

    function run(effect) {
        switch (effect.type) {
        case "openRequest": return openRequest(effect.path);
        case "closeRequest": return closeRequest();
        case "sendRequest": return send(requestSocket, { id: effect.id, method: effect.method, params: effect.params });
        case "reply": return reply(effect);
        case "openEvents": return openEvents(effect.path);
        case "closeEvents": return closeEvents();
        case "sendEvents": return send(eventSocket, effect.msg);
        case "state": return setSnapshot(effect.service, effect.data);
        case "timer": return arm(effect.at);
        case "settleSoon": return settleSoon();
        case "log": return console.warn(effect.text);
        }
    }

    function setSnapshot(service, data) {
        const next = Object.assign({}, snapshots);
        if (data === null) delete next[service];
        else next[service] = data;
        snapshots = next;
    }

    function reply(effect) {
        const done = callbacks[effect.token];
        delete callbacks[effect.token];
        if (!done) return;
        try {
            done(effect.result, effect.error);
        } catch (e) {
            console.warn("dms: a reply handler threw:", e);
        }
    }

    // One collapsed settle per event-loop turn (S1).
    function settleSoon() {
        if (settleQueued) return;
        settleQueued = true;
        Qt.callLater(() => { settleQueued = false; post({ type: "settle" }); });
    }

    function arm(at) {
        if (at === null) { timer.stop(); return; }
        timer.interval = Math.max(1, at - Date.now());
        timer.restart();
    }
    Timer {
        id: timer
        repeat: false
        onTriggered: root.post({ type: "tick" })
    }

    // ---- sockets: one object per connection, so a late signal from an old one is never mistaken for the new one ----
    Component {
        id: socketFactory
        Socket {
            id: socket
            signal line(string text)
            parser: SplitParser { onRead: data => socket.line(data) }
        }
    }

    function parse(text) {
        try { return JSON.parse(text); } catch (_) { return null; }
    }
    function send(socket, message) {
        if (!socket || !socket.connected) return;
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
    }

    // A closed socket is released a turn later: this may run inside the socket's own parser callback.
    function detach(socket) {
        if (!socket) return;
        Qt.callLater(() => { socket.connected = false; socket.destroy(); });
    }

    function openRequest(path) {
        detach(requestSocket);
        const socket = socketFactory.createObject(root, { path: path });
        requestSocket = socket;
        socket.connectionStateChanged.connect(() => {
            if (socket === requestSocket) post({ type: socket.connected ? "requestUp" : "requestDown" });
        });
        socket.error.connect(() => { if (socket === requestSocket && !socket.connected) post({ type: "requestDown" }); });
        socket.line.connect(text => { if (socket === requestSocket) post({ type: "line", msg: parse(text) }); });
        socket.connected = true;
    }
    function closeRequest() {
        detach(requestSocket);
        requestSocket = null;
    }

    function openEvents(path) {
        detach(eventSocket);
        const socket = socketFactory.createObject(root, { path: path });
        eventSocket = socket;
        socket.connectionStateChanged.connect(() => {
            if (socket === eventSocket) post({ type: socket.connected ? "eventsUp" : "eventsDown" });
        });
        socket.error.connect(() => { if (socket === eventSocket && !socket.connected) post({ type: "eventsDown" }); });
        socket.line.connect(text => { if (socket === eventSocket) post({ type: "eventLine", msg: parse(text) }); });
        socket.connected = true;
    }
    // The machine waits for eventsDown, so it is always posted, from the socket we let go of.
    function closeEvents() {
        detach(eventSocket);
        eventSocket = null;
        Qt.callLater(() => post({ type: "eventsDown" }));
    }
}
