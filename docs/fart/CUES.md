# Cue system and motion

Status: **approved and implemented 6 November 2026** (M4 steps 1–5). You approved every recommendation in section 13. The code in `view/cues/` is the source of truth; when the two disagree, fix this file. Section 14 records where the implementation refined the draft. Section 15, the amendment that makes FART move like the rest of Serpantinum, was **approved and implemented 6 November 2026**; where it changed a token or a site, §15.3 supersedes §5 and §9.

M4 implements D17: a declarative cue system with interrupt and reverse semantics, Motion tokens, a reduced-motion path with a static montage and no shaders, and a flash cap of 3 per second. It also absorbs Astra's MOTION-01. M5 (unfold, command line, satellites), M6 (montage, reticle), M8 (ignite, strata), M9 (kinetic lyrics) and M13 (lensing) build on it, so the API has to hold for them. M4 itself only migrates the motion that exists today, with no new visual design.

## 1. Rules

1. **State changes at input time; cues only show it.** A key or click changes the logical state (page, open, month, selection) in the same event-loop turn. A cue animates the visual toward that state afterwards. The visual may lag the logical state, never the reverse. No logic waits for an animation to finish.
2. **One animation per cue, and nothing queues.** A new trigger retargets the running animation from the value it has reached. A cue never stores a pending trigger, and never plays one animation after another because input arrived during the first.
3. **Idle costs nothing.** A cue that is not moving holds no running animation, so Qt's animation timer has nothing to tick. An invisible cue settles at once. A finite cue never runs while nobody can see it.
4. **Reduced motion is a complete path.** With motion reduced, every cue lands on its final state at once, nothing loops, nothing flashes and no shader is created. The result is the static Silent montage, not a broken animation.

## 2. Files

Everything lives in `view/cues/`, imported as `qs.view.cues`.

| File | Kind | Role |
| --- | --- | --- |
| `Motion.qml` | singleton | Tokens (durations, easings, distances), `reduced`, `timeScale`, `live(item)`, the activity count |
| `Cue.qml` | type | A state cue: `value` follows `on` between 0 and 1 |
| `Pulse.qml` | type | An impulse: rest → peak → rest, optionally repeating, optionally a flash |
| `Timeline.qml` | type | One linear driver with several `Track`s, for staggered choreography |
| `Track.qml` | type | One eased segment of a `Timeline` |
| `Tween.qml` | type | A gated `Behavior` for property feedback (colour, position) |
| `FlashGate.qml` | singleton | The flash limiter (D17): at most 3 flashes in any 1000 ms window |
| `Activity.qml` | type | Reports a running animation that is not a cue (the bongocat) to `Motion.activeNames` |

Layering: `view/cues` imports only QtQuick and Quickshell (for the `QsWindow` attached property), and nothing from `qs.*`. It never reads `ViewState` or the host. `Overlay` binds `Motion.reduced` from the preference (section 6), the same way it injects the palette into `Design`. That keeps cues loadable alone in the fixture harness. `tests/test_contract.py` gains the rule: `view/cues` imports no `qs.*` module.

## 3. Components

### 3.1 Cue (state)

```qml
Cue {
    id: unfold
    name: "overlay.unfold"
    on: root.opened
    enter: Motion.unfold      // ms to reach 1
    exit: Motion.fold         // ms to reach 0
    easing: Motion.standard
}
// consumers bind to unfold.value
```

| Member | Meaning |
| --- | --- |
| `on: bool` | The target. `true` → 1, `false` → 0. It is the only way to drive the cue. It is normally bound to logical state, and may be assigned by imperative owners. |
| `enter`, `exit: int` | Full-distance durations in ms, taken from tokens. `exit` defaults to `enter`. |
| `easing`, `exitEasing: int`, `overshoot: real` | Easing tokens. `exitEasing` defaults to `easing`. |
| `scope: Item` | The item whose visibility decides liveness (3.5). `null` means live whenever motion is not reduced. |
| `name: string` | Stable id for the activity count, tests and diagnostics (`room.part`). |
| `value: real` (read-only) | 0 at rest, 1 at full. An expressive easing may overshoot past 1, so consumers clamp where it matters (opacity). |
| `running: bool` (read-only) | Visual only. Never bound to `enabled` or to logic (rule 1, enforced in 4.3). |
| `settle()` | Jump to the target now. Used for liveness loss, reduced motion and tests. |
| `settled()` signal | Fires after reaching the target, whether animated or snapped. Handlers may only touch visuals, for example to unload an outgoing layer. |

Internally a Cue is one `NumberAnimation` on `value`. When the target changes, it stops, sets `from` to the current value and `to` to the target, and starts again. The duration is **proportional to the remaining distance**: `round(token × min(1, |to − value|))`. So a reversal at 66% takes 66% of `exit`. The spike in 11.1 measured that.

### 3.2 Pulse (impulse)

