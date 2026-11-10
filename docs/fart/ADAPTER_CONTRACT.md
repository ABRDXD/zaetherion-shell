# Host adapter contract

Status: **implemented in M1, 6 November 2026.** The user reviewed the draft and approved every recommendation (section 7). The source of truth is `view/contract/`. This file explains the contract and records the decisions behind it. When the two disagree, the code wins: fix this file.

The view never talks to a desktop shell directly. It receives one `HostAdapter`, and that object is its only route to the host. The adapter has 14 domains: media, audio, network, bluetooth, notifications, workspaces, power, palette, hostActions, sfx, clockGeometry, lyrics, system and clipboard. `adapters/serpantinum` implements them for Serpantinum 2.4.1. `adapters/fixture` holds inert sample data for offscreen tests.

## 1. Delivery

```
shell.qml          SerpantinumAdapter { id: host }  ─┐
shell-fixture.qml  FixtureAdapter     { id: host }  ─┴► Overlay { host } ──► Shell { host, shell } ──► room { host, shell }
```

- **Types.** `view/contract/HostDomain.qml` is the base of every domain. It provides `available`, leases and the fixture call log. Each domain file (`MediaDomain.qml` …) declares its properties with "unavailable" defaults and its methods as no-ops that only log. `HostAdapter.qml` holds one instance of each domain. The view owns this interface, and adapters derive from it (`SerpantinumMedia.qml` is `MediaDomain { … }`). Adapters may import `qs.view.contract` and nothing else from `view/`.
- **Overriding.** Adapters redeclare contract methods with the same parameter names. A spike confirmed that the derived method wins, including when the base type calls the method itself. `tests/test_contract.py` checks that every Serpantinum implementation overrides every contract method with matching parameters.
- **Rooms** declare `required property HostAdapter host` and `required property ShellContext shell`. `ShellContext` (`view/shell/`) is view-only state: `panelOpen`, `wideLayout`, `engagedTimerKind`, plus the methods `close()`, `openHost(target)`, `toggleLayout()` and `toggleActiveTimer()`. `openHost` closes FART first and then calls `host.hostActions.open(target)`.
- **Singletons** cannot take required properties. `Overlay` injects the host into them once: `Host.adapter` and `Design.source = host.palette`.
- **The core.** `SerpantinumAdapter` takes `required property CoreClient core` (`qs.core.client`), and `SerpantinumNotifications` reads the mirror from the core's `notifications` topic ([CORE.md](CORE.md) §5). That is an implementation detail: the `notifications` contract is unchanged. `Design` keeps a copy of the palette and refreshes it on change signals. It never binds through `source`, because at shutdown such bindings would re-run against a palette that is being destroyed.
- **Preferences that shape host work** are pushed in with `Binding` from `Overlay`: `media.preferredPlayer` and `system.sampleInterval`.
- **Deferred domains** (7 November 2026, [COLDSTART.md](COLDSTART.md)). `HostAdapter.loadDeferred()` is a no-op by default. An adapter may leave a domain that the panel's first frame does not show on its contract default ("unavailable") until that call, then replace it. The view calls it once the first open's unfold has settled, or at once when a room other than Home is shown. `CoreHostCalls` calls it before resolving a host call's domain and moves a waiting call's lease if the domain is swapped in later. `HostLease` already follows a domain change. `SerpantinumAdapter` defers audio (with its equalizer), bluetooth, notifications, lyrics and clipboard, about 17 ms of a cold start offscreen. `sfx` stays eager, because a UI sound can arrive with the open. The fixture defers nothing.

## 2. Conventions

