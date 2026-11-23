#!/usr/bin/env python3
"""Compare two cores scenario by scenario (Z226; docs/PARITY_HARNESS.md).

    tools/parity.py                         Python core vs core-cpp/build/fartd-cpp (Python vs Python if not built)
    tools/parity.py --b path/to/fartd-cpp   name the second core
    tools/parity.py -k tasks                only scenarios whose name contains "tasks"
    tools/parity.py --stage 1               only stages up to 1 (0 and 1)

Each scenario's own checks must pass on both cores; then every observation (normalised: times and pids as type
tags, random ids as aliases) must be equal, in order and key order. Python vs Python is the harness's self-test:
any difference there is noise the normaliser must learn, not a core difference.
"""
from __future__ import annotations

import argparse
import difflib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

from parity.harness import available_cores, core_name  # noqa: E402
from parity.scenarios import SCENARIOS, run_scenario  # noqa: E402

STAGES = ["0", "1", "2a", "2b", "3a", "3b", "3c", "4", "5"]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", default="python")
    parser.add_argument("--b", default=available_cores()[-1])
    parser.add_argument("-k", default="")
    parser.add_argument("--stage", choices=STAGES)
    args = parser.parse_args(argv)
    last = STAGES.index(args.stage) if args.stage else len(STAGES) - 1
    chosen = [sc for sc in SCENARIOS.values() if args.k in sc.name and STAGES.index(sc.stage) <= last]
    a, b = core_name(args.a), core_name(args.b)
    print(f"{len(chosen)} scenarios: {a} vs {b}")
    failed = 0
    for sc in chosen:
        records = {}
        for label, which in (("a", args.a), ("b", args.b)):
            try:
                records[label] = run_scenario(sc, which)[0].lines()
            except Exception as error:  # a failed check: report it and keep going
                records[label] = None
                print(f"  FAIL {sc.name} on {core_name(which)}: {str(error).splitlines()[0]}")
        if None in records.values():
            failed += 1
            continue
        if records["a"] == records["b"]:
            print(f"  ok   {sc.name} ({len(records['a'])} observations)")
            continue
        failed += 1
        print(f"  DIFF {sc.name}")
        for line in difflib.unified_diff(records["a"], records["b"], a, b, lineterm="", n=1):
            print("       " + line[:300])
    print(f"{len(chosen) - failed}/{len(chosen)} equal")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
