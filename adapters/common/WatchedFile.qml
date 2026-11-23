import QtQuick
import Quickshell.Io

// A text file read, and read again when it changes; content is "" while it is missing or unreadable. Read only.
// Host-free: an adapter names the file (DMS's adapters may not import Quickshell.Io themselves, test_dms_contract).
QtObject {
    id: root
    property string path: ""
    property string content: ""
    readonly property FileView view: FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.content = text()
        onLoadFailed: root.content = ""
    }
}