| Topic | Rule |
| --- | --- |
| Values | Plain JS objects and arrays owned by FART. Host objects (`MprisPlayer`, `PwNode`, `BluetoothDevice`, `HyprlandToplevel`) never cross the boundary. Collections are replaced, never mutated in place, so bindings fire. Rooms only read domain properties. |
| Ids | Strings: MPRIS bus name, PipeWire node id, Bluetooth address, Hyprland address, workspace id, cliphist id, notification id. |
| Units | Seconds (real) for durations and media position. Epoch milliseconds for timestamps, except `recording.startedAt`, which is in epoch seconds. `0..1` for volume, brightness, battery, signal and spectrum. KiB for memory and disk. dB for EQ. Logical pixels for geometry, except `Monitor.width`/`height`, which are the mode size (divide by `scale`). |
| Availability | Every domain has `available`. When it is false, the other properties hold their defaults and methods do nothing. |
| Methods | Fire and forget. They return `void` (except `clockGeometry.rectFor`), never throw, and report outcomes only through properties. Names state the intent (`setMuted(true)`). Where Serpantinum offers only a toggle, the adapter toggles only when the requested state differs from the current one. |
| Leases | Costly work runs only while held: `acquire(feature, owner)` / `release(feature, owner)` / `holds(feature)`. The view helper `HostLease { domain; feature; active }` (`view/ui/`) pairs acquire with release, including on destruction. A test fails if a view lease names a feature no adapter checks. |
| Presentation | Adapters provide no icons, colours or labels beyond host-provided names. |
| Fixture | `FixtureAdapter` uses the contract types directly, with `recordCalls: true` and sample data. Method calls are appended to `calls` as `{method, args}`, and nothing real is actuated. |

### Leases

| Domain | Feature | Work held | Held by |
| --- | --- | --- | --- |
| media | `position` | position sample (`position`, `positionStamp`) every 500 ms while playing | Media |
| media | `spectrum` | CAVA process while playing | Media (ambient on) |
| audio | `mixer` | PipeWire tracker binding the default sink, default source and playback streams. `output`, `input` and `streams` are valid only while it is held. | Devices |
| network | `details` | one `ip` address probe per device change | Devices |
| network | `scan` | Wi-Fi scanner (`networks`) | none yet (M6 quick connect) |
| power | `brightness` | host brightness file watch and one probe | Devices |
| hostActions | `recording` | recorder status probe every 1.5 s | Devices |
| lyrics | `lyrics` | lookup for the active track | Media (lyrics on) |
| system | `resources` | `/proc` CPU, memory, temperature and disk sampling | Performance |
| system | `gpu` | `gpu_sample.py` every 3 s | Performance |
| clipboard | `history` | `cliphist list` | Clips |

## 3. Domains

The signatures below match `view/contract/`. `T?` means a value or `null`.

**media.** `players: list<Player>`, `active: Player?`, `selection` ("" = automatic), `preferredPlayer`, `position`, `positionStamp`, `spectrum` (56 bins). Methods: `select(playerId)`, `togglePlaying()`, `next()`, `previous()`, `seek(seconds)`, `setShuffle(on)`, `setLoop("none"|"track"|"playlist")`, `raise()`. `Player = { id, identity, desktopEntry, title, artist, album, artUrl, length, playing, canToggle, canNext, canPrevious, canSeek, canRaise, shuffle, shuffleSupported, loop, loopSupported }`. To get the current position while playing, extrapolate: `position + (now − positionStamp)/1000`. The active player is the manual selection, else the preferred player, else the first one playing, else the first one listed. The Spotify rule replaces this in M6.

**audio.** `output`, `input: Endpoint?`, `outputs`, `inputs: list<Device>`, `streams: list<Stream>` and `equalizer: EqualizerDomain`. Methods: `setVolume(endpointId, level)`, `setMuted(endpointId, muted)`, `setDefault("output"|"input", deviceId)`. `Endpoint = { id, name, volume, muted }`, `Device = { id, name, isDefault }`, `Stream = { id, app, volume, muted }`. Volume changes need the node bound, so the M5 `vol` verb must hold `mixer` briefly.

