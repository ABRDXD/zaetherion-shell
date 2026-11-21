"""Capture (S9, Z48, Z221): screenshots, OCR, QR, snip-to-search and screen recording, run by the core so the keys
work with the panel reaped. Published as `capture` (the island's recording timer reads it).

A shot freezes first: the whole layout is grabbed (`grim`) the moment it is asked for, the area is chosen after
(`slurp`, over the live screen until Astra's frozen overlay lands), and the picture is cut from the frozen grab, so
what you get is what was on screen when you pressed the key. Then one action: copy (always, and saved under
Pictures/Screenshots), edit (satty), text (tesseract, copied), qr (zbarimg, copied), lens (Google Lens in the
browser, the owner's pick of 20 November 2026). A cancelled selection does nothing. One shot at a time.

Recording is gpu-screen-recorder: the focused monitor or a chosen region, with the desktop's sound and/or the mic,
saved under Videos/Recordings; stopping sends SIGINT so the file is finished properly.
Every tool is called through `run`/`spawn`, so tests drive this with fakes and never touch the screen.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
from pathlib import Path
import signal
import time
from typing import Awaitable, Callable

from core.errors import bad_args

log = logging.getLogger("fart.capture")

SHOT_MODES = ("region", "window", "monitor", "full")
ACTIONS = ("copy", "edit", "text", "qr", "lens")
RECORD_MODES = ("monitor", "region")
TOOLS = ("grim", "slurp", "magick", "wl-copy", "satty", "tesseract", "zbarimg", "gpu-screen-recorder", "xdg-open",
         "hyprctl")
OCR_LANGS = "eng"
STOP_WAIT = 10.0          # seconds a stopping recorder gets to finish its file before it is killed
LENS_UPLOAD = "https://lens.google.com/v3/upload"

Run = Callable[..., Awaitable[tuple[int, bytes, bytes]]]


async def run_process(argv: list[str], stdin: bytes | None = None, timeout: float | None = 120) -> tuple[int, bytes, bytes]:
    process = await asyncio.create_subprocess_exec(*argv, stdin=asyncio.subprocess.PIPE if stdin is not None else asyncio.subprocess.DEVNULL,
                                                   stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        out, err = await asyncio.wait_for(process.communicate(stdin), timeout)
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        return -1, b"", b"timed out"
    return (process.returncode if process.returncode is not None else -1), out, err


async def spawn_process(argv: list[str]):
    return await asyncio.create_subprocess_exec(*argv, stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.DEVNULL,
                                                stderr=asyncio.subprocess.PIPE)


def lens_upload(path: Path) -> str:
    """Posts the picture to Google Lens and returns the results page it redirects to (opened in the browser).
    urllib loads here, not at import: it costs the core about 8 MiB it would otherwise hold all day (BUDGETS.md)."""
    import urllib.error
    import urllib.parse
    import urllib.request
    boundary = os.urandom(16).hex()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"encoded_image\"; filename=\"{path.name}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    url = LENS_UPLOAD + "?" + urllib.parse.urlencode({"ep": "ccm", "s": "", "st": str(int(time.time() * 1000))})
    request = urllib.request.Request(url, data=body, method="POST",
                                     headers={"Content-Type": f"multipart/form-data; boundary={boundary}",
                                              "User-Agent": "Mozilla/5.0"})

    class Keep(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            raise urllib.error.HTTPError(newurl, code, msg, headers, fp)

    try:
        urllib.request.build_opener(Keep).open(request, timeout=20)
    except urllib.error.HTTPError as redirect:
        if 300 <= redirect.code < 400 and redirect.filename:
            return redirect.filename
        raise
    raise OSError("Google Lens gave no results page")


def which(tool: str) -> str | None:
    """shutil.which without shutil: on Python 3.14 it loads the compression modules, about 1 MiB the core would hold."""
    for folder in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(folder, tool)
        if folder and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def user_dir(kind: str, fallback: str) -> Path:
    """XDG_PICTURES_DIR / XDG_VIDEOS_DIR when set, else ~/Pictures or ~/Videos."""
    value = os.environ.get(f"XDG_{kind}_DIR")
    return Path(value).expanduser() if value else Path.home() / fallback


def geometry(text: str) -> tuple[int, int, int, int]:
    """slurp's "x,y wxh" → (x, y, w, h)."""
    try:
        at, size = text.strip().split(" ")
        x, y = (int(float(v)) for v in at.split(","))
        w, h = (int(float(v)) for v in size.split("x"))
    except ValueError as error:
        raise ValueError(f"not a geometry: {text!r}") from error
    if w <= 0 or h <= 0:
        raise ValueError(f"empty geometry: {text!r}")
    return x, y, w, h


