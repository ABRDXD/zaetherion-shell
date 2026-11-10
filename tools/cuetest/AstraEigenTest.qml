import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.overdrive
import qs.view.strata
import qs.view.cues
import qs.view.ui
Scope {
    id:test
    CoreClient { id:core; path:"" }
    FixtureAdapter { id:host }
    ShellContext { id:context; core:core; panelOpen:true }
    FloatingWindow {
        implicitWidth:1280;implicitHeight:900;visible:true;color:Design.background
        Item {
            id:stage;anchors.fill:parent
            Rectangle { anchors.fill:parent;color:Design.background }
            EigenDiagram { anchors.fill:parent;desktopTier:true }
            Rectangle { x:160;y:120;width:960;height:620;color:Qt.alpha(Design.background,.94) }
            Shell { id:shell; x:160;y:120;width:960;height:620;host:host;shell:context;core:core }
        }
    }
    Component.onCompleted: {
        Design.source=host.palette;
        Motion.overdrive=true;Motion.reduced=false;Motion.seen=true;
        Eigenmode.desktop=Qt.rect(0,0,1280,900);Eigenmode.origin=Qt.point(160,120);
    }
    function check(name,ok) {console.log(ok?"CUE_PASS":"CUE_FAIL",name);}
    function residual() {
        const g=Eigenmode.graph;
        let error=0;
        for(let m=0;m<g.modes.length;m++) {
            const mode=g.modes[m],u=mode.vector;
            for(let i=0;i<g.nodes.length;i++) {
                let lu=0;
                for(let k=0;k<g.edges.length;k++) {const e=g.edges[k];if(e[0]===i)lu+=e[2]*(u[i]-u[e[1]]);if(e[1]===i)lu+=e[2]*(u[i]-u[e[0]]);}
                error=Math.max(error,Math.abs(lu-mode.value*g.nodes[i].mass*u[i]));
            }
        }
        return error;
    }
    property real reducedAt: 0
    property real stillDuration: 0
    Connections {
        target:Eigenmode
        function onStillChanged() { if(!Eigenmode.still && test.reducedAt>0) test.stillDuration=Date.now()-test.reducedAt; }
    }
    property int step:0
    property var first: null
    Timer {
        interval:500;running:true;repeat:true
        onTriggered: {
            if(test.step===0) {
                test.check("laplacian.residual",test.residual()<1e-7);
                test.check("laplacian.zero",Eigenmode.graph.modes[0].value<1e-8);
                let orthogonal=true;
                const g=Eigenmode.graph;
                for(let a=0;a<g.modes.length;a++)for(let b=a+1;b<g.modes.length;b++) {
                    let dot=0;for(let i=0;i<g.nodes.length;i++)dot+=g.nodes[i].mass*g.modes[a].vector[i]*g.modes[b].vector[i];
                    if(Math.abs(dot)>1e-7)orthogonal=false;
                }
                test.check("modes.orthogonal",orthogonal);
                const changed=[];for(let i=0;i<g.nodes.length;i++)changed.push({name:g.nodes[i].name,x:g.nodes[i].x,y:g.nodes[i].y,mass:g.nodes[i].mass*(i===4?2:1)});
                const altered=Eigenmode.solve(changed,g.edges);let difference=0;
                for(let i=1;i<g.modes.length;i++)difference+=Math.abs(altered.modes[i].value-g.modes[i].value);
                test.check("geometry.mass.matters",difference>1e-6);
                shell.navigate("timers");test.first=Eigenmode.selected;
                test.check("real.room.path",Eigenmode.cause==="room" && Eigenmode.selected!==null);
            }
            if(test.step===1) {
                test.check("antinode.moves",Math.abs(Eigenmode.offset("room"))>0.01);
                shell.commandLine.focusInput();
                test.check("controls.focus.during.motion",shell.commandLine.inputFocused && shell.commandLine.enabled);
                stage.grabToImage(r=>r.saveToFile("/tmp/astra-eigen.png"));
            }
            if(test.step===2) {
                core.receive(JSON.stringify({event:"sfx.cue",data:{cue:"timer.done"}}));
                test.check("real.timer.path",Eigenmode.cause==="timer" && Eigenmode.selected!==test.first);
                host.bluetooth.devices=[];
            }
            if(test.step===3) {
                host.bluetooth.devices=[{id:"fixture-device",connected:true}];
                test.check("real.device.path",Eigenmode.cause==="device");
                stage.grabToImage(r=>r.saveToFile("/tmp/astra-eigen-device.png"));
            }
            if(test.step===4) {
                // A nodal crossing is unchanged under every amplitude, including the antinode peak.
                const g=Eigenmode.graph,u=Eigenmode.selected.vector;
                let zeros=0,err=0;
                for(let k=0;k<g.edges.length;k++){const e=g.edges[k],a=u[e[0]],b=u[e[1]];if(a*b<0){const f=a/(a-b);err=Math.max(err,Math.abs((1-f)*a+f*b));zeros++;}}
                test.check("nodes.fixed",zeros>0 && err<1e-12);
                Motion.reduced=true;test.reducedAt=Date.now();Eigenmode.strike("timer");
                test.check("reduced.still",Eigenmode.still && Eigenmode.amplitude===0);
            }
            if(test.step===5) {
                test.check("reduced.300ms",!Eigenmode.still && test.stillDuration>=250 && test.stillDuration<400);
                Motion.reduced=false;Eigenmode.strike("room");Motion.overdrive=false;
                test.check("release.rest",Eigenmode.amplitude===0 && Eigenmode.scars.length===0);
            }
            if(test.step===6) {test.check("release.destroyed",Strata.live.indexOf("panel:eigenmode")<0);console.log("CUE_DONE");Qt.quit();}
            test.step++;
        }
    }
}
