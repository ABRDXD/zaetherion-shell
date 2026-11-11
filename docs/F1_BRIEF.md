# F1 brief: the supervisor (Fable design session, S1)

One page. Read this, then only the inputs listed below. Don't search the whole repo.

## Goal
Design how `fartd` (ZÆTHERION's core) supervises `dms run -c <resident dir>` and the disposable panel, replacing the interim `tools/session-start` loop. Deliver the design and **one finished slice**, not the full rollout (docs/ROADMAP.md §2).

## The design must cover
1. **States and transitions** for each supervised child: starting, up, crashed, backing off, stopping, stopped, given up (if any). A written transition table.
2. **Restart with backoff** (Z11): the policy, when the backoff resets, and what happens after repeated quick crashes.
3. **DMS is the resident UI's parent** (Z10, RISKS row 2): one exit event covers both a DMS crash and a UI crash (docs/F1_RECON.md). How the supervisor tells them apart for the crash notice (Z127) and the trial log (Z110), and announces down/up on the island (Z123; the island exists from S3, so emit the events now).
4. **Owner restarts** (`dms restart`, Super+R) replace DMS with a process that isn't fartd's child. Recognise this as "restarted by the owner", not a crash, and don't start a second DMS.
5. **Named clients** (ARCHITECTURE.md "Startup and supervision"): `fartd` assumes one view today (`core/view.py`, `core/app.py`, `kind == "view"`). Generalise to `resident` and `panel` without breaking the panel's spawn/reap behaviour (Z12, Z91, Z142).
6. **Clean logout with no leftover processes:** what ends the session (Hyprland socket gone, SIGTERM, SIGHUP), the stop order, signals and timeouts. Recon: HUP or KILL on `dms` orphans its `qs`, and `qs` has its own children (polkit helpers, a log `tee`). Kill whole trees.
7. **`dms.path`**: DMS keeps one shared pointer file that every DMS keybind uses, and deletes it when it exits (recon). Say how the supervisor avoids a stray second DMS and the no-keybinds gap during restarts, or record it as a known limit.
8. **Lock safety** (Z35, RISKS row 1): no fallback locker. A restart while locked must let the new resident take over the lock (`allow_session_lock_restore` is set in the session config; docs/NESTED.md shows a new lock client takes over). Design only; the lock itself is S7.
9. **The Serpantinum session stays untouched.** Nothing here runs in or edits it.

## Constraints
Z10, Z11, Z12, Z35, Z91, Z110, Z123, Z127, Z142 (docs/DECISIONS.md). AGENTS.md rules: nothing assumed (if neither DECISIONS nor OPEN answers a behaviour question, ask the owner in plain words), no actuation for tests, privacy (public repo: no home paths, device names or user names), Python stdlib only in `fartd`.

## Acceptance (docs/MILESTONES.md, S1)
Login starts fartd → dms → resident; the Serpantinum session is unchanged; logout leaves no processes. For this session: the transition-table test passes, and the slice below runs in the nested test Hyprland.

## Output
- `docs/SUPERVISOR.md`: the state machine, the transition table, the logout sequence, how each recon finding is handled, and anything left open (added to docs/OPEN.md).
- A skeleton (`core/supervisor.py` or similar) with a **table-driven transition test** using fake processes and the fake clock (pattern: `tests/test_core_view.py`, `tests/core_fakes.py`).
- **One finished slice:** supervising `dms run -c` end to end (start, crash → backoff → restart, owner restart, logout teardown of the whole tree), checked live with `tools/nested_hypr.py` and a private `XDG_RUNTIME_DIR` for the test DMS (recon §Shared state). The panel generalisation and switching the real session over to it are follow-up work.
- A HANDOFF.md entry describing the pattern so a cheaper model continues.

## Out of scope
- Switching the owner's live session from `session-start` to the new supervisor (needs the owner's go; propose it, don't do it).
- Any Hyprland config or keybind change (approval).
- The resident UI (S3), lock implementation (S7), systemd units.
- **F2 (the `dms` adapter)** only if the limit clearly allows after F1 is delivered, with its own brief written first.

## Inputs (read these, nothing else unless one points to it)
- docs/F1_RECON.md (measured DMS behaviour), docs/NESTED.md
- docs/ARCHITECTURE.md §Processes and §Startup and supervision
- docs/DECISIONS.md, the Z-numbers above only; docs/RISKS.md first two rows; docs/MILESTONES.md S1 row; docs/ROADMAP.md §2 and the S1 entry
- `tools/session-start` (current behaviour to replace)
- `core/fartd.py`, `core/view.py`, `core/app.py` (spawn, hello, reap), `core/protocol.py` (client kinds)
- `tools/zaetherion.py` (`start_core`, `stop_core`)
- `tests/test_core_view.py`, `tests/core_fakes.py` (test style)
- `tools/nested_hypr.py` (live checks)

## Stop rule
When the output above is delivered, write the HANDOFF entry and stop. No routine edits with leftover limit.
