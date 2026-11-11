# Risks

| Risk | Mitigation | Tested at |
|---|---|---|
| The screen stays locked with nothing drawn after the resident process crashes. There is no fallback locker, by the owner's choice (Z35). | Set `allow_session_lock_restore`; `fartd` restarts `dms` and the resident process; the lock is Silent-only, and a failing sky layer degrades to a plain card instead of unlocking | S7 crash tests in nested Hyprland |
| DMS is the resident process's parent, so if DMS dies the shell dies with it | Restart with backoff; recovery ≤ 5 s; island announcements (Z123, Z127) | S2, S7 |
| API drift from the `-git` package | Pinned `apiVersion` range (40 at planning); recorded fixtures; a mismatch notice in the settings window | S0, S2 |
| Two owners of the ScreenSaver D-Bus name or of the clipboard | Only the ZÆTHERION session runs DMS. Serpantinum and its idle helper don't start there. cliphist keeps the clipboard (owner, 11 Nov 2026); DMS's clipboard stays off. | S1 |
| Runtime reads from Serpantinum (presets, sounds, emoji, PAM) break if it's removed | Degrade (Z125). At retirement, keep the used files and delete the rest only with approval (Z111) | S12 |
| Display settings apply instantly with no revert (Z92), so a bad output config can blank the screen | The `zaetherion display reset` verb and a bind restore the monitor config (Z94) | S10 |
| A keybind edit breaks Hyprland's config (Z93) | Check `hyprctl configerrors` after reload; keep the previous file; roll back automatically | S10 |
| The file index exhausts inotify watches (Z78) | Count watches before arming; fall back to a periodic walk; report it in settings | S6 |
| DMS location uses an IP lookup (Z16), so it can be wrong or fail offline | *Proposed, owner approval needed:* cache the last good location; the sky uses the cache and says so, as Z126 does for weather | S8 |
| A public repo leaks personal data | Scrub fixtures (Z113); grep for coordinates, SSIDs, MACs, notification text and absolute home paths before every push | Every push |
| Video wallpaper decoding wakes the dGPU | *Proposed, owner approval needed:* pin the decoder to the iGPU in the environment, as Serpantinum does; measure `runtime_status` | S8 |
| Nested Hyprland isn't viable for tests | Verify at S1. If it fails, ask the owner how lock testing should proceed. | S1 |
