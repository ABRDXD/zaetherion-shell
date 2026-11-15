# UI inspiration in use — for Astra (and every agent), from Claude A

15 November 2026. Read with `docs/UI_CREATIVE_HANDOFF.md`. The owner's taste, learned the hard way today:

## 1. The room is the scene (not a dashboard with a picture)

- Fluid Timers went list → ring dial → both **rejected as bland** ("very very bland"). Five canvas mock-ups later the
  owner picked a **scene**: you stand on a planet, a black hole crosses its sky over a stretch, the time still to go
  spirals into it and one pulsing light marks now (Z203, `view/fluid/TimersSky.qml`). "Majestic."
- So: mock **2–3 whole-room scenes** first (the owner picks; combinations are common: "B + C"), then build.
  A widget-sized idea inside a card layout is still bland.
- Owner picks today: **Fluid Tasks = "star atlas"** (each list a constellation, sooner = nearer the centre, done =
  hollow, overdue = warm). **Fluid Performance = "the star"** (CPU temperature is its colour along the spectral classes,
  memory its size, load its glow, the GPU a companion; in Overdrive one shell per core and the heaviest processes as
  planets). **Claude A is building both now**, so please don't start Performance (the prompt in
  `docs/NEXT_CHAT_PROMPT.md` predates this).

## 2. Mood and rules the owner set today

- **Astrophysics everywhere**, at the approved scale: black hole = overview, planetary systems = rooms/workspaces,
  planets = apps/windows, moons = contextual actions.
- **Cold, mature, vast**: "a large cold universe … witnessing a speck of it", "as mature as possible". Edge-on views,
  scenes that run past the surface's edges, silhouettes with crescents, slow smooth easing.
- **Symmetry is essential.** **Never average or merely acceptable**: always experimental.
- Island faces leave within **1 s** (Z200; critical waits; hover or a reply draft holds a notice).

## 3. Web UI libraries as inspiration (the owner asked for "as much inspo as possible")

They can't be installed in QML; their **ideas** are ported, each live and tested:

| Library | What it became | Where |
|---|---|---|
| NumberFlow | Rolling digits: changed digits roll the way the number moves | `view/ui/RollingDigits.qml` (Timers clock, battery %, OSD level, workspace readout) |
| Sonner | Stacked island notices: waiting card edges, fan-out on hover, sideways flick | `IslandExpansion.qml` notice card, `IslandSurface.waitingNotices` |
| Vaul | Rubber-band drag: pull the island to open FART, drag the launcher up to fold | `view/shell/Rubber.js`, `IslandSurface.pullBy/endPull/endFold` |
| cmdk | Launcher pages: Enter on a bare FART verb opens its choices as moons | `Commands.page`, op `launcher.page`, `LauncherFace.page` |
| Radix / Base UI | Keyboard: ring for the keyboard only, Enter presses, arrows rove a row, ↑/↓ a list | `view/fluid/FluidKeys.js`, `FluidButton`, `FluidActionRow` |

Use them in your rooms: `RollingDigits` for any changing number, `FluidButton` / `FluidActionRow` (keyboard comes free),
`Rubber.js` for any drag that should resist. Owner's later wish: pages for UI items too (rooms, settings), not only
verbs.

## 4. Shared pieces worth reusing

`view/ui/ColdStar.qml`, `ColdPlanet.qml` (cold tokens in `Design`), `view/fluid/TimersSky.qml` (planet horizon, black
hole, breathing light via a `Pulse` cue), `PresentationHost` (now guards its deferred steps; see HANDOFF).
