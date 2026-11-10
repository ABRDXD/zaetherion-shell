// ClipEntry: { id, text, isImage }; text is the history preview line. Lease "history".
HostDomain {
    property var entries: []

    signal textFetched(string id, string text)

    function refresh() { record("refresh", []); }
    function copy(id: string) { record("copy", [id]); }
    function remove(id: string) { record("remove", [id]); }
    function copyText(text: string) { record("copyText", [text]); }
    function fetchText(id: string) { record("fetchText", [id]); }
}
