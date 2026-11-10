#!/usr/bin/env python3
"""Measure the two Astra rooms using the existing Overdrive/desktop-idle samplers.

Private fixture core, synthetic genealogy, real GPU window. No live core/window actions.
This runner selects the requested pages explicitly: the current overdrive_cost.py always
opens Home even for custom --places values. Interrupted/unknown rows are not accepted.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.measure.overdrive_cost import FRAME, Interaction, private_core, row, window


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, default=20)
    parser.add_argument('--output', type=Path, default=Path('/tmp/astra-cost.json'))
    args = parser.parse_args()
    report = dict(at=datetime.now(timezone.utc).isoformat(), seconds=args.seconds, source=str(ROOT), scenarios={})
    extra = dict(FART_MOTION='serpantinum', FART_FRAME_PROBE='0', QSG_RHI_PROFILE='0', FART_KEEP_SHELL='1',
                 FART_REDUCED='0', FART_AMBIENT='1', FART_IDLE_MS='')
    try:
        with private_core(source=ROOT, desktop=True, extra_env=extra) as f:
            # Only the private temporary harness is amended, before its view has started.
            harness = Path(f.env['FART_VIEW_ENTRY'])
            source = harness.read_text()
            source = 'import "tools/cuetest/AstraFixture.js" as AstraData\n' + source
            hook = '''
    Connections {
        target: body.shell
        function onLoadedPageChanged() {
            if (body.shell.loadedPage === "workspaces") {
                fixture.workspaces.windows = AstraData.windows();
                body.shell.shownSlot.item.historyOverride = AstraData.genealogy();
            }
        }
    }
'''
            at = source.rfind('}')
            harness.write_text(source[:at] + hook + source[at:])
            for place in ('workspaces', 'timers'):
                if place == 'timers':
                    f.request('timer.start', kind='countdown', seconds=330)
                    f.request('timer.start', kind='pomodoro', focus=352)
                    f.request('timer.start', kind='stopwatch')
                f.request('view.open', page=place)
                view = f.wait_state(True, place)['pid']
                time.sleep(4)
                for state in ('silent', 'overdrive', 'released'):
                    if state == 'overdrive':
                        f.request('overdrive.request', mode='sticky')
                        time.sleep(3)
                    elif state == 'released':
                        f.request('overdrive.release')
                        time.sleep(5)
                    before = len(f.log.read_text().splitlines())
                    with Interaction(os.environ) as interaction:
                        rows = window(f.process.pid, args.seconds, view)
                    lines = f.log.read_text().splitlines()[before:]
                    frames = sum(bool(FRAME.search(line)) for line in lines)
                    result = dict(interaction=interaction.status, accepted=interaction.status == 'quiet',
                                  frames=frames, fps=frames/args.seconds, view=row(rows,'view'), core=row(rows,'core'))
                    report['scenarios'][place+'_'+state] = result
                    print(place, state, json.dumps(result), flush=True)
                f.request('view.close')
                f.wait_state(False, place)
    except (RuntimeError, OSError) as error:
        report['unavailable'] = str(error)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    return 0 if len(report['scenarios']) == 6 and all(r['accepted'] for r in report['scenarios'].values()) else 3


if __name__ == '__main__':
    raise SystemExit(main())
