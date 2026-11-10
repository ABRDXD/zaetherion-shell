# Roadmap: who builds what, and in what order

This is the working roadmap for building ZÆTHERION. It sits on top of [MILESTONES.md](MILESTONES.md), which defines S0–S12 and their acceptance tests, and changes none of them. It adds three things: the order of work inside each milestone, which model does which part, and what the owner approves along the way.

**Status of this file:** a proposal written 10 November 2026. The model split is not in DECISIONS.md. If the owner changes it, change it here. Nothing in this file overrides AGENTS.md ("nothing is assumed"; ask before the listed approvals).

**Start condition (Z1):** FART-next's Overdrive is around its M12, and the owner says so. Until then, no shell code is written.

## 1. Why there are two models

Fable 5.2 is the strongest model available and also uses the usage limit much faster than Sonnet 5.5. So Fable is spent only where one wrong design is expensive, and Sonnet does the rest.

**Fable gets work that is:**
- a design with no obvious right answer (lifecycle, ownership, failure recovery);
- security-sensitive or hard to undo (lock screen, display reset, keybind rollback);
- a bug whose cause is still unknown after a Sonnet attempt;
- a final review of code that is hard to test by hand.

**Sonnet gets work that is:**
- following a pattern that already exists (a second or third adapter, a fourth room);
- QML layout, visuals, motion tuning and shot checks;
- fixtures, tests, measurement scripts and docs;
- reading, grepping and listing (method lists, parity rows, package checks).

**Opus 5.5 is the middle tier.** It takes work that needs more thought than Sonnet but where a mistake is recoverable:
- reviews of code that is already tested (leaks, races, missed edge cases);
- smaller design questions with a clear shape (for example key buffering on a cold panel);
- the first escalation when Sonnet is stuck, before Fable is considered;
- measured-budget misses (idle frames, memory not returning to baseline) where the cause is unknown.

**Owner's measurement (10 November 2026):** Opus thinks more than Sonnet and its limit lasts about one hour less, but the code it produces is better, and the owner judges that trade worth it. So Opus also **writes** the code where quality matters and the work is not just copying a pattern:
- S3: the island state machine and priority queue;
- S6: launcher input, search and ranking;
- S7: the implementation of the lock, idle and polkit design (Fable designs and reviews it, Opus builds it);
- S2: the first non-trivial adapters after F2 (for example bluetooth with its pairing agent).

Sonnet keeps pattern-copying, layout and visuals, fixtures, tests, measurement scripts and docs. Its usage rate against Fable has not been measured; after the first Fable session, check `/usage` and move work between the tiers if needed.

**Escalation ladder:** Sonnet → Opus → Fable. Each step needs a written note of what the previous one tried.

**Rule of thumb:** if the task can be written as a checklist, it is Sonnet's. If it starts with "decide how" and a mistake is recoverable, Opus. If a mistake is costly or hard to undo (lock screen, display reset, adapter lifecycle), Fable.

## 1a. House style, taken from FART-next (read 10 November 2026)

Every model follows the style already in `fart-next`, so that the code stays consistent whichever model wrote it:
- **Lifecycle code is a pure `step(state, event, now) → (state, effects)`**, with a thin class that runs the effects (see `core/overdrive.py`). Each branch cites a numbered row in a transition table in `docs/`, and there is one test per row. This applies to the supervisor (S1), the island queue (S3) and the lock (S7).
- **Adapters implement the existing 14-domain contract** (`view/contract/`; `docs/ADAPTER_CONTRACT.md` in FART-next). Values are plain objects with fixed units. Methods are fire-and-forget, never throw, and report outcomes through properties. Costly work runs only while a lease is held, and every lease is checked by a test.
- **Zero cost when idle.** Nothing polls without a reason. Any new periodic work needs a lease and a measured budget.
- **Docs and code agree.** When they disagree, the code wins and the doc is fixed.
- **Fixtures are the test seam.** Anything that talks to DMS has a recorded, scrubbed fixture and a test that replays it.

## 2. How a Fable session works

Fable sessions are short and planned. Each one has a brief, a fixed set of inputs and a stated output, so it never spends its limit exploring.

1. **Prepare with Sonnet first.** Sonnet does the recon and puts the results in a file: recorded fixtures, measurements, the list of relevant code.
2. **Brief.** One page: the goal, the constraints (by Z-number), the acceptance test from MILESTONES.md, and what is out of scope.
3. **Inputs.** Name the files to read. Do not let it search the whole repo.
4. **Output.** A design note in `docs/` or a skeleton plus **one finished slice** with tests. It does not roll the pattern out to every case.
5. **Hand back.** Fable writes the pattern down in a HANDOFF entry. Sonnet continues from there.
6. **Stop rule.** If the output is delivered, end the session. Do not use leftover limit for routine edits.

