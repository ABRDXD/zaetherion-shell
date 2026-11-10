import QtQuick

// An idle loop's gate (MONTAGE.md §4.5): `running` is true only while Overdrive's engine is engaged (Motion.drive,
// so through the spin-down too), while ambient motion is on, motion is not reduced and the scope can be seen, so
// every idle loop stops when the panel folds, the window hides or the engine reaches 0.
// Each running loop is reported to Motion.activeNames as "idle.<name>".
QtObject {
    id: root
    property Item scope: null
    property string name: "loop"
    property bool enabled: true
    readonly property bool running: enabled && Motion.engaged && Motion.ambient && Motion.live(scope)
    property Activity activity: Activity { name: "idle." + root.name; running: root.running }
}
