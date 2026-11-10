import QtQuick
import qs.view.cues
import qs.view.overdrive
Item {
    id: root
    Cue {
        id: decay
        scope: root
        name: "eigenmode"
        enter: 2800
        exit: 0
        easing: Easing.Linear
        onValueChanged: Eigenmode.phase=value
    }
    Connections {
        target: Eigenmode
        function onStruck() { decay.on=false;decay.settle();decay.on=true; }
    }
    Component.onDestruction: Eigenmode.phase=1
}
