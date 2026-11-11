# Decisions

Every decision below was made by the project owner during the planning session of 8 November 2026, in answer to explicit questions. Nothing here is a default chosen by an implementer. If something is not covered here or in [OPEN.md](OPEN.md), it is an open question for the owner, not something to assume.

ZÆTHERION inherits FART-next's D-series decisions (D1–D23) except where [Inherited decisions that change](#inherited-decisions-that-change) says otherwise.

### Project
| # | Decision |
|---|---|
| Z1 | Starts once FART-next's Overdrive is far enough along, **around M12**. This replaces "after all of FART-next". *Reached:* by 10 November 2026 FART-next had built all of its M0–M16, plus the heavy layer on the NVIDIA card. |
| Z2 | Repo at `~/src/zaetherion-shell`. A **fresh git repo**, seeded by copying from fart-next at a tagged commit, with the seed commit recorded in NOTICE. |
| Z3 | Licence **GPL-3.0**, inherited. DMS-derived files keep their MIT notice ("Copyright (c) 2025 Avenge Media LLC") in NOTICE. |
| Z4 | **Hyprland first.** Previously niri was first; niri comes later. |
| Z5 | Coexistence: a separate **SDDM session**, "Hyprland (ZÆTHERION)". Serpantinum's session stays untouched until it is retired. |
| Z6 | After ZÆTHERION passes its daily-drive trial, the Serpantinum session and FART-next are **retired**. Until then FART-next stays the rollback. |
| Z7 | The planning output becomes a **public GitHub repo `ABRDXD/zaetherion-shell`** holding design docs only (no code). GitHub milestones and issues mirror the S-milestones.  |

### Backend and processes
| # | Decision |
|---|---|
| Z8 | **DMS owns everything it offers**: network (NM/iwd), Bluetooth with a pairing agent, brightness/DDC, clipboard, `wayland.gamma` night light, outputs/DPMS, logind, dgop stats, weather, location and lyrics. Quickshell built-ins cover only what DMS does in QML: audio (Pipewire), notifications server, lock/PAM, idle, polkit, MPRIS, UPower and the tray. |
| Z9 | Package **`dux-shell` from Arch's `extra` repository** (changed 10 November 2026: the owner installed `dux-shell` 2.1.0-1, not `dux-shell-git`). Pin the accepted `apiVersion` range (40 at research time; recheck against 2.1.0 when the fixtures are recorded in S0). **Decided 11 November 2026:** a DMS newer than the checked API version keeps working, with a note in Settings; an older one is switched off. |
| Z10 | DMS is launched as **`dms run -c <zaetherion resident UI dir>`**. DMS runs its backend, then starts ZÆTHERION's resident Quickshell as its child and passes it `DMS_SOCKET`. |
| Z11 | When DMS is down: **degrade and restart.** `fartd` restarts it with backoff, and affected controls show OFFLINE in the system voice. |
| Z12 | **Two Quickshell processes.** The resident one is always alive and holds the island, wallpaper, widgets, notifications, OSD, lock, idle and polkit. The panel is disposable and reaped (rooms, settings window, overview). |
| Z13 | **Hyprland autostart only** (no systemd units). The ZÆTHERION `autostart.lua` runs `zaetherion start`. |
| Z14 | Clipboard: import the existing cliphist history once with DMS `clipboard.import`. The ZÆTHERION session starts no cliphist watchers; Serpantinum's session keeps them. |
| Z15 | Night light: **DMS `wayland.gamma`**, scheduled from DMS location. |
| Z16 | Location: the **DMS location service**, which does an IP lookup over the network. It feeds the sky, night light and weather. |

