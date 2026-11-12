import QtQuick

// A plane in the desktop's form (Z146): Angular draws the montage Plane with both sides at 78°, Fluid a rounded
// plate. Same roles and text colour either way, so a part can be written once for both forms.
Item {
    id: root
    property string role: "paper"   // paper | ink | signal | clear
    // Angular: which sides lean at 78° (Plane.slant); both by default.
    property int slant: 3
    property bool fluid: Design.fluid
    // Fluid: corner radius; a pill when it is at least half the height.
    property real radius: Design.roundSmall
    readonly property color textColor: plane.textColor

    Plane {
        id: plane
        anchors.fill: parent
        visible: !root.fluid
        role: root.role
        slant: root.slant
    }
    Rectangle {
        anchors.fill: parent
        visible: root.fluid
        radius: Math.min(root.radius, height / 2)
        color: plane.fillColor
    }
}
