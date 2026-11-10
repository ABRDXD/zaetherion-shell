pragma Singleton
import QtQuick
import Quickshell

// The flash limiter (D17, docs/CUES.md §7): at most `limit` flashes in any `period` ms,
// across every FART surface. Denied flashes are dropped, never deferred.
Singleton {
    id: root
    readonly property int limit: 3
    readonly property int period: 1000
    // Milliseconds; the fixture harness replaces it.
    property var now: () => Date.now()
    property var grants: []
    function request(name) {
        if (Motion.reduced) return false;
        const t = now();
        // A grant from a clock that jumped backwards no longer counts.
        const recent = grants.filter(g => t - g >= 0 && t - g < root.period);
        if (recent.length >= root.limit) {
            grants = recent;
            return false;
        }
        grants = [...recent, t];
        return true;
    }
}
