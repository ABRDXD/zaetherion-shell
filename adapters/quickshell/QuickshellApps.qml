import QtQuick
import Quickshell
import qs.view.contract

// The installed apps from Quickshell's DesktopEntries (it watches the application folders, so the list follows
// installs). Who starts an app is the session's: `spawner.run(argv, workingDirectory)`, Hyprland's exec in the DMS
// session; without one, Quickshell starts it detached.
AppsDomain {
    id: root
    property var spawner: null
    readonly property var source: DesktopEntries.applications
    available: true
    entries: rows(source.values)

    function rows(values) {
        const seen = new Set();
        const out = [];
        for (const entry of values) {
            if (!entry || entry.noDisplay || !entry.id || seen.has(entry.id))
                continue;
            seen.add(entry.id);
            out.push({ id: entry.id, name: entry.name || entry.id, genericName: entry.genericName || "",
                       comment: entry.comment || "", icon: entry.icon ? Quickshell.iconPath(entry.icon, true) : "",
                       keywords: Array.from(entry.keywords || []), terminal: entry.runInTerminal === true });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }

    function run(argv: var): void {
        record("run", [argv]);
        const command = Array.from(argv || []).map(String);
        if (command.length === 0)
            return;
        if (spawner)
            spawner.run(command, "");
        else
            Quickshell.execDetached({ command: command, workingDirectory: Quickshell.env("HOME") });
    }

    function launch(id: string, terminal: string): void {
        record("launch", [id, terminal]);
        const entry = DesktopEntries.byId(id);
        if (!entry || !entry.command || entry.command.length === 0)
            return;
        const command = Array.from(entry.command);
        // Terminals take the program after -e (kitty, foot, alacritty, xterm).
        const argv = entry.runInTerminal && terminal ? [terminal, "-e"].concat(command) : command;
        if (spawner)
            spawner.run(argv, entry.workingDirectory || "");
        else
            Quickshell.execDetached({ command: argv, workingDirectory: entry.workingDirectory || Quickshell.env("HOME") });
    }
}
