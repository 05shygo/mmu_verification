// =============================================================================
// L2TLB Phase 6E directed/negative test base.
//
// This base adds auditable scenario metadata and trigger/checker gates around
// the existing Phase 9 generated-test execution skeleton.  It does not drive
// L2TLB internals directly; stimulus still comes from legal UVM agents/vseqs.
// =============================================================================
`ifndef L2TLB_PHASE6E_TEST_BASE_SVH
`define L2TLB_PHASE6E_TEST_BASE_SVH

class l2tlb_phase6e_test_base extends phase9_generated_test_base;

  `uvm_component_utils(l2tlb_phase6e_test_base)

  string phase6e_scenario_id;
  string phase6e_audit_ids;
  string phase6e_kind;
  string phase6e_trigger_gate;
  string phase6e_checker_gate;
  string phase6e_expected_log_token;
  string phase6e_waiver_policy;
  string phase6e_run_tier;
  string phase6f_class;
  string phase6f_future_exact_items;

  virtual l2tlb_negative_inject_if phase6e_neg_vif;

  bit phase6e_require_trigger_gate;
  bit phase6e_require_checker_gate;
  bit phase6e_is_negative;
  bit phase6e_is_debug;
  bit phase6e_is_future_or_waiver;

  int unsigned phase6e_trigger_count;
  int unsigned phase6e_checker_count;
  int unsigned phase6e_waiver_count;

  bit              phase6e_shadow_baseline_valid;
  longint unsigned phase6e_base_ptw_req_seen;
  longint unsigned phase6e_base_ptw_data_seen;
  longint unsigned phase6e_base_ptw_fault_seen;
  longint unsigned phase6e_base_l2_hit_seen;
  longint unsigned phase6e_base_l2_miss_seen;
  longint unsigned phase6e_base_pfu_seen;
  longint unsigned phase6e_base_pfu_payload_ignore_seen;
  longint unsigned phase6e_base_inv_seen;
  longint unsigned phase6e_base_cp0_all_inv_seen;
  longint unsigned phase6e_base_reset_epoch_count;
  longint unsigned phase6e_base_abort_epoch_count;
  longint unsigned phase6e_base_control_epoch_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(virtual l2tlb_negative_inject_if)::get(
      this, "", "L2TLB_NEG_INJECT_VIF", phase6e_neg_vif));
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                    = "L2TLB-P6E-UNSPECIFIED";
    p9_seq_desc                 = "phase6e_unspecified";
    p9_checker                  = "phase6c_l2_shadow,phase6d_sva,log_gate";
    p9_reviewer                 = "Phase6E";
    phase6e_scenario_id         = "L2TLB_SCN_PHASE6E_UNSPECIFIED";
    phase6e_audit_ids           = "";
    phase6e_kind                = "positive";
    phase6e_trigger_gate        = "unset";
    phase6e_checker_gate        = "unset";
    phase6e_expected_log_token  = "";
    phase6e_waiver_policy       = "no waiver";
    phase6e_run_tier            = "l2tlb_directed_p0";
    phase6f_class                = "";
    phase6f_future_exact_items   = "";
    phase6e_require_trigger_gate = 1'b0;
    phase6e_require_checker_gate = 1'b0;
    phase6e_is_negative          = 1'b0;
    phase6e_is_debug             = 1'b0;
    phase6e_is_future_or_waiver  = 1'b0;
    phase6e_trigger_count        = 0;
    phase6e_checker_count        = 0;
    phase6e_waiver_count         = 0;
    phase6e_shadow_baseline_valid = 1'b0;
    phase6e_base_ptw_req_seen = 0;
    phase6e_base_ptw_data_seen = 0;
    phase6e_base_ptw_fault_seen = 0;
    phase6e_base_l2_hit_seen = 0;
    phase6e_base_l2_miss_seen = 0;
    phase6e_base_pfu_seen = 0;
    phase6e_base_pfu_payload_ignore_seen = 0;
    phase6e_base_inv_seen = 0;
    phase6e_base_cp0_all_inv_seen = 0;
    phase6e_base_reset_epoch_count = 0;
    phase6e_base_abort_epoch_count = 0;
    phase6e_base_control_epoch_count = 0;
  endfunction

  protected function int unsigned phase6e_plan_item_count();
    return m_vseq_names.size() + m_ifu_seq_names.size() + m_lsu_seq_names.size() +
           m_cp0_seq_names.size() + m_pmp_seq_names.size() + m_sysmap_seq_names.size() +
           m_misc_seq_names.size() + m_ptw_seq_names.size();
  endfunction

  protected function string phase6e_bool_name(bit value);
    return value ? "1" : "0";
  endfunction

  protected function longint unsigned phase6e_pos_delta(
    longint unsigned now_value,
    longint unsigned base_value
  );
    if (now_value >= base_value)
      return now_value - base_value;
    // Some reset tests intentionally reset the Phase6C shadow helper.
    return now_value;
  endfunction

  protected virtual function string phase6e_shadow_summary();
    if ((m_env != null) && (m_env.m_l2tlb_shadow != null))
      return m_env.m_l2tlb_shadow.summary();
    return "l2tlb_shadow_unavailable";
  endfunction

  protected virtual function void phase6e_capture_shadow_baseline();
    phase6e_shadow_baseline_valid = 1'b0;
    if ((m_env == null) || (m_env.m_l2tlb_shadow == null)) begin
      $display("[L2TLB_PHASE6E_SHADOW_BASE] test=%s scenario_id=%s status=unavailable",
        get_type_name(), phase6e_scenario_id);
      return;
    end

    phase6e_base_ptw_req_seen = m_env.m_l2tlb_shadow.m_ptw_req_seen;
    phase6e_base_ptw_data_seen = m_env.m_l2tlb_shadow.m_ptw_data_seen;
    phase6e_base_ptw_fault_seen = m_env.m_l2tlb_shadow.m_ptw_fault_seen;
    phase6e_base_l2_hit_seen = m_env.m_l2tlb_shadow.m_l2_hit_seen;
    phase6e_base_l2_miss_seen = m_env.m_l2tlb_shadow.m_l2_miss_seen;
    phase6e_base_pfu_seen = m_env.m_l2tlb_shadow.m_pfu_seen;
    phase6e_base_pfu_payload_ignore_seen = m_env.m_l2tlb_shadow.m_pfu_payload_ignore_seen;
    phase6e_base_inv_seen = m_env.m_l2tlb_shadow.m_inv_seen;
    phase6e_base_cp0_all_inv_seen = m_env.m_l2tlb_shadow.m_cp0_all_inv_seen;
    phase6e_base_reset_epoch_count = m_env.m_l2tlb_shadow.m_reset_epoch_count;
    phase6e_base_abort_epoch_count = m_env.m_l2tlb_shadow.m_abort_epoch_count;
    phase6e_base_control_epoch_count = m_env.m_l2tlb_shadow.m_control_epoch_count;
    phase6e_shadow_baseline_valid = 1'b1;

    $display("[L2TLB_PHASE6E_SHADOW_BASE] test=%s scenario_id=%s summary=\"%s\"",
      get_type_name(), phase6e_scenario_id, phase6e_shadow_summary());
  endfunction

  protected virtual function void phase6e_note_observed_shadow_trigger();
    longint unsigned d_ptw_req;
    longint unsigned d_ptw_data;
    longint unsigned d_ptw_fault;
    longint unsigned d_l2_hit;
    longint unsigned d_l2_miss;
    longint unsigned d_pfu;
    longint unsigned d_payload_ignore;
    longint unsigned d_inv;
    longint unsigned d_cp0_all_inv;
    longint unsigned d_reset_epoch;
    longint unsigned d_abort_epoch;
    longint unsigned d_control_epoch;
    longint unsigned activity;

    if (!phase6e_shadow_baseline_valid || (m_env == null) ||
        (m_env.m_l2tlb_shadow == null)) begin
      $display("[L2TLB_PHASE6E_SHADOW_DELTA] test=%s scenario_id=%s status=unavailable",
        get_type_name(), phase6e_scenario_id);
      return;
    end

    d_ptw_req = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_ptw_req_seen,
      phase6e_base_ptw_req_seen);
    d_ptw_data = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_ptw_data_seen,
      phase6e_base_ptw_data_seen);
    d_ptw_fault = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_ptw_fault_seen,
      phase6e_base_ptw_fault_seen);
    d_l2_hit = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_l2_hit_seen,
      phase6e_base_l2_hit_seen);
    d_l2_miss = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_l2_miss_seen,
      phase6e_base_l2_miss_seen);
    d_pfu = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_pfu_seen,
      phase6e_base_pfu_seen);
    d_payload_ignore = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_pfu_payload_ignore_seen,
      phase6e_base_pfu_payload_ignore_seen);
    d_inv = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_inv_seen,
      phase6e_base_inv_seen);
    d_cp0_all_inv = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_cp0_all_inv_seen,
      phase6e_base_cp0_all_inv_seen);
    d_reset_epoch = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_reset_epoch_count,
      phase6e_base_reset_epoch_count);
    d_abort_epoch = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_abort_epoch_count,
      phase6e_base_abort_epoch_count);
    d_control_epoch = phase6e_pos_delta(m_env.m_l2tlb_shadow.m_control_epoch_count,
      phase6e_base_control_epoch_count);

    activity = d_ptw_req + d_ptw_data + d_ptw_fault + d_l2_hit + d_l2_miss +
               d_pfu + d_payload_ignore + d_inv + d_cp0_all_inv +
               d_reset_epoch + d_abort_epoch + d_control_epoch;

    $display("[L2TLB_PHASE6E_SHADOW_DELTA] test=%s scenario_id=%s ptw_req=%0d ptw_data=%0d ptw_fault=%0d l2_hit=%0d l2_miss=%0d pfu=%0d payload_ignore=%0d inv=%0d cp0_all_inv=%0d reset_epoch=%0d abort_epoch=%0d control_epoch=%0d activity=%0d",
      get_type_name(), phase6e_scenario_id, d_ptw_req, d_ptw_data,
      d_ptw_fault, d_l2_hit, d_l2_miss, d_pfu, d_payload_ignore, d_inv,
      d_cp0_all_inv, d_reset_epoch, d_abort_epoch, d_control_epoch,
      activity);

    if (activity != 0) begin
      phase6e_note_trigger($sformatf(
        "shadow_delta ptw_req=%0d ptw_data=%0d ptw_fault=%0d l2_hit=%0d l2_miss=%0d pfu=%0d payload_ignore=%0d inv=%0d cp0_all_inv=%0d reset_epoch=%0d abort_epoch=%0d control_epoch=%0d",
        d_ptw_req, d_ptw_data, d_ptw_fault, d_l2_hit, d_l2_miss, d_pfu,
        d_payload_ignore, d_inv, d_cp0_all_inv, d_reset_epoch,
        d_abort_epoch, d_control_epoch));
    end
  endfunction

  protected virtual function void phase6e_emit_meta();
    $display("[L2TLB_PHASE6E_META] test=%s scenario_id=%s audit_ids=\"%s\" kind=%s tier=%s trigger_gate=\"%s\" checker_gate=\"%s\" expected_log_token=\"%s\" waiver_policy=\"%s\" require_trigger=%s require_checker=%s",
      get_type_name(), phase6e_scenario_id, phase6e_audit_ids, phase6e_kind,
      phase6e_run_tier, phase6e_trigger_gate, phase6e_checker_gate,
      phase6e_expected_log_token, phase6e_waiver_policy,
      phase6e_bool_name(phase6e_require_trigger_gate),
      phase6e_bool_name(phase6e_require_checker_gate));
    if (phase6f_class != "") begin
      $display("[L2TLB_PHASE6F_META] test=%s scenario_id=%s audit_ids=\"%s\" phase6f_class=\"%s\" future_exact_items=\"%s\"",
        get_type_name(), phase6e_scenario_id, phase6e_audit_ids,
        phase6f_class, phase6f_future_exact_items);
    end
  endfunction

  protected virtual function void phase6e_note_trigger(string evidence);
    phase6e_trigger_count++;
    $display("[L2TLB_PHASE6E_TRIGGER] test=%s scenario_id=%s count=%0d gate=\"%s\" evidence=\"%s\"",
      get_type_name(), phase6e_scenario_id, phase6e_trigger_count,
      phase6e_trigger_gate, evidence);
  endfunction

  protected virtual function void phase6e_note_checker(string evidence);
    phase6e_checker_count++;
    $display("[L2TLB_PHASE6E_CHECKER] test=%s scenario_id=%s count=%0d gate=\"%s\" evidence=\"%s\"",
      get_type_name(), phase6e_scenario_id, phase6e_checker_count,
      phase6e_checker_gate, evidence);
  endfunction

  protected virtual function void phase6e_note_waiver(string reason);
    phase6e_waiver_count++;
    phase6e_is_future_or_waiver = 1'b1;
    $display("[L2TLB_PHASE6E_WAIVER] test=%s scenario_id=%s count=%0d audit_ids=\"%s\" reason=\"%s\" policy=\"%s\"",
      get_type_name(), phase6e_scenario_id, phase6e_waiver_count,
      phase6e_audit_ids, reason, phase6e_waiver_policy);
  endfunction

  protected virtual task phase6e_inject_ptw_negative(
    input l2tlb_neg_kind_e kind,
    input string case_name,
    input string expected_class,
    input bit [6:0] id,
    input bit [2:0] typ,
    input bit data_vld,
    input bit pgflt,
    input bit acc_err,
    input bit [13:0] flg = 14'h0000
  );
    if (phase6e_neg_vif == null)
      `uvm_fatal(get_type_name(), "L2TLB_NEG_INJECT_VIF unavailable")

    phase6e_neg_vif.inject_ptw_completion(
      kind,
      case_name,
      phase6e_audit_ids,
      expected_class,
      id,
      typ,
      data_vld,
      pgflt,
      acc_err,
      flg,
      1);

    if (!phase6e_neg_vif.trigger_seen)
      `uvm_error(get_type_name(),
        $sformatf("L2TLB negative trigger missing for %s: %s",
          case_name, phase6e_neg_vif.observed_msg))
    if (!phase6e_neg_vif.checker_seen)
      `uvm_error(get_type_name(),
        $sformatf("L2TLB negative checker missing for %s: %s",
          case_name, phase6e_neg_vif.observed_msg))

    phase6e_note_trigger($sformatf("negative_injector case=%s class=%s msg=%s",
      case_name, expected_class, phase6e_neg_vif.observed_msg));
    phase6e_note_checker($sformatf("expected negative classification case=%s class=%s",
      case_name, expected_class));
  endtask

  protected virtual task phase6e_inject_control_hazard_negative(
    input string case_name,
    input string expected_class
  );
    if (phase6e_neg_vif == null)
      `uvm_fatal(get_type_name(), "L2TLB_NEG_INJECT_VIF unavailable")

    phase6e_neg_vif.inject_control_hazard(
      case_name,
      phase6e_audit_ids,
      expected_class,
      1);

    if (!phase6e_neg_vif.trigger_seen)
      `uvm_error(get_type_name(),
        $sformatf("L2TLB control-hazard trigger missing for %s: %s",
          case_name, phase6e_neg_vif.observed_msg))
    if (!phase6e_neg_vif.checker_seen)
      `uvm_error(get_type_name(),
        $sformatf("L2TLB control-hazard checker missing for %s: %s",
          case_name, phase6e_neg_vif.observed_msg))

    phase6e_note_trigger($sformatf("negative_injector case=%s class=%s msg=%s",
      case_name, expected_class, phase6e_neg_vif.observed_msg));
    phase6e_note_checker($sformatf("expected negative classification case=%s class=%s",
      case_name, expected_class));
  endtask

  protected virtual task phase6e_pre_stimulus();
    $display("[L2TLB_PHASE6E_PLAN] test=%s scenario_id=%s plan_items=%0d sv39_bringup=%0b",
      get_type_name(), phase6e_scenario_id, phase6e_plan_item_count(),
      m_enable_sv39_4k_bringup);
    phase6e_capture_shadow_baseline();
  endtask

  protected virtual task phase6e_post_stimulus();
    phase6e_note_observed_shadow_trigger();
    phase6e_note_checker($sformatf("stimulus_completed expected_log_token=%s shadow_summary=\"%s\"",
      phase6e_expected_log_token, phase6e_shadow_summary()));
  endtask

  protected virtual function void phase6e_check_gates();
    if (phase6e_require_trigger_gate && phase6e_trigger_count == 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Phase6E trigger gate not observed: scenario_id=%s audit_ids=%s gate=%s",
          phase6e_scenario_id, phase6e_audit_ids, phase6e_trigger_gate))
    end

    if (phase6e_require_checker_gate && phase6e_checker_count == 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Phase6E checker gate not observed: scenario_id=%s audit_ids=%s gate=%s",
          phase6e_scenario_id, phase6e_audit_ids, phase6e_checker_gate))
    end

    $display("[L2TLB_PHASE6E_CLOSE] test=%s scenario_id=%s audit_ids=\"%s\" kind=%s tier=%s trigger_count=%0d checker_count=%0d waiver_count=%0d future_or_waiver=%0b",
      get_type_name(), phase6e_scenario_id, phase6e_audit_ids, phase6e_kind,
      phase6e_run_tier, phase6e_trigger_count, phase6e_checker_count,
      phase6e_waiver_count, phase6e_is_future_or_waiver);
    if (phase6f_class != "") begin
      $display("[L2TLB_PHASE6F_CLOSE] test=%s scenario_id=%s phase6f_class=\"%s\" trigger_count=%0d checker_count=%0d future_exact_items=\"%s\"",
        get_type_name(), phase6e_scenario_id, phase6f_class,
        phase6e_trigger_count, phase6e_checker_count,
        phase6f_future_exact_items);
    end
  endfunction

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");

    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase6e_pre_stimulus();

    foreach (m_cp0_seq_names[i])    start_cp0_seq_by_name(m_cp0_seq_names[i]);
    foreach (m_pmp_seq_names[i])    start_pmp_seq_by_name(m_pmp_seq_names[i]);
    foreach (m_sysmap_seq_names[i]) start_sysmap_seq_by_name(m_sysmap_seq_names[i]);
    foreach (m_misc_seq_names[i])   start_misc_seq_by_name(m_misc_seq_names[i]);
    foreach (m_ptw_seq_names[i])    start_ptw_seq_by_name(m_ptw_seq_names[i]);
    foreach (m_ifu_seq_names[i])    start_ifu_seq_by_name(m_ifu_seq_names[i]);
    foreach (m_lsu_seq_names[i])    start_lsu_seq_by_name(m_lsu_seq_names[i]);
    foreach (m_vseq_names[i])       start_vseq_by_name(m_vseq_names[i]);

    #(m_post_drain);
    phase6e_post_stimulus();
    phase6e_check_gates();
  endtask

endclass : l2tlb_phase6e_test_base

`endif // L2TLB_PHASE6E_TEST_BASE_SVH
