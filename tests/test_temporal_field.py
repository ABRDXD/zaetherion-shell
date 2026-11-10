"""Exercise the exact JS scalar/marching-squares code used by Silent, not a Python copy."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'needs installed node to execute QML JavaScript maths')
class TemporalFieldTests(unittest.TestCase):
    def evaluate(self, expression):
        source = (ROOT / 'view/rooms/TemporalMath.js').read_text().replace('.pragma library', '')
        run = subprocess.run(['node', '-e', source + '\nconsole.log(JSON.stringify(' + expression + '));'], capture_output=True, text=True, check=True)
        return json.loads(run.stdout)

    def test_shear_continuity_angle_and_monotonic_compression(self):
        self.assertEqual(self.evaluate('[fraction(-1,60),fraction(90,60),fraction(0,0)]'), [0, 1, 1])
        self.assertEqual(self.evaluate('[compression(0),compression(1)]'), [.18, 1])
        self.assertTrue(self.evaluate('compression(.1)<compression(.5) && compression(.5)<compression(.9)'))
        self.assertTrue(self.evaluate('Math.abs((seam(0,2)-seam(1,2))*slope-1)<1e-9'))
        self.assertTrue(self.evaluate('Math.abs(warp(seam(.4,2),.4,2,.01)[0]-seam(.4,2))<1e-9'))
        self.assertTrue(self.evaluate('warp(.1,.2,2,0)[0]===.1'))

    def test_convergence_depends_on_real_running_deadlines_only(self):
        self.assertEqual(self.evaluate('closeness({seconds:100,deadline:true,running:true},{seconds:130,deadline:true,running:true})'), .5)
        self.assertEqual(self.evaluate('closeness({seconds:100,deadline:true,running:true},{seconds:100,deadline:false,running:true})'), 0)
        self.assertEqual(self.evaluate('closeness({seconds:100,deadline:true,running:false},{seconds:100,deadline:true,running:true})'), 0)
        self.assertEqual(self.evaluate('closeness({seconds:100,deadline:true,running:true},{seconds:161,deadline:true,running:true})'), 0)

    def test_anchor_reports_seconds_and_stopwatch_is_elapsed_emitter(self):
        self.assertEqual(self.evaluate('value(.5,.5,[{x:.25,y:.5,seconds:120,deadline:true}],2,1)'), 120)
        self.assertEqual(self.evaluate('value(.5,.5,[{x:.25,y:.5,seconds:125,deadline:false}],2,1)'), -5)
        self.assertEqual(self.evaluate('value(.5,.5,[],2,1)'), 0)

    def test_equal_deadlines_crowd_midpoint_and_remain_finite(self):
        expr='''(() => { const a=[{x:.2,y:.5,seconds:100,deadline:true,running:true},{x:.8,y:.5,seconds:100,deadline:true,running:true}];
            return [crowd(1,.5,a,2),crowd(0,0,a,2),Number.isFinite(value(1,.5,a,2,0)),value(1,.5,a,2,1)]; })()'''
        center, edge, finite, scalar = self.evaluate(expr)
        self.assertEqual(center, 1)
        self.assertGreater(center, edge)
        self.assertTrue(finite)
        self.assertGreater(scalar, 100)

    def test_contour_segments_finite_inside_sheet_even_at_zero(self):
        self.assertTrue(self.evaluate('''(() => {const lines=segments(180,100,[{x:.3,y:.7,seconds:0,deadline:true,running:true},{x:.8,y:.2,seconds:15,deadline:true,running:true}],0,60);
          return lines.length>10 && lines.every(s=>s[2]%60===0 && s.slice(0,2).every(p=>p.every(Number.isFinite)&&p[0]>=0&&p[0]<=180&&p[1]>=0&&p[1]<=100));})()'''))
        self.assertEqual(self.evaluate('segments(0,100,[],1,60)'), [])

    def test_shader_keeps_same_field_constants(self):
        # A guard against the dynamic and static renderers silently choosing different laws.
        shader = (ROOT / 'view/strata/shaders/temporal.frag').read_text()
        for token in ('1800.', '1.6*crowd', '/60.', '/24.', '24.*log', 'band(field,60.', 'band(field,300.'):
            self.assertIn(token, shader)
