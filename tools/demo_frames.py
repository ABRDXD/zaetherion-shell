#!/usr/bin/env python3
"""Frame sequences of the canvas and the idle motion, for review (docs/M6-SPLIT.md), offscreen.

    python3 tools/demo_frames.py OUT_DIR [--source TREE] [--preset Mocha] [--slow 4] [--gl] [--only travel,orbit]

Renders the fixture view in a window and grabs the frame at a steady cadence while it moves. Moves (a
room switch through the orbit, the orbit opening and closing, and any prototype call) run `--slow` times slower
(Motion.timeScale), so the grabs sample them finely; idle runs at real time over a few seconds. Writes
OUT_DIR/<sequence>/NNN.png, OUT_DIR/<sequence>.webp (played back at real speed) and OUT_DIR/sheet-<sequence>.png
(a contact sheet with each frame's time). For looking at, never for timing: use
tools/measure/desktop_canvas.py and desktop_idle.py for cost. Nothing is actuated; fixture data only.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from shots import preset_colors  # noqa: E402
from smoke import ROOT, prepare, run_view  # noqa: E402

# Each sequence: the room it starts in (settled first), the actions at times in ms after the first grab
# (a room id travels there; "orbit" / "back" open the orbit / leave it; {"call": name, "args": [...]} calls a Shell
# function a prototype adds), how many frames, the grab cadence in ms, and whether moves are slowed.
SEQUENCES = {
    "travel": dict(start="home", actions=[[150, "performance"]], frames=36, every=70, slowed=True),
    "diagonal": dict(start="home", actions=[[150, "notifications"]], frames=36, every=70, slowed=True),
    "orbit": dict(start="tasks", actions=[[150, "orbit"], [2000, "back"]], frames=56, every=70, slowed=True),
    "idle": dict(start="home", actions=[], frames=24, every=250, slowed=False),
}

HARNESS = '''import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui as Fart
Scope {
    id: scope
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    property var plan: %(plan)s
    property string out: %(out)s
    property real slow: %(slow)s
    property int seq: -1
    property int frame: 0
    property int fired: 0   // actions already run in this sequence (they are in time order)
    property double t0: 0
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
    }
    FloatingWindow {
        implicitWidth: %(width)d; implicitHeight: %(height)d; visible: true
        color: "#40464d" // a neutral stand-in for the wallpaper behind the translucent panel
        Item {
            id: canvas
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Fart.Design.background; opacity: Fart.Design.panelOpacity }
            Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
        }
    }
    function act(step) {
        if (step === "orbit") { if (!dashboard.orbitOpen) dashboard.toggleOrbit(); }
        else if (step === "back") { if (dashboard.orbitOpen) dashboard.escapeKey(); }
        else if (typeof step === "string") dashboard.navigate(step);
        else if (typeof dashboard[step.call] === "function") dashboard[step.call](...(step.args || []));
        else console.log("FART_DEMO_MISSING", step.call);
    }
    function nextSequence() {
        seq++;
        if (seq >= plan.length) {
            console.log("FART_DEMO_DONE");
            quit.start();  // after the last save has reached the disk
            return;
        }
        Motion.timeScale = 1;
        if (dashboard.orbitOpen) dashboard.toggleOrbit();
        act(plan[seq].start);
        settle.restart();
    }
    Timer { interval: 2500; running: true; onTriggered: scope.nextSequence() }
    Timer { id: quit; interval: 800; onTriggered: Qt.quit() }
    Timer {
        id: settle
        interval: 1800
        onTriggered: {
            const s = scope.plan[scope.seq];
            Motion.timeScale = s.slowed ? scope.slow : 1;
            scope.frame = 0;
            scope.fired = 0;
            scope.t0 = Date.now();
            scope.grab();
        }
    }
    Timer { id: cadence; interval: scope.plan[scope.seq]?.every ?? 100; onTriggered: scope.grab() }
    function grab() {
        const s = plan[seq];
        const t = Date.now() - t0;
        while (fired < s.actions.length && t >= s.actions[fired][0])
            act(s.actions[fired++][1]);
        canvas.grabToImage(result => {
            result.saveToFile(out + "/" + s.name + "/" + String(frame).padStart(3, "0") + ".png");
            console.log("FART_DEMO_FRAME", s.name, frame, t, Motion.active, JSON.stringify(Motion.activeNames));
            frame++;
            if (frame >= s.frames) nextSequence();
            else cadence.restart();
        });
    }
}
'''


def build_outputs(out: Path, plan: list, frames: dict, slow: float):
    """Animated WebP at real speed and a labelled contact sheet per sequence (Pillow, if present)."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Pillow is not installed: frames only")
        return
    for s in plan:
        name = s["name"]
        times = frames.get(name, [])
        paths = sorted((out / name).glob("*.png"))
        if not paths:
            continue
        images = []
        for path in paths:
            try:
                images.append(Image.open(path).convert("RGB"))
            except OSError:
                print(f"skipped an unreadable frame: {path.name} in {name}")
        if not images:
            continue
        factor = slow if s["slowed"] else 1
        durations = [max(20, round((times[i + 1] - times[i]) / factor)) if i + 1 < len(times) else 600 for i in range(len(images))]
        images[0].save(out / f"{name}.webp", save_all=True, append_images=images[1:], duration=durations, loop=0, quality=80)
        thumb_w = 280
        thumb_h = round(images[0].height * thumb_w / images[0].width)
        columns = 6
        rows = (len(images) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * (thumb_w + 6) + 6, rows * (thumb_h + 22) + 6), "#1b1b22")
        draw = ImageDraw.Draw(sheet)
        for i, image in enumerate(images):
            x = 6 + (i % columns) * (thumb_w + 6)
            y = 6 + (i // columns) * (thumb_h + 22)
            sheet.paste(image.resize((thumb_w, thumb_h)), (x, y))
            real = round(times[i] / factor) if i < len(times) else 0
            draw.text((x + 2, y + thumb_h + 4), f"{i:02d}  t={real} ms", fill="#c8c8d0")
        sheet.save(out / f"sheet-{name}.png")


def main():
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    parser.add_argument("out", type=Path)
    parser.add_argument("--source", type=Path, default=ROOT, help="checkout to render")
    parser.add_argument("--preset", default="Mocha")
    parser.add_argument("--slow", type=float, default=4, help="Motion.timeScale for moves")
    parser.add_argument("--size", default="1120x760")
    parser.add_argument("--only", help="comma-separated sequences")
    parser.add_argument("--extra", help='more sequences as JSON: {"pan": {"start": "home", "actions": [[150, {"call": "pan", "args": [400, 0]}]], ...}}')
    parser.add_argument("--gl", action="store_true", help="OpenGL offscreen instead of the software renderer (draws fillItem)")
    args = parser.parse_args()
    sequences = dict(SEQUENCES, **(json.loads(args.extra) if args.extra else {}))
    names = [n for n in (args.only.split(",") if args.only else sequences)]
    plan = [dict(name=n, **sequences[n]) for n in names]
    out = args.out.resolve()
    for s in plan:
        (out / s["name"]).mkdir(parents=True, exist_ok=True)
        for old in (out / s["name"]).glob("*.png"):
            old.unlink()
    width, height = (int(n) for n in args.size.lower().split("x"))
    with tempfile.TemporaryDirectory(prefix="fart-next-demo-") as tmp:
        base = Path(tmp)
        text = HARNESS % {"plan": json.dumps(plan), "out": json.dumps(str(out)), "slow": args.slow,
                          "colors": json.dumps(preset_colors(args.preset)), "width": width, "height": height}
        env, _, view_log = prepare(base, text, source=args.source.resolve())
        if args.gl:
            env.pop("QT_QUICK_BACKEND", None)
            env["QSG_RHI_BACKEND"] = "opengl"
        core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(Path(env["FART_RUNTIME_DIR"]) / "core.sock", timeout=300)
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ""
    frames, activity = {}, {}
    for line in output.splitlines():
        if "FART_DEMO_FRAME " in line:
            parts = line.split("FART_DEMO_FRAME ")[1].split(" ", 4)
            frames.setdefault(parts[0], []).append(int(parts[2]))
            activity.setdefault(parts[0], []).append(json.loads(parts[4]))
    missing = sorted({line.split()[-1] for line in output.splitlines() if "FART_DEMO_MISSING" in line})
    for line in output.splitlines():
        if any(s in line for s in ("ReferenceError", "TypeError")):
            print(line)
    build_outputs(out, plan, frames, args.slow)
    # What was still moving in the last frame of each sequence (idle loops show up here by name).
    summary = {n: dict(frames=len(frames.get(n, [])), last_active=activity.get(n, [[]])[-1]) for n in names}
    (out / "demo.json").write_text(json.dumps(dict(source=str(args.source.resolve()).replace(str(Path.home()), "~", 1),
                                                   slow=args.slow, gl=args.gl, missing_calls=missing, sequences=summary), indent=2) + "\n")
    print(json.dumps(summary))
    print(f"{sum(len(v) for v in frames.values())} frames in {out}" + (f"; missing calls: {missing}" if missing else ""))
    return 0 if exited and all(len(frames.get(n, [])) == sequences[n]["frames"] for n in names) else 1


if __name__ == "__main__":
    raise SystemExit(main())
