pragma Singleton
import QtQuick
import Quickshell

// Local wall clock at minute precision; not host-specific.
Singleton {
    readonly property alias date: systemClock.date
    readonly property string hourStr: Qt.formatTime(date, "HH")
    readonly property string minuteStr: Qt.formatTime(date, "mm")
    SystemClock { id: systemClock; precision: SystemClock.Minutes }

    // 83 -> "1:23"; whole seconds, never negative.
    function formatSeconds(totalSeconds) {
        const s = Math.max(0, Math.round(totalSeconds));
        return Math.floor(s / 60) + ":" + (s % 60).toString().padStart(2, "0");
    }
}
