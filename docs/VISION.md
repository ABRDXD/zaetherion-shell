# Vision

## Why

FART started as a dynamic-island-style control centre that ran beside a host shell. The host owned everything else: the bar, launcher, notifications, OSD, wallpaper, lock, idle, polkit, screenshots, settings. Each of those had its own look and its own costs. ZÆTHERION is FART grown into the whole shell, so every surface speaks one design language and follows one rule about cost.

The goal: **the most distinctive daily driver possible, which still costs nothing when it has nothing to do.**

## Principles

1. **One exterior: the island.** The only permanent thing on screen is a 36 px navy trapezoid notch (Z17, Z64–Z66). Everything else grows out of it and shrinks back: the panel, the launcher, notifications, OSD, polkit and debriefs.
2. **No system backend of our own.** The DMS backend and Quickshell's built-in services do the system work. `fartd` keeps only FART's own state (Z8, Z10).
3. **Silent by default, Overdrive by lease.** Silent is static, with event-driven updates and zero idle frames. Overdrive is a timed, guarded lease that animates the sky, the island and transitions, then gives its memory back (D3/D4, Z57, Z119–Z122).
4. **Destroy, don't hide.** Anything not visible is unloaded: widgets whenever a window is on the workspace (Z85), the launcher after it closes (Z138), the panel after a reap delay (Z142).
5. **Keyboard first, mouse equal.** The command line, hjkl and arrows everywhere, and island keyboard focus (Z115).
6. **Measure before claiming.** Every surface has a measured budget (Z141).
7. **Nothing is assumed.** Each behaviour is a recorded decision ([DECISIONS.md](DECISIONS.md)) or a listed open item ([OPEN.md](OPEN.md)).

## Design language: Montage × Cosmos

| Influence | Principle taken | Where it shows |
|---|---|---|
| Persona | Angled planes (−12° and 78°), bold slanted display type, cut-ins for events, three colour roles (paper, ink, signal) | Launcher rows, the session card, the room index, island expansions |
| NieR:Automata | A diegetic machine voice: terse uppercase log lines (`> WIFI · ONLINE`), type-on text, brief scan/glitch on transitions capped at 3 per second. It can be switched off (Z53). | Boot, launcher results, lock failures, OFFLINE states |
| Astrophysics | The real sky at the user's location: a star chart by night and a gradient by Sun altitude by day. Orbits as motion, lensing as a transition. | Wallpaper (sky mode and image cuts), the lock title card, Home, widgets, Overdrive |

**Originality rule (Z61):** principles only. No names, logos, fonts, art, sound or copied layouts from those games.

**Type:** Inter Display for headlines and the clock; JetBrains Mono for the system voice and readouts (Z52).

**Colour:** the island uses a theme-derived navy, recalling the laptop's "Performance Blue" chassis (Z65). Everything else uses the active preset or Matugen palette behind a contrast guard (Z43).

**Motion:** four levels, OFF / MINIMAL / REDUCED / ALL. The default is ALL; Sessions force MINIMAL (Z116).

## What it is not

- Not a dock: the dock is dropped (Z46).
- Not a fork of the shell it replaces: Serpantinum's assets are only read at runtime, never copied.
- Not multi-monitor-first: the island and widgets go on the primary screen; the wallpaper and lock go on every screen (Z58).
