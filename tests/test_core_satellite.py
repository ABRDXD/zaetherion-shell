"""Satellites with the view reaped (DAILY_DRIVER §5): the core spawns the view closed for DONE and the track.

The spawn is recorded and refused, so no view ever starts.
"""
import asyncio
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.guards import SessionGuard


class SatelliteSpawn(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, self.profile, host = core_fakes.fakes()
        self.spawns = 0
        self.core = self.make(scheduler, host)

    def make(self, scheduler, host):
        async def spawn():
            self.spawns += 1
            raise OSError("no view in this test")
        return Core(self.clock, scheduler, host, Path(self.temp.name), spawn=spawn, guard_types=[SessionGuard])

    async def settle(self):
        for _ in range(5):
            await asyncio.sleep(0)

    async def test_a_countdown_done_spawns_the_absent_view_once(self):
        self.core.timers.start("countdown", 60)
        with self.assertLogs("fart.core", "INFO"):
            self.clock.advance(61)
            # A fixed number of loop turns wasn't always enough (it failed about one run in six): wait for the spawn itself, within a limit.
            for _ in range(200):
                if self.spawns:
                    break
                await asyncio.sleep(0.001)
        self.assertEqual(self.spawns, 1)
        self.core.timers.lap()  # an unrelated change with DONE still set: no second spawn
        self.core.timers.start("stopwatch")
        await self.settle()
        self.assertEqual(self.spawns, 1)

    async def test_each_pomodoro_phase_end_spawns(self):
        self.core.timers.configure(pomodoro={"focus": 60, "break": 60, "longBreak": 60, "cycles": 4})
        self.core.timers.start("pomodoro")
        with self.assertLogs("fart.core", "INFO"):
            self.clock.advance(61)
            await self.settle()
            self.clock.advance(60)
            await self.settle()
        self.assertEqual(self.spawns, 2)

    async def test_no_spawn_while_a_view_exists_or_for_a_restored_done(self):
        self.core.view.state = "ready"
        self.core.timers.start("countdown", 60)
        self.clock.advance(61)
        await self.settle()
        self.assertEqual(self.spawns, 0)
        self.core.view.state = "absent"
        restarted = self.make(self.clock.scheduler, self.core.host)  # the DONE is restored from timers.json
        restarted.timers.start("stopwatch")
        await self.settle()
        self.assertEqual(self.spawns, 0)
        restarted.timers.ack()
        await self.settle()
        self.assertEqual(self.spawns, 0)


if __name__ == "__main__":
    unittest.main()
