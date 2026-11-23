import QtQuick
import qs.view.cues
import qs.view.ui

// Z174 (owner, 13 November 2026): while FART is grown from the island it covers the island, so a volume, mic or
// brightness change shows in FART's header instead of waiting for the fold: the island's OSD face compacted to
// one line (glyph, kind, blades, percent or MUTED) on a small island silhouette exactly the header row's height,
// over the header's middle. It drops in from FART's top edge, updates in place, and the island decides how long
// it stays (1.2 s after the last change). No flash and no card: that is the critical path (Z161, FartAlertDrop).
Item {
    id: root
    // The OSD event the island hands over ({ kind, level, muted }), or null.
    property var event: null
    // The header row, in this item's coordinates (Shell.headerTop, Shell.headerHeight), and the span the readout
    // centres on and stays within (Shell.headerSlotX, headerSlotWidth: the command line, never the buttons).
    property real headerTop: 0
    property real headerHeight: 32
    property real slotX: 0
    property real slotWidth: width
    property bool systemVoice: true
    readonly property bool showing: !!shown

    // The readout keeps the last level while it slides back up.
    property var shown: null
    onEventChanged: if (event) shown = event
    Cue {
        id: drop
        on: !!root.event
        scope: root
        name: "fart.osd"
        enter: Design.fluid ? Motion.navigate : Motion.cutDuration(root.headerTop + root.headerHeight, 0, false)
        exit: Design.fluid ? Motion.feedback : Motion.cutDuration(root.headerTop + root.headerHeight, 0, true)
        easing: Design.fluid ? Motion.standard : Motion.cutIn
        exitEasing: Design.fluid ? Motion.standard : Motion.cutOut
        onSettled: if (!on) root.shown = null
    }

    readonly property string glyph: {
        const kind = shown?.kind ?? "";
        if (kind === "mic") return shown.muted ? "mic_off" : "mic";
        if (kind === "brightness") return "brightness_medium";
        if (kind === "volume") return shown.muted ? "volume_off" : "volume_up";
        return "tune";
    }
    function voice(line: string): string {
        if (systemVoice) return line;
        const clean = line.replace(/^>\s*/, "").toLowerCase();
        return clean.charAt(0).toUpperCase() + clean.slice(1);
    }

    // From FART's top edge to the bottom of the header row, clipped: the plate drops out of the edge into the row
    // as the island drops from the screen's, and never shows below the row.
    Item {
        id: well
        x: root.slotX + (root.slotWidth - width) / 2
        width: Math.min(90 * Design.baseline, root.slotWidth)
        height: root.headerTop + root.headerHeight
        clip: true
        visible: !!root.shown
        Item {
            id: plate
            objectName: "fartHeaderOsd"
            width: parent.width
            height: root.headerHeight
            y: -height + drop.value * (root.headerTop + height)
            IslandFrame {
                id: frame
                anchors.fill: parent
                fill: Design.islandFill
            }
            Item {
                anchors.fill: parent
                anchors.leftMargin: frame.shoulderRun + frame.ear + 3 * Design.baseline
                anchors.rightMargin: anchors.leftMargin
                MaterialSymbol {
                    id: glyph
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    fill: Design.iconFill
                    weight: Design.iconWeight
                    text: root.glyph
                    iconSize: Design.statusIcon
                    color: Design.ink
                }
                FText {
                    id: label
                    anchors.left: glyph.right
                    anchors.leftMargin: 2 * Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    // Wide enough for "> MICROPHONE", so the blades keep their length across kinds.
                    width: 23 * Design.baseline
                    text: root.voice("> " + (root.shown?.kind === "mic" ? "MICROPHONE" : root.shown?.kind ?? ""))
                    font.capitalization: root.systemVoice ? Font.AllUppercase : Font.MixedCase
                    color: Design.accent
                    technical: true
                }
                FText {
                    id: reading
                    objectName: "fartHeaderOsdReading"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * Design.baseline
                    horizontalAlignment: Text.AlignRight
                    headline: true
                    sheared: !Design.fluid
                    font.weight: Font.Bold
                    font.pixelSize: Design.readout
                    text: root.shown?.muted ? "MUTED" : Math.round((root.shown?.level ?? 0) * 100) + "%"
                }
                FBlades {
                    anchors.left: label.right
                    anchors.leftMargin: 2 * Design.baseline
                    anchors.right: reading.left
                    anchors.rightMargin: 3 * Design.baseline
                    anchors.verticalCenter: parent.verticalCenter
                    blades: 16
                    level: root.shown?.level ?? 0
                    muted: !!root.shown?.muted
                }
            }
        }
    }
}