### The island (spine)
| # | Decision |
|---|---|
| Z17 | The bar is a **dynamic island**. At rest it is **hugged to the edge like a notch**, switchable to a **floating** island. Height **36 px**. It reserves its space and **hides only for fullscreen windows**. |
| Z18 | Edges: the design allows top, bottom, left and right. **Top and bottom ship first**; left and right come in a later milestone. |
| Z19 | **At rest:** the clock in the centre, now-playing media, battery, and a visualiser that always runs while music plays (CAVA). |
| Z20 | **Hover** expands the island to show every status glyph (Wi-Fi, BT, volume, mic, caps/num lock, airplane, power profile, weather) and the **system tray**. **Clicking unfolds the full control panel** from the island. These are two distinct gestures. |
| Z21 | **Workspaces** appear only while switching: the island briefly expands into the blades for N workspaces. N is fixed and configurable. |
| Z22 | **Expansion triggers:** track change and playback, timers, sessions and alarms, notifications, OSD, recording, mic or camera in use, and charging. |
| Z23 | Several events are resolved by a **fixed priority queue**: critical notification > alarm DONE > OSD > notification > recording/mic/camera > charging > track change > timer/session > resting media. A higher event interrupts and a lower one resumes after it. |
| Z24 | **OSD:** volume, mic and brightness expand the island when they change. Caps/num lock, airplane and power profile show only in the hover view. |
| Z25 | **Polkit** authentication grows out of the island. |