**audio.equalizer.** `bands` (10 gains in dB), `frequencies` [31 … 16000], `minGain` −12, `maxGain` 12, `preset`, `presets`, `balance` (−1..1), `mono`, `swap`, `dynamicEq`, `dynamics` ("off"|"balanced"|"night"), `pending`. Methods: `setBand(index 0..9, gain)`, `applyPreset(name)`, `setBalance(v)`, `setFlag("mono"|"swap"|"dynamicEq", on)`, `setDynamics(mode)`, `resetAudio()`, `openHost()`. This is the host's own EQ. FART never runs a second filter chain.

**network.** `wifiEnabled`, `kind` ("wifi"|"ethernet"|"none"), `connected`, `name`, `ipAddress`, `networks: list<WifiNetwork>`. Methods: `setWifiEnabled(on)`, `connect(networkId)`. `connect` joins remembered networks only. An unknown network opens the host's Wi-Fi dialog instead. `WifiNetwork = { id, ssid, strength, secured, known, connected }`.

**bluetooth.** `enabled`, `devices: list<BtDevice>` (paired or connected), `primary: BtDevice?`. Methods: `setEnabled(on)`, `connect(id)` (paired devices only), `disconnect(id)`. `BtDevice = { id, name, kind, connected, paired, battery }`, where `battery` is −1 when unknown.

**notifications.** `available` means the mirror is listening. Properties: `items: list<Notification>` (newest last, ≤100), `unread`, `dnd`. Methods: `setDnd(on)`, `markAllRead()`, `dismiss(id)`, `openHost()`. `Notification = { id, appName, summary, body, time, urgency ("normal"|"critical"), read, hasActions }`. Actions are invoked in the host centre. M2 moves the mirror into the core, and the contract stays the same.

**keybinds.** `binds: list<{ mods, key, section, description }>`, the host's described keybinds; `mods` from SUPER, SHIFT, CTRL, ALT. `refresh()` reads them again (the Codex room calls it on opening).

**workspaces.** `focusedScreen`, `activeId`, `workspaces: list<{ id, name, monitor, active, windowCount }>`, `windows: list<{ id, title, appId, workspaceId, monitor, x, y, width, height, floating, fullscreen, focused }>`, `monitors: list<{ name, x, y, width, height, scale, reservedTop, reservedBottom }>`. Methods: `switchTo(workspaceId)`, `focusWindow(windowId)`.

**power.** `battery = { available, level, charging, pluggedIn }`, `profile` and `profiles` ("power-saver"|"balanced"|"performance"), `idleInhibited`, `brightness = { available, level }`, `nightLight`. Methods: `setProfile(name)`, `setIdleInhibited(on)`, `setBrightness(level)`, `setNightLight(on)`, `lock()`. Serpantinum has no direct night-light verb, so `setNightLight` opens its system panel. FART never suspends, reboots or powers off; it opens `hostActions.open("power")`.

**palette.** `revision`, `colors` (neutral roles: background, surface, surfaceRaised, text, textMuted, textFaint, line, accent, warm, danger, success, highlight; any key may be missing), `opacity`, `radius`, `blur`, `monoFamily`. `Design` supplies the fallbacks. For Serpantinum the mapping is base, surface0, surface1, text, overlay2, subtext1, overlay0, blue, yellow, red, green, mauve, read from `qs_colors.json`, or from `qs_matugen_colors.json` when Matugen is on.

**motion.** `roles`: FART role → `{ duration, easing, overshoot, … }`, static data with no files or processes ([CUES.md](CUES.md) §15). Missing roles or fields keep FART's defaults (`Motion.defaults`). Serpantinum has no motion tokens, so `SerpantinumMotion` holds the values its own popups and controls use inline. The fixture leaves `roles` empty.

