# Core daemon

Status: **approved and implemented in M2, 6 November 2026.** You reviewed the protocol (section 2) and the Overdrive state machine (section 6) and approved every recommendation in section 12. The code in `core/` and `core/client/` is the source of truth, and this file explains it. When the two disagree, the code wins: fix this file. Section 14 records where the implementation refined the draft.

The core is the long-lived half of FART, as decided in D11. It owns timers, task lists, the notification mirror, Overdrive leases and guards, the view's lifecycle, discovery counters and the session engine. The QML view becomes disposable: the core spawns it on demand and reaps it when it is closed and idle or when memory is under pressure. Alarms still fire while the view is reaped.

## 1. Process

| Item | Value (fart-next) | At cutover (M7) |
| --- | --- | --- |
| Entry | `python3 -I core/fartd.py` (stdlib only) | same |
| Socket | `$XDG_RUNTIME_DIR/fart-next/core.sock`, directory 0700, socket 0600 | `$XDG_RUNTIME_DIR/fart/core.sock` |
| Single instance | `flock` on `$XDG_RUNTIME_DIR/fart-next/core.lock`; a stale socket is unlinked only while holding it | same |
| State | `$FART_STATE_DIR` (`~/.local/state/fart-next`) | `~/.local/state/fart` |
| Cache | `$FART_CACHE_DIR` (`~/.cache/fart-next`) | `~/.cache/fart` |
| Log | `$XDG_RUNTIME_DIR/fart-next/core.log`, truncated to its last 256 KiB at start. It never contains notification bodies, task text or clipboard data. | journal |
| Started by | `fart-next`: when the socket refuses, it takes `launch.lock`, starts the core detached (`start_new_session`), and waits up to 2 s for the socket | systemd `--user` socket activation (needs your approval) |

The core accepts an inherited listening socket using the `LISTEN_FDS`/`LISTEN_PID` protocol (fd 3), so the same entry works under the socket unit. The unit file will be written to `tools/systemd/fart-next-core.{socket,service}` but **not installed or enabled** until you approve it.

Once started, the core stays running. It does not exit when idle, because the notification mirror can only capture notifications while it runs (question Q1).

**Budget (D20):** the core process ≤25 MiB RSS. Its helper subprocesses are reported separately: `busctl` always, and the guard monitors only while Overdrive is requested. Wakeups happen only on events. The core has no periodic timer except the dGPU guard read, which runs only while Overdrive is requested (section 6.3).

### Modules

```
core/fartd.py        entry: lock, socket (own or inherited), asyncio loop, signal handling
core/protocol.py     framing, envelope, peer check, dispatch table, topics and subscriptions
core/clock.py        Clock (boottime, realtime, boot_id) + Scheduler (one timerfd) + realtime-change watch
core/store.py        atomic JSON files (temp + fsync + rename, 0600), versioned migrations
core/timers.py       pomodoro, stopwatch, countdown
core/tasks.py        lists and tasks, todo.json migration
core/notifications.py busctl monitor parser, mirror, 24 h persistence
core/overdrive.py    pure lease×guard state machine (no I/O; table-tested)
core/guards.py       dGPU, fullscreen, battery and session guard monitors
core/view.py         view spawn/handshake/reap, PSI trigger
core/sessions.py     session engine skeleton
core/discovery.py    counters, empty trigger registry
core/host.py         loads the host profile (section 10)
tools/fart_next.py   the CLI: a thin client of the socket (plus the read-only `update` report)
```

## 2. Socket protocol

### 2.1 Framing and security

- Each message is one UTF-8 JSON object followed by `\n`. A message has no embedded newlines, because `json.dumps` escapes them.
- **Peer check:** the core reads `SO_PEERCRED` on accept and drops any peer whose uid differs from its own. The directory and socket modes are a second line of defence.
- **Limits:** an inbound line may be at most 1 MiB, and a longer one closes the connection. If a client's unsent output exceeds 4 MiB, the client is dropped. Because events carry full snapshots (2.3), a client that reconnects and resubscribes loses nothing.
- **Version:** `protocol: 1`. The core rejects a `hello` with a different major version (`error.code = "protocol"`).

### 2.2 Envelope

| Kind | Direction | Shape |
| --- | --- | --- |
| Request | client → core | `{"id": 7, "op": "timer.start", "args": {…}}`. `args` may be omitted. With no `id`, it is a notification: the core sends no reply, and errors only go to the log. |
| Reply | core → client | `{"id": 7, "ok": true, "result": …}` or `{"id": 7, "ok": false, "error": {"code": "bad-args", "message": "…"}}` |
| Event | core → subscribers | `{"event": "timers", "rev": 12, "data": {…}}`. `data` is the topic's **full snapshot**. `rev` increases per topic and resets when the core restarts. |

Error codes: `protocol`, `bad-request` (not JSON, or no `op`), `unknown-op`, `bad-args`, `not-found`, `conflict` (for example, removing the default list), `unavailable` (a subsystem is not running, such as the mirror without `busctl`), `refused` (a policy refusal; the message says which), `internal`.

Replies to one connection arrive in request order. Events can be interleaved between replies. A mutating request's reply is sent **after** the resulting event, so a client that waits for the reply already holds the new state.

### 2.3 Topics

Every topic's snapshot is small. It is replaced whole, which matches the view's convention that collections are replaced, never mutated.

| Topic | Snapshot | Published when |
| --- | --- | --- |
| `core` | `{version, protocol, pid, startedAt, host}` | on subscribe only |
| `timers` | section 3.5 | state change, phase change, alarm, realtime clock change, resume |
| `tasks` | `{lists: [List], tasks: [Task]}` (section 4) | change |
| `notifications` | `{available, items: [Notification], unread}`, using exactly the contract's `Notification` fields | change |
| `overdrive` | `{requested: {mode, until}, effective, reasons, since}` (section 6) | change |
| `session` | `{active: null \| {preset, startedAt, until}}` | change |
| `view` | `{state, pid, open, page, closedSince}` (section 7) | change |
| `view.command` | `{action: "open"\|"page"\|"close"\|"toggle", page, from}` | only to the connected view, never stored |

Time values in snapshots are epoch milliseconds (`at`, `startedAt`, `until`, `time`). Durations are seconds as real numbers, matching the adapter contract's units.

### 2.4 Operations

**Connection**

