import QtQuick
import "../login-clock-study" as Login

// preview.py supplies one fixed reading from lines.json.
Login.LoginClock {
    readonly property int inputIndex: Qt.application.arguments.indexOf("--reading")
    Component.onCompleted: {
        if (inputIndex >= 0)
            lines = JSON.parse(Qt.application.arguments[inputIndex + 1]);
    }
}
