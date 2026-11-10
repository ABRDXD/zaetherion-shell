"""Frame timing from the fixture view.

`frame_stats` reads Qt's render-loop total, which is whole milliseconds, truncated, and on a
vsynced desktop includes the swap's wait for the next vblank (Qt 6.12 qsgthreadedrenderloop.cpp:
`int(threadTimer.elapsed())`, timer started before sync, `endFrame()` inside "swap"). It is kept
for the offscreen software gate. Desktop runs use `desktop_stats`: sub-millisecond GUI frame
intervals from the FixtureView probe, the GPU time from RHI timestamps, and render-thread CPU
work (sync + render, whole ms), all per room, with the vsync wait excluded.
"""
import json
import math
import re
from statistics import median

# Qt 6 software, basic and threaded loops. Ignore GPU timing, phase breakdown
# and frameDelta (includes time when the static scene requested no frame).
FRAME = re.compile(r"qt\.scenegraph\.time\.renderloop: .*?frame rendered "
                   r"(?:with 'software' renderloop )?in (\d+(?:\.\d+)?)\s*ms\b", re.I)


def frame_stats(lines, budget_ms):
    samples = sorted(float(m[1]) for line in lines if (m := FRAME.search(line)))
    def percentile(p):
        return samples[math.ceil(p * len(samples)) - 1] if samples else None
    return dict(count=len(samples), median_ms=median(samples) if samples else None,
                p95_ms=percentile(.95), p99_ms=percentile(.99), budget_ms=budget_ms,
                p99_note="fewer than 100 frames: p99 is the slowest frame" if 0 < len(samples) < 100 else None,
                missed_frames=sum(value > budget_ms for value in samples))


THREADED = re.compile(r"syncAndRender: frame rendered in (\d+)ms, sync=(-?\d+), render=(-?\d+), swap=(-?\d+)")
GPU = re.compile(r"last retrieved GPU frame time was (\d+(?:\.\d+)?) ms")
PAGE = re.compile(r"FART_PAGE (\w+) (\d+)")
PROBE = re.compile(r"FART_FRAMES (\[.*\])")
GC = re.compile(r"========== GC ==========")
LOAD = re.compile(r"FART_LOAD (\w+) (\d+)")
POLISH = re.compile(r"\[gui thread\] Frame prepared, polish=(\d+) ms")


def nearest(samples, p):
    return samples[math.ceil(p * len(samples)) - 1] if samples else None


def summary(values, limit=None):
    values = sorted(values)
    out = dict(count=len(values), median=median(values) if values else None, p95=nearest(values, .95),
               p99=nearest(values, .99), max=values[-1] if values else None)
    out["over"] = sum(v > limit for v in values) if limit is not None else None
    return out


def missed_presentations(interval, period):
    """Presentations an interval skipped: one per extra refresh period, counted from 1.5 periods."""
    return max(0, round(interval / period) - 1)


