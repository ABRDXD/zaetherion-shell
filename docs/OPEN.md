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
