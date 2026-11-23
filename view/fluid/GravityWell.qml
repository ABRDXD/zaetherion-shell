import QtQuick
import QtQuick.Shapes
import qs.view.ui

// A gravity well (Fluid Performance): a grid plane seen in perspective, reaching back under the star, pulled down
// around it by its mass (memory in use). Rows recede into the distance and fade; the columns converge toward the
// horizon. Redrawn only when the mass changes, never animated on its own.
Item {
    id: root
    property real mass: 0          // 0–1
    property real wellX: width / 2 // where the well's centre projects (under the star)
    readonly property int rows: 12
    readonly property int columns: 17
    readonly property int steps: 48
    // The plane: X across (−1…1), Z depth (near…far), the eye above it; the well sits at depth `wellZ`.
    readonly property real nearZ: 0.55
    readonly property real farZ: 3.2
    readonly property real wellZ: 1.35
    readonly property real eye: 0.42       // the plane's drop below the eye
    readonly property real focal: height * 0.62
    readonly property real horizon: height * 0.42

    function depthAt(x: real, z: real): real {
        const d2 = x * x + (z - wellZ) * (z - wellZ);
        return (0.08 + 0.42 * mass) / (1 + d2 / 0.06);
    }
    function project(x: real, z: real): point {
        const y = eye + depthAt(x, z);
        return Qt.point(wellX + x * focal * 1.6 / z, horizon + y * focal / z);
    }
    function line(points): var { return points.map(p => project(p[0], p[1])); }

    // Rows (constant depth), far ones fainter.
    Repeater {
        model: root.rows
        Shape {
            id: rowLine
            required property int index
            readonly property real planeZ: root.nearZ + (root.farZ - root.nearZ) * Math.pow(index / (root.rows - 1), 1.6)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.coldLine, 0.9 * (1 - rowLine.planeZ / root.farZ) + 0.12)
                strokeWidth: 1
                fillColor: "transparent"
                PathPolyline {
                    path: { const pts = []; for (let i = 0; i <= root.steps; i++) pts.push([-1.6 + 3.2 * i / root.steps, rowLine.planeZ]); return root.line(pts); }
                }
            }
        }
    }
    // Columns, converging toward the horizon.
    Repeater {
        model: root.columns
        Shape {
            id: columnLine
            required property int index
            readonly property real planeX: -1.6 + 3.2 * index / (root.columns - 1)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Design.coldLine, 0.55)
                strokeWidth: 1
                fillColor: "transparent"
                PathPolyline {
                    path: { const pts = []; for (let i = 0; i <= root.steps; i++) pts.push([columnLine.planeX, root.nearZ + (root.farZ - root.nearZ) * i / root.steps]); return root.line(pts); }
                }
            }
        }
    }
}
