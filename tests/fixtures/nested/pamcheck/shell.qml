import QtQuick
import Quickshell
import Quickshell.Services.Pam
// Fake PAM check (Z109): private PAM configs from ZT_PAM_DIR, never the system's.
// Prints "PERMIT <n>" and "DENY <n>" (0 = Success) and quits.
ShellRoot {
  property int done: 0
  function fin(tag, r) { console.log("ZT", tag, r); if (++done === 2) Qt.quit() }
  PamContext { id: permit; configDirectory: Quickshell.env("ZT_PAM_DIR"); config: "zt-permit"
    onCompleted: r => fin("PERMIT", r); onError: e => fin("PERMIT-ERROR", e) }
  PamContext { id: deny; configDirectory: Quickshell.env("ZT_PAM_DIR"); config: "zt-deny"
    onCompleted: r => fin("DENY", r); onError: e => fin("DENY-ERROR", e) }
  Component.onCompleted: { permit.start(); deny.start() }
}
