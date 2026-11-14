import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.ui

// A masked field for a password, PIN or passkey, with a hold-to-show eye, a submit and a cancel (Z193). The text is
// handed out once by `submitted` and cleared at once; it is also cleared on cancel and whenever the row is not
// `shown` (the section folded, closed, or the prompt went away). Nothing else ever reads it.
RowLayout {
    id: root
    property bool shown: false
    property string action: "Join"
    property string placeholder: "Password"
    property bool allowEmpty: false
    property bool digits: false
    signal submitted(string secret)
    signal cancelled()
    spacing: Design.baseline * 2

    onShownChanged: { field.text = ""; if (shown) field.forceActiveFocus(); }
    function submit() {
        if (!root.allowEmpty && field.text === "") return;
        const secret = field.text;
        field.text = "";
        root.submitted(secret);
    }

    FField {
        id: field
        property bool secret: true
        objectName: "secretField"
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        placeholderText: root.placeholder
        echoMode: eye.pressed ? TextInput.Normal : TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | (root.digits ? Qt.ImhDigitsOnly : 0)
        validator: root.digits ? digitsOnly : null
        onAccepted: root.submit()
        Keys.onEscapePressed: { field.text = ""; root.cancelled(); }
        RegularExpressionValidator { id: digitsOnly; regularExpression: /[0-9]{0,16}/ }
    }
    FButton { id: eye; symbol: eye.pressed ? "visibility" : "visibility_off"; hint: "Hold to show"; implicitHeight: field.implicitHeight }
    FButton { label: root.action; primary: true; implicitHeight: field.implicitHeight; enabled: root.allowEmpty || field.text !== ""; onClicked: root.submit() }
    FButton { label: "Cancel"; implicitHeight: field.implicitHeight; onClicked: { field.text = ""; root.cancelled(); } }
}
