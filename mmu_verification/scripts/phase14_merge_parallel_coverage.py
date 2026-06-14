#!/usr/bin/env python3
"""Merge Phase14 high-parallel shard VDBs with URG.

When the local URG binary crashes while reading otherwise-valid VDB XML, this
script can emit an explicit XML-derived fallback report.  The fallback is only a
diagnostic/reporting path; a successful URG merge remains the preferred and
official coverage artifact.
"""

import argparse
import gzip
import html
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from contextlib import contextmanager
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple


def _popen_text_stdio_kwargs():
    """Text mode for captured stdout (``text=`` requires Python 3.7+)."""
    if sys.version_info >= (3, 7):
        return {"text": True, "errors": "ignore"}
    if sys.version_info >= (3, 6):
        return {"universal_newlines": True, "encoding": "utf-8", "errors": "ignore"}
    return {"universal_newlines": True}


FIELDS = (
    "shard_id",
    "seed",
    "list",
    "summary",
    "cov_vdb",
    "base_vdb",
    "stamp",
    "log_dir",
    "driver_log",
    "run_dir",
)

BIT_METRICS = ("line", "branch", "cond", "fsm", "tgl")
BIT_METRIC_LABELS = {
    "line": "line",
    "branch": "branch",
    "cond": "condition",
    "fsm": "fsm",
    "tgl": "toggle",
}
INSTANCE_DATA_RE = re.compile(r"<instance_data\b([^>]*)/?>")
ATTR_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"')


def parse_manifest(path: Path) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not raw.strip() or raw.startswith("#"):
            continue
        parts = raw.rstrip("\n").split("\t")
        if len(parts) == len(FIELDS) - 1:
            parts.append(str(Path(parts[-1]).parent / "run"))
        elif len(parts) != len(FIELDS):
            raise ValueError(f"bad manifest row with {len(parts)} fields: {raw}")
        rows.append(dict(zip(FIELDS, parts)))
    if not rows:
        raise ValueError(f"manifest has no shards: {path}")
    return rows


def has_files(path: Path) -> bool:
    return path.is_dir() and any(path.rglob("*"))


def has_optional_files(path: Optional[Path]) -> bool:
    return path is not None and has_files(path)


