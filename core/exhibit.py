"""The Fold: a numeric-only score compiler and temporary exhibition lifecycle."""
from __future__ import annotations
import asyncio
import json
import math
import os
from pathlib import Path
import struct
from core.errors import OpError

ROOMS = ('home', 'media', 'performance', 'workspaces', 'devices', 'tasks', 'timers', 'clipboard', 'notifications', 'codex')

def number(v, maximum=1000000):
    return round(max(0, min(maximum, float(v))), 4) if type(v) in (int, float) and math.isfinite(v) else 0

def sanitize(source):
    """An allowlist, not recursive filtering: unknown strings/fields never enter the score."""
    source = source if isinstance(source, dict) else {}
    journey = source.get('journey', {})
    journey = journey if isinstance(journey, dict) else {}
    visits = journey.get('visits', {})
    seconds = journey.get('seconds', {})
    pairs = journey.get('pairs', [])
    return dict(
        rooms=[[number(visits.get(r, 0)), number(seconds.get(r, 0))] for r in ROOMS],
        edges=[[ROOMS.index(p['a']), ROOMS.index(p['b']), number(p.get('weight'))]
               for p in pairs[:36] if isinstance(p, dict) and p.get('a') in ROOMS and p.get('b') in ROOMS],
        **{k: [number(v) for v in source.get(k, [])[:64]] if isinstance(source.get(k), list) else []
           for k in ('processes', 'geometry', 'devices', 'timers', 'spectrum', 'sky')},
        time=number(source.get('time'), 100000000000))

def compile_score(snapshot):
    import hashlib  # hashlib, tempfile and wave cost the always-running core 2.5 MiB, so they load on the first exhibit
    data = sanitize(snapshot)
    digest = hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':')).encode()).digest()
    duration = 22 + digest[0] % 7
    ribs = []
    for i, (visits, seconds) in enumerate(data['rooms']):
        ribs.append(dict(room=i, mass=round(1 + math.log1p(visits + seconds / 60), 4),
                         x=round((i + .5) / len(ROOMS), 4), depth=1 + digest[i+1] % 7))
    sections = []
    count = 4 + digest[10] % 3
    for i in range(count):
        sections.append(dict(at=round(i * (duration-2) / count, 4),
                             camera=[round(.7+digest[11+i]/90, 3), (digest[18+i]%5-2)*.16],
                             type=(digest[24+i] + i) % 3, pressure=1+digest[3+i]%9))
    cuts = [s['at'] for s in sections[1:]]
    notes = [dict(at=s['at'], hz=55 * (1 + ribs[i%9]['depth']/4),
                  length=round((duration-2)/count, 4), gain=.16 + s['pressure']*.008)
             for i, s in enumerate(sections)]
    return dict(version=1, duration=duration, seed=int.from_bytes(digest[:4], 'big'),
                ribs=ribs, sections=sections, cuts=cuts, notes=notes, state=data)

def synthesize(score, path):
    """A pressure drone and impact from exactly the visual section score; no input audio."""
    import wave
    rate = 16000
    with wave.open(str(path), 'wb') as out:
        out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        frames = bytearray()
        for sample in range(int(score['duration'] * rate)):
            t = sample / rate
            value = 0
            for note in score['notes']:
                age = t-note['at']
                if 0 <= age < note['length']:
                    env = min(1, age*25) * min(1, (note['length']-age)*3)
                    phase = 2*math.pi*note['hz']*age
                    value += note['gain']*env*(math.sin(phase)+.3*math.sin(phase*1.5))
                    value += .13*math.exp(-age*18)*math.sin(phase*.5)
            value *= min(1, max(0, (score['duration']-t)/2))
            frames.extend(struct.pack('<h', int(max(-.8, min(.8, value))*32767)))
        out.writeframes(frames)

