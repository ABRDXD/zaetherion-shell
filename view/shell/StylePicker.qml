import QtQuick
import QtQuick.Layouts
import qs.core.client
import qs.view.ui

ColumnLayout {
    id: root
    required property CoreClient core
    readonly property string selected: core.islandData?.form ?? Design.form
    property bool busy: false
    property string queuedForm: ""
    property int requestSerial: 0
    property string error: ""
    function choose(form) {
        if (!core.connected || !["angular", "fluid"].includes(form)) return;
        error = "";
        // A pending command may change the form before its reply. Keep the latest intent.
        if (busy) { queuedForm = form; return; }
        if (form === selected) return;
        send(form);
    }
    function send(form) {
        const serial = ++requestSerial;
        busy = true;
        core.request("cmd.run", {line: "island " + form, record: false}, (ok, reply) => {
            if (serial !== requestSerial) return;
            busy = false;
            const next = queuedForm;
            queuedForm = "";
            if (next && next !== form && core.connected) { send(next); return; }
            if (!ok || reply?.ok !== true) error = reply?.message || reply?.line || "Could not change design style";
        });
    }
    Connections {
        target: root.core
        function onConnectedChanged() {
            if (root.core.connected) return;
            root.requestSerial++;
            root.busy = false;
            root.queuedForm = "";
        }
    }
    FText { text: "DESIGN STYLE"; technical: true; color: Design.accent }
    RowLayout {
        Layout.fillWidth: true
        FButton {
            objectName: "style.angular"
            Layout.fillWidth: true
            label: "Angular"
            selected: root.selected === "angular"
            enabled: root.core.connected
            onClicked: root.choose("angular")
        }
        FButton {
            objectName: "style.fluid"
            Layout.fillWidth: true
            label: "Fluid"
            selected: root.selected === "fluid"
            enabled: root.core.connected
            onClicked: root.choose("fluid")
        }
    }
    FText { Layout.fillWidth: true; visible: root.error !== ""; text: root.error; wrapMode: Text.Wrap; color: Design.danger }
}
