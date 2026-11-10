import qs.view.cues
import qs.view.ui
import QtQuick
import "DayTime.js" as T

// Home's day ruler, under the clock (docs/OVERDRIVE.md §21). It labels civil hours, but daylight always takes the
// same share of its width and night the rest, from today's real sunrise and sunset (atlas #65): a winter's few bright
// hours are drawn wide and a summer's many packed close, so the season shows in the ruler's segmentation. Now is a short
// accent mark; it moves once a minute. In Overdrive a second row of ticks above the line counts sidereal hours, which
// come round four minutes earlier every day (#63), and a cursor follows the sky's time-lapse (HomeSky.lapse). Now and
// then, on opening, the moment is drawn in three frames at once, civil, solar and sidereal, all correct and all apart
// (W4); hovering one names its frame and explains nothing. Over the hours when a room keeps being opened, a small
// hollow window straddles the line (#66); hovering it names the room. It predicts nothing.
Item {
    id: root
    property var sky: null
    property var journey: null
    property real lapse: 0
    property bool active: false
    implicitHeight: 16
    readonly property real lineY: 4
    function local(iso) {
        if (!iso) return NaN;
        const d = new Date(iso);
        return d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600;
    }
    readonly property real rise: local(sky?.sun?.rise)
    readonly property real set: local(sky?.sun?.set)
    // Civil time now, read once a minute.
    readonly property real now: { Clock.minuteStr; const d = new Date(); return d.getHours() + d.getMinutes() / 60; }
    // Local sidereal time now, in hours, carried on from the sky's own moment.
    readonly property real lst: {
        Clock.minuteStr;
        if (!sky || !Number.isFinite(sky.sidereal)) return NaN;
        return ((sky.sidereal / 15 + (Date.now() - new Date(sky.at).getTime()) / 3600000 * 1.0027379) % 24 + 24) % 24;
    }
    readonly property bool overdrive: Motion.engaged && !Motion.reduced
    // Misregistration: about one opening in nine (in Overdrive, every opening).
    property bool misregistered: false
    onActiveChanged: if (active) misregistered = Math.random() < 1 / 9
    readonly property bool frames: (misregistered || overdrive) && Number.isFinite(lst)
    function px(h) { return T.x(h, rise, set) * width; }

    // The line, and today's daylight on it a little heavier.
    Rectangle { y: root.lineY; width: root.width; height: 1; color: Design.line }
    Rectangle {
        visible: Number.isFinite(root.rise) && Number.isFinite(root.set)
        x: root.px(root.rise)
        y: root.lineY - 1
        width: root.px(root.set) - x
        height: 3
        color: Design.calendarAccent
        opacity: 0.7
    }
    // Civil hours: a tick each, longer and labelled every six.
    Repeater {
        model: T.ticks(root.rise, root.set)
        Item {
            required property var modelData
            x: modelData.x * root.width
            Rectangle { x: -0.5; y: root.lineY + 1; width: 1; height: modelData.major ? 5 : 2; color: modelData.major ? Design.muted : Design.line }
            FText {
                visible: modelData.label !== ""
                x: modelData.h === 0 ? 2 : -implicitWidth / 2
                y: root.lineY + 3
                text: modelData.label
                technical: true
                font.pixelSize: 9   // scale: the ruler's hour figures
                color: Design.faint
            }
        }
    }
    // Recurrence windows: the hours a room keeps being opened.
    Repeater {
        model: T.recurrence(root.journey)
        Item {
            required property var modelData
            x: root.px(modelData.h) + 1
            y: root.lineY - 3
            width: Math.max(3, root.px(modelData.h + 1) - root.px(modelData.h) - 2)
            height: 7
            Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Design.muted; opacity: 0.8 }
            HoverHandler { id: windowHover; margin: 3 }
            FText {
                visible: windowHover.hovered
                x: 0
                y: -12
                text: parent.modelData.number + " " + parent.modelData.room.toUpperCase() + " · " + T.hhmm(parent.modelData.h)
                technical: true
                font.pixelSize: 9   // scale: the ruler's hour figures
                color: Design.muted
            }
        }
    }
    // Now.
    Rectangle { x: root.px(root.now) - 1; y: root.lineY - 3; width: 2; height: 9; color: Design.accent }

    // Overdrive: the sidereal margin above the line, and the time-lapse's cursor.
    Repeater {
        model: root.overdrive && Number.isFinite(root.lst) ? T.siderealTicks(root.now, root.lst, root.rise, root.set) : []
        Rectangle {
            required property var modelData
            x: modelData.x * root.width - 0.5
            y: root.lineY - (modelData.k % 6 === 0 ? 5 : 3)
            width: 1
            height: modelData.k % 6 === 0 ? 5 : 3
            color: Design.accent
            opacity: (modelData.k === 0 ? 1 : 0.5) * Motion.drive
        }
    }
    FText {
        visible: root.overdrive && Number.isFinite(root.lst)
        anchors.right: parent.right
        y: root.lineY - 12
        text: "SIDEREAL " + T.hhmm(root.lst)
        technical: true
        font.pixelSize: 9   // scale: the ruler's hour figures
        color: Design.accent
        opacity: 0.8 * Motion.drive
    }
    Rectangle {
        visible: root.overdrive && Math.abs(root.lapse) > 0.01
        x: root.px(((root.now + root.lapse) % 24 + 24) % 24) - 3
        y: root.lineY - 3
        width: 7
        height: 7
        rotation: 45
        color: "transparent"
        border.width: 1
        border.color: Design.accent
        opacity: Motion.drive
    }
    // The moment in three frames (W4).
    Repeater {
        model: root.frames ? T.frames(root.now, root.lst, root.rise, root.set).slice(1) : []
        Item {
            required property var modelData
            x: modelData.x * root.width
            width: 1
            height: root.implicitHeight
            Rectangle { x: -0.5; y: root.lineY - 4; width: 1; height: 11; color: modelData.frame === "SOLAR" ? Design.calendarAccent : Design.accent; opacity: 0.85 }
            HoverHandler { id: hover; margin: 4 }
            FText {
                visible: hover.hovered
                x: 4
                y: root.lineY - 14
                text: modelData.frame
                technical: true
                font.pixelSize: 9   // scale: the ruler's hour figures
                color: Design.muted
            }
        }
    }
}
