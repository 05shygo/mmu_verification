#!/usr/bin/env python3
"""Generate scope-specific XML fallback coverage from Phase14 shard VDBs.

This is a diagnostic companion to phase14_merge_parallel_coverage.py.  It does
not create an official URG report; it filters VDB XML instance_data records by
hierarchy prefix and ORs the covered bitstrings across all shard VDBs.
"""

import argparse
import html
import json
import sys
import time
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

from phase14_merge_parallel_coverage import (
    BIT_METRIC_LABELS,
    BIT_METRICS,
    INSTANCE_DATA_RE,
    AssertionAccumulator,
    BitMetricAccumulator,
    iter_testdata_dirs,
    open_maybe_gzip_text,
    parse_xml_attrs,
    pct_text,
)


DEFAULT_SCOPES = {
    "L1TLB": ["tb_top.u_dut.u_mmu_l1dtlb", "tb_top.u_dut.x_mmu_l1itlb"],
    "L2TLB": ["tb_top.u_dut.x_mmu_l2tlb"],
    "PTW": ["tb_top.u_dut.x_ct_mmu_ptw"],
}

ORDERED_METRICS = ("line", "branch", "cond", "tgl", "fsm", "assertion")


def matches_scope(name: str, prefixes: Sequence[str]) -> bool:
    for prefix in prefixes:
        if name == prefix or name.startswith(prefix + "."):
            return True
    return False


def iter_vdbs(root: Path) -> List[Path]:
    return sorted(path for path in root.glob("phase14_parallel_*.vdb") if path.is_dir())


def parse_bit_metric_file(path: Path, accumulators: Dict[str, BitMetricAccumulator], scopes: Dict[str, List[str]]) -> None:
    for accumulator in accumulators.values():
        accumulator.files_seen += 1
    with open_maybe_gzip_text(path) as stream:
        for line in stream:
            match = INSTANCE_DATA_RE.search(line)
            if not match:
                continue
            attrs = parse_xml_attrs(match.group(1))
            name = attrs.get("name", "")
            value = attrs.get("value", "")
            chksum = attrs.get("chksum", "")
            for scope_name, prefixes in scopes.items():
                if matches_scope(name, prefixes):
                    accumulators[scope_name].add_value(name, chksum, value)


def parse_assertion_file(path: Path, accumulators: Dict[str, AssertionAccumulator], scopes: Dict[str, List[str]]) -> None:
    for accumulator in accumulators.values():
        accumulator.files_seen += 1
    with open_maybe_gzip_text(path) as stream:
        for line in stream:
            match = INSTANCE_DATA_RE.search(line)
            if not match:
                continue
            attrs = parse_xml_attrs(match.group(1))
            name = attrs.get("name", "")
            value = attrs.get("value", "")
            for scope_name, prefixes in scopes.items():
                if matches_scope(name, prefixes):
                    accumulators[scope_name].add_value(name, value)


def collect_scope_coverage(vdbs: Sequence[Path], scopes: Dict[str, List[str]]) -> Dict[str, object]:
    started = time.time()
    bit_accumulators = {
        scope: {metric: BitMetricAccumulator(metric) for metric in BIT_METRICS}
        for scope in scopes
    }
    assertion_accumulators = {scope: AssertionAccumulator() for scope in scopes}
    missing_testdata = 0

    for index, vdb in enumerate(vdbs, start=1):
        testdata_dirs = list(iter_testdata_dirs(vdb))
        if not testdata_dirs:
            missing_testdata += 1
            continue
        for testdata in testdata_dirs:
            for metric in BIT_METRICS:
                metric_path = testdata / f"{metric}.verilog.data.xml"
                if metric_path.is_file():
                    parse_bit_metric_file(
                        metric_path,
                        {scope: bit_accumulators[scope][metric] for scope in scopes},
                        scopes,
                    )
            assertion_path = testdata / "assert.verilog.data.xml"
            if assertion_path.is_file():
                parse_assertion_file(assertion_path, assertion_accumulators, scopes)
        if index == 1 or index == len(vdbs) or index % 250 == 0:
            print(f"scope XML fallback progress: {index}/{len(vdbs)} VDBs scanned")

    scope_summaries: Dict[str, object] = {}
    for scope_name, prefixes in scopes.items():
        metrics: Dict[str, object] = {}
        for metric, accumulator in bit_accumulators[scope_name].items():
            metrics[metric] = accumulator.summary()
        metrics["assertion"] = assertion_accumulators[scope_name].summary()
        scope_summaries[scope_name] = {
            "prefixes": prefixes,
            "metrics": metrics,
        }

    return {
        "schema_version": "phase14_scope_xml_fallback_coverage_v1",
        "kind": "scope_xml_fallback",
        "vdb_count": len(vdbs),
        "missing_testdata_vdbs": missing_testdata,
        "elapsed_s": round(time.time() - started, 2),
        "scopes": scope_summaries,
    }


