pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: sheet
    visible: true
    readonly property bool fluid: Qt.application.arguments.includes("--fluid")
    readonly property int columnWidth: Qt.application.arguments.includes("--narrow") ? 220 : 304
    readonly property string sans: fluid ? "Inter" : "Roboto Condensed"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property color paper: "#edece6"
    readonly property color muted: "#b7bbbf"
    readonly property color surface: "#141c22"
    readonly property color accent: "#ffd09a"
    readonly property int caption: 12
    readonly property int actionSize: 15
    readonly property int heading: 26
    width: columnWidth * 2 + 60
    height: layout.implicitHeight + 40
    title: "Typeset this picture"

    component LabelText: Text {
        font.family: sheet.sans
        font.pixelSize: sheet.actionSize
        textFormat: Text.PlainText
        color: sheet.paper
    }

    // An invented crescent, drawn from the same light field in continuous tone and in type.
    component Moon: Canvas {
        id: moon
        property real split: 1
        onSplitChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.fillStyle="#17242e"; c.fillRect(0,0,width,height);
            const r=height*0.62, cx=width*0.54, cy=height*0.62;
            const cut=width*split;
            c.save();
            c.beginPath(); c.rect(0,0,cut,height); c.clip();
            for(let y=0;y<height;y+=2) {
                for(let x=0;x<cut;x+=2) {
                    const u=(x-cx)/r,v=(y-cy)/r,z=1-u*u-v*v;
                    if(z<0) continue;
                    const light=Math.max(0,+0.68*u-0.47*v+0.19*Math.sqrt(z));
                    const band=0.91+0.08*Math.sin(27*v+1.7*Math.sin(5*u));
                    c.fillStyle=Qt.rgba((48+198*light)*band/255,(48+134*light)*band/255,(56+68*light)*band/255,1);
                    c.fillRect(x,y,2,2);
                }
            }
            c.restore();
            if(split===1) return;
            c.fillStyle="#11171d"; c.fillRect(cut,0,width-cut,height);
            const step=height<60 ? 6 : 9;
            c.font=step+"px monospace"; c.textBaseline="top";
            const chars=" .:itEA";
            for(let y=0;y<height;y+=step) {
                for(let x=cut;x<width;x+=step*0.75) {
                    const u=(x-cx)/r,v=(y-cy)/r,z=1-u*u-v*v;
                    if(z<0) continue;
                    const light=Math.max(0,+0.68*u-0.47*v+0.19*Math.sqrt(z));
                    c.fillStyle=sheet.accent;
                    c.fillText(chars[Math.min(6,1+Math.floor(light*6))],x,y);
                }
            }
        }
    }

    component TypesetAction: AbstractButton {
        id: key
        required property bool splitPrint
        property bool busy: false
        implicitHeight: Math.max(splitPrint ? 80 : 62, words.implicitHeight+24)
        enabled: !busy
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.name: busy ? "Typesetting… about half a minute" : "Typeset this picture"
        background: Rectangle {
            radius: sheet.fluid ? 8 : 0
            color: key.splitPrint ? "#1a252c" : key.busy ? "#746757" : sheet.accent
            border.color: key.visualFocus || key.hovered ? sheet.paper : "#445259"
            border.width: key.splitPrint || key.visualFocus || key.hovered ? 1 : 0
        }
        contentItem: RowLayout {
            spacing: 10
            Item { implicitWidth: 2 }
            Item {
                Layout.preferredWidth: key.splitPrint ? 70 : 34
                implicitHeight: key.splitPrint ? 46 : 32
                Moon { anchors.fill: parent; visible: key.splitPrint; split: 0.44 }
                LabelText {
                    visible: !key.splitPrint; anchors.centerIn: parent
                    text: "Tt"; font.family: sheet.mono; font.pixelSize: sheet.heading; font.bold: true; color: "#24211e"
                }
            }
            ColumnLayout {
                id: words
                Layout.fillWidth: true
                spacing: 2
                LabelText {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: key.busy ? "Typesetting…" : "Typeset this picture"
                    font.pixelSize: sheet.actionSize
                    font.weight: Font.DemiBold
                    color: key.splitPrint ? sheet.paper : "#201b17"
                }
                LabelText {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: key.busy ? "About half a minute" : "Save and set a lettered copy"
                    font.pixelSize: sheet.caption; color: key.splitPrint ? sheet.muted : "#382e22"
                }
            }
            Item { implicitWidth: 2 }
        }
    }

    component Excerpt: ColumnLayout {
        id: sample
        required property bool splitPrint
        property bool busy: false
        property bool finished: false
        spacing: 8
        LabelText {
            text: sample.splitPrint ? "B · Split print" : "A · Type block"
            font.pixelSize: sheet.heading; font.weight: Font.DemiBold
        }
        Moon { Layout.fillWidth: true; Layout.preferredHeight: sheet.columnWidth*9/16; split: sample.finished ? 0 : 1 }
        LabelText { text: sample.finished ? "Crescent.type.png" : "Crescent.png"; font.pixelSize: sheet.caption; font.family: sheet.fluid ? sheet.sans : sheet.mono }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 34; radius: sheet.fluid ? 16 : 0; color: "#263138"
            LabelText { anchors.centerIn: parent; text: "Colours from this wallpaper: off"; font.pixelSize: sheet.caption }
        }
        TypesetAction {
            visible: !sample.finished
            Layout.fillWidth: true; splitPrint: sample.splitPrint; busy: sample.busy
            onClicked: { sample.busy=true; finish.start(); }
        }
        LabelText {
            visible: sample.finished; Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "A typeset plate: its accent follows the palette"; color: sheet.muted; font.pixelSize: sheet.caption
        }
        Timer { id: finish; interval: 1700; onTriggered: { sample.finished=true; sample.busy=false; } }
    }

    Rectangle {
        id: page; anchors.fill: parent; color: sheet.surface
        ColumnLayout {
            id: layout; x: 20; y: 16; spacing: 14; width: parent.width-40
            RowLayout {
                Layout.fillWidth: true; spacing: 20
                Excerpt { Layout.preferredWidth: sheet.columnWidth; Layout.alignment: Qt.AlignTop; splitPrint: false }
                Excerpt { Layout.preferredWidth: sheet.columnWidth; Layout.alignment: Qt.AlignTop; splitPrint: true }
            }
            LabelText { text: "While typesetting"; color: sheet.muted; font.pixelSize: sheet.caption }
            RowLayout {
                Layout.fillWidth: true; spacing: 20
                TypesetAction { Layout.preferredWidth: sheet.columnWidth; Layout.alignment: Qt.AlignTop; splitPrint: false; busy: true }
                TypesetAction { Layout.preferredWidth: sheet.columnWidth; Layout.alignment: Qt.AlignTop; splitPrint: true; busy: true }
            }
        }
    }
    Timer {
        interval: 250; running: Qt.application.arguments.includes("--out")
        onTriggered: {
            const args=Qt.application.arguments, path=args[args.indexOf("--out")+1];
            page.grabToImage(r=>Qt.exit(r.saveToFile(path) ? 0 : 1));
        }
    }
}
