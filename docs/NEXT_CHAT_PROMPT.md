# Paste this into the next Codex chat

> **Update 15 Nov, Claude A:** Fluid Performance ("the star") and Fluid Tasks ("star atlas") are owner-picked and
> being built by Claude A. Read `docs/UI_INSPIRATION.md` first; pick other Fluid work with the owner.

Continue FART / ZÆTHERION FLUID Phase 2 in this repository. **Implement; do not restart
the project, redesign Confluence, repeat Phase 1 or deliver another proposal.**

The owner explicitly says: **we reward creative implementation, not proving you know
the existing code. Read only what is required.** Previous sessions spent too much of
their allowance reconstructing context. Correct that behaviour from the first tool call.

## Current checkpoint

- `s0-seed` contains the merged and deployed Fluid checkpoint. Home and Media have separate
  Angular/Confluence presentations backed by persistent controllers. Settings has Angular /
  Fluid beside Palette, using `island.form` → `Design.form`; palette and mode are independent.
- Existing Overdrive effects work. Dedicated Fluid transitions, other rooms and shared
  shell framing remain unfinished. A global selector does not mean every room is converted.
- Merge: `bc16cde`; integration: `01f2f88`; cue test fix: `cdc7a51`; generated module ordering:
  `e325f3a`; verification handoff: `e7a89f7`; creative standards: `a58f9a9`.
  These are landmarks, not a request to read every commit. Discover newer work with Git.
- Claude A is actively working on FART too. Main is live. Start a fresh `codex/` worktree
  from current `s0-seed`; the older Fluid branches are behind main. Preserve concurrent work.
  Do not reload the live view merely to inspect it or overwrite the owner's current choices.

## First implementation task

**Build the next incremental Confluence room: Performance.** Preserve Angular's visuals
and behaviour. Reuse existing telemetry/services. Extract only the shared state and
resource ownership needed to survive presentation replacement. Reuse `PresentationHost`
and existing Fluid primitives. Do not turn this into a broad refactor.

Use a purposeful composition that makes important readings and relationships clear.
Avoid a generic metric-card grid or an astronomy decoration pasted onto it. Confluence
means connected matte surfaces, deliberate negative space, elegant proportions and
restrained architectural curves. Its Silent and Overdrive modes share one design system.
No new Performance-specific concept has been approved; develop within the approved
direction, and ask only if an unresolved owner-level behaviour or direction blocks it.

Starting points, **only as needed**:

- `view/rooms/Performance.qml`, `tools/cuetest/PerformanceTest.qml`.
- `view/rooms/OrreryField.qml`, `view/rooms/Orrery.js` if the room's behaviour requires them.
- `view/rooms/Home.qml`, `HomeSession.qml`, `view/shell/PresentationHost.qml` for the existing
  controller/presentation pattern; inspect relevant symbols rather than all three files.
- `view/fluid/` for tokens and reusable controls. Tests include `tests/test_orrery_laws.py`
  and `tests/test_core_orrery.py`; select checks according to the actual change.

## Reading discipline — enforce this

1. Begin with `pwd`, `git status --short`, branch, recent commits and worktree list.
2. Follow repository instructions using the current HANDOFF entry, relevant DECISIONS /
   OPEN sections and `docs/UI_CREATIVE_HANDOFF.md`. Read the creative brief once.
3. Spend roughly **10–15% of effort on orientation**, then implement. Aim for 4–6 focused
   initial read/search calls; this is a soft limit, not permission to skip a real dependency.
4. Before a substantial read, identify the implementation decision it will resolve.
   Use `rg`, targeted line ranges and diffs. No recursive repository reading, historical
   handoff archaeology, repeated unchanged-file dumps or full original design proposals.
5. After two searches without an actionable finding, change approach. Existing code and
   tests are enough when they establish the required contract. Do not seek perfect context.
6. Produce the smallest coherent working slice, inspect it, fix concrete failures, and
   continue. Keep progress updates brief. A long plan is not the deliverable.

## Verification and boundaries

Use fixtures and nested Hyprland for visual captures and UI integration. Never actuate
real playback, volume, networking, locking or power to test appearance. Preserve protected
paths, DMS integration, palette independence, controller state, focus and lease counts.
Respect reduced motion and hidden-work budgets; no 144 Hz claim from 60 Hz evidence.

The last checkpoint passed 64 Home/Media nested checks, six closing animation scenarios,
focused regressions, ten-room smoke and QML syntax checks. The 1104-test broad run had
issues subsequently addressed with focused reruns; **it was not a clean full-suite pass**.
Details are in HANDOFF. Do not rerun that long suite merely to regain confidence.
Use `QT_LOGGING_RULES=qml.debug=true` for tests that read QML debug markers; regenerate
module lists with `python tools/make_qmldirs.py` after adding components.

Finish with working code and inspected evidence. Report completed, verified, remaining,
branch/worktree/commit state, and one precise next task. Update HANDOFF. Leave the next
chat an implementation starting point, not another repository-reading assignment.
