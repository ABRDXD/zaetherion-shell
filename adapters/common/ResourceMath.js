.pragma library

function cpuSample(text) {
    const line = text.match(/^cpu\s+(.+)$/m);
    if (!line) return null;
    // guest/guest_nice are already counted in user/nice: only sum eight fields.
    const fields = line[1].trim().split(/\s+/).slice(0, 8).map(Number);
    if (fields.length !== 8 || fields.some(v => !Number.isFinite(v) || v < 0)) return null;
    return { total: fields.reduce((a, b) => a + b, 0), idle: fields[3] + fields[4] };
}

function cpuDelta(previous, current) {
    if (!previous || !current) return null;
    const total = current.total - previous.total;
    const idle = current.idle - previous.idle;
    if (total <= 0 || idle < 0 || idle > total) return null;
    return Math.max(0, Math.min(1, (total - idle) / total));
}
