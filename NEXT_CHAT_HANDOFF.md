# Handoff for the next chat (written 11 November 2026, ~12:40)

Read this first, then `HANDOFF.md` (top entry). Continue from the files, not from memory.

## Who you are, how the user works
- You're Claude A, working on two projects: **FART** (`~/.local/share/fart/next-m6`, branch `m6-design`; the user's everyday copy is `~/.local/share/fart/next`, branch `main`, command `fart`) and **ZÆTHERION** (`~/src/zaetherion-shell`, branch `s0-seed`).
- Read FART's `CLAUDE.md` and `AGENTS.md` (the Overdrive mandate, the safety rules, "poop", no push).
- **Short milestone updates in plain words; questions saved for the end.** The user is enthusiastic and visual: show what changed (screenshots of the bar via `grim -g "0,0 1920x40"` worked well).
- **"poop"** means the screen is free: run the on-screen measurements at once.
- **Gosling rule (essential):** on "I Drive", *or whenever the user makes a Ryan Gosling / Drive / Barbie-Ken meme or pun*, make one back, then carry on.
- **No frame-rate cap** in Overdrive (the user sees 144 vs 120 Hz): cut the cost of each frame instead.
- **Shells aren't just UIs:** before saying a shell is off, find every path that restarts it, and re-check after waiting. (Seen again today: `serpantinumd stop` leaves `serpantinum-audio daemon` running.)
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.
- **Resuming:** `claude -c` opens the wrong chat if the folder differs; tell the user `claude --resume` and pick by name. `!` commands can't take a sudo password: give root commands for the user to run in their own terminal.

## The user's desktop right now
- **The user now logs into the ZÆTHERION session** (SDDM entry `/usr/share/wayland-sessions/zaetherion.desktop`, installed by the user). It runs Hyprland with `~/.config/hypr/zaetherion.lua`, which starts cliphist watchers and `tools/session-start` → ZÆTHERION's core (`core/fartd.py` from this repo) → `dms run` with **DMS's own UI** (ZÆTHERION's resident UI doesn't exist until S3). Logs: `$XDG_RUNTIME_DIR/zaetherion/session.log` and `dms.log`.
  - **Login and logout tested 11 Nov:** clean login, no config errors; after logout + login none of the old processes survived and exactly one fresh set ran.
  - Super+\` in this session opens **ZÆTHERION's** FART copy, not the everyday `fart`. FART-next's core isn't running in this session.
  - ZÆTHERION's core reports `host serpantinum` (seeded default); fix with the S2 adapters.
- **The plain "Hyprland" session** (`~/.config/hypr/hyprland.lua`) is Serpantinum's, unchanged except `config/keybinds.lua`, which currently holds the **DMS** keybinds. Serpantinum is disabled (`bin/serpantinum{,d}` → `*.off`), and nothing autostarts DMS there, so that session would come up with no shell. Restore steps for Serpantinum: rename the two back, copy `config/keybinds.lua.serpantinum-2026-11-10` over `keybinds.lua`, `hyprctl reload`, `serpantinumd start`. Backups in `~/backups/serpantinum-2026-11-10*.tar.zst`.
- **DMS bar (user-tuned with Claude, 11 Nov):** `~/.config/dms/settings.json` (backup `settings.json.bak-2026-11-11`). Left: workspaces with `workspacePaddingCount` 7 (chosen to balance the sides). Centre: music (+ clock). Right: notifications, battery, control centre (Wi-Fi/volume), **power button**. CPU pill added then disabled. Sides within ~15 px. DMS has no "equal sides" option.
  - The user is also changing DMS settings themselves (fonts changed mid-session); always re-read settings.json before writing it.
- **Modern Clock** DMS plugin (`~/.config/dms/plugins/modernClock`, GPL-3.0; Anurati font is personal-use only, Poppins OFL) is the user's favourite thing. It's in PARITY.md as a ZÆTHERION widget (S10). Never commit Anurati.
- **DMS clipboard history stays off**; cliphist records in the ZÆTHERION session (user's choice). Never read clipboard contents.
- DMS's lock screen is still untested.

## FART state (unchanged today)
- `main` at `850a995`; `m6-design` ahead by notes only (`12d2914`, `6d82e18`, `dedb464`, `c13d874`, `af9d741`), to reach `main` with the next tested merge. Tag `FARG` = `c13d874`.
- Still to fix (Overdrive, on screen): flights 162 % CPU, the Overlay keeping ~96 MiB after release, AMD 70 % with the heavy layer on. AMD optimisation task not started.

## ZÆTHERION state (branch `s0-seed`, last commit: this handoff)
- **S0 done:** full unit suite 673 OK; quiet baseline Serpantinum + FART-next = **768 MiB PSS** (533 with FART's panel reaped) → the total budget in BUDGETS.md.
- **S1 (approved by the user) — done so far:** Hyprland require list (`~/.config/hypr/zaetherion.lua` + `~/.config/hypr/zaetherion/`, copies in `session/hypr/`), `tools/session-start` (interim starter with DMS restart backoff and stop-on-logout), SDDM entry (template `session/zaetherion.desktop` with `@HOME@`), installed and login/logout tested.
- **S1 still owed:**
  - ~~nested Hyprland check (Z109)~~ **done 11 Nov afternoon:** viable, `tools/nested_hypr.py selftest` 9/9 (docs/NESTED.md);
  - **F1**: `fartd` supervising `dms run -c` and the panel (state machine, restart backoff, DMS-dies case, named clients), replacing `session-start`'s loop. The roadmap marks F1 as a Fable design session; suggest the user raise effort / switch model for it (CLAUDE.md effort rules);
  - `zaetherion start/stop/restart/status` exists from the seed; check it fits the session;
  - `session-start` logs DMS's whole output into `session.log` (noisy); trim when F1 lands.
- **New design inputs from the user (11 Nov), already in docs:**
  - Island modules they actually use: power, network, notifications, battery, active media (SURFACES.md §1). Power button and a notification glyph are missing from the wing lists: add at S3.
  - **Memory on demand:** a memory-pressure island expansion (top 3 processes by PSS, pinnable). Threshold etc. is **OPEN 14** (S3).
  - They love the "dynamic island" idea and DMS's customisability.
- `docs/ROADMAP.md` is the user's file. Leave it alone.
