import QtQuick

// Property feedback that animates only while its scope is live (docs/CUES.md §3.4).
// A new value retargets from the current one, as any Behavior does. When the scope stops
// being live mid-flight, the running animation (≤ 220 ms) finishes; later changes jump.
// Tweens are finite and numerous (one per button), so they stay a bare gated Behavior and
// are not reported to Motion.activeNames.
Behavior {
    property Item scope: null
    enabled: Motion.live(scope)
}
