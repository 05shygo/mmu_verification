#!/usr/bin/env python3
"""Validate that a VCS coverage VDB was compiled with required code metrics."""

import argparse
import gzip
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Set


def parse_metric_list(raw: str) -> Set[str]:
    return {item for item in re.split(r"[+,\s]+", raw.strip()) if item}


def parse_vcm_metrics(vdb: Path) -> Set[str]:
    vcm_args = vdb / "snps/coverage/db/auxiliary/vcmArguments.xml"
    if not vcm_args.is_file():
        raise FileNotFoundError(f"missing VCS coverage arguments XML: {vcm_args}")

    metrics: Set[str] = set()
    with gzip.open(vcm_args, "rb") as handle:
        root = ET.parse(handle).getroot()

    for node in root.iter("vcm_arg_data"):
        opt = node.attrib.get("vcm_opt", "")
        match = re.match(r"\s*-cm\s+(.+?)\s*$", opt)
        if match:
            metrics.update(parse_metric_list(match.group(1)))
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check whether a VCS VDB has coverage compile context."
    )
    parser.add_argument("--vdb", required=True, help="Coverage VDB directory")
    parser.add_argument(
        "--metrics",
        default="line+cond+fsm+tgl+branch+assert",
        help="Required coverage metrics, separated by +, comma, or space",
    )
    parser.add_argument("--label", default="coverage VDB", help="Name shown in diagnostics")
    args = parser.parse_args()

    vdb = Path(args.vdb)
    required = parse_metric_list(args.metrics)
    if not vdb.is_dir():
        print(f"ERROR: {args.label} is missing: {vdb}", file=sys.stderr)
        return 1

    try:
        found = parse_vcm_metrics(vdb)
    except Exception as exc:
        print(f"ERROR: cannot inspect {args.label} at {vdb}: {exc}", file=sys.stderr)
        return 1

    missing = sorted(required - found)
    if missing:
        print(
            f"ERROR: {args.label} at {vdb} is not a complete coverage compile context.",
            file=sys.stderr,
        )
        print(f"       missing metrics: {'+'.join(missing)}", file=sys.stderr)
        print(f"       found metrics   : {'+'.join(sorted(found)) or '<none>'}", file=sys.stderr)
        print("       Re-run: make comp COV_FORCE_REBUILD=1", file=sys.stderr)
        return 1

    print(f"[PASS] {args.label}: coverage metrics {'+'.join(sorted(required))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
