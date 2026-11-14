import QtQuick

// A button for something that can't be undone from FART (forget a network, forget a device): the first click arms it
// and a second click within `window` ms confirms; otherwise it disarms by itself. Behaviour only; it draws as an
// FButton, danger-coloured while armed. Set `verb` ("Forget"), not `label`.
FButton {
    id: root
    property string verb: ""
    property string armedVerb: verb + "?"
    property int window: 3000
    property bool armed: false
    signal confirmed()
    danger: armed
    label: armed ? armedVerb : verb
    onClicked: {
        if (armed) { armed = false; disarm.stop(); confirmed(); }
        else { armed = true; disarm.restart(); }
    }
    onEnabledChanged: if (!enabled) armed = false
    Timer { id: disarm; interval: root.window; onTriggered: root.armed = false }
}
