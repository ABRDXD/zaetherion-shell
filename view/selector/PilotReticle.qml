import QtQuick

// Pilot light's pointer in region mode: a lime cross with an open centre at (pointX, pointY) of its parent.
// Each arm is drawn twice, a dark outline under the lime line; the ends are square, as in the mock.
Item {
    id: root
    property real pointX: 0
    property real pointY: 0
    readonly property int reach: EclipseLook.reticleGap + EclipseLook.reticleArm
    x: pointX - reach
    y: pointY - reach
    width: 2 * reach
    height: 2 * reach

    component Arm: Rectangle {
        property bool across: true
        property bool far: false // right or down of the centre
        property int thickness: EclipseLook.reticleWidth
        readonly property real start: far ? root.reach + EclipseLook.reticleGap : 0
        width: across ? EclipseLook.reticleArm : thickness
        height: across ? thickness : EclipseLook.reticleArm
        x: across ? start : root.reach - thickness / 2
        y: across ? root.reach - thickness / 2 : start
    }

    Arm { across: true; far: false; thickness: EclipseLook.reticleOutline; color: EclipseLook.footer }
    Arm { across: true; far: true; thickness: EclipseLook.reticleOutline; color: EclipseLook.footer }
    Arm { across: false; far: false; thickness: EclipseLook.reticleOutline; color: EclipseLook.footer }
    Arm { across: false; far: true; thickness: EclipseLook.reticleOutline; color: EclipseLook.footer }
    Arm { across: true; far: false; color: EclipseLook.lime }
    Arm { across: true; far: true; color: EclipseLook.lime }
    Arm { across: false; far: false; color: EclipseLook.lime }
    Arm { across: false; far: true; color: EclipseLook.lime }
}
