pragma ComponentBehavior: Bound
import QtQuick
import "DesktopGrid.js" as Grid

// Edit widgets (Z46, Z86; Astra's tools/widget-editor-study, owner's picks 24 Nov: A · Chase in Angular,
// B · Margin in Fluid). One screen's desktop, scaled into the sheet with its 12 columns; the clock at its pose.
// Chase: drag the clock to move it, the upper tab turns it, the lower-right tab changes its span. Margin: choose
// Move, Resize or Rotate in the side panel, then drag the clock or set the value on its ruler. Every change is
// saved through the core (widgets.place) a moment after it settles; Escape or Preview returns to the desktop.
FocusScope {
    id: root
    required property bool fluid
    required property string monitor
    required property size screenSize
    property var widgets: null
    property string wallpaper: ""
    // Placement follows the form (the owner's picks); a test may ask for the other.
    property bool margin: fluid
    signal placed(var pose)
    signal closed()
    signal showWidgets(bool on)
    readonly property bool shown: widgets?.shown !== false

    readonly property var savedPose: widgets?.monitors?.[monitor]?.clock ?? widgets?.defaults?.clock
        ?? ({ column: 2, span: 8, y: 0.42, angle: 0 })
    readonly property int minSpan: widgets?.minSpan?.clock ?? 3
    property var pose: savedPose
    onSavedPoseChanged: if (!gesture && !commit.running) pose = savedPose
    property string tool: "Move"
    property string gesture: ""
    readonly property string activeTool: gesture || tool
    property var start: null
    property point origin

    // The study's palette and type (EditorStudy.qml), named for the type-scale rule.
    readonly property color stock: fluid ? "#242334" : "#1d2027"
    readonly property color paper: fluid ? "#efedf8" : "#f3efdc"
    readonly property color signal: fluid ? "#d9cdff" : "#ffd064"
    readonly property color signalInk: "#23232c"
    readonly property color quiet: fluid ? "#c4c0d4" : "#bcc1c0"
    readonly property string sans: fluid ? "Noto Sans" : "Roboto Condensed"
    readonly property string mono: "DejaVu Sans Mono"
    readonly property int titleSize: 30
    readonly property int wordSize: 17
    readonly property int fineSize: 13

    readonly property rect box: {
        const r = Grid.rect(pose, screenSize.width, screenSize.height);
        return Qt.rect(r.x, r.y, r.width, r.height);
    }

    function change(next) {
        pose = next;
        commit.restart();
    }
    function bearing(point, centre) {
        return Math.atan2(point.y - centre.y, point.x - centre.x) * 180 / Math.PI;
    }
    function begin(kind, point) {
        tool = kind;
        start = Object.assign({}, pose);
        origin = point;
        gesture = kind;
    }
    function track(point) {
        if (!gesture) return;
        const dx = point.x - origin.x, dy = point.y - origin.y;
        if (gesture === "Move") {
            change(Grid.moved(start, dx, dy, screenSize.width, screenSize.height, minSpan));
        } else if (gesture === "Resize") {
            const rad = start.angle * Math.PI / 180;
            change(Grid.resized(start, dx * Math.cos(rad) + dy * Math.sin(rad), screenSize.width, minSpan));
        } else {
            const r = Grid.rect(start, screenSize.width, screenSize.height);
            const centre = Qt.point(r.x + r.width / 2, r.y + r.height / 2);
            change(Grid.turned(start, bearing(point, centre) - bearing(origin, centre)));
        }
    }
    function end() {
        gesture = "";
        commit.stop();
        root.placed(pose);
    }

    Timer { id: commit; interval: 250; onTriggered: root.placed(root.pose) }

    focus: true
    Keys.onEscapePressed: root.closed()

    component Words: Text {
        font.family: root.sans
        font.pixelSize: root.wordSize
        color: root.paper
    }
    component Fine: Words {
        font.family: root.fluid ? root.sans : root.mono
        font.pixelSize: root.fineSize
        color: root.quiet
    }
    component DragSurface: MouseArea {
        id: hit
        required property string kind
        cursorShape: kind === "Rotate" ? Qt.CrossCursor : kind === "Resize" ? Qt.SizeFDiagCursor
                    : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        function point(event) { return mapToItem(desk, event.x, event.y); }
        onPressed: event => root.begin(kind, point(event))
        onPositionChanged: event => { if (pressed) root.track(point(event)); }
        onReleased: event => { root.track(point(event)); root.end(); }
        onCanceled: root.end()
    }

    Rectangle {
        id: sheet
        anchors.fill: parent
        color: root.stock

        Item {
            id: header
            width: parent.width; height: 74
            Words {
                x: 32; anchors.verticalCenter: parent.verticalCenter
                text: "Edit widgets"
                font.pixelSize: root.titleSize; font.weight: Font.DemiBold
            }
            Fine {
                objectName: "editorContext"
                x: 245; anchors.verticalCenter: parent.verticalCenter
                text: root.monitor + "   /   " + (root.widgets?.layout ?? "Default")
            }
            Rectangle {
                id: showToggle
                objectName: "editorShowToggle"
                width: toggleLabel.implicitWidth + 36; height: 38
                radius: root.fluid ? 19 : 0
                anchors.right: done.left; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1
                border.color: root.shown ? root.paper : root.signal
                Accessible.role: Accessible.Button
                Accessible.name: toggleLabel.text
                Accessible.onPressAction: root.showWidgets(!root.shown)
                Words { id: toggleLabel; anchors.centerIn: parent; text: root.shown ? "Hide widgets" : "Show widgets"; color: root.shown ? root.paper : root.signal }
                TapHandler { onTapped: root.showWidgets(!root.shown) }
            }
            Rectangle {
                id: done
                objectName: "editorDone"
                width: doneLabel.implicitWidth + 36; height: 38
                radius: root.fluid ? 19 : 0
                anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter
                color: root.paper
                Accessible.role: Accessible.Button
                Accessible.name: doneLabel.text
                Accessible.onPressAction: root.closed()
                Words { id: doneLabel; anchors.centerIn: parent; text: "Preview"; color: root.stock; font.weight: Font.DemiBold }
                TapHandler { onTapped: root.closed() }
            }
        }

        Item {
            id: viewport
            y: header.height; height: sheet.height - y
            width: sheet.width - (marginPanel.active ? marginPanel.width : 0)
            clip: true
            Item {
                id: desk
                objectName: "editorDesk"
                width: root.screenSize.width; height: root.screenSize.height
                anchors.centerIn: parent
                scale: Math.min((viewport.width - 48) / width, (viewport.height - 48) / height)
                clip: true
                Rectangle { anchors.fill: parent; color: "#16191e" }
                Image {
                    anchors.fill: parent
                    visible: root.wallpaper !== ""
                    source: root.wallpaper ? "file://" + root.wallpaper : ""
                    sourceSize.width: 1280
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Twelve columns belong to the display; the top rule marks the clock's span, even while it turns.
                Repeater {
                    model: 13
                    Item {
                        id: columnLine
                        required property int index
                        x: Grid.MARGIN + index * Grid.pitch(root.screenSize.width) - (index === 12 ? Grid.metrics(root.screenSize.width).gutter : 0)
                        height: desk.height; width: 1
                        Rectangle { y: 27; width: 1; height: parent.height - y; color: root.fluid ? "#463f60" : "#d7d8d1"; opacity: .18 }
                        Rectangle { y: 18; width: 1; height: 9; color: root.fluid ? "#49425d" : root.paper }
                        Fine {
                            visible: columnLine.index < 12
                            x: 5; y: 7; text: String(columnLine.index + 1).padStart(2, "0")
                            color: root.fluid ? "#373147" : root.paper
                        }
                    }
                }
                Rectangle {
                    objectName: "spanRule"
                    x: root.box.x; y: 25; width: root.box.width; height: 3
                    color: root.fluid ? "#524567" : root.signal
                }
                Item {
                    id: selection
                    objectName: "editorClock"
                    x: root.box.x; y: root.box.y; width: root.box.width; height: root.box.height
                    rotation: root.pose.angle
                    opacity: root.shown ? 1 : 0.35  // hidden on the desktop; still placeable here
                    DesktopClock { anchors.fill: parent; fluid: root.fluid; face: root.widgets?.face ?? ({}) }
                    DragSurface { objectName: "moveArea"; anchors.fill: parent; kind: root.margin ? root.tool : "Move" }
                    // Registration marks show the actual rotated bounds.
                    Repeater {
                        model: 4
                        Item {
                            required property int index
                            x: index % 2 ? selection.width : 0
                            y: index >= 2 ? selection.height : 0
                            Rectangle { x: parent.index % 2 ? -17 : 0; width: 17; height: 2; color: root.fluid ? "#54496e" : root.signal }
                            Rectangle { y: parent.index >= 2 ? -17 : 0; width: 2; height: 17; color: root.fluid ? "#54496e" : root.signal }
                        }
                    }
                    Loader {
                        anchors.fill: parent
                        active: !root.margin
                        sourceComponent: ChaseHandles {
                            id: handles
                            angle: root.pose.angle; span: root.pose.span
                            fluid: root.fluid; stock: root.stock; paper: root.paper
                            signal: root.signal; signalInk: root.signalInk
                            labelFamily: root.fluid ? root.sans : root.mono
                            DragSurface { parent: handles.rotationTarget; objectName: "turnHandle"; anchors.fill: parent; kind: "Rotate" }
                            DragSurface { parent: handles.resizeTarget; objectName: "spanHandle"; anchors.fill: parent; kind: "Resize" }
                        }
                    }
                }
            }
        }

        Loader {
            id: marginPanel
            anchors.right: parent.right; y: header.height; height: viewport.height
            active: root.margin
            sourceComponent: MarginPanel {
                objectName: "marginPanel"
                fluid: root.fluid; stock: root.stock; paper: root.paper; signal: root.signal
                sans: root.sans; labelFamily: root.fluid ? root.sans : root.mono
                tool: root.tool; activeTool: root.activeTool
                column: root.pose.column; span: root.pose.span; angle: root.pose.angle
                minimum: tool === "Rotate" ? -180 : tool === "Move" ? 1 : root.minSpan
                maximum: tool === "Rotate" ? 180 : tool === "Move" ? 13 - root.pose.span : 12 - root.pose.column
                onToolRequested: value => root.tool = value
                onValueRequested: value => {
                    const next = Object.assign({}, root.pose);
                    if (tool === "Rotate") next.angle = value;
                    else if (tool === "Move") next.column = value - 1;
                    else next.span = value;
                    root.change(next);
                }
            }
        }
    }
}