def clean_dir(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def chunked(items: List[Path], size: int) -> List[List[Path]]:
    size = max(1, size)
    return [items[index : index + size] for index in range(0, len(items), size)]


@contextmanager
def open_maybe_gzip_text(path: Path):
    """Open VDB XML files, which may be gzip-compressed without a .gz suffix."""

    raw = path.open("rb")
    try:
        magic = raw.read(2)
        raw.seek(0)
        stream = gzip.GzipFile(fileobj=raw) if magic == b"\x1f\x8b" else raw
        text = io.TextIOWrapper(stream, encoding="utf-8", errors="ignore")
        try:
            yield text
        finally:
            text.close()
    finally:
        try:
            raw.close()
        except Exception:
            pass


def parse_xml_attrs(raw: str) -> Dict[str, str]:
    return {match.group(1): html.unescape(match.group(2)) for match in ATTR_RE.finditer(raw)}


def pct(covered: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return (100.0 * float(covered)) / float(total)


def pct_text(value: Optional[float]) -> str:
    return "N/A" if value is None else f"{value:.2f}%"


def xml_tag(elem: ET.Element) -> str:
    tag = elem.tag
    if "}" in tag:
        return tag.rsplit("}", 1)[1]
    return tag


def int_attr(elem: ET.Element, name: str, default: int = 0) -> int:
    raw = elem.attrib.get(name)
    if raw is None or raw == "":
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def int_text(raw: str, default: int = 0) -> int:
    try:
        return int(raw)
    except (TypeError, ValueError):
        return default


class BitMetricAccumulator:
    def __init__(self, metric: str):
        self.metric = metric
        self._bits: Dict[Tuple[str, str, int], bytearray] = {}
        self.files_seen = 0
        self.records_seen = 0

    def add_value(self, name: str, chksum: str, value: str) -> None:
        if not name or not value:
            return
        clean = "".join(ch for ch in value if ch in "01")
        if not clean:
            return
        key = (name, chksum or "-", len(clean))
        bits = self._bits.get(key)
        if bits is None:
            bits = bytearray(b"0" * len(clean))
            self._bits[key] = bits
        for index, ch in enumerate(clean):
            if ch == "1":
                bits[index] = ord("1")
        self.records_seen += 1

    def summary(self) -> Dict[str, object]:
        total = sum(len(bits) for bits in self._bits.values())
        covered = sum(bits.count(ord("1")) for bits in self._bits.values())
        return {
            "metric": self.metric,
            "covered": covered,
            "total": total,
            "percent": pct(covered, total) if total else None,
            "objects": len(self._bits),
            "files_seen": self.files_seen,
            "records_seen": self.records_seen,
            "method": "bitwise OR of VDB instance_data value bitstrings",
        }


class AssertionAccumulator:
    """Track assertion records as an XML-derived activity diagnostic.

    Synopsys assertion data stores several counters per assertion object.  The
    fallback deliberately reports activity rate instead of pretending to
    recreate URG's proprietary assertion score.
    """

    def __init__(self):
        self.records: Dict[Tuple[str, int], bool] = {}
        self.files_seen = 0
        self.values_seen = 0
        self.malformed_values = 0

    def add_value(self, name: str, value: str) -> None:
        if not name or not value:
            return
        numbers = [int_text(item, 0) for item in value.split()]
        if len(numbers) < 6:
            self.malformed_values += 1
            return
        usable = (len(numbers) // 6) * 6
        if usable != len(numbers):
            self.malformed_values += 1
        for offset in range(0, usable, 6):
            group = numbers[offset : offset + 6]
            active = any(count > 0 for count in group[1:])
            key = (name, offset // 6)
            self.records[key] = self.records.get(key, False) or active
        self.values_seen += 1

    def summary(self) -> Dict[str, object]:
        total = len(self.records)
        active = sum(1 for is_active in self.records.values() if is_active)
        return {
            "metric": "assertion",
            "covered": active,
            "total": total,
            "percent": pct(active, total) if total else None,
            "objects": total,
            "files_seen": self.files_seen,
            "records_seen": self.values_seen,
            "inactive_records": total - active,
            "malformed_values": self.malformed_values,
            "method": "VDB assertion record activity rate; not an official URG assertion score",
        }


class FunctionalAccumulator:
    """Collect explicit covergroup bins and bounded auto coverpoint bins."""

    def __init__(self):
        self.explicit_bins: Dict[Tuple[str, str, str, str], bool] = {}
        self.auto_denoms: Dict[Tuple[str, str], int] = {}
        self.auto_hits: Dict[Tuple[str, str], Set[int]] = {}
        self.files_seen = 0
        self.groups_seen = 0
        self.auto_crosses_seen = 0

    def add_explicit_bin(self, key: Tuple[str, str, str, str], hit: bool) -> None:
        self.explicit_bins[key] = self.explicit_bins.get(key, False) or hit

    def add_auto_cp(self, key: Tuple[str, str], denom: int) -> None:
        if denom <= 0:
            return
        # Avoid manufacturing impossible cross-sized denominators from partially
        # reconstructed data.  Explicit bins are still counted separately.
        denom = min(denom, 4096)
        self.auto_denoms[key] = max(self.auto_denoms.get(key, 0), denom)

    def add_auto_hit(self, key: Tuple[str, str], index: int, value: int) -> None:
        if value <= 0 or index < 0:
            return
        self.auto_hits.setdefault(key, set()).add(index)
        if key not in self.auto_denoms:
            self.auto_denoms[key] = min(index + 1, 4096)

    def summary(self) -> Dict[str, object]:
        explicit_total = len(self.explicit_bins)
        explicit_covered = sum(1 for hit in self.explicit_bins.values() if hit)
        auto_total = 0
        auto_covered = 0
        for key, denom in self.auto_denoms.items():
            hits = self.auto_hits.get(key, set())
            auto_total += denom
            auto_covered += sum(1 for index in hits if 0 <= index < denom)
        total = explicit_total + auto_total
        covered = explicit_covered + auto_covered
        return {
            "metric": "functional",
            "covered": covered,
            "total": total,
            "percent": pct(covered, total) if total else None,
            "objects": explicit_total + len(self.auto_denoms),
            "files_seen": self.files_seen,
            "groups_seen": self.groups_seen,
            "explicit_bins": explicit_total,
            "auto_coverpoint_bins": auto_total,
            "auto_crosses_seen": self.auto_crosses_seen,
            "method": (
                "testbench.inst.xml explicit bins plus bounded auto coverpoint bins; "
                "auto cross reconstruction is diagnostic only"
            ),
        }


def parse_bit_metric_file(path: Path, accumulator: BitMetricAccumulator) -> None:
    accumulator.files_seen += 1
    with open_maybe_gzip_text(path) as stream:
        for line in stream:
            match = INSTANCE_DATA_RE.search(line)
            if not match:
                continue
            attrs = parse_xml_attrs(match.group(1))
            accumulator.add_value(attrs.get("name", ""), attrs.get("chksum", ""), attrs.get("value", ""))


def parse_assertion_file(path: Path, accumulator: AssertionAccumulator) -> None:
    accumulator.files_seen += 1
    with open_maybe_gzip_text(path) as stream:
        for line in stream:
            match = INSTANCE_DATA_RE.search(line)
            if not match:
                continue
            attrs = parse_xml_attrs(match.group(1))
            accumulator.add_value(attrs.get("name", ""), attrs.get("value", ""))


def parse_functional_file(path: Path, accumulator: FunctionalAccumulator) -> None:
    accumulator.files_seen += 1
    group_stack: List[str] = []
    parent_stack: List[Dict[str, object]] = []
    try:
        with open_maybe_gzip_text(path) as stream:
            for event, elem in ET.iterparse(stream, events=("start", "end")):
                tag = xml_tag(elem)
                if event == "start":
                    if tag in {"cg_inst", "cg_src", "cg_covdef"}:
                        group_name = elem.attrib.get("name") or elem.attrib.get("scope") or tag
                        group_stack.append(group_name)
                        if tag in {"cg_inst", "cg_src"}:
                            accumulator.groups_seen += 1
                    elif tag == "cp":
                        group_name = "::".join(group_stack) if group_stack else "<unknown_group>"
                        parent_stack.append(
                            {
                                "kind": "cp",
                                "group": group_name,
                                "id": elem.attrib.get("id", ""),
                                "name": elem.attrib.get("name") or elem.attrib.get("exprname") or elem.attrib.get("id", ""),
                                "type": elem.attrib.get("type", ""),
                                "width": int_attr(elem, "width", 0),
                                "auto_max": 0,
                            }
                        )
                    elif tag == "cc":
                        group_name = "::".join(group_stack) if group_stack else "<unknown_group>"
                        parent_stack.append(
                            {
                                "kind": "cc",
                                "group": group_name,
                                "id": elem.attrib.get("id", ""),
                                "name": elem.attrib.get("name") or elem.attrib.get("id", ""),
                                "type": "cross",
                                "width": 0,
                                "auto_max": 0,
                            }
                        )
                    elif tag == "cp_option" and parent_stack and parent_stack[-1]["kind"] == "cp":
                        parent = parent_stack[-1]
                        auto_max = int_attr(elem, "auto_bin_max", 0)
                        parent["auto_max"] = auto_max
                        if parent.get("type") == "auto_c":
                            auto_key = (str(parent["group"]), str(parent["id"]) or str(parent["name"]))
                            width = int(parent.get("width", 0) or 0)
                            if auto_max <= 0 and 0 < width <= 12:
                                auto_max = 1 << width
                            accumulator.add_auto_cp(auto_key, auto_max)
                    elif tag == "cc_option" and parent_stack and parent_stack[-1]["kind"] == "cc":
                        parent_stack[-1]["auto_max"] = int_attr(elem, "cross_auto_bin_max", 0)
                    elif tag == "bn" and parent_stack:
                        parent = parent_stack[-1]
                        if (elem.attrib.get("excl", "0") == "1"
                                or elem.attrib.get("unreachable", "0") == "1"
                                or elem.attrib.get("illegal", "0") == "1"):
                            continue
                        bin_id = elem.attrib.get("id", "")
                        bin_name = elem.attrib.get("name", "") or bin_id
                        key = (
                            str(parent["group"]),
                            f"{parent['kind']}:{parent.get('id', '')}:{parent.get('name', '')}",
                            bin_id,
                            bin_name,
                        )
                        accumulator.add_explicit_bin(key, int_attr(elem, "data", 0) > 0)
                    elif tag == "data" and parent_stack and parent_stack[-1]["kind"] == "cp":
                        parent = parent_stack[-1]
                        if parent.get("type") != "auto_c":
                            continue
                        auto_key = (str(parent["group"]), str(parent["id"]) or str(parent["name"]))
                        indexes = [int_text(item, -1) for item in elem.attrib.get("index", "").split()]
                        values = [int_text(item, 0) for item in elem.attrib.get("vals", "").split()]
                        for index, value in zip(indexes, values):
                            accumulator.add_auto_hit(auto_key, index, value)
                    elif tag == "covered_auto_crosses":
                        accumulator.auto_crosses_seen += 1
                else:
                    if tag in {"cp", "cc"} and parent_stack:
                        parent_stack.pop()
                    elif tag in {"cg_inst", "cg_src", "cg_covdef"} and group_stack:
                        group_stack.pop()
                    elem.clear()
    except ET.ParseError:
        # Keep fallback conservative; a malformed functional XML file simply
        # contributes no functional bins instead of fabricating coverage.
        return


def iter_testdata_dirs(vdb: Path) -> Iterable[Path]:
    testdata_root = vdb / "snps" / "coverage" / "db" / "testdata"
    if not testdata_root.is_dir():
        return []
    return [path for path in sorted(testdata_root.iterdir()) if path.is_dir()]


def collect_xml_fallback(vdbs: Sequence[Path], log_path: Path) -> Dict[str, object]:
    started = time.time()
    bit_accumulators = {metric: BitMetricAccumulator(metric) for metric in BIT_METRICS}
    assertion_acc = AssertionAccumulator()
    functional_acc = FunctionalAccumulator()
    missing_testdata = 0

    for index, vdb in enumerate(vdbs, start=1):
        testdata_dirs = list(iter_testdata_dirs(vdb))
        if not testdata_dirs:
            missing_testdata += 1
            continue
        for testdata in testdata_dirs:
            for metric, accumulator in bit_accumulators.items():
                metric_path = testdata / f"{metric}.verilog.data.xml"
                if metric_path.is_file():
                    parse_bit_metric_file(metric_path, accumulator)
            assertion_path = testdata / "assert.verilog.data.xml"
            if assertion_path.is_file():
                parse_assertion_file(assertion_path, assertion_acc)
            functional_path = testdata / "testbench.inst.xml"
            if not functional_path.is_file():
                functional_path = testdata / "testbench.cumulative.xml"
            if functional_path.is_file():
                parse_functional_file(functional_path, functional_acc)
        if index == 1 or index == len(vdbs) or index % 100 == 0:
            message = f"XML fallback progress: {index}/{len(vdbs)} VDBs scanned"
            print(message)
            with log_path.open("a", encoding="utf-8", errors="ignore") as log:
                log.write(message + "\n")

    metrics: Dict[str, Dict[str, object]] = {}
    for metric, accumulator in bit_accumulators.items():
        metrics[metric] = accumulator.summary()
    metrics["functional"] = functional_acc.summary()
    metrics["assertion"] = assertion_acc.summary()
    return {
        "schema_version": "phase14_xml_fallback_coverage_v1",
        "kind": "xml_fallback",
        "vdb_count": len(vdbs),
        "missing_testdata_vdbs": missing_testdata,
        "elapsed_s": round(time.time() - started, 2),
        "metrics": metrics,
    }


def write_xml_fallback_report(
    report_dir: Path,
    merged_db: Path,
    log_path: Path,
    summary: Dict[str, object],
    urg_stage: str,
    urg_rc: int,
) -> None:
    clean_dir(report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)

    metrics = summary["metrics"]
    assert isinstance(metrics, dict)
    lines = [
        "Phase14 XML fallback coverage report",
        "",
        "WARNING: URG failed on this host. This report is derived directly from VDB XML data.",
        "It is not an official Synopsys URG report and should not be used to hide coverage holes.",
        "",
        f"urg_failure_stage: {urg_stage}",
        f"urg_failure_rc: {urg_rc}",
        f"vdb_count: {summary.get('vdb_count')}",
        f"missing_testdata_vdbs: {summary.get('missing_testdata_vdbs')}",
        f"elapsed_s: {summary.get('elapsed_s')}",
        "",
        "Metric summary:",
    ]

    ordered = [
        ("line", "line coverage"),
        ("branch", "branch coverage"),
        ("cond", "condition coverage"),
        ("tgl", "toggle coverage"),
        ("fsm", "fsm coverage"),
        ("functional", "functional coverage"),
        ("assertion", "assertion coverage"),
    ]
    for key, label in ordered:
        metric = metrics.get(key, {})
        if not isinstance(metric, dict):
            continue
        value = metric.get("percent")
        percent = None if value is None else float(value)
        covered = int(metric.get("covered", 0) or 0)
        total = int(metric.get("total", 0) or 0)
        lines.append(f"{label}: {pct_text(percent)} ({covered}/{total})")
        lines.append(f"  method: {metric.get('method', '')}")
        if key == "functional":
            lines.append(
                "  note: functional fallback excludes full URG auto-cross reconstruction; "
                "review JSON details before signoff."
            )
        if key == "assertion":
            lines.append(
                "  note: assertion fallback is an activity diagnostic; assertion failures are checked in simulation logs."
            )
    lines.append("")
    lines.append(f"Original URG log: {log_path}")
    lines.append(f"Official merged VDB was not created by fallback: {merged_db}")

    text_path = report_dir / "coverage_summary.txt"
    text_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    json_path = report_dir / "coverage_summary.json"
    json_path.write_text(json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8")

    html_rows = []
    for key, label in ordered:
        metric = metrics.get(key, {})
        if not isinstance(metric, dict):
            continue
        value = metric.get("percent")
        percent = None if value is None else float(value)
        html_rows.append(
            "<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>".format(
                html.escape(label),
                html.escape(pct_text(percent)),
                html.escape(str(metric.get("covered", 0))),
                html.escape(str(metric.get("total", 0))),
                html.escape(str(metric.get("method", ""))),
            )
        )
    html_text = """<!doctype html>
<html>
<head><meta charset="utf-8"><title>Phase14 XML fallback coverage</title></head>
<body>
<h1>Phase14 XML fallback coverage report</h1>
<p><strong>WARNING:</strong> URG failed on this host. This report is derived directly from VDB XML data and is not an official Synopsys URG report.</p>
<p>Assertion fallback is an activity diagnostic; assertion failures remain covered by the clean simulation log checks.</p>
<p>URG failure stage: {stage}, rc: {rc}</p>
<table border="1" cellspacing="0" cellpadding="4">
<thead><tr><th>Metric</th><th>Coverage</th><th>Covered</th><th>Total</th><th>Method</th></tr></thead>
<tbody>
{rows}
</tbody>
</table>
<p>See coverage_summary.json for machine-readable details.</p>
</body>
</html>
""".format(stage=html.escape(urg_stage), rc=urg_rc, rows="\n".join(html_rows))
    (report_dir / "index.html").write_text(html_text, encoding="utf-8")

    note_path = merged_db.parent / f"{merged_db.name}.xml_fallback.txt"
    note_path.write_text(
        "\n".join(
            [
                "URG merged VDB was not created on this host.",
                f"Fallback report: {report_dir}",
                f"URG failure stage: {urg_stage}",
                f"URG failure rc: {urg_rc}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def run_xml_fallback_report(
    vdbs: Sequence[Path],
    report_dir: Path,
    merged_db: Path,
    log_path: Path,
    urg_stage: str,
    urg_rc: int,
) -> int:
    with log_path.open("a", encoding="utf-8", errors="ignore") as log:
        log.write(
            "\n# URG failed; starting XML-derived fallback report "
            f"stage={urg_stage} rc={urg_rc}\n"
        )
    summary = collect_xml_fallback(vdbs, log_path)
    write_xml_fallback_report(report_dir, merged_db, log_path, summary, urg_stage, urg_rc)
    metrics = summary.get("metrics", {})
    required = ("line", "branch", "tgl", "fsm", "functional", "assertion")
    missing = []
    if isinstance(metrics, dict):
        for metric in required:
            item = metrics.get(metric, {})
            if not isinstance(item, dict) or int(item.get("total", 0) or 0) <= 0:
                missing.append(metric)
    if missing:
        print(
            "ERROR: XML fallback could not reconstruct required coverage metrics: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 1
    print(f"Phase14 XML fallback coverage report: {report_dir}")
    return 0


def run_and_tee(cmd: List[str], log_path: Path) -> int:
    with log_path.open("a", encoding="utf-8", errors="ignore") as log:
        log.write("\n$ " + " ".join(cmd) + "\n")
        log.flush()
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            **_popen_text_stdio_kwargs(),
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            print(line, end="")
            log.write(line)
        return proc.wait()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Merge Phase14 parallel VDBs with URG")
    parser.add_argument("--manifest", required=True, help="Parallel shard manifest")
    parser.add_argument("--urg", default="urg", help="URG executable")
    parser.add_argument("--base-db", default="", help="Compile-time coverage context VDB")
    parser.add_argument("--merged-db", required=True, help="Output merged VDB")
    parser.add_argument("--report-dir", required=True, help="Output URG report directory")
    parser.add_argument("--log", required=True, help="URG merge log")
    parser.add_argument(
        "--batch-size",
        type=int,
        default=12,
        help="Shard VDBs per intermediate URG merge batch",
    )
    parser.add_argument(
        "--xml-fallback",
        choices=("auto", "never"),
        default=os.environ.get("PHASE14_XML_COVERAGE_FALLBACK", "auto"),
        help=(
            "Emit an explicit XML-derived report if URG fails. "
            "Default: auto (set PHASE14_XML_COVERAGE_FALLBACK=never to disable)."
        ),
    )
    parser.add_argument(
        "--elfile",
        default="",
        help=(
            "Optional URG exclusion file applied at report time (-elfile). "
            "Used to honor reviewed coverage exclusions (e.g. simu/exclude_v4.tgl). "
            "Only structural/unreachable exclusions should be placed here; see "
            "MMU-P14-ISSUE-022."
        ),
    )
    return parser


def merge_with_optional_context(
    urg: str,
    base_db: Optional[Path],
    vdbs: List[Path],
    out_db: Path,
    log_path: Path,
    label: str,
) -> int:
    """Merge VDBs, preferring compile context when available."""

    attempts: List[List[str]] = []
    if has_optional_files(base_db):
        assert base_db is not None
        attempts.append([urg, "-full64", "-dir", str(base_db), *[str(path) for path in vdbs], "-dbname", str(out_db)])
    attempts.append([urg, "-full64", "-dir", *[str(path) for path in vdbs], "-dbname", str(out_db)])

    last_rc = 1
    for attempt_index, cmd in enumerate(attempts, start=1):
        clean_dir(out_db)
        with log_path.open("a", encoding="utf-8", errors="ignore") as log:
            log.write(
                f"\n# {label}: attempt {attempt_index}/{len(attempts)} "
                f"inputs={len(vdbs)} context={'yes' if base_db is not None and cmd[3] == str(base_db) else 'no'}\n"
            )
        last_rc = run_and_tee(cmd, log_path)
        if last_rc == 0 and has_files(out_db):
            return 0
    return last_rc


def report_with_optional_context(
    urg: str,
    base_db: Optional[Path],
    merged_db: Path,
    report_dir: Path,
    log_path: Path,
    elfile: Optional[Path] = None,
) -> int:
    elfile_args: List[str] = []
    if elfile and Path(elfile).is_file():
        elfile_args = ["-elfile", str(elfile)]
    attempts: List[List[str]] = [
        [urg, "-full64", "-dir", str(merged_db), *elfile_args, "-format", "both", "-report", str(report_dir)]
    ]
    if has_optional_files(base_db):
        assert base_db is not None
        attempts.append(
            [
                urg,
                "-full64",
                "-dir",
                str(base_db),
                str(merged_db),
                *elfile_args,
                "-format",
                "both",
                "-report",
                str(report_dir),
            ]
        )

    last_rc = 1
    for attempt_index, cmd in enumerate(attempts, start=1):
        clean_dir(report_dir)
        with log_path.open("a", encoding="utf-8", errors="ignore") as log:
            log.write(f"\n# report attempt {attempt_index}/{len(attempts)}\n")
        last_rc = run_and_tee(cmd, log_path)
        if last_rc == 0 and has_files(report_dir):
            return 0
    return last_rc


def main() -> int:
    args = build_parser().parse_args()
    rows = parse_manifest(Path(args.manifest))
    vdbs = [Path(row["cov_vdb"]) for row in rows]
    missing = [str(path) for path in vdbs if not has_files(path)]
    if missing:
        print("ERROR: missing/empty parallel shard VDBs:", file=sys.stderr)
        for path in missing[:20]:
            print(f"  {path}", file=sys.stderr)
        if len(missing) > 20:
            print(f"  ... truncated, total missing={len(missing)}", file=sys.stderr)
        return 1

    merged_db = Path(args.merged_db)
    report_dir = Path(args.report_dir)
    log_path = Path(args.log)
    base_db = Path(args.base_db) if args.base_db else None
    batch_size = max(1, int(args.batch_size))
    batch_root = merged_db.parent / f".{merged_db.name}.phase14_parallel_batches"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(
        "\n".join(
            [
                f"Phase14 parallel VDB count: {len(vdbs)}",
                f"Phase14 compile context VDB: {base_db if has_optional_files(base_db) else 'unavailable'}",
                f"Phase14 URG batch size: {batch_size}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    clean_dir(merged_db)
    clean_dir(report_dir)
    clean_dir(batch_root)
    batch_root.mkdir(parents=True, exist_ok=True)

    batches = chunked(vdbs, batch_size)
    batch_dbs: List[Path] = []
    with log_path.open("a", encoding="utf-8", errors="ignore") as log:
        log.write(f"Phase14 URG merge batches: {len(batches)}\n")

    for batch_index, batch_vdbs in enumerate(batches):
        batch_db = batch_root / f"batch_{batch_index:04d}.vdb"
        batch_dbs.append(batch_db)
        rc = merge_with_optional_context(
            args.urg,
            base_db,
            batch_vdbs,
            batch_db,
            log_path,
            f"batch {batch_index + 1}/{len(batches)}",
        )
        if rc != 0:
            print(
                f"ERROR: URG batch merge failed batch={batch_index + 1}/{len(batches)} "
                f"rc={rc} log={log_path}",
                file=sys.stderr,
            )
            if args.xml_fallback == "auto":
                return run_xml_fallback_report(
                    vdbs,
                    report_dir,
                    merged_db,
                    log_path,
                    f"batch {batch_index + 1}/{len(batches)}",
                    rc,
                )
            return rc

    final_inputs = batch_dbs if len(batch_dbs) > 1 else batch_dbs[:1]
    rc = merge_with_optional_context(
        args.urg,
        base_db,
        final_inputs,
        merged_db,
        log_path,
        f"final merge from {len(final_inputs)} batch DBs",
    )
    if rc != 0:
        print(f"ERROR: URG final merge failed rc={rc} log={log_path}", file=sys.stderr)
        if args.xml_fallback == "auto":
            return run_xml_fallback_report(vdbs, report_dir, merged_db, log_path, "final merge", rc)
        return rc

    rc = report_with_optional_context(
        args.urg, base_db, merged_db, report_dir, log_path, elfile=args.elfile or None
    )
    if rc != 0:
        print(f"ERROR: URG report generation failed rc={rc} log={log_path}", file=sys.stderr)
        if args.xml_fallback == "auto":
            return run_xml_fallback_report(vdbs, report_dir, merged_db, log_path, "report generation", rc)
        return rc

    if not has_files(report_dir):
        print(f"ERROR: URG report missing after parallel merge: {report_dir}", file=sys.stderr)
        return 1
    print(f"Phase14 parallel URG report: {report_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
