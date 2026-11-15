# S6: the launcher (design, F4)

Draft, 14 November 2026 (Claude A). For the owner's OK before building. Decisions it rests on: Z26–Z31, Z75, Z77, Z96,
Z102, Z117, Z136, Z138, Z139, Z162, Z176.

## 1. Where things stand

- There is no launcher of ours. Super tap and Super+Space run `dms ipc call spotlight toggle || pkill fuzzel || fuzzel`
  (`~/.config/hypr/zaetherion/keybinds.lua:25`). FART's command line hands anything it doesn't know to the host's
  launcher (`core/command.py` `_fallthrough` → `hostActions.openLauncher`), which folds FART first.
- FART's command line (`view/shell/CommandLine.qml`) is the input; the core owns grammar, matching and history
  (`cmd.run`, `cmd.complete`, `cmd.history`). Super+` opens it through `zaetherion key down|up`: a process per press,
  a socket round trip to the core, then the core asks the view to open.
- Since S4 went live the **view is resident** (`FART_RESIDENT_VIEW=1`): the process and the island are always up.
  The island's window can already take the keyboard (`IslandSurface.keyboardRequest` → `WlrKeyboardFocus.Exclusive`).
  The FART panel is a separate surface that is unmapped while folded; a warm open measured ~60 ms on 7 Nov, of which
  ~38 ms was the panel's first frame and ~6 ms Hyprland's focus (COLDSTART.md).
- Old ranking data: `~/.local/state/quickshell/applauncher/launch_stats.json`, `{app name: {date: launches}}`, 29 apps.

## 2. Key capture (the F4 question)

Z139: key press → typing accepted ≤ 100 ms, keys typed meanwhile never lost.

A key typed before our surface has keyboard focus goes to the window that still has it; the view can't buffer what it
never receives. So "no lost keys" means **shrinking the gap to nothing**, not replaying keys afterwards.

Where the time goes today (Super+` path): Hyprland bind → spawn `zaetherion` (Python) → core socket → core asks the
view → view maps the panel → first frame → Hyprland moves focus. Measurements: §2.1.

Options:

| | How | Gap | Cost |
|---|---|---|---|
| A. Today's path | bind → `zaetherion key` → core → view | process spawn + round trip + panel map | none |
| B. Global shortcut | Quickshell `GlobalShortcut` in the view; Hyprland bind with the `global` dispatcher | no process, no core round trip | the view must be up (it is, resident) |
| C. B + grow out of the island | B, and the launcher draws in the island's window, which is already mapped; only its keyboard focus changes | no map, no first frame of a new surface | island window grows; Z26 already says the launcher grows out of the island |
| D. Keep the panel surface mapped and transparent | COLDSTART's one-frame idea | ~one frame | an always-mapped surface (M5 rule); not needed if C works |

Recommendation: **B now, C for the launcher**. B (measured) meets Z139 with the view up and removes A's dropped presses; C
should close the remaining gap for letters typed straight after the press, and is measured with the same tool once built. The core still learns of every open (the view tells it), so
history, frecency and the session blocklist stay in the core; only the press no longer travels through it.

### 2.1 Measurements (14 November 2026)

`tools/launcher_keycheck.py`: nested Hyprland, private core, fixture adapter, a focused app that logs its keys. Each trial
presses Super+` (held 60 ms) and types a 12-letter word right after, 0/5/15/40 ms between keys; 10 trials per row.
"Keyboard" is ms from the press until the panel is active with the command line focused. "To app" counts letters
that went to the app instead (in order: the app gets the start of the word, FART the rest). Raw data: run2.json.

| path | case | keyboard median (min–max) | letters to the app at 0 / 5 / 15 / 40 ms |
|---|---|---|---|
| A (today) | view up, panel folded | 85–89 (78–128) | 20 / 0 / 0 / 0 |
| A (today) | first open after view start | ~115 (107–124) | 97 / 41 / 19 / 4 |
| B (global shortcut) | view up, panel folded | ~60 (53–85) | 4 / 0 / 0 / 0 |
| B (global shortcut) | first open after view start | ~87 (81–95) | 43 / 19 / 3 / 0 |

What it showed:
1. **A bug, fixed:** on the first open after the view starts, **every** key was lost (10/10 trials, both paths).
   Hyprland handed the keyboard to the panel, then ~5 ms later to the island surface named in the same focus grab,
   which takes no keys. Listing the panel last in `HyprlandFocusGrab.windows` (`view/shell/Overlay.qml`) fixed it:
   0 lost in 160 trials. This hits the owner's first Super+` after every login, so it goes to `s0-seed` on its own.
