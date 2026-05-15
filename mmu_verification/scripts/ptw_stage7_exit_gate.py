#!/usr/bin/env python3
"""PTW stage-7 P1/P2/random exit gate.

The gate checks that Stage-7 logs are clean, that source-SB field summaries are
present, and that P2/illegal tests classify illegal stimulus as constrained
instead of reporting a DUT failure.
"""

from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path


SB_RE = re.compile(
    r"PTW_SOURCE_SB_SUMMARY\b(?=.*\bstage=7\b)(?=.*\bmismatch=0\b)"
    r"(?=.*\bpending=0\b)(?=.*\billegal=0\b)"
)
FIELD_RE = re.compile(r"PTW_SOURCE_SB_FIELD_COVERAGE\b(?=.*\bstage=7\b)")
REF_RE = re.compile(r"PTW_SOURCE_REF_SUMMARY\b(?=.*\bstage=7\b)")
ERROR_RE = re.compile(
    r"\b(UVM_ERROR|UVM_FATAL)\b(?!(?:\s*[:=]\s*0\b))"
    r"|\b(assert(?:ion)?|sva)\b[^\n]{0,80}\b(fail|failed)\b"
    r"|\bTEST FAILED\b|\bFAILED:",
    re.IGNORECASE,
)


P2_TESTS = {
    "test_ptw_same_id_no_reuse_constraint_001",
    "test_ptw_bare_mode_no_request_constraint_001",
    "test_ptw_p2_illegal_constraint_matrix",
}

PURE_ILLEGAL_TESTS = {
    "test_ptw_p2_illegal_constraint_matrix",
}


def strip_inline_comment(line: str) -> str:
    out: list[str] = []
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


def check_log(log_path: Path, test: str) -> list[str]:
    errors: list[str] = []
    if not log_path.is_file():
        return [f"missing log: {log_path}"]
    text = log_path.read_text(encoding="utf-8", errors="ignore")
    if ERROR_RE.search(text):
        errors.append(f"{log_path}: error/fatal/fail pattern found")
    if "PTW_SOURCE_MISMATCH" in text or "PTW_SOURCE_DROP_MISMATCH" in text:
        errors.append(f"{log_path}: source mismatch marker found")
    requires_source_summary = test not in PURE_ILLEGAL_TESTS
    if requires_source_summary and not SB_RE.search(text):
        errors.append(f"{log_path}: missing clean stage-7 PTW_SOURCE_SB_SUMMARY")
    if requires_source_summary and not FIELD_RE.search(text):
        errors.append(f"{log_path}: missing PTW_SOURCE_SB_FIELD_COVERAGE")
    if requires_source_summary and not REF_RE.search(text):
        errors.append(f"{log_path}: missing PTW_SOURCE_REF_SUMMARY stage=7")
    if "PTW_STAGE7_TEST_SUMMARY" not in text:
        errors.append(f"{log_path}: missing PTW_STAGE7_TEST_SUMMARY")
    if test in P2_TESTS and "PTW_STAGE7_ILLEGAL status=blocked_by_constraint" not in text:
        errors.append(f"{log_path}: P2 test missing blocked-by-constraint marker")
    if "consumer_only_does_not_close_source=1" not in text and requires_source_summary:
        errors.append(f"{log_path}: missing consumer-only source-closure separation marker")
    return errors


def check_csv(csv_path: Path) -> list[str]:
    if not csv_path.is_file():
        return [f"missing closure csv: {csv_path}"]
    text = csv_path.read_text(encoding="utf-8", errors="ignore")
    required = [
        "test_ptw_pde_satp_old_walk_reupdate_001",
        "test_ptw_pmp_cfg_clear_no_flush_001",
        "test_ptw_asid_refill_current_sample_001",
        "test_ptw_maee_mid_sysmap_change_001",
        "test_ptw_random_pte_perm_cross_001",
        "test_ptw_same_id_no_reuse_constraint_001",
        "test_ptw_bare_mode_no_request_constraint_001",
        "test_ptw_p2_illegal_constraint_matrix",
        "consumer-only",
    ]
    missing = [item for item in required if item not in text]
    if missing:
        return [f"{csv_path}: missing Stage-7 closure tokens: {', '.join(missing)}"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description="PTW stage-7 P1/P2/random exit gate")
    parser.add_argument("--list", action="append", required=True, type=Path)
    parser.add_argument("--log-dir", required=True, type=Path)
    parser.add_argument("--seed", required=True)
    parser.add_argument("--csv", required=True, type=Path)
    args = parser.parse_args()

    errors: list[str] = []
    tests: list[str] = []
    for list_path in args.list:
        loaded = load_tests(list_path)
        if not loaded:
            errors.append(f"no tests found in {list_path}")
        tests.extend(loaded)

    for test in tests:
        errors.extend(check_log(args.log_dir / f"{test}_{args.seed}.log", test))

    errors.extend(check_csv(args.csv))

    if errors:
        print("PTW_STAGE7_EXIT_GATE status=FAIL")
        for item in errors:
            print(f"  - {item}")
        return 1

    print(
        f"PTW_STAGE7_EXIT_GATE status=PASS tests={len(tests)} seed={args.seed} "
        "source_sb=clean field_coverage=present p2_illegal=blocked"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
