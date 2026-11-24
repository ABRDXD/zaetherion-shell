pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtCore
import "../../view/widgets" as Placement
import "../widget-study" as Widgets
import "../login-clock-study" as Login

Window {
    id: win
    width: 1160; height: 650
    visible: true
    title: "Modern Clock · Widget editor"
    readonly property var args: Qt.application.arguments
    readonly property bool fluid: args.includes("--fluid")
    readonly property bool margin: args.includes("--margin") || (fluid && !args.includes("--chase"))
    property bool editing: true
    property bool faceOpen: true
    readonly property string timeLabel: faceStrip.twelveHour ? "– 7:24 AM –" : "– 07:24 –"
    property bool occupied: args.includes("--occupied")
    property string tool: "Move"
    readonly property string activeTool: pose.gesture || tool
    readonly property color stock: fluid ? "#242334" : "#1d2027"
    readonly property color paper: fluid ? "#efedf8" : "#f3efdc"
    readonly property color signal: fluid ? "#d9cdff" : "#ffd064"
    readonly property color signalInk: "#23232c"
    readonly property color quiet: fluid ? "#c4c0d4" : "#bcc1c0"
    readonly property string sans: fluid ? "Noto Sans" : "Roboto Condensed"
    readonly property string mono: "DejaVu Sans Mono"
    readonly property url localFonts: StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                       + "/.config/dms/plugins/modernClock/fonts/"
    FontLoader { id: dayFont; source: win.localFonts + "Anurati.otf" }
    FontLoader { id: smallFont; source: win.localFonts + "Poppins.ttf" }
    readonly property string dayFamily: dayFont.status === FontLoader.Ready ? dayFont.name
                                      : Qt.fontFamilies().includes("Anurati") ? "Anurati" : "DejaVu Sans"
    readonly property string smallFamily: smallFont.status === FontLoader.Ready ? smallFont.name
                                        : Qt.fontFamilies().includes("Poppins") ? "Poppins" : "DejaVu Sans"

    component Words: Text {
        font.family: win.sans
        font.pixelSize: 17
        color: win.paper
    }
    component Fine: Words {
        font.family: win.fluid ? win.sans : win.mono
        font.pixelSize: 13
        color: win.quiet
    }
    component DragSurface: MouseArea {
        id: hit
        required property string kind
        cursorShape: kind === "Rotate" ? Qt.CrossCursor : kind === "Resize" ? Qt.SizeFDiagCursor
                    : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        function point(event) { return mapToItem(desk, event.x, event.y); }
        onPressed: event => { win.tool = kind; pose.begin(kind, point(event)); }
        onPositionChanged: event => { if (pressed) pose.track(point(event)); }
        onReleased: event => { pose.track(point(event)); pose.gesture = ""; }
        onCanceled: pose.gesture = ""
    }

    EditPose {
        id: pose
        objectName: "pose"
        step: (desk.width - 2 * leftInset) / 12
        leftInset: 36
        canvasHeight: desk.height
    }

    Rectangle {
        id: sheet
        anchors.fill: parent
        color: win.stock
        focus: true
        Keys.onSpacePressed: win.occupied = !win.occupied
        Keys.onEscapePressed: win.editing = !win.editing
        Item {
            id: header
            width: parent.width; height: 74
            Words {
                x: 32; anchors.verticalCenter: parent.verticalCenter
                text: win.editing ? "Edit widgets" : "Layout preview"
                font.pixelSize: 30; font.weight: Font.DemiBold
            }
            Fine {
                x: 245; anchors.verticalCenter: parent.verticalCenter
                text: "Display 1   /   Morning"
            }
            AbstractButton {
                id: appearance
                objectName: "faceToggle"
                visible: win.editing && !win.occupied
                text: "Clock face"
                anchors.right: previewAction.left; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 115; implicitHeight: 38
                Accessible.checkable: true
                Accessible.checked: win.faceOpen
                onClicked: win.faceOpen = !win.faceOpen
                contentItem: Words {
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: appearance.text; color: win.faceOpen ? win.signal : win.paper
                }
                background: Rectangle {
                    color: "transparent"
                    radius: win.fluid ? 19 : 0
                    border.width: appearance.visualFocus || win.faceOpen ? 1 : 0
                    border.color: win.faceOpen ? win.signal : win.paper
                }
            }
            Rectangle {
                id: previewAction
                width: action.implicitWidth + 36; height: 38
                radius: win.fluid ? 19 : 0
                anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter
                color: win.paper
                Words {
                    id: action; anchors.centerIn: parent
                    text: win.editing ? "Preview" : "Edit widgets"
                    color: win.stock; font.weight: Font.DemiBold
                }
                TapHandler { onTapped: win.editing = !win.editing }
            }
        }

        Item {
            id: viewport
            y: header.height; height: sheet.height - y - (faceStrip.visible ? faceStrip.height : 0)
            width: sheet.width - (marginPanel.active ? marginPanel.width : 0)
            clip: true
            Item {
                id: desk
                width: 1160; height: 576
                anchors.centerIn: parent
                scale: Math.min(viewport.width / width, viewport.height / height)
                clip: true
                Widgets.OffcutWallpaper {
                    anchors.fill: parent
                    fluid: win.fluid; darkStock: !win.fluid; family: win.dayFamily
                }

                // Twelve columns belong to the display. The top rule marks the span
                // occupied by the selected clock, even while its lettering rotates.
                Item {
                    anchors.fill: parent
                    visible: win.editing && !win.occupied
                    Repeater {
                        model: 13
                        Item {
                            id: columnLine
                            required property int index
                            x: pose.leftInset + index * pose.step
                            height: desk.height; width: 1
                            Rectangle { y: 27; width: 1; height: parent.height - y; color: win.fluid ? "#463f60" : "#d7d8d1"; opacity: .18 }
                            Rectangle { y: 18; width: 1; height: 9; color: win.fluid ? "#49425d" : win.paper }
                            Fine {
                                visible: columnLine.index < 12
                                x: 5; y: 7; text: String(columnLine.index + 1).padStart(2, "0")
                                color: win.fluid ? "#373147" : win.paper
                            }
                        }
                    }
                    Rectangle {
                        x: pose.left; y: 25; width: pose.faceWidth; height: 3
                        color: win.fluid ? "#524567" : win.signal
                    }
                }

                Loader {
                    objectName: "clockFace"
                    active: !win.occupied
                    x: pose.left; y: pose.middleY - height / 2
                    width: pose.faceWidth; height: pose.faceHeight
                    rotation: pose.angle
                    sourceComponent: Item {
                        id: selection
                        Item {
                            id: specimen
                            width: 780; height: 209; anchors.centerIn: parent
                            scale: selection.width / width
                            Loader {
                                anchors.fill: parent
                                sourceComponent: win.fluid ? softDay : angularDay
                                Component {
                                    id: angularDay
                                    Widgets.DayIndex {
                                        dayFamily: win.dayFamily; detailFamily: win.smallFamily
                                        briefDate: faceStrip.briefDate
                                        trackingOffset: faceStrip.trackingOffset
                                        timeLabel: win.timeLabel; signal: faceStrip.chosenInk
                                    }
                                }
                                Component {
                                    id: softDay
                                    Widgets.OffcutClock {
                                        fluid: true; dayFamily: win.dayFamily; detailFamily: win.smallFamily
                                        briefDate: faceStrip.briefDate
                                        trackingOffset: faceStrip.trackingOffset
                                        timeLabel: win.timeLabel; typeInk: faceStrip.chosenInk
                                    }
                                }
                            }
                            Login.PressMark {
                                visible: !win.fluid
                                x: 43; y: 10; width: 56; height: 40
                                paper: faceStrip.inkChoice === 0 ? "#f2efdf" : faceStrip.chosenInk
                                progress: 1; line: 3
                            }
                        }
                        Item {
                            anchors.fill: parent
                            visible: win.editing
                            DragSurface { objectName: "moveArea"; anchors.fill: parent; kind: win.margin ? win.tool : "Move" }

                            // Registration marks show the actual rotated bounds.
                            Repeater {
                                model: 4
                                Item {
                                    required property int index
                                    x: index % 2 ? selection.width : 0
                                    y: index >= 2 ? selection.height : 0
                                    Rectangle { x: parent.index % 2 ? -17 : 0; width: 17; height: 2; color: win.fluid ? "#54496e" : win.signal }
                                    Rectangle { y: parent.index >= 2 ? -17 : 0; width: 2; height: 17; color: win.fluid ? "#54496e" : win.signal }
                                }
                            }
                            Loader {
                                anchors.fill: parent
                                active: win.editing && !win.margin
                                sourceComponent: Placement.ChaseHandles {
                                    id: handles
                                    angle: pose.angle; span: pose.span
                                    fluid: win.fluid; stock: win.stock; paper: win.paper
                                    signal: win.signal; signalInk: win.signalInk
                                    labelFamily: win.fluid ? win.sans : win.mono
                                    DragSurface { parent: handles.rotationTarget; objectName: "turnHandle"; anchors.fill: parent; kind: "Rotate" }
                                    DragSurface { parent: handles.resizeTarget; objectName: "spanHandle"; anchors.fill: parent; kind: "Resize" }
                                }
                            }
                        }
                    }
                }
            }
        }

        FaceStrip {
            id: faceStrip
            objectName: "appearanceStrip"
            fluid: win.fluid
            visible: win.faceOpen && win.editing && !win.occupied
            anchors.bottom: parent.bottom; width: parent.width
            height: implicitHeight
        }
        Loader {
            id: marginPanel
            anchors.right: parent.right; y: header.height; height: viewport.height
            active: win.margin && win.editing && !win.occupied
            sourceComponent: Placement.MarginPanel {
                fluid: win.fluid; stock: win.stock; paper: win.paper; signal: win.signal
                sans: win.sans; labelFamily: win.fluid ? win.sans : win.mono
                tool: win.tool; activeTool: win.activeTool
                column: pose.column; span: pose.span; angle: pose.angle
                minimum: tool === "Rotate" ? -180 : tool === "Move" ? 1 : 3
                maximum: tool === "Rotate" ? 180 : tool === "Move" ? 13 - pose.span : 12 - pose.column
                onToolRequested: value => win.tool = value
                onValueRequested: value => {
                    if (tool === "Rotate") pose.angle = value;
                    else if (tool === "Move") pose.column = value - 1;
                    else pose.span = value;
                }
            }
        }
    }
    Timer {
        interval: 180
        running: win.args.includes("--out")
        onTriggered: {
            const out = win.args[win.args.indexOf("--out") + 1];
            sheet.grabToImage(image => Qt.exit(image.saveToFile(out) ? 0 : 1));
        }
    }
}