2. **A drops presses:** with press and release arriving together (no hold), ~3 in 10 presses opened nothing; the
   two `zaetherion key` processes race and the core is left "pressed". B doesn't have this.
3. **Z139:** B meets it with the view up (median ~60 ms, worst 85); A doesn't reliably (worst 128). About 30 ms of A is
   the spawn and round trip; the rest is mapping the panel and Hyprland's focus. B's first open (~87) is under budget
   but still sends the first letters to the app if typed within ~15 ms.
4. Option C, measured 14 November 2026 once built (same tool, path C: `hl.dsp.global("zaetherion:apps")`, the
   launcher grown in the island's window with its focus grab): keyboard in **10 ms** median (8–13) with the view up and
   **13 ms** (11–19) on the first open after the view starts; **0 letters lost or sent to the app in 80 trials**
   at 0/5/15/40 ms. The command reaches the view in ~4 ms; the rest is Hyprland moving focus. That closes F4: no
   new surface, no lost keys.
5. (Superseded) Not measured yet: option C (no new surface to map). It removes most of what B still pays, which is what decides
   the first letters typed straight after the press.

Caveats: fixture adapter, nested compositor's output (not the owner's monitors); `wtype` needs
`input.resolve_binds_by_sym = true` in the nested config only.

## 3. What the launcher is

- **Surface:** grows out of the island (Z26), ~600 px wide, 6 rows (Z75), montage rows (Z29). Exclusive keyboard
  while open, focus returns to the previous window on close (Z117). Esc or the bind again folds it into the island.
- **Tabs:** Apps · Files · Emoji · Clips (Ctrl+1–4 and prefixes); FART verbs, calc, unit/currency conversion, `?term`
  web search (Brave) and `>cmd` inline in Apps (Z27, Z28). Windows and window actions (Z77).
