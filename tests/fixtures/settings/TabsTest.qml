import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.ui

// FART's Island and Clips tabs (Z176, Z184, Z201, Z202) in the real settings pane, offscreen. The core is a stand-in
// that records what the tabs ask for; DMS's clipboard settings are made-up values on the fixture's domain.
ShellRoot {
    id: root
    property int step: 0
    property var sent: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "TABS_PASS " : "TABS_FAIL ") + name);
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
    function lines(): var { return root.sent.filter(s => s.op === "cmd.run").map(s => s.args.line); }

    FixtureAdapter { id: fixture }
    CoreClient {
        id: client
        function request(op, args, callback) {
            root.sent = root.sent.concat([{ op: op, args: args }]);
            if (callback) callback(true, { ok: true });
        }
    }
    Component.onCompleted: {
        Design.source = fixture.palette;
        client.islandData = { form: "angular", edge: "top", placement: "notch", screen: "",
                              rest: { power: "hover", network: "always", battery: "always", inbox: "dot" } };
        client.clipsData = { enterPastes: false, rows: 6, showImages: true };
        fixture.clipboard.config = { disabled: false, maxHistory: 1000, maxEntrySize: 5242880, autoClearDays: 0,
                                     maxPinned: 25, clearAtStartup: false };
    }
    Component.onDestruction: Design.source = null

    FloatingWindow {
        implicitWidth: 1160
        implicitHeight: 700
        color: Design.background
        Item {
            id: scene
            anchors.fill: parent
            PreferencesPane {
                id: prefs
                core: client
                host: fixture
                expanded: true
                section: "island"
                onSectionPicked: section => prefs.section = section
            }
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            switch (root.step++) {
            case 6:
                root.check(root.find(prefs, "rest-preset-b")?.selected === true
                           && root.find(prefs, "rest-preset-a")?.selected === false, "the owner's rest reads as preset B");
                root.check(root.find(prefs, "choice-edge-top")?.selected === true
                           && root.find(prefs, "choice-screen-")?.selected === true, "edge and screen read from the core");
                root.check(!fixture.clipboard.holds("config"), "the clipboard settings are not read on another tab");
                scene.grabToImage(r => root.check(r.saveToFile(Quickshell.env("TABS_SHOT_ISLAND")), "island capture"));
                break;
            case 7:
                root.find(prefs, "rest-preset-a").clicked();
                root.find(prefs, "choice-power-always").clicked();
                root.find(prefs, "choice-edge-bottom").clicked();
                root.find(prefs, "choice-screen-").clicked();          // already chosen: nothing sent
                root.check(JSON.stringify(root.lines()) === JSON.stringify(["island rest a", "island rest power always", "island bottom"]),
                           "island choices go through the island verb");
                prefs.section = "clips";
                break;
            case 10:
                root.check(fixture.clipboard.holds("config"), "the clips tab reads DMS's clipboard settings");
                root.check(root.find(prefs, "choice-enter-false")?.selected === true
                           && root.find(prefs, "choice-keep-1000")?.selected === true, "values read from the core and DMS");
                scene.grabToImage(r => root.check(r.saveToFile(Quickshell.env("TABS_SHOT_CLIPS")), "clips capture"));
                break;
            case 11: {
                root.sent = [];
                root.find(prefs, "choice-enter-true").clicked();
                root.find(prefs, "choice-rows-8").clicked();
                const quick = root.sent.filter(s => s.op === "clips.set").map(s => s.args);
                root.check(JSON.stringify(quick) === JSON.stringify([{ key: "enterPastes", value: true }, { key: "rows", value: 8 }]),
                           "quick paste choices go to the core");
                root.find(prefs, "choice-keep-500").clicked();
                root.find(prefs, "choice-auto-clear-7").clicked();
                const set = fixture.clipboard.calls.filter(c => c.method === "setConfig").map(c => c.args);
                root.check(JSON.stringify(set) === JSON.stringify([["maxHistory", 500], ["autoClearDays", 7]]),
                           "history choices go to DMS's config");
                const clear = root.find(prefs, "clipsClear");
                clear.clicked();
                const once = fixture.clipboard.calls.filter(c => c.method === "clearHistory").length;
                clear.clicked();
                const twice = fixture.clipboard.calls.filter(c => c.method === "clearHistory").length;
                root.check(once === 0 && twice === 1, "clear asks twice");
                prefs.section = "island";
                break;
            }
            case 13:
                root.check(!fixture.clipboard.holds("config"), "leaving the tab lets go of the settings");
                Qt.quit();
                break;
            }
        }
    }
}
