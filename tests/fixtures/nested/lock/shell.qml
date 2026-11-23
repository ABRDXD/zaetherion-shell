import QtQuick
import Quickshell
import Quickshell.Wayland
// Fake lock for nested tests: locks the nested compositor and unlocks itself after
// ZT_UNLOCK_MS (default 4000). No PAM, no input.
ShellRoot {
  WlSessionLock {
    id: lock
    locked: true
    WlSessionLockSurface {
      color: "#200030"
      Text { anchors.centerIn: parent; text: "ZÆTHERION nested lock test"; color: "white"; font.pixelSize: 40 }
    }
  }
  Timer {
    interval: parseInt(Quickshell.env("ZT_UNLOCK_MS") || "4000")
    running: true
    onTriggered: { lock.locked = false; Qt.quit() }
  }
}
