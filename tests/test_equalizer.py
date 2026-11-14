"""Our own equaliser (Z50, Z173): the chain on paper, the settings, and the process's state machine with a fake chain."""
import asyncio
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import core_fakes
from core import eq_chain, equalizer
from core.app import Core
from core.equalizer import ChainError, Equalizer, node_of, valid_state
from core.errors import OpError
from core.guards import SessionGuard
from core.verbs.equalizer import eq as eq_verb


class ChainOnPaperTests(unittest.TestCase):
    def test_presets_are_the_small_set_with_flat_first_and_in_range(self):
        self.assertEqual(list(eq_chain.PRESETS), ["Flat", "Bass", "Treble", "Vocal", "Loudness"])
        self.assertFalse(any(eq_chain.PRESETS["Flat"]))
        for name, gains in eq_chain.PRESETS.items():
            self.assertEqual(len(gains), 10, name)
            self.assertTrue(all(isinstance(g, int) and eq_chain.MIN_GAIN <= g <= eq_chain.MAX_GAIN for g in gains), name)

    def test_gains_clamp_to_whole_db_and_refuse_nonsense(self):
        self.assertEqual(eq_chain.clamp_gain(30), 12)
        self.assertEqual(eq_chain.clamp_gain(-13.2), -12)
        self.assertEqual(eq_chain.clamp_gain("3.6"), 4)
        for bad in ("loud", float("nan"), None):
            with self.assertRaises((ValueError, TypeError)):
                eq_chain.clamp_gain(bad)

    def test_presets_are_named_without_case_and_other_bands_are_custom(self):
        self.assertEqual(eq_chain.preset_named(" bass "), "Bass")
        self.assertIsNone(eq_chain.preset_named("Rock"))
        self.assertEqual(eq_chain.preset_for(eq_chain.PRESETS["Vocal"]), "Vocal")
        self.assertEqual(eq_chain.preset_for([1] + [0] * 9), "Custom")

    def test_a_peaking_band_has_its_gain_at_its_frequency_and_none_far_away(self):
        for freq, gain in ((1000, 6), (63, -9), (16000, 12)):
            coefficients = eq_chain.peaking(freq, gain)
            self.assertAlmostEqual(eq_chain.magnitude_db(coefficients, freq), gain, places=6)
        self.assertAlmostEqual(eq_chain.magnitude_db(eq_chain.peaking(1000, 6), 20), 0, delta=0.05)
        self.assertEqual(eq_chain.peaking(500, 0), (1.0, 0.0, 0.0, 0.0, 0.0))

    def test_flat_is_flat_and_headroom_covers_the_loudest_boost(self):
        self.assertEqual(eq_chain.response([0] * 10, [31, 1000, 16000]), [0, 0, 0])
        self.assertEqual(eq_chain.headroom([0] * 10), 0.0)
        self.assertEqual(eq_chain.headroom([-6] * 10), 0.0)  # cuts never need it
        self.assertAlmostEqual(eq_chain.headroom([0, 0, 0, 0, 0, 6, 0, 0, 0, 0]), 6.0, delta=0.1)
        for name, gains in eq_chain.PRESETS.items():
            peak = max(eq_chain.response(gains, eq_chain.GRID))
            self.assertGreaterEqual(eq_chain.headroom(gains) + 0.05, peak, name)

    def test_mono_is_half_of_each_side_and_the_headroom_lowers_both(self):
        stereo = eq_chain.mixer_gains(False, 0)
        self.assertEqual(stereo, {"mixL:Gain 1": 1.0, "mixL:Gain 2": 0.0, "mixR:Gain 1": 0.0, "mixR:Gain 2": 1.0})
        mono = eq_chain.mixer_gains(True, 0)
        self.assertEqual(set(mono.values()), {0.5})
        lowered = eq_chain.mixer_gains(False, 6.0)
        self.assertAlmostEqual(lowered["mixL:Gain 1"], 0.501187, places=5)
        self.assertEqual(lowered["mixL:Gain 2"], 0.0)

    def test_params_name_every_control_once_for_both_channels(self):
        items = eq_chain.params(eq_chain.PRESETS["Bass"], True)
        names, values = items[0::2], items[1::2]
        self.assertEqual(len(names), 24)
        self.assertEqual(len(set(names)), 24)
        self.assertEqual(values[names.index("eqL_1:Gain")], 6.0)
        self.assertEqual(values[names.index("eqR_1:Gain")], 6.0)
        self.assertEqual(values[names.index("eqR_10:Gain")], 0.0)
        text = eq_chain.props_text([0] * 10, False)
        self.assertTrue(text.startswith('{ params = [ "mixL:Gain 1" 1.0 "mixL:Gain 2" 0.0 '), text)
        self.assertTrue(text.endswith(' ] }'))

    def test_config_is_a_smart_filter_with_twenty_biquads_and_the_given_state(self):
        bands = [3, 0, 0, 0, 0, 0, 0, 0, 0, -4]
        text = eq_chain.config_text(bands, True)
        self.assertEqual(text.count("label = bq_peaking"), 20)
        self.assertEqual(text.count("label = mixer"), 2)
        self.assertEqual(text.count("{"), text.count("}"))
        self.assertEqual(text.count("["), text.count("]"))
        self.assertIn("filter.smart = true", text)
        self.assertIn('node.name = "zaetherion_eq"', text)
        self.assertIn('node.name = "zaetherion_eq.output"', text)
        self.assertIn("node.passive = true", text)
        self.assertNotIn("target.object", text)  # it follows the default sink; WirePlumber places it
        self.assertIn('name = eqL_1 label = bq_peaking control = { "Freq" = 31.0 "Q" = 1.41 "Gain" = 3.0 }', text)
        self.assertIn('name = eqR_10 label = bq_peaking control = { "Freq" = 16000.0 "Q" = 1.41 "Gain" = -4.0 }', text)
        level = round(10 ** (-eq_chain.headroom(bands) / 20) / 2, 6)
        self.assertIn(f'name = mixL label = mixer control = {{ "Gain 1" = {level} "Gain 2" = {level} }}', text)
        # Each band feeds the next, per channel, from its mixer to the graph's output.
        links = re.findall(r'output = "(\w+):Out" input = "(\w+):In', text)
        self.assertIn(("mixL", "eqL_1"), links)
        self.assertIn(("eqR_9", "eqR_10"), links)
        self.assertIn('outputs = [ "eqL_10:Out" "eqR_10:Out" ]', text)
        self.assertNotIn("protocol-pulse", text)
        self.assertNotIn("alsa", text)  # the chain's process opens no device


class SettingsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name)

    def test_first_run_is_off_flat_stereo_and_unavailable_without_a_chain(self):
        eq = Equalizer(self.path)
        state = eq.snapshot()
        self.assertEqual((state["on"], state["mono"], state["preset"], state["status"]), (False, False, "Flat", "off"))
        self.assertFalse(state["available"])
        self.assertEqual(state["frequencies"], [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000])
        self.assertFalse((self.path / "eq.json").exists())
        with self.assertRaises(OpError):
            eq.set_on(True)
        self.assertFalse((self.path / "eq.json").exists())

    def test_settings_persist_and_only_real_changes_publish(self):
        eq = Equalizer(self.path)
        events = []
        eq.on_change = lambda: events.append(1)
        eq.set_band(2, 5)
        eq.set_band(2, 5)
        eq.set_mono(True)
        eq.set_mono(True)
        self.assertEqual(len(events), 2)
        again = Equalizer(self.path)
        self.assertEqual(again.state["bands"][2], 5)
        self.assertTrue(again.state["mono"])
        self.assertEqual(again.snapshot()["preset"], "Custom")
        self.assertEqual(json.loads((self.path / "eq.json").read_text())["version"], 1)

    def test_presets_set_every_band_and_bad_arguments_are_refused(self):
        eq = Equalizer(self.path)
        state = eq.apply_preset("treble")
        self.assertEqual(state["bands"], list(eq_chain.PRESETS["Treble"]))
        self.assertEqual(state["preset"], "Treble")
        self.assertEqual(eq.set_band(9, 99)["bands"][9], 12)
        for call in (lambda: eq.set_band(10, 0), lambda: eq.set_band(True, 0), lambda: eq.set_band(0, "loud"),
                     lambda: eq.apply_preset("Rock"), lambda: eq.set_mono("yes"), lambda: eq.set_on(1)):
            with self.assertRaises(OpError):
                call()

    def test_a_damaged_or_odd_file_falls_back_per_field(self):
        (self.path / "eq.json").write_text("{not json")
        self.assertEqual(Equalizer(self.path).state, {"on": False, "mono": False, "bands": [0] * 10})
        self.assertEqual(valid_state({"on": True, "mono": "yes", "bands": [1, 2]}), {"on": True, "mono": False, "bands": [0] * 10})
        self.assertEqual(valid_state({"bands": [40] + [0] * 9})["bands"][0], 12)
        self.assertEqual(valid_state({"bands": ["x"] * 10})["bands"], [0] * 10)


