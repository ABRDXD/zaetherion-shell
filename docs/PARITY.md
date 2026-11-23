# Parity with Serpantinum 2.4.1

Every user-visible feature of the shell ZÆTHERION replaces, with its fate. This table is the retirement gate's checklist (Z112): every row must be **kept**, **replaced** or **dropped**, and every kept or replaced row must work.

The inventory was read from Serpantinum's installed source on 8 Nov 2026.

| Area | Serpantinum feature | Fate | ZÆTHERION | Ref |
|---|---|---|---|---|
| **Bar** | One bar per screen, top/bottom/left/right | replaced | Island on the primary screen; top and bottom first | Z17, Z18, Z58 |
| | Autohide (reveal on hover), hide in fullscreen | replaced | Always on, hidden in fullscreen | Z17 |
| | Menu button (settings, launcher, night light, caffeine, shuffle wallpaper) | replaced | Desktop right-click menu, verbs, settings | Z86 |
| | Workspaces module (pills/numbers, scroll) | replaced | Island workspace flash on switch; overview | Z21, Z76 |
| | Focused window title | dropped | — | — |
| | Media module and side popout | replaced | Island media fragment; Media room | Z19, Z69 |
| | CAVA visualizer | replaced | Island line waveform | Z70 |
| | System tray | kept | Hover right wing; montage menus | Z130, Z131 |
| | Clock faces (classic/material/badge, `HH:mm:ss`, typing date) | replaced | Island `HH:mm`, seconds on hover | Z67 |
| | Info module (recording timer, timers) | replaced | Island expansions | Z22 |
| | Weather module | replaced | Hover wing and Home | Z45 |
| | Sysmon (CPU/RAM/temp/disk) | replaced | Performance room | Z100 |
| | Keyboard layout switch | **open** | Not covered by a decision: ask the owner at S3 | — |
| | Wi-Fi, BT, volume, battery modules | replaced | Hover glyphs; battery bar at rest | Z68, Z130 |
| **Launcher** | Apps with frecency and focus-time ranking | kept | Apps tab | Z75 |
| | Files tab | replaced | Indexed home search | Z78 |
| | Emojis tab | kept | Emoji tab (data read at runtime) | Z31 |
| | `>cmd` in the terminal | kept | `>` prefix | Z27 |
| | `?term` web search (Brave) | kept | `?` prefix, Brave | Z28 |
| | Inline calculator | kept | `=` prefix plus units and currency | Z80 |
| | Shell popups as entries | replaced | Verbs | Z27 |
| **Clipboard** | Popup with search, pins, image previews, wipe | replaced | Clips tab and Clips room on DMS clipboard | Z14, Z96 |
| **Notifications** | Server with actions and images | kept | Plus inline reply | Z33 |
| | Popups with position presets | replaced | Island expansions | Z73 |
| | History, grouped by app | replaced | Inbox, persisted 24 h | Z32 |
| | DND | kept | Plus forced by Sessions | Z34 |
| | Notification sound | kept | Read at runtime | Z104 |
| | Battery notifications at 20% and 5% | replaced | Island at 20, 10 and 5% | Z129 |
| | Self-updater notifications | dropped | Not applicable | — |
| **OSD** | Volume, mic, brightness | kept | Island on change | Z24 |
| | Caps lock, num lock, airplane | replaced | Hover only | Z24 |
| **Volume popup** | Master, per-app streams, devices | replaced | Devices and Media rooms | Z95 |
| **Media popup** | Art, seek, lyrics (lrclib and NetEase), player switch | replaced | Media room; lyrics source decided at S2 | OPEN 3 |
| | 10-band EQ (closed `serpantinum-audio` helper) | replaced | Own PipeWire filter-chain | Z50 |
| **Network popup** | Wi-Fi scan and connect, ethernet, connectivity, BT, airplane | replaced | Devices (quick) and settings (full) on DMS | Z8, Z95 |
| **System panel** | Sliders, night light, caffeine, Wi-Fi/BT/airplane toggles | replaced | Devices room, settings, verbs | Z95 |
| | Power profiles, battery time | replaced | Devices room, hover glyph | Z95 |
| | Power actions | replaced | Session card | Z90 |
| **Calendar popup** | Month view and weather forecast | replaced | Home calendar (tasks and `.ics`) and forecast | Z99, Z45 |
| **Wallpaper** | Own engine, shader transitions | replaced | Montage wipe | Z82 |
| | Video wallpapers | kept | Paused when covered; still on battery | Z140 |
| | Picker, favourites, history, filters | kept | Wallpaper picker | Z41 |
| | Online search (DuckDuckGo) | kept | Online search | Z41 |
| | Per-monitor wallpaper | **open** | Z58 puts wallpaper on every screen; per-screen images not decided: ask the owner at S8 | — |
| | Matugen trigger and app theming (~45 apps) | replaced | Owner's Matugen templates | Z44 |
| | 96 colour presets | kept | Read at runtime | Z43 |
| **Lock** | Session lock, PAM `serpantinum` | kept | Same PAM service, `login` fallback | Z37 |
| | Fingerprint | dropped (for now) | `fprintd` not installed; the PAM file stays as is | Z37 |
| | Attempt limits | dropped | No limit | Z88 |
| | Blurred screen-freeze background | replaced | Wallpaper with sky cuts | Z89 |
| | Clock, media, battery, power buttons | kept | Title card | Z36, Z87 |
| | Avatar, user name, keyboard layout, notifications, weather, sysinfo | dropped | — | Z36 |
| | Lock layout editor | dropped | — | — |
| **Idle** | Dim, lock, DPMS, suspend at the owner's timeouts | kept | 150/300/450/600 s | Z38 |
| | Media inhibit, app inhibitors, caffeine, lock on sleep | kept | Via DMS and Quickshell | Z38 |
| | Custom idle actions | dropped | — | — |
| **Polkit** | Own dialog | replaced | Island expansion | Z25 |
| **Screenshot** | Region/full/monitor, frozen selector | kept | Serpantinum-like selector | Z105 |
| | satty editor, OCR, QR | kept | Same tools | Z48 |
| | Recording (gpu-screen-recorder, sound, mic) | kept | Island timer, keybind stop | Z105 |
| **Quick actions** | Edge hover | kept | Right edge only | Z107 |
| | Draw | kept | Annotate or blank; full tool set | Z106 |
| | Calculator and converters | replaced | Launcher `=` | Z47 |
| | Timer, notes, system usage, mini dock | dropped | FART Timers, notes widget, Performance room | Z47 |
| **Dock** | Pinned apps, magnify, running indicators | dropped | — | Z46 |
| **Desktop widgets** | Editor; time, music, visualizer, weather, image, user, stats, GitHub, notes, text | replaced | Clock/sky, music/lyrics, notes, text, image; same kind of editor | Z46, Z85 |
| | *(from DMS, owner's request 11 Nov 2026)* Modern Clock desktop widget: huge spaced day name, small date, `– time –` | **added** | A desktop widget kind, owner's favourite: day name in Anurati, date and time in Poppins, centred upper third. Port of the GPL-3.0 DMS plugin `modernClock` (credit in NOTICE). Anurati is personal-use only, so it is **never committed**: loaded from the installed plugin or `~/.local/share/fonts`, falling back to a picked font. Poppins (OFL) may ship. Shown in the interim session already (it runs DMS's UI) | S10 |
| **Settings app** | 13 tabs with search | replaced | Settings window, 17 tabs | Z93 |
| | 23 translations | dropped (for now) | English, string table ready for translations | Z56 |
| **Wellbeing** | Focus tracking, charts, app limits | kept | Source decided at S2 | OPEN 1 |
| **First launch** | Intro and tutorial | replaced | Boot sequence every login | Z55 |
| **Weather/location** | Open-Meteo, IP or manual location | replaced | DMS weather and location | Z16, Z45 |
| **Night light** | `serpantinum-gamma` with schedule | replaced | DMS `wayland.gamma` | Z15 |
| **Keybinds** | ~40 binds calling `serpantinum …` | replaced | Same keys, retargeted | Z59 |
| **Robustness** | No restart after a crash; lock can't start the shell | replaced | `fartd` supervision; lock restore | ARCHITECTURE |

## Rows still open

These rows have no decision yet. Ask the owner at the named milestone.

- **Keyboard layout indicator and switching** (S3).
- **Per-monitor wallpaper images** (S8).
