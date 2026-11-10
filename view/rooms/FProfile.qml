import qs.view.shell
import qs.view.ui
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: root
    // A portal chooser is an external window, so DiPanel releases its focus grab.
    readonly property bool externalDialogOpen: picker.visible
    signal closeRequested
    color: Design.background
    property string username: ""
    property string picture: Config.options.profile.avatarPicture
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 18
        RowLayout {
            FHeading {
                number: "01"
                title: "A face for this world."
                subtitle: "Resident profile"
                Layout.fillWidth: true
            }
            FButton {
                symbol: "close"
                hint: "Close editor"
                onClicked: root.closeRequested()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            Image {
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                source: root.picture
                sourceSize: Qt.size(540, 800)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                FText {
                    text: "DISPLAY NAME"
                    technical: true
                    color: Design.muted
                }
                FField {
                    id: name
                    Layout.fillWidth: true
                    text: Config.options.profile.displayName || root.username
                }
                FText {
                    text: "IMAGE PATH"
                    technical: true
                    color: Design.muted
                }
                FField {
                    Layout.fillWidth: true
                    text: root.picture
                    onTextEdited: root.picture = text
                }
                FButton {
                    label: "Choose image…"
                    symbol: "image"
                    onClicked: picker.open()
                }
                FText {
                    Layout.fillWidth: true
                    text: "LOCAL IMAGE · FILL CROP"
                    wrapMode: Text.Wrap
                    color: Design.faint
                }
                Item {
                    Layout.fillHeight: true
                }
                FButton {
                    Layout.fillWidth: true
                    label: "Save profile"
                    primary: true
                    onClicked: {
                        Config.options.profile.displayName = name.text.trim();
                        Config.options.profile.avatarPicture = root.picture;
                        Config.options.profile.avatarPath = root.picture.slice(0, root.picture.lastIndexOf(
                                                                                   "/"));
                        root.closeRequested();
                    }
                }
            }
        }
    }
    FileDialog {
        id: picker
        title: "Choose profile image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: root.picture = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
    }
}
