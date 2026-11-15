import QtQuick
import QtQuick.Window

// Swap presentation only. Controllers and subscriptions must live outside this host.
// The old view stays usable until its replacement is ready; obsolete requests never commit.
Item {
    id: root
    property Component presentation: null
    property bool firstShown: true
    readonly property Loader shown: firstShown ? first : second
    readonly property Loader pending: firstShown ? second : first
    readonly property Item item: shown.item
    readonly property bool loading: pending.sourceComponent !== null
    property string error: ""
    signal committed()
    implicitHeight: item?.implicitHeight ?? 0

    function containsItem(item) {
        for (let node = item; node; node = node.parent)
            if (node === root) return true;
        return false;
    }
    function focusName(item) {
        for (let node = item; node && node !== root; node = node.parent)
            if (node.objectName) return node.objectName;
        return "";
    }
    function named(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const result = named(child, name);
            if (result) return result;
        }
        return null;
    }
    function prepare() {
        error = "";
        if (!presentation || shown.sourceComponent === presentation) {
            pending.sourceComponent = null;
            return;
        }
        if (presentation.status === Component.Error) {
            pending.sourceComponent = null;
            error = "Could not change view";
            return;
        }
        pending.sourceComponent = presentation;
    }
    // A deferred step can run after the room is gone (a test tearing several rooms down at once): it then does nothing.
    property bool alive: true
    Component.onDestruction: alive = false
    function ready(slot) {
        // Defer to let geometry/bindings settle and coalesce rapid changes in the same turn.
        Qt.callLater(() => {
            if (!root.alive) return;
            if (slot !== root.pending || slot.status !== Loader.Ready || slot.sourceComponent !== root.presentation) return;
            const window = root.Window.window;
            const focus = window?.activeFocusItem;
            const key = root.containsItem(focus) ? root.focusName(focus) : "";
            const old = shown;
            firstShown = !firstShown;
            old.sourceComponent = null;
            const replacement = shown.item;
            const focusAfter = window?.activeFocusItem;
            Qt.callLater(() => {
                // Never take focus back from settings or a newer presentation.
                if (!root.alive || !key || root.item !== replacement || window?.activeFocusItem !== focusAfter) return;
                const control = root.named(replacement, key);
                if (control?.visible && control.enabled) control.forceActiveFocus(Qt.OtherFocusReason);
            });
            committed();
        });
    }
    onPresentationChanged: prepare()
    Component.onCompleted: prepare()
    Loader {
        id: first
        anchors.fill: parent
        asynchronous: true
        visible: root.firstShown
        enabled: visible
        onLoaded: root.ready(first)
        onStatusChanged: if (status === Loader.Error) { root.error = "Could not change view"; sourceComponent = null; }
    }
    Loader {
        id: second
        anchors.fill: parent
        asynchronous: true
        visible: !root.firstShown
        enabled: visible
        onLoaded: root.ready(second)
        onStatusChanged: if (status === Loader.Error) { root.error = "Could not change view"; sourceComponent = null; }
    }
}
