import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.rooms
import qs.view.shell

// Performance's own Overdrive and history (docs/OVERDRIVE.md §18–19). The machine's weather in the header: before any
// report, the old promise; with reports, the latest sentence and its pressure, a barograph of up to 24 reports, and
// the second line with the span on hover; nothing animates. The cache palimpsest: in Silent a changed figure keeps no
// impression; in Overdrive it does, lingering by memory pressure, and a release wipes the page.
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
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    FloatingWindow {
        id: window
        implicitWidth: 1100; implicitHeight: 760; visible: true
        Performance { id: room; anchors.fill: parent; anchors.margins: 20; host: fixture; shell: context }
    }
    Component.onCompleted: after(400, () => {
        const label = () => find(room, i => typeof i.text === "string" && (i.text === "NO SYNTHETIC READINGS" || i.text.includes(" HPA")));
        const before = label()?.text;
        const at = Math.round(new Date(2026, 10, 9, 12, 0).getTime() / 1000);
        room.weather = { count: 3, latest: { sentence: "fair, steady pressure / light airs / dry", detail: "mild, a light current, slack water",
                                             values: { hpa: 1033 }, at: at, span: 2 * 3600 + 15 * 60 },
                         barograph: [{ hpa: 1001 }, { hpa: 1020 }, { hpa: 1033 }],
                         strata: [{ span: 7200, temp: 44 }, { span: 1800, temp: 82 }, { span: 3600, temp: 55 }, { span: 600, temp: 70 }] };
        after(50, () => {
            const text = label()?.text;
            check("weather.header", before === "NO SYNTHETIC READINGS" && text === "FAIR, STEADY PRESSURE / LIGHT AIRS / DRY · 1033 HPA",
                  { before: before, text: text });
            const marks = room.barograph;
            check("weather.barograph", marks.length === 3 && marks[0].x === 0 && marks[2].x === 64 && marks[2].y < marks[0].y,
                  { marks: marks.map(p => [p.x, p.y]) });
            const voiced = [];
            const walk = i => { if (i.voice === "kernel" && i.visible) voiced.push(i.voiceShift); for (const c of i.children ?? []) walk(c); };
            walk(room);
            const strata = find(room, i => i.layers !== undefined && i.strata !== undefined);
            check("strata.layers", !!strata && strata.layers.length === 4 && strata.layers[0].h > strata.layers[1].h && strata.layers[1].tone > strata.layers[0].tone,
                  { layers: strata?.layers });
            check("voice.kernel", voiced.length >= 3 && voiced.every(v => v === 1), { voiced: voiced });
            check("weather.detail", room.weatherDetail === "SINCE 09:45 · 2 H 15 MIN\nMILD, A LIGHT CURRENT, SLACK WATER", { detail: room.weatherDetail });
            const done = () => root.palimpsest();
            const shots = Quickshell.env("PERF_SHOTS") || "";
            if (shots) room.grabToImage(r => { r.saveToFile(shots + "/performance.png"); done(); }); else done();
        });
    });
    // The scheduler's plates: eight cores, then core 3 flat out with fourteen runnable and preemption rising.
    function plates(next) {
        const plates = find(room, i => i.loads !== undefined && i.scarps !== undefined);
        if (!plates) {
            check("plates.faults", false, { loaded: false });
            next();
            return;
        }
        plates.autonomous = false;
        const calm = { running: true, cores: [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1], runnable: 1, blocked: 0, ctxt: 8000, voluntary: 6000, involuntary: 60 };
        plates.take(calm);
        const calmAngle = plates.weave.angleI;
        for (let k = 0; k < 6; k++)
            plates.take({ running: true, cores: [0.1, 0.1, 0.1, 1, 0.1, 0.1, 0.1, 0.1], runnable: 14, blocked: 0, ctxt: 20000, voluntary: 6000, involuntary: 5000 });
        const label = find(plates, i => typeof i.text === "string" && i.text.startsWith("CPU "));
        check("plates.faults", plates.polys.length === 8 && plates.lead === 3 && plates.stress > 0.5 && plates.scarps.length >= 2
              && plates.weave.angleI < calmAngle && label?.text.startsWith("CPU 3 · "),
              { polys: plates.polys.length, lead: plates.lead, stress: plates.stress, scarps: plates.scarps.length,
                angles: [calmAngle, plates.weave.angleI], label: label?.text });
        const shots = Quickshell.env("PERF_SHOTS") || "";
        const spectro = () => root.spectrograph(next);
        if (shots) after(200, () => room.grabToImage(r => { r.saveToFile(shots + "/plates.png"); spectro(); })); else spectro();
    }
    // MEM chosen: the plates go, the spectrograph comes, fed with the orrery's samples (fed directly here).
    function spectrograph(next) {
        const halo = find(room, i => i.currentIndex !== undefined && i.count !== undefined && i.model !== undefined);
        halo.currentIndex = room.readings.findIndex(r => r.key === "memory");
        after(300, () => {
            const g = find(room, i => i.tracks !== undefined && i.sparks !== undefined);
            const plates = find(room, i => i.loads !== undefined && i.scarps !== undefined);
            const body = (id, name, cpu, rss, age) => ({ id: id, name: name, cpu: cpu, rss: rss, age: age, born: false });
            const daemon = cpu => body("1:1", "pipewire", cpu, 30, 86400 * 3);
            if (g) {
                g.sample = { running: true, forks: 0, bodies: [daemon(2), body("2:1", "cc1plus", 0, 400, 3)] };
                g.sample = { running: true, forks: 9, bodies: [daemon(0), body("2:1", "cc1plus", 350, 600, 4)] };
                g.sample = { running: true, forks: 3, bodies: [daemon(1.5)] };
            }
            const t = g ? g.tracks : {};
            const label = g ? find(g, i => typeof i.text === "string" && i.text === "PIPEWIRE") : null;
            check("spectro.lines", !!g && !plates && t["1:1"]?.notches.length === 1 && t["1:1"].x > 0.8 && t["2:1"]?.gone === 3 && g.sparks === 3
                  && t["2:1"].y > t["1:1"].y && t["2:1"].w > t["1:1"].w && !!label,
                  { found: !!g, plates: !!plates, tracks: t, sparks: g?.sparks });
            const shots = Quickshell.env("PERF_SHOTS") || "";
            const tide = () => root.tide(next);
            if (shots) after(200, () => room.grabToImage(r => { r.saveToFile(shots + "/spectrograph.png"); tide(); })); else tide();
        });
    }
    // DISK chosen: the tide comes (fed directly). A burst of writes, then quiet: a wrack line and the tideline stay.
    function tide(next) {
        const halo = find(room, i => i.currentIndex !== undefined && i.count !== undefined && i.model !== undefined);
        halo.currentIndex = room.readings.findIndex(r => r.key === "disk");
        after(300, () => {
            const t = find(room, i => i.state !== undefined && i.speed !== undefined && i.take !== undefined);
            const spectro = find(room, i => i.tracks !== undefined && i.sparks !== undefined);
            if (t) {
                t.autonomous = false;
                for (let k = 0; k < 6; k++) t.take({ running: true, read: 2e5, written: 80e6, busy: 0.7 }, 1);
                for (let k = 0; k < 6; k++) t.take({ running: true, read: 1e4, written: 0, busy: 0.02 }, 1);
            }
            const label = t ? find(t, i => typeof i.text === "string" && i.text.startsWith("HW ")) : null;
            check("tide.wrack", !!t && !spectro && t.state.wracks.length === 1 && t.state.high.h > 0.5 && t.state.level < t.state.high.h
                  && t.speed < 0 && !!label?.visible,
                  { found: !!t, spectro: !!spectro, state: t?.state, speed: t?.speed });
            const shots = Quickshell.env("PERF_SHOTS") || "";
            const recorder = () => root.recorder(next);
            if (shots) after(200, () => room.grabToImage(r => { r.saveToFile(shots + "/tide.png"); recorder(); })); else recorder();
        });
    }
    // GPU chosen: the chart recorder (fed directly). Seventy seconds of samples: one revolution kept.
    function recorder(next) {
        const halo = find(room, i => i.currentIndex !== undefined && i.count !== undefined && i.model !== undefined);
        halo.currentIndex = room.readings.findIndex(r => r.key === "gpu");
        after(300, () => {
            const g = find(room, i => i.trace !== undefined && i.main !== undefined && i.take !== undefined);
            const tide = find(room, i => i.state !== undefined && i.speed !== undefined && i.take !== undefined);
            if (g) {
                g.autonomous = false;
                for (let k = 0; k < 70; k++)
                    g.take({ running: true, gpus: [{ card: "card0", vendor: "NVIDIA", awake: false },
                                                   { card: "card1", vendor: "AMD", awake: true, busy: 0.5 + 0.45 * Math.sin(k / 6), levels: [800, 1100, 2700],
                                                     level: k % 20 < 10 ? 0 : 2, vram: 300 * 1048576, total: 512 * 1048576 }] });
            }
            const label = g ? find(g, i => typeof i.text === "string" && i.text.startsWith("AMD ")) : null;
            check("recorder.chart", !!g && !tide && g.trace.length === 60 && !!label?.text.endsWith("NVIDIA ASLEEP"),
                  { found: !!g, tide: !!tide, trace: g?.trace.length, label: label?.text });
            const shots = Quickshell.env("PERF_SHOTS") || "";
            const silt = () => root.silt(next);
            if (shots) after(200, () => room.grabToImage(r => { r.saveToFile(shots + "/recorder.png"); silt(); })); else silt();
        });
    }
    // SWAP chosen: silt (fed directly). Three minutes of paging out: three bands; grains fall, then come to rest.
    function silt(next) {
        const halo = find(room, i => i.currentIndex !== undefined && i.count !== undefined && i.model !== undefined);
        halo.currentIndex = room.readings.findIndex(r => r.key === "swap");
        after(300, () => {
            const g = find(room, i => i.flying !== undefined && i.bands !== undefined && i.take !== undefined);
            const recorder = find(room, i => i.trace !== undefined && i.main !== undefined && i.take !== undefined);
            if (g) {
                g.autonomous = false;
                for (let k = 0; k < 150; k++) g.take({ running: true, in: k % 30 === 0 ? 400 : 0, out: 2000, used: k * 2e6, total: 4e9 });
            }
            const flying = g ? g.flying.length : 0;
            check("silt.bed", !!g && !recorder && g.bands.length === 3 && g.bed > 0 && flying > 0 && Motion.activeNames.includes("idle.performance.silt"),
                  { found: !!g, recorder: !!recorder, bands: g?.bands.length, bed: g?.bed, flying: flying, names: Motion.activeNames });
            after(1500, () => {
                if (g) g.take({ running: true, in: 0, out: 0, used: 300e6, total: 4e9 });
                after(1500, () => {
                    check("silt.rest", !!g && g.flying.length === 0 && !Motion.activeNames.includes("idle.performance.silt"), { flying: g?.flying.length, names: Motion.activeNames });
                    const shots = Quickshell.env("PERF_SHOTS") || "";
                    if (shots) room.grabToImage(r => { r.saveToFile(shots + "/silt.png"); next(); }); else next();
                });
            });
        });
    }
    function palimpsest() {
        const page = find(room, i => i.halfLife !== undefined && i.impress !== undefined);
        const figure = page.target;
        // Silent: no impression.
        figure.text = "11%";
        figure.text = "12%";
        const silent = page.ghosts.length;
        // Overdrive, memory nearly full: the old figure stays, faint and out of register.
        Motion.overdrive = true;
        Motion.settleDrive();
        page.pressure = 0.95;
        figure.text = "13%";
        figure.text = "14%";
        const kept = page.ghosts.map(g => g.text);
        const ghost = find(page, i => i.text === "13%" && i !== figure);
        const faint = !!ghost && ghost.opacity > 0.3 && ghost.opacity <= 0.4 && (ghost.x !== 0 || ghost.y !== 0);
        check("palimpsest.kept", silent === 0 && JSON.stringify(kept) === JSON.stringify(["12%", "13%"]) && faint && page.halfLife > 40,
              { silent: silent, kept: kept, faint: faint, halfLife: page.halfLife });
        // A roomy machine: clean paper within a few seconds, and nothing left running.
        page.pressure = 0.2;
        after(4500, () => {
            // Interrupt rainfall: a sample's drops and a spike's crater (the core is absent here, so it is fed directly).
            const rain = find(room, i => i.drops !== undefined && i.craters !== undefined);
            rain?.rain({ running: true, total: 5000, rain: [{ kind: "gpu", rate: 3000 }, { kind: "timer", rate: 2000 }], spikes: ["gpu"] });
            const fell = rain ? rain.drops.length : -1, struck = rain ? rain.craters.length : -1;
            check("rain.drops", fell >= 4 && struck === 1 && rain.drops.every(d => d.kind === "gpu" || d.kind === "timer"), { drops: fell, craters: struck });
            root.plates(() => {
            check("palimpsest.clears", page.ghosts.length === 0 && !Motion.activeNames.includes("idle.palimpsest"),
                  { ghosts: page.ghosts.length, names: Motion.activeNames });
            page.pressure = 0.95;
            figure.text = "15%";
            figure.text = "16%";
            const before = page.ghosts.length;
            Motion.overdrive = false;
            Motion.settleDrive();
            after(50, () => {
                check("palimpsest.release", before === 2 && page.ghosts.length === 0, { before: before, after: page.ghosts.length });
                check("plates.release", !find(room, i => i.loads !== undefined && i.scarps !== undefined) && !find(room, i => i.tracks !== undefined && i.sparks !== undefined)
                      && !find(room, i => i.state !== undefined && i.speed !== undefined && i.take !== undefined)
                      && !find(room, i => i.trace !== undefined && i.main !== undefined && i.take !== undefined)
                      && !find(room, i => i.flying !== undefined && i.bands !== undefined && i.take !== undefined), {});
                console.log("CUE_ACTIVE", Motion.active, JSON.stringify(Motion.activeNames));
                console.log("CUE_DONE");
                Qt.exit(0);
            });
            });
        });
    }
}
