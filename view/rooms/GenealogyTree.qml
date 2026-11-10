import QtQuick
import QtQuick.Controls
import qs.view.ui
import qs.view.cues
import qs.view.strata

// Editorial launch adjacency. Time runs down; the 78° elbows are clipped to this sheet.
Item {
    id: root
    property var nodes: []
    property var windows: []
    property var focusHistory: []
    property string active: ""
    property var memory: null
    property bool witnessed: false
    signal focusWindow(string address)
    readonly property var arranged: {
        const levels = {};
        return nodes.map((n, i) => {
            const depth = n.parent && levels[n.parent] !== undefined ? Math.min(3, levels[n.parent] + 1) : 0;
            levels[n.id] = depth;
            return Object.assign({}, n, {row: i, depth: depth});
        });
    }
    function nx(n) { return 40 + n.depth * Math.min(132, width * 0.18); }
    function ny(n) { return 30 + n.row * 94; }
    function address(value) { return String(value || "").replace(/^0x/, "").toLowerCase(); }
    function liveWindow(n) { return windows.find(w => address(w.id) === n.address); }
    function draw(c, growth) {
        c.reset();
        const all = arranged;
        c.lineWidth = 2; c.strokeStyle = Design.line;
        for (let i = 0; i < all.length; i++) {
            const n = all[i], p = all.find(x => x.id === n.parent);
            if (!p) continue;
            const x = nx(n), y = ny(n) + 34;
            const px = nx(p) + 20, py = ny(p) + (p.closed !== null ? 38 : 68);
            const dx = (y - py) / Design.slope;
            c.beginPath(); c.moveTo(px, py);
            const progress = i === all.length - 1 ? growth : 1;
            const elbow = px - dx;
            if (progress < 0.5) c.lineTo(px - dx * progress * 2, py + (y - py) * progress * 2);
            else { c.lineTo(elbow, y); c.lineTo(elbow + (x - elbow) * (progress * 2 - 1), y); }
            c.stroke();
        }
        // Focus succession is distinct from launch adjacency: fine, broken return routes.
        c.lineWidth = 1; c.strokeStyle = Qt.alpha(Design.accent, 0.35); c.setLineDash([3, 6]);
        const recent = focusHistory.slice(-12);
        for (let i = 1; i < recent.length; i++) {
            const from = all.find(n => recent[i-1].node ? n.id === recent[i-1].node : n.address === recent[i-1].address);
            const to = all.find(n => recent[i].node ? n.id === recent[i].node : n.address === recent[i].address);
            if (!from || !to || from.id === to.id) continue;
            const fy = ny(from) + 74, ty = ny(to) + 74;
            const x = Math.max(nx(from), nx(to)) + 40;
            c.beginPath(); c.moveTo(nx(from) + 16, fy); c.lineTo(x, fy);
            c.lineTo(x - (ty - fy) / Design.slope, ty); c.lineTo(nx(to) + 16, ty); c.stroke();
        }
    }
    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, root.arranged.length * 94 + 60)
        ScrollBar.vertical: ScrollBar {}
        Canvas {
            id: branches
            property color lineColor: Design.line
            property color signalColor: Design.accent
            onLineColorChanged: requestPaint()
            onSignalColorChanged: requestPaint()
            width: scroll.width; height: scroll.contentHeight
            visible: !growing.item
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: root; function onArrangedChanged() { branches.requestPaint(); } function onFocusHistoryChanged() { branches.requestPaint(); } }
            onPaint: root.draw(getContext("2d"), 1)
        }
        Repeater {
            model: root.arranged
            Item {
                id: node
                z: 1
                required property var modelData
                readonly property var live: root.liveWindow(modelData)
                readonly property bool closed: modelData.closed !== null
                x: root.nx(modelData)
                y: root.ny(modelData)
                width: Math.max(120, Math.min(scroll.width * 0.49, scroll.width - x - 30))
                height: closed ? 38 : 68
                Plane { id: plate; anchors.fill: parent; role: node.closed ? "clear" : root.active === node.modelData.address ? "ink" : "paper"; backing: !node.closed; slant: 2 }
                Rectangle { x: -2; width: node.closed ? 18 : 3; height: node.closed ? 2 : parent.height; y: node.closed ? 18 : 0; color: node.closed ? Design.muted : Design.accent }
                FText {
                    x: 14; y: node.closed ? 8 : 6; width: parent.width - 110
                    text: node.modelData.app || "WINDOW"
                    headline: true; font.pixelSize: node.closed ? Design.control : Design.figure
                    font.weight: Font.DemiBold
                    color: node.closed ? Design.muted : plate.textColor
                }
                FText {
                    x: 14; y: 43; width: parent.width - 32; visible: !node.closed
                    text: node.live?.title || (root.witnessed ? "LAUNCH ADJACENCY" : "PRESENT WHEN OBSERVED")
                    technical: true; color: plate.textColor; elide: Text.ElideRight
                }
                FText {
                    anchors.right: parent.right; anchors.rightMargin: 14; y: 9
                    text: node.closed ? "SCAR / " + String(node.modelData.id).padStart(2, "0") : String(node.modelData.id).padStart(2, "0")
                    technical: true; color: node.closed ? Design.faint : plate.textColor
                }
                // Existing adapter actions only. A historical address is never actionable.
                AbstractButton {
                    anchors.fill: parent; enabled: !!node.live && !node.closed
                    Accessible.name: "Focus " + (node.live?.title || node.modelData.app)
                    onClicked: root.focusWindow(node.live.id)
                    background: Rectangle { color: "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: Design.accent }
                }
            }
        }
        Stratum {
            id: growing
            name: "genealogy-growth"; gpu: false; scope: root
            width: scroll.width; height: scroll.contentHeight
            onItemChanged: branches.requestPaint()
            sourceComponent: Component {
                Canvas {
                    id: growth
                    property color lineColor: Design.line
                    property color signalColor: Design.accent
                    onLineColorChanged: requestPaint()
                    onSignalColorChanged: requestPaint()
                    property var data: root.arranged
                    property int latestId: 0
                    onDataChanged: {
                        const next = data.length ? data[data.length-1].id : 0;
                        if (latestId && next > latestId) arrival.replay();
                        latestId = next;
                        requestPaint();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Cue { id: arrival; name: "genealogy.branch"; scope: growth; on: true; enter: Motion.navigate * 2; onValueChanged: growth.requestPaint() }
                    Connections { target: root; function onFocusHistoryChanged() { growth.requestPaint(); } }
                    onPaint: root.draw(getContext("2d"), 1 - (1 - arrival.value) * Motion.drive)
                }
            }
        }

    }
    // Empty desks contain rectangles only: the whole former composition, normalized as one plan.
    Item {
        id: ghost
        anchors.fill: parent
        visible: root.memory !== null && !root.nodes.some(n => n.closed === null)
        readonly property var rects: root.memory?.rects ?? []
        readonly property real minX: rects.length ? Math.min(...rects.map(r => r.rect[0])) : 0
        readonly property real minY: rects.length ? Math.min(...rects.map(r => r.rect[1])) : 0
        readonly property real maxX: Math.max(1, ...rects.map(r => r.rect[0] + r.rect[2]))
        readonly property real maxY: Math.max(1, ...rects.map(r => r.rect[1] + r.rect[3]))
        readonly property real fit: Math.min((width - 48) / (maxX - minX), (height - 80) / (maxY - minY))
        Plane { anchors.fill: parent; role: "paper" }
        Repeater {
            model: ghost.rects
            Rectangle {
                required property var modelData
                x: 24 + (modelData.rect[0] - ghost.minX) * ghost.fit
                y: 40 + (modelData.rect[1] - ghost.minY) * ghost.fit
                width: Math.max(2, modelData.rect[2] * ghost.fit - 3)
                height: Math.max(2, modelData.rect[3] * ghost.fit - 3)
                color: "transparent"; border.width: 1; border.color: Qt.alpha(Design.ink, 0.20)
            }
        }
        Stratum {
            name: "genealogy-memory"; gpu: false; scope: ghost
            anchors.fill: parent
            sourceComponent: Component {
                Item {
                    id: breath
                    IdleLoop { id: lungs; name: "genealogy.memory"; scope: breath; period: 9000 }
                    Repeater {
                        model: ghost.rects
                        Rectangle {
                            required property var modelData
                            x: 24 + (modelData.rect[0] - ghost.minX) * ghost.fit
                            y: 40 + (modelData.rect[1] - ghost.minY) * ghost.fit
                            width: Math.max(2, modelData.rect[2] * ghost.fit - 3)
                            height: Math.max(2, modelData.rect[3] * ghost.fit - 3)
                            color: "transparent"; border.width: 2; border.color: Design.accent
                            opacity: lungs.level * (0.06 + 0.08 * Math.sin(lungs.phase * Math.PI * 2))
                        }
                    }
                }
            }
        }
        FText { x: 24; y: 12; text: "LAST OCCUPIED PLAN"; technical: true; color: Design.muted }
    }
}