- **Order of building:** Apps with frecency first (daily use), then verbs/calc/`>cmd`/`?`, then windows, Emoji, Clips
  (shares C's quick-paste work), Files last (the home index, Z78, watch the inotify limit).

## 4. Where things live

- **Apps list:** the adapter (Quickshell's `DesktopEntries`, live as apps are installed), mapped to a neutral
  contract domain; the core never parses `.desktop` files.
- **Frecency and history:** the core (persisted like other state; launches reported by the view). Imported once from
  `launch_stats.json` (Z136), matched by app name. Ranking blends frecency with wellbeing focus time (Z75) when a
  wellbeing source is there.
- **Matching:** the core, like `cmd.complete` today, so the command line and the launcher agree.
- **Session blocklist** (Z102): the core refuses a blocked launch and says why.

## 5. Settings (Z176)

Each has a control in FART's settings: what Super tap and Super+Space open; rows shown; tab order and which tabs are on;
web search engine; terminal for `>cmd`; frecency reset; apps hidden from results; Files index on/off and excluded
folders.

## 6. Binds (owner's OK each time)

Super tap and Super+Space move from DMS's spotlight to ours (option B's `global` dispatcher). The old lines are kept
commented, so rolling back is restoring them and `hyprctl reload`.

**Done 15 November 2026 (owner's yes):** Super tap (`SUPER_L`/`SUPER_R` on release) and Super+Space send the global
`zaetherion:apps`; DMS's spotlight moved to Super+Ctrl+Space. `tools/session-start` exports `FART_LAUNCHER_SHORTCUT=1`.
Backup: `~/.config/hypr/zaetherion/keybinds.lua.bak-2026-11-15-starchart`.

## 7. The owner's answers (14 November 2026)

1. **DMS's spotlight stays reachable on another key during the trial**; ours takes Super tap and Super+Space. Which
   key keeps the spotlight is the owner's pick when the binds change (and a setting, Z176).
2. **Brave stays the browser for `?term`** (Z28); the engine and browser are settings (§5).

## 8. Built so far (14 November 2026, branch `s6-launcher`)

- **Apps list** (Z185): `view/contract/AppsDomain.qml`; `adapters/quickshell/QuickshellApps.qml` over DesktopEntries in the
  DMS adapter (ready at start); sample apps in the fixture adapter. The legacy Serpantinum adapter has none.
- **Ranking and history in the core** (Z185, Z186): `core/matching.py` (DMS's match order and weights),
  `core/launcher.py` (frecency per day, the one-time import of `launch_stats.json` through the host profile, hidden apps,
  the Session blocklist, Z188). Ops: `apps.index` (view only), `launcher.query {text, limit}` → `{rows: [{kind: "app", id,
  name, description, icon, score, match, blocked}], total}`, `launcher.launch {id}` → `{id, terminal}` or the error
  `blocked`, `launcher.configure`, `launcher.forget`; topic `launcher` (settings and counts).
- **Starting an app** (Z187): through Hyprland's exec with the compositor's environment; terminal apps in the terminal setting.
- **Settings** (Z189): rows, terminal, hidden, blocklist in `launcher.json`; their FART controls come with the surface.
- **Surface (option C, Z185).** The launcher is a face of the island (`view/shell/LauncherFace.qml`, rows in
  the star chart in `LauncherOrbit.qml`, `LauncherBody.qml` and `LauncherScenery.qml` (Z196), sizes in `LauncherLayout.js`): kind `launcher` in the island queue at the `held` priority, like the
  session card, so only a critical event interrupts it. A line to type in (the island's resting height), a refusal
  line, then `rows` montage rows. Every key asks the core; stale replies are dropped. ↑/↓ (Ctrl+J/K, Ctrl+N/P) move,
  Enter launches, Esc or the key again folds it, a click outside folds it, hover selects, a click launches. The face
  keeps its full depth while typing, so the island never jumps. The island's window is as deep as the launcher
  (`IslandSurface.deepest`) and never resizes. `view/shell/AppsIndex.qml` hands the app list to the core whenever it
  changes or the core reconnects.
- **Ways in.** `view/shell/LauncherRoutes.qml`, in every shell entry: the host's apps key
  (`KeybindsDomain.appsPressed`, the global shortcut `zaetherion:apps` with `FART_LAUNCHER_SHORTCUT=1`) and
  `qs -p <entry> ipc call launcher toggle`. An open FART folds first.
- **Keyboard (Z117).** Hyprland 0.57 doesn't move the keyboard to a mapped layer that turns Exclusive, so a key-opened
  launcher got nothing (every letter stayed in the app; the island's own `focus` route behaves the same in nested
  Hyprland). The island's focus grab now starts at once for the launcher. The window then has the keyboard 6 ms after the open.
- **Inline rows** (Z195, 15 November 2026): sums, unit conversions, `>cmd`, `?term` and FART verbs, from
  `core/inline.py` through `launcher.query`; Enter goes through `launcher.act`. Settings `search` and `browser` join
  `launcher.json`. The adapter's `AppsDomain.run(argv)` starts what the core worked out; sums copy through the
  clipboard domain. Each kind is its own body on the orbit (Z196); an unfinished `>`/`?` row is faint and Enter waits.
- **The star chart** (Z196, owner's pick B): see DECISIONS. Wheel swings the orbit; a click on a body launches it.
- **DMS's engine** (Z197): `LauncherDomain`, `adapters/dms/DmsLauncher.qml`, the bridge in DMS, `view/shell/LauncherMerge.js`.
  Files, clipboard and plugins now come from DMS; our own Files/Emoji/Clips tabs are not needed while DMS answers.
- **Not yet**: currency, windows; the settings controls in FART.
