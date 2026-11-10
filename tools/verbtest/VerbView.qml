import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.contract

// A view for tests/test_verbs_view.py: the fixture adapter behind a real CoreClient, so core host calls
// run the real CoreHostCalls. Every lease and call change of the acting domains is printed as one line.
Scope {
    id: root
    FixtureAdapter { id: fixture }
    // The fixture behind an adapter that defers audio as SerpantinumAdapter does (ADAPTER_CONTRACT §1)
    // and swaps it in a frame after loadDeferred(), so every audio call also tests CoreHostCalls
    // loading and following the swap.
    HostAdapter {
        id: host
        name: fixture.name
        media: fixture.media; network: fixture.network; bluetooth: fixture.bluetooth; notifications: fixture.notifications
        workspaces: fixture.workspaces; power: fixture.power; palette: fixture.palette; motion: fixture.motion
        hostActions: fixture.hostActions; sfx: fixture.sfx; clockGeometry: fixture.clockGeometry; lyrics: fixture.lyrics
        system: fixture.system; clipboard: fixture.clipboard
        function loadDeferred() {
            Qt.callLater(() => {
                if (host.audio === fixture.audio) return;
                host.audio = fixture.audio;
                console.log("VERB_DEFERRED audio");
            });
        }
    }
    CoreClient { id: core; host: host }
    readonly property var watched: ["audio", "power", "network", "bluetooth", "media", "hostActions"]
    function show(name) {
        const d = fixture[name];
        console.log("VERB_STATE", name, JSON.stringify({ leases: d.leases, calls: d.calls }));
    }
    Connections {
        target: core
        function onCue(data) { console.log("VERB_CUE", JSON.stringify(data)); }
        function onSfxDataChanged() { console.log("VERB_SFX", JSON.stringify(core.sfxData)); }
    }
    Instantiator {
        model: root.watched
        delegate: Connections {
            required property string modelData
            target: fixture[modelData]
            function onLeasesChanged() { root.show(modelData); }
            function onCallsChanged() { root.show(modelData); }
        }
    }
}
