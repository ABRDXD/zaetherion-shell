import QtQuick
import QtQuick.Shapes
import qs.view.ui
import "TasksAtlasLayout.js" as Atlas

// The star atlas (Fluid Tasks, owner's pick "B"): one list as a constellation on a sky chart seen at an angle, its far
// side at the top. The centre is now: overdue tasks burn warm at the core, sooner tasks sit nearer it, undated ones
// keep to the rim, and today's finished tasks stay as hollow rings. The route, a thin line, runs through the open
// tasks in the order they fall due. The most pressing twelve are named; the rest are stars. Click a star to finish it
// (or bring it back), right-click to remove it.
Item {
    id: root
    property var tasks: []          // [{id, text, done, days (or null), due (label)}]
    property string listId: ""
    signal toggled(var task)
    signal removed(var task)
    readonly property real cx: width / 2
    readonly property real cy: height * 0.5
    readonly property real chartR: Math.min(width * 0.31, height * 0.8)
    readonly property var placed: {
        const byId = {};
        for (const t of tasks) byId[t.id] = t;
        return Atlas.place(tasks, listId).map(p => Object.assign(p, Atlas.project(p.r, p.a, cx, cy, chartR), { task: byId[p.id] }));
    }
    readonly property bool anyLate: placed.some(p => p.late)
    readonly property var stars: Atlas.field(150, 11)

    function ring(r): var {
        const pts = [];
        for (let i = 0; i <= 96; i++) {
            const a = 2 * Math.PI * i / 96, p = Atlas.project(r, a, cx, cy, chartR);
            pts.push(Qt.point(p.x, p.y));
        }
        return pts;
    }

    // The background sky: fixed stars, fainter toward the chart.
    Repeater {
        model: root.stars
        Rectangle {
            required property var modelData
            x: modelData[0] * root.width; y: modelData[1] * root.height
            width: modelData[2]; height: width; radius: width / 2
            color: Design.coldStar
            opacity: modelData[3]
        }
    }
    // The chart's face: a faint disc, lit from its centre.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(Design.coldRim, 0.22)
            strokeWidth: 1
            fillGradient: RadialGradient {
                centerX: root.cx; centerY: root.cy; focalX: root.cx; focalY: root.cy
                centerRadius: root.chartR * 1.05; focalRadius: 0
                GradientStop { position: 0; color: Qt.alpha(root.anyLate ? Design.warm : Design.coldStar, 0.10) }
                GradientStop { position: 0.4; color: Qt.alpha(Design.coldLine, 0.35) }
                GradientStop { position: 1; color: Qt.alpha(Design.voidFill, 0.85) }
            }
            PathPolyline { path: root.ring(1.04) }
        }
    }
    // Hour lines from the core to the rim, the far ones fainter.
    Repeater {
        model: 24
        Shape {
            id: hourLine
            required property int index
            readonly property real angle: Math.PI * 2 * index / 24
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.coldLine, index % 6 === 0 ? 1 : 0.55)
                strokeWidth: 1
                fillColor: "transparent"
                startX: Atlas.project(Atlas.coreR, hourLine.angle, root.cx, root.cy, root.chartR).x
                startY: Atlas.project(Atlas.coreR, hourLine.angle, root.cx, root.cy, root.chartR).y
                PathLine {
                    x: Atlas.project(1.04, hourLine.angle, root.cx, root.cy, root.chartR).x
                    y: Atlas.project(1.04, hourLine.angle, root.cx, root.cy, root.chartR).y
                }
            }
        }
    }
    // The rings: today, week, month, later, someday, named on the near right.
    Repeater {
        model: Atlas.rings
        Item {
            id: ringItem
            required property var modelData
            readonly property real r: Atlas.radiusFor(modelData[0])
            anchors.fill: parent
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(Design.coldRim, modelData[0] === 0 ? 0.4 : 0.2)
                    strokeWidth: 1
                    strokeStyle: modelData[0] === null ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: [2, 5]
                    fillColor: "transparent"
                    PathPolyline { path: root.ring(ringItem.r) }
                }
            }
            FText {
                readonly property var p: Atlas.project(ringItem.r, 0.32, root.cx, root.cy, root.chartR)
                x: p.x + Design.baseline; y: p.y
                technical: true
                font.pixelSize: Design.caption
                color: Qt.alpha(Design.coldInk, 0.8)
                text: String(modelData[1]).toUpperCase()
            }
        }
    }
    // The core: now. Warm while anything is late.
    Rectangle {
        readonly property real rx: Atlas.coreR * root.chartR
        x: root.cx - rx; y: root.cy - rx * Atlas.tilt; width: 2 * rx; height: 2 * rx * Atlas.tilt; radius: height / 2
        color: Qt.alpha(root.anyLate ? Design.warm : Design.coldStar, root.anyLate ? 0.14 : 0.06)
        border.width: 1
        border.color: Qt.alpha(root.anyLate ? Design.warm : Design.coldRim, 0.5)
    }
    FText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + Atlas.coreR * root.chartR * Atlas.tilt + 2   // under the core, clear of its stars
        technical: true
        font.pixelSize: Design.caption
        color: root.anyLate ? Design.warm : Design.coldInk
        text: root.anyLate ? "LATE" : "NOW"
    }
    // The route through the open tasks, in the order they fall due.
    Shape {
        objectName: "tasksRoute"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.placed.filter(p => !p.done).length > 1
        ShapePath {
            strokeColor: Qt.alpha(Design.coldStar, 0.45)
            strokeWidth: 1
            fillColor: "transparent"
            PathPolyline { path: root.placed.filter(p => !p.done).map(p => Qt.point(p.x, p.y)) }
        }
    }
    // The stars.
    Repeater {
        objectName: "tasksStars"
        model: root.placed
        Item {
            id: star
            required property var modelData
            readonly property real size: Design.baseline * 2.2 * Atlas.magnitude(modelData.r, modelData.depth)
            readonly property color tone: modelData.late ? Design.warm : Design.coldStar
            objectName: "tasksStar." + modelData.id
            x: modelData.x
            y: modelData.y
            z: 1 + modelData.depth
            opacity: modelData.done ? 0.7 : 0.65 + 0.35 * modelData.depth
            Shape {
                id: glow
                visible: !star.modelData.done
                readonly property real r: star.size * 3.2
                x: -r; y: -r; width: 2 * r; height: 2 * r
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: glow.r; centerY: glow.r; focalX: centerX; focalY: centerY
                        centerRadius: glow.r; focalRadius: 0
                        GradientStop { position: 0; color: Qt.alpha(star.tone, 0.55) }
                        GradientStop { position: 0.3; color: Qt.alpha(star.tone, 0.16) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathAngleArc { centerX: glow.r; centerY: glow.r; radiusX: glow.r; radiusY: glow.r; startAngle: 0; sweepAngle: 360 }
                }
            }
            Rectangle {
                objectName: "tasksStarBody"
                readonly property bool hollow: star.modelData.done
                x: -star.size / 2; y: -star.size / 2; width: star.size; height: star.size; radius: star.size / 2
                color: hollow ? "transparent" : Qt.lighter(star.tone, 1.15)
                border.width: hollow ? 1.2 : 0
                border.color: Design.coldRim
            }
            // Four short spikes on the most pressing, the way bright stars photograph.
            Repeater {
                model: star.modelData.rank < 3 && !star.modelData.done ? 2 : 0
                Rectangle {
                    required property int index
                    width: index ? 1 : star.size * 4; height: index ? star.size * 4 : 1
                    x: -width / 2; y: -height / 2
                    color: Qt.alpha(star.tone, 0.45)
                }
            }
            Column {
                visible: star.modelData.named
                x: star.size / 2 + Design.baseline * 1.5
                y: -Design.caption
                spacing: 1
                FText {
                    text: String(star.modelData.task?.text ?? "").length > 30 ? String(star.modelData.task.text).slice(0, 29) + "…" : String(star.modelData.task?.text ?? "")
                    font.pixelSize: star.modelData.rank < 3 ? Design.body : Design.caption // scale: the three most pressing read larger
                    font.strikeout: star.modelData.done
                    color: star.modelData.done ? Design.coldInk : Design.ink
                }
                FText {
                    visible: !!star.modelData.task?.due
                    technical: true
                    font.pixelSize: Design.caption
                    color: star.modelData.late ? Design.warm : Design.coldInk
                    text: star.modelData.task?.due ?? ""
                }
            }
            MouseArea {
                x: -16; y: -16; width: 32; height: 32
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => mouse.button === Qt.RightButton ? root.removed(star.modelData.task) : root.toggled(star.modelData.task)
            }
        }
    }
}