def desktop_stats(lines, budget_ms, refresh):
    """Per-room desktop timing at `refresh` Hz.

    Each FART_PAGE marker starts a segment at a probe index. Segment 0 (the window's first open and
    settle) is excluded. In every later segment, the first interval spans the command and the
    synchronous room load; the rest are the room's entrance and steady frames. Render-loop lines are
    attributed to the segment of the last marker.
    """
    page = None
    segment = -1
    starts = []
    probe = []
    rooms = {}
    def room(name):
        return rooms.setdefault(name, dict(work=[], swap=[], gpu=[], intervals=[], first=[], create=[], polish=[],
                                           misses=[], gc=0))
    for line in lines:
        if m := PAGE.search(line):
            page, segment = m[1], segment + 1
            starts.append((page, int(m[2])))
        if m := PROBE.search(line):
            probe.extend(json.loads(m[1]))
        if segment < 1:
            continue
        if GC.search(line):
            room(page)["gc"] += 1
        if m := LOAD.search(line):
            room(page)["create"].append(int(m[2]))
            room(page)["polish"].append(0)
        elif (m := POLISH.search(line)) and room(page)["polish"]:
            room(page)["polish"][-1] = max(room(page)["polish"][-1], int(m[1]))
        if m := THREADED.search(line):
            total, sync, render, swap = map(int, m.groups())
            if render >= 0:  # render < 0: the frame was skipped (canRender false)
                room(page)["work"].append(sync + render)
                room(page)["swap"].append(swap)
        elif m := GPU.search(line):
            room(page)["gpu"].append(float(m[1]))
    every = []
    for n, (name, start) in enumerate(starts[1:], 1):
        end = starts[n + 1][1] if n + 1 < len(starts) else len(probe)
        intervals = [i for _, i in probe[start:end]]
        period = 1000 / refresh if refresh else None
        if intervals:
            room(name)["first"].append(intervals[0])
            room(name)["intervals"].extend(intervals[1:])
            every.extend(intervals)
            # Where in the step each late frame fell: ms from the step's start, and the interval itself.
            # The probe draws every vsync, so a miss late in a step is not the step's own frame.
            at = 0.0
            for i in intervals:
                at += i
                if period and i > 1.5 * period:
                    room(name)["misses"].append([round(at - i, 1), round(i, 2)])
    period = 1000 / refresh if refresh else None
    missed = 1.5 * period if period else None
    report = {}
    for name, r in rooms.items():
        report[name] = dict(
            load_frame_ms=summary(r["first"], missed),
            load_frames_in_order_ms=r["first"],
            create_ms_in_order=r["create"],
            polish_max_ms_in_order=r["polish"],
            interval_ms=summary(r["intervals"], missed),
            missed_steady=sum(missed_presentations(i, period) for i in r["intervals"]),
            missed_per_load_max=max((missed_presentations(i, period) for i in r["first"]), default=0),
            gpu_ms=summary(r["gpu"], budget_ms),
            render_thread_work_ms=summary(r["work"], budget_ms),
            vsync_wait_ms=summary(r["swap"]),
            misses_at_ms=r["misses"],
            gc_runs=r["gc"])
    return dict(navigations=len(starts) - 1, refresh_hz=refresh, period_ms=period, missed_threshold_ms=missed, budget_ms=budget_ms,
                intervals=summary(every, missed), rooms=report,
                units=dict(create="synchronous command handling, whole ms (Date.now)",
                           polish="largest GUI polish phase in the segment, whole ms", interval="GUI frame interval, sub-ms (FrameAnimation)", gpu="RHI timestamps, sub-ms",
                           render_thread_work="sync + render, whole ms truncated", vsync_wait="swap phase, whole ms",
                           misses_at="[ms from the step's start, interval ms] per late frame",
                           gc_runs="QML garbage collections in the segment (only with qt.qml.gc.statistics on)"))


def desktop_checks(stats, budget):
    """The desktop navigation budget (budgets.desktop_navigate), checked per room."""
    rooms = stats["rooms"].values()
    measured = dict(missed_steady=sum(r["missed_steady"] for r in rooms),
                    missed_per_load=max((r["missed_per_load_max"] for r in rooms), default=None),
                    gpu_p99_ms=max((r["gpu_ms"]["p99"] for r in rooms if r["gpu_ms"]["p99"] is not None), default=None),
                    render_thread_p99_ms=max((r["render_thread_work_ms"]["p99"] for r in rooms
                                              if r["render_thread_work_ms"]["p99"] is not None), default=None))
    return {key: dict(measured=measured[key], limit=limit,
                      status="insufficient" if measured[key] is None else "pass" if measured[key] <= limit else "fail")
            for key, limit in budget.items()}


if __name__ == "__main__":
    from fixture import private_core
    from tools.measure.budgets import BUDGETS
    with private_core() as f:
        f.navigate()
        print(json.dumps(dict(platform="offscreen/software",
                              frames=frame_stats(f.log.read_text().splitlines(),
                                                 BUDGETS["navigate"]["p99_ms"])), indent=2))


# Open to an interactive command line (DAILY_DRIVER §1). The fixture view prints wall-clock ms once per
# open, on the first frame swapped after the command line has active focus (PanelBody.interactive).
CMDLINE_READY = re.compile(r"FART_CMDLINE ready (\d+(?:\.\d+)?)")


def cmdline_markers(lines):
    return [float(m[1]) for line in lines if (m := CMDLINE_READY.search(line))]


def open_stats(samples_ms, refresh):
    """Latencies from sending view.open to the marker, in ms and in refresh periods."""
    period = 1000 / refresh
    if not samples_ms:
        return dict(count=0, samples_ms=[], median_ms=None, max_ms=None, median_frames=None, max_frames=None)
    mid, top = median(samples_ms), max(samples_ms)
    return dict(count=len(samples_ms), samples_ms=[round(v, 1) for v in samples_ms], median_ms=round(mid, 1),
                max_ms=round(top, 1), median_frames=round(mid / period, 2), max_frames=round(top / period, 2))


def open_checks(cold, warm, budget):
    """Every run must be within budget, so the checks use the maxima. A mode not run is not checked."""
    checks = {}
    for key, stats, field in (("cold_ms", cold, "max_ms"), ("warm_frames", warm, "max_frames")):
        if stats is None:
            continue
        measured = stats[field]
        checks[key] = dict(measured=measured, limit=budget[key],
                           status="insufficient" if measured is None else "pass" if measured <= budget[key] else "fail")
    return checks
