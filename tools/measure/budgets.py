"""Upper bounds for the implemented Silent scenarios, in the report's units."""
BUDGETS = {
    "core_idle": {"core_rss_mib": 25, "core_switches_per_minute": 1},
    "closed_idle": {"view_pss_mib": 200, "view_cpu_percent": 0},
    "navigate": {"p99_ms": 6.9},  # offscreen render-loop total, informational (MEASUREMENT.md)
    # Desktop presentation (frames.desktop_checks): missed presentations outside room loads, the
    # most missed on any one room load, and per-room p99 of GPU time and render-thread work.
    "desktop_navigate": {"missed_steady": 0, "missed_per_load": 1, "gpu_p99_ms": 6.9, "render_thread_p99_ms": 6.9},
    # The command line while typing (desktop_cmdline.py, DAILY_DRIVER §1): no missed presentation at all.
    "desktop_cmdline": {"missed": 0, "gpu_p99_ms": 6.9, "render_thread_p99_ms": 6.9},
    "open_static": {"core_and_view_cpu_percent": 2},
    # Open to an interactive command line (desktop_nav.py --cold/--warm, DAILY_DRIVER §1), every run.
    "desktop_open": {"cold_ms": 450, "warm_frames": 1},
}