def metric_row(scope_name: str, metric_key: str, metric: Dict[str, object]) -> str:
    value = metric.get("percent")
    percent = None if value is None else float(value)
    covered = int(metric.get("covered", 0) or 0)
    total = int(metric.get("total", 0) or 0)
    label = "assertion" if metric_key == "assertion" else BIT_METRIC_LABELS.get(metric_key, metric_key)
    return (
        f"{scope_name:6s} {label:10s} {pct_text(percent):>8s} "
        f"({covered}/{total})"
    )


def write_text(path: Path, summary: Dict[str, object]) -> None:
    lines = [
        "Phase14 scope XML fallback coverage report",
        "",
        "WARNING: This report is derived directly from VDB XML data.",
        "It is not an official Synopsys URG hierarchy report.",
        "",
        f"vdb_count: {summary['vdb_count']}",
        f"missing_testdata_vdbs: {summary['missing_testdata_vdbs']}",
        f"elapsed_s: {summary['elapsed_s']}",
        "",
        "Scope metric summary:",
    ]
    scopes = summary["scopes"]
    assert isinstance(scopes, dict)
    for scope_name in scopes:
        scope = scopes[scope_name]
        assert isinstance(scope, dict)
        prefixes = scope.get("prefixes", [])
        lines.append("")
        lines.append(f"{scope_name}:")
        lines.append("  prefixes: " + ", ".join(str(prefix) for prefix in prefixes))
        metrics = scope.get("metrics", {})
        assert isinstance(metrics, dict)
        for metric_key in ORDERED_METRICS:
            metric = metrics.get(metric_key, {})
            if isinstance(metric, dict):
                lines.append("  " + metric_row(scope_name, metric_key, metric).strip())
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def bar_class(percent: float) -> str:
    if percent >= 90.0:
        return "good"
    if percent >= 75.0:
        return "warn"
    return "low"


