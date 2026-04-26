# =============================================================================
# MMU UVM Verification — testbench/Files.f
# Phase 2: DUT RTL + params package + 7 interfaces + common package
# Compilation order: dv_utils → relate_rtl → params → RTL → interfaces → common
# =============================================================================

# --- dv_utils UVM utilities ---
-F ${CV_DV_UTILS_DIR}/uvm/Files.f

# ---------------------------------------------------------------------------
# Phase 2: RTL compile-time macro definitions (must come before RTL sources)
# ---------------------------------------------------------------------------
${TB_DIR}/common/mmu_rtl_defines.v

# ---------------------------------------------------------------------------
# Phase 2: Relate-RTL library units (behavioral cells)
# ---------------------------------------------------------------------------
${RELATE_RTL_DIR}/clk/gated_clk_cell.v
${RELATE_RTL_DIR}/rtu/ct_rtu_compare_iid.v

# ---------------------------------------------------------------------------
# Phase 2: Shared parameters package (must compile before RTL & interfaces)
# ---------------------------------------------------------------------------
${MMU_PARAMS_DIR}/mmu_params_pkg.sv

# ---------------------------------------------------------------------------
# Phase 2: DUT RTL sources
# ---------------------------------------------------------------------------
${MMU_RTL_DIR}/ct_mmu_dplru.v
${MMU_RTL_DIR}/ct_mmu_dutlb_entry.v
${MMU_RTL_DIR}/ct_mmu_dutlb_huge_entry.v
${MMU_RTL_DIR}/ct_mmu_iplru.v
${MMU_RTL_DIR}/ct_mmu_iutlb_entry.v
${MMU_RTL_DIR}/ct_mmu_iutlb_fst_entry.v
${MMU_RTL_DIR}/ct_mmu_l2tlb_data_array.sv
${MMU_RTL_DIR}/ct_mmu_l2tlb_rrpv_array.sv
${MMU_RTL_DIR}/ct_mmu_l2tlb_tag_array.sv
${MMU_RTL_DIR}/ct_mmu_regs.v
${MMU_RTL_DIR}/ct_mmu_sysmap_hit.v
${MMU_RTL_DIR}/ct_mmu_sysmap.v
${MMU_RTL_DIR}/ct_mmu_tlboper.v
${MMU_RTL_DIR}/ct_spram_wrapper.sv
${MMU_RTL_DIR}/ct_spsram_256x196.v
${MMU_RTL_DIR}/ct_spsram_256x84.v
${MMU_RTL_DIR}/L1PDE_cache.sv
${MMU_RTL_DIR}/L2PDE_cache.sv
${MMU_RTL_DIR}/mbuf_entry.sv
${MMU_RTL_DIR}/mmu_arb.sv
${MMU_RTL_DIR}/mmu_fpga_ram.sv
${MMU_RTL_DIR}/mmu_l1dtlb_allocator.sv
${MMU_RTL_DIR}/mmu_l1dtlb_hit_rd.sv
${MMU_RTL_DIR}/mmu_l1dtlb_expt_cam.sv
${MMU_RTL_DIR}/mmu_l1dtlb_install.sv
${MMU_RTL_DIR}/mmu_l1dtlb_mb_entry.sv
${MMU_RTL_DIR}/mmu_l1dtlb_scheduler.sv
${MMU_RTL_DIR}/mmu_l1dtlb.sv
${MMU_RTL_DIR}/mmu_l1itlb.sv
${MMU_RTL_DIR}/mmu_l2tlb_mb_entry.sv
${MMU_RTL_DIR}/mmu_l2tlb_mb.sv
${MMU_RTL_DIR}/mmu_l2tlb_replacement_policy.sv
${MMU_RTL_DIR}/mmu_l2tlb_reqq_entry.sv
${MMU_RTL_DIR}/mmu_l2tlb_reqq.sv
${MMU_RTL_DIR}/mmu_l2tlb_rrpv_wbuf.sv
${MMU_RTL_DIR}/mmu_l2tlb.sv
${MMU_RTL_DIR}/one_to_four_xbar.sv
${MMU_RTL_DIR}/PDE_cache.sv
${MMU_RTL_DIR}/pplru.sv
${MMU_RTL_DIR}/twu.sv
${MMU_RTL_DIR}/ptw_mbuf.sv
${MMU_RTL_DIR}/ptw.sv
${MMU_RTL_DIR}/ct_mmu_top.v

# ---------------------------------------------------------------------------
# Phase 7: SVA (bind to DUT submodules; compile before UVM, after RTL)
# ---------------------------------------------------------------------------
${TB_DIR}/top/mmu_sva.sv
${TB_DIR}/top/mmu_arb_sva.sv
${TB_DIR}/top/mmu_l2tlb_rrpv_sva.sv
${TB_DIR}/top/mmu_plru_sva.sv
${TB_DIR}/top/credit_sva.sv

# ---------------------------------------------------------------------------
# Phase 2: Testbench interfaces (must come after RTL & params package)
# ---------------------------------------------------------------------------
${TB_DIR}/ifu_agent/ifu_if.sv
${TB_DIR}/lsu_agent/lsu_if.sv
${TB_DIR}/cp0_agent/cp0_if.sv
${TB_DIR}/ptw_mem_agent/ptw_mem_if.sv
${TB_DIR}/pmp_agent/pmp_if.sv
${TB_DIR}/sysmap_cfg_agent/sysmap_cfg_if.sv
${TB_DIR}/misc_agent/misc_if.sv

# ---------------------------------------------------------------------------
# Phase 2: Common utilities package
# ---------------------------------------------------------------------------
${TB_DIR}/common/mmu_common_pkg.sv

# ---------------------------------------------------------------------------
# Phase 2: Minimal base test (smoke check)
# ---------------------------------------------------------------------------
${TB_DIR}/test/mmu_base_test.sv

# ---------------------------------------------------------------------------
# Phase 3: Agent packages (must compile before mmu_env_pkg)
# ---------------------------------------------------------------------------
${TB_DIR}/cp0_agent/cp0_agent_pkg.sv
${TB_DIR}/pmp_agent/pmp_agent_pkg.sv
${TB_DIR}/sysmap_cfg_agent/sysmap_cfg_agent_pkg.sv
${TB_DIR}/ifu_agent/ifu_agent_pkg.sv
${TB_DIR}/lsu_agent/lsu_agent_pkg.sv
${TB_DIR}/ptw_mem_agent/ptw_mem_agent_pkg.sv
${TB_DIR}/misc_agent/misc_agent_pkg.sv

# ---------------------------------------------------------------------------
# Phase 3: Environment package (imports all 3 agent pkgs above)
# ---------------------------------------------------------------------------
${TB_DIR}/env/mmu_env_pkg.sv

# ---------------------------------------------------------------------------
# Phase 3: Test package (imports mmu_env_pkg; includes test_base + sanity tests)
# ---------------------------------------------------------------------------
${TB_DIR}/test/test_pkg.sv
