pragma Singleton
import QtQuick
import Quickshell

// FART's own commands. M2 moves these behind the core socket.
Singleton {
    // The FART-native repository has no upstream to merge; this reports its Git state.
    function updateReport() {
        Quickshell.execDetached(["kitty", "--hold", Quickshell.shellPath("tools/fart_next.py"), "update"]);
        Host.close();
    }
}
