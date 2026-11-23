//@ pragma Env QS_NO_RELOAD_POPUP=1
// The frozen-screen selector (Z48, Z221), started by the core for one shot and gone when it answers.
// ZAE_SELECTOR_SPEC names a JSON file: {frozen, origin: {x, y}, scale, scales: {name: scale}, mode, screens: [name],
// active: name, windows: [{x, y, width, height}], out}. Mode "record" (no frozen grab) is Viewfinder over the live
// desktop; "region" and "window" are Eclipse over the grab. A window opens on each listed screen (every screen when the list is missing).
// `active` (the focused monitor) leads until the pointer moves; a drag keeps its screen until release.
// The answer is written to `out`: slurp's "x,y wxh" in layout coordinates, or "cancel".
import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.selector

ShellRoot {
    id: root
    property var spec: null
    property bool answered: false
    property string activeScreen: ""
    property string dragScreen: ""

    function finish(answer) {
        if (answered)
            return;
        answered = true;
        answerFile.setText(answer + "\n");
        Qt.quit();
    }

    FileView {
        path: Quickshell.env("ZAE_SELECTOR_SPEC") || ""
        blockLoading: true
        onLoaded: {
            try {
                root.spec = JSON.parse(text());
                root.activeScreen = root.spec.active || "";
            } catch (error) {
                console.warn("selector: unreadable spec", error);
                Qt.exit(2);
            }
        }
        onLoadFailed: error => { console.warn("selector: no spec", error); Qt.exit(2); }
    }
    FileView {
        id: answerFile
        path: root.spec ? root.spec.out : ""
        preload: false // written once, never read
        blockWrites: true
        atomicWrites: true
    }

    readonly property var screens: root.spec ? Quickshell.screens.filter(s => !root.spec.screens || root.spec.screens.includes(s.name)) : []
    readonly property bool live: root.spec !== null && root.spec.mode === "record"

    Variants {
        model: root.live ? root.screens : []
        LiveSelector {
            required property var modelData
            screen: modelData
            stage.sourceScale: (root.spec.scales || {})[modelData.name] || 1
            stage.active: root.dragScreen ? root.dragScreen === modelData.name
                : root.activeScreen === modelData.name || !root.activeScreen
            stage.onEntered: if (!root.dragScreen) root.activeScreen = modelData.name
            stage.onDraggingChanged: root.dragScreen = stage.dragging ? modelData.name : ""
            onPicked: answer => root.finish(answer)
            onCancelled: root.finish("cancel")
        }
    }
    Variants {
        model: root.spec && !root.live ? root.screens : []
        FrozenSelector {
            required property var modelData
            screen: modelData
            stage.frozen: root.spec.frozen
            stage.origin: root.spec.origin
            stage.sourceScale: root.spec.scale
            stage.mode: root.spec.mode
            stage.windows: root.spec.windows || []
            stage.active: root.dragScreen ? root.dragScreen === modelData.name
                : root.activeScreen === modelData.name || !root.activeScreen
            stage.dragElsewhere: root.dragScreen !== "" && root.dragScreen !== modelData.name
            stage.onEntered: if (!root.dragScreen) root.activeScreen = modelData.name
            stage.onDraggingChanged: root.dragScreen = stage.dragging ? modelData.name : ""
            onPicked: answer => root.finish(answer)
            onCancelled: root.finish("cancel")
        }
    }
}
