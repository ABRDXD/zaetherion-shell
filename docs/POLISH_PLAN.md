# Polish plan: one desktop, not many studies · from 25 November 2026

Source: the two audits of 24 Nov, `docs/audits/desktop-cohesion-2026-11-24.md` (findings **F1–F21**, shared fixes
**S1–S7**) and `docs/audits/desktop-vs-professional-2026-11-24.md` (gaps **G1–G10**). Astra's older pass
(`codex/cohesion-audit`, `docs/COHESION.md`, 17 Nov, unmerged) found F5, F6, F7 and F17 first. This plan supersedes
it, and its branch stays as a record.

## The goal changes

The audits agree: the desktop doesn't lack features, it lacks rules. New surfaces arrived as studies with their own
parts; Fluid is a second set of parts that lags behind; nothing catches drift before it reaches the owner's screen.

1. **A feature freeze until polish phases P1–P4 are done.** No new surfaces, studies or features merge until then.
   The rest of S8–S12 waits, and so does C++ stage 2a. Bug fixes still go in. The lock karaoke is done and stays.
2. **A new definition of done for any surface, written into AGENTS.md:**
   - It's built from the shared parts (`view/ui`; `view/fluid` only where the layout really differs).
   - Its colours, sizes, spacing, durations and easings come from `Design` / `Motion` roles. Literals need a
     `// scale:`-style reason.
   - It appears in the catalogue (P2) in every state, in both forms, on a dark and a light palette.
   - Every state change on it moves through a shared cue, or is listed as deliberately instant.
3. **The island is the model.** It isn't redesigned. Its grammar (shape leads, content follows; timing from distance;
   exits quicker on the opposite curve) is copied outward.

## Who does what
- **Claude B:** tokens, lints, the catalogue, wiring, contrast logic, merges and every suite run.
- **Astra:** values and looks: the state rule's amounts, the Fluid timing values, the appear cue's look, the menu
  skins, `DesktopLook`, icons.
- **Owner:** the picks at the end.

Each phase merges in small units, each with a green full suite, and goes live only on the owner's restart.

## P1 · Quick wins you'll notice (Claude B, this week, each S)

