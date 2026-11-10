import qs.view.cues
import qs.view.strata
import qs.view.ui
import QtQuick
import Quickshell.Wayland

// The contact sheet (M14): every desk as a frame on one sheet of film, its windows where the compositor really has them.
// In Silent the windows are outlines (still, nothing captured). In Overdrive each is captured once, as the sheet opens
// (never live, never written anywhere), and develops from a negative. A click on a window goes to it; a click on a frame
// goes to that desk; dragging a window to another frame moves it there, without leaving where you are. The last frame
// is the first empty desk, so a window can always be sent somewhere new. Arrows or hjkl walk the frames, a digit jumps,
// Enter goes, Esc or W closes.
Item {
    id: root
    required property var host
    property var shell: null
    signal closed()
    readonly property var wm: host?.workspaces ?? null
    // Live previews (docs/OVERDRIVE.md §26): a rolling shutter walks the sheet, re-exposing one window per tick, so every frame keeps moving for a fraction of what running them all live
    // would cost. Overdrive only: Silent still captures nothing, and with reduced motion each window stays the single exposure it was.
    readonly property bool rolling: root.capturing && Motion.driving
    property var shutter: []
    property int shutterAt: 0
    Timer {
        interval: 66
        repeat: true
        running: root.rolling && root.shutter.length > 0
        onTriggered: {
            const frames = root.shutter;
            root.shutterAt = (root.shutterAt + 1) % frames.length;
            const view = frames[root.shutterAt]?.item;
            if (view && !view.live && typeof view.captureFrame === "function")
                view.captureFrame();
        }
    }
    readonly property bool capturing: Motion.engaged && !Motion.reduced
    readonly property bool hardware: GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property var windows: (wm?.windows ?? []).filter(w => Number(w.workspaceId) > 0)
    // Every desk in use, the current one, and the lowest number free.
    readonly property var desks: {
        const used = new Set(windows.map(w => Number(w.workspaceId)));
        if (Number(wm?.activeId) > 0)
            used.add(Number(wm.activeId));
        let free = 1;
        while (used.has(free))
            free++;
        used.add(free);
        return [...used].sort((a, b) => a - b).map(String);
    }
    property int cursor: Math.max(0, desks.indexOf(String(wm?.activeId ?? "")))

    function monitorOf(desk) {
        const monitors = wm?.monitors ?? [];
        const name = (wm?.workspaces ?? []).find(w => String(w.id) === desk)?.monitor
            || windows.find(w => w.workspaceId === desk)?.monitor || wm?.focusedScreen;
        return monitors.find(m => m.name === name) ?? monitors[0] ?? null;
    }
    function logical(monitor) {
        return { width: (monitor?.width ?? 1920) / (monitor?.scale || 1), height: (monitor?.height ?? 1080) / (monitor?.scale || 1) };
    }
    readonly property var screen: logical(monitorOf(wm?.activeId ?? ""))

    readonly property int pad: 30
    readonly property int headerHeight: 58
    readonly property int captionHeight: 24
    readonly property int gap: 22
    readonly property int columns: desks.length <= 1 ? 1 : desks.length <= 4 ? 2 : desks.length <= 9 ? 3 : 4
    readonly property int rows: Math.ceil(desks.length / columns)
    readonly property real plateWidth: {
        const across = (width - 2 * pad - (columns - 1) * gap) / columns;
        const down = (height - headerHeight - pad - (rows - 1) * gap) / rows - captionHeight;
        return Math.max(40, Math.min(across, down * screen.width / screen.height));
    }
    readonly property real plateHeight: plateWidth * screen.height / screen.width
    readonly property real gridLeft: (width - columns * plateWidth - (columns - 1) * gap) / 2
    function plateX(i) { return gridLeft + (i % columns) * (plateWidth + gap); }
    function plateY(i) { return headerHeight + Math.floor(i / columns) * (plateHeight + captionHeight + gap); }

    // The drag: the window being carried, where it is and the frame under it.
    property var carried: null
    property point carriedAt: Qt.point(0, 0)
    property string dropDesk: ""
    function plateAt(x, y) {
        for (let i = 0; i < plates.count; i++) {
            const plate = plates.itemAt(i);
            const p = plate.mapFromItem(root, x, y);
            if (p.x >= 0 && p.x <= plate.width && p.y >= 0 && p.y <= plate.height + root.captionHeight)
                return plate.modelData;
        }
        return "";
    }
    function carry(window, x, y) {
        carried = window;
        carriedAt = Qt.point(x, y);
        dropDesk = plateAt(x, y);
    }
    function drop() {
        const window = carried, desk = dropDesk;
        carried = null;
        dropDesk = "";
        if (window && desk)
            sendTo(window, desk);
    }
    function sendTo(window, desk) {
        if (desk === window.workspaceId)
            return false;
        wm.moveWindow(window.id, desk);
        Feedback.play("foley.splice");
        return true;
    }
    function go(desk) {
        if (desk !== String(wm.activeId))
            wm.switchTo(desk);
        shell?.close();
    }
    function goWindow(window) {
        if (window.workspaceId !== String(wm.activeId))
            wm.switchTo(window.workspaceId);
        wm.focusWindow(window.id);
        shell?.close();
    }
    function walk(direction) {
        const delta = { left: -1, right: 1, up: -columns, down: columns }[direction];
        const next = cursor + delta;
        if (next >= 0 && next < desks.length)
            cursor = next;
    }

    Component.onCompleted: {
        forceActiveFocus();
        develop.on = true;
        if (capturing)
            Feedback.play("foley.paper");
    }
    Keys.onPressed: event => {
        const letters = { h: "left", j: "down", k: "up", l: "right" };
        const arrows = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" };
        const direction = arrows[event.key] ?? letters[event.text];
        if (direction)
            walk(direction);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            go(desks[cursor]);
        else if (event.key === Qt.Key_Escape || event.text === "w" || event.text === "W")
            closed();
        else if (event.text >= "1" && event.text <= "9" && desks.indexOf(event.text) >= 0)
            cursor = desks.indexOf(event.text);
        else
            return;
        event.accepted = true;
    }
    property alias developCue: develop
    Cue {
        id: develop
        name: "desks.develop"
        scope: root
        enter: Motion.scaled(1100)
        exit: 0
        easing: Easing.Linear
    }

    // Opaque, and it takes every click that lands between the frames.
    Rectangle {
        anchors.fill: parent
        color: Design.background
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    Plane {
        id: title
        x: root.pad
        y: 14
        width: titleText.implicitWidth + 44
        height: 30
        role: root.capturing ? "signal" : "ink"
        slant: 3
        backing: true
        FText {
            id: titleText
            anchors.centerIn: parent
            text: "CONTACT SHEET"
            headline: true
            font.weight: Font.Black
            color: title.textColor
        }
    }
    FText {
        anchors.verticalCenter: title.verticalCenter
        x: title.x + title.width + 16
        text: (root.desks.length - 1) + " DESKS · " + root.windows.length + " WINDOWS" + (root.capturing ? "" : " · OUTLINES IN SILENT")
        technical: true
        color: Design.muted
    }
    FText {
        anchors.verticalCenter: title.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        text: "CLICK GOES · DRAG MOVES · ESC"
        technical: true
        color: Design.faint
    }

    Repeater {
        id: plates
        model: root.desks
        delegate: Item {
            id: plate
            required property string modelData
            required property int index
            readonly property var monitor: root.monitorOf(modelData)
            readonly property var size: root.logical(monitor)
            readonly property bool current: modelData === String(root.wm?.activeId ?? "")
            readonly property bool keyed: index === root.cursor
            readonly property bool dropping: root.dropDesk === modelData && root.carried !== null && root.carried.workspaceId !== modelData
            readonly property var here: root.windows.filter(w => w.workspaceId === modelData)
            property string hoveredTitle: ""
            x: root.plateX(index)
            y: root.plateY(index)
            width: root.plateWidth
            height: root.plateHeight
            // The whole frame leans on the house angle; pointer coordinates follow it.
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Design.shear, 0, -Design.shear * plate.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
            Rectangle {
                anchors.fill: parent
                color: Design.surface
                border.width: plate.dropping || plate.keyed || plate.current ? 2 : 1
                border.color: plate.dropping ? Design.warm : plate.keyed || plate.current ? Design.accent : Design.line
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.cursor = plate.index
                onClicked: root.go(plate.modelData)
            }
            // The film's edge: perforations above and below the frame.
            Repeater {
                model: Math.floor(plate.width / 16) * 2
                Rectangle {
                    required property int index
                    z: 5
                    readonly property int across: Math.floor(plate.width / 16)
                    x: 5 + (index % across) * 16
                    y: index < across ? 4 : plate.height - 8
                    width: 7
                    height: 4
                    radius: 1
                    color: Design.line
                    opacity: 0.6
                }
            }
            FText {
                anchors.centerIn: parent
                visible: plate.here.length === 0
                text: "EMPTY · DROP HERE"
                technical: true
                color: Design.faint
            }
            Repeater {
                model: plate.here
                delegate: Item {
                    id: thumb
                    required property var modelData
                    required property int index
                    readonly property real sx: plate.width / plate.size.width
                    readonly property real sy: plate.height / plate.size.height
                    x: (modelData.x - (plate.monitor?.x ?? 0)) * sx
                    y: (modelData.y - (plate.monitor?.y ?? 0)) * sy
                    width: Math.max(8, modelData.width * sx)
                    height: Math.max(8, modelData.height * sy)
                    z: modelData.focused ? 2 : modelData.floating ? 1 : 0
                    opacity: root.carried?.id === modelData.id ? 0.3 : 1
                    readonly property var source: root.capturing ? root.wm.thumbnailSource(modelData.id) : null
                    // Each window a little after the one before it.
                    readonly property real progress: Math.min(1, Math.max(0, develop.value * 1.5 - 0.5 * index / Math.max(1, plate.here.length)))
                    readonly property bool developing: root.capturing && root.hardware && progress < 1
                    layer.enabled: developing
                    layer.effect: Develop {
                        progress: thumb.progress
                        seed: thumb.index + plate.index * 7.0
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Design.background
                        border.width: 1
                        border.color: Design.line
                        FText {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            visible: !capture.item?.hasContent
                            text: thumb.modelData.appId
                            technical: true
                            font.capitalization: Font.MixedCase
                            color: Design.muted
                        }
                    }
                    Loader {
                        id: capture
                        anchors.fill: parent
                        active: thumb.source !== null
                        sourceComponent: ScreencopyView {
                            captureSource: thumb.source
                            // The focused window runs at full rate; the others take their turn under the rolling shutter below.
                            live: thumb.modelData.focused && root.rolling
                            paintCursor: false
                        }
                        onLoaded: root.shutter = root.shutter.concat([capture])
                        Component.onDestruction: root.shutter = root.shutter.filter(c => c !== capture)
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: thumb.modelData.focused || hover.containsMouse ? 2 : 0
                        border.color: hover.containsMouse ? Design.warm : Design.accent
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property point pressedAt
                        function inSheet(mouse) { return mapToItem(root, mouse.x, mouse.y); }
                        onEntered: { root.cursor = plate.index; plate.hoveredTitle = thumb.modelData.title; }
                        onExited: plate.hoveredTitle = ""
                        onPressed: mouse => pressedAt = inSheet(mouse)
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const p = inSheet(mouse);
                            if (root.carried || Math.hypot(p.x - pressedAt.x, p.y - pressedAt.y) > 6)
                                root.carry(thumb.modelData, p.x, p.y);
                        }
                        onReleased: mouse => {
                            if (root.carried)
                                root.drop();
                            else if (containsMouse)
                                root.goWindow(thumb.modelData);
                        }
                    }
                }
            }
            // The frame's number on the film's edge, and the window under the pointer.
            FText {
                y: plate.height + 4
                text: plate.modelData.padStart(2, "0") + "A"
                technical: true
                font.weight: Font.Black
                color: plate.current ? Design.accent : Design.warm
            }
            FText {
                x: 42
                y: plate.height + 4
                width: plate.width - 42
                elide: Text.ElideRight
                text: plate.hoveredTitle !== "" ? plate.hoveredTitle
                    : plate.here.length + (plate.here.length === 1 ? " WINDOW" : " WINDOWS") + (plate.current ? " · HERE" : "")
                technical: plate.hoveredTitle === ""
                color: Design.muted
            }
        }
    }
    // The window being carried, under the pointer.
    Rectangle {
        visible: root.carried !== null
        x: root.carriedAt.x - width / 2
        y: root.carriedAt.y - height / 2
        z: 20
        width: 130
        height: 74
        color: Design.surface
        border.width: 2
        border.color: Design.warm
        FText {
            anchors.centerIn: parent
            width: parent.width - 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.carried?.appId ?? ""
            technical: true
            font.capitalization: Font.MixedCase
            color: Design.ink
        }
    }
}
