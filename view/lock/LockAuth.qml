pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock's password check (S7, docs/LOCK.md §3.2). PAM service `serpantinum` (Z37), `login` when that file is
// missing (Z125). Nested tests point FART_LOCK_PAM_DIR at tests/fixtures/nested/pam (zt-permit / zt-deny), so no
// system PAM file and no real password is involved. The secret is held only until PAM asks for it, then dropped;
// it is never logged. Anything but PamResult.Success is a refusal: an error never unlocks.
Scope {
    id: root
    property string configDirectory: Quickshell.env("FART_LOCK_PAM_DIR") || "/etc/pam.d"
    property string service: Quickshell.env("FART_LOCK_PAM_SERVICE") || "serpantinum"
    property bool serviceFound: true
    readonly property string config: serviceFound ? service : "login"
    readonly property bool busy: pam.active
    property string pending: ""
    signal accepted()
    signal rejected(string why)

    function submit(secret) {
        if (pam.active)
            return false;
        pending = secret;
        if (!pam.start()) {
            pending = "";
            rejected("PAM did not start");
            return false;
        }
        return true;
    }

    FileView {
        path: root.configDirectory + "/" + root.service
        printErrors: false
        onLoaded: root.serviceFound = true
        onLoadFailed: root.serviceFound = false
    }

    PamContext {
        id: pam
        config: root.config
        configDirectory: root.configDirectory
        onPamMessage: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success)
                root.accepted();
            else
                root.rejected(PamResult.toString(result));
        }
        onError: error => {
            root.pending = "";
            root.rejected(PamError.toString(error));
        }
    }
}
