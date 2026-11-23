import QtQuick

// The queue owns dwell time. Pre-emption and notification hover preserve the remaining time.
QtObject {
    id: root
    property var entries: []
    property bool hovered: false
    property var clock: () => Date.now()
    // Z161: while a panel is open only entries at or above this priority show; the rest wait with their dwell intact.
    property real ceiling: Infinity
    readonly property var current: head()
    // Read directly by schedule(): a change handler may run before `current` re-evaluates.
    function head(): var {
        return entries.length > 0 && entries[0].priority <= ceiling ? entries[0] : null;
    }
    property double deadline: 0
    function isPaused(): bool {
        const shown = head();
        return hovered && (shown?.kind === "notification" || shown?.kind === "critical");
    }

    function snapshot(now: double): var {
        // The deadline belongs to the head, which may have just dropped below the ceiling.
        if (entries.length === 0 || deadline === 0) return entries.slice();
        return [Object.assign({}, entries[0], { remaining: Math.max(0, deadline - now) })].concat(entries.slice(1));
    }

    function schedule(now: double): void {
        expiry.stop();
        deadline = 0;
        const shown = head();
        if (!shown || isPaused() || shown.remaining === null) return;
        deadline = now + shown.remaining;
        expiry.interval = Math.max(1, shown.remaining);
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

    // Bank the running dwell, then reschedule under the new hover or ceiling.
    function rebase(): void {
        if (deadline !== 0) {
            const next = snapshot(clock());
            deadline = 0;
            entries = next;
        }
        schedule(clock());
    }
    onHoveredChanged: rebase()
    onCeilingChanged: rebase()

    property Timer expiry: Timer {
        onTriggered: { const shown = root.head(); if (shown) root.remove(shown.id); }
    }
}
