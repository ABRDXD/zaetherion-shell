// The desktop's 12-column grid (Z46, SURFACES §7): the shell's Grid rule (view/ui/Grid.qml: 12 columns, 16 px gutters,
// 12 px under 920 px) inside a 36 px desktop margin, the editor study's inset. A widget's pose (core/widgets.py) is a
// first column, a span, the centre's height as a share of the screen and an angle; these turn it into pixels and
// back. Pure, for tests/test_desktop_clock.py under Node.
.pragma library

var COLUMNS = 12;
var MARGIN = 36;
var FACE_RATIO = 209 / 780;  // the clock's sheet

function metrics(width) {
    var gutter = width < 920 ? 12 : 16;
    var inner = Math.max(0, width - 2 * MARGIN);
    return { gutter: gutter, column: Math.max(0, (inner - gutter * (COLUMNS - 1)) / COLUMNS) };
}

function pitch(width) {
    var m = metrics(width);
    return m.column + m.gutter;
}

// {x, y, width, height} of the widget's unrotated box on a screen of this size.
function rect(pose, width, height, ratio) {
    var m = metrics(width);
    var first = Math.max(0, Math.min(COLUMNS - 1, pose.column));
    var span = Math.max(1, Math.min(COLUMNS - first, pose.span));
    var w = span * m.column + (span - 1) * m.gutter;
    var h = w * (ratio || FACE_RATIO);
    var centre = Math.max(h / 2, Math.min(height - h / 2, pose.y * height));
    return { x: MARGIN + first * (m.column + m.gutter), y: centre - h / 2, width: w, height: h };
}

// The pose a drag leaves: whole columns (snapped), the height as a share, clamped to the grid and the screen.
function moved(start, dx, dy, width, height, minSpan) {
    var step = pitch(width);
    var column = Math.max(0, Math.min(COLUMNS - start.span, start.column + Math.round(dx / step)));
    var box = rect(start, width, height);
    var half = box.height / 2 / height;
    var y = Math.max(half, Math.min(1 - half, start.y + dy / height));
    return { column: column, span: start.span, y: Math.round(y * 10000) / 10000, angle: start.angle };
}

// A resize along the widget's own axis (advance in pixels), snapped to whole columns.
function resized(start, advance, width, minSpan) {
    var span = Math.max(minSpan || 3, Math.min(COLUMNS - start.column, start.span + Math.round(advance / pitch(width))));
    return { column: start.column, span: span, y: start.y, angle: start.angle };
}

// A turn by `delta` degrees from the start, wrapped to -180..180 and whole degrees.
function turned(start, delta) {
    var a = Math.round(start.angle + delta);
    return { column: start.column, span: start.span, y: start.y, angle: ((a + 540) % 360) - 180 };
}
