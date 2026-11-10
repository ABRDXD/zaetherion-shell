import QtQuick

// What a room may know about the view around it. Host state comes from the adapter, not from here.
QtObject {
    property bool panelOpen: false
    property bool wideLayout: Host.wide
    property string engagedTimerKind: "countdown"
    property var core: null
    function close() { Host.close(); }
    function openHost(target: string) { Host.openHost(target); }
    function toggleLayout() { Host.toggleLayout(); }
    function toggleActiveTimer() { core?.timers.toggle(engagedTimerKind); }
}
