import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// Mock-up scenes for the owner. Made-up clips only.
ShellRoot {
    id: root
    property int step: 0
    property int scene: -1
    readonly property string out: Quickshell.env("MOCK_OUT")
    readonly property var wanted: (Quickshell.env("MOCK_SCENES") || "").split(",").filter(s => s)
    readonly property var clips: [
        { id: "9", text: "https://quickshell.org/docs/types/Quickshell.Wayland/WlrLayershell", isImage: false },
        { id: "8", text: "Meet at the north gate at 18:30 and bring the spare charger, the long one", isImage: false },
        { id: "7", text: "[[ binary data 412 KiB png 1920x1080 ]]", isImage: true },
        { id: "6", text: "#89b4fa", isImage: false },
        { id: "5", text: "const rows = entries.filter(e => e.pinned);", isImage: false },
        { id: "4", text: "~/Documents/notes/plan.md", isImage: false },
        { id: "3", text: "+44 20 7946 0958", isImage: false },
        { id: "2", text: "[[ binary data 88 KiB png 640x360 ]]", isImage: true },
        { id: "1", text: "https://example.org/a/very/long/link/that/keeps/on/going/past/the/edge/of/the/row", isImage: false }
    ]
    readonly property var scenes: [
        { name: "clips-open", run: () => { load(true); island.openClips(); } },
        { name: "clips-typed", run: () => { load(true); island.openClips(); type("http"); } },
        { name: "clips-images", run: () => { load(true); island.openClips(); key(Qt.Key_Tab, Qt.ControlModifier); key(Qt.Key_Tab, Qt.ControlModifier); } },
        { name: "clips-cold", run: () => { load(false); island.openClips(); type("gate"); } },
        { name: "rest-0-today", run: () => rest({}, false) },
        { name: "rest-0-today-alert", run: () => rest({}, true) },
        { name: "rest-a-clock", run: () => rest({ power: "hover", network: "matters", battery: "matters", inbox: "matters" }, false) },
        { name: "rest-a-clock-alert", run: () => rest({ power: "hover", network: "matters", battery: "matters", inbox: "matters" }, true) },
        { name: "rest-b-unread", run: () => rest({ power: "hover", network: "matters", battery: "matters", inbox: "unread" }, false) },
        { name: "rest-b-unread-alert", run: () => rest({ power: "hover", network: "matters", battery: "matters", inbox: "unread" }, true) },
        { name: "rest-c-battery", run: () => rest({ power: "hover", network: "matters", battery: "always", inbox: "unread" }, false) },
        { name: "rest-c-battery-alert", run: () => rest({ power: "hover", network: "matters", battery: "always", inbox: "unread" }, true) },
        { name: "rest-owner", run: () => rest({ power: "hover", network: "always", battery: "always", inbox: "dot" }, false) },
        { name: "rest-owner-read", run: () => { rest({ power: "hover", network: "always", battery: "always", inbox: "dot" }, false); fixture.notifications.unread = 0; } },
        { name: "rest-owner-alert", run: () => rest({ power: "hover", network: "always", battery: "always", inbox: "dot" }, true) },
        { name: "rest-owner-hover", run: () => { rest({ power: "hover", network: "always", battery: "always", inbox: "dot" }, false); island.hoverOpen = true; } },
        { name: "rest-hover", run: () => { rest({ power: "hover", network: "matters", battery: "matters", inbox: "matters" }, false); island.hoverOpen = true; } },
        { name: "clips-moved", run: () => { load(true); island.openClips(); key(Qt.Key_Down, 0); key(Qt.Key_Down, 0); key(Qt.Key_Down, 0); } }
    ]
    function rest(items: var, alert: bool): void {
        island.hoverOpen = false;
        island.restItems = items;
        fixture.network.connected = !alert;
        fixture.power.battery = { available: true, level: alert ? 0.14 : 0.64, charging: false, pluggedIn: false };
        fixture.notifications.items = [{ id: "1", appName: "Fixture", summary: "Sample", body: "", time: 0, urgency: alert ? "critical" : "normal", read: false }];
        fixture.notifications.unread = 1;
    }
    function load(ready: bool): void {
        fixture.clipboard.entries = ready ? clips : [];
        fixture.clipboard.loaded = ready;
        fixture.clipboard.thumbnails = ({ "7": "file://@THUMBS@/thumb0.png", "2": "file://@THUMBS@/thumb1.png" });
        Config.options.search.clipboardPins = [{ id: "8", text: clips[1].text, content: "" }, { id: "5", text: clips[4].text, content: "" }];
    }
    function type(text: string): void { island.clipsFace?.typeText(text); }
    function key(code: int, mods: int): void { island.clipsFace?.pressKey(code, mods); }

    FixtureAdapter { id: fixture }
    Component.onCompleted: {
        fixture.palette.colors = ({});
        Design.source = fixture.palette;
    }
    Component.onDestruction: Design.source = null

    FloatingWindow {
        id: win
        implicitWidth: 1100
        implicitHeight: 400
        color: "#40464d"
        Item {
            id: scene
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#40464d" }
            // A window under the island, as on the desktop.
            Rectangle { x: 60; y: 52; width: parent.width - 120; height: parent.height - 52; color: "#d9dce1"; radius: 6
                Repeater { model: 9; Rectangle { x: 40; y: 40 + index * 30; width: 300 + (index * 97) % 500; height: 8; radius: 2; color: "#a9adb5" } } }
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
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            const i = Math.floor(root.step / 4);
            const phase = root.step % 4;
            root.step++;
            if (i >= root.scenes.length) { Qt.quit(); return; }
            const s = root.scenes[i];
            if (root.wanted.length && !root.wanted.includes(s.name)) return;
            if (phase === 0) { island.closeClips(); }
            else if (phase === 1) s.run();
            else if (phase === 2 && s.name.startsWith("rest"))
                for (const id of ["notification:1", "low-battery", "charging", "track", "backend", "workspace", "osd"]) island.dismissCovered(id);
            else if (phase === 3) scene.grabToImage(result => {
                console.log("MOCK " + s.name + " " + result.saveToFile(root.out + "/" + s.name + ".png") + " " + island.width + "x" + island.height);
            });
        }
    }
}
