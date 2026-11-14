.pragma library

// Verbs that take the wanted value (`bluetooth.setPowered {powered}`), unlike the toggles of DmsToggle.js. Pure.
// One call in flight; a repeat of it sends nothing; a different value asked meanwhile is sent after the answer, and
// only if the system does not already have it. State: {sending: null|bool, queued: null|bool}. Returns {state, send}.

function initial() {
    return { sending: null, queued: null };
}

function request(state, on, current) {
    if (state.sending !== null)
        return { state: { sending: state.sending, queued: on === state.sending ? null : on }, send: null };
    if (on === current) return { state: state, send: null };
    return { state: { sending: on, queued: null }, send: on };
}

// After the answer (or an error): send the queued value if the system still differs from it.
function answered(state, current) {
    const next = state.queued;
    if (next !== null && next !== current) return { state: { sending: next, queued: null }, send: next };
    return { state: initial(), send: null };
}