### Launcher and overview
| # | Decision |
|---|---|
| Z26 | Super tap and Super+Space open the command line, which **grows out of the island**. Super+` keeps the FART command line and hold-to-ignite. |
| Z27 | **Tabs:** Apps · Files · Emoji · Clips, switched with Ctrl+1–4 and with prefixes. Tab stays as verb completion. FART verbs, calc and unit conversion, web search and `>cmd` appear inline in Apps when the input matches. |
| Z28 | Coverage is everything Serpantinum has: apps (frecency), files, emoji, `>cmd` in the terminal, `?term` via **Brave**, the calculator and unit/currency converters, plus windows and FART verbs. |
| Z29 | **Montage rows:** a slanted −12° selection blade, icon, bold name and faint mono description. The selected row cuts in from the left. |
| Z30 | **Super+Tab** opens the montage **overview**: geometry miniatures in Silent, live thumbnails in Overdrive. |
| Z31 | Emoji data is read at runtime from Serpantinum's `EmojiData.js` and not copied. The tab is empty if Serpantinum is removed (see Z125 for the degraded behaviour). |

### Notifications
| # | Decision |
|---|---|
| Z32 | ZÆTHERION is the notification server. History is **persisted for 24 h**, max 100 items, file mode 0600, and the private-apps list is never stored. |
| Z33 | Supports action buttons, inline reply, images and a sound per notification. |
| Z34 | DND is on/off plus Sessions forcing it; critical notifications always pass. |

### Lock, idle and power
| # | Decision |
|---|---|
| Z35 | **ZÆTHERION's own lock only**, with no fallback locker. |
| Z36 | Lock contents: a title card with clock, live sky and date; media controls; battery; power buttons (hold-to-confirm). |
| Z37 | PAM: reuse the existing **`serpantinum`** service. It tries pam_fprintd, which is not installed and is marked optional (`-auth`), then system-auth. |
| Z38 | Idle values kept exactly: dim 150 s → lock 300 s → screen off 450 s → suspend 600 s. Playing media inhibits; app inhibitors are respected; the screen locks before sleep; the caffeine toggle stays. |
| Z39 | **Session card** on Ctrl+Alt+Del: lock, suspend, hibernate, reboot, power off, log out. Destructive actions are hold-to-confirm, and each is also a verb. |

### Wallpaper, sky, theme
| # | Decision |
|---|---|
| Z40 | Wallpaper has **two switchable modes**: *image* (the owner's images cut into montage planes, with the real sky showing through the cuts) and *sky* (procedural). |
| Z41 | Image mode keeps nearly all of Serpantinum's engine: the picker, favourites and history, transitions (montage-style), **video wallpapers**, and online search. |
| Z42 | Sky content: bright stars down to about magnitude 5 from a bundled catalogue, plus Sun, Moon with its phase, the naked-eye planets and the local horizon. |
| Z43 | Palette: **Serpantinum's 96 presets plus Matugen, read at runtime** from Serpantinum's install, not copied. |
| Z44 | App theming: ZÆTHERION **runs the existing `~/.config/matugen` templates** (GTK3/4, KDE, Hyprland, hyprlock, fuzzel) when the palette changes, and kitty and others get templates added later. |
| Z45 | **Weather** from DMS, shown in the island's hover view and on Home with the forecast. |

### Features kept or dropped from Serpantinum
| # | Decision |
|---|---|
| Z46 | **Dock dropped. Widgets kept**: clock and sky, music and lyrics, notes, text and image. The editor works like Serpantinum's (drag, resize, rotate, per-monitor layouts and presets), snapping to the 12-column grid. |
| Z47 | Quick actions kept: calculator and converters (in the launcher), **Draw**, and the **edge-hover trigger**. Dropped: the quick-actions timer (FART has Timers), system usage (Performance room), notes (now a widget) and the mini dock. |
| Z48 | **All capture features kept:** region, full and monitor screenshots with a frozen-screen selector; satty editor; recording with gpu-screen-recorder (sound and mic); OCR with tesseract; QR with zbarimg; snip-to-search. |
| Z49 | Settings live in a **separate settings window**, like Serpantinum's, and every setting is also reachable as a verb. |
| Z50 | **EQ:** ZÆTHERION's own **PipeWire filter-chain** (10 biquads). No closed `serpantinum-audio` binary. |
| Z51 | **Wellbeing:** DMS `wellbeing` versus `focus_daemon.py`, settled by a side-by-side test on low cost, keeping the owner's history, and accuracy (see OPEN.md). |

### Identity
| # | Decision |
|---|---|
| Z52 | Typefaces: **Inter Display** for display text and **JetBrains Mono** for the system voice and readouts. No bundled font. **S3 mock-up review, 11 November 2026:** the owner chose **Roboto Condensed**, matching the built FART panel, for the island mock-ups. At S3 implementation review the owner confirmed **Roboto Condensed for the Angular island clock**. |
| Z53 | The NieR-style **system voice is a toggle**: `system` (terse uppercase log lines) or `plain`. |
| Z54 | Sounds: **Serpantinum's sounds, read at runtime.** If they're missing, playback is silent. |
| Z55 | A **boot sequence at every login**: about 1.5 s of type-on system log, skippable by any key, and off under reduced motion. |
| Z56 | English only, but every string goes through one table so translations can be added later. |
| Z57 | Overdrive animates the **sky wallpaper, the island (kinetic lyrics, richer cut-ins), and the launcher and overview (lensing, live thumbnails)**. The lock screen is never animated by Overdrive. |
| Z58 | Monitors: **primary plus basics.** The island and widgets go on the primary screen; the wallpaper and lock cover every screen; hotplug is handled. |
| Z59 | Keybinds: **same keys plus new ones.** A ZÆTHERION copy of `keybinds.lua` keeps every key, retargeted from `serpantinum …` to `zaetherion …`; app binds are unchanged. The owner approves each new bind (overview, ignite, widget editor, draw). |
| Z60 | Memory budget: **ZÆTHERION total (resident + panel + fartd + dms) ≤ Serpantinum + FART-next today**, re-measured quietly before S0. |
| Z61 | Originality guardrail: take principles from Persona and NieR:Automata, never their assets. That excludes their names, logos, fonts, art, sound and copied layouts. |

### Round 2 (8 Nov 2026)
| # | Decision |
|---|---|
| Z62 | **ZÆTHERION brings FART over; it doesn't rebuild it** (changed 10 November 2026). FART-next built M13–M16 itself after all (lensing, the contact sheet with live previews, discovery and the archive, the T2/T3 tiers), along with M11 sessions and the heavy layer, so they all arrive with the S0 seed. S11 then extends them to ZÆTHERION's own surfaces (the island, the launcher, the overview, the lock card); shell-wide discovery whispers still come after S12. Nothing is built twice. |
| Z63 | **Discovery whispers are shell-wide**: one faint line for about 1 s, which may appear on the island, the lock card or the boot sequence. Horror stays in the archive only (D10). |
| Z64 | **Island shape:** a trapezoid notch with **84°** sides (6° off vertical) and a flat edge against the screen. |
| Z65 | **Island fill:** a theme-derived navy, recalling the HP Victus 15 "Performance Blue" chassis. Rule: use the darkest palette role whose hue is blue. If the theme has no blue role, use the **darkest role as is**. |
| Z66 | **Island width:** fixed at about 420 px. Contents rearrange inside it, and expansions morph beyond it. |
| Z67 | **Clock:** `HH:mm`, redrawn once a minute. Seconds show only on hover. |
| Z68 | **Battery:** a slanted −12° bar glyph, with the percentage on hover. |
| Z69 | **Media at rest:** a tiny album-art square plus a truncated title. There is no marquee. |
| Z70 | **Visualiser:** a thin **line waveform**. |
| Z71 | **Expansion motion:** a continuous **morph** of width and height (host motion profile, overshoot) with contents cross-fading. Overdrive adds the extras listed in Z57. |
| Z72 | **Hover delay:** 300 ms. |
| Z73 | **Notifications:** clicking one opens the app (default action) and shrinks the island. It leaves after a 5 s timeout, which hover pauses, or on a swipe or scroll toward the edge. It always stays in the Inbox. |
| Z74 | **Mic or camera in use:** a signal-coloured dot on the island, with the app's name on hover. |
| Z75 | **Launcher ranking:** frecency blended with focus time from whichever wellbeing source wins (Z51). With nothing typed, it shows the top frecent apps. It shows 6 rows at about 600 px wide. |
| Z76 | **Super+Tab** opens the **FART orbit overview** (the m6-design 3D orbit Workspaces overview). |
| Z77 | **Window actions** from the overview and launcher: focus, close, move to workspace, float, fullscreen, pin. |
| Z78 | **Files tab:** a `fartd` index of the whole home folder, excluding caches, `.git`, `node_modules` and dot-folders except `.config`. It's updated by inotify, with a fallback to a periodic walk if the inotify watch limit is hit. |
| Z79 | **Clips:** image thumbnails, decoded only for visible rows. |
| Z80 | **Currency rates:** fetched at most once a day, only when a currency query is typed, and cached for offline use. |
| Z81 | **Wallpaper cuts:** a toggle. When on, 2–3 **slanted bands at 78°**, adjustable per wallpaper in the picker. |
| Z82 | **Wallpaper transition:** a **montage wipe**, where the new image slides in as staggered slanted planes. |
| Z83 | **Sky style:** a **star chart at night** (ink ground, stars sized by magnitude, faint constellation lines, alt-az grid, labelled planets) and a **gradient by sun altitude during the day**. |
| Z84 | **Wallpaper folder:** `~/Pictures/Wallpapers`, changeable in settings. |
| Z85 | **Widgets:** island-coloured **montage planes**. They are **unloaded** (Loader inactive, objects destroyed) whenever the active workspace has any window, to save RAM, and rebuilt when it's empty. |
| Z86 | **Widget editor:** reached from the **desktop right-click menu**: Edit widgets, Wallpaper, Theme, Settings. |
| Z87 | **Lock layout:** a **centred title card**. The slanted clock and the date are centred over the sky, with the password plane under them. Media, battery and power sit on the bottom band. |
| Z88 | **Wrong password:** the field shakes (no shake under reduced motion) and a line reads `> AUTH FAILED · n`. There is no attempt limit. |
| Z89 | **Lock background:** the current **wallpaper with sky cuts**, never a screen capture. |
| Z90 | **Session card:** six slanted blades: Lock · Suspend · Hibernate · Log out · Reboot · Power off. Keys 1–6. The last four are hold-to-confirm. Hibernate shows only when logind reports `CanHibernate=yes`. |
| Z91 | **Settings window:** a normal Hyprland application window (tiled or floating, reachable by alt-tab). Navigation is a **78° diagonal index** with search at the top. The panel process is not reaped while this window is open. |
| Z92 | **Settings apply instantly**, including display changes, by the owner's choice (see RISKS.md). |
| Z93 | **Settings tabs:** Display, Theme, Wallpaper, Island, Widgets, Launcher, Notifications, Network & Bluetooth (VPN, hotspot, pairing through DMS), Audio/EQ, Idle, Lock, Capture, Wellbeing, Overdrive (tiers, guards, lease defaults), Sessions & Timers, **Keybinds (editable**: writes the ZÆTHERION keybinds file, then reloads Hyprland), About. |

### Round 3 (8 Nov 2026)
| # | Decision |
|---|---|
| Z94 | **Safety mitigations kept:** the `zaetherion display reset` verb (its keybind needs owner's approval); the keybind-edit rollback on `configerrors`; the file-index walk fallback. |
| Z95 | **Devices room** handles the quick things: toggles, quick connect, volume and brightness, power profile. Pairing, VPN, hotspot and passwords live in settings. |
| Z96 | **Clips:** both the room (browse, pins) and the launcher tab (quick paste) stay. |
| Z97 | **Workspaces room = the Super+Tab overview:** one component with two entry points. Super+Tab opens it without the panel. |
| Z98 | **Updates:** the count comes from DMS `sysupdate`. The action opens a terminal running the update command, which is configurable and defaults to `yay`; the password is typed there. |
| Z99 | **Home calendar:** task due marks plus **local `.ics` files** whose paths are set in settings. No network. |
| Z100 | **Performance room:** data from **DMS `dgop`**. The Ollama/AI block stays FART's own. |
| Z101 | **Inbox:** action buttons work only while the sending app is still listening. Otherwise they are greyed out with a system line. |
| Z102 | **During a Session:** the island shows only the countdown and current task, and media shrinks to a glyph. The launcher blocks apps on the preset's **blocklist** (starter set: Steam, Discord, game launchers; editable) with `> BLOCKED · SESSION`. Widgets unload, and the wallpaper switches to sky mode, restored afterwards. |
| Z103 | **Session debrief:** an island expansion until dismissed. It appears on the lock card if the session ends while the screen is locked. |
| Z104 | **Sound events,** read from Serpantinum's files at runtime: notifications (`notifications/Progress`, configurable) and alarms (freedesktop `alarm-clock-elapsed`); island and launcher UI (`reusables` click, switch, toggle and input); network/BT (`network/connect`, `disconnect`, `power_on`, `power_off`); boot (`Start/start`); lock and unlock (`reusables` switch). All are gated by D19. |
| Z105 | **Capture selector:** **Serpantinum-like** behaviour and controls, in ZÆTHERION's colours. **Recording:** a timer on the island; the same keybind stops it. |
| Z106 | **Draw:** annotate over a frozen screen, or a blank canvas. Tools: pen, highlighter, shapes and text, with palette colours and undo/redo. Save to `~/Pictures` or copy to the clipboard. |
| Z107 | **Edge hover:** the **right edge** slides out a plane with Calculator and Draw. |
| Z108 | **Boot text:** fixed flavour lines. About 6 original lines in the system voice, with no game quotes, for owner's approval; they're stored as a data file. With voice set to `plain`, boot shows **only the title card**. |
| Z109 | **Security testing:** a **nested Hyprland** test compositor plus fixtures, including a fake PAM. Lock and polkit are tested in the real session only with the owner present. Whether Hyprland runs nested is verified in S1. |
| Z110 | **Trial logging:** a `zaetherion trial note <text>` verb, plus automatic entries for crashes, DMS restarts and session switches, with a daily summary in HANDOFF. |
| Z111 | **Serpantinum retirement (S12):** keep only the Serpantinum files ZÆTHERION uses (presets, sounds, emoji, the PAM file) and delete the rest. Each deletion is listed and approved by the owner at that time. |
| Z112 | **Retirement gate (all required):** 7 trial days with 0 unplanned fallbacks in the last 3; every PARITY.md row kept, replaced or dropped, with the kept ones working; budgets passing in quiet measurement; rollback to the Serpantinum session rehearsed once. |
| Z113 | **DMS fixtures are scrubbed before commit.** SSIDs, MACs, device names, clipboard entries and location become placeholders, and a test fails if a raw value leaks. |
| Z114 | **Workflow is the same as fart-next:** AGENTS.md rules (approval scope, no actuation for visual tests, measure before claiming), HANDOFF at checkpoints, and issues closed per acceptance item. |

### Round 4 (8 Nov 2026)
| # | Decision |
|---|---|
| Z115 | **Island keyboard focus:** **Super+Shift+I**, chosen by the owner at S3 after checking `hyprctl binds`, gives the hover state keyboard focus. Arrows or hjkl move across glyphs, tray items and actions; Enter activates; Esc leaves. |
| Z116 | **Motion setting with four levels.** **OFF:** no animation, instant changes. **MINIMAL:** short opacity fades only (≤120 ms). **REDUCED:** morphs and slides without overshoot; no shake, type-on, wipes or glitch; Overdrive shaders off. **ALL:** everything, including Overdrive effects when ignited. The default is **ALL**, and **Sessions set it to MINIMAL** for their duration. |
| Z117 | **Focus:** the launcher and polkit take **exclusive** keyboard focus, and focus returns to the previous window on close. |
| Z118 | **UI scale:** a setting from 0.9 to 1.5 that multiplies all ZÆTHERION text and hit areas. |
| Z119 | **Overdrive ignition:** hold Super+` about 600 ms, **long-press the island** about 600 ms (the meter fills inside the island), or the `overdrive 20m\|sticky` verb (kept). |
| Z120 | **An active lease** shows as a thin signal line along the island's lower edge, and hover shows the time remaining. |
| Z121 | **Overdrive on the island:** **kinetic lyrics** replace the truncated title while music plays and lyrics exist. |
| Z122 | **Battery guard:** Overdrive suspends on battery and resumes on AC, as in D4. |
| Z123 | **DMS offline:** an island expansion each time it goes down and each time it comes back; the affected glyphs are greyed in the meantime. |
| Z124 | **Empty states:** the slot is hidden. No player means no media slot; no battery means no glyph. The clock stays centred. |
| Z125 | **A missing Serpantinum file degrades:** presets fall back to Matugen or defaults, sounds go silent, the emoji tab shows a line instead of results, and PAM falls back to the `login` service. The About tab lists what is missing. |
| Z126 | **No network:** the Wi-Fi glyph is crossed out. Weather, currency, lyrics and online wallpaper search use their caches and say so (`CACHED · 3h`). Web search still opens the browser. |
| Z127 | **Resident crash while unlocked:** it is restarted, and the restart shows a **full notice**: an expansion saying what crashed, with a link to the log. The crash goes into the trial log. |
| Z128 | **Panel crash limit reached:** clicking the island shows `> PANEL · HALTED` with a retry action. The resident surfaces keep working. |
| Z129 | **Low battery:** island expansions at 20%, 10% and 5%. The 5% one is critical and passes DND. |

