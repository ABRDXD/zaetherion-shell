# Lock (S7, F5): design and failure table

Owner, 24 November 2026: Astra's password lock is approved for both forms (`view/lock/`, `tools/password-lock-study/`).
Z35 makes it the only locker (no fallback), so a fault must never leave the session open or the screen blank. This
note is the design the code is built and reviewed against (F6 reviews the code against the table in §5).

## 1. What already holds
- Hyprland: `allow_session_lock_restore = true` (`~/.config/hypr/zaetherion/session.lua`). A lock client that dies
  leaves the screen covered ("lockscreen app died"); a new client may take the lock over (docs/NESTED.md, 9/9).
- PAM: the `serpantinum` service (Z37): `-auth sufficient pam_fprintd.so`, then `system-auth`. pam_fprintd is not
  installed today, so only the password is asked; the design keeps a fingerprint path for when it is (§3.4).
- DMS's backend already decides *when* to lock: idle (Z38: dim 150 s, lock 300 s, off 450 s, suspend 600 s),
  `loginctl lock-session`, lock before sleep, its session actions. It has a **custom lock command** setting
  (`customPowerActionLock`): when set, each of those runs the command instead of DMS's own lock surface, and a
  logind Unlock resets it (`Modules/Lock/Lock.qml`: `spawnCustomLocker`, `onSessionUnlocked`).

## 2. Shape (UI only; DMS stays the backend)
- **When to lock: DMS**, unchanged (idle, logind, sleep). Its custom lock command is set to
  `<repo>/zaetherion lock`. No idle daemon, no logind listener of our own.
- **The lock itself: ZÆTHERION.** `zaetherion lock` → core op `lock.engage` → core state `lock` (topic):
  `{locked, since, reason}`, also written to `$XDG_RUNTIME_DIR/zaetherion/locked` before it is published.
  The resident view's `LockHost` (`view/lock/`) holds Quickshell's `WlSessionLock` with one
  `WlSessionLockSurface` per output, each showing `PasswordLockFace` over the wallpaper (Z89; no screen capture).
- **Unlock: only PAM in the view.** On PAM success the view sends `lock.release`; the core clears the state and
  the marker, then runs `loginctl unlock-session` so logind (and DMS) know. The view drops `WlSessionLock.locked`
  only after the core has answered (a lost core keeps the screen locked; see F7).
- **The core never unlocks by itself.** No timeout, no op other than `lock.release` from the view that holds the
  lock, and `lock.release` is refused unless the session is locked.

## 3. Behaviour
1. **Engage:** `WlSessionLock.locked = true` on the core's state; surfaces on every output, created only while
   locked (SURFACES §8). The `switch` cue plays (Z104). No Overdrive on the lock (Z57).
2. **Password:** typed into the password plane; the secret stays in the auth host (never in a property the face
   reads; the face gets only the mask length). Enter submits to PAM (`PamContext`, service `serpantinum`, falling
   back to `login` if the file is missing, Z125). Failure: `attempts += 1`, `rejectionMs` 0 → 320 (shake; none at
   reduced motion), `> AUTH FAILED · n`, field cleared. No attempt limit (Z88).
3. **Band:** media (the host's MPRIS controls), battery, power with hold-to-confirm (the host's power actions).
4. **Fingerprint (when pam_fprintd is installed):** a second `PamContext` limited to fingerprint, started on
   lock, as DMS does; a match unlocks the same way. Absent module: nothing shown.
5. **New output while locked:** gets a surface (Quickshell makes one per screen). An output removed: its surface
   goes.
6. **Sleep:** DMS locks before sleep through the command; resume finds the lock up.

## 4. Restarts
- **View crash while locked:** Hyprland keeps the screen covered. The core respawns the view (Z159); the new view
  reads the core's `lock` state (or the marker, if the core is gone) on start and takes the lock over at once
  (`allow_session_lock_restore`). Target: covered within 2 s of the respawn.
- **Core restart while locked:** the marker survives; the new core loads `locked` from it; the view keeps its lock.
- **DMS restart while locked:** irrelevant to the lock surface (ours). OPEN 19 dissolves: the core's `lock` state
  is how the supervisor knows the screen is locked.
- **Live restart (`tools/live-restart`) while locked:** refused by the tool while the marker says locked.

## 5. Failure table (each row is a test; N = nested Hyprland with fake PAM, U = unit/offscreen)

| # | Fault | Must happen | Test |
|---|---|---|---|
| F1 | Wrong password | stays locked; shake (or none when reduced); `AUTH FAILED · n`; field cleared | N: pam_deny |
| F2 | Right password | unlocks; core state cleared; `loginctl unlock-session` run | N: pam_permit |
| F3 | View killed while locked | screen stays covered; respawned view re-locks; then F2 works | N: kill qs |
| F4 | Core killed while locked | screen stays locked; new core reads the marker; F2 works | N |
| F5 | PAM service file missing | falls back to `login`; never unlocks on the error | U: PamContext stub |
| F6 | PAM errors (not a refusal) | treated as a refusal; stays locked | N: broken pam dir |
| F7 | Core unreachable at unlock | stays locked; says so; retries | N: stop core, then permit |
| F8 | Sky / face fails to load | plain card with the field; still locked | U: broken face |
| F9 | `lock.release` from another client / when unlocked | refused | U: core |
| F10 | Two lock requests | one lock | N |
| F11 | Output added / removed while locked | every output covered | N: headless output |
| F12 | Password never in logs, files or properties the face can read | none | U: grep logs, property scan |
| F13 | Reduced motion | no shake; error state still shown | U |
| F14 | DMS command unset (switch reverted) | DMS's own lock works again | N |

**Status (24 Nov):** built behind `FART_LOCK=own`. `tools/lock_nested_check.py` (a private nested Hyprland, a core
that spawns the view, the fake PAM) passes engage, F1, F2, F3, F4, F7, F10, F11; `tests/test_core_lock.py` F4, F9, F10,
F12 (the release side); `tests/test_lock_screen.py` F8, F12 (the face never holds the secret), F13 (the face's
reduced state). Still to do: F5/F6 (PAM file missing, PAM erroring) in the nested check, F14 (the switch undone), the
power hold's action (the owner's pick), the `switch` cue on lock and unlock.

## 6. Switch-over (owner present, Z109)
1. Everything in §5 green in nested Hyprland with fake PAM.
2. Owner at the machine: set DMS's `customPowerActionLock` (the core writes it byte-exact, as `dms_bar` does
   its setting), `tools/live-restart`, then lock with the session card and unlock with the real password; then
   idle lock (shortened only for the trial), then `loginctl lock-session`.
3. Undo: clear the setting (DMS's own lock is back at once). Kept on a branch until the owner says it is good.
