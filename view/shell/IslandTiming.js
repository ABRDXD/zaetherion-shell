.pragma library

// How long each island face stays, in ms, in one place (owner, 15 November 2026: "the notifications and anything
// expanding from the dynamic island just stay on for too long"; Z200). Hovering a notification still pauses it (Z175).
const notification = 2000;     // a notification whose sender leaves the time to us
const notificationCap = 3500;  // the most a non-critical notification stays, whatever its sender asked
const track = 1800;
const workspace = 1600;        // after the last switch; the turn itself takes 1.1 s
const osd = 1000;              // after the last volume, mic or brightness change
const charging = 1500;
const lowBattery = 3000;
const backend = 3000;