**hostActions.** `name`, `version`, `targets`, `launcherAcceptsQuery`, `updates = { available, checking, count }`, `recording = { available, active, startedAt }`. Methods: `open(target)`, `openLauncher(query)`, `checkUpdates()`, `capture()`, `setRecording(on)`. The Serpantinum targets are launcher, clipboard, settings, themes, wallpapers, wifi, bluetooth, notifications, power, display, music, calendar and updates. Each was checked against `Main.qml` and `WindowRegistry.js`.

**sfx.** `muted` and `volume` come from the host (`general.muteSfx`, `general.sfxVolume`). Method: `play(cue, gain)`. The cues are FART's: `timer.done` and `pomodoro.phase` today, mapped to the freedesktop `alarm-clock-elapsed`. Playback goes through `pw-play` with `media.role=event`, the same route as the host's `Sounds.qml`. D19's DND and Session gating is FART policy, applied before `play()`.

**clockGeometry.** `rectFor(screen) → { x, y, width, height, edge, exact }` and `setHookRect(screen, x, y, width, height)`. Without the hook (M5), the rect is estimated from `bar.position`, `bar.height` and a centred 160 px width, and `exact` is false.

**lyrics.** `status` ("idle"|"loading"|"ok"|"none"|"no-track"), `source` ("host-cache"|"fart-cache"|"fetch"|"local"), `trackKey`, `lines: list<{ time, end, text, words: [{ time, end, text }] }>`, `wordTimed`. Methods: `reload()`, `loadLocal(path)` (an `.lrc` file). The adapter supplies data only. `view/rooms/LyricsTimeline.qml` turns position into the current line and wakes only at line boundaries. The implementation is shared (`adapters/common/LyricsSource.qml`): host cache (read-only), then FART cache (`$FART_CACHE_DIR/lyrics`), then `tools/lyrics/lyrics.py`, which fetches, caches atomically and prints one JSON line.

**system.** `user`, `hostname`, `cpuModel`, `uptime` (seconds, refreshed each minute), `sampleInterval`, `cpu = { available, usage, history, temperature }`, `memory = { available, total, used, history, swapTotal, swapUsed }`, `disk = { available, total, used, free }`, `gpu = { available, failed, usage, temperature, vramUsed, vramTotal, source, error, history }`. The implementation is shared (`adapters/common/LinuxSystem.qml`). The old package and install-age probes (`pacman -Q`, `flatpak list`) were dropped because nothing displayed them.

**clipboard.** `entries: list<{ id, text, isImage }>`. Methods: `refresh()`, `copy(id)`, `remove(id)`, `copyText(text)`, `fetchText(id)`, and the signal `textFetched(id, text)`. Pins are FART settings and live in `view/rooms/ClipPins.qml`. The implementation is shared (`adapters/common/CliphistClipboard.qml`) and reads history only under the `history` lease.

## 4. Serpantinum interfaces verified read-only

- **EQ:** Serpantinum has no Quickshell IPC target for it. The control surface is `$SERPANTINUM_DIR/quickshell/media/equalizer.sh` with these verbs: `get`, `set_band <1..10> <dB>`, `preset <name>`, `set_balance`, `set_mono`/`set_swap`/`set_dyneq <bool>`, `set_dynamics`, `reset_audio`, `apply`, `test`, `stop_test`. The state lives in `$XDG_RUNTIME_DIR/serpantinum/music/eq_state.json`, with gains stored as strings. The script applies through `serpantinum-audio ctl set` on `serpantinum_sink`. The adapter watches that file, which is event-driven with no polling, and runs the script by argv. `available` requires both the script and the state file. FART never seeds the file, because `get` may start the audio daemon. `test` and `stop_test` play audio and are not exposed.
- **Lyrics cache:** `${XDG_CACHE_HOME:-~/.cache}/serpantinum/lyrics/<md5(artist.trim() + " - " + title.trim())>.json`, holding a JSON array of `{time, text, words: [] | [{time, endTime, text}]}`. On 6 November 2026 there were 6 files: 1 word-timed, 5 line-only, and none with translations.
- **Launcher:** `msg open launcher` takes no query in 2.4.1, so `launcherAcceptsQuery` is false.

