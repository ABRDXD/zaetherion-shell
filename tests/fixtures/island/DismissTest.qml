import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.shell
import qs.view.ui

// Z175: a right-click dismisses a shown notification (island and Inbox), and its countdown pauses only while the
// pointer is on the card, not on the island around it. Synthetic items only.
ShellRoot {
    id: root
    property int step: 0
    function check(ok: bool, name: string): void {
        console.log((ok ? "ISLAND_PASS " : "ISLAND_FAIL ") + name);
    }
    function item(id: string, time: int, more: var): var {
        return Object.assign({ id, time, appName: "DEMO APP", summary: "Synthetic " + id, body: "Synthetic line",
            urgency: "normal" }, more);
    }
    function show(items: var): void { fixture.notifications.items = items; }
    function area(): var {
        const found = [];
        const walk = node => {
            if (node.objectName === "noticeRightClick") found.push(node);
            for (const child of node.children) walk(child);
        };
        walk(island);
        return found[0] ?? null;
    }
    function dismissed(id: string): bool {
        return fixture.notifications.calls.some(call => call.method === "dismiss" && call.args[0] === id);
    }

    FixtureAdapter { id: fixture }
    Component.onCompleted: Design.source = fixture.palette
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 920
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
        repeat: true
        running: true
        onTriggered: {
            switch (root.step++) {
            case 0:
                root.check(root.area()?.enabled === false, "right-click is idle without a notification");
                root.show([root.item("a", 1, {})]);
                break;
            case 1:
                root.check(island.expansion?.id === "notification:a" && island.expansion.remaining === 3000, "default showing time is 3 s");
                root.check(root.area()?.enabled === true && root.area().acceptedButtons === Qt.RightButton, "right-click takes only the right button");
                root.area().clicked(null);
                break;
            case 2:
                root.check(island.expansion === null, "right-click removes it from the island");
                root.check(root.dismissed("a"), "right-click dismisses it in the Inbox");
                root.show([root.item("a", 1, {}), root.item("c", 2, { urgency: "critical" })]);
                break;
            case 3:
                root.check(island.expansion?.kind === "critical" && island.expansion.remaining === null, "critical stays until dismissed");
                root.area().clicked(null);
                break;
            case 4:
                root.check(island.expansion === null && root.dismissed("c"), "right-click dismisses a critical notification");
                // The pointer on the island but off the card does not pause the countdown.
                island.pointerInside = true;
                root.show([root.item("c", 2, {}), root.item("p", 3, { timeout: 500 })]);
                break;
            case 5:
                root.check(island.expansion?.id === "notification:p" && !island.noticeHovered, "pointer off the card");
                break;
            case 12:
                root.check(island.expansion === null, "island hover does not pause a notification");
                // The pointer on the card does.
                root.show([root.item("c", 2, {}), root.item("p", 3, { timeout: 500 }), root.item("q", 4, { timeout: 500 })]);
                island.noticeHovered = true;
                break;
            case 13:
                root.check(island.expansion?.id === "notification:q", "second notification shown");
                break;
            case 20:
                root.check(island.expansion?.id === "notification:q", "card hover pauses a notification");
                island.noticeHovered = false;
                break;
            case 27:
                root.check(island.expansion === null, "leaving the card resumes the countdown");
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
