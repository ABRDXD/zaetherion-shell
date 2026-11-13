# S4: switching the live session to our notification server

Needs the owner present. Nothing here has been run on the live session yet. Prepared 13 November 2026 (Z171).

## Where things stand

- The live core runs from the main checkout (`~/src/zaetherion-shell`), which is on `s8-palette` with Astra's uncommitted docs. That branch has no S4. `s0-seed` has S4, the palette work, the DMS guard and quiet DMS.
- The live core's settings: `FART_HOST=serpantinum`, `FART_SUPERVISE=dms`; no resident view, no notification server of ours. DMS's own UI holds `org.freedesktop.Notifications`.

## What changes when it's on

| Setting | Does |
|---|---|
| `FART_RESIDENT_DIR=~/.local/state/zaetherion/dms-quiet` | DMS runs its full UI minus its notification server (`tools/dms_quiet.py`) |
| `FART_RESIDENT_VIEW=1` | Our view (island, FART) stays up with the core; DMS's bar is hidden while it is up (Z159) |
| `FART_NOTIFICATION_SERVER=1` | The view runs our server; it takes the name when DMS lets go (Z169) |

DMS's notification centre and popups go quiet; notifications show on the island and in FART's Inbox, with actions, reply, pictures, sound and DND (Z166–Z170).

## Steps

1. Bring the main checkout to `s0-seed`. Astra's uncommitted files in `docs/` have to be committed or moved first; ask the owner whose call that is.
2. Build the quiet copy while the stock DMS is running: `python3 tools/dms_quiet.py build`, then `python3 tools/dms_quiet.py check ~/.local/state/zaetherion/dms-quiet`.
3. Optional re-check: `python3 tools/dms_quiet_check.py` (nested Hyprland, private bus, about 1 minute).
4. From the main checkout:
   `FART_RESIDENT_DIR=$HOME/.local/state/zaetherion/dms-quiet FART_RESIDENT_VIEW=1 FART_NOTIFICATION_SERVER=1 ./zaetherion restart`
5. Check: `busctl --user status org.freedesktop.Notifications` names the view's `qs` (not DMS's); then the `notify-send` matrix: normal, low, critical (stays), an action (`-A ok=OK`, prints `ok` when clicked), a picture (`-i`), a replace-id (`-r`), expiry (`-t 2000`), DND on and off. Also Wi-Fi, lock, logout card, tray, media, audio and battery, as for Z159.

## Going back

`./zaetherion restart` without the three settings. DMS's stock UI takes the name again.

## Open

- **After a reboot.** The settings above live only in the shell that ran the restart; `tools/session-start` doesn't set them. Making them stick is a one-line change there, after the owner has lived with it.
- **DMS upgrades.** The copy is tied to the DMS revision it was made from (`.zaetherion-quiet`). After an upgrade, rebuild it with the stock UI running; until then DMS would run the old UI. Not yet automated: the core could compare it with the running DMS's revision and fall back to stock.
