"""Live machine counters for Overdrive's telemetry (Claude B; docs/OVERDRIVE.md §31): interrupt rainfall (atlas #17) and
the network letterpress (#73).

Pulled, never pushed, like the orrery: Performance's rainfall and Devices' letterpress ask `telemetry.sample` about
once a second while their strata exist. Nothing is read unless Overdrive is in effect, and the last reading is dropped
when the view closes or after a gap. Read-only and counters only: `/proc/interrupts` (per line, folded into classes by
the driver's name: timer, ipi, gpu, net, disk, input, usb, other) and `/proc/net/dev` (bytes in and out, loopback
left out). No process, address or anything typed; nothing goes to disk.

A sample is {running, rain: [{kind, rate}], total, spikes: [kind], net: {rx, tx}} with rates per second since the last
sample; a spike is a class running at three times its own recent average (and at least 50 a second).

The scheduler's reading (`telemetry.sched`, docs/OVERDRIVE.md §37, atlas #15 and #72), pulled by Performance's plates:
`/proc/stat` (each core's busy share, the runnable and blocked counts, context switches a second) and every process's
voluntary and involuntary context switches (`/proc/PID/status`; only the two counters, summed as deltas of the
processes seen in both readings, so one starting or ending doesn't count; the PIDs are kept in memory only). About 10 ms
a reading on 430 processes. A reading is {running, cores: [0–1], runnable, blocked, ctxt, voluntary, involuntary}.

The disks' reading (`telemetry.disk`, docs/OVERDRIVE.md §44), pulled by Performance's tide: `/proc/diskstats` for the
physical disks only (those with a `device` in `/sys/block`), bytes read and written a second and the busiest disk's
share of time spent doing I/O. A reading is {running, read, written, busy}.

The graphics cards' reading (`telemetry.gpu`, docs/OVERDRIVE.md §45), pulled by Performance's chart recorder: for every
card only `power/runtime_status` (reading anything else from a sleeping card could wake it), and for an awake AMD card
its busy share, its clock ladder (`pp_dpm_sclk`: the levels and the engaged one) and its VRAM.

The swap's reading (`telemetry.swap`, docs/OVERDRIVE.md §46): pages swapped in and out a second (`/proc/vmstat`) and the
swap in use (`/proc/meminfo`). A reading is {running, in, out, used, total}.

The processor's temperature (`telemetry.thermal`, docs/OVERDRIVE.md §47), for the cockled sheet: its own hwmon sensor
(k10temp, coretemp…), else the hottest ACPI zone; never a graphics card's. A reading is {running, temp, sensor}.
"""
from __future__ import annotations

from pathlib import Path
from typing import Callable

STALE = 5.0
SPIKE = 3.0
SPIKE_FLOOR = 50.0
EMA = 0.2
KINDS = (("timer", ("LOC", "timer", "hpet", "rtc")), ("ipi", ("CAL", "RES", "TLB", "IWI", "NMI", "PMI")),
         ("gpu", ("amdgpu", "i915", "nvidia", "xe", "radeon", "nouveau")),
         ("net", ("iwlwifi", "rtw", "ath", "mt7", "r8169", "e1000", "igc", "enp", "wlp", "eth", "brcm")),
         ("disk", ("nvme", "ahci", "ata", "mmc", "sdhci")), ("input", ("i8042", "hid", "elan", "i2c", "AMDI0010")),
         ("usb", ("xhci", "ehci", "usb", "thunderbolt")))


def kind_of(name: str) -> str:
    low = name.lower()
    for kind, needles in KINDS:
        if any(n.lower() in low for n in needles):
            return kind
    return "other"


