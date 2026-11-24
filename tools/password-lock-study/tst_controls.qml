import QtQuick
import QtTest
import "../../view/lock" as Lock

Item {
    width: 1280
    height: 720
    Lock.PasswordLockFace {
        id: face
        anchors.fill: parent
        fluid: false
        timeText: "06:42"
        dateText: "Tuesday"
        maskLength: 0
        attempts: 0
        rejectionMs: -1
        reducedMotion: false
        playing: true
        mediaAvailable: true
        trackTitle: "Title"
        artist: "Artist"
        batteryFraction: 0.76
        holdProgress: 0
    }
    SignalSpy {
        id: media
        target: face
        signalName: "mediaRequested"
    }
    SignalSpy {
        id: down
        target: face
        signalName: "powerHoldStarted"
    }
    SignalSpy {
        id: up
        target: face
        signalName: "powerHoldEnded"
    }
    TestCase {
        name: "LockControls"
        when: windowShown
        function test_controls_data() {
            return [
                {
                    tag: "Angular",
                    fluid: false
                },
                {
                    tag: "Fluid",
                    fluid: true
                }
            ];
        }
        function test_controls(data) {
            face.fluid = data.fluid;
            face.mediaAvailable = true;
            face.playing = true;
            media.clear();
            down.clear();
            up.clear();
            const y = data.fluid ? 649 : 667;
            for (const [x, action] of [[583, "previous"], [640, "pause"], [697, "next"]]) {
                mouseClick(face, x, y);
                compare(media.signalArguments[media.count - 1][0], action);
            }
            face.playing = false;
            mouseClick(face, 640, y);
            compare(media.signalArguments[media.count - 1][0], "play");
            face.mediaAvailable = false;
            mouseClick(face, 640, y);
            compare(media.count, 4);
            mousePress(face, 1100, y);
            compare(down.count, 1);
            compare(up.count, 0);
            mouseRelease(face, 1100, y);
            compare(up.count, 1);
        }
    }
}
