## Current-code recheck · `eb09501` · 12 November 2026

**The tuned memory plateau reproduces; 20 Hz view + CAVA still exceeds the 5% media budget with synthetic PCM.** The allocator default and both 20 Hz settings were already committed in `946feb7`. No additional runtime change is proposed. Measurements exclude concurrent uncommitted work in the shared checkout.

The resident/panel launch reaches `core/view.py:spawn_quickshell` from `core/fartd.py`. It copies the child environment and uses `setdefault`, preserving nonempty **and empty** owner values. `shell-dms.qml` uses `DmsAdapter.media: QuickshellMedia`, whose lease/playing-gated CAVA process **does use `tools/cava.conf`**.

Private hidden nested Hyprland, hardware OpenGL, private runtime/home/config/cache/state/data/DBus, inherited `FART_*` unset. The compositor used explicitly empty `MALLOC_CONF`; the view received the actual child-launch default `thp:never,narenas:4,dirty_decay_ms:3000`. Five-second memory settling; 100 Home open/fold cycles, checking open and fully unretained states. MiB:

| Cycles | RSS | PSS | Private_Dirty |
|---:|---:|---:|---:|
| 0 | 269.7 | 84.3 | 62.9 |
| 1 | 329.1 | 126.5 | 99.9 |
| 21 | 328.8 | 128.2 | 102.0 |
| 50 | 330.0 | 129.1 | 103.1 |
| 100 | 328.1 | 127.5 | 101.4 |

Cycle 100 includes **225.7 MiB shared mappings**; `AnonHugePages` remains 12 MiB. No new object-count/allocator ablations were needed. This is not a memory-budget pass.

CPU is percent of one core, mean **[min–max]** over three consecutive 30-second windows per row:

| Source/state | View | CAVA producer | Combined |
|---|---:|---:|---:|
| Rest | 0.02 [0.00–0.07] | — | 0.02 [0.00–0.07] |
| Existing 24-bin fixture, 20 Hz | 4.72 [4.70–4.73] | in view | 4.72 [4.70–4.73] |
| CAVA, 56 bins, 20 Hz | 4.90 [4.63–5.26] | 1.47 [1.37–1.57] | **6.36 [6.09–6.83]** |
| CAVA, 56 bins, 30 Hz control | 7.37 [7.16–7.53] | 2.08 [2.03–2.10] | 9.45 [9.26–9.62] |

CAVA consumed private synthetic stereo PCM through a FIFO; the fixture used the production ASCII parser, with counters added. All 56 bins were nonzero at window boundaries. Delivered source rates were 20.02/30.06 Hz, **not measured display FPS**. The 20 Hz condition used about 33% less combined CPU. Combined excludes the nested compositor (20 Hz mean 2.10%) and artificial PCM feeder (0.67%). CAVA alone sampled 11.7 MiB RSS / 6.2 MiB PSS / 2.8 MiB Private_Dirty.

**Uncertainty.** Real audio-backend capture and the full DMS stack remain unmeasured; this fixture cannot establish a live-session pass. Consecutive windows and sequential conditions do not control process-to-process, clock, cache or background-load variation. Current uncommitted island changes need their own recheck.

**Artifacts/checks.** [Raw samples and method](measurements/island-eb09501.json), [measured runtime diff, already in HEAD](measurements/island-eb09501-runtime-already-applied.patch), [proposed six-line empty-owner-value regression test](measurements/island-eb09501-proposed.patch), [experimental CAVA fixture diff](measurements/island-eb09501-experiment.patch). The experimental fixture expects `ASTRA_CAVA_CONFIG` pointing to the private FIFO config described in the evidence. 28 core-view, five offscreen island and three DMS-entry tests passed; all ten offscreen smoke rooms passed; Qt 6 `qmllint` had zero `syntax*` diagnostics; nested `hyprctl configerrors` was empty. No QML binding/type/reference errors. Baseline-only warnings concern the absent private avatar/font, nested text-input focus and private portal registration; CAVA runs had none.

