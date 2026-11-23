.pragma library

// How long each island face stays, in ms, in one place (owner, 15 November 2026: "the notifications and anything
// expanding from the dynamic island just stay on for too long", then "make all of these 1 or less than 1"; Z200).
// Hovering a notification still pauses it (Z175); critical ones stay until dismissed.
const notification = 1000;     // a notification whose sender leaves the time to us
const notificationCap = 1000;  // the most a non-critical notification stays, whatever its sender asked
const track = 1000;
const workspace = 1000;        // after the last switch; the turn itself takes 0.7 s
const osd = 800;               // after the last volume, mic or brightness change
const charging = 1000;
const lowBattery = 1000;
const backend = 1000;
