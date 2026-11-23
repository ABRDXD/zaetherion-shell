# S4: switching the live session to our notification server

Needs the owner present. Nothing here has been run on the live session yet. Prepared 13 November 2026 (Z171).

## Where things stand

- The live core runs from the main checkout (`~/src/zaetherion-shell`), which is on `s8-palette` with Astra's uncommitted docs. That branch has no S4. `s0-seed` has S4, the palette work, the DMS guard and quiet DMS.
- The live core's settings: `FART_HOST=serpantinum`, `FART_SUPERVISE=dms`; no resident view, no notification server of ours. DMS's own UI holds `org.freedesktop.Notifications`.

## What changes when it's on

| Setting | Does |
|---|---|
| `FART_RESIDENT_DIR=~/.local/state/zaetherion/dms-quiet` | DMS runs its full UI minus its notification server (`tools/dms_quiet.py`) |
| `FART_VIEW_ENTRY=<repo>/shell-dms.qml` | The view is the DMS adapter's entry; without it the view is `shell.qml`, which has no server of ours |
| `FART_RESIDENT_VIEW=1` | Our view (island, FART) stays up with the core; DMS's bar is hidden while it is up (Z159) |
| `FART_NOTIFICATION_SERVER=1` | The view runs our server; it takes the name when DMS lets go (Z169) |

DMS's notification centre and popups go quiet; notifications show on the island and in FART's Inbox, with actions, reply, pictures, sound and DND (Z166–Z170).

## Steps

1. Bring the main checkout to `s0-seed`. Astra's uncommitted files in `docs/` have to be committed or moved first; ask the owner whose call that is.
2. Build the quiet copy while the stock DMS is running: `python3 tools/dms_quiet.py build`, then `python3 tools/dms_quiet.py check ~/.local/state/zaetherion/dms-quiet`.
3. Optional re-check: `python3 tools/dms_quiet_check.py` (nested Hyprland, private bus, about 1 minute).
4. From the main checkout:
   `FART_VIEW_ENTRY=$PWD/shell-dms.qml FART_RESIDENT_DIR=$HOME/.local/state/zaetherion/dms-quiet FART_RESIDENT_VIEW=1 FART_NOTIFICATION_SERVER=1 ./zaetherion restart`
   If the log says "another core is already running", the old core had not finished stopping: run `./zaetherion start` with the same settings once it has gone.
5. Check: `busctl --user status org.freedesktop.Notifications` names the view's `qs` (not DMS's); then the `notify-send` matrix: normal, low, critical (stays), an action (`-A ok=OK`, prints `ok` when clicked), a picture (`-i`), a replace-id (`-r`), expiry (`-t 2000`), DND on and off. Also Wi-Fi, lock, logout card, tray, media, audio and battery, as for Z159.

## Going back

`./zaetherion restart` without the four settings. DMS's stock UI takes the name again.

## Done, 14 November 2026

Live with all four settings, from the main checkout on `s0-seed` with S5 merged (`39719a2`, 948 OK). Two things found: the steps lacked `FART_VIEW_ENTRY`, and the server only started at FART's first open (fixed on `s4-eager-notif`: `DmsAdapter` creates the notifications domain at start when the server is on). The matrix passed with the owner watching: normal, low, critical (stays), an action (`ok` came back), a picture, a replace-id, expiry, do-not-disturb on (normal held, critical through) and off; all in FART's Inbox. Wi-Fi, tray, media, audio, battery, logout card and lock work.

## Open

- **After a reboot.** Done (14 November): `tools/session-start` turns ours on at login when `dms_quiet.py fits` says the copy was made for the installed `dms`; else DMS's own, with the reason in `session.log`. Leaving a file `~/.local/state/zaetherion/stock-notifications` brings DMS's own back at the next login.
- **DMS upgrades.** The copy records the `dms` program it was made from (`.zaetherion-dms`: path, size, mtime). After an upgrade the next login falls back to DMS's own notifications; rebuild with the stock UI running (`dms_quiet.py build`) to get ours back. Not automated.
