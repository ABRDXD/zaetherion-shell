import QtQuick

// The queue owns dwell time. Pre-emption and notification hover preserve the remaining time.
QtObject {
    id: root
    property var entries: []
    property bool hovered: false
    property var clock: () => Date.now()
    readonly property var current: entries[0] ?? null
    property double deadline: 0
    function isPaused(): bool {
        return hovered && (current?.kind === "notification" || current?.kind === "critical");
    }

    function snapshot(now: double): var {
        if (!current || deadline === 0) return entries.slice();
        return [Object.assign({}, current, { remaining: Math.max(0, deadline - now) })].concat(entries.slice(1));
    }

    function schedule(now: double): void {
        expiry.stop();
        deadline = 0;
        if (!current || isPaused() || current.remaining === null) return;
        deadline = now + current.remaining;
        expiry.interval = Math.max(1, current.remaining);
        expiry.start();
    }

    function offer(id: string, kind: string, priority: int, data: var, dwell: var): void {
        const now = clock();
        const next = snapshot(now);
        const replacement = { id, kind, priority, data, remaining: dwell };
        const old = next.findIndex(event => event.id === id);
        if (old >= 0) next.splice(old, 1);
        const insert = next.findIndex(event => event.priority > priority);
        next.splice(insert < 0 ? next.length : insert, 0, replacement);
        deadline = 0;
        entries = next;
        schedule(now);
    }

    function remove(id: string): void {
        if (!entries.some(event => event.id === id)) return;
        const now = clock();
        const next = snapshot(now).filter(event => event.id !== id);
        deadline = 0;
        entries = next;
        schedule(now);
    }

    onHoveredChanged: {
        if (deadline !== 0) {
            const next = snapshot(clock());
            deadline = 0;
            entries = next;
        }
        schedule(clock());
    }

    property Timer expiry: Timer {
        onTriggered: if (root.current) root.remove(root.current.id)
    }
}
