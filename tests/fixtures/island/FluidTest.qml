import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// FARTland // Fluid (Z145, Z146): the compact rest, the playing width, hover and a notification face.
ShellRoot {
    id: root
    property int step: 0
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: {
        Design.source = fixture.palette;
        Design.form = "fluid";
    }
    Component.onDestruction: {
        Design.form = "angular";
        Design.source = null;
    }

    FloatingWindow {
        implicitWidth: 980
        implicitHeight: 176
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                motionLevel: "off"
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
                fixture.media.active = Object.assign({}, fixture.media.active, { playing: false });
                break;
            case 1:
                root.check(Design.fluid && island.width === 100 && island.height === 36, "fluid rests compact");
                fixture.media.active = Object.assign({}, fixture.media.active, { playing: true });
                break;
            case 2:
                root.check(island.width > 140, "fluid shows media while playing");
                island.preferClock = true;
                break;
            case 3:
                root.check(island.width === 100, "right-click switches to the clock");
                island.preferClock = false;
                island.pointerInside = true;
                break;
            case 7:
                root.check(island.wings && island.width > 500, "fluid hover shows the row");
                island.pointerInside = false;
                fixture.notifications.items = fixture.notifications.items.concat([{ id: "fluid", appName: "DEMO",
                    summary: "Sample", body: "Synthetic line", urgency: "normal", actions: [{ id: "open", label: "View" }],
                    reply: "reply" }]);
                break;
            case 8:
                root.check(island.expansion?.kind === "notification" && island.height === 124, "fluid notification face");
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
