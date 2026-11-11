# The supervisor (F1, S1): how `fartd` keeps DMS and the panel alive

Designed 11 November 2026 from docs/F1_BRIEF.md and docs/F1_RECON.md. **Finished slice:** `fartd` supervising `dms run` end to end, behind `FART_SUPERVISE=dms` (off by default, so the session still runs on `tools/session-start` until the owner says switch). **Design only:** the panel on the same vocabulary (§9), the lock hand-over (§8).

| Piece | Where |
|---|---|
| State machine, driver, real-process code | `core/supervisor.py` (`Machine`, `Child`, `DmsPorts`, `SessionWatch`, `Supervisor`) |
| Wiring, opt-in | `core/fartd.py` `supervise()`; `core/app.py` `attach_supervisor()`, `close()` |
| Unit tests (fake processes, fake clock) | `tests/test_core_supervisor.py`, 24 tests |
| Live check (nested Hyprland, private folders) | `tools/supervisor_check.py`, 16 checks |

## 1. Shape

```
fartd
 ├─ Supervisor            topic `supervisor`, pushed `supervisor.event`
 │    └─ Child "dms"      Machine (pure table) + DmsPorts (spawn, find, probe, sweep)
 ├─ SessionWatch          Hyprland's event socket: closed and not reopenable = the compositor is gone
 └─ ViewManager           the panel, unchanged for now (§9)
```

`Machine` knows no clock and no processes: it maps (state, event) to (next state, actions). `Child` runs the actions through its *ports*, so tests swap in fake processes and the fake clock. `DmsPorts` is the only code that knows how DMS behaves.

## 2. States and transitions

| State | Meaning |
|---|---|
| `stopped` | Not wanted, nothing running |
| `starting` | Looking for a DMS that already runs; adopting it, or spawning ours; then waiting until it is ready (its socket file exists and its UI process runs; 10 s limit) |
| `up` | A `dms` runs with its UI. `owned` says whether we started it or adopted it (§5); it is a flag, not a state |
| `crashed` | It went down; what is left of its process tree is being stopped. Nothing is started before this finishes |
| `backoff` | Waiting before the next start, and looking out for a DMS someone else starts (§3) |
| `stopping` | Stop requested; the whole tree is being stopped |
| `failed` | Given up after `limit` failures in a row. **Never reached by `dms`** (§3) |

