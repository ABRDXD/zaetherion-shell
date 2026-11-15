import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// After Sonner: notices waiting behind the shown one show as card edges with "+N waiting"; hovered, the card lists
// who they are from; a hard sideways flick sends the card off the island (the Inbox keeps it), a small one springs
// back. Synthetic items only; the countdown is held by a pointer on the card throughout.
ShellRoot {
    id: root
    property int step: 0
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function item(id: string, time: int, app: string): var {
        return { id, time, appName: app, summary: "Synthetic " + id, body: "Synthetic line", urgency: "normal" };
    }
    function find(name: string): var {
        const found = [];
        const walk = node => { if (node.objectName === name) found.push(node); for (const child of node.children) walk(child); };
        walk(island);
        return found;
    }
    readonly property var card: find("noticeCard").find(c => c.visible && c.enabled !== false) ?? null
    function dismissed(id: string): bool {
        return fixture.notifications.calls.some(call => call.method === "dismiss" && call.args[0] === id);
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
        implicitHeight: 260
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
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                fixture.notifications.items = [root.item("a", 1, "MAIL"), root.item("b", 2, "CHAT"), root.item("c", 3, "CALENDAR")];
                island.noticeHovered = true;   // the countdown waits while the pointer is on the card
                break;
            case 2: {
                const shown = island.expansion?.id;
                root.check(island.noticeVisible && island.waitingNotices.length === 2 && !island.waitingNotices.some(e => e.id === shown),
                           "two wait behind the shown notice");
                const waiting = root.find("noticeWaiting").find(t => t.visible);
                root.check(!!waiting && waiting.text.indexOf("+2") === 0, "card edges say +2 waiting");
                root.card.fan = true;
                break;
            }
            case 3: {
                const fan = root.find("noticeFan");
                root.check(fan.length === 2 && fan.every(row => row.visible), "hover fans out who is waiting");
                root.check(root.find("noticeWaiting").every(t => !t.visible), "the count gives way to the list");
                root.card.fan = false;
                const first = island.expansion.id;
                root.card.flick = root.card.width * 0.5;
                root.card.release();
                root.flicked = first;
                break;
            }
            case 6:
                root.check(island.expansion?.id !== root.flicked && island.noticeVisible, "a hard flick sends it off");
                root.check(!root.dismissed(root.flicked.replace("notification:", "")), "the Inbox keeps a flicked notice");
                root.held = island.expansion.id;
                root.card.flick = 12;
                root.card.release();
                break;
            case 9:
                root.check(island.expansion?.id === root.held && root.card.flick === 0, "a small flick springs back");
                root.check(island.waitingNotices.length === 1, "one left waiting");
                running = false;
                scene.grabToImage(result => {
                    root.check(result.saveToFile(Quickshell.env("ISLAND_FRAME_SHOT")), "offscreen capture");
                    Qt.quit();
                });
                break;
            }
        }
    }
    property string flicked: ""
    property string held: ""
}