```qml
Pulse { id: press; name: "creature.press"; attack: Motion.feedback; release: Motion.navigate; easing: Motion.expressive }
// onClicked: press.trigger()
```

| Member | Meaning |
| --- | --- |
| `trigger()` | Rise to 1 over `attack`, then fall to 0 over `release`. |
| `cancel()` | Snap to 0. |
| `repeat: bool` | Loop rise and fall while live. Used for breathing indicators. |
| `flash: bool` | This pulse is a flash. Each rise asks `FlashGate` first (section 7). |
| `value`, `running`, `scope`, `name` | As in Cue. |

### 3.3 Timeline and Track

A Timeline is a Cue whose `value` is a **linear** driver `t` from 0 to 1. Each `Track` maps a window `[start, end]` of `t` to its own eased `value`. One animation drives every track, so a ten-plane montage costs one animation, not ten.

```qml
Timeline {
    id: montage; name: "home.planes"; on: root.shown; enter: Motion.unfold
    Track { id: back;  start: 0.0; end: 0.6; easing: Motion.standard }
    Track { id: front; start: 0.3; end: 1.0; easing: Motion.expressive }
}
// planeA.x: Motion.nudge * (1 - back.value)
```

A Track evaluates its curve with `easing.valueForProgress(local)` on an internal, never-started `PropertyAnimation`, so tracks use the same easing tokens as cues. The 11.1 spike confirmed that this exists in Qt 6.12. Reversing a Timeline retraces it, so the stagger order reverses on its own. A different exit choreography is a second Timeline, not a mode.

### 3.4 Tween (property feedback)

Some motion is not a 0..1 state: a colour easing between roles, the portrait parallax following the pointer, the M6 reticle following focus. A Tween is a `Behavior` that knows about liveness:

```qml
Tween on fillColor { scope: root; ColorAnimation { duration: Motion.feedback } }
```

`Tween` is `Behavior { property Item scope; enabled: Motion.live(scope) }`, plus the activity count on its animation. Retargeting works the way Qt's `Behavior` already does: a new value starts a new animation from the current one. Durations are not proportional here, because colour distance is not meaningful and these are 100–180 ms. While not live, the Behavior is disabled, so the property jumps.

### 3.5 Liveness

`Motion.live(item)` is `!Motion.reduced && (item === null || (item.visible && (item.QsWindow.window?.visible ?? true)))`. `Item.visible` is already effective visibility, so it is false when any ancestor is hidden. The window term covers the panel surface being unmapped. A spike confirmed that attached properties resolve through a property or a function argument (11.1). Each component binds `live` once, so call sites stop repeating the `visible && QsWindow.window.visible && Motion.enabled` expression that FButton, FCreature, FStatusDot, Shell and Home each carry today.

## 4. Interrupt and reverse semantics

### 4.1 Event table

| Event | Cue | Pulse | Timeline |
| --- | --- | --- | --- |
| Triggered again in the same direction, mid-flight | No-op. The animation continues, with no restart and no jump. | During the rise: no-op. During the fall: rises again from the current value. It never stacks or exceeds 1. | No-op |
| Reversed mid-flight | Retarget from the current value with the other direction's easing. Duration = `exit` (or `enter`) × distance. Position is continuous. | Not applicable (a pulse always returns) | The driver runs back linearly from the current `t`. Every track retraces its own curve. |
| Cancelled mid-flight | `on = false; settle()`: at rest now, no animation | `cancel()`: at 0 now | `on = false; settle()` |
| Triggered while settled at the target | No-op | Starts a pulse | No-op |
| Scope hidden mid-flight | `settle()` to the target. Not paused (Q1). | Snaps to 0, and a repeating pulse stops | `settle()` |
| Scope shown again | Stays settled. Nothing replays. | A repeating pulse restarts from 0 | Stays settled |
| `Motion.reduced` set mid-flight | `settle()` | Snaps to 0, and repeating stops | `settle()` |
| Owner destroyed mid-flight | The animation dies with it. The activity count is decremented in `Component.onDestruction`. | Same | Same |
| Many triggers in one frame | Only the last `on` counts | One pulse (rise is idempotent) | Only the last `on` counts |

The proportional duration is the main visible change from today's `Behavior`, which always runs its full duration. Closing the panel 50 ms into its 240 ms unfold currently takes the full 140 ms fold. With the Cue, it takes about 30 ms (Q3).

### 4.2 Input is never queued

- **No deferred logic.** `ScriptAction`, `PauseAnimation` and `SequentialAnimation`/`ParallelAnimation` with side effects are not used outside `view/cues`. Cue signals (`settled`) may only change visual properties, for example unloading an outgoing layer. A page change, focus move, data write or host call never happens in an animation callback.
- **No interaction gating on motion.** Controls are never disabled because a cue is running. A click during an entrance acts at once on the logical state.
- **Outgoing content is not interactive.** If a cue shows content that is leaving (an out-phase), that content has `enabled: false` from the moment it starts leaving. Input then reaches the new content, not a ghost of the old (Q2).
- **Retarget, don't sequence.** Fast input converges: ten Ctrl+digit presses in 200 ms leave the last room loaded and its entrance settling within one `navigate` duration of the last press, not ten.

