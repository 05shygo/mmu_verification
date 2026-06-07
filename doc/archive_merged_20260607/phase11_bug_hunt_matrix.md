# Phase 11 Bug Hunt Matrix

## Summary

- This matrix is the executable traceability view for Phase 11 B-owned assets.
- Runnable wrappers were created under:
  - `mmu_verification/testbench/test/bug_hunt_tests/`
  - `mmu_verification/testbench/test/ptw_lsu_protocol_tests/`
- `TC-BUG-015` stays document-only by design.

## Bug Hunt

| Trace ID | Wrapper / Output | F-ID | Priority | Status | Checker | Runnable | List membership |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `TC-BUG-001` | `test_bug_001_twu_fst_fetch_type` | `F4.NEW.2` | `P1` | `Functional` | twu fetch-type positive guard | Yes | `mmu_v3_regression_list` |
| `TC-BUG-002` | `test_bug_002_thd_chk_4k_a_bit` | `F4.NEW.3` | `P1` | `Functional` | `sva_thd_a_bit_pgflt` | Yes | `mmu_v3_regression_list` |
| `TC-BUG-003` | `test_bug_003_thd_chk_leaf_refill` | `F4.NEW.1` | `P1` | `Functional` | `sva_pde_nonleaf_upd` | Yes | `mmu_v3_regression_list` |
| `TC-BUG-004` | `test_bug_004_mmu_arb_bank_mask` | `F5.NEW.1` | `P1` | `Functional` | `mmu_arb_sva` positive guard | Yes | `mmu_v3_regression_list` |
| `TC-BUG-005` | `test_bug_005_l2_raw_vld_and_gate` | `F3.4` | `P0` | `Blocked-Waiting-RTL-Fix` | `sva_raw_vld_and_gate` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-006` | `test_bug_006_l2_is_dtlb_store` | `F3.5` | `P0` | `Blocked-Waiting-RTL-Fix` | `cg_l2_store_dtlb_tag` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-007` | `test_bug_007_rrpv_post_inv` | `F3.NEW.1` | `P0` | `Blocked-Waiting-RTL-Fix` | `sva_rrpv_inv_state` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-008` | `test_bug_008_pplru_entry0_first_hit` | `F12.NEW.1` | `P0` | `Blocked-Waiting-RTL-Fix` | `sva_pplru_entry0_first_hit` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-011` | `test_bug_011_twu_2m_csr_cross` | `F4.NEW.4` | `P0` | `Blocked-Waiting-RTL-Fix` | `sva_twu_2m_cross_data`, `cg_twu_2m_csr_cross` | Yes | commented out until `R19` closes |
| `TC-BUG-012` | `test_bug_012_csr_grant_onehot` | `F4.NEW.5` | `P1` | `Planned` | `sva_csr_grant_onehot` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-013` | `test_bug_013_ptw_write_pipe_reset` | `F5.NEW.2` | `P1` | `Planned` | `sva_ptw_write_pipe_reset_safe` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-014` | `test_bug_014_xbar_cold_start` | `F5.NEW.3` | `P1` | `Planned` | `cg_xbar_cold_start` | Yes | `mmu_bug_hunt_list`, `mmu_v3_regression_list` |
| `TC-BUG-015` | `doc/phase11_bug015_doc_review.md` | `F8.NEW.2` | `P2` | `DOC_REVIEW` | document review | No | document-only |

## PTW -> LSU Protocol

| Trace ID | Wrapper | F-ID | Priority | Checker | Runnable | List membership |
| --- | --- | --- | --- | --- | --- | --- |
| `TC-PMBUF-SERIAL-OUTSTANDING-001` | `test_pmbuf_serial_outstanding_001` | `F4.42a` | `P0` | `sva_single_outstanding`, `sva_lsu_req_stable_until_vld` | Yes | `mmu_ptw_lsu_protocol_list`, `mmu_v3_regression_list` |
| `TC-PMBUF-ADDR-STABLE-001` | `test_pmbuf_addr_stable_001` | `F4.42a` | `P0` | `sva_lsu_addr_stable_until_vld`, `cg_lsu_req_outstanding` | Yes | `mmu_ptw_lsu_protocol_list`, `mmu_v3_regression_list` |
| `TC-PMBUF-NO-TAG-001` | `test_pmbuf_no_tag_001` | `F4.42b` | `P0` | `sva_vld_only_when_req` | Yes | `mmu_ptw_lsu_protocol_list`, `mmu_v3_regression_list` |
| `TC-PMBUF-INORDER-RESP-001` | `test_pmbuf_inorder_resp_001` | `F4.42b` | `P0` | `sva_response_inorder` | Yes | `mmu_ptw_lsu_protocol_list`, `mmu_v3_regression_list` |
| `TC-PMBUF-PTR-HOLD-001` | `test_pmbuf_ptr_hold_001` | `F4.42c` | `P1` | `sva_mbuf_ptr_only_on_response`, `cg_mbuf_ptr_hold` | Yes | `mmu_ptw_lsu_protocol_list`, `mmu_v3_regression_list` |