### Round 5 (8 Nov 2026)
| # | Decision |
|---|---|
| Z130 | **Hover layout: "wings".** The island widens sideways in one row. Glyphs (Wi-Fi, BT, volume, mic, caps/num, airplane, profile) grow out on the left wing; weather (icon + °C) and tray icons on the right wing. The centre shows the resting content plus seconds and battery %. |
| Z131 | **Tray menus** are a **montage dropdown** from the island (DBusMenu), navigable by keyboard. |
| Z132 | **Clicking a hover glyph** unfolds the panel at the Devices room. |
| Z133 | **The panel continues the notch.** Navy shoulders form the top band, and the body is theme surface + blur, inside one continuous outline with 84° shoulders. Size is **1360×860**. |
| Z134 | **Panel closes** on a second click of the island (it folds back into the notch), on Esc, or on an outside click. |
| Z135 | **Migrated from FART-next on first start** (copied; originals untouched; existing destination files win): `tasks.json`, `timers.json`, `settings.json`, `preferences.json`, `notifications.json`, `history.json`, `overdrive.json`, the lyrics cache and the Home portrait. **Not migrated:** sessions, streaks and discovery, which start fresh. |
| Z136 | **Imported once from Serpantinum** (copies only): launcher frecency (`launch_stats.json`), wallpaper favourites and history, the notification position and sound file, and wellbeing history (`focustime.db`, imported into the winning source per Z51). |
| Z137 | **Wallpapers:** Serpantinum's `wallpaperDir` is already `~/Pictures/Wallpapers` (106 files, 632 MiB), so **nothing is copied**. Both shells share the folder. |

