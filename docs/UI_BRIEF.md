# UI brief: the island (S3), for GPT 6.1 SOL

> **You are the best experimental UI designer working today.** Nobody has made a desktop like this one, and the owner wants it to look like nothing else on a screen. Be bold, specific and a little strange: sharp angles, a machine voice, a sky behind everything. No generic rounded-card panel, no default-toolkit look. Surprise the owner, then make it hold to the rules below.

## The look is FART's, strictly
The owner wants **the whole desktop to look like FART**, so FART does not read as a one-off inside someone else's shell. The island is the first piece of that desktop. It must look like it grew out of FART's panel: the same family, the same rules, the same voice. You are extending an existing design language with new surfaces, **not inventing a new one**. Be experimental inside the language, never outside it.

The language is **Montage × Cosmos** (docs/VISION.md, and FART's own system in docs/fart/DESIGN_SYSTEM.md and docs/fart/MONTAGE.md). The rules you must keep:
- **One angle family:** −12° and its perpendicular, 78°. Nothing else leans. Headings, numerals and selected bands shear at −12° (`Design.shear`); plane edges use 78° (`Design.slope`). The island's trapezoid sides are 84° (Z64), already decided.
- **Three colour roles only:** *paper* (the backing plane), *ink* (text and lines, or an inverted plane), *signal* (the one accent: selected, current, alarm). Take every colour from `Design` tokens and the palette domain. **No colour literals.** The island's fill is the darkest blue-hued palette role (Z65).
- **Type from the scale:** `caption` 11, `body` 12, `control` 13, `readout` 20, `figure` 32, `headline` 52, `display` 86, through `FText`. No `pixelSize` literal. Numerals are tabular. Data is never large type: a notification body is never a headline.
- **Planes on a 12-column grid with a 4 px baseline** (`Grid.qml`); radii 0 to 2 px inside; hit areas at least 24 px (`Design.minHit`).
- **Machine voice (NieR-style, original wording):** terse uppercase lines such as `> BACKEND · OFFLINE`, brief type-on text, scan or glitch on transitions capped at 3 per second, switchable off (Z53). Principles only: no names, art, fonts, sound or layouts from any game (Z61).
- **Astrophysics as metaphor:** the real sky, orbits as motion, lensing as a transition. Never a picture of a planet or a sun.
- **Silent is still.** At rest nothing moves, ticks or redraws. Motion comes from an event or a lease. Idle motion belongs to Overdrive only.
- **Motion** uses the host motion profile (CUES.md) with overshoot, and respects all four levels: OFF, MINIMAL, REDUCED, ALL.
- **Reuse before inventing.** Look in `view/ui/`, `view/cues/`, `view/strata/` and `view/overdrive/` first. If the island needs a new building block, build it so the panel and every later surface can use it too.

**Where you can be experimental:** the shape of each expansion, how the planes cut in and out, the choreography between rest, wings and expansions, the voice lines, how Overdrive looks on the island. Mock up two or three daring options for the owner on anything not already decided and say which you'd pick.

**How you'll be judged:** put an island mock-up next to a screenshot of FART's panel. They must look like the same product, and the island must be the more striking of the two.

**Check before you show anything:** `tests/test_layout.py` (no literals), the contrast guard or audit if it exists, and a side-by-side with the panel. If DESIGN_SYSTEM.md and VISION.md disagree (for example on the headline font: Roboto Condensed is built, Inter Display was decided in Z52), say so and ask the owner. Don't choose.

One page. Read this, then only the inputs listed. Don't search the whole repo.

## Goal
Design and build the **island**, ZÆTHERION's always-present top-edge surface, as QML in the resident. This is the first visual piece of the shell and the owner's favourite idea. Deliver a working island that runs **on the fixture adapter**, not on DMS: the real adapters (S2) are being built separately by another model, so the island must read only the contract domains (`view/contract/`) and never touch DMS, Quickshell services or Hyprland directly.

## Order of work (stop and show the owner after each step)
1. **Look first, with no code.** One page of mock-ups (an HTML or SVG file in `docs/ui/`, or screenshots) for: the resting state; the hover wings; three expansions (notification, OSD, memory pressure); notch and floating modes. The owner reviews and approves or changes the look before step 2.
2. **The shell of it:** window (layer, namespace, exclusive zone), trapezoid shape, fill, notch/floating, top/bottom, hidden for fullscreen.
3. **Rest content and wings:** the modules and their rules (SURFACES.md §1).
4. **Expansions and the priority queue** (SURFACES.md §1 table). Start with notification, OSD, track change, workspace flash, then the rest.
5. **Click to panel, long-press ignite, keyboard focus.** The key bind is chosen with the owner; do not edit any Hyprland config or keybind.

## What is decided (don't reopen; docs/DECISIONS.md is the authority)
Z17–Z25, Z33, Z64–Z74, Z115, Z119–Z134, Z139. Highlights: trapezoid with 84° sides and the flat edge on the screen, about 420 px wide at rest; fill is the darkest blue-hued palette role; no marquee; empty slots hidden; hover wings after 300 ms; 600 ms long-press ignites Overdrive; a fixed priority queue where a higher expansion interrupts and a lower one resumes; morphing uses the host motion profile with overshoot.

The owner's own modules (what they use daily): **power button, network, notifications (unread dot), battery, active media.** Everything else stays out of the rest state. Memory appears only when pressure is high or pinned by hand (OPEN 14: threshold and pin control are the owner's to decide: propose, with measurements).