### 4.3 Enforcement (static, in `tests/test_contract.py`)

- Outside `view/cues/`: no `SequentialAnimation`, `ParallelAnimation`, `ScriptAction`, `PauseAnimation`, `SpringAnimation` without a `Tween`, raw `Behavior on` or `loops: Animation.Infinite`.
- Outside `view/strata/`: no `ShaderEffect`, `MultiEffect` or `ShaderEffectSource`.
- No `enabled:` or `visible:` binding that reads a cue's `.running`.
- Every `Cue`, `Pulse`, `Timeline` and `Tween` has a `name` or a `scope`, so the activity count can name it.

## 5. Motion tokens

### 5.1 Durations

The token values keep today's numbers, so the migration is visually neutral. Retuning belongs to M5 and M6, with your review.

| Token | Base ms | Was | Used by |
| --- | --- | --- | --- |
| `feedback` | 100 | `Motion.control`, `Design.fast` | Button fill colour, creature eye, press-in |
| `navigate` | 140 | `Motion.navigation`, `Design.enter` | Room entrance, creature body, calendar day colour (was 140 inline) |
| `fold` | 140 | `Motion.exit` | Panel close |
| `swap` | 180 | inline 170, 180, 210 | Calendar month fade-in and shift, day radius, portrait parallax |
| `emphasis` | 220 | inline 220 | Calendar day scale (expressive) |
| `unfold` | 240 | `Motion.panel` | Panel open |
| `breath` | 550 | inline 550 | Half-period of a repeating indicator pulse |

`Motion.<token>` returns the **effective** value: `round(base × timeScale)`, or 0 when reduced. `Motion.base.<token>` holds the raw number. `timeScale` defaults to 1. The fixture harness sets 10 so timing assertions tolerate frame jitter (section 10). It can also be used live, for slow-motion inspection. Tokens for timing that is not animation (the 600 ms ignite hold, the 3 s track satellite dwell, the 1 s discovery whisper) are added by the milestones that use them (M8, M5, M15), not now.

### 5.2 Easings and distances

| Token | Value | Was | Used for |
| --- | --- | --- | --- |
| `standard` | `Easing.OutCubic` | `Motion.ease`, inline OutCubic | Entering and settling. Also the panel fold today (Q9). |
| `expressive` | `Easing.OutBack`, `overshoot` 0.55 | `Motion.expressiveEase`, `overshoot`, inline 0.5 | Small accents only (day scale, creature). Never for panels or planes. |
| `linear` | `Easing.Linear` | NumberAnimation's default | Timeline drivers, breathing pulses |
| `nudge` | 6 px | inline 6 (entrance), 5 (calendar shift) | Entrance travel |

The montage angles (−12°/78°) stay in `Design`. M6 adds plane travel along them using these tokens.

### 5.3 Migrating `view/ui/Motion.qml`

1. Create `view/cues/Motion.qml` with the tokens above, `reduced`, `timeScale`, `live()` and the activity count. `Motion.enabled` becomes `!Motion.reduced` for one commit only.
2. `Overlay` adds `Binding { target: Cues.Motion; property: "reduced"; value: !ViewState.motionEnabled }`. The preference key stays `motion` in `preferences.json`, and the "Motion: full / reduced" button is unchanged.
3. Migrate every site in section 9, one commit per area: Overlay, Shell, controls (`view/ui`), rooms.
4. Delete `view/ui/Motion.qml` and `Design.fast`/`Design.enter`. The lint in 4.3 then holds, and `grep` finds no `Motion.enabled`, `Motion.control` or `Motion.navigation`.

## 6. Reduced motion

**Source.** The FART preference "Motion: reduced" (`ViewState.motionEnabled`), as today. I checked the host read-only. The desktop portal (1.22.1) has no `org.freedesktop.appearance reduced-motion` key here, GNOME's `enable-animations` is true, and Serpantinum 2.4.1 has no motion setting. A host hint can become an adapter field later if a host offers one (Q4).

**What changes when reduced.**
- Every token returns 0, and `live()` is false. Cues snap, Pulses do nothing, repeating pulses stop, and Tweens are disabled. State changes are hard cuts.
- `FlashGate` grants nothing. Flash cues show their steady end state instead (section 7).
- **Static montage.** Silent planes are already static by D13. Reduced motion pins them at their final positions, with no entrance travel and no parallax.
- **No shaders.** The M8 strata `Loader` is `active: overdriveHeld && !Motion.reduced`. While motion is reduced, no stratum, `ShaderEffect` or effect texture exists, even if Overdrive is held. The core's lease stays as requested, so the strata appear when you turn motion back on, and the panel shows "Overdrive · reduced motion" (Q5). The M13 lensing capture is skipped, which also saves its texture.
- Animated assets stop: the bongocat `AnimatedImage` already checks `Motion.enabled`, and that becomes `live()`.
- **Information is not motion.** Progress that reports state stays visible, because it is bound to data, not to a cue. That covers timer rings, the seek position, the M8 ignite hold meter and the M9 lyric line position. Under reduced motion it updates in place with no easing.

