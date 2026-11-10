import QtQuick
import Quickshell
import qs.view.overdrive
import qs.view.ui
import qs.view.strata
import qs.view.cues
import "tools/cuetest/AstraExhibitFixture.js" as Data
Scope {
    id: test
    property int stops: 0
    QtObject {
        id: fakeCore
        function request(op, args, callback) { callback(true, {}); }
        function notify(op, args) { if(op === "exhibit.stop") test.stops++; }
    }
    FloatingWindow {
        implicitWidth: 1280; implicitHeight: 800; visible: true
        color: Design.background
        Stratum {
            id: layer
            anchors.fill: parent
            gpu: false
            wanted: false
            sourceComponent: Exhibit { score: Data.score(); core: fakeCore }
        }
        ExhibitFilm { id: film; anchors.fill: parent; score: Data.score() }
    }
    property int step: 0
    Timer {
        interval: 700; running: true; repeat: true
        onTriggered: {
            if(step===0) film.seek(8);
            if(step===1) film.grabToImage(r=>r.saveToFile("/tmp/astra-exhibit.png"));
            if(step===2) film.seek(17);
            if(step===3) film.grabToImage(r=>r.saveToFile("/tmp/astra-exhibit-late.png"));
            if(step===4) { Motion.overdrive=true; layer.wanted=true; }
            if(step===5) {
                console.log(layer.item ? "CUE_PASS stratum.loaded" : "CUE_FAIL stratum.loaded");
                layer.wanted=false;
            }
            if(step===6) {
                console.log(test.stops===1 ? "CUE_PASS stratum.destroyed" : "CUE_FAIL stratum.destroyed");
                Motion.reduced=true; layer.wanted=true;
            }
            if(step===7) {
                console.log(layer.item===null ? "CUE_PASS stratum.reduced" : "CUE_FAIL stratum.reduced");
                console.log("CUE_DONE");Qt.quit();
            }
            step++;
        }
    }
}
