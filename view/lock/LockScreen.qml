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

    Rectangle { anchors.fill: parent; color: "#06070a" }
    Image {
        anchors.fill: parent
        visible: root.lock.wallpaper !== ""
        source: root.lock.wallpaper ? "file://" + root.lock.wallpaper : ""
        sourceSize.width: 1920
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
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
    // F8: the face failed; the lock still asks for the password.
    Column {
        objectName: "plainCard"
        visible: face.status === Loader.Error
        anchors.centerIn: parent
        spacing: 16
        Text { text: Qt.formatTime(Clock.date, "HH:mm"); color: "#f3efdc"; font.family: Design.sans; font.pixelSize: Design.display }
        Text { text: "•".repeat(root.lock.maskLength) || "PASSWORD"; color: "#f3efdc"; font.family: Design.mono; font.pixelSize: Design.readout }
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
        Keys.onEscapePressed: text = ""
    }
}
