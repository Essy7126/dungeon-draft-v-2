#!/usr/bin/env python3
"""Compare l'identité exacte des échecs GUT à la baseline historique."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
SCRIPT = re.compile(r"(?:res://)?(?:test/unit/)?(test_[^/\\]+\.gd)\s*$")
FAILED_TEST = re.compile(r"^-\s+(test_[A-Za-z0-9_]+)\s*$")


def parse_failures(text: str) -> set[str]:
    current = ""
    failures: set[str] = set()
    for raw in ANSI.sub("", text).splitlines():
        line = raw.strip()
        match = SCRIPT.search(line.replace("\\", "/"))
        if match:
            current = match.group(1)
            continue
        match = FAILED_TEST.match(line)
        if match and current:
            failures.add(f"{current}::{match.group(1)}")
    return failures


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: verify_gut_historical_allowlist.py GLOBAL_LOG ALLOWLIST_JSON")
        return 2
    observed = parse_failures(Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
    expected = set(json.loads(Path(sys.argv[2]).read_text(encoding="utf-8")))
    added = sorted(observed - expected)
    missing = sorted(expected - observed)
    print(f"Observed failures: {len(observed)}; expected: {len(expected)}")
    if added:
        print("New failures:")
        print("\n".join(f"  + {item}" for item in added))
    if missing:
        print("Historical failures missing (baseline update required):")
        print("\n".join(f"  - {item}" for item in missing))
    if added or missing:
        return 1
    print("Exact historical allowlist matched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
