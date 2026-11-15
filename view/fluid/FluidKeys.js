.pragma library

// Keyboard behaviour shared by Fluid's buttons (after Radix / Base UI): arrows move along a row of sibling controls
// (a toolbar), skipping hidden and disabled ones; Tab still jumps between groups.
function sibling(item, step) {
    const parent = item?.parent;
    if (!parent) return null;
    const row = Array.from(parent.children).filter(c => c.visible && c.enabled && c.activeFocusOnTab && c.width > 0 && c.height > 0);
    const at = row.indexOf(item);
    if (at < 0) return null;
    return row[at + step] ?? null;
}

// The next action row up or down the focus chain (a vertical list, as a Radix menu), or null at either end.
function along(item, forward) {
    const next = item?.nextItemInFocusChain(forward);
    return next && next !== item && next.detail !== undefined ? next : null;
}
