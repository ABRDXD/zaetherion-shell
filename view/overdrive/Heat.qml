import qs.view.cues
import QtQuick
import Quickshell.Io

// The heat (docs/OVERDRIVE.md §8, Claude A's idea): Overdrive's real cost, measured. Once a second while the engine
// drives and the panel is seen, it reads this process's own CPU time from /proc/self/stat (utime + stime) and turns
// it into a share of one core; `heat` places that share between the cool and hot ends of what Overdrive really costs
// (docs/OVERDRIVE.md §9: about 30 % of a core on Home, about 135 % on the orbit), so the header's haze shimmers as
// hard as the view is really working and differs from place to place. Nothing is read in Silent.
QtObject {
    id: root
    readonly property bool running: Motion.driving && Motion.seen
    property real cpu: 0
    // The haze at rest in a light room and flat out on the orbit, in percent of one core. The square root keeps the
    // cheap end visible: the eye reads a faint shimmer against none much more strongly than a strong one against a
    // slightly stronger one.
    readonly property real cool: 20
    readonly property real hot: 140
    function level(percent) {
        return Math.sqrt(Math.max(0, Math.min(1, (percent - cool) / (hot - cool))));
    }
    // Eased per sample, so the once-a-second reading doesn't step the haze.
    property real heat: 0
    property real lastTicks: -1
    property double lastAt: 0
    property FileView stat: FileView {
        path: root.running ? "/proc/self/stat" : ""
        printErrors: false
        blockLoading: true
    }
    property Timer tick: Timer {
        interval: 1000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: root.sample()
        onRunningChanged: if (!running) { root.lastTicks = -1; root.cpu = 0; root.heat = 0; }
    }
    function sample() {
        stat.reload();
        const text = stat.text();
        // The command name may hold spaces; the fields after its closing parenthesis are fixed.
        const fields = text.slice(text.lastIndexOf(")") + 2).split(" ");
        const ticks = Number(fields[11]) + Number(fields[12]);
        const now = Date.now();
        if (Number.isFinite(ticks) && root.lastTicks >= 0 && now > root.lastAt) {
            root.cpu = 100 * (ticks - root.lastTicks) / 100 / ((now - root.lastAt) / 1000);
            root.heat += 0.4 * (root.level(root.cpu) - root.heat);
        }
        if (Number.isFinite(ticks)) {
            root.lastTicks = ticks;
            root.lastAt = now;
        }
    }
}