| Op | Args | Result |
| --- | --- | --- |
| `hello` | `{client: "cli"\|"view", protocol: 1, pid?}` | `{core: <core snapshot>}`. A `view` hello must come from the PID the core spawned (checked by `SO_PEERCRED`); otherwise `refused`. |
| `subscribe` | `{topics: [..]}` | `{snapshots: {topic: data, …}}`. Events for those topics follow. The view is subscribed to `view.command` implicitly. |
| `unsubscribe` | `{topics}` | `{}` |
| `status` | — | `{core: {pid, rssKiB, uptime}, view, timers, tasks: {lists, open, done}, notifications: {available, count, unread}, overdrive, session}` |
| `shutdown` | — | `{}`. The core reaps the view, flushes its state and exits. Used by `fart-next stop`. |

**View lifecycle** (section 7)

| Op | Args | Effect |
| --- | --- | --- |
| `view.open` | `{page?, from?: {x, y, width, height}}` | Spawns the view if needed, then sends `view.command open`. The reply comes once the view is ready (up to 12 s). |
| `view.close` | — | `view.command close`. Does nothing when no view is running; never spawns one. |
| `view.toggle` | `{page?}` | Open if closed or absent, close if open. |
| `view.state` | `{open, page}` | **View only, sent without `id`.** Reports the panel state; the reap timer and panel leases follow it. |

**Timers** (section 3). `kind` ∈ `pomodoro`, `stopwatch`, `countdown`.

