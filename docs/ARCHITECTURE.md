# Architecture

## Processes

```
SDDM ─► Hyprland, "Hyprland (ZÆTHERION)" session (its own entry file and require list)
          autostart.lua ─► zaetherion start
                             └─ fartd  (Python stdlib: supervisor + FART state)
                                  ├─ dms run -c <repo>/resident   (DMS backend; parent of the resident qs)
                                  │     └─ qs resident: island, launcher, notifications, OSD, wallpaper,
                                  │                     widgets, lock, idle, polkit, capture, draw, boot
                                  └─ qs panel (spawned, reaped): rooms, settings window, overview
```

| Process | Lifetime | Holds |
|---|---|---|
| `fartd` | The whole session | Timers, tasks, sessions, leases and guards, notification mirror and 24 h history, command history, frecency, file index, sky ephemeris, trial log, supervision |
| `dms` | The whole session; restarted with backoff (Z11) | System backend (see the backend map below) |
| resident `qs` | Child of `dms` (Z10) | Every surface that must never disappear |
| panel `qs` | Spawned on demand; reaped after a delay chosen at S2 (Z142); never reaped while the settings window is open (Z91) | Rooms, settings window, overview |

### Startup and supervision
- Hyprland autostart only, with no systemd units (Z13).
- `zaetherion start` starts `fartd`, which starts `dms run -c`. DMS starts the resident process with `DMS_SOCKET` set.
- If `dms` dies, the resident process dies with it. `fartd` restarts the pair, and the island announces it (Z123, Z127).
- The panel keeps FART-next's crash limit: 3 crashes within 5 s halts it (Z128).
- `fartd` today assumes a single view (one `process`, one `client`, `kind=="view"` in `core/view.py` and `core/app.py`). It is generalised to named clients, `resident` and `panel`.
- The ZÆTHERION Hyprland config sets `misc.allow_session_lock_restore = true`, so a restarted resident process can take over a held lock.

### IPC
- Both Quickshell processes speak FART's JSON-lines protocol on `$XDG_RUNTIME_DIR/zaetherion/core.sock`. It checks the peer's uid; `hello` must come first.
- The resident process connects to DMS on `$DMS_SOCKET` (`$XDG_RUNTIME_DIR/dms-<pid>.sock`).
- The panel opens its own DMS connection inside its adapters, and subscribes to a service only while a lease holds it. When the lease is released, it resubscribes with the shorter list.

### State
- `~/.local/state/zaetherion`, `~/.cache/zaetherion` and `$XDG_RUNTIME_DIR/zaetherion`.
- **On first start, copied from FART-next** (existing destination files win; originals untouched; Z135): `tasks.json`, `timers.json`, `settings.json`, `preferences.json`, `notifications.json`, `history.json`, `overdrive.json`, the lyrics cache and the Home portrait.
  - Sessions, streaks and discovery start fresh.
- **Copied once from Serpantinum** (Z136): launcher frecency, wallpaper favourites and history, the notification position and sound, and wellbeing history (imported into whichever wellbeing source wins; see [OPEN.md](OPEN.md)).
- The cliphist history is imported into DMS's clipboard once (Z14).

## Adapters

The view never talks to a system service directly. Rooms and surfaces receive one typed `HostAdapter` (FART-next's contract, extended in [CONTRACT.md](CONTRACT.md)).

| Adapter | Implements |
|---|---|
| `adapters/dms` | A socket client (request connection plus subscribe connection, replies matched by `id`, `apiVersion` range pinned), plus one implementation per DMS-backed domain |
| `adapters/quickshell` | Pipewire, MPRIS, UPower, SystemTray, Notifications, PAM, Polkit and Idle. DMS-derived QML is credited in NOTICE. |
| `adapters/hyprland` | Workspaces, windows, fullscreen, keybind file read/write |
| `adapters/serpantinum-assets` | Read-only, at runtime: presets, sounds, emoji, the frecency seed. Degrades per Z125. |
| `adapters/fixture` | Inert sample data and a call log for offscreen tests. DMS fixtures are scrubbed of personal data (Z113). |

**Rules carried from FART-next:**
- No host strings in the view.
- Only the designated files start processes.
- `qs.*` imports stay inside their layer.
- Every lease is acquired and released in pairs.
- The contract tests gain one conformance map per adapter.

## Backend map

| Domain | Source |
|---|---|
| Network (NM/iwd, VPN, hotspot), Bluetooth (with pairing agent) | DMS `network.*`, `bluetooth.*` (Z8) |
| Brightness, DDC/CI | DMS `brightness.*` |
| Clipboard history | DMS `clipboard.*` |
| Night light | DMS `wayland.gamma.*` (Z15) |
| Outputs | DMS `wlroutput.*`; DPMS through Hyprland |
| Logind (sleep inhibit, lock hints, lock before suspend) | DMS `loginctl.*` |
| Process and system stats | DMS `dgop.*` (Z100) |
| Weather, location | DMS `weather.*`, `location.*` (Z16, Z45) |
| Lyrics | DMS `lyrics.*` and FART's lrclib cache; the order is set in S2 (OPEN.md) |
| Updates | DMS `sysupdate.*` (Z98) |
| Wellbeing | DMS `wellbeing.*` or `focus_daemon.py`, decided in S2 (OPEN.md) |
| Audio | Quickshell Pipewire; EQ is ZÆTHERION's own filter-chain config (Z50) |
| Media | Quickshell MPRIS |
| Battery, power profiles | Quickshell UPower |
| Notifications server, tray, lock/PAM, idle, polkit | Quickshell services |
| Workspaces, windows, fullscreen | Quickshell Hyprland IPC |
| Timers, tasks, sessions, leases, history, frecency, file index, sky ephemeris | `fartd` |

## Sky engine

- The ephemeris (Meeus: Sun, Moon with phase, naked-eye planets, sidereal time) and the catalogue projection run in `fartd`. They are pure stdlib, and position comes from DMS location.
- The wallpaper, lock, widgets and Home all read one `sky` topic, published once a minute, and only while a subscriber is visible.
- In Overdrive, the strata interpolate between topic updates. The core does not publish more often.

## Hyprland integration

- The session is its own SDDM entry, "Hyprland (ZÆTHERION)" (installing it needs root and the owner's approval).
- It uses its own require list: a copy of the owner's keybinds retargeted from `serpantinum …` to `zaetherion …` (Z59), plus `allow_session_lock_restore` and the ZÆTHERION autostart.
- The Serpantinum session's files are never edited.
- Every ZÆTHERION popup closes on a workspace change.
