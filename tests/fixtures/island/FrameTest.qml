import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.ui

ShellRoot {
    FixtureAdapter { id: fixture }
    Component.onCompleted: {
        Design.source = fixture.palette;
        const fixtureBlue = fixture.palette.colors.background;
        check(Design.islandFill.toString() === fixtureBlue, "fixture palette");
        fixture.palette.colors = ({ background: "#101010", surface: "#334466", surfaceRaised: "#88aaff",
            accent: "#1a2a3a" });
        check(Design.islandFill.toString() === "#1a2a3a", "darkest blue role");
        fixture.palette.colors = ({ background: "#602010", surface: "#292929", text: "#c8c8c8" });
        check(Design.islandFill.toString() === "#292929", "darkest role without blue");
        fixture.palette.colors = ({});
        check(Design.islandFill === Design.background, "empty palette fallback");
    }
    Component.onDestruction: Design.source = null

    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }

    FloatingWindow {
        implicitWidth: 440
        implicitHeight: 96

        Item {
            id: scene
            anchors.fill: parent

            IslandFrame {
                width: implicitWidth
                height: implicitHeight
            }
            IslandFrame {
                width: implicitWidth
                height: implicitHeight
                anchors.bottom: parent.bottom
                bottomEdge: true
            }
        }
    }

    Timer {
        running: true
        interval: 150
        onTriggered: {
            const started = scene.grabToImage(result => {
                check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture");
                Qt.quit();
            });
            if (!started) {
                check(false, "offscreen capture");
                Qt.quit();
            }
        }
    }
}
