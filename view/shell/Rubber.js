.pragma library

// Rubber-band drag (after Vaul): a surface follows the pointer with growing resistance and never passes `reach`.
// Distances are px along the pull; `threshold` is how far the pointer itself must travel to commit.
const reach = 120;       // the most a pull ever stretches the surface
const threshold = 90;    // pointer travel that commits (opens or folds)
const slop = 8;          // travel before a press becomes a pull (a click stays a click)
const springMs = 260;    // the spring back, or the commit's settle

function stretch(distance, limit) {
    const max = limit ?? reach;
    const d = Math.max(0, distance);
    return max * (1 - 1 / (d / max + 1));
}
function committed(distance) {
    return distance >= threshold;
}
