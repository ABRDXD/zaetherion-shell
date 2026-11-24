pragma ComponentBehavior: Bound
import QtQuick
import qs.view.cues
import qs.view.ui

// One screen of the lock (SURFACES §8; Astra's PasswordLockFace, owner's pick 24 Nov). An opaque base first, so a
// lock is never see-through; the wallpaper over it (Z89: never a screen capture); the face. The password is typed
// into a field the face never sees (it gets the length only). If the face cannot load (F8), a plain card with the
// field stands in: still locked. `lock` is the LockHost (or a test's stand-in) that holds the shared state.
FocusScope {
    id: root
    required property var lock
    readonly property alias field: field
    readonly property bool faceLoaded: face.status === Loader.Ready
    focus: true

    // The arrival (owner, 24 Nov: "arrival + living sky"): the face cuts in from the left as the lock comes up and
    // goes the same way when it unlocks (LockHost keeps the screen covered for that). Reduced motion: no travel.
    property real arrival: 0
    readonly property bool leaving: root.lock.leaving === true
    Component.onCompleted: { cut.to = 1; cut.restart(); }
    onLeavingChanged: if (leaving) { cut.to = 0; cut.restart(); }
    NumberAnimation {
        id: cut
        target: root; property: "arrival"
        duration: Motion.reduced ? 0 : (root.leaving ? 260 : 420)
        easing.type: root.leaving ? Motion.cutOut : Motion.cutIn
    }
    Activity { name: "lock.arrival"; running: cut.running }

    // The living sky (Z89 sky cuts): a few faint planes on the 78° seam, in the palette's accent and ink, drifting
    // slowly over the wallpaper. Positions come from a slow clock (no endless animation; nothing fast moves while
    // typing). Still with reduced motion.
    property real skyTime: 0
    Timer {
        interval: 100
        repeat: true
        running: !Motion.reduced && root.visible
        onTriggered: root.skyTime += 0.1
    }
    Rectangle { anchors.fill: parent; color: "#06070a" }
    Image {
        anchors.fill: parent
        visible: root.lock.wallpaper !== ""
        source: root.lock.wallpaper ? "file://" + root.lock.wallpaper : ""
        sourceSize.width: 1920
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Item {
        id: sky
        objectName: "lockSky"
        anchors.fill: parent
        opacity: root.arrival
        Repeater {
            // [height share, top share, width share, speed px/s, start share, accent?, alpha]
            model: [[0.62, 0.08, 0.16, 6, 0.10, true, 0.07], [0.80, 0.18, 0.08, 9, 0.55, false, 0.05],
                    [0.46, 0.40, 0.22, 4, 0.80, true, 0.05], [0.70, 0.02, 0.05, 12, 0.30, false, 0.06]]
            Rectangle {
                id: cutPlane
                required property var modelData
                readonly property real run: sky.width + width + sky.height * 0.21255656
                width: sky.width * modelData[2]
                height: sky.height * modelData[0]
                y: sky.height * modelData[1]
                x: ((modelData[4] * run + modelData[3] * root.skyTime) % run) - width
                color: Qt.alpha(modelData[5] ? Design.accent : Design.ink, modelData[6])
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.21255656, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            }
        }
    }
    // The face travels in from the left along the Cut timing as it fades up (no slanted clip: a clip on a skewed item
    // can paint its bounds solid on some renderers, and a lock must never show a box over the field).
    Item {
        width: parent.width
        height: parent.height
        x: -48 * (1 - root.arrival)
        opacity: root.arrival
    Loader {
        id: face
        objectName: "lockFace"
        anchors.fill: parent
        // The face's properties are required: give them at creation, then keep them bound.
        Component.onCompleted: setSource(root.lock.faceSource, {
            fluid: Design.fluid, timeText: Qt.formatTime(Clock.date, "HH:mm"), dateText: Qt.formatDate(Clock.date, "dddd, d MMMM yyyy"),
            maskLength: root.lock.maskLength, attempts: root.lock.attempts, reducedMotion: Motion.reduced,
            rejectionMs: root.lock.rejectionMs, mediaAvailable: !!root.lock.track, trackTitle: root.lock.track?.title ?? "",
            artist: root.lock.track?.artist ?? "", playing: root.lock.track?.playing === true,
            batteryFraction: root.lock.batteryFraction, holdProgress: root.lock.holdProgress })
        onLoaded: {
            const f = item;
            f.fluid = Qt.binding(() => Design.fluid);
            f.timeText = Qt.binding(() => Qt.formatTime(Clock.date, "HH:mm"));
            f.dateText = Qt.binding(() => Qt.formatDate(Clock.date, "dddd, d MMMM yyyy"));
            f.maskLength = Qt.binding(() => root.lock.maskLength);
            f.attempts = Qt.binding(() => root.lock.attempts);
            f.reducedMotion = Qt.binding(() => Motion.reduced);
            f.rejectionMs = Qt.binding(() => root.lock.rejectionMs);
            f.mediaAvailable = Qt.binding(() => !!root.lock.track);
            f.trackTitle = Qt.binding(() => root.lock.track?.title ?? "");
            f.artist = Qt.binding(() => root.lock.track?.artist ?? "");
            f.playing = Qt.binding(() => root.lock.track?.playing === true);
            f.batteryFraction = Qt.binding(() => root.lock.batteryFraction);
            f.holdProgress = Qt.binding(() => root.lock.holdProgress);
            f.mediaRequested.connect(action => root.lock.media(action));
            f.powerHoldStarted.connect(() => root.lock.holdStart());
            f.powerHoldEnded.connect(() => root.lock.holdEnd());
        }
    }
    }
    // F8: the face failed; the lock still asks for the password.
    Column {
        objectName: "plainCard"
        visible: face.status === Loader.Error
        anchors.centerIn: parent
        spacing: 16
        Text { text: Qt.formatTime(Clock.date, "HH:mm"); color: Design.ink; font.family: Design.sans; font.pixelSize: Design.display }
        Text { text: "•".repeat(root.lock.maskLength) || "PASSWORD"; color: Design.ink; font.family: Design.mono; font.pixelSize: Design.readout }
        Text { visible: root.lock.attempts > 0; text: "> AUTH FAILED · " + root.lock.attempts; color: Design.danger; font.family: Design.mono; font.pixelSize: Design.body }
    }
    Text {
        objectName: "lockNotice"
        visible: root.lock.notice !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 120
        text: root.lock.notice
        color: Design.danger
        font.family: Design.mono
        font.pixelSize: Design.body
    }
    // After a full hold of the power button: Suspend / Restart / Power off. A click outside or Escape closes it.
    MouseArea {
        anchors.fill: parent
        visible: root.lock.powerChoice === true
        onClicked: root.lock.powerChoice = false
    }
    Rectangle {
        id: powerPlane
        objectName: "powerChoice"
        visible: root.lock.powerChoice === true
        anchors.right: parent.right
        anchors.rightMargin: 40
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        width: 220
        height: choices.implicitHeight + 16
        color: Design.islandFill
        border.width: 1
        border.color: Qt.alpha(Design.ink, 0.25)
        Column {
            id: choices
            x: 8; y: 8
            width: parent.width - 16
            Repeater {
                model: [["suspend", "Suspend"], ["reboot", "Restart"], ["poweroff", "Power off"]]
                Rectangle {
                    id: choice
                    required property var modelData
                    objectName: "power_" + modelData[0]
                    width: choices.width
                    height: 40
                    color: hover.hovered ? Qt.alpha(Design.accent, 0.9) : "transparent"
                    Text {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: choice.modelData[1]
                        color: hover.hovered ? Design.islandFill : Design.ink
                        font.family: Design.sans
                        font.pixelSize: Design.control
                    }
                    HoverHandler { id: hover }
                    TapHandler { onTapped: root.lock.power(choice.modelData[0]) }
                    Accessible.role: Accessible.Button
                    Accessible.name: choice.modelData[1]
                    Accessible.onPressAction: root.lock.power(choice.modelData[0])
                }
            }
        }
    }
    TextInput {
        id: field
        objectName: "lockField"
        // Holds the keyboard; drawn by nobody (the face shows dots from the length).
        x: -width; width: 1; height: 1; opacity: 0
        focus: true
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
        onTextChanged: root.lock.typing(text.length)
        onAccepted: {
            root.lock.submit(text);
            text = "";
        }
        Keys.onEscapePressed: {
            if (root.lock.powerChoice) root.lock.powerChoice = false;
            else text = "";
        }
    }
}
