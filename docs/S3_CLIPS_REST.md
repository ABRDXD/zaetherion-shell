# S3: quick paste from the island, and a calmer island at rest

Branch `s3-clips-rest` (from `s0-seed` at `0c617f5`). Design and prototype for the owner's look. Nothing is live, no
Hyprland file is changed. Decision numbers Z181–Z185 are proposed here and go into DECISIONS.md once the owner agrees
(Claude B holds Z177–Z180 on `s9-wall-presets`).

## 1. Quick paste (Super+V)

### What it is
The clipboard history grows out of the top island as a **held face**, the way the session card (Z158) and tray
menus (Z157) do: one island shape, its depth set by the list, folding back into the rest when it closes. Only a
critical event interrupts it (Z161). It is drawn in `view/shell/IslandClips.qml` and offered by
`IslandSurface.openClips()`.

- **Header:** a paste glyph, the field (`> PASTE · TYPE TO FILTER`), the filters ALL · PINNED · IMAGES as ink tags,
  and a count (`matches/total`, or `> READING` until the history is in).
- **Rows:** 6 by default, 30 px each. Each row: the clip's kind (TEXT, LINK, PATH, COLOUR, NUMBER, CODE, IMAGE from
  `ClipKinds.js`) and its mark, then one line of the clip; a pin glyph on pinned clips. An image row is two rows tall
  with a 16:9 thumbnail and its size (`412 KIB PNG 1920X1080`). The chosen row is the ink wipe.
- **Footer:** the keys, and `CTRL+O CLIPS ROOM ›` on the right.
- **Height is fixed** for a given row count, so filtering never makes the island jump.
- Contents are drawn only here and in the Clips room, never in faces, logs or captures (DESIGN_SYSTEM §9).

### Keys (DMS's map, Z161, plus two of ours)
| Key | Does |
|---|---|
| typing | filters (the field holds the keyboard from the first frame) |
| Up/Down, Tab/Shift+Tab, Ctrl+J/K, Ctrl+N/P | move |
| Enter | paste into the window underneath (setting: or copy) |
| Shift+Enter | the other one (copy, or paste) |
| Ctrl+S | pin / unpin (pins are FART's own and outlive cliphist's limit) |
| Delete | remove the chosen clip (only when the field has nothing after its cursor) |
| Ctrl+Tab / Ctrl+Shift+Tab | ALL → PINNED → IMAGES |
| Ctrl+O or Ctrl+Enter | fold and open the Clips room in FART with the query carried |
| Esc | fold |

DMS's Shift+Delete "clear all" is left to the room (destructive, hold-to-confirm there).

