#!/usr/bin/env python3
"""Live check of our equaliser (core/equalizer.py, Z173) on a PRIVATE PipeWire. The owner's PipeWire, WirePlumber
and audio are never touched: every PipeWire process and tool here runs with its own runtime and config
directories in a temporary folder, and each call is refused unless its environment points there.

The private daemon has two null sinks and no session manager, so nothing is linked or heard; the check is what
PipeWire reports (pw-dump): the chain's nodes, the gains and mono after each change, a PipeWire restart, a core
killed with the chain running, and switching off.

    eq_check.py        exit 1 if any check fails
"""
import asyncio
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core import eq_chain  # noqa: E402
from core.equalizer import Equalizer, PipewireChain  # noqa: E402

REMOTE = "zaetherion-eq-check"
DAEMON = """context.properties = {
    core.daemon = true
    core.name = zaetherion-eq-check
    log.level = 2
    support.dbus = false
}
context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}
context.modules = [
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-metadata }
    { name = libpipewire-module-spa-node-factory }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-access }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-link-factory }
]
context.objects = [
    { factory = spa-node-factory
        args = { factory.name = support.node.driver node.name = check-driver node.group = check.dummy priority.driver = 20000 } }
    { factory = adapter
        args = { factory.name = support.null-audio-sink node.name = check-speakers media.class = Audio/Sink
                 audio.position = [ FL FR ] object.linger = true } }
    { factory = adapter
        args = { factory.name = support.null-audio-sink node.name = check-headphones media.class = Audio/Sink
                 audio.position = [ FL FR ] object.linger = true } }
    { factory = metadata args = { metadata.name = default } }
]
"""
# A stand-in core: it runs the equaliser on, says the chain's pid, then waits to be killed.
FAKE_CORE = """
import asyncio, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from core.equalizer import Equalizer, PipewireChain
async def main():
    eq = Equalizer(Path(sys.argv[2]))
    eq.attach(PipewireChain(Path(sys.argv[3])))
    for _ in range(100):
        if eq.status == "on":
            break
        await asyncio.sleep(0.05)
    print(eq.chain.process.pid if eq.status == "on" else -1, flush=True)
    await asyncio.sleep(60)
asyncio.run(main())
"""


class Private:
    """A private PipeWire daemon and the environment that reaches only it."""

    def __init__(self):
        self.base = Path(tempfile.mkdtemp(prefix="zeq-", dir="/tmp"))  # short: a socket path has 108 bytes
        self.runtime = self.base / "rt"
        self.conf = self.base / "conf"
        self.runtime.mkdir(mode=0o700)
        self.conf.mkdir()
        shutil.copy("/usr/share/pipewire/client.conf", self.conf / "client.conf")
        (self.conf / "check-daemon.conf").write_text(DAEMON)
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(("FART_", "PIPEWIRE_", "PULSE_", "JACK_")) and k != "DBUS_SESSION_BUS_ADDRESS"}
        env.update(PIPEWIRE_RUNTIME_DIR=str(self.runtime), XDG_RUNTIME_DIR=str(self.runtime),
                   PIPEWIRE_CONFIG_DIR=str(self.conf), PIPEWIRE_REMOTE=REMOTE)
        self.env = env
        self.daemon = None

    def guard(self, env):
        if env.get("PIPEWIRE_RUNTIME_DIR") != str(self.runtime) or env.get("XDG_RUNTIME_DIR") != str(self.runtime) \
                or env.get("PIPEWIRE_REMOTE") != REMOTE or "DBUS_SESSION_BUS_ADDRESS" in env:
            raise SystemExit("refusing: this environment could reach the owner's PipeWire")

    def start(self):
        self.guard(self.env)
        log = (self.base / "daemon.log").open("ab")
        self.daemon = subprocess.Popen(["pipewire", "-c", str(self.conf / "check-daemon.conf")], env=self.env,
                                       stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
        log.close()
        socket = self.runtime / REMOTE
        for _ in range(100):
            if socket.exists() and self.dump():
                return True
            time.sleep(0.05)
        return False

    def stop_daemon(self):
        if self.daemon and self.daemon.poll() is None:
            self.daemon.terminate()
            try:
                self.daemon.wait(3)
            except subprocess.TimeoutExpired:
                self.daemon.kill()
                self.daemon.wait()

    def dump(self) -> list:
        self.guard(self.env)
        try:
            out = subprocess.run(["pw-dump"], env=self.env, stdin=subprocess.DEVNULL, capture_output=True, timeout=5).stdout
            return json.loads(out or b"[]")
        except (subprocess.TimeoutExpired, ValueError):
            return []

    def ours(self) -> list:
        """Processes whose command line names this check's folder."""
        found = []
        for proc in Path("/proc").iterdir():
            if proc.name.isdigit():
                try:
                    if str(self.base).encode() in (proc / "cmdline").read_bytes():
                        found.append(int(proc.name))
                except OSError:
                    pass
        return [pid for pid in found if pid != os.getpid()]

    def chains(self) -> list:
        """Our chain processes still alive."""
        found = []
        for pid in self.ours():
            try:
                if alive(pid) and b"zaetherion-eq.conf" in Path(f"/proc/{pid}/cmdline").read_bytes():
                    found.append(pid)
            except OSError:
                pass
        return found

    def cleanup(self):
        self.stop_daemon()
        for pid in self.ours():
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass
        shutil.rmtree(self.base, ignore_errors=True)


def node(dump, name):
    return next((o for o in dump if o.get("type", "").endswith(":Node") and o["info"]["props"].get("node.name") == name), None)


def controls(dump) -> dict:
    """The filter graph's controls (the node also lists its converter's params; those are skipped)."""
    found = node(dump, eq_chain.NODE_NAME)
    values = {}
    for prop in (found or {}).get("info", {}).get("params", {}).get("Props", []):
        items = prop.get("params")
        if isinstance(items, list):
            values.update((k, v) for k, v in zip(items[0::2], items[1::2]) if ":" in str(k))
    return values


def alive(pid) -> bool:
    try:
        state = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0]
        return state != "Z"
    except (OSError, IndexError):
        return False


