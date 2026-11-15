import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core.client
import qs.view.ui
import "IslandRestChoices.js" as Rest

// FART's Island tab (Z176, Z155, Z201): what shows at rest (a preset, or each item's own mode) and where the island
// sits (edge, placement, screen). Everything is the core's `island` topic, changed through the `island` verb, so the
// command line and this tab can never disagree. The design style (Angular or Fluid) stays beside the palette.
ColumnLayout {
    id: root
    required property CoreClient core
    property bool active: false
    spacing: Design.baseline * 3

    readonly property var island: core.islandData ?? null
    readonly property var rest: island?.rest ?? null
    readonly property string preset: Rest.presetOf(rest)
    property string error: ""
    // One `island …` line at a time, newest wish last (as StylePicker does for the form).
    property bool busy: false
    property string queued: ""
    // Without a core, the request answers "not connected", which shows as the error line.
    function run(line) {
        error = "";
        if (busy) {
            queued = line;
            return;
        }
        busy = true;
        core.request("cmd.run", { line: line, record: false }, (ok, reply) => {
            root.busy = false;
            const next = root.queued;
            root.queued = "";
            if (!ok || reply?.ok !== true)
                root.error = reply?.message || reply?.line || "Could not change the island";
            if (next)
                root.run(next);
        });
    }

    // ---- At rest.
    FText { text: "AT REST · HOVER SHOWS EVERYTHING"; technical: true; color: Design.accent }
    RowLayout {
        Layout.fillWidth: true
        spacing: Design.baseline * 2
        Repeater {
            model: ["today", "a", "b", "c"]
            FButton {
                required property string modelData
                objectName: "rest-preset-" + modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: (modelData === "today" ? "All" : modelData.toUpperCase()) + " · " + Rest.PRESET_NOTES[modelData]
                selected: root.preset === modelData
                enabled: root.rest !== null
                implicitHeight: Design.minHit
                onClicked: if (root.preset !== modelData) root.run("island rest " + modelData)
            }
        }
    }
    Repeater {
        model: [["power", "POWER"], ["network", "WI-FI"], ["battery", "BATTERY"], ["inbox", "NOTIFICATIONS"]]
        SettingChoices {
            required property var modelData
            Layout.fillWidth: true
            label: modelData[1]
            note: "matters: " + Rest.MATTERS[modelData[0]]
            enabled: root.rest !== null
            options: Rest.options(modelData[0])
            value: root.rest?.[modelData[0]]
            onPicked: value => root.run("island rest " + modelData[0] + " " + value)
        }
    }

    FRule { Layout.fillWidth: true }

    // ---- Where it sits.
    FText { text: "PLACE"; technical: true; color: Design.accent }
    SettingChoices {
        Layout.fillWidth: true
        label: "EDGE"
        enabled: root.island !== null
        options: [["top", "Top"], ["bottom", "Bottom"]]
        value: root.island?.edge
        onPicked: value => root.run("island " + value)
    }
    SettingChoices {
        Layout.fillWidth: true
        label: "PLACEMENT"
        note: "notch hugs the edge"
        enabled: root.island !== null
        options: [["notch", "Notch"], ["floating", "Floating"]]
        value: root.island?.placement
        onPicked: value => root.run("island " + value)
    }
    SettingChoices {
        Layout.fillWidth: true
        label: "SCREEN"
        enabled: root.island !== null
        options: [["", "Focused"]].concat(Quickshell.screens.filter(screen => screen.name).map(screen => [screen.name, screen.name]))
        value: root.island?.screen
        onPicked: value => root.run("island screen " + (value === "" ? "auto" : value))
    }
    FText {
        visible: root.error !== ""
        text: root.error
        technical: true
        color: Design.danger
    }
    Item { Layout.fillHeight: true }
}
