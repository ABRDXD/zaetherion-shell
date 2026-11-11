# F1 recon: how `dms run` lives and dies (11 November 2026)

Input for the F1 supervisor design. Measured with DMS 2.1.0 (apiVersion 38) inside the nested test Hyprland (`tools/nested_hypr.py`, docs/NESTED.md), with an empty UI (`dms run -c <dir>`, `shell.qml` = `ShellRoot {}`) and private `XDG_*_HOME` and `XDG_RUNTIME_DIR` folders, so the owner's running DMS was never touched. Each row ran once; timings are single samples.

## Start
- `$XDG_RUNTIME_DIR/dms-<pid>.sock` exists **≈ 0.05 s** after spawn; the UI `qs -p <dir>` is running **≈ 0.06 s** after spawn.
- `qs` is a **direct child of `dms`** (its parent pid is `dms`), but it is forked from a non-main thread, so `/proc/<dms>/task/<dms>/children` does not list it. Find it by scanning parent pids.
- Per instance DMS writes `dms-<pid>.{pid,session,sock,start}` and a `dms-migrate-<uid>-<wayland display>.lock` in the runtime folder.

## Death and signals

| Event | What DMS does | UI `qs` | Left behind |
|---|---|---|---|
| UI `qs` killed (SIGKILL) | **exits too, code 137** (mirrors the child) | gone, **not respawned** | `dms-<pid>.{pid,session,start}` |
| UI `qs` stopped (SIGTERM) | **exits too, code 143** | gone, not respawned | the socket as well |
| `dms` SIGTERM | exits 0 in **0.57 s** | exits with it | nothing |
| `dms` SIGINT | exits 0 in 0.57 s | exits with it | nothing |
| `dms` **SIGHUP** | dies by the signal at once | **orphaned, keeps running** | all four files incl. socket |
| `dms` SIGKILL | dies | **orphaned, keeps running** | all four files incl. socket |

So:
- DMS does **not** restart its UI. A UI crash takes DMS down with it, so the supervisor sees one event (dms exited) for either crash, and must read the exit code / which process died first if it wants to tell them apart (Z127 needs "what crashed").
- **Only TERM/INT shut the pair down cleanly.** HUP and KILL orphan the UI. A logout path that HUPs dms (or a supervisor that escalates to KILL) must also stop the `qs` child itself, or a second UI survives next to the restarted one.
- Stale `dms-<pid>.*` files are left after unclean exits; anything that finds DMS by globbing the runtime folder must check the pid is alive.

## Shared state between DMS instances (found the hard way)
- **`$XDG_RUNTIME_DIR/dms.path`** holds the UI config path of the *most recently started* DMS, and DMS **deletes it on exit**. `dms ipc call …` (every DMS keybind) uses it to find the UI. A second DMS in the same runtime folder took the owner's keybinds away from their bar until the file was restored by hand.
  - Consequences for F1: during a restart there is a window with no `dms.path` (keybinds fail silently); a stray second `dms` steals the keybinds; and when the newer one exits, the file is gone even though the older one still runs.
  - Tests must run DMS with a private `XDG_RUNTIME_DIR` (symlink `hypr/` into it and give `WAYLAND_DISPLAY` as an absolute path).
- `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`: DMS writes settings, the clipboard db and the wellbeing db there (DMS_OBSERVED.md). Two DMS instances share them unless separated.

## Today's session (interim, for comparison)
- `tools/session-start` (a shell loop) starts the core, then `dms run` with DMS's own UI; restarts dms with backoff 1→30 s when no `dms` process exists; stops both when the Hyprland socket disappears, and traps TERM/INT/HUP.
- `dms restart` (the owner's Super+R) replaces the dms process with a new one that is **not** the starter's child, which is why the loop looks for any `dms` by name. A supervisor that tracks only its own child will think DMS died on every Super+R.
- The UI `qs` has children of its own (a `tee` into the log, and polkit helpers such as `pkexec` waiting for an answer). Logout cleanup must cover the whole tree, not just `dms` and `qs`.

## Not measured
- `dms restart` and `dms kill` (they act on whichever DMS `dms.path`/pid files point at, so they were not run near the owner's instance).
- What `dms run --session` changes.
- Behaviour when the compositor goes away first (logout order).
