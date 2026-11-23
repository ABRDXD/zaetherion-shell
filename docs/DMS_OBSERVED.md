# DMS as observed on this machine (S0, 10 November 2026)

`docs/DMS_BACKEND.md` is what the source said. This file is what DMS actually did when it was run here for the first time. Read both before changing anything that talks to DMS. Raw, scrubbed recording: `tests/fixtures/dms/s0-v2.1.0.json`. Nothing was implemented from this; it's analysis only.

## How it was run
- **Serpantinum was fully stopped first** (the owner's condition): `serpantinumd stop`, then its leftover helpers by pid (twelve stuck `screenshot.sh` processes going back hours, and an "Update available" `notify-send`). Backup of everything Serpantinum, the Hyprland config, its `/usr/local/bin` helpers and `/etc/pam.d/serpantinum`: `~/backups/serpantinum-2026-11-10.tar.zst` (949 MiB, 5,228 files). Its autostart (`hl.exec_cmd("serpantinumd start")` in `~/.config/hypr/config/autostart.lua`) was left in place, so it returns at next login.
- **Correction: Serpantinum came back by itself at 21:04:13, during the recording.** Every `serpantinum <command>` (`bin/serpantinum`, `ensure_daemon`) restarts the daemon if it isn't running, and the volume, brightness, screenshot and lock keys all call that command. So something (most likely a key press) restarted it. The replies were taken with it off; **the last ~9 s of the 15 s event window ran with Serpantinum back on** (recording ended 21:04:22). Keeping it off for real needs those triggers stopped too.
- `~/.config/dms/clsettings.json` was written as `{"disabled": true}` beforehand, to keep the clipboard manager off.
- `dms run -c <dir> --log-level debug --log-file …` with a UI dir holding only `import Quickshell; ShellRoot {}`, so DMS's own bar never appeared. Socket up within a second at `$XDG_RUNTIME_DIR/dms-<pid>.sock`; Quickshell ran as its child `qs -p <dir>`.
- Only read calls were made (`*.getState`, `getServerInfo`, `dgop.*`), plus a 15 s subscribe to everything. `clipboard.getHistory` was deliberately never called. Stopped with `kill <pid>`; the socket went with it.

## Facts that differ from the plan
- **`apiVersion` is 38, not 40.** The installed package is `extra/dux-shell` **2.1.0** (`cliVersion` v2.1.0); the plan read v2.1.1's source. Pin 38 for now, and re-check everything below after an upgrade.
- **Capabilities on this machine (21):** plugins, dgop, drives, lyrics, lyrics.plugins, network, loginctl, freedesktop, gamma, bluetooth, browser, brightness, wlroutput, evdev, clipboard, theme.auto, wallpaper, wellbeing, dbus, sysupdate, files. Not present: weather, location, cups (CUPS isn't running), Tailscale.
- **Method names the plan guessed wrong:** `weather.getState` and `lyrics.getState` are unknown methods; `location.getState` answers "location manager not initialized"; `dgop.meta` needs a `modules` parameter. The real names for weather, lyrics and location must be read from DMS's own QML (the plan's "read from the UI source at S0" items are still open).
- **Events on a subscribe-all (15 s):** server first, then one snapshot each of bluetooth, brightness, clipboard, evdev, freedesktop, freedesktop.screensaver, gamma, loginctl, network, sysupdate, theme.auto, wallpaper, wellbeing, wlroutput. Each looks like `{"id":…, "result": {"service": "<name>", "data": {…}}}`, not a `method` field.
- **`wlroutput` works on Hyprland:** it reports eDP-1 with make, model and modes. **`gamma`** answers with an empty output list and defaults (4000–6500 K), and creates nothing until configured, as planned.
- **`dgop.gpu`** lists both cards (AMD HawkPoint2 at 0000:06:00.0, RTX 3050 at 0000:01:00.0) **without waking the NVIDIA card**: its runtime status was still `suspended` afterwards. Calls that read live NVIDIA load might wake it; not tried.
- **`sysupdate`** found yay (AUR) and Flatpak as backends.
- **Startup warnings, harmless here:** Tailscale not running; CUPS not running.

## Immediate problems for ZÆTHERION
1. **The clipboard manager ignores `clsettings.json` in 2.1.0.** With `{"disabled": true}` in `~/.config/dms/clsettings.json` it still started ("Clipboard manager initialized successfully") and reported `enabled: true` (history empty). It created `~/.cache/dms/clipboard/db`, which was deleted unread. Either the switch lives somewhere else in 2.1.0 or it's applied later. Until that's found, any `dms run` records clipboard history, which breaks AGENTS.md's "never capture clipboard contents" during tests, and Z14 (import cliphist once) has to know where the real switch is. **Find this before the next run.**
2. **DMS opens raw keyboard input** (the evdev manager): the laptop keyboard, the 2.4 GHz wireless keyboard and its media keys, and ydotoold's virtual device. It reads key state (likely Caps Lock and similar). The plan doesn't mention evdev; decide whether ZÆTHERION wants it and whether it can be switched off.
3. **It writes state as soon as it runs:** `~/.config/dms/`, `~/.cache/dms/clipboard/`, `~/.local/state/dms/wellbeing/db`, and a lock `$XDG_RUNTIME_DIR/dms-migrate-<uid>-wayland-1.lock` (the v2 migration check runs on every start). Wellbeing starts recording usage by itself (OPEN 1 hasn't decided whether ZÆTHERION uses it).
4. **Without Serpantinum there's no lock screen, idle handling, notifications, screenshots, volume or brightness keys, or bar.** Serpantinum's keybinds (`keybinds.lua`) call `serpantinum …` commands that then go nowhere. DMS's Go side does none of these by itself (lock, idle, notifications and audio are QML services in DMS's own UI, and that UI was replaced by an empty one). Until ZÆTHERION's resident UI exists, a DMS-only session is unlocked and silent, so it's only safe for short tests at the keys.
5. **Bus names:** with the empty UI, DMS held no user-bus name we could see (`org.freedesktop.Notifications` belongs to the systemd unit, which isn't used). The ScreenSaver claim (`DoNotQueue`) wasn't seen on the bus during this run; check it with Serpantinum off for longer.
6. **Serpantinum leaks processes:** it had left twelve `screenshot.sh --full` processes running for hours. That's not DMS, but it counts in the quiet baseline's numbers if Serpantinum is on.

## Scrubbing (Z113)
88 fields replaced in the fixture by key (SSIDs, BSSIDs, MACs, addresses, serials, UUIDs, hostnames, IPs, connection and device names, user names, real name, paths), plus patterns (MACs, IPv4 and IPv6, `/home/<user>`, the user name) and the time-zone offset. Kept: hardware models, driver names, PCI ids, the output name eDP-1. The scrub test S0 asks for isn't written yet.


## Second, clean run (21:18): Serpantinum really off
- **Serpantinum has more than one way back, so a shell isn't just its UI.** `bin/serpantinum` restarts the daemon whenever it's called (`ensure_daemon`). Callers: Hyprland's keybinds (44 `exec_cmd("serpantinum …")`: volume, brightness, screenshots, lock, reload), **FART itself** (`adapters/serpantinum/SerpantinumPower.qml` polls `serpantinum brightness get`; Notifications and HostActions call it too), and Hyprland's autostart. Both `~/.local/bin/serpantinum*` and the root-owned `/usr/local/bin/serpantinum*` are symlinks to `~/.local/share/serpantinum/bin/`.
- **How it was kept off:** stopped, then `bin/serpantinum` and `bin/serpantinumd` renamed to `*.off` (both sets of symlinks break). It stayed off through the whole run. **To bring it back:** rename them back and run `serpantinumd start` (or log in again). State backup: `~/backups/serpantinum-state-2026-11-10-b.tar.zst`.
- **The clipboard switch, found:** `clsettings.json` *is* the file, but writing `{"disabled": true}` by hand wasn't enough. Sending `clipboard.setConfig {"disabled": true}` (first call after start) worked: `getConfig` says `disabled: true`, and DMS rewrote the file in full (maxHistory 100, maxEntrySize 5 MiB, autoClearDays 0, clearAtStartup false, maxPinned 25). The state event's `enabled: true` seems to mean the manager is running, not that history is on. **But the manager still creates `~/.cache/dms/clipboard/db` at every start, before any call can arrive.** It was deleted unread both times. Check on the next run whether the saved setting stops it from recording from the start.
- Same results otherwise: `apiVersion` 38, the same 21 capabilities and 15 event services, the keyboards opened, the NVIDIA card still asleep, no user-bus names held. **The fixture now comes from this run**; the first run's events are discarded.
- Scrubber: `tools/dms_scrub.py raw.json out.json` (keys + patterns + time-zone offset; fails if the user name survives).

## Method names, from DMS's own QML (11 November)
Read from the UI DMS unpacks while running (`$XDG_RUNTIME_DIR/dms-shell/<hash>/`):
- **Lyrics:** `lyrics.get` with the track's fields plus `allowNetwork` and `providers` (`Services/LyricsController.qml`); `lyrics.plugins` lists providers.
- **Location:** `location.getState`, used only when the `location` capability is present (`Services/LocationService.qml`). Absent on this machine.
- **Weather is not a backend method.** `Services/WeatherService.qml` fetches Open-Meteo itself with `dms dl --connect-timeout 8 --timeout 20` under `nice`/`ionice`, plus reverse geocoding (Nominatim, Photon, BigDataCloud) and ip-api.com for an IP location. ZÆTHERION has to do its own (or call `dms dl`).
- Also seen: `sysupdate.{refresh,upgrade,setInterval,repoStatus,releases,release,cancel,acquire}`, `wellbeing.{summary,setState,setLimits,clear}`.

## Memory, first look (11 November, indicative: the owner was using DMS)
| | RSS MiB | PSS MiB |
| --- | --- | --- |
| DMS backend, fresh | 52–56 | 49–53 |
| DMS backend after a wallpaper change | 408–419 | 396–407 |
| DMS UI (its Quickshell + children) | 611–681 | 415–490 |
| FART view + core, at rest | 531–535 | 281–284 |
- **The backend keeps ~350 MiB after building a theme from a wallpaper** (matugen, in-process; "Building theme: image …"). It doesn't grow afterwards, so it looks like Go holding freed heap, not a leak. Check whether it shrinks after several minutes. ZÆTHERION doesn't need DMS's theming, so don't trigger it (no wallpaper through DMS); a backend at ~50 MiB is the realistic figure.
- Last night, after use: backend 158 PSS, UI 530 PSS.
- **The S0 baseline (Serpantinum + FART at rest) is still owed:** Serpantinum is off while the owner tries DMS. BUDGETS.md's total isn't fixed yet.

## Not done yet in S0
Only the quiet baseline with Serpantinum on. Done: the scrub test and the replay (`tests/test_dms_fixtures.py`, `tools/dms_replay.py`), the method names (above).
