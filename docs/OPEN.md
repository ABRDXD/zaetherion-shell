# Open items

Only these remain open. Each is settled by the named test, and the result goes back to the owner. Anything not listed here or in [DECISIONS.md](DECISIONS.md) is a question for the owner, not an assumption.

| # | Item | How it is settled | When |
|---|---|---|---|
| 1 | Wellbeing source: DMS `wellbeing` or Serpantinum's `focus_daemon.py` (Z51) | Run both side by side for 2 days. Compare, in the owner's order of priority: low cost (RSS, PSS, wakeups), keeping existing history (can `focustime.db` be imported or read), and accuracy against known focus time (idle and lock excluded). | S2 |
| 2 | Whether tesseract, zbarimg and satty are installed | Read-only package check. Any install needs the owner's approval. | S0 |
| 3 | Lyrics source order: DMS `lyrics` or FART's lrclib cache | Compare hit rates over the owner's recent tracks | S2 |
| 4 | Star catalogue file and licence (Yale Bright Star, public domain) | Confirm the source and licence; record it in NOTICE | S8 |
| 5 | Panel reap timer (Z142) | Measure cold-open cost against held memory, at 10 min and at 60 min | S2 |
| 6 | Installing the SDDM session file (root) | Owner's approval | S1 |
| 7 | Exact binds for island focus, display reset, overview and draw | Check `hyprctl binds` for free keys; owner's approval for each | S3, S10 |
| 8 | Boot flavour lines | About 6 original lines drafted in the system voice, with no quotes from any game; owner's approval | S10 |
| 9 | Fallback when DMS location is unavailable: cache the last good location? (proposed in RISKS.md) | Owner decides | S8 |
| 10 | Pin video decoding to the iGPU through the environment? (proposed in RISKS.md) | Owner decides; then measure dGPU `runtime_status` | S8 |
| 11 | Keyboard layout indicator and switching (Serpantinum's bar had one) | Owner decides | S3 |
| 12 | Per-monitor wallpaper images | Owner decides | S8 |
| 13 | FART's heavy layer draws Overdrive's black hole and the Medium on the NVIDIA card (the owner's choice for FART-next, 9 November 2026), but BUDGETS.md says "dGPU: never woken" and S11 accepts on it | Owner decides: keep the heavy layer and change the budget, or keep the budget and move the heavy layer to the iGPU. Measure either way (NVIDIA load and power, AMD load) | **Decided 10 November 2026: the heavy layer stays on the NVIDIA card, for Overdrive only** (the AMD chip couldn't carry it). Budget changed in BUDGETS.md. |
| 14 | Memory-pressure expansion on the island (owner's idea, 11 Nov 2026): threshold (e.g. PSI `memory some avg10`, or % used), its place in the priority queue, and the pin control | Propose at S3 with measurements; owner decides | S3 |
| 15 | DMS-down notice (Z123): the island lives in the process that goes down with DMS, so it cannot show "DMS went down" at that moment (docs/SUPERVISOR.md §4) | Owner decides: one notice when it is back ("was down 3 s"), or also have the panel show it if it happens to be open | S3 |
| 16 | A DMS the owner stopped on purpose (`dms kill`, or a plain kill): the supervisor starts it again after 3 s, as the interim `session-start` loop brings it back today | Owner decides: always bring it back, or stay down until asked | S1 switch-over |
| 17 | Retry pace while the screen is locked: the supervisor waits up to 30 s between attempts after repeated crashes; proposed 5 s at most while locked | Propose at S7 with the crash tests; owner decides | S7 |
| 18 | A second DMS next to the supervised one (started by hand, or an owner restart slower than 3 s): two bars, and the keybinds follow the newer one. The supervisor only reports it (docs/SUPERVISOR.md §5) | Owner decides: leave it and show a notice, or stop the extra one and restart cleanly | S1 switch-over |
