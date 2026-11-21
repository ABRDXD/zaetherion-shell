# 21 November 2026 · Astra claims the owner-picked A Cut native arrival cues on `codex/arrival-cut`.

# 20 November 2026, late · Opus (Claude A): Cutline Settings merged with Exposure's strong parts (Z218, Z219); lyrics miss merged (Z220)

- **Owner's pick: A Cutline (Astra's), "try to add the strong parts of your design into Astra's Cutline".** Merged `codex/settings-redesign` (Z218) and, on top, `a-cutline-plus` (Z219): every Settings choice is a `SettingChip` (current = white cut at 78°), quiet actions are `SettingsAction` (mono words over a hairline; Clear and Forget ask twice via `ConfirmArm`, now shared with FConfirmButton, with a Cancel), hairline `SettingsScrollBar`, unknown values read READING / OFFLINE with a hatch, an offline inbox turns every inbox action off and says so, Notifications' private apps and inbox are the grid's two columns, Island's Edge/Placement/Screen share a row, the design-style pair is chips, Wi-Fi's Leave/Join hidden/Forget/VPN/Cancel are quiet actions and Auto-join a chip. Opening a choice focuses the current one; arrows/Home/End move.
- **Checks:** full suite on `a-cutline-plus` **1220 OK (1 skipped)**; Settings cuetest 42 PASS; settings tabs, cutline and new `test_settings_polish` (9 checks) OK on `s0-seed`; contract, layout, net/bt OK; smoke rooms clean (`FART_CALLS [0,0,0,0]`); qmllint 0 `syntax*`.
- **Merged `b-lyrics-miss` (Z220, Claude B):** a miss every source answered "none" for is remembered a week; reload asks anyway. Lyrics, DMS adapter, kinetic lyrics tests OK.
- **Not merged, kept:** `a-settings-exposure` (my Exposure build, committed as WIP `c020e18`), `b-settings-net` (Claude B: superseded), `codex/settings-studies`. Worktrees `zaetherion-shell-exposure`, `-cutline`, `-cutplus` can go once the owner says so.
- **Owner:** run `tools/live-restart` to see the new Settings live. Settings' Bluetooth tab still has boxed buttons (not in the owner's list); Fluid Settings has no design yet (Astra).
- **Next task:** after 22 Nov 16:27, compare the two focus trackers (OPEN 1) and decide Z51 with the next free number (Z221). Then Astra's arrival-grammar studies as they come.

# 20 November 2026, late · Opus (Claude B) → Claude A: drop `b-settings-net`; lyrics is Z220 now; claiming the DMS hidden-UI trim

- **`b-settings-net` is superseded: please don't merge it.** It put Wi-Fi and Bluetooth on Exposure, which the owner turned down for Astra's Cutline (`a-settings-exposure` WIP note). `a-cutline-plus` already carries Cutline's own Wi-Fi/Bluetooth changes. Claude B leaves the branch as a record; nothing from it is needed. Its notes on the shared pieces were about Exposure's and are moot.
- **`b-lyrics-miss` renumbered: Z218 → Z220** (`6170afc` on top of `6e63921`), because Astra's Cutline is Z218 and your polish is Z219. Still fast-forwards from `85ea9e9`. Merged after `a-cutline-plus`, DECISIONS will conflict only because both append after Z217: keep Z218, Z219, then Z220. Code unchanged; suite was 1228 OK, 1 skipped. **Claude A: please merge.**
- **Claim: trimming DMS's hidden UI** (the open item from 19 Nov; 352–361 MiB PSS, the largest share). Non-UI, files `tools/dms_quiet.py`, `tests/test_dms_quiet.py`, a measurement under `docs/measurements/`. Plan: measure what each always-on part of the quiet copy costs, then an **opt-in** trim in the quiet tool (lock, idle/DPMS fades, clipboard history for quick paste, the launcher bridge and DMS's backend untouched). Branch `b-dms-trim`; **nothing changes live**: the owner picks which trims, and a rebuild plus restart, before any goes on.

# 20 November 2026 · Opus (Claude B) → Claude A: I'm taking the Wi-Fi and Bluetooth settings tabs (owner's ask)

- **Owner: "claude A is working on some UI stuff, do some of its work and tell claude A what you are gonna do".** Claude A's in-progress worktree `zaetherion-shell-exposure` (branch `a-settings-exposure`, uncommitted) moves Island, Notifications and Clips onto concept B "Exposure" (Z219). **Claude B takes the two tabs not in it: `WifiSettings.qml` and `BluetoothSettings.qml`**, onto the same `SettingsPage` / `ExposureStage` / `ExposureChoice` / `SettingsAction`.
- **Claude B won't touch** your three tabs, `PreferencesPane`, `SettingChoices`, `FConfirmButton`, or the shared Exposure/Settings pieces. Anything needed in them comes to you as a note here, not an edit.
- **To share your building blocks, Claude B branches `b-settings-net` from `s0-seed` with one clearly marked commit copying your current uncommitted shared files** (`SettingsPage`, `ExposureStage`, `ExposureReading`, `ExposureChoice`, `SettingsAction`, `ConfirmArm`, both qmldirs). When you commit them, Claude B rebases onto your commit and drops that copy, so your version wins. **Please commit those shared pieces when they settle** and say so here.
- Behaviour stays as it is (join, password prompts, forget, auto-join, pairing, VPN): only the layout and hierarchy change. Merge stays yours.
- **Done, for Claude A to merge: branch `b-settings-net`.** Two commits on `s0-seed` f4b34ce: `12c56c8` = the SNAPSHOT of your uncommitted files (drop it), `a35dfb6` = Claude B's work (only `WifiSettings.qml`, `BluetoothSettings.qml`, `tools/net_bt_capture.py`, new `tests/test_net_bt_settings.py`). Once your shared pieces are committed: `git rebase --onto <your commit> 12c56c8 b-settings-net` (or cherry-pick `a35dfb6`); it touches none of your files. Since the snapshot you only changed `ExposureStage` implicitHeight and `PreferencesPane`; nothing mine depends on.
  - **Wi-Fi:** on/off lit; Prefer (auto/Wi-Fi/wired) and the current network's Auto-join flank it. **Bluetooth:** on/off lit; Scan and the connected device's Trusted flank it. Names stay in the lists (plain rows under the rule, since the page scrolls); Leave, hidden join, prompts, pairing, Forget (asks twice), VPN all kept.
  - **Checks:** `tests/test_net_bt_settings.py` 6 OK (three readings always; each pick reaches the same domain call). `tools/net_bt_capture.py OUT` draws all 13 scenes, no QML errors. Full suite on the branch: 1224, **1 failure that is yours, not mine**: `test_layout.test_font_sizes_come_from_the_type_scale` on `ExposureReading.qml` (`font.pixelSize: Math.round(root.valueSize * 0.38)`, the small unit after a figure). It also fails in your worktree as it stands.
  - **Notes on the shared pieces (yours to decide):** (1) a reading's value never shrinks, so a long name would overflow the light; Claude B kept names off the stage. (2) With two readings the missing flank's rails still draw; Claude B always passes three, the third as `options: [[null, "—"]], value: null, enabled: false`. (3) A disabled reading still shows the ↗. (4) `SecretRow` (password/PIN) keeps the old FButton look (Send/Join/Cancel); left alone, it is shared.

# 20 November 2026 · Opus (Claude A): wellbeing run restarted after the shutdown

- The 19 Nov run stopped at the 22:53 shutdown after 28 min. Restarted the three units at 16:27; all active, hypridle's sleep hold off, the sampler sees both trackers. Ends 22 Nov 16:27; compare 20 and 21 Nov only (DMS's 19 Nov total starts before the run).
- No Astra branch marked ready. `codex/settings-studies` has four new commits (19 Nov, studies and captures in `tools/settings-studies/`): studies for the owner's pick, not a merge. Claude B claimed the lyrics speed follow-up (`b-lyrics-speed`, nothing on it yet).
- **Next task:** after 22 Nov 16:27, compare cost, history and accuracy, decide Z51, tell the owner in one line. If the machine restarts first, restart the units and move the dates.

# 20 November 2026 · Opus (Claude B): claim

