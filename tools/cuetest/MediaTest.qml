import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell
import qs.view.strata

// Media's spectral architecture (view/rooms/SpectralArchitecture.qml, docs/OVERDRIVE.md §20) in the real room against
// the fixture player, playing. A song is fed in synthetic time: bass-heavy, then bright. In Silent there is none; in
// Overdrive the first section stands on one massive column, the bright section fractures it into narrow cuts with the
// planes sliding there, it takes no input and sits behind the content, and a release removes it. With MEDIA_SHOTS
// set, frames are saved there.
Scope {
    id: root
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const child of item.children ?? []) {
            const found = find(child, test);
            if (found) return found;
        }
        return null;
    }
    readonly property string shots: Quickshell.env("MEDIA_SHOTS") || ""
    function shot(name, fn) {
        if (!shots) { fn(); return; }
        stage.grabToImage(r => { r.saveToFile(shots + "/" + name + ".png"); fn(); });
    }
    function bins(kind) { return Array.from({ length: 56 }, (_, i) => kind === "bass" ? (i < 9 ? 0.9 : i < 28 ? 0.25 : 0.05) : (i < 9 ? 0.1 : i < 28 ? 0.35 : 0.8)); }
    function song(arch, kind, from, seconds) { for (let k = 0; k < seconds * 30; k++) arch.feed(bins(kind), from + k / 30); }
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1100; implicitHeight: 700; visible: true
        color: "#0d1218"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#0d1218" }
            Media { id: room; anchors.fill: parent; anchors.margins: 24; host: fixture; shell: context }
        }
    }
    property var typeset: null
    function architecture() { return find(room, i => i.feed !== undefined && i.compose === undefined && i.pool !== undefined); }
    Component.onCompleted: after(300, () => {
        fixture.media.active = Object.assign({}, fixture.media.active, { playing: true });
        after(200, () => {
            const silent = !architecture() && !Strata.live.includes("panel:media.architecture");
            const voiced = [];
            const walk = i => { if (i.voice === "media") voiced.push(i.voiceShift); for (const c of i.children ?? []) walk(c); };
            walk(room);
            check("voice.media", voiced.length === 3 && voiced.every(v => v === -1), { voiced: voiced });
            Motion.overdrive = true;
            Motion.settleDrive();
            after(400, () => {
                const arch = architecture();
                const mount = find(room, i => i.name === "media.architecture" && i.sourceComponent !== undefined);
                song(arch, "bass", 0, 3);
                arch.morph = 1;
                const first = arch.columns.slice();
                const widest = Math.max(...first.map(c => c.w));
                const planes = arch.children.filter(c => c.role !== undefined && c.visible).length;
                check("arch.first", silent && arch.section?.index === 1 && first.length <= 2 && widest > 0.7 && planes === first.length && mount.z < 0,
                      { silent: silent, section: arch.section?.index, columns: first.length, widest: widest, planes: planes, z: mount.z });
                // The groove: a frame of sound at 50 s of the 200 s track cuts the cell under the playhead, and only it.
                fixture.media.position = 50;
                fixture.media.spectrum = bins("bass");
                const grooveKey = Object.keys(ViewState.grooves).find(k => k.includes("Fixture Signal"));
                const cut = grooveKey ? ViewState.grooves[grooveKey] : [];
                const line = find(room, i => i.groove !== undefined && i.track !== undefined);
                check("groove.cut", cut.length === 160 && cut[40] > 0.5 && cut.filter(v => v > 0).length === 1 && !!line && line.progress === 0.25,
                      { key: grooveKey, cells: cut.filter(v => v > 0).length, at40: cut[40], line: !!line });
                // The harmonic typesetter: a bass section sets the title broad; the bright section that follows re-sets it leaning.
                const typer = find(room, i => i.feed !== undefined && i.set !== undefined && i.target !== undefined);
                if (typer) {
                    typer.autonomous = false;
                    for (let k = 0; k < 90; k++) typer.feed(bins("bass"), k / 30);
                    const first = Object.assign({}, typer.set), firstSection = typer.section;
                    for (let k = 0; k < 300; k++) typer.feed(bins("bright"), 3 + k / 30);
                    root.typeset = { first: first, firstSection: firstSection, second: Object.assign({}, typer.set), section: typer.section,
                                     weight: typer.target.font.weight, title: typer.target };
                }
                check("type.sections", !!typer && root.typeset.firstSection === 1 && root.typeset.section === 2 && root.typeset.first.stretch > 1.05
                      && root.typeset.second.slant < root.typeset.first.slant && root.typeset.weight === root.typeset.second.weight,
                      { found: !!typer, typeset: root.typeset ? { first: root.typeset.first, second: root.typeset.second, section: root.typeset.section, weight: root.typeset.weight } : null });
                shot("arch-1-bass", () => {
                    song(arch, "bright", 3, 9);
                    const cutAt = arch.section?.index;
                    const startMorph = arch.morph;
                    after(900, () => {
                        const cuts = arch.columns;
                        check("arch.cut", cutAt === 2 && startMorph < 1 && arch.morph === 1 && cuts.length >= 6 && Math.max(...cuts.map(c => c.w)) < 0.35
                              && JSON.stringify(cuts) === JSON.stringify(arch.to), { section: cutAt, startMorph: startMorph, morph: arch.morph, cuts: cuts.length });
                        const input = find(arch, i => i.acceptedButtons !== undefined || i.hoverEnabled === true);
                        check("arch.inert", !input && !Motion.activeNames.includes("media.architecture"), { input: !!input, names: Motion.activeNames });
                        // For the frame only: a groove cut over the first quarter, louder in places, a pause in it.
                        if (shots) {
                            const k = Object.keys(ViewState.grooves).find(k => k.includes("Fixture Signal"));
                            ViewState.keepGroove(k, Array.from({ length: 160 }, (_, i) => i < 40 && (i < 18 || i > 24) ? 0.25 + 0.75 * Math.abs(Math.sin(i / 5)) : 0));
                        }
                        shot("arch-2-bright", () => {
                            // Held silence: twelve square columns in register; sound lets them go back.
                            const quiet = Array.from({ length: 56 }, () => 0);
                            for (let k = 0; k < 45; k++) arch.feed(quiet, 12 + k / 30);
                            arch.morph = 1;
                            const hushed = arch.hushed && arch.columns.length === 12 && arch.columns.every(c => c.slant === 0);
                            for (let k = 0; k < 15; k++) arch.feed(bins("bright"), 13.5 + k / 30);
                            arch.morph = 1;
                            check("arch.silence", hushed && !arch.hushed && JSON.stringify(arch.columns) === JSON.stringify(arch.composed),
                                  { hushed: hushed, after: arch.hushed, columns: arch.columns.length });
                            Motion.overdrive = false;
                            after(Motion.spinDown + 600, () => {
                                check("arch.release", !architecture() && !Strata.live.includes("panel:media.architecture"), { live: Strata.live });
                                const t = root.typeset?.title;
                                check("type.release", !!t && t.stretch === 1 && t.slant === 0 && t.font.weight === Font.Black && t.font.letterSpacing === -1.5
                                      && !Strata.live.includes("panel:media.typesetter"), { stretch: t?.stretch, slant: t?.slant, weight: t?.font.weight, live: Strata.live });
                                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames.filter(n => !n.startsWith("media.cat"))));
                                console.log("CUE_DONE");
                                Qt.exit(0);
                            });
                        });
                    });
                });
            });
        });
    });
}