class Capture:
    def __init__(self, runtime_dir: Path, pictures: Path | None = None, videos: Path | None = None, run: Run = run_process,
                 spawn=spawn_process, upload=lens_upload, clock=time.time, which=which,
                 alert: Callable[..., None] = lambda summary, body, image=None: None):
        self.work = runtime_dir / "capture"
        self.pictures = (pictures or user_dir("PICTURES", "Pictures")) / "Screenshots"
        self.videos = (videos or user_dir("VIDEOS", "Videos")) / "Recordings"
        self.run, self.spawn, self.upload, self.clock, self.which = run, spawn, upload, clock, which
        self.alert = alert  # the host's notice (core/host.py alert), so the core names no host program
        self.on_change = lambda: None
        self.busy = False
        self.recording: dict | None = None
        self.recorder = None
        self.tasks: set[asyncio.Task] = set()

    # ---- State

    def tools(self) -> dict:
        return {tool: bool(self.which(tool)) for tool in TOOLS}

    def snapshot(self) -> dict:
        return {"busy": self.busy, "recording": dict(self.recording) if self.recording else None, "tools": self.tools()}

    def _changed(self):
        self.on_change()

    def stamp(self) -> str:
        return time.strftime("%Y-%m-%d_%H-%M-%S", time.localtime(self.clock()))

    def background(self, coroutine) -> None:
        task = asyncio.get_running_loop().create_task(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)

    # ---- Host reads

    async def monitors(self) -> list[dict]:
        code, out, _ = await self.run(["hyprctl", "monitors", "-j"], timeout=5)
        try:
            monitors = json.loads(out) if code == 0 else []
        except ValueError:
            monitors = []
        return [m for m in monitors if isinstance(m, dict) and not m.get("disabled")]

    async def window_boxes(self, monitors: list[dict]) -> list[str]:
        """The windows on the workspaces showing now, as slurp boxes "x,y wxh"."""
        shown = {m.get("activeWorkspace", {}).get("id") for m in monitors}
        code, out, _ = await self.run(["hyprctl", "clients", "-j"], timeout=5)
        try:
            clients = json.loads(out) if code == 0 else []
        except ValueError:
            clients = []
        boxes = []
        for c in clients:
            if not isinstance(c, dict) or c.get("hidden") or not c.get("mapped", True):
                continue
            if c.get("workspace", {}).get("id") not in shown:
                continue
            (x, y), (w, h) = c.get("at", (0, 0)), c.get("size", (0, 0))
            if w > 0 and h > 0:
                boxes.append(f"{x},{y} {w}x{h}")
        return boxes

    async def select(self, mode: str, monitors: list[dict]) -> tuple[int, int, int, int] | None:
        """The area to cut, in layout coordinates, or None for the whole grab. Raises Cancelled when the owner
        dismisses the selection."""
        if mode == "full":
            return None
        if mode == "monitor":
            focused = next((m for m in monitors if m.get("focused")), monitors[0] if monitors else None)
            if not focused:
                raise RuntimeError("no monitor to capture")
            scale = float(focused.get("scale") or 1)
            return (int(focused.get("x", 0)), int(focused.get("y", 0)),
                    round(focused.get("width", 0) / scale), round(focused.get("height", 0) / scale))
        argv, stdin = ["slurp", "-d"], None
        if mode == "window":
            boxes = await self.window_boxes(monitors)
            if not boxes:
                raise RuntimeError("no window to capture")
            argv, stdin = ["slurp", "-r"], ("\n".join(boxes) + "\n").encode()
        code, out, _ = await self.run(argv, stdin=stdin, timeout=None)
        if code != 0 or not out.strip():
            raise Cancelled()
        return geometry(out.decode())

    # ---- Shots

    def shoot(self, mode: str = "region", action: str = "copy") -> str:
        """Starts a shot in the background; the result arrives as a notification. Returns what it is doing."""
        if mode not in SHOT_MODES:
            raise bad_args(f"shot: {mode!r} is not one of {', '.join(SHOT_MODES)}")
        if action not in ACTIONS:
            raise bad_args(f"shot: {action!r} is not one of {', '.join(ACTIONS)}")
        if self.busy:
            raise bad_args("a capture is already running")
        self.busy = True
        self._changed()
        self.background(self._shot(mode, action))
        return "selecting" if mode in ("region", "window") else "captured"

    async def _shot(self, mode: str, action: str) -> dict:
        frozen = self.work / f"freeze-{os.urandom(8).hex()}.png"
        cut = self.work / f"cut-{os.urandom(8).hex()}.png"
        try:
            self.work.mkdir(parents=True, exist_ok=True)
            monitors = await self.monitors()
            code, _, err = await self.run(["grim", "-l", "0", str(frozen)], timeout=15)
            if code != 0:
                raise RuntimeError("grim: " + err.decode(errors="replace").strip()[:200])
            area = await self.select(mode, monitors)
            picture = frozen
            if area is not None:
                picture = cut
                await self.crop(frozen, cut, area, monitors)
            return await self.finish(picture, action, mode)
        except Cancelled:
            return {"status": "cancelled"}
        except Exception as error:  # every failure is told, never silent
            log.warning("capture %s %s: %s", mode, action, error)
            await self.notify("Capture failed", str(error))
            return {"status": "error", "message": str(error)}
        finally:
            for path in (frozen, cut):
                path.unlink(missing_ok=True)
            self.busy = False
            self._changed()

    async def crop(self, frozen: Path, out: Path, area: tuple[int, int, int, int], monitors: list[dict]) -> None:
        """grim -l of the whole layout starts at its top-left monitor and renders at the largest scale."""
        x0 = min((int(m.get("x", 0)) for m in monitors), default=0)
        y0 = min((int(m.get("y", 0)) for m in monitors), default=0)
        scale = max((float(m.get("scale") or 1) for m in monitors), default=1.0)
        x, y, w, h = area
        box = f"{round(w * scale)}x{round(h * scale)}+{round((x - x0) * scale)}+{round((y - y0) * scale)}"
        code, _, err = await self.run(["magick", str(frozen), "-crop", box, "+repage", str(out)], timeout=15)
        if code != 0:
            raise RuntimeError("crop: " + err.decode(errors="replace").strip()[:200])

    async def finish(self, picture: Path, action: str, mode: str) -> dict:
        if action == "text":
            code, out, err = await self.run(["tesseract", str(picture), "-", "-l", OCR_LANGS], timeout=60)
            text = out.decode(errors="replace").strip() if code == 0 else ""
            if not text:
                await self.notify("No text found", "Nothing readable in that area.")
                return {"status": "empty"}
            await self.copy_text(text)
            await self.notify("Text copied", f"{len(text)} characters")
            return {"status": "ok", "text": text}
        if action == "qr":
            code, out, _ = await self.run(["zbarimg", "-q", "--raw", str(picture)], timeout=20)
            found = out.decode(errors="replace").strip() if code == 0 else ""
            if not found:
                await self.notify("No QR code found", "Nothing to read in that area.")
                return {"status": "empty"}
            await self.copy_text(found)
            await self.notify("QR code copied", found.splitlines()[0][:120])
            return {"status": "ok", "text": found}
        if action == "lens":
            url = await asyncio.get_running_loop().run_in_executor(None, self.upload, picture)
            await self.run(["xdg-open", url], timeout=10)
            return {"status": "ok", "url": url}
        # copy and edit keep the picture
        self.pictures.mkdir(parents=True, exist_ok=True)
        saved = self.pictures / f"Screenshot_{self.stamp()}.png"
        saved.write_bytes(picture.read_bytes())
        if action == "edit":
            await self.spawn(["satty", "--filename", str(saved), "--output-filename", str(saved),
                              "--copy-command", "wl-copy", "--early-exit"])
            return {"status": "ok", "file": str(saved)}
        code, _, err = await self.run(["wl-copy", "--type", "image/png"], stdin=saved.read_bytes(), timeout=10)
        if code != 0:
            raise RuntimeError("wl-copy: " + err.decode(errors="replace").strip()[:200])
        await self.notify("Screenshot copied", saved.name, image=saved)
        return {"status": "ok", "file": str(saved)}

    async def copy_text(self, text: str) -> None:
        code, _, err = await self.run(["wl-copy"], stdin=text.encode(), timeout=10)
        if code != 0:
            raise RuntimeError("wl-copy: " + err.decode(errors="replace").strip()[:200])

    async def notify(self, title: str, body: str, image: Path | None = None) -> None:
        self.alert(title, body, image=str(image) if image is not None else None)

    # ---- Recording

    async def record_start(self, mode: str = "monitor", sound: bool = False, mic: bool = False) -> dict:
        if mode not in RECORD_MODES:
            raise bad_args(f"record: {mode!r} is not one of {', '.join(RECORD_MODES)}")
        if self.recording:
            raise bad_args("already recording")
        monitors = await self.monitors()
        if mode == "region":
            try:
                area = await self.select("region", monitors)
            except Cancelled:
                return {"status": "cancelled"}
            assert area is not None  # a region is always an area
            x, y, w, h = area
            target = ["-w", "region", "-region", f"{w}x{h}+{x}+{y}"]
        else:
            focused = next((m for m in monitors if m.get("focused")), monitors[0] if monitors else None)
            target = ["-w", focused["name"] if focused and focused.get("name") else "screen"]
        self.videos.mkdir(parents=True, exist_ok=True)
        file = self.videos / f"Recording_{self.stamp()}.mp4"
        argv = ["gpu-screen-recorder", *target, "-f", "60", "-o", str(file)]
        audio = "|".join(name for name, on in (("default_output", sound), ("default_input", mic)) if on)
        if audio:
            argv[-2:-2] = ["-a", audio]
        self.recorder = await self.spawn(argv)
        self.recording = {"active": True, "startedAt": self.clock(), "file": str(file), "mode": mode,
                          "sound": sound, "mic": mic}
        self._changed()
        self.background(self._watch(self.recorder))
        return dict(self.recording)

    async def _watch(self, process) -> None:
        """When the recorder ends (stopped or crashed), the state clears and the owner is told where the file is."""
        code = await process.wait()
        if process is not self.recorder:
            return
        stopped = self.recording or {}
        self.recorder, self.recording = None, None
        self._changed()
        file = Path(stopped.get("file", ""))
        if code in (0, -signal.SIGINT, 130) and file.is_file() and file.stat().st_size > 0:
            await self.notify("Recording saved", file.name)
        else:
            await self.notify("Recording failed", f"the recorder stopped (code {code})")

    async def record_stop(self) -> dict:
        process = self.recorder
        if not process or not self.recording:
            return {"status": "idle"}
        process.send_signal(signal.SIGINT)
        try:
            await asyncio.wait_for(asyncio.shield(process.wait()), STOP_WAIT)
        except asyncio.TimeoutError:
            process.kill()
        return {"status": "stopped"}

    async def record_toggle(self, mode: str = "monitor", sound: bool = False, mic: bool = False) -> dict:
        return await self.record_stop() if self.recording else await self.record_start(mode, sound, mic)

    async def stop(self) -> None:
        """The core's own stop: a running recording is finished, not lost."""
        if self.recording:
            await self.record_stop()


class Cancelled(Exception):
    """The owner dismissed the selection (Escape, or a click without a drag)."""
