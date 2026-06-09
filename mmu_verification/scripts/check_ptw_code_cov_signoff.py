#!/usr/bin/env python3
"""Validate that the PTW code coverage summary is a final signoff PASS."""

import argparse
import json
import sys
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check PTW code coverage signoff summary")
    parser.add_argument("--summary-json", default="output/ptw_cov/ptw_code_coverage_summary.json")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary_path = Path(args.summary_json)
    if not summary_path.is_file():
        print(f"PTW_CODE_COV_SIGNOFF_CHECK status=FAIL reason=summary_missing summary={summary_path}")
        return 1
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"PTW_CODE_COV_SIGNOFF_CHECK status=FAIL reason=summary_invalid error={exc} summary={summary_path}")
        return 1

    profile = str(data.get("profile", ""))
    status = str(data.get("status", ""))
    reason = str(data.get("reason", ""))
    functional_gate = data.get("functional_gate", {})
    gate_status = str(functional_gate.get("status", "UNKNOWN")) if isinstance(functional_gate, dict) else "UNKNOWN"

    ok = profile == "signoff" and status == "PASS" and gate_status in {"PASS", "REUSED"}
    result = "PASS" if ok else "FAIL"
    print(
        "PTW_CODE_COV_SIGNOFF_CHECK "
        f"status={result} profile={profile} summary_status={status} "
        f"reason={reason} functional_gate={gate_status} summary={summary_path}"
    )
    if not ok:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
