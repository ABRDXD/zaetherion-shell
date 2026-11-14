"""ZAETHERION's own equaliser (Z50, Z173): the owner's settings, kept here and published as `equalizer`, and the
PipeWire filter-chain process that applies them while it is on.

The chain runs as this core's child (`pipewire -c <runtime>/zaetherion-eq.conf`), written fresh at each start from
core/eq_chain.py. Its sink is a WirePlumber smart filter: WirePlumber puts it in front of the default sink and
links streams straight to the device again when the process is gone. So switching off, a crash of the chain or
of the core (the child dies with its parent), or PipeWire restarting all leave the owner's routing as it was.
Gains and mono change live (`pw-cli set-param`); nothing is restarted for them.

Only a core whose session runs the chain (fartd attaches it in the DMS session) ever starts a process; elsewhere
the settings are kept and the topic reads unavailable.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
from pathlib import Path
import signal

from core import eq_chain
from core.errors import bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.equalizer")

DEFAULTS = {"on": False, "mono": False, "bands": list(eq_chain.PRESETS[eq_chain.FLAT])}
BACKOFF = (1.0, 2.0, 4.0)  # seconds before each restart after the chain stopped by itself
FAILURE_WINDOW = 60.0  # this many stops within it and the equaliser gives up until asked again
START_TIMEOUT = 3.0
TOOLS = ("pipewire", "pw-cli", "pw-dump")


class ChainError(Exception):
    pass


def find_tool(name: str) -> str | None:
    """shutil.which without shutil (the core keeps its imports small)."""
    for directory in os.environ.get("PATH", "/usr/bin:/bin").split(os.pathsep):
        candidate = os.path.join(directory or ".", name)
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def valid_state(saved) -> dict:
    state = {"on": DEFAULTS["on"], "mono": DEFAULTS["mono"], "bands": list(DEFAULTS["bands"])}
    if not isinstance(saved, dict):
        return state
    for key in ("on", "mono"):
        if isinstance(saved.get(key), bool):
            state[key] = saved[key]
    bands = saved.get("bands")
    if isinstance(bands, list) and len(bands) == len(eq_chain.FREQUENCIES):
        try:
            state["bands"] = [eq_chain.clamp_gain(b) for b in bands]
        except (TypeError, ValueError):
            pass
    return state


class PipewireChain:
    """The chain's process. Its environment decides which PipeWire it joins (a check passes a private one)."""

    def __init__(self, runtime_dir: Path, env: dict | None = None):
        self.conf = runtime_dir / "zaetherion-eq.conf"
        self.pidfile = runtime_dir / "zaetherion-eq.pid"
        self.env = env
        self.process = None
        self.node = None
        self.reason = ""
        self._ended = None
        self._watch = None
        self._missing = None  # looked up once

    def missing(self) -> str | None:
        if self._missing is None:
            self._missing = next((f"{tool} is not installed" for tool in TOOLS if not find_tool(tool)), "")
        return self._missing or None

    def _stop_stale(self):
        """A chain left by a core that was killed before its child heard (the child normally dies with it)."""
        try:
            pid = int(self.pidfile.read_text().strip())
            cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
        except (OSError, ValueError):
            return
        if str(self.conf).encode() in cmdline:
            log.info("stopping a stale equaliser process (pid %d)", pid)
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass

    async def start(self, text: str):
        self._stop_stale()
        self.conf.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temp = self.conf.with_name(self.conf.name + ".tmp")
        temp.write_text(text)
        os.replace(temp, self.conf)
        argv = ["pipewire", "-c", str(self.conf)]
        if find_tool("setpriv"):
            argv = ["setpriv", "--pdeathsig", "TERM", "--", *argv]  # dies with the core: nobody left to switch it off
        self.reason = ""
        self.node = None
        loop = asyncio.get_running_loop()
        self.process = await asyncio.create_subprocess_exec(
            *argv, env=self.env, cwd="/", stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE)
        self.pidfile.write_text(f"{self.process.pid}\n")
        self._ended = loop.create_future()
        self._watch = loop.create_task(self._read(self.process, self._ended))
        try:
            await asyncio.wait_for(self._find_node(), START_TIMEOUT)
        except asyncio.TimeoutError:
            await self.stop()
            raise ChainError(self.reason or "the equaliser's sink did not appear") from None
        if self.node is None:
            await self.stop()
            raise ChainError(self.reason or "the equaliser process stopped")

    async def _read(self, process, ended):
        """The child's warnings. A connection error means PipeWire went away: the process would linger with
        nothing in it, so it is ended and the equaliser starts it again once PipeWire is back."""
        async for raw in process.stderr:
            line = raw.decode(errors="replace").strip()
            if not line:
                continue
            log.info("chain: %s", line[-300:])
            if "connection error" in line or "can't connect" in line:
                self.reason = "PipeWire went away"
                if process.returncode is None:
                    process.terminate()
            elif "[E]" in line and not self.reason:
                self.reason = line.split("]")[-1].strip()[:200]
        code = await process.wait()
        if not ended.done():
            ended.set_result(self.reason or f"the equaliser process exited ({code})")

    async def _find_node(self):
        delay = 0.05
        while not self._ended.done():
            dump = await self._dump()
            self.node = node_of(dump, self.process.pid)
            if self.node is not None:
                return
            await asyncio.sleep(delay)
            delay = min(0.4, delay * 2)

    async def _dump(self):
        process = await asyncio.create_subprocess_exec(
            "pw-dump", env=self.env, stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL)
        try:
            out, _ = await process.communicate()
        finally:
            if process.returncode is None:  # cancelled by the start's timeout: leave no pw-dump behind
                process.kill()
                await process.wait()
        try:
            return json.loads(out or b"[]")
        except ValueError:
            return []

    async def set(self, props: str):
        if self.node is None:
            raise ChainError("the equaliser is not running")
        process = await asyncio.create_subprocess_exec(
            "pw-cli", "set-param", str(self.node), "Props", props, env=self.env, stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE)
        try:
            _, err = await asyncio.wait_for(process.communicate(), START_TIMEOUT)
        except asyncio.TimeoutError:
            process.kill()
            await process.wait()
            raise ChainError("pw-cli did not answer") from None
        if process.returncode != 0:
            raise ChainError((err or b"").decode(errors="replace").strip()[:200] or "pw-cli failed")

    async def wait(self) -> str:
        return await asyncio.shield(self._ended)

    async def stop(self):
        process, self.process, self.node = self.process, None, None
        if process and process.returncode is None:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), 2.0)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
        if self._watch:
            await asyncio.gather(self._watch, return_exceptions=True)
            self._watch = None
        try:
            self.pidfile.unlink()
        except FileNotFoundError:
            pass


