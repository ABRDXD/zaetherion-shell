"""Read Linux process memory, process-wide CPU and per-thread context switches."""
import argparse
import json
import math
import os
from pathlib import Path
import time

FIELDS = ("Rss", "Pss", "Private_Dirty", "Pss_Anon", "Pss_File")
SWITCHES = ("voluntary_ctxt_switches", "nonvoluntary_ctxt_switches")


def fields(path, names):
    values = {}
    for line in path.read_text().splitlines():
        key, _, value = line.partition(":")
        if key in names:
            values[key] = int(value.split()[0])
    return {key: values.get(key) for key in names}


def stat(path):
    # comm may contain spaces and ')'. The suffix starts at field 3 (state).
    parts = path.read_text().rsplit(")", 1)[1].split()
    return int(parts[19]), int(parts[11]) + int(parts[12])


def snapshot(core_pid, view_pid=None):
    rows = {}

    def visit(pid, role):
        if pid in rows:
            return
        root = Path("/proc") / str(pid)
        try:
            birth, ticks = stat(root / "stat")
            name = (root / "comm").read_text().strip()
            memory = fields(root / "smaps_rollup", FIELDS)
            threads, children = {}, set()
            for task in (root / "task").iterdir():
                try:
                    tid_birth, _ = stat(task / "stat")
                    counts = fields(task / "status", SWITCHES)
                    threads[(task.name, tid_birth)] = tuple(counts[k] for k in SWITCHES)
                    children.update(map(int, (task / "children").read_text().split()))
                except (FileNotFoundError, ProcessLookupError):
                    continue
            if stat(root / "stat")[0] != birth:
                return
        except (FileNotFoundError, ProcessLookupError):
            return
        if pid == view_pid or (role != "core" and name in ("qs", "quickshell") and view_pid is None):
            role = "view"
        rows[pid] = dict(pid=pid, role=role, name=name, birth=birth, ticks=ticks,
                         threads=threads, memory_kib=memory, at=time.monotonic())
        for child in sorted(children):
            visit(child, "helper")

    visit(core_pid, "core")
    if core_pid not in rows:
        raise ProcessLookupError(f"core PID {core_pid} unavailable")
    return rows


def window(core_pid, duration=60, view_pid=None, workload=None):
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError("duration must be finite and positive")
    before = snapshot(core_pid, view_pid)
    if workload is None:
        time.sleep(duration)
    else:
        workload()
    after = snapshot(core_pid, view_pid)
    result = []
    for pid in sorted(before.keys() | after.keys()):
        first, last = before.get(pid), after.get(pid)
        row = last or first
        out = {k: row[k] for k in ("pid", "role", "name", "memory_kib")}
        result.append(out)
        if not first or not last or first["birth"] != last["birth"]:
            out["coverage"] = "new" if not first else "exited" if not last else "pid-reused"
            continue
        seconds = last["at"] - first["at"]
        ticks = last["ticks"] - first["ticks"]
        start, end = first["threads"], last["threads"]
        common = start.keys() & end.keys()
        vol, invol = [sum(end[t][i] - start[t][i] for t in common) for i in range(2)]
        out.update(coverage="window", seconds=seconds, cpu_ticks=ticks,
                   cpu_percent=100 * ticks / os.sysconf("SC_CLK_TCK") / seconds,
                   voluntary_switches=vol, nonvoluntary_switches=invol,
                   thread_set_changed=start.keys() != end.keys(),
                   switches_per_minute=60 * (vol + invol) / seconds)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("core_pid", type=int)
    parser.add_argument("--seconds", type=float, default=60)
    parser.add_argument("--view-pid", type=int)
    args = parser.parse_args()
    print(json.dumps(window(args.core_pid, args.seconds, args.view_pid), indent=2))
