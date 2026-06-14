# -----------------------------------------------------------------------------
# MMU Phase 14 coverage exclusion / waiver policy
# -----------------------------------------------------------------------------
# Owner: Phase14 Closure Owner
# Tracker: ../../doc/MMU_Phase14_IssueTracker.md
#
# Phase 14 is a closure phase. Historical A-side/B-side ownership is retained
# for traceability, but active waiver/signoff execution is owned by the
# Phase14 Closure Owner.
#
# Active exclusion policy:
# - Every active `coverage exclude ...` command must carry a `-comment`.
# - The comment must include a Phase 14 tracker ID:
#     MMU-P14-ISSUE-NNN: <reason>
# - The referenced issue must exist in doc/MMU_Phase14_IssueTracker.md.
# - Waiver or signoff decisions require second review in
#   doc/MMU_Phase14_SignoffMatrix.md.
# - Small testcase/list/gate fixes can be closed directly by the Closure Owner.
# - Any change to signoff criteria, coverage threshold, waiver policy, or URG
#   fallback policy must be recorded in the issue tracker before gate/matrix
#   changes are accepted.
#
# No active exclusions are enabled at Phase 14 bootstrap. The baseline Phase 10
# policy remains in simu/exclude.do; this v4 file records only Phase 14
# tracker-backed exclusions and review policy.
#
# -----------------------------------------------------------------------------
# Active Phase 14 exclusions (MMU-P14-ISSUE-022)
# -----------------------------------------------------------------------------
# The applied exclusions live in the URG elfile simu/exclude_v4.tgl, which is
# passed to URG at report time via -elfile (wired into phase14_coverage_merge_
# parallel and the scope URG reports). Only structurally-unreachable objects
# are excluded; no functional/behavioral toggle or FSM transition is excluded.
#
# Excluded signal classes (whole-signal toggle, both directions):
#   cpurst_b / rst_b / rst_n      -> reset nets; 1->0 never occurs functionally
#   pad_yy_icg_scan_en             -> DFT scan/ICG enable, tied 0 in functional mode
#   hpcp_mmu_cnt_en                -> perf-counter enable, gated in verification
#
# Excluded FSM transition classes (reset-path-only, no functional next-state):
#   ct_mmu_tlboper: tlbp/tlbr/tlbwi WFG->IDLE, tlbwr TLBWR_WFG/WRTAG->IDLE,
#                   tlbiasid IASID_RD/WFC->IDLE, tlbiva IVA_CMP/RD/WR/WT->IDLE
#   mmu_l2tlb:      pfu PFU_CHK->PFU_IDLE
#   Each was verified in RTL: the WFG/WFC/WT combinational case has no IDLE
#   assignment, and the state register has no abort-to-IDLE branch. The only
#   code path is `if(!cpurst_b) state <= IDLE`, requiring mid-test reset.
#
# Representative `coverage exclude` records below document the same waiver for
# sim-time tools and human review. The full instance-level list is in
# simu/exclude_v4.tgl. Measured impact on phase14_merged.vdb:
#   Toggle exclusions: DUT u_dut toggle 72.09% -> 72.34% (+0.25%).
#   FSM exclusions   : DUT u_dut FSM 80.90% -> 86.10% (+5.20%).
#   line/branch/cond/assert unchanged.
coverage exclude -scope /tb_top/u_dut -togglenode {cpurst_b} -comment "MMU-P14-ISSUE-022: reset net; 1->0 never occurs in functional runs; full list in simu/exclude_v4.tgl"
coverage exclude -scope /tb_top/u_dut -togglenode {rst_b} -comment "MMU-P14-ISSUE-022: reset net; 1->0 never occurs in functional runs; full list in simu/exclude_v4.tgl"
coverage exclude -scope /tb_top/u_dut -togglenode {rst_n} -comment "MMU-P14-ISSUE-022: reset net; 1->0 never occurs in functional runs; full list in simu/exclude_v4.tgl"
coverage exclude -scope /tb_top/u_dut -togglenode {pad_yy_icg_scan_en} -comment "MMU-P14-ISSUE-022: DFT scan/ICG enable tied 0 in functional mode; out of MMU verification scope"
coverage exclude -scope /tb_top/u_dut -togglenode {hpcp_mmu_cnt_en} -comment "MMU-P14-ISSUE-022: performance-counter enable gated/tied in verification; not a functional toggle target"
coverage exclude -scope /tb_top/u_dut/x_ct_mmu_tlboper -fsmstate {tlbp_cur_st} -trans {PWFG->IDLE} -comment "MMU-P14-ISSUE-022: reset-path-only FSM transition; no functional next-state path; full list in simu/exclude_v4.tgl"
coverage exclude -scope /tb_top/u_dut/x_ct_mmu_tlboper -fsmstate {tlbiva_cur_st} -trans {IVA_CMP->IVA_IDLE} -comment "MMU-P14-ISSUE-022: reset-path-only FSM transition; no functional next-state path; full list in simu/exclude_v4.tgl"
coverage exclude -scope /tb_top/u_dut/x_mmu_l2tlb -fsmstate {pfu_cur_st} -trans {PFU_CHK->PFU_IDLE} -comment "MMU-P14-ISSUE-022: reset-path-only FSM transition; PFU_CHK has only ->DENY/->OK, no functional IDLE path; full list in simu/exclude_v4.tgl"
