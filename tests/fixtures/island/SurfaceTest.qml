import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

ShellRoot {
    id: root
    property int step: 0
    property double fakeNow: 1000
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }

    FixtureAdapter { id: fixture }
    IslandQueue { id: order; clock: () => root.fakeNow }
    Component.onCompleted: {
        Design.source = fixture.palette;
        order.offer("notice", "notification", 40, {}, 5000);
        fakeNow += 750;
        order.offer("osd", "osd", 20, {}, 1200);
        check(order.current.id === "osd" && order.entries[1].remaining === 4250, "preemption saves dwell");
        fakeNow += 300;
        order.remove("osd");
        order.hovered = true;
        check(order.current.id === "notice" && order.deadline === 0 && order.current.remaining === 4250, "resume and hover pause");
        fakeNow += 2000;
        order.hovered = false;
        check(order.deadline === fakeNow + 4250, "hover resumes remaining time");
        order.remove("notice");
    }
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 176
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                motionLevel: "off"
                workspaceIds: ["1", "2", "3", "4"]
                pointerInside: false
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.check(island.width === 420 && island.height === 36 && !island.wings, "rest frame");
                root.check(!fixture.media.holds("spectrum") && !fixture.audio.holds("mixer"), "idle has no leases");
                fixture.media.active = Object.assign({}, fixture.media.active, { playing: true });
                island.pointerInside = true;
                break;
            case 1:
                root.check(!island.wings && fixture.media.holds("spectrum"), "hover delay and playing lease");
                break;
            case 5:
                root.check(island.wings && island.width > 420 && fixture.audio.holds("mixer"), "hover shows wings");
                island.pointerInside = false;
                fixture.media.active = Object.assign({}, fixture.media.active, { playing: false, title: "Test Track" });
                break;
            case 6:
                root.check(!fixture.media.holds("spectrum") && !fixture.audio.holds("mixer"), "leases released");
                root.check(island.expansion?.kind === "track" && island.height === 72, "track face");
                fixture.workspaces.activeId = "2";
                break;
            case 7:
                root.check(island.expansion?.kind === "workspace", "workspace flash");
                fixture.notifications.items = fixture.notifications.items.concat([{ id: "preview", appName: "DEMO", summary: "Sample",
                    body: "Synthetic line", urgency: "normal", actions: [{ id: "open", label: "View" }], reply: "reply" }]);
                fixture.system.memory = Object.assign({}, fixture.system.memory, { pressureSomeAvg10: 1.2,
                    processes: [{ name: "Sample process", pss: 131072 }] });
                break;
            case 8:
                root.check(island.expansion?.kind === "memory" && island.height === 140, "memory face");
                fixture.osd.event = { kind: "volume", level: .4, muted: false };
                break;
            case 9:
                root.check(island.expansion?.kind === "osd" && island.height === 56, "osd face");
                fixture.notifications.items = fixture.notifications.items.concat([{ id: "critical", appName: "DEMO",
                    summary: "Critical fixture", body: "Synthetic", urgency: "critical" }]);
                break;
            case 10:
                root.check(island.expansion?.kind === "critical" && island.height === 124, "notification face");
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
