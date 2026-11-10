import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.ui as UI
import qs.view.cues
import qs.view.strata

Scope {
    id: test
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: host }
    ShellContext { id: shell; core: core; panelOpen: true }
    function snapshot(running, left, done) {
        return {at:Date.now(),config:{pomodoro:{focus:1500,break:300,cycles:4}},
            pomodoro:{running:running,phase:"focus",cycle:0,elapsed:1500-left-22,duration:1500,lengths:{focus:1500,break:300},done:null},
            countdown:{running:running,elapsed:900-left,duration:900,done:done ? {at:Date.now()} : null},
            stopwatch:{running:running,elapsed:192,laps:[42,105,168]}};
    }
    FloatingWindow {
        implicitWidth: Number(Quickshell.env("ASTRA_WIDTH")) || 1100; implicitHeight: Number(Quickshell.env("ASTRA_HEIGHT")) || 680; visible: true
        color: UI.Design.background
        Item {
            id: stage; anchors.fill: parent
            Rectangle { anchors.fill: parent; color: UI.Design.background }
            Timers { id: room; anchors.fill: parent; anchors.margins: 30; host: host; shell: shell; core: core }
            // GPU drawing is separately checked with --window. This software probe exercises the
            // actual field's lifecycle and cue properties, without overriding the room's GPU gate.
            Stratum {
                id: probe; name: "temporal-test-probe"; gpu: false; scope: stage
                width: 2; height: 2
                sourceComponent: Component { TemporalField { sources: room.sources; eventKey: room.eventKey; completionKey: room.completionKey; flowing: core.timers.anyRunning } }
            }
        }
    }
    Component.onCompleted: {
        UI.Design.source=host.palette; ViewState.timerKind="countdown";
        core.connected=true; core.timersData=snapshot(false,307,false);
        Motion.reduced=false; Motion.overdrive=false; Motion.seen=true;
    }
    function findNamed(item,name) {
        if (item.objectName===name) return item;
        for (const child of item.children) { const found=findNamed(child,name); if(found) return found; }
        return null;
    }
    function check(name,ok) {console.log(ok ? "CUE_PASS" : "CUE_FAIL",name);}
    property int step: 0
    property int paints: 0
    property real oldDrive: 0
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            if(test.step===0) {
                stage.grabToImage(r=>r.saveToFile("/tmp/astra-temporal-held.png"));
                test.paints=room.staticPaints;
            } else if(test.step===2) {
                test.check("temporal.silent.rest",room.staticPaints===test.paints && Motion.idleLoops===0);
                core.timersData=test.snapshot(true,307,false);
                test.paints=room.staticPaints;
            } else if(test.step===5) {
                test.check("temporal.second.clock",core.timers.tickInterval===1000 && room.staticPaints-test.paints<=5);
                stage.grabToImage(r=>r.saveToFile("/tmp/astra-temporal-running.png"));
                Motion.overdrive=true;
            } else if(test.step===7) {
                test.check("temporal.live",probe.item!==null && Motion.idleLoops>0);
                core.timersData=test.snapshot(true,9,false);
            } else if(test.step===8) {
                stage.grabToImage(r=>{ r.saveToFile("/tmp/astra-temporal-urgent.png"); core.timersData=test.snapshot(false,0,true); test.check("temporal.done.logical",core.timers.countdownDone); });
            } else if(test.step===10) {
                test.check("temporal.done.finite",probe.item && probe.item.completion===0 && Motion.idleLoops===0);
                stage.grabToImage(r=>r.saveToFile("/tmp/astra-temporal-done.png"));
                Motion.overdrive=false;
            } else if(test.step===13) {
                test.check("temporal.release",Strata.live.length===0 && Motion.idleLoops===0);
                Motion.reduced=true; Motion.overdrive=true;
            } else if(test.step===14) {
                test.check("temporal.reduced",Strata.live.length===0 && Motion.idleLoops===0);
                const longTimer=test.snapshot(false,31536000,false);
                longTimer.countdown.duration=31536000; longTimer.countdown.elapsed=0;
                core.timersData=longTimer;
            } else if(test.step===15) {
                const clock=test.findNamed(room,"temporal-clock");
                test.check("temporal.long.readout",clock && clock.contentWidth<=clock.width+1 && !clock.truncated);
                console.log("CUE_DONE");Qt.quit();
            }
            test.step++;
        }
    }
}
