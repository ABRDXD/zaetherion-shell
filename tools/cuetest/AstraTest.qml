import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.ui as UI
import qs.view.cues
import qs.view.strata
import "tools/cuetest/AstraFixture.js" as Data

Scope {
    id: test
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: host }
    GenealogyFeed { id: feedProbe; parent: stage; path: "" }
    ShellContext { id: shell; core: core; panelOpen: true }
    FloatingWindow {
        implicitWidth: 1100; implicitHeight: 680; visible: true
        color: UI.Design.background
        Item {
            id: stage; anchors.fill: parent
            Rectangle { anchors.fill: parent; color: UI.Design.background }
            Workspaces { id: room; anchors.fill: parent; anchors.margins: 30; host: host; shell: shell; historyOverride: Data.genealogy() }
        }
    }
    Component.onCompleted: {
        UI.Design.source = host.palette;
        host.workspaces.windows = Data.windows();
        Motion.reduced = false; Motion.overdrive = false; Motion.seen = true;
    }
    function check(name, ok) { console.log(ok ? "CUE_PASS" : "CUE_FAIL", name); }
    property int step: 0
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            if (test.step === 0) {
                test.check("genealogy.silent", Motion.idleLoops === 0 && Strata.live.length === 0);
                feedProbe.accept({available:false,revision:0});
                feedProbe.accept({available:true,revision:1});
                feedProbe.accept({available:true,revision:2});
                test.check("genealogy.snapshot.freeze",feedProbe.snapshot.revision===1);
                feedProbe.visible=false; feedProbe.visible=true;
                test.check("genealogy.reopen",feedProbe.snapshot.revision===2);
                stage.grabToImage(r => r.saveToFile("/tmp/astra-genealogy-silent.png"));
                Motion.overdrive = true;
            } else if (test.step === 2) {
                test.check("genealogy.live", Motion.idleLoops > 0);
                stage.grabToImage(r => r.saveToFile("/tmp/astra-genealogy-live.png"));
                room.looking = 3;
            } else if (test.step === 3) {
                stage.grabToImage(r => r.saveToFile("/tmp/astra-genealogy-memory.png"));
                Motion.overdrive = false;
            } else if (test.step === 6) {
                test.check("genealogy.release", Strata.live.length === 0 && Motion.idleLoops === 0);
                Motion.reduced = true; Motion.overdrive = true;
            } else if (test.step === 7) {
                test.check("genealogy.reduced", Strata.live.length === 0 && Motion.idleLoops === 0);
                console.log("CUE_DONE"); Qt.quit();
            }
            test.step++;
        }
    }
}
