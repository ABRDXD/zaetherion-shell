pragma Singleton
import QtQuick
import Quickshell
import qs.view.cues

// Generalized eigenproblem L u = lambda M u. No random modes, canned wave or per-item springs.
Singleton {
    id: root
    property rect desktop: Qt.rect(0,0,1920,1080)
    property point origin: Qt.point(0,0)
    property var elements: []
    property var graph: ({nodes:[], edges:[], modes:[]})
    property var selected: null
    property var eventModes: ({room:1,device:2,timer:3})
    readonly property real stiffness: graph.modes.length ? 12/Math.sqrt(Math.max(.001,graph.modes[graph.modes.length-1].value)) : 1
    property var scars: []
    property real phase: 1
    property bool still: false
    property int serial: 0
    property string cause: "room"
    signal struck
    readonly property bool moving: Motion.overdrive && !Motion.reduced && phase < 1 && selected !== null
    readonly property real seconds: phase * 2.8
    readonly property real amplitude: moving ? 28 * Math.exp(-1.65*seconds) * Math.sin(Math.sqrt(selected.value)*stiffness*seconds) * Math.min(1,(2.8-seconds)*5) : 0
    function displacement(index) { return moving && selected ? selected.vector[index]*amplitude : 0; }
    function offset(name) {
        for(let i=0;i<graph.nodes.length;i++) if(graph.nodes[i].name===name) return displacement(i);
        return 0;
    }
    function solve(nodes, edges) {
        const n=nodes.length, a=[], v=[];
        for(let i=0;i<n;i++) { a.push([]);v.push([]);for(let j=0;j<n;j++){a[i].push(0);v[i].push(i===j?1:0);} }
        for(let k=0;k<edges.length;k++) {
            const e=edges[k],i=e[0],j=e[1],w=e[2];
            a[i][i]+=w/nodes[i].mass;a[j][j]+=w/nodes[j].mass;
            a[i][j]-=w/Math.sqrt(nodes[i].mass*nodes[j].mass);a[j][i]=a[i][j];
        }
        // Symmetric Jacobi rotations; converge on off-diagonal norm, not an assumed basis.
        for(let sweep=0;sweep<80*n*n;sweep++) {
            let p=0,q=1,largest=0;
            for(let i=0;i<n;i++) for(let j=i+1;j<n;j++) if(Math.abs(a[i][j])>largest){largest=Math.abs(a[i][j]);p=i;q=j;}
            if(largest<1e-11) break;
            const theta=.5*Math.atan2(2*a[p][q],a[q][q]-a[p][p]),c=Math.cos(theta),s=Math.sin(theta);
            const pp=a[p][p],qq=a[q][q],pq=a[p][q];
            for(let k=0;k<n;k++) if(k!==p && k!==q) {
                const kp=a[k][p],kq=a[k][q];
                a[k][p]=a[p][k]=c*kp-s*kq;a[k][q]=a[q][k]=s*kp+c*kq;
            }
            a[p][p]=c*c*pp-2*s*c*pq+s*s*qq;a[q][q]=s*s*pp+2*s*c*pq+c*c*qq;a[p][q]=a[q][p]=0;
            for(let k=0;k<n;k++){const vp=v[k][p],vq=v[k][q];v[k][p]=c*vp-s*vq;v[k][q]=s*vp+c*vq;}
        }
        const modes=[];
        for(let j=0;j<n;j++) {
            const u=[];let peak=0,sign=1;
            for(let i=0;i<n;i++){u.push(v[i][j]/Math.sqrt(nodes[i].mass));if(Math.abs(u[i])>peak){peak=Math.abs(u[i]);sign=u[i]<0?-1:1;}}
            for(let i=0;i<n;i++)u[i]=u[i]*sign/Math.max(peak,1e-12);
            modes.push({value:Math.max(0,a[j][j]),vector:u});
        }
        modes.sort((a,b)=>a.value-b.value);
        return {nodes:nodes,edges:edges,modes:modes};
    }
    function rebuild() {
        if(elements.length<3)return;
        const w=desktop.width,h=desktop.height;
        const nodes=[{name:"NW",x:0,y:0,mass:1},{name:"NE",x:w,y:0,mass:1},
                     {name:"SE",x:w,y:h,mass:1},{name:"SW",x:0,y:h,mass:1}];
        for(let i=0;i<elements.length;i++) {
            const e=elements[i];nodes.push({name:e.name,x:origin.x+e.x+e.width/2,y:origin.y+e.y+e.height/2,
                mass:Math.max(.2,Math.sqrt(e.width*e.height)/250)});
        }
        const edges=[];
        function join(i,j) {
            const dx=nodes[i].x-nodes[j].x,dy=nodes[i].y-nodes[j].y;
            edges.push([i,j,500/Math.max(60,Math.sqrt(dx*dx+dy*dy))]);
        }
        join(0,1);join(1,2);join(2,3);join(3,0);
        for(let i=4;i<nodes.length;i++) {
            if(i>4)join(i-1,i);
            join(i,0);join(i,2);
            // All panel masses attach to the wallpaper's two diagonals, one physical structure.
            join(i,1);join(i,3);
        }
        phase=1; selected=null; scars=[]; graph=solve(nodes,edges);
        // Assign distinct modes by participation of the actually struck structural mass.
        // Lowest modes can have a node at the entire centred panel; choosing by ordinal would miss it.
        const used=[],kinds=["room","device","timer"],targets=[5,4,6],map={};
        for(let k=0;k<kinds.length;k++) {
            let best=1,score=-1;
            for(let m=1;m<graph.modes.length;m++) {
                if(used.indexOf(m)>=0)continue;
                const u=graph.modes[m].vector;let norm=0;
                for(let i=0;i<nodes.length;i++)norm+=nodes[i].mass*u[i]*u[i];
                const participation=nodes[targets[k]].mass*u[targets[k]]*u[targets[k]]/norm;
                if(participation>score){score=participation;best=m;}
            }
            map[kinds[k]]=best;used.push(best);
        }
        eventModes=map;
    }
    function strike(kind) {
        if(!Motion.overdrive || graph.modes.length<4)return;
        const index=eventModes[kind] || 1;
        selected=graph.modes[index];cause=kind;serial++;
        scars=scars.concat([{vector:selected.vector.slice(),value:selected.value,cause:kind}]).slice(-4);
        if(Motion.reduced){phase=1;still=true;stillLife.restart();}else{still=false;struck();}
    }
    onElementsChanged: rebuild()
    onDesktopChanged: rebuild()
    onOriginChanged: rebuild()
    Timer { id: stillLife; interval:300; onTriggered:root.still=false }
    Connections {
        target:Motion
        function onOverdriveChanged(){if(!Motion.overdrive){root.phase=1;root.still=false;root.scars=[];root.selected=null;}}
        function onReducedChanged(){root.phase=1;root.still=false;}
    }
}