class FakeChain:
    """Stands in for PipewireChain: records calls, and its process ends when the test says."""

    def __init__(self, fail_starts=0):
        self.calls = []
        self.fail_starts = fail_starts
        self.running = False
        self.ended = None
        self.gone = None

    def missing(self):
        return self.gone

    async def start(self, text):
        self.calls.append(("start", text))
        await asyncio.sleep(0)
        if self.fail_starts:
            self.fail_starts -= 1
            raise ChainError("the equaliser's sink did not appear")
        self.running = True
        self.ended = asyncio.get_running_loop().create_future()

    async def wait(self):
        return await asyncio.shield(self.ended)

    async def set(self, props):
        self.calls.append(("set", props))
        await asyncio.sleep(0.01)

    async def stop(self):
        if self.running:
            self.calls.append(("stop",))
        self.running = False
        if self.ended and not self.ended.done():
            self.ended.set_result("stopped")

    def die(self, reason="PipeWire went away"):
        self.running = False
        self.ended.set_result(reason)

    def count(self, kind):
        return sum(1 for call in self.calls if call[0] == kind)


async def settle(steps=20):
    for _ in range(steps):
        await asyncio.sleep(0)


class ChainLifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name)
        self.eq = Equalizer(self.path)
        self.chain = FakeChain()
        self.statuses = []
        self.eq.on_change = lambda: self.statuses.append(self.eq.status)
        patcher = patch.object(equalizer, "BACKOFF", (0.01, 0.02, 0.03))
        patcher.start()
        self.addCleanup(patcher.stop)

    async def asyncTearDown(self):
        await self.eq.close()

    async def test_on_starts_the_chain_with_the_current_state_and_off_stops_it(self):
        self.eq.attach(self.chain)
        self.eq.set_band(0, 4)
        self.assertEqual(self.chain.calls, [])  # off: nothing runs, the setting is kept
        self.eq.set_on(True)
        await settle()
        self.assertEqual(self.eq.status, "on")
        self.assertTrue(self.eq.snapshot()["active"])
        self.assertIn('"Gain" = 4.0', self.chain.calls[0][1])
        self.assertIn("starting", self.statuses)
        self.eq.set_on(False)
        await settle()
        self.assertEqual(self.eq.status, "off")
        self.assertFalse(self.chain.running)
        self.assertEqual(self.chain.count("stop"), 1)
        self.assertFalse(json.loads((self.path / "eq.json").read_text())["on"])

    async def test_gains_and_mono_change_live_and_a_drag_is_coalesced(self):
        self.eq.attach(self.chain)
        self.eq.set_on(True)
        await settle()
        sets = self.chain.count("set")
        for gain in range(1, 8):
            self.eq.set_band(5, gain)
        self.eq.set_mono(True)
        await asyncio.sleep(0.05)
        live = [call[1] for call in self.chain.calls[1:] if call[0] == "set"]
        self.assertLessEqual(len(live) - sets, 2)  # one in flight, then the latest
        self.assertIn('"eqL_6:Gain" 7.0', live[-1])
        self.assertIn('"eqR_6:Gain" 7.0', live[-1])
        self.assertNotIn('"mixL:Gain 2" 0.0', live[-1])  # mono: each side takes half of the other
        self.assertEqual(self.chain.count("start"), 1)  # never restarted for a change

    async def test_the_chain_comes_back_after_pipewire_goes_and_gives_up_after_repeated_stops(self):
        self.eq.attach(self.chain)
        self.eq.set_on(True)
        await settle()
        self.chain.die()
        await settle()
        self.assertEqual(self.eq.status, "retrying")
        self.assertEqual(self.eq.error, "PipeWire went away")
        await asyncio.sleep(0.03)
        await settle()
        self.assertEqual(self.eq.status, "on")
        self.assertEqual(self.chain.count("start"), 2)
        for _ in range(3):
            self.chain.die("the equaliser process exited (1)")
            await asyncio.sleep(0.06)
            await settle()
        self.assertEqual(self.eq.status, "failed")
        self.assertEqual(self.eq.error, "the equaliser process exited (1)")
        self.assertTrue(self.eq.snapshot()["on"])  # the owner's wish stays; asking again retries
        self.assertFalse(self.eq.snapshot()["active"])
        self.eq.set_on(True)
        await settle()
        self.assertEqual(self.eq.status, "on")
        self.assertEqual(self.eq.error, "")

    async def test_off_after_giving_up_reads_off(self):
        self.chain.fail_starts = 99
        self.eq.attach(self.chain)
        self.eq.set_on(True)
        await asyncio.sleep(0.15)
        await settle()
        self.assertEqual(self.eq.status, "failed")
        self.eq.set_on(False)
        self.assertEqual((self.eq.status, self.eq.error), ("off", ""))

    async def test_a_start_that_fails_is_retried(self):
        self.chain.fail_starts = 1
        self.eq.attach(self.chain)
        self.eq.set_on(True)
        await settle()
        self.assertEqual(self.eq.status, "retrying")
        await asyncio.sleep(0.03)
        await settle()
        self.assertEqual(self.eq.status, "on")

    async def test_switching_off_while_waiting_to_retry_stops_at_once(self):
        self.eq.attach(self.chain)
        self.eq.set_on(True)
        await settle()
        self.chain.die()
        await settle()
        self.eq.set_on(False)
        await settle()
        self.assertEqual(self.eq.status, "off")
        await asyncio.sleep(0.05)
        self.assertEqual(self.chain.count("start"), 1)

    async def test_a_core_that_starts_with_it_on_starts_the_chain_once_attached(self):
        (self.path / "eq.json").write_text(json.dumps({"version": 1, "on": True, "mono": True, "bands": [0] * 10}))
        eq = Equalizer(self.path)
        await settle()
        self.assertEqual(eq.status, "off")  # no chain yet: not this session's, nothing runs
        eq.attach(self.chain)
        await settle()
        self.assertEqual(eq.status, "on")
        self.assertIn('"Gain 1" = 0.5 "Gain 2" = 0.5', self.chain.calls[0][1])
        await eq.close()
        self.assertFalse(self.chain.running)
        self.assertTrue(json.loads((self.path / "eq.json").read_text())["on"])  # closing is not switching off

    async def test_unavailable_tools_mean_no_process(self):
        self.chain.gone = "pw-cli is not installed"
        self.eq.attach(self.chain)
        state = self.eq.snapshot()
        self.assertEqual((state["available"], state["reason"]), (False, "pw-cli is not installed"))
        with self.assertRaises(OpError):
            self.eq.set_on(True)
        await settle()
        self.assertEqual(self.chain.calls, [])


