import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// Z174: while FART covers the island, an OSD change shows in FART's header at once, is never banked for the
// fold, updates in place and leaves 1.2 s after the last change. Uncovered, the island shows it as before.
ShellRoot {
    id: root
    property int step: 0
    property var reading: null
    property var plate: null
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function find(item, name: string): var {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
    // Whether the island's queue holds an entry: the IslandQueue is a QtObject in the surface's data list.
    function banked(id: string): bool {
        for (const object of island.data)
            if (object && object.entries !== undefined && typeof object.offer === "function")
                return object.entries.some(event => event.id === id);
        return true;
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 176
        color: Design.background
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
            // The Overlay's binding, without the Overlay: the header readout follows the island's hand-over.
            FartHeaderOsd {
                id: header
                anchors.fill: parent
                headerTop: 24
                headerHeight: 32
                event: island.headerOsd
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
                island.docked = true;
                break;
            case 1:
                fixture.osd.event = { kind: "volume", level: .4, muted: false };
                break;
            case 2:
                root.reading = root.find(header, "fartHeaderOsdReading");
                root.plate = root.find(header, "fartHeaderOsd");
                // In the header at once, and not waiting in the queue for the fold.
                root.check(island.headerOsd?.kind === "volume" && island.expansion === null && island.coveredEvent === null
                    && !root.banked("osd") && header.showing && root.reading?.text === "40%", "covered osd shows in header");
                break;
            case 3:
                fixture.osd.event = { kind: "volume", level: .55, muted: false };
                break;
            case 4:
                root.check(root.find(header, "fartHeaderOsdReading") === root.reading && root.reading.text === "55%"
                    && island.headerOsd?.level === .55 && island.coveredEvent === null && !root.banked("osd"),
                    "repeat updates in place");
                break;
            case 8:
                // Dropped in: on the header row and no taller than it.
                root.check(root.plate?.height === header.headerHeight && Math.abs(root.plate.y - header.headerTop) < .01,
                    "readout sits on the header row");
                break;
            case 9:
                fixture.osd.event = { kind: "volume", level: .55, muted: true };
                break;
            case 10:
                root.check(root.reading.text === "MUTED", "muted reads MUTED");
                scene.grabToImage(result => root.check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture"));
                break;
            case 17:
                // 1.6 s after the first change, 0.8 s after the last (ticks only run late): still up.
                root.check(island.headerOsd?.muted === true && header.showing, "dwell follows the last change");
                break;
            case 23:
                root.check(island.headerOsd === null, "leaves after its dwell");
                break;
            case 24:
                root.check(!header.showing, "header readout gone");
                island.docked = false;
                break;
            case 25:
                root.check(island.expansion === null && island.headerOsd === null, "fold replays no stale osd");
                fixture.osd.event = { kind: "brightness", level: .7, muted: false };
                break;
            case 26:
                root.check(island.expansion?.kind === "osd" && island.expansion.data.kind === "brightness"
                    && island.headerOsd === null && !header.showing && root.banked("osd"), "uncovered osd on island");
                island.docked = true;
                break;
            case 27:
                root.check(island.headerOsd?.kind === "brightness" && island.expansion === null && !root.banked("osd"),
                    "dock lifts osd into header");
                island.docked = false;
                break;
            case 28:
                root.check(island.expansion?.kind === "osd" && island.headerOsd === null, "fold hands it back");
                running = false;
                Qt.quit();
                break;
            }
        }
    }
}
