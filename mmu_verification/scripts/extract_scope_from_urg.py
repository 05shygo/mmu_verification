#!/usr/bin/env python3
"""Extract scope-specific coverage from an official URG report.

Reads modinfo.txt (per-instance covered/total counts) and aggregates all
instances matching the scope's hierarchy prefixes.  This honors whatever
exclusions were applied at URG report time via -elfile, because it reads the
post-exclusion report.

The output JSON matches the schema produced by generate_scope_fallback_report.py
so that scope_coverage_gate.py can consume it unchanged.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


# Metric section headers in modinfo.txt
METRIC_HEADERS = {
    "line": "Line Coverage for Instance :",
    "branch": "Branch Coverage for Instance :",
    "cond": "Cond Coverage for Instance :",
    "tgl": "Toggle Coverage for Instance :",
    "fsm": "FSM Coverage for Instance :",
    "assertion": "Assert Coverage for Instance :",
}

# For toggle, use "Total Bits" (bit-level) row, not "Totals" (signal-level)
TOGGLE_TOTAL_ROW = "Total Bits"
# For line/branch/cond, use the "TOTAL" summary row
SUMMARY_TOTAL_ROW = "TOTAL"
# For FSM, sum transitions across all FSMs
FSM_TRANSITIONS_RE = re.compile(r"^Transitions\s+(\d+)\s+(\d+)\s+")
# For assertion, use "Assertions" row: "Assertions  <total> <attempted> <pct> ..."
ASSERT_RE = re.compile(r"^\s*Assertions\s+(\d+)\s+(\d+)")


def normalize_instance(raw: str) -> str:
    """Strip the trailing (x) / (N) parameterization marker."""
    return re.sub(r"\([^)]*\)\s*$", "", raw.strip())


def matches_scope(name: str, prefixes: Sequence[str]) -> bool:
    for prefix in prefixes:
        if name == prefix or name.startswith(prefix + "."):
            return True
    return False


def parse_modinfo(report_dir: Path, scope_prefixes: Sequence[str]) -> Dict[str, Dict[str, int]]:
    """Parse modinfo.txt and aggregate covered/total per metric for scope instances.

    Returns {metric: {"covered": int, "total": int}}.
    """
    modinfo = report_dir / "modinfo.txt"
    if not modinfo.is_file():
        return {}

    text = modinfo.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()

    agg: Dict[str, Dict[str, int]] = {m: {"covered": 0, "total": 0, "objects": 0} for m in METRIC_HEADERS}

    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        # Detect instance header for any metric
        matched_metric: Optional[str] = None
        matched_instance: Optional[str] = None
        for metric, header in METRIC_HEADERS.items():
            if line.startswith(header):
                rest = line[len(header):].strip()
                matched_instance = normalize_instance(rest)
                matched_metric = metric
                break

        if matched_metric is None or matched_instance is None:
            i += 1
            continue

        if not matches_scope(matched_instance, scope_prefixes):
            i += 1
            continue

        # Found a matching instance section; parse the covered/total
        agg[matched_metric]["objects"] += 1

        if matched_metric == "tgl":
            # Find "Total Bits" row (bit-level toggle): "Total Bits  <total> <covered> <pct>"
            for j in range(i + 1, min(i + 10, n)):
                row = lines[j].strip()
                if row.startswith(TOGGLE_TOTAL_ROW + " ") or row == TOGGLE_TOTAL_ROW:
                    parts = row.split()
                    # ["Total", "Bits", total, covered, pct]
                    if len(parts) >= 4:
                        try:
                            total = int(parts[2]); covered = int(parts[3])
                            agg["tgl"]["total"] += total
                            agg["tgl"]["covered"] += covered
                        except ValueError:
                            pass
                    break
        elif matched_metric == "fsm":
            # Sum all "Transitions" rows within this instance section
            for j in range(i + 1, min(i + 300, n)):
                row = lines[j].strip()
                if any(row.startswith(h) for h in METRIC_HEADERS.values()):
                    break
                m = FSM_TRANSITIONS_RE.match(row)
                if m:
                    total = int(m.group(1)); covered = int(m.group(2))
                    agg["fsm"]["total"] += total
                    agg["fsm"]["covered"] += covered
        elif matched_metric == "assertion":
            # Find "Assertions" row: "Assertions  <total> <attempted> <pct> <succ> <pct>"
            for j in range(i + 1, min(i + 15, n)):
                row = lines[j]
                if any(row.strip().startswith(h) for h in METRIC_HEADERS.values()):
                    break
                m = ASSERT_RE.match(row)
                if m:
                    total = int(m.group(1)); covered = int(m.group(2))
                    agg["assertion"]["total"] += total
                    agg["assertion"]["covered"] += covered
                    break
        elif matched_metric == "branch":
            # "Branches  <total> <covered> <pct>"
            for j in range(i + 1, min(i + 12, n)):
                row = lines[j].strip()
                if any(row.startswith(h) for h in METRIC_HEADERS.values()):
                    break
                if row.startswith("Branches ") or row.startswith("Branches\t"):
                    parts = row.split()
                    if len(parts) >= 3:
                        try:
                            total = int(parts[1]); covered = int(parts[2])
                            agg["branch"]["total"] += total
                            agg["branch"]["covered"] += covered
                        except ValueError:
                            pass
                    break
        elif matched_metric == "cond":
            # "Conditions  <total> <covered> <pct>"
            for j in range(i + 1, min(i + 12, n)):
                row = lines[j].strip()
                if any(row.startswith(h) for h in METRIC_HEADERS.values()):
                    break
                if row.startswith("Conditions ") or row.startswith("Conditions\t"):
                    parts = row.split()
                    if len(parts) >= 3:
                        try:
                            total = int(parts[1]); covered = int(parts[2])
                            agg["cond"]["total"] += total
                            agg["cond"]["covered"] += covered
                        except ValueError:
                            pass
                    break
        else:
            # line: find "TOTAL" summary row: "TOTAL  <total> <covered> <pct>"
            for j in range(i + 1, min(i + 12, n)):
                row = lines[j].strip()
                if any(row.startswith(h) for h in METRIC_HEADERS.values()):
                    break
                if row.startswith(SUMMARY_TOTAL_ROW + " ") or row.startswith(SUMMARY_TOTAL_ROW + "\t"):
                    parts = row.split()
                    if len(parts) >= 3:
                        try:
                            total = int(parts[1]); covered = int(parts[2])
                            agg[matched_metric]["total"] += total
                            agg[matched_metric]["covered"] += covered
                        except ValueError:
                            pass
                    break

        i += 1

    return agg


# Default functional covergroup patterns per scope (matches generate_scope_fallback_report.py)
SCOPE_FUNCTIONAL_GROUPS = {
    "L1TLB": ["cg_l1dtlb", "cg_l1itlb"],
    "L2TLB": ["cg_l2tlb_bank", "cg_l2_reqq"],
    "PTW": ["cg_ptw_walk", "cg_ptw_ready_transition", "cg_twu"],
}


def parse_functional(report_dir: Path, scope_name: str) -> Dict[str, object]:
    """Parse groups.txt to compute scope-specific functional coverage.

    Reads per-covergroup SCORE from URG groups.txt, filters by scope patterns,
    and reports the average score.
    """
    groups_txt = report_dir / "groups.txt"
    if not groups_txt.is_file():
        return {"percent": None, "covered": 0, "total": 0, "objects": 0}
    patterns = SCOPE_FUNCTIONAL_GROUPS.get(scope_name, [])
    if not patterns:
        return {"percent": None, "covered": 0, "total": 0, "objects": 0}

    text = groups_txt.read_text(encoding="utf-8", errors="ignore")
    scores: List[float] = []
    for line in text.splitlines():
        line_s = line.strip()
        # Each covergroup row ends with the NAME in the last column
        for pat in patterns:
            token = pat.lower()
            if line_s.lower().endswith(token) or ("::" + token) in line_s.lower():
                # First column is SCORE
                parts = line_s.split()
                if parts:
                    try:
                        score = float(parts[0])
                        if 0.0 <= score <= 100.0:
                            scores.append(score)
                    except ValueError:
                        pass
                break

    if not scores:
        return {"percent": None, "covered": 0, "total": 0, "objects": 0}
    avg = sum(scores) / len(scores)
    return {
        "percent": avg,
        "covered": round(avg),
        "total": 100,
        "objects": len(scores),
        "method": f"average of {len(scores)} scope covergroup scores from URG groups.txt",
    }


def build_scope_json(
    scope_name: str,
    scope_prefixes: Sequence[str],
    agg: Dict[str, Dict[str, int]],
    functional: Dict[str, object],
) -> Dict[str, object]:
    """Build the JSON structure matching scope_coverage_gate.py JSON_METRIC_KEYS."""
    metrics_json: Dict[str, Dict[str, object]] = {}
    # JSON keys must match scope_coverage_gate.JSON_METRIC_KEYS exactly
    # line->line, branch->branch, cond->cond, tgl->tgl, fsm->fsm, assertion->assertion
    for key in ("line", "branch", "cond", "tgl", "fsm", "assertion"):
        entry = agg.get(key, {"covered": 0, "total": 0})
        covered = entry["covered"]; total = entry["total"]
        pct = (covered * 100.0 / total) if total else None
        metrics_json[key] = {
            "metric": key,
            "covered": covered,
            "total": total,
            "percent": pct,
            "objects": entry.get("objects", 0),
            "method": "aggregated from URG modinfo.txt per-instance counts (post-elfile)",
        }
    metrics_json["functional"] = {
        "metric": "functional",
        **functional,
    }

    return {
        "schema_version": "phase14_scope_urg_extract_v1",
        "kind": "scope_urg_extract",
        "scopes": {
            scope_name: {
                "instances": list(scope_prefixes),
                "metrics": metrics_json,
            }
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract scope coverage from URG modinfo.txt")
    parser.add_argument("--urg-report-dir", required=True, help="Official URG report directory (with modinfo.txt)")
    parser.add_argument("--scope-name", required=True, help="Scope name, e.g. L1TLB")
    parser.add_argument("--scope-instances", required=True, help="Comma-separated hierarchy prefixes")
    parser.add_argument("--output", required=True, help="Output JSON path (scope_coverage_summary.json)")
    args = parser.parse_args()

    report_dir = Path(args.urg_report_dir)
    prefixes = [p.strip() for p in args.scope_instances.split(",") if p.strip()]
    # Normalize prefixes: allow both "u_dut.u_mmu_l1dtlb" and "tb_top.u_dut.u_mmu_l1dtlb"
    norm_prefixes: List[str] = []
    for p in prefixes:
        if not p.startswith("tb_top"):
            norm_prefixes.append("tb_top." + p)
        norm_prefixes.append(p)

    agg = parse_modinfo(report_dir, norm_prefixes)
    if not agg or all(v["total"] == 0 for v in agg.values()):
        print(f"ERROR: no scope instances matched in {report_dir}/modinfo.txt", file=sys.stderr)
        return 2

    functional = parse_functional(report_dir, args.scope_name)
    doc = build_scope_json(args.scope_name, prefixes, agg, functional)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=4, sort_keys=True) + "\n", encoding="utf-8")

    # Print a summary
    print(f"[extract_scope_from_urg] scope={args.scope_name} report={report_dir}")
    for label in ("line", "branch", "cond", "tgl", "fsm", "assertion", "functional"):
        m = doc["scopes"][args.scope_name]["metrics"].get(label, {})
        pct = m.get("percent")
        pct_s = f"{pct:.2f}%" if pct is not None else "N/A"
        print(f"  {label}: {pct_s}  covered={m.get('covered')} total={m.get('total')} objects={m.get('objects')}")
    print(f"[extract_scope_from_urg] wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
