# Wallpaper and preset selectors inside FART (design draft, S9)

Status: **draft for the owner. Nothing is built.** Branch `s9-wall-presets` from `s0-seed` 39719a2. New decisions start at Z176.

## 1. What exists

- `zaetherion wall` / `theme` (`core/verbs/hostactions.py`) and Home's DESK menu items "Wallpaper" and "Presets" (`view/rooms/Home.qml`) fold FART and open DMS's own picker and themes. That breaks Z162.
- The palette picker (Z160, Z163–Z165): `view/shell/PalettePicker.qml` in `PreferencesPane`, `core/palette.py` (`palette.json`, the `palette` topic, `palette.list/choose/preview/cancel`), catalogue read at core start through `adapters/common/palette_sources.py`.

## 2. How DMS does wallpapers here (read-only, dux-shell 2.1.0)

| Thing | Where |
| --- | --- |
| Current wallpaper | `~/.local/state/dms/session.json`: `wallpaperPath`, and with `perModeWallpaper: true` also `wallpaperPathDark`/`wallpaperPathLight`; `perMonitorWallpaper` + `monitorWallpapers` when per screen (off here) |
| Folder the picker shows | the current wallpaper's folder, or the picker's last path: `~/Pictures/Wallpapers` (84 files: 83 images, 1 mp4) |
| File types | images jpg jpeg png bmp gif webp jxl avif heif exr svg; video mp4 webm mkv mov m4v avi (`Common/WallpaperFormats.js`) |
| Setting one | `dms ipc call wallpaper set <abs path>` → `SessionData.setWallpaper` (writes session.json, both the path and the current mode's per-mode path). Refuses while per-monitor is on (`setFor <screen> <path>` then). Also `get`, `next`, `prev`, `clear` |
| Drawing it | DMS's own `WallpaperBackground` layer (QML). `awww` is installed but DMS doesn't use it |
| Colours | Every set calls `Theme.generateSystemThemesFromCurrentTheme()`. Matugen takes colours **from the image only when DMS's theme is "dynamic"**. Today it is `custom` (Amoled Black), so a new wallpaper changes no colours; Matugen just re-runs the app templates with Amoled Black. DMS caches seeds in `~/.cache/dms/matugen-seeds.json` |

## 3. Proposal

**Where.** FART's settings pane gets section tabs across its right side: `PALETTE · WALLPAPER · PRESETS` (the palette picker unchanged in the first). `zaetherion wall`, `theme`, and Home's "Wallpaper" / "Presets" items open FART's settings at that tab instead of folding (FART opens first if it was closed). No DMS window ever opens.

**Morph.** As settings does now: the pane grows out of FART's field (`reveal`, `Motion.unfold`), the tab switch is an ink wipe, Esc or the close button folds it back into FART (`Motion.fold`), and folding FART folds it too.

**Wallpaper section.** A grid of thumbnails (decoded small and asynchronously, only for visible tiles, none kept after close) beside one large preview plane. A video shows a "VIDEO" tile with no thumbnail. Name filter field on top, as in the palette picker.

**Preview.** Hover or arrow keys show the image in the large plane, with FART's current palette over it; nothing is written to DMS. Click or Enter applies it through DMS. Esc, closing, folding: nothing to undo (the desktop never changed). Optional *peek*: holding Space while a tile is highlighted makes FART's panel fade to its outline so the real desktop shows (still the old wallpaper until saved).

**Keys.** Arrows move in two dimensions, PgUp/PgDn by page, Home/End, typing filters, Enter applies, Esc clears the filter then closes, Tab moves between filter, grid and buttons; `[`/`]` switch section tabs.

**Core** (`core/wallpaper.py`, like `palette.py`):
- Stores `wallpaper.json`: `folder` (default `~/Pictures/Wallpapers`, Z84) and `recent` (last 12 applied, for Z41's history).
- Publishes topic `wallpaper`: `{folder, available, entries count, current, preview, error}`. `current` is what the host reports; the host remains the authority (DMS can still change it by cycling).
- Ops: `wallpaper.list` (scans the folder: name, path, kind image|video, size, mtime; a plain filesystem read, no host knowledge), `wallpaper.choose(name|path)` (resolves within the folder, then a host call), `wallpaper.preview(name)` / `cancel` (state only, owner-tied like the palette, so the CLI and other clients see what is being previewed).
- Verb: `zaetherion wall` opens the section; `wall <name>` applies; `wall list`; `wall next|prev` by name order.

**Contract.** A new 16th domain, `wallpaper` (`view/contract/WallpaperDomain.qml`): `available`, `current` (absolute path or ""), `perScreen` (bool), `error`, method `set(path)`. DMS: `adapters/dms/DmsWallpaper.qml` watches session.json read-only (a `FileView` with change watch), maps it through `DmsWallpaperMap.js` (dark/light per-mode, per-screen) and sets with `dms ipc call wallpaper set`. Fixture: sample paths and the call log. Serpantinum (legacy): unavailable.

**When the source is missing.**
- Folder gone or empty: the section says so ("NO WALLPAPERS IN ~/Pictures/Wallpapers") and offers a path field to point elsewhere; nothing else breaks.
- Host can't set (fixture, DMS down, per-screen mode on): images still browse; "Apply" is off with the reason shown; the CLI returns the same reason.
- A file vanishes between listing and applying: refused with "no longer there", list refreshed.
- Unreadable image: its tile shows the name only.

**Colours from the wallpaper** (owner: an option, off by default). A toggle in the wallpaper section, "Colours from this wallpaper". When on, the highlighted image also previews a palette made from it, and applying saves that palette. The adapter runs `matugen image <path> --dry-run --json hex` (matugen 4.2.0 has both flags). That writes no files and runs none of your app templates. Its dark scheme goes through DMS's role map and `normalize()` (Z165), becoming palette entry `wall:<file name>`. The core caches it by path, size and mtime, the way DMS's seed cache does. DMS's own theme stays as it is.

## 4. Presets (owner: wallpaper + colours, island shape, DMS's theme)

A preset is one saved look: `{name, wallpaper, palette, islandForm, dmsTheme}`. Any field may be left empty, meaning "leave that alone".

- **Section.** The `PRESETS` tab lists looks as wide cards: a small wallpaper thumbnail, the palette's accent swatches, and the island's form drawn in miniature. "Save current look" makes a new preset from what is in use now (name typed inline). Rename and delete happen inline.
- **Preview.** Hover or arrows preview the palette (the existing `palette.preview`, so all of FART recolours live), the island form, and the wallpaper in the large plane. Nothing in DMS changes until you apply. Esc, close or fold restores everything, as the palette picker does.
- **Apply** (click or Enter), in order: palette (`palette.choose`), island form (the stored form setting, Z155), wallpaper (`wallpaper` host call), and last the DMS theme.
- **DMS's theme.** DMS has no command to switch theme (its `theme` IPC only does light/dark). DMS reloads `~/.config/dms/settings.json` by itself when the file changes, so the adapter would set only `currentThemeName`/`currentThemeCategory`/`customThemeFile` there. It would write atomically, keep a dated backup the first time, and leave every other key untouched. **This is the one write to a DMS file in the whole design**; it needs your explicit OK when built.
- **Core.** `core/presets.py`: `presets.json` (list of looks), topic `presets`, ops `presets.list/save/rename/delete/preview/cancel/apply`; verb `zaetherion look <name>` / `look list` / `look save <name>`.
- **Missing parts.** If a preset's wallpaper file is gone, its palette is no longer installed, or DMS is down, the card marks that part "missing". Apply does the rest and says what it skipped.

## 5. Decisions to record (next free: Z176)

- Z176: wallpaper picker inside FART's settings, previewed in a large plane in FART, applied through the host. `wall`/`theme` and Home's items open FART's section instead of DMS.
- Z177: the `wallpaper` contract domain; the host is the authority for the current wallpaper; the core keeps folder, recent and preview.
- Z178: colours from a wallpaper, optional and off by default, via `matugen --dry-run`.
- Z179: presets bundle wallpaper, palette, island form and DMS theme; the DMS theme switch edits DMS's settings file (owner's OK required).

## 6. Build order (after the owner's OK)

1. Core `wallpaper.py` + verb + tests (folder scan, resolve, missing folder, recent).
2. Contract `WallpaperDomain`, `DmsWallpaper` + `DmsWallpaperMap.js` + tests on sample session.json files; fixture.
3. Settings tabs + wallpaper section; nested-Hyprland captures to the owner **before committing UI**.
4. Colours from wallpaper (adapter matugen run, catalogue entry, cache).
5. Presets core + section + DMS theme write (owner's OK on that write first).
6. `make_qmldirs.py --check`, full suite with FART_*/DMS_* unset, HANDOFF entry. No merge or push without the owner.
