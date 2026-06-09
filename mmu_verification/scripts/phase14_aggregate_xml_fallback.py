#!/usr/bin/env python3
"""Generate a Phase14 XML fallback coverage report from one aggregate VDB."""

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from phase14_merge_parallel_coverage import run_xml_fallback_report  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Emit the Phase14 XML-derived coverage fallback report when URG "
            "cannot render an aggregate VDB on this host."
        )
    )
    parser.add_argument("--vdb", required=True, help="Aggregate coverage VDB")
    parser.add_argument("--report-dir", required=True, help="Fallback report directory")
    parser.add_argument("--merged-db", required=True, help="Expected official merged VDB path")
    parser.add_argument("--log", required=True, help="URG log to append fallback diagnostics to")
    parser.add_argument("--stage", default="aggregate VDB URG", help="URG stage that failed")
    parser.add_argument("--rc", type=int, default=1, help="URG return code")
    args = parser.parse_args()

    return run_xml_fallback_report(
        [Path(args.vdb)],
        Path(args.report_dir),
        Path(args.merged_db),
        Path(args.log),
        args.stage,
        args.rc,
    )


if __name__ == "__main__":
    raise SystemExit(main())
