import qs.view.cues
import QtQuick

// The strata loader (D12, docs/OVERDRIVE.md §4): an Overdrive effect exists only while Overdrive's engine is
// engaged (Motion.engaged: the lease is active, or its spin-down has not reached rest), motion is not reduced,
// the effect is wanted and its scope can be seen. Otherwise the Loader is inactive, so the effect is destroyed,
// never just hidden, and its textures go with it. `gpu` effects (shaders) also need a GPU scene graph: the
// software renderer draws no shaders, so there they never load. Each loaded stratum is listed in Strata.live.
// `tier` is D3's: "panel" (T1, inside the panel), "clock" (T2) or "desktop" (T3).
Loader {
    id: root
    property string name: "stratum"
    property string tier: "panel"
    property bool wanted: true
    property bool gpu: true
    property Item scope: null
    readonly property bool hardware: GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
    active: wanted && Motion.engaged && !Motion.reduced && (!gpu || hardware) && (!scope || Motion.live(scope))
    asynchronous: true
    property string listed: ""
    onItemChanged: {
        if (listed !== "") Strata.remove(listed);
        listed = item ? root.tier + ":" + root.name : "";
        if (listed !== "") Strata.add(listed);
    }
    Component.onDestruction: if (listed !== "") Strata.remove(listed)
}
