.pragma library

// The toggle-only verbs of docs/DMS_ADAPTER.md §1 (`network.wifi.toggle` answers {enabled}). Pure.
//
// 1. Remember the wanted value; one flip in flight at a time; the newest request wins.
// 2. Flip only if wanted differs from the current value.
// 3. The answer's `enabled` is newer than the last snapshot: keep it as an override until the next snapshot.
// 4. If the answer isn't the wanted value (the snapshot was stale), flip once more, then give up.
//
// State: {wanted: null|bool, busy, extra, override: null|bool}. Each function returns {state, flip}.

function initial() {
    return { wanted: null, busy: false, extra: 0, override: null };
}

// The value the domain shows: the override until the next snapshot, else the snapshot.
function current(state, snapshotValue) {
    return state.override !== null ? state.override : snapshotValue;
}

function request(state, on, snapshotValue) {
    const s = Object.assign({}, state, { wanted: on, extra: 1 });
    if (s.busy) return { state: s, flip: false };              // the answer decides what happens next
    if (on === current(s, snapshotValue)) return { state: Object.assign(s, { wanted: null, extra: 0 }), flip: false };
    s.busy = true;
    return { state: s, flip: true };
}

function answered(state, enabled) {
    const s = Object.assign({}, state, { busy: false, override: enabled });
    if (s.wanted !== null && s.wanted !== enabled && s.extra > 0) {
        s.extra -= 1;
        s.busy = true;
        return { state: s, flip: true };
    }
    s.wanted = null;
    s.extra = 0;
    return { state: s, flip: false };
}

// An error, a timeout or "offline": the property stays as it was.
function failed(state) {
    return { state: Object.assign({}, state, { wanted: null, busy: false, extra: 0 }), flip: false };
}

function snapshot(state) {
    return Object.assign({}, state, { override: null });
}
