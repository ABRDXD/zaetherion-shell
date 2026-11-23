import QtQuick

// A button for something that can't be undone from FART (forget a network, forget a device): the first click arms it
// and a second click within `window` ms confirms; otherwise it disarms by itself (ConfirmArm). Behaviour only; it
// draws as an FButton, danger-coloured while armed. Set `verb` ("Forget"), not `label`.
FButton {
    id: root
    property string verb: ""
    property string armedVerb: verb + "?"
    property alias window: arm.window
    readonly property alias armed: arm.armed
    signal confirmed()
    danger: armed
    label: armed ? armedVerb : verb
    onClicked: arm.press()
    onEnabledChanged: if (!enabled) arm.cancel()
    ConfirmArm { id: arm; onConfirmed: root.confirmed() }
}
