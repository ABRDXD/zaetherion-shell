# The cutover (M7)

**Status (8 November 2026, 16:22): switched.** On the user's instruction ("yes you can merge and also take over the old fart ui"):
- `main` was fast-forwarded to `m6-design` (`3b24cb8`);
- `cutover.py apply --live` ran cleanly, and `check` is all `ok` afterwards.

So `fart` and the clock's right-click now run fart-next from `~/.local/share/fart/next`, and `fart-archive` runs the archive. **To roll back:** `python3 ~/.local/share/fart/next/tools/cutover.py rollback --live`.

M6 acceptance (Claude B) and the desktop budget runs are still open. They now land on a switched desktop. The archive tag still needs its own approval.

**The user's state choice:** asked whether fart-next should take over `~/.local/state/fart`, the user approved taking over the UI. The state stays separate, as recommended (§1).

PROJECT_PLAN M7: "Parity checklist vs the archive (all Astra connection-matrix routes still valid on the Serpantinum side). Point `fart` and the clock hook to `next`; the archive keeps working via an explicit path for rollback. *Test:* full budget gate passes; rollback rehearsed once."

## 1. What switches, and what doesn't

The cutover changes **only the entry points**:

| Entry point | Before | After |
| --- | --- | --- |
| `~/.local/bin/fart` | the archive (`source/tools/fart.py`) | fart-next (`next/tools/fart_next.py`, branch `main`) |
| `~/.local/bin/fart-archive` | absent | the archive by an explicit path, for rollback |
| The clock's right-click (Serpantinum `TimeDateFace.qml`) | the archive's hunk: `fart open` | the variant: `fart toggle --from x,y,w,h --screen NAME` (DAILY_DRIVER §2) |
| `~/.local/bin/fart-next`, the Super+` bind | fart-next | unchanged |

**Each side keeps its own directories** (a deviation from CORE.md's "At cutover" column; to confirm with the user):
- **State:** `~/.local/state/fart-next` and `~/.local/state/fart`.
- **Runtime:** `$XDG_RUNTIME_DIR/fart-next` and `…/fart`.
- **Cache:** `~/.cache/fart-next` and `~/.cache/fart`.

**Why:** fart-next's core migrates what it finds. For example, it rewrites a version 1 `timers.json` to version 2. If it took over `~/.local/state/fart`, a rollback would hand the archive files it can't read. Kept apart, a rollback finds the archive's state exactly as it was left. fart-next already seeded its own state from the archive's on first start (LAYOUT.md).

## 2. The tool: `tools/cutover.py`

- **`check`:** read-only preflight of this desktop. Each line is `ok`, `wait` (expected before the switch, or needs the user) or `BLOCK`.
- **`plan`:** prints the steps.
- **`apply` / `rollback --root DIR`:** rehearse on a sandbox, laid out as `DIR/.local/bin/fart` and `DIR/TimeDateFace.qml`.
- **`apply` / `rollback --live`:** the real switch, run only on the user's instruction.

**Apply:**
1. Refuse unless `fart` is the archive's launcher and the clock carries the archive's hunk.
2. Stop the archive's panel, with its own CLI.
3. Write `fart-archive`, then `fart`.
4. Remove the archive's hunk with the archive's own tool (`tools/fart_clock.py`, imported read-only), then install the variant with `adapters/serpantinum/hook/clock_hook.py`. Each tool only reverses its own hunk.
5. Reload Serpantinum's QML.
6. Stop any fart-next still running from a worktree (a running core would otherwise keep its source), then `fart start` from `main`.

**Rollback** is the mirror:
1. Stop fart-next.
2. Restore the variant to upstream, then reinstall the archive's hunk.
3. Restore `fart` and remove `fart-archive`.
4. Reload Serpantinum's QML.
5. Start the archive.

Launchers are written atomically (0755), and the clock file keeps its mode.

**Rehearsed once** (8 November): on copies of the live launcher and the live `TimeDateFace.qml`.
- Apply gave fart-next's launcher, `fart-archive` and the variant.
- A second apply changed nothing.
- Rollback returned both copies byte-identical, with `fart-archive` gone.
- The live files' hashes were unchanged throughout.
- `tests/test_cutover.py` repeats this on every run and fails if the live launcher or clock file changes.

**Check before the switch:** every line `ok` but one: `main` is 50 commits behind `m6-design`.

## 3. Parity: the archive's controls on fart-next

The archive's connection matrix (`source/HANDOFF.md` §3) was written against Illogical Impulse. fart-next routes the same intents through the typed adapter contract (`docs/ADAPTER_CONTRACT.md`) to Serpantinum.

Each row below was checked by reading the room's code on 8 November. **Status key:**
- **✓** the same control exists;
- **≈** the intent is kept by a different route, by design;
- **–** not carried over, with the reason.

| Archive control | fart-next | Status |
| --- | --- | --- |
| **Frame** | | |
| SEARCH (rice launcher) | The command line (`Super+\``, Q4/Q5); `host.actions.openLauncher` for the host's launcher | ≈ |
| CLOSE | Header close, Esc | ✓ |
| Rooms 00–08 | `navigate()`: the index, `Ctrl+0–8`, the orbit (`Ctrl+M`), `fart page` | ✓ |
| APPEARANCE | Header preferences (`Shell.preferencesOpen`) | ✓ |
| ARCHIVE | `FArchive` (`Shell.archiveOpen`) | ✓ |
| POWER MENU | `shell.openHost("power")` → `serpantinum msg open system` | ✓ |
| **04 Devices** | | |
| Wi-Fi, Bluetooth, night light, stay awake | `network.setWifiEnabled`, `bluetooth.setEnabled`, `power.setNightLight` (the shell closes first), `power.setIdleInhibited`; also on the orbit's moons | ✓ |
| Do not disturb | `notifications.setDnd` (Devices and Inbox) | ✓ |
| Output and mic level, mute, device choice | `audio.setVolume`, `setMuted`, `setDefault` under the `mixer` lease | ✓ |
| Display brightness | `power.setBrightness` under the `brightness` lease | ✓ |
| Copy IP | `clipboard.copyText` | ✓ |
| Networks…, Bluetooth… dialogs | `shell.openHost("wifi" / "bluetooth")`: Serpantinum's own panels | ≈ |
| Power profile | `power.setProfile` | ✓ |
| Application mixer | `audio.streams` with per-stream level and mute | ✓ |
| Capture, Record | `actions.capture`, `actions.setRecording` (`tools/recording_control.py`) | ✓ |
| **08 Inbox** | | |
| Source filter, DND, mark read, dismiss | Inbox: filter, `setDnd`, `markAllRead`, `dismiss` | ✓ |
| Notification actions | "Actions in host center": `shell.openHost("notifications")`, since the host owns the notification | ≈ |
| Open notification centre | `shell.openHost("notifications")` | ✓ |
| **06 Timers** | | |
| Modes, presets (5/15/25/45), +1 min, lap, reset, start/pause | `ViewState.timerKind`, `startCountdown`, `addCountdown`, `lap`, `reset`, `toggle`: the core's timers | ✓ |
| **00 Home** | | |
| Edit profile, lock, play/pause, to Media | `FProfile`, `power.lock`, `media.togglePlaying`, `navigate("media")` | ✓ |
| Check updates | `actions.checkUpdates` (`serpantinum info updates`) | ✓ |
| System update, Update FART | `shell.openHost("updates")` (Serpantinum's about page); FART updates with `fart update` | ≈ |
| Wallpaper, presets, settings | `shell.openHost("wallpapers" / "themes" / "settings")` | ✓ |
| **01 Media** | | |
| Source, seek, shuffle, previous, play/pause, next, repeat, open player, lyrics | `media.select`, `seek`, `setShuffle`, `previous`, `togglePlaying`, `next`, `setLoop`, `raise`, the lyrics timeline | ✓ |
| **03 Workspaces** | | |
| Switch, focus a window, enter the inspected workspace | `workspaces.switchTo`, `focusWindow` | ✓ |
| **05 Tasks** | | |
| Add, filters, check/uncheck, delete with undo | The core's tasks: add (with `@list` and `!due`), the filter, `setDone`, remove, Undo | ✓ |
| **07 Clips** | | |
| Search, filters (all/pinned/images), pin, copy, delete, load more | Clips: search, `ViewState.clipFilter`, `ClipPins`, `clipboard.copy`, `remove`, `limit` | ✓ |

**The CLI:**
- **Carried over:** `fart` gains fart-next's commands: `open`, `toggle`, `page`, `key`, `close`, `status`, `start`, `stop`, `restart`, `update`, and every verb.
- **Not carried over:** the archive's `launch`, `repair`, `island`, `clock-hook` and `checkpoint`. They stay reachable as `fart-archive …`.
- **Nothing external calls them:** the Hyprland config calls only `fart-next key down|up`, and the clock calls `fart toggle` after the switch.

## 4. Before the switch

1. **M6 acceptance** (Claude B): ≤ 2 % CPU at rest, contrast, keyboard reach, the room systems measured.
2. **The full budget gate** passes on `m6-design` (`tools/check-budgets`, DAILY_DRIVER §1).
   - **Baseline at `7cdd9a2`** (offscreen, fixture; `docs/measurements/budgets-7cdd9a2.json`): `within_fixture_budgets`.
     - core idle: 21.5 MiB RSS, 0 wakeups a minute;
     - closed: 104 MiB PSS, 0 % CPU;
     - open static: 0.17 % CPU;
     - navigation p99: informational under the software renderer.
   - **Still to run on the desktop, after B's work:** `desktop_nav`, `desktop_cmdline` and `desktop_open`.
3. **The user approves merging `m6-design` into `main`**, then the merge; `check` must then show no `wait`.
4. **The user approves the switch:** `python3 tools/cutover.py apply --live`, then `check`, then a right-click on the clock. **Done on 8 November**, before M6 acceptance, at the user's word.
   - **After the switch:** the archive's panel is stopped and Serpantinum reloaded in process (same pid).
   - The clock's own call (`fart toggle --from 880,4,160,40 --screen eDP-1`) opens the panel from a cold core.
   - fart-next's log is clean, and `hyprctl configerrors` is empty.
5. **Then the archive tag** (`legacy-end4-final`), which needs its own approval.
