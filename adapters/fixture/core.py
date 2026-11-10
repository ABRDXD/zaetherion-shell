"""Inert host profile for tests and the smoke run: records commands instead of running them.

With FART_FIXTURE_LOG set, each command is also appended there as one JSON line, so a test can watch
a core running in another process.
"""
import json
import os


class HostProfile:
    name = "fixture"

    def __init__(self):
        self.calls = []
        self.muted = False
        self.volume = 1.0
        self.dnd_on = False
        self.silent = set()  # cues the fixture host has no file for
        self.place = {"lat": 51.4769, "lon": 0.0, "name": "Greenwich"}  # None: a host without a location
        self.log = os.environ.get("FART_FIXTURE_LOG")
        self.focus_spans = None  # [[app class, seconds]]: what the host's focus tracker would say, or None

    def sfx(self):
        return self.muted, self.volume

    def dnd(self):
        return self.dnd_on

    def set_dnd(self, on):
        self.dnd_on = on
        self.record(["dnd", "on" if on else "off"])
        return True

    def play_command(self, cue, gain):
        return None if cue in self.silent else ["play", cue, f"{gain:.3f}"]

    def play_file_command(self, path, gain):
        return None  # generated exhibition audio is inert in fixtures

    def notify_command(self, summary, body):
        return ["notify", summary, body]

    def focus(self, start_ms, end_ms):
        return self.focus_spans

    def location(self):
        return self.place

    def before_open_command(self):
        return None

    def record(self, argv):
        self.calls.append(argv)
        if self.log:
            with open(self.log, "a") as out:
                out.write(json.dumps(argv) + "\n")
