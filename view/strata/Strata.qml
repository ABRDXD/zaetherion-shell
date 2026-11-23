pragma Singleton
import QtQuick
import Quickshell

// Which strata exist now (docs/OVERDRIVE.md §4): every Stratum adds its name while its item exists and removes it
// when destroyed. `fart status` reports it, and a release must leave it empty (M8's test).
Singleton {
    id: root
    property var live: []
    readonly property int count: live.length
    function add(name) { live = [...live, name]; }
    function remove(name) {
        const index = live.indexOf(name);
        if (index < 0) return;
        const names = live.slice();
        names.splice(index, 1);
        live = names;
    }
}
