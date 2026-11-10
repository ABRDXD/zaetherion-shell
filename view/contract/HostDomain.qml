import Quickshell

// Base of every contract domain: availability, leases for costly work, and the fixture call log.
Scope {
    id: root
    property bool available: false
    // feature -> list of owner keys. Replaced, never mutated, so holds() bindings re-evaluate.
    property var leases: ({})
    property bool recordCalls: false
    property var calls: []

    function record(method: string, args: var) {
        if (recordCalls) calls = calls.concat([{ method: method, args: args }]);
    }
    function holds(feature: string): bool {
        return (leases[feature] ?? []).length > 0;
    }
    function acquire(feature: string, owner: string) {
        const owners = leases[feature] ?? [];
        if (owners.includes(owner)) return;
        leases = Object.assign({}, leases, { [feature]: owners.concat([owner]) });
    }
    function release(feature: string, owner: string) {
        const owners = leases[feature] ?? [];
        if (!owners.includes(owner)) return;
        leases = Object.assign({}, leases, { [feature]: owners.filter(o => o !== owner) });
    }
}
