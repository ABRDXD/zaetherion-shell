# Desktop cohesion audit · 24 November 2026

Audit only. No view code was changed. Baseline `s0-seed` at `cf5325d`. Both forms (Angular, Fluid) were checked, on a
dark palette (Mocha) and a light one (Latte, plus GitHub Light for the island). Everything was rendered offscreen with
fixture data; nothing on the live session was touched. Renders and the small harnesses that made them are in the
audit's scratch folder, not in Git (see *How this was checked* at the end). Paths below like `frames/desktop/…` are
relative to that folder.

Tags: **Astra** (looks, layout, type, colour, motion design) · **Claude B** (behaviour, wiring, merges) ·
**Owner pick** (open, yours to decide). Size: S (an hour or two), M (a day), L (several days).

---

## 1. Verdict

1. **Your guess is half right.** Some ordinary things don't move at all: the desktop menu, the widget editor, the desktop clock appearing, Settings switching page, the lock's small pop-ups, and every Fluid button. But the island and the panel move well, so missing motion isn't the whole story.
2. **Cause 1: the newest surfaces were built as separate studies and wired in "as they are".** The desktop clock, the right-click menu, the widget editor, the lock and the capture selector use none of the shared parts (`F*`, `Fluid*`). They bring their own colours (34 fixed colours in `view/widgets/`), their own fonts and sizes, and their own buttons with no hover, press, focus or click sound. They look like a second program sitting next to the island.
3. **Cause 2: Fluid is only half built.** 5 of the 10 rooms, the whole panel frame (header, room title, index, footer) and the Settings list are still Angular when Fluid is on. Fluid controls don't animate. Fluid has no shared timing rule the way Angular has `cutDuration`, so each Fluid surface runs on its own clock.
4. **Cause 3: no motion on the ordinary things at the edges** (your guess). It's concentrated in the same places: the desktop, Settings pages, the lock's extras and Fluid controls. Frame captures show the desktop menu and editor are pixel-identical from 0 to 320 ms after opening.
5. **Detail slips make it worse:** the Fluid clock and editor almost vanish on a dark wallpaper, Fluid's big numbers turn white on a light palette, labels overlap in Home, Devices and Inbox, and three menus behave three different ways.

---

## 2. Motion inventory

"Yes / no / wrong" is what the frames and code show today. *Wrong* means it moves, but on a clock or curve that
doesn't match the surface beside it.

### 2.1 Login and desktop clock (`view/widgets/`)

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Login arrival | yes (1.5 s Register → Day index) | **no** (no Fluid login yet) | `LoginSequence.qml:227` literal 1500, `FoldMotion.qml` | keep (Z230); Fluid is an owner pick |
| Clock appears when a workspace empties | **no** | **no** | `LazyLoader`, `DesktopWidgets.qml:159-168` | an arrival cue: `Motion.cutIn` over `cutDuration` (Angular), the Fluid rule (S3) |
| Clock leaves when a window arrives | no | no | destroyed at once (Z85) | owner pick (see F1) |
| Hide / Show widgets | **no** | **no** | `visible:` flip, `DesktopStage.qml:37` | `Cue` fade, `Motion.navigate` |
| The minute changes | snaps | snaps | plain `Text` | `RollingDigits` (owner pick, F15) |
| Pose changes after editing | snaps | snaps | binding | `Motion.settle`, only when not dragging |

### 2.2 Desktop menu and widget editor

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Menu opens | **no** | **no** | `Loader`, `DesktopSheet.qml:48` | Cut from the pointer: `cutDuration` + `Motion.cutIn`; Fluid rule (S3) |
| Selection moves (keys or pointer) | **no** (Canvas repaint) | **no** | `DesktopMenu.qml:94-123` | band/rail slides: `Tween on y`, `Motion.settle` |
| Press on a row | no | no | none | `Motion.pressIn`/`pressOut`, `Feedback.play("ui.click")` |
| Menu closes | **no** | **no** | window destroyed | `Motion.cutOut`; keep the window until the fold ends |
| Editor opens / closes | **no** | **no** | `Loader`, `DesktopSheet.qml:64` | `Motion.navigate` or the cut |
| Margin tool switch (Move / Resize / Rotate) | – | **no** | `MarginPanel.qml` (no motion) | `Tween` on fill, `Motion.feedback` |
| Drag, turn, resize | follows the pointer (right) | same | – | keep instant |
| Snap to the column on release | snaps | snaps | `Grid.moved` | `Motion.settle` |
| Editor buttons: hover, press, focus | **none** | **none** | `Rectangle` + `TapHandler`, `DesktopEditor.qml:133-160` | `FButton` / `FluidButton` |

### 2.3 Island (`view/shell/Island*.qml`)

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Rest → event (OSD, notice) | yes | yes | Cut: `cutDuration` + `cutIn` / `emphasis` + OutBack (`IslandSurface.qml:286-291`) | keep, it's the model |
| Content cross-fade | yes | yes | `min(120, Motion.feedback)` (`IslandSurface.qml:206`) | keep |
| Event leaves | yes | yes | `cutOut` / emphasis | keep |
| OSD value changes | yes | yes | meter + `RollingDigits` | keep |
| Hover wings / leave | yes | yes | 300 ms delay (Z20) then reveal cue | keep |
| Pull and spring back | yes | yes | `Rubber.springMs`, OutBack | name it as a role (S7) |
| Long-press ignite | yes | yes | 600 ms (Z119) | keep |
| Minute change at rest | snaps | snaps | `FText` | owner pick (F15) |