def read_interrupts(proc: Path = Path("/proc")) -> dict:
    """{kind: count} summed over every CPU and line."""
    out: dict[str, int] = {}
    try:
        lines = (proc / "interrupts").read_text().splitlines()
    except OSError:
        return out
    cpus = len(lines[0].split()) if lines else 0
    for line in lines[1:]:
        label, _, rest = line.partition(":")
        fields = rest.split()
        counts = [int(f) for f in fields[:cpus] if f.isdigit()]
        if not counts:
            continue
        name = " ".join(fields[len(counts):]) if label.strip().isdigit() else label.strip()
        kind = kind_of(name)
        out[kind] = out.get(kind, 0) + sum(counts)
    return out


def read_net(proc: Path = Path("/proc")) -> tuple[int, int]:
    rx = tx = 0
    try:
        for line in (proc / "net/dev").read_text().splitlines()[2:]:
            name, _, rest = line.partition(":")
            fields = rest.split()
            if name.strip() != "lo" and len(fields) >= 9:
                rx += int(fields[0])
                tx += int(fields[8])
    except (OSError, ValueError):
        pass
    return rx, tx


def read_stat(proc: Path = Path("/proc")) -> dict:
    """{cores: [(busy, total) jiffies], ctxt, runnable, blocked} from /proc/stat."""
    out = {"cores": [], "ctxt": 0, "runnable": 0, "blocked": 0}
    try:
        lines = (proc / "stat").read_text().splitlines()
    except OSError:
        return out
    for line in lines:
        fields = line.split()
        if not fields:
            continue
        if fields[0].startswith("cpu") and fields[0] != "cpu":
            ticks = [int(f) for f in fields[1:9] if f.isdigit()]
            if len(ticks) >= 5:
                idle = ticks[3] + ticks[4]   # idle and iowait
                out["cores"].append((sum(ticks) - idle, sum(ticks)))
        elif fields[0] == "ctxt" and len(fields) > 1:
            out["ctxt"] = int(fields[1])
        elif fields[0] == "procs_running" and len(fields) > 1:
            out["runnable"] = int(fields[1])
        elif fields[0] == "procs_blocked" and len(fields) > 1:
            out["blocked"] = int(fields[1])
    return out


def read_switches(proc: Path = Path("/proc")) -> dict:
    """{pid: (voluntary, involuntary)} for every process that could be read."""
    out: dict[int, tuple[int, int]] = {}
    try:
        names = [n for n in (p.name for p in proc.iterdir()) if n.isdigit()]
    except OSError:
        return out
    for name in names:
        v = n = None
        try:
            with open(proc / name / "status", "rb") as f:
                for line in f:
                    if line.startswith(b"voluntary_ctxt_switches"):
                        v = int(line.split()[1])
                    elif line.startswith(b"nonvoluntary_ctxt_switches"):
                        n = int(line.split()[1])
        except (OSError, ValueError, IndexError):
            continue
        if v is not None and n is not None:
            out[int(name)] = (v, n)
    return out


def read_disks(proc: Path = Path("/proc"), sys_block: Path = Path("/sys/block")) -> dict:
    """{disk: (sectors read, sectors written, ms doing I/O)} for the physical disks."""
    out: dict[str, tuple[int, int, int]] = {}
    try:
        lines = (proc / "diskstats").read_text().splitlines()
    except OSError:
        return out
    for line in lines:
        f = line.split()
        if len(f) < 14 or not (sys_block / f[2] / "device").exists():
            continue
        try:
            out[f[2]] = (int(f[5]), int(f[9]), int(f[12]))
        except ValueError:
            continue
    return out