| # | What | From |
|---|---|---|
| 1 | One contrast helper in `Design` (`readable(fg, ground)`, `onAccent`), mirroring the core's 4.5:1 lift. Used by ClockWords, LockLook, FButton/FluidButton primary text, the lock power choice and the island fallback. Offcut's ink set to "auto" against the wallpaper. | S2: F3, F14, F21 |
| 2 | `RollingDigits.color` defaults to `Design.ink` (Fluid's big numbers on light palettes). | F10 |
| 3 | `tnum` in `FluidText`, so Fluid figures stop shuffling sideways. | G5 |
| 4 | The Angular Cut: width and height share one duration, so the outline lands in one piece. | G4 |
| 5 | Labels kept inside their plots: Home's moon label vs the clock, Devices names elided with clearance, Inbox comets clamped. | F11 |
| 6 | Lock: the lyric line's colour on the same 650 ms beat as its scroll, with one weight; the lyrics plate, bars, "AUTH FAILED" and notice fade in. | F12 (part) |
| 7 | Desktop menu → Settings opens over the last room shown (Z232), after the menu has closed. | F16 |

Astra's one-line look changes go in her queue alongside these: Sharp icons and a heavier weight in Angular (G6), and
the disabled-button fill (F19).

## P2 · The safety net (Claude B, M)

1. **Named motion roles** in `Motion.defaults`: `readout`, `lyric`, `arrival`/`leave`, `hold`, `draw`, `spring`. The
   literal durations (F17's list) are moved onto them, with the same values, so nothing changes on screen.
2. **Ratchet lints.** A test records today's count of literal durations, easings, hex colours, spacing values, alpha
   levels and font families per folder, and fails if any count goes **up**. Counts may only fall. Literals stay legal
   with a `// scale:` reason. This stops new drift at once without a big-bang cleanup.
3. **The catalogue** (`tools/catalogue`):
   - every `view/ui` and `view/fluid` part, at rest, hover, press, focus, disabled and with long text;
   - both forms, on Mocha and Latte;
   - offscreen renders stored under `tests/`, plus a test that reports pixel changes above a threshold;
   - each change to a part shows its before/after sheet.
4. **"Rough day" fixtures** (long names, empty, many items, offline, no art) rendered in the catalogue. Small at first,
   growing per room. (G7)

## P3 · The shared rules and parts (Astra values + Claude B parts, M each)

In this order, because each builds on the one before:
1. **State rule** in `Design` (hover / press / focus / drag amounts, one focus mark), drawn by FButton, FluidButton,
   FChoice/FluidChoice, FMenuItem, LimbNavigation, LimbSwitch. (S1, G3; fixes F5)
2. **Fluid timing:**
   - `Motion.flowDuration(travel, sizeChange, departing)` beside `cutDuration`, with paired in/out curves;
   - a spring role for retargeting, so an interrupted Fluid island no longer snaps;
   - used by Overlay, PreferencesPane, FartHeaderOsd, FartAlertDrop and IslandSurface. (S3, G4; fixes F7, F13)
3. **The appear part** (`view/ui`): opacity plus 6 px travel (Fluid) or a Cut reveal (Angular), with an exit, reduced
   motion and the activity report built in. Replaces `visible:` flips. (S4)
4. **One menu row, two skins**: FMenuItem's behaviour with Z86's Angular band and Fluid rail; open from its origin,
   flash the chosen row, fold on exit. (S5, G9)

## P4 · Bring the desktop onto the system (Astra looks + Claude B wiring, M)

1. **`DesktopLook`** (like `LockLook`): the desktop study's paper, stock, rules, fonts and sizes mapped onto roles and
   the scale. The Day index keeps its cream and charcoal plates (audit: leave alone). (S6; F2, F3)
2. **Desktop menu and editor:** the menu row from P3.4, opening as a Cut from the pointer (Fluid: P3.2). Editor buttons
   become FButton/FluidButton. The overlay window stays alive until the fold ends. (F4, F9)
3. **Desktop clock arrival** when a workspace empties; Hide/Show widgets fades (P3.3). On exit it folds away over about 200 ms (Z232). (F1)
4. **Settings pages** replay the room entrance on a section change. (F8)
5. **Rolling digits** for every clock and percentage, on the `readout` role (Z232, F15).
6. **Lock power choice** through the menu row. Capture selector footer and hint through the appear part. (F12, F18)

## P5 · Fluid as values, not a second set of parts (Claude B + Astra, L) · **waiting** (Z232: Fluid secondary)

The form becomes values every `F*` part reads: corner treatment and size per role, the state rule, the timing rule,
families. `Fluid*` files remain only where the layout differs (rooms). Then Fluid's missing rooms and the panel frame,
in the owner's order (pick 1). This is what stops Fluid falling behind again. (G1, F6)

## After the polish phases
- One hero per surface (G10), if the owner wants it as a rule.
- Unfreeze: the rest of S8–S12, C++ stage 2a, Astra's waiting studies (desktop widget collection, draw/edge, island
  lyric slots) and the clock face options, each now held to the definition of done above.

## Owner picks (24 Nov, Z232)
1. **Pause features until P1–P4 are done:** yes.
2. **Fluid stays secondary.** It gets P1–P4's fixes; P5 waits for a later pick.
3. **The desktop clock folds away** (about 200 ms) when a window arrives (amends Z85). This goes in P4.3.
4. **Clocks and percentages roll** on each change, on one `readout` role: the island rest, Angular Home, Day index,
   Offcut, the lock. This goes in P4, after P2.1's role.
5. **Desktop menu → Settings** opens over the last room you had open. This goes in P1.7.
6. Still open, for later: a Fluid login (F20); the desktop clock's figures in a face with tabular digits (G5).
