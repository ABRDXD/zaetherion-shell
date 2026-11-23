import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SurveyorNotes.js" as Notes
import "NightLog.js" as NightLog
import "Survey.js" as Survey
import "../overdrive/FalseRoom.js" as FalseRoom

Rectangle {
    id: root
    signal closeRequested
    // The core's discovery snapshot (M15): the fragments found so far, set by the Shell.
    property var discovery: null
    color: Design.background
    // The notes in view, in this item's coordinates, with how worn each is on the tape (view/strata/Tape.qml reads
    // them in Overdrive): [{y, h, wear, crease, label}]. Each second a note is in view while the archive is open is a
    // second of tape played over it (ViewState.playTape); wear grows with it, 63 % after five minutes.
    property var spans: []
    function wearOf(label) {
        return 1 - Math.exp(-(ViewState.tapeWear[label] ?? 0) / 300);
    }
    // A stable place for the crease in each note, from its label.
    function creaseOf(label) {
        let h = 7;
        for (let i = 0; i < label.length; i++)
            h = (h * 31 + label.charCodeAt(i)) % 1009;
        return 0.2 + 0.6 * h / 1009;
    }
    function updateSpans() {
        if (!notes.visible) {
            spans = [];
            return;
        }
        const top = notes.mapToItem(root, 0, 0).y, bottom = top + notes.height, out = [];
        for (let i = 0; i < noteRepeater.count; i++) {
            const it = noteRepeater.itemAt(i);
            if (!it)
                continue;
            const y = it.mapToItem(root, 0, 0).y, a = Math.max(top, y), b = Math.min(bottom, y + it.height);
            if (b - a < 1)
                continue;
            const label = it.modelData.label;
            out.push({ y: a, h: b - a, top: y, height: it.height, wear: wearOf(label), crease: creaseOf(label), label: label });
        }
        spans = out;
        // A note seen for the first time is filed today (its revision history, SurveyorNotes.revision).
        if (ViewState.loreEnabled)
            ViewState.fileNotes(out.map(s => s.label));
    }
    // The tape runs while the archive is open with its fiction on: a second for each note at least half in view.
    Timer {
        interval: 1000
        repeat: true
        running: ViewState.loreEnabled && root.visible
        onTriggered: {
            ViewState.playTape(root.spans.filter(s => s.h >= Math.min(60, s.height * 0.5)).map(s => s.label));
            root.updateSpans();
        }
    }
    // A note's text as set in the archive (the house's spaced capitals); the ghosts and the tear reuse it.
    component NoteText: FText {
        property var entry: ({})
        property bool first: false
        text: entry.text ?? ""
        wrapMode: Text.Wrap
        font.pixelSize: entry.record ? Design.control : Design.readout
        font.weight: first || entry.wrong || entry.record ? Font.Light : Font.Normal
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 16
        RowLayout {
            FText {
                text: "OPTIONAL / FIELD ARCHIVE"
                technical: true
                color: Design.accent
                Layout.fillWidth: true
            }
            FButton {
                symbol: "close"
                hint: "Close archive"
                onClicked: root.closeRequested()
            }
        }
        FHeading {
            number: "∅"
            title: ViewState.loreEnabled ? "A discrepancy in the margins." : "An unopened envelope."
            subtitle: "Fiction / no system consequences"
        }
        FText {
            Layout.fillWidth: true
            text: ViewState.loreEnabled
                  ? "These are observations from a fictional survey.\nNothing here is a system warning." :
                    "This room contains optional atmospheric fiction.\nNo jump scares, sound, fake faults, or interference with your work.\nNew fragments appear as you explore the interface."
            wrapMode: Text.Wrap
            color: Design.muted
            font.pixelSize: Design.body
        }
        FButton {
            visible: !ViewState.loreEnabled
            label: "Open the field archive"
            primary: true
            onClicked: ViewState.loreEnabled = true
        }
        // The notes, one per fragment unlocked so far (SurveyorNotes.js), scrolled when they outgrow the room.
        Flickable {
            id: notes
            visible: ViewState.loreEnabled
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            readonly property int surveyed: ViewState.visited.length
            readonly property int days: ViewState.surveyDays.length
            readonly property var shown: Notes.unlocked(surveyed, days)
            readonly property int coming: Notes.next(surveyed)
            readonly property int comingDay: Notes.nextDay(days)
            // Opening the archive with its fiction on counts the day (once per day).
            Component.onCompleted: { ViewState.markSurveyDay(); ViewState.markNight(); Qt.callLater(root.updateSpans); }
            onContentYChanged: root.updateSpans()
            onHeightChanged: root.updateSpans()
            onVisibleChanged: if (visible) { ViewState.markSurveyDay(); ViewState.markNight(); }
            ColumnLayout {
                id: column
                width: notes.width - 16
                onImplicitHeightChanged: Qt.callLater(root.updateSpans)
                spacing: 18
                Repeater {
                    id: noteRepeater
                    model: notes.shown
                    ColumnLayout {
                        id: note
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 6
                        // The unsigned note keeps its place in the numbering but not its signature; the team's
                        // records are filed apart, unsigned by the surveyor, in the faint ink of a carbon copy.
                        FText {
                            text: modelData.label + (modelData.wrong ? "  ·  NOT FILED BY THE SURVEY TEAM" : "")
                            technical: true
                            color: modelData.wrong ? Design.danger : modelData.record ? Design.faint : Design.accent
                        }
                        // Its revision history: when it was filed, and a revision for every two minutes it has been read.
                        FText {
                            readonly property string line: Notes.revision(note.modelData.label, ViewState.noteFiled[note.modelData.label] ?? "",
                                                                          ViewState.tapeWear[note.modelData.label] ?? 0, ViewState.surveyDays.length,
                                                                          ViewState.fieldBook?.seed ?? 0, notes.shown.map(n => n.label))
                            visible: line !== ""
                            text: line
                            technical: true
                            font.pixelSize: 9   // scale: a note's metadata, under its label
                            color: Design.faint
                        }
                        // The note's text. The team's records and the unsigned note are copies of copies: a red
                        // and a cyan ghost each slip a pixel aside, and the unsigned note tears, one band of it
                        // shifted. All static, painted with the text.
                        Item {
                            id: page
                            readonly property bool smeared: !!(note.modelData.record || note.modelData.wrong)
                            Layout.fillWidth: true
                            implicitHeight: body.implicitHeight
                            NoteText { entry: note.modelData; first: note.index === 0; width: page.width; visible: page.smeared; x: -1.5; y: 0.5; color: Design.danger; opacity: 0.35 }
                            NoteText { entry: note.modelData; first: note.index === 0; width: page.width; visible: page.smeared; x: 1.5; y: -0.5; color: Design.accent; opacity: 0.28 }
                            NoteText { id: body; entry: note.modelData; first: note.index === 0; width: page.width; color: page.smeared ? Design.muted : Design.ink }
                            Item {
                                visible: !!note.modelData.wrong
                                y: Math.round(body.height * 0.42)
                                width: page.width + 12
                                height: Math.max(5, Math.round(body.height * 0.07))
                                clip: true
                                Rectangle { anchors.fill: parent; color: Design.background }
                                NoteText { entry: note.modelData; width: page.width; x: 9; y: -parent.y; color: Design.muted }
                            }
                        }
                        // A rule's curve-rendered shape ignores the Flickable's clip: drawn only while in view.
                        FRule {
                            Layout.fillWidth: true
                            readonly property real at: note.y + y
                            opacity: at >= notes.contentY && at <= notes.contentY + notes.height ? 1 : 0
                        }
                    }
                }
                // The field book: what the surveyor measured while it wandered the panel in Overdrive (Survey.js).
                ColumnLayout {
                    // Under the surveyor's own lines, its notes on the False Room (W1), once the errors agree.
                    readonly property var book: Survey.lines(Survey.clean(ViewState.fieldBook, 0), null)
                        .concat(FalseRoom.notes(ViewState.fieldBook, Survey.locus(ViewState.fieldBook?.seed ?? 0), ViewState.falseRoomSpent))
                    visible: book.length > 0
                    Layout.fillWidth: true
                    spacing: 4
                    FText {
                        text: "FIELD BOOK / KEPT BY THE SURVEYOR"
                        technical: true
                        color: Design.accent
                    }
                    Repeater {
                        model: parent.book
                        FText {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.text
                            technical: true
                            wrapMode: Text.Wrap
                            color: modelData.tone === "error" ? Design.danger : modelData.tone === "faint" ? Design.faint : Design.muted
                        }
                    }
                }
                // Found in the margins (M15): each fragment discovery has turned up, newest first.
                ColumnLayout {
                    readonly property var found: (root.discovery?.found ?? []).slice().reverse()
                    visible: found.length > 0
                    Layout.fillWidth: true
                    spacing: 6
                    FText {
                        text: "FOUND IN THE MARGINS / " + parent.found.length + " OF " + (root.discovery?.total ?? 0)
                        technical: true
                        color: Design.accent
                    }
                    Repeater {
                        model: parent.found
                        ColumnLayout {
                            id: fragment
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            FText {
                                text: Qt.formatDate(new Date(fragment.modelData.at), "d MMM yyyy").toUpperCase() + " / " + fragment.modelData.whisper.toUpperCase()
                                technical: true
                                color: Design.faint
                            }
                            FText {
                                Layout.fillWidth: true
                                text: fragment.modelData.text
                                wrapMode: Text.Wrap
                                font.pixelSize: Design.control
                                color: Design.muted
                            }
                        }
                    }
                }
                FText {
                    visible: Notes.night(Clock.date.getHours())
                    Layout.fillWidth: true
                    text: "NIGHT NOTE\n" + Notes.NIGHT
                    wrapMode: Text.Wrap
                    font.pixelSize: Design.control
                    color: Design.muted
                }
                // The night log: the moon on each night the archive was opened late, newest first.
                FText {
                    visible: ViewState.nightLog.length > 0
                    Layout.fillWidth: true
                    text: "NIGHT LOG / THE SURVEYOR WATCHED THE MOON FROM THE DOORWAY\n"
                          + ViewState.nightLog.slice().reverse().slice(0, 12).map(e => NightLog.line(e)).join("\n")
                    technical: true
                    wrapMode: Text.Wrap
                    color: Design.faint
                }
                FText {
                    visible: notes.coming < 0
                    Layout.fillWidth: true
                    text: "FOUND PINNED TO THE ATLAS\n" + Notes.OWN
                    technical: true
                    wrapMode: Text.Wrap
                    color: Design.muted
                }
                FText {
                    visible: notes.coming >= 0
                    text: "NEXT FRAGMENT / " + notes.coming + (notes.coming === 1 ? " ROOM" : " ROOMS") + " SURVEYED"
                    technical: true
                    color: Design.faint
                }
                FText {
                    visible: notes.comingDay >= 0
                    text: "THE LOG CONTINUES / DAY " + notes.comingDay + " OF THE SURVEY"
                    technical: true
                    color: Design.faint
                }
            }
        }
        Item {
            visible: !ViewState.loreEnabled
            Layout.fillHeight: true
        }
        RowLayout {
            FCreature {}
            Item {
                Layout.fillWidth: true
            }
            FButton {
                visible: ViewState.loreEnabled
                label: "Seal archive"
                onClicked: ViewState.loreEnabled = false
            }
        }
    }
    // The sheet's grain, over everything but taking no input.
    ArchiveGrain {
        anchors.fill: parent
        visible: ViewState.loreEnabled
    }
}
