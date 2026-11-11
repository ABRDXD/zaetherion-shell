// Menu stack adapted from Dux Shell's TrayMenuContent.qml (MIT).
// Copyright (c) 2025 Avenge Media LLC. See licenses/DUX-SHELL-MIT.
import QtQuick
import qs.view.ui

FocusScope {
    id: root
    required property var entries
    signal closeRequested()
    signal choose(string id)

    implicitWidth: 248
    implicitHeight: Math.min(340, Math.max(Design.minHit, rows.contentHeight))
    readonly property var topMenu: topEntry()
    readonly property var model: topMenu?.children ?? entries

    property var entryStack: []
    function topEntry() {
        return entryStack.length ? entryStack[entryStack.length - 1] : null;
    }
    function showSubMenu(entry) {
        if (!entry?.children?.length) return;
        entryStack = entryStack.concat([entry]);
        rows.currentIndex = 0;
    }
    function goBack() {
        if (!entryStack.length) return;
        entryStack = entryStack.slice(0, -1);
        rows.currentIndex = 0;
    }
    function select(entry): void {
        if (!entry || entry.enabled === false) return;
        if (entry.children?.length) showSubMenu(entry);
        else {
            choose(entry.id);
            closeRequested();
        }
    }

    Keys.onEscapePressed: {
        if (entryStack.length > 0) root.goBack();
        else root.closeRequested();
    }
    Rectangle {
        anchors.fill: parent
        color: Design.surface
        border.color: Design.line
        border.width: 1
    }
    ListView {
        id: rows
        anchors.fill: parent
        model: root.model
        focus: true
        clip: true
        currentIndex: 0
        Keys.onReturnPressed: root.select(currentItem?.modelData)
        Keys.onEnterPressed: root.select(currentItem?.modelData)
        Keys.onRightPressed: root.showSubMenu(currentItem?.modelData)
        Keys.onLeftPressed: root.goBack()
        delegate: FMenuItem {
            required property var modelData
            width: ListView.view.width
            enabled: modelData.enabled !== false
            label: modelData.label
            detail: modelData.children?.length ? "›" : ""
            onClicked: root.select(modelData)
        }
        highlight: Rectangle { color: Design.hover }
    }
}
