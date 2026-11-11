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

**Quiet S0 baseline, 11 Nov 2026** (Serpantinum freshly started, 90 s settle, 6 samples 20 s apart, no input; FART-next view then opened, closed and sampled warm 4 × 15 s; plugged in). Last sample shown; the Serpantinum `quickshell` ranged 480–494 PSS across the run.

| Process | RSS (MiB) | PSS (MiB) | Private dirty (MiB) |
|---|---|---|---|
| Serpantinum `quickshell` | 743 | 491 | 386 |
| Serpantinum focus daemon | 21 | 11 | 9 |
| Serpantinum idle helper | 17 | 9 | 8 |
| Serpantinum audio daemon | 10 | 5 | 4 |
| `serpantinumd` (bash) | 6 | 1 | 1 |
| Serpantinum `inotifywait` × 2 | 5 | 0 | 0 |
| cliphist `wl-paste` watchers × 2 (Serpantinum autostart) | 4 | 0.4 | — |
| FART-next view (warm, closed) | 498 | 235 | 172 |
| FART-next `fartd` | 24 | 15 | 14 |
| **Total** | | **≈ 768** | |

**Fixed total budget: ZÆTHERION ≤ 768 MiB PSS** (resident + warm panel + `fartd` + `dms`, measured the same way). With the panel reaped, the comparison is ≈ 533 MiB.

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

### Angular island fixture sample (11 November 2026)

Hidden nested Hyprland, Qt Quick software renderer, synthetic data. The preview process also loads the folded fixture panel. These are process readings, not isolated per-surface memory limits.

| State | RSS (MiB) | PSS (MiB) | Private dirty (MiB) | Shared clean + dirty (MiB) |
|---|---:|---:|---:|---:|
| Rest | 106.85 | 46.27 | 37.66 | 69.15 |
| Playing | 106.36 | 45.57 | 36.95 | 69.38 |
| Wings | 107.77 | 46.54 | 37.74 | 69.99 |

Four seconds between minute ticks yielded zero Qt frames and 0.00% of one core at the CPU counter resolution. Four seconds of synthetic playback yielded 3.25% of one core with timing logs enabled. Across eight OSD open and fold cycles over the wings, the 548 Qt software frame samples had a p99 of 1 ms at whole-millisecond resolution. This sample excludes compositor presentation time. Measure the separated resident, actual adapter and compositor presentation before fixing the live per-surface limits.

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
