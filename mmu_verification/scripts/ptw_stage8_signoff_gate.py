#!/usr/bin/env python3
"""PTW stage-10 regression/signoff gate.

The gate freezes the PTW source-side signoff package. It is stricter for P0
and PDE-pmpflg source tests, keeps P2 illegal/constraint tests isolated, and
treats consumer logs as auxiliary evidence only.
"""

import argparse
import csv
import re
import shlex
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


CSV_FIELDS = [
    "requirement_id",
    "requirement_family",
    "audit_id",
    "flow_id",
    "legacy_id",
    "test_name",
    "scenario_id",
    "source_checker",
    "sva_cover",
    "consumer_evidence",
    "status",
    "action",
    "illegal_stimulus",
    "waiver_or_open_reason",
    "notes",
]

P2_TESTS = {
    "test_ptw_same_id_no_reuse_constraint_001",
    "test_ptw_bare_mode_no_request_constraint_001",
    "test_ptw_p2_illegal_constraint_matrix",
}

PURE_ILLEGAL_TESTS = {
    "test_ptw_p2_illegal_constraint_matrix",
}

CRITICAL_MISMATCH_FIELDS = {"flg", "page_size", "ppn", "fault_kind", "target"}

ERROR_RE = re.compile(
    r"\b(UVM_ERROR|UVM_FATAL)\b(?!(?:\s*[:=]\s*0\b))"
    r"|\bTEST FAILED\b|\bFAILED:"
    r"|\bPTW_SOURCE_(?:MISMATCH|DROP_MISMATCH|ILLEGAL_REUSE)\b",
    re.IGNORECASE,
)

ASSERT_FAIL_RE = re.compile(
    r"\b(assert(?:ion)?|sva)\b[^\n]{0,80}\bfail(?:ed|ure|s)?\b(?!\s*[:=]\s*0\b)",
    re.IGNORECASE,
)

COVER_RE = re.compile(r"\bPTW_SVA_COVER\b.*\bhits=([0-9]+)\b")
KEYVAL_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)")

PDE_PMPFLG_REQUIRED_TESTS = {
    "test_ptw_pde_l1_pmp_tag_deny_fst_fault_001",
    "test_ptw_pde_l1_pmp_tag_allow_reuse_001",
    "test_ptw_pde_l2_pmp_l1_deny_accerr_001",
    "test_ptw_pde_l2_pmp_l2_deny_accerr_001",
    "test_ptw_pde_pmpflg_propagation_update_001",
    "test_ptw_pde_accerr_priority_type_id_001",
    "test_ptw_pde_mmode_lock_matrix_001",
    "test_ptw_pde_l2_accerr_valid_gate_001",
    "test_ptw_pde_pmp_clear_repopulate_001",
}

PDE_PMPFLG_MARKER_BY_TEST = {
    "test_ptw_pde_l1_pmp_tag_deny_fst_fault_001": "PTW_STAGE8_CLOSURE status=closed",
    "test_ptw_pde_l1_pmp_tag_allow_reuse_001": "PTW_STAGE8_CLOSURE status=closed",
    "test_ptw_pde_l2_pmp_l1_deny_accerr_001": "PTW_STAGE8_CLOSURE status=partial",
    "test_ptw_pde_l2_pmp_l2_deny_accerr_001": "PTW_STAGE8_CLOSURE status=open",
    "test_ptw_pde_pmpflg_propagation_update_001": "PTW_STAGE8_CLOSURE status=closed",
    "test_ptw_pde_accerr_priority_type_id_001": "PTW_STAGE9_CLOSURE status=closed",
    "test_ptw_pde_mmode_lock_matrix_001": "PTW_STAGE9_CLOSURE status=open",
    "test_ptw_pde_l2_accerr_valid_gate_001": "PTW_STAGE9_CLOSURE status=closed",
    "test_ptw_pde_pmp_clear_repopulate_001": "PTW_STAGE9_CLOSURE status=partial",
}

PDE_PMPFLG_OPEN_TESTS = {
    "test_ptw_pde_l2_pmp_l2_deny_accerr_001",
    "test_ptw_pde_mmode_lock_matrix_001",
}

PDE_PMPFLG_PARTIAL_TESTS = {
    "test_ptw_pde_l2_pmp_l1_deny_accerr_001",
    "test_ptw_pde_pmp_clear_repopulate_001",
}

PDE_PMPFLG_REQUIRED_SVA_BY_TEST = {
    "test_ptw_pde_l1_pmp_tag_deny_fst_fault_001": {"PTW-SVA-PDE-011"},
    "test_ptw_pde_l1_pmp_tag_allow_reuse_001": {"PTW-SVA-PDE-011"},
    "test_ptw_pde_l2_pmp_l1_deny_accerr_001": {"PTW-SVA-PDE-012", "PTW-SVA-PDE-013"},
    "test_ptw_pde_pmpflg_propagation_update_001": {"PTW-SVA-PDE-015"},
    "test_ptw_pde_accerr_priority_type_id_001": {"PTW-SVA-PDE-017", "PTW-SVA-ARB-010"},
    "test_ptw_pde_pmp_clear_repopulate_001": {"PTW-SVA-PDE-001", "PTW-SVA-PDE-015"},
}

PDE_PMPFLG_COVER_BINS_BY_TEST = {
    "test_ptw_pde_l1_pmp_tag_deny_fst_fault_001": {"l1_deny_miss"},
    "test_ptw_pde_l1_pmp_tag_allow_reuse_001": {"l1_allow"},
    "test_ptw_pde_l2_pmp_l1_deny_accerr_001": {
        "l2_l1deny",
        "direct_accerr_load",
        "no_extra_lsu",
    },
    "test_ptw_pde_pmpflg_propagation_update_001": {"update_l1", "update_l2"},
    "test_ptw_pde_accerr_priority_type_id_001": {
        "l2_l1deny",
        "direct_accerr_store",
    },
    "test_ptw_pde_pmp_clear_repopulate_001": {"update_l2"},
}

PDE_PMPFLG_AGGREGATE_SVA_REQS = {
    "PTW-SVA-PDE-011",
    "PTW-SVA-PDE-012",
    "PTW-SVA-PDE-013",
    "PTW-SVA-PDE-014",
    "PTW-SVA-PDE-015",
    "PTW-SVA-PDE-017",
    "PTW-SVA-ARB-010",
}

