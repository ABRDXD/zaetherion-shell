"""The command line's grammar: one verb registry for the view's command line and the CLI (docs/M5-COMMAND.md).

A line is `verb [args…]`. The first word matches an exact name or alias, else a unique prefix, else an
ambiguous prefix ranked by history (the top one runs only if used at least twice as often as the next).
Anything else falls through to the host launcher, for the view's command line only; the CLI gets a usage
error instead. A bare verb opens its room; a verb with arguments acts.
"""
from __future__ import annotations

from collections import Counter
import logging
import os
from pathlib import Path

from core.errors import OpError
from core.store import read_json, write_json
from core.verbs import clips, equalizer, exhibit, hostactions, island, palette, media, modes, rooms, system, tasks, timers, wallpaper, presets
from core.verbs.base import Result, Usage, Verb

log = logging.getLogger("fart.command")
DOMAINS = (rooms, timers, tasks, modes, island, palette, wallpaper, presets, equalizer, exhibit, media, system, clips, hostactions)
MAX_LINE = 1000
HISTORY = 100
# Launcher pages (after cmdk, owner 15 November 2026): Enter on a bare verb in the launcher opens its choices as moons.
# A verb's page is its genuine choices: listed here where the usage alone can't say, else its examples with arguments.
# Verbs that take free text get no page (their examples are samples, not choices: "task buy milk" would add a task).
PAGE_CHOICES = {
    "vol": ("0", "20", "40", "60", "80", "100", "+5", "-5"),
    "bri": ("20", "40", "60", "80", "100", "+10", "-10"),
    "eq": ("on", "off", "mono", "stereo", "flat", "bass", "treble", "vocal", "loudness"),
    "island": ("fluid", "angular", "top", "bottom", "notch", "floating", "screen auto"),
    "tim": ("25", "50", "90s", "focus", "sw", "lap", "pause", "stop"),
    "focus": ("25", "50"),
    "overdrive": ("20m", "sticky", "off"),
    "power": ("perf", "bal", "save"),
    "wifi": ("on", "off"),
    "bt": ("on", "off"),
    "wall": ("list", "next", "prev"),
    "look": ("list",),
    "palette": ("list",),
    "go": ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"),
}
PAGE_FREE_TEXT = {"task", "clip", "out"}
ROOM_LABELS = {"home": "Home", "media": "Media", "performance": "Performance", "workspaces": "Workspaces",
               "devices": "Devices", "tasks": "Tasks", "timers": "Timers", "clipboard": "Clips",
               "notifications": "Inbox", "codex": "Codex"}


class Context:
    """What a verb may use: the core's subsystems, room navigation and host calls through the view."""

    def __init__(self, core, commands: "Commands", source: str):
        self.core = core
        self.commands = commands
        self.source = source

    def now(self):
        return self.core.clock.now()

    async def room(self, page: str) -> Result:
        await self.core.view.command("open", page)
        return Result(f"→ {ROOM_LABELS.get(page, page)}", "info", {"page": page})

    async def orbit(self, target: str) -> Result:
        """Open the orbit and fly to a moon by name; the view resolves it (only the view knows the moons)."""
        await self.core.view.command("open", None, fly=target)
        return Result("→ the orbit" + (f" · {target}" if target else ""), "info", {"fly": target})

    async def settings(self, section: str) -> Result:
        """FART's own settings at one section; nothing opens outside FART (Z162, Z177)."""
        view = self.core.view
        if not (view.state == "ready" and view.open):
            self.core._before_open()
        await view.command("open", view.page or "home", settings=section)
        return Result(f"→ settings · {section}", "info", {"settings": section})

    async def host(self, domain: str, method: str | None = None, args=(), **options):
        return await self.core.hostcalls.call(domain, method, args, **options)

    async def fold(self):
        """Host popups open under FART's layer, so the panel folds before one opens.

        Sent whenever a view is connected, not only when it has reported open: the report lags the
        open (the fixture view sends it after the room loads), and a fast type-and-Enter must not open
        the launcher under a panel that is still unfolding. A close on a closed panel is a no-op.
        """
        view = self.core.view
        if view.state == "ready":
            await view.command("close")


