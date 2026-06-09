#!/usr/bin/env python3
"""Generate object-level Phase14 coverage hotspot notes from VDB XML.

This is a diagnostic companion to the XML fallback report. It does not replace
official URG signoff; it ranks uncovered DUT objects so closure work can focus
on real design behavior instead of aggregate percentages.
"""

import argparse
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from phase14_merge_parallel_coverage import (  # noqa: E402
    BitMetricAccumulator,
    FunctionalAccumulator,
    iter_testdata_dirs,
    parse_bit_metric_file,
    parse_functional_file,
    pct,
)


BIT_METRICS = ("fsm", "tgl", "cond")
METRIC_LABELS = {
    "fsm": "FSM",
    "tgl": "Toggle",
    "cond": "Condition",
}
DEFAULT_SCOPES = {
    "L1TLB": ("tb_top.u_dut.u_mmu_l1dtlb", "tb_top.u_dut.x_mmu_l1itlb"),
    "L2TLB": ("tb_top.u_dut.x_mmu_l2tlb",),
    "PTW": ("tb_top.u_dut.x_ct_mmu_ptw",),
}


def matches_scope(name: str, prefixes: Sequence[str]) -> bool:
    for prefix in prefixes:
        if name == prefix or name.startswith(prefix + "."):
            return True
    return False


def iter_vdbs(root: Path) -> List[Path]:
    if root.is_dir() and root.name.endswith(".vdb"):
        return [root]
    if not root.is_dir():
        return []
    patterns = ("phase14_parallel_*.vdb", "*.vdb")
    seen = set()
    vdbs: List[Path] = []
    for pattern in patterns:
        for path in sorted(root.glob(pattern)):
            if path.is_dir() and path not in seen:
                seen.add(path)
                vdbs.append(path)
    return vdbs


def scope_of(name: str) -> str:
    for scope_name, prefixes in DEFAULT_SCOPES.items():
        if matches_scope(name, prefixes):
            return scope_name
    return "OTHER"


def collect_bit_metrics(vdbs: Sequence[Path], metrics: Sequence[str]) -> Dict[str, BitMetricAccumulator]:
    accumulators = {metric: BitMetricAccumulator(metric) for metric in metrics}
    for index, vdb in enumerate(vdbs, start=1):
        for testdata in iter_testdata_dirs(vdb):
            for metric, accumulator in accumulators.items():
                path = testdata / f"{metric}.verilog.data.xml"
                if path.is_file():
                    parse_bit_metric_file(path, accumulator)
        if index == 1 or index == len(vdbs) or index % 250 == 0:
            print(f"hotspot XML scan: {index}/{len(vdbs)} VDBs")
    return accumulators


def collect_functional(vdbs: Sequence[Path]) -> FunctionalAccumulator:
    accumulator = FunctionalAccumulator()
    for vdb in vdbs:
        for testdata in iter_testdata_dirs(vdb):
            path = testdata / "testbench.inst.xml"
            if not path.is_file():
                path = testdata / "testbench.cumulative.xml"
            if path.is_file():
                parse_functional_file(path, accumulator)
    return accumulator


def bit_hotspots(
    accumulator: BitMetricAccumulator,
    limit: int,
) -> List[Tuple[int, int, int, float, str, str]]:
    rows: List[Tuple[int, int, int, float, str, str]] = []
    for (name, _chksum, _width), bits in accumulator._bits.items():
        total = len(bits)
        covered = bits.count(ord("1"))
        missing = total - covered
        if missing <= 0:
            continue
        rows.append((missing, total, covered, pct(covered, total), scope_of(name), name))
    rows.sort(key=lambda item: (item[0], item[1], item[5]), reverse=True)
    return rows[:limit]


def functional_hotspots(accumulator: FunctionalAccumulator, limit: int) -> Dict[str, object]:
    missed_explicit = [
        key for key, hit in accumulator.explicit_bins.items()
        if not hit
    ]
    group_counts = Counter(group for group, _cp, _bin_id, _bin_name in missed_explicit)
    cp_counts = Counter((group, cp) for group, cp, _bin_id, _bin_name in missed_explicit)

    auto_rows = []
    for key, denom in accumulator.auto_denoms.items():
        hits = accumulator.auto_hits.get(key, set())
        covered = sum(1 for index in hits if 0 <= index < denom)
        missing = denom - covered
        if missing > 0:
            auto_rows.append((missing, denom, covered, pct(covered, denom), key))
    auto_rows.sort(key=lambda item: (item[0], item[1], str(item[4])), reverse=True)

    return {
        "summary": accumulator.summary(),
        "group_counts": group_counts.most_common(limit),
        "cp_counts": cp_counts.most_common(limit),
        "missed_explicit": missed_explicit[:limit],
        "auto_rows": auto_rows[:limit],
    }


def table_row(values: Iterable[object]) -> str:
    return "| " + " | ".join(str(value) for value in values) + " |"


