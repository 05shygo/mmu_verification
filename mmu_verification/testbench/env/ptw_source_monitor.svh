// =============================================================================
// PTW source-side monitor
//
// Stage 3 scope:
//   - Convert read-only DUT probes into source-side actual/probe transactions.
//   - Capture request accept and visible completion by {type,id}.
//   - Treat ptw_l2tlb_cmplt as an OR trigger only; completion class comes from
//     refill/fault-specific signals.
//   - Emit provisional context, level, PDE, and drop events for scenario logging.
//   - Do not implement golden modeling or scoreboard matching in this stage.
// =============================================================================
`ifndef PTW_SOURCE_MONITOR_SVH
`define PTW_SOURCE_MONITOR_SVH

class ptw_source_monitor extends uvm_monitor;

  `uvm_component_utils(ptw_source_monitor)

  mmu_top_cfg m_cfg;
  virtual mmu_dut_probes_if v_probe;

  uvm_analysis_port #(ptw_src_req_accept_txn) ap_req_accept;
  uvm_analysis_port #(ptw_src_actual_rsp_txn) ap_actual_rsp;
  uvm_analysis_port #(ptw_src_abort_txn)      ap_abort;
  uvm_analysis_port #(ptw_src_ctx_sample_txn) ap_ctx;
  uvm_analysis_port #(ptw_src_level_evt_txn)  ap_level;
  uvm_analysis_port #(ptw_src_pde_evt_txn)    ap_pde;
  uvm_analysis_port #(ptw_src_drop_txn)       ap_drop;

  int unsigned m_cycle;
  int unsigned m_req_accept_count;
  int unsigned m_actual_rsp_count;
  int unsigned m_refill_count;
  int unsigned m_page_fault_count;
  int unsigned m_access_fault_count;
  int unsigned m_abort_count;
  int unsigned m_drop_count;
  int unsigned m_ctx_count;
  int unsigned m_level_count;
  int unsigned m_pde_count;
  int unsigned m_pde_pmpflg_update_count;
  int unsigned m_pde_l1_deny_miss_count;
  int unsigned m_pde_direct_accerr_count;
  int unsigned m_gap_late_data_count;
  int unsigned m_gap_abort_bus_error_count;
  int unsigned m_gap_pre_existing_exception_count;
  bit          m_prev_pde_cache_acc_err_vld;

  typedef struct {
    bit                valid;
    ptw_src_req_type_e req_type;
    logic [5:0]        id;
    vpn_t              vpn;
    asid_t             asid;
    int unsigned       cycle;
  } pending_req_s;

  pending_req_s m_pending[string];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_cycle = 0;
    m_req_accept_count = 0;
    m_actual_rsp_count = 0;
    m_refill_count = 0;
    m_page_fault_count = 0;
    m_access_fault_count = 0;
    m_abort_count = 0;
    m_drop_count = 0;
    m_ctx_count = 0;
    m_level_count = 0;
    m_pde_count = 0;
    m_pde_pmpflg_update_count = 0;
    m_pde_l1_deny_miss_count = 0;
    m_pde_direct_accerr_count = 0;
    m_gap_late_data_count = 0;
    m_gap_abort_bus_error_count = 0;
    m_gap_pre_existing_exception_count = 0;
    m_prev_pde_cache_acc_err_vld = 1'b0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    ap_req_accept = new("ap_req_accept", this);
    ap_actual_rsp = new("ap_actual_rsp", this);
    ap_abort      = new("ap_abort",      this);
    ap_ctx        = new("ap_ctx",        this);
    ap_level      = new("ap_level",      this);
    ap_pde        = new("ap_pde",        this);
    ap_drop       = new("ap_drop",       this);

    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(
          this, "", "MMU_DUT_PROBES_VIF", v_probe)) begin
      `uvm_warning(get_type_name(),
        "PTW_SOURCE_CLOSURE component=monitor stage=3 status=created probe=missing provisional=1")
    end else begin
      `uvm_info(get_type_name(),
        "PTW_SOURCE_CLOSURE component=monitor stage=3 status=created probe=available provisional=1",
        UVM_LOW)
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    if (v_probe == null)
      return;

    @(posedge v_probe.clk_i);
    forever begin
      @(v_probe.mon_cb);
      m_cycle++;

      if (v_probe.rst_ni !== 1'b1) begin
        m_prev_pde_cache_acc_err_vld = 1'b0;
        emit_reset_drops();
        continue;
      end

      sample_req_accept();
      sample_context();
      sample_level_events();
      sample_pde_events();
      sample_abort_and_drops();
      sample_completion();
    end
  endtask

  protected function string key_string(input logic [2:0] req_type, input logic [5:0] id);
    return $sformatf("%0h:%0h", req_type, id);
  endfunction

  protected function ptw_src_req_type_e cast_req_type(input logic [2:0] raw_type);
    if (ptw_src_is_legal_req_type(raw_type))
      return ptw_src_req_type_e'(raw_type);
    return PTW_SRC_TYPE_UNKNOWN;
  endfunction

  protected function ptw_src_page_size_e cast_page_size(input logic [2:0] raw_pgs);
    if (ptw_src_is_legal_page_size(raw_pgs))
      return ptw_src_page_size_e'(raw_pgs);
    return PTW_SRC_PGS_NONE;
  endfunction

  protected function ptw_src_level_e level_from_onehot(input logic [2:0] raw_level);
    case (raw_level)
      3'b100: return PTW_SRC_LEVEL_FST;
      3'b010: return PTW_SRC_LEVEL_SCD;
      3'b001: return PTW_SRC_LEVEL_THD;
      default: return PTW_SRC_LEVEL_NONE;
    endcase
  endfunction

  protected function ptw_src_target_kind_e target_from_type(input logic [2:0] req_type);
    case (req_type)
      PTW_SRC_TYPE_FETCH: return PTW_SRC_TARGET_L1I;
      PTW_SRC_TYPE_LOAD,
      PTW_SRC_TYPE_STORE: return PTW_SRC_TARGET_L1D;
      PTW_SRC_TYPE_PFU:   return PTW_SRC_TARGET_PFU;
      default:            return PTW_SRC_TARGET_L2TLB;
    endcase
  endfunction

  protected function bit any_one16(input logic [15:0] vec);
    for (int unsigned i = 0; i < 16; i++) begin
      if (vec[i] === 1'b1)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  protected function logic [3:0] select_pmpflg16(
    input logic [15:0]      sel_vec,
    input logic [15:0][3:0] pmpflg_vec
  );
    logic [3:0] selected;

    selected = 4'h0;
    for (int unsigned i = 0; i < 16; i++) begin
      if (sel_vec[i] === 1'b1)
        selected = pmpflg_vec[i];
    end
    return selected;
  endfunction

  protected function bit effective_machine_for_type(input ptw_src_req_type_e req_type);
    logic [1:0] effective_priv;

    if (req_type == PTW_SRC_TYPE_FETCH)
      effective_priv = v_probe.mon_cb.ptw_cp0_priv_mode;
    else if (v_probe.mon_cb.ptw_cp0_mprv === 1'b1)
      effective_priv = v_probe.mon_cb.ptw_cp0_mpp;
    else
      effective_priv = v_probe.mon_cb.ptw_cp0_priv_mode;

    return (effective_priv == 2'b11);
  endfunction

  protected function void fill_pde_probe_fields(input ptw_src_pde_evt_txn tr);
    bit effective_m;

    tr.l1_tag_hit_vec = v_probe.mon_cb.pde_l1_tag_hit_vec;
    tr.l2_tag_hit_vec = v_probe.mon_cb.pde_l2_tag_hit_vec;
    tr.l2_accerr_vec = v_probe.mon_cb.pde_l2_entry_acc_err_vec;
    tr.l1_tag_hit = any_one16(tr.l1_tag_hit_vec);
    tr.l2_tag_hit = any_one16(tr.l2_tag_hit_vec);

    if (tr.l1_tag_hit)
      tr.cached_l1pmpflg = select_pmpflg16(tr.l1_tag_hit_vec,
        v_probe.mon_cb.pde_l1_cached_l1pmpflg_vec);
    if (tr.l2_tag_hit) begin
      tr.cached_l1pmpflg = select_pmpflg16(tr.l2_tag_hit_vec,
        v_probe.mon_cb.pde_l2_cached_l1pmpflg_vec);
      tr.cached_l2pmpflg = select_pmpflg16(tr.l2_tag_hit_vec,
        v_probe.mon_cb.pde_l2_cached_l2pmpflg_vec);
    end

    effective_m = effective_machine_for_type(tr.req_type);
    if (tr.l1_tag_hit)
      tr.l1_perm_allow = ptw_src_pde_pmp_allow(tr.req_type,
        tr.cached_l1pmpflg, effective_m);
    if (tr.l2_tag_hit) begin
      tr.l2_l1_perm_allow = ptw_src_pde_pmp_allow(tr.req_type,
        tr.cached_l1pmpflg, effective_m);
      tr.l2_l2_perm_allow = ptw_src_pde_pmp_allow(tr.req_type,
        tr.cached_l2pmpflg, effective_m);
      tr.l2_perm_allow = tr.l2_l1_perm_allow && tr.l2_l2_perm_allow;
    end

    tr.direct_accerr = (v_probe.mon_cb.pde_cache_acc_err_vld === 1'b1)
                    || any_one16(tr.l2_accerr_vec);
    if (tr.direct_accerr) begin
      tr.access_src = PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY;
      if (v_probe.mon_cb.pde_cache_acc_err_vld === 1'b1) begin
        tr.accerr_type = cast_req_type(v_probe.mon_cb.pde_cache_acc_err_type);
        tr.accerr_id = v_probe.mon_cb.pde_cache_acc_err_id;
      end else begin
        tr.accerr_type = tr.req_type;
        tr.accerr_id = tr.id;
      end
      tr.accerr_grant = v_probe.mon_cb.pde_cache_acc_err_grant;
      if (tr.l2_tag_hit && !tr.l2_l1_perm_allow && !tr.l2_l2_perm_allow)
        tr.reason = PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY;
      else if (tr.l2_tag_hit && !tr.l2_l1_perm_allow)
        tr.reason = PTW_SRC_PDE_REASON_L2_L1PMP_DENY;
      else if (tr.l2_tag_hit && !tr.l2_l2_perm_allow)
        tr.reason = PTW_SRC_PDE_REASON_L2_L2PMP_DENY;
      else
        tr.reason = PTW_SRC_PDE_REASON_UNMODELED;
    end else if (tr.l1_tag_hit && !tr.l1_hit && !tr.l2_hit && !tr.l1_perm_allow) begin
      tr.reason = PTW_SRC_PDE_REASON_L1_PMP_DENY;
    end else if (!tr.l1_tag_hit && !tr.l2_tag_hit && !tr.l1_hit && !tr.l2_hit) begin
      tr.reason = PTW_SRC_PDE_REASON_L1_TAG_MISS;
    end
  endfunction

  protected function void fill_key_from_pending(
    input ptw_src_drop_txn drop_tr,
    input string key
  );
    if (m_pending.exists(key)) begin
      drop_tr.has_key = 1'b1;
      drop_tr.key.req_type = m_pending[key].req_type;
      drop_tr.key.id = m_pending[key].id;
      drop_tr.vpn = m_pending[key].vpn;
    end
  endfunction

  protected task sample_req_accept();
    if ((v_probe.mon_cb.l2tlb_ptw_req === 1'b1)
        && (v_probe.mon_cb.ptw_jtlb_ready === 1'b1)) begin
      ptw_src_req_accept_txn tr;
      pending_req_s pending;
      string key;

      tr = ptw_src_req_accept_txn::type_id::create("ptw_req_accept");
      tr.req_type = cast_req_type(v_probe.mon_cb.l2tlb_ptw_type);
      tr.id       = v_probe.mon_cb.l2tlb_ptw_id;
      tr.vpn      = v_probe.mon_cb.l2tlb_ptw_vpn;
      tr.asid     = v_probe.mon_cb.regs_ptw_cur_asid;
      tr.cycle    = m_cycle;

      key = key_string(tr.req_type, tr.id);
      pending.valid = 1'b1;
      pending.req_type = tr.req_type;
      pending.id = tr.id;
      pending.vpn = tr.vpn;
      pending.asid = tr.asid;
      pending.cycle = m_cycle;
      m_pending[key] = pending;

      m_req_accept_count++;
      ap_req_accept.write(tr);
      `uvm_info(get_type_name(), {"PTW_REQ_ACCEPT ", tr.convert2string()}, UVM_HIGH)
    end
  endtask

  protected task sample_context();
    if ((v_probe.mon_cb.l2tlb_ptw_req === 1'b1)
        && (v_probe.mon_cb.ptw_jtlb_ready === 1'b1)) begin
      ptw_src_ctx_sample_txn tr;

      tr = ptw_src_ctx_sample_txn::type_id::create("ptw_ctx_sample");
      tr.req_type  = cast_req_type(v_probe.mon_cb.l2tlb_ptw_type);
      tr.id        = v_probe.mon_cb.l2tlb_ptw_id;
      tr.vpn       = v_probe.mon_cb.l2tlb_ptw_vpn;
      tr.asid      = v_probe.mon_cb.regs_ptw_cur_asid;
      tr.satp_ppn  = v_probe.mon_cb.regs_ptw_satp_ppn;
      tr.maee      = v_probe.mon_cb.ptw_cp0_maee;
      tr.mprv      = v_probe.mon_cb.ptw_cp0_mprv;
      tr.mpp       = v_probe.mon_cb.ptw_cp0_mpp;
      tr.mxr       = v_probe.mon_cb.ptw_cp0_mxr;
      tr.sum       = v_probe.mon_cb.ptw_cp0_sum;
      tr.priv_mode = v_probe.mon_cb.ptw_cp0_priv_mode;
      tr.cycle     = m_cycle;

      m_ctx_count++;
      ap_ctx.write(tr);
      `uvm_info(get_type_name(), {"PTW_CTX_SAMPLE ", tr.convert2string()}, UVM_HIGH)
    end
  endtask

  protected task sample_level_events();
    for (int unsigned twu = 0; twu < 4; twu++) begin
      bit event_seen;
      event_seen = (v_probe.mon_cb.ptw_twu_mbuf_req[twu] === 1'b1)
                || (v_probe.mon_cb.ptw_mbuf_twu_data_vld[twu] === 1'b1)
                || (v_probe.mon_cb.ptw_twu_ref_req[twu] === 1'b1)
                || (v_probe.mon_cb.ptw_twu_pgflt_vec[twu] === 1'b1)
                || (v_probe.mon_cb.ptw_twu_acc_err_vec[twu] === 1'b1)
                || (|v_probe.mon_cb.p13_pmp_vld_vec[twu])
                || (|v_probe.mon_cb.p13_pmp_grant_vec[twu])
                || (|v_probe.mon_cb.p13_pmp_deny_vec[twu])
                || (|v_probe.mon_cb.p13_pmp_wait_vec[twu]);

      if (event_seen) begin
        ptw_src_level_evt_txn tr;
        int unsigned lvl_idx;
        logic [2:0] level_vec;

        tr = ptw_src_level_evt_txn::type_id::create("ptw_level_evt");
        tr.cycle = m_cycle;
        tr.twu_idx = twu;
        if (v_probe.mon_cb.ptw_mbuf_twu_data_vld[twu] === 1'b1) begin
          // Data return identity is carried by the selected mbuf entry.  The
          // per-TWU twu_mbuf_* signals can already hold the next memory request.
          tr.req_type = cast_req_type(v_probe.mon_cb.ptw_mbuf_twu_type);
          tr.id = v_probe.mon_cb.ptw_mbuf_twu_id;
          tr.vpn = v_probe.mon_cb.ptw_mbuf_twu_vpn;
          tr.pte_pa = '0;
        end else begin
          tr.req_type = cast_req_type(v_probe.mon_cb.ptw_twu_mbuf_type[twu]);
          tr.id = v_probe.mon_cb.ptw_twu_mbuf_id[twu];
          tr.vpn = v_probe.mon_cb.ptw_twu_mbuf_vpn[twu];
          tr.pte_pa = v_probe.mon_cb.ptw_twu_mbuf_paddr[twu];
        end
        tr.mbuf_req = v_probe.mon_cb.ptw_twu_mbuf_req[twu];
        tr.mbuf_data_vld = v_probe.mon_cb.ptw_mbuf_twu_data_vld[twu];
        tr.refill_req = v_probe.mon_cb.ptw_twu_ref_req[twu];
        tr.page_fault = v_probe.mon_cb.ptw_twu_pgflt_vec[twu];
        tr.access_fault = v_probe.mon_cb.ptw_twu_acc_err_vec[twu];
        tr.pmp_vld = |v_probe.mon_cb.p13_pmp_vld_vec[twu];
        tr.pmp_grant = |v_probe.mon_cb.p13_pmp_grant_vec[twu];
        tr.pmp_deny = |v_probe.mon_cb.p13_pmp_deny_vec[twu];
        tr.pmp_wait = |v_probe.mon_cb.p13_pmp_wait_vec[twu];
        if (tr.pmp_vld || tr.pmp_grant || tr.pmp_deny)
          tr.selected_pmpflg = v_probe.mon_cb.p13_pmp_flg_vec[twu];
        tr.twu_mbuf_pmpflg = v_probe.mon_cb.ptw_twu_mbuf_pmpflg[twu];
        tr.mbuf_pmpflg = v_probe.mon_cb.ptw_mbuf_twu_pmpflg;
        tr.sysmap_hit = |v_probe.mon_cb.p13_sysmap_hit_vec[twu];
        tr.sysmap_flg = v_probe.mon_cb.p13_sysmap_flg_vec[twu];

        if (tr.mbuf_data_vld)
          level_vec = v_probe.mon_cb.ptw_mbuf_twu_lvl_vec;
        else
          level_vec = v_probe.mon_cb.ptw_twu_mbuf_lvl[twu];
        if (level_vec == 3'b000)
          level_vec = v_probe.mon_cb.ptw_mbuf_twu_lvl_vec;
        if ((level_vec == 3'b000) && (|v_probe.mon_cb.p13_pmp_vld_vec[twu]))
          level_vec = v_probe.mon_cb.p13_pmp_vld_vec[twu];
        if ((level_vec == 3'b000) && (|v_probe.mon_cb.p13_pmp_deny_vec[twu]))
          level_vec = v_probe.mon_cb.p13_pmp_deny_vec[twu];
        tr.level = level_from_onehot(level_vec);

        lvl_idx = (tr.level == PTW_SRC_LEVEL_FST) ? 2
                : (tr.level == PTW_SRC_LEVEL_SCD) ? 1
                : (tr.level == PTW_SRC_LEVEL_THD) ? 0
                : 0;
        if (tr.mbuf_data_vld)
          tr.pte_data = v_probe.mon_cb.ptw_mbuf_twu_data;
        if ((tr.req_type == PTW_SRC_TYPE_UNKNOWN)
            && ptw_src_is_legal_req_type(v_probe.mon_cb.p13_pmp_type_vec[twu][lvl_idx]))
          tr.req_type = cast_req_type(v_probe.mon_cb.p13_pmp_type_vec[twu][lvl_idx]);

        m_level_count++;
        ap_level.write(tr);
        `uvm_info(get_type_name(), {"PTW_LEVEL_EVT ", tr.convert2string()}, UVM_HIGH)
      end
    end
  endtask

  protected task sample_pde_events();
    bit direct_accerr_rise;

    direct_accerr_rise = (v_probe.mon_cb.pde_cache_acc_err_vld === 1'b1)
                      && (m_prev_pde_cache_acc_err_vld !== 1'b1);

    if ((v_probe.mon_cb.pde_cache_req === 1'b1)
        && (v_probe.mon_cb.pde_cache_ready === 1'b1)) begin
      ptw_src_pde_evt_txn tr;

      tr = ptw_src_pde_evt_txn::type_id::create("ptw_pde_evt");
      tr.cycle = m_cycle;
      tr.kind = (v_probe.mon_cb.pde_l2_hit_vld || v_probe.mon_cb.pde_l1_hit_vld)
              ? PTW_SRC_PDE_EVT_HIT : PTW_SRC_PDE_EVT_MISS;
      tr.req_type = cast_req_type(v_probe.mon_cb.pde_xbar_type);
      tr.id = v_probe.mon_cb.pde_xbar_id;
      tr.vpn = v_probe.mon_cb.pde_xbar_vpn;
      tr.ppn = v_probe.mon_cb.pde_xbar_ppn;
      tr.l1_hit = v_probe.mon_cb.pde_l1_hit_vld;
      tr.l2_hit = v_probe.mon_cb.pde_l2_hit_vld;
      fill_pde_probe_fields(tr);

      if (tr.reason == PTW_SRC_PDE_REASON_L1_PMP_DENY)
        m_pde_l1_deny_miss_count++;
      m_pde_count++;
      ap_pde.write(tr);
      `uvm_info(get_type_name(), {"PTW_PDE_EVT ", tr.convert2string()}, UVM_HIGH)
    end

    if (v_probe.mon_cb.pde_cache_update === 1'b1) begin
      ptw_src_pde_evt_txn tr;

      tr = ptw_src_pde_evt_txn::type_id::create("ptw_pde_update_evt");
      tr.cycle = m_cycle;
      tr.kind = PTW_SRC_PDE_EVT_UPDATE;
      tr.update = 1'b1;
      tr.update_level = v_probe.mon_cb.pde_cache_update_level;
      tr.update_vpn = v_probe.mon_cb.pde_cache_update_vpn;
      tr.update_ppn = v_probe.mon_cb.pde_cache_update_ppn;
      tr.update_l1pmpflg = v_probe.mon_cb.pde_cache_update_l1pmpflg;
      tr.update_l2pmpflg = v_probe.mon_cb.pde_cache_update_l2pmpflg;
      tr.mbuf_pmpflg = v_probe.mon_cb.ptw_mbuf_twu_pmpflg;
      tr.l1_update_vec = v_probe.mon_cb.pde_l1_update_vec;
      tr.l2_update_vec = v_probe.mon_cb.pde_l2_update_vec;

      m_pde_pmpflg_update_count++;
      m_pde_count++;
      ap_pde.write(tr);
      `uvm_info(get_type_name(), {"PTW_PDE_EVT ", tr.convert2string()}, UVM_HIGH)
    end

    if (v_probe.mon_cb.pde_cache_clear === 1'b1) begin
      ptw_src_pde_evt_txn tr;

      tr = ptw_src_pde_evt_txn::type_id::create("ptw_pde_clear_evt");
      tr.cycle = m_cycle;
      tr.kind = PTW_SRC_PDE_EVT_CLEAR;
      tr.clear = 1'b1;

      m_pde_count++;
      ap_pde.write(tr);
      `uvm_info(get_type_name(), {"PTW_PDE_EVT ", tr.convert2string()}, UVM_HIGH)
    end

    if (direct_accerr_rise) begin
      ptw_src_pde_evt_txn tr;

      tr = ptw_src_pde_evt_txn::type_id::create("ptw_pde_direct_accerr_evt");
      tr.cycle = m_cycle;
      tr.kind = PTW_SRC_PDE_EVT_MISS;
      tr.req_type = cast_req_type(v_probe.mon_cb.pde_cache_acc_err_type);
      tr.id = v_probe.mon_cb.pde_cache_acc_err_id;
      tr.vpn = v_probe.mon_cb.pde_xbar_vpn;
      tr.ppn = v_probe.mon_cb.pde_xbar_ppn;
      tr.l1_hit = v_probe.mon_cb.pde_l1_hit_vld;
      tr.l2_hit = v_probe.mon_cb.pde_l2_hit_vld;
      fill_pde_probe_fields(tr);
      tr.direct_accerr = 1'b1;
      tr.access_src = PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY;
      tr.accerr_type = tr.req_type;
      tr.accerr_id = v_probe.mon_cb.pde_cache_acc_err_id;
      tr.accerr_grant = v_probe.mon_cb.pde_cache_acc_err_grant;

      m_pde_direct_accerr_count++;
      m_pde_count++;
      ap_pde.write(tr);
      `uvm_info(get_type_name(), {"PTW_PDE_EVT ", tr.convert2string()}, UVM_HIGH)
    end

    m_prev_pde_cache_acc_err_vld =
      (v_probe.mon_cb.pde_cache_acc_err_vld === 1'b1);
  endtask

  protected task sample_abort_and_drops();
    if (v_probe.mon_cb.tlboper_ptw_abort === 1'b1) begin
      ptw_src_abort_txn abort_tr;

      abort_tr = ptw_src_abort_txn::type_id::create("ptw_abort");
      abort_tr.drop_reason = PTW_SRC_DROP_ABORT;
      abort_tr.cycle = m_cycle;
      abort_tr.has_key = 1'b0;
      if (v_probe.mon_cb.l2tlb_ptw_req === 1'b1) begin
        abort_tr.key.req_type = cast_req_type(v_probe.mon_cb.l2tlb_ptw_type);
        abort_tr.key.id = v_probe.mon_cb.l2tlb_ptw_id;
        abort_tr.vpn = v_probe.mon_cb.l2tlb_ptw_vpn;
        abort_tr.has_key = 1'b1;
      end

      m_abort_count++;
      ap_abort.write(abort_tr);
      `uvm_info(get_type_name(), {"PTW_ABORT ", abort_tr.convert2string()}, UVM_HIGH)

      emit_drop_for_all_pending(PTW_SRC_DROP_ABORT, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);

      if (v_probe.mon_cb.ptw_lsu_bus_error === 1'b1) begin
        m_gap_abort_bus_error_count++;
        emit_single_drop(
          PTW_SRC_DROP_ABORT_BUS_ERROR,
          key_string(v_probe.mon_cb.ptw_mbuf_twu_type, v_probe.mon_cb.ptw_mbuf_twu_id),
          1'b0, 1'b1, 1'b0, 1'b1, 1'b0);
      end
    end

    if ((v_probe.mon_cb.ptw_abort_flop === 1'b1)
        && ((v_probe.mon_cb.ptw_lsu_data_vld === 1'b1)
            || (v_probe.mon_cb.ptw_lsu_bus_error === 1'b1))) begin
      m_gap_late_data_count++;
      emit_single_drop(
        PTW_SRC_DROP_LATE_DATA,
        key_string(v_probe.mon_cb.ptw_mbuf_twu_type, v_probe.mon_cb.ptw_mbuf_twu_id),
        1'b0, 1'b1, 1'b1, v_probe.mon_cb.ptw_lsu_bus_error, 1'b0);
    end

    if ((v_probe.mon_cb.tlboper_ptw_abort === 1'b1)
        && ((v_probe.mon_cb.ptw_l2tlb_ref_pgflt === 1'b1)
            || (v_probe.mon_cb.ptw_l2tlb_ref_acc_err === 1'b1))) begin
      m_gap_pre_existing_exception_count++;
      emit_single_drop(
        PTW_SRC_DROP_PRE_EXISTING_EXCEPTION_GRANT,
        key_string(v_probe.mon_cb.ptw_l2tlb_type, v_probe.mon_cb.ptw_l2tlb_id),
        1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
    end
  endtask

  protected task sample_completion();
    bit refill_seen;
    bit page_fault_seen;
    bit access_fault_seen;
    bit completion_or_seen;

    completion_or_seen = (v_probe.mon_cb.ptw_l2tlb_cmplt === 1'b1);
    refill_seen = (v_probe.mon_cb.ptw_l2tlb_ref_data_vld === 1'b1)
               && (v_probe.mon_cb.arb_ptw_grant === 1'b1);
    page_fault_seen = (v_probe.mon_cb.ptw_l2tlb_ref_pgflt === 1'b1);
    access_fault_seen = (v_probe.mon_cb.ptw_l2tlb_ref_acc_err === 1'b1);

    if (refill_seen || page_fault_seen || access_fault_seen) begin
      ptw_src_actual_rsp_txn tr;
      ptw_src_refill_tag_s tag;
      ptw_src_refill_data_s data;
      string key;

      tr = ptw_src_actual_rsp_txn::type_id::create("ptw_actual_rsp");
      tr.cycle = m_cycle;
      tr.kind = PTW_SRC_EXP_UNKNOWN;
      tr.req_type = cast_req_type(v_probe.mon_cb.ptw_l2tlb_type);
      tr.id = v_probe.mon_cb.ptw_l2tlb_id;
      tr.vpn = '0;
      tr.asid = '0;
      tr.page_size = PTW_SRC_PGS_NONE;
      tr.ppn = '0;
      tr.global_bit = 1'b0;
      tr.flg = '0;
      tr.raw_tag = v_probe.mon_cb.ptw_arb_ref_tag_din;
      tr.raw_data = v_probe.mon_cb.ptw_arb_ref_data_din;
      tr.completion_or_seen = completion_or_seen;
      tr.refill_valid = refill_seen;
      tr.page_fault = page_fault_seen;
      tr.access_fault = access_fault_seen;
      tr.fault_kind = PTW_SRC_FAULT_NONE;
      tr.target_l2tlb = 1'b1;
      tr.target_l1i = v_probe.mon_cb.ptw_l1i_ref_cmplt;
      tr.target_l1d = v_probe.mon_cb.ptw_l1d_ref_cmplt;
      tr.target_pfu = (tr.req_type == PTW_SRC_TYPE_PFU);
      tr.target = target_from_type(tr.req_type);

      if (refill_seen) begin
        tag = ptw_src_decode_refill_tag(v_probe.mon_cb.ptw_arb_ref_tag_din);
        data = ptw_src_decode_refill_data(v_probe.mon_cb.ptw_arb_ref_data_din);
        tr.kind = PTW_SRC_EXP_REFILL;
        tr.vpn = tag.vpn;
        tr.asid = tag.asid;
        tr.page_size = tag.page_size;
        tr.ppn = data.ppn;
        tr.global_bit = tag.global_bit;
        tr.flg = v_probe.mon_cb.ptw_l2tlb_flg;
        tr.fault_kind = PTW_SRC_FAULT_NONE;
        m_refill_count++;
      end else if (page_fault_seen) begin
        tr.kind = PTW_SRC_EXP_PAGE_FAULT;
        tr.page_size = PTW_SRC_PGS_NONE;
        tr.fault_kind = PTW_SRC_FAULT_PAGE;
        m_page_fault_count++;
      end else begin
        tr.kind = PTW_SRC_EXP_ACCESS_FAULT;
        tr.page_size = PTW_SRC_PGS_NONE;
        tr.fault_kind = PTW_SRC_FAULT_ACCESS;
        m_access_fault_count++;
      end

      key = key_string(tr.req_type, tr.id);
      if (!refill_seen && m_pending.exists(key)) begin
        tr.vpn = m_pending[key].vpn;
        tr.asid = m_pending[key].asid;
      end
      if (m_pending.exists(key))
        m_pending.delete(key);

      m_actual_rsp_count++;
      ap_actual_rsp.write(tr);
      `uvm_info(get_type_name(), {"PTW_ACTUAL_RSP ", tr.convert2string()}, UVM_HIGH)
    end else if (completion_or_seen) begin
      `uvm_warning(get_type_name(),
        $sformatf("PTW_L2TLB_CMPLT_OR_ONLY cycle=%0d type=0x%0h id=0x%02h no class-specific completion bit",
          m_cycle, v_probe.mon_cb.ptw_l2tlb_type, v_probe.mon_cb.ptw_l2tlb_id))
    end
  endtask

  protected task emit_single_drop(
    input ptw_src_drop_reason_e reason,
    input string key,
    input bit reset_drop,
    input bit abort_drop,
    input bit late_data,
    input bit abort_bus_error,
    input bit pre_existing_exception_grant
  );
    ptw_src_drop_txn drop_tr;

    drop_tr = ptw_src_drop_txn::type_id::create("ptw_drop");
    drop_tr.cycle = m_cycle;
    drop_tr.drop_reason = reason;
    drop_tr.reset_drop = reset_drop;
    drop_tr.abort_drop = abort_drop;
    drop_tr.late_data = late_data;
    drop_tr.abort_bus_error = abort_bus_error;
    drop_tr.pre_existing_exception_grant = pre_existing_exception_grant;
    fill_key_from_pending(drop_tr, key);

    m_drop_count++;
    ap_drop.write(drop_tr);
    `uvm_info(get_type_name(), {"PTW_DROP ", drop_tr.convert2string()}, UVM_HIGH)
  endtask

  protected task emit_drop_for_all_pending(
    input ptw_src_drop_reason_e reason,
    input bit reset_drop,
    input bit abort_drop,
    input bit late_data,
    input bit abort_bus_error,
    input bit pre_existing_exception_grant
  );
    string key;
    string keys[$];

    foreach (m_pending[key])
      keys.push_back(key);

    foreach (keys[i]) begin
      emit_single_drop(reason, keys[i], reset_drop, abort_drop, late_data,
        abort_bus_error, pre_existing_exception_grant);
      m_pending.delete(keys[i]);
    end
  endtask

  protected task emit_reset_drops();
    if (m_pending.num() != 0)
      emit_drop_for_all_pending(PTW_SRC_DROP_RESET, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
  endtask

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf({"PTW_SOURCE_MONITOR_SUMMARY stage=3 req_accept=%0d actual_rsp=%0d ",
                 "refill=%0d page_fault=%0d access_fault=%0d abort=%0d drop=%0d ",
                 "ctx=%0d level=%0d pde=%0d pending=%0d gap_late_data=%0d ",
                 "pde_pmpflg_update=%0d pde_l1_deny_miss=%0d ",
                 "pde_direct_accerr=%0d gap_abort_bus_error=%0d ",
                 "gap_pre_existing_exception=%0d provisional=1"},
        m_req_accept_count, m_actual_rsp_count, m_refill_count,
        m_page_fault_count, m_access_fault_count, m_abort_count, m_drop_count,
        m_ctx_count, m_level_count, m_pde_count, m_pending.num(),
        m_gap_late_data_count, m_pde_pmpflg_update_count,
        m_pde_l1_deny_miss_count, m_pde_direct_accerr_count,
        m_gap_abort_bus_error_count,
        m_gap_pre_existing_exception_count),
      UVM_NONE)

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=monitor stage=3 status=provisional actual_probe_only=1",
      UVM_NONE)
  endfunction

endclass : ptw_source_monitor

`endif // PTW_SOURCE_MONITOR_SVH
