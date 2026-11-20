import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.contract
import qs.view.cues
import qs.view.shell
import qs.view.ui

// A fake core and fixture domains only. No real controls or private data.
Scope {
    id: root

    readonly property bool contextCapture: Quickshell.env("SETTINGS_CONTEXT") === "1"
    property int step: 0
    property int captured: 0
    property var sent: []
    readonly property var pages: ["palette", "wallpaper", "presets", "island", "notifications", "clips", "wifi", "bluetooth"]

    function check(name, ok) {
        console.log(ok ? "CUE_PASS" : "CUE_FAIL", name);
    }

    function named(name, item) {
        const target = item ?? prefs;
        if (target.objectName === name)
            return target;

        for (const child of target.children ?? []) {
            const found = named(name, child);
            if (found)
                return found;
        }
        return null;
    }

    function shot(name) {
        const directory = Quickshell.env("SETTINGS_SHOTS");
        if (!directory)
            return;

        scene.grabToImage(result => {
            root.check("capture." + name, result.saveToFile(directory + "/" + name + ".png"));
            root.captured++;
        });
    }

    ShellContext {
        id: shellContext
        panelOpen: true
        core: client
    }
    Component.onCompleted: {
        Host.adapter = fixture;
        fixture.palette.colors = {
            "background": "#080808",
            "surface": "#080808",
            "text": "#f2f2f2",
            "textMuted": "#999999",
            "line": "#555555",
            "accent": "#ffffff",
            "highlight": "#f2f2f2",
            "danger": "#d5a69c"
        };
        Design.source = fixture.palette;
        Motion.overdrive = false;
        Motion.reduced = true;
        client.islandData = {
            "form": "angular",
            "edge": "top",
            "placement": "notch",
            "screen": "",
            "noticeMs": 3000,
            "rest": {
                "power": "hover",
                "network": "always",
                "battery": "always",
                "inbox": "dot"
            }
        };
        client.clipsData = {
            "enterPastes": true,
            "rows": 6,
            "showImages": true
        };
        client.sfxData = {
            "cues": [
                {
                    "name": "notify.normal",
                    "enabled": false
                },
                {
                    "name": "notify.critical",
                    "enabled": true
                }
            ]
        };
        client.paletteData = {
            "name": "fixture:ink",
            "effective": "fixture:ink",
            "preview": false
        };
        client.wallpaperData = {
            "folder": "",
            "current": "",
            "available": true,
            "perScreen": false,
            "recent": [],
            "colours": false
        };
        client.presetsData = {
            "looks": [
                {
                    "name": "Ink",
                    "wallpaper": "",
                    "palette": "fixture:ink",
                    "paletteName": "Ink",
                    "islandForm": "angular",
                    "hostTheme": "",
                    "missing": [],
                    "swatch": ["#080808", "#f2f2f2"]
                }
            ],
            "preview": null
        };
        fixture.clipboard.config = {
            "disabled": false,
            "maxHistory": 1000,
            "maxEntrySize": 5.24288e+06,
            "autoClearDays": 0,
            "maxPinned": 25,
            "clearAtStartup": false
        };
    }

    FixtureAdapter {
        id: fixture
    }

    CoreClient {
        id: client

        function request(op, args, callback) {
            root.sent = root.sent.concat([
                {
                    "op": op,
                    "args": args
                }
            ]);
            let result = {
                "ok": true
            };
            if (op === "palette.list")
                result = [
                    {
                        "id": "fixture:ink",
                        "name": "Ink",
                        "source": "Fixture",
                        "accent": "#ffffff"
                    },
                    {
                        "id": "fixture:paper",
                        "name": "Paper",
                        "source": "Fixture",
                        "accent": "#aaaaaa"
                    }
                ];

            if (op === "wallpaper.list")
                result = {
                    "folder": "",
                    "exists": true,
                    "entries": []
                };

            if (op === "notif.privateApps")
                result = {
                    "apps": []
                };

            if (callback)
                callback(true, result);
        }

        path: ""
    }

    FloatingWindow {
        id: window

        implicitWidth: root.contextCapture ? 1440 : 1160
        implicitHeight: root.contextCapture ? 900 : 700
        color: Design.background

        Item {
            id: scene

            anchors.fill: parent

            Loader {
                id: shellCapture
                anchors.fill: parent
                active: root.contextCapture
                sourceComponent: Shell {
                    host: fixture
                    core: client
                    shell: shellContext
                }
            }
            PreferencesPane {
                id: prefs
                visible: !root.contextCapture && reveal > 0

                core: client
                host: fixture
                expanded: true
                section: "notifications"
                onSectionPicked: section => {
                    return prefs.section = section;
                }
                onClosed: expanded = false
            }
        }
    }

    Timer {
        interval: 140
        running: true
        repeat: true
        onTriggered: {
            const i = root.step++;
            if (root.contextCapture) {
                if (i === 2) {
                    shellCapture.item.preferencesSection = "notifications";
                    shellCapture.item.preferencesOpen = true;
                }
                if (i === 8)
                    root.shot("fart-settings");
                if (i === 12) {
                    console.log("CUE_DONE");
                    Qt.quit();
                }
                return;
            }
            if (i >= 2 && i < 18) {
                const page = root.pages[Math.floor((i - 2) / 2)];
                if (i % 2 === 0) {
                    root.named("section-" + page).clicked();
                } else {
                    root.check("section." + page, prefs.section === page);
                    root.check("lease." + page, fixture.clipboard.holds("config") === (page === "clips"));
                    root.shot(page);
                }
                return;
            }
            switch (i) {
            case 18:
                prefs.section = "notifications";
                break;
            case 20:
                {
                    const reading = root.named("current-on-the-island");
                    const writes = root.sent.length;
                    root.check("current.value", reading.valueLabel === "3 s");
                    root.check("alternatives.recede", !root.named("choice-on-the-island-1000"));
                    reading.clicked();
                    root.check("opening.never.writes", root.sent.length === writes && reading.expanded);
                    root.check("alternatives.reveal", root.named("choice-on-the-island-1000").visible);
                    root.shot("notifications-expanded");
                    break;
                }
            case 22:
                {
                    root.sent = [];
                    root.named("choice-on-the-island-3000").clicked();
                    root.check("same.value.no.write", root.sent.length === 0);
                    root.check("closed.choices.destroyed", !root.named("choice-on-the-island-1000"));
                    root.check("choice.returns.focus", root.named("current-on-the-island").activeFocus);
                    root.named("current-on-the-island").clicked();
                    root.named("choice-on-the-island-5000").clicked();
                    root.check("one.authoritative.write", root.sent.length === 1 && root.sent[0].args.line === "island notice 5");
                    root.check("no.optimistic.value", root.named("current-on-the-island").valueLabel === "3 s");
                    root.named("current-on-the-island").clicked();
                    prefs.section = "island";
                    break;
                }
            case 23:
                client.islandData = Object.assign({}, client.islandData, {
                    rest: {
                        power: "hover",
                        network: "hover",
                        battery: "always",
                        inbox: "dot"
                    }
                });
                root.check("custom.rest.has.a.reading", root.named("current-at-rest").valueLabel === "Custom");
                prefs.section = "notifications";
                break;
            case 24:
                root.check("leaving.dismisses", !root.named("current-on-the-island").expanded);
                client.islandData = Object.assign({}, client.islandData, {
                    "noticeMs": 0
                });
                root.check("unknown.is.not.off", root.named("current-on-the-island").valueLabel === "—" && !root.named("current-on-the-island").enabled);
                client.islandData = Object.assign({}, client.islandData, {
                    "noticeMs": 3000
                });
                window.implicitWidth = 900;
                break;
            case 26:
                root.shot("notifications-compact");
                root.check("compact.contains.value", root.named("current-on-the-island").mapToItem(scene, 0, 0).x + root.named("current-on-the-island").width <= scene.width);
                prefs.section = "palette";
                break;
            case 28:
                root.sent = [];
                prefs.expanded = false;
                root.check("close.cancels.palette", root.sent.some(call => {
                    return call.op === "palette.cancel";
                }));
                break;
            case 30:
                root.check("silent.settles", Motion.active === 0);
                root.check("no.hidden.config.lease", !fixture.clipboard.holds("config"));
                console.log("CUE_DONE");
                Qt.quit();
            }
        }
    }
}
