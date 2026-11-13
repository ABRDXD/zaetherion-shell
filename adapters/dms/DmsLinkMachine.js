.pragma library

// The DMS link as a pure machine (docs/DMS_ADAPTER.md §2). step(state, event, now) → {state, effects}.
// It touches nothing: DmsLink.qml owns the sockets and the timer and runs the effects, one event at a time.
// Row names (L1…, R1…, S1…) are the table rows in that note; tests/test_dms_link_machine.py has one test per row.
//
// Events:  path(path)  requestUp  requestDown  line(msg)  call(token, method, params, timeoutMs)
//          feed(key, service, capability, wanted)  unfeed(key)  settle  eventsUp  eventsDown  eventLine(msg)  tick
// Effects: openRequest(path)  closeRequest  sendRequest(id, method, params)  reply(token, result, error)
//          openEvents(path)  closeEvents  sendEvents(msg)  state(service, data)  timer(at)  settleSoon  log(text)

var MIN_API = 38;       // below this DMS is too old and every DMS-backed domain is off
var CHECKED_API = 38;   // above this it works, marked untested (owner's decision, 11 Nov 2026)
var GREETING_MS = 3000;
var CALL_MS = 10000;
var BACKOFF_MS = [100, 200, 400, 800, 1600, 2000];

function minApi() { return MIN_API; }
function checkedApi() { return CHECKED_API; }
function backoff(attempt) { return BACKOFF_MS[Math.min(attempt, BACKOFF_MS.length - 1)]; }

function initial(clientId) {
    return {
        phase: "down", path: "", problem: "", attempt: 0, evAttempt: 0,
        apiVersion: 0, cliVersion: "", capabilities: [], untested: false,
        nextId: 1, pending: {}, feeds: {}, ev: "closed", subscribed: [], cache: {}, clientId: clientId || "zaetherion",
        retryAt: null, greetingAt: null, evRetryAt: null, timerAt: null
    };
}

// Services the event connection must carry: wanted feeds whose capability is present, and only while ready.
function needs(s) {
    if (s.phase !== "ready") return [];
    const out = [];
    for (const key in s.feeds) {
        const f = s.feeds[key];
        if (f.wanted && s.capabilities.indexOf(f.capability) >= 0 && out.indexOf(f.service) < 0) out.push(f.service);
    }
    return out.sort();
}

// S9a: DMS sends a change as "<service>.update" (brightness: {device}), beside the whole snapshot. It belongs to its
// service: it arrives, is cached and is dropped with it, under its own name.
function owner(service) {
    return service.endsWith(".update") ? service.slice(0, -".update".length) : service;
}

function sameList(a, b) {
    return a.length === b.length && a.every((v, i) => v === b[i]);
}

function step(state, event, now) {
    const c = { s: Object.assign({}, state), fx: [], now: now };
    handle(c, event);
    finish(c, event);
    return { state: c.s, effects: c.fx };
}

function handle(c, ev) {
    switch (ev.type) {
    case "path": return onPath(c, ev.path);
    case "requestUp": return onRequestUp(c);
    case "requestDown": return onRequestDown(c);
    case "line": return onLine(c, ev.msg);
    case "call": return onCall(c, ev);
    case "feed": return onFeed(c, ev);
    case "unfeed": return onUnfeed(c, ev.key);
    case "settle": return onSettle(c);
    case "eventsUp": return onEventsUp(c);
    case "eventsDown": return onEventsDown(c);
    case "eventLine": return onEventLine(c, ev.msg);
    case "tick": return onTick(c);
    }
}

// ---- helpers --------------------------------------------------------------------------------------------

function ids(pending) {
    return Object.keys(pending).map(Number).sort((a, b) => a - b);
}

function failPending(c, error) {
    for (const id of ids(c.s.pending)) c.fx.push({ type: "reply", token: c.s.pending[id].token, result: null, error: error });
    c.s.pending = {};
}

function clearCache(c) {
    for (const service of Object.keys(c.s.cache).sort()) c.fx.push({ type: "state", service: service, data: null });
    c.s.cache = {};
}

function closeEvents(c) {
    if (c.s.ev === "closed" || c.s.ev === "closing") return;
    c.s.ev = "closing";
    c.fx.push({ type: "closeEvents" });
}

// What a lost or replaced request connection takes with it.
function forget(c) {
    failPending(c, "offline");
    closeEvents(c);
    clearCache(c);
    c.s.subscribed = [];
    c.s.evRetryAt = null;
    c.s.evAttempt = 0;
    c.s.capabilities = [];
    c.s.apiVersion = 0;
    c.s.cliVersion = "";
    c.s.untested = false;
    c.s.greetingAt = null;
    c.s.retryAt = null;
}