PDE_PMPFLG_ALLOWED_OPEN_IDS = {
    "PTW-ADD-039",
    "PTW-ADD-040",
    "PTW-ADD-043",
    "PTW-ADD-045",
    "PTW-FLOW-025",
    "PTW-FLOW-026",
    "PTW-FLOW-028",
    "PDE-TP-014",
    "PDE-TP-015",
    "PDE-TP-018",
}

LSU_ID_P0_REQUIRED_TESTS = {
    "test_pmbuf_req_resp_id_basic_001",
    "test_pmbuf_multi_outstanding_id_001",
    "test_pmbuf_ooo_response_by_id_001",
    "test_pmbuf_grant_hold_addr_id_001",
    "test_pmbuf_abort_before_grant_cancel_001",
    "test_pmbuf_bus_error_route_by_id_001",
    "test_pmbuf_abort_drain_single_001",
    "test_pmbuf_abort_drain_multi_001",
    "test_pmbuf_no_new_req_during_drain_001",
    "test_pde_consecutive_l1_update_plru_001",
    "test_pde_consecutive_l2_update_plru_001",
    "test_pde_abort_drain_no_update_001",
}

LSU_ID_P1_REQUIRED_TESTS = {
    "test_pmbuf_duplicate_id_blocked_001",
    "test_pmbuf_random_id_ooo_stress_001",
    "test_pde_consecutive_mixed_update_001",
}

LSU_ID_P2_NEGATIVE_TESTS = {
    "test_pmbuf_invalid_rsp_id_ignored_001",
}

LSU_ID_FOCUSED_REQUIRED_TESTS = {
    "test_pmbuf_req_resp_id_basic_001",
    "test_pmbuf_multi_outstanding_id_001",
    "test_pmbuf_ooo_response_by_id_001",
    "test_pmbuf_grant_hold_addr_id_001",
    "test_pmbuf_abort_before_grant_cancel_001",
    "test_pmbuf_bus_error_route_by_id_001",
    "test_pmbuf_abort_drain_multi_001",
    "test_pmbuf_invalid_rsp_id_ignored_001",
    "test_pde_consecutive_l1_update_plru_001",
    "test_pde_consecutive_l2_update_plru_001",
    "test_pde_abort_drain_no_update_001",
}

LSU_ID_LEGACY_WRAPPER_TESTS = {
    "test_pmbuf_serial_outstanding_001",
    "test_pmbuf_no_tag_001",
    "test_pmbuf_inorder_resp_001",
    "test_pmbuf_addr_stable_001",
    "test_pmbuf_ptr_hold_001",
}

LSU_ID_REQUIRED_MATRIX_IDS = {
    "PTW-LSU-ID-001",
    "PTW-LSU-ID-002",
    "PTW-LSU-ID-003",
    "PTW-LSU-ID-004",
    "PTW-LSU-GRANT-001",
    "PTW-LSU-GRANT-002",
    "PTW-LSU-MULTI-001",
    "PTW-LSU-MULTI-002",
    "PTW-LSU-ABORT-001",
    "PTW-LSU-ABORT-002",
    "PTW-LSU-ABORT-003",
    "PDE-UPD-020",
    "PDE-UPD-021",
    "PDE-UPD-022",
}

# Not every assertion has an independent cover counter. Gate the cover-capable
# IDs here, and validate assertion-only IDs through clean logs plus matrix rows.
LSU_ID_AGGREGATE_SVA_COVER_REQS = {
    "PTW-SVA-LSUID-001",
    "PTW-SVA-LSUID-002",
    "PTW-SVA-LSUID-004",
    "PTW-SVA-LSUID-006",
    "PTW-SVA-GRANT-001",
    "PTW-SVA-GRANT-003",
    "PTW-SVA-ABDRN-002",
    "PTW-SVA-ABDRN-003",
    "PTW-SVA-ABDRN-004",
    "PTW-SVA-ABDRN-005",
    "PTW-SVA-PDE-UPD-020",
    "PTW-SVA-PDE-UPD-021",
    "PTW-SVA-PDE-UPD-022",
    "PTW-SVA-PDE-UPD-023",
    "PTW-SVA-PDE-UPD-024",
    "PTW-SVA-PDE-UPD-025",
    "PTW-SVA-PDE-UPD-026",
    "PTW-SVA-BUSERR-001",
}

LSU_ID_MATRIX_SVA_REQS = {
    "PTW-SVA-LSUID-003",
    "PTW-SVA-LSUID-005",
    "PTW-SVA-GRANT-002",
    "PTW-SVA-ABDRN-005",
}

LSU_ID_REQUIRED_SOURCE_COUNTERS = {
    "req_rsp_id_match",
    "two_outstanding",
    "ooo",
    "grant_wait",
    "abort_drain",
    "buserr_by_id",
    "invalid_id",
}

LSU_ID_REQUIRED_PDE_COUNTERS = {
    "consecutive_l1",
    "consecutive_l2",
    "blocked_by_abort_drain",
}

LSU_ID_OBSOLETE_MARKERS = [
    ("strict_single_outstanding", re.compile(r"\bstrict_single_outstanding\b", re.IGNORECASE)),
    ("NO_TAG", re.compile(r"\bNO_TAG\b")),
    ("response_inorder required", re.compile(r"\bresponse_inorder\s+required\b", re.IGNORECASE)),
    ("sva_response_inorder", re.compile(r"\bsva_response_inorder\b", re.IGNORECASE)),
    ("PTW-014-OBSOLETE-OOO", re.compile(r"\bPTW-014-OBSOLETE-OOO\b")),
]


def strip_inline_comment(line: str) -> str:
    out: List[str] = []
    in_single = False
    in_double = False
    for char in line:
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            break
        out.append(char)
    return "".join(out).strip()


def load_tests(list_path: Path) -> List[str]:
    tests: List[str] = []
    for raw in list_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_inline_comment(raw)
        if not line:
            continue
        tokens = shlex.split(line)
        if tokens:
            tests.append(tokens[0])
    return tests


def parse_keyvals(line: str) -> Dict[str, str]:
    return {match.group(1): match.group(2) for match in KEYVAL_RE.finditer(line)}