def read_gpus(drm: Path = Path("/sys/class/drm")) -> list[dict]:
    """Each card: {vendor, awake} for every one (only `power/runtime_status` is read, so a sleeping card stays asleep),
    and for an awake AMD card {busy, level, levels: [MHz], vram, total} from its own counters."""
    out = []
    try:
        cards = sorted(p for p in drm.iterdir() if p.name.startswith("card") and "-" not in p.name)
    except OSError:
        return out
    for card in cards:
        d = card / "device"
        def read(name):
            try:
                return (d / name).read_text().strip()
            except OSError:
                return ""
        vendor, status = read("vendor"), read("power/runtime_status")
        gpu = {"card": card.name, "vendor": {"0x1002": "AMD", "0x10de": "NVIDIA", "0x8086": "INTEL"}.get(vendor, vendor),
               "awake": status != "suspended"}
        if vendor == "0x1002" and gpu["awake"]:
            try:
                gpu["busy"] = int(read("gpu_busy_percent") or 0) / 100
                ladder = read("pp_dpm_sclk").splitlines()
                gpu["levels"] = [int("".join(c for c in line.split(":")[1] if c.isdigit()) or 0) for line in ladder if ":" in line]
                gpu["level"] = next((i for i, line in enumerate(ladder) if line.rstrip().endswith("*")), 0)
                gpu["vram"], gpu["total"] = int(read("mem_info_vram_used") or 0), int(read("mem_info_vram_total") or 0)
            except ValueError:
                pass
        out.append(gpu)
    return out


def read_swap(proc: Path = Path("/proc")) -> dict:
    """{in, out} pages swapped in and out since boot (/proc/vmstat), {used, total} bytes (/proc/meminfo)."""
    out = {"in": 0, "out": 0, "used": 0, "total": 0}
    try:
        for line in (proc / "vmstat").read_text().splitlines():
            k, _, v = line.partition(" ")
            if k == "pswpin":
                out["in"] = int(v)
            elif k == "pswpout":
                out["out"] = int(v)
        info = {}
        for line in (proc / "meminfo").read_text().splitlines():
            k, _, v = line.partition(":")
            if k in ("SwapTotal", "SwapFree"):
                info[k] = int(v.split()[0]) * 1024
        out["total"] = info.get("SwapTotal", 0)
        out["used"] = max(0, out["total"] - info.get("SwapFree", 0))
    except (OSError, ValueError, IndexError):
        pass
    return out


CPU_SENSORS = ("k10temp", "coretemp", "zenpower", "cpu_thermal")


def read_thermal(hwmon: Path = Path("/sys/class/hwmon")) -> dict:
    """{temp (°C), sensor}: the processor's own sensor (k10temp, coretemp, …), else the hottest ACPI zone; never a
    graphics card's (reading a sleeping card's sensor could wake it)."""
    found: dict[str, float] = {}
    try:
        for h in hwmon.iterdir():
            try:
                name = (h / "name").read_text().strip()
                found.setdefault(name, int((h / "temp1_input").read_text().strip()) / 1000)
            except (OSError, ValueError):
                continue
    except OSError:
        return {"temp": None, "sensor": ""}
    for name in CPU_SENSORS:
        if name in found:
            return {"temp": round(found[name], 1), "sensor": name}
    if "acpitz" in found:
        return {"temp": round(found["acpitz"], 1), "sensor": "acpitz"}
    return {"temp": None, "sensor": ""}