### Paste
`ClipboardDomain.paste(id)`: `cliphist decode | wl-copy`, then 200 ms later (DMS's delay, so the island has let go
of the keyboard and the window underneath has it back, Z117) the paste keystroke. The keystroke is Hyprland's own
`hl.dsp.send_shortcut` (`adapters/hyprland/HyprlandPaste.qml`): Ctrl+V, or Ctrl+Shift+V when the focused window is
a terminal (DMS's terminal list and rule). DMS's `clipboard.sendPaste` is not used: the DMS adapter must not name
DMS's clipboard service while its history is off (F2-4, `test_dms_contract`). **Not yet verified** in the nested
Hyprland (whether `send_shortcut` without a window reaches the focused one under the Lua config).

### Cold start (Z139's spirit: fast, no lost keys)
1. **The bind reaches a process that is already running.** The island is resident (Z138). Proposed bind: Hyprland's
   global shortcut to Quickshell's `GlobalShortcut` (`zaetherion:clips`), delivered over the compositor's own
   protocol, so no process starts. (`qs ipc call island clips` also works but starts `qs` first: ~20 ms measured
   for `qs --version`, more for the IPC.)
2. **The clipboard domain exists from the start where the island lives** (`DmsAdapter.clipsWanted`, bound to
   `ZAETHERION_ISLAND` like `osdWanted`). It is no longer deferred to FART's first open there. At rest it reads
   nothing: `cliphist list` runs only while a surface leases `history`. Cost at rest: one small object and four idle
   `Process` objects. The panel-only entry keeps it deferred.
3. **The face takes the keyboard at once.** Opening it is a queue offer; the field takes focus in its first frame and
   the layer asks for exclusive focus in the same commit (the held-face path the session card uses).
4. **The history lands behind the typing.** `cliphist list` with 750 entries (186 images) took 8–9 ms here. Until
   it lands the count reads `> READING`; text typed meanwhile is in the field and filters the list when it arrives.
   **An Enter pressed before then is held** (`pendingEnter`) and acts on the first match once the list is in.
5. **Thumbnails only for rows on screen** (Z79): decoded one at a time with `cliphist decode` into
   `$XDG_RUNTIME_DIR/zaetherion/clips` (tmpfs, mode 700, never the home folder), shown at their row's size, and the
   folder is removed when the lease ends.
6. **The island surface's depth.** The island's layer surface is a fixed 160 px deep (it never resizes during a
   morph, which caused stretched frames). Quick paste is ~251 px. Proposal: the surface resizes once to the clips
   depth before the face grows and back after it has folded, never during the morph. Alternative: keep it 260 px
   deep always (on this 1920 px screen +0.9 MB of transparent buffer). To measure in the nested Hyprland.

### Settings (Z176): a "Clips" tab in FART's settings
| Setting | Control | Default |
|---|---|---|
| Enter does | choice: Paste · Copy | Paste (DMS's default is Copy; owner to choose) |
| Rows in quick paste | stepper 4–10 | 6 |
| Images in quick paste | toggle: thumbnails · text only | thumbnails |
| Keep history of | choice: 100 · 250 · 750 · 1500 entries | 750 (cliphist's) |
| Record images | toggle | on |
| Pins | list with remove; "pinned first" toggle | — |
| Clear history | hold-to-confirm button | — |
| Shortcut | shown, editable in the Keybinds tab (Z93, Z94) | Super+V |

The two recording settings (history length, images) need FART to own the recorders. Today the Hyprland session
starts `wl-paste --type text|image --watch cliphist store` (`~/.config/hypr/zaetherion/session.lua`). Proposal: the
core starts and supervises these two watchers with `-max-items N`, and those two lines leave session.lua (a Hyprland
change: owner's OK first). Until then the two settings are hidden, not shown dead.

### The Clips room
The room keeps its archive layout; to match quick paste: the same kind column and marks, one excerpt style, the same
key map (Enter, Shift+Enter, Ctrl+S, Delete), image rows with thumbnails (it shows the `[[ binary data ]]` line
today), the filter as the same ink tags, and the query carried from quick paste. Pins and "load 100 more" stay.
Captures of the room come after the owner's look at quick paste.

### Super+V: the bind change (needs the owner's OK; not made)
In `~/.config/hypr/zaetherion/keybinds.lua` (the ZÆTHERION session; `config/keybinds.lua` is the Serpantinum/DMS
session's copy and stays), lines 33–35 today:
```lua
-- Clipboard history
local clipCmd = "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipCmd), { description = "Shell: Toggle clipboard history" })
```
become a comment pointing to `zaetherion/fart.lua`, and `zaetherion/fart.lua` gains:
```lua
-- Super+V: quick paste grows from the island (S3). Undo: delete these lines and restore the fuzzel bind in keybinds.lua.
hl.bind("SUPER + V", hl.dsp.global("zaetherion:clips"), { description = "ZÆTHERION: quick paste" })
```
**Roll back:** `cp keybinds.lua.pre-clips-<date> keybinds.lua` and `fart.lua.pre-clips-<date> fart.lua` (both backed up
first, as on 14 November), then `hyprctl reload`. If the island is not running the global shortcut does nothing; the
fuzzel line can stay as a fallback on another key (Super+Shift+V) if the owner wants one.

## 2. The island at rest

Today at rest (Angular): power | media · clock · network, battery | inbox. The owner finds it cluttered.

Each of power, network, battery and inbox gets a rest mode (`IslandRest.restItems`): **always**, **when it matters**,
or **on hover only**. Hovered, everything shows as before. "Matters": network when disconnected; battery at 20 % or
less and not plugged in (Z129's first step); inbox when a critical notification is unread. Power never "matters", so
it is on hover only unless set to always. The mic/camera privacy glyph is not a choice: it shows whenever a stream
is live (Z74). Prototype in `IslandRest.atRest()`.

Three calmer rests, as presets of those modes (captures: normal / everything needs you):

| | Power | Network | Battery | Inbox |
|---|---|---|---|---|
| Today | always | always | always | always |
| **A · Clock only** | hover | matters | matters | critical unread |
| **B · Clock + unread** | hover | matters | matters | any unread |
| **C · Clock + battery** | hover | matters | always | any unread |

The modes live in the core's `island` topic (`rest`, like form/edge/placement, Z155), so the resident reads them
without FART open; the "Island" tab in FART's settings shows the three presets and the per-item choice under them.
The resting width stays 420 px (Z66); a narrower island for A is possible but bends Z66, so it is a question.

## 3. Proposed decisions (numbers held for after the owner's answers)
- **Z181** Quick paste is a held island face (Super+V), DMS's key map, Enter pastes by default (pending answer),
  Ctrl+O to the room, contents only there and in the room.
- **Z182** Cold start: the clipboard domain is created at start where the island lives and reads only under lease;
  the field takes keys at once; an early Enter is held; thumbnails only for rows on screen, in the runtime dir.
- **Z183** Paste keystroke through Hyprland's `send_shortcut`, DMS's terminal rule; not DMS's clipboard service.
- **Z184** Clips settings tab (§1), with the recorders owned by the core.
- **Z185** Island rest modes per item and the presets; the privacy glyph always shows.

## 4. State of the branch
Committed: the contract (`loaded`, `thumbnails`, `paste`, `requestThumbnail`), `CliphistClipboard` (paste,
thumbnails), `HyprlandPaste`, `DmsAdapter.clipsWanted`, NOTICE, this note. **Not committed (waiting for the owner's
look):** `IslandClips.qml`, the island wiring and `IslandRest` rest modes, and the capture harness
(`tools/clips_capture/`). Not yet wired: the global shortcut, the face's paste/copy/room signals out of
`IslandWindow`, the surface depth, the settings tabs (they go into Claude B's settings tabs once merged), the room.