Owned views, CAVA, PCM feeders, private DBus/services and nested compositor were stopped and the detached worktree removed. Shared runtime code was untouched; no staging, commits, pushes, installs or live-session actuation.

# Island memory and CPU diagnosis · 12 November 2026

**Memory plateaus.** The large increase is mainly allocator/transparent-huge-page overhead, with expected Shell and compilation retention. Measured at `9662778` in a detached worktree: hidden nested Hyprland, GPU renderer, private fixture environment, inherited `FART_*` unset, five-second settling. Table uses default jemalloc settings; absolute baselines differ from the earlier report, but its growth pattern reproduced. All memory figures are MiB. The island has no memory budget yet.

| Cycles | RSS | PSS | Private_Dirty | Trend |
|---:|---:|---:|---:|---|
| 0 | 330.0 | 144.4 | 118.2 | Baseline |
| 1 | 398.6 | 199.8 | 166.3 | Initial allocation |
| 21 | 425.5 | 226.7 | 193.5 | Approaching plateau |
| 50 | 425.4 | 222.5 | 193.5 | Flat |
| 100 | 420.4 | 221.6 | 188.5 | Plateau confirmed |

RSS at cycle 100 includes approximately **227 MiB of shared mappings**.

- **First-open cost.** Private_Dirty increased 48 MiB, while live jemalloc allocations increased only 11.5 MiB. Ablations attribute approximately **4 MiB of live allocations to keeping Shell**, and **6 MiB to the room/compilation path**, including **2–3 MiB from room precompilation**. These are approximate, overlapping measurements.
- **Allocator overhead.** Live allocations stayed around **56–57 MiB through 100 cycles**. This binary uses **jemalloc**, so `malloc_trim()` did nothing. After cycle 100, `gc()` recovered 0.7 MiB Private_Dirty; jemalloc purge recovered another 11 MiB. The inherited setting `thp:never,narenas:4,dirty_decay_ms:3000` reduced cycle-100 **PSS/Private_Dirty from 222/188 to 135/101**, with essentially unchanged live allocations. Untuned `AnonHugePages` reached 100 MiB.
- **Ruled out as accumulating leaks.** Both room slots emptied after folding; sampled leases and satellites were empty. Counts stayed exactly **1,859 objects, 32 Connections, 23 Loaders and 49 Shapes** from cycles 1–100. Disabling island morphing provided no meaningful live-allocation saving. Driver VRAM allocations rose approximately **39→77→81 MiB**, then plateaued; they are separate from PSS. Graphics-resource release and component-cache trimming barely changed process memory. Texture/glyph caches remain plausible bounded first-use costs.

**CPU.** Thirty-second measurements gave **0.03% of one core at rest**, **6.53% playing**, **0.67% generating but not publishing spectrum**, and **0% with the timer stopped**. Roughly **5.9 percentage points** belong to spectrum updates/rendering. At **20 Hz**, consumption was **4.33% with 24 bins** and **4.37% with 56 active simulated bins**, within the 5% media budget; rest is within 2%. Changing Shape renderer alone still exceeded 5%. CAVA's separate process was not measured.

**Historical proposal at `9662778` — subsequently applied in `946feb7`.** Allocator settings preserve an existing owner-supplied value; the 20 Hz source rate matches the measured fixture interval. Recheck on current code and include CAVA before claiming the live media budget passes.

```diff
--- a/core/view.py
+++ b/core/view.py
@@
 async def spawn_quickshell(entry: Path, env: dict):
+    env = dict(env)
+    env.setdefault("MALLOC_CONF", "thp:never,narenas:4,dirty_decay_ms:3000")
--- a/shell-island-fixture.qml
+++ b/shell-island-fixture.qml
@@
-        interval: 33
+        interval: 50
--- a/tools/cava.conf
+++ b/tools/cava.conf
@@
-framerate = 30
+framerate = 20
```

**Verification and cleanup.** No unexpected QML errors; nested `hyprctl configerrors` empty. Nested compositor stopped and detached worktree removed. No commits, staging, pushes, or live-session changes were made for the diagnosis.