| Op | Args | Effect |
| --- | --- | --- |
| `timer.start` | `{kind, seconds?, focus?}` | Countdown: sets `duration = seconds` and runs it. Pomodoro: starts a fresh run; `focus` overrides the focus length for this run only. Stopwatch: resets the stopwatch and runs it. |
| `timer.toggle` | `{kind}` | Pause or resume (the current `toggle*` behaviour) |
| `timer.add` | `{kind: "countdown", seconds}` | Adds to the duration, running or paused (`addCountdownMinutes`) |
| `timer.lap` | — | Appends the stopwatch's current elapsed time |
| `timer.reset` | `{kind}` | The current `reset*` behaviour |
| `timer.ack` | `{kind?}` | Clears the `done` state (the satellite's inverted DONE, M5) |
| `timer.configure` | `{pomodoro?: {focus, break, longBreak, cycles}, sound?: bool}` | Timer settings (moved from `settings.json`, see 3.6). A change applies from the next phase on, never to the running one. |

**Tasks** (section 4)

| Op | Args | Result |
| --- | --- | --- |
| `task.add` | `{text, list?, due?, index?}` | `{task}`. Appends to `list` (the default list if omitted) |
| `task.update` | `{id, text?, done?, due?, list?}` | `{task}`. `due: null` clears the due date |
| `task.move` | `{id, index}` | `{task}`. Reorders within its list |
| `task.remove` | `{id}` | `{task, index}`, which the view keeps for undo |
| `task.restore` | `{task, index}` | `{task}`. Reinserts a removed task with its original id |
| `list.add` | `{name}` | `{list}` |
| `list.rename` | `{id, name}` | `{list}` |
| `list.remove` | `{id}` | `{}`. Its tasks move to the default list. The default list cannot be removed (`conflict`). |

**Notifications** (section 5)

| Op | Args | Effect |
| --- | --- | --- |
| `notif.markAllRead` | — | contract `markAllRead()` |
| `notif.dismiss` | `{id}` | contract `dismiss(id)`: `CloseNotification` on the host's server |
| `notif.clear` | — | Wipes the mirror and its file without touching the host. For the Inbox "Clear" button (plan); it is not a contract method. |
| `notif.privateApps` | `{apps?: [string]}` | Sets or reads the private-apps list (Q3) |

**Overdrive, sessions, discovery**

| Op | Args | Effect |
| --- | --- | --- |
| `overdrive.request` | `{mode: "timed", seconds}` \| `{mode: "panel"}` \| `{mode: "sticky"}` | Section 6 |
| `overdrive.release` | — | Section 6 |
| `session.start` | `{preset, seconds}` | Skeleton (section 9) |
| `session.end` | — | Skeleton |
| `discovery.bump` | `{counter, by?}` | Increments a named counter. The registry is empty in M2. |
| `sky.now` | `{}` | The astronomical clock's sky (M10, `core/skywatch.py`): every body's place, the moon's face, today's sunrise and sunset, the place (`source` host, timezone or none) and the next 36 h of events. Asked by Home once a minute while its clock shows; nothing is pushed. |

**M5 additions** ([M5-COMMAND.md](M5-COMMAND.md) §2): `cmd.run`, `cmd.complete`, `cmd.history` (the verb registry), `host.done` (answers the `view.host` event: host calls through the view's adapter), `sfx.emit`, `sfx.configure` and the `sfx` topic with its `sfx.cue` events.

## 3. Timers

### 3.1 Clocks

| Clock | Use |
| --- | --- |
| `CLOCK_BOOTTIME` | The truth for elapsed time within one boot. It keeps counting during suspend, so a 25-minute countdown ends 25 real minutes after it started even if the lid was closed in between. NTP and manual clock changes do not move it. |
| `CLOCK_REALTIME` | Display stamps, and the fallback across a reboot, when boottime restarts from zero. |
| `boot_id` (`/proc/sys/kernel/random/boot_id`) | Says whether a stored boottime anchor is still comparable. |

asyncio's own timers use `CLOCK_MONOTONIC`, which **stops during suspend**. A `call_later(1500)` scheduled before a 1-hour suspend would fire 1 hour late. The core therefore never schedules user-visible deadlines on the asyncio clock.

### 3.2 The run model

Every timer, and every deadline in the core (lease timeout, session end, notification expiry), uses one structure:

```
Run    = { running: bool, elapsed: seconds before anchor, anchor: Anchor | null }
Anchor = { boot: CLOCK_BOOTTIME seconds, real: epoch seconds, bootId: string }

span(anchor, now) = now.boot − anchor.boot             if anchor.bootId == now.bootId
                  = max(0, now.real − anchor.real)      otherwise (rebooted)
elapsed(run, now) = run.elapsed + (run.running ? max(0, span(run.anchor, now)) : 0)
```

- **Start or resume:** `anchor = now`. **Pause:** `elapsed = elapsed(run, now)`, `anchor = null`, `running = false`.
- **Rebase:** at load, a running run whose `bootId` differs from the current boot is folded once (`elapsed = elapsed(run, now)`, `anchor = now`). After that, only boottime arithmetic applies.
- **Realtime jumps** within one boot have no effect on `elapsed`. The view extrapolates from a realtime stamp (3.5), so the core republishes `timers` when the realtime clock is set.

### 3.3 The scheduler

There is one `timerfd` on `CLOCK_BOOTTIME` with `TFD_TIMER_ABSTIME`, armed to the earliest pending deadline and registered with `loop.add_reader`. A deadline in boottime is `anchor.boot + (target − run.elapsed)`.

- When the system resumes after a deadline passed during suspend, the timerfd is already expired, so the core wakes immediately. It does not need to watch logind for this. The `_ALARM` variant would wake the machine from suspend; it needs `CAP_WAKE_ALARM` and is not used.
- A second timerfd on `CLOCK_REALTIME`, armed far in the future with `TFD_TIMER_CANCEL_ON_SET`, fails with `ECANCELED` when the wall clock is set. The core then republishes `timers` with a fresh stamp and re-arms it.
- When nothing is running, the boottime timerfd is disarmed and the core has no wakeups at all.
- `Clock` is injected, so tests drive a fake clock (`boot`, `real`, `bootId`, and a fake scheduler that fires on `advance()`).

Both timerfd calls were checked on this machine (Python 3.14.9, kernel 7.2).

### 3.4 Behaviour per kind

Semantics are unchanged from `TimerService` except where marked **new**.

- **Countdown:** `remaining = duration − elapsed`. At 0 it stops, sets `done = {at, late}`, notifies ("Countdown finished"), and plays `timer.done` if sound is on. `duration` is kept, where the old code zeroed it, so "restart" can reuse it (**new**; while `done`, the Timers room shows 0 left). `done` stays until `timer.ack` (which returns the countdown to a full, ready one of the same length), `timer.start` or `timer.reset`.
- **Pomodoro:** phases are focus → break → … → long break when `cycle + 1 == cycles`, and the cycle increments when a focus phase begins, exactly as now. A run snapshots its phase lengths at `timer.start`. A configuration change applies from the next phase on (**new**: the old binding changed the running phase's length mid-phase). At a phase boundary, the next phase is anchored at the **true boundary** (`anchor.boot = boundary`), not at the moment the core noticed it, so wake latency never accumulates.
- **Stopwatch:** elapsed time keeps counting across suspend, because it measures real time. `laps` are cumulative elapsed seconds, as now.

**After suspend (Q2).** `late` is how long after the deadline the core woke.
- If `late ≤ 60 s`, the transition behaves normally.
- If `late > 60 s`, the deadline passed while the machine was asleep:
  - A countdown completes silently and the notification says "finished 14 min ago".
  - A pomodoro moves to the next phase **paused** at its beginning, with one notification ("Focus ended 14 min ago, paused"). It never fast-forwards through several phases or plays a chain of sounds.

### 3.5 Snapshot

```json
{
  "at": 1793900000123,
  "sound": false,
  "pomodoro": {"running": true, "phase": "focus", "cycle": 0, "elapsed": 312.4, "duration": 1500,
               "lengths": {"focus": 1500, "break": 300, "longBreak": 900, "cycles": 4}},
  "stopwatch": {"running": false, "elapsed": 0, "laps": []},
  "countdown": {"running": false, "elapsed": 0, "duration": 300, "done": null}
}
```

`at` is the realtime stamp at which the `elapsed` values were computed. While a timer runs, the view shows `elapsed + (Date.now() − at) / 1000`, which is the same rule as `media.position` and `positionStamp`. The view ticks only while something visible displays a running timer. The core never ticks for display.

### 3.6 Persistence and migration

`timers.json` becomes core-owned at version 2:

```json
{"version": 2,
 "config": {"pomodoro": {"focus": 1500, "break": 300, "longBreak": 900, "cycles": 4}, "sound": false},
 "pomodoro": {"phase": "focus", "cycle": 0, "lengths": {…}, "run": Run},
 "stopwatch": {"run": Run, "laps": []},
 "countdown": {"duration": 300, "run": Run, "done": null}}
```

The core writes on change only, atomically, 0600. It never writes on a tick, because nothing ticks.

**Migration from version 1** (the current file, which has no `version`). It runs once, when the core first loads a file without `version`. The original is copied to `timers.v1.json` first.
- `config` comes from `settings.json` → `time.pomodoro.{focus, breakTime, longBreak, cyclesBeforeLongBreak}` and `sounds.pomodoro`, read once. After that, the core owns timer settings, and the view stops reading those `Config` keys (Q10).
- **Pomodoro:** `isBreak`/`cycle` become `phase`/`cycle`. If `running`, then `elapsed = now − start` (epoch seconds), with a realtime-only anchor.
- **Stopwatch:** `start` and `elapsed` are in 10 ms units. Running: `elapsed = (now×100 − start)/100`. Paused: `elapsed/100`. `laps` are divided by 100.
- **Countdown:** if `running`, then `elapsed = now − start`.

Today's file has nothing running: countdown 300 s paused, pomodoro idle, stopwatch idle.

### 3.7 Tests (`tests/test_core_timers.py`)

All of these use the fake clock:
- Countdown 1500 s, then a simulated suspend of 3600 s (boot +3600, monotonic +0, real +3600): wake, `done`, `late = 2100`, silent, notified once.
- Countdown 1500 s, suspend 600 s, resume: remaining is exactly 900 s, and the scheduler is armed at the boottime deadline. That is 0 drift.
- Realtime jumps ±1 h within one boot: `elapsed` is unchanged, and `timers` is republished with a new `at`.
- Reboot: a different `bootId`, with real +300 s → elapsed includes 300 s, and it is rebased once.
- Pomodoro boundary noticed 0.8 s late: the next phase's anchor is at the boundary, so 100 cycles accumulate 0 drift.
- Pomodoro with `late > 60 s`: paused at the start of the next phase, one notification, no sound.
- Version 1 migration with each kind running or paused, using the stored formats above. An existing version 2 file is never touched.
- No timer running → the scheduler is disarmed.

The M2 acceptance test "alarms fire with the view reaped" runs the real core with a fixture host profile and no view: a 1 s countdown must record one notify and one sfx call.

## 4. Tasks

### 4.1 Model

```json
{"version": 1,
 "lists": [{"id": "default", "name": "Tasks"}],
 "tasks": [{"id": "t3f9a01c2", "list": "default", "text": "…", "done": false,
            "due": null, "created": 1793900000000, "doneAt": null}]}
```

- **File:** `$FART_STATE_DIR/tasks.json`, 0600, core-owned.
- **Order:** the order of `tasks` within each list is the display order.
- **`id`:** `"t"` + 8 random hex digits. `restore` reuses the original id.
- **`due`:** a local date `"YYYY-MM-DD"`, or a local date and time `"YYYY-MM-DDTHH:MM"`, or `null`. The view computes "overdue" from the local date, so the core needs no midnight wakeup. The `!due` grammar (`!fri`, `!tomorrow`) belongs to the M5 command line, which sends a resolved date.
- **Lists:** a list's `id` is `"l"` + hex, except `default`, which always exists.
- **Text:** at most 1000 characters. Leading and trailing whitespace is trimmed, and empty text is `bad-args`.

### 4.2 Migration of the 12 tasks

On the first start where `tasks.json` is absent and `todo.json` exists:
1. Parse `todo.json` (an array of `{content, done}`). If it is invalid JSON, the core refuses to migrate, logs the reason and serves an empty default list. It never overwrites anything.
2. Each item becomes a task in `default`, in the same order, with `text = content`, `done` unchanged, `created = doneAt = null` (unknown), and a fresh id.
3. Write `tasks.json` atomically (`os.link` publish, like the launcher's seeding, so a concurrent writer can never be overwritten).
4. Leave `todo.json` untouched as the record of version 1. Nothing reads or writes it afterwards.

Today, `~/.local/state/fart-next/todo.json` has 12 items. The archive never reads fart-next's state, so the migration cannot affect `fart`.

**Mapping the Tasks room.** The room keeps its interaction and changes only its data source:
- `Todo.addTask(text)` → `task.add`
- `markDone`/`markUnfinished(index)` → `task.update {id, done}`
- `deleteItem` → `task.remove`, keeping `{task, index}`; undo calls `task.restore`

Rows are addressed by id instead of index, which removes the old index race after a concurrent change.

**Tests** (`tests/test_core_tasks.py`):
- The 12-item fixture migrates in order with the same done flags.
- Invalid `todo.json` is left alone.
- An existing `tasks.json` wins.
- `list.remove` moves its tasks to the default list.
- Removing the default list gives `conflict`.
- `remove` followed by `restore` returns the same id and index.

## 5. Notification mirror

### 5.1 Source

It replaces `tools/notification_feed.py`, which needs dbus-python and GLib and costs 15 MiB PSS, with one `busctl --user monitor --json=short` subprocess. Its matches are the same four rules the feed uses:
- `Notify` method calls
- method returns from the server
- `NotificationClosed`
- `NameOwnerChanged` for `org.freedesktop.Notifications`

This was checked on a private test bus. Each line carries `type`, `cookie`, `reply_cookie`, `sender` (a unique name), `destination` and a typed `payload`. A `Notify` return is matched to its call by `(destination, reply_cookie) == (call sender, call cookie)`, which is the same pairing the feed does today. The current owner's unique name comes from `NameOwnerChanged` plus one initial `busctl --user call org.freedesktop.DBus … GetNameOwner`.

**Cost to watch:** busctl prints `image-data` hints as JSON integer arrays, so one avatar notification can be a line of several hundred KiB. The reader uses a 4 MiB line limit, discards longer lines with a log entry (no content), and drops image hints before keeping anything. The M2 measurement includes this. If busctl's cost turns out unacceptable, the fallback is to restore `notification_feed.py` (deleted in M2, still in Git history) as the core's child. Measured live: busctl 5.8 MiB RSS / 1.0 MiB PSS, against 15.3 MiB PSS for the old feed.

### 5.2 The contract does not change

`NotificationsDomain` keeps exactly its properties and methods: `items`, `unread`, `dnd`, `setDnd`, `markAllRead`, `dismiss`, `openHost`. `SerpantinumNotifications` keeps `dnd`, `setDnd` and `openHost`, which are host-side as now. It takes `available`, `items` and `unread` from the core's `notifications` topic, and it forwards `markAllRead` and `dismiss` to it. The rooms and the fixture adapter are unaffected.

Behaviour preserved from the feed:
- Transient notifications are skipped.
- Field caps are 256/512/2000 characters, and an empty app name becomes "System".
- The pending-call table is bounded at 128.
- The list is capped at 100, newest last.
- `NotificationClosed` removes the item.
- A change of server owner clears the mirror, because the host restarted and its ids are void.

Changes:
- **Ids:** they stay the host's notification id as a string, as now. The core keeps the owner per item for `dismiss`.
- **`time`:** set by the core at receipt (epoch ms) instead of by the view. **`read`** is kept by the core, so it survives a view reap.
- **24 h persistence** (plan, Inbox): `notifications.json`, 0600, with `{owner, items}`. Items older than 24 h are dropped by one scheduled deadline at the oldest item's expiry, not by polling. At core start, the file is kept only if the server's current owner equals the stored `owner`; otherwise it is wiped as a host restart. After a core restart, items the host closed while the core was down stay until dismissed or expired, because the spec has no way to list open notifications.
- **Private apps (Q3):** matched case-insensitively on `appName`. Recommended behaviour: mirrored in memory but never written to disk.
- **`dismiss`:** runs `busctl --user call <owner> /org/freedesktop/Notifications org.freedesktop.Notifications CloseNotification u <id>`. The item leaves on the resulting `NotificationClosed`, as now. If the owner is gone, the item is removed directly.
- **`available`:** true while `busctl` runs and the initial owner lookup has finished. If busctl exits, `available` turns false and the mirror empties, as now. The core restarts busctl with a backoff of 1, 2, 4 … up to 60 s.

Logging: counts and error kinds only, never app names, summaries or bodies.

**Tests** (`tests/test_core_notifications.py`) feed recorded busctl JSON lines, written by hand with fake contents, into the parser:
- A call and return pair produce an item.
- An unpaired return is ignored.
- A transient notification is skipped.
- Close removes the item.
- An owner change clears the mirror.
- The 100 cap holds.
- 24 h expiry is scheduled at the oldest item.
- A private app is never written to disk.
- An oversized line is dropped.

## 6. Overdrive: lease × guard state machine

Overdrive has no visible effect until M8, but the machine, its persistence and its guards are built and tested now, as D4 states.

### 6.1 State

- **Requested** `R`:
  - `off`
  - `timed(until)`, from `overdrive 20m`
  - `panel`, from hold-to-ignite (M8); it lasts until the panel closes
  - `sticky`
- **Guards** `G ⊆ {dgpu, fullscreen, battery, session}`. Guards are observed **only while `R ≠ off`**.
- **Effective** `E = off` if `R = off`; `suspended(G)` if `G ≠ ∅`; otherwise `active`. The view loads strata only when `E = active` (M8).

`overdrive.py` is a pure function `step(state, event, now) → (state, effects)`. The effects are `start_guards`, `stop_guards`, `arm_timeout(until)`, `disarm_timeout`, `publish` and `persist`. Only `guards.py` and the scheduler do I/O.

### 6.2 Transition table

`*` means any value of `R` other than `off`. Rows are checked in order, and the first match wins.

| # | R before | Event | R after | G | Effects |
| --- | --- | --- | --- | --- | --- |
| 1 | `off` | `request timed(d)` | `timed(now+d)` | probe all guards | start guards, arm timeout |
| 2 | `off` | `request panel`, view open | `panel` | probe | start guards |
| 3 | `off` | `request panel`, view not open | `off` | — | reply `refused` ("panel is not open") |
| 4 | `off` | `request sticky` | `sticky` | probe | start guards |
| 5 | `timed` | `request timed(d)` | `timed(now+d)` (replaces: can extend or shorten) | unchanged | re-arm timeout |
| 6 | `timed`, `panel` | `request sticky` | `sticky` | unchanged | disarm timeout |
| 7 | `panel`, `sticky` | `request timed(d)` | `timed(now+d)` | unchanged | arm timeout |
| 8 | `timed`, `sticky` | `request panel` | unchanged (already at least as long) | unchanged | — |
| 9 | `panel` / `sticky` | the same request again | unchanged | unchanged | — |
| 10 | `*` | `release` | `off` | ∅ | stop guards, disarm timeout |
| 11 | `timed` | `timeout` (counts while suspended, too) | `off` | ∅ | stop guards |
| 12 | `panel` | `panel closed` or `view reaped/exited` | `off` | ∅ | stop guards |
| 13 | `timed`, `sticky` | `panel closed` | unchanged | unchanged | — |
| 14 | `*` | `guard g on` | unchanged | G ∪ {g} | if G was ∅: E `active` → `suspended` |
| 15 | `*` | `guard g off` (debounced 2 s) | unchanged | G ∖ {g} | if G becomes ∅: E `suspended` → `active` |
| 16 | `off` | `guard …`, `timeout`, `panel closed` | `off` | ∅ | ignored (stale; the monitors are already stopping) |
| 17 | `off` | `release` | `off` | ∅ | — (idempotent) |
| 18 | — | core start | persisted `timed` (if `until` is still ahead) or `sticky`; never `panel` | probe | start guards, arm timeout |

Rules worth stating:
- **Sticky never ends by itself.** Guards suspend and resume it (D4).
- **A request is accepted while a guard is on** (rows 1, 2, 4). The reply carries `effective: "suspended"` and its `reasons`, so the CLI prints "Overdrive requested, suspended: fullscreen". The same applies to a running session (Q5).
- **Asymmetric debounce:** guard-on suspends at once, so effects stop before a game frame or a battery drain. Guard-off waits 2 s, so a fullscreen toggle does not flap the strata.
- **Persistence:** `overdrive.json` holds `R`, with `until` as a Run-style anchor so a timed lease survives suspend correctly (section 3.2). `G` is never persisted; it is probed again.

The test (`tests/test_core_overdrive.py`) is generated from this table. For every `R` × `G ∈ {∅, {g}}` × event, it asserts the next state and effects. It also asserts that no event in the state `off` produces `start_guards`, and that every `start_guards` is eventually paired with `stop_guards`. There are separate scripted sequences:
- ignite → fullscreen → timeout during suspension → `off`
- sticky → battery on → battery off → `active` after 2 s
- core restart with `timed` expired → `off`

### 6.3 Guard sources (only while `R ≠ off`)

| Guard | Source | On when | Cost |
| --- | --- | --- | --- |
| `dgpu` | `power/runtime_status` of the display-class PCI device with `boot_vga = 0` (here `0000:01:00.0`, NVIDIA, now `suspended`). The path can be overridden in `core.json`. Never `nvidia-smi`. | `active` or `resuming` | One sysfs read every 5 s. The attribute cannot be polled, and reading it does not wake the device. This is the core's only periodic work. |
| `fullscreen` | Hyprland `.socket2.sock` events (`fullscreen`, `workspace`, `activewindow`, `focusedmon`, `closewindow`, `movewindow`). On each one, debounced 100 ms, the core queries `j/monitors` on `.socket.sock` and checks whether any monitor's active workspace `hasfullscreen`. | a visible workspace has a fullscreen window | event-only |
| `battery` | UPower `OnBattery`: one `busctl --system get-property` at start, then a `gdbus monitor --system --dest org.freedesktop.UPower --object-path /org/freedesktop/UPower` subprocess. It uses AddMatch, not eavesdropping, so it works unprivileged. The system bus cannot be watched by the always-on user-bus `busctl`, which corrects the plan's note. | on battery (Q4) | event-only, one subprocess |
| `session` | the session engine | a session with forced Silent is running | in-process |

A guard whose source is unavailable (no Hyprland socket, no UPower, no dGPU) reports off and is listed in `status` as `unavailable`. It never blocks Overdrive.

## 7. View lifecycle

### 7.1 States

`absent → starting → ready → absent`. While `ready`, the view is `open` or `closed`, as reported by `view.state`.

| Event | Action |
| --- | --- |
| `view.open`/`toggle` while `absent` | Spawn `qs -n --no-color -p <repo>/shell.qml` as the core's child: new session, `stdin`/`stdout`/`stderr` to `/dev/null` (or to `$FART_VIEW_STDOUT` in tests; `FART_VIEW_ENTRY` replaces the entry for the smoke harness), and the environment `FART_STATE_DIR`, `FART_CACHE_DIR`, `FART_CORE_SOCKET`. Queue the command. State `starting`. |
| View `hello` from the spawned PID or a descendant | State `ready`; subscribe; flush the queued command. |
| No `hello` within 12 s | SIGTERM, then SIGKILL after 3 s; the queued request fails with `unavailable` and the log path. |
| `view.state {open: false}` | `closedSince = now`; arm the reap deadline at now + 60 min (`REAP_AFTER`; 10 min until 7 Nov 2026) (boottime, so suspend counts as closed time). |
| `view.state {open: true}` | Disarm reap. |
| Reap deadline, PSI trigger (7.2), or `shutdown` | Only when closed for ≥ 5 s, so the close animation and the view's 250 ms preference writes have finished. SIGTERM, then SIGKILL after 3 s. State `absent`. |
| Child exits unexpectedly | State `absent`. A `panel` lease ends (row 12). No automatic respawn: the next `open` spawns again. Three exits within 5 s of spawn in a row make `view.open` reply `unavailable` until `fart-next restart`. |

- **Kept from today:** spawning stays on demand, cold start was 0.42 s at M0, and the view keeps its own Quickshell log (`qs log -p …/shell.qml`).
- **Not reaped:** an open view, ever. In M2 the reaper also skips the view while `R ≠ off`, because M8 strata live in the view. A desktop-tier stratum (M16) will need to revisit this.
- **Legacy instance:** when the core starts, it checks `qs list -a -j` in a thread for a `shell.qml` instance not spawned by the core (one started by the M0/M1 launcher). If it finds one, it stops it with `qs -p … kill`. The first spawn waits for the check only if it is still running, so there is never a duplicate and a cold open does not pay the 60–130 ms of `qs list`. A failed check is retried on the next spawn. Only fart-next's own path is ever touched, never the archive's.
- **Hot reload:** the core starts the view straight from the working tree, as now. Edits hot-reload the running view, and its socket reconnects.

### 7.2 PSI

The core opens `/proc/pressure/memory` read-write and writes the trigger `some 150000 2000000` (150 ms of stall within a 2 s window; unprivileged triggers need a window that is a multiple of 2 s). The fd is registered with an `epoll` object for `EPOLLPRI`, and that epoll fd is added to the loop with `add_reader`, so there is no polling.
- A firing while the view is `ready` and closed reaps it at once, which recovers about 200 MiB PSS.
- A firing while the view is open does nothing.

The trigger exists only while a view is running.

Writing the trigger was checked on this machine. The user cgroup's `memory.pressure` is not writable by the user, so the trigger is system-wide.

**Tests** (`tests/test_core_view.py`): a fake spawner (a Python child that connects and says `hello`) plus the fake clock:
- open → ready → close → reaped after 60 min
- reopened at 9 min → not reaped
- PSI while closed for 6 s → reaped
- PSI while open → not reaped
- PSI 1 s after close → deferred to 5 s
- no hello → killed and `unavailable`
- crash loop → `unavailable`
- a panel lease ends on reap

## 8. CLI verbs

`fart-next <verb>` opens one connection: `hello`, then one or two requests, then it prints the result and exits. Since M5, `tim`, `overdrive`, `session` and every other non-builtin word are parsed by the core's registry through `cmd.run` ([M5-COMMAND.md](M5-COMMAND.md) §3). The behaviour in the table below is unchanged.
- **Exit codes:** 0 on success, 1 when the core returns an error, 2 for a usage error, 3 when the core is unreachable after an attempted start.
- **Output:** human-readable, one line where possible; `--json` prints the raw result.
- **Auto-start:** verbs other than `update`, `status` and `close` start the core if needed.

| Verb | Request | Notes |
| --- | --- | --- |
| `open [--from x,y,w,h]` | `view.open {page: "home", from}` | `from` is accepted and stored. The unfold uses it in M5. |
| `page <room>` | `view.open {page}` | Rooms and aliases as now (`inbox`, `clips`) |
| `close` | `view.close` | Never spawns the core or the view |
| `toggle` | `view.toggle` | Kept for the clock hook's sake |
| `status [--json]` | `status` | Without a core: `core: stopped`, and the source path |
| `tim` | `view.open {page: "timers"}` | A bare verb opens its room |
| `tim <dur>` | `timer.start {kind: countdown, seconds}` | `25` = minutes; `90s`, `25m`, `1h30` |
| `tim focus [<min>]` | `timer.start {kind: pomodoro, focus}` | The override lasts for this run only |
| `tim sw` | `timer.toggle {kind: stopwatch}` | |
| `tim lap` | `timer.lap` | |
| `tim pause` | `timer.toggle` on each running timer | |
| `tim stop` | `timer.ack` plus `timer.reset` of each running timer | Q6 |
| `overdrive` | `status` → prints the `overdrive` line | |
| `overdrive <dur>` / `sticky` / `off` | `overdrive.request` / `overdrive.release` | Prints the effective state and reasons |
| `session` | prints the session line | |
| `session <preset> <dur>` | `session.start` | e.g. `session pyq 2h` |
| `session end` | `session.end` | |
| `start` / `stop` / `restart` | `hello` / `shutdown` / both | `stop` reaps the view and stops the core |
| `update` | none: the read-only Git report, as now | |

`launch` (an alias of `open`) and `island` (the compact exterior that D5 removes) are dropped (Q9).

## 9. How the view talks to the core

```
shell.qml:  CoreClient { id: core }   SerpantinumAdapter { id: host; core: core }   Overlay { host; core }
                │ Quickshell.Io Socket + SplitParser on $FART_CORE_SOCKET
                ▼
            core.sock
```

- **`core/client/CoreClient.qml`** (`import qs.core.client`) is the QML half of the protocol. It holds a `Socket` with `path: Quickshell.env("FART_CORE_SOCKET")` and a `SplitParser`. It sends `hello {client: "view", pid}` and `subscribe`, and keeps a map from request id to callback. It exposes one read-only property per topic (`timers`, `tasks`, `notifications`, `overdrive`, `session`), plus `connected` and the signal `command(action, page, from)`.
  - **Reconnect:** while disconnected, it retries with a backoff from 0.25 s up to 5 s. While connected, it runs no timer.
  - **Offline:** while disconnected, the topic snapshots keep their last value and `connected` is false. The rooms disable controls that act on the core.
- **`core/client/CoreTimers.qml`** and **`CoreTasks.qml`** are thin facades with today's method names where they map cleanly. Examples: `timers.toggle("pomodoro")`, `timers.formatSeconds` (moved to `view/ui/Format.js`), `tasks.add(text)`, `tasks.setDone(id, on)`, `tasks.remove(id)`. That keeps the room diffs small.
- **Rooms:** rooms receive the client as a third required property, `required property CoreClient core`, passed by `Shell` like `host` and `shell` (Q12). Today only Timers and Tasks use it. Home's today strip will use it in M6.
- **Overlay:** `Overlay` reacts to `core.command` instead of `IpcHandler` `open`/`page`/`close`/`toggle`. It reports `view.state` on every change of `opened` or `currentPage`. `IpcHandler` keeps only `status`, for diagnostics (Q8). `ShellContext.toggleActiveTimer()` calls `core.timers.toggle(engagedTimerKind)`.
- **Removed with M2:**
  - `view/compat/` (`Todo`, `TimerService`)
  - `view/shell/Persistent.qml` (`timers.json` is now core-owned)
  - `Config.options.time.pomodoro` and `sounds.pomodoro` (migrated by the core before it first spawns a view; the view's `JsonAdapter` drops them from `settings.json` on its next write)
  - `tools/notification_feed.py`
  - `TimerService`'s `notify-send` entry in the process allowlist
- **Lint changes in `test_contract.py`:**
  - The view and adapters may import `qs.core.client`, and nothing else from `core/`.
  - `core/client/*.qml` may import only Quickshell, Quickshell.Io and QtQuick.
  - No view file may start a process except `FartCommands`.
- **Fixture and smoke:** `tools/smoke.py` starts a real core on a temporary runtime, state and cache directory with the fixture host profile (section 10), then runs the rooms against it. The task and stopwatch round trips go through the core. `shell-fixture.qml` without a core still loads, with `connected: false`.

The adapter contract itself does not change. `ADAPTER_CONTRACT.md` §1 gains one line: `SerpantinumNotifications` reads the mirror from the core.

## 10. Host knowledge in the core

The core must play sounds and check the host's sfx mute and DND with no view running (D19, and alarms with the view reaped). That host knowledge goes into a small Python profile **beside the QML adapter**, so `adapters/serpantinum/` stays the only place that knows Serpantinum:

```
adapters/serpantinum/core.py   class HostProfile:
    sfx() -> (muted, volume)    # general.muteSfx / general.sfxVolume, read from settings.json when needed
    dnd() -> bool               # notifications.dnd, read when needed
    play(cue, gain)             # pw-play, media.role=event, the same cue map as SerpantinumSfx
    notify(summary, body)       # notify-send -a FART
adapters/fixture/core.py        records calls; used by tests and smoke
```

- **Selection:** `FART_HOST` selects the profile. `fartd` refuses to start without it (and without `FART_STATE_DIR`); `fart-next` sets `serpantinum` unless the variable is already set.
- **Reads on demand:** the profile reads host settings only at the moment it needs them, such as an alarm. It needs no watcher and causes no idle wakeups.
- **Sound gating (D19):** a sound plays only if timer sound is on, the host is not muted, DND is off and no session is quieting sounds. DND suppresses sound, not the notification.
- **Lint:** the lint test extends to `core/`. It must not name host paths or binaries, which must stay in the profile.

## 11. Sessions and discovery (skeletons)

- **Sessions:**
  - `session.start {preset, seconds}` records `{preset, startedAt, until}` (a Run anchor), turns on the `session` guard and schedules the end.
  - `session.end`, or reaching `until`, turns the guard off, appends `{preset, start, end, seconds}` to `sessions.jsonl` (0600) and notifies once.
  - **M11 (10 November):** presets `focus` 50 min, `deep` 90 min, `study` 2 h, `read` 45 min (`core/sessions.py` PRESETS): `session focus` takes the preset's length; any other short name still needs one (`session pyq 2h`). `session.start {preset, seconds?}`, `session.end`, `session.dismiss`.
  - **The debrief** (`snapshot().last`): preset, planned and done seconds, completed or ended early, how many tasks were finished in the span (`Tasks.done_between`, a count only), and `apps`: seconds per app class from the host's focus tracker over the span, at most four, or `null`. Serpantinum's is Digital Wellbeing's `focustime.db`, opened read-only (`mode=ro`, 0.2 s timeout), `focus_minutes` only: window titles live in the same file and are never read. Missing, locked or broken: `null`. The apps stay in memory; `session.json` keeps the debrief without them. A new start or `session.dismiss` puts it away.
  - **The streak** (`snapshot().streak`): read back from `sessions.jsonl` (the last 2000 lines, bad lines skipped). A day counts with 10 minutes of session time in it; `current` runs back from today (or yesterday, while today is still empty), `best` is the longest run, `minutes` the last 14 days.
  - **The view:** Timers' fourth tab, Session (`view/rooms/Timers.qml`, `SessionDebrief.qml`): the presets as buttons, the running session on the field and its clock, End session, and the debrief card with the streak strip. Tested by `tests/test_core_sessions.py` (with `tools/cuetest/SessionTest.qml`).
  - **Do Not Disturb and music** (the user said yes, 10 November): a session turns the host's DND on if it was off (Serpantinum: `notifications.dnd` in its settings.json, written as Serpantinum writes it, temporary file renamed over, every other key kept) and puts it back off at the end, before the end's alert so it is heard; DND already on is left alone. Remembered in `session.json`, so a restart mid-session still puts it back. Every preset but `read` starts the active player if it is paused, through the view's adapter, and only while the view is alive (a session never spawns it). Tests run on the fixture host only.
- **Discovery:** `discovery.json` holds `{counters: {name: n}, found: {id: ms}, unseen: [id]}`. `discovery.bump` increments a counter and saves it, debounced 5 s.
  - **M15 (10 November):** the registry is the data files in `assets/fragments/<id>.json`: `{when, whisper, text}`. `when` is declarative and every condition in it must hold at once: `counter` (+ `atLeast`), `hours` [from, to) local, `streak` (session days), `uptime` (hours, suspend included), `listening` (a track started in the last 15 min), `visits` ({room: n}). A file that doesn't parse or names an unknown condition is left out with a warning. Checked on a bump, the panel opening (which bumps `view.opens`), a session change and a new track; at most one find per check. Twelve fragments ship: the moon full and new, a conjunction, thirty sunrises, 3 a.m., listening past midnight, streaks of three and seven, three days awake, the hundredth start, the twenty-fifth visit to the Codex, the thousandth open.
  - **The reveal:** the `discovery` topic carries the found fragments and `whisper`, the first one not yet whispered. The view (`view/shell/Whisper.qml`) shows it as one faint neutral line under the room for about a second, once the panel has settled, then says `discovery.seen {id}`; a find made while the panel was closed waits for the next open. The fragment's text is in the archive under FOUND IN THE MARGINS. Uncanny text stays in the archive; whispers stay plain. Disk keeps counters and ids with times, never what was playing.
  - **Tests:** `tests/test_core_discovery.py` (with `tools/cuetest/DiscoveryTest.qml`).
- **Sky events (M10):** `core/skywatch.py` schedules the next sky event on the boottime scheduler, one wake-up per event (a few a day), starting 3 s after start-up so the first search (~15 ms) misses a cold open. Each one that fires bumps `sky.<kind>`: `sky.moon.new`, `.first`, `.full`, `.last`, `sky.sun.rise`, `sky.sun.set`, and `sky.conjunction` plus `sky.conjunction.<a>-<b>` for two of the moon and the five naked-eye planets within 3°. An event more than 10 minutes late at wake-up (slept through) is skipped, not counted. A wall-clock jump recomputes. The place is the host profile's `location()` (Serpantinum: `general.location`), else the system time zone's reference city (zone1970.tab), else 0° 0°.

## 12. Review decisions (6 November 2026)

Every recommendation below was approved.

| # | Question | Decision |
| --- | --- | --- |
| Q1 | Core lifetime | Stay running once started, because the Inbox only captures while the core runs. Until you approve a unit, the core starts on the first `fart-next` use. At approval, decide whether the socket unit is also pulled in at login (`WantedBy=default.target`), so the Inbox captures from login. |
| Q2 | Deadlines passed during suspend | If late by more than 60 s: no sound, a pomodoro pauses at the start of the next phase, and one notification says how long ago it ended. |
| Q3 | Private apps | Shown in the Inbox while the core runs, never written to disk. The alternative is to drop them entirely. |
| Q4 | Battery guard | On when `OnBattery` is true, at any level. The alternative is on battery *and* below a threshold. |
| Q5 | Overdrive requests while a guard or session is on | Accept them as `suspended`, with the reason shown, the same as a guard tripping mid-lease. The alternative is to refuse them. |
| Q6 | `tim stop` | Acknowledge DONE and reset every running timer. `tim pause` pauses them all. |
| Q7 | `NotificationClosed` | Keep today's rule: it removes the item. Serpantinum appears not to close notifications on popup expiry, since the archive's session mirror held 49. That is inferred, not verified. |
| Q8 | View IPC | `open`/`page`/`close`/`toggle` go only through the core. `qs ipc` keeps `status` for diagnostics. |
| Q9 | Verbs | Drop `launch` and `island`, and keep `toggle`. |
| Q10 | Pomodoro settings | Move from `settings.json` into the core's `timers.json` `config`, migrated once. The running phase keeps its length when the settings change. |
| Q11 | Host profile location | `adapters/serpantinum/core.py`, beside the QML adapter. |
| Q12 | How rooms get the core | A third required property `core: CoreClient`, not a singleton, so the smoke test can point it at a test core. |

## 13. Implementation order (done)

Each step is checkpointed in Git:

1. `clock`, `store`, `timers`, plus the timer tests (the HANDOFF's first item).
2. `protocol` and `fartd`, plus the CLI rewrite; the `status`, `tim` and `shutdown` verbs.
3. `tasks` plus the migration.
4. `view` lifecycle, `CoreClient`, the room ports; delete `view/compat` and `Persistent`; update the smoke test and lint.
5. `notifications` (busctl), then switch `SerpantinumNotifications` and delete `notification_feed.py`.
6. `overdrive` plus `guards`, and the table test.
7. `sessions` and `discovery` skeletons.
8. Measurement:
   - the core's RSS and PSS, idle and after the smoke run
   - the busctl RSS
   - wakeups over 60 s idle (`/proc/<pid>/status` context switches)
   - the alarm firing with the view reaped
   - a live check against Serpantinum without actuating anything

   Then the HANDOFF entry.

Not done without your approval: installing or enabling the socket unit, the Super+` bind, the archive tag, the cutover.

## 14. Implementation notes (M2)

- **Memory.** Importing asyncio pulls in `ssl` (OpenSSL), and `tempfile`/`secrets` pull in the compression and hashing libraries. Together that is about 7 MiB of RSS the core never uses. `fartd.py` sets `sys.modules["ssl"] = None` before importing asyncio. `store.py` and `tasks.py` use `os.open`/`os.urandom` instead. The live core then maps only libc, libm and libpython: 21.4 MiB RSS, 12.5 MiB PSS, 11.7 MiB private dirty.
- **Timers snapshot** also carries `config` (the pomodoro lengths and `sound`), so the Timers room shows the focus and rest lengths.
- **Migration detail.** Task text is trimmed. On the live data, 1 of the 12 tasks lost a single surrounding space. Pomodoro settings came from fart-next's `settings.json` (focus 3600 s, sound off).
- **The view client.** `core/client/CoreClient.qml` holds the socket and the topic snapshots (`timersData`, `tasksData`, `notificationsData`, `overdriveData`, `sessionData`). `CoreTimers` and `CoreTasks` are its facades. Only the `tasks` and `timers` rooms receive `core`, through `Shell.coreRooms`. `ShellContext.core` serves `toggleActiveTimer()`. The Timers room holds `ticking` with a `Binding` while it is visible: 50 ms for the stopwatch, 200 ms otherwise.
- **Exterior.** The `island` IPC is gone, so `Overlay.showExterior` is now always false. Its compact exterior is dead code, to be removed with the M5 unfold.
- **Tests.** The tests are:
  - `test_core_timers` (drift, suspend, reboot, migration, a real timerfd)
  - `test_core_tasks`
  - `test_core_daemon` (real core process plus CLI, fixture host)
  - `test_core_view` (spawn, reap, PSI, crash loop)
  - `test_core_overdrive` (the §6.2 table plus sequences)
  - `test_core_notifications` (the parser)
  - `test_core_guards`
  - `test_core_busctl` (real busctl against a private `dbus-daemon` with a fake server; skipped without dbus-python)

  `tools/smoke.py` has the core spawn the harness as its view.
