import QtQuick
import Quickshell
import qs.adapters.quickshell
import "../adapters/hyprland/HyprlandExec.js" as HyprlandExec

// S6: the apps domain over Quickshell's DesktopEntries, against the test's own application folder (synthetic
// entries only). The spawner records instead of starting anything.
ShellRoot {
    id: root
    property var spawned: []
    function check(ok: bool, name: string): void {
        console.log((ok ? "APPS_PASS " : "APPS_FAIL ") + name);
    }
    QtObject {
        id: recorder
        function run(argv, workingDirectory) { root.spawned = root.spawned.concat([{ argv: argv, dir: workingDirectory }]); }
    }
    QuickshellApps { id: apps; spawner: recorder }

    Timer {
        // DesktopEntries scans the folders after start-up.
        interval: 50; repeat: true; running: true
        property int tries: 0
        onTriggered: {
            if (apps.entries.length < 3 && ++tries < 100)
                return;
            running = false;
            root.verify();
            Qt.quit();
        }
    }

    function verify() {
        const ids = apps.entries.map(e => e.id);
        check(JSON.stringify(ids) === JSON.stringify(["zt-editor", "zt-monitor", "zt-viewer"]), "listed by name, hidden left out " + JSON.stringify(ids));
        const editor = apps.entries[0];
        check(editor.name === "Alpha Editor" && editor.genericName === "Text Editor" && editor.comment === "Edits text"
              && JSON.stringify(editor.keywords) === JSON.stringify(["write", "notes"]) && editor.terminal === false, "fields mapped");
        check(apps.entries[1].terminal === true, "terminal flag");
        check(apps.available, "available");

        apps.launch("zt-editor", "kitty");
        const first = spawned[0];
        check(first && JSON.stringify(first.argv) === JSON.stringify(["zt-edit", "--new"]) && first.dir === "/tmp", "field codes dropped, working folder kept " + JSON.stringify(first));
        apps.launch("zt-monitor", "kitty");
        check(spawned[1] && JSON.stringify(spawned[1].argv) === JSON.stringify(["kitty", "-e", "zt-top"]), "terminal app runs in the terminal");
        apps.launch("zt-monitor", "");
        check(spawned[2] && JSON.stringify(spawned[2].argv) === JSON.stringify(["zt-top"]), "no terminal given: the program alone");
        apps.launch("missing", "kitty");
        check(spawned.length === 3, "an unknown id starts nothing");

        check(HyprlandExec.line(["a b", "it's"], "") === "exec 'a b' 'it'\\''s'", "words quoted for the shell");
        check(HyprlandExec.line(["x"], "/w d") === "cd '/w d' && exec 'x'", "working folder first");
        check(HyprlandExec.line(["echo", "$HOME;rm"], "") === "exec 'echo' '$HOME;rm'", "nothing expands");
        check(HyprlandExec.luaString('a"b\\c\nd') === '"a\\"b\\\\c\\010d"', "Lua string escaped " + HyprlandExec.luaString('a"b\\c\nd'));
        check(HyprlandExec.dispatch(["x"], "") === 'hl.dsp.exec_cmd("exec \'x\'")', "dispatch is a Lua call");
    }
}
