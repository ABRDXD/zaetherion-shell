import qs.view.ui
import qs.view.cues
import qs.view.strata
import QtQuick

// The room's sheet (MONTAGE.md §4): a plane the size of the field with the room's cut wedge on one edge
// (its side, span and alignment from Shell.cuts) and register marks in the corners. The live room is laid
// over it by the Shell, clear of the wedge. Rooms used to sit on a lattice of these; the orbit replaced
// the lattice (docs/ORBIT.md §4), so there is one sheet, the shown room's.
Item {
    id: root
    required property var entry
    required property var plan
    required property string number
    property real cut: 150
    // The room's viewport, for the title under load (LiveTitle): passed by the mount, or else the sheet's
    // sibling that scrolls (the Shell lays the room's Flickable over the sheet, in the same stage).
    property Item viewport: null
    readonly property Item roomViewport: viewport ?? findViewport()
    // The sheet stratum's KeepOut of the same viewport, lent to the sundial so the room is captured once (the Shell).
    property Item sharedMask: null
    // The journey, for the sheet's wear: passed by the mount, or else read through the room the viewport carries.
    property var journey: undefined
    readonly property var roomJourney: journey !== undefined ? journey : (roomCore?.journeyData ?? null)
    property var roomCore: null
    function findCore(item, depth) {
        if (!item || depth > 3)
            return null;
        if (item.shell?.core)
            return item.shell.core;
        for (const c of item.children ?? []) {
            const found = findCore(c, depth + 1);
            if (found)
                return found;
        }
        return null;
    }
    Timer {
        interval: 1000
        repeat: true
        running: Motion.engaged && root.journey === undefined && !root.roomCore && root.roomViewport !== null
        triggeredOnStart: true
        onTriggered: root.roomCore = root.findCore(root.roomViewport?.contentItem ?? null, 0)
    }
    function findViewport() {
        void parent;
        for (const c of parent?.children ?? [])
            if (c !== root && c.contentItem && c.contentY !== undefined && typeof c.flick === "function")
                return c;
        return null;
    }
    readonly property bool leftSide: (plan.side ?? "left") === "left"
    Accessible.name: entry.name
    Accessible.description: entry.about ?? ""

    Rectangle {
        anchors.fill: parent
        color: Qt.tint(Design.background, Qt.alpha(Design.surface, 0.18))
        border.width: 1
        border.color: Qt.alpha(Design.line, 0.35)
    }
    // How far the sheet has swelled in the heat (Overdrive, §47): the register marks move out by it.
    readonly property real swell: cockle.item?.swell ?? 0
    Repeater {
        model: 4
        Register {
            required property int index
            x: (index % 2 ? root.width - width : 0) + (index % 2 ? -8 + root.swell : 8 - root.swell)
            y: (index > 1 ? root.height - height : 0) + (index > 1 ? -8 + root.swell : 8 - root.swell)
            color: Qt.alpha(Design.faint, 0.6)
        }
    }
    // Overdrive: the sheet handled as much as the room is lived in (docs/OVERDRIVE.md §41), under the title and the room.
    Stratum {
        name: "sheet.wear"
        gpu: false
        scope: root
        anchors.fill: parent
        sourceComponent: SheetWear {
            roomId: root.entry.id ?? ""
            wedgeLeft: root.leftSide
            journey: root.roomJourney
        }
    }
    // Overdrive: the sheet cockles in the processor's heat (docs/OVERDRIVE.md §47).
    Stratum {
        id: cockle
        name: "sheet.cockle"
        gpu: false
        scope: root
        anchors.fill: parent
        sourceComponent: SheetCockle { core: root.roomCore }
    }
    // Overdrive: the room's content casts a shadow from where the sun (or the moon) really is (docs/OVERDRIVE.md §43).
    Stratum {
        name: "sheet.sundial"
        scope: root
        wanted: !!root.roomViewport
        x: (root.roomViewport?.x ?? 0) - root.x
        y: (root.roomViewport?.y ?? 0) - root.y
        width: root.roomViewport?.width ?? 0
        height: root.roomViewport?.height ?? 0
        sourceComponent: Sundial {
            viewport: root.roomViewport
            shared: root.sharedMask
            core: root.roomCore
        }
    }
    CutTitle {
        id: cutTitle
        x: root.leftSide ? 0 : root.width - width
        width: root.cut
        height: root.height
        side: root.leftSide ? "left" : "right"
        span: root.plan.span ?? 1
        align: root.plan.align ?? "top"
        text: root.entry.name
        number: root.number
        voice: root.entry.voice ?? ""
        live: true
    }
    // Overdrive: the title as type under load (docs/OVERDRIVE.md §35, atlas #41–44).
    Stratum {
        name: "title.type"
        gpu: false
        scope: root
        // Exactly CutTitle's frame: a Loader with a size sizes its item, and the title is clipped to the wedge.
        x: cutTitle.x
        y: cutTitle.y
        width: cutTitle.width
        height: cutTitle.height
        sourceComponent: LiveTitle {
            title: cutTitle
            viewport: root.roomViewport
            roomId: root.entry.id ?? ""
        }
    }
}
