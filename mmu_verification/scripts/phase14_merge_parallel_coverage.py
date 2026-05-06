#!/usr/bin/env python3
"""Merge Phase14 high-parallel shard VDBs with URG."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional


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
) -> int:
    attempts: List[List[str]] = [
        [urg, "-full64", "-dir", str(merged_db), "-format", "both", "-report", str(report_dir)]
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
        return rc

    rc = report_with_optional_context(args.urg, base_db, merged_db, report_dir, log_path)
    if rc != 0:
        print(f"ERROR: URG report generation failed rc={rc} log={log_path}", file=sys.stderr)
        return rc

    if not has_files(report_dir):
        print(f"ERROR: URG report missing after parallel merge: {report_dir}", file=sys.stderr)
        return 1
    print(f"Phase14 parallel URG report: {report_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
