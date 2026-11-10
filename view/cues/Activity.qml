import QtQuick

// Reports one running animation to Motion.activeNames, at most once, including on destruction.
QtObject {
    id: root
    property string name: "motion"
    property bool running: false
    property bool counted: false
    onRunningChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Motion.end(name)
    function sync() {
        if (running === counted) return;
        counted = running;
        if (running) Motion.begin(name); else Motion.end(name);
    }
}
