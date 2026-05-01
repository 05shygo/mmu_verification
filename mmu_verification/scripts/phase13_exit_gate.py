#!/usr/bin/env python3
"""Phase 13 exit-criteria gate.

This script only checks artifacts produced by Makefile targets. It does not
compile or run simulation by itself.
"""

import argparse
import html
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


PHASE13_COVERGROUPS = [
    "cg_pmp_per_level_result",
    "cg_pmp_grant_level",
    "cg_pmp_pa_format",
    "cg_pmp_deny_by_level",
    "cg_twu_mask_cause",
    "cg_ptw_pmp_port_map",
    "cg_sysmap_flg_per_region",
    "cg_sysmap_cross_1g",
    "cg_sysmap_cross_2m",
    "cg_sysmap_degrade_pgs",
    "cg_sysmap_pa_align",
    "cg_sysmap_4twu_concurrent",
    "cg_sysmap_default_flag",
]

PMP_ASSERTS = [
    "sva_pmp_check_before_lsu_req",
    "sva_pmp_wait_implies_mask",
    "sva_pmp_deny_no_refill",
    "sva_pmp_deny_acc_fault",
    "sva_pmp_grant_onehot",
    "sva_no_lsu_req_during_pmp_wait",
    "sva_pmp_fetch_matches_grant_stage",
    "sva_pmp_deny_uses_original_type_perm",
    "sva_pmp_deny_no_lsu_req",
]

PMP_COVERS = [
    "cp_pmp_check_before_lsu_req",
    "cp_pmp_wait_implies_mask",
    "cp_pmp_deny_no_refill",
    "cp_pmp_deny_acc_fault",
    "cp_pmp_grant_onehot",
    "cp_no_lsu_req_during_pmp_wait",
    "cp_pmp_fetch_matches_grant_stage",
    "cp_pmp_fetch_high",
    "cp_pmp_fetch_uses_x_perm",
    "cp_pmp_load_pref_uses_r_perm",
    "cp_pmp_store_uses_w_perm",
    "cp_pmp_mmode_l0_bypass",
    "cp_pmp_deny_no_lsu_req",
]

SYSMAP_ASSERTS = [
    "sva_csr_refill_flg_matches_sysmap",
    "sva_sysmap_cross_degrade",
    "sva_sysmap_cross_degrade_2m",
    "sva_sysmap_no_cross_no_degrade",
    "sva_sysmap_pa_align",
]

SYSMAP_COVERS = [
    "cp_csr_refill_flg_matches_sysmap",
    "cp_sysmap_cross_degrade",
    "cp_sysmap_no_cross_no_degrade",
    "cp_sysmap_pa_align",
]