def has_clean_source_summary(text: str, *, require_stage: Optional[str] = None) -> bool:
    for line in text.splitlines():
        if "PTW_SOURCE_SB_SUMMARY" not in line:
            continue
        kv = parse_keyvals(line)
        if require_stage is not None and kv.get("stage") != require_stage:
            continue
        mismatch = kv.get("mismatch", "0")
        pending = kv.get("pending", "0")
        illegal = kv.get("illegal", kv.get("unexpected_illegal", "0"))
        if mismatch == "0" and pending == "0" and illegal == "0":
            return True
    return False


def has_sva_cover_hit(text: str) -> bool:
    return any(int(match.group(1)) > 0 for match in COVER_RE.finditer(text))


def has_sva_req_hit(text: str, req_id: str) -> bool:
    for line in text.splitlines():
        if "PTW_SVA_COVER" not in line or req_id not in line:
            continue
        match = re.search(r"\bhits=([0-9]+)\b", line)
        if match and int(match.group(1)) > 0:
            return True
    return False


def parse_pde_pmp_coverage(text: str) -> Optional[Dict[str, int]]:
    cov: Optional[Dict[str, int]] = None
    for line in text.splitlines():
        if "PTW_SOURCE_SB_PDE_PMP_COVERAGE" not in line:
            continue
        cov = {}
        for key, value in parse_keyvals(line).items():
            if key == "stage":
                continue
            try:
                cov[key] = int(value, 0)
            except ValueError:
                pass
    return cov


def parse_int_value(value: str) -> Optional[int]:
    value = value.strip().rstrip(",;")
    try:
        return int(value, 0)
    except ValueError:
        return None


def parse_int_keyvals(line: str) -> Dict[str, int]:
    values: Dict[str, int] = {}
    for key, value in parse_keyvals(line).items():
        parsed = parse_int_value(value)
        if parsed is not None:
            values[key] = parsed
    return values


def parse_lsu_id_coverage(text: str) -> Optional[Dict[str, int]]:
    cov: Optional[Dict[str, int]] = None
    for line in text.splitlines():
        if "PTW_SOURCE_SB_LSU_ID_COVERAGE" not in line:
            continue
        cov = parse_int_keyvals(line)
    return cov


def parse_pde_update_contig_coverage(text: str) -> Optional[Dict[str, int]]:
    cov: Optional[Dict[str, int]] = None
    for line in text.splitlines():
        if "PTW_SOURCE_SB_PDE_UPDATE_CONTIG_COVERAGE" not in line:
            continue
        cov = parse_int_keyvals(line)
    return cov


def merge_counter_values(dst: Dict[str, int], src: Optional[Dict[str, int]]) -> None:
    if not src:
        return
    for key, value in src.items():
        if key.endswith("_mask"):
            dst[key] = dst.get(key, 0) | value
        elif key.startswith("max_"):
            dst[key] = max(dst.get(key, 0), value)
        else:
            dst[key] = dst.get(key, 0) + value


def collect_sva_cover_from_text(text: str) -> Tuple[Set[str], Dict[str, int]]:
    req_hits: Set[str] = set()
    named_hits: Dict[str, int] = {}
    for line in text.splitlines():
        if "PTW_SVA_COVER" not in line:
            continue
        kv = parse_keyvals(line)
        hits = parse_int_value(kv.get("hits", "0"))
        if hits is None:
            continue
        name = kv.get("name")
        if name:
            named_hits[name] = max(named_hits.get(name, 0), hits)
        if hits <= 0:
            continue
        for req_id in kv.get("req", "").split(","):
            req_id = req_id.strip()
            if req_id:
                req_hits.add(req_id)
    return req_hits, named_hits


def check_no_obsolete_lsu_markers(text: str, path: Path) -> List[str]:
    errors: List[str] = []
    for marker, pattern in LSU_ID_OBSOLETE_MARKERS:
        if pattern.search(text):
            errors.append(f"{path}: obsolete LSU-ID closure marker found: {marker}")
    return errors


def check_no_extra_lsu_violation(text: str, path: Path) -> List[str]:
    cov = parse_pde_pmp_coverage(text)
    if cov is None:
        return [f"{path}: missing PTW_SOURCE_SB_PDE_PMP_COVERAGE/no_extra_lsu evidence"]
    if cov.get("no_extra_lsu_violation", 0) != 0:
        return [f"{path}: no_extra_lsu_violation is nonzero"]
    return []


def has_stage8_or_stage9_metadata(text: str) -> bool:
    markers = [
        "PTW_STAGE8_CLOSURE",
        "PTW_STAGE8_TEST_SUMMARY",
        "PTW_STAGE9_CLOSURE",
        "PTW_STAGE9_TEST_SUMMARY",
    ]
    return any(marker in text for marker in markers)


def has_scenario_metadata(text: str) -> bool:
    markers = [
        "PTW_SCENARIO_BEGIN",
        "PTW_SCENARIO_META",
        "PTW_STAGE6_CLOSURE",
        "PTW_FLOW_BIND",
        "PTW_STAGE7_TEST_SUMMARY",
        "PTW_STAGE8_CLOSURE",
        "PTW_STAGE8_TEST_SUMMARY",
        "PTW_STAGE9_CLOSURE",
        "PTW_STAGE9_TEST_SUMMARY",
    ]
    return any(marker in text for marker in markers)


def read_log(log_path: Path) -> Tuple[Optional[str], List[str]]:
    if not log_path.is_file():
        return None, [f"missing log: {log_path}"]
    text = log_path.read_text(encoding="utf-8", errors="ignore")
    errors: List[str] = []
    if ERROR_RE.search(text):
        errors.append(f"{log_path}: error/fatal/source-mismatch marker found")
    if ASSERT_FAIL_RE.search(text):
        errors.append(f"{log_path}: assertion/SVA failure marker found")
    return text, errors


def check_p0_log(log_path: Path, test: str, *, require_lsu_id_coverage: bool = False) -> List[str]:
    text, errors = read_log(log_path)
    if text is None:
        return errors
    errors.extend(check_no_obsolete_lsu_markers(text, log_path))
    if not has_clean_source_summary(text):
        errors.append(f"{log_path}: missing clean PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0")
    if not has_sva_cover_hit(text):
        errors.append(f"{log_path}: missing PTW_SVA_COVER hits>0")
    if not has_scenario_metadata(text):
        errors.append(f"{log_path}: missing PTW scenario/closure metadata")
    if require_lsu_id_coverage and parse_lsu_id_coverage(text) is None:
        errors.append(f"{log_path}: missing PTW_SOURCE_SB_LSU_ID_COVERAGE")
    return errors


