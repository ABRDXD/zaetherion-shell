import QtQuick
import Quickshell
import Quickshell.Io
import qs.view.cues

// Room-owned subscription; Silent takes one snapshot on open. No polling.
Item {
    id: root
    property var snapshot: null
    property var latest: null
    property bool live: Motion.engaged && !Motion.reduced && visible
    property string path: Quickshell.env("FART_CORE_SOCKET") || ""
    onLiveChanged: if (live && latest) snapshot = latest
    onVisibleChanged: {
        if (visible) {
            if (latest) snapshot = latest;
            socket.connected = path !== "";
        } else {
            retry.stop();
            socket.connected = false;
        }
    }
    function accept(value) {
        latest = value;
        if (!snapshot || live || (!snapshot.available && value.available)) snapshot = value;
    }
    function send(message) { socket.write(JSON.stringify(message) + "\n"); socket.flush(); }
    Socket {
        id: socket
        path: root.path
        connected: root.path !== "" && root.visible
        onConnectionStateChanged: {
            if (connected) root.send({id: 1, op: "hello", args: {client: "cli", protocol: 1}});
            else if (root.visible && root.path) retry.restart();
        }
        onError: if (root.visible && root.path) retry.restart()
        parser: SplitParser {
            onRead: line => {
                let msg;
                try { msg = JSON.parse(line); } catch (_) { return; }
                if (msg.id === 1 && msg.ok) root.send({id: 2, op: "subscribe", args: {topics: ["genealogy"]}});
                if (msg.id === 2 && msg.ok) root.accept(msg.result.snapshots.genealogy);
                if (msg.event === "genealogy") root.accept(msg.data);
            }
        }
    }
    Timer { id: retry; interval: 2000; onTriggered: if (root.visible) socket.connected = true }
}
