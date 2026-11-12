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

**Proposed minimal diff — not applied.** Allocator settings preserve an existing owner-supplied value; the 20 Hz source rate matches the measured fixture interval. Recheck on current code and include CAVA before claiming the live media budget passes.

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
