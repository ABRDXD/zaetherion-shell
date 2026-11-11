import QtQuick
import QtQuick.Shapes

// A passive trace of the adapter's spectrum, with no sampling clock of its own.
Shape {
    id: root
    property var levels: []
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: Design.accent
        strokeWidth: 1
        PathPolyline {
            path: {
                const bins = root.levels;
                return bins.map((value, index) => Qt.point(
                    root.width * index / Math.max(1, bins.length - 1),
                    root.height * (0.5 + (index % 2 ? -1 : 1) * Math.max(0, Math.min(1, value)) * 0.45)
                ));
            }
        }
    }
}