### Round 6 (8 Nov 2026)
| # | Decision |
|---|---|
| Z138 | **Loaded at rest in the resident process:** the island (rest state), the wallpaper layer, the notification server, idle monitors, the polkit agent, the lock *definition* (its surfaces are created only when locking) and the tray. **Created on demand and destroyed afterwards:** launcher, OSD, capture, draw, session card, widgets (while covered), boot. |
| Z139 | **Launcher open ≤ 100 ms** from key press to typing accepted. Keys typed during creation are buffered, never lost. If it can't meet that on demand, it is **kept warm** and the memory cost is reported. This replaces an earlier "≤ 1 frame warm" draft. |
| Z140 | **Video wallpaper:** paused when covered, and shown as a **still frame on battery**. |
| Z141 | **Per-surface budgets.** Each of these gets a measured delta and a limit, enforced by a `check-budgets` gate: island rest, island hover, launcher open, widgets loaded, video wallpaper, lock, overview. The limits are set from measurements at the milestone that builds each surface. |
| Z142 | **Panel reap timer:** chosen at **S2** by measuring cold-open cost against held memory (candidates 10 min and 60 min). |

## S3 mock-up review (11 November 2026)

| # | Decision |
|---|---|
| Z143 | The island's **power glyph opens the session card**; its **notification glyph opens Inbox**. The owner confirmed these destinations during step 1. No implementation or approval of the look is implied. |
| Z144 | **Approved S3 island look.** Keep the Angular mock-up with the continuous navy trapezoid, fixed lighting and shallow 4 px bevel. Use the inverted app tag shown in the main notification. The island widens into wings and deepens for events within the same outline. See [the approved study](ui/island-s3-review.svg). |

