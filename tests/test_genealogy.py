"""Synthetic event streams only; never manipulate compositor windows."""
import asyncio
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from core.genealogy import DAY, Genealogy


class GenealogyTests(unittest.TestCase):
    def setUp(self):
        self.time = 100000
        self.g = Genealogy(now=lambda: self.time)

    def emit(self, value):
        self.time += 1
        return self.g.event(value)

    def test_open_focus_move_close_workspace(self):
        self.emit('openwindow>>aaa,1,terminal,SECRET,title')
        self.emit('activewindowv2>>aaa')
        self.emit('openwindow>>bbb,1,editor,SECRET')
        self.assertEqual(self.g.nodes[1]['parent'], 1)
        self.emit('activewindowv2>>bbb')
        self.emit('movewindowv2>>bbb,2,two')
        self.emit('workspacev2>>2,two')
        self.assertEqual(self.g.workspace, '2')
        self.assertEqual(self.g.nodes[1]['workspace'], '2')
        self.emit('closewindow>>bbb')
        self.assertEqual(len(self.g.memories['2']['rects']), 1)
        self.assertEqual(len(self.g.focus), 2)
        self.assertNotIn('SECRET', json.dumps(self.g.snapshot()))

    def test_full_empty_plan_survives_sequential_closes_until_reuse(self):
        self.g.reconcile([{'address': '0xa', 'class': 'term', 'workspace': {'id': 1}, 'at': [0, 0], 'size': [800, 600], 'title': 'SECRET'},
                          {'address': '0xb', 'class': 'edit', 'workspace': {'id': 1}, 'at': [800, 0], 'size': [800, 600]}])
        self.emit('closewindow>>a')
        self.emit('closewindow>>b')
        self.assertEqual(len(self.g.memories['1']['rects']), 2)
        self.assertNotIn('SECRET', json.dumps(vars(self.g), default=str))
        self.emit('openwindow>>c,1,browser,new')
        self.assertNotIn('1', self.g.memories)

    def test_addresses_reused_get_new_node_not_cycle(self):
        self.emit('openwindow>>a,1,term,title')
        self.emit('closewindow>>a')
        self.emit('openwindow>>a,1,edit,title')
        self.assertEqual([n['id'] for n in self.g.nodes], [1, 2])
        self.assertIsNone(self.g.nodes[1]['parent'])

    def test_prune_day_limits_and_preserves_live(self):
        self.emit('openwindow>>a,1,term,title')
        self.emit('activewindowv2>>a')
        self.emit('openwindow>>b,2,edit,title')
        self.emit('closewindow>>b')
        self.time += DAY + 1
        snap = self.g.snapshot()
        self.assertEqual(len(snap['nodes']), 1)
        self.assertFalse(snap['focus'])
        self.assertFalse(snap['memories'])
        for i in range(2100):
            self.emit('activewindowv2>>' + str(i))
        self.assertEqual(len(self.g.focus), 2048)

    def test_no_file_io_and_snapshot_detached(self):
        with patch('builtins.open', side_effect=AssertionError('must not persist')):
            self.emit('openwindow>>a,1,term,PRIVATE TITLE')
            snap = self.g.snapshot()
            snap['nodes'][0]['app'] = 'changed'
            self.assertEqual(self.g.nodes[0]['app'], 'term')

    def test_reconcile_does_not_invent_ancestry(self):
        self.g.reconcile([{'address': a, 'workspace': {'id': 1}} for a in ['a', 'b']])
        self.assertTrue(all(n['parent'] is None for n in self.g.nodes))
        self.g.reconcile([])
        self.assertTrue(all(n['closed'] is not None for n in self.g.nodes))

    def test_geometry_query_cannot_steal_buffered_launch_or_close_events(self):
        self.emit('openwindow>>a,1,term,title')
        self.emit('activewindowv2>>a')
        self.g.reconcile([{'address': 'a', 'workspace': {'id': 1}},
                          {'address': 'b', 'workspace': {'id': 1}}], discover=False)
        self.assertIsNone(self.g.live('b'))
        self.emit('openwindow>>b,1,edit,title')
        self.assertEqual(self.g.live('b')['parent'], self.g.live('a')['id'])
        self.g.reconcile([], discover=False)
        self.assertIsNotNone(self.g.live('b'))
        self.emit('closewindow>>b')
        self.assertIsNone(self.g.live('b'))


class SocketStreamTests(unittest.IsolatedAsyncioTestCase):
    async def test_independent_socket_stream_and_shutdown(self):
        # StreamReader delivers real socket2 framing without requiring socket permissions.
        reader = asyncio.StreamReader()
        reader.feed_data(b'openwindow>>a,1,term,SECRET\nactivewindowv2>>a\nopenwindow>>b,1,edit,SECRET\nmovewindow>>b,2\nworkspace>>2\nclosewindow>>b\n')
        from unittest.mock import AsyncMock, MagicMock
        writer = MagicMock()
        writer.wait_closed = AsyncMock()
        g = Genealogy(directory=Path('/synthetic'))
        def query(directory, op):
            return [{'address': n['address'], 'class': n['app'], 'workspace': {'id': n['workspace']}, 'at': [0, 0], 'size': [100, 100]}
                    for n in g.nodes if n['closed'] is None]
        async def in_thread(fn, *args):
            return fn(*args)
        with patch('asyncio.to_thread', side_effect=in_thread), patch('core.genealogy.hypr_query', side_effect=query), patch('asyncio.open_unix_connection', new=AsyncMock(return_value=(reader, writer))) as connect, patch.dict('os.environ', {'FART_HOST': 'test'}):
            g.start()
            for _ in range(100):
                if g.workspace == '2' and g.nodes[-1]['closed'] is not None:
                    break
                await asyncio.sleep(.002)
            self.assertEqual(g.workspace, '2')
            self.assertEqual(len(g.nodes), 2)
            self.assertIsNotNone(g.nodes[1]['closed'])
            self.assertNotIn('SECRET', json.dumps(g.snapshot()))
            connect.assert_awaited_once_with('/synthetic/.socket2.sock')
            task = g.task
            g.stop()
            with self.assertRaises(asyncio.CancelledError):
                await task
            writer.close.assert_called_once()
