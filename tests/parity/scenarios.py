"""Socket-level scenarios for the parity harness (Z226). Each one runs against any core: it checks what every core
must do (Record.equal and friends raise at once) and records what it saw (Record.see), so tools/parity.py can
compare two cores observation by observation.

A scenario declares the ops and topics it covers; tests/test_parity_coverage.py holds the registry to account.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import os
import stat
import time
from typing import Callable

from parity.harness import Core, CoreGone
from parity.normalise import Normaliser


@dataclass
class Scenario:
    name: str
    stage: str
    ops: tuple[str, ...]
    topics: tuple[str, ...]
    run: Callable
    core_args: dict = field(default_factory=dict)


SCENARIOS: dict[str, Scenario] = {}


def scenario(stage: str, ops=(), topics=(), **core_args):
    def wrap(fn):
        SCENARIOS[fn.__name__] = Scenario(fn.__name__, stage, tuple(ops), tuple(topics), fn, core_args)
        return fn
    return wrap


class Record:
    """Observations in order, normalised; failures name the step."""

    def __init__(self):
        self.seen: list[tuple[str, object]] = []
        self.normalise = Normaliser()

    def see(self, label: str, value):
        value = self.normalise(value)
        self.seen.append((label, value))
        return value

    def same(self, label: str, got, want):
        """Asserts equality but records only that it held: for values that differ run to run (times, bytes)."""
        self.see(label, got == want)
        if got != want:
            raise AssertionError(f"{label}: got {got!r}, want {want!r}")

    def file(self, label: str, data: bytes | None):
        """A state file: its parsed value (key order kept) and its text style, both normalised."""
        if data is None:
            return self.see(label, None)
        try:
            parsed = [json.loads(line) for line in data.splitlines()] if label.endswith(".jsonl") else json.loads(data)
        except ValueError:
            parsed = "<not JSON>"
        self.seen.append((label, {"value": self.normalise(parsed), "text": self.normalise.text(data)}))

    def equal(self, label: str, got, want):
        self.see(label, got)
        if got != want:
            raise AssertionError(f"{label}: got {got!r}, want {want!r}")

    def true(self, label: str, condition: bool, detail=None):
        self.see(label, bool(condition))
        if not condition:
            raise AssertionError(f"{label}: not true ({detail!r})" if detail is not None else f"{label}: not true")

    def lines(self) -> list[str]:
        return [f"{label}: {json.dumps(value, ensure_ascii=False, default=_plain)}" for label, value in self.seen]


def _plain(value):
    if isinstance(value, (set, frozenset)):
        return sorted(value, key=repr)
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="backslashreplace")
    raise TypeError(type(value).__name__)


def run_scenario(sc: Scenario, which: str | None = None) -> tuple[Record, Core]:
    """Runs one scenario on a fresh core; returns its record (raises on a failed check)."""
    rec = Record()
    core = Core(which, **sc.core_args)
    try:
        core.start()
        sc.run(core, rec)
    except Exception as error:
        log = core.log()
        if log.strip():
            error.args = (f"{error.args[0] if error.args else error}\n--- {core.name} core log ---\n{log[-3000:]}",)
        raise
    finally:
        core.close()
    return rec, core


def epoch(*parts) -> float:
    """A UTC moment as epoch seconds: datetime(year, month, day, hour, minute)."""
    return datetime(*parts, tzinfo=timezone.utc).timestamp()


def ms(*parts) -> int:
    return round(epoch(*parts) * 1000)


TOPICS = ("genealogy", "timers", "tasks", "notifications", "overdrive", "session", "island", "widgets", "lock", "clips", "palette",
          "wallpaper", "equalizer", "launcher", "capture", "view", "presets", "core", "supervisor", "sfx", "journey",
          "discovery", "track", "ignite")


# ----------------------------------------------------------------------------------------------------------------
# Stage 0: the protocol itself


@scenario("0", ops=("hello",))
def protocol_hello(core, rec):
    peer = core.connect()
    rec.equal("before hello", peer.error("status"), "protocol")
    rec.equal("wrong protocol", peer.error("hello", client="cli", protocol=2), "protocol")
    rec.equal("unknown client kind", peer.error("hello", client="robot", protocol=1), "bad-args")
    rec.equal("hello without protocol", peer.error("hello", client="cli"), "bad-args")
    rec.equal("a view the core never spawned", peer.error("hello", client="view", protocol=1), "refused")
    rec.equal("still not welcome", peer.error("status"), "protocol")
    hello = peer.hello()
    rec.equal("hello's keys", list(hello), ["core"])
    rec.equal("core snapshot keys", list(hello["core"]), ["version", "protocol", "pid", "host", "startedAt"])
    rec.equal("protocol", hello["core"]["protocol"], 1)
    rec.equal("host", hello["core"]["host"], "fixture")
    rec.same("pid is the core's", hello["core"]["pid"], core.process.pid)
    rec.true("startedAt is epoch ms", abs(hello["core"]["startedAt"] - time.time() * 1000) < 60_000)
    rec.see("second hello", peer.call("hello", client="cli", protocol=1)["ok"])


@scenario("0", ops=("hello",))
def protocol_errors(core, rec):
    peer = core.client()
    peer.send_raw(b"not json\n")
    rec.equal("not JSON", peer.read(), {"id": None, "ok": False, "error": {"code": "bad-request", "message": "not JSON"}})
    peer.send_raw(b"[1,2]\n")  # valid JSON, but not a request: no id, so nothing comes back
    rec.equal("a JSON array answers nothing", peer.drain(0.3), [])
    for label, raw in (("no op", b'{"id":7}\n'), ("op not text", b'{"id":8,"op":5}\n'),
                       ("args not an object", b'{"id":9,"op":"status","args":[1]}\n'),
                       ("unpaired surrogate", b'{"id":10,"op":"task.add","args":{"text":"\\ud800"}}\n')):
        peer.send_raw(raw)
        reply = peer.read()
        rec.equal(label, (reply["ok"], reply["error"]["code"]), (False, "bad-request"))
        rec.see(f"{label} reply", reply)
    rec.equal("unknown op", peer.error("egg"), "unknown-op")
    rec.equal("unknown argument", peer.error("timer.start", kind="countdown", bogus=1), "bad-args")
    rec.equal("missing argument", peer.error("task.add"), "bad-args")
    # Requests without an id are notifications: nothing comes back, whether they work or fail.
    peer.notify("egg")
    peer.notify("status")
    peer.send({"id": None, "op": "status"})
    rec.equal("notifications answer nothing", peer.drain(0.3), [])
    rec.equal("and the line still works", peer.call("status")["ok"], True)
    # Ids are echoed as sent, whatever their type.
    for request_id in ("abc", 0, 2.5, [1], {"k": 1}):
        peer.send({"id": request_id, "op": "egg"})
        rec.equal(f"id {request_id!r} echoed", peer.read()["id"], request_id)


@scenario("0", ops=("hello", "status"))
def protocol_pipelining(core, rec):
    peer = core.client()
    peer.send_raw(b"".join(json.dumps({"id": n, "op": "status" if n % 2 else "egg"}).encode() + b"\n" for n in range(1, 21)))
    replies = [peer.read() for _ in range(20)]
    rec.equal("replies in request order", [r["id"] for r in replies], list(range(1, 21)))
    rec.equal("each its own answer", [r["ok"] for r in replies], [n % 2 == 1 for n in range(1, 21)])
    # A frame split across writes is one request; an unfinished last frame is never answered.
    peer.send_raw(b'{"id":30,')
    time.sleep(0.1)
    peer.send_raw(b'"op":"status"}\n')
    rec.equal("split frame", peer.read()["id"], 30)
    peer.send_raw(b'{"id":31,"op":"status"}')
    peer.sock.shutdown(1)  # SHUT_WR: EOF with an incomplete frame
    rec.equal("incomplete last frame: nothing, then closed", peer.until_closed(), ([], True))


@scenario("0", ops=("hello",))
def protocol_limits(core, rec):
    peer = core.client()
    big = b'{"id":1,"op":"egg","args":{"pad":"' + b"x" * ((1 << 20) + 64) + b'"}}\n'
    try:
        peer.send_raw(big)
    except (BrokenPipeError, ConnectionResetError):
        pass
    rec.equal("a line over 1 MiB closes the client", peer.closed_by_core(3), True)
    other = core.client()
    rec.equal("the core still serves others", other.call("status")["ok"], True)
    near = b'{"id":2,"op":"egg","args":{"pad":"' + b"x" * ((1 << 20) - 200) + b'"}}\n'
    other.send_raw(near)
    rec.equal("a line just under 1 MiB is read", other.read()["error"]["code"], "unknown-op")
    mode = stat.S_IMODE(os.stat(core.socket_path).st_mode)
    rec.equal("socket is private", oct(mode), oct(0o600))


@scenario("0", ops=("hello", "subscribe", "unsubscribe"), topics=TOPICS)
def protocol_subscribe(core, rec):
    peer = core.client()
    reply = peer.call("subscribe", topics=["tasks", "nope"])
    rec.equal("unknown topic", reply["error"]["code"], "bad-args")
    offered = reply["error"]["message"].split("from ", 1)[1].split(", ")
    rec.equal("topics offered", sorted(offered), sorted(TOPICS))
    rec.equal("topics not a list", peer.error("subscribe", topics="tasks"), "bad-args")
    snap = peer.subscribe(*TOPICS)
    rec.equal("result keys", list(snap), ["snapshots", "revs"])
    rec.equal("every topic snapshotted", sorted(snap["snapshots"]), sorted(TOPICS))
    rec.equal("fresh revs are 0", set(snap["revs"].values()), {0})
    for topic in TOPICS:
        rec.see(f"snapshot {topic} keys", list(snap["snapshots"][topic]))
    for topic in ("timers", "tasks", "session", "island", "clips", "core", "supervisor", "view", "ignite", "track"):
        rec.see(f"snapshot {topic}", snap["snapshots"][topic])
    rec.equal("unsubscribe", peer.request("unsubscribe", topics=list(TOPICS)), {})
    rec.equal("unsubscribe with junk", peer.request("unsubscribe", topics="x"), {})


@scenario("0", ops=("hello", "subscribe", "unsubscribe", "task.add"), topics=("tasks",))
def protocol_events(core, rec):
    a, b, c = core.client(), core.client(), core.client()
    a.subscribe("tasks")
    b.subscribe("tasks")
    c.subscribe("tasks")
    c.request("unsubscribe", topics=["tasks"])
    # The event for a change goes out before the reply to the request that made it.
    a.send({"id": 1, "op": "task.add", "args": {"text": "one"}})
    first, second = a.read(), a.read()
    rec.equal("event before reply", (first.get("event"), second.get("id")), ("tasks", 1))
    rec.equal("event shape", list(first), ["event", "rev", "data"])
    rec.equal("rev counts changes", first["rev"], 1)
    rec.equal("others see it", b.event("tasks")["rev"], 1)
    a.request("task.add", text="two")
    rec.equal("next rev", a.event("tasks")["rev"], 2)
    rec.equal("unsubscribed hear nothing", c.drain(0.3), [])
    late = core.client()
    rec.equal("a late subscriber gets the current rev", late.subscribe("tasks")["revs"], {"tasks": 2})
    rec.see("event data", first["data"])


@scenario("0", ops=("hello", "status", "shutdown"))
def lifecycle(core, rec):
    peer = core.client()
    status = peer.request("status")
    rec.equal("status keys", list(status), ["core", "view", "timers", "tasks", "notifications", "overdrive", "session"])
    rec.equal("status core keys", list(status["core"]), ["pid", "rssKiB", "uptime", "host"])
    rec.see("status", status)
    rec.true("under the 25 MiB budget", status["core"]["rssKiB"] < 25 * 1024, status["core"]["rssKiB"])
    rec.equal("shutdown", peer.request("shutdown"), {})
    rec.equal("exits cleanly", core.process.wait(5), 0)
    rec.equal("socket removed", core.socket_path.exists(), False)
    core.start()
    core.stop()
    rec.equal("SIGTERM exits cleanly", core.process.returncode, 0)
    rec.equal("and removes the socket", core.socket_path.exists(), False)


# ----------------------------------------------------------------------------------------------------------------
# Stage 1: plain state


@scenario("1", ops=("timer.start", "timer.toggle", "timer.add", "timer.reset", "timer.ack"), topics=("timers",))
def timers_countdown(core, rec):
    peer = core.client()
    peer.subscribe("timers")
    rec.equal("bad kind", peer.error("timer.start", kind="egg"), "bad-args")
    rec.equal("no length", peer.error("timer.start", kind="countdown"), "bad-args")
    for bad in (0, -5, True, "5", 10 ** 9):
        reply = peer.call("timer.start", kind="countdown", seconds=bad)
        rec.see(f"seconds {bad!r}", reply.get("error", {}).get("code") or reply["result"]["countdown"]["duration"])
    snap = peer.request("timer.start", kind="countdown", seconds=1)
    rec.equal("running", (snap["countdown"]["running"], snap["countdown"]["duration"]), (True, 1.0))
    done = peer.event("timers", lambda d: d["countdown"]["done"] is not None, timeout=5)["data"]
    rec.see("done", done["countdown"])
    rec.equal("notified", core.wait_host_call(lambda c: c[0] == "notify"), ["notify", "Timers", "⏰ Countdown finished"])
    snap = peer.request("timer.ack", kind="countdown")
    rec.equal("ack: full and ready", (snap["countdown"]["done"], snap["countdown"]["running"], snap["countdown"]["elapsed"],
                                      snap["countdown"]["duration"]), (None, False, 0.0, 1.0))
    peer.request("timer.start", kind="countdown", seconds=600)
    snap = peer.request("timer.toggle", kind="countdown")
    rec.equal("paused", snap["countdown"]["running"], False)
    snap = peer.request("timer.add", kind="countdown", seconds=60)
    rec.equal("extended", snap["countdown"]["duration"], 660.0)
    rec.equal("only countdowns extend", peer.error("timer.add", kind="stopwatch", seconds=60), "bad-args")
    snap = peer.request("timer.reset", kind="countdown")
    rec.equal("reset", (snap["countdown"]["duration"], snap["countdown"]["running"]), (0.0, False))
    rec.equal("ack with nothing done", peer.request("timer.ack")["countdown"]["done"], None)
    rec.equal("bad ack kind", peer.error("timer.ack", kind="egg"), "bad-args")
    rec.see("host calls", core.host_calls())


@scenario("1", ops=("timer.start", "timer.toggle", "timer.lap", "timer.reset", "timer.configure"), topics=("timers",))
def timers_stopwatch_pomodoro(core, rec):
    peer = core.client()
    rec.equal("lap while idle adds nothing", peer.request("timer.lap")["stopwatch"]["laps"], [])
    peer.request("timer.start", kind="stopwatch")
    time.sleep(0.05)
    snap = peer.request("timer.lap")
    rec.equal("one lap", len(snap["stopwatch"]["laps"]), 1)
    rec.true("lap is a float", isinstance(snap["stopwatch"]["laps"][0], float))
    snap = peer.request("timer.toggle", kind="stopwatch")
    rec.equal("paused keeps laps", (snap["stopwatch"]["running"], len(snap["stopwatch"]["laps"])), (False, 1))
    rec.equal("reset clears laps", peer.request("timer.reset", kind="stopwatch")["stopwatch"]["laps"], [])
    snap = peer.request("timer.start", kind="pomodoro", focus=600)
    rec.equal("pomodoro", (snap["pomodoro"]["phase"], snap["pomodoro"]["duration"], snap["pomodoro"]["lengths"]["focus"]),
              ("focus", 600.0, 600.0))
    rec.see("pomodoro snapshot", snap["pomodoro"])
    for label, args in (("unknown setting", {"pomodoro": {"lunch": 60}}), ("too short", {"pomodoro": {"focus": 30}}),
                        ("cycles 0", {"pomodoro": {"cycles": 0}}), ("cycles 13", {"pomodoro": {"cycles": 13}}),
                        ("cycles float", {"pomodoro": {"cycles": 2.0}}), ("not an object", {"pomodoro": 5}),
                        ("sound not bool", {"sound": 1})):
        rec.equal(label, peer.error("timer.configure", **args), "bad-args")
    snap = peer.request("timer.configure", pomodoro={"break": 420, "cycles": 3}, sound=True)
    rec.equal("configured", (snap["config"]["pomodoro"], snap["config"]["sound"], snap["sound"]),
              ({"focus": 1500, "break": 420, "longBreak": 900, "cycles": 3}, True, True))
    rec.equal("the running phase keeps its length", snap["pomodoro"]["duration"], 600.0)
    snap = peer.request("timer.reset", kind="pomodoro")
    rec.equal("reset takes the new lengths", (snap["pomodoro"]["duration"], snap["pomodoro"]["lengths"]["break"]), (1500, 420))
    rec.see("snapshot", snap)


@scenario("1", ops=("timer.start", "timer.toggle", "timer.configure"), topics=("timers",))
def timers_survive_restart(core, rec):
    peer = core.client()
    peer.request("timer.configure", pomodoro={"focus": 1200})
    peer.request("timer.start", kind="countdown", seconds=300)
    time.sleep(0.2)
    paused = peer.request("timer.toggle", kind="countdown")["countdown"]
    peer.request("timer.start", kind="stopwatch")
    saved = core.state("timers.json")
    rec.file("timers.json", core.state_bytes("timers.json"))
    peer.close()
    core.restart()
    snap = core.client().subscribe("timers")["snapshots"]["timers"]
    rec.same("paused countdown kept exactly", (snap["countdown"]["running"], snap["countdown"]["elapsed"],
                                               snap["countdown"]["duration"]),
             (False, paused["elapsed"], 300.0))
    rec.equal("stopwatch still running", snap["stopwatch"]["running"], True)
    rec.equal("config kept", snap["config"]["pomodoro"]["focus"], 1200)
    rec.same("file untouched by the restart", core.state("timers.json"), saved)


@scenario("1", ops=("task.add", "task.update", "task.move", "task.remove", "task.restore", "list.add", "list.rename",
                    "list.remove"), topics=("tasks",))
def tasks_ops(core, rec):
    peer = core.client()
    for label, args in (("empty", {"text": "  "}), ("not text", {"text": 5}), ("too long", {"text": "x" * 1001}),
                        ("bad due", {"text": "a", "due": "tomorrow"}), ("not a date", {"text": "a", "due": "2026-02-30"}),
                        ("bad time", {"text": "a", "due": "2026-02-03T25:00"}), ("index -1", {"text": "a", "index": -1}),
                        ("index bool", {"text": "a", "index": True}), ("index float", {"text": "a", "index": 1.0})):
        rec.equal(label, peer.error("task.add", **args), "bad-args")
    rec.equal("no such list", peer.error("task.add", text="a", list="lnope"), "not-found")
    rec.equal("1000 characters is fine", len(peer.request("task.add", text="y" * 1000)["task"]["text"]), 1000)
    a = peer.request("task.add", text="  alpha  ", due="2026-12-01")["task"]
    rec.see("added", a)
    rec.equal("trimmed", a["text"], "alpha")
    b = peer.request("task.add", text="beta", due="2026-12-01T09:30", index=0)["task"]
    shop = peer.request("list.add", name="Shop")["list"]
    rec.see("list", shop)
    c = peer.request("task.add", text="milk", list=shop["id"])["task"]
    rec.equal("order", [t["text"] for t in peer.subscribe("tasks")["snapshots"]["tasks"]["tasks"]],
              ["beta", "y" * 1000, "alpha", "milk"])
    done = peer.request("task.update", id=a["id"], done=True)["task"]
    rec.true("doneAt set", isinstance(done["doneAt"], int))
    rec.equal("undone", peer.request("task.update", id=a["id"], done=False)["task"]["doneAt"], None)
    rec.equal("done not bool", peer.error("task.update", id=a["id"], done=1), "bad-args")
    rec.equal("clear due", peer.request("task.update", id=a["id"], due=None)["task"]["due"], None)
    rec.equal("unknown change", peer.error("task.update", id=a["id"], colour="red"), "bad-args")
    rec.equal("no such task", peer.error("task.update", id="t00000000", text="x"), "not-found")
    moved = peer.request("task.update", id=b["id"], list=shop["id"])["task"]
    rec.equal("moved list", moved["list"], shop["id"])
    rec.see("move", peer.request("task.move", id=c["id"], index=5))
    rec.equal("bad move index", peer.error("task.move", id=c["id"], index=-2), "bad-args")
    removed = peer.request("task.remove", id=c["id"])
    rec.see("removed", removed)
    rec.equal("restore conflict first", peer.error("task.restore", task=a), "conflict")
    rec.equal("restore junk", peer.error("task.restore", task={"id": "x"}), "bad-args")
    restored = peer.request("task.restore", task=removed["task"], index=removed["index"])["task"]
    rec.equal("restored as it was", restored, removed["task"])
    rec.equal("rename", peer.request("list.rename", id=shop["id"], name=" Shopping ")["list"]["name"], "Shopping")
    rec.equal("long name", peer.error("list.rename", id=shop["id"], name="n" * 65), "bad-args")
    rec.equal("default stays", peer.error("list.remove", id="default"), "conflict")
    rec.equal("list removed", peer.request("list.remove", id=shop["id"]), {})
    final = peer.subscribe("tasks")["snapshots"]["tasks"]
    rec.equal("tasks moved home", {t["list"] for t in final["tasks"]}, {"default"})
    rec.see("final", final)
    rec.equal("file matches the snapshot", {k: v for k, v in core.state("tasks.json").items() if k != "version"}, final)


@scenario("1", ops=("task.add",), topics=("tasks",),
          seed={"todo.json": [{"content": " one ", "done": False}, {"content": "two", "done": True}, {"content": ""},
                              {"done": True}, "junk"]})
def tasks_migrate_and_bytes(core, rec):
    peer = core.client()
    rows = peer.subscribe("tasks")["snapshots"]["tasks"]["tasks"]
    rec.equal("migrated", [(t["text"], t["done"], t["created"]) for t in rows], [("one", False, None), ("two", True, None)])
    peer.request("task.add", text="naïve ☕ “quotes” \\ back \u2028 line")
    peer.close()
    before = core.state_bytes("tasks.json")
    rec.file("tasks.json", before)
    rec.true("ASCII escapes, compact", before.isascii() and b", " not in before and b": " not in before)
    core.restart()
    core.client().subscribe("tasks")
    rec.same("a restart rewrites nothing", core.state_bytes("tasks.json"), before)
    rec.equal("todo.json left alone", core.state("todo.json")[1], {"content": "two", "done": True})


@scenario("1", topics=("tasks",), seed={"tasks.json": "{not json"})
def tasks_invalid_file(core, rec):
    rows = core.client().subscribe("tasks")["snapshots"]["tasks"]
    rec.equal("fresh lists", rows, {"lists": [{"id": "default", "name": "Tasks"}], "tasks": []})
    rec.equal("kept aside", core.state_bytes("tasks.json.invalid"), b'"{not json"')


@scenario("1", ops=("session.start", "session.end", "session.dismiss"), topics=("session",))
def sessions(core, rec):
    peer = core.client()
    peer.subscribe("session")
    for label, args in (("bad name", {"preset": "Focus!"}), ("unknown without length", {"preset": "nap"}),
                        ("too short", {"preset": "nap", "seconds": 59}), ("too long", {"preset": "nap", "seconds": 12 * 3600 + 1}),
                        ("bool length", {"preset": "nap", "seconds": True})):
        rec.equal(label, peer.error("session.start", **args), "bad-args")
    rec.equal("nothing to end", peer.error("session.end"), "not-found")
    snap = peer.request("session.start", preset="nap", seconds=600)
    rec.see("started", snap)
    rec.equal("active", (snap["active"]["preset"], snap["active"]["seconds"]), ("nap", 600))
    rec.equal("one at a time", peer.error("session.start", preset="focus"), "conflict")
    rec.equal("DND on", core.wait_host_call(lambda c: c[0] == "dnd"), ["dnd", "on"])
    rec.file("session.json", core.state_bytes("session.json"))
    time.sleep(0.2)
    snap = peer.request("session.end")
    rec.see("ended", snap)
    rec.equal("debrief", (snap["active"], snap["last"]["preset"], snap["last"]["completed"]), (None, "nap", False))
    rec.equal("DND back off", core.wait_host_call(lambda c: c == ["dnd", "off"]), ["dnd", "off"])
    rec.equal("dismissed", peer.request("session.dismiss")["last"], None)
    rec.equal("logged", [e["preset"] for e in map(json.loads, core.state_bytes("sessions.jsonl").splitlines())], ["nap"])
    rec.file("sessions.jsonl", core.state_bytes("sessions.jsonl"))
    rec.see("host calls", core.host_calls())


@scenario("1", ops=("island.rest", "clips.set"), topics=("island", "clips"))
def island_and_clips(core, rec):
    peer = core.client()
    peer.subscribe("island", "clips")
    rec.equal("bad mode", peer.error("island.rest", item="power", mode="never"), "bad-args")
    rec.equal("bad item", peer.error("island.rest", item="toaster", mode="always"), "bad-args")
    rec.equal("unread only for inbox", peer.error("island.rest", item="power", mode="unread"), "bad-args")
    snap = peer.request("island.rest", item="inbox", mode="unread")
    rec.equal("rest", snap["rest"]["inbox"], "unread")
    rec.equal("event", peer.event("island")["data"]["rest"]["inbox"], "unread")
    peer.request("island.rest", item="inbox", mode="unread")
    rec.equal("no change, no event", [m for m in peer.drain(0.3) if m.get("event") == "island"], [])
    for key, value in (("rows", 3), ("rows", 11), ("rows", True), ("rows", 6.0), ("enterPastes", 1), ("showImages", "no"),
                       ("colour", "red")):
        rec.equal(f"clips {key}={value!r}", peer.error("clips.set", key=key, value=value), "bad-args")
    rec.equal("clips rows", peer.request("clips.set", key="rows", value=10), {"enterPastes": False, "rows": 10, "showImages": True})
    peer.request("clips.set", key="enterPastes", value=True)
    rec.file("island.json", core.state_bytes("island.json"))
    rec.file("clips.json", core.state_bytes("clips.json"))
    peer.close()
    core.restart()
    snap = core.client().subscribe("island", "clips")["snapshots"]
    rec.equal("kept", (snap["island"]["rest"]["inbox"], snap["clips"]["rows"], snap["clips"]["enterPastes"]), ("unread", 10, True))


# Lines that never open the view (a bare room verb would try to spawn it). Each reply is compared whole.
COMMAND_LINES = (
    "", "   ", "?", "t", "zzz", "TIM 25", "tim 90s", "tim 45s", "tim 1h30", "tim 1m30s", "tim 2h10m15s", "tim 5x",
    "tim 25 26", "tim lap", "tim pause", "tim stop", "sw", "sw now", "focus", "focus 50", "focus 50 60", "tim focus 30",
    "task buy milk !tomorrow", "task call mum !fri", "task plan !+3d", "task trip !+2w", "task x !2026-02-30",
    "task y !someday", "task @Tasks z !today", "task  spaced   words  ", "isl", "island rest power never",
    "island rest inbox unread", "task " + "w" * 1001,
)


@scenario("1", ops=("cmd.run", "cmd.complete", "cmd.history"), topics=("tasks", "timers"),
          tz="Asia/Kolkata", env={"FART_FIXTURE_EPOCH": str(epoch(2026, 11, 23, 20, 0))})
def commands(core, rec):
    # 23 Nov 20:00 UTC is 24 Nov 01:30 in Kolkata (a Tuesday): the verbs' "today" is the local one.
    peer = core.client()
    for line in COMMAND_LINES:
        reply = peer.call("cmd.run", line=line)
        rec.see(f"run {line[:40]!r}", reply.get("result", reply.get("error")))
    dues = [t["due"] for t in peer.subscribe("tasks")["snapshots"]["tasks"]["tasks"]]
    rec.equal("local dates", dues, ["2026-11-25", "2026-11-27", "2026-11-27", "2026-12-08", "2026-11-24", None])
    for bad in ({"line": 5}, {"line": "x" * 5000}, {"line": "?", "record": "yes"}, {"line": "?", "fallthrough": 1}):
        rec.see(f"cmd.run {list(bad)}", peer.error("cmd.run", **bad))
    for text in ("", "t", "ta", "tim ", "task bu", "is", "zz", "?"):
        rec.see(f"complete {text!r}", peer.request("cmd.complete", text=text))
    peer.request("cmd.run", line="tim 25", record=True)
    peer.request("cmd.run", line="tim  5", record=True)
    peer.request("cmd.run", line="tim 25", record=True)
    rec.equal("history, newest last", peer.request("cmd.history")["lines"], ["tim 5", "tim 25"])
    rec.equal("history prefix", peer.request("cmd.history", prefix="tim 2")["lines"], ["tim 25"])
    rec.see("history limit", peer.request("cmd.history", limit=1))


# The DST trap: Europe/London went to summer time at 01:00 UTC on 29 March 2026. A session at 23:30 UTC on the
# 29th is 00:30 on the 30th locally; the two before it (27th, 28th, still GMT) stay on their own days. A core that
# applies one fixed offset to every timestamp gets a three-day streak instead of 1 (best 2).
@scenario("1", topics=("session",), tz="Europe/London", env={"FART_FIXTURE_EPOCH": str(epoch(2026, 3, 30, 11, 0))},
          seed={"sessions.jsonl": "".join(json.dumps({"preset": "focus", "start": ms(2026, 3, d, 23, 30), "seconds": 1200}) + "\n"
                                          for d in (27, 28, 29)) + "not json\n" + json.dumps({"preset": 5}) + "\n"})
def time_zone_dst(core, rec):
    streak = core.client().subscribe("session")["snapshots"]["session"]["streak"]
    rec.equal("streak across the DST change", (streak["current"], streak["best"]), (1, 2))
    rec.equal("strip, 17th to 30th March", streak["minutes"], [0] * 10 + [20, 20, 0, 20])


# New York left summer time at 06:00 UTC on 1 November 2026. "Now", 04:30 UTC on the 2nd, is 23:30 EST on 1 Nov.
# Sessions: 03:30 UTC on the 1st is 23:30 EDT on 31 Oct; 05:30 UTC is 01:30 EDT on 1 Nov; 04:30 UTC on the 2nd is
# 23:30 EST on 1 Nov. A core using today's offset (EST) for all of them still agrees; one using EDT puts the last on
# 2 November and makes "today" the 2nd.
@scenario("1", topics=("session",), tz="America/New_York", env={"FART_FIXTURE_EPOCH": str(epoch(2026, 11, 2, 4, 30))},
          seed={"sessions.jsonl": "".join(json.dumps({"preset": "deep", "start": ms(2026, 11, d, h, 30), "seconds": 900}) + "\n"
                                          for d, h in ((1, 3), (1, 5), (2, 4)))})
def time_zone_dst_fall(core, rec):
    streak = core.client().subscribe("session")["snapshots"]["session"]["streak"]
    rec.equal("streak", (streak["current"], streak["best"]), (2, 2))
    rec.equal("strip ends 31 Oct, 1 Nov", streak["minutes"][-2:], [15, 30])


@scenario("1", ops=("cmd.run",), topics=("tasks",), tz="America/New_York",
          env={"FART_FIXTURE_EPOCH": str(epoch(2026, 11, 1, 5, 30))})
def time_zone_due_on_dst_day(core, rec):
    # 05:30 UTC on 1 Nov is 01:30 EDT, half an hour before the clocks go back: "today" is 1 November.
    peer = core.client()
    for line in ("task a !today", "task b !tomorrow", "task c !sun", "task d !+1w"):
        peer.request("cmd.run", line=line)
    dues = [t["due"] for t in peer.subscribe("tasks")["snapshots"]["tasks"]["tasks"]]
    rec.equal("dates", dues, ["2026-11-01", "2026-11-02", "2026-11-08", "2026-11-08"])


@scenario("1", topics=("core",), env={"FART_FIXTURE_EPOCH": "1000000000"})
def fixture_clock(core, rec):
    started = core.client().subscribe("core")["snapshots"]["core"]["startedAt"]
    rec.true("the fixture clock moves the core's wall clock", abs(started - 1_000_000_000_000) < 30_000, started)


__all__ = ["SCENARIOS", "Scenario", "Record", "run_scenario", "CoreGone", "TOPICS"]