Frames: `frames/island/notice-in-*`, `osd-in-*`, `hover-*`: every frame from 40 to 320 ms differs, in both forms.

### 2.4 Panel and rooms

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Panel grows from the island | yes (≈460 ms in, ≈330 out) | **wrong** (560 / 320 literals, linear driver) | `Overlay.qml:57-60` | Fluid rule (S3) |
| Room switch | yes | yes | orbit `Motion.transfer` 1000 | keep (docs/ORBIT.md) |
| Room entrance | yes | yes | `Motion.navigate` 140 | keep |
| Button hover / press | yes (wipe, 100 ms, 1 px press, click) | **no** (colour snaps) | `FButton.qml:41-55` vs `FluidButton.qml:27-31` | S1 |
| A big reading changes | snaps | rolls (340 ms) | `RollingDigits.qml:16` literal | `readout` role (S7) |
| Fluid scenes (star, horizon) | – | yes | literals 900 / 1100 / 1200 (`PerformanceStar.qml:42-43`, `TasksHorizon.qml:20-22`) | named roles (S7) |
| Lyric line (Angular Media) | yes | – | literal 320 (`AngularMedia.qml:215`) | `lyric` role (S7) |

### 2.5 Launcher and command line

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Launcher opens | yes | yes | island Cut + orbit draw 720 + flare 680 (`LauncherLayout.js:31-32`) | keep the scene; name its roles (S7) |
| Results arrive | yes | yes | staggered births, `revealMs/2` OutBack (`LauncherBody.qml:35-42`) | keep |
| Selection moves | yes | yes | `swingMs` 320 OutBack | keep |
| Launcher closes | yes | yes | island fold, `cutOut` | keep |
| Command-line hint | yes | yes | `Cue` | keep |
| Gate planes part | yes | yes | literal 160 (`CommandLine.qml:298`) | `Motion.swap` |

The launcher's 720 ms draw is the slowest arrival on the desktop: about twice the island's notice and 1.5 times the panel.
It's a scene, so it can stay, but as a named role, not a file constant.

### 2.6 Settings (`PreferencesPane.qml`, `Settings*.qml`, `Limb*.qml`)

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Opens | yes (≈460 ms, Cut) | yes (240 ms, OutCubic) | `PreferencesPane.qml:36-44` | Fluid rule (S3) |
| Closes | yes (≈330 ms, `cutOut`) | **wrong** (140 ms on an Out curve) | same | paired exit (S3) |
| Page (section) switch | **no** (the index band tints; the page snaps) | **no** (nothing moves) | `visible:` flips, `PreferencesPane.qml:127-288` | replay `Motion.navigate` on the page |
| Choice and action hover | yes (`SettingChip`, `SettingsAction`, `SettingReadout`) | **no** | Angular parts tween on `Motion.feedback` | S1 |
| Limb ring moves to a section | – | **no** | `LimbNavigation.qml` | `Motion.settle` |

Frames: `frames/settings-angular/seq/017-023` and `frames/settings-fluid/seq/017-023`. Fluid frames 018-023 are identical.

### 2.7 OSDs, alerts and notifications

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Header OSD in / out | yes (Cut) | **wrong** (140 / 100, Out curve both ways) | `FartHeaderOsd.qml:31-34` | S3 |
| Alert drop in / out (FART open) | **wrong** (140 / 100) | **wrong** | `FartAlertDrop.qml:30-31` | the same Cut as the island's notice |
| Whisper | yes | yes | literals 220 / 1000 (`Whisper.qml:35-36`) | a named role |
| Satellites | stood down (Z227) | – | – | – |

### 2.8 Capture, session card, lock

| State change | Angular | Fluid | Uses now | Should use |
|---|---|---|---|---|
| Selector opens / closes, mode switch | **no** (code: no motion part in `view/selector/`) | **no** | – | appear cue (S4); not rendered, so treat this as likely |
| Region drag | instant (right) | same | – | keep |
| Session card | yes (grows from the island, Z158) | yes | island Cut | keep (not rendered) |
| Lock arrives / leaves | yes (420 / 260, `cutIn`/`cutOut`, Z231) | yes | literals, `LockScreen.qml:26` | keep the values; name them (S7) |
| Wrong password shake | yes (320) | yes | `LockHost.qml:128` literal, not scaled | `scaled()` + a role |
| "> AUTH FAILED · n" | **no** (pops when the shake ends) | **no** | `PasswordPlane.qml:76`, `LockScreen.qml:147` | appear cue (S4) |
| Notice line | **no** | **no** | `LockScreen.qml:151` | appear cue |
| Power hold fill | yes (1000) | yes | `LockHost.qml:130` literal | `hold` role |
| Power choice | **no** (pops; hover snaps) | **no** | `LockScreen.qml:163-200` | the shared menu (S5) + Cut |
| Lyric line changes | yes (650, scale and fade follow the scroll) | yes | `LockLyrics.qml:25-29` | keep; also tween its colour and weight (F12) |
| Lyrics plate / visualiser appear | **no** | **no** | `LockScreen.qml:116, 129` | appear cue |

