# Surfaces

Each surface lists its process (**R** = resident, **P** = panel; see [ARCHITECTURE.md](ARCHITECTURE.md)), when it exists, and the decisions behind it.

## 1. Island (R, always present)

- **Window:** layer `Top`, namespace `zaetherion-island`, exclusive zone 36 px.
  - Top or bottom edge; left and right come later (Z18).
  - **Notch mode:** hugs the edge. **Floating mode:** detached with a margin (Z17).
  - Hidden only for fullscreen windows.
- **Shape:** trapezoid with 84° sides (6° off vertical) and the flat edge against the screen (Z64). Fixed width ~420 px at rest (Z66).
- **Fill:** the darkest palette role whose hue is blue, or else the darkest role as is (Z65).
- **Rest content** (Z19, Z67–Z70), left to right:
  - Album art square and truncated title (no marquee), plus a thin line waveform while playing (CAVA lease, only while a player plays).
  - Clock, `HH:mm`, redrawn once a minute.
  - Battery as a −12° bar glyph.
  - Empty slots are hidden (Z124).
- **Hover** (Z20, Z72, Z130): after a 300 ms delay the island widens into **wings**.
  - Left wing: Wi-Fi, BT, volume, mic, caps/num lock, airplane, power profile.
  - Centre: the rest content, plus seconds and battery %.
  - Right wing: weather (icon and °C), then tray icons.
  - Clicking a glyph opens the Devices room (Z132).
  - Tray menus open as a montage dropdown (DBusMenu), navigable by keyboard (Z131).
- **Click:** the panel unfolds from the island. The room follows the top activity (media → Media, timer → Timers), otherwise Home. A second click folds it back (Z134).
- **Long-press ~600 ms:** ignites Overdrive, with the meter filling inside the island (Z119).
- **Keyboard focus:** a bind (chosen at S3) focuses the hover state. Arrows/hjkl move, Enter activates, Esc leaves (Z115).

- **Owner's modules (11 Nov 2026, from daily DMS use):** power button, network (Wi-Fi/Ethernet), notifications, battery, active media. That's all they use; everything else stays out of the rest state. Check the wings against this at S3: the power button and a notification glyph (unread dot) aren't in the lists above yet.
- **Memory on demand (owner, 11 Nov 2026):** memory isn't shown normally. It appears only when it matters: the *Memory pressure* expansion below, or pinned by hand while the owner is doing something memory-heavy, showing where the memory is going (top processes by PSS). Threshold and pin control: OPEN 14.

### Expansions (Z22, Z23, Z71)

The island morphs continuously (width and height, host motion profile with overshoot) and cross-fades its content. When several are due, a fixed priority queue decides; a higher one interrupts and a lower one resumes after:

1. Critical notification
2. Alarm DONE
3. OSD (volume, mic, brightness on change; Z24)
4. Notification
5. Recording, mic/camera in use
6. Charging
7. Track change (~3 s)
8. Timer or session
9. Resting media

| Expansion | Content | Leaves |
|---|---|---|
| Notification (Z33, Z73) | App tag, summary, ≤ 2 body lines, actions, inline reply field, image | 5 s timeout (paused on hover), or swipe/scroll toward the edge. Click opens the app. Always kept in Inbox. |
| OSD | −12° blade meter with level | 1.2 s after the last change |
| Track change | Art, title, artist | ~3 s |
| Timer/session | Countdown and current task; DONE inverts until clicked | On click (DONE) |
| Recording | Signal-coloured timer; stopped by the same keybind (Z105) | When stopped |
| Mic/camera in use | Signal dot at rest; app name on hover (Z74) | When the stream ends |
| Workspace switch | N blades, active highlighted (Z21) | ~0.8 s |
| Memory pressure (owner, 11 Nov 2026) | Used/total bar, then the top 3 processes by PSS; pinnable to stay while working | Pressure falls below the threshold for ~10 s, unless pinned |
| Low battery | Signal plane at 20, 10 and 5%; 5% is critical and passes DND (Z129) | Timeout, or on click |
| Session debrief | Duration, tasks done, streak (Z103) | When dismissed |
| DMS offline/online | `> BACKEND · OFFLINE` / `ONLINE`; affected glyphs greyed (Z123) | Timeout |
| Resident restarted | What crashed, plus a log link (Z127) | When dismissed |
| Polkit | Action, program, password field; exclusive focus (Z25, Z117) | Auth, cancel or deny |
| Overdrive | Signal line on the lower edge, time on hover (Z120); kinetic lyrics replace the title (Z121) | When the lease ends |

