# DMS as observed on this machine (S0, 10 November 2026)

`docs/DMS_BACKEND.md` is what the source said. This file is what DMS actually did when it was run here for the first time. Read both before changing anything that talks to DMS. Raw, scrubbed recording: `tests/fixtures/dms/s0-v2.1.0.json`. Nothing was implemented from this; it's analysis only.

## How it was run
- **Serpantinum was fully stopped first** (the owner's condition): `serpantinumd stop`, then its leftover helpers by pid (twelve stuck `screenshot.sh` processes going back hours, and an "Update available" `notify-send`). Backup of everything Serpantinum, the Hyprland config, its `/usr/local/bin` helpers and `/etc/pam.d/serpantinum`: `~/backups/serpantinum-2026-11-10.tar.zst` (949 MiB, 5,228 files). Its autostart (`hl.exec_cmd("serpantinumd start")` in `~/.config/hypr/config/autostart.lua`) was left in place, so it returns at next login.
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

## Not done yet in S0
The scrub test, replaying the fixtures offscreen, the right weather, lyrics and location methods, and the quiet RSS/PSS baseline.
