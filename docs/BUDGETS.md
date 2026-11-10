# Budgets

Rules carried over from FART-next:
- Report RSS, PSS and private dirty separately, and note shared mappings.
- Don't equate nominal vsync with sustained FPS.
- Exclude runs interrupted by user input.
- Measure before claiming.

## Total (Z60)

**ZÆTHERION's total must be no larger than Serpantinum plus FART-next's total.** Its total is the resident process, the warm panel, `fartd` and `dms`, measured as PSS. The comparison total is re-measured quietly at S0.

A point-in-time reading from planning, 8 Nov 2026 (not a quiet measurement):

| Process | RSS (MiB) | PSS (MiB) | Private dirty (MiB) |
|---|---|---|---|
| Serpantinum `quickshell` | 725 | 482 | 430 |
| Serpantinum focus daemon | 18 | 8 | — |
| Serpantinum idle helper | 13 | 4 | — |
| FART-next view | 506 | 218 | — |
| FART-next `fartd` | 22 | 12 | — |

## Per surface (Z141)

Each surface gets a measured memory delta and a frame budget. The limits are fixed at the milestone that builds the surface, then enforced by a `check-budgets` gate.

| Surface | Fixed at | Frame/CPU rule |
|---|---|---|
| Island at rest | S3 | 0 frames between minute ticks; ≤ 2% of one core when static |
| Island with media playing (waveform) | S3 | ≤ 5% of one core |
| Island hover and expansions | S3 | p99 ≤ 6.9 ms |
| Launcher open | S6 | ≤ 100 ms key → typing accepted (Z139) |
| Widgets loaded | S10 | Unloaded whenever a window is on the workspace (Z85) |
| Video wallpaper | S8 | Paused when covered; still frame on battery (Z140) |
| Sky wallpaper | S8 | ≤ 1 redraw per minute in Silent |
| Lock | S7 | Surfaces exist only while locked |
| Overview | S11 | Thumbnails only in Overdrive |
| Panel | carried over | Cold start target ≤ 450 ms; p99 ≤ 6.9 ms on open, navigation and command line; reap timer set at S2 (Z142) |

## Overdrive (carried over)

| Rule | Limit |
|---|---|
| CPU | ≤ 25% of one core |
| Memory over Silent-open, including iGPU textures | ≤ +400 MiB |
| dGPU | Never woken outside Overdrive. In Overdrive the heavy layer runs on it (OPEN 13, the owner, 10 November 2026; FARG measured about 38 % and 12–14 W) |
| Frame time | p95 ≤ 6.9 ms, p99 ≤ 10 ms |
| Release | Back to the Silent baseline ±10 MiB within 5 s |
| Battery | Suspended on battery (Z122) |

## At rest (Z138)

**Loaded:**
- The island (rest state)
- The wallpaper layer
- The notification server
- Idle monitors
- The polkit agent
- The lock definition
- The tray

**Created on demand and destroyed afterwards:**
- Launcher
- OSD
- Capture
- Draw
- Session card
- Widgets (while covered)
- Boot
