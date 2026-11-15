import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// The island's hover word (docs/NET_BT.md §5): "joining", "wrong password", "pairing" beside the Wi-Fi and Bluetooth
// glyphs while hovered; a click opens FART's settings at that section. Made-up names only; nothing is actuated.
ShellRoot {
    id: root
    property int step: 0
    property var opened: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    // Every shown item under the rest row whose text or description is `text`.
    function find(item: var, text: string): var {
        if (!item) return null;
        if (item.visible && (item.text === text || item.description === text) && item.width > 0) return item;
        for (const child of item.children) {
            const found = find(child, text);
            if (found) return found;
        }
        return null;
    }
    readonly property var rest: island.restPaneItem

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 120
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                motionLevel: "off"
                pointerInside: false
                anchors.horizontalCenter: parent.horizontalCenter
                onOpenSettings: section => root.opened = root.opened.concat(["settings:" + section])
                onOpenPanel: room => root.opened = root.opened.concat(["panel:" + room])
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
                fixture.network.attempt = { target: "FIXTURE-CAFE", action: "join", phase: "working", reason: "" };
                // A pair in progress (its prompt, when one comes, is the island's own event: PromptTest).
                fixture.bluetooth.attempts = { "00:00:5E:00:53:02": { target: "00:00:5E:00:53:02", action: "pair", phase: "working", reason: "" } };
                break;
            case 1:
                root.check(!root.find(root.rest, "joining") && !root.find(root.rest, "pairing"), "no word at rest");
                island.pointerInside = true;
                break;
            case 6:
                root.check(island.wings && !!root.find(root.rest, "joining") && !!root.find(root.rest, "pairing"),
                           "hovered: joining and pairing");
                scene.grabToImage(result => root.check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture"));
                break;
            case 7:
                root.find(root.rest, "joining").clicked();
                root.find(root.rest, "Bluetooth: pairing").clicked();
                root.check(JSON.stringify(root.opened) === JSON.stringify(["settings:wifi", "settings:bluetooth"]),
                           "a word opens its settings section");
                fixture.network.attempt = { target: "FIXTURE-CAFE", action: "join", phase: "wrong-secret", reason: "bad-credentials" };
                fixture.bluetooth.attempts = {};
                break;
            case 8:
                root.check(!!root.find(root.rest, "wrong password") && !root.find(root.rest, "pairing")
                           && root.find(root.rest, "wrong password").color === Design.accent, "wrong password, in accent");
                fixture.network.attempt = { target: "FIXTURE-CAFE", action: "join", phase: "done", reason: "" };
                break;
            case 9:
                root.check(!root.find(root.rest, "wrong password") && !root.find(root.rest, "joining"), "nothing once it is done");
                root.opened = [];
                root.find(root.rest, "Network").clicked();
                root.find(root.rest, "Bluetooth").clicked();
                root.check(JSON.stringify(root.opened) === JSON.stringify(["panel:devices", "panel:devices"]),
                           "without a word the glyphs open Devices as before");
                island.pointerInside = false;
                break;
            case 10:
                Qt.quit();
                break;
            }
        }
    }
}