**Escalating:** after two failed Sonnet attempts on the same problem, or when a measured budget is missed and the cause is not found, go to Opus. Go on to Fable only if Opus also fails, or if the problem is in the Fable list above. Write down what was tried first, and hand that over.

## 3. The plan, milestone by milestone

Legend: **F** = Fable session, **S** = Sonnet work, **(A)** = owner approval needed first, per AGENTS.md.

### S0 — Seed
Mostly routine. **No Fable.**
- S: ask for approval to install `dux-shell-git` **(A)**; seed from a tagged FART-next commit and record it in NOTICE; read-only check for tesseract, zbarimg and satty (OPEN 2); quiet RSS/PSS baseline.
- S: start `dms debug-srv` or `dms run`, read the real socket path and `getServerInfo`, list the methods (grep the QML services for method names), and record the fixtures: greeting, `getServerInfo`, one reply per method, events. Scrub them (Z113) and grep before anything is committed.
- This recon is the input that makes the Fable sessions below short. Do not skip it.

### S1 — Session
- **F1 (design): the supervisor.** `fartd` supervising `dms run -c` and the panel. Cover: restart with backoff, what happens when DMS (the panel's parent) dies, named clients, clean logout with no leftover processes, and the Serpantinum session staying untouched. Output: a state-machine note and a skeleton with a transition-table test.
- S: nested Hyprland check (Z109). If it is not viable, stop and ask the owner how lock testing proceeds.
- S: `zaetherion start/stop/restart/status`; the Hyprland require list and autostart **(A)**; the SDDM session file **(A, root)** — prepared by Sonnet, installed only on the owner's go-ahead.

### S2 — Adapters (the DMS connection)
This is the main place to spend Fable.
- **F2 (design, same session as F1 if the limit allows): the `dms` adapter.**
  - How `adapters/dms` implements the **existing** 14-domain contract so rooms don't change. The contract and its lease table already exist, so this session does not design them. It decides how DMS request/reply maps onto fire-and-forget methods that report through properties, and which DMS service backs which lease (`mixer`, `scan`, `details`, `history`, …). Audio, notifications, lock, idle and polkit are not in DMS's Go backend (see DMS_BACKEND.md), so their adapters stay on Quickshell primitives.
  - Tying DMS subscriptions to FART leases: subscribe on acquire, resubscribe with the shorter list on release.
  - Capability gating, the pinned `apiVersion` range (40 at planning), and what a room shows when it is OFFLINE or out of range.
  - Recovery when `dms` restarts (target ≤ 5 s).
  - Output: design note, skeleton, and **network** done end to end against the fixtures, with tests.
- S: copy the pattern to bluetooth, brightness, clipboard, loginctl, lyrics and the rest, one at a time, each against its fixture.
- S: `quickshell`, `hyprland`, `serpantinum-assets` and fixture adapters.
- S: the measurement items: wellbeing side by side for 2 days (OPEN 1), lyrics hit rate (OPEN 3), panel reap timer at 10 and 60 min (OPEN 5). Report the numbers to the owner; the owner decides.
- **F3 (review): the finished adapter.** Look for lease leaks, subscription races, and behaviour when `dms` dies mid-request. Input: the diff, the tests, and the Sonnet-written list of what was tried. Output: a findings list; Sonnet fixes.

### S3 — Island
- S: rest, hover wings, click to panel, priority queue, workspace flash, fullscreen hide, notch/floating, top/bottom, tray menus, keyboard focus **(A for the bind)**, long-press ignite. Decide OPEN 7 and 11 with the owner.
- S: record per-surface budgets.
- **F only if** "0 frames idle between minute ticks" or "p99 ≤ 6.9 ms on expansions" is missed and one Sonnet attempt did not find the cause.

### S4 — Notifications
- S: server with actions, inline reply, images, sound, 24 h persistence, DND, Inbox as authority; the `notify-send` matrix. No Fable.

### S5 — OSD and keys
- S: volume, mic and brightness expansions, EQ filter-chain, media and brightness keys. No Fable.
- Acceptance includes "keys work with the panel reaped", so test that case first.

### S6 — Launcher
- **F4 (design, short): key capture while the panel is cold.** Z139 wants key → typing accepted ≤ 100 ms with no lost keys. Decide how keys pressed before the panel is ready are buffered and replayed. Output: a design note and a test that types fast into a cold panel.
- S: tabs, prefixes, frecency, file index (watch the inotify limit, Z78), emoji, clips, calc, converters, Brave, windows, verbs, session blocklist. Binds **(A)**.

### S7 — Lock, idle, polkit, session card
Security-critical. The owner chose no fallback locker (Z35), so a crash must never leave a blank locked screen or an open session.
- **F5 (design): lock architecture.** Lock survives a resident crash and a DMS restart (`allow_session_lock_restore`); what draws while the resident restarts; wrong password and PAM errors; resume paths; what a failing sky layer does (degrade to a plain card, never unlock). Output: design note and a threat/failure table with a test per row.
- S: build the nested-Hyprland harness with a fake PAM, write the failure-table tests, and implement the idle timeline at 150/300/450/600 s using fixture time.
- **F6 (review): the lock, idle and polkit code.** Independent review of the finished code against the table. Use Fable's `/code-review`-style pass; give it the table, not the repo.
- Real-session lock and polkit checks happen only with the owner present (Z109).

### S8 — Wallpaper and palette
- S: image mode (picker, montage wipe, video, cuts, online search), sky mode, ephemeris in `fartd` (check positions against a reference to 1°), Matugen and templates, presets, contrast guard on ≥ 5 presets, Silent ≤ 1 redraw per minute.
- S: confirm the star catalogue licence (OPEN 4). Ask the owner on OPEN 9, 10 and 12.
- S: if video decoding wakes the dGPU, measure `runtime_status` and report. **F only** if the cause is not found after one attempt.

### S9 — Capture and draw
- S: selector, satty, recording, OCR, QR, snip-to-search, right-edge hover, draw canvas. No Fable.

### S10 — Widgets, settings, boot
- S: widget kinds and editor, desktop menu, every settings tab, voice toggle, weather, PARITY.md walk-through (every row kept, replaced or dropped). Boot lines **(A)** (OPEN 8).
- **F7 (design + review): the two safety paths.** Display reset (Z92–Z94: a bad output config must always be recoverable) and keybind rollback (Z93: check `hyprctl configerrors`, keep the previous file, roll back automatically). These can blank the screen or lock the owner out of their binds. Output: design note, then a review of the implementation. Test in nested Hyprland, not the live session.

### S11 — Overdrive shell tiers
- S: sky animation, island kinetic lyrics, launcher and overview lensing, live thumbnails. This reuses FART-next's Overdrive patterns.
- Acceptance: release returns to the Silent baseline ±10 MiB within 5 s, and the dGPU never wakes.
- **F only if** memory does not return to baseline and Sonnet's leak hunt (lease by lease) finds nothing.

### S12 — Trial and retirement
- S: run the 7-day trial and keep the trial log (Z110); track unplanned fallbacks; rehearse rollback.
- **F8 (audit): before the retirement gate.** One cross-cutting pass over the whole shell: leaks across leases, the lock path, secrets or personal data in the public repo, and anything that still reads from Serpantinum (Z125). Output: a go/no-go list.
- Retiring the Serpantinum session and FART-next, and deleting Serpantinum files one by one, are **(A)** every time (Z111).
- Later: niri adapter, discovery and lore.

## 4. Fable budget at a glance

| Session | Milestone | Kind | Why it is Fable |
|---|---|---|---|
| F1 | S1 | design | supervisor and failure recovery |
| F2 | S2 | design + one slice | adapter, leases, ownership; the core of the DMS connection |
| F3 | S2 | review | leaks and races (**Opus first**; Fable only if Opus finds the design itself is wrong) |
| F4 | S6 | design | key capture on a cold panel (**Opus**; smaller and recoverable) |
| F5 | S7 | design | lock architecture, no fallback locker |
| F6 | S7 | review | security |
| F7 | S10 | design + review | display reset, keybind rollback (design Fable; the review can be **Opus**) |
| F8 | S12 | audit | go/no-go before retirement |
| escape | any | debug | Sonnet → Opus after two failed attempts; Fable only after Opus fails |

Eight planned sessions in total. Fable is firm for F1, F2, F5, F6, F7's design and F8. F3, F4 and F7's review start on Opus. S3–S5, S8–S9 and S11 should need no planned Fable or Opus session; Opus is the first stop if a budget is missed there.

## 5. Rules that apply to everyone

- Start every task with HANDOFF.md, then DECISIONS.md, then OPEN.md (AGENTS.md).
- Every milestone ends with a Git checkpoint, a HANDOFF entry, and issues closed against the acceptance items.
- Do not actuate playback, volume, network, recording, power, locking or destructive actions just to test a visual change. Use fixtures, nested Hyprland and temporary surfaces.
- Never edit the Serpantinum session, the FART archive or FART-next from this repo.
- The repo is public. Scrub fixtures (Z113) and grep for coordinates, SSIDs, MACs, notification text, clipboard text, absolute home paths and email addresses before every push.
- Pushing, installing packages, root changes, Hyprland config and keybind changes, and deleting Serpantinum files all need the owner's approval each time.

## 6. Order at a glance

```
S0 recon (S) ─► S1 F1 ─► S2 F2 ─► S2 rollout (S) ─► S2 F3
                                       │
                         S3 ─► S4 ─► S5 ─► S6 (F4)
                                       │
                                 S7 (F5 ─► S ─► F6)
                                       │
                         S8 ─► S9 ─► S10 (F7) ─► S11
                                       │
                                 S12 (trial) ─► F8 ─► retirement (A)
```

S3–S5 can start once S2's adapters are in. S8 and S9 do not depend on S7 and can run beside it if the owner wants.