PREFERRED_REPORT_FILES = {
    "groups.txt": 0,
    "groups.html": 1,
    "dashboard.txt": 2,
    "dashboard.html": 3,
    "index.html": 4,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check Phase 13 exit criteria")
    parser.add_argument("--list", required=True, help="Phase 13 regression list")
    parser.add_argument("--seeds", required=True, help="Phase 13 seed set")
    parser.add_argument("--summary", required=True, help="Regression summary path")
    parser.add_argument("--log-dir", required=True, help="Simulation log directory")
    parser.add_argument("--urg-report-dir", required=True, help="URG report directory")
    parser.add_argument("--pmp-sva", required=True, help="mmu_pmp_twu_sva.sv")
    parser.add_argument("--sysmap-sva", required=True, help="mmu_sysmap_sva.sv")
    parser.add_argument("--da003", required=True, help="DA-003 record path")
    parser.add_argument("--regress-rc", default="0", help="regress_v4_sysmap_pmp return code")
    parser.add_argument("--sva-min-hits", type=int, default=20, help="Minimum aggregate hits for each cover property")
    parser.add_argument("--covergroup-threshold", type=float, default=50.0, help="Minimum URG covergroup score")
    return parser.parse_args()


def normalize_words(raw: str) -> str:
    return " ".join(raw.split())


def load_tests(list_path: Path) -> List[str]:
    tests: List[str] = []
    for raw in list_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        tests.append(line.split()[0])
    return tests


def parse_seeds(raw: str) -> List[str]:
    return [item for item in re.split(r"[,\s]+", raw.strip()) if item]


def parse_summary(path: Path) -> Dict[str, str]:
    data: Dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        data[key.strip()] = value.strip()
    return data


def has_labeled_statement(path: Path, name: str, kind: str) -> bool:
    pattern = re.compile(rf"^\s*{re.escape(name)}\s*:\s*{kind}\s+property\b", re.MULTILINE)
    return pattern.search(path.read_text(encoding="utf-8", errors="ignore")) is not None


def collect_sva_hits(log_paths: Iterable[Path]) -> Tuple[Dict[str, int], List[Path]]:
    hits: Dict[str, int] = {}
    missing: List[Path] = []
    pattern = re.compile(r"\bPHASE13_SVA_COVER\b.*\bname=([A-Za-z0-9_]+)\s+hits=(\d+)")

    for log_path in log_paths:
        if not log_path.is_file():
            missing.append(log_path)
            continue
        for match in pattern.finditer(log_path.read_text(encoding="utf-8", errors="ignore")):
            name = match.group(1)
            hits[name] = hits.get(name, 0) + int(match.group(2))

    return hits, missing


def iter_report_files(report_dir: Path) -> List[Path]:
    files = [
        path
        for path in report_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in {".txt", ".html", ".htm"}
    ]

    def key(path: Path) -> Tuple[int, int, str]:
        return (
            PREFERRED_REPORT_FILES.get(path.name.lower(), 99),
            len(path.parts),
            str(path),
        )

    return sorted(files, key=key)


def sanitize_text(raw_text: str) -> str:
    unescaped = html.unescape(raw_text)
    no_tags = re.sub(r"<[^>]+>", " ", unescaped)
    return re.sub(r"\s+", " ", no_tags)


def html_table_cells(row_html: str, cell_tag: str) -> List[str]:
    cell_re = re.compile(rf"<{cell_tag}\b[^>]*>(.*?)</{cell_tag}>", re.IGNORECASE | re.DOTALL)
    return [sanitize_text(cell).strip() for cell in cell_re.findall(row_html)]


def group_name_matches(candidate: str, group_name: str) -> bool:
    candidate = sanitize_text(candidate).strip()
    return (
        candidate == group_name
        or candidate.endswith(f"::{group_name}")
        or candidate.endswith(f".{group_name}")
    )


def parse_score_value(text: str) -> Optional[float]:
    match = re.search(r"(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])", text)
    if match is None:
        return None
    value = float(match.group(1))
    return value if 0.0 <= value <= 100.0 else None


def candidate_urg_table_scores(raw_text: str, group_name: str) -> List[float]:
    row_re = re.compile(r"<tr\b[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
    values: List[float] = []
    for row_match in row_re.finditer(raw_text):
        row = row_match.group(1)
        if group_name not in html.unescape(row):
            continue
        cells = html_table_cells(row, "td")
        if len(cells) < 2 or not group_name_matches(cells[0], group_name):
            continue
        value = parse_score_value(cells[1])
        if value is not None:
            values.append(value)
    return values


def candidate_group_detail_scores(raw_text: str, group_name: str) -> List[float]:
    title_patterns = (
        re.compile(r"<title\b[^>]*>.*?Group\s*::\s*(.*?)</title>", re.IGNORECASE | re.DOTALL),
        re.compile(r"<center\b[^>]*class=[\"']pagetitle[\"'][^>]*>\s*Group\s*:\s*(.*?)</center>", re.IGNORECASE | re.DOTALL),
        re.compile(r"<span\b[^>]*class=[\"']titlename[\"'][^>]*>\s*Group\s*:\s*(.*?)</span>", re.IGNORECASE | re.DOTALL),
    )
    if not any(
        group_name_matches(match.group(1), group_name)
        for pattern in title_patterns
        for match in pattern.finditer(raw_text)
    ):
        return []

    table_re = re.compile(r"<table\b[^>]*>(.*?)</table>", re.IGNORECASE | re.DOTALL)
    row_re = re.compile(r"<tr\b[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
    for table_match in table_re.finditer(raw_text):
        rows = row_re.findall(table_match.group(1))
        if len(rows) < 2:
            continue
        header_cells = html_table_cells(rows[0], "td")
        if not header_cells or header_cells[0].upper() != "SCORE":
            continue
        value_cells = html_table_cells(rows[1], "td")
        if not value_cells:
            continue
        value = parse_score_value(value_cells[0])
        if value is not None:
            return [value]
    return []


def candidate_text_row_scores(text: str, group_name: str) -> List[float]:
    values: List[float] = []
    for raw_line in text.splitlines():
        line = sanitize_text(raw_line)
        if group_name not in line:
            continue
        value = parse_score_value(line.split(group_name, 1)[1])
        if value is not None:
            values.append(value)
    return values


def candidate_percentages(text: str, group_name: str) -> List[float]:
    escaped = re.escape(group_name)
    patterns = (
        re.compile(escaped + r"[\s\S]{0,240}?(\d+(?:\.\d+)?)\s*%", re.IGNORECASE),
        re.compile(r"(\d+(?:\.\d+)?)\s*%[\s\S]{0,240}?" + escaped, re.IGNORECASE),
    )
    values: List[float] = []
    for pattern in patterns:
        for match in pattern.findall(text):
            value = float(match)
            if 0.0 <= value <= 100.0:
                values.append(value)
    return values


def locate_group_percentage(report_dir: Path, group_name: str) -> Optional[Tuple[float, Path]]:
    for path in iter_report_files(report_dir):
        raw_text = path.read_text(encoding="utf-8", errors="ignore")
        if path.suffix.lower() in {".html", ".htm"}:
            values = candidate_urg_table_scores(raw_text, group_name)
            if not values:
                values = candidate_group_detail_scores(raw_text, group_name)
        else:
            values = candidate_text_row_scores(raw_text, group_name)
            if not values:
                values = candidate_percentages(raw_text, group_name)
        if values:
            return max(values), path
    return None


def print_result(status: bool, criterion: str, detail: str = "") -> None:
    print(f"[{'PASS' if status else 'FAIL'}] {criterion}")
    if detail:
        for line in detail.splitlines():
            print(f"       {line}")


def main() -> int:
    args = parse_args()

    list_path = Path(args.list)
    summary_path = Path(args.summary)
    log_dir = Path(args.log_dir)
    report_dir = Path(args.urg_report_dir)
    pmp_sva = Path(args.pmp_sva)
    sysmap_sva = Path(args.sysmap_sva)
    da003 = Path(args.da003)

    tests: List[str] = []
    seeds = parse_seeds(args.seeds)
    results: List[bool] = []

    print("========================================")
    print("PHASE13 EXIT CHECK SUMMARY")
    print("========================================")
    print(f"list              : {list_path}")
    print(f"seeds             : {' '.join(seeds)}")
    print(f"summary           : {summary_path}")
    print(f"URG report        : {report_dir}")
    print(f"regress target rc : {args.regress_rc}")
    print()

    run_ok = args.regress_rc == "0"
    print_result(run_ok, "phase13 command - regress_v4_sysmap_pmp completed successfully", f"regress_rc={args.regress_rc}")
    results.append(run_ok)

    try:
        tests = load_tests(list_path)
        summary = parse_summary(summary_path)
        expected_total = len(tests) * len(seeds)
        crit1 = (
            len(seeds) == 3
            and summary.get("mode") == "run_cov"
            and normalize_words(summary.get("seeds", "")) == normalize_words(args.seeds)
            and summary.get("total_runs") == str(expected_total)
            and summary.get("failed_runs") == "0"
            and summary.get("xpass_unexpected_runs") == "0"
            and summary.get("pass_rate") == "1.0000"
        )
        detail = (
            f"tests={len(tests)} seeds={len(seeds)} expected_total={expected_total}\n"
            f"mode={summary.get('mode')} total={summary.get('total_runs')} "
            f"failed={summary.get('failed_runs')} pass_rate={summary.get('pass_rate')}"
        )
    except Exception as exc:
        crit1 = False
        detail = str(exc)
    print_result(crit1, "criterion 1 - Phase 13 list, 3 seeds, 100% pass", detail)
    results.append(crit1)

    all_log_paths = [log_dir / f"{test}_{seed}_cov.log" for test in tests for seed in seeds]
    hits, missing_logs = collect_sva_hits(all_log_paths)
    cover_names = PMP_COVERS + SYSMAP_COVERS
    cover_lines = []
    crit2 = not missing_logs
    if missing_logs:
        cover_lines.append(f"missing_logs={len(missing_logs)}")
        cover_lines.extend(str(path) for path in missing_logs[:10])
    for name in cover_names:
        count = hits.get(name, 0)
        ok = count >= args.sva_min_hits
        crit2 = crit2 and ok
        cover_lines.append(f"{name}: hits={count} threshold={args.sva_min_hits} status={'PASS' if ok else 'FAIL'}")
    print_result(crit2, "criterion 2 - every Phase 13 cover property reaches hit threshold", "\n".join(cover_lines))
    results.append(crit2)

    sysmap_static = sysmap_sva.is_file()
    sysmap_lines = []
    for name in SYSMAP_ASSERTS:
        ok = sysmap_sva.is_file() and has_labeled_statement(sysmap_sva, name, "assert")
        sysmap_static = sysmap_static and ok
        sysmap_lines.append(f"{name}: {'found' if ok else 'missing'}")
    for name in SYSMAP_COVERS:
        ok = sysmap_sva.is_file() and has_labeled_statement(sysmap_sva, name, "cover")
        sysmap_static = sysmap_static and ok
        sysmap_lines.append(f"{name}: {'found' if ok else 'missing'}")
    print_result(sysmap_static, "criterion 3 - mmu_sysmap_sva.sv assertions have cover properties", "\n".join(sysmap_lines))
    results.append(sysmap_static)

    pmp_static = pmp_sva.is_file()
    pmp_lines = []
    for name in PMP_ASSERTS:
        ok = pmp_sva.is_file() and has_labeled_statement(pmp_sva, name, "assert")
        pmp_static = pmp_static and ok
        pmp_lines.append(f"{name}: {'found' if ok else 'missing'}")
    for name in PMP_COVERS:
        ok = pmp_sva.is_file() and has_labeled_statement(pmp_sva, name, "cover")
        pmp_static = pmp_static and ok
        pmp_lines.append(f"{name}: {'found' if ok else 'missing'}")
    print_result(pmp_static, "criterion 4 - mmu_pmp_twu_sva.sv complete/static review", "\n".join(pmp_lines))
    results.append(pmp_static)

    cov_ok = report_dir.is_dir() and any(report_dir.rglob("*"))
    cov_lines = []
    if not report_dir.is_dir():
        cov_lines.append(f"URG report directory missing: {report_dir}")
    for group_name in PHASE13_COVERGROUPS:
        located = locate_group_percentage(report_dir, group_name) if report_dir.is_dir() else None
        if located is None:
            cov_ok = False
            cov_lines.append(f"{group_name}: not found")
            continue
        percentage, source = located
        ok = percentage >= args.covergroup_threshold
        cov_ok = cov_ok and ok
        cov_lines.append(
            f"{group_name}: {percentage:.2f}% threshold={args.covergroup_threshold:.2f}% "
            f"status={'PASS' if ok else 'FAIL'} source={source}"
        )
    print_result(cov_ok, "criterion 5 - 13 Phase 13 covergroups reach coverage threshold", "\n".join(cov_lines))
    results.append(cov_ok)

    da_ok = da003.is_file()
    da_detail = f"path={da003}"
    if da_ok:
        text = da003.read_text(encoding="utf-8", errors="ignore")
        required_tokens = ["DA-003", "pa3", "flg3", "twu_one", "mmu_pmp_fecth"]
        missing = [token for token in required_tokens if token not in text]
        da_ok = not missing
        if missing:
            da_detail += "\nmissing tokens: " + ", ".join(missing)
    print_result(da_ok, "criterion 6 - DA-003 written record present", da_detail)
    results.append(da_ok)

    print()
    print("========================================")
    if all(results):
        print("PHASE13_EXIT_CHECK: PASS")
        print("========================================")
        return 0

    print(f"PHASE13_EXIT_CHECK: FAIL ({results.count(False)} failed criterion/criteria)")
    print("========================================")
    return 1


if __name__ == "__main__":
    sys.exit(main())
