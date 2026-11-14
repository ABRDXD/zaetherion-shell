.pragma library

// One user action on the system (join a network, pair a device, …) from the click to its outcome (docs/NET_BT.md §3,
// Z192). Pure: every function takes the state and returns the next one; null is "nothing happening".
//
// The outcome comes only from what DMS reports: a reply to the call, and the snapshots the domain turns into an
// observation {ok, progress, reason, wrongSecret} for the attempt's target. Nothing here touches a radio.
//
// Phases: working (asked, waiting) · lost (DMS went away while working; the next snapshot decides) ·
// done · wrong-secret · timeout · failed · cancelled. `reason` is DMS's own word ("bad-credentials", "offline", …).

const SETTLED = ["done", "wrong-secret", "timeout", "failed", "cancelled"];
// How long a settled attempt stays readable before it goes back to null.
const LINGER = { done: 5000, other: 60000 };
// How long each kind of action may take before it is a timeout (Z192). A prompt has its own (DmsPrompt.js).
const TIMEOUTS = { wifi: 40000, vpn: 30000, "bt-connect": 20000, "bt-pair": 60000, "bt-other": 10000 };

function timeout(kind) {
    return TIMEOUTS[kind] ?? TIMEOUTS["bt-other"];
}

function busy(state) {
    return !!state && (state.phase === "working" || state.phase === "lost");
}

function settle(state, phase, reason, now) {
    return Object.assign({}, state, { phase: phase, reason: reason || "", settledAt: now });
}

// A new action. A repeat of the running one is dropped (a double click sends nothing extra); another action while
// one runs is refused. wrong-secret counts as running: its prompt is still open.
function begin(state, target, action, now, timeoutMs) {
    if (busy(state) || (state && state.phase === "wrong-secret")) {
        const same = state.target === target && state.action === action;
        return { state: state, send: false, refused: same ? "" : "busy" };
    }
    return {
        state: { target: target, action: action, phase: "working", reason: "", startedAt: now, deadline: now + timeoutMs,
                 timeoutMs: timeoutMs, replied: false, progressed: false, settledAt: 0 },
        send: true, refused: ""
    };
}

// The reply to the call. "" means DMS took it; the outcome still waits for a snapshot.
function replied(state, error, now) {
    if (!state || state.phase !== "working") return state;
    if (error === "") return Object.assign({}, state, { replied: true });
    if (error === "offline") return Object.assign({}, state, { phase: "lost", reason: "offline" });
    if (error === "timeout") return settle(state, "timeout", "no-answer", now);
    return settle(state, "failed", error, now);
}

function failurePhase(reason) {
    if (reason === "bad-credentials") return "wrong-secret";
    if (reason === "user-canceled") return "cancelled";
    return "failed";
}

// A snapshot, seen for this attempt's target.
function observe(state, obs, now) {
    if (!state || !obs) return state;
    if (obs.ok) return state.phase === "done" ? state : settle(state, "done", "", now);
    if (state.phase === "working") {
        if (obs.wrongSecret) return settle(state, "wrong-secret", "bad-credentials", now);
        if (obs.progress) return state.progressed ? state : Object.assign({}, state, { progressed: true });
        // It was under way and stopped without succeeding: that is the outcome. A stale error from before the
        // attempt is never read, because nothing counts until progress has been seen.
        if (state.progressed) return settle(state, failurePhase(obs.reason), obs.reason, now);
        return state;
    }
    if (state.phase === "lost") {
        if (obs.progress) return Object.assign({}, state, { phase: "working", progressed: true, reason: "" });
        return settle(state, "failed", "dms-restarted", now);
    }
    return state;
}

// A secret was typed after wrong-secret: the same attempt runs again with a fresh deadline.
function retry(state, now) {
    if (!state || state.phase !== "wrong-secret") return state;
    return Object.assign({}, state, { phase: "working", reason: "", progressed: false, replied: false, settledAt: 0,
                                      deadline: now + state.timeoutMs });
}

function tick(state, now) {
    if (!state) return state;
    if (busy(state) && now >= state.deadline)
        return settle(state, state.phase === "lost" ? "failed" : "timeout", state.phase === "lost" ? "offline" : "", now);
    if (SETTLED.indexOf(state.phase) >= 0 && state.phase !== "wrong-secret"
            && now >= state.settledAt + (state.phase === "done" ? LINGER.done : LINGER.other))
        return null;
    return state;
}

function linkDown(state) {
    return state && state.phase === "working" ? Object.assign({}, state, { phase: "lost", reason: "offline" }) : state;
}

// The clock starts again: after a resume (time asleep does not count) and when a prompt waits for the person.
function rearm(state, now) {
    return busy(state) ? Object.assign({}, state, { deadline: now + state.timeoutMs }) : state;
}

function cancel(state, now, reason) {
    return state && (busy(state) || state.phase === "wrong-secret") ? settle(state, "cancelled", reason || "user-canceled", now) : state;
}

// The next time tick() can change something, or -1.
function nextDeadline(state) {
    if (!state) return -1;
    if (busy(state)) return state.deadline;
    if (state.phase === "wrong-secret") return -1;
    return state.settledAt + (state.phase === "done" ? LINGER.done : LINGER.other);
}

// The contract's view of it: no timers, no bookkeeping.
function view(state) {
    return state ? { target: state.target, action: state.action, phase: state.phase, reason: state.reason } : null;
}
