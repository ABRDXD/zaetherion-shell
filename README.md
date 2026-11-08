# ZÆTHERION

**Status: design complete, no code yet.** This repository holds the full plan for ZÆTHERION, a complete Wayland desktop shell for Hyprland built with Quickshell. The shell code is seeded later (milestone S0) from its predecessor, FART-next, once FART-next's Overdrive work reaches about M12.

| | |
|---|---|
| Name | ZÆTHERION |
| Command | `zaetherion` |
| Repository | `zaetherion-shell` |
| Internal codename | FART |
| Licence | GPL-3.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)) |

## What it is

A daily-driver shell that looks like nothing else and costs nothing when it has nothing to do.

- **The island.** The bar is a single dynamic island: a navy trapezoid notch hugging the top of the screen. At rest it shows the time, what's playing, battery and a waveform. Hover widens it into wings with status and tray. Click unfolds the full control panel out of it. Notifications, volume, timers and recording grow out of it and shrink back.
- **Montage × Cosmos.** The look takes principles, never assets, from Persona (angled planes, cut-ins, bold slanted type), NieR:Automata (a terse machine voice, log-line feedback) and astrophysics. The wallpaper, lock screen and clock show the real sky at the user's location: stars, Moon phase, planets, Sun altitude.
- **Keyboard first.** One command line opens apps, files, emoji, clipboard and FART's verbs (`tim 25`, `vol 40`, `overdrive 20m`), and it grows out of the island.
- **Silent and Overdrive.** By default everything is static and nearly free. Overdrive is a timed lease that animates the sky, the island (kinetic lyrics) and transitions, and releases its memory when it ends.
- **No backend written from scratch.** System integration comes from the DMS backend (Dux Modular Shell, MIT) and Quickshell's built-in services. The project's own daemon, `fartd`, keeps only FART's state: timers, tasks, sessions, leases.

## Documents

| Document | Contents |
|---|---|
| [docs/VISION.md](docs/VISION.md) | What and why, the design language |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Every decision (Z1–Z142), plus the inherited FART decisions that change |
| [docs/SURFACES.md](docs/SURFACES.md) | Every on-screen surface, specified |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Processes, supervision, IPC, state, adapters, backend map |
| [docs/CONTRACT.md](docs/CONTRACT.md) | New adapter-contract domains |
| [docs/MILESTONES.md](docs/MILESTONES.md) | S0–S12 with acceptance criteria |
| [docs/BUDGETS.md](docs/BUDGETS.md) | Memory, CPU and frame budgets |
| [docs/RISKS.md](docs/RISKS.md) | Risks and mitigations |
| [docs/PARITY.md](docs/PARITY.md) | Every feature of the shell it replaces, marked kept, replaced or dropped |
| [docs/DMS_BACKEND.md](docs/DMS_BACKEND.md) | What DMS provides and how ZÆTHERION uses it |
| [docs/OPEN.md](docs/OPEN.md) | The few items still open, each with the test that settles it |
| [docs/ZAETHERION-overview.pdf](docs/ZAETHERION-overview.pdf) | A plain-language overview for non-technical readers |
| [AGENTS.md](AGENTS.md), [HANDOFF.md](HANDOFF.md) | Working rules and status |
