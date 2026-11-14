import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.ui
import qs.view.cues

// Real Shell, synthetic data, private runtime. No host actions are actuated.
ShellRoot {
    id: root
    readonly property var output: Quickshell.screens.find(s => s.name === "ZTEST") ?? null
    readonly property var room: dashboard.shownSlot.item
    property int stage: 0
    property int cycles: 0
    property int skyCalls: 0
    property int minuteRefreshes: 0
    property int leaseChanges: 0
    property var original: null
    property var originalSky: null
    property int leaseSnapshot: 0
    property int skySnapshot: 0
    property string monthSnapshot: ""
    property string weekSnapshot: ""
    property string selectionSnapshot: ""
    property string foldSnapshot: ""
    property string editionSnapshot: ""
    property var saved: ({name:"dms:amoledBlack",effective:"dms:amoledBlack",preview:false,
        colors:{background:"#000000",surface:"#000000",text:"#eeeeee",accent:"#ffffff"},
        savedColors:{background:"#000000",surface:"#000000",text:"#eeeeee",accent:"#ffffff"}})
    property var calls: []
    property bool deferSky: false
    property var skyReplies: []
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) { const result=find(child,test); if (result) return result; }
        return null;
    }
    function control(name) { return find(dashboard, i => i.objectName === name); }
    function surveyor() { return find(dashboard, i => typeof i.rescan === "function" && typeof i.begin === "function"); }
    function choose(form) { control("style." + form).clicked(); }
    function check(ok, name) {
        console.log((ok ? "FLUID_PASS " : "FLUID_FAIL ") + name);
        if (!ok) Qt.quit();
    }
    function bounds(name) {
        const item=control(name), p=item.mapToItem(room,0,0);
        check(p.x>=-1 && p.y>=-1 && p.x+item.width<=room.width+1 && p.y+item.height<=room.height+1, name+" fits Home");
    }
    function iso(hour) { const d=new Date(); d.setHours(hour,0,0,0); return d.toISOString(); }
    FixtureAdapter { id: fixture }
    CoreClient {
        id: client
        path: ""
        connected: true
        islandData: ({form:"angular"})
        paletteData: root.saved
        tasksData: ({lists:[{id:"default",name:"Tasks"}],tasks:[
            {id:"one",text:"Review the interface study",done:false,due:Qt.formatDate(new Date(),"yyyy-MM-dd"),list:"default"},
            {id:"two",text:"Finish the prototype",done:false,due:null,list:"default"},
            {id:"three",text:"Collect the next set of ideas",done:false,due:null,list:"default"}]})
        timersData: ({at:Date.now(),config:{pomodoro:{focus:1500,break:300}},
            stopwatch:{running:false,elapsed:0,laps:[]},countdown:{running:false,elapsed:0,duration:0,done:false},
            pomodoro:{running:false,elapsed:0,duration:1500,phase:"focus",cycle:0,done:null}})
        function request(op,args,callback) {
            root.calls.push({op,args});
            if (op === "sky.now") {
                root.skyCalls++;
                if (root.deferSky) { root.skyReplies.push(callback); return; }
                callback(true,{at:new Date().toISOString(),sun:{rise:root.iso(6),set:root.iso(18)},bodies:{},moon:{illumination:0.4}});
                return;
            }
            if (op === "cmd.run") { islandData={form:args.line.split(" ")[1]}; if(callback)callback(true,{ok:true}); return; }
            if (op === "palette.list") {
                callback(true,[{id:"dms:amoledBlack",name:"Amoled Black",source:"DMS",accent:"#ffffff"},
                    {id:"amoled:ice",name:"Ice",source:"AMOLED studies",accent:"#8edfff"}]); return;
            }
            if (op === "palette.preview") paletteData=Object.assign({},root.saved,{preview:true,effective:"amoled:ice",colors:Object.assign({},root.saved.colors,{accent:"#8edfff"})});
            if (op === "palette.cancel") paletteData=root.saved;
            if (op === "task.update") tasksData=Object.assign({},tasksData,{tasks:tasksData.tasks.map(t=>t.id===args.id ? Object.assign({},t,{done:args.done}) : t)});
            if(callback)callback(true,{});
        }
    }
    Binding { target: Design; property: "form"; value: client.islandData.form }
    PaletteBinding { core: client }
    ShellContext { id: context; core:client; panelOpen:true }
    Connections { target:fixture.media; function onLeasesChanged() { root.leaseChanges++; } }
    Connections { target:Clock; function onMinuteStrChanged() { root.minuteRefreshes++; } }
    PanelWindow {
        screen:root.output
        visible:root.output!==null
        anchors {top:true;bottom:true;left:true;right:true}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
        color:"#0a0d0f"
        Rectangle {
            x:280;y:110;width:1360;height:860
            color:Design.background;radius:Design.fluid?26:0;border.color:Design.line
            Shell { id:dashboard;anchors.fill:parent;host:fixture;core:client;shell:context }
        }
    }
    IpcHandler {
        target:"fluid-fixture"
        function style(name:string):void { root.choose(name); }
        function settings(on:bool):void { dashboard.preferencesOpen=on; }
        function preview():void { root.find(dashboard,i=>typeof i.preview==="function").preview("amoled:ice"); }
        function overdrive(on:bool):void { Motion.reduced=false;Motion.overdrive=on;Motion.settleDrive(); }
        function playing(on:bool):void { fixture.media.active=Object.assign({},fixture.media.active,{playing:on}); }
        function month(delta:int):void { root.room.session.shiftMonth(delta); }
        function state():string { return JSON.stringify({form:Design.form,page:dashboard.currentPage,controller:String(root.room.session),
            room:{width:root.room.width,height:root.room.height},palette:client.paletteData,settings:dashboard.preferencesOpen,
            month:root.room.session.calendarMonth,skyCalls:root.skyCalls,leases:fixture.media.leases}); }
    }
    Component.onCompleted: { Motion.reduced=true;console.log("FLUID_READY"); }
    Timer {
        interval:180
        repeat:true
        running:Quickshell.env("FLUID_AUTOTEST")==="1"
        onTriggered: {
            if(!root.room?.presentation?.item || root.room.presentation.loading) return;
            switch(root.stage++) {
            case 0:
                root.original=root.room.session;root.originalSky=root.original.sky;
                root.skySnapshot=root.skyCalls;root.leaseSnapshot=root.leaseChanges;
                root.check(!!root.originalSky && fixture.media.leases.position.length===1,"Active Home has a sky snapshot and one position lease");
                const week = root.control("home.week");
                week.shiftWeek(2);week.selectedDate=new Date(week.week.getFullYear(),week.week.getMonth(),week.week.getDate()+2);
                root.weekSnapshot=week.week.toISOString();root.selectionSnapshot=week.selectedDate.toISOString();
                root.control("home.play").forceActiveFocus();root.choose("fluid");
                break;
            case 1:
                root.check(root.room.session===root.original && root.room.session.sky===root.originalSky,"Home controller and sky survive Angular to Fluid");
                root.check(root.control("home.play").activeFocus,"Home transport focus transfers to Fluid");
                root.room.session.shiftMonth(2);root.monthSnapshot=root.room.session.calendarMonth.toISOString();
                dashboard.preferencesOpen=true;
                root.find(dashboard,i=>typeof i.preview==="function").preview("amoled:ice");
                root.choose("angular");
                break;
            case 2:
                root.check(client.paletteData.preview && dashboard.preferencesOpen,"Home switching preserves Settings and palette preview");
                root.check(root.room.session.calendarMonth.toISOString()===root.monthSnapshot,"Calendar month survives return to Angular");
                root.check(root.control("home.week").week.toISOString()===root.weekSnapshot && root.control("home.week").selectedDate.toISOString()===root.selectionSnapshot,"Angular calendar week and selected day survive presentation replacement");
                dashboard.preferencesOpen=false;Motion.reduced=false;Motion.overdrive=true;Motion.settleDrive();
                break;
            case 3:
                root.check(!client.paletteData.preview,"Home Settings close cancels preview");
                root.check(!!root.room.session.foldSnapshot,"Angular Home records its opening fold");
                root.foldSnapshot=JSON.stringify(root.room.session.foldSnapshot);root.editionSnapshot=root.room.session.edition;
                root.leaseSnapshot=root.leaseChanges;root.skySnapshot=root.skyCalls-root.minuteRefreshes;
                root.surveyor().autonomous=false;
                break;
            case 4:
                if(root.cycles++<40) {
                    const surveyor=root.surveyor();
                    if(surveyor.room!==root.room.presentation.item) { root.check(false,"Surveyor follows the current presentation");return; }
                    surveyor.begin();
                    root.choose(Design.fluid?"angular":"fluid");root.stage--;break;
                }
                root.check(true,"Surveyor follows all forty presentations without stale controls");
                root.check(root.room.session===root.original && root.room.session.edition===root.editionSnapshot,"Forty switches retain Home controller and edition");
                root.check(JSON.stringify(root.room.session.foldSnapshot)===root.foldSnapshot,"Style changes do not press extra folds");
                root.check(root.control("home.week").week.toISOString()===root.weekSnapshot && root.control("home.week").selectedDate.toISOString()===root.selectionSnapshot,"Forty switches retain Angular calendar navigation");
                root.check(root.leaseChanges===root.leaseSnapshot && root.skyCalls-root.minuteRefreshes===root.skySnapshot,"Forty switches do not churn leases or sky requests");
                root.choose("fluid");
                break;
            case 5:
                root.check(root.room.session.calendarMonth.toISOString()===root.monthSnapshot,"Fluid restores its chosen calendar month");
                let viewport=root.room.parent;
                while(viewport && viewport.contentY===undefined) viewport=viewport.parent;
                root.check(!!viewport && root.room.height<=viewport.height+1,"Fluid Home fits the native viewport without scrolling");
                root.bounds("home.main");root.bounds("home.aside");root.bounds("home.lock");root.bounds("home.settings");
                root.control("home.task.one").clicked();root.control("home.focus").clicked();
                root.check(client.tasksData.tasks[0].done && root.calls.some(c=>c.op==="task.update" && c.args.id==="one"),"Home task completion uses task identity and shared core");
                root.check(root.calls.some(c=>c.op==="timer.toggle" && c.args.kind==="pomodoro"),"Home focus action uses existing timer service");
                fixture.media.calls=[];root.control("home.play").clicked();
                root.check(fixture.media.calls.length===1 && fixture.media.calls[0].method==="togglePlaying","Home transport uses the shared adapter");
                context.panelOpen=false;
                break;
            case 6:
                root.check(!fixture.media.holds("position"),"Folding Home releases position lease");
                root.skySnapshot=root.skyCalls;root.room.session.askSky();
                root.check(root.skyCalls===root.skySnapshot,"Hidden Home does not refresh sky");
                context.panelOpen=true;Motion.overdrive=false;Motion.settleDrive();Motion.reduced=true;
                root.choose("angular");
                break;
            case 7:
                root.control("home.profile").forceActiveFocus();root.choose("fluid");
                break;
            case 8:
                root.check(root.control("home.profile").activeFocus,"Home profile focus transfers between presentations");
                root.check(fixture.power.calls.length===0 && fixture.hostActions.calls.length===0,"Home tests never actuate lock or host actions");
                root.deferSky=true;
                root.originalSky=root.room.session.sky;
                root.room.session.askSky();
                context.panelOpen=false;
                root.skyReplies.shift()(true,{obsolete:true});
                root.check(root.room.session.sky===root.originalSky,"Late sky reply cannot update a folded Home");
                context.panelOpen=true;
                client.connected=false;
                root.skyReplies.shift()(true,{obsolete:true});
                root.check(root.room.session.sky===root.originalSky,"Disconnected sky reply cannot replace the last snapshot");
                fixture.media.active=null;
                break;
            case 9:
                root.check(root.room.session.upcoming.length===0 && !root.control("home.focus").enabled && !root.control("home.play").enabled,"Offline tasks and unavailable media disable their actions");
                root.check(!fixture.media.holds("position"),"No player releases Home's position lease");
                console.log("FLUID_DONE");Qt.quit();
            }
        }
    }
}