def common_prefix(names: list[str]) -> str:
    return os.path.commonprefix(names) if names else ""


class Commands:
    def __init__(self, core, state_dir: Path, verbs: list[Verb] | None = None, on_result=lambda source, result: None):
        self.core = core
        self.on_result = on_result  # the core turns view results into cmd.ok / cmd.error cues
        builtin = Verb("?", "help", "? [verb]", "lists the verbs, or one verb's grammar", ("?", "? vol"),
                       self._help, aliases=("help",), record=False)
        self.verbs = [*(verbs if verbs is not None else [v for d in DOMAINS for v in d.VERBS]), builtin]
        self.names: dict[str, Verb] = {}
        for verb in self.verbs:
            for name in (verb.name, *verb.aliases):
                if name in self.names:
                    raise ValueError(f"verb name {name!r} is registered twice")
                self.names[name] = verb
        self.path = state_dir / "history.json"
        self.history = self._load()

    # History: the last 100 lines that ran from the command line, newest last, 0600.

    def _load(self) -> list[str]:
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            log.warning("history.json is not JSON; starting empty")
            return []
        lines = saved.get("lines") if isinstance(saved, dict) else None
        return [line for line in lines if isinstance(line, str)][-HISTORY:] if isinstance(lines, list) else []

    def _remember(self, line: str):
        self.history = [*(l for l in self.history if l != line), line][-HISTORY:]
        write_json(self.path, {"version": 1, "lines": self.history})

    def counts(self) -> Counter:
        counts = Counter()
        for line in self.history:
            verb = self.names.get(line.split()[0].lower()) if line.split() else None
            if verb:
                counts[verb.name] += 1
        return counts

    def recent(self, prefix: str = "", limit: int = HISTORY) -> dict:
        if not isinstance(prefix, str) or isinstance(limit, bool) or not isinstance(limit, int) or limit < 1:
            raise OpError("bad-args", "prefix must be a string and limit a positive integer")
        return {"lines": [l for l in self.history if l.startswith(prefix)][-limit:]}

    # Matching

    def resolve(self, word: str) -> tuple[Verb | None, list[Verb]]:
        """(verb, candidates). A verb with no candidates is an exact or unique match."""
        word = word.lower()
        if word in self.names:
            return self.names[word], []
        matches: list[Verb] = []
        for name, verb in self.names.items():
            if name.startswith(word) and verb not in matches:
                matches.append(verb)
        if len(matches) <= 1:
            return (matches[0] if matches else None), []
        counts = self.counts()
        ranked = sorted(matches, key=lambda v: (-counts[v.name], v.name))
        top, second = counts[ranked[0].name], counts[ranked[1].name]
        if top > 0 and top >= 2 * second:
            return ranked[0], ranked
        return None, ranked

    def inline(self, text: str) -> dict | None:
        """The launcher's verb row (Z195): an exact verb name, or a unique prefix with arguments ("vol 40"). A bare
        prefix is left to the apps, so "fi" finds Firefox before any verb."""
        words = text.split() if isinstance(text, str) and len(text) <= MAX_LINE else []
        if not words or words[0].startswith(("?", ">")):
            return None
        verb, ranked = self.resolve(words[0])
        if verb is None or ranked or (len(words) == 1 and words[0].lower() not in self.names):
            return None
        return {"verb": verb.name, "usage": verb.usage, "summary": verb.summary}

    def page(self, name) -> dict:
        """A verb's launcher page: {verb, usage, summary, options: [{line, label}]}; no options when it has none."""
        verb, ranked = self.resolve(name) if isinstance(name, str) and name.strip() else (None, [])
        if verb is None or ranked:
            raise OpError("bad-args", f"no verb {name!r}")
        if verb.name in PAGE_FREE_TEXT:
            labels = []
        elif verb.name == "session":   # the presets the core knows, then end
            presets = self.core.sessions.snapshot().get("presets", []) if self.core else []
            labels = [p["name"] for p in presets] + ["end"]
        elif verb.name in PAGE_CHOICES:
            labels = list(PAGE_CHOICES[verb.name])
        else:
            labels = [e.split(" ", 1)[1] for e in verb.examples if " " in e]
        return {"verb": verb.name, "usage": verb.usage, "summary": verb.summary,
                "options": [{"line": f"{verb.name} {label}", "label": label} for label in labels]}

    def complete(self, text: str) -> dict:
        """The live hint while typing: the matched verb's grammar, or the candidates and their common prefix."""
        if not isinstance(text, str) or len(text) > MAX_LINE:
            raise OpError("bad-args", f"text must be a string of at most {MAX_LINE} characters")
        words = text.split()
        if not words:
            return {"verb": None, "usage": None, "candidates": [], "complete": ""}
        verb, ranked = self.resolve(words[0])
        candidates = ranked or ([verb] if verb else [])
        return {"verb": verb.name if verb else None, "usage": verb.usage if verb else None,
                "candidates": [{"name": v.name, "usage": v.usage, "summary": v.summary} for v in candidates],
                "complete": common_prefix([v.name for v in candidates]) if ranked else (verb.name if verb else "")}

    # Running

    async def run(self, line, source: str = "cli", fallthrough: bool | None = None, record: bool | None = None) -> dict:
        result = await self._run(line, source, fallthrough, record)
        self.on_result(source, result)
        return result

    async def _run(self, line, source, fallthrough, record) -> dict:
        if not isinstance(line, str) or len(line) > MAX_LINE:
            raise OpError("bad-args", f"line must be a string of at most {MAX_LINE} characters")
        for name, flag in (("fallthrough", fallthrough), ("record", record)):
            if flag is not None and not isinstance(flag, bool):
                raise OpError("bad-args", f"{name} must be a boolean")
        fallthrough = source == "view" if fallthrough is None else fallthrough
        record = source == "view" if record is None else record
        words = line.split()
        if not words:
            return self._error("usage", "type a verb; ? lists them")
        verb, ranked = self.resolve(words[0])
        if verb is None and ranked:
            names = [v.name for v in ranked]
            return {"ok": False, "tone": "info", "code": "ambiguous", "line": f"{words[0]}: {' · '.join(names)}?",
                    "candidates": names, "complete": common_prefix(names)}
        if verb is None:
            if not fallthrough:
                return self._error("usage", f"unknown verb {words[0]!r}; ? lists them")
            return await self._fallthrough(line.strip())
        try:
            result = await verb.run(Context(self.core, self, source), words[1:])
        except Usage as error:
            return {**self._error("usage", str(error)), "verb": verb.name}
        except OpError as error:
            return {**self._error(error.code, error.message), "verb": verb.name}
        if record and verb.record:
            self._remember(" ".join(words))
        return {"ok": True, "tone": result.tone, "line": result.line, "verb": verb.name, "data": result.data or {}}

    @staticmethod
    def _error(code: str, message: str) -> dict:
        return {"ok": False, "tone": "error", "code": code, "line": message}

    async def _fallthrough(self, text: str) -> dict:
        context = Context(self.core, self, "view")
        try:
            await context.fold()
            await context.host("hostActions", "openLauncher", [text], hold=0)
        except OpError as error:
            return self._error(error.code, error.message)
        return {"ok": True, "tone": "info", "line": "", "verb": None, "fallthrough": "launcher", "data": {}}

    async def _help(self, context, words) -> Result:
        if words:
            verb, _ = self.resolve(words[0])
            if verb is None:
                raise Usage(f"no verb {words[0]!r}; ? lists them")
            aliases = f" (also {', '.join(verb.aliases)})" if verb.aliases else ""
            return Result(f"{verb.usage}{aliases}: {verb.summary}. e.g. {', '.join(verb.examples)}", "info",
                          {"verb": verb.name, "usage": verb.usage, "examples": list(verb.examples)})
        domains: dict[str, list[str]] = {}
        for verb in self.verbs:
            domains.setdefault(verb.domain, []).append(verb.name)
        return Result("\n".join(f"{domain}: {' '.join(names)}" for domain, names in domains.items()), "info",
                      {"domains": domains})
