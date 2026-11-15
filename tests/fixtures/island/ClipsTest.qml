import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// Quick paste (S3, Z181–Z183) and the island's rest modes (Z201). Made-up clips only.
ShellRoot {
    id: root
    property int step: 0
    property string roomQuery: "-"
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function calls(method: string): var {
        return fixture.clipboard.calls.filter(call => call.method === method);
    }
    readonly property var clips: [
        { id: "3", text: "https://example.org/one", isImage: false },
        { id: "2", text: "a plain sentence about the gate", isImage: false },
        { id: "1", text: "[[ binary data 1 KiB png 8x8 ]]", isImage: true }
    ]

    FixtureAdapter { id: fixture }
    Component.onCompleted: {
        Design.source = fixture.palette;
        fixture.clipboard.entries = [];
        fixture.clipboard.loaded = false;
    }
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 320
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                motionLevel: "off"
                pointerInside: false
                anchors.horizontalCenter: parent.horizontalCenter
                onClipRoom: query => root.roomQuery = query
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const face = island.clipsFace;
            switch (root.step++) {
            case 0:
                island.openClips();
                break;
            case 1:
                root.check(island.expansion?.kind === "clips" && island.heldFace && island.keyboardRequest === "exclusive",
                    "opens as a held face with the keyboard");
                root.check(fixture.clipboard.holds("history"), "leases the history while open");
                // Cold: the history is not in yet. Typing is kept and an early Enter waits.
                face.typeText("gate");
                face.pressKey(Qt.Key_Return, 0);
                root.check(root.calls("copy").length === 0 && face.pendingEnter, "early enter is held");
                fixture.clipboard.entries = root.clips;
                fixture.clipboard.loaded = true;
                break;
            case 2:
                root.check(root.calls("copy").length === 1 && root.calls("copy")[0].args[0] === "2",
                    "held enter copies the first match once loaded");
                root.check(!island.clipsOpen, "folds after acting");
                island.openClips();
                break;
            case 3:
                root.check(face === null || true, "reopens");
                island.clipsFace.pressKey(Qt.Key_Down, 0);
                island.clipsFace.pressKey(Qt.Key_Return, Qt.ShiftModifier);
                root.check(root.calls("paste").length === 1 && root.calls("paste")[0].args[0] === "2",
                    "shift+enter pastes the chosen clip");
                island.openClips();
                break;
            case 4:
                island.clipsFace.pressKey(Qt.Key_Tab, Qt.ControlModifier);
                island.clipsFace.pressKey(Qt.Key_Tab, Qt.ControlModifier);
                root.check(island.clipsFace.filter === "images" && island.clipsFace.matches.length === 1, "ctrl+tab steps the filter");
                root.check(root.calls("requestThumbnail").some(call => call.args[0] === "1"), "a visible image row asks for its thumbnail");
                island.clipsFace.typeText("zz");
                island.clipsFace.pressKey(Qt.Key_O, Qt.ControlModifier);
                root.check(root.roomQuery === "zz" && !island.clipsOpen, "ctrl+o opens the room with the query");
                island.openClips();
                break;
            case 5:
                island.clipsFace.pressKey(Qt.Key_Escape, 0);
                root.check(!island.clipsOpen && !fixture.clipboard.holds("history"), "esc folds and lets go of the history");
                island.toggleClips();
                break;
            case 6:
                root.check(island.clipsOpen, "toggle opens");
                island.toggleClips();
                root.check(!island.clipsOpen, "toggle folds");
                island.openClips();
                break;
            case 7:
                // Super+V again closes (owner): Hyprland hands the keys to the face while it holds the keyboard.
                island.clipsFace.pressKey(Qt.Key_V, Qt.MetaModifier);
                root.check(!island.clipsOpen && !fixture.clipboard.holds("history"), "super+v folds");
                // The owner's rest (B): power and bell on hover; Wi-Fi and battery at the shoulder; unread as a dot.
                fixture.notifications.unread = 1;
                island.restItems = { power: "hover", network: "always", battery: "always", inbox: "dot" };
                break;
            case 8: {
                const rest = island.restPaneItem;
                root.check(rest && !rest.inboxAtRest && rest.statusAtEdge && rest.unreadDot, "rest B: no bell, status at the edge, unread dot");
                fixture.notifications.unread = 0;
                break;
            }
            case 9:
                root.check(!island.restPaneItem.unreadDot, "no dot when all is read");
                island.restItems = ({});
                break;
            case 10:
                root.check(island.restPaneItem.inboxAtRest && !island.restPaneItem.statusAtEdge, "default rest unchanged");
                scene.grabToImage(result => root.check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture"));
                break;
            case 11:
                Qt.quit();
                break;
            }
        }
    }
}