---

## 3. Findings, ranked by how often you see it × how much it hurts

### F1 · The desktop clock pops in and out every time you visit an empty workspace
- **Where:** desktop clock, both forms. `view/widgets/DesktopWidgets.qml:159-168` (the layer is a `LazyLoader`); `view/widgets/DesktopStage.qml:37` (Hide/Show widgets is a `visible:` flip). `view/widgets/` has no `Cue`, `Tween` or `Timeline` at all.
- **What's wrong:** each switch to an empty workspace builds the clock and shows it at once, and fonts load as it appears. Hide widgets makes it vanish the same way. It's the most frequent "boring" change on the desktop, and it's the one that never moves. Only the once-a-day login lands it gracefully.
- **Evidence:** grep (`view/widgets`: 0 `Cue`, 0 `Tween`, 2 `Motion.` references, both in the login), plus a code read. `DesktopWidgets.qml:36` turns the arrival off in Fluid.
- **Fix:** an arrival on `DesktopStage` when its window is made: Angular reuses the login's draw-in of the two planes, shortened (`SlantedReveal.qml` is already in the folder) on `cutDuration` + `Motion.cutIn`; Fluid fades and rises on the Fluid rule (S3). Hide/Show fades through a `Cue` before the flip. Leaving when a window arrives conflicts with Z85/Z228 ("unloaded whenever the active workspace has any window"); letting it linger ~200 ms to fold is your call.
- **Tag:** Astra (the arrival's look), Claude B (wiring), **Owner pick** (exit linger). **Size:** M.

### F2 · The desktop menu, editor and clock bring their own palette, fonts, sizes and controls
- **Where:** right-click menu and widget editor, both forms.
  - Fixed colours: `DesktopMenu.qml:19, 63, 75, 115, 121` (`#f3efdc`, `#20232b`, `#2d273e`, `#60616a`, `#f5efff`, `#464952`); `DesktopEditor.qml:38-43, 175, 192-197, 204, 221-222`; `MarginPanel.qml:38-76`; `SettingGauge.qml:25-47`; `PressMark.qml:11, 57`; `DayIndexFace.qml:23-24`; `LoginSequence.qml:55-58`.
  - Fonts written out: `DesktopSheet.qml:58` (`"Noto Sans"` / `"Roboto Condensed"`; Fluid's family elsewhere is `FluidTokens.sans` = Inter); `DesktopEditor.qml:44-45` (`"DejaVu Sans Mono"`); `LoginSequence.qml:125-139, 204-208`; `PressMark.qml:32`.
  - Sizes off the scale: `DesktopMenu.qml:18` (17 / 19); `DesktopEditor.qml:46-48` (30 / 17 / 13). The scale is 12 · 15 · 16 · 26 · 34 · 42 · 72.
  - Controls: `DesktopEditor.qml:133-160`, two `Rectangle`s with a `TapHandler`: no hover, press, focus ring or disabled look.
- **What's wrong:** these surfaces don't use the vocabulary the island and panel use. Only the accent follows the theme (fixed on 24 Nov); the plates, rules, text and paper stay the study's own. Hover and selection are the same thing, there's no press state, and nothing plays the click sound (`Feedback.play`: 0 uses in `view/widgets/`, `view/lock/`, `view/selector/`). There are four different hairline greys (`#464952`, `#60616a`, `#777479`, `#858489`) where the rest of the shell uses one `Design.line`.
- **Evidence:** grep counts per folder (shared parts used in `view/widgets`, `view/lock`, `view/selector`: none). Renders `frames/desktop/menu-open-angular-0000.png` and `editor-open-fluid-0320.png`: the Margin panel is a bright lilac sheet that ignores the Mocha palette.
- **Fix:** a `DesktopLook` beside `LockLook`, mapping the study's paper, stock, quiet and rule onto `Design` roles (`surface`, `hover`, `ink`, `muted`, `line`, `islandFill`), with fonts from `Design.sans` / `FluidTokens.sans` and sizes from the scale. Keep Z86's shapes (Angular's clipped band, Fluid's curved rail). Editor buttons become `FButton` / `FluidButton`. Menu rows get `FMenuItem`'s behaviour (S5). The Day index's fixed cream and charcoal read well on both wallpapers (`frames/desktop/clock-angular-*`); keeping them is fine, see *Leave alone*.
- **Tag:** Astra. **Size:** M.

### F3 · The Fluid clock and the Fluid editor nearly disappear on a dark wallpaper
- **Where:** Fluid desktop clock and editor. `OffcutFace.qml:15` (the ink is a fixed dark colour, `Words.ink(settings.ink, true)`); `DesktopEditor.qml:192-197, 204, 221-222` (column numbers and marks `#373147`, `#463f60`, `#524567`, `#54496e` on `#16191e`).
- **What's wrong:** dark violet type on a dark desk. You see this every day in Fluid if your wallpaper is dark. Claude B reported it to Astra on 24 Nov (HANDOFF); it's still open.
- **Evidence:** `frames/desktop/clock-fluid-dark.png` (barely legible) vs `clock-fluid-light.png`; `editor-open-fluid-0320.png`.
- **Fix:** let the face's ink default to "auto": chosen against the wallpaper's luminance with the shared contrast helper (S2). The editor's marks use `Design.muted` / `line`.
- **Tag:** Astra. **Size:** S.

### F4 · The desktop menu and the editor have no motion at all
- **Where:** both forms. `DesktopSheet.qml:48-64` (two `Loader`s); `DesktopMenu.qml:94-123` (selection is a Canvas repaint); `DesktopWidgets.qml:139-157` (the window is made and destroyed with the menu).
- **What's wrong:** open, selection moving, close, and editor open and close are all instant. Next to the island, where every change moves, the first thing you touch on the desktop feels unfinished.
- **Evidence:** `frames/desktop/menu-open-{angular,fluid}-0000…0320.png`, `menu-step-*`, `editor-open-*`: every frame in each burst has the same hash (`54d831e6` ×5, `1d076db7` ×5, …).
- **Fix:** open as a Cut from the pointer (`cutDuration(travel, sizeChange, false)` + `Motion.cutIn`; Fluid via S3), with the content cross-fading on `Motion.feedback` after the shape, as the island does. The band (Angular) and the rail highlight (Fluid) slide between rows with `Tween on y`, `Motion.settle`. Close on `cutOut`, keeping the overlay window alive until the fold ends (as `LockHost.leaving` does). Press: `pressIn`/`pressOut` + `Feedback.play("ui.click")`.
- **Tag:** Astra (motion design), Claude B (window lifetime). **Size:** M.

### F5 · Fluid buttons, choices and the Settings index don't react with motion
- **Where:** Fluid, every surface. `view/fluid/FluidButton.qml:27-31` (colour snaps on hover, press and selection; no press offset); `FluidChoice.qml`, `FluidActionRow.qml`, `view/shell/LimbNavigation.qml`, `LimbSwitch.qml` (no `Tween`). Compare `view/ui/FButton.qml:41-55, 103-105` (100 ms wipe, 1 px press) and `SettingsAction.qml:51, 73`, `SettingChip.qml:29`.
- **What's wrong:** in Angular every control answers your pointer with a 100 ms wipe; in Fluid the same control just changes colour. The click sound was added to `FluidButton` after the 17 Nov audit, but the visual answer is still missing.
- **Evidence:** grep (`view/fluid`: 4 `Tween`, all in the star and horizon scenes); `frames/settings-fluid/seq/018-023` identical after a section change, so the Limb ring jumps.
- **Fix:** systemic S1.
- **Tag:** Astra. **Size:** S.

### F6 · Fluid is half a form: five rooms, the panel frame and the Settings list stay Angular
- **Where:** Fluid. Only Home, Media, Performance, Tasks and Timers have a Fluid presentation (`PresentationHost` in `view/rooms/Home.qml:28`, `Timers.qml:29`, `Performance.qml:26`, …). Workspaces, Devices, Clips, Inbox and Codex render the same in both forms. The panel's header, the slanted room title, the 00-09 index, the footer and Settings' palette list (square rows, mono "STUDY" tags) are Angular in Fluid. `Design.qml:9` still says "Only the island reads it so far".
- **What's wrong:** in Fluid you open a rounded island and land in a sharp, condensed, mono panel. A Fluid room sits inside an Angular frame, and one room later you're in a fully Angular room. This is the clearest "two programs" moment in Fluid.
- **Evidence:** `renders/rooms-fluid-Mocha/devices.png`, `notifications.png`, `clipboard.png`, `workspaces.png`, `codex.png` match their Angular versions; `sheets/home.png` shows Fluid Home inside the Angular frame; `frames/settings-fluid/seq/011.png`.
- **Fix:** Z146 says the form toggles "across the whole desktop" and Z153 says FART follows Fluid only once FART // Fluid exists, so this isn't a bug: it's an unfinished plan. You decide the order. Suggested: (1) the panel frame (header, title, index, footer), since it shows in every room; (2) Devices and Inbox, since you act in them; then Clips, Workspaces, Codex.
- **Tag:** **Owner pick** (order), then Astra. **Size:** L.

### F7 · Fluid surfaces each run on their own clock, and Fluid exits slow down instead of speeding up
- **Where:** Fluid. Panel from the island: 560 in / 320 out, literal (`Overlay.qml:57-60`). Settings: `Motion.unfold` 240 / `Motion.fold` 140 with OutCubic both ways (`PreferencesPane.qml:40-43`). Island morph: `Motion.emphasis` 220, OutBack (`IslandSurface.qml:288-291`). Header OSD: `navigate` 140 / `feedback` 100, OutCubic both ways (`FartHeaderOsd.qml:31-34`).
- **What's wrong:** Angular has one rule: every grow and fold comes from `Motion.cutDuration(distance)`, with `cutIn` paired against `cutOut`. That's why Angular hangs together. Fluid has no such rule, so the panel takes 560 ms while Settings, growing a similar distance, takes 240. Leaving uses an "ease out" curve, so exits decelerate and drag.
- **Evidence:** code read (the four sites above); frames `frames/settings-fluid/seq/030-031` (Fluid's close is done within one frame, Angular's takes six).
- **Fix:** systemic S3.
- **Tag:** Astra (values), Claude B (wiring). **Size:** M.

### F8 · Settings pages snap when you switch section
- **Where:** Settings, both forms. `PreferencesPane.qml:127-288` (each section is `visible: root.section === "…"`).
- **What's wrong:** the pane opens and closes with motion, but changing section swaps the page in one frame. Angular's index band tints; Fluid shows no motion at all. Rooms, by contrast, replay `Motion.navigate` (6 px travel, fade from 0.7) on entrance.
- **Evidence:** `frames/settings-angular/seq/017→018` (the new page is complete in the first frame) and `frames/settings-fluid/seq/018-023` (identical).
- **Fix:** replay a `navigate` cue on the page container at each section change (the room entrance's pattern in `Shell.qml`), through S4.
- **Tag:** Astra, Claude B. **Size:** S.

### F9 · One gesture, three menus: desktop, island tray and lock power choice behave differently
- **Where:** `view/widgets/DesktopMenu.qml` (a custom Canvas: pops, selection repaints, no sound); `view/shell/IslandTrayMenu.qml` (`FMenuItem`: wipe, pointer, sound, grows from the island); `view/lock/LockScreen.qml:163-200` (plain `Rectangle`s: pops, hover snaps, text on the accent is `Design.islandFill` whatever the accent, no keyboard).
- **What's wrong:** you open a short list of actions in three places and get three objects, each with its own hover, press, timing and keyboard rules.
- **Evidence:** code read; desktop frames (F4).
- **Fix:** systemic S5: one menu row with `FMenuItem`'s behaviour and two skins (Z86's Angular band, Fluid rail), used by all three.
- **Tag:** Astra (skins), Claude B (lock keyboard). **Size:** M.

### F10 · Fluid's big numbers turn white on a light palette
- **Where:** Fluid Tasks and Performance. `view/ui/RollingDigits.qml:13` (`property color color: "white"`); `view/fluid/FluidTasks.qml:70-76` and `FluidPerformance.qml:66-72, 96-102` don't set a colour (FluidTimers does, at line 141).
- **What's wrong:** the room's one primary reading ("00" open tasks, "25 %" processor, "8.0 GiB") is near-white ExtraLight type on a near-white room. The core's contrast lift can't help, because the colour isn't a palette role.
- **Evidence:** `renders/norm-fluid-Latte/tasks.png` and `performance.png`, rendered with the core's own `normalize()` as live.
- **Fix:** default `RollingDigits.color` to `Design.ink`; the two rooms use `FluidTokens.ink`.
- **Tag:** Claude B. **Size:** S.

### F11 · Labels collide or get cut in Home, Devices and Inbox
- **Where:** both forms (these rooms are shared).
  - Home: the sky band's "MOON 100%" sits across the clock's last digit (`view/rooms/HomeSky.qml:57-65, 169`: label rows avoid each other, not the clock).
  - Devices: the signal map's link name runs over the rings and planet, and "MIC 60 · MU…" is clipped by the planet (`view/rooms/DevicesSky.qml:155`: no elide, no clearance).
  - Inbox: a comet's label is cut at the plot's left edge ("IXTURE") (`view/rooms/InboxComet.qml:21`: centred on the comet, not kept inside).
- **What's wrong:** fixture names are short; real names are longer, so live it gets worse. These are exactly the details that make a screen feel unfinished.
- **Evidence:** `renders/rooms-angular-Mocha/home.png`, `devices.png`, `notifications.png`; crops in `sheets/overlaps.png`, `sheets/overlaps2.png`.
- **Fix:** keep labels inside their plot (clamp x), give the Devices names `elide` plus a clearance ring around the planet, and add the clock's box to Home's label-row obstacles.
- **Tag:** Astra (placement), Claude B (clamping). **Size:** S.

### F12 · The lock's small pop-ups appear without motion
- **Where:** lock, both forms. `LockScreen.qml:116, 129` (lyrics plate, visualiser), `:147, 151` ("> AUTH FAILED", notice), `:163-200` (power choice); `PasswordPlane.qml:76`. In `LockLyrics.qml:84-87`, the current line's colour and weight snap while its scale and fade glide.
- **What's wrong:** the face arrives and leaves well (Z231) and the field shakes, but everything that appears afterwards just pops. The bold/regular switch on the lyric line also changes its width at once.
- **Evidence:** code read (visible flips; no `Cue` in `view/lock/`).
- **Fix:** the appear cue (S4) for the lines and the plate; the power choice through S5 with a Cut. Tween the lyric line's colour on the same 650 ms beat and keep one weight, so the change reads as one event (see §6, the previous shell's lyrics).
- **Tag:** Astra, Claude B. **Size:** S.

### F13 · The same notification moves differently depending on where it lands
- **Where:** `view/shell/FartAlertDrop.qml:30-31` (FART open: `navigate` 140 in, `feedback` 100 out) vs the island's notice (Cut, ≈330 ms in, ≈240 out). The header OSD already uses the Cut in Angular (`FartHeaderOsd.qml:31`).
- **What's wrong:** a notification snaps into the header when FART is open, but grows out of the island when it's closed.
- **Fix:** `FartAlertDrop` takes the header OSD's timing (`cutDuration` in Angular, S3 in Fluid).
- **Tag:** Astra. **Size:** S.

### F14 · Text on the accent follows three private rules, and some places follow none
- **Where:** `view/widgets/ClockWords.js:56-60` (`inkOn`, threshold 0.22, fixed inks); `view/lock/LockLook.qml:21` (`readable`); `core/palette_catalog.py:30-52` (the core lifts text to 4.5:1 against background and surface only). With no rule: `FButton.qml:33, 39` (primary = `Design.background` on `Design.selected`), `FluidButton.qml:29, 35` (`FluidTokens.base` on the accent), `LockScreen.qml:185-193` (`islandFill` on the accent).
- **What's wrong:** on a palette whose accent and background are both light, primary buttons and highlighted rows go unreadable. The core only protects text against the two grounds it knows.
- **Fix:** systemic S2.
- **Tag:** Claude B. **Size:** S.

### F15 · Clocks snap at the minute, while Fluid readings roll
- **Where:** island rest (`IslandRest.qml`, `FText`), Angular Home, Day index, Offcut and the lock show `HH:mm` as plain text; Fluid rooms and the island's OSD use `RollingDigits`.
- **What's wrong:** the same kind of change behaves two ways depending on form and surface.
- **Fix:** `RollingDigits` for every clock and percentage, on one `readout` role (S7). Z146 says "Silent is still", but a roll is event-driven: one short motion per minute, which fits BUDGETS' "0 frames between minute ticks". Whether you want it is your call.
- **Tag:** **Owner pick**, then Claude B. **Size:** S.

### F16 · Desktop menu → Settings lands on the Devices room
- **Where:** `shell.qml:85, 105` (`root.showPanel("devices"); Host.openSettings(section)`).
- **What's wrong:** you right-click near the pointer, the menu vanishes, then the panel unfolds from the island at the top on Devices, and Settings grows over Devices. Three objects and three origins for one choice; the Devices room behind Settings is unrelated to what you asked for.
- **Fix:** open on Home or the last room shown (your pick), and let the menu's fold (F4) run before the panel unfolds, so the hand-over reads as one move.
- **Tag:** **Owner pick** (which room), Claude B. **Size:** S.

### F17 · Motion values written into files instead of named roles
- **Where:**
  - These ignore `Motion.scaled()`, so the harness can't slow them and some don't report as running: `LiveTitle.qml:180, 188, 294` (220 / 200); `HarmonicType.qml:52-54` (700); `LockHost.qml:128, 130` (320 / 1000); `LockScreen.qml:26` (420 / 260).
  - These are scaled, but are still one-off values: `Overlay.qml:58, 60`; `IslandExpansion.qml:350-351`; `CommandLine.qml:298`; `Whisper.qml:35-36`; `RollingDigits.qml:16`; `PerformanceStar.qml:42-43`; `TasksHorizon.qml:20-22`; `CodexKeys.qml:61`; `CodexElements.qml:46`; `AngularMedia.qml:215`; `OrbitSystem.qml:265-268, 779-780`; `Shell.qml:1797-1798`; `LauncherLayout.js:30-32`.
  - `Workspaces.qml:51` uses `Motion.transfer` with OutBack 1.1, while the role is Linear.
- **What's wrong:** each surface tunes its own timing, so neighbours drift apart. The suite can't see it, because `tests/test_contract.py:67` (`RAW_MOTION`) allows a plain `NumberAnimation` with a literal duration, and `tests/test_layout.py:32-37` only catches `pixelSize: <number>`, not a size kept in a property (`labelSize: 19`).
- **Fix:** systemic S7.
- **Tag:** Claude B (tokens, lint), Astra (values). **Size:** M.

### F18 · The capture selector doesn't move
- **Where:** `view/selector/` (0 `Motion` references; 14 fixed colours in `EclipseLook.qml`, `ViewfinderLook.qml`).
- **What's wrong:** the frame, the footer and mode changes appear at once. Region dragging should stay instant; the rest could arrive like the island's faces. Not rendered in this audit (code read only), so treat it as likely rather than confirmed.
- **Fix:** the appear cue (S4) on the footer and the hint; colours through roles.
- **Tag:** Astra. **Size:** S.

### F19 · A disabled button lets the lines behind it show through
- **Where:** `FluidButton.qml:26` (`opacity: enabled ? 1 : 0.5` on the whole control), `FButton.qml:25`, `FMenuItem.qml` (0.45).
- **What's wrong:** in Fluid Media, the disabled "Open player" looks crossed out, because the room's rule runs behind it.
- **Evidence:** `renders/rooms-fluid-Mocha/media.png`.
- **Fix:** dim the label and the outline, not the fill: an opaque fill with `Design.faint` text.
- **Tag:** Astra. **Size:** S.

### F20 · In Fluid, login has no arrival at all
- **Where:** `DesktopWidgets.qml:36`. Z230: "in Fluid (no approved login yet) it does not play".
- **What's wrong:** an Angular login lands into the clock; a Fluid login just shows the desktop. Decided for now, but it's the first seam of your day.
- **Tag:** **Owner pick** (commission a Fluid login from Astra or not). **Size:** M.

### F21 · Light palettes outside the core's lift
- **Where:** `Design.qml:66, 93-110`. With no core selection, the island takes the darkest blue role; on Latte, GitHub Light and Rose Pine Dawn that is the text colour itself, so the clock and title disappear.
- **Evidence:** `frames/island-Latte/rest-*.png`, `island-GitHubLight/*`.
- **Live risk:** low. The core always has a selection (default Amoled Black) and `normalize()` puts the island on the background and lifts the text (`core/palette_catalog.py:44-52`); `frames/island-norm/*` reads fine. But fixtures, tests and any host-palette path see the unguarded version, so reviews of light palettes can mislead.
- **Fix:** the same guard in the view (S2).
- **Tag:** Claude B. **Size:** S.

Already raised by Astra's 17 Nov audit (`codex/cohesion-audit`, `docs/COHESION.md`, not merged) and still open: F5 (in part), F6, F7, F17.

---

## 4. Systemic fixes: one shared change, many findings

| # | Change | Fixes | Owner | Size |
|---|---|---|---|---|
| S1 | **Fluid parts react like Angular parts.** `Tween on color` (and on opacity) with `Motion.feedback` / `Motion.roles.feedback.easing` in `FluidButton`, `FluidChoice`, `FluidActionRow`, `LimbNavigation`, `LimbSwitch`; a press nudge on `Motion.pressIn`/`pressOut`; the Limb ring slides on `Motion.settle`. Same acknowledgement as FButton, Fluid's own shape. | F5, part of F8 | Astra | S |
| S2 | **One contrast helper in `Design`.** `Design.readable(fg, ground)` and `Design.onAccent` / `Design.inkOn(ground)`, mirroring `core/palette_catalog.readable` (4.5:1). Replaces `ClockWords.inkOn`, `LockLook.readable`, FButton/FluidButton primary text, the lock power choice; Offcut's ink and the island's fallback use it; `RollingDigits` defaults to `Design.ink`. | F3, F10, F14, F21, part of F2 | Claude B | S–M |
| S3 | **A Fluid timing rule beside `cutDuration`.** For example `Motion.flowDuration(travel, sizeChange, departing)` with paired easings (`flowIn`: an Out curve; `flowOut`: an In curve, ~0.72 of the arrival, like the Cut). `Overlay`, `PreferencesPane`, `FartHeaderOsd`, `FartAlertDrop`, `IslandSurface` and the desktop menu all use it. | F4 (Fluid), F7, F13 | Astra (values), Claude B | M |
| S4 | **A shared "appear" part.** A small `view/ui` part wrapping a `Cue`: opacity plus `Motion.navigate`'s 6 px travel (Fluid), or a Cut reveal (Angular), with an exit, reduced motion and the activity report built in. Used wherever something now flips `visible:`: Settings pages, lock lines and plate, the desktop clock's arrival, Hide widgets, selector footers. | F1, F8, F12, F18 | Astra (look), Claude B | M |
| S5 | **One menu row, two skins.** `FMenuItem`'s behaviour (Wipe, Pointer, keyboard, `Feedback`) with Z86's Angular band and Fluid rail as skins, plus an open/close on the Cut / S3. Used by the desktop menu, the tray menu and the lock's power choice. | F4, F9, part of F2 | Astra, Claude B | M |
| S6 | **`DesktopLook`** (like `LockLook`): the desktop study's colours, families and sizes mapped once to roles and the scale, read by DesktopMenu, DesktopEditor, MarginPanel, SettingGauge and the faces. | F2, F3 | Astra | M |
| S7 | **Named roles for recurring motion, and lint that can see drift.** Add `readout` (340, OutCubic), `lyric` (650, OutCubic), `arrival`/`leave` (the lock's 420/260), `hold` (1000), `draw` (the launcher's 720/680), `spring` (Rubber) to `Motion.defaults`. Then make `test_contract` reject literal `duration:` numbers outside `view/cues`, and make `test_layout` follow sizes kept in properties. | F15, F17, and stops new drift | Claude B (tokens, tests), Astra (values) | M |

Do S2, S1 and S7 first: they're small, fix the most, and make the rest checkable.

---

## 5. Leave alone (decided, or working well)

- **The island is the model.** Shape and content both move on every event; Angular timing comes from distance (`cutDuration`), entrances and exits pair (`cutIn`/`cutOut`), content waits ~100 ms behind the shape, and every motion level is honoured. Frames: `frames/island/*`. Copy its grammar outward rather than changing it.
- **Angular's panel growth and the orbit room switch** (`Overlay.qml` Cut; `Motion.transfer` 1000 ms, docs/ORBIT.md). They're long, but they're the shell's signature and they're consistent.
- **Island faces leave within a second** (Z200). It can feel abrupt; it's your call.
- **Login → Day index** (Z230): the best seam on the desktop. Don't touch its timing.
- **The lock's arrival and drifting sky** (Z231: 420/260 ms; the lock moves outside Overdrive). Name the values (S7), keep them.
- **The desktop menu opens at the pointer in its own window** (Z229), even though Z157 says everything grows from the island; Z229 is the later, specific decision.
- **Both desktop menu shapes** (Z86, Z229): only their colours, states and motion change, not the band or the rail.
- **The Day index's fixed cream and charcoal plates**: they read well on both dark and light wallpapers (`frames/desktop/clock-angular-*`); only the accent needs to follow the theme, and it already does.
- **Truncated title on the island, no marquee** (Z19).
- **Angular Settings parts** (`SettingChip`, `SettingsAction`, `SettingReadout`): they tween on `Motion.feedback` and are the model for S1.
- **Empty states**: "Space for the sound." (Fluid Media), "Nothing here yet. Type above to add a task." (Fluid Tasks), "Nothing waiting." (Home). Calm, in the voice, never blank.
- **The core's contrast lift** (`core/palette_catalog.py:30-52`): exactly the right rule; S2 extends it to more grounds.

---

## 6. Outside references: what makes them feel finished, and where ZÆTHERION can do the same

### impasto (your October setup; captures from 26–29 Oct, the 29 Oct screencast, its generated themes)

What makes it feel finished:
- **One material.** Desktop tiles, the notch, the launcher, the control centre and the themed apps are the same black plate with one corner radius and the same inner padding. Nothing on screen is a different object.
- **One tile anatomy.** Every tile puts things in the same places: icon top-left in a ring, a small label top-right, one large figure bottom-left, a small caption under it. Your eye learns it once.
- **Shape leads, content follows.** In the screencast (about 43–45 s), the notch widens into a plate and its content fades in a beat later; the control centre arrives as an empty plate and fills on the next frame. Because the notch and the panel are the same plate, there's no seam.
- **Colour discipline** (comments in its btop, spicetify and yazi themes): 13 colours, with the missing ones ramped or derived rather than invented; every colour that carries type "lifted to a minimum contrast against the ground it lands on"; one hairline colour for all chrome; one hue at two weights for related states; "nothing here is a warning" unless it is.

Where ZÆTHERION can do the same, in its own words:
- **Shape leads, content follows** is already the island's grammar. Give it to the desktop menu, Settings pages and the lock's pop-ups (S4, S5).
- **One material per form**: the desktop menu, the editor and the lock's power choice should be the island's plate (`islandFill`, the form's corner), not three study colours (S5, S6).
- **Type lifted against the ground it lands on**: the core already lifts against background and surface. Extend it to the accent, the island and the wallpaper under the desktop clock (S2).
- **One hairline**: the desktop study's four greys become `Design.line` (S6).
- Don't take its tile layout, its black-on-paper look or its widgets. Take the discipline: one object, one anatomy, one rule per job.

### The previous shell's lock and lyrics view (read only; the source in its own folder)

What makes it feel finished:
- **One beat per event.** When the lyric line changes, the scroll, colour, opacity and scale all move on the same 650 ms OutCubic (`reusables/media/LyricsView.qml:191-322`): current line 1.0, neighbours 0.88, the rest 0.80 and dimmer. Nothing moves on its own clock.
- **Every small state moves.** The power controls open by height (340 ms, OutBack) and fade (250 ms); the clock fades and scales; readouts glide (800 ms, OutQuint), but only once the entrance has finished, so numbers don't fight the arrival.
- **Exits are quicker than entrances and use the opposite curve**: arrival on OutBack, unlock on InQuad/InBack in 100–250 ms.

Where ZÆTHERION can do the same:
- `LockLyrics` already shares the 650 ms beat for scroll, scale and fade. Put colour on the same beat and keep one weight (F12).
- The lock's power choice, "> AUTH FAILED" and the lyrics plate should arrive and leave the way the face does (S4, S5).
- Readouts that change during an arrival should wait for the arrival's `Cue.settled` before rolling, everywhere (`RollingDigits` in the island, Fluid rooms).
- Exits in Fluid need the "quicker, opposite curve" rule that Angular's Cut already has (S3).
- Don't copy its layout, names or art.

---

## How this was checked

- **Rooms:** `tools/shots.py` (all ten rooms) in both forms (the harness with `Design.form` set), on Mocha and Latte, and again on Latte through the core's own `normalize()` as live (`renders/norm-*`).
- **Desktop:** a harness that puts `DesktopStage` and `DesktopSheet` in one offscreen window, with frames grabbed at 0, 40, 80, 160 and 320 ms after opening the menu, moving its selection and opening the editor (`frames/desktop/`).
- **Island:** `IslandSurface` at motion level "all", with frames at 0–480 ms across an OSD, a notice and hover, in both forms, on Mocha, Latte and GitHub Light (`frames/island*`).
- **Settings:** `shots.py` stepped at ~40 ms per frame through open, two section switches and close (`frames/settings-*/seq/`).
- **Not rendered:** the lock, the selector, the session card and the launcher (code read only; marked where it matters). Nested Hyprland wasn't needed for these findings. No second-monitor check was made.
- **Grep evidence:** per-folder counts of literal durations, `Easing.`, fixed colours, `visible:`, `Loader`, `Tween`/`Cue`, shared-part use, `Feedback.play` and focus handling, each confirmed by reading the file and, where possible, by a render.
