import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.view.rooms
import qs.view.ui as UI
import qs.view.cues

// Devices' signal map (Z212), offscreen on the fixture: the rings carry the levels, a star per other network (the
// joined one is the satellite), a star's click asks to join it, a stronger signal sits nearer, an unknown strength
// shows no number; Silent is still and Overdrive pings.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function all(item, test, found) {
        found = found ?? [];
        if (!item) return found;
        if (test(item)) found.push(item);
        for (const c of item.children ?? []) all(c, test, found);
        return found;
    }
    property var joined: []
    FixtureAdapter { id: fixture }
    FloatingWindow {
        implicitWidth: 700; implicitHeight: 480; visible: true; color: "#000000"
        DevicesSky {
            id: sky; anchors.fill: parent
            network: fixture.network; bluetooth: fixture.bluetooth; audio: fixture.audio; power: fixture.power
            onJoin: id => root.joined = root.joined.concat([id])
        }
    }
    function net(id, strength, connected, known) { return { id: id, ssid: id, strength: strength, secured: true, known: known, connected: connected }; }
    property int step: 0
    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: {
            const s = root.step++;
            if (s === 0) {
                UI.Design.source = fixture.palette;
                Motion.reduced = false; Motion.overdrive = false; Motion.seen = true;
                fixture.network.wifiEnabled = true; fixture.network.connected = true; fixture.network.kind = "wifi"; fixture.network.name = "HOME";
                fixture.network.networks = [net("HOME", 0.9, true, true), net("CAFE", 60, false, true), net("FAR", 0.2, false, false)];
            } else if (s === 1) {
                root.check("levels.ringed", sky.levels.length === 3 && sky.levels[0].label === "OUTPUT", sky.levels.map(l => l.label));
                const stars = root.all(sky, i => i.modelData?.ssid !== undefined && i.clicked !== undefined);
                root.check("star.each.other", stars.length === 2 && !stars.some(x => x.modelData.ssid === "HOME"), stars.map(x => x.modelData.ssid));
                stars.find(x => x.modelData.ssid === "CAFE").clicked();
                root.check("star.joins", JSON.stringify(root.joined) === JSON.stringify(["CAFE"]), root.joined);
                const near = sky.linkStrength;
                root.check("strength.read", near === 0.9, near);
                root.check("silent.still", Motion.idleLoops === 0, Motion.idleLoops);
                fixture.network.networks = [];
            } else if (s === 2) {
                root.check("strength.unknown", sky.linkStrength === null && root.all(sky, i => i.text !== undefined && /^HOME/.test(i.text)).some(t => t.text === "HOME"));
                Motion.overdrive = true;
            } else if (s === 4) {
                root.check("overdrive.pings", Motion.idleLoops > 0, Motion.idleLoops);
                Motion.overdrive = false;
            } else if (s === 8) {
                root.check("release.still", Motion.idleLoops === 0, Motion.idleLoops);
                console.log("CUE_DONE"); Qt.quit();
            }
        }
    }
}