def write_markdown(
    path: Path,
    vdb_root: Path,
    vdb_count: int,
    elapsed_s: float,
    bit_accumulators: Dict[str, BitMetricAccumulator],
    functional: Dict[str, object],
    limit: int,
) -> None:
    lines: List[str] = []
    lines.append("# Phase14 Coverage Hotspots")
    lines.append("")
    lines.append("This report is derived from VDB XML and is diagnostic only. Official signoff still requires Synopsys URG.")
    lines.append("")
    lines.append(f"- VDB root: `{vdb_root}`")
    lines.append(f"- VDBs scanned: {vdb_count}")
    lines.append(f"- Elapsed seconds: {elapsed_s:.2f}")
    lines.append(f"- Object limit per table: {limit}")
    lines.append("")
    lines.append("## Metric Summary")
    lines.append("")
    lines.append(table_row(("Metric", "Coverage", "Covered", "Total", "Objects")))
    lines.append(table_row(("---", "---:", "---:", "---:", "---:")))
    for metric in BIT_METRICS:
        summary = bit_accumulators[metric].summary()
        covered = int(summary.get("covered", 0) or 0)
        total = int(summary.get("total", 0) or 0)
        percent = summary.get("percent")
        percent_text = "N/A" if percent is None else f"{float(percent):.2f}%"
        lines.append(table_row((METRIC_LABELS[metric], percent_text, covered, total, summary.get("objects", 0))))
    f_summary = functional["summary"]
    assert isinstance(f_summary, dict)
    f_percent = f_summary.get("percent")
    lines.append(table_row((
        "Functional",
        "N/A" if f_percent is None else f"{float(f_percent):.2f}%",
        int(f_summary.get("covered", 0) or 0),
        int(f_summary.get("total", 0) or 0),
        int(f_summary.get("objects", 0) or 0),
    )))
    lines.append("")

    for metric in BIT_METRICS:
        lines.append(f"## {METRIC_LABELS[metric]} Worst Objects")
        lines.append("")
        lines.append(table_row(("Scope", "Missing", "Covered", "Total", "Coverage", "Object")))
        lines.append(table_row(("---", "---:", "---:", "---:", "---:", "---")))
        for missing, total, covered, percent_value, scope, name in bit_hotspots(bit_accumulators[metric], limit):
            lines.append(table_row((scope, missing, covered, total, f"{percent_value:.2f}%", f"`{name}`")))
        lines.append("")

    lines.append("## Functional Uncovered Explicit Bins By Group")
    lines.append("")
    lines.append(table_row(("Uncovered", "Covergroup")))
    lines.append(table_row(("---:", "---")))
    for group, count in functional["group_counts"]:
        lines.append(table_row((count, f"`{group}`")))
    lines.append("")

    lines.append("## Functional Uncovered Explicit Bins By Coverpoint")
    lines.append("")
    lines.append(table_row(("Uncovered", "Covergroup", "Coverpoint")))
    lines.append(table_row(("---:", "---", "---")))
    for (group, cp_name), count in functional["cp_counts"]:
        lines.append(table_row((count, f"`{group}`", f"`{cp_name}`")))
    lines.append("")

    lines.append("## Functional Uncovered Explicit Bin Samples")
    lines.append("")
    lines.append(table_row(("Covergroup", "Coverpoint", "Bin ID", "Bin Name")))
    lines.append(table_row(("---", "---", "---:", "---")))
    for group, cp_name, bin_id, bin_name in functional["missed_explicit"]:
        lines.append(table_row((f"`{group}`", f"`{cp_name}`", bin_id, f"`{bin_name}`")))
    lines.append("")

    lines.append("## Functional Auto Coverpoint Gaps")
    lines.append("")
    lines.append(table_row(("Missing", "Covered", "Total", "Coverage", "Coverpoint Key")))
    lines.append(table_row(("---:", "---:", "---:", "---:", "---")))
    for missing, total, covered, percent_value, key in functional["auto_rows"]:
        lines.append(table_row((missing, covered, total, f"{percent_value:.2f}%", f"`{key}`")))
    lines.append("")

    lines.append("## DUT-quality Notes")
    lines.append("")
    lines.append("- Treat L1TLB/PTW/L2TLB scoped objects as first-priority DUT closure targets.")
    lines.append("- Treat OTHER scope rows as waiver candidates only after proving they are not DUT signoff behavior.")
    lines.append("- Do not close a hotspot with stimulus unless the run has scoreboard/assertion evidence for the behavior being exercised.")
    lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(description="Generate Phase14 VDB XML coverage hotspot markdown")
    parser.add_argument("--vdb-root", type=Path, default=Path("output/phase14_parallel_vdb"))
    parser.add_argument("--report-dir", type=Path, default=Path("output/coverage/phase14_urgReport"))
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--top", type=int, default=30)
    parser.add_argument("--skip-functional", action="store_true")
    args = parser.parse_args(argv)

    started = time.time()
    vdbs = iter_vdbs(args.vdb_root)
    if not vdbs:
        print(f"ERROR: no VDB directories found under {args.vdb_root}", file=sys.stderr)
        return 2

    bit_accumulators = collect_bit_metrics(vdbs, BIT_METRICS)
    if args.skip_functional:
        functional_acc = FunctionalAccumulator()
    else:
        functional_acc = collect_functional(vdbs)
    functional = functional_hotspots(functional_acc, max(1, args.top))

    out_path = args.out or (args.report_dir / "coverage_hotspots.md")
    write_markdown(
        out_path,
        args.vdb_root,
        len(vdbs),
        time.time() - started,
        bit_accumulators,
        functional,
        max(1, args.top),
    )
    print(f"Phase14 coverage hotspot report: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
