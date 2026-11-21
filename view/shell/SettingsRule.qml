import QtQuick
import qs.view.fluid
import qs.view.ui

Loader {
    sourceComponent: Design.fluid ? straight : cut
    Component { id: straight; Rectangle { implicitHeight: 1; color: FluidTokens.rule } }
    Component { id: cut; FRule {} }
}
