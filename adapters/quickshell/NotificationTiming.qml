pragma Singleton
import QtQuick

// How long a notification shows when its sender leaves that to us, by urgency, in ms. 0 = until it is dismissed.
// The owner's own choice (Z175), shorter than DMS's 5 s defaults (Z161).
QtObject {
    readonly property int lowMs: 3000
    readonly property int normalMs: 3000
    readonly property int criticalMs: 0
    readonly property var urgencies: ["low", "normal", "critical"]

    // expireTimeout: the sender's wish in ms; negative leaves it to us.
    function showMs(expireTimeout: int, urgency: string): int {
        if (expireTimeout >= 0) return expireTimeout;
        return urgency === "critical" ? criticalMs : urgency === "low" ? lowMs : normalMs;
    }
}