def node_of(dump: list, pid: int) -> int | None:
    """The id of our capture node, created by the client whose process is pid."""
    clients = {o.get("id") for o in dump if o.get("type", "").endswith(":Client")
               and str((o.get("info") or {}).get("props", {}).get("pipewire.sec.pid")) == str(pid)}
    for o in dump:
        props = (o.get("info") or {}).get("props", {})
        if o.get("type", "").endswith(":Node") and props.get("node.name") == eq_chain.NODE_NAME and props.get("client.id") in clients:
            return o.get("id")
    return None


class Equalizer:
    def __init__(self, state_dir: Path):
        self.path = state_dir / "eq.json"
        self.chain = None  # set by attach(): only a core whose session runs the chain has one
        self.on_change = lambda: None
        try:
            saved = read_json(self.path, {})
        except ValueError as error:
            log.warning("%s; the equaliser starts flat and off", error)
            saved = {}
        self.state = valid_state(saved)
        self.status = "off"  # off | starting | on | retrying | failed
        self.error = ""
        self._runner = None
        self._dirty = False
        self._pusher = None
        self._stops = []  # loop times the chain stopped by itself
        self._closing = False

    # Settings

    def attach(self, chain):
        """This core's session runs the chain (fartd: the DMS session, PipewireChain in the core's runtime
        directory): start it if the owner left it on."""
        self.chain = chain
        self._sync()
        self.on_change()

    def missing(self) -> str | None:
        if self.chain is None:
            return "this session's equaliser is not ours"
        return self.chain.missing()

    def snapshot(self) -> dict:
        bands = list(self.state["bands"])
        missing = self.missing()
        return {"available": missing is None, "reason": missing or "", "on": self.state["on"], "status": self.status,
                "active": self.status == "on", "error": self.error, "bands": bands, "mono": self.state["mono"],
                "preset": eq_chain.preset_for(bands), "presets": list(eq_chain.PRESETS),
                "frequencies": list(eq_chain.FREQUENCIES), "minGain": eq_chain.MIN_GAIN, "maxGain": eq_chain.MAX_GAIN,
                "headroom": eq_chain.headroom(bands)}

    def _save(self):
        write_json(self.path, {"version": 1, **self.state})

    def set_on(self, on) -> dict:
        if not isinstance(on, bool):
            raise bad_args("on must be true or false")
        if on and self.missing():
            raise bad_args(f"the equaliser is unavailable: {self.missing()}")
        if on != self.state["on"] or (on and self.status == "failed"):
            self.state["on"] = on
            self._save()
            self._stops.clear()
            self.error = ""
            if not on and self._runner is None:
                self.status = "off"  # it had given up; off is off
            self._sync()
            self.on_change()
        return self.snapshot()

    def set_band(self, index, gain) -> dict:
        if not isinstance(index, int) or isinstance(index, bool) or not 0 <= index < len(eq_chain.FREQUENCIES):
            raise bad_args(f"band must be 0 to {len(eq_chain.FREQUENCIES) - 1}")
        try:
            value = eq_chain.clamp_gain(gain)
        except (TypeError, ValueError):
            raise bad_args("gain must be a number of dB") from None
        bands = list(self.state["bands"])
        bands[index] = value
        return self._set_bands(bands)

    def apply_preset(self, name) -> dict:
        preset = eq_chain.preset_named(name) if isinstance(name, str) else None
        if preset is None:
            raise bad_args("preset must be one of " + ", ".join(eq_chain.PRESETS))
        return self._set_bands(list(eq_chain.PRESETS[preset]))

    def set_mono(self, on) -> dict:
        if not isinstance(on, bool):
            raise bad_args("mono must be true or false")
        if on != self.state["mono"]:
            self.state["mono"] = on
            self._changed()
        return self.snapshot()

    def _set_bands(self, bands) -> dict:
        if bands != self.state["bands"]:
            self.state["bands"] = bands
            self._changed()
        return self.snapshot()

    def _changed(self):
        self._save()
        self._push()
        self.on_change()

    # The chain

    def _wanted(self) -> bool:
        return self.state["on"] and self.missing() is None

    def _sync(self):
        if self._wanted() and self._runner is None:
            self._runner = asyncio.get_running_loop().create_task(self._run())
        elif not self._wanted() and self._runner is not None:
            self._runner.cancel()  # its finally stops the process, wherever it was (starting, on, waiting to retry)

    def _status(self, status: str, error: str = ""):
        if (status, error) != (self.status, self.error):
            self.status, self.error = status, error
            self.on_change()

    async def _run(self):
        loop = asyncio.get_running_loop()
        try:
            while self._wanted():
                self._status("starting")
                try:
                    await self.chain.start(eq_chain.config_text(self.state["bands"], self.state["mono"]))
                except (ChainError, OSError) as error:
                    reason = str(error)
                else:
                    self._status("on")
                    self._push()  # what changed while it started
                    reason = await self.chain.wait()
                    if not self._wanted():
                        break
                log.warning("equaliser stopped: %s", reason)
                now = loop.time()
                self._stops = [t for t in self._stops if now - t < FAILURE_WINDOW] + [now]
                if len(self._stops) > len(BACKOFF):
                    self._status("failed", reason)
                    break
                self._status("retrying", reason)
                await asyncio.sleep(BACKOFF[len(self._stops) - 1])
        finally:
            await self.chain.stop()
            self._runner = None
            if self.status != "failed":
                self._status("off")
            if self._wanted() and self.status != "failed" and not self._closing:
                self._sync()  # switched off and on again while it was stopping

    def _push(self):
        """Tell the running chain the current settings. One pw-cli at a time; a change during one sends the latest
        again after it, so a dragged slider costs at most two calls in flight."""
        if self.status != "on":
            return
        self._dirty = True
        if self._pusher is None:
            self._pusher = asyncio.get_running_loop().create_task(self._send())

    async def _send(self):
        try:
            while self._dirty and self.status == "on":
                self._dirty = False
                try:
                    await self.chain.set(eq_chain.props_text(self.state["bands"], self.state["mono"]))
                except (ChainError, OSError) as error:
                    log.warning("equaliser: %s", error)
        finally:
            self._pusher = None

    async def close(self):
        """The core is stopping: the chain goes with it (the setting stays as the owner left it)."""
        self._closing = True
        runner = self._runner
        if runner:
            runner.cancel()
            await asyncio.gather(runner, return_exceptions=True)
        if self.chain:
            await self.chain.stop()