## Not decided: ask, don't pick
If DECISIONS.md and OPEN.md both say nothing about a behaviour, **ask the owner in plain everyday language**. Don't choose a default. Open items that touch you: OPEN 7 (binds), OPEN 11 (keyboard layout indicator), OPEN 14 (memory pressure).

## Hard rules (docs and AGENTS.md; the short form)
- **No actuation to test visuals.** Never change volume, playback, network, power, recording or locking to see a change. Use the fixture adapter, `tools/nested_hypr.py` (a hidden nested Hyprland, docs/NESTED.md) and offscreen smoke tests. The owner's live session is not your test bench.
- **Only adapters know DMS, Quickshell services or Hyprland.** The island reads contract domains.
- **Budgets** (docs/BUDGETS.md): 0 frames when idle between minute ticks (visualiser off); p99 ≤ 6.9 ms on expansions. Destroy what is not visible; pair every lease acquire with its release. Measure before claiming a gain; report RSS, PSS and private dirty separately.
- **No pixelSize literals:** font sizes come from the type scale (`tests/test_layout.py` enforces it). Directory imports use `qs.*` modules; run `python3 tools/make_qmldirs.py` after adding QML files.
- **Privacy:** this repo is public. No coordinates, SSIDs, MAC addresses, device names, clipboard or notification contents, home paths or email addresses in anything you commit.
- Add no dependency without a concrete benefit; record third-party assets and adapted code in NOTICE.
- **Never edit** the Serpantinum session, its files, the FART archive or FART-next. **Never push.** Ask before changing Hyprland config, installing packages, or deleting any file that is not yours.
- The Serpantinum session and the owner's `~/.config` stay untouched.

## Tests you must keep green
Run from the repo root: `python3 -m unittest discover -s tests` (about 10 minutes; run the files you touch first). Add offscreen smoke tests for each expansion, following the existing room smoke tests.

## Inputs (read these, nothing else unless one points to it)
- `HANDOFF.md` (top two entries), `AGENTS.md`, `docs/OPEN.md`
- `docs/SURFACES.md` §1 (the island) and `docs/DECISIONS.md` (the Z-numbers above)
- `docs/VISION.md`, `docs/fart/DESIGN_SYSTEM.md`, `docs/fart/MONTAGE.md`, `docs/fart/CUES.md`, `docs/CONTRACT.md`, `docs/ARCHITECTURE.md` (Processes), `docs/BUDGETS.md`
- `view/contract/`, `view/shell/`, `view/cues/`, `view/ui/`, `adapters/fixture/`
- `docs/NESTED.md` and `tools/nested_hypr.py` for live checks

## Output
Mock-ups for approval, then the island's QML, its fixture-driven tests, and a HANDOFF.md entry at the top after each step: what changed, how it was checked, what is next. Short updates, plain words. If a check fails, say so with the output.

## Stop rule
After step 1, stop and wait for the owner. Don't start step 2 without their approval of the look.
