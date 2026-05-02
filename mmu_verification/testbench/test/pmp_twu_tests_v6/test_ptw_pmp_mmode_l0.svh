`ifndef TEST_PTW_PMP_MMODE_L0_SVH
`define TEST_PTW_PMP_MMODE_L0_SVH

class test_ptw_pmp_mmode_l0 extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_mmode_l0)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-MMODE-L0-001";
    p12_fid = "F7.NEW.5"; p12_priority = "P1";
    p12_seq_desc = "PTW PMP X/W deny plus MPRV M-mode L=0 bypass";
    p12_checker = "cp_pmp_fetch_uses_x_perm + cp_pmp_store_uses_w_perm + cp_pmp_mmode_l0_bypass";
    p12_reviewer = "A+B";
    num_txn = 192; m_post_drain = 1200ns;
  endfunction

  protected virtual task set_phase13_ptw_pmp_flg(input bit [3:0] ptw_flg);
    bit [3:0] raw_flg[8];
    foreach (raw_flg[i]) raw_flg[i] = 4'h7;
    raw_flg[3] = ptw_flg;
    raw_flg[5] = ptw_flg;
    raw_flg[6] = ptw_flg;
    raw_flg[7] = ptw_flg;
    phase12_set_pmp_raw(raw_flg);
  endtask

  protected virtual task set_phase13_priv_s();
    cp0_priv_switch_seq seq;
    seq = cp0_priv_switch_seq::type_id::create("phase13_priv_s_seq");
    seq.priv_mode = 2'b01;
    seq.start(m_env.m_cp0.m_sequencer);
    #80ns;
  endtask

  protected virtual task set_phase13_mprv_m(input bit enable);
    cp0_mprv_seq seq;
    seq = cp0_mprv_seq::type_id::create("phase13_mprv_m_seq");
    seq.mprv_val = enable;
    seq.mpp_val  = 2'b11;
    seq.start(m_env.m_cp0.m_sequencer);
    #80ns;
  endtask

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();

    set_phase13_priv_s();
    set_phase13_mprv_m(1'b0);
    phase12_map_4k_window(39'h0_E200_0000, 96, 40'h0_B000_0000);
    phase12_map_4k_window(39'h0_E300_0000, 96, 40'h0_B100_0000);
    phase12_map_4k_window(39'h0_E400_0000, 96, 40'h0_B200_0000);

    // X=0, R/W=1: fetch-originated PTW PMP denies.
    set_phase13_ptw_pmp_flg(4'h3);
    phase12_cp0_tlb_allinv();
    phase12_drive_ifu_rr(39'h0_E200_0000, 96, 160, 1'b1);

    // W=0, R/X=1: store-originated PTW PMP denies.
    set_phase13_priv_s();
    set_phase13_mprv_m(1'b0);
    set_phase13_ptw_pmp_flg(4'h5);
    phase12_cp0_tlb_allinv();
    phase12_drive_lsu_rr(39'h0_E300_0000, 96, 160, LSU_PIPE1, 1'b1, 1'b1);

    // R=0 with L=0 while effective privilege is M: deny condition is present,
    // but M-mode L0 bypass must suppress the deny.
    set_phase13_priv_s();
    set_phase13_mprv_m(1'b1);
    set_phase13_ptw_pmp_flg(4'h6);
    phase12_cp0_tlb_allinv();
    phase12_drive_lsu_rr(39'h0_E400_0000, 96, 192, LSU_PIPE0, 1'b0, 1'b1);

    set_phase13_mprv_m(1'b0);
    phase12_set_pmp_allow_all();
    #(m_post_drain);
  endtask
endclass

`endif