## 7. Flash limiter (D17)

**What counts as a flash.** A cue that swaps paper and ink, inverts a surface, or cuts a large area between light and dark roles. It is tagged explicitly with `flash: true` on a Pulse, or through `FlashGate.request()` for a hard cut. The inventory today has **no** flash cues. The first ones will be the M5 timer `DONE` satellite inversion, the M8 ignite flash and the M9 kinetic-lyric cuts. Section 9 shows that no current cue qualifies: the status-dot breath is an 8 px element, and the room entrance dips content opacity by 30% at most.

**The gate.** `FlashGate` is one view-wide singleton, because flashes on the panel and on the satellites add up for the eye. It keeps the timestamps of its last grants and allows a request only if fewer than 3 were granted in the preceding 1000 ms. One pulse (out and back) counts as one flash, which is the WCAG 2.3.1 pair of opposing changes.

**Denied means dropped, not deferred.** A denied flash pulse holds its steady state. A denied hard cut becomes a cut without the flash (M9's cut cap). Deferring the flash to the next free slot would be a queue (rule 2) and would desynchronise it from its cause (Q6). Under reduced motion, every request is denied.

**Testability.** `FlashGate.now` is a function the harness can replace, so the window can be tested without waiting.

## 8. Invisible, idle and release

- **While running:** a cue holds one Qt animation. Qt drives it from the GUI thread's animation timer, which runs only while some animation is registered.
- **When it settles:** the animation stops and unregisters. A settled cue costs a few hundred bytes of object memory and no wakeups. The measurement in 11.2 checks this, rather than assuming it.
- **When invisible:** finite cues settle and repeating pulses stop (3.5). Nothing is paused half-way, because a paused frame shown later would be stale, and finishing it would make the visual lag input (Q1).
- **Release by destruction:** rooms are unloaded on navigation, `Shell` is unloaded when the panel finishes folding (`Overlay` `Loader.active: retained`), and the core reaps the whole view after 10 minutes closed. Cues inside are destroyed with them, and nothing is kept hidden. The M8 strata follow the same rule through their leases.
- **The activity count:** each component calls `Motion.begin(name)` when its animation starts and `Motion.end(name)` when it stops or is destroyed. `Motion.active` is the count, and `Motion.activeNames` the list. Diagnostic `fart status` (IPC) gains `motion: {reduced, active}`. When everything is settled, `active` must be 0. A loop that is playing shows up by name. That gives the zero-idle-cost claim a number that can be checked live without screenshots, and lets a test enforce D12's limit of ≤2 moving elements per room.

## 9. Adoption: every animation site today

The inventory comes from `grep` over `view/` on main `d7651b7`. None of the nine rooms has an animation beyond these.

| Site | Today | Becomes | Visible difference |
| --- | --- | --- | --- |
| `Overlay` expansion | `Behavior on expansion`, 240 open / 140 close, OutCubic | `Cue overlay.unfold`, `on: opened`, `enter: unfold`, `exit: fold`. `expansion: unfold.value`. No scope, because the surface's visibility depends on this cue. | A reversal mid-unfold takes proportional time (Q3). Otherwise none. |
| `Shell` room entrance | `ParallelAnimation` restarted on load: opacity 0.7→1, x 6→0, 140 ms | `Cue shell.entrance`, reset to 0 by `onLoaded` only when settled. A load during flight keeps the current value and retargets, so mashing room keys cannot strobe the 30% dip. `pageLoader.opacity: 0.7 + 0.3 × value`, `x: nudge × (1 − value)`. | Rapid navigation no longer re-dips each time. Single navigation is identical. |
| `FCalendar` month swap | Sequential: fade out 85 → swap month in a `ScriptAction` → fade in 170 and shift 210 | `month` changes at once on click. `Cue calendar.swap` resets and runs in only: opacity and a 6 px shift over `swap` (180) (Q2). | The 85 ms fade-out is dropped, the fade-in is 10 ms longer and the shift 30 ms shorter and 1 px longer. The logical month no longer lags the click by 85 ms. |
| `FCalendar` day cell | Ungated `Behavior`s: scale 220 OutBack 0.5, radius 180, colour 140 | `Tween`s with scope = cell: scale `emphasis` and `expressive`, radius `swap`, colour `navigate` | Overshoot 0.5 → 0.55. They now stop under reduced motion, which they ignored before (a bug). |
| `Home` portrait parallax | `Behavior on x/y` 180 OutCubic, gated by hand | `Tween` with scope = room, `swap`, `standard` | None |
| `FButton` fill | `Behavior on fillColor`, ColorAnimation 100, gated by hand | `Tween`, `feedback` | None |
| `FCreature` body | `Behavior on rotation`, SpringAnimation (spring 4, damping 0.35) | `Tween` holding the same `SpringAnimation`. The lint allows springs only inside a `Tween`. | None (Q7) |
| `FCreature` eye | `Behavior on height`, 100 | `Tween`, `feedback` | None |
| `FCreature` reaction | `SequentialAnimation`: scale → 0.93 in 100, → 1 in 140 OutBack | `Pulse creature.press`, `attack: feedback`, `release: navigate`, `expressive`. `scale: 1 − 0.07 × value`. | None. A retrigger mid-reaction rises from the current value, as `restart()` without `from` does now. |
| `FStatusDot` | Infinite opacity loop 1 → 0.3 → 1, 550 ms each, linear | `Pulse status.breath`, `repeat: true`, `attack` = `release` = `breath`, `linear`. `opacity: 1 − 0.7 × value`. | None. It counts as one moving element (Media while playing, Devices while recording). |
| `Media` bongocat | `AnimatedImage.playing` gated by hand | Unchanged asset. `playing` uses `Motion.live(root)`, and a one-line `Motion.hold(name, playing)` reports it to the activity count. | None |
| Timers, `LyricsTimeline`, Devices recording clock | `Timer`s for data, not motion | Unchanged and outside the cue system | — |

The Overlay focus grab keeps `expansion > 0.02` in its condition. `retained` becomes `opened || unfold.value > 0`.

## 10. Fixture test plan

All QML tests run under Quickshell offscreen, like `tools/smoke.py`, because `qs.*` imports resolve only at runtime. A new `tools/cuetest.py` starts a harness `CueTest.qml` with the fixture adapter and a private core, sets `Motion.timeScale = 10` (240 ms becomes 2.4 s, so a 16 ms frame is under 1% of a cue), records `onValueChanged` samples with `Date.now()`, and prints result lines. `tests/test_cues.py` runs it and asserts. Static checks go in `test_contract.py` (4.3).

### 10.1 Component tests (each of Cue, Pulse, Timeline, Tween)

For each, at 25%, 50% and 75% of flight:

| Case | Assertion |
| --- | --- |
| Retrigger in the same direction | The value stays monotonic, with no restart and a settle time unchanged within 2 frames |
| Reverse | No position jump: every step ≤ the largest per-frame step of the uninterrupted run, plus 1%. Settles at the start within token × distance ± 2 frames. |
| Cancel | Value 0 on the same turn, `running` false, `Motion.active` back to the baseline |
| Hide the scope | Settled at the target on the same turn, and `active` drops |
| Show the scope again | No replay; a repeating pulse restarts |
| Reduced set | Settled, and no animation starts afterwards |
| Destroy the owner | No warnings; `active` back to the baseline |
| 20 triggers in one frame | One animation, final value = last `on` |

Timeline extras: reversing mid-flight retraces each track, and stagger order reverses (the front track leaves first). Pulse extras: a retrigger during the fall never exceeds 1. FlashGate, with a stubbed clock: 10 requests in 200 ms grant exactly 3; a request 1001 ms after the first grant is allowed; with reduced motion, 0 are granted.

### 10.2 Every adopted cue, in place

The harness walks the inventory in section 9 by `name`. For each cue, it drives the real owner (open/close the Overlay, navigate rooms, shift the month, hover and press a fixture button, wake and poke the creature) and interrupts at 50% with a reverse and with a cancel. It then asserts the same no-jump and settle rules. A cue named in section 9 that the harness cannot reach fails the test, so the inventory and the test stay in step.

### 10.3 No queued input

| Scenario | Assertion |
| --- | --- |
| `navigate()` through all 9 rooms within 100 ms | After each call, `currentPage` and `loadedPage` equal the request on the same turn. After the last call, everything settles within one `navigate` + 2 frames. |
| Overlay open/close × 5 within 100 ms | `opened` follows each command on its turn. The final state is the last command. Settles within one `unfold` or `fold` of the last command. The focus grab state follows `opened`. |
| `shiftMonth(+1)` × 5 within 100 ms | `month` is +5 at once, and one swap cue is running, not five |
| Click a fixture control during the room entrance | It acts on the same turn (state change or fixture call log), and nothing waits for `settled` |
| Hover in and out ×10 at frame rate on a button | One Tween animation at a time; the final colour matches the final hover state |

### 10.4 Idle

- After settling in each of the nine rooms with fixture media **paused**: `Motion.active == 0`.
- With fixture media **playing** in Media: `activeNames` is exactly the status-dot breath and the bongocat, which is within D12's ≤2.
- With the window hidden: 0.

### 10.5 Live checks (after implementation, read-only)

- `fart-next status` plus IPC `status`: `motion.active == 0` with the panel open and idle, and with it closed.
- 60 s idle wakeups for the view main thread, compared with the M2 baseline (≈5/s, the same as the archive). This checks rule 3 rather than assuming it.
- View RSS and PSS reported separately, before and after, closed and open idle. I expect no measurable change and will not claim an optimization.
- If M3's harness has landed: `QSG_RENDER_TIMING` on open, navigation and fold, with p99 compared against 6.9 ms. Runs with user input are excluded.
- No playback, volume, network, Bluetooth, brightness, power, recording or update action is used. A playing state comes only from the fixture.

## 11. Evidence behind the draft

### 11.1 Spikes (offscreen `qml`, Qt 6.12.0, throwaway files in the job directory, not in the repo)

- **Retarget:** a 1000 ms OutCubic animation reversed at 300 ms reached 0.663. A proportional reversal was planned at 663 ms and settled in 672 ms (one frame over). The first sample after the reversal was 0.616, and the largest step in the run was 0.051, at OutCubic's fastest phase. So there is no position jump.
- **Easing evaluation:** `PropertyAnimation.easing.valueForProgress(0.5)` returns 0.8750 for OutCubic, so Tracks can share easing tokens with Cues.
- **Attached properties:** `item.Window.window` resolves through a property and through a function argument. `QsWindow` is expected to behave the same way, and implementation step 1 confirms that under `qs`.

### 11.2 Still to measure in implementation

- That `Tween on <property>` works for a QML type whose root is `Behavior` (it should, as a property value interceptor). If it does not, the sites keep `Behavior on` with `enabled: Motion.live(scope)`, and the lint allows that one form.
- That a settled Cue adds no wakeups. Compare 100 settled cues with none, over 60 s offscreen.
- The view's RSS/PSS change from the cue objects. The calendar alone has 42 cells × 3 Tweens. I expect it to be small, and it will be reported, not assumed.

## 12. Implementation order

Each step ends with a Git checkpoint.

1. `view/cues/`: `Motion`, `Cue`, `Pulse`, `Timeline`, `Track`, `Tween`, `FlashGate`, plus `tools/cuetest.py` and `tests/test_cues.py` with the 10.1 tests. Confirm `QsWindow` liveness and the wakeup baseline (11.2).
2. Overlay and Shell adopt cues: unfold and entrance. 10.3 navigation and Overlay tests.
3. `view/ui` controls adopt cues: FButton, FCreature, FStatusDot.
4. Rooms adopt cues: FCalendar and Home. Bongocat activity. 10.2 and 10.4.
5. Delete `view/ui/Motion.qml` and the `Design` aliases. Add the 4.3 lint and the IPC `motion` field.
6. Smoke, QML syntax and live checks (10.5); update LAYOUT and HANDOFF.

## 13. Review decisions (6 November 2026)

Every recommendation below was approved.

| # | Question | Decision | Alternative (rejected) |
| --- | --- | --- | --- |
| Q1 | What does a cue do when it becomes invisible mid-flight? | **Settle** at once at the target. Nothing replays when it is shown again. | Pause, and resume when visible. That shows a stale frame and makes the visual lag input. |
| Q2 | The calendar month swap | **In-only:** the month changes on click, and the new grid fades and shifts in. The 85 ms fade-out is dropped. | Keep an 80 ms out-phase showing the old grid, non-interactive. Clicks in that window would hit nothing. |
| Q3 | How long does a reversal take? | **Proportional** to the distance covered (token × distance) | The full token duration, as Qt's `Behavior` does today |
| Q4 | Where does reduced motion come from? | **The FART preference only.** The host offers no signal (section 6). An adapter field follows if a host adds one. | Also read GNOME `enable-animations` through the adapter |
| Q5 | Reduced motion while Overdrive is held | **Strata never load.** The lease stays as requested, and the panel says "Overdrive · reduced motion". | Reduced motion refuses or ends Overdrive in the core |
| Q6 | A flash request over the cap | **Dropped:** the steady state is shown, and nothing is deferred | Deferred to the next free slot. That is a queue, and the flash would lose its cause. |
| Q7 | The creature spring and the status-dot loop | **Keep as is**, inside `Tween`/`Pulse`, so nothing visibly changes in M4. M6 revisits the creatures with the montage. | Replace the spring with an expressive Cue now. It overshoots once instead of oscillating. |
| Q8 | Timing in fixture tests | **Real time with `Motion.timeScale = 10`** and tolerances in frames | A manual test clock. That needs a custom animation driver instead of Qt animations, which means more code and a path the real view never runs. |
| Q9 | Panel fold easing | **Keep OutCubic** in both directions for M4 (no visible change). M5 retunes the unfold from the clock rect. | Switch the fold to an accelerating InCubic now |
| Q10 | Names | `Cue`, `Pulse`, `Timeline`, `Track`, `Tween`, `FlashGate`, `Motion` in `qs.view.cues`. `Timeline` shadows the optional `QtQuick.Timeline` module, which FART does not use and will not import. | `CueTimeline` to avoid any shadowing |

## 14. Implementation notes (M4)

Where the code refined the draft:

- **Creation never animates.** A Cue ignores target changes until it completes, then starts at its target. Without this, a cue created `on` animated in while its bindings settled (Home's calendar swap ran for its whole duration on every room load). `cue.created` tests it.
- **`replay()`** is a Cue method the draft implied for the room entrance and the calendar swap: start again from rest unless already in flight.
- **A loop turned off** (a status dot when playback stops) falls back to rest from where it is, within one `release`. The old code snapped the opacity to 1, and a naive loop would have finished its cycle (up to 1.1 s).
- **Tweens are not counted** in `Motion.activeNames`, and do not snap when they lose liveness: Qt's `complete()` on a Behavior's animation stops it where it is rather than jumping (spike, 11.1), and the old FButton/FCreature `complete()` calls never jumped either. A Tween's run is finite (≤ 220 ms, or a settling spring) and its later changes jump. Counting them cost ~10 KiB per instance (measured below), which matters with one per button, so `Tween` is a bare gated `Behavior`.
- **The creature's press** keeps Qt's default OutBack overshoot (1.70158) instead of the `expressive` token, so it looks the same as before.
- **Overlay** has no scope (its surface's visibility depends on the cue). Offscreen has no `PanelWindow`, so `ViewTest` exercises the unfold through its exact Cue configuration.
- **Lint rules** (in `test_contract.py`): no raw sequences, `ScriptAction`, `PauseAnimation`, `Behavior on` or infinite loops outside `view/cues`; springs only inside a `Tween`; shaders only in `view/strata`; no `enabled`/`visible` reading a declared cue's `.running`; `view/cues` imports no `qs.*`. Each rule was shown to fail on a planted violation. The "every cue has a name" rule was dropped: `Cue` defaults its name.

Measured (offscreen, `qs` 0.3.2, Qt 6.12, software backend, 30 s windows after a 5 s settle; RSS is the steadier figure, PSS shown too):

| Harness | Context switches | CPU ticks | RSS | PSS |
| --- | --- | --- | --- | --- |
| 0 cells | 0 | 0 | 76.6 / 76.7 MiB | 27.1 / 29.7 MiB |
| 100 cells, each a settled Cue + Tween | 0 | 0 | 81.6 / 81.6 MiB | 32.1 / 34.5 MiB |

Per-instance cost from the 100 → 400 slope, beyond a bare cell: a plain `Behavior` ≈ 0.7 KiB, the final `Tween` within noise of that, a `Cue` ≈ 15 KiB. Loading the cue types costs a one-off 1.5–2.5 MiB. The view holds about ten Cues/Pulses, so roughly 150 KiB. Settled cues cause no wakeups, which is rule 3. The live view was not re-measured at this checkpoint (see HANDOFF).

Tests: `tests/test_cues.py` runs `tools/cuetest/CueTest.qml` (19 component cases) and `ViewTest.qml` (11 in-place cases: navigation burst, entrance interrupt and reduced, Overlay unfold burst and reverse, calendar burst, click during entrance, button fill retarget, creature retrigger, idle in every room, Media playing = exactly `media.cat` + `status.breath`, hidden = 0). Four mutations of the components (full-duration reversal, restart instead of retarget, replay restarting in flight, a flash cap of 4) and the creation guard each made the expected cases fail.

## 15. Amendment: move like Serpantinum (approved and implemented 6 November 2026)

You asked that FART not feel like its own thing: it should animate like the rest of the shell. "Or vice versa" would mean patching Serpantinum, which its updater overwrites (ADAPTER_CONTRACT §7.6), so FART follows the host. This revises D2's "identity comes from … motion" for Silent motion.

### 15.1 What Serpantinum does (2.4.1, read-only survey of 186 QML files)

Serpantinum has no motion tokens or reduced-motion setting; values are inline but consistent:

- **Popup open** (Volume, Calendar, Music, Wellbeing): a staggered intro. The body goes `scale 0.95→1`, opacity 0→1 and rises 20 px over 760–800 ms (OutQuart or OutExpo). Sections follow 100–400 ms later, rising 15–25 px over 700–900 ms (OutQuint, OutExpo, or OutBack with overshoot 0.8–1.2 for accents).
- **Popup close:** 150–160 ms with accelerating curves (InCubic, InQuart, InBack), content first and the body ~50 ms later.
- **Feedback:** colour 150 ms (88 Behaviors), opacity 150/250 ms, scale 250 ms OutQuint, content swap in 400 ms OutQuart, layout moves 480–800 ms OutQuint. Most used overall: 250 ms (424), 150 ms (246), 400 ms (155); OutCubic (346), OutQuint (169).

### 15.2 Proposal

1. **A host motion profile through the adapter.** The contract gains a static `motion` profile (role → duration, easing, overshoot), the way `palette` carries colours. `adapters/serpantinum/SerpantinumMotion.qml` holds the table below, derived from the survey; the fixture keeps today's values. `Motion` reads its tokens from the profile and keeps `reduced`, `timeScale` and the activity count. Only adapters know the host (D1).
2. **The panel opens like a Serpantinum popup**, as a `Timeline`: body (scale, opacity, 20 px rise), then the header/index, then the room, staggered like 15.1. Closing reverses the Timeline over ~160 ms. Time-reversing an Out curve gives an accelerating In curve, and the stagger reverses on its own (room first, body last), which is Serpantinum's close, with interrupt/reverse semantics intact. The old morph from the dead 104×40 exterior goes away; M5's unfold from the clock rect would use the same profile.
3. **Mapping:**

| FART role | Now | Serpantinum profile |
| --- | --- | --- |
| Panel open | 240 ms OutCubic morph | Timeline ≈ 1000 ms: body 800 OutQuart, header +100 ms OutBack 1.2, room +200 ms OutExpo |
| Panel close | 140 ms OutCubic | Timeline reversed over ≈ 160 ms |
| Room switch | 140 ms, opacity 0.7→1, 6 px from the side | 400 ms OutQuart, opacity and a 15 px rise |
| Button fill, eye | 100 ms | 150 ms OutCubic |
| Calendar month | 180 ms | 400 ms OutQuart |
| Day cell scale | 220 ms OutBack 0.55 | 250 ms OutQuint |
| Parallax, radius, day colour | 180 / 140 ms | 250 ms OutCubic / 150 ms |
| Status breath, creature | 550 ms, spring | unchanged (Serpantinum has no equivalent) |

4. **Unchanged:** no queued input, retargeting, the flash cap, reduced motion (still FART's preference, because Serpantinum has none), zero idle cost. Input never waits, so the longer opening does not delay the M5 ≤450 ms interactive budget; it does mean ~1 s of frames on each open, which M3's frame timing should measure against the p99 budget.

### 15.3 Implementation notes

- **Contract:** `view/contract/MotionDomain.qml` (`roles`, plain data) is the 15th domain. `adapters/serpantinum/SerpantinumMotion.qml` holds the 15.2 table; the fixture adapter leaves `roles` empty, so it runs on FART's defaults. `Overlay` binds `Motion.profile` from `host.motion.roles`, as it binds `reduced`; `view/cues` still imports no `qs.*`.
- **Motion by role:** `Motion.roles.<role>` merges `Motion.defaults` with the profile, field by field, and `Motion.<role>` is the effective duration (× `timeScale`, 0 when reduced). The roles are `feedback` (button fill, creature eye), `navigate` (room entrance: `travel`, `axis`, `fromOpacity`), `swap` (calendar month), `settle` (parallax, day radius), `tint` (day colour), `emphasis` (day scale), `unfold` (driver duration plus `body`, `header` and `room` windows with `rise` and the body's `scale`) and `fold`. The old tokens split where one served two roles: `swap` became `swap` + `settle`, and `navigate` became `navigate` + `tint`. `breath`, `pressIn` and `pressOut` (status dot, creature) are FART's own and no profile changes them. `Motion.base` is gone.
- **The unfold:** `view/shell/Unfold.qml` is the Timeline, shared by `Overlay`, `tools/measure/FixtureView.qml` and the cue harness. `Overlay` draws the frame at full size with the body's opacity, scale (about its centre) and rise. A separate `bodyShape` item tracks the drawn rectangle, so the input mask and the blur region follow it: Qt regions follow item geometry, not transforms. `Shell` takes `headerReveal`/`headerRise` (the header row and the index) and `roomReveal`/`roomRise` (the room viewport). The 104×40 exterior morph and the dead exterior row went away.
- **Visible differences under the fixture defaults:** the panel now fades in at full size instead of growing from 104×40. The fold retraces OutCubic, so it accelerates where it used to decelerate. The day radius eases OutCubic where it was linear. Under the Serpantinum profile, the 15.2 table applies.
- **Blur:** the blur region is the body's drawn rectangle from the first frame of the unfold, while the tint fades in. If the host compositor blurs regardless of alpha, the blur appears at full strength before the tint. This was not checked visually (no screenshots); it is a candidate for the M5 unfold review.
- **Tests:** `ViewTest` exercises the real `Unfold` and adds `motion.profile` (a partial profile keeps the other fields; the Serpantinum table applies; reset restores the defaults) and `overlay.unfold.stagger` (body before header before room at 15% of the driver; closing retraces within one `fold`, the room reaching 0 before the body, with no jump).
