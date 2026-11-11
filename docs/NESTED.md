# Nested Hyprland for tests (Z109), verified 11 November 2026

**Result: viable.** Hyprland 0.57.1 runs nested inside the live session, and lock tests work in it without touching the real session or the owner's password.

## How it works
- `tools/nested_hypr.py start` launches `Hyprland -c tests/fixtures/nested/nested.lua` with exec rules (`special:ztest silent`, no initial focus), so the nested window never appears and never takes the keyboard. No Hyprland config or keybind of the owner's changes.
- The nested window is hidden, so it gets no frame callbacks and its own output never renders (grim times out on it). The tool therefore adds a **headless output `ZTEST`** inside the nested compositor; it renders on its own timer, and `shot` captures it.
- The DRM backend fails nested (the seat is taken) and Hyprland falls back to the Wayland backend. That log noise is expected.
- `run CMD…` runs a client against the nested compositor; `stop` exits it and removes its runtime folder.

## Self-test (`tools/nested_hypr.py selftest`, 9/9 pass, twice)
1. Base screen is not locked.
2. A fake lock (Quickshell `WlSessionLock`, `tests/fixtures/nested/lock`) covers the screen; 3. unlocking clears it.
4. Killing the lock client keeps the screen covered (Hyprland's "lockscreen app died" page; recovery would be `hyprctl --instance N eval 'hl.clear_crashed_lockscreen()'`).
5. A new lock client takes over (`allow_session_lock_restore`); 6. it unlocks.
7–8. **Fake PAM:** Quickshell's `PamContext` with `configDirectory` pointing at `tests/fixtures/nested/pam` uses only those files: `pam_permit` → Success, `pam_deny` → failure. No system PAM file and no real password is involved.
9. The real session has no `ZTEST` output and no `special:ztest` workspace left afterwards, and was never locked.

## Limits
- Needs a live Hyprland session (it is not part of the offline unit suite; `tests/test_nested_fixtures.py` checks the fixtures only).
- Real PAM (`pam_unix`), fingerprint and polkit agents still need the real session with the owner present (Z109).
