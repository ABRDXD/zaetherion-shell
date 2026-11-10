import qs.view.ui
import QtQuick
import QtQuick.Layouts

// The session's debrief and the streak (M11, docs/CORE.md §11), on the Timers room's field: what was planned and what
// was done, how many tasks were finished in it, where the time went by the host's own focus tracker (app classes
// only, never titles; nothing when the host keeps none), and the last fourteen days of session time. Static: it is
// drawn once per change and never moves.
Plane {
    id: root
    // core.sessionData.last and .streak
    property var debrief: null
    property var streak: null
    signal dismissed()
    role: "paper"
    backing: true
    slant: 2
    implicitHeight: column.implicitHeight + 24
    function stamp(seconds) {
        return Clock.formatSeconds(Math.max(0, seconds ?? 0));
    }
    readonly property var apps: debrief?.apps
    readonly property real appsTotal: (apps ?? []).reduce((n, a) => n + a[1], 0)
    readonly property real most: Math.max(1, ...(streak?.minutes ?? [0]))

    ColumnLayout {
        id: column
        x: 14
        y: 12
        width: root.width - 28
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            visible: root.debrief !== null
            FText {
                Layout.fillWidth: true
                text: "DEBRIEF / " + String(root.debrief?.preset ?? "").toUpperCase()
                technical: true
                color: root.textColor
            }
            FButton {
                symbol: "close"
                hint: "Put the debrief away"
                Accessible.name: "Put the debrief away"
                onClicked: root.dismissed()
            }
        }
        GridLayout {
            visible: root.debrief !== null
            columns: 2
            columnSpacing: 18
            rowSpacing: 2
            FText { text: "PLANNED"; technical: true; color: Design.muted }
            FText { text: "DONE"; technical: true; color: Design.muted }
            FText { text: root.stamp(root.debrief?.planned); headline: true; font.pixelSize: Design.readout; font.weight: Font.Light }
            FText {
                text: root.stamp(root.debrief?.seconds)
                headline: true
                font.pixelSize: Design.readout
                font.weight: Font.Light
                color: root.debrief?.completed ? Design.warm : Design.ink
            }
        }
        FText {
            visible: root.debrief !== null
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: (root.debrief?.completed ? "RAN TO THE END" : "ENDED EARLY") + " · TASKS FINISHED " + (root.debrief?.tasks ?? 0)
            technical: true
            color: Design.muted
        }
        Hairline { Layout.fillWidth: true; visible: root.debrief !== null }
        FText {
            visible: root.debrief !== null
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.apps === undefined ? "FOCUS / NOT KEPT ACROSS A RESTART"
                : root.apps === null || root.apps.length === 0 ? "FOCUS / THE HOST KEPT NO RECORD" : "FOCUS / BY THE HOST'S TRACKER"
            technical: true
            color: Design.faint
        }
        Repeater {
            model: root.debrief !== null ? (root.apps ?? []) : []
            RowLayout {
                id: app
                objectName: "session-app"
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                FText {
                    Layout.preferredWidth: 96
                    text: String(app.modelData[0]).toUpperCase()
                    technical: true
                    elide: Text.ElideRight
                    color: Design.muted
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    Rectangle {
                        width: parent.width * app.modelData[1] / Math.max(1, root.appsTotal)
                        height: parent.height
                        color: Design.accent
                    }
                }
                FText {
                    text: Math.round(app.modelData[1] / 60) + " MIN"
                    technical: true
                    color: Design.muted
                }
            }
        }
        Hairline { Layout.fillWidth: true; visible: root.debrief !== null && root.streak !== null }
        FText {
            visible: root.streak !== null
            Layout.fillWidth: true
            text: "STREAK " + (root.streak?.current ?? 0) + ((root.streak?.current ?? 0) === 1 ? " DAY" : " DAYS")
                  + " · BEST " + (root.streak?.best ?? 0)
            wrapMode: Text.Wrap
            technical: true
            color: (root.streak?.current ?? 0) > 0 ? Design.accent : Design.muted
        }
        // Fourteen days of session time, today on the right.
        Row {
            visible: root.streak !== null
            Layout.fillWidth: true
            height: 28
            spacing: 3
            Repeater {
                model: root.streak?.minutes ?? []
                Item {
                    id: day
                    required property int modelData
                    required property int index
                    width: (column.width - 13 * 3) / 14
                    height: 28
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(1, parent.height * day.modelData / root.most)
                        color: day.modelData >= 10 ? (day.index === 13 ? Design.accent : Design.ink) : Design.line
                    }
                }
            }
        }
    }
}
