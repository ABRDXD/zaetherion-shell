# F2 brief: the `dms` adapter (Fable design session, S2)

One page. Read this, then only the inputs listed below. Don't search the whole repo. Runs **in parallel with F1** (the supervisor) in a separate worktree; see "Parallel rules".

## Goal
Design how `adapters/dms` implements the **existing** 14-domain host contract (`view/contract/`) on DMS's socket, so FART's rooms don't change. The contract and its lease table already exist: don't redesign them. Deliver the design and **one finished slice: network**, end to end against the fixtures (docs/ROADMAP.md S2).

## The design must cover
1. **Request/reply → contract.** DMS is JSON request/reply plus subscribed events over `$XDG_RUNTIME_DIR/dms-<pid>.sock`; the contract is fire-and-forget methods that never throw and report through properties. The mapping, including in-flight requests, timeouts and errors.
2. **Which DMS service backs which domain and which lease** (`scan`, `details`, `history`, `mixer`, …). Audio, notifications, lock, idle and polkit are **not** in DMS's Go backend (DMS_BACKEND.md): those stay on Quickshell primitives; say which adapter owns them.
3. **Leases ↔ subscriptions:** subscribe on acquire, resubscribe with the shorter list on release. No subscription without a lease.
4. **Capability gating and versions:** the 21 capabilities seen on this machine (DMS_OBSERVED.md); `apiVersion` is **38** on the installed 2.1.0, not the 40 the plan assumed (Z9: pin the accepted range). What a domain shows when a capability is missing, the version is out of range, or DMS is OFFLINE (Z11, Z123, Z126).
5. **DMS restarts (target: recovered ≤ 5 s).** The socket name changes with the pid, and the resident UI is DMS's child, so a DMS restart also restarts the resident (docs/F1_RECON.md). Say how the adapter finds the new socket (`DMS_SOCKET` from the launcher, Z10) and restores its subscriptions.
6. **Privacy:** the clipboard is never read outside the `history` lease; DMS clipboard history stays off for the owner (`clipboard.setConfig {"disabled": true}` is the switch that works, DMS_OBSERVED.md). Fixtures stay scrubbed (Z113).

## Constraints
Z9, Z10, Z11, Z14, Z15, Z16, Z113, Z123, Z126 (docs/DECISIONS.md). AGENTS.md: nothing assumed (ask the owner in plain words if DECISIONS and OPEN don't answer), no actuation for tests (no Wi-Fi connect/disconnect, no setting changes on the real DMS), public repo privacy. Only adapters know DMS.

## Acceptance
From docs/MILESTONES.md S2, for this slice: rooms pass smoke and contract tests on the `dms` adapter for network; killing `dms` recovers in ≤ 5 s (shown against the stand-in server `tools/dms_replay.py`).

## Output
- `docs/DMS_ADAPTER.md`: the design (points 1–6), the service ↔ domain ↔ lease table, and open items (added to docs/OPEN.md).
- Skeleton `adapters/dms/` (qmldir, adapter root, socket client) plus **network** done end to end against `tests/fixtures/dms/s0-v2.1.0.json` via `tools/dms_replay.py`, with tests (contract test, lease test, restart/recovery test).
- A HANDOFF.md entry describing the pattern so a cheaper model copies it to bluetooth, brightness, clipboard, loginctl, lyrics and the rest.

## Out of scope
The supervisor (F1, in the other session), other domains beyond network, the resident UI (S3), any change to the owner's running DMS or its settings, Hyprland config.

## Parallel rules (F1 runs at the same time)
- Work only in the worktree `~/src/zaetherion-shell-f2`, branch `f2-dms-adapter`. Commit there; never push; never touch the main checkout or branch `s0-seed`.
- Don't edit `core/` (F1 owns it), `tools/session-start` or `tools/zaetherion.py`. If the adapter needs something from `fartd` (e.g. a "DMS restarted" event), write the need into `docs/DMS_ADAPTER.md` under "Needs from F1".
- HANDOFF.md and OPEN.md: add your own new entries at the top only, so the merge is easy. Claude A merges both branches.
- Never start a second real DMS in the owner's runtime folder: it takes over the shared `dms.path` and the owner's keybinds (docs/F1_RECON.md). Use `tools/dms_replay.py`, or a private `XDG_RUNTIME_DIR` inside the nested Hyprland (docs/NESTED.md).

## Inputs (read these, nothing else unless one points to it)
- docs/DMS_BACKEND.md, docs/DMS_OBSERVED.md, docs/F1_RECON.md (§Start, §Shared state only)
- docs/fart/ADAPTER_CONTRACT.md; `view/contract/HostDomain.qml`, `HostAdapter.qml`, `NetworkDomain.qml`
- `adapters/serpantinum/SerpantinumNetwork.qml`, `SerpantinumAdapter.qml`, `adapters/fixture/FixtureAdapter.qml` (existing adapter pattern)
- `tools/dms_replay.py`, `tests/test_dms_fixtures.py`, `tests/fixtures/dms/s0-v2.1.0.json`
- docs/DECISIONS.md, the Z-numbers above only; docs/ROADMAP.md S2 entry and §2
- `tools/smoke.py` (how rooms are smoke-tested)

## Stop rule
When the output above is delivered, write the HANDOFF entry and stop. No routine edits with leftover limit.
