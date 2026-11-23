import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.ui

// Z219 in the real settings pane, offscreen: opening a choice focuses the current one; an unknown value reads
// READING and can't open; an offline inbox reads OFFLINE, turns every inbox action off and says so; Clear asks
// twice and Cancel disarms it.
ShellRoot {
    id: root
    property int step: 0
    property var sent: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "POLISH_PASS " : "POLISH_FAIL ") + name);
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
    CoreClient {
        id: client
        function request(op, args, callback) {
            root.sent = root.sent.concat([{ op: op, args: args }]);
            if (callback) callback(true, op === "notif.privateApps" ? { apps: [] } : { ok: true });
        }
    }
    Component.onCompleted: {
        Design.source = fixture.palette;
        client.islandData = { form: "angular", edge: "top", placement: "notch", screen: "", noticeMs: 3000,
                              rest: { power: "hover", network: "always", battery: "always", inbox: "dot" } };
        client.sfxData = { cues: [{ name: "notify.normal", kind: "notice", enabled: true },
                                  { name: "notify.critical", kind: "notice", enabled: true }] };
    }
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 1360
        implicitHeight: 860
        color: Design.background
        PreferencesPane {
            id: prefs
            core: client
            host: fixture
            expanded: true
            section: "notifications"
            onSectionPicked: section => prefs.section = section
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 6:
                root.find(prefs, "current-on-the-island").clicked();
                break;
            case 9: {
                const chip = root.find(prefs, "choice-on-the-island-3000");
                root.check(!!chip && (chip.activeFocus || chip.focus), "opening focuses the current choice");
                root.check(chip?.selected === true, "the current choice is the white cut");
                root.find(prefs, "choice-on-the-island-3000").clicked();
                client.islandData = Object.assign({}, client.islandData, { noticeMs: 0 });
                break;
            }
            case 11: {
                const reading = root.find(prefs, "current-on-the-island");
                root.check(reading.missing === "READING" && !reading.enabled, "an unknown value reads READING and can't open");
                fixture.notifications.available = false;
                break;
            }
            case 13: {
                root.check(root.find(prefs, "current-do-not-disturb").missing === "OFFLINE", "an offline inbox reads OFFLINE");
                root.check(!root.find(prefs, "notifReadAll").enabled && !root.find(prefs, "notifClear").enabled,
                           "an offline inbox turns every inbox action off");
                root.check(root.find(prefs, "inboxCount").text === "Offline", "an offline inbox says so");
                fixture.notifications.available = true;
                break;
            }
            case 15: {
                const clear = root.find(prefs, "notifClear");
                clear.clicked();
                root.check(clear.armed, "clear arms first");
                root.find(prefs, "notifClearCancel").clicked();
                root.check(!clear.armed, "cancel disarms");
                root.sent = [];
                clear.clicked();
                clear.clicked();
                root.check(root.sent.some(s => s.op === "notif.clear"), "clear asks twice, then clears");
                Qt.quit();
                break;
            }
            }
        }
    }
}
