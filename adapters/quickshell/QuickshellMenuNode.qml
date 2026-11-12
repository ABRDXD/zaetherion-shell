import QtQuick
import Quickshell

// One level of a tray item's menu, as a plain snapshot (TrayDomain.menuEntries). Submenus are opened level by level
// through nested nodes, only while this node exists, so closing the menu releases them all.
//   entry id = the path of raw indexes ("2", "2.0"), stable while the menu does not change; triggerAt() walks it.
QtObject {
    id: node
    property var handle: null
    property string prefix: ""

    readonly property QsMenuOpener opener: QsMenuOpener { menu: node.handle }
    readonly property var raw: opener.children ? opener.children.values : []
    // Submenu snapshots by raw index, filled by the children below.
    property var below: ({})

    readonly property var snapshot: {
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const e = raw[i];
            if (!e || e.isSeparator) continue;
            const item = { id: prefix + i, label: e.text ?? "", enabled: e.enabled !== false };
            if (e.hasChildren) item.children = below[i] ?? [];
            out.push(item);
        }
        return out;
    }

    readonly property Instantiator submenus: Instantiator {
        model: node.raw.length
        delegate: Loader {
            required property int index
            readonly property var entry: node.raw[index]
            active: !!entry && entry.hasChildren === true
            // By URL: a type may not instantiate itself by name.
            source: Qt.resolvedUrl("QuickshellMenuNode.qml")
            onItemChanged: {
                if (!item) return;
                item.handle = entry;
                item.prefix = node.prefix + index + ".";
                item.snapshotChanged.connect(() => node.below = Object.assign({}, node.below, { [index]: item.snapshot }));
                node.below = Object.assign({}, node.below, { [index]: item.snapshot });
            }
        }
    }

    // Fire the entry at a path made by this node ("2.0": entry 0 of the submenu at 2).
    function triggerAt(path: string): bool {
        const parts = path.split(".");
        const index = Number(parts[0]);
        const entry = raw[index];
        if (!entry || entry.isSeparator || entry.enabled === false || !Number.isInteger(index)) return false;
        if (parts.length === 1) {
            if (entry.hasChildren) return false;
            entry.triggered();
            return true;
        }
        for (let i = 0; i < submenus.count; i++) {
            const loader = submenus.objectAt(i);
            if (loader && loader.index === index && loader.item) return loader.item.triggerAt(parts.slice(1).join("."));
        }
        return false;
    }
}
