import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.rooms
import qs.view.ui

// The Wi-Fi and Bluetooth tiles' settings glyph (owner, 15 November 2026): hidden at rest, shown hovered or focused;
// a left click on it opens the link's panel like the right button, and never toggles the link.
ShellRoot {
    id: root
    property int step: 0
    property var events: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "TILE_PASS " : "TILE_FAIL ") + name);
    }
    function find(item: var, name: string): var {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = find(child, name);
            if (found) return found;
        }
        return null;
    }
    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 600
        implicitHeight: 150
        color: Design.background
        Row {
            id: scene
            x: 20; y: 20
            spacing: 16
            LinkPlane {
                id: wifi
                width: 270; height: 104
                symbol: "wifi"; label: "Wi-Fi"; on: true; line: "FIXTURE-NET"; detail: "192.0.2.10"
                settingsHint: "Wi-Fi settings"
                onClicked: root.events = root.events.concat(["wifi:toggle"])
                onSecondaryClicked: root.events = root.events.concat(["wifi:settings"])
            }
            LinkPlane {
                id: bt
                width: 270; height: 104
                symbol: "bluetooth"; label: "Bluetooth"; on: false; line: "Off"
                settingsHint: "Bluetooth settings"
                onClicked: root.events = root.events.concat(["bt:toggle"])
                onSecondaryClicked: root.events = root.events.concat(["bt:settings"])
            }
        }
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 1:
                root.check(root.find(wifi, "linkSettings").opacity === 0 && root.find(bt, "linkSettings").opacity === 0,
                           "the glyph is hidden at rest");
                wifi.forceActiveFocus();
                break;
            case 4:
                root.check(root.find(wifi, "linkSettings").opacity === 1 && root.find(bt, "linkSettings").opacity === 0,
                           "the focused tile shows its glyph");
                scene.grabToImage(r => root.check(r.saveToFile(Quickshell.env("TILE_SHOT")), "capture"));
                break;
            case 5: {
                const area = root.find(wifi, "linkSettings").children[0];
                area.clicked(null);
                wifi.clicked();
                root.check(JSON.stringify(root.events) === JSON.stringify(["wifi:settings", "wifi:toggle"]),
                           "the glyph opens settings; the tile still toggles");
                Qt.quit();
                break;
            }
            }
        }
    }
}
