pragma Singleton
import QtQuick
import "Elements.js" as Table

// The periodic table for the view (Elements.js): the data, and the element of the day.
QtObject {
    readonly property var elements: Table.ELEMENTS
    function ofDay(date) { return Table.ofDay(date); }
}