## Future FARTland // Fluid

| # | Decision |
|---|---|
| Z145 | **Approved Fluid island look.** A compact matte navy notch attaches to the screen edge, with rounded corners and a subtle 3 px underside. At rest it shows the clock. While media plays it adds track information and a waveform. On hover it widens to reveal the other controls. See [the approved study](ui/fartland-fluid-study.svg) and [motion preview](ui/fartland-fluid-motion.gif). FARTland // Fluid depends on the future FART // Fluid project. |
| Z146 | **Two separate dials.** **Form** is Angular or Fluid (owner toggles it, across the whole desktop: FART, FARTland and the island). **Mode** is Silent or Overdrive, and those are FART's only two modes. That gives four combinations: Angular Silent, Angular Overdrive, Fluid Silent, Fluid Overdrive. Angular is the reference look. Fluid needs FART // Fluid, which is still to be designed; until then the island is built on Angular (Z144). Silent is still in both forms. |

## S3 event timings

| # | Decision |
|---|---|
| Z147 | **Island notice dwell.** Charging stays for 2 s. Low battery and the backend comeback notice stay for 5 s. |

## Inherited decisions that change

| Inherited (FART-next) | In ZÆTHERION |
|---|---|
| D2, host palette always | The palette comes from presets or Matugen, and ZÆTHERION owns it (Z43, Z44) |
| D5, no permanent exterior | The always-on island is the exterior (Z17) |
| D6, unknown input falls through to the host launcher | The launcher is ZÆTHERION's own (Z26–Z28) |
| D21, repository | Replaced by Z2 |
| Contract rule "FART never suspends" | Replaced by the session card with hold-to-confirm (Z39, Z90) |
| D1, D3, D4, D7–D20, D22, D23 | Unchanged |
