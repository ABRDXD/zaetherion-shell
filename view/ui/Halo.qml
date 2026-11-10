import qs.view.cues
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

// The halo: a tilted orbit, after the host's hourly arc around its clock. The entries ride a dashed
// ellipse seen from above, as tall leaning pills; depth follows the orbit, so pills in front are larger,
// more opaque and drawn over the centre, and pills behind pass under it. The selected entry is the
// accent-filled pill at the front, with its reading large in the centre (the room's own content, the
// default property). Choosing a pill swaps it with the front one: only those two move (D12), through
// one Cue. Nothing runs at rest; a reading that changes rebinds its pill once.
//
// model: [{ label, text, value (0–1, or < 0 for none), hot, available }]. The Repeater is keyed by the
// model's length, so new readings rebind the pills instead of recreating them (focus survives).
Item {
    id: root
    property var model: []
    property int currentIndex: 0
    // The orbit's height as a share of its width (the tilt), and the pills' size at the front.
    property real tilt: 0.46
    property real pillHeight: Math.max(64, Math.min(100, width * 0.19))
    readonly property real pillWidth: Math.round(pillHeight * 0.6)
    property color accent: Design.accent
    // How far the centre stands above the middle of the orbit, in pill heights.
    property real centreLift: 0.22
    // The centre's content (the room's readout for `current`).
    default property alias centre: centreItem.data
    readonly property var current: model[currentIndex] ?? null
    readonly property int count: model.length
    // Depth scale and opacity, back (0) to front (1).
    readonly property real nearScale: 1.1
    readonly property real farScale: 0.72
    readonly property real farOpacity: 0.55
    readonly property real rx: Math.max(0, (width - pillWidth * nearScale) / 2)
    readonly property real ry: Math.max(0, Math.min(rx * tilt, (height - pillHeight * nearScale) / 2))
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // The front of the orbit (90°: nearest the viewer) is the selected entry's place.
    readonly property real front: Math.PI / 2
    // slots[i] is entry i's place on the orbit (0 … count − 2), or −1 for the front.
    property var slots: []
    // The last swap: `incoming` left slot `slot` for the front and `outgoing` took that slot.
    property int incoming: -1
    property int outgoing: -1
    property int held: -1
    readonly property real swapping: swap.value

    signal activated(int index)

    // The others share the rest of the orbit evenly, starting clockwise from the front.
    function slotAngle(slot) {
        return slot < 0 ? front : front + drift + 2 * Math.PI * (slot + 1) / Math.max(1, count);
    }
    // Idle sway (MONTAGE.md §4.5): the pills behind the front one drift back and forth along the orbit,
    // as the host's orbit does; the front pill stays put. Stopped whenever the halo cannot be seen.
    readonly property real drift: 0.16 * Math.sin(2 * Math.PI * sway.phase)
    IdleLoop { id: sway; scope: root; name: "halo"; period: 12800 }
    function onOrbit(angle) {
        return Qt.point(cx + Math.cos(angle) * rx, cy + Math.sin(angle) * ry);
    }
    // Entry i's centre point. Mid-swap the chosen pill rides the orbit to the front the short way, and
    // the old front cuts across inside the orbit to the chosen slot, so the two never meet.
    function placeOf(i) {
        const t = swap.value;
        if (i === incoming) {
            const from = slotAngle(slots[outgoing] ?? 0);
            let turn = (front - from) % (2 * Math.PI);
            if (turn > Math.PI) turn -= 2 * Math.PI;
            if (turn < -Math.PI) turn += 2 * Math.PI;
            return onOrbit(from + turn * t);
        }
        if (i === outgoing) {
            const a = onOrbit(front);
            const b = onOrbit(slotAngle(slots[i] ?? 0));
            return Qt.point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
        }
        return onOrbit(slotAngle(slots[i] ?? 0));
    }
    function depthAt(y) {
        return ry > 0 ? Math.max(0, Math.min(1, ((y - cy) / ry + 1) / 2)) : 1;
    }
    function resetSlots() {
        const next = [];
        let slot = 0;
        for (let i = 0; i < count; i++)
            next.push(i === currentIndex ? -1 : slot++);
        slots = next;
        held = currentIndex;
        incoming = outgoing = -1;
    }
    // A new selection trades places with the old one; nothing else moves.
    function trade() {
        // A swap still in flight lands first, so the next one starts from rest.
        swap.settle();
        if (slots.length !== count || held < 0 || held >= count) {
            resetSlots();
            return;
        }
        if (currentIndex === held || currentIndex < 0 || currentIndex >= count)
            return;
        const next = slots.slice();
        next[held] = next[currentIndex];
        next[currentIndex] = -1;
        incoming = currentIndex;
        outgoing = held;
        held = currentIndex;
        slots = next;
        swap.replay();
    }
    // Entry i's pill, or the centre, as a rect in the halo's coordinates, for rooms that grow something
    // out of it. Read it in `activated`: the chosen pill has not moved yet then.
    function pillRect(i) {
        const pill = satellites.itemAt(i);
        return pill ? pill.mapToItem(root, 0, 0, pill.width, pill.height) : centreRect();
    }
    function centreRect() {
        return centreItem.mapToItem(root, 0, 0, centreItem.width, centreItem.height);
    }
    function select(i) {
        if (i === currentIndex)
            return;
        const focused = satellites.itemAt(i)?.activeFocus ?? false;
        const previous = currentIndex;
        currentIndex = i;
        activated(i);
        // The keyboard stays where it was: the old selection now sits in the slot that was chosen.
        if (focused)
            satellites.itemAt(previous)?.forceActiveFocus(Qt.TabFocusReason);
    }

    onCountChanged: resetSlots()
    onCurrentIndexChanged: trade()
    Component.onCompleted: resetSlots()
    implicitWidth: 520
    implicitHeight: 360

    Cue {
        id: swap
        name: "halo.swap"
        on: true
        scope: root
        enter: Motion.swap
        easing: Motion.roles.swap.easing
        onSettled: root.incoming = root.outgoing = -1
    }

    // The orbit, dashed, with the selected entry's reading lit along it from the front, clockwise as seen
    // from above. It is drawn in two halves: the far half (and the plate inside it) behind the centre, the
    // near half in front of it, so the ring passes behind the centre's content and then before it.
    readonly property real sweep: 360 * (current?.available === false ? 0 : Math.max(0, Math.min(1, current?.value ?? -1)))
    readonly property color sweepColor: current?.hot ? Design.danger : accent
    Shape {
        anchors.fill: parent
        z: -200
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: Qt.alpha(Design.surface, 0.45)
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.cx
                centerY: root.cy
                radiusX: root.rx
                radiusY: root.ry
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: Qt.alpha(root.accent, 0.5)
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 6]
            PathAngleArc {
                centerX: root.cx
                centerY: root.cy
                radiusX: root.rx
                radiusY: root.ry
                startAngle: 180
                sweepAngle: 180
            }
        }
        ShapePath {
            strokeColor: root.sweepColor
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.cx
                centerY: root.cy
                radiusX: root.rx
                radiusY: root.ry
                startAngle: 180
                sweepAngle: Math.max(0, Math.min(180, root.sweep - 90))
            }
        }
    }
    Shape {
        anchors.fill: parent
        z: 0.5
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(root.accent, 0.5)
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 6]
            PathAngleArc {
                centerX: root.cx
                centerY: root.cy
                radiusX: root.rx
                radiusY: root.ry
                startAngle: 0
                sweepAngle: 180
            }
        }
        ShapePath {
            strokeColor: root.sweepColor
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.cx
                centerY: root.cy
                radiusX: root.rx
                radiusY: root.ry
                startAngle: 90
                sweepAngle: Math.min(90, root.sweep)
            }
        }
        ShapePath {
            strokeColor: root.sweepColor
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.cx
                centerY: root.cy
                radiusX: root.rx
                radiusY: root.ry
                startAngle: 0
                sweepAngle: Math.max(0, Math.min(90, root.sweep - 270))
            }
        }
    }
    // The centre stands above the middle of the orbit, clear of the front pill.
    Item {
        id: centreItem
        x: root.cx - width / 2
        y: root.cy - root.pillHeight * root.centreLift - height / 2
        width: root.rx * 1.2
        height: Math.max(0, root.ry * 2 + root.pillHeight * 0.3)
        z: 0
        // The new reading arrives with the swap; at rest this is 1.
        opacity: root.incoming >= 0 ? root.swapping : 1
        scale: root.incoming >= 0 ? 0.94 + 0.06 * root.swapping : 1
    }
    Repeater {
        id: satellites
        model: root.count
        AbstractButton {
            id: pill
            required property int index
            readonly property var entry: root.model[index] ?? ({})
            readonly property bool selected: root.slots[index] === -1
            // The swap fills the arriving pill and empties the leaving one.
            readonly property real fill: index === root.incoming ? root.swapping : index === root.outgoing ? 1 - root.swapping : selected ? 1 : 0
            readonly property point place: root.placeOf(index)
            readonly property real depth: root.depthAt(place.y)
            readonly property real fraction: entry.available === false ? -1 : entry.value ?? -1
            readonly property color ink: fill > 0.5 ? (Design.onSignal ?? Design.background) : entry.hot ? Design.danger : Design.ink
            width: root.pillWidth
            height: root.pillHeight
            x: place.x - width / 2
            y: place.y - height / 2
            // Front pills over the centre, back pills under it; the old front passes under on its way out.
            z: index === root.outgoing ? -100 : (depth - 0.5) * 200 + (selected ? 1 : 0)
            scale: (root.farScale + (root.nearScale - root.farScale) * depth) * (hovered && !selected ? 1.04 : 1)
            opacity: root.farOpacity + (1 - root.farOpacity) * depth
            // The selected entry is shown in the centre already; its pill is a marker, not a stop.
            enabled: !selected
            hoverEnabled: true
            padding: 0
            Accessible.name: (entry.label ?? "") + " " + (entry.text ?? "")
            Accessible.role: Accessible.Button
            onClicked: {
                Feedback.play("ui.switch");
                root.select(index);
            }
            // A soft filled capsule leaning on the −12° shear; the text inside stays upright.
            background: Item {
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    antialiasing: true
                    color: pill.hovered || pill.down ? Design.hover : Design.surface
                    border.width: pill.activeFocus || pill.entry.hot ? 1 : 0
                    border.color: pill.activeFocus ? Design.ink : Design.danger
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * pill.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    antialiasing: true
                    visible: pill.fill > 0
                    opacity: pill.fill
                    color: pill.entry.hot ? Design.danger : root.accent
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * pill.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }
            }
            contentItem: Item {
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pill.entry.label ?? ""
                        technical: true
                        color: pill.fill > 0.5 ? pill.ink : pill.hovered || pill.activeFocus ? Design.ink : Design.muted
                    }
                    FText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pill.entry.text ?? ""
                        headline: true
                        font.pixelSize: Design.control
                        font.weight: Font.Black
                        color: pill.ink
                    }
                    // The pill's own share, a short bar under its value.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: pill.width * 0.44
                        height: 3
                        visible: pill.fraction >= 0
                        Rectangle {
                            anchors.fill: parent
                            color: pill.ink
                            opacity: 0.22
                        }
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, pill.fraction))
                            height: parent.height
                            color: pill.fill > 0.5 ? pill.ink : pill.entry.hot ? Design.danger : root.accent
                        }
                    }
                }
            }
        }
    }
}
