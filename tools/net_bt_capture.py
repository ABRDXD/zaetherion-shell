#!/usr/bin/env python3
"""Captures of FART's Wi-Fi and Bluetooth settings (docs/NET_BT.md §5), offscreen, for the owner's look.

    python3 tools/net_bt_capture.py OUT_DIR [--preset Mocha] [--scenes wifi,bt-pin] [--size 1080x620]

Each scene fills plain contract domains (view/contract/NetworkDomain.qml, BluetoothDomain.qml) with invented
values and draws the section inside a stand-in for FART's settings pane, as Claude B's tabs will show it. Nothing
is actuated: the domains are the contract's own placeholders, whose methods only record. Names are made up.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from shots import preset_colors  # noqa: E402
from smoke import ROOT, prepare, run_view  # noqa: E402

NEARBY = [
    {"id": "Lantern 5G", "ssid": "Lantern 5G", "strength": 0.92, "secured": True, "known": True, "connected": True,
     "enterprise": False, "hidden": False, "autoconnect": True, "band": "5"},
    {"id": "Lantern 2.4", "ssid": "Lantern 2.4", "strength": 0.81, "secured": True, "known": True, "connected": False,
     "enterprise": False, "hidden": False, "autoconnect": False, "band": "2.4"},
    {"id": "Copper Kettle", "ssid": "Copper Kettle", "strength": 0.64, "secured": True, "known": False, "connected": False,
     "enterprise": False, "hidden": False, "autoconnect": False, "band": "5"},
    {"id": "Northside Guest", "ssid": "Northside Guest", "strength": 0.48, "secured": False, "known": False,
     "connected": False, "enterprise": False, "hidden": False, "autoconnect": False, "band": "2.4"},
    {"id": "Workplace Secure", "ssid": "Workplace Secure", "strength": 0.37, "secured": True, "known": False,
     "connected": False, "enterprise": True, "hidden": False, "autoconnect": False, "band": "5"},
    {"id": "Neighbour 7B", "ssid": "Neighbour 7B", "strength": 0.18, "secured": True, "known": False, "connected": False,
     "enterprise": False, "hidden": False, "autoconnect": False, "band": "2.4"},
]
SAVED = [
    {"id": "Lantern 5G", "ssid": "Lantern 5G", "autoconnect": True, "inRange": True, "enterprise": False, "connected": True},
    {"id": "Lantern 2.4", "ssid": "Lantern 2.4", "autoconnect": False, "inRange": True, "enterprise": False, "connected": False},
    {"id": "Grandma's", "ssid": "Grandma's", "autoconnect": True, "inRange": False, "enterprise": False, "connected": False},
]
VPNS = [{"id": "vpn-1", "name": "Home tunnel", "state": "on"}, {"id": "vpn-2", "name": "Travel", "state": "off"}]
NET = {"available": True, "wifiEnabled": True, "kind": "wifi", "connected": True, "name": "Lantern 5G",
       "ipAddress": "192.0.2.24", "networks": NEARBY, "saved": SAVED, "connecting": "",
       "wired": {"connected": False, "name": ""}, "vpns": VPNS, "preference": "auto",
       "attempt": None, "vpnAttempt": None, "prompt": None}

DEVICES = [
    {"id": "d1", "name": "Studio Headphones", "kind": "headphones", "connected": True, "paired": True, "trusted": True,
     "blocked": False, "audio": True, "battery": 0.8},
    {"id": "d2", "name": "Travel Mouse", "kind": "mouse", "connected": True, "paired": True, "trusted": True,
     "blocked": False, "audio": False, "battery": 0.35},
    {"id": "d3", "name": "Kitchen Speaker", "kind": "speaker", "connected": False, "paired": True, "trusted": False,
     "blocked": False, "audio": True, "battery": -1},
    {"id": "d4", "name": "Low-Profile Keyboard", "kind": "keyboard", "connected": False, "paired": True, "trusted": True,
     "blocked": False, "audio": False, "battery": -1},
]
FOUND = [
    {"id": "n1", "name": "Pocket Speaker", "kind": "speaker", "connected": False, "paired": False, "trusted": False,
     "blocked": False, "audio": True, "battery": -1, "strength": 0.7},
    {"id": "n2", "name": "Phone", "kind": "smartphone", "connected": False, "paired": False, "trusted": False,
     "blocked": False, "audio": False, "battery": -1, "strength": 0.55},
    {"id": "n3", "name": "Game Controller", "kind": "sports_esports", "connected": False, "paired": False,
     "trusted": False, "blocked": False, "audio": False, "battery": -1, "strength": 0.3},
]
BT = {"available": True, "enabled": True, "discovering": True, "devices": DEVICES, "primary": DEVICES[0],
      "nearby": FOUND, "attempts": {}, "pairing": None}


def wifi(**changes):
    return {"kind": "wifi", "net": dict(NET, **changes.pop("net", {})), "view": changes.pop("view", {})}


def bt(**changes):
    return {"kind": "bt", "bt": dict(BT, **changes.pop("bt", {})), "view": dict({"scanning": True}, **changes.pop("view", {}))}


SCENES = {
    "wifi": wifi(),
    "wifi-join": wifi(view={"prefill": "Copper Kettle"}),
    "wifi-joining": wifi(net={"kind": "none", "connected": False, "name": "", "ipAddress": "", "connecting": "Copper Kettle",
                              "networks": [dict(n, connected=False) for n in NEARBY],
                              "attempt": {"target": "Copper Kettle", "action": "join", "phase": "working", "reason": ""}}),
    "wifi-wrong": wifi(net={"attempt": {"target": "Copper Kettle", "action": "join", "phase": "wrong-secret", "reason": "bad-credentials"},
                            "prompt": {"id": "net-1", "ssid": "Copper Kettle", "name": "Copper Kettle", "reason": "wrong-password", "kind": "psk"}}),
    "wifi-timeout": wifi(net={"attempt": {"target": "Copper Kettle", "action": "join", "phase": "timeout", "reason": ""}}),
    "wifi-enterprise": wifi(net={"attempt": {"target": "Workplace Secure", "action": "connect", "phase": "failed", "reason": "enterprise"}}),
    "wifi-hidden": wifi(view={"hiddenForm": True}),
    "wifi-off": wifi(net={"wifiEnabled": False, "kind": "ethernet", "name": "eno1", "networks": [], "wired": {"connected": True, "name": "eno1"}}),
    "bt": bt(),
    "bt-confirm": bt(bt={"pairing": {"id": "bt-1", "kind": "confirm", "deviceName": "Phone", "device": "n2", "passkey": "042137"},
                         "attempts": {"n2": {"target": "n2", "action": "pair", "phase": "working", "reason": ""}}}),
    "bt-pin": bt(bt={"pairing": {"id": "bt-2", "kind": "pin", "deviceName": "Game Controller", "device": "n3", "passkey": ""},
                     "attempts": {"n3": {"target": "n3", "action": "pair", "phase": "working", "reason": ""}}}),
    "bt-failed": bt(bt={"attempts": {"d3": {"target": "d3", "action": "connect", "phase": "timeout", "reason": ""}}}),
    "bt-off": bt(bt={"enabled": False, "discovering": False, "primary": None,
                     "devices": [dict(d, connected=False) for d in DEVICES], "nearby": []}, view={"scanning": False}),
}

HARNESS = '''import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.contract
import qs.view.shell
import qs.view.ui as Fart
Scope {
    id: root
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    property var scenes: %(scenes)s
    property var names: Object.keys(scenes)
    property string out: %(out)s
    property int cursor: -1
    property var scene: ({ kind: "wifi", view: {} })
    NetworkDomain { id: net }
    BluetoothDomain { id: bt }
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
    }
    FloatingWindow {
        implicitWidth: %(width)d; implicitHeight: %(height)d; visible: true
        color: "#40464d"
        Item {
            id: frame
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Fart.Design.surface; border.width: 1; border.color: Fart.Design.line }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Fart.Design.baseline * 4
                spacing: Fart.Design.baseline * 3
                // A stand-in for the settings pane's header and Claude B's tabs.
                RowLayout {
                    Fart.FText { text: "INSTRUMENT SETTINGS"; technical: true; color: Fart.Design.accent }
                    Item { Layout.preferredWidth: Fart.Design.baseline * 4 }
                    Repeater {
                        model: [["palette", "PALETTE"], ["wallpaper", "WALLPAPER"], ["presets", "PRESETS"], ["wifi", "WI-FI"], ["bt", "BLUETOOTH"]]
                        Fart.FButton { required property var modelData; label: modelData[1]; selected: root.scene.kind === modelData[0]; implicitHeight: Fart.Design.minHit }
                    }
                    Item { Layout.fillWidth: true }
                    Fart.FButton { symbol: "close"; implicitHeight: Fart.Design.minHit }
                }
                Loader {
                    id: section
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: root.scene.kind === "wifi" ? wifiSection : btSection
                }
            }
        }
    }
    Component { id: wifiSection; WifiSettings { network: net; active: true } }
    Component { id: btSection; BluetoothSettings { bluetooth: bt; active: true } }
    Timer {
        id: tick
        interval: 700; running: true; repeat: false
        onTriggered: {
            if (cursor >= 0) {
                const name = names[cursor];
                frame.grabToImage(result => {
                    console.log("FART_SHOT", name, result.saveToFile(out + "/" + name + ".png"));
                    next();
                });
                return;
            }
            next();
        }
    }
    function apply(target, values) { for (const key in values) target[key] = values[key]; }
    function next() {
        cursor++;
        if (cursor >= names.length) { console.log("FART_SHOTS_DONE"); Qt.quit(); return; }
        const s = scenes[names[cursor]];
        if (s.net) apply(net, s.net);
        if (s.bt) apply(bt, s.bt);
        section.sourceComponent = null;
        root.scene = s;
        section.sourceComponent = s.kind === "wifi" ? wifiSection : btSection;
        apply(section.item, s.view);
        tick.restart();
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("out", type=Path)
    parser.add_argument("--preset", default="Mocha")
    parser.add_argument("--scenes", default=",".join(SCENES))
    parser.add_argument("--size", default="1080x620", help="Claude B's roomy settings pane")
    parser.add_argument("--log", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    scenes = {name: SCENES[name] for name in args.scenes.split(",") if name}
    width, height = (int(n) for n in args.size.lower().split("x"))
    with tempfile.TemporaryDirectory(prefix="fart-netbt-") as tmp:
        text = HARNESS % {"scenes": json.dumps(scenes), "out": json.dumps(str(out)),
                          "colors": json.dumps(preset_colors(args.preset)), "width": width, "height": height}
        env, _state, view_log = prepare(Path(tmp), text)
        core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(Path(env["FART_RUNTIME_DIR"]) / "core.sock")
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ""
    saved = [line.split()[-2] for line in output.splitlines() if "FART_SHOT " in line and line.endswith("true")]
    problems = [line for line in output.splitlines() if any(s in line for s in ("ReferenceError", "TypeError", "Cannot assign", "is not a type", "Error:"))]
    for line in output.splitlines() if args.log else problems:
        print(line)
    print(f"{len(saved)}/{len(scenes)} scenes saved to {out}")
    return 0 if exited and len(saved) == len(scenes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
