import QtQuick

// Task lists as the rooms read them; rows are addressed by id, never by index.
QtObject {
    required property var core
    readonly property bool available: core.connected && !!core.tasksData
    readonly property var lists: core.tasksData?.lists ?? []
    readonly property var all: core.tasksData?.tasks ?? []

    // list and due are optional: the default list, no date.
    function add(text, list, due) {
        const args = { text: text };
        if (list)
            args.list = list;
        if (due)
            args.due = due;
        core.request("task.add", args);
    }
    function setDone(id, done) { core.request("task.update", { id: id, done: done }); }
    function setDue(id, due) { core.request("task.update", { id: id, due: due || null }); }
    // callback(list) receives the new list's {id, name}.
    function addList(name, callback) { core.request("list.add", { name: name }, (ok, result) => { if (ok && callback) callback(result.list); }); }
    // callback({task, index}) keeps what undo needs.
    function remove(id, callback) { core.request("task.remove", { id: id }, (ok, removed) => { if (ok && callback) callback(removed); }); }
    function restore(removed) { core.request("task.restore", { task: removed.task, index: removed.index }); }
}
