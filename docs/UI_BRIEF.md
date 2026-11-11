# UI brief: the island (S3), for GPT 6.1 SOL

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
- `docs/DESIGN_SYSTEM.md`, `docs/MONTAGE.md`, `docs/CONTRACT.md`, `docs/ARCHITECTURE.md` (Processes), `docs/BUDGETS.md`
- `view/contract/`, `view/shell/`, `view/cues/`, `view/ui/`, `adapters/fixture/`
- `docs/NESTED.md` and `tools/nested_hypr.py` for live checks

## Output
Mock-ups for approval, then the island's QML, its fixture-driven tests, and a HANDOFF.md entry at the top after each step: what changed, how it was checked, what is next. Short updates, plain words. If a check fails, say so with the output.

## Stop rule
After step 1, stop and wait for the owner. Don't start step 2 without their approval of the look.
