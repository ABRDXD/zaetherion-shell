import json
import tempfile
import unittest
import wave
from pathlib import Path
from core.exhibit import compile_score, synthesize

class ExhibitTests(unittest.TestCase):
    def test_deterministic_and_structural(self):
        a={'journey':{'visits':{'home':4}},'time':10}
        self.assertEqual(compile_score(a),compile_score(a))
        b=compile_score({'journey':{'visits':{'home':900}},'time':20})
        self.assertNotEqual(compile_score(a)['sections'],b['sections'])
        self.assertNotEqual(compile_score(a)['ribs'],b['ribs'])

    def test_no_private_strings(self):
        poison='SECRET_TITLE_TRACK_CLIP_FILE_NOTIFICATION'
        s=compile_score({'title':poison,'spectrum':[poison], 'geometry':[poison],
                         'journey':{'visits':{poison:1},'pairs':[{'a':poison,'b':'home'}]}})
        self.assertNotIn(poison,json.dumps(s))

    def test_limits(self):
        for n in range(100):
            s=compile_score({'time':n})
            self.assertTrue(20<=s['duration']<=30)
            for cut in s['cuts']:
                self.assertLessEqual(sum(cut<=v<cut+1 for v in s['cuts']),3)
            self.assertLess(s['cuts'][-1],s['duration']-2)

    def test_sound(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'score.wav'; s=compile_score({});s['duration']=1
            synthesize(s,p)
            with wave.open(str(p)) as w:
                self.assertEqual(w.getnframes(),16000)
                self.assertEqual(w.getnchannels(),1)

class ExhibitLifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def test_refusal_and_prepare(self):
        import asyncio
        from types import SimpleNamespace as N
        from unittest.mock import Mock, AsyncMock
        from core.exhibit import Exhibit
        from core.errors import OpError
        core=N(overdrive=N(state=N(effective='off')),view=N(command=AsyncMock(),open=True),
               journey=N(snapshot=lambda:{}),clock=N(now=lambda:N(real=1000)),
               timers=N(summary=lambda:{}), sky=N(now=lambda:{'bodies':{'sun':{'altitude':10}}}))
        exhibit=Exhibit(core)
        with self.assertRaises(OpError): await exhibit.request()
        core.overdrive.state.effective='active'
        # The verb must return before the view answers: typed in the panel, the answer comes on the same connection.
        self.assertIsNone(await asyncio.wait_for(exhibit.request(), 1))
        with self.assertRaises(OpError): exhibit.prepare(True, {})
        await exhibit.request()
        with self.assertRaises(OpError): await exhibit.request()
        score=exhibit.prepare(False, {'title':'private'})
        self.assertNotIn('private', str(score))
        core.view.open=False
        exhibit.stop()
        with self.assertRaises(OpError): await exhibit.request()
        exhibit.stop()
        self.assertIsNone(exhibit.score)
        self.assertIsNone(exhibit.expiry)
        exhibit.stop()

    async def test_audio_cleanup_without_playback(self):
        from types import SimpleNamespace as N
        from unittest.mock import AsyncMock, Mock, patch
        from core.exhibit import Exhibit
        player=N(returncode=None,terminate=Mock(),wait=AsyncMock())
        core=N(sfx=N(play_exhibit=AsyncMock(return_value=player),decide=lambda c:(True,None,1)))
        exhibit=Exhibit(core)
        exhibit.score=compile_score({});exhibit.score['duration']=.01
        with tempfile.TemporaryDirectory() as directory, patch.dict('os.environ',{'XDG_RUNTIME_DIR':directory}):
            await exhibit.start()
            self.assertEqual(len(list(Path(directory).glob('*.wav'))),1)
            exhibit.stop()
            player.returncode=0
            self.assertEqual(list(Path(directory).glob('*.wav')),[])
            player.terminate.assert_called_once()
            if exhibit.watch: await exhibit.watch