class Exhibit:
    def __init__(self, core):
        self.core, self.pending, self.score, self.path, self.player = core, None, None, None, None
        self.expiry = None
        self.watch = None
        self.generation = 0

    async def request(self):
        """Ask the view to prepare the film. Doesn't wait for its answer: typed in the panel, this verb arrives on the view's own
        connection, which the server reads one request at a time, so `exhibit.prepare` couldn't arrive until this returned."""
        if self.core.overdrive.state.effective != 'active':
            raise OpError('refused', 'exhibit requires Overdrive and full motion')
        if self.pending or self.score:
            raise OpError('refused', 'an exhibit is already running')
        if not self.core.view.open:
            raise OpError('refused', 'exhibit requires a visible panel with full motion')
        self.pending = asyncio.get_running_loop().call_later(5, self._forget_request)
        await self.core.view.command('exhibit')

    def _forget_request(self):
        self.pending = None

    def prepare(self, reduced=True, metadata=None):
        if not self.pending:
            raise OpError('refused', 'no exhibition requested')
        self.pending.cancel()
        self.pending = None
        if reduced or self.core.overdrive.state.effective != 'active':
            raise OpError('refused', 'exhibit requires Overdrive and full motion')
        safe = sanitize(metadata)
        snapshot = {k: safe[k] for k in ('geometry','devices','spectrum')}
        snapshot.update(journey=self.core.journey.snapshot(), time=int(self.core.clock.now().real),
                        timers=[v['elapsed'] for v in self.core.timers.summary().values()
                                if isinstance(v, dict) and v.get('running')])
        # /proc exposes only counts by scheduler state here: never cmdline, comm or filenames.
        counts = [0, 0, 0]
        for p in Path('/proc').glob('[0-9]*/stat'):
            try:
                state = p.read_text().rsplit(')', 1)[1].split()[0]
                counts[0 if state == 'R' else 1 if state == 'S' else 2] += 1
            except (OSError, IndexError):
                pass
        snapshot['processes'] = counts
        celestial = self.core.sky.now()
        snapshot['sky'] = [v['altitude'] + 90 for v in celestial.get('bodies', {}).values()] if isinstance(celestial.get('bodies'), dict) else []
        self.score = compile_score(snapshot)
        self.expiry = asyncio.get_running_loop().call_later(self.score['duration']+5, self.stop)
        return self.score

    async def start(self):
        if not self.score or self.path:
            return
        generation = self.generation
        runtime = os.environ.get('XDG_RUNTIME_DIR')
        if runtime:
            import tempfile
            fd, name = tempfile.mkstemp(prefix='fart-exhibit-', suffix='.wav', dir=runtime)
            os.close(fd)
            path = self.path = Path(name)
            try:
                synthesize(self.score, path)
                player = await self.core.sfx.play_exhibit(path)
            except (OSError, ValueError):
                self.stop()
                raise OpError('unavailable', 'exhibit audio could not be prepared')
            if generation != self.generation:
                if player and player.returncode is None:
                    player.terminate()
                path.unlink(missing_ok=True)
                return
            self.player = player
            if player:
                self.watch = asyncio.create_task(self._watch_sound(player, path))
        if self.expiry:
            self.expiry.cancel()
        if self.score:
            self.expiry = asyncio.get_running_loop().call_later(self.score['duration'], self.stop)

    async def _watch_sound(self, player, path):
        from core.sfx import CUES
        while player.returncode is None:
            if not self.core.sfx.decide(CUES['foley.paper'])[0]:
                player.terminate()
                break
            await asyncio.sleep(.1)
        await player.wait()
        path.unlink(missing_ok=True)
        if self.path == path:
            self.path = None

    def stop(self):
        self.generation += 1
        if self.pending:
            self.pending.cancel()
            self.pending = None
        if self.expiry:
            self.expiry.cancel()
            self.expiry = None
        if self.player and self.player.returncode is None:
            try:
                self.player.terminate()
            except ProcessLookupError:
                pass
        self.player = None
        if self.path:
            self.path.unlink(missing_ok=True)
            self.path = None
        self.score = None