def check_pde_pmpflg_log(log_path: Path, test: str) -> List[str]:
    text, errors = read_log(log_path)
    if text is None:
        return errors
    errors.extend(check_no_obsolete_lsu_markers(text, log_path))

    expected_marker = PDE_PMPFLG_MARKER_BY_TEST.get(test)
    if expected_marker and expected_marker not in text:
        errors.append(f"{log_path}: missing pde-pmpflg closure marker: {expected_marker}")

    if not has_stage8_or_stage9_metadata(text):
        errors.append(f"{log_path}: missing Stage8/Stage9 pde-pmpflg metadata")

    if "source_sb_required=0" in text:
        if test not in PDE_PMPFLG_OPEN_TESTS:
            errors.append(f"{log_path}: source_sb_required=0 is allowed only for explicit open/unreachable tests")
    else:
        if not has_clean_source_summary(text):
            errors.append(f"{log_path}: missing clean PTW_SOURCE_SB_SUMMARY mismatch=0 pending=0 illegal=0")
        if "PTW_SOURCE_REF_SUMMARY" not in text:
            errors.append(f"{log_path}: missing PTW_SOURCE_REF_SUMMARY")
        cov = parse_pde_pmp_coverage(text)
        if cov is None:
            errors.append(f"{log_path}: missing PTW_SOURCE_SB_PDE_PMP_COVERAGE")
        else:
            for bin_name in sorted(PDE_PMPFLG_COVER_BINS_BY_TEST.get(test, set())):
                if cov.get(bin_name, 0) <= 0:
                    errors.append(f"{log_path}: PTW_SOURCE_SB_PDE_PMP_COVERAGE {bin_name} not hit")
            if cov.get("no_extra_lsu_violation", 0) != 0:
                errors.append(f"{log_path}: no_extra_lsu_violation is nonzero")

    for req_id in sorted(PDE_PMPFLG_REQUIRED_SVA_BY_TEST.get(test, set())):
        if not has_sva_req_hit(text, req_id):
            errors.append(f"{log_path}: missing PTW_SVA_COVER hits>0 for {req_id}")

    if test in PDE_PMPFLG_OPEN_TESTS:
        if "unreachable" not in text or "no_source_request_driven_unreachable_by_spec" not in text:
            errors.append(f"{log_path}: explicit open test lacks unreachable/no-source marker")

    if test in PDE_PMPFLG_PARTIAL_TESTS:
        if "limitation={" not in text:
            errors.append(f"{log_path}: partial pde-pmpflg test lacks limitation marker")

    if test == "test_ptw_pde_l2_accerr_valid_gate_001":
        if "no_pde_direct_accerr" not in text:
            errors.append(f"{log_path}: valid-gate negative test lacks no_pde_direct_accerr evidence")

    return errors


def check_stage7_log(log_path: Path, test: str, *, list_role: str) -> List[str]:
    text, errors = read_log(log_path)
    if text is None:
        return errors
    errors.extend(check_no_obsolete_lsu_markers(text, log_path))

    if test in PDE_PMPFLG_REQUIRED_TESTS:
        return check_pde_pmpflg_log(log_path, test)

    pure_illegal = test in PURE_ILLEGAL_TESTS
    if test in P2_TESTS or list_role == "p2":
        if "PTW_STAGE7_ILLEGAL status=blocked_by_constraint" not in text:
            errors.append(f"{log_path}: P2/illegal test missing blocked-by-constraint marker")

    if not pure_illegal:
        if not has_clean_source_summary(text, require_stage="7"):
            errors.append(f"{log_path}: missing clean PTW_SOURCE_SB_SUMMARY")
        if "PTW_SOURCE_SB_FIELD_COVERAGE" not in text:
            errors.append(f"{log_path}: missing PTW_SOURCE_SB_FIELD_COVERAGE")
        if "PTW_SOURCE_REF_SUMMARY" not in text:
            errors.append(f"{log_path}: missing PTW_SOURCE_REF_SUMMARY")
        if "consumer_only_does_not_close_source=1" not in text:
            errors.append(f"{log_path}: missing consumer-only/source-closure separation marker")

    if "PTW_STAGE7_TEST_SUMMARY" not in text:
        errors.append(f"{log_path}: missing PTW_STAGE7_TEST_SUMMARY")
    return errors


def check_lsu_id_log(log_path: Path, test: str, *, negative: bool = False) -> List[str]:
    text, errors = read_log(log_path)
    if text is None:
        return errors
    errors.extend(check_no_obsolete_lsu_markers(text, log_path))
    if not has_clean_source_summary(text, require_stage="7"):
        errors.append(f"{log_path}: missing clean PTW_SOURCE_SB_SUMMARY")
    if "PTW_SOURCE_REF_SUMMARY" not in text:
        errors.append(f"{log_path}: missing PTW_SOURCE_REF_SUMMARY")
    if not has_scenario_metadata(text):
        errors.append(f"{log_path}: missing PTW scenario metadata")

    lsu_cov = parse_lsu_id_coverage(text)
    if lsu_cov is None:
        errors.append(f"{log_path}: missing PTW_SOURCE_SB_LSU_ID_COVERAGE")
    elif negative:
        if lsu_cov.get("invalid_id", 0) <= 0:
            errors.append(f"{log_path}: invalid response negative test did not hit invalid_id")

    errors.extend(check_no_extra_lsu_violation(text, log_path))

    if negative and not has_sva_req_hit(text, "PTW-SVA-LSUID-006"):
        errors.append(f"{log_path}: missing PTW_SVA_COVER hits>0 for PTW-SVA-LSUID-006")

    if "PTW_META phase=12" not in text and "ptw_lsu_id_phase12" not in text:
        errors.append(f"{log_path}: missing Phase12 LSU-ID metadata")
    return errors


def check_consumer_log(log_path: Path) -> List[str]:
    text, errors = read_log(log_path)
    if text is None:
        return errors
    if "PTW_SOURCE_MISMATCH" in text or "PTW_SOURCE_SB_SUMMARY" in text and not has_clean_source_summary(text):
        errors.append(f"{log_path}: consumer evidence log has dirty source-checker output")
    return errors


def required_ids(prefix: str, first: int, last: int) -> List[str]:
    return [f"{prefix}-{idx:03d}" for idx in range(first, last + 1)]


