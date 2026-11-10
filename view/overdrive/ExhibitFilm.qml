import QtQuick
import qs.view.ui
import qs.view.cues

// A printing plate under impossible pressure. Every mark is reconstructed from score + time.
Item {
    id: root
    property var score: null
    property real time: 0
    property bool playing: false
    property int lastCut: -1
    property bool cutGranted: true
    signal finished
    readonly property real duration: score ? score.duration : 24
    function seek(t) { if (!playing) cutGranted = true; time = Math.max(0, Math.min(duration, t)); }
    function start() { playing = true; clock.replay(); }
    Cue {
        id: clock
        scope: root
        name: "exhibit"
        on: root.playing
        enter: root.duration * 1000
        easing: Easing.Linear
        onValueChanged: if (root.playing) root.seek(value * root.duration)
        onSettled: if (root.playing && value === 1) root.finished()
    }
    onTimeChanged: {
        if (playing && score) {
            let cut = -1;
            for (let i=0;i<score.cuts.length;i++) if (time>=score.cuts[i]) cut=i;
            if(cut!==lastCut) { lastCut=cut; cutGranted=FlashGate.request("exhibit.cut"); }
        }
        plate.requestPaint();
    }
    onScoreChanged: plate.requestPaint()
    // The final die retracts in strips; the live surface is the image revealed.
    opacity: 1
    Canvas {
        id: plate
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c=getContext("2d"), w=width, h=height, s=root.score;
            c.reset(); c.clearRect(0,0,w,h);
            if(!s) return;
            const t=root.time, end=Math.max(0,(t-(s.duration-2))/2);
            let section=s.sections[0], si=0;
            for(let i=0;i<s.sections.length;i++) if(t>=s.sections[i].at) {section=s.sections[i];si=i;}
            const ink=Design.ink.toString(), paper=Design.background.toString();
            const warm=Design.warm.toString(), faint=Design.line.toString();
            c.fillStyle=paper;c.fillRect(0,0,w,h);
            // A margin is a scar ledger, not a container. Earlier plates stay in space.
            for(let j=0;j<=si;j++) {
                c.fillStyle=j===si?warm:faint;
                c.fillRect(18+j*13,0,2,h*(.25+j*.11));
                c.save();c.translate(24+j*13,h-24);c.rotate(-Math.PI/2);
                c.font=Design.caption+"px "+Design.mono;c.fillText("IMPRESSION / "+String(j+1).padStart(2,'0'),0,0);c.restore();
            }
            c.save();
            c.translate(w*.57,h*.48);
            c.transform(1,-.2126,0,1,0,0);
            const intro=Math.min(1,t/3);
            const next=s.sections[Math.min(si+1,s.sections.length-1)];
            const span=(si+1<s.sections.length?s.sections[si+1].at:s.duration-2)-section.at;
            const progress=Math.max(0,Math.min(1,(t-section.at)/Math.max(1,span)));
            const travel=progress*progress*(3-2*progress);
            const zoom=section.camera[0]*(1-travel)+next.camera[0]*travel;
            const pressure=section.pressure*(1-travel)+next.pressure*travel;
            c.scale(.7+zoom*.17,.7+zoom*.17);
            // Not a picture of a graph: graph weight physically buckles the printing surface.
            for(let layer=0;layer<72;layer++) {
                const z=layer/71;
                c.beginPath();
                for(let i=0;i<s.ribs.length;i++) {
                    const r=s.ribs[i];
                    const x=(r.x-.5)*w*(1.4+z*.9)*(1-end*.65);
                    const wave=Math.sin(i*.67+t*.65-z*4)*r.mass;
                    const y=(z-.5)*h*.95 + wave*(14+pressure*4)*intro + Math.cos(z*5+t*.4)*h*.12;
                    if(i===0)c.moveTo(x,y);else c.lineTo(x,y);
                }
                c.strokeStyle=layer%9===0?warm:(layer%3===0?ink:faint);
                c.globalAlpha=layer%9===0?.9:.25+.4*z;c.lineWidth=layer%9===0?2.5:.65;c.stroke();
            }
            c.globalAlpha=1;
            // Edges are incisions. Their weights determine the cut width.
            for(let i=0;i<s.state.edges.length;i++) {
                const e=s.state.edges[i], a=s.ribs[e[0]], b=s.ribs[e[1]];
                c.beginPath();c.moveTo((a.x-.5)*w*1.6,-h*.4);
                c.lineTo((b.x-.5)*w*1.6,h*.45);
                c.strokeStyle=paper;c.lineWidth=4+Math.log(1+e[2])*7;c.stroke();
                c.strokeStyle=warm;c.lineWidth=1;c.stroke();
            }
            c.restore();
            // Type is larger than its viewport: the machine stamps right through the edge.
            c.save();c.translate(w*.16,h*.79);c.transform(1,-.2126,0,1,0,0);
            c.font="900 "+Math.round(h*.70)+"px "+Design.sans;
            c.lineWidth=1;c.strokeStyle=ink;c.fillStyle=ink;
            const words=["FOLD","PRESS","HERE"];
            const word=words[section.type];
            c.globalAlpha=Math.min(1,(t-section.at)*2,Math.max(0,(span-(t-section.at))*2));
            if(si%2===0) c.strokeText(word,-t*5,0); else c.fillText(word,-w*.13,0);
            c.restore();
            // Old impressions tear loose: their number and offsets are the actual section history.
            for(let scar=0;scar<si;scar++) {
                const old=s.sections[scar];
                c.save();c.globalAlpha=Math.min(1,(t-s.sections[scar+1].at)*2);c.translate(w*(.09+scar*.17),h*(.22+scar*.12));
                c.transform(1,-.2126,0,1,0,0);
                c.beginPath();c.rect(-w*.3,-h*.16,w*1.4,25+old.pressure*5);c.clip();
                c.fillStyle=scar%2===0?warm:ink;c.fillRect(-w*.3,-h*.16,w*1.4,h*.5);
                c.fillStyle=paper;c.font="900 "+Math.round(h*.58)+"px "+Design.sans;
                c.fillText(words[old.type],-w*(.2+scar*.03),h*.18);
                c.restore();
            }
            // Process classes perforate the film. These persist across camera movements.
            const processes=s.state.processes.reduce((a,b)=>a+b,0);
            c.fillStyle=warm;
            const holes=Math.min(180,12+Math.floor(processes/3));
            for(let i=0;i<holes;i++) {
                const x=w*.12+(i%60)*w*.0145,y=h*.9+Math.floor(i/60)*8;
                c.fillRect(x,y,2+(s.seed+i)%4,3);
            }
            // Geometry produces the negative spaces of the final die.
            for(let i=0;i<s.state.geometry.length;i+=4) {
                const g=s.state.geometry, scale=.08+end*.8;
                c.strokeStyle=warm;c.lineWidth=2;
                c.strokeRect(w*.58+(i%3)*24,h*.14+(i%4)*19,Math.min(w*.35,g[i+2]*scale||60),Math.min(h*.35,g[i+3]*scale||40));
            }
            c.fillStyle=paper;c.fillRect(w*.12-8,12,340,46);
            c.font=Design.body+"px "+Design.mono;c.fillStyle=ink;
            c.fillText("THE EXHIBIT / THE FOLD",w*.12,30);
            c.fillText("A MACHINE IMPRESSES ITS OWN HISTORY",w*.12,49);
            c.fillStyle=warm;c.fillText(String(si+1).padStart(2,'0')+" / "+s.sections.length,w-110,30);
            c.fillStyle=ink;c.fillText(end>0?"YOU ARE ALREADY HERE":"COMPILED FROM THIS INSTANT",w*.12,h-25);
            c.fillText(t.toFixed(2)+" / "+s.duration.toFixed(2),w-150,h-25);
            if(end>0) {
                // Each rib opens its own aperture. No screenshot, no replacement panel.
                for(let i=0;i<s.ribs.length;i++) {
                    const gap=Math.min(1,end*(1.25+s.ribs[i].mass*.035));
                    c.clearRect(i*w/9,0,w/9,h*gap);
                    if(end>.92)c.clearRect(i*w/9,0,w/9,h);
                }
            }
            if(end===0 && root.cutGranted && si>0 && t-section.at<.14) {
                c.fillStyle=warm;c.fillRect(w*.11,65,w*.78,3);
            }
        }
    }
}
