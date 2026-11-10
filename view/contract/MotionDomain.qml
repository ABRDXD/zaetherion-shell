// Host motion by FART role (docs/CUES.md §15): { <role>: { duration (ms), easing (Easing.Type),
// overshoot, …distances } }. Roles: feedback, navigate, swap, settle, tint, emphasis, unfold, fold.
// A missing role or field keeps FART's default (qs.view.cues Motion.defaults). Static data only.
HostDomain {
    property var roles: ({})
}