def expand_seed_args(values: Optional[List[str]], default: str) -> List[str]:
    seeds: List[str] = []
    if not values:
        values = [default]
    for value in values:
        for item in re.split(r"[,\s]+", value):
            if item:
                seeds.append(item)
    return seeds


def load_closure_csv(csv_path: Path) -> Tuple[List[Dict[str, str]], List[str]]:
    errors: List[str] = []
    if not csv_path.is_file():
        return [], [f"missing closure csv: {csv_path}"]
    with csv_path.open(newline="", encoding="utf-8", errors="ignore") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != CSV_FIELDS:
            errors.append(f"{csv_path}: unexpected CSV header {reader.fieldnames}")
        rows = list(reader)

    for idx, row in enumerate(rows, start=2):
        extra = row.get(None)
        if extra:
            errors.append(f"{csv_path}:{idx}: extra CSV fields {extra}")
        for field in CSV_FIELDS:
            if row.get(field) is None:
                errors.append(f"{csv_path}:{idx}: missing field {field}")
    return rows, errors


def closed_enough(status: str) -> bool:
    if not status:
        return False
    if "open" in status or "partial" in status:
        return False
    return any(token in status for token in ["closed", "implemented", "strengthened"])


def actionable_open(row: Dict[str, str]) -> bool:
    status = row["status"]
    family = row["requirement_family"]
    reason = row["waiver_or_open_reason"]
    if family == "AUDIT" and reason == "stage0 mapping only":
        return False
    if status == "consumer-only":
        return False
    return "open" in status or "partial" in status or status == "open"


def validate_closure_csv(rows: List[Dict[str, str]]) -> List[str]:
    errors: List[str] = []
    expected = (
        required_ids("PTW-AUD", 1, 23)
        + required_ids("PTW-ADD", 1, 45)
        + required_ids("PTW-FLOW", 1, 28)
        + required_ids("PTW-INFRA", 1, 9)
        + required_ids("PDE-TP", 1, 19)
        + required_ids("MBUF-TP", 1, 12)
        + required_ids("MAEE-TP", 1, 13)
    )
    by_id: Dict[str, Dict[str, str]] = {}
    duplicates: Set[str] = set()
    for row in rows:
        rid = row["requirement_id"]
        if rid in by_id:
            duplicates.add(rid)
        by_id[rid] = row
    missing = [rid for rid in expected if rid not in by_id]
    if missing:
        errors.append(f"closure csv missing IDs: {', '.join(missing)}")
    if duplicates:
        errors.append(f"closure csv duplicate IDs: {', '.join(sorted(duplicates))}")

    for flow_id in required_ids("PTW-FLOW", 1, 28):
        row = by_id.get(flow_id)
        if not row:
            continue
        if not closed_enough(row["status"]):
            if not row["waiver_or_open_reason"] or not row["action"]:
                errors.append(f"{flow_id}: open/partial flow lacks action or open reason")

    for row in rows:
        if row["status"] == "consumer-only" and "consumer" not in row["consumer_evidence"].lower():
            errors.append(f"{row['requirement_id']}: consumer-only row lacks consumer_evidence")
        if row["requirement_id"] in required_ids("PTW-ADD", 37, 45):
            tests = [item for item in row["test_name"].split(";") if item]
            if not any(test in PDE_PMPFLG_REQUIRED_TESTS for test in tests):
                errors.append(f"{row['requirement_id']}: pde-pmpflg ADD row lacks required directed test")
        if row["requirement_id"] in required_ids("PDE-TP", 13, 19):
            if not row["sva_cover"] and row["requirement_id"] not in {"PDE-TP-018"}:
                errors.append(f"{row['requirement_id']}: pde-pmpflg PDE row lacks SVA cover")
        if row["requirement_id"] in PDE_PMPFLG_ALLOWED_OPEN_IDS:
            if "open" not in row["status"] and "partial" not in row["status"]:
                errors.append(f"{row['requirement_id']}: expected explicit open/partial pde-pmpflg status")
            if not row["waiver_or_open_reason"]:
                errors.append(f"{row['requirement_id']}: pde-pmpflg open/partial row lacks reason")
        if row["status"].lower().startswith("waiv"):
            reason = row["waiver_or_open_reason"].lower()
            if "global" in reason:
                errors.append(f"{row['requirement_id']}: global waiver is not allowed")
            if any(field in reason for field in CRITICAL_MISMATCH_FIELDS):
                errors.append(f"{row['requirement_id']}: waiver references critical mismatch field")
    return errors


def validate_lsu_id_closure_csv(rows: List[Dict[str, str]]) -> List[str]:
    errors: List[str] = []
    by_id: Dict[str, Dict[str, str]] = {}
    duplicates: Set[str] = set()
    for row in rows:
        rid = row["requirement_id"]
        if rid in by_id:
            duplicates.add(rid)
        by_id[rid] = row

    missing = sorted(LSU_ID_REQUIRED_MATRIX_IDS - set(by_id.keys()))
    if missing:
        errors.append("lsu-id closure csv missing IDs: " + ", ".join(missing))
    duplicated_lsu = sorted(duplicates & LSU_ID_REQUIRED_MATRIX_IDS)
    if duplicated_lsu:
        errors.append("lsu-id closure csv duplicate IDs: " + ", ".join(duplicated_lsu))

    for rid in sorted(LSU_ID_REQUIRED_MATRIX_IDS):
        row = by_id.get(rid)
        if not row:
            continue
        if not closed_enough(row["status"]):
            errors.append(f"{rid}: lsu-id matrix row is not closed")
        if not row["test_name"]:
            errors.append(f"{rid}: lsu-id matrix row lacks test_name")
        if not row["source_checker"]:
            errors.append(f"{rid}: lsu-id matrix row lacks source_checker")
        if not row["sva_cover"]:
            errors.append(f"{rid}: lsu-id matrix row lacks sva_cover")
        if rid == "PTW-LSU-ID-004" and row["illegal_stimulus"] != "yes":
            errors.append(f"{rid}: invalid response ID row must be marked illegal_stimulus=yes")
        elif rid != "PTW-LSU-ID-004" and row["illegal_stimulus"] == "yes":
            errors.append(f"{rid}: legal lsu-id row unexpectedly marked illegal_stimulus=yes")

    matrix_sva_text = "\n".join(row["sva_cover"] for row in rows)
    missing_matrix_sva = sorted(LSU_ID_MATRIX_SVA_REQS - {
        req_id for req_id in LSU_ID_MATRIX_SVA_REQS if req_id in matrix_sva_text
    })
    if missing_matrix_sva:
        errors.append(
            "lsu-id closure csv missing assertion-only SVA evidence IDs: "
            + ", ".join(missing_matrix_sva)
        )

    for row in rows:
        evidence = " ".join([
            row["source_checker"],
            row["sva_cover"],
            row["consumer_evidence"],
        ])
        for marker, pattern in LSU_ID_OBSOLETE_MARKERS:
            if pattern.search(evidence):
                errors.append(f"{row['requirement_id']}: obsolete marker used as closure evidence: {marker}")
    return errors


