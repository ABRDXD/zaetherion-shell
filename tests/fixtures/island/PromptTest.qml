import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// A Wi-Fi password or a Bluetooth pairing asked for while FART is closed (docs/NET_BT.md §5): an island event held
// while the question is open, whose click opens FART's settings there. Made-up names; nothing is actuated.
ShellRoot {
    id: root
    property int step: 0
    property var opened: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function find(item: var, test: var): var {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children) {
            const found = find(child, test);
            if (found) return found;
        }
        return null;
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 140
        Item {
            id: scene
            anchors.fill: parent
            IslandSurface {
                id: island
                host: fixture
                motionLevel: "off"
                pointerInside: false
                anchors.horizontalCenter: parent.horizontalCenter
                onOpenSettings: section => root.opened = root.opened.concat([section])
            }
        }
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 2:
                fixture.network.prompt = { id: "fake-prompt", ssid: "FIXTURE-CAFE", name: "FIXTURE-CAFE", kind: "psk", reason: "" };
                break;
            case 5: {
                const shown = island.expansion;
                root.check(shown?.kind === "prompt" && shown.data.section === "wifi"
                           && shown.data.task === "FIXTURE-CAFE needs its password.", "a password asked for shows on the island");
                root.check(JSON.stringify(shown?.data ?? {}).indexOf("secret") < 0, "no secret on the island");
                scene.grabToImage(r => root.check(r.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture"));
                break;
            }
            case 6: {
                const area = root.find(island, item => item instanceof MouseArea && item.enabled && item.cursorShape === Qt.PointingHandCursor);
                area?.clicked(null);
                root.check(JSON.stringify(root.opened) === JSON.stringify(["wifi"]), "a click opens the Wi-Fi settings");
                fixture.network.prompt = { id: "fake-prompt", ssid: "FIXTURE-CAFE", name: "FIXTURE-CAFE", kind: "psk", reason: "wrong-password" };
                break;
            }
            case 8:
                root.check(island.expansion?.data.task === "Wrong password for FIXTURE-CAFE. Type it again.", "a wrong password says so");
                fixture.network.prompt = null;
                break;
            case 11:
                root.check(island.expansion?.kind !== "prompt", "it goes when the question does");
                fixture.bluetooth.pairing = { id: "fake-pairing", kind: "confirm", deviceName: "Fixture Keyboard", device: "x", passkey: "000000" };
                break;
            case 14:
                root.check(island.expansion?.kind === "prompt" && island.expansion.data.section === "bluetooth"
                           && island.expansion.data.task === "Does Fixture Keyboard show 000000?", "a pairing shows its question");
                fixture.bluetooth.pairing = null;
                break;
            case 17:
                root.check(island.expansion?.kind !== "prompt", "the pairing goes with its question");
                Qt.quit();
                break;
            }
        }
    }
}