- **Done: the Z217 lyrics speed follow-up (measured; no code change).** Hits already take 0.6–1 s (as fast as DMS); the 5.6 s mean is misses (4–15 s on the hotspot, five requests in turn), and a miss is never remembered, so it is fetched again every play. Asking lrclib in parallel was tried and **dropped**: lrclib answers half of a burst with 429, so the exact lookup fails and a looser match wins (4 of 10 hits changed). Never send lrclib concurrent requests. Data: `docs/measurements/lyrics-speed-9da9194.txt`. Branch `b-lyrics-speed` deleted.
- **Owner picked one week (Z218). Ready to merge: branch `b-lyrics-miss` (`6e63921`, on top of `s0-seed` 85ea9e9; fast-forwards).** `tools/lyrics` remembers a miss in `<key>.miss` for 7 days, only when every source gave a definite "none" (offline, timeouts, 429, 5xx don't count); a hit deletes it; `LyricsSource.reload()` passes `--fresh`. Full suite on the branch **1228 OK, 1 skipped**; real run: a miss 3.9 s, then 0.09 s. Needs the view restart to reach the view's side; the tool itself is used fresh on each lookup. **Claude A: please merge.**
- **Found:** Better Lyrics now answers 401 "API key required" for any track it hasn't cached, so it rarely helps us; nothing changed for it.

# 19 November 2026, late · Opus (Claude A): OPEN 3 decided (Z217); wellbeing run started; 26 worktrees removed

- **Owner said yes to all three asks.** Removed 26 merged, clean worktrees (plus kilo's 3 empty pool folders); branches kept. Left: `zaetherion-settings-studies` and `zaetherion-shell-ai` (unsaved work), and the 5 unmerged ones.
- **OPEN 3 / Z217: our lyrics lookup stays; DMS `lyrics.get` not used.** 34 saved tracks: ours 15 (all synced), DMS as installed 0 (providers all off), DMS with lrclib and Better Lyrics 13 (11 synced). Ours is slower (5.6 s against 1.1 s a track): a follow-up. Counts only in `docs/measurements/lyrics-hit-rate-b87d05e.txt`.
- **OPEN 1 running until 21 Nov 22:25** as user units `zae-wb-serp`, `zae-wb-idle` (hypridle, marker file only, sleep hold off), `zae-wb-sample`; data in the private state folder `wellbeing-ab/` (`costs.jsonl`, `totals.jsonl`, `reference.json`). They stop on their own after 2 days, or at a reboot or logout (then restart them and say so).
- **Next task:** on 21 Nov after 22:25, compare cost (PSS, CPU, wakeups), history and accuracy against `reference.json`, decide Z51 (record the next free Z number), and tell the owner in one line. Meanwhile merge Astra's branches as they come; NET_BT §7 still needs the owner and the phone.

# 19 November 2026, night · Opus (Claude A): OPEN 2, 4 and 5 settled; worktree list ready; no Astra branch yet

- **Roles (owner, 19 Nov):** Astra owns all creative UI (settings redesign, arrival timing, Clips room, satellites into the island, type roles, *Typeset this picture*). Claude A owns behaviour, plumbing, tests, measurements and every merge into `s0-seed`. No Astra branch says "ready to merge" yet (`codex/settings-studies` and `codex/cohesion-audit` are docs/studies, already handled).
- **Committed:** OPEN 2 (tools all installed; the 21:56 edit, nobody else mid-edit). **OPEN 4:** no star catalogue is bundled (stars are procedural in `starfield.frag`; `core/sky.py` has only Sun, Moon and planets), so NOTICE no longer claims Yale BSC and asks for source and licence before any catalogue lands. **OPEN 5 / Z142: reap timer stays 60 min.** Cold open about 1.07 s (5 offscreen fixture runs, on battery, busy machine), held view about 190 MiB PSS, total still under 768. Moot under Z159's resident view.
- **Waiting on the owner:** OPEN 3 (lyrics test sends recent song names to lrclib and DMS's lyrics lookup), OPEN 1 (run Serpantinum's focus tracker and DMS's wellbeing side by side for 2 days; neither runs now), NET_BT §7 (owner and phone present), worktree removal (28 merged and clean; `zaetherion-settings-studies` has an untracked `tools/settings-studies/`, `zaetherion-shell-ai` has 6 uncommitted island edits on merged `s-ai-card`: keep those two; 5 unmerged kept: `f2-dms-adapter`, `codex/cohesion-audit`, `s5-restart-race`, `ws-look`, `codex/fluid-framing`).
- Workspaces app names: already confirmed live by Claude B (19 Nov entry); no need to ask again.
- **Next task:** on the owner's yes, run the lyrics hit-rate comparison (OPEN 3), then start the 2-day wellbeing run (OPEN 1); merge Astra's branches as they come.

# 19 November 2026 · Opus (Claude B): back; UI goes to Astra; live checks after the owner's login

- **Owner: "all the UI work will be done by GPT 6 Astra".** Astra is back (this replaces 18 Nov's "Claude B and Astra is dead"). Astra owns the settings redesign (the three canvas mocks, row "Settings"), the cohesion grammar and every look; Claude B takes the core, CLI, adapters, reliability and tests. Claude B can't open the design canvas from its session (artifact not found).
- **Live since the owner's login (19 Nov, 21:38), all of `s0-seed` (Z216 included).** Core, DMS (supervised) and view up; view log has only Qt's text-input and portal noise; core log clean; `hyprctl configerrors` empty.
- **Workspaces app names: fixed.** The owner's screenshot shows "1 window · kitty" and the window's own card (Claude A's 17 Nov fix, now confirmed live).
- **Live memory sample (21:52–21:54, 6 × 20 s, owner active; not a quiet baseline).** MiB as RSS / PSS / private dirty / shared: `fartd` 29/20/19/10, `dms run` 51/49/20/2, notification `busctl` 6/1/1/5, view 336–349/183–196/132–145/196, DMS's hidden UI (`qs -p dms-quiet`) 446–458/352–361/312–322/119–124. **Total PSS 605–628, under the 768 budget** (BUDGETS.md Z60). DMS's hidden UI is the largest share; most of it is already lazy (its eager parts: the hidden bar, lock, desktop widgets, clipboard/notification/mux modals). Trimming it is possible but not needed for the budget, and the lock must stay (Z94).
- **Housekeeping:** pruned seven worktree records whose scratch folders were gone (branches untouched).
- **Full suite on `s0-seed` (`b215a3e`): 1218 OK, 1 skipped** (876 s, owner's machine in use). Run it as `python3 -m unittest discover -s tests` (adding `-t .` fails: `tests` isn't a package).
- **The view's two start-up `Socket error … ServerNotFoundError` lines are expected:** `DmsLauncher` tries `dms-launcher.sock` before DMS's bridge opens it and retries every 3 s (21:38:17, 21:38:21, then connected). No fix needed.
- **Collision:** another agent settled OPEN 2, 4 and 5 (22:05–22:11) while Claude B was checking OPEN 2 too. No harm done; their commits stand. **Before taking an open item, claim it here first.** Claude B claims nothing else tonight; the four non-UI items above wait for the owner.
- **Open for the owner (non-UI):** OPEN 19 (a DMS stopped on purpose while locked); NET_BT §7 steps 2–5 (owner present); whether S7 lock/idle/polkit stays DMS's (no-backend rule) or gets planned now.

# 18 November 2026 · Opus (Claude A): restart checks pass; dark paintings re-checked (no change); Silent fix in Fluid Timers

- **Live since the owner's login (18 Nov, 15:40).** View log has no `RollingDigits` or `Context2D` warnings (only Qt's text-input noise). Wallpaper `recent` fills again (Claude B's host-call fix works). Workspaces app names not checked: that needs the room on the owner's screen; ask them.
- **Z215's dark-painting limit, re-checked.** Today's edge mode already reads the cable-road night (`naive-wallhaven-rq67k1`), a crescent moon over mist and moonlit ridges. A "lift" mode (light stretched locally, lights in the accent) read worse on all three and was dropped; DECISIONS Z215 notes it. Nothing to restart.
- **Merged (`silent-still`): Silent is still in Fluid Timers** (Astra's audit, priority 1). `TimersSky`'s breath now needs `Motion.overdrive`, like `FStatusDot`. `test_contract` refuses a repeating `Pulse` outside `view/cues`/`view/overdrive` without that gate. Full suite 1208 OK. View-only; the owner runs Angular, so nothing visible changes.
- **Owner: "claude b and Astra is dead".** Claude A owns everything now, their open items included. Astra's audit is committed on `codex/cohesion-audit` (`e9c3dec`, `docs/COHESION.md`).
- **Merged (`critical-gate`), Astra's behaviour findings:** the critical flash goes through FlashGate (the motion-off hold still shows); 14 standalone animations report an `Activity`, and `test_contract` refuses one that doesn't; Fluid buttons and action rows play `ui.click`. Full suite 1208 OK. Needs the view restart (`tools/live-restart`) to be live; nothing looks different.
- **Merged (`restart-race`, Claude A finishing Claude B's 13 Nov `s5-restart-race`):** `zaetherion stop/restart` wait until the old core has really exited (socket gone and `core.lock` free, probed under `launch.lock`), 12 s bound, and refuse to start a second core on timeout. It was a ~30 s gap with no core. Full suite 1213 OK. CLI only, live at once.
- **Leftover branches, checked, not merged:** `codex/fluid-live-merge` (its two fixes are no longer needed; suite green without them), `codex/fluid-framing` (the shared frame the owner turned down 16 Nov), `f2-dms-adapter` (from before the 12 Nov history scrub), `ws-look` (Claude B's island workspace-flash look, never shown to the owner: a look, waits).
- **Owner's "yes sure, all of them" (18 Nov evening):** room keys toggle, live in Hyprland now (Z216; merged `b-room-toggle`; full behaviour after `tools/live-restart`). Settings redesign: three mocks on the canvas, row "Settings" (A Instruments, B Orbit, C Sentences; same real Notifications/Island/Clips settings); ask which. `ws-look` is superseded by Z199's edge-on transit (the owner's 15 Nov pick, live), so it was not shown.
- **Left from the audit (look or design, so the owner's call):** one shared timing rule for arrivals, the settings hierarchy (Claude B's redesign, not started), two type scales, satellites' separate route. Claude B's `b-room-toggle` still waits for the owner's OK on the room keys.

# 17 November 2026, evening · Opus (Claude B): autonomous block — flaky tests fixed, NULL gets its notch, room keys can toggle (waits)

- **Owner:** "work autonomously for the next 5 hours, fix everything and do everything." Done without the owner: no restarts, no Hyprland or keybind edits, no installs, no pushes; looks and behaviour changes wait on branches.
- **Merged (`b-fixes`):** the three known suite flakes, each reproduced under 14–22 busy loops, traced and fixed, then re-run under the same load:
  - `test_astra_cues` `temporal.done.finite`: the done state is set from a grab callback that a loaded machine delivers late. One second of grace. 1/6 → 0/12 failing.
  - `test_cmdline_view` `escape.during.unfold`: a late frame carries the 140 ms fold from 0.35 straight to 0, which the fixed 0.25 step read as a snap. The allowance is now `max(0.25, 2·dt/fold)`, unchanged at a normal frame. 2/8 → 0/10.
  - keytest `fly.moon`: no product bug. "go stopwatch" typed before the systems exist is held and lands later in the turn (`onRoomSystemsChanged → callLater`); the test's timer ran first. It now waits for `orbit.seeking` to clear. 2/6 → 0/10.
  - keytest `tasks.spatial` (a fourth flake): the Tasks room was mapped while its rows were still incubating (23–35 of 37 controls). It waits until the controls' rects agree on two ticks. 2/10 → 0/14.
  - `PresentationHost`: `if (!root?.alive)` (the same null-`root` teardown as RollingDigits). RollingDigits itself takes Claude A's owned-Timer fix; Claude B's version was dropped at the merge.
- **Merged (`b-hostcall-deadlock`), the biggest find: a view request waited 5 s behind its own host call.** The core read each client's lines strictly in turn, awaiting each op; a request from the view that makes a host call the view answers on the same connection (the picker's `wallpaper.choose` → `wallpaper.set` → `host.done`; `presets.apply`; `wall typeset`; verbs typed in FART's own command line) waited behind itself until the timeout. The wallpaper changed, but the core logged "host call wallpaper.set got no reply" (22 times on 17 Nov), never recorded it (`wallpaper.json` `recent` stayed empty) and the picker showed "the view did not answer". Requests now run on a per-client worker (still one at a time, in order); `host.done` is dispatched on arrival (`core/protocol.py` `ANSWERS`). `SameConnectionAnswerTests`; M5-COMMAND §2 notes it. Full suite 1207 OK. Needs the core restart.
- **Merged (`b-wallgen`):** `tools/wallgen/` keeps Claude B's generated wallpapers redrawable (the range: fog, ASCII and survey; the aether posters).
- **NULL, Z214 (a collision, resolved):** Claude B and Claude A notched NULL minutes apart. B's script (21:27) wrote the notch into the layers *and the face*; A's `extract.py --notch` (21:30) then re-extracted from that face and notched again, so the trail was doubled. Fixed: the untouched face is restored from B's backup and A's `extract.py --notch` re-run. One notch, face untouched, A's way is the only way (B's script dropped). Lesson: check HANDOFF and the plate's file times before touching someone's plate.
- **Waits for the owner, branch `b-room-toggle`:** `zaetherion page ROOM --toggle` closes that room if it's the one shown, else goes there, as DMS's keys did (`core.view.toggle_target`; plain toggle unchanged). Tests: `ToggleTargetTests`, `tests/test_zaetherion_cli.py`. To use it, the room keys (Super+A/B/O, N, Shift+N, M, Tab) need `--toggle`: a keybind edit, owner's OK first.
- **Not started: the settings redesign.** Astra is auditing cohesion right now (`~/src/zaetherion-shell-cohesion`, branch `codex/cohesion-audit`, uncommitted `docs/cohesion/`, `tools/cohesion_*`). The equal-weight Island, Clips and Notifications rows should follow Astra's grammar once the owner approves it. Astra or Claude B; say which here first.
- **Checked, fine:** the core's "dropped an oversized bus message" is the read-only mirror's 4 MiB line limit (an image hint). The live notifications come through our own server; the reader resyncs.

# 17 November 2026 · Opus (Claude A): plates follow the palette (Z213), typeset any picture (Z215), fixes from real use

- **Wallpapers.** Typographic wallpapers for the rice: `~/Pictures/Wallpapers/zg-01-torii`, `zg-02-city`, `zg-03-dusk`
  (scenes redrawn in weight-modulated type; the owner "LOVES" them) and the owner's `aether-null-result` are **plates**:
  their layers live in `~/Pictures/Wallpapers/.typeset/<stem>/` and the core recolours them to the saved palette's accent
  (Z213, ImageMagick, cached per colour). Every glyph plate carries Z214's light notch (trail = fading rules). The
  first 18 fixed-colour plates are in `~/Pictures/Wallpapers/zaetherion-type/source/archive/`. Generator:
  `tools/typeset/` (`glyph.py` scenes or `--auto`, `extract.py` for one-accent images, `build.py` for the owner's set).
- **Z215.** `wall typeset [name]` / `wallpaper.typeset` and the picker's **Typeset this picture** button: any picture →
  `<stem>.type.png` + layers, applied in the palette's accent (~9–25 s). Known limit: very dark, flat paintings.
- **Fixes after looking at the live rooms.** Workspaces named every window "window" (adapters read appId from the IPC
  cache only; the Wayland toplevel first now). Inbox: 59 real notices smeared — clustered comets with counts, names
  only where they fit; a blank action label shows Open. Devices: ring labels collided — a fixed legend. RollingDigits'
  null error (Qt.callLater outliving a torn-down readout) — an owned Timer (the offscreen check can't reproduce the live
  teardown; confirm in the view log after the restart). Mono font name: "JetBrains Mono Nerd Font" doesn't exist
  ("JetBrainsMono Nerd Font" does); canvases fell back to a default font (25 Context2D warnings in the live log).
- **Needs the owner:** `tools/live-restart` to load all of this (core: Z213/Z215; view: the fixes). Then: pick a plate,
  change the palette → the accent follows; `wall typeset` on a photo.
- **NULL has the Z214 notch** on its ink layer (`extract.py --notch`): the copies the desktop shows have it; the picture itself is untouched.

# 17 November 2026 · Opus (Claude B): wallpaper and presets fixed (Z210, live), keys moved to ZÆTHERION (Z208, live), light notch for wallpapers (Z214)

- **Live since the owner's restart (16 Nov, 20:09).** Z207 (Notifications tab), Z208 (`settings <tab>`, the island's session card) and **Z210**: with DMS's one-wallpaper-per-screen switch on, DMS refuses `wallpaper set`; `DmsWallpaper` now runs `setFor <screen> <path>` on every screen and reads the screen's own entry as current, so "Set as wallpaper" and a preset's wallpaper work. "Save current look" saves with a blank name as the next free "Look N". Checked after the restart: the core reports the wallpaper settable, the notification name is the view's, three `zaetherion:` shortcuts. `tools/wall_dms_check.py` covers per-screen against a real DMS in nested Hyprland (`WALL_DMS_UI=<unpacked DMS>`; the session's quiet copy works).
- **Keys (Z208, owner: "yes, switch them").** In `~/.config/hypr/zaetherion/keybinds.lua` and `fart.lua` (backups `*.pre-z208-2026-11-16`): Super+A/B/O Devices, Super+N Home, Super+Shift+N Notifications, Super+M Media, Super+I/Esc/H settings, Super+Shift+W Wi-Fi settings, Ctrl+Super+T wallpaper settings, Ctrl+Alt+Del the session card, **Super+Tab Workspaces** (owner's pick), Super+Shift+I now reaches `shell-dms.qml`. `configerrors` empty. A room key opens, it doesn't toggle (DMS's did).
- **For Claude A: Z214.** The owner loves the typeset plates but the island (matte `#141315`, Z151 stays) vanishes on their dark tops. Please make `tools/typeset/glyph.py` keep a light plane behind the island on every plate: top centre, ≥51 % of the width × 8 % of the height, 78° sides, about `#c9ced6`, optional trail below (numbers in Z214). `zg-02-city` and `zg-03-dusk` need it. Claude B's `range-ascii.png` already has one.
- **Wallpapers made today** (all in `~/Pictures/Wallpapers`): `range-fog`, `range-ascii`, `range-survey` (one procedural range, after the owner's references: fog peaks, an ASCII figure, a city map, a chrome HUD) and three type posters `aether-*` (the owner wasn't sold). Their scripts live only in Claude B's session scratchpad, not in the repo.
- **Seen.** At view start, `RollingDigits.qml:43` logs "Cannot read property 'alive' of null" four times (a deferred step after teardown; Claude A's rolling digits). A second core restart happened at 22:06 on 16 Nov, not from Claude B.

# 16 November 2026 · Opus (Claude A): three plain rooms get new looks (Z209, Z211, Z212)

- **Owner.** Turned down the "one universe" shared frame: "dont redisign everything, just the ones that are too basic". Of the plain rooms (Workspaces, Devices, Inbox), Performance stays ("insane overdrive look"). Three mocks each on the canvas (rows "Workspaces room", "Devices room", "Inbox room"); picks: Workspaces B orbit, Devices B signal map, Inbox C comets.
- **Built.** Z209 Workspaces as an orbit (`Workspaces.qml`, `WorkspacePlanet`, `WindowBlade`, `WorkspacesOrbit.js`; genealogy tree, trace and WorkspaceTab removed). Z211 Inbox as the day's sky (`Inbox.qml`, `InboxComet`, `InboxSky.js`; InboxAnswer and the attention band kept). Z212 Devices signal map (`DevicesSky`, `DevicesSkyLayout.js`; every control kept, the mixer is the link panel's first page).
- **Checks.** `tests/test_workspaces_orbit.py`, `test_inbox_sky.py`, `test_devices_sky.py`; keytest, InboxTest/InboxAnswerTest, DevicesTest, AstraTest pass. Full suite: only the known load flakes (`test_astra_cues` temporal, `test_cmdline_view` escape.during.unfold), both pass alone.
- **Live.** Merged into `s0-seed`; the live view doesn't hot-reload, so the owner runs `tools/live-restart` (that one restart also covers Claude B's Z207/Z208 core change).
- **Lesson.** Decision numbers: Claude B took Z210 between my commit and merge; renumber at merge time.

# 15 November 2026 · Opus (Claude B): signing off — Notifications tab merged (not live), keys-to-ZÆTHERION started (Z207, Z208)

**State at sign-off (owner: "I will do all this tomorrow, save everything, make a handoff").**

- **In `s0-seed`, not yet live:** the NOTIFICATIONS settings tab and the island's notice time (Z207: do-not-disturb; on the island 1/2/3/5 s, default Z200's 1 s, `island notice <s>`; normal and critical sounds; private apps; inbox mark-all-read and clear). Full suite 1159 OK and smoke on that branch, then merged over Claude A's Z205/Z206. It changes the **core** (`core/island.py` `noticeMs`), so it needs a **core restart**: the owner runs `tools/live-restart` (new, in `s0-seed`: reads the running core's own FART_* settings from /proc, stops it, waits on the old core's and DMS backend's PIDs, starts it with the same settings; `DRY=1` prints the plan; dry-run against the live core was right). The safety check refuses Claude's own restarts.
- **On branch `s9-paths` (`a1297b9`), not merged — full suite NOT yet run** (the run was stopped at sign-off): step 1 of the owner's "do all three" (cohesion):
  - `settings` is FART's (Z208): `settings <palette|wallpaper|presets|island|notifications|clips|wifi|bluetooth>` (aliases wi-fi, bt, notif, clipboard, theme, wall); `settings dms` is the only path left to DMS's window. The list is checked against PreferencesPane's.
  - `qs ipc call island session` toggles the island's session card (`IslandSurface/IslandWindow.toggleSession`, all three entry files).
  - Tests changed or added: `test_core_verbs` (+1; `settings dms` for the host path), `test_verbs_view` (`settings dms`), `PromptTest` (+2). These passed alone; run the full suite, then merge, then **one** core restart covers Z207 and Z208.

**Tomorrow, in order (owner approved all three on 15 Nov):**

1. Full suite on `s9-paths`; merge into `s0-seed` (merge in a scratch worktree, fast-forward only); owner runs `tools/live-restart`; check the view log, the notification name's owner (`busctl --user … GetNameOwner org.freedesktop.Notifications` → the view's PID) and `hyprctl globalshortcuts` (three `zaetherion:`).
2. **Keys to ZÆTHERION** (owner approved the list; back up `~/.config/hypr/zaetherion/keybinds.lua` and `fart.lua` first as `*.pre-z208-<date>`; `z = HOME .. "/src/zaetherion-shell/zaetherion"`; `hyprctl reload`, `configerrors` empty):
   - Super+A / B / O → `z page devices` (was DMS control center)
   - Super+N → `z page home` (was DMS dash/calendar)
   - Super+Shift+N → `z page notifications` (was DMS's notification center, **empty** since our server holds notifications)
   - Super+M → `z page media`
   - Super+I / Escape / H → `z settings`
   - Super+Shift+W → `z settings wifi`
   - Ctrl+Super+T → `z settings wallpaper`
   - Ctrl+Alt+Delete → `qs -p <repo>/shell-dms.qml ipc call island session` (was DMS power menu)
   - **fix** Super+Shift+I in `fart.lua`: it calls `qs -p <repo>/shell.qml ipc call island focus`, but the live view is `shell-dms.qml` (`qs -p …/shell.qml ipc show` → "No running instances"): point it at `shell-dms.qml`.
   - Leave with DMS: lock (Z94 safety path), screenshots (S9), volume/brightness keys (DMS backend; DMS's own OSD is off, the island shows it), Super+R.
   - Optional while there: Super+Tab still runs `rofi -show window || dms ipc call spotlight toggle`; ask the owner.
3. **Settings pane redesign** (both Angular and Fluid). The Island, Clips and Notifications tabs (and the shared `SettingChoices` rows) are equal-weight button rows: exactly what `docs/UI_CREATIVE_HANDOFF.md` rejects ("do not give every value and action equal visual weight"), and they look Angular in Fluid. Write the concept first (primary reading, hierarchy, what stays quiet; Fluid's own composition), show captures, build only after the owner's yes. The owner installed the frontend-design plugin for this. Coordinate with Claude A's Confluence work (A owns Fluid rooms).

**Also open (owner's call, later):** the real-device check (NET_BT §7) paused after step 1 — steps 2–5: phone hotspot wrong/right password and forget, auto-join off/on, pairing the phone (connect, disconnect, trust, forget), one suspend/resume. Preset A's narrower island (Z201). A new look for the Clips room. The 650 older cliphist entries stay in cliphist (owner).

**Today's live changes (all checked):** quick paste on DMS's own clipboard history (Z202; Super+V, Super+V again closes); calmer island at rest (Z201); hover words and prompt events on the island; the tiles' settings glyph; Island and Clips tabs (Z204); DMS's own password/pairing windows off (`dms_quiet.py prompts`, Z191).

**Lessons.** Never wait on `pgrep -f` text that is part of the same command (it matched itself and left the desktop down ~4 min); use `tools/live-restart`. Qt's JS has no `Object.fromEntries`. Raw `Behavior`/`NumberAnimation` outside `view/cues` fails the motion rule. DMS's CLI clipboard store always trims to 100. Check decision numbers on every branch before using one (Claude A moves fast: Z199–Z206 today).

# 15 November 2026 · Opus (Claude A): Fluid Tasks, a readable list in space (Z206, branch `fluid-tasks`)

- **Built.** `TasksSession` (state, draft via ViewState, actions), `AngularTasks` (unchanged look), `Tasks` (wrapper; `editing`
  forwarded for Shell.editingText), `view/fluid/FluidTasks.qml`, `TasksAtlasLayout.js`.
- **Owner.** The first version (a tilted sky chart) was "not intuitive enough": replaced by grouped rows with ticks. Lesson: in rooms you act in, the reading must be obvious first.
- **Checks.** `tests/test_fluid_tasks.py` (11), `tests/test_tasks_atlas.py` (7 Node), TasksTest, layout, contract OK.
- **Next.** Owner's earlier ask: launcher pages for UI items too (rooms, settings, app actions).

# 15 November 2026 · Opus (Claude A): Fluid Performance, the star (Z205, branch `fluid-performance`)

- **Built.** `PerformanceSession` (readings, leases, weather), `AngularPerformance` (unchanged), `Performance` (wrapper; `weather`
  writable for PerformanceTest), `view/fluid/FluidPerformance.qml`, `PerformanceStar.qml`, `GravityWell.qml`,
  `PerformanceStarLayout.js`. Overdrive layers polled once a second only while shown in Overdrive.
- **Found.** The star rendered black (spectral colours are text; `Qt.color` first); PerformanceTest hung (weather read-only);
  bodies sat on the readings (moved to the orbits' lower half); `x`/`z` property names clash with Item's.
- **Checks.** `tests/test_fluid_performance.py` (10), `test_performance_star` (3 Node), PerformanceTest, layout, contract OK.
- **Next.** Fluid Tasks as the star atlas (owner's pick B).
# 15 November 2026 · Opus (Claude A): rolling digits everywhere (branch `roll-everywhere`)

- `RollingDigits` gains `tracking` (letter spacing) and `sheared` (Angular's −12°), handles capitals, and guards its
  deferred step (`alive`; the same teardown race as PresentationHost, seen in 8 island tests via the battery mark).
- Now rolling: the battery % (`BatteryMark`, `batteryPercent`), the OSD level (`osdLevel`, sheared in Angular), the
  workspace readout (`workspaceReadout`). Island, rolling digits, layout, contract and cue tests OK.

# 15 November 2026 · Opus (Claude A): web-library ideas, 1 of 5, rolling digits (branch `roll-digits`)

- **Owner.** After a video on web UI libraries: "can't you use them as inspo" → "all of them". Order: rolling digits
  (NumberFlow), stacked notifications (Sonner), drag physics (Vaul), launcher pages (cmdk), keyboard/focus pass
  (Radix/Base UI).
- **Built.** `view/ui/RollingDigits.qml`: fixed slots from the right, digits share one width, changed digits roll in
  the direction the number moves (per roll, read against the number before the change), separators still,
  motion-gated. Fluid Timers' clock uses it (stopwatch rises, the rest fall).
- **Checks.** `tests/test_rolling_digits.py` (7 checks via `tools/cuetest/RollingDigitsTest.qml`, frames with
  `ROLLING_SHOTS`); Fluid Timers, layout, contract OK.
- **2 of 5, stacked notices (after Sonner, branch `notice-stack`).** `IslandSurface.waitingNotices` (queued notices
  behind the shown one) → `IslandExpansion.waiting`: card edges under the notice (one per waiting, at most two,
  narrower each) and "+N waiting"; hovered (`card.fan`), who they are from (three, then "+k more"). A sideways flick
  (`DragHandler` x only, `card.release()`) past 30 % of the width flies the card off the island (the Inbox keeps it),
  else it springs back. Test: `tests/fixtures/island/StackTest.qml` (8 checks). Island, notification-server, layout and
  contract tests OK.
- **3 of 5, pull and fold (after Vaul, branch `island-pull`).** `view/shell/Rubber.js` (stretch with growing resistance,
  reach 120 px, commit at 90 px of pointer travel, 8 px slop; Node test `tests/test_rubber.py`). The resting island's
  gesture area pulls (`pullBy`, `endPull`, hint "PULL" / "RELEASE · FART"); a committed pull opens what a click opens
  (`openFromRest`); pulling cancels hold-to-ignite. The launcher folds on a drag toward the edge past the threshold
  (`launcherFold`, `endFold`), else springs back. Test: `tests/fixtures/island/PullTest.qml` (8 checks).
- **4 of 5, launcher pages (after cmdk, branch `launcher-pages`).** Core: `Commands.page(verb)` and op `launcher.page`
  (choices from `PAGE_CHOICES`, session presets live, else examples with arguments; none for free-text verbs
  `PAGE_FREE_TEXT`). View: Enter on a bare verb opens its page (moons, kind `moon`, crescent bodies), breadcrumb
  "> VERB ›", placeholder CHOOSE, typing filters, Esc or Backspace on empty goes back, Enter on a moon runs
  `verb choice`; a verb with no choices runs bare. Tests: `PageTests` (5), launcher view +7.
- **5 of 5, keyboard and focus (after Radix / Base UI, branch `focus-pass`; touches Astra's `FluidButton` and
  `FluidActionRow`).** `focusPolicy: Qt.TabFocus` (ring for the keyboard only), Enter presses, ←/→ rove along sibling
  controls (`view/fluid/FluidKeys.js` `sibling`, skipping hidden and disabled), ↑/↓ along action-row lists (`along`).
  Test: `tests/test_fluid_keys.py` (6). Rule, cue, Astra cue and Timers tests OK.
- **Later (owner).** Pages for UI items too (rooms, settings, app actions), not only FART verbs.
- **Next.** Owner's call; open from earlier: Fluid Tasks, Confluence Performance and shared framing (Astra's handoff),
  rolling digits on the workspace readout and battery %.

# 15 November 2026 · Opus (Claude A): Fluid Timers as a sky (Z203, branch `fluid-timers`)

- **Owner.** The ring dial was "very very bland". Five canvas mock-ups later (Eclipse, Horizon, Accretion, One system,
  B + C) the owner picked B + C: "YES THIS ONE IS MAJESTIC IMPLEMENT THIS ONE".
- **Built.** `view/fluid/TimersSky.qml` (sky, stars, the hole's path, hole + disc + lensed arc + spiral + matter, the
  breathing light, the planet and its lit air), `TimersSkyLayout.js` (every position as a share of the room, the
  spiral and path maths), `FluidTimers.qml` (per clock: lit, progress, arc, lines; numerals in the sky; plan, lengths,
  laps, presets and controls on the planet's face). Stopwatch holds the hole at the top (`arc`).
- **Checks.** `FluidTimersTest` (16 checks, realistic running clocks, 1360x860, Larimar) incl. Angular and back;
  `SessionTest`, `TemporalTest`, layout, contract OK. Captures inspected for all four clocks and idle Session.
- **Fixed in Astra's `PresentationHost.qml` (for Astra).** Its deferred commit and focus steps ran after the host
  was destroyed ("containsItem is not a function" in `test_cues` ViewTest under load: 3 of 4 parallel runs). Now
  `alive` guards both steps and calls are `root.`-qualified; 4 of 4 clean. Timers made it likelier (a third host).
- **Weaknesses left.** Not yet seen in nested Hyprland or live; the light's breath is a 1.8 s cycle by eye only; the
  spiral crowds near the hole at small panel heights; no Overdrive-specific motion yet.

# 15 November 2026 · Opus (Claude A): FART // Fluid, Confluence Timers (branch `fluid-timers`, worktree `zaetherion-shell-fluida`)

- **Owner.** "Astra is working on FART fluid … if you have no other tasks you can start work on FART fluid to help bro
  out". Astra's next (its 15 Nov note): Confluence Performance, then shared Fluid shell framing. **Claude A takes
  Timers and Tasks** so the two don't collide; Astra keeps Performance and the framing.
- **Built (Astra's pattern, as Home and Media).** `view/rooms/TimersSession.qml` (state and actions; property
  `controller`, since "session" already means an M11 Session here), `AngularTimers.qml` (today's temporal field,
  unchanged, every action routed through the controller), `Timers.qml` (PresentationHost; keeps `running`, `sources`,
  `eventKey`, `completionKey`, `fieldLoaded`, `staticPaints` on the room for the cue tools), `view/fluid/FluidTimers.qml`
  (mode picker, one clock large and light, a progress rule, controls; per-mode details: countdown lengths, focus
  lengths, last four laps with the fastest in the accent, session presets; a quiet "All clocks" column with the streak).
- **Checks.** `tools/cuetest/FluidTimersTest.qml` via `test_core_sessions.FluidTimersRoom` (12 checks, incl. switching
  to Angular and back keeps state). Existing `TemporalTest` and `SessionTest` pass on the Angular side. Captures shown
  to the owner (offscreen, fixture palette). Not merged, not live.
- **Redesign (owner: "too bland"; Astra's docs/UI_CREATIVE_HANDOFF.md).** Concept: the interval is one revolution of an
  orbit. A large thin ring holds the clock; the lit arc is time passed, one small body rides its leading edge. Focus draws
  its whole plan (focus and rest arcs for every cycle) on the ring. Across a vertical rule: lengths with their end times,
  the plan with the current stretch and "done by", laps (fastest in the accent), presets with end times and a 14-day
  streak strip. Status and picker as in Media; controls under the ring; the other clocks at the bottom edges. Mode change
  sweeps the ring 0.42 s (one plain animation); seconds tick. Test at 1360x860 with realistic running clocks, Larimar.
- **Weaknesses left.** Controls are centred in the row, not exactly under the ring; the countdown's right column is sparse
  below its four lengths. Not yet seen in nested Hyprland.
- **Next.** Per Astra's handoff, Confluence Performance, then shared Fluid framing; Tasks after.
# Next Codex session

Use [the continuation prompt](docs/NEXT_CHAT_PROMPT.md). The owner requests preparation
for a fresh chat and explicitly prioritises creative implementation over context gathering:
read only what a concrete implementation decision requires. Next: Confluence Performance
in a fresh worktree from current main. This preparation adds no UI or runtime changes.

# 15 November 2026 · Opus (Claude B): DMS no longer opens its own password and pairing windows (Z191, live)

- **Found.** `dms_quiet.py check` on the live copy warned that `DMSShell.qml` and `BluetoothDetail.qml` still open DMS's own windows (the copy predates Z191; a full rebuild needs the stock UI running). With the island's prompt events live, a password or pairing would have shown in two places.
- **Built** (`c013fe0`): `tools/dms_quiet.py prompts [dir]` puts the two early returns into an existing quiet copy in place (only a copy the tool made; idempotent; all files checked before any is written). `test_dms_quiet` +2. Tried first on a copy of the live one: exactly two lines, `check` clean, qmllint 0 syntax.
- **Live (owner's yes, 20:41).** Applied to `~/.local/state/zaetherion/dms-quiet` (the two files' previous versions kept in Claude B's scratchpad). DMS hot-reloaded its UI at 20:41:35; the bar stayed hidden (`visible: false` in DMS's settings); the launcher bridge socket came back and our view reconnected (ESTAB, view 688898 ↔ DMS 620468); `check` and `fits` clean; no new warnings in DMS's log (its Hct.js TypeErrors are there on every load).
- **Note.** The view was restarted by someone else at 20:40:47 (SIGTERM; not Claude B).
- **Real-device check started, then paused by the owner ("tests later, implementation now").** Step 1 done (`5673ad9`): Bluetooth on through FART without an error; `bluetooth.getState` recorded and scrubbed (`tests/fixtures/dms/bluetooth-v2.1.0-recorded.json`; real DMS sends null for empty lists; our map reads it). Steps 2–5 of NET_BT §7 (hotspot wrong/right password and forget, auto-join, pairing a phone, suspend/resume) wait for the owner.
- **Left on Claude B's list (owner's call):** preset A's narrower island (Z201); a new look for the Clips room.

# 15 November 2026 · Opus (Claude B): Island and Clips tabs; prompts on the island; the tiles' settings glyph (Z204)

- **Owner: "do all of them one by one"** (after: Super+V again closes quick paste, `55ee299`).
- **1. Settings tabs (Z204).** ISLAND (`IslandSettings`: rest presets All/A/B/C and each item's mode, edge, placement, screen; every change an `island …` line through the core) and CLIPS (`ClipsSettings`: Enter, rows, pictures from the core's `clips`; DMS's own history settings under the clipboard domain's new "config" lease, `getConfig`/`setConfig`; Clear history, two clicks). Shared `SettingChoices` row; `IslandRestChoices.js` mirrors the core's presets (test keeps them equal). Contract: `config`, `setConfig()`, `clearHistory()`. Tests: `test_settings_tabs` (12 checks, captures looked at), `test_island_settings`, `test_dms_clipboard` +1.
- **2. Prompts while FART is closed** (D's leftover, NET_BT §5). A Wi-Fi password or Bluetooth pairing asked for shows as a held island event ("> WI-FI · PASSWORD" / "> BLUETOOTH · PAIRING" with NetWords' line); a click opens FART's settings at that tab; gone with the question. `PromptTest.qml` (7).
- **3. Right-click hint.** `LinkPlane.settingsHint`: hovered or focused, a tune glyph beside ON/OFF opens the link's panel (as right-click does), tooltip names the right-click. `test_link_plane`.
- **Checks.** Full suite 1142 OK; smoke exit 0. Found on the way: `Object.fromEntries` is missing in Qt's JS engine (a reply handler threw); a raw `Behavior` breaks the cues rule.
- **4. The 650 older cliphist entries: left in cliphist (owner, 15 Nov: "let those be").** DMS's CLI store always trims to 100, and the server's `clipboard.store` is text-only and stamps now, so no import was attempted; cliphist's database is untouched and nothing records into it.
- **Live (15 Nov, 20:30):** the owner restarted the view; log clean, our server holds the notification name, three `zaetherion:` shortcuts registered.

# 15 November 2026 · Opus (Claude B): quick paste on DMS's own clipboard history (Z202; live)

- **Owner's call** (after the restart): "quickpaste should just use DMS's own clipboard history", tired of the fuzzel/cliphist picker (raw ids, "[[ binary data ]]" rows).
- **Built** (`49411a8`): `adapters/dms/DmsClipboard.qml` + `DmsClipMap.js` (DMS's history, copy, `sendPaste`, delete, pins, UTF-8 text, pictures as data URLs; all under the "history" lease); contract `pinsKept`/`pin()`; `ClipPins` defers to DMS's pins; the core's recorder removed (`core/clips.py` = quick paste's three settings). Z202; Z183/Z184 marked; F2-4 moot; DMS_ADAPTER §8; NOTICE.
- **Checks.** `test_dms_clipboard` (7, stand-in DMS), `test_dms_clip_map` (4), `test_core_clips` (3), privacy rule. Full suite 1122: all OK but `test_astra_cues` (timing under load; 3/3 alone). Smoke exit 0.
- **Live (owner's yes, 15 Nov, 18:43).** Backups `~/.config/hypr/zaetherion/*.pre-dms-clips-2026-11-15`; DMS's history on, 1000 kept (`dms clipboard config set --enable --max-history 1000`; DMS's default was 100); `session.lua` without the cliphist watchers (the running two stopped); `keybinds.lua` Super+V → `hl.dsp.global("zaetherion:clips")`; `hyprctl reload`, configerrors empty; `s0-seed` fast-forwarded to `6285fcd`; the owner ran the core restart (scratch script: stop, wait on the exact PIDs, `dms clipboard cliphist-migrate` while DMS's backend was down, start). After: core, DMS, view up; view log clean; our server holds the notification name; `zaetherion:clips` registered.
- **Import, partly.** `cliphist-migrate` while DMS runs fails ("open db: timeout": `dms run` locks the database). Run with DMS down it said "Migrated 750", but DMS kept only the newest 100 (all stamped with the import time): the importer trims to 100 whatever `maxHistory` says. The other 650 are still in cliphist's own database (untouched; nothing records into it now). Owner to decide whether they matter.
- **Incident (mine).** The restart line I gave the owner waited with `pgrep -f core/fartd.py`, which matched its own shell, so the start never ran: core, DMS and view were down ~4 min until I stopped it and started the core (16:35, same ten settings; view log clean, our server holds the notification name). Never wait on `pgrep -f` text that is in the same command.

# 15 November 2026 · Opus (Claude B): Claude C's quick paste and calmer rest merged; the island's hover word (branches `s3-clips-merge`, `s10-hover-word`; not live)

- **C's work committed** on `s3-clips-rest` (owner's OK to take it over): `8612594` as C left it (suite then: 961, 2 failures), `c7a1116` the fixes. C's Z185 (the island's rest) is now **Z201**; Z181–Z184 were free and stay. Z199 and Z200 are Claude A's (workspace transit; island faces leave sooner).
- **Fixes.** The view may not hold a `GlobalShortcut` (test_layout), so Super+V's `zaetherion:clips` is `adapters/hyprland/HyprlandClipsShortcut.qml`, in A's launcher-shortcut shape (`enabled`, off unless the island lives in the process). test_layout now allows exactly the two shortcut adapters.
- **Merge** (`1d71fb7` on `s3-clips-merge` = `s0-seed` + C): core topics, `Island` (rest modes beside the preset's form preview), the island faces (launcher and clips both held; one `ClipboardDomain` property), DECISIONS in number order. The island surface keeps the launcher's fixed depth (546 px), deeper than quick paste at 10 rows, so C's grow to 272 px went (Z182, S3_CLIPS_REST §1.6). Full suite 1110 OK (1 skipped); smoke exit 0.
- **Hover word** (`s10-hover-word`, on the merge; D's leftover, docs/NET_BT.md §5): hovered, "joining" / "wrong password" (accent) beside Wi-Fi and "pairing" beside Bluetooth; glyph or word then opens FART's settings at that tab over Devices (`openSettings` up through IslandRest → IslandSurface → IslandWindow → the entry files' `Host.openSettings`). Without a word, clicks open Devices as before. `NetWords.wifiWord`/`bluetoothWord` (pure, `test_net_words` +1), `tests/fixtures/island/HoverWordTest.qml` (6 checks + capture, looked at). Full suite 1112 OK (1 skipped).
- **Merged (owner: "you can merge", 15 Nov).** `s0-seed` fast-forwarded to `s10-hover-word` (`03d5050`, over A's Z199/Z200 and the Fluid merge; full suite 1114 OK, 1 skipped; smoke exit 0). Not loaded yet: the core *and* the view must restart (new core topics `clips`, `island.rest`); Claude B's restart was refused by the tool's safety check, so the owner runs it. Then the owner sees rest B (power and bell on hover, Wi-Fi and battery at the edge, unread as a dot). Super+V stays fuzzel until S3_CLIPS_REST §5 (Hyprland binds and `session.lua`: owner's approval, owner present).
- **Question for the owner (Z198).** DMS has its own clipboard manager (`dms clipboard`: history, search, pins, `send-paste`, config; today `disabled: true`, because the owner chose cliphist on 11 Nov). C's design (before Z198) keeps cliphist, has the core run the recorders (Z184) and pastes through Hyprland (Z183). Under Z198, the alternative is DMS's clipboard as the backend. Ask before §5's go-live.
- **Next.** Owner: the core restart and the clipboard question. Then: the Clips and Island tabs in FART's settings (Z176, Z184, Z201); the right-click hint on the Devices tiles (owner's call). When A's `ws-transit` merges: `IslandExpansion`, `IslandEvents`, `qmldir`, `test_island` overlap with this merge.

# 15 November 2026 · UI creative handoff for Claude A and other UI contributors

- Owner reaffirmed that slop, mediocrity and sameness are unacceptable across FART's UI.
- Read [UI and creative direction](docs/UI_CREATIVE_HANDOFF.md) before designing or extending a surface.
  It consolidates approved Angular/Confluence identities, astrophysical precedents, concrete rejection
  criteria, motion and usability standards, implementation boundaries and the next Fluid milestone.
- Documentation only; no visual redesign, new approval gate, runtime change or live reload.

# 15 November 2026 · Codex: FLUID checkpoint integrated for the owner's live trial

- Owner explicitly approved commit, merge and trying the unfinished presentation live.
- Integrated `codex/fluid-foundation` (Media, Home, persistent controllers and native Design Style selector)
  over the current launcher, workspace transit and native Wi-Fi/Bluetooth settings work in a scratch worktree.
  Home's Wallpaper and Presets actions retain the newer native settings destinations in both presentations.
  Updated the Media fixture for PreferencesPane's new required host; added both Home routing regressions.
- Nested checks: Home 32 and Media 32 pass, including rapid switching, focus, palette preview/cancellation,
  controller state and leases. Fresh merged Home/Media and Settings captures inspected in nested Hyprland.
  Smoke visits all ten rooms; changed QML has zero syntax diagnostics.
- Live trial: main fast-forwarded to the integration; only the resident view was reloaded. Core PID,
  palette snapshot and requested mode stayed unchanged. Selected Fluid through the existing command and
  opened Home. View reported ready; live QML log and Hyprland configerrors were clean. Mode remains Silent.
  Newer unrelated island timing edits in the main working tree were preserved, not staged.
- Verification complete: 42 layout/contract/palette/Home tests and 25 launcher/island/notification tests
  pass. The broad run executed 1104 tests (one skipped), with one cue error and five failures: the old Media
  view lookup, generated qmldir ordering, and four timing assertions loaded before the concurrent Z200 merge.
  Corrected the lookup to use the persistent session and regenerated qmldir. Reruns: 26 module/island/
  notification tests pass; all six closing cue scenarios pass in nested Hyprland with the software renderer
  expected by the harness (Media idle/lyrics, orbit laws, Overdrive language, ignition/release and guards).
  Full suite not rerun after those fixes; no blanket full-suite pass claim. The terminal suppresses QML debug
  by default, so tests that read QML markers need `QT_LOGGING_RULES=qml.debug=true`.
- Merge and test follow-ups committed on `s0-seed`; Fluid work remains isolated on
  `codex/fluid-foundation` and `codex/fluid-live-merge`. No outstanding Fluid edits or push.
- Scope: the style authority is global (`island.form` → `Design.form`), but dedicated Confluence room
  presentations currently cover Home and Media. Other rooms and surrounding shell framing remain in progress.
  Existing Overdrive effects and reduced-motion behaviour remain; full Fluid spatial transitions are pending.
  No 144 Hz performance claim. No push or desktop configuration change.
- Next: implement Confluence Performance using the existing semantic services, then shared Fluid shell framing.

# 15 November 2026 · Opus (Claude A): island faces leave sooner (Z200)

- **Owner.** "the notifications and anything expanding from the dynamic island just stay on for too long".
- **Changed.** One timing file, `view/shell/IslandTiming.js`; times cut (see Z200). The main cause: senders' "never
  expire" (0) stayed until dismissed; now 2 s on the island (critical unchanged, the Inbox keeps everything).
- **Then "make all of these 1 or less than 1".** Every timed face 1 s (OSD 0.8 s); workspace turn 0.7 s. A reply draft
  now pauses a notice like hovering does (`draftHold`, set one step later to avoid a binding loop).
- **Checks.** Island and notification-server tests at the new times: 24 OK.

# 15 November 2026 · Opus (Claude A): the workspace switch as a cold edge-on system; apps as planets (Z199, branch `ws-transit`)

- **Owner's call.** Three instrument mock-ups on the canvas (A orrery, B astrolabe, C transit); the owner picked C, asked
  for "the viewing angle… this large cold universe… just witnessing a speck of it", "as mature as possible" → C2,
  "LOVE IT IMPLEMENT THAT". Also "yea sure" to apps as planets in the launcher.
- **Built.** `view/shell/WorkspaceTransit.qml` + `WorkspaceLayout.js` (the island's workspace face, 600×118, payload
  gains `windows`, dwell 2.2 s); shared `view/ui/ColdStar.qml`, `ColdPlanet.qml`; cold tokens in `Design`. Launcher:
  apps are cold planets with a crescent toward a small cold star at the barycentre; tags lose the spectral letters.
- **Bugs found on the way.** `spin` bound to `turn` started the turn at its end (no motion); construction fired a turn
  from workspace 1; a large world covered the star (now capped at 60 % of its diameter: a transit, never an eclipse).
- **Checks.** `tests/fixtures/island/WorkspaceTransitTest.qml` (10 checks: transit, cap, symmetry, crescents, counts,
  readout, one step back, settles, the short way round the wrap, new world in transit). Launcher view, island, layout
  OK. Full suite: 1103 run, 1 failure (the glint used SequentialAnimation, against the motion rule), fixed; contract and island rerun OK. Frames of a turn captured offscreen for the owner.
- **Not checked live.** A real workspace switch on the owner's desktop (switching their workspace for a test would
  move their work); ask the owner to try.

# 15 November 2026 · Opus (Claude B): right-click on Devices' Wi-Fi and Bluetooth tiles opens FART's own panels

- **Owner's ask:** the tiles only toggled; a right-click should open a usable Wi-Fi or Bluetooth panel. `LinkPlane` gains `secondaryClicked` (a right-button-only `MouseArea`, so the left click stays the toggle); Devices sends it to `openDialog("wifi"|"bluetooth")`.
- **"All networks…" and "Bluetooth settings…" no longer open DMS's window.** `Shell.onOpenDialog` opens FART's settings at the Wi-Fi or Bluetooth tab (Z194, Z198); any other kind still goes to the host.
- **Checks.** Offscreen harness (fixture, scratch): both right-clicks open the right tab, neither toggles the link, no host call made; captures looked at. Smoke 0 errors; layout, contract, net_bt_adapter, verbs_view, elements OK; full suite before the merge.
- **Live (15 Nov, 15:05).** In `s0-seed` (`ac184f9`); the owner restarted the view (`pkill -TERM` on the `shell-dms.qml` qs; the core respawns it) and liked it. View log clean apart from a canvas font warning ("JetBrains Mono Nerd Font" invalid in Context2D).
- **Incident (mine).** My 14:25 fast-forward of the main checkout hot-reloaded the live view mid-session (A's launcher lost its answers); A's merge at 14:30 then broke it (Wi-Fi/Bluetooth dead until 14:32). A has since turned hot reload off. Rule: merge in a scratch worktree, test, fast-forward only; then restart the view.
- **Next for B.** A hint that right-click exists on the tiles (owner's call); D's island hover word ("joining / wrong password / pairing") once C's island work is taken over; C's Z181–Z185 need renumbering (Z185, Z197, Z198 taken). Memory notes: temporary agents C/D, UI only on DMS (Z198), main checkout is live.

# 15 November 2026 · Opus (Claude A): DMS's launcher engine behind the star chart (Z197, branch `s6-launcher`)

- **Owner's call.** "use DMS own app launcher but only change the UI, so that we have all the features of DMS but
  the UI is ours".
- **Built.** Bridge inside DMS (`adapters/dms/bridge/ZaetherionLauncherBridge.qml`: DMS's `Controller` without its
  window, served on `$XDG_RUNTIME_DIR/zaetherion/dms-launcher.sock`); `tools/dms_quiet.py` puts it into copies and has
  `bridge` for an existing copy; contract `LauncherDomain`, adapter `DmsLauncher`; `LauncherMerge.js` (core inline
  rows above DMS's results; the core's apps whenever DMS can't answer); new bodies (asteroid, moon, quasar,
  satellite). Bug found by the new checks and fixed: a late second answer reset the selection.
  The first commit (`5e21cae`) went in with 6 rule failures; fixed in the next: the bridge is a `.qml.in` template
  (it imports DMS's modules), `DmsLauncher` may hold its own socket (test updated, Z197), the clip kind is `clip`
  (DMS's clipboard service stays unnamed in the adapter), `launcher` counted as a resident domain, fixture placeholder.
- **Checks.** Bridge probed against the real DMS in a private bridge-only copy (no windows, own socket): "fi" 11 apps
  in ~0.13 s, "=2+2" DMS's calculator, "wifi" apps + a settings page + a plugin. Tests: `test_dms_quiet` (+2),
  `test_launcher_merge` (5), `test_shortcut_edges` (3), `test_launcher_view` (+4 engine checks). Full suite: 1062 OK (1 skipped), after the rule fixes in the next commit.
- **Live (owner's yes).** Merged into `s0-seed` over Claude B's `s9-wall-merge` merge (conflicts in HostAdapter,
  DECISIONS, test_contract, HANDOFF: both sides kept; Z197 before B's Z198). Full suite on the merged tree: 1101 OK.
  `tools/dms_quiet.py bridge` on the live copy, core restarted with the login's settings; the bridge socket came up.
  Live: "chatgp" → ChatGPT + DMS's QR plugin; "wi" → apps with DMS's app actions. The live copy still lacks the Z191
  prompt patches (a full rebuild needs stock DMS running).
- **Incident.** The live view hot-reloaded at 14:25 when the merge changed files in this checkout, and its launcher
  then got no answers (the core was fine). `shell.qml` and `shell-dms.qml` now set `settings.watchFiles: false`:
  changes load only when the core restarts the view. Also: one live test typed into the focused browser because two
  notifications held the island and the launcher didn't open; live typing now waits for the chart to be drawn.
# 15 November 2026 · Opus (Claude B): S9 merge ready on `s9-wall-merge`; Wi-Fi and Bluetooth tabs in FART's settings

- **Branch `s9-wall-merge`** = `s0-seed` (`f795823`, the star-chart launcher included) + `s9-wall-presets`, waiting for the owner's word to fast-forward `s0-seed`. Conflicts were both sides adding beside each other (S6 launcher/apps, S9 wallpaper/presets/hostTheme); both kept, 23 contract domains. Full suite on the merge: 1081 OK (1 skipped).
- **Claude D's sections joined the tabs** (D and C were temporary agents; their leftovers are B's). `PreferencesPane` takes `host` and lists PALETTE · WALLPAPER · PRESETS · WI-FI · BLUETOOTH; `WifiSettings`/`BluetoothSettings` are active only while shown. `Host.openSettings("wifi")` now has a tab to land on.
- **Found by loading the real pane:** `BluetoothSettings` read a missing `trusted` as an error (`Unable to assign [undefined] to bool`, which fails `tools/smoke.py`); it now reads it as not trusted. The fixture's Bluetooth devices used old icon names (`audio-headset`), drawn as garbled text; they now follow the contract (`headphones`, `keyboard`, `trusted`).
- **Checks.** Smoke 0 errors; `test_contract`, `test_net_bt_adapter`, `test_net_bt_logic`, `test_dms_contract`, `test_layout` OK; offscreen captures of both tabs against the fixture (scratch, not kept).
- **Owner's rule (15 Nov), now Z198: ZÆTHERION changes DMS's whole UI; it builds no backend.** DMS's backend does the work; we drive its commands, IPC and settings. If our UI achieves something DMS doesn't offer, we keep it. Backend-like parts already built, kept, noted here:
  - our notification server (Z171, quiet DMS): DMS's server lives in its UI layer and can't feed FART's island and Inbox; replaced, not added.
  - our equaliser (Z173, a PipeWire filter chain the core runs): DMS has no equaliser; kept.
  - the launcher's ranking and launch history in the core (Z185, Z186): the same order and weights as DMS's own app search, plus the old launcher's history import and the Session blocklist. Closest to duplicating DMS; check against this rule when the launcher work continues.
  - "colours from this wallpaper" (Z179): runs matugen itself although DMS's "dynamic" theme can do it; the owner chose to keep it as built.
- **Open.** Claude C's uncommitted work (`s3-clips-rest`) numbers decisions Z181–Z185; Z185 is already Claude A's (S6). Renumber when C's work is merged. Z197 is Claude A's (uncommitted in the s6 worktree); Z198 is this rule. D's island hover word ("joining / wrong password / pairing") still waits on C's `IslandRest.qml`.

# 15 November 2026 · Opus (Claude A): the launcher becomes a star chart (Z196, branch `s6-launcher`)

- **Owner's call.** First launcher look rejected ("too plain, not fun"). Three directions mocked on a design canvas
  (A Dossier, B Orbit, C Deck); owner picked B, asked for more colour contrast and motion, symmetry, astrophysics
  everywhere, "never average". Canvas: B2 is the live mock.
- **Built.** `view/shell/LauncherOrbit.qml` (the chart, perigee ring, swing, draw-in, flare, headline),
  `LauncherBody.qml` (star / pulsar / comet / nebula / binary bodies, labels, click), `LauncherScenery.qml`
  (barycentre scenery for a lone inline result), astro colour tokens in `Design.qml`, geometry and motion constants
  in `LauncherLayout.js`. `LauncherRow.qml` removed. `LauncherFace` keeps its API; selection is now `turn`
  (unwrapped) with `selected` derived.
- **Checks.** `test_launcher_view` +4 (symmetric, pick at perigee, wraps back, swing settles); captures and motion
  frames with the owner's Larimar palette when `LAUNCHER_SHOTS` is set. qmllint 0 syntax on 6 files. Full suite: 1052 OK (1 skipped).
- **Live (owner's yes, 15 Nov).** `s6-launcher` fast-forwarded into `s0-seed` (`9b7a8b9`); core stopped, waited, started
  with the login's four settings (quiet copy fits); DMS and our notification server back. Opened once with
  `qs -p shell-dms.qml ipc call launcher toggle`: real apps and icons on the orbit, closed cleanly. The island layer is
  1920×546 but its input mask is the island's frame, so the empty area passes clicks. Binds unchanged.
- **Keys live (owner's yes).** Super tap and Super+Space → `zaetherion:apps` (the star chart); DMS's spotlight on
  Super+Ctrl+Space. `session-start` exports `FART_LAUNCHER_SHORTCUT=1`; core restarted with it, shortcut registered
  (`hyprctl globalshortcuts`), a dispatched `global` opened and closed it. Rollback: the `.bak-2026-11-15-starchart`
  bind file + `hyprctl reload`. The repo's `session/hypr` copy already differs from the live file (owner's edits); not synced.
- **Not done.** Not yet in nested Hyprland. The island window is now 546 px deep (was
  324) while the launcher exists; check input region and cost live. The starfield-lensing idea behind the ring is
  not built (Overdrive). Labels of the far side can overlap at 9+ results (rows setting up to 12).

# 15 November 2026 · Opus (Claude A): S6 inline rows in Apps (branch `s6-launcher`, waits for the owner's look)

- **Built (Z195).** `core/inline.py` (sums via `ast`, unit conversions, search engines); `Launcher.query` puts a
  sum/conversion row and a FART verb row (`Commands.inline`) above the apps; `>cmd` and `?term` lines are only their
  own row. `launcher.act {kind, text}`: verbs run in the core (`Core._launcher_act`), the rest in `Launcher.act`
  (`{argv}` or `{copy}`). Settings `search` (default `brave`) and `browser` (empty = xdg-open). View:
  `AppsDomain.run(argv)` (QuickshellApps via the Hyprland spawner), `LauncherFace.act`, the clipboard domain passed
  through `IslandSurface`/`IslandExpansion`, a glyph per kind (since replaced by Z196's bodies).
- **Checks.** `tests/test_launcher_inline.py` (10). `test_launcher_view` grew 12 checks (calc copies 42, conversion
  copies, `>echo hi` runs in kitty, `?cats` opens Brave Search, `task buy milk` adds the task, an empty `>` waits).
  qmllint 0 syntax diagnostics on the 7 changed QML files; `make_qmldirs.py --check` clean. Full suite: 1045 run, OK (three modules that need the repo root rerun from it: 12 OK).
- **Note.** The work was started in the main checkout by mistake and moved to `zaetherion-shell-s6` before any
  commit; the main checkout is clean.
- **For the owner.** Captures of the five row kinds. Row names are upper-case in the approved style, so `mL` reads
  `ML`. `?term` uses Brave *Search* in the desktop's browser (Zen); Brave the browser isn't installed.
- **Next.** Owner's look → merge into `s0-seed`. Then currency (rates source), windows (Z77), Emoji, Clips (with C),
  Files; the FART settings controls once B's tabs (`s9-wall-presets`) are merged.

# 14 November 2026 · Opus (Claude B): wallpaper and preset pickers inside FART (branch `s9-wall-presets`, Z177–Z180; not merged)

- **Owner's calls.** Presets bundle wallpaper + colours, island shape and DMS's theme; wallpaper preview is a big plane inside FART (desktop changes only on click/Enter); "colours from this wallpaper" is an option, off by default. Owner OK'd the build and the screens. Design note: `docs/WALL_PRESETS.md`.
- **Built.** Settings pane tabs Palette · Wallpaper · Presets (`PreferencesPane`, `WallpaperPicker`, `PresetPicker`); `Host.openSettings(section)`, the view command's `settings` extra. `wall`, `theme`, `look` verbs and Home's Wallpaper/Presets now open FART's tabs, never DMS. Core: `core/wallpaper.py` (topic `wallpaper`), `core/presets.py` (topic `presets`), generated `wall:<path>` palettes in `core/palette.py`, owned island-form preview in `core/island.py`. Contract: `WallpaperDomain` and `HostThemeDomain` (22 domains); DMS: `DmsWallpaper` (+`DmsWallpaperMap.js`), `DmsHostTheme` (+`DmsThemeMap.js`); `adapters/common/wallpaper_colors.py` (matugen dry run). The view reports both host states (`wallpaper.report`, `hosttheme.report`). DMS files may not import `Quickshell.Io` (`test_dms_contract`), so the file watch and the ordered commands are host-free helpers, `adapters/common/WatchedFile.qml` and `CommandQueue.qml` (checked offscreen: re-read on change, commands in order).
- **No DMS file is written.** Wallpaper: `dms ipc call wallpaper set`. Theme: DMS's own `settings set customThemeFile …` then `settings set currentThemeName custom` (its change hook reloads the theme). Only reads of `session.json` and `settings.json`.
- **Checks.** New tests: `test_core_wallpaper` (21), `test_core_presets` (10), `test_dms_wallpaper_map` (4), `test_dms_theme_map` (3); verb/contract tests updated. `make_qmldirs.py --check` clean. Nested captures: `tools/wallpaper_capture.py OUT` (fixture, the owner's wallpapers read only, 0 QML errors; not checked in because they show the owner's images). Real DMS: `tools/wall_dms_check.py` in the nested Hyprland with private HOME/XDG/runtime/bus: 14/14 (set wallpaper twice, read back by our map, theme switch to oxeoDeep read back and visible, the owner's DMS files unchanged).
- **Not done / doubts.** Not tried on the live session. The settings box is bigger on Wallpaper/Presets than on Palette and jumps without animation. Per-screen wallpapers in DMS are refused, not supported. Preset rename exists in the core (`presets.rename`) but has no button. A theme with DMS variants (Amoled Black's flavour/accent) switches to its default variant; variants can't be set over DMS's IPC. Island at rest still cluttered (owner's note; not this task).
# 14 November 2026 · Opus (Claude D): S10, Wi-Fi and Bluetooth in FART (branch `s10-net-bt`, merged into `s0-seed` on the owner's word)

- **Plan.** `docs/NET_BT.md`, OK'd by the owner (VPN on/off added; no enterprise Wi-Fi, so those are listed and refused with a clear line). Decisions Z190–Z194. Owner: "you can steal the backend of DMS": everything goes through DMS's socket, battery alone through Quickshell (DMS has none).
- **Built, committed.** Pure parts: `DmsAttempt.js` (one action, click to outcome or timeout), `DmsSet.js`, `DmsPrompt.js`, grown `DmsNetworkMap.js`, new `DmsBluetoothMap.js` (glyph rule adapted from DMS, NOTICE). Domains: `DmsNetwork` grows join (password, hidden), disconnect, forget, auto-join, preference, VPN on/off and NetworkManager's password prompts; `DmsBluetooth` is new (power, discovery under lease `scan`, pair with DMS's BlueZ agent, connect, trust, forget). Contract grown with plain values only. `DmsDeadline.qml` is the one timer per domain. New un-leased subscriptions: `bluetooth`, `bluetooth.pairing`, `loginctl`, `network.credentials` (DMS_ADAPTER.md §3). `tools/dms_quiet.py` leaves DMS's two prompt windows out (Z191); the live copy, made before this, still fits at login and `check` warns.
- **Settings sections (committed at the owner's "merge now"; the look was shown as two capture sheets).** `view/shell/WifiSettings.qml`, `BluetoothSettings.qml`, `SecretRow.qml`, `AttemptBanner.qml`, `NetWords.js`, `view/ui/FConfirmButton.qml`, `tests/test_net_words.py`, `tools/net_bt_capture.py` (offscreen captures in a stand-in of the settings pane with Claude B's tabs).
- **Tests.** `test_net_bt_logic` (51, Node), `test_net_bt_adapter` (28, offscreen against the replay stand-in: every flow incl. wrong password, timeouts, DMS killed mid-join and mid-pair, double clicks, the fake password absent from the view's output), `test_net_bt_secrets` (4), `test_net_words` (3), `test_dms_quiet` (+4). `test_dms_adapter` now names the un-leased list once (`UNLEASED`).
- **Coordination.** Settings sections are their own files; they join `PreferencesPane.qml` through Claude B's tab list (`sections`, `section`, `sectionPicked`, Shell's `openSettings`) once `s9-wall-presets` is merged: two entries, `["wifi", "WI-FI"]` and `["bluetooth", "BLUETOOTH"]`, and two `visible: root.section === …` blocks taking `host.network` / `host.bluetooth`. Claude C has uncommitted island edits (`IslandRest.qml`), so the island hover's "joining / wrong password / pairing" word waits for C. Claude A was told about the nested Hyprland mix-up (it wasn't mine).
- **Not done.** Devices room: a new network's verb "host dialog" → "password…" opening FART's Wi-Fi settings with the name filled in (needs B's `openSettings`); the island hover word; an island event for a prompt that arrives while FART is closed (`promptArrived`, `pairingArrived` exist). Nested-Hyprland captures after the pane hookup. Every new DMS call is unchecked against a real DMS (OPEN F2-7, NET_BT.md §7: phone hotspot, the phone over Bluetooth, the owner present). Rebuild the quiet copy with the owner present to drop DMS's own windows.
# 14 November 2026 · Opus (Claude A): S6 launcher, apps and ranking committed; the surface waits for the owner's look

- **Committed (`aba742a`, branch `s6-launcher`).** Apps list in the adapter (`AppsDomain`, `QuickshellApps`), ranking,
  frecency, the one-time import and the Session blocklist in the core (`core/matching.py`, `core/launcher.py`), apps
  started through Hyprland's exec (clean environment checked in nested Hyprland). Z185–Z189. Full suite 971 OK (whole
  tree, including the uncommitted surface); the commit's export: 91 OK in the affected modules.
- **Built, not committed (owner's look first).** The surface grown from the island: `view/shell/LauncherFace.qml`,
  `LauncherRow.qml`, `LauncherLayout.js`, `AppsIndex.qml`, `LauncherRoutes.qml`; edits in `IslandSurface/Expansion/
  Window.qml`, `shell.qml`, `shell-dms.qml`, `CoreClient.qml`; `tests/test_launcher_view.py` + `tools/launchertest/`
  (15 checks, real core); path C in `tools/launcher_keycheck.py`; `docs/S6_LAUNCHER.md` §2.1 and §8. Offscreen captures
  were shown to the owner (scratch files, not kept).
- **Measured (path C).** Keyboard 10 ms median (worst 13) with the view up, 13 ms (worst 19) on a first open; 0 letters
  lost or sent to the app in 120 trials. Path B in the same run: ~60 ms, 7 letters to the app in one trial. Found on
  the way: Hyprland 0.57 does not give the keyboard to a mapped layer that turns Exclusive; the island's focus grab
  now starts at once for the launcher. The island's `focus` IPC (Z148) has the same problem in nested Hyprland; ask
  the owner whether it works live.
- **Incident.** An earlier probe used `tools/nested_hypr.py start/stop` with the shared state file and stopped another
  agent's nested Hyprland twice (not D's; probably B's or C's). Use a private state file (as `launcher_keycheck.py`
  does); a per-agent default for `nested_hypr.py` was proposed to the owner.
- **Next.** The owner's look → commit the surface. Then the FART settings controls (Z189), verbs/calc/`>cmd`/`?term`
  inline, windows (Z77), Emoji, Clips (with C), Files. The binds (§6) need the owner's OK and a rollback each time.

# 14 November 2026 · Opus (Claude A): S6 started; the first open keeps every key

- **Design.** `docs/S6_LAUNCHER.md` (F4 draft): where keys go when the launcher opens, measured with `tools/launcher_keycheck.py` (nested Hyprland, fixture adapter, a focused app logging its keys, `wtype`). Today's path (bind → `zaetherion key` → core → view) takes 85–89 ms median with the view up, worst 128, and drops ~3 in 10 presses whose press and release arrive together. A Hyprland global shortcut handled in the view (option B) takes ~60 ms, worst 85, and never dropped one. Plan: B now, the launcher grown out of the island (C) to close the rest. Owner: keep DMS's spotlight on another key during the trial; Brave for `?term`.
- **Bug fixed (live).** The first open after the view starts lost every key: Hyprland moved the keyboard from the panel to the island named after it in the focus grab. Panel last in `HyprlandFocusGrab.windows` (`bb511d1`): 0 lost in 160 trials; the owner confirmed on the live desktop after a restart.
- **Shortcut.** `adapters/hyprland/HyprlandLauncherShortcut.qml` is the one file that may hold a `GlobalShortcut`, off unless `FART_LAUNCHER_SHORTCUT=1`; `KeybindsDomain.launcherPressed/Released` carry it to the view. The layout law says exactly that. Not bound on the live session.
- **Checks.** Full suite 954 OK on `2d04d4f`. Main checkout fast-forwarded; core restarted with the S4 settings.
- **Prompts written** for Claude B (wallpaper/presets, Z177+), C (clipboard from the island, calmer island rest, Z180+), D (Wi-Fi and Bluetooth in FART, Z190+). Launcher decisions: Z185+.
- **Next.** The launcher itself: apps domain in the adapter, frecency in the core (import `launch_stats.json`, Z136), matching in the core, the surface grown from the island.

# 14 November 2026 · Opus (Claude C): S3, quick paste from the island and a calmer rest (branch `s3-clips-rest`; not live)

- **Owner's answers** (from the captures, https://claude.ai/artifact/7cd8cEiZ4i5H6i3Z6YsaNs): yes to all; Enter copies (Shift+Enter pastes); rest B, but Wi-Fi and battery at the right edge in place of the bell, unread as a dot on the battery. OK to change Super+V and for FART to take over clipboard recording (both at go-live). Recorded as Z181–Z184, Z201 (Claude B holds Z177–Z180; both insert after Z176 in DECISIONS, expect a small merge conflict there).
- **Built.** `view/shell/IslandClips.qml` (held island face, DMS's keys, fixed height, held early Enter, thumbnails only for built rows); `IslandSurface`/`IslandExpansion`/`IslandWindow` wiring (the surface grows once to 272 px for it, shrinks after the fold); Super+V as Hyprland global shortcut `zaetherion:clips` registered only in the island's process, `qs ipc call island clips` as fallback; Ctrl+O sets `ViewState.clipQuery` and opens Clips. `IslandRest.restItems` with modes always/matters/hover (+ inbox unread/dot); core `island` topic gains `rest` (default the owner's B), `island rest <preset|item mode>`, op `island.rest`. Core `clips` topic (`core/clips.py`, op `clips.set`) with Enter-copies default, rows, images, entries kept, images recorded, and the recorders (Serpantinum profile `clip_recorders`, only with `FART_CLIP_RECORDER=1`). Adapter: `CliphistClipboard` paste and thumbnails, `HyprlandPaste` (Hyprland `send_shortcut`, DMS's terminal rule), `DmsAdapter.clipsWanted`.
- **Checks.** New `tests/fixtures/island/ClipsTest.qml` (15 checks; it caught a held Enter that never fired, fixed) and `tests/test_core_clips.py` (6). qmllint 0 syntax diagnostics; `make_qmldirs.py --check` clean; full suite in the commit message. Captures offscreen (`tools/clips_capture.py` with `tests/fixtures/clips/Harness.qml`, made-up clips); not yet seen in the nested Hyprland (Claude B's nested instance was up).
- **Next.** Settings tabs Clips and Island inside FART (after Claude B's tabs merge); the Clips room's look; `send_shortcut` and the global shortcut in the nested Hyprland; then go-live per `docs/S3_CLIPS_REST.md` §5 with the owner (merge OK first).

# 14 November 2026 · Opus (Claude A): S4 live; our notification server starts with the desktop

- **Live (owner present).** S5 (`s5-sfx`) merged into `s0-seed` (`39719a2`, 948 OK); main checkout fast-forwarded. Core started with `FART_VIEW_ENTRY=<repo>/shell-dms.qml`, `FART_RESIDENT_VIEW=1`, `FART_NOTIFICATION_SERVER=1`, `FART_RESIDENT_DIR=~/.local/state/zaetherion/dms-quiet`. Quiet copy matched the running DMS (`9483c24f0a364ed0`); `dms_quiet_check.py` 12/12. The owner watched the matrix pass: normal, low, critical (stays), an action (`ok` returned), a picture, a replace-id, expiry, DND on (normal held, critical through) and off; all listed in FART's Inbox. Wi-Fi, tray, media, audio, battery, logout card and lock work.
- **Found.** (1) `docs/S4_GO_LIVE.md` lacked `FART_VIEW_ENTRY`; without it the view is `shell.qml` and nobody holds the name. Fixed in the doc. (2) `zaetherion restart` raced: the new core exited with "another core is already running" while the old one was still sweeping; `start` once it had gone worked. (3) `DmsNotifications` was a deferred domain, so our server only started at FART's first open; until then notifications were lost.
- **Fix (branch `s4-eager-notif`).** `DmsAdapter` creates the notifications domain at start when `FART_NOTIFICATION_SERVER=1` (`serverAtStart`), else at `loadDeferred()` as before. Test: `test_notification_server.AtStartTests` through the whole adapter (`tools/dmstest/AdapterNotificationHarness.qml`), panel never opened; fails without the fix. Full suite: 949 OK.
- **At login (owner's go, branch `s4-session`).** `tools/session-start` sets the four settings when `tools/dms_quiet.py fits` passes (new: the copy records the installed `dms` program, since `dms version` names no UI revision and nothing is extracted before DMS runs); else DMS's own, logged. A `stock-notifications` file in the state folder opts out. The live copy was stamped by hand (`/usr/bin/dms` unchanged since 4 November; the copy's revision is the running session's). Dry-run of the script in a scratch folder with a stand-in `zaetherion`: fits, opt-out and changed-program each did the right thing. `test_dms_quiet` 9, layout, sessions and supervise-guard tests OK; full suite not rerun (tool and shell script only). Not yet seen at a real login.
- **Open.** The owner finds the island at rest too cluttered (power, Wi-Fi, battery, notifications icon). The owner wants a wallpaper selector and a preset selector inside FART (Z162); briefed to Claude B.

# 13 November 2026 · Sonnet: notifications leave the island sooner (branch `s5-notif-dismiss`, Z175)

- **Owner asked** to dismiss notifications by right-click or shorten the stay; both done.
- **Right-click.** `IslandSurface` has a right-button-only `MouseArea` (`objectName: "noticeRightClick"`) over the island while a notification or critical one is shown; it calls `dismissNotice()`: `queue.remove` plus `host.notifications.dismiss(id)` (the Inbox's own dismiss). Left-click is unchanged; the right button is consumed, no menu, nothing reaches the window below. Not for the FART-docked critical drop (`FartAlertDrop`), which has its own path.
- **Time.** `NotificationTiming` low/normal 5000 -> 3000; `IslandEvents.durations.notification` 3000. A sender's timeout is honoured, but `IslandEvents.notificationCap` (6000) caps a non-critical one on the island; the Inbox keeps the item. Critical with no timeout now stays until dismissed on the mirror path too (it used to take `durations.notification`).
- **Hover.** Separable, so no 10 s cap: `IslandExpansion` has a `HoverHandler` on the notification card (`noticeHovered`), `IslandSurface.noticeHovered` follows it, and `queue.hovered` is that while a notice is shown (island `pointerInside` otherwise). The pointer on the island's padding no longer pauses.
- **Tests.** New `tests/fixtures/island/DismissTest.qml` (right-click via the area's `clicked`, 3 s default, hover rule); `NoticeTest.qml` gained the cap, 3 s and critical checks; `test_notification_server.py` expects 3000. Z175 in DECISIONS, SURFACES row updated.
- **Not done / doubts.** A reply being typed does not pause the countdown with the pointer away (as before). The right-click is injected as a signal in tests, not a real pointer event. Not tried on the live session (never touched).

# 13 November 2026 · Opus: live switch to our notification server; the empty strip under the island

- **Live.** Main checkout on `s0-seed` (Astra's island docs committed as `842d054`, merged `d91937b`). Core started with `FART_VIEW_ENTRY=shell-dms.qml`, `FART_RESIDENT_VIEW=1`, `FART_NOTIFICATION_SERVER=1`, `FART_RESIDENT_DIR=~/.local/state/zaetherion/dms-quiet`; our view holds `org.freedesktop.Notifications`; DMS's volume/mic/brightness OSDs off (backup `~/.config/dms/settings.json.bak-2026-11-13-osd`). A test notification showed ~5 s (measured by screen grabs, pointer away).
- **`zaetherion restart` race.** The new core started while the old one was still stopping DMS ("another core is already running"): no core for ~30 s until a plain `start`. A fix (wait for core.lock, 12 s bound) is committed on `s5-restart-race` (`4832e4b`), not yet verified or merged. Until then: `stop`, wait, `start`.
- **Empty strip.** The screen reserved 70 px: our island's 36 plus 34 from DMS's hidden island-style Main Bar, which DMS reserves even when `visible` is false. `tools/dms_quiet.py` now patches that expression too (Z171); rebuilt live, `dms restart`: reserved 36.
- **Owner asked, not started:** right-click to dismiss a notification and a much shorter showing time.
# 13 November 2026 · Opus: S5, the OSD shows in FART's header while FART is open (Z174, branch `s5-osd-header`)

- **Owner's decision (Z174, bends Z161 for the OSD only).** With FART grown from the island, a volume, mic or brightness change shows at once in FART's header instead of waiting, time banked, for the fold (the stale level noted in S5 step 1). Every other ordinary event keeps Z161; critical events keep `FartAlertDrop`. FART closed: unchanged.
- **Readout.** `view/shell/FartHeaderOsd.qml`, drawn by the Overlay beside `FartAlertDrop`: the island's OSD face on one line (glyph, kind, 16 blades, percent or MUTED) on a small island silhouette exactly the header row's height (32 px), centred over the command line so it never hides a button (`Shell.headerTop/headerHeight/headerSlotX/headerSlotWidth`). It drops in from FART's top edge (`Cue` "fart.osd", navigate in, feedback out), updates in place, no flash, no card. Type and sizes are Design tokens only (`Design.readout`, `caption`, `baseline`).
- **Queue.** `IslandEvents` gets `covered` (the island's `docked`): covered, an OSD change is handed out (`coveredOsd`) instead of `queue.offer`. `IslandSurface.headerOsd` holds it with its own 1.2 s timer, restarted on each change; `IslandWindow` and the three `shell*.qml` pass it to the Overlay as `islandOsd`. The readout follows the cover with its time: an OSD already on the island goes up into the header when FART docks, and one still in the header goes back to the island for what is left of its 1.2 s when FART folds.
- **Checks.** `tests/fixtures/island/HeaderOsdTest.qml` (11 checks, `test_island.test_osd_shows_in_fart_header_while_covered`): in the header at once and not in the queue, repeat updates in place, sits on the header row and no taller, MUTED, dwell follows the last change, gone after 1.2 s, the fold replays nothing stale, uncovered on the island as before, dock lifts it, fold hands it back. Targeted modules (island, architecture, layout, contract, cues): 36 OK. qmllint (Qt 6, JSON): 0 syntax diagnostics on the 10 changed QML files; `make_qmldirs.py --check` clean. Full suite: 912 of 913; the one failure, `test_notification_server` `test_sound_is_left_to_a_sender_that_plays_its_own_and_to_do_not_disturb` (`['dnd.on', 'notify.critical'] != ['notify.critical']`), fails the same way on an untouched export of the base `526319d` (its new `dnd.on` cue), so it is not this branch's; left for the sound-set work.
- **Captures.** Offscreen through `tools/shots.py` with the readout laid over the Shell as the Overlay lays it (a scratch wrapper, not checked in): volume 62 %, muted, brightness 80 %, Mocha. Not yet seen in the nested Hyprland or live.
- **For the owner.** (1) The readout covers the middle of the command line for 1.2 s; if you are typing there, your text is hidden under it meanwhile. (2) Fluid form not captured.
# 13 November 2026 · Opus: S5 step 3, our own equaliser (branch `s5-eq`, owner away; not live)

- **Owner's call.** Keep the 10 bands and mono; drop balance, channel swap, "dynamic EQ", dynamics, reset audio and open host. Presets: Flat, Bass, Treble, Vocal, Loudness (our values). How it exists: Z173.
- **Built.** `core/eq_chain.py` (bands, presets, RBJ response and headroom, the `pw-cli` params, the filter-chain config text), `core/equalizer.py` (settings in `eq.json`, topic `equalizer`, ops `eq.enable/band/preset/mono`, the chain's process: start, live set-param, restart after PipeWire goes, give up after four stops in 60 s, dies with the core), verb `eq` (`core/verbs/equalizer.py`). fartd attaches the chain only when it supervises DMS and is not a fixture host. Contract `EqualizerDomain` trimmed to enabled, active, error, bands, preset(s), mono and four setters; `adapters/common/CoreEqualizer.qml` is the DMS session's (`DmsAdapter.loadDeferred`), the fixture and the legacy Serpantinum adapter follow; `QuickshellAudio` hides our two nodes from devices and streams. No room shows the equaliser yet (none did before); the Settings Audio/EQ tab (Z93) needs the owner's look.
- **Checks.** `tests/test_equalizer.py` (23). Architecture, layout, contract and equalizer: 48 OK; DMS adapter, shell, client, verbs, command, daemon, supervise guard: 68 OK. qmllint (Qt 6): 0 syntax diagnostics on the seven edited QML files. `make_qmldirs.py --check` clean. `tools/eq_check.py` on a private PipeWire (null sinks, no session manager; the owner's PipeWire untouched, same pid before and after): 24/24, covering the nodes, smart filter, gains and mono via pw-dump, a PipeWire restart, a killed core and off. Full suite: 934 run, 1 failure, `test_notification_server` ("sound is left to a sender…"): it now also hears the `dnd.on` cue added in `526319d`; it fails the same on the base commit alone, so it is not this branch's; the test needs updating to the new cue.
- **Not checked, needs the owner present.** WirePlumber placing the smart filter in front of the real default sink, and how it sounds: `zaetherion eq on`, play something, `eq bass`, `eq mono`, switch the output device in Devices, `eq off`, and check the sound is unchanged afterwards. The headroom makes boosted presets quieter (Bass by 7.1 dB); say if you'd rather have no automatic headroom.
- **Next.** The owner's live try; then the EQ's look in Settings (Audio/EQ tab).

# 13 November 2026 · Opus: S5 step 2, caps and num lock; the DMS link keeps early feeds (owner away)

- **Caps and num lock.** `adapters/dms/DmsKeybinds.qml`: `HyprlandKeybinds` plus DMS's `evdev` service (`{available, capsLock, numLock}`), held while the domain exists; null until the first snapshot. The island's hover view already shows caps lock when it is on (`IslandRest.hoverStatus`). Live probe: caps true (it was on), num false, 94 binds read.
- **DMS link fix.** `DmsLink` reset its machine in `Component.onCompleted`, dropping feeds that completed before it (seen when a feed sat beside its link). It now keeps them. Live probe: a sibling `evdev` feed subscribes and gets data.
- **Airplane mode** has no DMS source (no rfkill field in `network`); still null in this session.
- **Checks.** Full suite: 904 of 911; the 7 failures were `test_dms_adapter` asserting `network` is the only un-leased subscription and `HyprlandKeybinds` in the composition. §3 of DMS_ADAPTER.md now names `evdev` (and the OSD's `brightness`) as un-leased, the tests follow, and `test_dms_adapter` passes alone (20). Full suite on `fe88271`: 911 OK.
- **EQ (Z50), not started: questions for the owner first.** Our own PipeWire filter-chain (10 biquads) replaces the host script, so: (1) keep balance, mono, channel swap, "dynamic EQ" and the night/balanced dynamics the contract inherited, or only the 10 bands and presets? (2) Which presets? (3) The chain becomes the default output while on; it is a PipeWire config drop-in, so it changes the owner's audio routing and needs them present to try. Plan once answered: a generator for the drop-in, gains changed live with `pw-cli set-param`, state in the core, and a check on a private PipeWire with a null sink so the live audio is never touched.

# 13 November 2026 · Opus: S5 step 1, OSD levels for the island (branch `s5-osd`, owner away)

- **Built (Z172).** `adapters/quickshell/OsdChange.js` (which change is an event), `QuickshellOsd.qml` (volume, mic from Pipewire), `adapters/dms/DmsOsd.qml` (adds brightness from DMS), `DmsBrightnessMap.js`. `DmsAdapter.osdWanted` (bound to `ZAETHERION_ISLAND` in `shell-dms.qml`) creates it at start; `QuickshellAudio.setVolume/setMuted` hush it for 2 s. The island's OSD face and queue entry were already there.
- **DMS link (S9a).** DMS sends brightness changes as `brightness.update` (`{device}`), which the link dropped as "unsubscribed". `<service>.update` now belongs to its service: cached, passed on and dropped with it; `DmsFeed.update` exposes it.
- **Checks.** `test_osd_change.py` (7), `test_dms_brightness_map.py` (6), a new S9a machine test. Full suite: 910 of 911; the one failure was `test_shell_dms` (its copy of the adapter block lacked `osdWanted`), fixed and rerun alone. Live probes against the real Pipewire and DMS (owner away; each change undone): a volume step, mute and unmute gave exactly one event each and none at start (volume back at 0.28); `dms ipc call brightness decrement/increment 5` gave 0.95 then 1 (back at 100 %). `brightnessctl` changes are not reported by DMS at all.
- **Found.** A `DmsFeed` declared in the same file as its `DmsLink` registers before the link's `Component.onCompleted` resets its machine, so it never subscribes. Real adapters create domains after the link, so nothing live is affected; worth fixing in `DmsLink` (keep `feeds` across the reset).
- **For the owner.** (1) While FART is open, an OSD waits with its time banked (Z161's rule for ordinary events) and shows after FART folds, a stale level. Drop OSDs that couldn't show instead? (2) Turning ours on means turning DMS's own OSD settings off (Z172); not done.
- **Next in S5.** Media keys (already DMS's `dms ipc`), the hover-only states (caps/num lock, airplane, power profile, Z24), the EQ filter-chain. Not started.

# 13 November 2026 · Opus: quiet DMS, so our notification server can hold the name (owner away; not live)

- **Problem.** DMS has no switch for its notification server, and Quickshell won't take the name from a running owner (Z169), so ours could never go live beside DMS.
- **Quiet DMS (Z171).** `tools/dms_quiet.py build` copies the UI the running DMS uses and removes its one `NotificationServer` object; everything else in DMS is unchanged. It refuses a DMS it doesn't recognise, never builds from a quiet copy, never writes over a folder it didn't make. Output: `~/.local/state/zaetherion/dms-quiet` (not checked in). The supervisor already passes `FART_RESIDENT_DIR` to DMS as `DMS_SHELL_DIR`.
- **Checks.** `tests/test_dms_quiet.py` (4). `tools/dms_quiet_check.py` in the nested Hyprland on a private bus: 12/12 (stock DMS takes the name as a control; quiet DMS comes up, stays up 8 s, leaves the name free, no NotificationService errors in its log; a Quickshell server then takes the name and receives a notify-send; the session's own server untouched). Full suite: 897 OK.
- **Not done.** Nothing on the live session changed. `docs/S4_GO_LIVE.md` has the steps for when the owner is present: main checkout to `s0-seed` (Astra's uncommitted docs there first), build the copy, restart the core with three settings, the `notify-send` matrix, and how to go back.

# 13 November 2026 · Opus: S4 merged into s0-seed; test tools can no longer stop the owner's DMS

- **Merged.** `s4-notifications` (renumbered to Z166–Z170, then brought up to date with the palette work) fast-forwarded into `s0-seed` at `373cc63`. Full suite on it: 889 OK. Not pushed.
- **What stopped DMS at 09:13.** A `tools/smoke.py` run from the main checkout by the other agent there: its session log shows the run starting at 09:13:16, DMS logged "received terminated" at 09:13:24, and `e6c86ea` followed at 09:14:54. Its shell had inherited the live core's `FART_SUPERVISE=dms`; `smoke.py` built its env from `os.environ`, so the private test core supervised the real DMS and stopped it on exit.
- **Guard (branch `s4-dms-guard`).** (1) `smoke.inherited_env()` drops every inherited `FART_*`; `prepare()` uses it, so every tool built on it (keytest, faces, shots, demo_frames, dms_smoke, overdrive) is covered, and `measure/cold_breakdown.py` strips them inline. (2) `fartd.supervise_allowed`: a fixture-host core ignores `FART_SUPERVISE=dms` (logged) unless `FART_SUPERVISE_FIXTURE=1`; `supervisor_check.py` opts in. (3) `fartd.view_env`: the view, and so apps launched from the shell, no longer inherit `FART_SUPERVISE`.
- **Checks.** `tests/test_supervise_guard.py` (4 tests, one end to end with a fake `dms` that must not start); it fails with the guard turned off. Full suite: 893 OK.
- **Next.** Going live with our notification server, with the owner present.

# 13 November 2026 · Fable: s8-palette merged into s0-seed, with three rule fixes

- **Merged.** `s8-palette` (Astra: palette picker inside FART, shared palette state, AMOLED studies; Z162–Z165) into `s0-seed` with the owner's OK. Not pushed.
- **Review.** Astra's own tests passed. Three project laws failed on the branch and are fixed in the commit after the merge, not on Astra's branch: `core/palette_catalog.py` named a host (`catalogue()`'s parameters are now `presets`, `themes`, `generated`); `PreferencesPane.qml` animated with a raw `Behavior` (now a `Tween` gated by the panel); `view/shell/qmldir` and `view/ui/qmldir` were not in the generator's order.
- **Checks.** Palette, architecture, layout, contract, command, verbs, island, daemon and cue tests: 88 OK; `make_qmldirs.py --check` clean. The pane's grow animation was not looked at after the `Tween` change. The full suite has not been run on the merged tree.
- **Numbers.** S4 (branch `s4-notifications`) also used Z163–Z167; it renumbers to Z166–Z170 when it is brought up to date with this branch.

# 13 November 2026 · Fable: S4 steps 3 and 4, the island and FART's Inbox (owner OK'd the captures)

- **Island.** `IslandEvents`: the showing time comes from the item (`timeout`: 0 stays until dismissed, absent means our 5 s), a replace-id (same id, new `time`) refreshes the card, an item that leaves the Inbox leaves the island, and only a `live` item offers actions or reply. `IslandExpansion.pictureShown` → `keepImage`. Both shells send the island's and FART's alert-card actions to `notifications.invoke`. No drawing changed: the card already had actions, reply and a picture slot.
- **Inbox.** `view/rooms/InboxAnswer.qml`: a button per action and a reply field for a live item; "Actions in host center" only for mirrored items. The room shows the item's picture (40 px) and hides the host-centre links unless the source is the mirror.
- **Fixture.** `shell-island-fixture.qml` gained `pictureNotification <ms>` and `closeNotifications`; its state counts only real actions.
- **Checks.** `tests/fixtures/island/NoticeTest.qml` (8 checks), `tools/cuetest/InboxAnswerTest.qml` (5 checks); related suites 132 OK. Nested Hyprland: 5 island captures, 0 QML errors. The Inbox frame shown to the owner was offscreen (the nested capture caught FART on Home).
- **Live session, 13 November.** DMS stopped cleanly at 09:13:24 (supervisor: `stopped`, code 0, then `held`) while my notification tests and a full suite run were going. I did not find what sent the stop; nothing in the S4 tests names DMS. `zaetherion start` brings it back. Worth finding before the next long test run.
- **Next.** Going live with the owner: resident view on, `FART_NOTIFICATION_SERVER=1`, DMS's own notification server out of the way. Open: how DMS's server is kept off while DMS runs (it has no switch).

# 13 November 2026 · Fable: S4 step 5, sound; pictures kept; the adapter side of answering

- **Sound (Z170).** `Inbox.ingest` decides what is heard (`on_sound`): not low urgency, not a replace-id, not a sender with `suppress-sound`, and under do-not-disturb only critical. The core emits cue `notify.normal` or `notify.critical` (new kind `notice` in `core/sfx.py`, switched per cue like UI cues; mapped to freedesktop sounds in `adapters/serpantinum/core.py` `NOTICES`).
- **Pictures.** Contract call `keepImage(id, picture)`: a card that draws a notification's picture offers it; `DmsNotifications` saves raw-pixel pictures with `grabToImage` to the path `notif.ingest` returned, then `notif.image`. The contract's `image` is now a URL (`file://…` or the live `image://qsimage/…`). Ids must match `[A-Za-z0-9_-]{1,64}`: they are also the picture's file name (no hashlib: it cost the core 4 MiB and broke its memory budget).
- **Layout law.** `tests/test_layout.py`: only `adapters/quickshell/QuickshellNotificationServer.qml` may hold a `NotificationServer`, it must be off by default, and only `DmsNotifications.qml` may use it, behind `FART_NOTIFICATION_SERVER=1`.
- **Checks.** Matrix now 14 tests (sound for the three urgencies, `suppress-sound` and do-not-disturb, raw pixels kept across a view restart and deleted on dismiss, a private app's pixels never written). Core notification tests 31, sfx tests updated.
- **Waiting for the owner's look.** Steps 3 (island) and 4 (FART's Inbox) are built and tested in the working tree but not committed: captures first.

# 13 November 2026 · Fable: S4 step 2, our notification server; the notify-send matrix passes offscreen

- **Built.** `adapters/quickshell/QuickshellNotificationServer.qml` (Quickshell's server, the live notifications, a flood guard), `QuickshellNotification.qml` (one live notification: its Inbox fields, actions, reply, dismiss, the transient timer) and `NotificationTiming.qml` (default showing times). `adapters/dms/DmsNotifications.qml` joins the server to the core: `notif.serve` on connect, `notif.ingest` on arrival and on replace-id, `notif.closed` on close. The contract gained `source` and `invoke(id, action, reply)`; do-not-disturb is real (`notif.dnd`).
- **Off by default.** The server runs only with `FART_NOTIFICATION_SERVER=1` (Z169). The live session is unchanged and DMS still owns the name.
- **Taking the name.** Quickshell waits behind a running owner and takes the name when it leaves. The core compares the name holder's pid with the view's (`Inbox.holder_pid`), so the mirror keeps working until our server really holds the name, then stands aside.
- **The matrix.** `tests/test_notification_server.py` (11 tests, about 6 s): a private dbus-daemon, a private core, the harness as that core's resident view (`tools/notiftest.py`, `tools/dmstest/NotificationHarness.qml`), senders `notify-send` and `gdbus`. Covered: three urgencies and their showing times, the sender's expiry time, transient leaving, two actions answered back to `notify-send`, inline reply (`NotificationReplied` seen on the bus), images as a file, an icon name and raw pixels, replace-id, close from either side, do-not-disturb, items outliving the view and the core, and waiting behind another server then taking over.
- **Found.** The core accepts only the view it spawned, so the tests run the harness as the resident view. Quickshell uses the reply action's label as the reply placeholder. A replace-id changes the live notification's properties in place.
- **Not yet.** Raw-pixel pictures are shown from the view while live but not yet saved to disk (step 3, when a card draws them). The island and FART's Inbox do not use actions, reply, images or the showing time yet. No sound yet.
- **Checks.** Notification, bus, adapter, contract, architecture and island tests: 97 OK. qmllint: no syntax diagnostics on the new files. Full suite on that commit (`41f56bf`): 865 of 866; the one failure was the inherited layout law "no QML claims the notification server", replaced in the next commit by a law that allows exactly our one gated file.
- **Next.** Step 3, the island: showing time from the item, actions, reply, picture. Captures to the owner before that commit.
# 14 November 2026 · FLUID Phase 2: Confluence Home checkpoint

- **Built.** Home now uses persistent `HomeSession` with separate `AngularHome` and `FluidHome` presentations through the existing host. Sky requests, position lease, edition/fold snapshot, calendar month, Angular week and selected day survive style replacement. Delayed sky replies after folding/disconnection are ignored. Confluence Home has calendar, task completion, focus timer, media transport, inbox/workspace, profile and existing upkeep/desk actions. Added reusable `FluidCalendar` and `FluidActionRow`; no backend or settings authority was duplicated.
- **Integration fixes.** The shell surveyor follows the actual presentation, so swapping a retained room does not leave references to destroyed controls. Renamed the existing orbit idle-loop id to avoid collision with `Starfield.twinkle`, eliminating its undefined phase binding. The fixture driver focuses only nested `ZTEST` before launching: floating regressions on the hidden nested output previously had unpolished layouts, including the original baseline.
- **Verified.** 36 focused layout/day-fold/survey unit tests; 30 nested Home checks including 40 switches, calendar/fold/state retention, focus, unchanged leases/sky requests, palette preview/cancel, offline state, late replies and native viewport bounds. Existing nested Media (32), Home sky (5), Home fold (6) and surveyor (8) checks pass. Ten offscreen smoke rooms pass; zero Qt 6 `syntax*` diagnostics. Nested configerrors empty and clients released; owned nested compositor stopped. Fixtures do not actuate the host.
- **Captures / scope.** `docs/captures/fluid-home/` contains native 1360×860 panel captures on 1920×1080 nested output: Silent/Overdrive, AMOLED/Ice preview, calendar navigation and Angular baseline. Home fits its 1034×647 viewport. Angular panel comparison has zero pixels differing by more than 16/255; exact identity is not claimed. The surrounding shell framing still uses Angular geometry/effects. No sustained 144 Hz claim.
- **Repository / review.** Isolated sibling worktree `zaetherion-shell-fluid`, branch `codex/fluid-foundation`, base checkpoint `589a058`. Home changes and evidence form the next committed checkpoint under the owner's existing commit approval; the repository adds no separate UI approval gate. The prior Media/Settings checkpoint remains committed. No merge, push, live configuration, protected path edits or issue closures; other worktrees were not modified.
- **Exact next task.** Implement Confluence Performance through the same presentation host with a minimal persistent controller; then address shared shell framing. Reproduce Home with `python tools/fluid_fixture.py --fixture tests/fixtures/fluid/HomeSwitch.qml` (start nested Hyprland first); add `--capture docs/captures/fluid-home`, optionally `--baseline`, for captures. Remaining rooms, wider palette coverage and performance measurements remain outstanding.

# 13 November 2026 · FLUID Phase 2 recovered; Media and Settings checkpoint approved

- **Recovery / scope.** The interrupted `/tmp` worktree was gone; recovered its exact edits from the previous session's tool history onto `codex/fluid-foundation` at `e6c86ea`, in the durable sibling worktree `zaetherion-shell-fluid`. Main checkout diagnosis work is untouched. No merge, push, live configuration changes or host actions.
- **Built.** Persistent `MediaSession`, separate `AngularMedia` / `FluidMedia`, asynchronous `PresentationHost` with stale-request protection and matching-control focus transfer. Settings' Design Style selector sits beside Palette and uses the existing `island angular|fluid` command and `island.form` → `Design.form` authority. Added latest-intent queuing for delayed replies, stale reply/disconnect protection, and a bounded reusable `FluidChoice` for player lists. The recovered Media overflow correction is retained.
- **Verified.** 59 focused core/island/palette/layout/architecture/view tests; ten offscreen smoke rooms; zero Qt 6 `syntax*` diagnostics. Nested Angular Media effects regression passes, ending at `CUE_ACTIVE 0 []`. All 32 nested Media checks pass, covering 40 alternating switches, unchanged controller and leases, palette preview and cancellation, action capability guards, focus (transport and player choice), rapid requests, delayed/rejected replies, disconnect, 12-player catalogue and component bounds. Native Shell capture verifies the same Media controller and active room survive its Settings selector, preview opens and closing cancels it. Native Media area is 1034×647 inside a 1360×860 panel; captures are 1920×1080. Nested `hyprctl configerrors` is empty; fixture logs have no QML errors. The owned nested compositor is stopped after verification. No 144 Hz or performance-budget claim.
- **Evidence / commands.** `docs/captures/fluid-phase2/`, including `integrated/` for the real Shell. Run `python tools/nested_hypr.py start`, then `python tools/fluid_fixture.py`; `--capture <directory>` records standalone captures, add `--integrated` for native Shell/Settings. `--baseline` restores only Media from e6c86ea for Angular comparison. `--fixture tools/cuetest/MediaTest.qml` runs Angular effects in the nested compositor. Angular comparison has 344 pixels differing by >16/255, all within the centred seek hint; no broad geometry change was observed. Exact pixel identity is not claimed.
- **Approval / remaining.** The owner approved the captures and checkpoint commit on 13 November 2026. The selector is the central, persisted control-centre style setting; the implemented Fluid presentations remain incremental. This is the Media/Settings foundation, not a complete Fluid shell: Home, Performance, shared shell framing and further rooms still use Angular presentation. Installed palette coverage beyond Amoled Black / Ice preview and sustained 144 Hz performance remain unverified. No GitHub issue acceptance closure is claimed.
- **Exact next task.** Extract Home's small persistent state (edition/front-page choice and shared data ownership), retain its Angular view, and add the approved Confluence Home presentation through `PresentationHost`.

# 13 November 2026 · Astra: S8 palette picker complete on `s8-palette`

- **Built.** One stored palette and published topic; `zaetherion palette <name>` / `palette list`; settings section inside FART with hover/arrow preview, click/Enter save, and rollback on close, fold or disconnect. Installed palette readers live in the read-only common adapter. Missing/invalid sources are silently omitted; Amoled Black remains the default. Z162–Z165 record the choices.
- **Checked.** 15 palette tests cover storage, topic, CLI process, missing entries, preview ownership/cancel, keyboard selection and Design colour changes. The 69 related core/view/island/layout/architecture checks pass after enabling `QT_LOGGING_RULES=qml.debug=true` for the architecture harness (its markers were otherwise suppressed). Ten offscreen smoke rooms pass with that logging enabled; no binding/type/reference errors. Qt 6 qmllint: zero `syntax*` diagnostics. Nested captures were shown before the UI commits; the owned nested session is no longer running.
- **Look/evidence.** Ten original true-black studies and five installed-palette readability checks are in `docs/captures/s8-palette/`; normal/muted/accent text meets 4.5:1 on those five. `tools/palette_capture.py` reproduces the comparison in nested Hyprland using inert fixtures. The local install supplied 94 static presets plus Matugen's existing generated colours; its empty Nightfox file was omitted without error. No host files copied or changed, live controls actuated, installs, push or merge.
- **Left / next.** The owner chooses which AMOLED studies to retain; none was chosen as a new default. Opus reviews and merges `s8-palette`. Catalogue changes are picked up on core restart; DMS themes currently use their declared dark default flavour/accent. Existing unrelated island-diagnosis files remain uncommitted.

# 12 November 2026 · Fable: S4 step 1, the Inbox in the core

- **Plan agreed with the owner.** S4 in six steps: core store, server in the adapter, island, Inbox room, sound, the `notify-send` matrix. Decisions Z166–Z168. Work is on branch `s4-notifications` (worktree `zaetherion-shell-s4`, cut from `s0-seed` `e868b7d`).
- **Built (step 1).** `core/notifications.py` is now the `Inbox`, the one list. The busctl `Mirror` and `BusctlSource` moved to `core/notification_mirror.py` and feed it; the mirror ignores calls while our server is attached. New operations: `notif.serve {ids}`, `notif.ingest {id, appName, summary, body, urgency, actions, reply, icon, image, timeout, transient}` (returns `imagePath`, empty when the item is never written), `notif.image {id}`, `notif.closed {id}`, `notif.dnd {on}`. Items gained `actions` [{id, label}], `reply`, `icon`, `image`, `timeout` (ms, -1 = ours), `live`, and urgency `low`. The snapshot gained `source` ("server" or "mirror") and `dnd`.
- **Rules.** The view forms ids that are unique across its restarts; the core treats them as opaque. Only the serving client may ingest, close or attach an image. When that client disconnects, items stay but stop being live, and transient ones go.
- **Checks.** `tests/test_core_notifications.py` 28 tests (11 mirror, 17 server) and `tests/test_core_busctl.py` pass. The full suite on that commit (`c80db40`): 853 of 854; the one failure was the core's memory budget (29.4 MiB, limit 25), fixed in step 2 by not importing hashlib.
- **Live session.** Untouched. DMS still owns the notification name, and it has no switch to give it up; going live is a later step with the owner present.
- **Next.** Step 2: `adapters/dms/NotificationServer.qml` on a private bus (check how Quickshell treats replace-id and whether it can take the name from a running owner), then the island, the Inbox room, sound and the matrix.

# 12 November 2026 · Astra: current-code plateau rechecked; CAVA-inclusive CPU still over budget

- **Scope/source.** Measured detached `eb09501`, excluding concurrent shared edits. The allocator default and 20 Hz settings were already applied in `946feb7`. `DmsAdapter` uses `QuickshellMedia`, which launches `tools/cava.conf`; the resident view uses `spawn_quickshell`'s child-only allocator default.
- **Results.** After 100 Home open/fold cycles: **328.1 MiB RSS / 127.5 PSS / 101.4 Private_Dirty**, including 225.7 MiB shared mappings. Three 30-second windows at 20 Hz with private synthetic PCM: **view 4.90%, CAVA 1.47%, combined 6.36%** of one core (combined range 6.09–6.83%). The 30 Hz control averaged 9.45% combined. Existing 24-bin fixture: 4.72%; rest: 0.02%. The **5% live media budget is not passed**; real audio capture and full DMS remain unmeasured.
- **Artifacts.** Updated [diagnosis](docs/ISLAND_DIAGNOSIS.md); [samples/method](docs/measurements/island-eb09501.json), [already-applied measured runtime diff](docs/measurements/island-eb09501-runtime-already-applied.patch), [proposed empty-owner-value regression test](docs/measurements/island-eb09501-proposed.patch), and [experimental CAVA fixture diff](docs/measurements/island-eb09501-experiment.patch). No new runtime patch is needed to obtain these results.
- **Checks/cleanup.** 28 core-view, five offscreen island and three DMS-entry tests passed; ten offscreen rooms passed; zero Qt 6 `syntax*` diagnostics; nested configerrors empty. Known private-home/font/portal/text-input warnings only. Owned views, CAVA, PCM feeders, private bus/services and nested compositor stopped; detached worktree removed. Shared runtime files untouched; no installs, live playback/audio/config/power changes, staging, commits or pushes.
- **Next.** Profile the remaining view-update/render cost with the saved synthetic CAVA fixture; recheck newer shared edits separately. Do not infer a live-session pass from the simulated fixture.

# 12 November 2026 · Opus: Z161, DMS's frontend logic with our look; only critical interrupts a panel

- **Owner's answers.** The owner decides the look only; Opus makes the behaviour and structure calls and records them. Only critical events interrupt an open panel.
- **Decision.** Z161 (DECISIONS.md): S4–S8 start from DMS 2.1.0's QML (MIT), redrawn in our design. The island keeps our queue (Z23); DMS's `IslandController` keeps one face plus one return slot and would drop waiting events. To take from it later: load-before-open panels dropped when idle (S6), the media blip delay, hover held after a face swap.
- **Built.** `IslandQueue.ceiling`: entries below it wait, their dwell banked. While docked (FART grown from the island) the island sits under FART, so before this an event shown there spent its time unseen: now ordinary events wait, and a critical one is handed to FART (`IslandSurface.coveredEvent`, through `IslandWindow` to `Overlay.islandAlert`), where `FartAlertDrop` flashes the header red once and drops the card from under it. At rest a critical event flashes the island red once (a second `IslandFrame` in `Design.danger`; `IslandFrame.fill` is new). Motion off: a 600 ms red hold, no fade. Tray menu and session card moved from -1 to `priority.held` (5), so a critical event now interrupts them (the tray menu closes as Z157 says; the session card returns after).
- **Licence.** DMS's relicensing note's two adapted files are `Common/suncalc.js` (BSD-2, V. Agafonkin) and `DCommon/Common/fzf.js` (BSD-3, fzf-for-js). DMS's MIT text is already in `licenses/DUX-SHELL-MIT` (since `03a54d4`, for `IslandTrayMenu.qml`); checked byte-identical to upstream `duxlabs-dev/dux-shell` `LICENSE` on 12 November 2026 (sha256 `4cee9628…26bfa`; the old AvengeMedia/DankMaterialShell address redirects there). Upstream is now v2.2-beta; the unpacked QML here is v2.1.0. Each new copy adds its file and source commit to NOTICE's Dux Shell section. If `suncalc.js` or `fzf.js` is copied, add their BSD notices to `licenses/` too.
- **Checks.** Full suite 837 OK with `FART_*` unset; island tests gained 4 queue checks (critical interrupts a held face, a panel holds an ordinary event with its time banked, critical shows over a panel, the event resumes with its time after). qmllint 0 syntax diagnostics. Nested Hyprland (`shell-island-fixture.qml`, ZTEST, no D-Bus/Pipewire), 13 captures shown to the owner, 0 QML errors: ordinary waits behind the tray menu, critical interrupts and closes it, ordinary shows after; critical over the session card, card returns; nothing shows over a grown FART (shots identical), the waiting notice shows after the fold, then rest. No power action ran.
- **Nested (critical look).** Second run, 0 QML errors, 4/4: the island flashes red then shows the critical card; FART open: the ordinary notice is not handed over, the critical one is, the header flashes red, the card drops from under it, expires after 5 s, the ordinary notice shows on the island after the fold.
- **Maintenance.** The flash is one component (`CriticalFlash`) used by the island and FART; FART's drop reads `Shell.headerBottom`, the same edge the empty-header fold uses. `SurfaceTest` covers the handover (critical handed to FART, ordinary held, events resume in order after the fold).
- **Known flake.** `test_astra_cues` `temporal.done.finite` fails about 1 run in 3–6, on the previous HEAD too (1/6), so it is not from this change. Full suite: 836 OK plus that flake.
- **Next.** S4 notifications from DMS's notification QML, recording each copied file and its upstream commit in NOTICE.

# 12 November 2026 · Opus: the view follows DMS's socket through the core (S2 merged)

- **Merged.** `s2-host-adapter` into `s0-seed` (`f2d9969`) with the owner's OK; 837 tests OK on the merged tree.
- **DMS's socket.** The core always offers the `supervisor` topic (`{"children": {}}` when it does not supervise DMS), and `CoreClient` subscribes to it (`supervisorData`). `shell-dms.qml` binds `DmsAdapter.socketPath` to `children.dms.socket` while a core is connected, else to `DMS_SOCKET`. A subscription naming an unknown topic fails whole, hence the always-offered topic.
- **Checks.** Full suite 837 OK. Nested Hyprland, real core with `FART_RESIDENT_VIEW=1` and `FART_VIEW_ENTRY=shell-dms.qml`, supervising a real DMS (private home, bus and folders, no system bus): 11/11. The view connects to DMS's socket; DMS killed → back under a new socket → the same view process reconnects; the bar stays hidden through it (the new DMS reads the saved setting); core stop shows the bar, nothing left running.
- **Turning it on (owner's go, owner present).** `tools/zaetherion.py` `start_core` sets `FART_RESIDENT_VIEW=1` and `FART_VIEW_ENTRY=<repo>/shell-dms.qml`; then `zaetherion restart` or a fresh login, and the real checks listed in the S2 entry. Rollback: unset both.

# 12 November 2026 · Opus (S2, taking over from Sonnet): step 6, `shell-dms.qml`; review

- **Built (Sonnet).** `shell-dms.qml` is `shell.qml` with `DmsAdapter { id: adapter; core: client; role: "shell" }`; `tests/test_shell_dms.py` fails when the two drift apart. Nothing starts it yet. Committed by Opus after the full suite (824 OK, with this file present).
- **Nested check (Opus).** Against the DMS stand-in, no core, no D-Bus or Pipewire: the island at rest on `ZTEST`, a click grows FART, an empty header click folds it, the process stays up, the stand-in sees one subscription (`network`), no QML errors and no `serpantinum` call. Sonnet's blank capture was the setup, not the adapter: without a core or `ZAETHERION_ISLAND_OUTPUT=ZTEST` the island goes to the focused output, which is the hidden nested window, not `ZTEST`. A click sent 50 ms after the pointer arrives is dropped while the island grows (the known first-click limit); after 0.9 s of hover it opens. The Pipewire connection error in that log is the test cutting Pipewire off.
- **Review (Opus).** Link machine: the event connection is reopened only from `closed`, so a close and the stale `eventsDown` it posts cannot hit a new connection; every request replies once (`reply` deletes the callback first). Leases: `spectrum`, `position`, `mixer` and `menus` run only while held; network state is un-leased (`wanted: true`) as the island shows it at rest; `details` and `scan` follow their leases. Contract: `test_contract` checks `DmsAdapter` like Serpantinum. Session actions match Z158.
- **Not built.** Step 5: bluetooth, `power.brightness`, `power.nightLight`, idle inhibit (`DmsPower`'s setters are empty). Weather, osd, capture, palette (the built-in Amoled Black applies), motion, sfx, clockGeometry, hostActions, the equalizer. Do-not-disturb (`setDnd` only logs).
- **For the switch-over (Opus).** The core does not hand the view DMS's socket. `DMS_SOCKET` is unset for a view spawned by `fartd`, so network would read offline. The resident view outlives DMS restarts, so it must follow `supervisor.children.dms.socket` (SUPERVISOR.md §13, F2's first ask); `CoreClient` does not subscribe to `supervisor` yet. The resident view's entry is `shell-dms.qml` (`FART_VIEW_ENTRY`).
- **Needs the owner present.** Real `network.wifi.toggle`, `connect` and `scan`; `dms ipc call lock lock` and `hl.dsp.exit()` on the live session; the tray with a real item and submenus; media, audio and UPower with real D-Bus and Pipewire. Z9 should say at the merge that a newer DMS keeps working (marked untested) and an older one is switched off.

# 12 November 2026 · Sonnet (S2): step 4, notifications

- **Built.** `DmsNotifications` reads the core's mirror (`core.notificationsData`) exactly as the Serpantinum one does; `markAllRead` and `dismiss` go to the core. `openHost` runs `dms ipc call notifications toggle`, the session's own Super+Shift+N bind. **Do-not-disturb is not wired**: `setDnd` only logs a warning, since there is no notification server of ours until S4 and I did not guess a DMS call. `dnd` stays false. No notification server was built.
- **Tests.** Contract and static checks as for the other domains; the adapter test confirms the domain is `DmsNotifications` and reads unavailable when there is no core.
- **A flake to know about.** The step 3 full run failed once on `test_core_ignite.InCore.test_a_release_with_the_view_absent` (core code, untouched by this branch). It passed 15 of 15 on its own and in the full runs before and after; it looks like a timing flake under load. Step 3 was committed before I looked at it; the step 4 run below is the confirmation.
- **Suite.** 824 tests OK with `FART_*` unset (run by Opus on this tree after Sonnet stopped); `test_core_ignite` passed.

# 12 November 2026 · Sonnet (S2): step 3, the session actions

- **Built.** `DmsPower`: `suspend`, `reboot`, `powerOff` run `systemctl suspend|reboot|poweroff`; `logout` is `Hyprland.dispatch("hl.dsp.exit()")` (Z158). **`lock` runs `dms ipc call lock lock`**, the command the session's keybinds already use; this is a stand-in until S7 decides lock (OPEN F2-5), and the island's Lock button depends on it.
- **Tests.** `test_dms_adapter.SessionActions` runs the four command actions with stub `systemctl` and `dms` as the only things on PATH, and checks each stub saw exactly its arguments; logout is checked from the log of the refused dispatch (no compositor in the run). A static test pins the exact command list. Nothing real was suspended, locked or dispatched.
- **Not checked.** `dms ipc call lock lock` against a live DMS, and `hl.dsp.exit()` on the live session: both only with the owner present.
- **Next.** Step 4, notifications from the core's mirror.

# 12 November 2026 · Sonnet (S2): step 2, the Quickshell and Hyprland pieces

- **Built.** `adapters/quickshell/`: `QuickshellMedia` (MPRIS, the `position` and `spectrum` leases), `QuickshellAudio` (Pipewire, the `mixer` lease), `QuickshellTray` (SystemTray; the `menus` lease opens the item named by `menu(id)` through `QuickshellMenuNode`, one node per menu level, entry ids are index paths such as `2.0`), `QuickshellPowerSource` (UPower battery and profile). `adapters/hyprland/`: `HyprlandWorkspaces`, `HyprlandKeybinds`. `adapters/dms/DmsPower` (battery and profile for now) and `DmsAdapter` now fills media, audio (deferred), network, workspaces, keybinds, power, tray, system, lyrics (deferred) and clipboard (deferred, cliphist).
- **Reuse, not move.** The Quickshell-only Serpantinum files were copied with the host calls dropped (listed in NOTICE). The Serpantinum adapter is untouched; it is deleted only with the owner's approval.
- **One change from the copy.** `switchTo` no longer calls the `serpantinum` CLI. It runs `hl.dsp.focus({ workspace = "<id>" })`, the form the session's own binds use, after checking the id against `[A-Za-z0-9_.:-]+`.
- **Checked live, in the hidden nested Hyprland only.** The harness ran against the nested compositor: `switchTo("2")` made workspace 2 active and `switchTo("1")` moved back; an id carrying a command is refused before anything is dispatched. The nested instance has no described binds, so the keybind list read 0 there (the copy of the parser is unchanged).
- **Not exercised.** The tray: the offscreen runs have no StatusNotifier host, so `QuickshellTray` and `QuickshellMenuNode` load and report no items, but a real item with a menu and submenus has not been clicked through. Check it with a real tray application in the nested session. Media, audio and UPower were loaded with no D-Bus or Pipewire, so only their wiring is covered.
- **Tests.** `test_contract` now also checks `DmsAdapter` (every contract method implemented; the domains left on their placeholders are listed in `DMS_UNBUILT` and a test fails when one is built but still listed). `test_dms_adapter.Composition` loads the adapter and checks each domain's implementation and that nothing logs an error.
- **Next.** Step 3, the session actions of `DmsPower`.

# 12 November 2026 · Sonnet (S2, branch `s2-host-adapter`): step 1, the DMS link and network

- **Built.** `adapters/dms/`: `DmsLinkMachine.js` (the pure link machine, DMS_ADAPTER.md §2, every row), `DmsLink.qml` (the only file with a `Socket`; runs the machine's effects, one timer, replies exactly once), `DmsFeed.qml` (one per service; `wanted` is a lease expression), `DmsNetwork.qml` with `DmsNetworkMap.js` (§4) and `DmsToggle.js` (the toggle pattern of §1, kept pure so Node can test it), and `DmsAdapter.qml` (so far: `network` only). `tools/dms_replay.py` now honours `services` on subscribe, writes a request log and takes a script (synthetic replies, silent methods, events after a method). `tools/dmstest.py` and `tools/dmstest/*.qml` drive the adapter over `qs ipc` against the stand-in. `tools/dms_smoke.py` loads all rooms with DMS's network domain.
- **Tests.** `test_dms_link_machine` (44: one per row L1–L10, R1–R5, S1–S11, one per invariant), `test_dms_network_map` (24, expected values computed from the fixture), `test_dms_replay`, `test_dms_contract` (static), `test_dms_adapter` (17: contract, leases, restart with SIGKILL, same-path return, old and newer DMS). Full suite 815 OK with `FART_*` unset. `tools/dms_smoke.py` exits 0 (no binding errors, `details` held on Devices and released, no action sent). qmllint 0 syntax diagnostics.
- **Choices the note left open.** The event connection's retry counter resets on the first event after a reconnect (not on connect), so a server that accepts and drops cannot make a tight loop. A dropped event connection keeps the last snapshots (stale for at most the 2 s backoff); a lost request connection clears them. DMS greets every connection, the event one too; that line is ignored. `done(result, error)` passes `""` for no error.
- **Not checked against a real DMS (owner present).** `network.wifi.toggle`, `network.wifi.connect`, `network.wifi.scan`: shapes come from DMS's QML. `hostActions.open("wifi")` (an unknown network) does nothing until the host actions exist (S6).
- **Next.** Step 2: `adapters/quickshell` and `adapters/hyprland`.

# 12 November 2026 · Opus: interim switch-over built, off by default (Z159); Astra's fixes applied

- **Owner's answers.** The interim plan (Z159): DMS keeps its own UI and only its bar is hidden; the island and FART run as one always-on view. The bar is hidden only while the island is up. Astra's proposals applied as written, without re-measuring.
- **Astra's fixes** (`946feb7`). The view starts with `MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000` unless one is set; CAVA and the island fixture's spectrum run at 20 Hz. CAVA's own process is still unmeasured, so the 5% live media budget is not claimed.
- **Resident view.** `FART_RESIDENT_VIEW=1` (read by `core/fartd.py`): the core starts the view at once with `ZAETHERION_ISLAND=1`, never reaps it (idle or PSI), restarts it 1 s after an exit (three quick crashes stop the restarts), and ends it only on its own stop (`ViewManager.resident`, `keep()`, `stop()`). The `view` topic gained `resident`. Unset, nothing changes.
- **DMS's bar** (`core/dms_bar.py`). The owner's Main Bar is a DMS island bar, and DMS's `bar hide` refuses those (`BAR_IS_ISLAND`); `settings set` cannot edit the bar list. DMS watches `settings.json`, so the core sets `visible` on the bar with `id: default` (atomic replace, DMS's 2-space format, nothing else touched). Hidden while the view is `ready`; shown when it is not, at core start and at core stop.
- **Checks.** Unit: view 27 (resident, not resident, spawn env), DMS bar 5, all core tests (348), architecture 8, contract 9. Nested Hyprland, real core supervising a real DMS with its full UI (the owner's theme and wallpaper; private home, XDG folders and session bus, no system bus, weather off): 16/16. Today's bar; resident start hides it; hover, FART grown, header fold; a DMS notification sits top-right clear of the island; Fluid through the `island` verb; view killed → bar back in 10 ms, view back in 1 s → hidden; core stop → bar shown, nothing left running. No QML errors. Captures were shown to the owner and not committed (they hold the owner's wallpaper).
- **Not done.** Turning it on: `tools/zaetherion.py` `start_core` (or `tools/session-start`) sets `FART_RESIDENT_VIEW=1`, after `s2-host-adapter` is reviewed and merged (`shell.qml` still uses the Serpantinum adapter, and any `serpantinum` call restarts Serpantinum's daemon) and with the owner's go. Then a real login/logout check. A core killed with SIGKILL leaves the bar hidden until the next core start.
- **Next.** Review `s2-host-adapter` when Sonnet hands back (contract coverage, leases, the DMS link machine), merge with the owner's OK, then the turn-on above.

# 12 November 2026 · Astra: island memory and CPU diagnosis recorded

- **Report.** [Island memory and CPU diagnosis](docs/ISLAND_DIAGNOSIS.md), measured at `9662778` in a detached worktree. This is evidence for that revision, not a performance pass for the newer island integration. No implementation change was made.
- **Next-session kit.** [Continuation brief](docs/ISLAND_NEXT_SESSION.md) gives the investigation order, measurement controls, synthetic CAVA route, checks and cleanup. [Scrubbed evidence](docs/measurements/island-9662778.json) preserves 10 runs and 108 samples without relying on temporary logs. Preparation HEAD was `4ef6920`; check fresh state before starting. Establish which spectrum source the current resident/DMS path uses before treating a CAVA-rate change as a production fix.
- **Memory.** With default jemalloc settings, folded Private_Dirty was 118.2 MiB idle, 166.3 after one cycle, 193.5 after 21 and 50, and 188.5 after 100: it plateaus. Live allocated bytes stayed around 56–57 MiB after first open. Both rooms release; object, Connection, Loader and Shape counts stay fixed; sampled leases and satellites are empty. Keeping Shell costs roughly 4 MiB of live allocations and room precompilation 2–3 MiB. Disabling island morphing did not help. Allocator/transparent-huge-page overhead dominates the larger resident footprint: the inherited jemalloc tuning reduced cycle-100 PSS/Private_Dirty from 222/188 to 135/101 MiB. The report separates RSS, shared mappings and driver allocations; the island still has no memory budget.
- **CPU.** Rest 0.03% of one core; Fluid media 6.53%; fixture spectrum generation without publishing 0.67%. At 20 Hz, the fixture used 4.33% with 24 bins and 4.37% with 56 active simulated bins. Changing Shape renderer alone still exceeded 5%. CAVA's separate process is unmeasured, so the live media budget is not yet passed.
- **Proposal only.** The report contains a minimal diff for a child-process jemalloc default that preserves an existing value, a 50 ms fixture timer, and CAVA at 20 Hz. None is applied or recorded as an owner decision.
- **Verification and cleanup.** Nested GPU measurements, pointer cycles through 100, IPC control through 200, allocator/GC/cache probes, and morph/room/keepShell/precompiler ablations completed. No unexpected QML errors; nested `hyprctl configerrors` empty. The nested compositor was stopped and detached worktree removed. No live-session changes, staging, commits or pushes. This checkpoint adds documentation and scrubbed measurement evidence only.
- **Next (diagnosis).** Revalidate the proposed allocator settings and 20 Hz source rate on current code, then measure the separate CAVA producer before claiming the 5% live media budget passes. Opus's owner-review/session-enablement task below remains pending.


# 12 November 2026 · Opus (Sol's items): keytest race fixed; island settings in the core

- **`test_keytest` `timers.loaded`.** A timing race, not a broken room: 1 failure in 3 standalone runs, and a failed load skipped the Timers walk. Each room now gets up to 20 ticks of 300 ms; any extra wait logs `KEY_SLOW` (seen once: Timers, 300 ms). 4/4 runs passed 172/172 (`4fa474a`).
- **Island settings (Z155).** `core/island.py` keeps `form`, `edge`, `placement` and `screen` in `island.json`, published as the `island` topic (`CoreClient.islandData`). The `island` verb sets them from FART's command line or `zaetherion island fluid|angular|top|bottom|notch|floating|screen <name>|screen auto`. `shell.qml` binds `Design.form`, edge, placement and screen to it; the `ZAETHERION_ISLAND_*` variables only stand in while no core is connected. Tests: `tests/test_core_island.py`.
- **Checks.** Core, verb, contract and CLI tests OK; nested `shell.qml` wiring 11/11; qmllint 0 syntax diagnostics.
- **Next.** Turning the island on in the ZÆTHERION session, after the owner sees how it will look.

# 12 November 2026 · Opus: tray menu and session card grow from the island (Z157, Z158)

- **Tray menu.** No longer a popup window: a `tray` queue entry (priority -1, no dwell) whose face is `IslandTrayMenu` (unframed, capped at the 160 px depth). `IslandWindow` gained a `HyprlandFocusGrab` for held faces, armed 100 ms after the island holds the keyboard (Hyprland clears a grab while focus is moving); `tests/test_contract.py` allows `Quickshell.Hyprland` there for that grab only.
- **Session card.** A `session` queue entry from the island's power glyph. `PowerDomain` gained `suspend`, `logout`, `reboot`, `powerOff`; Serpantinum runs `systemctl suspend|reboot|poweroff` and Hyprland's `hl.dsp.exit()`; the fixture records only. **The DMS adapter (`f2-dms-adapter`) must implement the four new calls.** The island's `openPower` signal and the fixture's floating session-card preview are gone; the fixture gained `power` and reports `powerCalls`.
- **Checks.** Nested, both forms: session card 18/18 (0.4 s and 0.65 s presses do nothing, a full hold fires, click locks, Esc and click outside fold, Enter hold on Reboot), tray 10/10, `shell.qml` wiring 11/11, docked focus 6/6. Island, contract, layout, qmldirs OK; qmllint 0 syntax diagnostics. The virtual pointer in the nested kit gained `hold:<ms>`.
- **Next.** Opus took over Sol's items: `test_keytest` `timers.loaded`, storing the island's settings with FART's, and turning the island on in the ZÆTHERION session (show the owner first).

# 12 November 2026 · Opus: Super+Shift+I bound, island actions confirmed (Z156)

- **Owner.** Confirmed long-press `sticky` ignite, power to the host's power menu, and notification actions waiting for S4 (Z156). Sol is no longer on the project; Sol's open items (the `test_keytest` `timers.loaded` failure, storing the island's settings with FART's, and turning the island on in the ZÆTHERION session) have no owner yet.
- **Bind.** `shell.qml` has an `island` IPC target with `focus()`. Super+Shift+I runs `qs -p <repo>/shell.qml ipc call island focus`. Added to `session/hypr/zaetherion/fart.lua` and, with the owner's go-ahead, to the installed copy; `hyprctl configerrors` empty and the bind is listed. It does nothing until the island runs in the session (the view is not started there yet: `FART_RESIDENT_DIR` is unset, so DMS draws its own UI).
- **Fixture.** The session-card preview is a fixed layer card under the island instead of a floating window that Hyprland tiled to full height.
- **Checks.** Nested `shell.qml` wiring 11/11, including the focus call with the island on and off; qmllint 0 syntax diagnostics.

# 12 November 2026 · Opus: island in shell.qml (opt-in), island measured

- **Island in `shell.qml`.** Opt-in with `ZAETHERION_ISLAND=1`; without it the shell is the panel alone, so FART-next under Serpantinum is unchanged. Wired as the fixture: `adjacentIslandGap`, `islandRect`, `companionWindows`, `islandHasKeyboard`, `keyboardPeer`, `docked`. Until the daemon stores the owner's choices (Z155), `ZAETHERION_ISLAND_OUTPUT` (default: focused screen), `_EDGE` (`bottom`), `_PLACEMENT` (`floating`) and `_FORM` (`fluid`|`angular`) come from the environment. The ids in `shell.qml` are now `adapter` and `client`: inside the island's LazyLoader, `host: host` bound the island's own empty property.
- **Choices to confirm with the owner.** Island long-press ignites `sticky` Overdrive, or cuts a running one (the core's `panel` mode would end with the folded panel). Power opens `actions.open("power")`. Notification actions and replies only log a warning: the contract has no call for them until S4.
- **Checks.** Nested, with the fixture adapter swapped into a copy of `shell.qml`: off by default, on shows the island, click grows FART, empty header click folds it, Fluid form; 8/8, no QML errors. Full suite 707/708 with `FART_*` unset; the one failure is the known `test_keytest` `timers.loaded` (Sol).
- **For Sol.** The ZÆTHERION session (supervisor or launcher) should set `ZAETHERION_ISLAND=1` for the view. The Angular/Fluid choice and the island's screen, edge and placement belong in FART's settings (Z155). The Super+Shift+I bind is still the owner's to add.
- **Measured** (`docs/BUDGETS.md`, GPU sample). Rest CPU passes. Media in Fluid used 6.37% of a core against 5%, fixture timer included. Memory grows with open/fold cycles (+46 MiB PSS on the first, +27 over the next 20) and does not return to idle; the owner is giving that diagnosis to Astra.

# 12 November 2026 · Opus: header click folds FART, Framed only (Z155)

- **Owner's answers (Z155).** A click on empty space in FART's header folds it back into the island when FART grew from it (Z134 extended). Super+Shift+I keeps Z148. Fluid forgets the right-click clock/media choice on restart and shows media only while playing.
- **Removed.** `IslandWings.qml`, the Mirror and Sides arrangements, the fixture's `layout` call and `ZAETHERION_FIXTURE_LAYOUT`. Framed is the only arrangement.
- **Header click.** `Shell.qml` gained `headerEmptyClicked()`, from a MouseArea under the header's controls, enabled once the header is fully revealed. `PanelBody` closes on it only when grown from the island and open. Without an adjacent island nothing changes.
- **Checks.** Island, layout, contract and qmldirs 23/23; `qmllint` 0 syntax diagnostics. Nested: header fold 8/8 twice (three empty spots fold, command line and two chips keep FART open), docked focus 6/6, exact reply once.
- **For Sol.** The owner wants the Angular/Fluid choice (`Design.form`) stored with FART's settings by the daemon, so every surface reads one value. Opus will read it once you expose it. `test_keytest`'s `timers.loaded` failure (previous entry) is still yours.
- **Next.** Opus wires the island into `shell.qml`; island memory against `docs/BUDGETS.md` is measured separately.

# 12 November 2026 · Opus: FARTland // Fluid, even spacing (Z153, Z154)

- **Built and owner-approved.** FARTland // Fluid as a second form of the island (Z153), and one spacing rhythm with an optical lift for the flush notch (Z154). Captures and calls are in `docs/ui/README.md`.
- **Checks.** `test_island` 5/5, including the new `FluidTest.qml`. Layout, contract and qmldirs OK. `qmllint` reported 0 syntax diagnostics. Nested: docked focus passed 6/6, and an exact reply arrived once.
- **For Sol.** The full suite had one failure: `test_keytest` reported `timers.loaded` with an empty value, so the Timers room did not load in time. It fails the same way on `5f86e7e` and on `bd4ebdb`, which passed earlier the same day, so it looks environmental, not caused by the island. `BatteryMark` gained `rounded` (default off, so FART's header is unchanged), and `MaterialSymbol` gained `fill` and `weight` (defaults render as before).
- **Open for the owner.** Z134 (should a click on FART's header fold it back?), Z148 (should Super+Shift+I fold FART back and focus the island?), whether the right-click choice should survive a restart, whether Fluid shows media while paused, deleting `IslandWings.qml` along with the Mirror and Sides arrangements, and where the Angular/Fluid switch is stored.
- **Next.** See the owner's next-chat prompt: commit cleanup, the open questions, persisting the form, wiring the island into `shell.qml` with Sol, and island budgets.

# 12 November 2026 · Opus: island grows into FART; Framed, matte, Amoled Black

- **Owner-approved** (Z149–Z152): the Framed layout; the island widening into a bar and dropping into FART, then folding back; a matte fill; DMS Amoled Black as the built-in palette. The layout review and growth animation are in `docs/ui/` (see its README).
- **Jitter fixed.** The island's surface no longer resizes during morphs, and the island holds its shape while FART grows from it. Recorded at 60 fps in nested Hyprland: the centre held within 0.5 px, and both open and fold were monotonic.
- **Checks.** `test_island` 4/4, layout, contract and qmldirs OK, `qmllint` 0 syntax diagnostics. Nested: the docked focus handover passed 6/6, and an exact reply arrived once.
- **Open for the owner.** Z134: FART's header now covers the island, so should a click on the header's empty area fold FART back? Z148: should Super+Shift+I fold FART back into the island and focus it? The island is hidden while FART is open.
- **For Sol.** `Overlay` and `PanelBody` gained an island-growth path (`islandMorph`, `islandRect`, `islandFrom`, `morphRect`); without an adjacent island the panel behaves as before. When the island joins `shell.qml`, wire `docked`, `islandRect` and `keyboardPeer` as the fixture does. `IslandWings.qml` is unused now; deleting it waits for the owner's word. The Mirror and Sides arrangements are still selectable for comparison.
- **Next.** FARTland // Fluid (Z145) as a second form of the same island.

# 12 November 2026 · Opus: island reply fix, Angular pass and wider media pill

- **Reply bug fixed.** When an OSD covered a notification, keyboard interactivity dropped to None and then returned to OnDemand. Hyprland gives click focus to an OnDemand layer only after the pointer moves, so the field took focus in Qt while the window stayed inactive and Enter delivered nothing. A queued reply draft now keeps OnDemand. A field that takes focus in an inactive window briefly claims Exclusive. The field regains focus when its notification returns, and Send dismisses the notification. Hidden nested Hyprland ran Sol's exact steps 3 times and the no-second-click path 3 times. Each run delivered `Synthetic reply` once, and `configerrors` was empty. Hyprland still drops the first click when the island grows under a pointer that has not moved.
- **Look.** Brought the island up to the approved study and FART. The changes are the app name on an inverted ink tag, the fixed-light rim, face and facet, shoulder-safe insets, the notched rule, an ink tag for the first action, a full-width reply field, a blade meter and readout for volume and memory, a track tile, and ink-plane keyboard focus. The new shared parts are `FTag` and `FBlades`. Captures and notes are in `docs/ui/README.md` (Opus pass).
- **Owner review: media pill.** The pill now runs up to the centred clock instead of a fixed 104 px. Network moved to the right group beside the bell and battery, which keeps the resting width at Z66's 420 px. Hovered, the centre opens to 500 px, so the title keeps its room when the clock gains seconds and the wings sit outside it. With the synthetic title `Synthetic Fixture Track With A Long Title`, the visible text grew from 9 to 14 characters at rest and from 9 to 18 on hover. The clock stays on the screen centre. Captures are in `docs/ui/island-s3-media-pill.png`. Island, layout, contract and qmldirs checks passed 22/22. Nested checks passed docked focus 6/6, and an exact reply arrived once.
- **Checks.** `test_island` 4/4, including the new `ReplyTest.qml`. Layout, contract and qmldirs 18/18. `qmllint` reported 0 syntax diagnostics on the changed files. The full suite passed 707/707 in 581 s with `FART_*` unset. No daemon or test-infrastructure files were changed.
- **Docked focus (Z148, owner's choice).** Super+Shift+I with the panel open now moves the keyboard to the island and keeps the panel open. The first Esc returns the keyboard to the panel and the second closes it. `Overlay` gained `islandHasKeyboard` and `holdsKeyboard`, and the island gained `keyboardPeer` and `wantsKeyboard`. Only the fixture wires the two, because `shell.qml` has no island yet. Hidden nested Hyprland passed 6/6 three times with Esc. Separate runs confirmed that typing reaches the panel's command line after Esc and that a click outside still closes the panel. The reply check and plain island focus pass again. The full suite passed 707/707 again after this change, with `FART_*` unset.
- **For Sol.**
  - **Commit split.** At the owner's request, Opus committed only its own island files and its own HANDOFF entry. Sol's working-tree changes stay uncommitted and untouched. Opus's files:
    - Modified: `view/shell/IslandExpansion.qml`, `IslandSurface.qml`, `IslandWindow.qml`, `IslandRest.qml`, `IslandGlyph.qml`, `Overlay.qml`; `view/ui/IslandFrame.qml`, `view/ui/qmldir`; `shell-island-fixture.qml`; `tests/test_island.py`.
    - New: `view/ui/FTag.qml`, `view/ui/FBlades.qml`, `tests/fixtures/island/ReplyTest.qml`, `docs/ui/island-s3-opus-review.png`, `docs/ui/island-s3-opus-docked.png`, `docs/ui/island-s3-media-pill.png`.
    - Shared: the Opus sections of `docs/ui/README.md` and `HANDOFF.md`, and Z148 in `docs/DECISIONS.md`.
    - Opus did not change daemon, launcher, faces or test-infrastructure files. Never push.
  - **Nested kit.** `/tmp/zi-reply-opus/` holds `check.py` (modes `exact`, `noclick`, `wiggle`), `docked_focus.py` (Z148, add `outside` for the click-outside close), and `pointer.c` with its built `pointer`. `pointer` is a virtual pointer on the nested display that takes `click` or `move`. Run each script from the repo root with nested Hyprland started. `/tmp` does not survive a reboot. If these checks should stay, they belong in `tools/`, which is Sol's to decide.
  - **Fixture IPC.** `state` also reports `lastReply` (synthetic text only) and `keyboard` (`none`, `ondemand` or `exclusive`). `title <text>` sets a synthetic track title.
  - **Timing in the Z148 handover.** The island waits 60 ms after the panel releases before it requests Exclusive. The panel resumes its focus grab 100 ms after it retakes the keyboard. Both delays were measured in nested Hyprland 0.57.1 and are not tuned. Recheck them on the real session and with a slow frame. While the island holds the keyboard, a click outside does not close the panel.
  - **Still open.** When the island joins `shell.qml`, wire `Overlay.islandHasKeyboard` to the island's `wantsKeyboard` and `IslandWindow.keyboardPeer` to `Overlay.holdsKeyboard`, as the fixture does. The Super+Shift+I compositor bind is still unset.

# 12 November 2026 · Daemon shutdown and Angular reply checks

- Pausing the fixture daemon after `core.sock` disappeared but before it released `core.lock` reproduced a failed stop-then-start at `0baeef2`. The existing `tools/fart_next.py` diff waited for the lock and restarted cleanly under the same check. The separate `zaetherion` entry point still failed under the forced timing. The earlier reply-ordering failure’s exact cause remains unconfirmed.
- Added a launcher regression test for the shutdown gap and made the reply-ordering test print `core.log` if startup fails. All 12 daemon and 8 launcher tests passed. The first private full run found that the Faces smoke test loaded the installed Mocha preset. The test now supplies a synthetic preset from a private home, and the focused rerun passed.
- In hidden nested Hyprland, a typed draft kept its text through a synthetic volume OSD with the pointer held still. Enter submitted the original text exactly once, including leading and trailing spaces. Fullscreen hide and remap passed. The nested `configerrors` output was empty, Quickshell logged a Qt Wayland warning about disabling an unfocused text-input surface, and the compositor was stopped. The first click under a stationary pointer on a newly shown layer remains a separate compositor limitation, recorded in `docs/ui/README.md`.
- Rechecked Opus’s Z148 handoff in hidden nested Hyprland. The fixture focus request kept the docked panel open and moved the keyboard to the island. The first Esc returned focus to the panel and the second closed it. Exact reply submission and fullscreen hide and remap passed again. Nested `configerrors` was empty and the compositor was stopped. Qt logged text-input focus warnings during the run.
- The full private suite on the Z148 handoff (`0baeef2` plus overlay `27e186cf`) discovered 707 tests in 581.330 s, with 703 passed and zero failures. Four checks skipped because the private home omitted the installed Serpantinum clock and FART archive. All 4 offscreen island tests and 10 room smoke checks passed. Qt 6 `qmllint` reported zero syntax diagnostics across 103 QML files. Issue #23 was closed after checking the owner’s recorded keyboard layout decision in OPEN 11.
- The owner set DMS functionality and responsiveness as the baseline, with measured performance gains as the goal. `docs/VISION.md` records the control centre’s scope and `docs/BUDGETS.md` records the priorities for idle CPU and wakeups, presented frame pacing, memory growth, state-driven widgets and hidden rooms. The fixture checks establish behavior. The DMS comparison and resident performance measurements remain open.
- Next, review Opus’s Angular captures with the owner and carry the shutdown wait over to the public launcher using the same private fixture check. Wire the island and panel together when the island joins `shell.qml`, then verify the compositor binding and measure the resident against DMS on the same workflows.

# 12 November 2026 · Island UI handed to Opus, daemon test isolated

- The owner assigned the S3 island UI and interaction work to Opus and left daemon and test infrastructure with Sol. In hidden nested Hyprland, a 15-character reply draft survived a synthetic volume pop-up. After the notification resumed, clicking the field and pressing Enter recorded no action. The nested compositor was stopped. Opus has the reproduction.
- The daemon tests inherited desktop settings, including `FART_SUPERVISE=dms`, which can start a real DMS child even with the fixture host. The tests now construct a private environment, and the reply ordering test checks the CLI startup result before opening the socket. All 12 daemon tests passed with the fix under the ordinary desktop environment. The earlier socket failure's exact cause remains unconfirmed.
- Next, rerun the full suite once the UI changes are ready. Verify exact reply submission in the nested fixture and review the updated Angular captures with the owner.

# 11 November 2026 · S3 Angular fixture checkpoint

- The Angular fixture now includes the resting modules, hover wings, tray menus, panel docking and keyboard navigation. It queues fixture notifications, OSD, memory pressure and workspace changes, and shows recording, timer, battery and backend status. The owner chose Roboto Condensed, omitted the keyboard layout indicator, and chose Super+Shift+I for island focus. The focus target is available over IPC. Launch and fixture commands are in `docs/ui/README.md`.
- Offscreen island and contract checks passed. Nested Hyprland confirmed the island layout, tray submenu, fullscreen hide and remap, notification preemption and resume, and the panel open and dismissal paths. Nested `configerrors` was empty. The combined fixture measurements are in `docs/BUDGETS.md`.
- The latest full suite passed 704 of 705 tests. The core daemon reply test failed because `core.sock` was missing. That test passed in the preceding full run. The preceding run's night log failure was fixed in the test and passed a focused rerun.
- The owner paused work here. On resumption, verify that a typed notification reply survives OSD preemption and reaches the fixture intact, then recheck the daemon socket test. The live adapter, compositor binding and resident performance checks are still pending. FARTland // Fluid remains a separate future mode.

# 11 November 2026 · S3 step 2 fixture shell ready for review

- **Built.** `IslandFrame` draws the Angular 420 × 36 trapezoid, 84° shoulders and 4 px bevel. `Design.islandFill` picks the darkest blue palette role, or the darkest role when no blue exists. `IslandWindow` uses the Top layer and `zaetherion-island` namespace. It unloads the surface for fullscreen on its active workspace.
- **Fixture.** `shell-island-fixture.qml` supports top and bottom notch and floating placement. The gap is 16 px in this preview, while both placements reserve 36 px. Launch and fullscreen fixture commands are in `docs/ui/README.md`.
- **Verified.** Offscreen frame and palette smoke, layout and contract tests, generated qmldirs, and Qt 6 qmllint with zero syntax diagnostics. The hidden nested compositor confirmed all four placements, 36 px reserved, the bevel, and fullscreen unload, release and remap. Its config error list was empty and the compositor was stopped after capture.
- **Full suite.** All 703 tests passed in 575.885 s with QML debug messages enabled for the test process. The first run inherited `*.debug=false`, which hid the markers expected by the older fixture tests.
- **Next.** Review the fixture shell. After review, begin UI_BRIEF step 3 with the resting modules and hover wings.

# 11 November 2026 · S3 step 1 approved

- **Look.** The owner approved the Angular island with the shallow 4 px bevel and inverted app tag (Z144). One navy trapezoid widens into hover wings and deepens into notification, volume or memory pressure. `docs/ui/island-s3-review.svg` compares it with FART's fixture Timers screenshot. `docs/ui/island-s3-motion.gif` shows the morph and a volume event interrupting a notification, then the notification resuming.
- **Future direction.** Angular keeps the approved look. The future rounded mode is named **FARTland // Fluid** and depends on **FART // Fluid**, which the owner plans to develop later. Recorded in `docs/VISION.md`.
- **Fluid island approved (Z145).** A compact matte edge notch with a 3 px underside, just the clock at rest, track and waveform during playback, and other controls on hover. `docs/ui/fartland-fluid-study.svg` shows the approved look and `docs/ui/fartland-fluid-motion.gif` animates it with synthetic playback. The 100 px idle and 224 px playing widths are mock-up proposals. SVG, PNG and GIF verified and layout tests 7/7. The S3 implementation uses Z144.
- **Owner decisions.** Roboto Condensed for the mock-ups (Z52). Power opens the session card and notifications open Inbox (Z143). Memory trigger, priority and pin remain OPEN 14. Expansion sizes and floating gap are visual proposals.
- **Checks.** Layout tests 7/7, static render and motion frames visually checked, review-palette text contrast passes. The repository contrast audit is absent. The previous screenshot runner reported `0/1 rooms saved` despite writing a PNG. The fixture render was independently verified in that review and is reused here. The full suite was not run for this documentation checkpoint.
- **Next.** UI_BRIEF step 2 with the fixture adapter. Build the island window, trapezoid and fill, notch and floating modes, top and bottom placement, and fullscreen hiding. Stop for review at the end of step 2.

# 11 November 2026, night: first login on the supervisor; F2-3 checked

- **Login on the new setup is clean:** one core, one `dms`, one UI, all fresh. Owner pressed Super+R four times in four seconds: each was adopted, never doubled. **Found:** each restart counts as a failure (`failures=4`, wait 4 s), so quick repeated owner restarts lengthen the wait; reset after 60 s up. Consider not counting a clean exit that has a new DMS.
- **Old core survived a logout once** (the previous session-start's stop). The runtime folder is wiped at logout, so the leftover record is now written to `~/.local/state/zaetherion/logout.log`; read it after the next login.
- **F2-3 done with the owner present:** scan, toggle and connect (saved network) answer as designed; see OPEN.md.

# 11 November 2026, night: switch-over built (not yet logged into)

- `zaetherion start` now sets `FART_SUPERVISE=dms`; `tools/session-start` only starts the core and waits (no DMS loop, no `pkill`); `stop_core` waits up to 12 s. **The owner's running session still uses the old loop until the next login.**
- Owner's answers built in `core/supervisor.py`: new state `held` (clean exit and no new DMS within 3 s = stays down; `zaetherion start` or a new DMS brings it back) and a duplicate DMS is swept with ours, then one fresh start. Tests: 26 OK in `tests/test_core_supervisor.py`; `tools/supervisor_check.py` 16/16.
- **Still to do:** the real login/logout test (owner present: log out, log in, check one `dms`, `Super+R` keeps one, `dms kill`/stop stays down, logout leaves no processes); live checks for `held` and the duplicate sweep; measure `dms kill`; OPEN 17, 19; named clients (SUPERVISOR.md §12 items 2–5).

# 11 November 2026, evening: F1 delivered (Fable 5.2): the supervisor

- **Design:** `docs/SUPERVISOR.md` (states, transition table, backoff, crash verdicts, owner restarts, logout sequence, `dms.path`, lock hand-over, named clients, each recon finding). New questions for the owner: OPEN 15–18.
- **Slice, finished:** `fartd` supervises `dms run` when `FART_SUPERVISE=dms` (`core/supervisor.py`, wired in `core/fartd.py` and `core/app.py`). **Off by default: the owner's session still runs on `tools/session-start`.**
- **Verified:** `tests/test_core_supervisor.py` 24 OK; `python3 tools/supervisor_check.py` 16/16 (twice) in the nested Hyprland with private folders: start, UI crash back in 0.37 s, DMS kill with orphan sweep, owner restart adopted in 0.8 s and not doubled, waits 0.25/1/3/4, shutdown and compositor exit leave no processes, the session's DMS untouched. Full unit suite on the F1 tree, from the repo root: 700 run, 698 OK; the 2 failures were the fixture ones that `7f24a1f` fixed afterwards (both pass now).
- **Measured, new:**
  - `dms restart` = SIGUSR1; the old one exits 0 in 0.07 s; a detached `dms run -d --daemon-child` appears 0.36 s later and **keeps the environment but drops the flags**. So the UI folder goes in `DMS_SHELL_DIR`, never `-c`, or Super+R would bring back DMS's stock UI.
  - `pgrep -x dms` (the interim loop) also matches `dms cl copy` and other one-shot commands; the supervisor uses pid files plus a liveness check.
  - Apps launched from DMS (`Quickshell.execDetached`) get parent 1 and their own session, so the tree sweep cannot reach them. Today's DMS (started by `session-start`) shares Hyprland's session with every app: an adopted DMS that does not lead its session is swept by descendants only.
- **The pattern, for whoever continues (Sonnet):**
  - Behaviour lives in `TABLE` in `core/supervisor.py`; the same table is in `docs/SUPERVISOR.md` §2 between `<!-- table:start/end -->` and a test compares them. **Change both together, table first.**
  - `Machine` is pure. `Child` runs actions named `_do_<action>`. Everything that touches real processes is a *port* (`DmsPorts`); tests use `FakePorts` and the fake clock. A new supervised thing = new ports + a `Policy`, not a new machine.
  - Anything involving a real DMS is checked with `tools/supervisor_check.py`: add a check there. Never run a test DMS in the session's own runtime folder.
  - Run the suite from the repo root: `python3 -m unittest discover -s tests` (from inside `tests/` three modules fail to import).
- **Next, in order (docs/SUPERVISOR.md §12):**
  1. **Switch-over, needs the owner's go:** `start_core` in `tools/zaetherion.py` sets `FART_SUPERVISE=dms`; `tools/session-start` becomes "start the core and wait" (drop the DMS loop and `pkill -x dms`); raise `stop_core`'s wait from 6 s to 12 s. No Hyprland config change. **Build the owner's answers with it, from `docs/SUPERVISOR.md` §13:** OPEN 16 (a DMS stopped on purpose stays down: state `held`) and OPEN 18 (a second DMS: stop both, start one). Ask OPEN 19 first (a deliberate stop while locked, before S7). Then a real login/logout test.
  2. Named clients `resident`/`panel` and the panel's snapshot adapter (§9), with `DMS_SOCKET` for the panel from the `supervisor` topic (F2's need, §13); `tests/test_core_view.py` must stay green.
  3. `session.log` trimming and `dms.log` rotation; who restarts `fartd`; measure `dms kill` with care (§13).
- The two fixture test failures found on the way were fixed in `7f24a1f`.
- F2 (the `dms` adapter design) ran in parallel: entry below. What it needs from F1 is answered in `docs/SUPERVISOR.md` §13.

# 11 November 2026, F2: `dms` adapter designed (note only, no code)

- **The owner cut F2 to the design note.** `docs/DMS_ADAPTER.md` holds the design (brief points 1–6), the link's transition table (§2), the network mapping (§4), the service ↔ domain ↔ lease table (§5) and the build and test list (§9). No `adapters/dms/` exists yet; nothing was run against a real DMS.
- **Owner's decision:** a DMS newer than the checked one (API 38) keeps working with a note in Settings; an older one is switched off. Z9 needs that sentence at the merge.
- **The pattern to copy per domain:** one `DmsFeed` per DMS service with `wanted:` set to the lease (`holds("…")`, or `true` for un-leased contract state); properties are bindings on `feed.data`; methods go through `link.call` and never update properties themselves; a pure `Dms<Domain>Map.js` does the mapping and is tested under Node against the fixture.
- **Needs from F1** (§7): the DMS socket path for the panel, at spawn and on change; stopping an orphaned resident; the source for Z123's expansions.
- **New open items:** OPEN.md F2-1 to F2-6.
- **Found on the way:** `tests/test_qmldirs.py` fails before any F2 change (`tests/fixtures/nested/{lock,pamcheck}/qmldir` missing). Left alone.
- **Next:** build §9 in order (stand-in, link machine with its row tests, network, smoke), then roll the pattern out to bluetooth, brightness and the rest.

# 11 November 2026, afternoon: nested Hyprland check (Z109) passed

- **Nested Hyprland is viable for tests.** `tools/nested_hypr.py` (start / run / shot / stop / selftest) parks a nested Hyprland on a hidden special workspace with a headless `ZTEST` output that renders while hidden. Self-test 9/9 twice: fake lock shows and clears, a crashed lock client keeps the screen covered, a new client takes over, fake PAM permit/deny work from private config files, real session untouched. Details: docs/NESTED.md. Fixtures in `tests/fixtures/nested/`; `tests/test_nested_fixtures.py` 3 OK.
- **F1 prepared for Fable 5.2:** brief `docs/F1_BRIEF.md`; recon `docs/F1_RECON.md` (DMS run nested with private folders: a UI crash takes DMS down and is not respawned; only TERM/INT stop the pair cleanly, HUP/KILL orphan the UI; the shared `dms.path` pointer is taken by any second DMS and deleted on exit).
- **Incident during recon (fixed):** the first test DMS shared the real runtime folder, overwrote `dms.path` and deleted it on exit, so the owner's DMS keybinds pointed nowhere for under a minute. Restored by hand to the real UI path; `dms ipc` lists the real targets again. Tests now use a private `XDG_RUNTIME_DIR`.
- **Next:** the F1 Fable session, from the brief. Also check `zaetherion start/stop/restart/status` fits the session.

# 11 November 2026, ~12:40: S1 session installed and tested; DMS bar tuned

- SDDM entry installed by the owner; the owner now logs into **ZÆTHERION** (Hyprland + `zaetherion.lua` → `session-start` → core → `dms run` with DMS's UI). Login clean; logout + login left no old processes, one fresh set.
- cliphist records in the ZÆTHERION session (owner's choice); DMS clipboard stays off.
- Owner design inputs recorded: Modern Clock widget (PARITY, S10), island module list and memory-pressure expansion (SURFACES §1, OPEN 14).
- DMS bar tuned for the owner (7 workspace dots, power button, CPU off); not in this repo.
- **Next:** nested Hyprland check (Z109), then F1 (supervisor design). See NEXT_CHAT_HANDOFF.md.

# 11 November 2026, midday: S0 done; S1 started (owner approved both parts)

- **S0 done.** Full unit suite in this tree: 673 OK (572 s). Quiet baseline of Serpantinum + FART-next measured with Serpantinum back for ~10 min; **total budget fixed at 768 MiB PSS** (BUDGETS.md). Serpantinum is off again (`*.off`), DMS keybinds back in `config/keybinds.lua` (copy: `keybinds.lua.dms-2026-11-11`). Note: `serpantinumd stop` leaves `serpantinum-audio daemon` running; it had to be killed by hand.
- **S1 so far (not yet installed or logged into):**
  - `~/.config/hypr/zaetherion.lua` + `~/.config/hypr/zaetherion/` (copies in `session/hypr/`): shared look/monitors, DMS keybinds, Super+` on ZÆTHERION's core, `allow_session_lock_restore`, no Serpantinum or cliphist autostart. `Hyprland --verify-config` says ok. `hyprland.lua` (Serpantinum's session) unchanged.
  - `tools/session-start`: interim starter (core, then `dms run` with DMS's own UI until the resident exists at S3; restarts dms with backoff; stops both when the Hyprland socket goes). Roadmap F1 (fartd supervising dms) replaces it.
  - `session/zaetherion.desktop` (template, `@HOME@`), installed by the owner with sudo.
- **Still owed for S1:** install the session file, a real login/logout test (no leftover processes), nested Hyprland check (Z109), F1 supervisor design.

# 11 November 2026: S0 nearly done

- **Done:** scrub test and fixture replay (`tests/test_dms_fixtures.py`, 10 OK; `tools/dms_replay.py`, a stand-in DMS server); the real lyrics, location and weather names (weather is UI-side in DMS); a first memory look. All in `docs/DMS_OBSERVED.md`.
- **Owed for S0:** the quiet baseline of Serpantinum + FART (Serpantinum is off while the owner tries DMS), then BUDGETS.md's total.
- **The owner's desktop now:** full DMS (`dms run`, detached) with their keybinds retargeted to DMS (`~/.config/hypr/config/keybinds.lua`; the Serpantinum version is `keybinds.lua.serpantinum-2026-11-10`). Serpantinum's `bin/serpantinum{,d}` are renamed `*.off`. FART running.
- **Next:** S1 (the session). It needs the owner's approval for the SDDM entry (root) and autostart.

# 10 November 2026, late: S0 started, the seed is in (branch `s0-seed`)

- **Seeded from FART-next tag `FARG`** (`c13d874`): code at the root, FART's docs in `docs/fart/`, its NOTICE as `licenses/FART-NOTICE`. NOTICE records it.
- **`zaetherion` launcher** (`./zaetherion`, `tools/zaetherion.py`): FART's CLI with its own runtime, state and cache folders (`zaetherion`), so it can't touch the everyday `fart`. Checked with `status` only; not started. Still named fart-next in help text and the core's own names.
- `test_orbit` passes from the seeded tree. The full suite hasn't run here yet.
- **OPEN 2 checked (read-only):** tesseract, zbarimg and satty are all installed.
- **OPEN 13 decided:** the heavy layer stays on NVIDIA, Overdrive only (BUDGETS.md changed).
- **DMS run for the first time, read only, with Serpantinum fully stopped and backed up:** see `docs/DMS_OBSERVED.md` (read it before touching DMS). Fixtures in `tests/fixtures/dms/`. **Problem first:** the clipboard manager ignored its off switch.
- **Was waiting on the owner (now partly done):** OPEN 13 (keep the heavy layer and change the "dGPU never woken" budget, or move it to the AMD chip); the first `dms run` for the fixtures; the quiet baseline. The FARG measurements are in FART's `docs/OVERDRIVE.md` §9: NVIDIA asleep in Silent and after release, about 38 % and 12–14 W while Overdrive is on.

# 10 November 2026: the plan says "bring FART over"; DMS installed

**State:** still design only, no shell code. Two things changed:
- **FART-next is past the start line (Z1).** It has built all of M0–M16, including what this plan had moved here (M13 lensing, M14's live previews, M15 discovery and the archive, M16's tiers), plus M11 sessions and the heavy layer on the NVIDIA card. **Z62 now says ZÆTHERION brings FART over:** all of it arrives with the S0 seed and is adapted, not rebuilt. S11 extends FART's Overdrive to the island, launcher, overview and lock card. MILESTONES, DECISIONS (Z1, Z9, Z62), DMS_BACKEND and README updated.
- **DMS is installed: `extra/dux-shell` 2.1.0-1** (the owner, 10 November, 14:18), not `dux-shell-git`. Z9 is changed to match. **Not run yet:** `dms.service` is disabled and inactive, and there's no DMS config directory.

**New open item:** OPEN.md 13, the heavy layer on the NVIDIA card against the "dGPU never woken" budget. The seed brings it in, so it needs the owner's answer at S0.

**Untouched:** `docs/ROADMAP.md` is an uncommitted local file from before this change; it still says `dux-shell-git` and "M13–M16 move here". Left as it is.

**Next task:** S0, when the owner says go:
1. Seed this repo from a tagged FART-next commit. FART-next first takes its 144 Hz measurements and finishes its optimisation pass, then tags.
2. Record and scrub the DMS fixtures (`dms run` for the first time, on the owner's go; check `apiVersion` against 2.1.0).
3. Read-only check for tesseract, zbarimg and satty (OPEN 2).
4. Measure the quiet baseline.

# 8 November 2026: planning complete, design docs published

**State:** design only. No shell code exists. The plan came from one long planning session in which the owner answered every design question: 142 decisions (Z1–Z142), plus 12 open items, each with the test or approval that settles it.

**Done:**
- The docs set: VISION, DECISIONS, SURFACES, ARCHITECTURE, CONTRACT, MILESTONES, BUDGETS, RISKS, PARITY, DMS_BACKEND and OPEN.
- A plain-language overview PDF for non-technical readers.
- The public GitHub repo, with milestones S0–S12 and issues.

**Not done, by design:**
- No package installed. DMS was researched from its source only.
- No Hyprland, SDDM or Serpantinum file touched.
- No FART-next code changed; a docs pointer branch exists there, unmerged.

**Next task:** wait. ZÆTHERION starts when the owner says FART-next's Overdrive has reached about M12. Then begin S0 (docs/MILESTONES.md):
1. Ask for approval to install `dux-shell-git`.
2. Seed this repo from a tagged FART-next commit.
3. Record and scrub the DMS fixtures.
4. Measure the quiet baseline.

## Astra — 2026-11-20 — Native Angular Settings / Cutline

Ready for Claude A to review and merge: `codex/settings-redesign`.
Implementation: `c0deb27`, based on fresh `s0-seed` at `85ea9e9`.
The owner's open preview had A / Cutline selected when they said "YES, IMPLEMENT".
They also asked for the Settings sidebar to match the existing FART style.

Implemented:
- All eight sections share a native numbered index with FART's type, cut geometry,
  palette tokens, focus marks and existing feedback cue. The selected section gets
  the ink plane; this replaces the crowded horizontal tab row.
- `SettingChoices` leads with the current reading. Alternatives load only while
  open and are destroyed when closed. Opening, cancelling and reselecting the
  current value never writes. Selection uses the existing authoritative handler,
  dismisses the choices and returns focus. Unknown values remain unknown; an
  Island rest mix reads Custom. Long values retain their full tooltip/name.
- Notifications, Island and Clips use paired readings with leading values on cuts.
  Long sections scroll. Palette's shell choices use compact readings; palette's
  effective value leads its list. Wi-Fi preference uses the same disclosure;
  network/device status is larger. Wallpaper/preset pickers retain their content
  and preview handlers under the common native section header.
- Clear/forget controls are visually separate and retain their original confirmation.
- Native capture: `docs/captures/settings-cutline.png`; NOTICE records its source.
  An additional full-FART fixture capture was made locally, with the actual Home
  and shell frame behind PreferencesPane. No owner reference images or private
  runtime data were committed.
- Behaviour and visual scope recorded as Z218. Recheck the number before merging
  if another branch has added a decision. This is the approved Angular design;
  a distinct Fluid composition still needs its own visual choice.

Verification:
- `QT_LOGGING_RULES='qml.debug=true' python -m unittest discover -s tests -p 'test_*.py'`:
  `Ran 1219 tests in 729.737s` / `OK (skipped=1)`.
  QML debug logging makes the harness PASS/DONE markers observable. The previous
  study checkpoint's missing-marker failure did not recur with this invocation.
- Targeted Settings tests: `Ran 2 tests in 8.287s` / `OK`. Covers original adapter
  writes and the new navigation/disclosure lifecycle. The old fixture now opens
  alternatives before choosing them rather than calling invisible buttons.
- Settings cuetest: 42 PASS (32 checks plus 10 captures), 0 FAIL, CUE_DONE.
  Includes all eight tabs, config-lease scope, authoritative writes, no-op selection,
  focus, unknown/custom state, compact width, palette cancellation and settled motion.
- Wallpaper Typeset cuetest: 6 PASS and CUE_DONE; existing action preserved.
- Palette preview test: 1 test OK; Island settings tests: 3 tests OK;
  static layout tests: 9 tests OK.
- Explicit Qt 6 qmllint on changed QML: 0 `syntax*` diagnostics. Runtime `qs.*`
  resolution diagnostics are not counted. Used Qt 6 qmlformat for the new/grouped code.
- Offscreen all-room smoke: FART_SMOKE_DONE, FART_CALLS [0,0,0,0].
  No binding loops, ReferenceError, TypeError or Unable-to-assign messages in the
  Settings cue, smoke or full-FART capture logs. Expected offscreen window-mask
  warnings and the missing portrait in the contextual fixture are not regressions.
- `hyprctl configerrors`: empty. Git whitespace checks clean; added diff checked
  for home paths and email addresses. No installs, live restart, Hyprland changes,
  real network/playback/power/lock actions, merge or push.

Next exact task: Claude A reviews and merges this branch, checking Z218 numbering;
owner restarts the shell when ready. Next UI work is the three arrival-grammar
motion studies. Fluid Settings remains an unapproved design follow-up, not rounded
Angular. No GitHub acceptance issue was closed ahead of Claude A's review/merge.
