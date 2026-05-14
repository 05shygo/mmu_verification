#!/usr/bin/env python3
"""PTW stage-6 P0 closure log gate.

This script is intentionally lightweight.  It checks that every test in the P0
list produced a clean log with source-SB and Stage-5 SVA evidence, and that the
Stage-6 closure report/CSV still names every P0 ADD/FLOW item.
"""

from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path


SB_RE = re.compile(
    r"PTW_SOURCE_SB_SUMMARY\b(?=.*\bmismatch=0\b)(?=.*\bpending=0\b)(?=.*\billegal=0\b)"
)
COVER_RE = re.compile(r"PTW_SVA_COVER\b.*\bhits=([1-9][0-9]*)\b")
ERROR_RE = re.compile(
    r"\b(UVM_ERROR|UVM_FATAL)\s+"
    r"|\b(assert(?:ion)?|sva)\b[^\n]{0,80}\b(fail|failed)\b"
    r"|\bTEST FAILED\b|\bFAILED:",
    re.IGNORECASE,
)


def strip_inline_comment(line: str) -> str:
    out = []
    in_single = False
    in_double = False
    for char in line:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            break
        out.append(char)
    return "".join(out).strip()


def load_tests(list_path: Path) -> list[str]:
    tests: list[str] = []
    for raw in list_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_inline_comment(raw)
        if not line:
            continue
        tokens = shlex.split(line)
        if tokens:
            tests.append(tokens[0])
    return tests


def check_log(log_path: Path) -> list[str]:
    errors: list[str] = []
    if not log_path.is_file():
        return [f"missing log: {log_path}"]
    text = log_path.read_text(encoding="utf-8", errors="ignore")
    if ERROR_RE.search(text):
        errors.append(f"{log_path}: error/fatal/fail pattern found")
    if not SB_RE.search(text):
        errors.append(f"{log_path}: missing clean PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0")
    if not COVER_RE.search(text):
        errors.append(f"{log_path}: missing PTW_SVA_COVER with hits>0")
    if "PTW_STAGE6_CLOSURE" not in text and "PTW_FLOW_BIND" not in text:
        errors.append(f"{log_path}: missing PTW_STAGE6_CLOSURE/PTW_FLOW_BIND markers")
    return errors


def required_ids(prefix: str, first: int, last: int) -> list[str]:
    return [f"{prefix}-{idx:03d}" for idx in range(first, last + 1)]


def check_artifact_ids(path: Path, ids: list[str], label: str) -> list[str]:
    if not path.is_file():
        return [f"missing {label}: {path}"]
    text = path.read_text(encoding="utf-8", errors="ignore")
    missing = [item for item in ids if item not in text]
    if missing:
        return [f"{path}: missing {label} IDs: {', '.join(missing)}"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description="PTW stage-6 P0 exit gate")
    parser.add_argument("--list", required=True, type=Path)
    parser.add_argument("--log-dir", required=True, type=Path)
    parser.add_argument("--seed", required=True)
    parser.add_argument("--closure", required=True, type=Path)
    parser.add_argument("--csv", required=True, type=Path)
    args = parser.parse_args()

    errors: list[str] = []
    tests = load_tests(args.list)
    if not tests:
        errors.append(f"no tests found in {args.list}")

    for test in tests:
        errors.extend(check_log(args.log_dir / f"{test}_{args.seed}.log"))

    add_ids = required_ids("PTW-ADD", 1, 34)
    flow_ids = required_ids("PTW-FLOW", 1, 23)
    errors.extend(check_artifact_ids(args.closure, add_ids + flow_ids, "closure report"))
    errors.extend(check_artifact_ids(args.csv, add_ids + flow_ids, "closure csv"))

    if errors:
        print("PTW_STAGE6_EXIT_GATE status=FAIL")
        for item in errors:
            print(f"  - {item}")
        return 1

    print(
        f"PTW_STAGE6_EXIT_GATE status=PASS tests={len(tests)} seed={args.seed} "
        "source_sb=clean sva_cover=hit closure_ids=present"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