def system_pipewire() -> list:
    out = subprocess.run(["pgrep", "-a", "-x", "pipewire"], capture_output=True, text=True).stdout
    return sorted(line for line in out.splitlines() if " -c " not in line)


async def until(predicate, seconds=5.0):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return True
        await asyncio.sleep(0.05)
    return predicate()


async def run(private: Private, check):
    state = private.base / "state"
    state.mkdir()
    eq = Equalizer(state)
    chain = PipewireChain(private.base / "core", env=private.env)
    (private.base / "core").mkdir()
    try:
        eq.attach(chain)
        check("first run: off, flat, nothing started", eq.status == "off" and not private.chains() and node(private.dump(), eq_chain.NODE_NAME) is None)
        eq.set_on(True)
        await until(lambda: eq.status in ("on", "failed"))
        dump = private.dump()
        sink, output = node(dump, eq_chain.NODE_NAME), node(dump, eq_chain.NODE_NAME + ".output")
        check("on: the chain's sink and output exist", sink is not None and output is not None, eq.error)
        props = sink["info"]["props"] if sink else {}
        check("the sink is a smart filter, never a default", props.get("filter.smart") in (True, "true") and props.get("media.class") == "Audio/Sink")
        check("the output is passive and targets nothing", output is not None and output["info"]["props"].get("node.passive") in (True, "true")
              and "target.object" not in output["info"]["props"])
        c = controls(dump)
        check("starts flat and stereo", c.get("eqL_1:Gain") == 0 and c.get("mixL:Gain 1") == 1 and c.get("mixL:Gain 2") == 0, str({k: c.get(k) for k in ("eqL_1:Gain", "mixL:Gain 1", "mixL:Gain 2")}))
        check("twenty biquads at the ten frequencies", all(c.get(f"eq{ch}_{i + 1}:Freq") == f for ch in "LR" for i, f in enumerate(eq_chain.FREQUENCIES)))
        first_pid = chain.process.pid if chain.process else None

        eq.set_band(0, 6)
        level = 10 ** (-eq_chain.headroom(eq.state["bands"]) / 20)
        await until(lambda: controls(private.dump()).get("eqR_1:Gain") == 6)
        c = controls(private.dump())
        check("a gain changes live on both channels", c.get("eqL_1:Gain") == 6 and c.get("eqR_1:Gain") == 6, f"{c.get('eqL_1:Gain')}, {c.get('eqR_1:Gain')}")
        check("the headroom lowers the input", abs(c.get("mixL:Gain 1", 0) - level) < 1e-4, f"{c.get('mixL:Gain 1')} vs {level:.6f}")
        eq.set_mono(True)
        await until(lambda: controls(private.dump()).get("mixL:Gain 2", 0) > 0)
        c = controls(private.dump())
        half = level / 2
        check("mono: each side is half of both", all(abs(c.get(k, -1) - half) < 1e-4 for k in ("mixL:Gain 1", "mixL:Gain 2", "mixR:Gain 1", "mixR:Gain 2")),
              str({k: c.get(k) for k in ("mixL:Gain 1", "mixL:Gain 2", "mixR:Gain 1", "mixR:Gain 2")}))
        eq.set_mono(False)
        await until(lambda: controls(private.dump()).get("mixL:Gain 2") == 0)
        c = controls(private.dump())
        check("stereo again", c.get("mixL:Gain 2") == 0 and c.get("mixR:Gain 1") == 0 and abs(c.get("mixR:Gain 2", 0) - level) < 1e-4)
        eq.apply_preset("Vocal")
        eq.set_mono(True)
        await until(lambda: controls(private.dump()).get("eqR_6:Gain") == 3)
        c = controls(private.dump())
        check("a preset sets all ten bands", [c.get(f"eqL_{i + 1}:Gain") for i in range(10)] == list(eq_chain.PRESETS["Vocal"]))
        check("no change restarted the chain", chain.process is not None and chain.process.pid == first_pid)

        # PipeWire restarts: the chain must not linger without it, and must come back with the settings.
        private.stop_daemon()
        gone = await until(lambda: eq.status == "retrying" and (first_pid is None or not alive(first_pid)), 5)
        check("PipeWire gone: the chain process ends and the equaliser waits", gone, f"{eq.status}, {eq.error}")
        check("it says why", eq.error == "PipeWire went away", eq.error)
        private.start()
        back = await until(lambda: eq.status == "on", 15)
        c = controls(private.dump())
        check("PipeWire back: the chain is back with the same settings", back and [c.get(f"eqL_{i + 1}:Gain") for i in range(10)] == list(eq_chain.PRESETS["Vocal"])
              and abs(c.get("mixL:Gain 2", 0) - 10 ** (-eq_chain.headroom(eq_chain.PRESETS["Vocal"]) / 20) / 2) < 1e-4, eq.status)

        eq.set_on(False)
        off = await until(lambda: eq.status == "off" and node(private.dump(), eq_chain.NODE_NAME) is None)
        check("off: the chain's nodes are gone", off)
        check("off: its process and pid file are gone", chain.process is None and not chain.pidfile.exists() and not private.chains())
        check("off is remembered", json.loads((state / "eq.json").read_text())["on"] is False)
    finally:
        await eq.close()

    # A core killed while the chain runs: the chain goes with it (setpriv --pdeathsig), so nothing lingers.
    fake_state, fake_rt = private.base / "fake-state", private.base / "fake-rt"
    fake_state.mkdir()
    fake_rt.mkdir()
    (fake_state / "eq.json").write_text(json.dumps({"version": 1, "on": True, "mono": False, "bands": [0] * 10}))
    private.guard(private.env)
    fake = subprocess.Popen([sys.executable, "-I", "-c", FAKE_CORE, str(ROOT), str(fake_state), str(fake_rt)], env=private.env,
                            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True, start_new_session=True)
    try:
        pid = int(fake.stdout.readline().strip() or -1)
        check("a core that starts with it on starts the chain", pid > 0 and node(private.dump(), eq_chain.NODE_NAME) is not None)
        fake.kill()
        fake.wait()
        died = await until(lambda: pid > 0 and not alive(pid) and node(private.dump(), eq_chain.NODE_NAME) is None, 5)
        check("the core killed: its chain and nodes are gone", died)
    finally:
        if fake.poll() is None:
            fake.kill()
            fake.wait()


def main():
    before = system_pipewire()
    print(f"owner's PipeWire before: {before}", flush=True)
    private = Private()
    results = []

    def check(name, ok, note=""):
        results.append((name, bool(ok)))
        print(f"{'PASS' if ok else 'FAIL'} {name}{' (' + note + ')' if note and not ok else ''}", flush=True)

    try:
        check("private PipeWire up", private.start())
        nodes = {o["info"]["props"].get("node.name") for o in private.dump() if o.get("type", "").endswith(":Node")}
        check("it is the private one (two null sinks)", {"check-speakers", "check-headphones"} <= nodes, str(nodes))
        asyncio.run(run(private, check))
    finally:
        private.cleanup()
    left = private.ours()
    check("cleaned up: no process of this check left", not left, str(left))
    after = system_pipewire()
    check("the owner's PipeWire is the same process", before == after, f"{before} -> {after}")
    failed = [name for name, ok in results if not ok]
    print(f"{len(results) - len(failed)}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