function openRequest(c) {
    c.s.phase = "connecting";
    c.s.nextId = 1;
    c.fx.push({ type: "openRequest", path: c.s.path });
}

function retryLater(c, problem) {
    c.s.phase = "down";
    c.s.problem = problem;
    c.s.retryAt = c.now + backoff(c.s.attempt);
    c.s.attempt += 1;
}

// L6/L7, and S8 when a `server` event changes the version.
function gate(c) {
    const s = c.s;
    if (s.apiVersion < MIN_API) {
        if (s.phase === "ready") failPending(c, "offline");
        s.phase = "unsupported";
        s.problem = "too-old";
        s.untested = false;
        s.greetingAt = null;
        s.evRetryAt = null;
        clearCache(c);
    } else {
        s.phase = "ready";
        s.problem = "";
        s.untested = s.apiVersion > CHECKED_API;
        s.attempt = 0;
        s.greetingAt = null;
        c.fx.push({ type: "settleSoon" });
    }
}

// ---- rows -----------------------------------------------------------------------------------------------

// L1, L2
function onPath(c, path) {
    const s = c.s;
    if (path === "") {                                          // L2
        if (s.phase !== "down") c.fx.push({ type: "closeRequest" });
        forget(c);
        s.path = "";
        s.phase = "down";
        s.problem = "no-socket";
        s.attempt = 0;
        return;
    }
    if (path === s.path) return;
    if (s.phase !== "down") c.fx.push({ type: "closeRequest" });  // L1
    forget(c);
    s.path = path;
    s.problem = "";
    s.attempt = 0;
    openRequest(c);
}

// L3
function onRequestUp(c) {
    if (c.s.phase !== "connecting") return;
    c.s.phase = "greeting";
    c.s.greetingAt = c.now + GREETING_MS;
}

// L4, L10
function onRequestDown(c) {
    const s = c.s;
    if (s.phase === "connecting") {                              // L4
        retryLater(c, "offline");
    } else if (s.phase === "greeting" || s.phase === "ready" || s.phase === "unsupported") {   // L10
        c.fx.push({ type: "closeRequest" });
        forget(c);
        retryLater(c, "offline");
    }
}

// L6, L7, L8, R3, R4
function onLine(c, msg) {
    const s = c.s;
    if (s.phase === "greeting") {
        if (!msg || typeof msg !== "object" || typeof msg.apiVersion !== "number") {   // L8
            s.phase = "unsupported";
            s.problem = "protocol";
            s.greetingAt = null;
            return;
        }
        s.apiVersion = msg.apiVersion;
        s.capabilities = Array.isArray(msg.capabilities) ? msg.capabilities.slice() : [];
        gate(c);                                                // L6 or L7
        return;
    }
    if (s.phase !== "ready" || !msg || typeof msg !== "object") return;
    const entry = s.pending[msg.id];
    if (!entry) return;                                          // R4
    s.pending = Object.assign({}, s.pending);
    delete s.pending[msg.id];                                    // R3
    if (msg.error !== undefined && msg.error !== null) c.fx.push({ type: "reply", token: entry.token, result: null, error: String(msg.error) });
    else c.fx.push({ type: "reply", token: entry.token, result: msg.result === undefined ? null : msg.result, error: "" });
}

// R1, R2
function onCall(c, ev) {
    const s = c.s;
    if (s.phase !== "ready") {                                   // R2
        c.fx.push({ type: "reply", token: ev.token, result: null, error: "offline" });
        return;
    }
    const id = s.nextId;                                         // R1
    s.nextId += 1;
    s.pending = Object.assign({}, s.pending);
    s.pending[id] = { token: ev.token, deadline: c.now + (ev.timeoutMs > 0 ? ev.timeoutMs : CALL_MS) };
    c.fx.push({ type: "sendRequest", id: id, method: ev.method, params: ev.params === undefined ? {} : ev.params });
}

// S1
function onFeed(c, ev) {
    c.s.feeds = Object.assign({}, c.s.feeds);
    c.s.feeds[ev.key] = { service: ev.service, capability: ev.capability, wanted: ev.wanted === true };
    c.fx.push({ type: "settleSoon" });
}

function onUnfeed(c, key) {
    c.s.feeds = Object.assign({}, c.s.feeds);
    delete c.s.feeds[key];
    c.fx.push({ type: "settleSoon" });
}

// S2
function openEvents(c) {
    c.s.ev = "opening";
    c.fx.push({ type: "openEvents", path: c.s.path });
}

