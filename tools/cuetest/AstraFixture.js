.pragma library
function genealogy() {
    const now = Date.now() / 1000;
    return {available: true, at: now, revision: 1, workspace: "1", active: "c", nodes: [
        {id: 1, address: "a", workspace: "1", app: "TERMINAL", opened: now-1500, closed: null, parent: null},
        {id: 2, address: "b", workspace: "1", app: "EDITOR", opened: now-1400, closed: null, parent: 1},
        {id: 3, address: "old", workspace: "1", app: "BUILD LOG", opened: now-1100, closed: now-800, parent: 2},
        {id: 4, address: "c", workspace: "1", app: "BROWSER", opened: now-900, closed: null, parent: 2},
        {id: 5, address: "d", workspace: "1", app: "REFERENCE", opened: now-600, closed: null, parent: 4}],
        focus: [0,12,45,410,420,430,440,450,460,1100,1450].map((v,i)=>({at:now-1500+v,address:["a","b","c"][i%3],workspace:"1"})),
        memories: {"3": {at:now-500,rects:[{rect:[0,0,960,1080]},{rect:[960,0,960,540]},{rect:[960,540,960,540]}]}}};
}
function windows() {
    return ["a","b","c","d"].map((a,i)=>({id:"0x"+a,appId:["terminal","editor","browser","reference"][i],title:["Session shell","Project / field study","Contour reference","Working notes"][i],workspaceId:"1",focused:i===2,x:i*240,y:0,width:480,height:1080}));
}
