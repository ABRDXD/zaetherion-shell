import qs.view.ui
import QtQuick

// The Codex as a planet: today's element. Changes once a day; nothing ticks.
Face {
    id: root
    readonly property var element: Periodic.ofDay(new Date())
    figure: element.symbol
    brief: element.name.toUpperCase()
    note: "ELEMENT " + element.z
    detail: element.label

    Accessible.role: Accessible.StaticText
    Accessible.name: "Element of the day, " + element.name
}
