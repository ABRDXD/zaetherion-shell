pragma Singleton
import QtQuick
import Quickshell
Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string state: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"
    // fart-next keeps its own state until cutover so two views never write the same files.
    readonly property string fartState: Quickshell.env("FART_STATE_DIR") || state + "/fart"
}