def write_html(path: Path, summary: Dict[str, object]) -> None:
    rows: List[str] = []
    scopes = summary["scopes"]
    assert isinstance(scopes, dict)
    for scope_name, scope in scopes.items():
        assert isinstance(scope, dict)
        metrics = scope.get("metrics", {})
        assert isinstance(metrics, dict)
        for metric_key in ORDERED_METRICS:
            metric = metrics.get(metric_key, {})
            if not isinstance(metric, dict):
                continue
            value = metric.get("percent")
            percent = None if value is None else float(value)
            percent_text = pct_text(percent)
            bar_value = 0.0 if percent is None else max(0.0, min(100.0, percent))
            covered = int(metric.get("covered", 0) or 0)
            total = int(metric.get("total", 0) or 0)
            label = "Assertion" if metric_key == "assertion" else BIT_METRIC_LABELS.get(metric_key, metric_key).title()
            rows.append(
                "<tr>"
                f"<td data-label=\"Scope\">{html.escape(scope_name)}</td>"
                f"<td data-label=\"Metric\">{html.escape(label)}</td>"
                f"<td data-label=\"Coverage\" class=\"percent\">{html.escape(percent_text)}</td>"
                f"<td data-label=\"Progress\"><div class=\"bar {bar_class(bar_value)}\" style=\"--value: {bar_value:.2f}%\"><span></span></div></td>"
                f"<td data-label=\"Covered / Total\" class=\"count\">{covered} / {total}</td>"
                "</tr>"
            )

    html_text = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MMU Phase14 Scope Coverage Report</title>
  <style>
    :root {{
      --bg: #f6f7f9;
      --panel: #ffffff;
      --text: #17202a;
      --muted: #5d6875;
      --border: #d9dee6;
      --accent: #1f7a8c;
      --good: #22863a;
      --warn: #b26a00;
      --low: #a33030;
      --bar-bg: #e9edf3;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; background: var(--bg); color: var(--text); font-size: 15px; line-height: 1.5; }}
    main {{ max-width: 1180px; margin: 0 auto; padding: 28px 20px 42px; }}
    h1 {{ margin: 0 0 6px; font-size: clamp(26px, 3vw, 38px); line-height: 1.1; }}
    .subtitle {{ margin: 0 0 18px; color: var(--muted); }}
    .notice {{ margin: 16px 0 22px; padding: 14px 16px; border-left: 4px solid var(--warn); background: #fff8eb; border-radius: 8px; }}
    table {{ width: 100%; border-collapse: collapse; background: var(--panel); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }}
    th, td {{ padding: 12px 14px; border-bottom: 1px solid var(--border); text-align: left; vertical-align: middle; }}
    th {{ background: #eef3f6; color: #25313d; font-size: 12px; letter-spacing: 0.04em; text-transform: uppercase; }}
    tr:last-child td {{ border-bottom: 0; }}
    .percent, .count {{ font-variant-numeric: tabular-nums; white-space: nowrap; }}
    .percent {{ font-weight: 720; }}
    .bar {{ width: 100%; min-width: 180px; height: 12px; background: var(--bar-bg); border-radius: 999px; overflow: hidden; }}
    .bar > span {{ display: block; width: var(--value); height: 100%; border-radius: inherit; background: var(--accent); }}
    .bar.good > span {{ background: var(--good); }}
    .bar.warn > span {{ background: var(--warn); }}
    .bar.low > span {{ background: var(--low); }}
    .links {{ display: flex; flex-wrap: wrap; gap: 10px; margin-top: 16px; }}
    .links a {{ padding: 7px 11px; border: 1px solid var(--border); border-radius: 7px; background: var(--panel); color: var(--accent); font-weight: 700; text-decoration: none; }}
    .footnote {{ margin-top: 18px; color: var(--muted); font-size: 13px; }}
    @media (max-width: 780px) {{
      table, thead, tbody, tr, th, td {{ display: block; }}
      thead {{ display: none; }}
      tr {{ border-bottom: 1px solid var(--border); }}
      td {{ border-bottom: 0; padding: 9px 12px; }}
      td::before {{ content: attr(data-label); display: block; color: var(--muted); font-size: 11px; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase; }}
      .bar {{ min-width: 0; }}
    }}
  </style>
</head>
<body>
  <main>
    <h1>MMU Phase14 Scope Coverage Report</h1>
    <p class="subtitle">L1TLB, L2TLB, and PTW code/assertion coverage derived from hierarchy-filtered VDB XML records.</p>
    <section class="notice">
      <strong>Important:</strong> This is an XML fallback scope report, not an official Synopsys URG hierarchy report.
      L1TLB includes <code>u_mmu_l1dtlb</code> and <code>x_mmu_l1itlb</code>; L2TLB includes <code>x_mmu_l2tlb</code>; PTW includes <code>x_ct_mmu_ptw</code>.
    </section>
    <table>
      <thead><tr><th>Scope</th><th>Metric</th><th>Coverage</th><th>Progress</th><th>Covered / Total</th></tr></thead>
      <tbody>
        {''.join(rows)}
      </tbody>
    </table>
    <div class="links">
      <a href="scope_coverage_summary.txt">Text summary</a>
      <a href="scope_coverage_summary.json">Machine-readable JSON</a>
      <a href="coverage_report.html">Full MMU report</a>
    </div>
    <p class="footnote">VDBs scanned: {summary['vdb_count']}; missing testdata VDBs: {summary['missing_testdata_vdbs']}; elapsed: {summary['elapsed_s']} seconds.</p>
  </main>
</body>
</html>
"""
    path.write_text(html_text, encoding="utf-8")


def main(argv: Sequence[str]) -> int:
    parser = argparse.ArgumentParser(description="Generate scope-specific XML fallback coverage report")
    parser.add_argument("--vdb-root", type=Path, default=Path("output/phase14_parallel_vdb"))
    parser.add_argument("--report-dir", type=Path, default=Path("output/coverage/phase14_urgReport"))
    args = parser.parse_args(argv)

    vdbs = iter_vdbs(args.vdb_root)
    if not vdbs:
        print(f"ERROR: no phase14_parallel_*.vdb directories under {args.vdb_root}", file=sys.stderr)
        return 2
    args.report_dir.mkdir(parents=True, exist_ok=True)
    summary = collect_scope_coverage(vdbs, DEFAULT_SCOPES)
    write_text(args.report_dir / "scope_coverage_summary.txt", summary)
    (args.report_dir / "scope_coverage_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8"
    )
    write_html(args.report_dir / "scope_coverage_report.html", summary)
    print(f"Scope XML fallback coverage report: {args.report_dir / 'scope_coverage_report.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