class Telemetry:
    def __init__(self, clock, active: Callable[[], bool], proc: Path = Path("/proc"), sys_block: Path = Path("/sys/block"),
                 drm: Path = Path("/sys/class/drm"), hwmon: Path = Path("/sys/class/hwmon")):
        self.clock, self.active, self.proc, self.sys_block, self.drm, self.hwmon = clock, active, proc, sys_block, drm, hwmon
        self.last: dict = {}
        self.average: dict[str, float] = {}
        self.sched_last: dict = {}
        self.disk_last: dict = {}
        self.swap_last: dict = {}

    def forget(self):
        self.last, self.average = {}, {}
        self.sched_last, self.disk_last, self.swap_last = {}, {}, {}

    def thermal(self) -> dict:
        if not self.active():
            return {"running": False}
        return {"running": True, **read_thermal(self.hwmon)}

    def swap(self) -> dict:
        if not self.active():
            self.forget()
            return {"running": False}
        now = self.clock.now().boot
        reading = read_swap(self.proc)
        last, self.swap_last = self.swap_last, {"at": now, **reading}
        rates = {"in": 0, "out": 0}
        if last and 0 < now - last["at"] <= STALE:
            dt = now - last["at"]
            rates = {k: round(max(0, reading[k] - last[k]) / dt, 1) for k in ("in", "out")}
        return {"running": True, **rates, "used": reading["used"], "total": reading["total"]}

    def gpu(self) -> dict:
        if not self.active():
            return {"running": False}
        return {"running": True, "gpus": read_gpus(self.drm)}

    def disk(self) -> dict:
        if not self.active():
            self.forget()
            return {"running": False}
        now = self.clock.now().boot
        disks = read_disks(self.proc, self.sys_block)
        last, self.disk_last = self.disk_last, {"at": now, "disks": disks}
        if not last or now - last["at"] <= 0 or now - last["at"] > STALE:
            return {"running": True, "read": 0, "written": 0, "busy": 0.0}
        dt = now - last["at"]
        read = written = 0
        busy = 0.0
        for name, (r, w, ms) in disks.items():
            before = last["disks"].get(name)
            if not before:
                continue
            read += max(0, r - before[0]) * 512
            written += max(0, w - before[1]) * 512
            busy = max(busy, min(1.0, max(0, ms - before[2]) / 1000 / dt))
        return {"running": True, "read": round(read / dt), "written": round(written / dt), "busy": round(busy, 3)}

    def sched(self) -> dict:
        if not self.active():
            self.forget()
            return {"running": False}
        now = self.clock.now().boot
        stat, switches = read_stat(self.proc), read_switches(self.proc)
        last, self.sched_last = self.sched_last, {"at": now, "stat": stat, "switches": switches}
        if not last or now - last["at"] <= 0 or now - last["at"] > STALE:
            return {"running": True, "cores": [], "runnable": stat["runnable"], "blocked": stat["blocked"],
                    "ctxt": 0, "voluntary": 0, "involuntary": 0}
        dt = now - last["at"]
        cores = []
        for (busy, total), (b0, t0) in zip(stat["cores"], last["stat"]["cores"]):
            cores.append(round(max(0.0, min(1.0, (busy - b0) / (total - t0))), 3) if total > t0 else 0.0)
        vol = inv = 0
        for pid, (v, n) in switches.items():
            before = last["switches"].get(pid)
            if before and v >= before[0] and n >= before[1]:
                vol += v - before[0]
                inv += n - before[1]
        return {"running": True, "cores": cores, "runnable": stat["runnable"], "blocked": stat["blocked"],
                "ctxt": round(max(0, stat["ctxt"] - last["stat"]["ctxt"]) / dt),
                "voluntary": round(vol / dt), "involuntary": round(inv / dt)}

    def sample(self) -> dict:
        if not self.active():
            self.forget()
            return {"running": False}
        now = self.clock.now().boot
        irq, (rx, tx) = read_interrupts(self.proc), read_net(self.proc)
        last, self.last = self.last, {"at": now, "irq": irq, "rx": rx, "tx": tx}
        if not last or now - last["at"] <= 0 or now - last["at"] > STALE:
            return {"running": True, "rain": [], "total": 0, "spikes": [], "net": {"rx": 0, "tx": 0}}
        dt = now - last["at"]
        rain, spikes = [], []
        for kind in sorted(irq):
            rate = max(0, irq[kind] - last["irq"].get(kind, irq[kind])) / dt
            avg = self.average.get(kind)
            if avg is not None and rate >= SPIKE_FLOOR and rate > SPIKE * avg:
                spikes.append(kind)
            self.average[kind] = rate if avg is None else avg + (rate - avg) * EMA
            rain.append({"kind": kind, "rate": round(rate, 1)})
        return {"running": True, "rain": rain, "total": round(sum(r["rate"] for r in rain), 1), "spikes": spikes,
                "net": {"rx": round(max(0, rx - last["rx"]) / dt), "tx": round(max(0, tx - last["tx"]) / dt)}}
