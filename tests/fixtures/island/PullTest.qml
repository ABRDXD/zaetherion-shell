import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// After Vaul: the resting island stretches toward the screen's middle with growing resistance, says what letting go
// will do, springs back short of the threshold and opens FART past it; the launcher folds only past its threshold.
ShellRoot {
    id: root
    property int step: 0
    property var opened: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function hint(): var {
        const found = [];
        const walk = node => { if (node.objectName === "islandPullHint") found.push(node); for (const child of node.children) walk(child); };
        walk(island);
        return found[0];
    }
    function pullTo(travel: real): void { island.pullBy(travel); }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 600
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                motionLevel: "off"
                pointerInside: false
                anchors.horizontalCenter: parent.horizontalCenter
                onTogglePanel: room => root.opened = root.opened.concat([room])
            }
        }
    }

    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.pullTo(40);
                break;
            case 1:
                root.check(island.height > island.restHeight && island.height < island.restHeight + 40, "the island follows with resistance");
                root.check(root.hint().visible && root.hint().text === "PULL", "short of the threshold it says PULL");
                island.endPull();
                break;
            case 4:
                root.check(island.pull === 0 && island.height === island.restHeight && root.opened.length === 0, "a short pull springs back");
                root.pullTo(140);
                break;
            case 5:
                root.check(island.pull < island.pullReach && root.hint().text === "RELEASE · FART", "past the threshold it says RELEASE");
                island.endPull();
                break;
            case 7:
                root.check(root.opened.length === 1, "a long pull opens FART");
                island.openLauncher();
                break;
            case 9:
                root.check(island.launcherOpen, "launcher open");
                island.foldTravel = 50;
                island.endFold();
                break;
            case 12:
                root.check(island.launcherOpen && island.foldTravel === 0, "a short drag up springs the launcher back");
                island.foldTravel = 120;
                island.endFold();
                break;
            case 14:
                root.check(!island.launcherOpen, "a long drag up folds the launcher");
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
