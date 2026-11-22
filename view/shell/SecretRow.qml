import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.view.cues
import qs.view.fluid
import qs.view.ui

// A masked field for a password, PIN or passkey, with a hold-to-show eye, a submit and a cancel (Z193), set as a
// Side column row (owner's pick B, 22 November 2026): the field on the left, the verb and Cancel in the right column.
// The text is handed out once by `submitted` and cleared at once; it is also cleared on cancel and whenever the row
// is not `shown` (the section folded, closed, or the prompt went away). Nothing else ever reads it.
SettingsSideRow {
    id: root
    property bool shown: false
    property string action: "Join"
    property string placeholder: "Password"
    property bool allowEmpty: false
    property bool digits: false
    signal submitted(string secret)
    signal cancelled()

    onShownChanged: { field.text = ""; if (shown) field.forceActiveFocus(); }
    function submit() {
        if (!root.allowEmpty && field.text === "") return;
        const secret = field.text;
        field.text = "";
        root.submitted(secret);
    }
    function cancel() {
        field.text = "";
        root.cancelled();
    }

    // ---- The reading: the masked field over a hairline, the eye at its end.
    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(field.implicitHeight, eye.implicitHeight) + 1
        TextField {
            id: field
            property bool secret: true
            objectName: "secretField"
            anchors.left: parent.left
            anchors.right: eye.left
            anchors.rightMargin: Design.baseline * 3
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: root.placeholder
            placeholderTextColor: Design.faint
            color: Design.ink
            selectionColor: Design.accent
            selectedTextColor: Design.background
            font.family: Design.fluid ? FluidTokens.sans : Design.mono
            font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
            leftPadding: 0
            echoMode: eye.pressed ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | (root.digits ? Qt.ImhDigitsOnly : 0)
            validator: root.digits ? digitsOnly : null
            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancel()
            background: null
            RegularExpressionValidator { id: digitsOnly; regularExpression: /[0-9]{0,16}/ }
        }
        // Shows the text only while held.
        AbstractButton {
            id: eye
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            implicitHeight: Design.minHit
            implicitWidth: eyeWords.implicitWidth
            Accessible.role: Accessible.Button
            Accessible.name: "Hold to show"
            contentItem: SettingsText {
                id: eyeWords
                verticalAlignment: Text.AlignVCenter
                text: eye.pressed ? "Showing" : "Hold to show"
                technical: true
                font.capitalization: Font.MixedCase
                font.pixelSize: Design.fluid ? FluidTokens.body : Design.body
                color: eye.hovered || eye.visualFocus || eye.pressed ? Design.ink : Design.muted
            }
            background: null
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: field.activeFocus ? Design.ink : Design.fluid ? FluidTokens.rule : Design.line
        }
    }

    // ---- The actions: the verb, then Cancel.
    actions: [
        SettingsAction {
            label: root.action
            leads: true
            underline: false
            enabled: root.allowEmpty || field.text !== ""
            onActivated: root.submit()
        },
        SettingsAction {
            label: "Cancel"
            glyph: ""
            underline: false
            onActivated: root.cancel()
        }
    ]
}
