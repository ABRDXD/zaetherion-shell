import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.ui

ShellRoot {
    id: root
    property int step: 0
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }

    function timers(running: bool, done: bool): var {
        return {
            at: Date.now(),
            countdown: { running, done, duration: 180, elapsed: 0 },
            stopwatch: { running: false, elapsed: 0, laps: [] },
            pomodoro: { running: false, elapsed: 0, done: null },
            config: { pomodoro: { focus: 1500, break: 300 } }
        };
    }

    FixtureAdapter { id: fixture }
    CoreClient { id: core; path: "" }
    IslandQueue { id: queue }
    IslandEvents { id: events; host: fixture; core: core; queue: queue }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 520
        implicitHeight: 152
        Item {
            id: scene
            anchors.fill: parent
            Loader {
                anchors.fill: parent
                active: !!queue.current
                sourceComponent: IslandExpansion { event: queue.current }
            }
        }
    }

    Timer {
        repeat: true
        interval: 100
        running: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                fixture.capture.recording = { active: true, startedAt: Date.now() / 1000 - 4 };
                break;
            case 1:
                root.check(queue.current?.kind === "recording" && queue.current.remaining === null, "recording status");
                fixture.capture.recording = { active: false };
                fixture.power.battery = { available: true, level: .64, charging: true, pluggedIn: true };
                break;
            case 2:
                root.check(queue.current?.kind === "charging" && queue.current.remaining === 2000, "charging notice");
                queue.remove("charging");
                fixture.notifications.dnd = true;
                fixture.power.battery = { available: true, level: .18, charging: false, pluggedIn: false };
                break;
            case 3:
                root.check(!queue.current, "DND suppresses ordinary battery warning");
                fixture.power.battery = { available: true, level: .05, charging: false, pluggedIn: false };
                break;
            case 4:
                root.check(queue.current?.kind === "low-battery" && queue.current.priority === 0, "critical battery passes DND");
                queue.remove("low-battery");
                events.startupNotice = { kind: "backend", label: "> BACKEND · BACK · DOWN 3 s" };
                break;
            case 5:
                root.check(queue.current?.kind === "backend" && queue.current.remaining === 5000, "backend comeback");
                queue.remove("backend");
                events.startupNotice = { kind: "resident", label: "> RESIDENT · RESTARTED", log: "fixture-log" };
                break;
            case 6:
                root.check(queue.current?.kind === "resident" && queue.current.remaining === null, "resident restart");
                queue.remove("resident");
                core.timersData = root.timers(true, false);
                break;
            case 7:
                root.check(queue.current?.kind === "timer", "timer status");
                core.timersData = root.timers(false, true);
                break;
            case 8:
                root.check(queue.current?.kind === "done", "timer done");
                core.timersData = root.timers(false, false);
                core.sessionData = { active: null, last: { seconds: 900, tasks: 2 }, streak: { current: 3 } };
                break;
            case 9:
                root.check(queue.current?.kind === "debrief" && queue.current.data.streak === 3, "session debrief");
                running = false;
                scene.grabToImage(result => {
                    root.check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture");
                    Qt.quit();
                });
                break;
            }
        }
    }
}
