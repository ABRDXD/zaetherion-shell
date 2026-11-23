# Working on FART (next)

**Astra: read only `ASTRA_HANDOFF.md`, then start working. It replaces the reading list below.**

This is the FART-native successor repository, run as `fart-next` beside the archive until cutover (M7). The archive at `~/.local/share/fart/source` (branch `fart`) is the rollback copy and the live `fart` desktop: do not edit it, its `fart` launcher or the Serpantinum clock hook from here.

At the start of a resumed task:

1. Read HANDOFF.md and PROJECT_PLAN.md, then docs/LAYOUT.md and whatever the milestone touches.
2. Inspect `git status`, recent commits and the affected code before editing. Preserve unrelated local work.
3. Check fresh live state when it matters. The user actively changes bar configuration and playback; never restore an old snapshot over those choices.

Approval scope: M0–M7 are authorized. Ask the user before adding the Hyprland Super+` bind, installing or enabling the systemd user socket unit, tagging the archive `legacy-end4-final`, or switching `fart` and the clock hook at cutover. Overdrive (M8+) starts after the user reviews the cutover.

Do not actuate playback, volume, network, recording, power or destructive data actions merely to test a visual change. Use read-only inspection, fixtures and temporary UI surfaces. If the user is interacting during a live check, exclude the interrupted result rather than reporting it as passing or idle. Do not capture private clipboard or notification contents in deliverables.

Validate only what the change needs:
- Python tests: `python3 -m unittest discover -s tests -v`
- Offscreen rooms: `python3 tools/smoke.py`
- QML syntax: Qt 6 `qmllint --json -`, counting only `syntax*` diagnostics; `qs.*` modules resolve only at runtime.
- After integration changes: the fart-next log (`qs log -p ~/.local/share/fart/next/shell.qml`) and `hyprctl configerrors`.

Measure before claiming optimization. Report RSS and PSS separately, distinguish shared mappings (PSS drops when the archive's qs process shares the same libraries), and do not equate nominal vsync with sustained FPS. Pause invisible animation and pair subscription acquisition with release.

Keep components small by responsibility, names descriptive, UI state explicit and integrations isolated. Directory imports use `qs.*` modules, never relative paths. Shared geometry belongs in `view/ui/CutCornerFrame.qml`; FART-specific tokens in `view/ui/Design.qml`. Add no dependency without a concrete benefit. Record every derived file and third-party asset in NOTICE.

At a coherent checkpoint, update HANDOFF with changes, verification, remaining work and the exact next task. Keep source and documentation in Git. Do not add a remote or push without the user's instruction.