def validate_lsu_id_list_hygiene(
    *,
    p0_smoke_list: Optional[Path],
    p0_list: Path,
    p1_list: Path,
    p2_list: Path,
    lsu_id_list: Optional[Path],
) -> List[str]:
    errors: List[str] = []
    p0_tests = set(load_tests(p0_list))
    p1_tests = set(load_tests(p1_list))
    p2_tests = set(load_tests(p2_list))
    p0_smoke_tests = set(load_tests(p0_smoke_list)) if p0_smoke_list is not None else set()
    lsu_id_tests = set(load_tests(lsu_id_list)) if lsu_id_list is not None else set()

    missing_p0 = sorted(LSU_ID_P0_REQUIRED_TESTS - p0_tests)
    if missing_p0:
        errors.append("p0 list missing LSU-ID required tests: " + ", ".join(missing_p0))
    missing_p1 = sorted(LSU_ID_P1_REQUIRED_TESTS - p1_tests)
    if missing_p1:
        errors.append("p1 list missing LSU-ID required tests: " + ", ".join(missing_p1))
    missing_p2 = sorted(LSU_ID_P2_NEGATIVE_TESTS - p2_tests)
    if missing_p2:
        errors.append("p2 list missing LSU-ID negative tests: " + ", ".join(missing_p2))

    for role, tests in [
        ("p0_smoke", p0_smoke_tests),
        ("p0_full", p0_tests),
        ("p1_directed", p1_tests),
    ]:
        negative_overlap = sorted(tests & LSU_ID_P2_NEGATIVE_TESTS)
        if negative_overlap:
            errors.append(f"{role} list contains P2-only LSU-ID negative tests: {', '.join(negative_overlap)}")
        legacy_overlap = sorted(tests & LSU_ID_LEGACY_WRAPPER_TESTS)
        if legacy_overlap:
            errors.append(f"{role} list contains legacy LSU protocol wrapper tests: {', '.join(legacy_overlap)}")

    if lsu_id_list is not None:
        legacy_overlap = sorted(lsu_id_tests & LSU_ID_LEGACY_WRAPPER_TESTS)
        if legacy_overlap:
            errors.append(f"lsu_id_focused list contains legacy LSU protocol wrapper tests: {', '.join(legacy_overlap)}")

    if lsu_id_list is not None:
        missing_focused = sorted(LSU_ID_FOCUSED_REQUIRED_TESTS - lsu_id_tests)
        if missing_focused:
            errors.append("lsu-id focused list missing tests: " + ", ".join(missing_focused))
    return errors


def parse_report_open_records(report_text: str) -> Dict[str, Dict[str, str]]:
    records: Dict[str, Dict[str, str]] = {}
    for line in report_text.splitlines():
        if "PTW_SIGNOFF_OPEN" not in line:
            continue
        kv = parse_keyvals(line)
        rid = kv.get("id")
        if rid:
            records[rid] = kv
    return records


def validate_report(report_path: Path, rows: List[Dict[str, str]]) -> List[str]:
    if not report_path.is_file():
        return [f"missing signoff report: {report_path}"]
    text = report_path.read_text(encoding="utf-8", errors="ignore")
    errors: List[str] = []
    required_markers = [
        "PTW_STAGE8_SIGNOFF_REPORT",
        "PTW_STAGE10_SIGNOFF_REPORT",
        "PTW_SIGNOFF_REGRESSION_LIST role=p0_smoke",
        "PTW_SIGNOFF_REGRESSION_LIST role=p0_full",
        "PTW_SIGNOFF_REGRESSION_LIST role=p1_directed",
        "PTW_SIGNOFF_REGRESSION_LIST role=pde_pmpflg",
        "PTW_SIGNOFF_REGRESSION_LIST role=p2_illegal",
        "PTW_SIGNOFF_REGRESSION_LIST role=random_stress",
        "PTW_SIGNOFF_REGRESSION_LIST role=consumer_only",
        "PTW_SIGNOFF_NO_GLOBAL_WAIVER critical_fields=flg,page_size,ppn,fault_kind,target",
        "PTW_SIGNOFF_OBSOLETE_FREEZE",
        "PTW_SIGNOFF_CONSUMER_ONLY",
        "PTW_SIGNOFF_CLOSURE_MATRIX frozen=1",
        "PTW_SIGNOFF_PDE_PMPFLG ids=PTW-ADD-037..045,PDE-TP-013..019,PTW-FLOW-024..028",
    ]
    for marker in required_markers:
        if marker not in text:
            errors.append(f"{report_path}: missing report marker: {marker}")

    open_records = parse_report_open_records(text)
    for row in rows:
        if not actionable_open(row):
            continue
        rid = row["requirement_id"]
        rec = open_records.get(rid)
        if not rec:
            errors.append(f"{report_path}: missing PTW_SIGNOFF_OPEN record for {rid}")
            continue
        if "owner" not in rec or "next" not in rec:
            errors.append(f"{report_path}: open record for {rid} lacks owner or next action")

    for line in text.splitlines():
        if "PTW_SIGNOFF_WAIVER" not in line:
            continue
        kv = parse_keyvals(line)
        if kv.get("scope") == "global":
            errors.append(f"{report_path}: global waiver is not allowed: {line}")
        fields = set(kv.get("fields", "").split(","))
        if fields & CRITICAL_MISMATCH_FIELDS and kv.get("scope") in {"global", "source", "all"}:
            errors.append(f"{report_path}: broad critical-field waiver is not allowed: {line}")
    return errors


