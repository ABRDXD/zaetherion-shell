import QtQuick
import Quickshell

// The view's half of core host calls (core/hostcalls.py, docs/M5-COMMAND.md §3). For each `view.host`
// event: acquire the lease under its own owner, wait until the domain is available and `ready` is truthy,
// call the method, wait `hold` ms so the change lands while the object is bound, read `read`, answer with
// host.done, and release `linger` ms later, so a follow-up call (vol +5 reads, then sets) keeps the object
// bound. A 20 ms step runs only while a call is pending or lingering; idle, nothing runs.
Scope {
    id: root
    required property var core
    // The HostAdapter. Without one (harnesses) every call answers unavailable.
    property var host: null
    property var calls: []
    readonly property int readyTimeout: 2000
    // The core allows only listed calls (core/hostcalls.py); this keeps lease, log and QObject methods out regardless.
    readonly property var reserved: ["acquire", "release", "holds", "record", "destroy", "deleteLater", "toString"]

    function resolve(object, path) {
        let value = object;
        for (const key of String(path).split(".")) {
            if (value === null || value === undefined) return undefined;
            value = value[key];
        }
        return value;
    }
    // Contract values are plain JS; copying keeps host objects from crossing the socket.
    function plain(value) {
        return value === undefined ? null : JSON.parse(JSON.stringify(value));
    }
    function reply(data, ok, result, error) {
        core.notify("host.done", ok ? { token: data.token, ok: true, result: result }
                                    : { token: data.token, ok: false, error: error });
    }
    function begin(data) {
        // A domain the adapter defers (docs/ADAPTER_CONTRACT.md §1) loads now; follow() moves the call if it swaps in later.
        if (root.host && typeof root.host.loadDeferred === "function") root.host.loadDeferred();
        const domain = root.host ? root.host[data.domain] : null;
        if (!domain || typeof domain.acquire !== "function") {
            reply(data, false, null, { code: "unavailable", message: "no host adapter" });
            return;
        }
        if (data.method && (reserved.includes(data.method) || typeof domain[data.method] !== "function")) {
            reply(data, false, null, { code: "bad-args", message: data.domain + " has no method " + data.method });
            return;
        }
        const call = { data: data, domain: domain, owner: "core:" + data.token, phase: "wait", until: Date.now() + readyTimeout };
        if (data.lease) domain.acquire(data.lease, call.owner);
        calls = calls.concat([call]);
        step();
    }
    function release(call) {
        if (call.data.lease) call.domain.release(call.data.lease, call.owner);
        calls = calls.filter(c => c !== call);
    }
    function finish(call, ok, result, error) {
        reply(call.data, ok, result, error);
        if (!ok || !(call.data.linger > 0)) {
            release(call);
            return;
        }
        call.phase = "linger";
        call.until = Date.now() + call.data.linger;
    }
    function invoke(call) {
        const d = call.data;
        const args = (d.args || []).map(a => a !== null && typeof a === "object" && "$" in a ? resolve(call.domain, a["$"]) : a);
        try {
            call.domain[d.method](...args);
            return true;
        } catch (error) {
            finish(call, false, null, { code: "unavailable", message: d.domain + "." + d.method + " failed" });
            return false;
        }
    }
    // While waiting, a deferred domain may replace its placeholder: move the lease to the new object.
    function follow(call) {
        const current = root.host ? root.host[call.data.domain] : null;
        if (!current || current === call.domain || typeof current.acquire !== "function") return;
        if (call.data.lease) {
            call.domain.release(call.data.lease, call.owner);
            current.acquire(call.data.lease, call.owner);
        }
        call.domain = current;
    }
    function step() {
        const now = Date.now();
        for (const call of calls.slice()) {
            const d = call.data;
            if (call.phase === "wait") {
                follow(call);
                if (!call.domain.available || (d.ready && !resolve(call.domain, d.ready))) {
                    if (now >= call.until) finish(call, false, null, { code: "unavailable", message: d.domain + " is not ready" });
                    continue;
                }
                if (d.method && !invoke(call)) continue;
                call.phase = "hold";
                call.until = now + (d.hold || 0);
            }
            if (call.phase === "hold" && now >= call.until)
                finish(call, true, { read: d.read ? plain(resolve(call.domain, d.read)) : null });
            else if (call.phase === "linger" && now >= call.until)
                release(call);
        }
    }

    Connections {
        target: root.core
        function onHostCall(data) { root.begin(data); }
        // A lost connection cancels everything: the core has already failed these calls.
        function onConnectedChanged() {
            if (root.core.connected) return;
            for (const call of root.calls)
                if (call.data.lease) call.domain.release(call.data.lease, call.owner);
            root.calls = [];
        }
    }
    Timer {
        interval: 20
        repeat: true
        running: root.calls.length > 0
        onTriggered: root.step()
    }
}
