import QtQuick
import Quickshell

// Cold-start phase markers for tools/measure/cold_breakdown.py, wall-clock ms, printed only with
// FART_COLD_PROBE=1. After `handled` it splits the last phase (handled → interactive) into the panel
// window's first swapped frame, the window turning active and the command line taking focus
// (docs/COLDSTART.md). Otherwise it does nothing: no connection is enabled.
QtObject {
    id: root
    readonly property bool enabled: Quickshell.env("FART_COLD_PROBE") === "1"
    property var window: null  // the panel's QQuickWindow
    property bool inputFocused: false
    property bool watching: false  // from `handled` until the open is interactive
    property bool swapped: false

    function mark(phase) {
        if (enabled)
            console.log("FART_COLD", phase, Date.now());
    }
    function handled() {
        mark("handled");
        if (!enabled)
            return;
        watching = true;
        swapped = false;
        if (window?.active)
            mark("active");
        if (inputFocused)
            mark("focus");
    }
    function interactive() {
        // Called from PanelBody's own frameSwapped handler, which runs before this object's: when the
        // first swapped frame is already the interactive one, it is marked here.
        if (watching && !swapped) {
            swapped = true;
            mark("swap");
        }
        watching = false;
    }
    onInputFocusedChanged: if (watching && inputFocused) mark("focus")

    readonly property Connections frames: Connections {
        target: root.window
        enabled: root.watching
        function onFrameSwapped() {
            if (!root.swapped) {
                root.swapped = true;
                root.mark("swap");
            }
        }
        function onActiveChanged() {
            if (root.window.active)
                root.mark("active");
        }
    }
}
