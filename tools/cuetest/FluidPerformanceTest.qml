import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.shell
import qs.view.rooms
import qs.view.contract
import qs.view.ui as UI
import qs.view.cues

// Confluence Performance (view/fluid/FluidPerformance.qml, PerformanceStar.qml), offscreen on fixture telemetry: the
// star's colour follows the CPU temperature, its core grows with memory, the GPU companion shows only with a GPU,
// the readings say what the star shows, Overdrive's layers draw when given, and Angular and back keep the readings.
// With FLUID_PERF_SHOTS set, frames are saved there.
Scope {
    id: root
    readonly property string shots: Quickshell.env("FLUID_PERF_SHOTS") || ""
    function check(name, ok, detail) { ok ? console.log("CUE_PASS", name) : console.log("CUE_FAIL", name, JSON.stringify(detail ?? {})); }
    function after(ms, fn) {
        const timer = Qt.createQmlObject("import QtQuick; Timer {}", root);
        timer.interval = ms;
        timer.triggered.connect(() => { timer.destroy(); fn(); });
        timer.start();
    }
    function shot(name, then) {
        if (!root.shots) { then(); return; }
        stage.grabToImage(r => { r.saveToFile(root.shots + "/" + name + ".png"); then(); });
    }
    function named(name) {
        const walk = i => { if (!i) return null; if (i.objectName === name) return i; for (const c of i.children ?? []) { const f = walk(c); if (f) return f; } return null; };
        return walk(room.presentation.item);   // the view showing now
    }
    function set(usage, temp, usedGiB) {
        const history = [];
        for (let i = 0; i < 48; i++) history.push(Math.max(0.02, Math.min(1, usage * 0.7 + 0.25 * Math.sin(i / 4) * usage + 0.12 * Math.sin(i / 1.3))));
        fixture.system.cpu = { available: true, usage: usage, history: history, temperature: temp };
        fixture.system.memory = { available: true, total: 16 * 1048576, used: usedGiB * 1048576, history: [], swapTotal: 8 * 1048576, swapUsed: 0.2 * 1048576 };
    }
    CoreClient { id: core; path: "" }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    PaletteDomain {
        id: larimar
        available: true
        colors: ({ background: "#000000", surface: "#0a181c", surfaceRaised: "#152d36", text: "#e6f9fc", textMuted: "#a0dbe6",
                   textFaint: "#589dbb", line: "#20424f", accent: "#42c8d9", warm: "#f9e2af", danger: "#b4befe",
                   highlight: "#42c8d9", success: "#94e2d5", islandBackground: "#071114" })
    }
    FloatingWindow {
        implicitWidth: 1360; implicitHeight: 860; visible: true; color: "#000000"
        Item {
            id: stage; anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#000000" }
            Performance { id: room; anchors.fill: parent; anchors.margins: 30; host: fixture; shell: context }
        }
    }
    Component.onCompleted: {
        UI.Design.source = larimar;
        UI.Design.form = "fluid";
        fixture.system.gpu = { available: true, failed: false, usage: 0.35, temperature: 52, vramUsed: null, vramTotal: null, source: "fixture", error: "", history: [] };
        root.set(0.18, 48, 5.2);
        after(1200, () => {
            const star = named("performance.star");
            check("fluid.presented", !!star && !!named("performanceCore"), {});
            const cool = { r: star.starColour.r, b: star.starColour.b }, coolCore = named("performanceCore").width;   // a snapshot, not a live link
            check("readings", named("performance.cpu").text === "18" && named("performance.memory").text === "5.2"
                  && named("performance.temperature").text.indexOf("48°C") === 0, [named("performance.cpu").text, named("performance.memory").text]);
            check("companion.with.gpu", named("performanceCompanion").visible, {});
            check("calm.verdict", named("performance.verdict").text === "A quiet star.", named("performance.verdict").text);
            root.shot("fluid-perf-cool", () => {
                root.set(0.86, 88, 12.4);
                after(1400, () => {
                    check("hotter.is.bluer", star.starColour.b > cool.b && star.starColour.r <= cool.r, [cool, String(star.starColour)]);
                    check("memory.grows.the.star", named("performanceCore").width > coolCore, [coolCore, named("performanceCore").width]);
                    check("hot.verdict", named("performance.verdict").text.indexOf("Burning hot") === 0, named("performance.verdict").text);
                    star.cores = [0.9, 0.4, 1, 0.2, 0.7, 0.5, 0.95, 0.1];
                    star.planets = [{ name: "zen", rss: 2100 }, { name: "code", rss: 1400 }, { name: "spotify", rss: 600 }, { name: "kitty", rss: 300 }];
                    after(200, () => {
                        let shells = 0;
                        const walk = i => { if (!i) return; if (i.objectName === "performanceShells") shells = i.count; for (const c of i.children ?? []) walk(c); };
                        walk(room);
                        check("overdrive.layers.draw", shells === 8, shells);
                        root.shot("fluid-perf-hot", () => {
                            fixture.system.gpu = { available: false, failed: false, usage: 0, temperature: null, vramUsed: null, vramTotal: null, source: "", error: "No GPU", history: [] };
                            after(200, () => {
                                check("no.gpu.no.companion", !named("performanceCompanion").visible, {});
                                UI.Design.form = "angular";
                                after(600, () => {
                                    check("angular.keeps.readings", !named("performance.star") && room.readings[0].text === "86%", room.readings[0].text);
                                    console.log("CUE_DONE");
                                    Qt.quit();
                                });
                            });
                        });
                    });
                });
            });
        });
    }
}
