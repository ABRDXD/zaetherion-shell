.pragma library

// What the star chart shows (S6, Z197): the core's inline rows (FART verbs, sums, conversions; Z195) above the host's
// own launcher engine (DMS's: apps, files, clipboard, settings, plugins). The core's own app ranking (Z185) stands in
// whenever the host's engine can't answer: unavailable, nothing typed (it answers nothing then), or a `>`/`?` line,
// which is only the core's row.
//   coreRows: launcher.query's rows; host: { available, results }; limit: rows shown.
function rows(text, coreRows, host, limit) {
    const line = String(text ?? "").trim();
    if (!host || !host.available || line === "" || line.startsWith(">") || line.startsWith("?"))
        return coreRows.slice(0, limit);
    const blocked = new Set(coreRows.filter(r => r.kind === "app" && r.blocked).map(r => r.id));
    const inline = coreRows.filter(r => r.kind !== "app");
    const engine = (host.results ?? []).map(r => Object.assign({}, r, {
        id: r.id || "host:" + r.key, source: "host", ready: true, blocked: blocked.has(r.id) }));
    return inline.concat(engine).slice(0, limit);
}

// What identifies a result list for the selection: kinds, ids and names in order.
function key(rows) {
    return (rows ?? []).map(r => (r.kind ?? "") + "\u0001" + (r.id ?? "") + "\u0001" + (r.name ?? "")).join("\u0002");
}
