#!/usr/bin/env python3
"""Extract PTW-only RTL code coverage from a URG report.

This parser is intentionally offline: it reads existing URG report artifacts and
does not invoke VCS, URG, or make. Stage 5 will call this script after the runner
has generated the report and manifest.
"""

import argparse
import datetime as _dt
import html
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


METRIC_ORDER = ["line", "condition", "branch", "fsm", "toggle", "assertion"]
HEADLINE_METRICS = ["line", "condition", "branch", "fsm", "toggle"]
ASSERTION_METRIC = "assertion"
STATUS_VALUES = {"PASS", "FAIL", "CONDITIONAL_PASS"}
FUNCTIONAL_GATE_STATUS = {"PASS", "FAIL", "SKIPPED", "REUSED", "UNKNOWN"}
PTW_ROOT = "tb_top.u_dut.x_ct_mmu_ptw"
SCHEMA_VERSION = "ptw_code_coverage_v1"

DEFAULT_THRESHOLDS = {
    "headline": 99.0,
    "line": 99.5,
    "condition": 99.0,
    "branch": 99.0,
    "fsm": 99.0,
    "toggle": 98.0,
    "assertion": 100.0,
}

ALIASES = {
    "line": ["line", "line coverage"],
    "condition": ["condition", "cond", "cond coverage", "condition coverage"],
    "branch": ["branch", "branch coverage"],
    "fsm": ["fsm", "fsm coverage"],
    "toggle": ["toggle", "tgl", "toggle coverage", "tgl coverage"],
    "assertion": ["assertion", "assert", "assert coverage", "assertion coverage"],
}

NON_PTW_SCOPE_PATTERNS = [
    r"tb_top\.u_dut\.x_ct_mmu_l1dtlb\b",
    r"tb_top\.u_dut\.x_ct_mmu_l1itlb\b",
    r"tb_top\.u_dut\.x_ct_mmu_l2tlb\b",
    r"tb_top\.u_dut\.x_ct_mmu_sysmap\b",
]


class ParseError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract PTW RTL code coverage from URG report")
    parser.add_argument("--urg-report", required=True, help="URG report directory")
    parser.add_argument("--scope", default="ptw_core")
    parser.add_argument("--hier-cfg", required=True, help="PTW coverage hierarchy configuration")
    parser.add_argument("--out-md", required=True, help="Markdown summary output")
    parser.add_argument("--out-json", required=True, help="JSON summary output")
    parser.add_argument("--manifest", help="Optional ptw_cov_manifest.json from Stage 5 runner")
    parser.add_argument("--profile", default="unknown", help="Coverage profile name")
    parser.add_argument("--cov-db", default="output/ptw_cov/simv_ptw.vdb")
    parser.add_argument("--merged-db", default="output/ptw_cov/merged_ptw.vdb")
    parser.add_argument("--headline-method", choices=["auto", "urg_total_score", "weighted_hit_total", "percent_average"], default="auto")
    parser.add_argument("--line-threshold", type=float, default=DEFAULT_THRESHOLDS["line"])
    parser.add_argument("--condition-threshold", type=float, default=DEFAULT_THRESHOLDS["condition"])
    parser.add_argument("--branch-threshold", type=float, default=DEFAULT_THRESHOLDS["branch"])
    parser.add_argument("--fsm-threshold", type=float, default=DEFAULT_THRESHOLDS["fsm"])
    parser.add_argument("--toggle-threshold", type=float, default=DEFAULT_THRESHOLDS["toggle"])
    parser.add_argument("--assertion-threshold", type=float, default=DEFAULT_THRESHOLDS["assertion"])
    parser.add_argument("--headline-threshold", type=float, default=DEFAULT_THRESHOLDS["headline"])
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def sanitize(raw: str) -> str:
    raw = html.unescape(raw)
    raw = re.sub(r"<[^>]+>", " ", raw)
    return re.sub(r"[ \t\r\f\v]+", " ", raw)


