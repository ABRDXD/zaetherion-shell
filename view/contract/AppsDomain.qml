// The installed apps (S6, docs/S6_LAUNCHER.md §4), as plain rows the view hands to the core for ranking:
// { id, name, genericName, comment, icon (a source an Image can show, or ""), keywords, terminal (bool) }.
// Apps the host marks as hidden are left out. The list is replaced, never mutated, when apps come or go.
HostDomain {
    property var entries: []
    // Starts the app the core allowed (`launcher.launch`); terminal is the program to run it in, or "" for none.
    function launch(id: string, terminal: string): void { record("launch", [id, terminal]); }
}
