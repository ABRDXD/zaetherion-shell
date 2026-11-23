pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    property alias options: settings
    FileView {
        id: file
        path: Directories.fartState + "/settings.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: save.restart()
        adapter: JsonAdapter {
            id: settings
            property JsonObject appearance: JsonObject {
                property bool geometric: false
                property JsonObject fonts: JsonObject { property bool italicMain: true }
            }
            property JsonObject profile: JsonObject {
                property string displayName: ""
                property string avatarPicture: ""
                property string avatarPath: ""
            }
            property JsonObject bar: JsonObject {
                property JsonObject dynamicIsland: JsonObject { property string layoutStyle: "clock" }
                property JsonObject media: JsonObject { property string preferredPlayer: "" }
                property JsonObject workspaces: JsonObject { property int shown: 8 }
            }
            property JsonObject resources: JsonObject { property int updateInterval: 3000; property int historyLength: 60 }
            property JsonObject search: JsonObject { property list<var> clipboardPins: [] }
        }
    }
    Timer { id: save; interval: 250; onTriggered: file.writeAdapter() }
}
