"""Track changes from MPRIS, read off the core's busctl monitor (Q8: the track satellite with the view reaped).

Read-only: FART never calls a player. Titles are kept in memory only, never logged or written to disk.
A change is a new (trackid, title, artist) from a player that is playing. Metadata that arrives while a
player is paused is announced when it starts playing; the same track sent again is not a change.
"""
from __future__ import annotations

import logging

log = logging.getLogger("fart.track")
PREFIX = "org.mpris.MediaPlayer2."
PLAYER = PREFIX + "Player"
PATH = "/org/mpris/MediaPlayer2"
BUS = "org.freedesktop.DBus"
MATCHES = [f"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='{PATH}',arg0='{PLAYER}'",
           f"type='signal',sender='{BUS}',interface='{BUS}',member='NameOwnerChanged',arg0namespace='{PREFIX[:-1]}'"]
LIMIT = 256


def player_name(bus_name: str) -> str:
    """org.mpris.MediaPlayer2.chromium.instance1234 → chromium."""
    return bus_name[len(PREFIX):].split(".", 1)[0][:64] if bus_name.startswith(PREFIX) else bus_name[:64]


def value(fields: dict, key: str):
    entry = fields.get(key)
    return entry.get("data") if isinstance(entry, dict) else None


class Player:
    def __init__(self):
        self.name = ""
        self.status = None  # Playing | Paused | Stopped | None (not seen yet)
        self.key = None  # (trackid, title, artist) last seen
        self.announced = None


class Track:
    def __init__(self, clock):
        self.clock = clock
        self.on_change = lambda: None  # the `track` topic
        self.on_track = lambda: None  # a new track is playing (the core may spawn the view for it)
        self.players: dict[str, Player] = {}  # by unique bus name
        self.current = None  # {player, artist, title, at}

    def snapshot(self) -> dict:
        return dict(self.current) if self.current else {"player": None, "artist": None, "title": None, "at": None}

    def started(self, owners: dict[str, str]):
        """owners: unique name → well-known MPRIS name, as found when the monitor started."""
        self.players = {}
        for unique, name in owners.items():
            self.players.setdefault(unique, Player()).name = player_name(name)

    def stopped(self):
        self.players = {}

    def feed(self, message: dict):
        if message.get("type") != "signal":
            return
        data = (message.get("payload") or {}).get("data") or []
        member, sender = message.get("member"), message.get("sender")
        if member == "NameOwnerChanged" and sender == BUS:
            if len(data) == 3 and isinstance(data[0], str) and data[0].startswith(PREFIX):
                name, old, new = data
                self.players.pop(old, None)
                if new:
                    self.players.setdefault(new, Player()).name = player_name(name)
        elif (member == "PropertiesChanged" and message.get("path") == PATH and len(data) >= 2
              and data[0] == PLAYER and isinstance(data[1], dict) and isinstance(sender, str)):
            self._changed(sender, data[1])

    def _changed(self, sender: str, changed: dict):
        player = self.players.setdefault(sender, Player())
        if not player.name:
            player.name = sender[:64]
        status = value(changed, "PlaybackStatus")
        if isinstance(status, str):
            player.status = status
        metadata = value(changed, "Metadata")
        if isinstance(metadata, dict):
            title = value(metadata, "xesam:title")
            artist = value(metadata, "xesam:artist")
            artist = ", ".join(a for a in artist if isinstance(a, str)) if isinstance(artist, list) else artist
            trackid = value(metadata, "mpris:trackid")
            if isinstance(title, str) and title.strip():
                player.key = (trackid if isinstance(trackid, str) else None, title.strip()[:LIMIT],
                              artist.strip()[:LIMIT] if isinstance(artist, str) else "")
        if player.key and player.key != player.announced and player.status in (None, "Playing"):
            player.announced = player.key
            now = self.clock.now()
            self.current = {"player": player.name, "artist": player.key[2] or None, "title": player.key[1],
                            "at": round(now.real * 1000)}
            self.on_change()
            self.on_track()