class NodeLookupTests(unittest.TestCase):
    def test_only_our_process_counts(self):
        dump = [
            {"id": 30, "type": "PipeWire:Interface:Client", "info": {"props": {"pipewire.sec.pid": 111}}},
            {"id": 31, "type": "PipeWire:Interface:Client", "info": {"props": {"pipewire.sec.pid": 222}}},
            {"id": 40, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "zaetherion_eq", "client.id": 30}}},
            {"id": 41, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "zaetherion_eq", "client.id": 31}}},
            {"id": 42, "type": "PipeWire:Interface:Node", "info": {"props": {"node.name": "zaetherion_eq.output", "client.id": 31}}},
        ]
        self.assertEqual(node_of(dump, 222), 41)
        self.assertIsNone(node_of(dump, 333))
        self.assertIsNone(node_of([], 222))


class Ctx:
    def __init__(self, core):
        self.core = core


class CoreTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(clock, scheduler, host, Path(temp.name), spawn=no_spawn, guard_types=[SessionGuard])
        self.chain = FakeChain()

    async def asyncTearDown(self):
        await self.core.equalizer.close()

    async def test_topic_ops_and_verb_share_one_state(self):
        before = self.core.server.revs["equalizer"]
        self.assertFalse(self.core.server.snapshots["equalizer"]()["available"])
        self.core.equalizer.attach(self.chain)
        ops = self.core.server.ops
        ops["eq.preset"](None, name="Bass")
        ops["eq.band"](None, index=9, gain=3)
        ops["eq.mono"](None, on=True)
        ops["eq.enable"](None, on=True)
        await settle()
        state = self.core.server.snapshots["equalizer"]()
        self.assertEqual((state["status"], state["mono"], state["preset"], state["bands"][9]), ("on", True, "Custom", 3))
        self.assertGreater(self.core.server.revs["equalizer"], before)
        result = await self.core.commands.run("eq loudness", "cli")
        self.assertTrue(result["ok"], result)
        self.assertIn("LOUDNESS · MONO", result["line"])
        self.assertEqual(self.core.equalizer.state["bands"], list(eq_chain.PRESETS["Loudness"]))
        self.assertIn("> EQ · ON", (await self.core.commands.run("eq", "cli"))["line"])
        self.assertTrue((await self.core.commands.run("eq 2 +4", "cli"))["ok"])
        self.assertEqual(self.core.equalizer.state["bands"][1], 4)
        self.assertFalse((await self.core.commands.run("eq 11 3", "cli"))["ok"])
        self.assertFalse((await self.core.commands.run("eq rock", "cli"))["ok"])
        await self.core.commands.run("eq off", "cli")
        await settle()
        self.assertEqual(self.core.equalizer.status, "off")

    async def test_the_verb_says_why_it_is_unavailable(self):
        result = await eq_verb(Ctx(self.core), [])
        self.assertIn("UNAVAILABLE", result.line)


if __name__ == "__main__":
    unittest.main()