def validate_legacy_freeze(legacy_path: Optional[Path], report_path: Path) -> List[str]:
    if legacy_path is None:
        return []
    if not legacy_path.is_file():
        return [f"missing legacy action list: {legacy_path}"]
    legacy = legacy_path.read_text(encoding="utf-8", errors="ignore")
    report = report_path.read_text(encoding="utf-8", errors="ignore") if report_path.is_file() else ""
    required = [
        "test_xbar_twu_round_robin",
        "test_pte_reserved_bits",
        "test_mbuf_ooo_response",
        "obsolete-by-spec",
        "consumer-only",
    ]
    errors: List[str] = []
    for token in required:
        if token not in legacy:
            errors.append(f"{legacy_path}: missing legacy freeze token {token}")
        if token not in report:
            errors.append(f"{report_path}: missing legacy freeze token {token}")
    return errors


def check_list_logs(
    *,
    list_path: Path,
    log_dir: Path,
    seed: str,
    role: str,
    allow_missing: bool = False,
    require_lsu_id_coverage: bool = False,
) -> Tuple[int, List[str]]:
    errors: List[str] = []
    tests = load_tests(list_path)
    if not tests:
        return 0, [f"no tests found in {list_path}"]

    for test in tests:
        log_path = log_dir / f"{test}_{seed}.log"
        if test in PDE_PMPFLG_REQUIRED_TESTS:
            errs = check_pde_pmpflg_log(log_path, test)
        elif test in LSU_ID_P2_NEGATIVE_TESTS:
            errs = check_lsu_id_log(log_path, test, negative=True)
        elif test in LSU_ID_P0_REQUIRED_TESTS or test in LSU_ID_P1_REQUIRED_TESTS:
            errs = check_lsu_id_log(log_path, test)
        elif role == "lsu_id_focused":
            errs = check_lsu_id_log(log_path, test)
        elif role in {"p0_smoke", "p0_full"}:
            errs = check_p0_log(log_path, test, require_lsu_id_coverage=require_lsu_id_coverage)
        elif role in {"p1_directed", "random_stress"}:
            errs = check_stage7_log(log_path, test, list_role=role)
        elif role == "p2_illegal":
            errs = check_stage7_log(log_path, test, list_role="p2")
        elif role == "consumer_only":
            errs = check_consumer_log(log_path)
        else:
            errs = [f"unknown list role {role}"]

        if allow_missing:
            errs = [err for err in errs if not err.startswith("missing log:")]
        errors.extend(errs)
    return len(tests), errors


def collect_sva_req_hits_for_list(
    *,
    list_path: Path,
    log_dir: Path,
    seeds: List[str],
    required_reqs: Set[str],
) -> Tuple[Set[str], List[str]]:
    hit_reqs: Set[str] = set()
    errors: List[str] = []
    tests = load_tests(list_path)
    for seed in seeds:
        for test in tests:
            log_path = log_dir / f"{test}_{seed}.log"
            text, errs = read_log(log_path)
            errors.extend([err for err in errs if not err.startswith("missing log:")])
            if text is None:
                continue
            for req_id in required_reqs:
                if req_id not in hit_reqs and has_sva_req_hit(text, req_id):
                    hit_reqs.add(req_id)
    return hit_reqs, errors


def collect_lsu_id_aggregate_evidence(
    *,
    list_specs: List[Tuple[Path, List[str]]],
    log_dir: Path,
) -> Tuple[Dict[str, int], Dict[str, int], Set[str], Dict[str, int], List[str]]:
    lsu_cov: Dict[str, int] = {}
    pde_cov: Dict[str, int] = {}
    sva_req_hits: Set[str] = set()
    named_sva_hits: Dict[str, int] = {}
    errors: List[str] = []

    for list_path, seeds in list_specs:
        tests = load_tests(list_path)
        for seed in seeds:
            for test in tests:
                log_path = log_dir / f"{test}_{seed}.log"
                if not log_path.is_file():
                    continue
                text = log_path.read_text(encoding="utf-8", errors="ignore")
                errors.extend(check_no_obsolete_lsu_markers(text, log_path))
                merge_counter_values(lsu_cov, parse_lsu_id_coverage(text))
                merge_counter_values(pde_cov, parse_pde_update_contig_coverage(text))
                pde_pmp_cov = parse_pde_pmp_coverage(text)
                if pde_pmp_cov is not None:
                    lsu_cov["no_extra_lsu_violation"] = (
                        lsu_cov.get("no_extra_lsu_violation", 0)
                        + pde_pmp_cov.get("no_extra_lsu_violation", 0)
                    )
                req_hits, name_hits = collect_sva_cover_from_text(text)
                sva_req_hits.update(req_hits)
                for name, hits in name_hits.items():
                    named_sva_hits[name] = max(named_sva_hits.get(name, 0), hits)
    return lsu_cov, pde_cov, sva_req_hits, named_sva_hits, errors