def iter_report_files(report_dir: Path) -> Iterable[Path]:
    names = ["dashboard.txt", "hierarchy.txt", "modlist.txt"]
    for name in names:
        path = report_dir / name
        if path.is_file():
            yield path
    for path in sorted(report_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.name in names:
            continue
        if path.suffix.lower() in {".txt", ".html", ".htm"}:
            yield path


def load_report_texts(report_dir: Path) -> List[Tuple[Path, str]]:
    if not report_dir.is_dir():
        raise ParseError("urg report directory does not exist: {}".format(report_dir))
    files = list(iter_report_files(report_dir))
    if not files:
        raise ParseError("urg report directory has no txt/html files: {}".format(report_dir))
    return [(path, sanitize(read_text(path))) for path in files]


def load_hier_cfg(path: Path) -> Dict[str, object]:
    if not path.is_file():
        raise ParseError("hier cfg does not exist: {}".format(path))
    roots: List[str] = []
    whitelist: List[str] = []
    excluded: List[str] = []
    for raw in read_text(path).splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("+tree"):
            parts = line.split()
            if len(parts) >= 2:
                roots.append(parts[1])
        elif line.startswith("+module"):
            parts = line.split()
            if len(parts) >= 2:
                whitelist.append(parts[1])
        elif line.startswith("-module"):
            parts = line.split()
            if len(parts) >= 2:
                excluded.append(parts[1])
    method = "instance_tree" if roots else "module_whitelist" if whitelist else "unknown"
    return {"method": method, "roots": roots, "whitelist": whitelist, "excluded": excluded, "path": str(path)}


def scope_check(report_texts: Sequence[Tuple[Path, str]], hier_cfg: Dict[str, object]) -> Dict[str, object]:
    combined = "\n".join(text for _, text in report_texts)
    method = str(hier_cfg.get("method", "unknown"))
    roots = list(hier_cfg.get("roots", []))
    whitelist = list(hier_cfg.get("whitelist", []))
    rejected: List[str] = []
    evidence: List[str] = []

    if method == "instance_tree":
        required = roots[0] if roots else PTW_ROOT
        if required in combined or PTW_ROOT in combined:
            evidence.append("required_root_found")
        else:
            # URG often reports hierarchy as indented tree, not dotted paths.
            # Try matching the last segment (instance name) in the hierarchy.
            last_seg = required.rsplit(".", 1)[-1] if "." in required else required
            if last_seg in combined:
                evidence.append("required_root_leaf_found={}".format(last_seg))
            else:
                rejected.append("required root not found in URG report: {}".format(required))
    elif method == "module_whitelist":
        if not whitelist:
            rejected.append("module whitelist is empty")
        else:
            evidence.append("module_whitelist={}".format(",".join(whitelist)))
    else:
        rejected.append("unsupported or empty hier cfg")

    for pattern in NON_PTW_SCOPE_PATTERNS:
        match = re.search(pattern, combined)
        if match:
            rejected.append("non-PTW scope found: {}".format(match.group(0)))

    return {
        "status": "PASS" if not rejected else "FAIL",
        "scope_method": method,
        "required_root": roots[0] if roots else None,
        "module_whitelist": whitelist,
        "rejected_scopes": rejected,
        "evidence": evidence,
    }


def metric_alias_regex(metric: str) -> str:
    return "|".join(re.escape(alias) for alias in ALIASES[metric])


def parse_number(raw: str) -> float:
    return float(raw.replace(",", ""))


def parse_metric_from_text(metric: str, text: str) -> Optional[Dict[str, object]]:
    alias_re = metric_alias_regex(metric)
    line_patterns = [
        re.compile(r"(?im)^\s*(?:{})(?:\s+coverage)?\s*[:| ]+\s*([0-9][0-9,]*)\s*/\s*([0-9][0-9,]*)\s*(?:\(?\s*([0-9]+(?:\.[0-9]+)?)\s*%\s*\)?)?".format(alias_re)),
        re.compile(r"(?im)^\s*(?:{})(?:\s+coverage)?\s*[:| ]+\s*([0-9][0-9,]*)\s+([0-9][0-9,]*)\s+([0-9]+(?:\.[0-9]+)?)\s*%?".format(alias_re)),
        re.compile(r"(?im)^\s*(?:{})(?:\s+coverage)?\s*[:| ]+\s*([0-9]+(?:\.[0-9]+)?)\s*%".format(alias_re)),
    ]
    for pattern in line_patterns:
        match = pattern.search(text)
        if not match:
            continue
        groups = match.groups()
        if len(groups) >= 2 and groups[1] is not None:
            hit = int(parse_number(groups[0]))
            total = int(parse_number(groups[1]))
            pct = float(groups[2]) if len(groups) >= 3 and groups[2] is not None else (100.0 * hit / total if total else None)
            return {"hit": hit, "total": total, "pct": pct, "source_kind": "hit_total"}
        pct = float(groups[0])
        return {"hit": None, "total": None, "pct": pct, "source_kind": "percentage"}

    # URG columnar format: SCORE  LINE   COND   TOGGLE FSM    BRANCH ASSERT GROUP
    #                      73.99  94.81  73.47  49.61  56.25  93.53  78.41  71.86
    metric_col_map = {"line": 1, "condition": 2, "toggle": 3, "fsm": 4, "branch": 5, "assertion": 6}
    col = metric_col_map.get(metric)
    if col is not None:
        # Find the "Total Coverage Summary" section header followed by values
        col_re = re.compile(
            r"Total\s+Coverage\s+Summary.*?\n"
            r"(?:-+\s*\n)?"
            r"\s*(?:SCORE|Score)\s+(?:LINE|Line)\s+(?:COND|Cond)\s+(?:TOGGLE|Toggle)\s+(?:FSM|Fsm)\s+(?:BRANCH|Branch)\s+(?:ASSERT|Assert)\s+(?:GROUP|Group).*?\n"
            r"\s*([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)(?:\s+[0-9]+(?:\.[0-9]+)?)?",
            re.IGNORECASE | re.DOTALL,
        )
        m = col_re.search(text)
        if m:
            vals = [float(parse_number(g)) for g in m.groups()]
            return {"hit": None, "total": None, "pct": vals[col], "source_kind": "percentage"}

    inline = re.compile(r"\b(?:{})\b[^\n%]{{0,80}}?([0-9]+(?:\.[0-9]+)?)\s*%".format(alias_re), re.IGNORECASE)
    match = inline.search(text)
    if match:
        return {"hit": None, "total": None, "pct": float(match.group(1)), "source_kind": "percentage"}

    na_re = re.compile(r"\b(?:{})\b[^\n]{{0,80}}\b(?:N/A|no objects|0\s*/\s*0)\b".format(alias_re), re.IGNORECASE)
    if na_re.search(text):
        return {"hit": 0, "total": 0, "pct": None, "source_kind": "not_applicable"}
    return None


def find_metric(metric: str, report_texts: Sequence[Tuple[Path, str]]) -> Dict[str, object]:
    for path, text in report_texts:
        parsed = parse_metric_from_text(metric, text)
        if parsed is None:
            continue
        parsed["source"] = str(path)
        return parsed
    return {"hit": None, "total": None, "pct": None, "source": None, "source_kind": "missing"}


def parse_total_score(report_texts: Sequence[Tuple[Path, str]]) -> Optional[Tuple[float, str]]:
    patterns = [
        re.compile(r"(?i)\btotal\s+(?:score|coverage)\b[^\n%]{0,80}?([0-9]+(?:\.[0-9]+)?)\s*%"),
        re.compile(r"(?i)\boverall\s+(?:score|coverage)\b[^\n%]{0,80}?([0-9]+(?:\.[0-9]+)?)\s*%"),
        # URG columnar: Total Coverage Summary followed by SCORE value
        re.compile(
            r"Total\s+Coverage\s+Summary.*?\n"
            r"(?:-+\s*\n)?"
            r"\s*(?:SCORE|Score)\s+(?:LINE|Line)\s+(?:COND|Cond)\s+(?:TOGGLE|Toggle)\s+(?:FSM|Fsm)\s+(?:BRANCH|Branch)\s+(?:ASSERT|Assert).*?\n"
            r"\s*([0-9]+(?:\.[0-9]+)?)\s+",
            re.IGNORECASE | re.DOTALL,
        ),
    ]
    for path, text in report_texts:
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                return float(match.group(1)), str(path)
    return None


def build_metrics(report_texts: Sequence[Tuple[Path, str]], thresholds: Dict[str, float]) -> Dict[str, Dict[str, object]]:
    metrics: Dict[str, Dict[str, object]] = {}
    for metric in METRIC_ORDER:
        parsed = find_metric(metric, report_texts)
        threshold = thresholds[metric]
        applicable = parsed["source_kind"] != "not_applicable"
        pct = parsed["pct"]
        if parsed["source_kind"] == "missing":
            status = "MISSING"
        elif not applicable:
            status = "N/A"
        elif pct is None:
            status = "MISSING"
        elif pct >= threshold:
            status = "PASS"
        else:
            status = "FAIL"
        item = {
            "hit": parsed["hit"],
            "total": parsed["total"],
            "pct": pct,
            "status": status,
            "applicable": applicable,
            "threshold": threshold,
            "source": parsed["source"],
            "included_in_headline": metric in HEADLINE_METRICS,
        }
        if not applicable:
            item["na_reason"] = "URG reports no applicable objects"
        metrics[metric] = item
    return metrics


def compute_headline(
    metrics: Dict[str, Dict[str, object]],
    report_texts: Sequence[Tuple[Path, str]],
    requested_method: str,
) -> Tuple[Optional[float], str, str]:
    total_score = parse_total_score(report_texts)
    if requested_method in {"auto", "urg_total_score"} and total_score is not None:
        return total_score[0], "urg_total_score", "high"

    can_weight = True
    hit_sum = 0
    total_sum = 0
    for metric in HEADLINE_METRICS:
        item = metrics[metric]
        if not item["applicable"]:
            continue
        if item["hit"] is None or item["total"] is None:
            can_weight = False
            break
        hit_sum += int(item["hit"])
        total_sum += int(item["total"])
    if requested_method in {"auto", "weighted_hit_total"} and can_weight and total_sum > 0:
        return 100.0 * hit_sum / total_sum, "weighted_hit_total", "high"

    pcts: List[float] = []
    for metric in HEADLINE_METRICS:
        item = metrics[metric]
        if item["applicable"] and item["pct"] is not None:
            pcts.append(float(item["pct"]))
    if pcts:
        confidence = "medium" if requested_method in {"auto", "percent_average"} else "low"
        return sum(pcts) / len(pcts), "percent_average", confidence
    return None, "unavailable", "low"


def extract_module_holes(report_texts: Sequence[Tuple[Path, str]], metrics: Dict[str, Dict[str, object]]) -> List[Dict[str, object]]:
    holes: List[Dict[str, object]] = []
    row_re = re.compile(
        r"(?im)^\s*(?:module\s+)?(?P<module>[A-Za-z_][A-Za-z0-9_$./]*)\s+"
        r"line=(?P<line>[0-9]+(?:\.[0-9]+)?)\s+"
        r"(?:condition|cond)=(?P<condition>[0-9]+(?:\.[0-9]+)?)\s+"
        r"branch=(?P<branch>[0-9]+(?:\.[0-9]+)?)\s+"
        r"fsm=(?P<fsm>[0-9]+(?:\.[0-9]+)?)\s+"
        r"(?:toggle|tgl)=(?P<toggle>[0-9]+(?:\.[0-9]+)?)"
    )
    keyed_row_re = re.compile(
        r"(?im)^\s*(?:module\s+)?(?P<module>[A-Za-z_][A-Za-z0-9_$./]*)\s+"
        r"(?P<line>[0-9]+(?:\.[0-9]+)?)\s+"
        r"(?P<condition>[0-9]+(?:\.[0-9]+)?)\s+"
        r"(?P<branch>[0-9]+(?:\.[0-9]+)?)\s+"
        r"(?P<fsm>[0-9]+(?:\.[0-9]+)?)\s+"
        r"(?P<toggle>[0-9]+(?:\.[0-9]+)?)"
    )
    for path, text in report_texts:
        use_plain_rows = bool(re.search(r"(?i)\bmodule\s+line\s+condition\s+branch\s+fsm\s+toggle\b", text))
        matches = list(row_re.finditer(text))
        if use_plain_rows:
            matches.extend(keyed_row_re.finditer(text))
        for match in matches:
            module = match.group("module")
            if "ptw" not in module.lower() and "twu" not in module.lower() and "pde" not in module.lower() and "mbuf" not in module.lower():
                continue
            for metric in HEADLINE_METRICS:
                pct = float(match.group(metric))
                threshold = float(metrics[metric]["threshold"])
                if pct < threshold:
                    holes.append({
                        "metric": metric,
                        "module": module,
                        "file": None,
                        "line": None,
                        "object": "module-level low {} coverage".format(metric),
                        "hit": None,
                        "total": None,
                        "pct": pct,
                        "classification": "module_low_coverage",
                        "action": "inspect_urg_html",
                        "source": str(path),
                    })
    if holes:
        return holes[:20]

    for metric in HEADLINE_METRICS:
        item = metrics[metric]
        if item["status"] in {"FAIL", "MISSING"}:
            holes.append({
                "metric": metric,
                "module": "ptw_core",
                "file": None,
                "line": None,
                "object": "{} coverage below threshold or missing".format(metric),
                "hit": item["hit"],
                "total": item["total"],
                "pct": item["pct"],
                "classification": "metric_low_coverage" if item["status"] == "FAIL" else "metric_missing",
                "action": "inspect_urg_report",
                "source": item["source"],
            })
    return holes[:20]


def git_commit() -> str:
    try:
        out = subprocess.check_output(["git", "rev-parse", "HEAD"], stderr=subprocess.DEVNULL, universal_newlines=True)
        return out.strip()
    except Exception:
        return "unknown"


def load_manifest(path: Optional[Path]) -> Dict[str, object]:
    if path is None or not path.is_file():
        return {}
    return json.loads(read_text(path))


def functional_gate_from_manifest(manifest: Dict[str, object]) -> Dict[str, object]:
    gate = manifest.get("functional_gate") if isinstance(manifest, dict) else None
    if isinstance(gate, dict):
        status = str(gate.get("status", "UNKNOWN"))
        if status not in FUNCTIONAL_GATE_STATUS:
            gate = dict(gate)
            gate["status"] = "UNKNOWN"
        return gate
    return {"status": "SKIPPED", "mode": "unknown", "evidence": {}, "reason": "manifest_absent"}


def run_manifest_from_manifest(manifest: Dict[str, object], profile: str) -> Dict[str, object]:
    run_manifest = manifest.get("run_manifest") if isinstance(manifest, dict) else None
    if isinstance(run_manifest, dict):
        return run_manifest
    return {"profile": profile, "runs": [], "deduped_entries": []}


def determine_status(
    profile: str,
    scope: Dict[str, object],
    metrics: Dict[str, Dict[str, object]],
    headline: Optional[float],
    confidence: str,
    functional_gate: Dict[str, object],
    thresholds: Dict[str, float],
) -> Tuple[str, str]:
    if scope["status"] != "PASS":
        return "FAIL", "scope_invalid"
    missing = [m for m in HEADLINE_METRICS if metrics[m]["status"] == "MISSING"]
    if missing:
        return "FAIL", "missing_metric"
    failed = [m for m in HEADLINE_METRICS if metrics[m]["status"] == "FAIL"]
    if headline is None:
        return "FAIL", "ambiguous_metric"
    if headline < thresholds["headline"] or failed:
        return "FAIL", "threshold_fail"
    if confidence == "low":
        return "CONDITIONAL_PASS", "confidence_low"
    gate_status = str(functional_gate.get("status", "UNKNOWN"))
    if gate_status == "FAIL":
        return "FAIL", "functional_gate_fail"
    if gate_status == "SKIPPED":
        return "CONDITIONAL_PASS", "functional_gate_skipped"
    if profile != "signoff":
        return "CONDITIONAL_PASS", "non_signoff_profile"
    if gate_status not in {"PASS", "REUSED"}:
        return "CONDITIONAL_PASS", "functional_gate_incomplete"
    return "PASS", "all_thresholds_met"


def pct_text(value: Optional[float]) -> str:
    return "N/A" if value is None else "{:.2f}".format(value)


def write_markdown(path: Path, summary: Dict[str, object]) -> None:
    metrics = summary["metrics"]
    run_manifest = summary["run_manifest"]
    fg = summary["functional_gate"]
    lines = [
        "# PTW Code Coverage Summary",
        "",
        "## Result",
        "",
        "PTW_CODE_COVERAGE_RESULT status={status} reason={reason} scope={scope} profile={profile} confidence={confidence} headline={headline} line={line} condition={condition} branch={branch} fsm={fsm} toggle={toggle} assertion={assertion} report={report}".format(
            status=summary["status"],
            reason=summary["reason"],
            scope=summary["scope"],
            profile=summary["profile"],
            confidence=summary["confidence"],
            headline=pct_text(summary["ptw_code_coverage"]),
            line=pct_text(metrics["line"]["pct"]),
            condition=pct_text(metrics["condition"]["pct"]),
            branch=pct_text(metrics["branch"]["pct"]),
            fsm=pct_text(metrics["fsm"]["pct"]),
            toggle=pct_text(metrics["toggle"]["pct"]),
            assertion=pct_text(metrics["assertion"]["pct"]),
            report=summary["paths"]["urg_report"],
        ),
        "",
        "## Scope",
        "",
        "- Hier cfg: {}".format(summary["paths"]["hier_cfg"]),
        "- Scope method: {}".format(summary["scope_check"].get("scope_method")),
        "- Root: {}".format(summary["scope_check"].get("required_root")),
        "- Rejected scopes: {}".format(", ".join(summary["scope_check"].get("rejected_scopes", [])) or "none"),
        "",
        "## Metrics",
        "",
        "| Metric | Hit | Total | Pct | Threshold | Status | Included In Headline |",
        "| --- | ---: | ---: | ---: | ---: | --- | --- |",
    ]
    for metric in METRIC_ORDER:
        item = metrics[metric]
        lines.append("| {} | {} | {} | {} | {:.2f} | {} | {} |".format(
            metric,
            item["hit"] if item["hit"] is not None else "N/A",
            item["total"] if item["total"] is not None else "N/A",
            pct_text(item["pct"]),
            item["threshold"],
            item["status"],
            "yes" if item["included_in_headline"] else "no",
        ))
    lines.extend(["", "## Runs", "", "| List | Seeds | Regress Name | Summary | Status |", "| --- | --- | --- | --- | --- |"])
    for run in run_manifest.get("runs", []):
        lines.append("| {} | {} | {} | {} | {} |".format(
            run.get("list", "-"),
            " ".join(str(seed) for seed in run.get("seeds", [])),
            run.get("regress_name", run.get("regress_names", "-")),
            run.get("summary", "-"),
            run.get("status", "-"),
        ))
    if not run_manifest.get("runs"):
        lines.append("| - | - | - | - | - |")
    lines.extend([
        "",
        "## Functional Gate",
        "",
        "- Status: {}".format(fg.get("status", "UNKNOWN")),
        "- Mode: {}".format(fg.get("mode", "unknown")),
        "",
        "## Holes",
        "",
        "| Metric | Module | Pct | Classification | Action |",
        "| --- | --- | ---: | --- | --- |",
    ])
    for hole in summary["holes_top20"]:
        lines.append("| {} | {} | {} | {} | {} |".format(
            hole.get("metric", "-"),
            hole.get("module", "-"),
            pct_text(hole.get("pct")),
            hole.get("classification", "-"),
            hole.get("action", "-"),
        ))
    if not summary["holes_top20"]:
        lines.append("| - | - | - | - | - |")
    lines.extend(["", "## Waivers", "", "{}".format(json.dumps(summary["waivers"], indent=2, sort_keys=True))])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_summary(args: argparse.Namespace) -> Dict[str, object]:
    report_dir = Path(args.urg_report)
    hier_cfg_path = Path(args.hier_cfg)
    thresholds = {
        "headline": args.headline_threshold,
        "line": args.line_threshold,
        "condition": args.condition_threshold,
        "branch": args.branch_threshold,
        "fsm": args.fsm_threshold,
        "toggle": args.toggle_threshold,
        "assertion": args.assertion_threshold,
    }
    report_texts = load_report_texts(report_dir)
    hier_cfg = load_hier_cfg(hier_cfg_path)
    scope = scope_check(report_texts, hier_cfg)
    metrics = build_metrics(report_texts, thresholds)
    headline, headline_method, confidence = compute_headline(metrics, report_texts, args.headline_method)
    if scope["status"] != "PASS":
        confidence = "low"
    manifest = load_manifest(Path(args.manifest) if args.manifest else None)
    functional_gate = functional_gate_from_manifest(manifest)
    run_manifest = run_manifest_from_manifest(manifest, args.profile)
    status, reason = determine_status(args.profile, scope, metrics, headline, confidence, functional_gate, thresholds)
    holes = extract_module_holes(report_texts, metrics)
    return {
        "schema_version": SCHEMA_VERSION,
        "status": status,
        "reason": reason,
        "confidence": confidence,
        "generated_at": _dt.datetime.now(_dt.timezone.utc).astimezone().isoformat(timespec="seconds"),
        "git_commit": git_commit(),
        "profile": args.profile,
        "scope": args.scope,
        "scope_check": scope,
        "functional_gate": functional_gate,
        "headline_method": headline_method,
        "ptw_code_coverage": round(headline, 2) if headline is not None else None,
        "metrics": metrics,
        "thresholds": thresholds,
        "threshold_status": "PASS" if status in {"PASS", "CONDITIONAL_PASS"} and reason not in {"threshold_fail", "missing_metric", "ambiguous_metric"} else "FAIL",
        "paths": {
            "urg_report": str(report_dir),
            "cov_db": args.cov_db,
            "merged_db": args.merged_db,
            "hier_cfg": str(hier_cfg_path),
        },
        "run_manifest": run_manifest,
        "holes_top20": holes,
        "waivers": [],
    }


def result_line(summary: Dict[str, object]) -> str:
    metrics = summary["metrics"]
    return (
        "PTW_CODE_COVERAGE_RESULT status={status} reason={reason} scope={scope} "
        "profile={profile} confidence={confidence} headline={headline} "
        "line={line} condition={condition} branch={branch} fsm={fsm} toggle={toggle} "
        "assertion={assertion} functional_gate={fg} report={report}"
    ).format(
        status=summary["status"],
        reason=summary["reason"],
        scope=summary["scope"],
        profile=summary["profile"],
        confidence=summary["confidence"],
        headline=pct_text(summary["ptw_code_coverage"]),
        line=pct_text(metrics["line"]["pct"]),
        condition=pct_text(metrics["condition"]["pct"]),
        branch=pct_text(metrics["branch"]["pct"]),
        fsm=pct_text(metrics["fsm"]["pct"]),
        toggle=pct_text(metrics["toggle"]["pct"]),
        assertion=pct_text(metrics["assertion"]["pct"]),
        fg=summary["functional_gate"].get("status", "UNKNOWN"),
        report=summary["paths"]["urg_report"],
    )


def main() -> int:
    args = parse_args()
    try:
        summary = build_summary(args)
    except ParseError as exc:
        summary = {
            "schema_version": SCHEMA_VERSION,
            "status": "FAIL",
            "reason": "urg_fail",
            "confidence": "low",
            "generated_at": _dt.datetime.now(_dt.timezone.utc).astimezone().isoformat(timespec="seconds"),
            "git_commit": git_commit(),
            "profile": args.profile,
            "scope": args.scope,
            "scope_check": {"status": "FAIL", "rejected_scopes": [str(exc)]},
            "functional_gate": {"status": "UNKNOWN", "mode": "unknown", "evidence": {}},
            "headline_method": "unavailable",
            "ptw_code_coverage": None,
            "metrics": {m: {"hit": None, "total": None, "pct": None, "status": "MISSING", "applicable": True, "threshold": DEFAULT_THRESHOLDS.get(m, 0), "included_in_headline": m in HEADLINE_METRICS} for m in METRIC_ORDER},
            "thresholds": DEFAULT_THRESHOLDS,
            "threshold_status": "FAIL",
            "paths": {"urg_report": args.urg_report, "cov_db": args.cov_db, "merged_db": args.merged_db, "hier_cfg": args.hier_cfg},
            "run_manifest": {"profile": args.profile, "runs": [], "deduped_entries": []},
            "holes_top20": [],
            "waivers": [],
        }
    out_json = Path(args.out_json)
    out_md = Path(args.out_md)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(out_md, summary)
    print(result_line(summary))
    return 0 if summary["status"] in STATUS_VALUES else 1


if __name__ == "__main__":
    sys.exit(main())
