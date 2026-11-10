import QtQuick
import qs.view.overdrive
import qs.view.ui

// Screen-space drawing is shared across both windows. No input handlers, layers or captured controls.
Canvas {
    id: root
    property point origin: Qt.point(0,0)
    property bool desktopTier: false
    property bool still: false
    property real tick: Eigenmode.phase
    property var graph: Eigenmode.graph
    property var mode: Eigenmode.selected
    property var history: Eigenmode.scars
    onTickChanged: requestPaint()
    onGraphChanged: requestPaint()
    onModeChanged: requestPaint()
    onHistoryChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c=getContext("2d");c.reset();c.setTransform(1,0,0,1,0,0);c.globalAlpha=1;c.clearRect(0,0,width,height);
        if(!mode)return;
        c.translate(-origin.x,-origin.y);
        const nodes=graph.nodes,edges=graph.edges,u=mode.vector;
        const warm=Design.warm.toString(),ink=Design.ink.toString(),line=Design.line.toString();
        const amp=still?0:Eigenmode.amplitude;
        // The shape is the eigenvector. A single scalar excitation moves every antinode in phase or antiphase.
        for(let k=0;k<edges.length;k++) {
            const e=edges[k],a=nodes[e[0]],b=nodes[e[1]],ua=u[e[0]],ub=u[e[1]];
            const ax=a.x+.2079*ua*amp,ay=a.y-.9781*ua*amp,bx=b.x+.2079*ub*amp,by=b.y-.9781*ub*amp;
            if(desktopTier) {
                // Engraved displacement envelope: every strand passes through the same exact zero.
                // It records the struck mode, not an independent animation or a decorative sine wave.
                for(let band=-18;band<=18;band++) {
                    const trace=band*1.55;
                    c.globalAlpha=.12;c.strokeStyle=ua*ub<0?warm:ink;c.lineWidth=.7;
                    c.beginPath();c.moveTo(a.x+.2079*ua*trace,a.y-.9781*ua*trace);
                    c.lineTo(b.x+.2079*ub*trace,b.y-.9781*ub*trace);c.stroke();
                }
            }
            c.strokeStyle=ua*ub<0?warm:line;c.lineWidth=desktopTier?2.4:.7;
            c.globalAlpha=desktopTier?.8:.26;c.beginPath();c.moveTo(ax,ay);c.lineTo(bx,by);c.stroke();
            if(ua*ub<0) {
                const f=ua/(ua-ub),x=a.x+(b.x-a.x)*f,y=a.y+(b.y-a.y)*f;
                // Exact zero of the piecewise-linear graph eigenfunction: no displacement, ever.
                c.globalAlpha=1;c.fillStyle=warm;c.fillRect(x-4,y-4,8,8);
                c.beginPath();c.moveTo(x-10,y+47);c.lineTo(x+10,y-47);c.stroke();
            }
        }
        for(let i=0;i<nodes.length;i++) {
            const p=nodes[i],d=u[i]*amp;
            c.globalAlpha=.8;c.strokeStyle=ink;c.beginPath();c.moveTo(p.x,p.y);c.lineTo(p.x+.2079*d,p.y-.9781*d);c.stroke();
        }
        if(desktopTier) {
            // Residual nodal cuts are a spatial record of the last four strikes.
            for(let j=0;j<history.length;j++) for(let k=0;k<edges.length;k++) {
                const e=edges[k],v=history[j].vector,a=nodes[e[0]],b=nodes[e[1]];
                if(v[e[0]]*v[e[1]]>=0)continue;
                const f=v[e[0]]/(v[e[0]]-v[e[1]]),x=a.x+(b.x-a.x)*f,y=a.y+(b.y-a.y)*f;
                c.globalAlpha=.15+j*.08;c.strokeStyle=warm;c.lineWidth=1;
                c.beginPath();c.moveTo(x-60,y+282);c.lineTo(x+60,y-282);c.stroke();
            }
            c.globalAlpha=.10;c.strokeStyle=ink;c.fillStyle=ink;c.lineWidth=1;
            c.font="900 "+Math.round(height*.8)+"px "+Design.sans;
            c.fillText("0"+Eigenmode.eventModes[Eigenmode.cause],width*.53,height*.98);
            c.globalAlpha=.8;c.fillStyle=warm;c.font=Design.body+"px monospace";
            c.fillText("STATIONARY / "+Eigenmode.cause.toUpperCase()+" / λ "+mode.value.toFixed(5),36,height-32);
        }
    }
}