// S2, S4, S6, S11
function onSettle(c) {
    const s = c.s;
    if (s.ev === "closed") {                                     // S2
        if (needs(s).length > 0) openEvents(c);
    } else if (s.ev === "open") {
        const want = needs(s);
        if (sameList(want, s.subscribed)) return;                // S6
        for (const service of Object.keys(s.cache).sort()) {     // S4
            if (want.indexOf(owner(service)) < 0) {
                s.cache = Object.assign({}, s.cache);
                delete s.cache[service];
                c.fx.push({ type: "state", service: service, data: null });
            }
        }
        closeEvents(c);
    }
    // opening, closing: S11, only noted. The list is compared again when the connection reaches open or closed.
}

// S3
function onEventsUp(c) {
    const s = c.s;
    if (s.ev !== "opening") return;
    const want = needs(s);
    if (want.length === 0) {                                     // the leases left while we were dialling
        closeEvents(c);
        return;
    }
    s.subscribed = want;
    s.ev = "open";
    c.fx.push({ type: "sendEvents", msg: { id: 1, method: "subscribe", params: { clientId: s.clientId, services: want } } });
}

// S5, S7
function onEventsDown(c) {
    const s = c.s;
    if (s.ev === "closing") {                                    // S5
        s.ev = "closed";
        s.subscribed = [];
        if (needs(s).length > 0) openEvents(c);
    } else if (s.ev === "open" || s.ev === "opening") {          // S7
        s.ev = "closed";
        s.subscribed = [];
        if (needs(s).length > 0) {
            s.evRetryAt = c.now + backoff(s.evAttempt);
            s.evAttempt += 1;
        }
    }
}

// S8, S9, S10
function onEventLine(c, msg) {
    const s = c.s;
    if (s.ev !== "open") return;
    if (!msg || typeof msg !== "object") return;
    if (msg.error !== undefined && msg.error !== null) {         // S10
        c.fx.push({ type: "log", text: "dms: event error: " + String(msg.error) });
        return;
    }
    const r = msg.result;
    if (!r && typeof msg.apiVersion === "number") return;      // DMS greets every connection, this one too
    if (!r || typeof r.service !== "string") {
        c.fx.push({ type: "log", text: "dms: event without a service" });
        return;
    }
    s.evAttempt = 0;
    if (r.service === "server") {                                // S8
        const d = r.data || {};
        if (typeof d.apiVersion === "number") s.apiVersion = d.apiVersion;
        if (typeof d.cliVersion === "string") s.cliVersion = d.cliVersion;
        if (Array.isArray(d.capabilities)) s.capabilities = d.capabilities.slice();
        gate(c);
        c.fx.push({ type: "settleSoon" });
        return;
    }
    if (s.subscribed.indexOf(owner(r.service)) < 0) {            // S10, S9a
        c.fx.push({ type: "log", text: "dms: event for an unsubscribed service" });
        return;
    }
    if (JSON.stringify(s.cache[r.service]) === JSON.stringify(r.data)) return;   // S9
    s.cache = Object.assign({}, s.cache);
    s.cache[r.service] = r.data;
    c.fx.push({ type: "state", service: r.service, data: r.data });
}

// L5, L9, R5, S7's retry
function onTick(c) {
    const s = c.s;
    if (s.phase === "down" && s.path !== "" && s.retryAt !== null && s.retryAt <= c.now) {    // L5
        s.retryAt = null;
        openRequest(c);
    }
    if (s.phase === "greeting" && s.greetingAt !== null && s.greetingAt <= c.now) {           // L9
        c.fx.push({ type: "closeRequest" });
        s.greetingAt = null;
        retryLater(c, "offline");
    }
    for (const id of ids(s.pending)) {                                                        // R5
        if (s.pending[id].deadline <= c.now) {
            c.fx.push({ type: "reply", token: s.pending[id].token, result: null, error: "timeout" });
            s.pending = Object.assign({}, s.pending);
            delete s.pending[id];
        }
    }
    if (s.evRetryAt !== null && s.evRetryAt <= c.now) {
        s.evRetryAt = null;
        if (s.ev === "closed" && needs(s).length > 0) openEvents(c);
    }
}

// One timer, armed for the earliest deadline; nothing runs while nothing waits.
function finish(c, ev) {
    const s = c.s;
    let at = null;
    const consider = t => { if (t !== null && (at === null || t < at)) at = t; };
    if (s.phase === "down" && s.path !== "") consider(s.retryAt);
    if (s.phase === "greeting") consider(s.greetingAt);
    for (const id in s.pending) consider(s.pending[id].deadline);
    consider(s.evRetryAt);
    if (at !== s.timerAt || (ev.type === "tick" && at !== null)) c.fx.push({ type: "timer", at: at });
    s.timerAt = at;
}
