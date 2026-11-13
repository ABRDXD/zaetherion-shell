import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.adapters.fixture
import qs.core.client
import qs.view.rooms
import qs.view.shell
import qs.view.ui
import qs.view.fluid
import qs.view.cues

ShellRoot {
    id: root
    readonly property var output: Quickshell.screens.find(s => s.name === "ZTEST") ?? null
    readonly property bool integrated: Quickshell.env("FLUID_INTEGRATED") === "1"
    readonly property var currentRoom: integrated ? dashboard.item?.shownSlot.item : room
    property bool settingsOpen: false
    property bool rejectStyle: false
    property bool delayStyle: false
    property var styleReplies: []
    property int cancels: 0
    property int leaseChanges: 0
    property int stage: 0
    property int cycles: 0
    property var originalSession: null
    property var leaseSnapshot: null
    property var paletteSnapshot: null
    property var saved: ({name:"dms:amoledBlack", effective:"dms:amoledBlack", preview:false,
        colors:{background:"#000000",surface:"#000000",text:"#eeeeee",accent:"#ffffff"},
        savedColors:{background:"#000000",surface:"#000000",text:"#eeeeee",accent:"#ffffff"}})
    property var choices: [
        {id:"dms:amoledBlack",name:"Amoled Black",source:"DMS",accent:"#ffffff"},
        {id:"amoled:ice",name:"Ice",source:"AMOLED studies",accent:"#8edfff"}
    ]
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) { const found=find(child,test); if(found) return found; }
        return null;
    }
    function control(name) { return find(room, i => i.objectName === name); }
    function picker() { return find(prefs, i => typeof i.preview === "function"); }
    function check(ok, name) {
        console.log((ok ? "FLUID_PASS " : "FLUID_FAIL ") + name);
        if (!ok) Qt.quit();
    }
    function replyStyle(ok) {
        const pending = styleReplies.shift();
        if (ok) client.islandData = {form: pending.form};
        pending.callback(true, {ok, line: ok ? "" : "Delayed rejection"});
    }
    function checkGeometry() {
        for (const name of ["media.player", "media.cover", "media.lyricBody", "media.seek", "media.play", "media.loop"]) {
            const item = control(name), p = item.mapToItem(room, 0, 0);
            check(p.x >= -1 && p.y >= -1 && p.x + item.width <= room.width + 1 && p.y + item.height <= room.height + 1,
                  name + " stays inside Media");
        }
    }
    CoreClient {
        id: client
        path: ""
        connected: true
        islandData: ({form: Quickshell.env("FLUID_FORM") || "angular"})
        paletteData: root.saved
        function request(op,args,callback) {
            if (op === "cmd.run") {
                if (root.delayStyle) { root.styleReplies.push({form:args.line.split(" ")[1], callback}); return; }
                if (root.rejectStyle) { callback(true,{ok:false,line:"Fixture rejection"}); return; }
                islandData = {form: args.line.split(" ")[1]};
                callback(true,{ok:true}); return;
            }
            if (op === "palette.list") { callback(true,root.choices); return; }
            if (!["palette.cancel", "palette.preview", "palette.choose"].includes(op)) {
                if (callback) callback(true, {});
                return;
            }
            if (op === "palette.cancel") { root.cancels++; paletteData=root.saved; }
            else {
                const entry=root.choices.find(e=>e.id===args.name);
                const colors={background:"#000000",surface:"#000000",text:"#eeeeee",accent:entry.accent};
                paletteData={name:root.saved.name,effective:entry.id,preview:true,colors,savedColors:root.saved.colors};
                if(op === "palette.choose") { root.saved={name:entry.id,effective:entry.id,preview:false,colors,savedColors:colors}; paletteData=root.saved; }
            }
            if(callback) callback(true,paletteData);
        }
    }
    Binding { target: Design; property: "form"; value: client.islandData.form }
    PaletteBinding { core: client }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: client }
    Connections { target: fixture.media; function onLeasesChanged() { root.leaseChanges++; } }
    Connections { target: fixture.lyrics; function onLeasesChanged() { root.leaseChanges++; } }
    PanelWindow {
        id: window
        screen: root.output
        visible: root.output !== null
        anchors { top:true; bottom:true; left:true; right:true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "#0a0d0f"
        Rectangle {
            id: panel
            x:280; y:110; width:1360; height:860
            color: Design.background
            border.color: Design.line
            radius: Design.fluid ? 26 : 0
            FluidText { visible:!root.integrated; x:32; y:24; text:"FART / MEDIA · PRESENTATION INTEGRATION FIXTURE"; color:Design.muted }
            StylePicker { id: style; visible:!root.integrated; x:1040; y:16; width:280; core:client }
            Media { id:room; visible:!root.integrated; x:40; y:100; width:1280; height:670; host:fixture; shell:context }
            TextField { id:outside; visible:!root.integrated; x:40; y:794; width:800; text:"Command draft survives the switch" }
            FluidButton { visible:!root.integrated; x:1170; y:794; text:"Settings"; onClicked:root.settingsOpen=!root.settingsOpen }
            PreferencesPane { id:prefs; core:client; expanded:root.settingsOpen && !root.integrated; onClosed:root.settingsOpen=false }
            Loader {
                id: dashboard
                anchors.fill: parent
                active: root.integrated
                onLoaded: item.navigate("media")
                sourceComponent: Shell {
                    host:fixture; core:client; shell:context
                    preferencesOpen: root.settingsOpen
                }
            }
        }
    }
    IpcHandler {
        target: "fluid-fixture"
        function style(name:string): void {
            if (root.integrated) {
                root.find(dashboard.item, i => i.objectName === "style." + name).clicked();
                root.currentRoom.lyrics=true;
            } else style.choose(name);
        }
        function settings(on:bool): void {
            if (root.integrated) dashboard.item.preferencesOpen=on;
            else root.settingsOpen=on;
        }
        function preview(): void {
            const picker = root.integrated ? root.find(dashboard.item, i => typeof i.preview === "function") : root.picker();
            picker.preview("amoled:ice");
        }
        function overdrive(on:bool): void { Motion.overdrive=on; Motion.settleDrive(); }
        function playing(on:bool): void {
            fixture.media.active=Object.assign({},fixture.media.active,{playing:on});
            fixture.media.positionStamp=Date.now();
            Motion.reduced=false;
        }
        function catalogue(): void {
            fixture.media.players=Array.from({length:12},(_,i)=>({id:"fixture-"+i,identity:"Long fixture player name "+i}));
            fixture.media.active=Object.assign({},fixture.media.active,{id:"fixture-11"});
        }
        function state(): string { return JSON.stringify({form:Design.form,palette:client.paletteData,leases:fixture.media.leases,lyrics:fixture.lyrics.leases,
            room: {width:root.currentRoom.width,height:root.currentRoom.height}, page:dashboard.item?.currentPage ?? "media",
            controller:String(root.currentRoom.session), settings:root.integrated ? dashboard.item.preferencesOpen : root.settingsOpen}); }
    }
    Component.onCompleted: {
        Motion.reduced = true;
        fixture.media.positionStamp=Date.now();
        room.lyrics=true;
        console.log("FLUID_READY");
    }
    Timer {
        interval: 150
        running: Quickshell.env("FLUID_AUTOTEST") === "1"
        repeat: true
        onTriggered: {
            if (room.presentation.loading || !room.presentation.item) return;
            switch(root.stage++) {
            case 0:
                root.originalSession=room.session;
                root.check(Design.form === "angular" && room.session.lyrics,"Angular starts with the persistent session");
                root.settingsOpen=true;
                break;
            case 1:
                root.picker().preview("amoled:ice");
                root.paletteSnapshot=JSON.stringify(client.paletteData);
                root.leaseSnapshot=root.leaseChanges;
                style.choose("fluid");
                break;
            case 2:
                root.check(Design.form === "fluid" && room.session === root.originalSession && room.session.lyrics,"Fluid retains session identity and lyrics choice");
                root.check(JSON.stringify(client.paletteData)===root.paletteSnapshot && root.cancels===0,"Style switch preserves the active palette preview");
                root.check(root.leaseChanges===root.leaseSnapshot,"Style switch does not churn leases");
                root.check(outside.text==="Command draft survives the switch" && root.settingsOpen,"Settings and command draft survive");
                root.settingsOpen=false;
                break;
            case 3:
                root.check(!client.paletteData.preview && root.cancels===1,"Closing settings still cancels preview exactly once");
                root.control("media.play").forceActiveFocus();
                style.choose("angular");
                break;
            case 4:
                root.check(root.control("media.play").activeFocus,"Focus follows the corresponding Angular control");
                style.choose("fluid");
                break;
            case 5:
                root.check(root.control("media.play").activeFocus,"Focus follows the corresponding Fluid control");
                outside.forceActiveFocus();
                style.choose("angular");
                break;
            case 6:
                root.check(outside.activeFocus,"Switching does not steal focus from outside the room");
                style.choose("fluid"); style.choose("angular"); style.choose("fluid");
                break;
            case 7:
                root.check(Design.form==="fluid" && room.presentation.item.session===room.session && !room.presentation.loading,"Rapid requests commit only the final view");
                root.rejectStyle=true; style.choose("angular");
                break;
            case 8:
                root.check(Design.form==="fluid" && style.error==="Fixture rejection","Rejected style command keeps the current design");
                root.rejectStyle=false;
                fixture.media.calls=[];
                root.control("media.play").clicked(); root.control("media.next").clicked();
                root.control("media.shuffle").clicked(); root.control("media.loop").clicked();
                room.session.seek(999); room.session.selectIndex(0);
                root.check(fixture.media.calls.map(c=>c.method).join(",")==="togglePlaying,next,setShuffle,setLoop,seek,select" && fixture.media.calls[4].args[0]===200,"Both views use capability checked shared actions");
                fixture.media.active=Object.assign({},fixture.media.active,{canToggle:false,canSeek:false});
                room.session.togglePlaying(); room.session.seek(20);
                root.check(fixture.media.calls.length===6,"Unavailable actions do not reach the adapter");
                fixture.media.active=Object.assign({},fixture.media.active,{playing:true});
                ViewState.visualiserEnabled=true; Motion.reduced=false;
                break;
            case 9:
                root.check(fixture.media.leases.position.length===1 && fixture.media.leases.spectrum.length===1 && fixture.lyrics.leases.lyrics.length===1,"Playing owns exactly one of each subscription");
                root.leaseSnapshot=root.leaseChanges;
                break;
            case 10:
                if(root.cycles++<40) { style.choose(Design.fluid ? "angular" : "fluid"); root.stage--; break; }
                root.check(root.leaseChanges===root.leaseSnapshot && room.session===root.originalSession,"Forty alternating switches preserve leases and controller identity");
                context.panelOpen=false;
                break;
            case 11:
                root.check(!fixture.media.holds("position") && !fixture.media.holds("spectrum") && !fixture.lyrics.holds("lyrics"),"Folding releases all subscriptions");
                context.panelOpen=true;
                root.delayStyle=true;
                style.choose("angular"); style.choose("fluid"); style.choose("angular"); style.choose("fluid");
                root.check(style.busy && root.styleReplies.length===1,"Delayed command serializes requests");
                root.replyStyle(true);
                root.check(style.busy && root.styleReplies.length===1 && root.styleReplies[0].form==="fluid","Latest queued intent returns to the original form");
                root.replyStyle(true);
                break;
            case 12:
                root.check(Design.fluid && !style.busy && style.error==="","Delayed style replies preserve final intent");
                style.choose("angular"); style.choose("fluid");
                root.replyStyle(false); root.replyStyle(true);
                root.check(style.error==="","Superseded failure cannot overwrite the newer request");
                style.choose("angular"); style.choose("fluid");
                client.connected=false;
                root.replyStyle(false);
                root.check(!style.busy && !style.queuedForm && style.error==="","Disconnect clears queued work and ignores stale replies");
                client.connected=true; root.delayStyle=false;
                fixture.media.players=[fixture.media.players[0], {id:"second-fixture",identity:"Second fixture player"}];
                root.control("media.player").forceActiveFocus();
                style.choose("angular");
                break;
            case 13:
                root.check(root.control("media.player").activeFocus,"Player choice focus transfers to Angular");
                style.choose("fluid");
                break;
            case 14:
                root.check(root.control("media.player").activeFocus,"Player choice focus transfers to Fluid");
                fixture.media.players=Array.from({length:12},(_,i)=>({id:"fixture-"+i,identity:"Long fixture player name "+i}));
                fixture.media.active=Object.assign({},fixture.media.active,{id:"fixture-11"});
                Motion.overdrive=true; Motion.settleDrive();
                root.settingsOpen=true;
                break;
            case 15:
                root.checkGeometry();
                root.check(root.control("media.player").currentIndex===11,"Long player catalogue retains selection");
                root.control("media.player").choose(0);
                root.check(fixture.media.calls[fixture.media.calls.length-1].method==="select","Fluid choice dispatches through the shared session");
                root.check(prefs.childrenRect.height <= prefs.height + 1,"Overdrive settings content fits its panel");
                console.log("FLUID_DONE"); Qt.quit();
            }
        }
    }
}
