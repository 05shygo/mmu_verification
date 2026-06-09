// =============================================================================
// Directed reset-mid-TLBOP FSM coverage.
// The target operation is intentionally allowed to be reset-dropped; recovery is
// checked by reinitializing the MMU and running a normal exact TLBP transaction.
// =============================================================================
`ifndef TEST_MMU_TLBOP_RESET_MID_FSM_SVH
`define TEST_MMU_TLBOP_RESET_MID_FSM_SVH

class tlbop_reset_mid_fsm_base extends phase9_generated_test_base;

  string m_target_kind;
  virtual mmu_dut_probes_if m_reset_probe_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-TLBOP-RESET-MID-FSM";
    p9_seq_desc = "reset-target TLBOP + post-reset exact TLBP recovery";
    p9_checker = "tlbop_lifecycle_sva,l2tlb_tlbop_decode,invalidation_sb,reset recovery";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_target_kind = "tlbp";
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 1000ns;
    if (m_reset_probe_vif == null)
      void'(uvm_config_db#(virtual mmu_dut_probes_if)::get(
        this, "", "MMU_DUT_PROBES_VIF", m_reset_probe_vif));
  endfunction

  protected task wait_reset_inject_done();
    string mode;
    int unsigned max_cycles;

    if (!$value$plusargs("MMU_TLBOP_RESET_MODE=%s", mode))
      return;

    if (m_reset_probe_vif == null)
      `uvm_fatal(get_type_name(),
        "MMU_DUT_PROBES_VIF unavailable; cannot synchronize TLBOP reset injection")

    max_cycles = 200500;
    void'($value$plusargs("MMU_TLBOP_RESET_TIMEOUT_CYCLES=%0d", max_cycles));
    max_cycles += 16;

    for (int unsigned cyc = 0; cyc < max_cycles; cyc++) begin
      @(m_reset_probe_vif.mon_cb);
      if (m_reset_probe_vif.tlbop_reset_inject_done === 1'b1) begin
        if (m_reset_probe_vif.tlbop_reset_inject_hit !== 1'b1)
          `uvm_fatal(get_type_name(),
            $sformatf("TLBOP reset injector completed without hit: mode=%s", mode))
        wait (m_reset_probe_vif.rst_ni === 1'b1);
        repeat (4) @(m_reset_probe_vif.mon_cb);
        `uvm_info(get_type_name(),
          $sformatf("TLBOP reset injector synchronized: mode=%s wait_cycles=%0d", mode, cyc),
          UVM_LOW)
        return;
      end
    end

    `uvm_fatal(get_type_name(),
      $sformatf("Timed out waiting for TLBOP reset injector done: mode=%s max_cycles=%0d",
        mode, max_cycles))
  endtask

  protected task run_invva_reset_target();
    cp0_l2tlb_inv_asid_directed_probe_seq cp0_probe;
    mmu_vseq_lsu_fixed_inv_va_seq lsu_inv;

    cp0_probe = cp0_l2tlb_inv_asid_directed_probe_seq::type_id::create("invva_reset_setup");
    cp0_probe.do_write = 1'b1;
    cp0_probe.global_entry = 1'b0;
    cp0_probe.expect_hit = 1'b1;
    cp0_probe.start(m_env.m_cp0.m_sequencer);

    lsu_inv = mmu_vseq_lsu_fixed_inv_va_seq::type_id::create("invva_reset_target");
    lsu_inv.m_inv_va = 27'h000423;
    lsu_inv.m_inv_asid = 16'h1234;
    lsu_inv.m_allow_busy = 1'b0;
    lsu_inv.start(m_env.m_lsu.m_sequencer);
  endtask

  protected task run_invasid_reset_target();
    cp0_l2tlb_inv_asid_directed_probe_seq cp0_probe;
    mmu_vseq_lsu_fixed_inv_asid_seq lsu_inv;

    cp0_probe = cp0_l2tlb_inv_asid_directed_probe_seq::type_id::create("invasid_reset_setup");
    cp0_probe.do_write = 1'b1;
    cp0_probe.global_entry = 1'b0;
    cp0_probe.expect_hit = 1'b1;
    cp0_probe.start(m_env.m_cp0.m_sequencer);

    lsu_inv = mmu_vseq_lsu_fixed_inv_asid_seq::type_id::create("invasid_reset_target");
    lsu_inv.m_inv_asid = 16'h1234;
    lsu_inv.m_allow_busy = 1'b0;
    lsu_inv.start(m_env.m_lsu.m_sequencer);
  endtask

  protected task run_reset_target_op();
    case (m_target_kind)
      "tlbp":    start_cp0_seq_by_name("cp0_l2tlb_tlbp_reset_target_seq");
      "tlbr":    start_cp0_seq_by_name("cp0_l2tlb_tlbr_reset_target_seq");
      "tlbwi":   start_cp0_seq_by_name("cp0_l2tlb_tlbwi_reset_target_seq");
      "tlbwr":   start_cp0_seq_by_name("cp0_l2tlb_tlbwr_reset_target_seq");
      "invva":   run_invva_reset_target();
      "invasid": run_invasid_reset_target();
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unknown TLBOP reset target kind '%s'", m_target_kind))
    endcase
  endtask

  virtual task run_test_body();
    setup_plan();
    void'($value$plusargs("NB_TXNS=%0d", num_txn));

    `uvm_info(get_type_name(),
      $sformatf("TLBOP reset-mid-FSM start: target_kind=%s tc_id=%s checker=%s",
        m_target_kind, p9_tc_id, p9_checker),
      UVM_LOW)

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    run_reset_target_op();
    wait_reset_inject_done();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_l2tlb_tlbp_hit_exact_seq");

    #(m_post_drain);
  endtask

endclass : tlbop_reset_mid_fsm_base

class test_mmu_tlbop_reset_tlbp_wfg extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_tlbp_wfg)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "tlbp";
    p9_tc_id = "TC-TLBOP-RESET-TLBP-WFG";
  endfunction
endclass : test_mmu_tlbop_reset_tlbp_wfg

class test_mmu_tlbop_reset_tlbr_wfg extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_tlbr_wfg)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "tlbr";
    p9_tc_id = "TC-TLBOP-RESET-TLBR-WFG";
  endfunction
endclass : test_mmu_tlbop_reset_tlbr_wfg

class test_mmu_tlbop_reset_tlbwi_wfg extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_tlbwi_wfg)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "tlbwi";
    p9_tc_id = "TC-TLBOP-RESET-TLBWI-WFG";
  endfunction
endclass : test_mmu_tlbop_reset_tlbwi_wfg

class test_mmu_tlbop_reset_tlbwr_wfg extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_tlbwr_wfg)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "tlbwr";
    p9_tc_id = "TC-TLBOP-RESET-TLBWR-WFG";
  endfunction
endclass : test_mmu_tlbop_reset_tlbwr_wfg

class test_mmu_tlbop_reset_tlbwr_wrtag extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_tlbwr_wrtag)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "tlbwr";
    p9_tc_id = "TC-TLBOP-RESET-TLBWR-WRTAG";
  endfunction
endclass : test_mmu_tlbop_reset_tlbwr_wrtag

class test_mmu_tlbop_reset_invasid_rd extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invasid_rd)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invasid";
    p9_tc_id = "TC-TLBOP-RESET-INVASID-RD";
  endfunction
endclass : test_mmu_tlbop_reset_invasid_rd

class test_mmu_tlbop_reset_invasid_wfc extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invasid_wfc)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invasid";
    p9_tc_id = "TC-TLBOP-RESET-INVASID-WFC";
  endfunction
endclass : test_mmu_tlbop_reset_invasid_wfc

class test_mmu_tlbop_reset_invasid_wt extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invasid_wt)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invasid";
    p9_tc_id = "TC-TLBOP-RESET-INVASID-WT";
  endfunction
endclass : test_mmu_tlbop_reset_invasid_wt

class test_mmu_tlbop_reset_invva_rd extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invva_rd)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invva";
    p9_tc_id = "TC-TLBOP-RESET-INVVA-RD";
  endfunction
endclass : test_mmu_tlbop_reset_invva_rd

class test_mmu_tlbop_reset_invva_cmp extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invva_cmp)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invva";
    p9_tc_id = "TC-TLBOP-RESET-INVVA-CMP";
  endfunction
endclass : test_mmu_tlbop_reset_invva_cmp

class test_mmu_tlbop_reset_invva_wr extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invva_wr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invva";
    p9_tc_id = "TC-TLBOP-RESET-INVVA-WR";
  endfunction
endclass : test_mmu_tlbop_reset_invva_wr

class test_mmu_tlbop_reset_invva_wt extends tlbop_reset_mid_fsm_base;
  `uvm_component_utils(test_mmu_tlbop_reset_invva_wt)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    m_target_kind = "invva";
    p9_tc_id = "TC-TLBOP-RESET-INVVA-WT";
  endfunction
endclass : test_mmu_tlbop_reset_invva_wt

`endif // TEST_MMU_TLBOP_RESET_MID_FSM_SVH
