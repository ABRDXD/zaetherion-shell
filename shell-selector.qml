//@ pragma Env QS_NO_RELOAD_POPUP=1
// The frozen-screen selector (Z48, Z221), started by the core for one shot and gone when it answers.
// ZAE_SELECTOR_SPEC names a JSON file: {frozen, origin: {x, y}, scale, mode, screens: [name], windows: [{x, y, width,
// height}], out}. A window opens on each listed screen (every screen when the list is missing).
// The answer is written to `out`: slurp's "x,y wxh" in layout coordinates, or "cancel".
import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.selector

ShellRoot {
    id: root
    property var spec: null
    property bool answered: false

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
        blockWrites: true
        atomicWrites: true
    }

    Variants {
        model: root.spec ? Quickshell.screens.filter(s => !root.spec.screens || root.spec.screens.includes(s.name)) : []
        FrozenSelector {
            required property var modelData
            screen: modelData
            stage.frozen: root.spec.frozen
            stage.origin: root.spec.origin
            stage.sourceScale: root.spec.scale
            stage.mode: root.spec.mode
            stage.windows: root.spec.windows || []
            onPicked: answer => root.finish(answer)
            onCancelled: root.finish("cancel")
        }
    }
}
