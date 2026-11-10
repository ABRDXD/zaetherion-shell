"""Host calls: the core asks the view's adapter to act, holding a lease only for the call (docs/M5-COMMAND.md §3).

The adapter lives in the view, so a verb such as `vol 40` reaches PipeWire through it. One call is one
`view.host` event and one `host.done` reply:

    core → view   {"event": "view.host", "data": {token, domain, method, args, lease, ready, read, hold, linger}}
    view → core   host.done {token, ok, result: {read}, error?: {code, message}}

The view (core/client/CoreHostCalls.qml) acquires `lease` under its own owner key, waits until the domain
is available and `ready` names a truthy property, calls `method(...args)`, waits `hold` seconds so the
change is applied while the object is still bound, reads `read` and answers. It releases `linger` seconds
after answering, so a follow-up call keeps the object bound. An argument {"$": "output.id"} is resolved on
the domain at call time.

Only the (domain, method) pairs below can be called, so the core never sends a lease or log method.
"""
from __future__ import annotations

import asyncio
import logging
import re

from core.errors import OpError

log = logging.getLogger("fart.hostcalls")

# None means a read-only call: lease, wait, read, release.
CALLS = {
    "audio": {None, "setVolume", "setMuted", "setDefault"},
    "power": {None, "setBrightness", "setProfile", "lock"},
    "network": {None, "setWifiEnabled"},
    "bluetooth": {None, "setEnabled"},
    "media": {None, "togglePlaying", "next", "previous"},
    "hostActions": {None, "open", "openLauncher"},
}
LEASES = {"audio": {"mixer"}, "power": {"brightness"}}
PATH = re.compile(r"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*){0,3}$")
REPLY_TIMEOUT = 5.0  # the view waits up to 2 s for readiness, then holds; this bounds a lost reply
HOLD = 0.3


class HostCalls:
    def __init__(self, view, timeout: float = REPLY_TIMEOUT):
        self.view = view
        self.timeout = timeout
        self.next_token = 0
        self.pending: dict[int, tuple[asyncio.Future, object]] = {}

    @staticmethod
    def _check(domain, method, args, lease, ready, read):
        if domain not in CALLS or method not in CALLS[domain]:
            raise OpError("bad-args", f"{domain}.{method} is not a host call")
        if lease is not None and lease not in LEASES.get(domain, ()):
            raise OpError("bad-args", f"{domain} has no lease {lease!r}")
        for path in (ready, read):
            if path is not None and not PATH.match(path):
                raise OpError("bad-args", f"bad property path {path!r}")
        for arg in args:
            if isinstance(arg, dict) and not (set(arg) == {"$"} and PATH.match(str(arg["$"]))):
                raise OpError("bad-args", "a reference argument is {\"$\": path}")

    async def call(self, domain: str, method: str | None = None, args=(), lease: str | None = None,
                   ready: str | None = None, read: str | None = None, hold: float = HOLD, linger: float = 0.0):
        """Returns the value of `read` after the call (None when not asked). Spawns the view, closed, if absent."""
        args = list(args)
        self._check(domain, method, args, lease, ready, read)
        await self.view.ensure()
        client = self.view.client
        if client is None or client.closed:
            raise OpError("unavailable", "the view is not connected")
        self.next_token += 1
        token = self.next_token
        future = asyncio.get_running_loop().create_future()
        self.pending[token] = (future, client)
        client.send({"event": "view.host", "rev": 0, "data": {
            "token": token, "domain": domain, "method": method, "args": args, "lease": lease,
            "ready": ready, "read": read, "hold": round(hold * 1000), "linger": round(linger * 1000)}})
        try:
            return await asyncio.wait_for(future, self.timeout)
        except asyncio.TimeoutError:
            log.warning("host call %s.%s got no reply", domain, method)
            raise OpError("unavailable", f"the view did not answer {domain}") from None
        finally:
            self.pending.pop(token, None)

    def done(self, peer, token, ok, result=None, error=None):
        """host.done from the view."""
        if peer is not self.view.client:
            raise OpError("refused", "only the view answers host calls")
        entry = self.pending.get(token) if isinstance(token, int) else None
        if entry is None or entry[0].done():
            return  # late: the caller already timed out
        future = entry[0]
        if ok is True:
            future.set_result((result or {}).get("read") if isinstance(result, dict) else None)
        else:
            error = error if isinstance(error, dict) else {}
            code = error.get("code") if error.get("code") in ("unavailable", "bad-args", "not-found") else "unavailable"
            future.set_exception(OpError(code, str(error.get("message") or "the host refused")[:200]))

    def disconnected(self, client):
        for future, sent_to in list(self.pending.values()):
            if sent_to is client and not future.done():
                future.set_exception(OpError("unavailable", "the view disconnected"))
