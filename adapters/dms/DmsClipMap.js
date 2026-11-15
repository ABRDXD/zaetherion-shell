.pragma library

// DMS's clipboard history (the history call's result, the service event's `history`) in the contract's shape
// (Z202). Pure; contents are never logged. DMS entry: { id (number), preview, isImage, pinned, timestamp,
// mimeType, size, hash }.

function newestFirst(a, b) {
    return (new Date(b.timestamp) - new Date(a.timestamp)) || (Number(b.id) - Number(a.id));
}

// The contract's ClipEntry list, newest first: { id (string), text, isImage, pinned }.
function entries(history) {
    if (!Array.isArray(history))
        return [];
    return history.filter(e => e && e.id !== undefined && e.id !== null)
        .slice().sort(newestFirst)
        .map(e => ({ id: String(e.id), text: String(e.preview ?? ""), isImage: e.isImage === true, pinned: e.pinned === true }));
}

// Our string id -> DMS's own id (a number), so a call names the entry exactly as DMS gave it.
function ids(history) {
    const map = {};
    if (Array.isArray(history))
        for (const e of history)
            if (e && e.id !== undefined && e.id !== null)
                map[String(e.id)] = e.id;
    return map;
}

// One entry's full result, for an image: a data URL (DMS sends the bytes as base64), or "".
function imageUrl(result) {
    const data = result && typeof result.data === "string" ? result.data.replace(/\s+/g, "") : "";
    if (!data || !/^[A-Za-z0-9+/]+=*$/.test(data))
        return "";
    const mime = result && typeof result.mimeType === "string" && /^image\/[\w.+-]+$/.test(result.mimeType)
        ? result.mimeType : "image/png";
    return "data:" + mime + ";base64," + data;
}

// Base64 bytes -> a JS string of UTF-8 text. `bytes` is what the runtime's atob gave: a binary string (Qt < 6.11)
// or an ArrayBuffer (Qt 6.11+).
function utf8(bytes) {
    let binary = "";
    if (typeof bytes === "string") {
        binary = bytes;
    } else if (bytes) {
        const view = new Uint8Array(bytes);
        const chunks = [];
        for (let i = 0; i < view.length; i += 8192)
            chunks.push(String.fromCharCode.apply(null, view.subarray(i, i + 8192)));
        binary = chunks.join("");
    }
    try {
        return decodeURIComponent(escape(binary));
    } catch (error) {
        return binary;
    }
}
