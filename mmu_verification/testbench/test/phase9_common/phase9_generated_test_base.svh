// =============================================================================
// MMU UVM Verification — Phase 9 generated test base
//
// Purpose:
//   Provide a compile-safe execution skeleton for large numbers of thin Phase 9
//   test wrappers. Each generated test overrides setup_plan() to declare
//   metadata plus one or more reusable direct sequences / vseqs.
//
// Notes:
//   - This base deliberately reuses the existing Phase 3/4/5/6/8 sequence
//     inventory. Many Phase 9 wrappers therefore share common bringup and
//     stimulus while preserving one-test-one-file granularity.
//   - Tests remain free to override run_test_body() later if a TC needs a fully
//     bespoke scenario instead of this generated skeleton.
// =============================================================================
`ifndef PHASE9_GENERATED_TEST_BASE_SVH
`define PHASE9_GENERATED_TEST_BASE_SVH

class phase9_generated_test_base extends test_base;

  `uvm_component_utils(phase9_generated_test_base)

  string p9_tc_id;
  string p9_seq_desc;
  string p9_checker;
  string p9_reviewer;

  string m_vseq_names[$];
  string m_ifu_seq_names[$];
  string m_lsu_seq_names[$];
  string m_cp0_seq_names[$];
  string m_pmp_seq_names[$];
  string m_sysmap_seq_names[$];
  string m_misc_seq_names[$];
  string m_ptw_seq_names[$];

  bit          m_enable_sv39_4k_bringup;
  bit          m_run_misc_init;
  bit          m_wait_lsu_idle_before_vseq;
  int unsigned m_nmap;
  va_t         m_va_base;
  ppn_t        m_root_ppn;
  asid_t       m_root_asid;
  ppn_t        m_leaf_ppn0;
  time         m_post_drain;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn     = 64;
    timeout_ns  = 2_000_000;
    m_post_drain = 500ns;
  endfunction

  virtual function void setup_plan();
    m_vseq_names.delete();
    m_ifu_seq_names.delete();
    m_lsu_seq_names.delete();
    m_cp0_seq_names.delete();
    m_pmp_seq_names.delete();
    m_sysmap_seq_names.delete();
    m_misc_seq_names.delete();
    m_ptw_seq_names.delete();

    p9_tc_id     = "UNSPECIFIED";
    p9_seq_desc  = "";
    p9_checker   = "";
    p9_reviewer  = "B";

    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init          = 1'b1;
    m_wait_lsu_idle_before_vseq = 1'b0;
    m_nmap                   = 32;
    m_va_base                = 39'h10_0000;
    m_root_ppn               = 28'h0;
    m_root_asid              = 16'h0;
    m_leaf_ppn0              = 28'h200;
    m_post_drain             = 500ns;
  endfunction

  protected function int unsigned clamp_direct_num_txn();
    if (num_txn == 0) return 1;
    if (num_txn > 256) return 256;
    return num_txn;
  endfunction

  protected function int unsigned clamp_vseq_num_txn();
    if (num_txn < 32) return 32;
    if (num_txn > 50000) return 50000;
    return num_txn;
  endfunction

  protected virtual task do_sv39_4k_bringup();
    cp0_tlb_allinv_seq       cp0_inv;
    pmp_flg_normal_seq       pmp_seq;
    sysmap_region_setup_seq  sysmap_seq;
    cp0_reg_rw_seq           cp0_init;

    cp0_inv = cp0_tlb_allinv_seq::type_id::create("cp0_inv");
    cp0_inv.start(m_env.m_cp0.m_sequencer);

    pmp_seq = pmp_flg_normal_seq::type_id::create("pmp_seq");
    pmp_seq.start(m_env.m_pmp.m_sequencer);

    sysmap_seq = sysmap_region_setup_seq::type_id::create("sysmap_seq");
    sysmap_seq.start(m_env.m_sysmap_cfg.m_sequencer);

    cp0_init = cp0_reg_rw_seq::type_id::create("cp0_init");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'(m_root_asid), 44'(m_root_ppn)};
          priv_mode == 2'b01;
          ptw_en    == 1'b1;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "cp0_init randomize failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);
    if (m_env.m_ref != null)
      m_env.m_ref.sync_shadow_state();

    m_env.m_pt_mem.m_builder.set_root(m_root_ppn, m_root_asid);
    for (int i = 0; i < int'(m_nmap); i++) begin
      va_t v;
      ppn_t leaf_ppn;
      v        = va_t'(m_va_base) + va_t'(i << 12);
      leaf_ppn = ppn_t'(m_leaf_ppn0 + ppn_t'(i));
      m_env.m_pt_mem.m_builder.map_4k(
        .va(v),
        .pa(pa_t'({leaf_ppn, 12'h000})),
        .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)
      );
    end
    #200ns;
  endtask

  protected virtual task start_vseq_by_name(string seq_name);
    mmu_base_vseq seq;
    int unsigned n_txn;

    n_txn = clamp_vseq_num_txn();
    case (seq_name)
      "mmu_smoke_vseq":               seq = mmu_smoke_vseq::type_id::create(seq_name);
      "mmu_concurrent_3pipe_vseq":    seq = mmu_concurrent_3pipe_vseq::type_id::create(seq_name);
      "mmu_ptw_thrash_vseq":          seq = mmu_ptw_thrash_vseq::type_id::create(seq_name);
      "mmu_sfence_during_walk_vseq":  seq = mmu_sfence_during_walk_vseq::type_id::create(seq_name);
      "mmu_asid_context_switch_vseq": seq = mmu_asid_context_switch_vseq::type_id::create(seq_name);
      "mmu_inv_asid_hit_directed_vseq": seq = mmu_inv_asid_hit_directed_vseq::type_id::create(seq_name);
      "mmu_inv_asid_global_directed_vseq": seq = mmu_inv_asid_global_directed_vseq::type_id::create(seq_name);
      "mmu_inv_asid_overlap_directed_vseq": seq = mmu_inv_asid_overlap_directed_vseq::type_id::create(seq_name);
      "mmu_huge_page_mix_vseq":       seq = mmu_huge_page_mix_vseq::type_id::create(seq_name);
      "mmu_rrpv_aging_vseq":          seq = mmu_rrpv_aging_vseq::type_id::create(seq_name);
      "mmu_l2tlb_bank_conflict_vseq": seq = mmu_l2tlb_bank_conflict_vseq::type_id::create(seq_name);
      "mmu_l2tlb_reqq_arb_fine_vseq": seq = mmu_l2tlb_reqq_arb_fine_vseq::type_id::create(seq_name);
      "mmu_l2tlb_hash_directed_vseq": seq = mmu_l2tlb_hash_directed_vseq::type_id::create(seq_name);
      "mmu_l1itlb_state_mix_vseq":    seq = mmu_l1itlb_state_mix_vseq::type_id::create(seq_name);
      "mmu_l2tlb_bank_page_size_matrix_vseq": seq = mmu_l2tlb_bank_page_size_matrix_vseq::type_id::create(seq_name);
      "mmu_l2tlb_tag_write_read_inv_mix_vseq": seq = mmu_l2tlb_tag_write_read_inv_mix_vseq::type_id::create(seq_name);
      "mmu_satp_hotswap_vseq":        seq = mmu_satp_hotswap_vseq::type_id::create(seq_name);
      "mmu_stress_all_ports_vseq":    seq = mmu_stress_all_ports_vseq::type_id::create(seq_name);
      "mmu_power_gating_vseq":        seq = mmu_power_gating_vseq::type_id::create(seq_name);
      "mmu_reset_midtransaction_vseq": seq = mmu_reset_midtransaction_vseq::type_id::create(seq_name);
      "mmu_error_rain_vseq":          seq = mmu_error_rain_vseq::type_id::create(seq_name);
      "mmu_perf_bench_vseq":          seq = mmu_perf_bench_vseq::type_id::create(seq_name);
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown vseq '%s'", seq_name))
    endcase
    if (!seq.randomize() with { num_txn == n_txn; })
      `uvm_fatal(get_type_name(), $sformatf("randomize failed for vseq '%s'", seq_name))
    seq.start(m_env.m_vseqr);
  endtask

  protected virtual task start_l1dtlb_directed_by_tc_id(string tc_id);
    l1dtlb_directed_vseq seq;
    int unsigned n_txn;

    n_txn = clamp_vseq_num_txn();
    seq = l1dtlb_directed_vseq::type_id::create({tc_id, "_directed_vseq"});
    seq.tc_id = tc_id;
    if (!l1dtlb_directed_vseq::decode_tc_id(tc_id, seq.scenario))
      `uvm_fatal(get_type_name(), $sformatf("Unknown L1DTLB tc_id '%s'", tc_id))
    if (!seq.randomize() with { num_txn == n_txn; })
      `uvm_fatal(get_type_name(), $sformatf("randomize failed for L1DTLB directed tc_id '%s'", tc_id))
    seq.tc_id = tc_id;
    seq.start(m_env.m_vseqr);
  endtask

  protected virtual task start_ifu_seq_by_name(string seq_name);
    int unsigned n_txn;
    n_txn = clamp_direct_num_txn();
    case (seq_name)
      "ifu_random_vaddr_seq": begin
        ifu_random_vaddr_seq seq = ifu_random_vaddr_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      "ifu_sequential_fetch_seq": begin
        ifu_sequential_fetch_seq seq = ifu_sequential_fetch_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      "ifu_abort_seq": begin
        ifu_abort_seq seq = ifu_abort_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      "ifu_branch_flush_seq": begin
        ifu_branch_flush_seq seq = ifu_branch_flush_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      "ifu_pagefault_trigger_seq": begin
        ifu_pagefault_trigger_seq seq = ifu_pagefault_trigger_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      "ifu_exec_perm_mix_seq": begin
        ifu_exec_perm_mix_seq seq = ifu_exec_perm_mix_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      "ifu_huge_page_fetch_seq": begin
        ifu_huge_page_fetch_seq seq = ifu_huge_page_fetch_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown IFU sequence '%s'", seq_name))
    endcase
  endtask

  protected virtual task start_lsu_seq_by_name(string seq_name);
    int unsigned n_txn;
    n_txn = clamp_direct_num_txn();
    case (seq_name)
      "lsu_pipe0_only_seq": begin
        lsu_pipe0_only_seq seq = lsu_pipe0_only_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_mapped_pipe0_rr_seq": begin
        mmu_vseq_lsu_rr_seq seq = mmu_vseq_lsu_rr_seq::type_id::create(seq_name);
        int unsigned npage;
        npage = (m_nmap > 0) ? m_nmap : 1;
        seq.m_va_table   = new[npage];
        seq.m_table_size = npage;
        seq.m_kind       = LSU_PIPE0;
        seq.m_st_inst    = 1'b0;
        for (int unsigned i = 0; i < npage; i++)
          seq.m_va_table[i] = va_t'(m_va_base) + va_t'(i << 12);
        seq.num_txn     = n_txn;
        seq.m_zero_idle = 1'b0;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_mapped_pipe0_back2back_seq": begin
        mmu_vseq_lsu_rr_seq seq = mmu_vseq_lsu_rr_seq::type_id::create(seq_name);
        int unsigned npage;
        npage = (m_nmap > 0) ? m_nmap : 1;
        seq.m_va_table   = new[npage];
        seq.m_table_size = npage;
        seq.m_kind       = LSU_PIPE0;
        seq.m_st_inst    = 1'b0;
        for (int unsigned i = 0; i < npage; i++)
          seq.m_va_table[i] = va_t'(m_va_base) + va_t'(i << 12);
        seq.num_txn     = n_txn;
        seq.m_zero_idle = 1'b1;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_pipe1_only_seq": begin
        lsu_pipe1_only_seq seq = lsu_pipe1_only_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_01_concurrent_seq": begin
        lsu_01_concurrent_seq seq = lsu_01_concurrent_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_prefetch_pipe2_seq": begin
        lsu_prefetch_pipe2_seq seq = lsu_prefetch_pipe2_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_stamo_seq": begin
        lsu_stamo_seq seq = lsu_stamo_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_back2back_seq": begin
        lsu_back2back_seq seq = lsu_back2back_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_same_line_hit_miss_seq": begin
        lsu_same_line_hit_miss_seq seq = lsu_same_line_hit_miss_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_abort_seq": begin
        lsu_abort_seq seq = lsu_abort_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_huge_page_seq": begin
        lsu_huge_page_seq seq = lsu_huge_page_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_cross_asid_seq": begin
        lsu_cross_asid_seq seq = lsu_cross_asid_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_st_ld_mix_seq": begin
        lsu_st_ld_mix_seq seq = lsu_st_ld_mix_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "lsu_unaligned_seq": begin
        lsu_unaligned_seq seq = lsu_unaligned_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "tlb_inv_all_seq": begin
        tlb_inv_all_seq seq = tlb_inv_all_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "tlb_inv_va_seq": begin
        tlb_inv_va_seq seq = tlb_inv_va_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "tlb_inv_asid_seq": begin
        tlb_inv_asid_seq seq = tlb_inv_asid_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "tlb_inv_va_asid_seq": begin
        tlb_inv_va_asid_seq seq = tlb_inv_va_asid_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      "sfence_vma_stress_seq": begin
        sfence_vma_stress_seq seq = sfence_vma_stress_seq::type_id::create(seq_name);
        seq.num_txn = n_txn;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown LSU sequence '%s'", seq_name))
    endcase
  endtask

  protected virtual task start_cp0_seq_by_name(string seq_name);
    case (seq_name)
      "cp0_satp_switch_seq": begin
        cp0_satp_switch_seq seq = cp0_satp_switch_seq::type_id::create(seq_name);
        seq.satp_val = {4'h8, 16'h0, 44'h0};
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_satp_sel_toggle_seq": begin
        cp0_satp_sel_toggle_seq seq = cp0_satp_sel_toggle_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_priv_switch_seq": begin
        cp0_priv_switch_seq seq = cp0_priv_switch_seq::type_id::create(seq_name);
        void'(seq.randomize() with { priv_mode inside {2'b00, 2'b01}; });
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_mxr_sum_cross_seq": begin
        cp0_mxr_sum_cross_seq seq = cp0_mxr_sum_cross_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_mprv_seq": begin
        cp0_mprv_seq seq = cp0_mprv_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_ptw_disable_seq": begin
        cp0_ptw_disable_seq seq = cp0_ptw_disable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_tlb_allinv_seq": begin
        cp0_tlb_allinv_seq seq = cp0_tlb_allinv_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_no_op_seq": begin
        cp0_no_op_seq seq = cp0_no_op_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_no_op_assert_seq": begin
        cp0_no_op_assert_seq seq = cp0_no_op_assert_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_no_op_clear_seq": begin
        cp0_no_op_clear_seq seq = cp0_no_op_clear_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_maee_enable_seq": begin
        cp0_maee_enable_seq seq = cp0_maee_enable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_maee_disable_seq": begin
        cp0_maee_disable_seq seq = cp0_maee_disable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_icg_enable_seq": begin
        cp0_icg_enable_seq seq = cp0_icg_enable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_icg_disable_seq": begin
        cp0_icg_disable_seq seq = cp0_icg_disable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_cskyee_enable_seq": begin
        cp0_cskyee_enable_seq seq = cp0_cskyee_enable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_cskyee_disable_seq": begin
        cp0_cskyee_disable_seq seq = cp0_cskyee_disable_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_satp_read_seq": begin
        cp0_satp_read_seq seq = cp0_satp_read_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_satp_read_both_seq": begin
        cp0_satp_read_both_seq seq = cp0_satp_read_both_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_satp_mode_sv39_seq": begin
        cp0_satp_mode_sv39_seq seq = cp0_satp_mode_sv39_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_satp_mode_bare_seq": begin
        cp0_satp_mode_bare_seq seq = cp0_satp_mode_bare_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_reg_access_seq": begin
        cp0_reg_access_seq seq = cp0_reg_access_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_tlbp_seq": begin
        cp0_tlbp_seq seq = cp0_tlbp_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbp_reset_target_seq": begin
        cp0_l2tlb_tlbp_reset_target_seq seq = cp0_l2tlb_tlbp_reset_target_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbp_hit_exact_seq": begin
        cp0_l2tlb_tlbp_hit_exact_seq seq = cp0_l2tlb_tlbp_hit_exact_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbp_miss_exact_seq": begin
        cp0_l2tlb_tlbp_miss_exact_seq seq = cp0_l2tlb_tlbp_miss_exact_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_tlbr_seq": begin
        cp0_tlbr_seq seq = cp0_tlbr_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbr_reset_target_seq": begin
        cp0_l2tlb_tlbr_reset_target_seq seq = cp0_l2tlb_tlbr_reset_target_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbr_read_exact_seq": begin
        cp0_l2tlb_tlbr_read_exact_seq seq = cp0_l2tlb_tlbr_read_exact_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbr_all_fields_exact_seq": begin
        cp0_l2tlb_tlbr_all_fields_exact_seq seq = cp0_l2tlb_tlbr_all_fields_exact_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_tlbwi_seq": begin
        cp0_tlbwi_seq seq = cp0_tlbwi_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbwi_reset_target_seq": begin
        cp0_l2tlb_tlbwi_reset_target_seq seq = cp0_l2tlb_tlbwi_reset_target_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbwi_write_exact_seq": begin
        cp0_l2tlb_tlbwi_write_exact_seq seq = cp0_l2tlb_tlbwi_write_exact_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbwi_overwrite_exact_seq": begin
        cp0_l2tlb_tlbwi_overwrite_exact_seq seq = cp0_l2tlb_tlbwi_overwrite_exact_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_tlbwr_seq": begin
        cp0_tlbwr_seq seq = cp0_tlbwr_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbwr_reset_target_seq": begin
        cp0_l2tlb_tlbwr_reset_target_seq seq = cp0_l2tlb_tlbwr_reset_target_seq::type_id::create(seq_name);
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbwr_visible_exact_seq": begin
        cp0_l2tlb_tlbwr_visible_exact_seq seq = cp0_l2tlb_tlbwr_visible_exact_seq::type_id::create(seq_name);
        seq.num_writes = 1;
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_l2tlb_tlbwr_rrpv_visible_exact_seq": begin
        cp0_l2tlb_tlbwr_visible_exact_seq seq = cp0_l2tlb_tlbwr_visible_exact_seq::type_id::create(seq_name);
        seq.num_writes = 3;
        seq.start(m_env.m_cp0.m_sequencer);
      end
      "cp0_reg_rw_seq": begin
        cp0_reg_rw_seq seq = cp0_reg_rw_seq::type_id::create(seq_name);
        if (!seq.randomize() with {
              satp_val  == {4'h8, 16'h0, 44'h0};
              priv_mode == 2'b01;
              ptw_en    == 1'b1;
              icg_en    == 1'b1;
            })
          `uvm_fatal(get_type_name(), "cp0_reg_rw_seq randomize failed")
        seq.start(m_env.m_cp0.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown CP0 sequence '%s'", seq_name))
    endcase
  endtask

  protected virtual task start_pmp_seq_by_name(string seq_name);
    case (seq_name)
      "pmp_flg_normal_seq": begin
        pmp_flg_normal_seq seq = pmp_flg_normal_seq::type_id::create(seq_name);
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_deny_fetch_seq": begin
        pmp_flg_deny_fetch_seq seq = pmp_flg_deny_fetch_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_deny_rw_seq": begin
        pmp_flg_deny_rw_seq seq = pmp_flg_deny_rw_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_deny_pfu_seq": begin
        pmp_flg_deny_pfu_seq seq = pmp_flg_deny_pfu_seq::type_id::create(seq_name);
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_cross_8port_seq": begin
        pmp_flg_cross_8port_seq seq = pmp_flg_cross_8port_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_raw_seq": begin
        pmp_flg_raw_seq seq = pmp_flg_raw_seq::type_id::create(seq_name);
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_coverage_sweep_seq": begin
        pmp_flg_coverage_sweep_seq seq = pmp_flg_coverage_sweep_seq::type_id::create(seq_name);
        seq.start(m_env.m_pmp.m_sequencer);
      end
      "pmp_flg_deny_ptw_rd_seq": begin
        pmp_flg_deny_ptw_rd_seq seq = pmp_flg_deny_ptw_rd_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_pmp.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown PMP sequence '%s'", seq_name))
    endcase
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
  endtask

  protected virtual task start_sysmap_seq_by_name(string seq_name);
    case (seq_name)
      "sysmap_region_setup_seq": begin
        sysmap_region_setup_seq seq = sysmap_region_setup_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_sysmap_cfg.m_sequencer);
      end
      "sysmap_hit_cross_tlb_seq": begin
        sysmap_hit_cross_tlb_seq seq = sysmap_hit_cross_tlb_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_sysmap_cfg.m_sequencer);
      end
      "sysmap_boundary_seq": begin
        sysmap_boundary_seq seq = sysmap_boundary_seq::type_id::create(seq_name);
        seq.start(m_env.m_sysmap_cfg.m_sequencer);
      end
      "sysmap_perm_flag_seq": begin
        sysmap_perm_flag_seq seq = sysmap_perm_flag_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_sysmap_cfg.m_sequencer);
      end
      "sysmap_cfg_coverage_sweep_seq": begin
        sysmap_cfg_coverage_sweep_seq seq = sysmap_cfg_coverage_sweep_seq::type_id::create(seq_name);
        seq.start(m_env.m_sysmap_cfg.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown SysMap sequence '%s'", seq_name))
    endcase
  endtask

  protected virtual task start_misc_seq_by_name(string seq_name);
    case (seq_name)
      "misc_rtu_flush_seq": begin
        misc_rtu_flush_seq seq = misc_rtu_flush_seq::type_id::create(seq_name);
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_rtu_expt_seq": begin
        misc_rtu_expt_seq seq = misc_rtu_expt_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_smp_disable_seq": begin
        misc_smp_disable_seq seq = misc_smp_disable_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_smp_disable_on_seq": begin
        misc_smp_disable_on_seq seq = misc_smp_disable_on_seq::type_id::create(seq_name);
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_smp_disable_off_seq": begin
        misc_smp_disable_off_seq seq = misc_smp_disable_off_seq::type_id::create(seq_name);
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_hpcp_enable_seq": begin
        misc_hpcp_enable_seq seq = misc_hpcp_enable_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_hpcp_enable_on_seq": begin
        misc_hpcp_enable_on_seq seq = misc_hpcp_enable_on_seq::type_id::create(seq_name);
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_hpcp_enable_off_seq": begin
        misc_hpcp_enable_off_seq seq = misc_hpcp_enable_off_seq::type_id::create(seq_name);
        seq.start(m_env.m_misc.m_sequencer);
      end
      "misc_init_seq": begin
        misc_init_seq seq = misc_init_seq::type_id::create(seq_name);
        seq.start(m_env.m_misc.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown misc sequence '%s'", seq_name))
    endcase
  endtask

  protected virtual task start_ptw_seq_by_name(string seq_name);
    case (seq_name)
      "ptw_mem_normal_rsp_seq": begin
        ptw_mem_normal_rsp_seq seq = ptw_mem_normal_rsp_seq::type_id::create(seq_name);
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_mem_delay0_rsp_seq": begin
        ptw_mem_delay_range_seq seq = ptw_mem_delay_range_seq::type_id::create(seq_name);
        seq.delay_min = 0;
        seq.delay_max = 0;
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_mem_delay1_rsp_seq": begin
        ptw_mem_delay_range_seq seq = ptw_mem_delay_range_seq::type_id::create(seq_name);
        seq.delay_min = 1;
        seq.delay_max = 1;
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_mem_ooo_rsp_seq": begin
        ptw_mem_ooo_rsp_seq seq = ptw_mem_ooo_rsp_seq::type_id::create(seq_name);
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_mem_slow_rsp_seq": begin
        ptw_mem_slow_rsp_seq seq = ptw_mem_slow_rsp_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_mem_bus_error_inject_seq": begin
        ptw_mem_bus_error_inject_seq seq = ptw_mem_bus_error_inject_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_mem_illegal_pte_seq": begin
        ptw_mem_illegal_pte_seq seq = ptw_mem_illegal_pte_seq::type_id::create(seq_name);
        seq.set_builder(m_env.m_pt_mem.m_builder);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_page_table_build_4k_seq": begin
        ptw_page_table_build_4k_seq seq = ptw_page_table_build_4k_seq::type_id::create(seq_name);
        seq.set_builder(m_env.m_pt_mem.m_builder);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_page_table_build_2m_seq": begin
        ptw_page_table_build_2m_seq seq = ptw_page_table_build_2m_seq::type_id::create(seq_name);
        seq.set_builder(m_env.m_pt_mem.m_builder);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_page_table_build_1g_seq": begin
        ptw_page_table_build_1g_seq seq = ptw_page_table_build_1g_seq::type_id::create(seq_name);
        seq.set_builder(m_env.m_pt_mem.m_builder);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_pte_ad_update_seq": begin
        ptw_pte_ad_update_seq seq = ptw_pte_ad_update_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      "ptw_deep_tree_random_seq": begin
        ptw_deep_tree_random_seq seq = ptw_deep_tree_random_seq::type_id::create(seq_name);
        void'(seq.randomize());
        seq.start(m_env.m_ptw_mem.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown PTW sequence '%s'", seq_name))
    endcase
  endtask

  virtual task run_test_body();
    setup_plan();
    // Leaf wrappers set scenario defaults in setup_plan(); keep +NB_TXNS as the
    // final override for focused debug and short regressions.
    void'($value$plusargs("NB_TXNS=%0d", num_txn));

    if (l1dtlb_directed_vseq::is_l1dtlb_tc(p9_tc_id)) begin
      p9_seq_desc = "l1dtlb_directed_vseq";
      p9_checker = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
      m_enable_sv39_4k_bringup = 1'b0;
    end

    `uvm_info(get_type_name(),
      $sformatf("Phase9 generated test start: tc_id=%s checker=%s reviewer=%s seq=%s",
        p9_tc_id, p9_checker, p9_reviewer, p9_seq_desc),
      UVM_LOW)

    if (l1dtlb_directed_vseq::is_l1dtlb_tc(p9_tc_id)) begin
      if (m_run_misc_init)
        start_misc_seq_by_name("misc_init_seq");
      start_l1dtlb_directed_by_tc_id(p9_tc_id);
      #(m_post_drain);
      return;
    end

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");

    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    foreach (m_cp0_seq_names[i])    start_cp0_seq_by_name(m_cp0_seq_names[i]);
    foreach (m_pmp_seq_names[i])    start_pmp_seq_by_name(m_pmp_seq_names[i]);
    foreach (m_sysmap_seq_names[i]) start_sysmap_seq_by_name(m_sysmap_seq_names[i]);
    foreach (m_misc_seq_names[i])   start_misc_seq_by_name(m_misc_seq_names[i]);
    foreach (m_ptw_seq_names[i])    start_ptw_seq_by_name(m_ptw_seq_names[i]);
    foreach (m_ifu_seq_names[i])    start_ifu_seq_by_name(m_ifu_seq_names[i]);
    foreach (m_lsu_seq_names[i])    start_lsu_seq_by_name(m_lsu_seq_names[i]);
    if (m_wait_lsu_idle_before_vseq && (m_lsu_seq_names.size() > 0)
        && (m_vseq_names.size() > 0)) begin
      m_env.wait_for_quiescent_midtest("phase9_before_vseq", 524288, 16);
    end
    foreach (m_vseq_names[i])       start_vseq_by_name(m_vseq_names[i]);

    #(m_post_drain);
  endtask

endclass : phase9_generated_test_base

`endif // PHASE9_GENERATED_TEST_BASE_SVH
