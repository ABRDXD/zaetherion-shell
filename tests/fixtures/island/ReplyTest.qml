import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// Keyboard interactivity around a reply draft. Dropping the layer to None during an OSD and back strands a
// resting pointer in Hyprland, so a queued draft must hold OnDemand through the pre-emption.
ShellRoot {
    id: root
    property int step: 0
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function notify(id: string): void {
        fixture.notifications.items = fixture.notifications.items.concat([{ id, appName: "DEMO", summary: "Sample",
            body: "Synthetic line", urgency: "normal", actions: [{ id: "open", label: "View" }], reply: "reply" }]);
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 560
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
                root.check(island.keyboardRequest === "none", "rest takes no keyboard");
                root.notify("plain");
                break;
            case 1:
                root.check(island.noticeVisible && island.keyboardRequest === "ondemand", "notice offers keyboard");
                fixture.osd.event = { kind: "volume", level: .3, muted: false };
                break;
            case 2:
                root.check(island.expansion?.kind === "osd" && island.keyboardRequest === "none",
                    "OSD over a notice without a draft releases keyboard");
                break;
            case 16:
                root.check(island.expansion?.id === "notification:plain", "notice resumes");
                island.replyDrafts = { "notification:plain": "Synthetic reply" };
                fixture.osd.event = { kind: "volume", level: .4, muted: false };
                break;
            case 17:
                root.check(island.expansion?.kind === "osd" && island.keyboardRequest === "ondemand",
                    "draft holds keyboard through OSD");
                break;
            case 31:
                root.check(island.expansion?.id === "notification:plain" && island.draftLength === 15
                    && island.keyboardRequest === "ondemand", "draft survives pre-emption");
                island.replyFocus("notification:plain", true);
                root.check(island.replyFocusId === "notification:plain"
                    && (island.windowActive || island.keyboardRequest === "exclusive"), "focus claim when inactive");
                break;
            case 36:
                root.check(island.keyboardRequest !== "exclusive", "claim is released");
                island.keyboardPeer = true;
                island.enterKeyboard();
                break;
            case 37:
                root.check(island.wantsKeyboard && island.keyboardRequest !== "exclusive", "island waits for docked panel");
                island.keyboardPeer = false;
                break;
            case 38:
                root.check(island.keyboardRequest === "exclusive", "island claims after panel lets go");
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
