import QtQuick
import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.cues
import qs.view.ui
import "DayFold.js" as Fold
import "TaskEntry.js" as TaskEntry

// One owner for Home's data, navigation and opening state across presentation changes.
Item {
    id: root
    required property HostAdapter host
    required property ShellContext shell
    property CoreClient core: null
    property Item surface: null
    property bool shown: false
    readonly property bool active: shown && shell.panelOpen
    readonly property bool overdrive: Motion.engaged && !Motion.reduced
    readonly property var player: host.media.active
    readonly property int uptimeMinutes: Math.floor(host.system.uptime / 60)
    readonly property real progress: (player?.length ?? 0) > 0 ? Math.max(0, Math.min(1, host.media.position / player.length)) : 0
    property var sky: null
    property int skyRequest: 0
    readonly property real sunrise: localHour(sky?.sun?.rise)
    readonly property real sunset: localHour(sky?.sun?.set)
    property string edition: ""
    property string printing: ""
    property var frontPage: []
    property var foldSnapshot: null
    property date foldOpened: new Date()
    property date calendarMonth: new Date(Clock.date.getFullYear(), Clock.date.getMonth(), 1)
    property date calendarWeek: new Date(Clock.date.getFullYear(), Clock.date.getMonth(), Clock.date.getDate() - (Clock.date.getDay() + 6) % 7)
    property date calendarSelection: Clock.date
    readonly property bool tasksAvailable: core?.tasks.available ?? false
    readonly property var openTasks: tasksAvailable ? core.tasks.all.filter(t => !t.done) : []
    readonly property var upcoming: openTasks.slice(0, 3)
    readonly property var updates: host.hostActions.updates
    signal navigate(string page)
    signal editProfile()

    HostLease { domain: root.host.media; feature: "position"; active: root.active && !!root.player }
    function localHour(iso) {
        if (!iso) return NaN;
        const d = new Date(iso);
        return d.getHours() + d.getMinutes() / 60;
    }
    function beginEdition() {
        foldSnapshot = null;
        const d = new Date(), h = d.getHours() + d.getMinutes() / 60;
        const noon = Number.isFinite(sunrise) && Number.isFinite(sunset) ? (sunrise + sunset) / 2 : NaN;
        edition = Fold.edition(h, sunrise, noon, sunset);
        const day = core?.journeyData?.days?.[Qt.formatDate(d, "yyyy-MM-dd")] ?? {};
        frontPage = Fold.front(["tasks", "timers", "notifications", "workspaces"], edition, day);
    }
    function askSky() {
        if (!active || !core?.connected) return;
        const request = ++skyRequest;
        core.request("sky.now", {tracks: true}, (ok, result) => {
            if (root && request === root.skyRequest && root.active && root.core?.connected && ok && result) root.sky = result;
        });
    }
    onActiveChanged: {
        if (active) { askSky(); if (overdrive) beginEdition(); }
        else skyRequest++;
    }
    onOverdriveChanged: if (active && overdrive) beginEdition()
    Connections { target: Clock; enabled: root.active; function onMinuteStrChanged() { root.askSky(); } }
    Connections {
        target: root.core
        function onConnectedChanged() { root.skyRequest++; root.askSky(); }
    }
    function shiftMonth(delta) { calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + delta, 1); }
    function taskDue(task) { return task.due ? TaskEntry.label(task.due, Clock.date) : "No date"; }
    function previous() { if (player?.canPrevious) host.media.previous(); }
    function togglePlaying() { if (player?.canToggle) host.media.togglePlaying(); }
    function next() { if (player?.canNext) host.media.next(); }
    function lock() { shell.close(); host.power.lock(); }
    function checkUpdates() { if (!updates.checking) host.hostActions.checkUpdates(); }
    function openHost(target) { shell.openHost(target); }
    function updateFart() { FartCommands.updateReport(); }
    function toggleFocus() { if (core?.timers.available) core.timers.toggle("pomodoro"); }
    function finishTask(id) { if (tasksAvailable && openTasks.some(t => t.id === id)) core.tasks.setDone(id, true); }
}
