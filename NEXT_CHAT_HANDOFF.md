# Handoff for the next chat (written 11 November 2026, morning)

Read this first, then `HANDOFF.md` (top entry) and `docs/DMS_OBSERVED.md`. Continue from the files, not from memory.

## Who you are, how the user works
- You're Claude A, working on two projects: **FART** (`~/.local/share/fart/next-m6`, branch `m6-design`; the user's everyday copy is `~/.local/share/fart/next`, branch `main`, command `fart`) and **ZÆTHERION** (`~/src/zaetherion-shell`, branch `s0-seed`).
- Read FART's `CLAUDE.md` and `AGENTS.md` (the Overdrive mandate, the safety rules, "poop", no push).
- **Short milestone updates in plain words; questions saved for the end.**
- **"poop"** means the screen is free: run the on-screen measurements at once.
- **Gosling rule (essential):** on "I Drive", *or whenever the user makes a Ryan Gosling / Drive / Barbie-Ken meme or pun*, make one back, then carry on.
- **No frame-rate cap** in Overdrive (the user sees 144 vs 120 Hz): cut the cost of each frame instead.
- **Shells aren't just UIs:** before saying a shell is off, find every path that restarts it, and re-check after waiting.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## The user's desktop right now (important)
- **DMS is running with its full UI** (`dms run`, started detached with `setsid`; logs in the old session's scratchpad). The user is trying it out and likes how customisable it is.
- **Serpantinum is disabled:** `~/.local/share/serpantinum/bin/serpantinum` and `serpantinumd` are renamed to `*.off`. That breaks every launcher (`~/.local/bin` and `/usr/local/bin` are symlinks to them). Its Hyprland autostart (`~/.config/hypr/config/autostart.lua`) is untouched and fails quietly.
  - **To restore:** rename both back, copy `~/.config/hypr/config/keybinds.lua.serpantinum-2026-11-10` over `keybinds.lua`, run `hyprctl reload`, then `serpantinumd start`. Stop DMS with `pkill -x dms`.
  - **Backups:** `~/backups/serpantinum-2026-11-10.tar.zst` (full: program, config, state, caches, `~/.config/hypr`, `/usr/local/bin` helpers, `/etc/pam.d/serpantinum`) and `~/backups/serpantinum-state-2026-11-10-b.tar.zst`.
- **Keybinds are retargeted to DMS** in `~/.config/hypr/config/keybinds.lua`: `dms ipc call …` for the launcher (spotlight), control centre, dash tabs (overview, media, wallpaper), notifications, settings, power menu, lock, audio and brightness (steps of 5); `dms screenshot` (piped to `satty -f -` for the edit keys); `dms restart` for reload. Workspaces use native Lua (`hl.dsp.focus({ workspace = ws })`, `hl.dsp.window.move({ workspace = ws })`), because `hyprctl dispatch workspace N` fails under this Hyprland's Lua config. Recording uses wf-recorder, toggled, saving to `~/Videos`. The clipboard key uses cliphist directly. The user confirmed workspaces were broken, and they were fixed; the other keys haven't been confirmed by the user yet.
- **DMS clipboard history is off** (`clipboard.setConfig {"disabled": true}`, saved in `~/.config/dms/clsettings.json`). It still creates `~/.cache/dms/clipboard/db` at start. Never read clipboard contents.
- **DMS's lock screen is untested** (PAM `dankshell`, then `login`).
- FART (`fart`) is running. It didn't come back after the reboot by itself; it was started with `fart start`.

## FART state
- `main` is at `850a995`. `m6-design` is ahead by notes only: `12d2914`, `6d82e18`, `dedb464`, `c13d874` (the §9 on-screen rows), `af9d741` (the Gosling rule in CLAUDE.md). These reach `main` with the next tested merge (full suite on the hidden desktop first, then `fart stop; fart start`).
- **Tag `FARG`** = `c13d874`: the ZÆTHERION seed.
- **On-screen results (plugged in, `docs/OVERDRIVE.md` §9):** orbit 49 → 144 fps, Devices 72 → 144, Performance CPU 53 → 27 %, Home AMD 69 → 58 %.
  - **Still to fix:** flights 162 % CPU, the Overlay keeping ~96 MiB after release, AMD 70 % with the heavy layer on.
  - None of these show in Silent. The AMD optimisation task (gpu_probe `--off` per room on the hidden desktop, cache or lower-resolution strata) wasn't started.

## ZÆTHERION state (branch `s0-seed`, last commit `e6a8cbe`)
- **S0, done:**
  - seeded from FARG (code at the root, FART docs in `docs/fart/`, `licenses/FART-NOTICE`, NOTICE updated);
  - `./zaetherion` launcher (own runtime, state and cache folders; still says fart-next in its help text);
  - OPEN 13 decided: the heavy layer stays on NVIDIA, Overdrive only; BUDGETS.md changed;
  - OPEN 2: tesseract, zbarimg and satty are installed;
  - DMS first runs: scrubbed fixture `tests/fixtures/dms/s0-v2.1.0.json`, `tools/dms_scrub.py`, `tools/dms_replay.py`, `tests/test_dms_fixtures.py` (10 OK);
  - real method names; first memory figures.
- **S0, owed:** the quiet RSS/PSS baseline of **Serpantinum + FART** at rest (needs Serpantinum back for a few minutes), then fix the total in BUDGETS.md. The full test suite hasn't run in the ZÆTHERION tree yet (only `test_orbit` and the new tests).
- **Key DMS facts:**
  - apiVersion 38 (v2.1.0), not 40;
  - weather is UI-side (Open-Meteo through `dms dl`), lyrics is `lyrics.get`, location only with the `location` capability (absent here);
  - DMS opens raw keyboard input (evdev);
  - wellbeing records app usage on its own;
  - the backend uses ~50 MiB PSS fresh but ~400 after a wallpaper theme build;
  - DMS's UI uses ~420–530 MiB PSS (ZÆTHERION replaces the UI).
- **Waiting on the user (asked, not answered yet):** approval for **S1**: (1) the SDDM session entry in `/usr/share/wayland-sessions/` (root, sudo), and (2) ZÆTHERION's own Hyprland require list (keybinds copy, `allow_session_lock_restore`, autostart of fartd → `dms run -c` → resident UI). Serpantinum's session must stay unchanged. Don't start S1 without that OK.
- `docs/ROADMAP.md` is the user's uncommitted local file. Leave it alone.
