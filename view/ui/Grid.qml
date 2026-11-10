import QtQuick

// The 12-column grid of one room (MONTAGE.md §2). Rooms place planes by span, never by pixel.
QtObject {
    id: root
    property real width: 0
    readonly property bool compact: width < 920
    readonly property int columns: 12
    readonly property real gutter: compact ? 12 : 16
    readonly property real column: Math.max(0, (width - gutter * (columns - 1)) / columns)
    // {x, width} of `count` columns starting at column `first` (0-based), gutters included.
    function span(first, count) {
        const start = Math.max(0, Math.min(columns - 1, first));
        const n = Math.max(1, Math.min(columns - start, count));
        return { x: start * (column + gutter), width: n * column + (n - 1) * gutter };
    }
    // Snap a length to the 4 px baseline.
    function snap(value) {
        return Math.round(value / Design.baseline) * Design.baseline;
    }
}
