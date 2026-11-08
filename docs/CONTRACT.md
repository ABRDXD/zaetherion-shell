# Adapter contract additions

ZÆTHERION keeps FART-next's 15 contract domains: media, audio (with equalizer), network, bluetooth, notifications, workspaces, power, palette, motion, hostActions, sfx, clockGeometry, lyrics, system and clipboard. They keep the same conventions:
- Plain values; collections are replaced, never mutated.
- Every domain has `available`.
- Methods are fire-and-forget, report results through properties and never throw.
- Costly work is held by leases.

What changes for the existing domains:
- `clockGeometry` becomes `islandGeometry`: the island's live rect per screen, and the panel's unfold origin.
- `hostActions` loses its host targets. Its methods move to ZÆTHERION's own surfaces (settings window, wallpaper picker, session card).
- `power` gains real power actions, through `sessionPower` below.
- `network` and `bluetooth` are implemented on DMS and gain pairing, VPN and hotspot for the settings window.

## New domains

Signatures are written as they will be specified at S2. Exact property lists get fixed against the recorded DMS fixtures; anything added beyond this list is an open question for the owner.

| Domain | Properties | Methods | Leases |
|---|---|---|---|
| `lock` | `locked`, `authState` ("idle"\|"checking"\|"failed"), `failures`, `pamService` | `lock()`, `submit(secret)`, `cancel()` | — |
| `idle` | `steps` [{id, timeout, enabled}], `inhibited`, `inhibitors` [{app, reason}], `caffeine` {on, until} | `setCaffeine(on, until)`, `setStep(id, timeout, enabled)` | — |
| `polkit` | `request` {action, message, program, iconName}? | `submit(secret)`, `cancel()` | — |
| `outputs` | `outputs` [{name, mode, scale, enabled, position}], `pending` | `apply(config)`, `reset()` | `outputs` |
| `sessionPower` | `canHibernate`, `canSuspend` | `lock()`, `suspend()`, `hibernate()`, `logout()`, `reboot()`, `poweroff()` | — |
| `wallpaper` | `mode` ("image"\|"sky"), `current`, `cuts` {on, bands}, `favourites`, `history`, `video` {playing, still} | `set(path)`, `setMode(m)`, `setCuts(on, bands)`, `favourite(path, on)`, `search(query)` | `picker`, `search` |
| `widgets` | `layout` [{id, kind, x, y, w, h, rotation}], `presets` | `add`, `move`, `resize`, `rotate`, `remove`, `applyPreset` | `editor` |
| `apps` | `entries` [{id, name, description, icon, frecency}] | `launch(id)`, `record(id)` | `index` |
| `files` | `results` [{path, name, kind}], `indexState` ("inotify"\|"walk"\|"building") | `query(text)`, `open(path)` | `query` |
| `emoji` | `available`, `results` | `query(text)`, `copy(char)` | — |
| `osd` | `event` {kind, level, muted}? | — | — |
| `tray` | `items` [{id, title, icon, status, hasMenu}] | `activate(id)`, `secondary(id)`, `menu(id)` | `menus` |
| `capture` | `recording` {active, startedAt, withSound}, `tools` {satty, tesseract, zbarimg} | `shot(mode, target)`, `record(on, opts)`, `ocr()`, `qr()` | — |
| `weather` | `current` {icon, tempC}, `forecast` [...], `cachedAt` | `refresh()` | `forecast` |
| `location` | `available`, `source`, `timezone` | — | — |
| `wellbeing` | `today` [{app, seconds}], `limits` | `setLimit(app, seconds)` | `stats` |
| `gamma` | `enabled`, `temperature`, `schedule` {mode, sunrise, sunset} | `setEnabled(on)`, `setTemperature(k)`, `setSchedule(s)` | — |
| `sky` (from `fartd`) | `sun` {alt, az}, `moon` {alt, az, phase}, `planets` [...], `stars` (projected, cached), `sidereal` | — | `sky` |

The `location` domain exposes no coordinates to the view. Only `fartd` and DMS handle them.