def validate_lsu_id_aggregate_evidence(
    *,
    lsu_cov: Dict[str, int],
    pde_cov: Dict[str, int],
    sva_req_hits: Set[str],
    named_sva_hits: Dict[str, int],
) -> List[str]:
    errors: List[str] = []

    missing_sva = sorted(LSU_ID_AGGREGATE_SVA_COVER_REQS - sva_req_hits)
    if missing_sva:
        errors.append(
            "lsu-id aggregate logs missing PTW_SVA_COVER hits>0 for: "
            + ", ".join(missing_sva)
        )

    for name in ["cp_lsu_two_outstanding", "cp_lsu_ooo_response"]:
        if named_sva_hits.get(name, 0) <= 0:
            errors.append(f"lsu-id aggregate logs did not hit {name}")

    for key in sorted(LSU_ID_REQUIRED_SOURCE_COUNTERS):
        if lsu_cov.get(key, 0) <= 0:
            errors.append(f"PTW_SOURCE_SB_LSU_ID_COVERAGE aggregate {key} not hit")
    if lsu_cov.get("no_extra_lsu_violation", 0) != 0:
        errors.append("PTW_SOURCE_SB_PDE_PMP_COVERAGE aggregate no_extra_lsu_violation is nonzero")

    for key in sorted(LSU_ID_REQUIRED_PDE_COUNTERS):
        if pde_cov.get(key, 0) <= 0:
            errors.append(f"PTW_SOURCE_SB_PDE_UPDATE_CONTIG_COVERAGE aggregate {key} not hit")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="PTW stage-10 signoff gate")
    parser.add_argument("--p0-smoke-list", type=Path)
    parser.add_argument("--p0-list", required=True, type=Path)
    parser.add_argument("--p1-list", required=True, type=Path)
    parser.add_argument("--pde-pmpflg-list", required=True, type=Path)
    parser.add_argument("--lsu-id-list", type=Path)
    parser.add_argument("--p2-list", required=True, type=Path)
    parser.add_argument("--random-list", required=True, type=Path)
    parser.add_argument("--consumer-list", required=True, type=Path)
    parser.add_argument("--log-dir", required=True, type=Path)
    parser.add_argument("--p0-seed", default="606")
    parser.add_argument("--p1-seed", default="606")
    parser.add_argument("--stage7-seed", default="707")
    parser.add_argument("--pde-pmpflg-seed", action="append")
    parser.add_argument("--lsu-id-seed", action="append")
    parser.add_argument("--consumer-seed", default="707")
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--legacy", type=Path)
    parser.add_argument("--allow-missing-consumer-logs", action="store_true")
    args = parser.parse_args()

    errors: List[str] = []
    counts: Dict[str, int] = {}
    pde_pmpflg_seeds = expand_seed_args(args.pde_pmpflg_seed, "606")
    lsu_id_seeds = expand_seed_args(args.lsu_id_seed, args.p0_seed)
    enable_lsu_id_gate = args.lsu_id_list is not None

    if args.p0_smoke_list is not None:
        counts["p0_smoke"], errs = check_list_logs(
            list_path=args.p0_smoke_list,
            log_dir=args.log_dir,
            seed=args.p0_seed,
            role="p0_smoke",
            require_lsu_id_coverage=enable_lsu_id_gate,
        )
        errors.extend(errs)

    for role, list_path, seed in [
        ("p0_full", args.p0_list, args.p0_seed),
        ("p1_directed", args.p1_list, args.p1_seed),
        ("p2_illegal", args.p2_list, args.stage7_seed),
        ("random_stress", args.random_list, args.stage7_seed),
    ]:
        counts[role], errs = check_list_logs(
            list_path=list_path,
            log_dir=args.log_dir,
            seed=seed,
            role=role,
            require_lsu_id_coverage=enable_lsu_id_gate and role == "p0_full",
        )
        errors.extend(errs)

    if args.lsu_id_list is not None:
        lsu_count = 0
        for seed in lsu_id_seeds:
            lsu_count, errs = check_list_logs(
                list_path=args.lsu_id_list,
                log_dir=args.log_dir,
                seed=seed,
                role="lsu_id_focused",
            )
            errors.extend(errs)
        counts["lsu_id_focused"] = lsu_count * len(lsu_id_seeds)

    pde_count = 0
    for seed in pde_pmpflg_seeds:
        pde_count, errs = check_list_logs(
            list_path=args.pde_pmpflg_list,
            log_dir=args.log_dir,
            seed=seed,
            role="pde_pmpflg",
        )
        errors.extend(errs)
    counts["pde_pmpflg"] = pde_count * len(pde_pmpflg_seeds)

    pde_sva_hits, errs = collect_sva_req_hits_for_list(
        list_path=args.pde_pmpflg_list,
        log_dir=args.log_dir,
        seeds=pde_pmpflg_seeds,
        required_reqs=PDE_PMPFLG_AGGREGATE_SVA_REQS,
    )
    errors.extend(errs)
    missing_pde_sva = sorted(PDE_PMPFLG_AGGREGATE_SVA_REQS - pde_sva_hits)
    if missing_pde_sva:
        errors.append(
            "pde_pmpflg list missing aggregate PTW_SVA_COVER hits>0 for: "
            + ", ".join(missing_pde_sva)
        )

    counts["consumer_only"], errs = check_list_logs(
        list_path=args.consumer_list,
        log_dir=args.log_dir,
        seed=args.consumer_seed,
        role="consumer_only",
        allow_missing=args.allow_missing_consumer_logs,
    )
    errors.extend(errs)

    rows, csv_errors = load_closure_csv(args.csv)
    errors.extend(csv_errors)
    if rows:
        errors.extend(validate_closure_csv(rows))
        if enable_lsu_id_gate:
            errors.extend(validate_lsu_id_closure_csv(rows))
        errors.extend(validate_report(args.report, rows))
    else:
        errors.extend(validate_report(args.report, []))
    errors.extend(validate_legacy_freeze(args.legacy, args.report))

    if enable_lsu_id_gate:
        errors.extend(validate_lsu_id_list_hygiene(
            p0_smoke_list=args.p0_smoke_list,
            p0_list=args.p0_list,
            p1_list=args.p1_list,
            p2_list=args.p2_list,
            lsu_id_list=args.lsu_id_list,
        ))
        lsu_specs: List[Tuple[Path, List[str]]] = [
            (args.p0_list, [args.p0_seed]),
            (args.p1_list, [args.p1_seed]),
            (args.p2_list, [args.stage7_seed]),
            (args.lsu_id_list, lsu_id_seeds),
        ]
        if args.p0_smoke_list is not None:
            lsu_specs.append((args.p0_smoke_list, [args.p0_seed]))
        lsu_cov, pde_cov, lsu_sva_hits, lsu_named_sva_hits, errs = collect_lsu_id_aggregate_evidence(
            list_specs=lsu_specs,
            log_dir=args.log_dir,
        )
        errors.extend(errs)
        errors.extend(validate_lsu_id_aggregate_evidence(
            lsu_cov=lsu_cov,
            pde_cov=pde_cov,
            sva_req_hits=lsu_sva_hits,
            named_sva_hits=lsu_named_sva_hits,
        ))

    if errors:
        print("PTW_STAGE10_SIGNOFF_GATE status=FAIL")
        print(
            "  hint: Stage10 gate validates UVM_INFO evidence markers; "
            "run signoff regressions with UVM_ERR_ONLY=0 so PTW_SOURCE_* "
            "and PTW_STAGE* markers are present in output/logs."
        )
        for item in errors:
            print(f"  - {item}")
        return 1

    print(
        "PTW_STAGE10_SIGNOFF_GATE status=PASS "
        + " ".join(f"{role}_tests={count}" for role, count in sorted(counts.items()))
        + " source_sb=clean p0_cover=hit pde_pmpflg_cover=hit"
        + (" lsu_id_cover=hit lsu_id_negative=isolated" if enable_lsu_id_gate else "")
        + " closure_matrix=frozen report=validated"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