Events: `start`, `stop` (requests); `spawned`, `adopted`, `spawn_failed` (the launch's three outcomes); `ready`, `start_timeout`; `exited` (our child ended, or the adopted one did); `swept` (the tree is gone); `timer` (the wait is over); `stable` (up for 60 s).

Every pair not in the table is ignored: nothing changes. `backoff or failed` is decided by the policy's limit. The test reads this table from this file and compares it with `TABLE` in the code, so neither can drift.

<!-- table:start -->
| State | Event | Next | Actions |
|---|---|---|---|
| `stopped` | `start` | `starting` | `launch` |
| `stopped` | `spawned` | `stopping` | `sweep` |
| `stopped` | `adopted` | `stopping` | `sweep` |
| `starting` | `spawned` | `starting` | `probe` |
| `starting` | `adopted` | `starting` | `watch`, `probe` |
| `starting` | `spawn_failed` | `backoff or failed` | `fail` |
| `starting` | `ready` | `up` | `arm_stable`, `note_up` |
| `starting` | `start_timeout` | `crashed` | `fail`, `cancel`, `note_down`, `sweep` |
| `starting` | `exited` | `crashed` | `fail`, `cancel`, `note_down`, `sweep` |
| `starting` | `stop` | `stopping` | `cancel`, `sweep` |
| `up` | `exited` | `crashed` | `fail`, `cancel`, `note_down`, `sweep` |
| `up` | `stable` | `up` | `reset` |
| `up` | `stop` | `stopping` | `cancel`, `sweep` |
| `crashed` | `swept` | `backoff or failed` | — |
| `crashed` | `stop` | `stopping` | `sweep` |
| `backoff` | `timer` | `starting` | `cancel`, `launch` |
| `backoff` | `start` | `starting` | `cancel`, `launch` |
| `backoff` | `stop` | `stopped` | `cancel`, `note_stopped` |
| `failed` | `start` | `starting` | `reset`, `launch` |
| `failed` | `stop` | `stopped` | `note_stopped` |
| `stopping` | `swept` | `stopped` | `note_stopped` |
| `stopping` | `spawned` | `stopping` | `sweep` |
| `stopping` | `adopted` | `stopping` | `sweep` |
<!-- table:end -->

Actions: `launch` (adopt a running DMS or spawn ours), `probe` (wait for ready), `watch` (pidfd on an adopted DMS), `arm_stable`, `cancel` (timers, probe, watch), `sweep` (§6), `schedule` (the wait and its look-outs), `fail`/`reset` (the failure count), `note_up`/`note_down`/`note_stopped`/`gave_up` (events, §4).

Three rules the table encodes, each with its own test:
- **A process that arrives late is never left running.** A spawn in flight when `stop` arrives is waited for and then stopped.
- **`stop` from any state ends in `stopped`,** and no timer brings the child back.
- **Nothing is started while a tree is still being stopped:** `crashed` is left only by `swept` or `stop`.

## 3. Restart and backoff (Z11)

- Wait by failures in a row: **0.25, 1, 2, 4, 8, 16, 30 s**, then 30 s each time.
- The count returns to zero after **60 s up**. That is the only reset.
- Every unrequested exit counts, including a clean one. After a **clean exit** (code 0, or an adopted DMS that went without leaving its UI behind) the wait is **at least 3 s**: someone is probably bringing a new DMS (§5).
- **While waiting, the supervisor looks for a DMS someone else started:** every 0.1 s for the first 3 s, then once a second. The moment it sees one, the wait ends and that DMS is adopted. This runs only during `backoff`; nothing is polled while DMS is up.
- **`dms` never gives up.** Z11 says degrade and restart, and with no fallback locker (Z35) a supervisor that stops trying could leave a locked screen with nothing behind it. After repeated quick crashes it keeps trying every 30 s; each `down` and `retry` event carries `failures`, so the notice can say "keeps crashing" (wording at S3).
- `limit` exists in the policy for the panel (Z128: 3 quick crashes halt it). `failed` + `start` tries again.
- Nothing is started once the compositor is gone (§6).

Measured live: UI killed → back up in **0.37 s**; RISKS row 2 asks for ≤ 5 s.

## 4. Which one crashed, and the announcements (Z127, Z110, Z123)

DMS gives one exit event for both crashes. `classify()` decides from the exit status and from whether the UI is still alive at that moment. First match wins:

| Seen | Verdict (`what`) |
|---|---|
| `dms` died by a signal | `dms`, `signal` |
| exit code 0 | `stopped`: on purpose (`dms restart`, `dms kill`, a TERM) |
| `dms` gone while its UI still runs | `dms` |
| an adopted DMS gone, UI gone too (there is no exit status for a process that is not our child) | `unknown`: a restart or a UI crash |
| non-zero code before any UI was seen | `dms`, `code` |
| code 128+N for a real signal N, UI already dead (DMS mirrors its dead UI: 137, 143) | `resident`, `signal` |
| other non-zero code, UI already dead | `resident`, `code` (255 = the UI lost its compositor) |
| not ready within 10 s | `dms`, `hung` |

What is emitted, now, for S3's island and the trial log to consume:
- **Topic `supervisor`**: `{children: {dms: {state, pid, owned, socket, since, failures, retryAt, last}}}`. `socket` is the DMS socket path of the running instance: the panel's adapters reconnect from it. `last` is the last outage: `{what, signal|code, failures, downAt, upAt, owned}`.
- **Pushed once, `supervisor.event`** (like sound cues, never replayed): `down` (the verdict, `wasUp`), `retry` (`inSeconds`, `failures`), `up` (`pid`, `owned`, `downFor`), `duplicate` (`pids`, §5), `failed`, `stopped`.
- Every event is also one line in `core.log`; the notice's log link is `dms.log` beside it (`DMS_LOG_FILE`).
- **Z127:** the resident UI dies with DMS, so it cannot show its own crash. On start it subscribes, reads `last`, and shows the full notice if `upAt` is recent. `what: stopped` with `owned: false` reads "restarted by the owner", not a crash.
- **Z110:** the trial log takes `down`/`up` from `Supervisor.on_event` when it exists (S12); nothing is written yet.
- **Z123 has a gap** → OPEN 15: the island lives in the process that goes down, so "an expansion each time it goes down" can only be shown once it is back (or by the panel, if open).

## 5. Owner restarts (`dms restart`, Super+R)

Measured (nested, private folders): `dms restart` sends SIGUSR1; the old `dms` exits **0 within 0.07 s**; a new `dms run -d --daemon-child` appears **0.36 s** later with parent 1 and its own session. It **inherits the environment but not the flags**: started with `-c <dir>` the restart came back with DMS's stock UI; started with **`DMS_SHELL_DIR=<dir>`** it came back with the same UI.

So:
- **The supervisor passes the UI folder and the log as environment (`DMS_SHELL_DIR`, `DMS_LOG_FILE`), never as flags.** This is Z10's `dms run -c` by its documented environment name; without it every Super+R would swap ZÆTHERION's resident UI for DMS's.
- A clean exit is never answered with an immediate spawn: the supervisor waits up to 3 s (8× the measured gap) and **adopts the new DMS the moment its pid file appears**. Measured: `up` again **0.8 s** after the restart signal, `owned: false`, verdict `stopped`.
- **Before every spawn, `launch` looks for a DMS that already runs** in this runtime folder (`dms-<pid>.pid` whose process is alive, named `dms`, ours) and adopts the newest: no second DMS. Pid files, not process names: `dms cl copy` and other one-shot `dms` commands also carry the name `dms`, and write no pid file (the interim loop's `pgrep -x dms` counts them as a running shell).
- An adopted DMS goes through the same `starting` → `up` (ready check, 10 s limit) and is watched with a pidfd, not polled. When it goes, its leftover tree is swept and the wait in §3 follows.
- The same path covers a core restart: a `fartd` that died leaves DMS running in its own session, and the next `fartd` adopts it.
- **Known limit → OPEN 18:** a DMS that appears *after* ours was spawned (an owner restart slower than 3 s, or one started by hand) runs next to it. The supervisor looks again when ours is ready and once more after 60 s, and **reports** it (`duplicate` event, log line). It does not stop either: which one to stop is the owner's call.

## 6. Ending the session with nothing left over

What ends it, all leading to the same path (`core.stopping` → `Core.close()`):
1. **The compositor is gone:** `SessionWatch` holds a connection to Hyprland's event socket. When it closes, the watch tries once more after 0.2 s; only a refused reconnect counts as gone (a dropped connection alone is not proof), and nothing is started in between. Nothing is polled. It covers logout and a compositor crash.
2. **SIGTERM, SIGINT, SIGHUP** to `fartd` (SIGHUP is new: before, it killed the core without cleanup).
3. **`shutdown`** (`zaetherion stop`).

Order: the panel first (`view.reap`, as today), then DMS, then the core's own flushes and exit.

`sweep` for one child (worst case 6 s; measured clean path 0.57 s):
1. If the root (`dms`) is alive: **SIGTERM, wait up to 3 s.** TERM is the only signal on which DMS takes its UI down itself and removes its files.
2. Collect what is left of the tree: descendants of the root and of the UI by parent pid, **plus every process in the root's session** (we start `dms` in its own session; an orphaned UI keeps the session id although its parent is now pid 1).
3. SIGTERM those, wait up to 2 s; collect again; **SIGKILL**, wait up to 1 s. Each pass logs the names and pids it signals.
4. Anything still alive is logged by pid (`could not stop pids …`). A helper that has become root (`pkexec` after its prompt) cannot be signalled by us; it ends when its parent does, and is reported if not.

Processes are identified by pid **and** start time, so a reused pid is never signalled. The same `sweep` runs after every crash, which is what removes the orphaned UI when DMS dies by HUP or KILL (recon).

**What the sweep can and cannot reach** (measured 11 November 2026):
- The UI's helpers (`Process` in QML: `tee`, `pkexec`, scripts) are children of `qs` in the same session: reached.
- **Apps the owner starts from the shell are not reached.** DMS's app launch function (`SessionService.launchDesktopEntry`) uses `Quickshell.execDetached` on all three of its paths (plain, with a launch prefix, in a terminal); a process started that way has parent 1 and a session of its own (measured with a test UI). So a DMS crash, a restart or `zaetherion stop` never closes the owner's windows.
- The clipboard holder (`dms cl copy --foreground`) leads its own session: not reached, the copied text survives a DMS restart.
- **An adopted DMS that does not lead its own session is never swept by session,** only by its descendants. Today's DMS (started by `session-start`) shares Hyprland's session with every open app.

When the compositor goes first, the UI exits by itself (code 255) and DMS follows; the core may see that exit just before the watch confirms, and at worst sits in `backoff`, which `stop` cancels.

Not the supervisor's: the cliphist watchers and anything else Hyprland's own config starts.

## 7. `dms.path`

- **No stray second DMS from us:** adoption before every spawn, and the look-out during every wait (§3, §5).
- **The gap is kept short, not removed.** DMS deletes the file on exit and writes it again at start, so keybinds fail silently for the outage: about 0.3 s after a first crash, DMS's own 0.36 s on an owner restart, 3 s after a deliberate stop, up to 30 s while it keeps crashing. Writing DMS's file ourselves was rejected: it is DMS's private format.
- **Known limit, recorded:** if another DMS is started by hand next to ours and exits, the file is gone while ours still runs; Super+R (`dms restart`) repairs it. Tests never share the runtime folder (`tools/supervisor_check.py` uses private `XDG_*` folders and checks that the session's `dms.path` and pid files are unchanged).

## 8. Lock safety (Z35; design only, built at S7)

- The supervisor never gives up on `dms` and never needs to stop it except at session end, so a locked screen always gets a new resident.
- The compositor keeps the screen covered when the lock client dies, and a new client may take the lock over (`allow_session_lock_restore`; docs/NESTED.md checks 4–6).
- `fartd` is the memory across the restart: the resident reports `locked` to the core (an op, S7); the flag is published with the `supervisor` topic; a resident that starts and finds `locked: true` **takes the lock before it draws anything else**, and shows no crash notice until unlocked (Z127 is "while unlocked").
- Proposed for S7, not decided (OPEN 17): while locked, cap the wait at 5 s instead of 30 s.
- Not covered by anything yet: `fartd` itself dying. DMS and the lock survive it (own session), but nothing restarts the core (Z13: no systemd units). Follow-up 5.

## 9. Named clients (design; follow-up work)

Today `hello` accepts `cli` and `view`, and only the one process the core spawned may be the view. Target:

| Client | Who may claim it | Lifecycle |
|---|---|---|
| `resident` | A process descending from the supervised DMS (`descends(peer.pid, dms.root.pid)`, own or adopted) | The `dms` child above |
| `panel` (`view` stays as an alias until the QML is renamed) | A process descending from the panel the core spawned (today's check) | `ViewManager`: on demand, reaped (Z142), not reaped while the settings window is open (Z91), halted after 3 quick crashes (Z128) |
| `cli` | Anyone with our uid | — |

- `peer.kind` becomes the name; every `peer is self.view.client` check stays panel-only, so spawn and reap behave as now.
- After an owner restart the resident can say `hello` a moment before its DMS is adopted (the look-out runs every 0.1 s). A refused `resident` hello is retried by the resident, and should also make the supervisor look at once.
- The panel is **not** given the restart policy: it is disposable and starts on demand. It joins the `supervisor` topic for one vocabulary (`absent`→`stopped`, `starting`, `ready`→`up`, reaping→`stopping`, crash limit→`failed`) by a small snapshot adapter, not by replacing `ViewManager`.
- The panel is the core's child, not DMS's, so it survives a DMS outage: its adapters show OFFLINE (Z11) and reconnect to the new `socket` from the topic.

## 10. Recon findings and where each is handled

| Finding (docs/F1_RECON.md) | Handling |
|---|---|
| UI crash takes DMS down; DMS does not respawn it | One child `dms`; the pair is restarted together (§3) |
| One exit event for both crashes | `classify()` (§4) |
| Only TERM/INT are clean; HUP/KILL orphan the UI | TERM first, then sweep by tree and session (§6); same sweep after every crash |
| UI is forked from a side thread | Found by scanning parent pids (`DmsPorts.probe`) |
| UI has its own children (`tee`, polkit helpers) | Whole-tree sweep; unsignalable helpers reported (§6) |
| Stale `dms-<pid>.*` files | Pid files are only a hint: the process must be alive, named `dms` and ours |
| `dms.path` shared, deleted on exit | §7 |
| `dms restart` replaces DMS with a non-child | Adoption (§5) |
| Not measured: `dms restart` | Measured here (§5) by the signal it sends, in private folders |
| Not measured: compositor goes first | Measured: UI exits 255, DMS follows, the core ends with nothing left (check 15) |
| Not measured: `dms run --session`, `dms kill` | Still not measured; not used |

## 11. Verified

- `tests/test_core_supervisor.py`: 24 OK. Table against this document, every row, ignored pairs, reachability, the three rules of §2, stop from every state (including a spawn in flight and an adopted DMS; no timer or watch left), backoff growth and reset, never-give-up and the limit, prompt adoption, a hand-started DMS during a long wait, orphan sweep, hung start, the duplicate report, verdicts.
- `python3 tools/supervisor_check.py` (needs a live Hyprland; runs the real core and a real DMS with an empty UI in the hidden nested compositor): **16/16**, twice, 11 November 2026. Start; UI crash named and back in 0.37 s; DMS killed, orphan UI swept; owner restart adopted in 0.8 s, not doubled (also after the 3 s wait), same UI; adopted DMS killed, ours back; waits 0.25, 1, 3, 4; shutdown leaves no processes; compositor exit ends the core and leaves no processes; the session's own DMS and `dms.path` untouched.
- The first live run found two real faults, both fixed: the session watch could not connect through a symlinked runtime folder (socket path over 107 bytes; the path is now resolved), and exit code 255 was reported as "signal 127".
- A review after the first green run changed five things, all re-checked: code 0 is always "stopped" (a UI a moment behind must not turn an owner restart into a crash with a 0.25 s wait); the new DMS is adopted when it appears, not after a fixed wait; `adopted` became a flag on `up`, so an adopted DMS gets the same ready check; a closed event socket is confirmed before the session is ended; an exception in the launch can no longer strand the state.

## 12. Left open

The owner answered OPEN 15, 16 and 18 on 11 November 2026; the design for those answers is in §13. Still open: OPEN 17 (retry pace while locked, S7) and OPEN 19 (a deliberate stop while locked, before S7).

Follow-up work, in order:
1. **Switch the session over** (needs the owner's go; nothing in Hyprland's config changes), together with §13's two changes: `tools/zaetherion.py` `start_core` sets `FART_SUPERVISE=dms`; `tools/session-start` shrinks to "start the core and wait" (no DMS loop, no `pkill`). Until S3 `FART_RESIDENT_DIR` stays unset, so DMS runs its own UI as now. `stop_core` waits 6 s for the core's socket to go; a worst-case teardown is 9 s (panel 3 s, DMS 6 s), so raise that wait to 12 s. Then a real login/logout test.
2. Named clients and the panel adapter (§9), with `tests/test_core_view.py` staying green.
3. Measure `dms kill` (§13) before relying on "exit code 0 means on purpose".
4. Trim what goes into `session.log`; decide who rotates `dms.log`.
5. Who restarts `fartd` if it dies (§8).

## 13. After the design: the owner's answers (11 November 2026) and what F2 asked for

The code still behaves as §3–§5 describe. The answers below are decided and are built with the switch-over (follow-up 1). The design for each is written here so it is not worked out twice.

**OPEN 15 → comeback notice only.** This is what §4 already provides: the resident reads `last` (`what`, `downAt`, `upAt`) or takes `downFor` from the `up` event. There is no "went down" surface.

**OPEN 16 → a DMS the owner stopped on purpose stays down.**
- "On purpose" is the verdict `stopped` **and** no new DMS within the 3 s wait. An owner restart also exits 0, but its new DMS appears (0.36 s) and is adopted as now.
- New state `held`: wanted, deliberately down, nothing running, no retry timer. Rows:
  - `backoff` + `timer` → `held` when the last verdict was `stopped`, else `starting` as now (decided like `backoff or failed`, by a flag the `exited` event sets);
  - `held` + `start` → `starting` (`launch`); `held` + `stop` → `stopped`.
  - The look-out must then dispatch `start`, not `timer`, when it sees a DMS, in `backoff` and in `held` alike: a DMS that appeared is always adopted, never held.
- `zaetherion start` or `restart` and Super+R (a DMS appears) bring it back. Emit a `held` event for the island and the trial log.
- Look-out while `held`: the slow one that already exists (once a second). It is the only steady look in the design, and it runs only while the shell is deliberately off.
- An adopted DMS has no exit status. Use DMS's own files instead (recon, "Left behind"): after a clean exit `dms-<pid>.pid` is gone; after any crash it is still there. So for an adopted DMS: pid file gone → `stopped`; still there → `dms` (UI alive) or `resident`. That also replaces `unknown`. Check it live when it is built: the recon rows are single samples.
- **`dms kill` is not measured.** If it uses SIGKILL the supervisor sees a crash and restarts. Find out how it picks its targets before running it anywhere near the session's DMS: it may go by process name, not by the runtime folder.
- **Lock (Z35):** while the screen is locked, a stopped DMS is restarted anyway; `held` is entered only while unlocked. The core learns `locked` at S7 (§8). Until then it cannot tell → OPEN 19.

**OPEN 18 → stop the extra DMS.**
- The extra one is whichever is not the supervised root. It is usually the newer one, so `dms.path` is its, and DMS deletes that file when it exits: stopping only the extra leaves the survivor without keybinds (§7).
- So: **stop both, start one.** `_look` (at ready and after 60 s) dispatches `duplicate` instead of only reporting it. Row: `up` + `duplicate` → `crashed` (`fail`, `cancel`, `note_down`, `sweep`), with `sweep` taking the extras as well, each by its own session rule (§6). Then the normal wait and a fresh start: the bar blinks once, one DMS runs, `dms.path` is valid. The verdict is `what: duplicate`; it gets no crash notice.
- The same sequence is right while locked: the new resident takes the lock over (§8).
- Add a unit test (a stray appears, the look, both swept, one fresh start) and a live check (a second `dms run` in the private folder; make the 60 s look shorter for the check).
- Still a limit: a stray started after the 60 s look is seen only at the next start, or (from S3) when its resident says `hello` and is refused (§9).

**What F2 asked of F1** (docs/DMS_ADAPTER.md §7):
1. *The DMS socket path for the panel:* the `supervisor` topic, `children.dms.socket` (with `state`, `pid`, `since`, `owned`). It changes on every restart, including an adopted owner restart. At panel spawn the same value goes into `DMS_SOCKET` (wiring belongs to follow-up 2); while DMS is down it is unset and the panel waits for the topic.
2. *Stopping an orphaned resident:* the sweep after every crash (§6; live check 6).
3. *The source for the comeback notice:* `last`, and `downFor` on the `up` event (§4).