## 2. Command line and launcher (R, on demand)

- **Opening:** Super tap and Super+Space. Super+` is kept for FART's command line and the hold-to-ignite (Z26). It grows downward out of the island.
- **Open time:** ≤ 100 ms from key press to typing accepted. Keys typed during creation are buffered. If on-demand creation can't meet that, the launcher is kept warm and the memory cost is reported (Z139).
- **Focus:** exclusive, restored on close (Z117).
- **Tabs:** Apps · Files · Emoji · Clips, switched with Ctrl+1–4 and with prefixes. Tab completes verbs (Z27).
- **Prefixes:** `>` command in the terminal, `?` Brave web search, `=` calculator and unit/currency conversion, `:` clips.
- **Apps tab, matched in this order:** FART verbs (core registry), then apps, then windows, then settings keys.
- **Ranking:** frecency blended with focus time. With nothing typed: the top frecent apps (Z75).
- **Size:** 6 rows, ~600 px wide.
- **Rows** (Z29): a slanted −12° selection blade, icon, bold name and faint mono description. The selected row cuts in from the left.
- **Files** (Z78): a `fartd` index of home. It excludes caches, `.git`, `node_modules` and dot-folders other than `.config`. Kept current by inotify, with a periodic-walk fallback if watches run out (Z94).
- **Emoji:** read at runtime from Serpantinum's data (Z31); degraded per Z125.
- **Clips:** DMS clipboard history. Thumbnails are decoded only for visible rows (Z79).
- **Currency:** rates fetched at most once a day, cached (Z80).
- **Window results:** focus, close, move to workspace, float, fullscreen, pin (Z77).
- **During a Session:** blocklisted apps show `> BLOCKED · SESSION` (Z102).

## 3. Panel (P, disposable)

- FART's rooms, unfolding from the island. Size 1360×860 (Z133).
- **Outline:** one continuous shape. Navy shoulders at 84° form the top band; the body is theme surface plus blur.
- **Closes on** a second island click, Esc or an outside click (Z134).
- **Rooms:**

  | Room | Contents in ZÆTHERION |
  |---|---|
  | Home | Clock, calendar (task due marks and local `.ics` files, paths set in settings; Z99), today strip, weather and forecast (Z45), actions |
  | Media | As in FART-next. EQ is ZÆTHERION's own PipeWire filter-chain (Z50) |
  | Performance | DMS `dgop` data; the Ollama/AI block is kept (Z100) |
  | Workspaces | The same orbit overview component as Super+Tab (Z76, Z97) |
  | Devices | Quick only: toggles, quick connect, volume, brightness, power profile (Z95) |
  | Tasks | As in FART-next |
  | Timers | As in FART-next |
  | Clips | Kept alongside the launcher tab (Z96) |
  | Inbox | The notification authority; actions work only while the app listens (Z101) |

- **Updates:** a count from DMS `sysupdate`. The action opens a terminal running the configured command, `yay` by default (Z98).
- **Crash limit:** after 3 crashes in 5 s, clicking the island shows `> PANEL · HALTED` with a retry (Z128).

## 4. Settings window (P, on demand)

- A normal Hyprland application window (Z91). The panel is not reaped while it is open.
- **Layout:** a 78° diagonal index with search at the top. Changes apply instantly (Z92).
- **Tabs** (Z93): Display · Theme · Wallpaper · Island · Widgets · Launcher · Notifications · Network & Bluetooth · Audio/EQ · Idle · Lock · Capture · Wellbeing · Overdrive · Sessions & Timers · Keybinds (editable) · About.
  - Keybinds rewrites the ZÆTHERION keybind file, reloads Hyprland, and rolls back automatically on `configerrors` (Z94).
  - About lists missing Serpantinum assets (Z125).
- **UI scale:** 0.9–1.5 (Z118). **Motion level:** OFF / MINIMAL / REDUCED / ALL (Z116). **Voice:** system / plain (Z53).

## 5. Overview (P, Super+Tab)

- The FART orbit overview (Z76).
  - Silent: geometry miniatures.
  - Overdrive: live thumbnails and lensing (Z57).
- Window actions per Z77.

## 6. Wallpaper (R, layer `Background`, every screen)

- **Modes** (Z40): *image* and *sky*, switchable.
- **Image mode** (Z41):
  - Folder `~/Pictures/Wallpapers` (Z84). It's the folder Serpantinum already uses, so nothing is copied (Z137).
  - Picker with favourites and history; online search.
  - Transition: a montage wipe of staggered slanted planes (Z82).
  - Video wallpapers pause when covered and show a still frame on battery (Z140).
  - **Cuts** are a toggle: 2–3 slanted bands at 78°, adjustable per wallpaper, with the sky showing through (Z81).
- **Sky mode** (Z42, Z83):
  - Night: a star chart with stars to about magnitude 5, faint constellation lines, an alt-az grid, labelled planets and the Moon with its phase.
  - Day: a gradient by Sun altitude.
  - Redrawn at most once a minute in Silent, and only when something visible changed.
- **Palette pipeline:** changing the wallpaper runs Matugen, which updates the palette and runs the owner's Matugen templates (Z44). The presets are read at runtime (Z43).

## 7. Widgets (R, layer `Bottom`, primary screen)

- **Kinds** (Z46): clock and sky, music and lyrics, notes, text, image.
- **Look:** island-coloured montage planes (Z85).
- **Visibility:** unloaded whenever the active workspace has any window, and rebuilt when it's empty (Z85).
- **Editor:** drag, resize, rotate, snapping to the 12-column grid, per-monitor layouts and presets. Reached from the desktop right-click menu: Edit widgets / Wallpaper / Theme / Settings (Z86).

## 8. Lock (R; surfaces created only when locking)

- **Session lock** on every screen.
- **Title card**, centred (Z87):
  - The slanted `HH:mm` and the full date, over the wallpaper with sky cuts (Z89). Never a screen capture.
  - The password plane under the clock.
  - Bottom band: media controls, battery, power (hold-to-confirm).
- **PAM:** the `serpantinum` service, falling back to `login` if it's missing (Z37, Z125).
- **Wrong password:** a shake (none below REDUCED motion), then `> AUTH FAILED · n`. No attempt limit (Z88).
- **No Overdrive on the lock** (Z57). A sky-layer failure leaves a plain card and never unlocks.
- **Sounds:** lock and unlock play the `switch` cue (Z104).

## 9. Idle (R)

- **Steps** (Z38): dim 150 s → lock 300 s → screen off 450 s → suspend 600 s.
- **Inhibited by** playing media and by app inhibitors (via DMS's ScreenSaver events).
- **Lock before sleep:** via DMS `loginctl`.
- **Caffeine:** a toggle.

## 10. Session card (R, Ctrl+Alt+Del)

- Six slanted blades: Lock · Suspend · Hibernate · Log out · Reboot · Power off. Keys 1–6 (Z39, Z90).
- The last four are hold-to-confirm, using the ignite hold.
- Hibernate is shown only when logind reports `CanHibernate=yes`.
- Every action is also a verb.

## 11. Capture and draw (R, on demand)

- **Capture** (Z48, Z105):
  - A Serpantinum-like frozen-screen selector in ZÆTHERION colours: region, window or screen.
  - Outputs: screenshot to clipboard and/or file, satty for editing, OCR (tesseract), QR (zbarimg), and recording with gpu-screen-recorder (sound and mic).
  - Snip-to-search is kept.
- **Draw** (Z106):
  - Annotate over a frozen screen, or use a blank canvas.
  - Pen, highlighter, shapes and text in palette colours, with undo/redo.
  - Save to `~/Pictures` or copy.
- **Edge hover:** the right edge slides out a plane with Calculator and Draw (Z107).

## 12. Boot sequence (R, once per login)

- About 1.5 s of fixed flavour lines in the system voice, typed on, then the ZÆTHERION title cuts in.
- Skippable by any key. The lines are drafted for the owner's approval and stored as a data file (Z55, Z108).
- With the voice set to plain: the title card only.
- Plays the `start` sound (Z104).
- A discovery whisper may appear (Z63).

## 13. Sessions, shell-wide (Z102, Z103, Z116)

During a study Session:
- The island shows only the countdown and the current task.
- Blocklisted apps are refused. The starter set is Steam, Discord and game launchers; it is editable.
- Widgets unload.
- The wallpaper switches to sky mode.
- DND is forced and motion goes to MINIMAL.

Everything is restored when the session ends.

## 14. Sounds (Z54, Z104)

Read at runtime from Serpantinum's files and gated by mute, DND and Sessions (D19). If the files are missing, playback is silent.

| Event | Sound |
|---|---|
| Notification | Serpantinum's notification sound (configurable) |
| Alarm | freedesktop `alarm-clock-elapsed` |
| Island/launcher UI | click, switch, toggle, input |
| Network/BT | connect, disconnect, power on, power off |
| Boot | start |
| Lock/unlock | switch |
