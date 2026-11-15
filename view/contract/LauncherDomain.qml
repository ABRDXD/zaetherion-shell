// The host's own launcher engine (S6, Z197): on DMS, DMS's launcher (apps with its frecency and actions, files,
// clipboard, DMS settings, plugins) without its window. The star chart sends what was typed and shows the answer;
// unavailable means the chart ranks apps in the core instead (Z185), so it always works.
//   results: [{ key, kind (app | file | setting | plugin | clipboard), name, description, icon (an Image source or
//              ""), glyph (a Material Symbols name or ""), source }] answering `query`; `searching` while more may come.
HostDomain {
    property var results: []
    property string query: ""
    property bool searching: false
    function open() { record("open", []); }
    function search(text: string) { record("search", [text]); }
    // Runs result `key` of the latest results, as the host's own launcher would.
    function execute(key: int) { record("execute", [key]); }
    function close() { record("close", []); }
}