## 5. Enforcement

- `tests/test_contract.py` fails a `view/**` file that imports `qs.adapters.*`, `Quickshell.Services.*`, `Quickshell.Bluetooth`, `Quickshell.Networking` or `Quickshell.Hyprland`. The one exception is `view/shell/Overlay.qml`, which may import Hyprland for the focus grab only.
- The same test fails a view file that names host paths or binaries (`serpantinum`, `qs_colors`, `cliphist`, `canberra-gtk-play`, `pw-play`, `wl-copy`, `gdbus`, `hyprctl`).
- It also fails a view file that starts a process outside the allowlist. Since M2 the allowlist is only `view/shell/FartCommands.qml` (the update report). The same test confines `qs.*` imports per layer (the view: `qs.view.*` and `qs.core.client`; adapters: `qs.view.contract`, `qs.core.client`, `qs.adapters.*`; `core/client`: none) and fails any `core/` file that names a host path or binary.
- It checks that every contract method is overridden by the Serpantinum implementation, that both adapters fill all 15 domains (declared, or assigned in `loadDeferred()`), and that every view lease is honoured by an adapter.
- `tools/smoke.py` loads all nine rooms against the fixture in a visible offscreen window. It also loads the Serpantinum adapter, isolated from real host files, which catches binding errors and checks the palette mapping. It asserts that leases are acquired and released and that the fixture recorded no method calls.

## 6. Where earlier code went

| Before M1 | Now |
| --- | --- |
| `adapters/serpantinum/*` singletons (`MprisController`, `Audio`, `Network`, `BluetoothStatus`, `Notifications`, `WM`, `HyprlandData`, `Battery`, `Brightness`, `Idle`, `Hyprsunset`, `Recording`, `Updates`, `Backend`, `HostSettings`, `GlobalStates`) | `Serpantinum<Domain>.qml` domain implementations, plus private `SerpantinumSettings` |
| `adapters/serpantinum/DateTime` | `view/ui/Clock` (clock) and `system.uptime` |
| `adapters/serpantinum/Weather` | removed (Home shows the date instead, per the Home design) |
| `view/ui/PaletteSource` | `SerpantinumPalette` and `Design.source` |
| `compat/LyricsService` | `LyricsSource` (data) and `view/rooms/LyricsTimeline` (timing) |
| `compat/ResourceUsage`, `ResourceMath.js`, `SystemInfo`, `rooms/Telemetry` | `adapters/common/LinuxSystem` |
| `compat/Cliphist` | `adapters/common/CliphistClipboard` and `view/rooms/ClipPins` |
| `compat/ConnectionDialog`, `Session`, `DynamicIslandService` | `shell.openHost(…)`, `power.lock()` |
| `compat/DotsUpdater` | "Host updates…" opens the host updates page; "Update FART" goes through `view/shell/FartCommands` |
| `compat/Config`, `Persistent`, `Directories` | `view/shell/` |
| `compat/Todo`, `compat/TimerService` | the core (`core/tasks.py`, `core/timers.py`) and `core/client` (M2) |

## 7. Review decisions (6 November 2026)

1. `system` and `clipboard` were added as domains, so fixtures replace them and no test reads the real clipboard. Their implementations are shared in `adapters/common/` for future hosts.
2. Brightness and night light stay under `power`.
3. Adapters override contract methods. Request signals were not used.
4. `Overlay.qml` keeps `Quickshell.Hyprland` for the focus grab. Focused-screen and reserved-area reads go through `workspaces`.
5. FART's own pacman/yay runner was removed. "Host updates…" opens the host's update page.
6. There is no host patch for launcher prefill, because the Serpantinum updater would overwrite one. D6 fallthrough opens the launcher empty, and a FART-side query is an M5 option.
7. `ShellContext` replaces `di`.
