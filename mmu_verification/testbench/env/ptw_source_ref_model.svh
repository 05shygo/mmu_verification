// =============================================================================
// PTW source-side reference model
//
// Stage 4 scope:
//   - Generate source-side expected transactions from PTW source monitor events.
//   - Model request accept, context samples, raw PTE decode, PMP/access fault,
//     page fault, refill tag/data/flg, MAEE=1, MAEE=0 4K sysmap, and basic
//     reset/abort/late-data drops.
//   - Track PDE cache events with an abstract model for later tests/debug.
//   - Do not call the shared translation reference-model API; this model is
//     event-driven from PTW source probes and memory monitor evidence.
//
// Stage 7 scope:
//   - Use current CSR samples for CHK/refill-time fields such as ASID, MXR/SUM,
//     effective privilege, and MAEE.
//   - Model MAEE=0 1G/2M SysMap no-cross/degrade refill page size, PPN, and
//     flg attributes.
//   - Keep satp/PMP clear-only events as PDE-cache clear events only; in-flight
//     requests remain eligible to update PDE state when their non-leaf data
//     returns.
//   - Treat pre-existing exception grant during abort as visible completion
//     evidence, not as a drop expected by the source scoreboard.
// =============================================================================
`ifndef PTW_SOURCE_REF_MODEL_SVH
`define PTW_SOURCE_REF_MODEL_SVH

class ptw_source_ref_model extends uvm_component;

  `uvm_component_utils(ptw_source_ref_model)

  mmu_top_cfg m_cfg;
  ptw_pde_cache_model m_pde_model;

  uvm_tlm_analysis_fifo #(cp0_txn)                af_csr_write;
  uvm_tlm_analysis_fifo #(pmp_txn)                af_pmp_cfg;
  uvm_tlm_analysis_fifo #(sysmap_cfg_txn)         af_sysmap_cfg;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_req;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_rsp;
  uvm_tlm_analysis_fifo #(ptw_mem_txn)            af_ptw_mem_drop;
  uvm_tlm_analysis_fifo #(ptw_src_req_accept_txn) af_req_accept;
  uvm_tlm_analysis_fifo #(ptw_src_abort_txn)      af_abort;
  uvm_tlm_analysis_fifo #(ptw_src_ctx_sample_txn) af_ctx;
  uvm_tlm_analysis_fifo #(ptw_src_level_evt_txn)  af_level;
  uvm_tlm_analysis_fifo #(ptw_src_pde_evt_txn)    af_pde;
  uvm_tlm_analysis_fifo #(ptw_src_drop_txn)       af_drop;

  uvm_analysis_port #(ptw_src_expected_rsp_txn) ap_expected;

  typedef struct {
    bit                    valid;
    ptw_src_req_type_e     req_type;
    logic [5:0]            id;
    vpn_t                  vpn;
    asid_t                 asid;
    asid_t                 accept_asid;
    ppn_t                  satp_ppn;
    bit                    maee;
    bit                    mprv;
    bit                    mxr;
    bit                    sum;
    logic [1:0]            mpp;
    logic [1:0]            priv_mode;
    bit                    ctx_sample_seen;
    int unsigned           accept_cycle;
    int unsigned           last_cycle;
    ptw_src_level_e        last_level;
    pte_t                  last_pte;
    logic [39:0]           last_pte_pa;
    ptw_src_page_size_e    expected_page_size;
    ptw_src_page_size_e    refill_page_size;
    ppn_t                  refill_ppn;
    logic [4:0]            refill_ext_attr;
    bit                    refill_fields_valid;
    bit                    refill_degraded;
    bit                    expected_page_fault;
    bit                    expected_access_fault;
    bit                    bus_error_seen;
    bit                    pmp_deny_seen;
    bit                    pde_direct_accerr_seen;
    ptw_src_access_src_e   access_src;
    ptw_src_pde_reason_e   pde_reason;
    logic [3:0]            pde_l1pmpflg;
    logic [3:0]            pde_l2pmpflg;
    bit                    pde_l1_tag_hit_deny_seen;
    bit                    pde_l2_tag_hit_deny_seen;
    int unsigned           pde_lookup_cycle;
    int unsigned           pde_direct_accerr_cycle;
    bit                    refill_source_seen;
    bit                    expected_emitted;
    bit                    drop_emitted;
  } pending_req_s;

  typedef struct {
    bit                valid;
    bit                committed;
    ptw_src_level_e    level;
    vpn_t              vpn;
    ppn_t              ppn;
    logic [3:0]        l1pmpflg;
    logic [3:0]        l2pmpflg;
    int unsigned       cycle;
  } pde_update_info_s;

  typedef struct {
    bit                valid;
    ptw_src_req_type_e req_type;
    logic [5:0]        id;
    int unsigned       cycle;
  } pde_direct_accerr_info_s;

  localparam int unsigned PDE_UPDATE_MATCH_WINDOW = 8;
  localparam int unsigned PDE_DIRECT_ACCERR_DUP_WINDOW = 8;

  pending_req_s m_pending[string];
  pde_update_info_s m_pde_expected_update_q[$];
  pde_update_info_s m_pde_observed_update_q[$];
  pde_direct_accerr_info_s m_pde_recent_direct_accerr_q[$];
  ptw_src_pde_evt_txn m_deferred_pde_lookup_q[$];
  bit [3:0]     m_pmp_flg [8];
  bit           m_sysmap_enable [8];
  bit [27:0]    m_sysmap_base [8];
  bit [27:0]    m_sysmap_mask [8];
  bit [4:0]     m_sysmap_flg [8];
  asid_t        m_cur_asid;
  ppn_t         m_cur_satp_ppn;
  bit           m_cur_maee;
  bit           m_cur_mprv;
  bit           m_cur_mxr;
  bit           m_cur_sum;
  logic [1:0]   m_cur_mpp;
  logic [1:0]   m_cur_priv_mode;

  int unsigned m_req_accept_count;
  int unsigned m_expected_count;
  int unsigned m_refill_expected_count;
  int unsigned m_page_fault_expected_count;
  int unsigned m_access_fault_expected_count;
  int unsigned m_drop_expected_count;
  int unsigned m_duplicate_req_count;
  int unsigned m_multi_pending_count;
  int unsigned m_mem_req_count;
  int unsigned m_mem_rsp_count;
  int unsigned m_mem_drop_count;
  int unsigned m_ctx_count;
  int unsigned m_level_count;
  int unsigned m_pde_event_count;
  int unsigned m_pde_update_count;
  int unsigned m_pde_l1_pmp_deny_miss_count;
  int unsigned m_pde_l2_l1pmp_deny_accerr_count;
  int unsigned m_pde_l2_l2pmp_deny_accerr_count;
  int unsigned m_pde_pmpflg_update_l1_count;
  int unsigned m_pde_pmpflg_update_l2_count;
  int unsigned m_pde_mmode_bypass_count;
  int unsigned m_pde_mmode_lock_deny_count;
  int unsigned m_pde_update_match_count;
  int unsigned m_pde_update_mismatch_count;
  int unsigned m_pde_duplicate_direct_accerr_event_count;
  int unsigned m_probe_gap_count;
  int unsigned m_satp_clear_count;
  int unsigned m_pmp_clear_count;
  int unsigned m_asid_current_refill_count;
  int unsigned m_context_current_sample_count;
  int unsigned m_maee0_sysmap_refill_count;
  int unsigned m_maee0_degrade_1g_to_2m_count;
  int unsigned m_maee0_degrade_1g_to_4k_count;
  int unsigned m_maee0_degrade_2m_to_4k_count;
  int unsigned m_pre_existing_exception_grant_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    foreach (m_pmp_flg[i])
      m_pmp_flg[i] = 4'h7;
    foreach (m_sysmap_enable[i]) begin
      m_sysmap_enable[i] = 1'b0;
      m_sysmap_base[i] = '0;
      m_sysmap_mask[i] = '0;
      m_sysmap_flg[i] = 5'h0;
    end
    m_cur_asid = '0;
    m_cur_satp_ppn = '0;
    m_cur_maee = 1'b0;
    m_cur_mprv = 1'b0;
    m_cur_mxr = 1'b0;
    m_cur_sum = 1'b0;
    m_cur_mpp = PRIV_M;
    m_cur_priv_mode = PRIV_M;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    af_csr_write    = new("af_csr_write",    this);
    af_pmp_cfg      = new("af_pmp_cfg",      this);
    af_sysmap_cfg   = new("af_sysmap_cfg",   this);
    af_ptw_mem_req  = new("af_ptw_mem_req",  this);
    af_ptw_mem_rsp  = new("af_ptw_mem_rsp",  this);
    af_ptw_mem_drop = new("af_ptw_mem_drop", this);
    af_req_accept   = new("af_req_accept",   this);
    af_abort        = new("af_abort",        this);
    af_ctx          = new("af_ctx",          this);
    af_level        = new("af_level",        this);
    af_pde          = new("af_pde",          this);
    af_drop         = new("af_drop",         this);
    ap_expected     = new("ap_expected",     this);
    m_pde_model     = ptw_pde_cache_model::type_id::create("m_pde_model");

    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=ref_model stage=7 status=created expected=0 provisional=0",
      UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      collect_csr_write();
      collect_pmp_cfg();
      collect_sysmap_cfg();
      collect_mem_req();
      collect_mem_rsp();
      collect_mem_drop();
      collect_req_accept();
      collect_abort();
      collect_ctx();
      collect_level();
      collect_pde();
      collect_drop();
    join_none
  endtask

  protected function string key_string(input logic [2:0] req_type, input logic [5:0] id);
    return $sformatf("%0h:%0h", req_type, id);
  endfunction

  protected function string pending_key_string(
    input logic [2:0]  req_type,
    input logic [5:0]  id,
    input vpn_t        vpn,
    input int unsigned cycle
  );
    return $sformatf("%s:%07h:%0d", key_string(req_type, id), vpn, cycle);
  endfunction

  protected function bit pending_key_matches(
    input pending_req_s      pending,
    input ptw_src_req_type_e req_type,
    input logic [5:0]        id,
    input bit                use_vpn,
    input vpn_t              vpn
  );
    if ((req_type != PTW_SRC_TYPE_UNKNOWN) && (pending.req_type != req_type))
      return 1'b0;
    if (pending.id != id)
      return 1'b0;
    if (use_vpn && (pending.vpn != vpn))
      return 1'b0;
    return 1'b1;
  endfunction

  protected function ptw_src_target_kind_e target_from_type(input ptw_src_req_type_e req_type);
    case (req_type)
      PTW_SRC_TYPE_FETCH: return PTW_SRC_TARGET_L1I;
      PTW_SRC_TYPE_LOAD,
      PTW_SRC_TYPE_STORE: return PTW_SRC_TARGET_L1D;
      PTW_SRC_TYPE_PFU:   return PTW_SRC_TARGET_PFU;
      default:            return PTW_SRC_TARGET_L2TLB;
    endcase
  endfunction

  protected function ptw_src_page_size_e page_size_from_level(input ptw_src_level_e level);
    case (level)
      PTW_SRC_LEVEL_FST: return PTW_SRC_PGS_1G;
      PTW_SRC_LEVEL_SCD: return PTW_SRC_PGS_2M;
      PTW_SRC_LEVEL_THD: return PTW_SRC_PGS_4K;
      default:           return PTW_SRC_PGS_NONE;
    endcase
  endfunction

  protected function bit resolve_pending_key(
    input  ptw_src_req_type_e req_type,
    input  logic [5:0]        id,
    output string             key,
    input  bit                use_vpn = 1'b0,
    input  vpn_t              vpn = '0,
    input  bit                warn_on_fail = 1'b1
  );
    string base_key;
    string candidate;
    string iter_key;
    int unsigned match_count;

    base_key = key_string(req_type, id);
    key = base_key;
    if (m_pending.exists(base_key)
        && pending_key_matches(m_pending[base_key], req_type, id, use_vpn, vpn))
      return 1'b1;

    match_count = 0;
    foreach (m_pending[iter_key]) begin
      if (!pending_key_matches(m_pending[iter_key], req_type, id, use_vpn, vpn))
        continue;
      candidate = iter_key;
      match_count++;
    end

    if (match_count != 0) begin
      key = candidate;
      if (match_count > 1) begin
        m_probe_gap_count++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_STAGE7_OPEN_GAP kind=ambiguous_pending_key type=%s id=0x%02h use_vpn=%0b vpn=0x%07h match_count=%0d pending=%0d selected=%s",
            req_type.name(), id, use_vpn, vpn, match_count, m_pending.num(), key))
      end
      return 1'b1;
    end

    if (warn_on_fail) begin
      m_probe_gap_count++;
      `uvm_warning(get_type_name(),
        $sformatf("PTW_STAGE7_OPEN_GAP kind=pending_key_not_found type=%s id=0x%02h use_vpn=%0b vpn=0x%07h pending=%0d",
          req_type.name(), id, use_vpn, vpn, m_pending.num()))
    end
    return 1'b0;
  endfunction

  protected function bit is_leaf(input pte_t raw_pte);
    return raw_pte[PTE_V] && (raw_pte[PTE_R] || raw_pte[PTE_X]);
  endfunction

  protected function bit is_write_only_fault(input pte_t raw_pte, input bit mxr);
    return raw_pte[PTE_W] && !(raw_pte[PTE_R] || (mxr && raw_pte[PTE_X]));
  endfunction

  protected function bit effective_machine(input pending_req_s pending);
    if (pending.priv_mode == PRIV_M)
      return 1'b1;
    if (((pending.req_type == PTW_SRC_TYPE_LOAD)
         || (pending.req_type == PTW_SRC_TYPE_STORE)
         || (pending.req_type == PTW_SRC_TYPE_PFU))
        && pending.mprv && (pending.mpp == PRIV_M))
      return 1'b1;
    return 1'b0;
  endfunction

  protected function bit effective_user(input pending_req_s pending);
    if (effective_machine(pending))
      return 1'b0;
    if (((pending.req_type == PTW_SRC_TYPE_LOAD)
         || (pending.req_type == PTW_SRC_TYPE_STORE)
         || (pending.req_type == PTW_SRC_TYPE_PFU))
        && pending.mprv)
      return (pending.mpp == PRIV_U);
    return (pending.priv_mode == PRIV_U);
  endfunction

  protected function bit effective_supervisor(input pending_req_s pending);
    if (effective_machine(pending))
      return 1'b0;
    if (((pending.req_type == PTW_SRC_TYPE_LOAD)
         || (pending.req_type == PTW_SRC_TYPE_STORE)
         || (pending.req_type == PTW_SRC_TYPE_PFU))
        && pending.mprv)
      return (pending.mpp == PRIV_S);
    return (pending.priv_mode == PRIV_S);
  endfunction

  protected function ptw_src_level_e pde_update_level_from_bits(input logic [1:0] update_level);
    if (update_level == 2'b10)
      return PTW_SRC_LEVEL_FST;
    if (update_level == 2'b01)
      return PTW_SRC_LEVEL_SCD;
    return PTW_SRC_LEVEL_NONE;
  endfunction

  protected function string pde_update_info2string(input pde_update_info_s info);
    return $sformatf(
      "valid=%0b committed=%0b level=%s vpn=0x%07h ppn=0x%07h pmp={l1=0x%0h,l2=0x%0h} cycle=%0d",
      info.valid, info.committed, info.level.name(), info.vpn, info.ppn,
      info.l1pmpflg, info.l2pmpflg, info.cycle);
  endfunction

  protected function bit pde_update_info_matches(
    input pde_update_info_s exp,
    input pde_update_info_s obs
  );
    return exp.valid && obs.valid
        && (exp.level == obs.level)
        && (exp.vpn == obs.vpn)
        && (exp.ppn == obs.ppn)
        && (exp.l1pmpflg == obs.l1pmpflg)
        && (exp.l2pmpflg == obs.l2pmpflg);
  endfunction

  protected function bit pde_reason_is_pmp_deny(input ptw_src_pde_reason_e reason);
    return (reason == PTW_SRC_PDE_REASON_L1_PMP_DENY)
        || (reason == PTW_SRC_PDE_REASON_L2_L1PMP_DENY)
        || (reason == PTW_SRC_PDE_REASON_L2_L2PMP_DENY)
        || (reason == PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY);
  endfunction

  protected function bit cycle_is_older_than(
    input int unsigned cycle,
    input int unsigned old_cycle,
    input int unsigned window
  );
    return (cycle >= old_cycle) && ((cycle - old_cycle) > window);
  endfunction

  protected function void prune_observed_pde_update_q(input int unsigned cycle);
    while ((m_pde_observed_update_q.size() > 0)
           && cycle_is_older_than(cycle, m_pde_observed_update_q[0].cycle,
             PDE_UPDATE_MATCH_WINDOW)) begin
      m_pde_update_mismatch_count++;
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_UPDATE_UNMATCHED_OBSERVED observed=%s predicted_q=%0d",
          pde_update_info2string(m_pde_observed_update_q[0]),
          m_pde_expected_update_q.size()))
      void'(m_pde_observed_update_q.pop_front());
    end
  endfunction

  protected function void prune_pde_direct_accerr_history(input int unsigned cycle);
    while ((m_pde_recent_direct_accerr_q.size() > 0)
           && cycle_is_older_than(cycle, m_pde_recent_direct_accerr_q[0].cycle,
             PDE_DIRECT_ACCERR_DUP_WINDOW)) begin
      void'(m_pde_recent_direct_accerr_q.pop_front());
    end
  endfunction

  protected function bit pde_direct_accerr_event_is_recent(
    input ptw_src_req_type_e req_type,
    input logic [5:0]        id,
    input int unsigned       cycle,
    input bit                count_duplicate = 1'b1
  );
    prune_pde_direct_accerr_history(cycle);
    foreach (m_pde_recent_direct_accerr_q[i]) begin
      if ((m_pde_recent_direct_accerr_q[i].req_type == req_type)
          && (m_pde_recent_direct_accerr_q[i].id == id)) begin
        if (count_duplicate)
          m_pde_duplicate_direct_accerr_event_count++;
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  protected function bit note_pde_direct_accerr_event(
    input ptw_src_req_type_e req_type,
    input logic [5:0]        id,
    input int unsigned       cycle
  );
    pde_direct_accerr_info_s info;

    if (pde_direct_accerr_event_is_recent(req_type, id, cycle))
      return 1'b0;

    info.valid = 1'b1;
    info.req_type = req_type;
    info.id = id;
    info.cycle = cycle;
    m_pde_recent_direct_accerr_q.push_back(info);
    return 1'b1;
  endfunction

  protected function void clear_pde_pmpflg_shadow();
    m_pde_expected_update_q.delete();
    m_pde_observed_update_q.delete();
    m_pde_recent_direct_accerr_q.delete();
    m_deferred_pde_lookup_q.delete();
  endfunction

  protected function void record_predicted_pde_update(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
    input logic [3:0]     l1pmpflg,
    input logic [3:0]     l2pmpflg,
    input int unsigned    cycle
  );
    pde_update_info_s info;

    info.valid = 1'b1;
    info.committed = 1'b0;
    info.level = level;
    info.vpn = vpn;
    info.ppn = ppn;
    info.l1pmpflg = l1pmpflg;
    info.l2pmpflg = (level == PTW_SRC_LEVEL_FST) ? 4'h0 : l2pmpflg;
    info.cycle = cycle;

    prune_observed_pde_update_q(cycle);
    foreach (m_pde_observed_update_q[i]) begin
      if (pde_update_info_matches(info, m_pde_observed_update_q[i])) begin
        m_pde_update_match_count++;
        m_pde_observed_update_q.delete(i);
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_LATE_PREDICT_MATCH %s",
            pde_update_info2string(info)),
          UVM_HIGH)
        return;
      end
    end

    m_pde_expected_update_q.push_back(info);
    `uvm_info(get_type_name(),
      $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_PREDICT_UPDATE %s",
        pde_update_info2string(info)),
      UVM_HIGH)

    while ((m_pde_expected_update_q.size() > 0)
           && cycle_is_older_than(cycle, m_pde_expected_update_q[0].cycle,
             PDE_UPDATE_MATCH_WINDOW)
           && !m_pde_expected_update_q[0].committed) begin
      m_pde_update_mismatch_count++;
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_UPDATE_TIMEOUT predicted=%s observed_q=%0d",
          pde_update_info2string(m_pde_expected_update_q[0]),
          m_pde_observed_update_q.size()))
      void'(m_pde_expected_update_q.pop_front());
    end
  endfunction

  protected function void commit_pde_update_from_observed(input pde_update_info_s obs);
    int match_idx;

    match_idx = -1;
    foreach (m_pde_expected_update_q[i]) begin
      if (pde_update_info_matches(m_pde_expected_update_q[i], obs)) begin
        match_idx = int'(i);
        break;
      end
    end

    if (match_idx >= 0) begin
      m_pde_expected_update_q.delete(match_idx);
      m_pde_update_match_count++;
    end else begin
      m_pde_observed_update_q.push_back(obs);
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_OBSERVED_UPDATE_PENDING_MATCH observed=%s predicted_q=%0d",
          pde_update_info2string(obs), m_pde_expected_update_q.size()),
        UVM_HIGH)
    end

    m_pde_model.commit_update_with_pmpflg(obs.level, obs.vpn, obs.ppn,
      obs.l1pmpflg, obs.l2pmpflg);
    if (obs.level == PTW_SRC_LEVEL_FST)
      m_pde_pmpflg_update_l1_count++;
    else if (obs.level == PTW_SRC_LEVEL_SCD)
      m_pde_pmpflg_update_l2_count++;
  endfunction

  protected function void finalize_pde_update_matching();
    while (m_pde_expected_update_q.size() > 0) begin
      m_pde_update_mismatch_count++;
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_UPDATE_UNMATCHED_PREDICTED predicted=%s observed_q=%0d",
          pde_update_info2string(m_pde_expected_update_q[0]),
          m_pde_observed_update_q.size()))
      void'(m_pde_expected_update_q.pop_front());
    end

    while (m_pde_observed_update_q.size() > 0) begin
      m_pde_update_mismatch_count++;
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_UPDATE_UNMATCHED_OBSERVED observed=%s",
          pde_update_info2string(m_pde_observed_update_q[0])))
      void'(m_pde_observed_update_q.pop_front());
    end
  endfunction

  protected task process_pde_lookup_event(input ptw_src_pde_evt_txn tr);
    string key;
    pending_req_s pending;
    ptw_pde_cache_model::pde_lookup_result_s lookup;

    if (tr.direct_accerr
        && pde_direct_accerr_event_is_recent(tr.req_type, tr.id, tr.cycle)) begin
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_DUP_DIRECT_ACCERR_IGNORED %s",
          tr.convert2string()),
        UVM_HIGH)
      return;
    end

    if (!resolve_pending_key(tr.req_type, tr.id, key, 1'b1, tr.vpn)) begin
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_LOOKUP_NO_PENDING %s", tr.convert2string()))
      return;
    end

    pending = m_pending[key];
    lookup = m_pde_model.lookup_detail(pending.vpn, pending.req_type,
      effective_machine(pending));

    if ((lookup.l1_hit != tr.l1_hit) || (lookup.l2_hit != tr.l2_hit)
        || (lookup.l1_tag_hit != tr.l1_tag_hit)
        || (lookup.l2_tag_hit != tr.l2_tag_hit)) begin
      m_probe_gap_count++;
      `uvm_warning(get_type_name(),
        $sformatf({"PTW_SOURCE_REF_PDE_LOOKUP_MISMATCH model={%s} ",
                   "actual={hit_l1=%0b hit_l2=%0b tag_l1=%0b tag_l2=%0b direct=%0b reason=%s}"},
          m_pde_model.lookup_result2string(lookup),
          tr.l1_hit, tr.l2_hit, tr.l1_tag_hit, tr.l2_tag_hit,
          tr.direct_accerr, ptw_src_pde_reason_name(tr.reason)))
    end

    if ((tr.cached_l1pmpflg != lookup.cached_l1pmpflg)
        || (tr.cached_l2pmpflg != lookup.cached_l2pmpflg)) begin
      if (lookup.l1_tag_hit || lookup.l2_tag_hit) begin
        m_probe_gap_count++;
        `uvm_warning(get_type_name(),
          $sformatf({"PTW_SOURCE_REF_PDE_PMPFLG_MISMATCH model={l1=0x%0h,l2=0x%0h} ",
                     "actual={l1=0x%0h,l2=0x%0h} key=%s"},
            lookup.cached_l1pmpflg, lookup.cached_l2pmpflg,
            tr.cached_l1pmpflg, tr.cached_l2pmpflg, key))
      end
    end

    pending.pde_lookup_cycle = tr.cycle;
    pending.pde_reason = lookup.reason;
    pending.pde_l1pmpflg = lookup.cached_l1pmpflg;
    pending.pde_l2pmpflg = lookup.cached_l2pmpflg;

    if (effective_machine(pending)
        && ((lookup.cached_l1pmpflg[3] == 1'b0)
            || (lookup.cached_l2pmpflg[3] == 1'b0))
        && (lookup.lookup_hit || lookup.l1_tag_hit || lookup.l2_tag_hit))
      m_pde_mmode_bypass_count++;
    if (effective_machine(pending) && pde_reason_is_pmp_deny(lookup.reason))
      m_pde_mmode_lock_deny_count++;

    if (lookup.l1_deny_miss) begin
      pending.pde_l1_tag_hit_deny_seen = 1'b1;
      m_pde_l1_pmp_deny_miss_count++;
      m_pending[key] = pending;
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_L1_PMP_DENY_MISS key=%s %s",
          key, m_pde_model.lookup_result2string(lookup)),
        UVM_MEDIUM)
    end else if (lookup.l2_direct_accerr) begin
      pending.pde_l2_tag_hit_deny_seen = 1'b1;
      pending.pde_direct_accerr_seen = 1'b1;
      pending.pde_direct_accerr_cycle = tr.cycle;
      pending.expected_access_fault = 1'b1;
      pending.access_src = PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY;
      pending.pde_reason = (lookup.reason != PTW_SRC_PDE_REASON_NONE)
                         ? lookup.reason : tr.reason;
      pending.pde_l1pmpflg = (lookup.l2_tag_hit || lookup.l1_tag_hit)
                           ? lookup.cached_l1pmpflg : tr.cached_l1pmpflg;
      pending.pde_l2pmpflg = lookup.l2_tag_hit
                           ? lookup.cached_l2pmpflg : tr.cached_l2pmpflg;

      if (note_pde_direct_accerr_event(pending.req_type, pending.id, tr.cycle)) begin
        if (pending.pde_reason == PTW_SRC_PDE_REASON_L2_L1PMP_DENY)
          m_pde_l2_l1pmp_deny_accerr_count++;
        else if (pending.pde_reason == PTW_SRC_PDE_REASON_L2_L2PMP_DENY)
          m_pde_l2_l2pmp_deny_accerr_count++;
        else if (pending.pde_reason == PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY) begin
          m_pde_l2_l1pmp_deny_accerr_count++;
          m_pde_l2_l2pmp_deny_accerr_count++;
        end

        m_pending[key] = pending;
        build_and_emit_completion(key, pending, PTW_SRC_EXP_ACCESS_FAULT,
          PTW_SRC_FAULT_ACCESS, pending.last_pte, 1'b0, tr.cycle,
          PTW_SRC_ACCESS_SRC_PDE_CACHE_PMP_DENY, pending.pde_reason,
          pending.pde_l1pmpflg, pending.pde_l2pmpflg, 1'b1);
      end else if (m_pending.exists(key)) begin
        m_pending[key] = pending;
      end
    end else begin
      m_pending[key] = pending;
    end
  endtask

  protected task drain_deferred_pde_lookup_events();
    ptw_src_pde_evt_txn tr;
    string key;

    while (m_deferred_pde_lookup_q.size() > 0) begin
      tr = m_deferred_pde_lookup_q[0];
      if (resolve_pending_key(tr.req_type, tr.id, key, 1'b1, tr.vpn, 1'b0)
          && m_pending[key].ctx_sample_seen) begin
        void'(m_deferred_pde_lookup_q.pop_front());
        process_pde_lookup_event(tr);
      end else begin
        break;
      end
    end
  endtask

  protected function bit leaf_page_fault(
    input pending_req_s pending,
    input pte_t raw_pte,
    input ptw_src_level_e level
  );
    bit fault;
    fault = 1'b0;
    if (!raw_pte[PTE_V])
      fault = 1'b1;
    if (is_write_only_fault(raw_pte, pending.mxr))
      fault = 1'b1;
    if (pending.req_type == PTW_SRC_TYPE_LOAD) begin
      if (!raw_pte[PTE_R] && !(pending.mxr && raw_pte[PTE_X]))
        fault = 1'b1;
    end else if (pending.req_type == PTW_SRC_TYPE_STORE) begin
      if (!raw_pte[PTE_W])
        fault = 1'b1;
    end else if (pending.req_type == PTW_SRC_TYPE_FETCH) begin
      if (!raw_pte[PTE_X])
        fault = 1'b1;
    end
    if (effective_supervisor(pending) && raw_pte[PTE_U] && !pending.sum)
      fault = 1'b1;
    if (effective_user(pending) && !raw_pte[PTE_U])
      fault = 1'b1;
    if (!raw_pte[PTE_A])
      fault = 1'b1;
    if ((pending.req_type == PTW_SRC_TYPE_STORE) && !raw_pte[PTE_D])
      fault = 1'b1;
    if ((level == PTW_SRC_LEVEL_FST) && (raw_pte[PTE_PPN_LSB +: 18] != 18'b0))
      fault = 1'b1;
    if ((level == PTW_SRC_LEVEL_SCD) && (raw_pte[PTE_PPN_LSB +: 9] != 9'b0))
      fault = 1'b1;
    return fault;
  endfunction

  protected function bit nonleaf_page_fault(
    input pending_req_s pending,
    input pte_t raw_pte,
    input ptw_src_level_e level
  );
    // RTL TWU gates FST/SCD page_flt with leaf_vld, so invalid or malformed
    // non-leaf encodings at those levels are treated as next-level pointers.
    // THD has no lower level and reports any non-leaf encoding as page fault.
    if (level == PTW_SRC_LEVEL_THD)
      return 1'b1;
    return 1'b0;
  endfunction

  protected function logic [4:0] sysmap_attr(input ppn_t ppn, output bit hit);
    // ct_mmu_sysmap is macro-configured in this build.  The sysmap_cfg_agent
    // mirror is not forced into RTL, so source expectations must use the RTL
    // compile-time region table rather than the UVM mirror transaction.
    hit = 1'b1;
`ifdef SYSMAP_BASE_ADDR0
    if (ppn < `SYSMAP_BASE_ADDR0) return `SYSMAP_FLG0;
    if (ppn < `SYSMAP_BASE_ADDR1) return `SYSMAP_FLG1;
    if (ppn < `SYSMAP_BASE_ADDR2) return `SYSMAP_FLG2;
    if (ppn < `SYSMAP_BASE_ADDR3) return `SYSMAP_FLG3;
    if (ppn < `SYSMAP_BASE_ADDR4) return `SYSMAP_FLG4;
    if (ppn < `SYSMAP_BASE_ADDR5) return `SYSMAP_FLG5;
    if (ppn < `SYSMAP_BASE_ADDR6) return `SYSMAP_FLG6;
    if (ppn < `SYSMAP_BASE_ADDR7) return `SYSMAP_FLG7;
`else
    if (ppn < 28'h0012100) return 5'b01111;
    if (ppn < 28'h0080000) return 5'b10011;
    if (ppn < 28'h00E0000) return 5'b10001;
    if (ppn < 28'h0200000) return 5'b01111;
    if (ppn < 28'h0400000) return 5'b01111;
    if (ppn < 28'h0800000) return 5'b01111;
    if (ppn < 28'h1000000) return 5'b01111;
    if (ppn < 28'hF000000) return 5'b10011;
`endif
    hit = 1'b0;
    return 5'b10011;
  endfunction

  protected function int sysmap_region(input ppn_t ppn, output bit hit);
    hit = 1'b1;
`ifdef SYSMAP_BASE_ADDR0
    if (ppn < `SYSMAP_BASE_ADDR0) return 0;
    if (ppn < `SYSMAP_BASE_ADDR1) return 1;
    if (ppn < `SYSMAP_BASE_ADDR2) return 2;
    if (ppn < `SYSMAP_BASE_ADDR3) return 3;
    if (ppn < `SYSMAP_BASE_ADDR4) return 4;
    if (ppn < `SYSMAP_BASE_ADDR5) return 5;
    if (ppn < `SYSMAP_BASE_ADDR6) return 6;
    if (ppn < `SYSMAP_BASE_ADDR7) return 7;
`else
    if (ppn < 28'h0012100) return 0;
    if (ppn < 28'h0080000) return 1;
    if (ppn < 28'h00E0000) return 2;
    if (ppn < 28'h0200000) return 3;
    if (ppn < 28'h0400000) return 4;
    if (ppn < 28'h0800000) return 5;
    if (ppn < 28'h1000000) return 6;
    if (ppn < 28'hF000000) return 7;
`endif
    hit = 1'b0;
    return -1;
  endfunction

  protected function bit same_sysmap_region(input ppn_t first_ppn, input ppn_t last_ppn);
    bit first_hit;
    bit last_hit;
    int first_region;
    int last_region;

    first_region = sysmap_region(first_ppn, first_hit);
    last_region = sysmap_region(last_ppn, last_hit);
    return (first_hit == last_hit) && (first_region == last_region);
  endfunction

  protected function void compute_refill_fields(
    input pending_req_s pending,
    input pte_t raw_pte,
    input ptw_src_page_size_e base_page_size,
    output ptw_src_page_size_e page_size,
    output ppn_t ppn,
    output logic [4:0] ext_attr,
    output bit degraded
  );
    bit hit;
    ppn_t leaf_ppn;
    ppn_t first_ppn;
    ppn_t last_ppn;
    ppn_t candidate_ppn;

    leaf_ppn = raw_pte[PTE_PPN_LSB +: PPN_WIDTH];
    page_size = base_page_size;
    ppn = leaf_ppn;
    degraded = 1'b0;

    if (pending.maee) begin
      ext_attr = raw_pte[63:59];
      return;
    end

    if (base_page_size == PTW_SRC_PGS_1G) begin
      first_ppn = leaf_ppn;
      last_ppn = {leaf_ppn[PPN_WIDTH-1:18], 18'h3ffff};
      if (!same_sysmap_region(first_ppn, last_ppn)) begin
        candidate_ppn = {leaf_ppn[PPN_WIDTH-1:18], pending.vpn[17:9], 9'b0};
        first_ppn = candidate_ppn;
        last_ppn = {candidate_ppn[PPN_WIDTH-1:9], 9'h1ff};
        page_size = PTW_SRC_PGS_2M;
        ppn = candidate_ppn;
        degraded = 1'b1;
        if (!same_sysmap_region(first_ppn, last_ppn)) begin
          page_size = PTW_SRC_PGS_4K;
          ppn = {leaf_ppn[PPN_WIDTH-1:18], pending.vpn[17:0]};
        end
      end
    end else if (base_page_size == PTW_SRC_PGS_2M) begin
      first_ppn = leaf_ppn;
      last_ppn = {leaf_ppn[PPN_WIDTH-1:9], 9'h1ff};
      if (!same_sysmap_region(first_ppn, last_ppn)) begin
        page_size = PTW_SRC_PGS_4K;
        ppn = {leaf_ppn[PPN_WIDTH-1:9], pending.vpn[8:0]};
        degraded = 1'b1;
      end
    end

    if (page_size == PTW_SRC_PGS_1G)
      ext_attr = sysmap_attr({ppn[PPN_WIDTH-1:18], 18'h3ffff}, hit);
    else if (page_size == PTW_SRC_PGS_2M)
      ext_attr = sysmap_attr({ppn[PPN_WIDTH-1:9], 9'h1ff}, hit);
    else
      ext_attr = sysmap_attr(ppn, hit);

    if (!hit)
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_SYSMAP_DEFAULT key=%s page_size=%s ppn=0x%07h attr=0x%02h",
          key_string(pending.req_type, pending.id), page_size.name(), ppn,
          ext_attr),
        UVM_HIGH)
  endfunction

  protected task emit_expected(input ptw_src_expected_rsp_txn exp);
    m_expected_count++;
    if (exp.kind == PTW_SRC_EXP_REFILL)
      m_refill_expected_count++;
    else if (exp.kind == PTW_SRC_EXP_PAGE_FAULT)
      m_page_fault_expected_count++;
    else if (exp.kind == PTW_SRC_EXP_ACCESS_FAULT)
      m_access_fault_expected_count++;
    else if (exp.kind == PTW_SRC_EXP_DROP)
      m_drop_expected_count++;
    ap_expected.write(exp);
    `uvm_info(get_type_name(), {"PTW_EXPECTED ", exp.convert2string()}, UVM_HIGH)
  endtask

  protected task build_and_emit_completion(
    input string key,
    input pending_req_s pending,
    input ptw_src_exp_kind_e kind,
    input ptw_src_fault_kind_e fault_kind,
    input pte_t raw_pte,
    input bit use_pte,
    input int unsigned cycle,
    input ptw_src_access_src_e access_src = PTW_SRC_ACCESS_SRC_NONE,
    input ptw_src_pde_reason_e pde_reason = PTW_SRC_PDE_REASON_NONE,
    input logic [3:0] pde_l1pmpflg = 4'h0,
    input logic [3:0] pde_l2pmpflg = 4'h0,
    input bit pde_direct_accerr = 1'b0
  );
    ptw_src_expected_rsp_txn exp;
    ptw_src_page_size_e pgs;
    ppn_t ppn;
    logic [4:0] ext_attr;
    bit degraded;
    asid_t refill_asid;

    exp = ptw_src_expected_rsp_txn::type_id::create("ptw_expected");
    exp.cycle = cycle;
    exp.kind = kind;
    exp.req_type = pending.req_type;
    exp.id = pending.id;
    exp.vpn = pending.vpn;
    refill_asid = (kind == PTW_SRC_EXP_REFILL) ? m_cur_asid : pending.asid;
    exp.asid = refill_asid;
    exp.target = target_from_type(pending.req_type);
    exp.target_l2tlb = 1'b1;
    exp.target_l1i = (pending.req_type == PTW_SRC_TYPE_FETCH);
    exp.target_l1d = (pending.req_type == PTW_SRC_TYPE_LOAD)
                  || (pending.req_type == PTW_SRC_TYPE_STORE);
    exp.target_pfu = (pending.req_type == PTW_SRC_TYPE_PFU);
    exp.fault_kind = fault_kind;
    exp.drop_reason = PTW_SRC_DROP_NONE;
    exp.access_src = access_src;
    exp.pde_reason = pde_reason;
    exp.pde_l1pmpflg = pde_l1pmpflg;
    exp.pde_l2pmpflg = pde_l2pmpflg;
    exp.pde_direct_accerr = pde_direct_accerr;
    exp.completion_or_seen = 1'b0;
    exp.raw_tag = '0;
    exp.raw_data = '0;
    exp.has_drop_key = 1'b0;
    exp.reset_drop = 1'b0;
    exp.abort_drop = 1'b0;
    exp.late_data = 1'b0;
    exp.abort_bus_error = 1'b0;
    exp.pre_existing_exception_grant = 1'b0;

    if (kind == PTW_SRC_EXP_REFILL) begin
      if (pending.refill_fields_valid) begin
        pgs = pending.refill_page_size;
        ppn = pending.refill_ppn;
        ext_attr = pending.refill_ext_attr;
      end else begin
        compute_refill_fields(pending, raw_pte, pending.expected_page_size,
          pgs, ppn, ext_attr, degraded);
      end
      exp.page_size = pgs;
      exp.ppn = ppn;
      exp.global_bit = raw_pte[PTE_G];
      exp.flg = ptw_src_make_refill_flg(ext_attr, raw_pte);
      exp.raw_tag = ptw_src_make_refill_tag(pending.vpn, refill_asid, pgs, raw_pte[PTE_G]);
      exp.raw_data = ptw_src_make_refill_data(ppn, ext_attr, raw_pte);
      exp.refill_valid = 1'b1;
      exp.page_fault = 1'b0;
      exp.access_fault = 1'b0;
      if (exp.asid != pending.accept_asid)
        m_asid_current_refill_count++;
    end else begin
      exp.page_size = PTW_SRC_PGS_NONE;
      exp.ppn = '0;
      exp.global_bit = 1'b0;
      exp.flg = '0;
      exp.refill_valid = 1'b0;
      exp.page_fault = (kind == PTW_SRC_EXP_PAGE_FAULT);
      exp.access_fault = (kind == PTW_SRC_EXP_ACCESS_FAULT);
    end

    emit_expected(exp);
    if (m_pending.exists(key)) begin
      m_pending[key].expected_emitted = 1'b1;
      m_pending.delete(key);
    end
  endtask

  protected task emit_drop_expected(input ptw_src_drop_txn drop_tr);
    ptw_src_expected_rsp_txn exp;

    exp = ptw_src_expected_rsp_txn::type_id::create("ptw_drop_expected");
    exp.cycle = drop_tr.cycle;
    exp.kind = PTW_SRC_EXP_DROP;
    exp.drop_reason = drop_tr.drop_reason;
    exp.fault_kind = PTW_SRC_FAULT_NONE;
    exp.page_size = PTW_SRC_PGS_NONE;
    exp.asid = '0;
    exp.ppn = '0;
    exp.global_bit = 1'b0;
    exp.flg = '0;
    exp.access_src = PTW_SRC_ACCESS_SRC_NONE;
    exp.pde_reason = PTW_SRC_PDE_REASON_NONE;
    exp.pde_l1pmpflg = 4'h0;
    exp.pde_l2pmpflg = 4'h0;
    exp.pde_direct_accerr = 1'b0;
    exp.raw_tag = '0;
    exp.raw_data = '0;
    exp.completion_or_seen = 1'b0;
    exp.refill_valid = 1'b0;
    exp.page_fault = 1'b0;
    exp.access_fault = 1'b0;
    exp.target_l2tlb = 1'b0;
    exp.target_l1i = 1'b0;
    exp.target_l1d = 1'b0;
    exp.target_pfu = 1'b0;
    exp.has_drop_key = drop_tr.has_key;
    exp.reset_drop = drop_tr.reset_drop;
    exp.abort_drop = drop_tr.abort_drop;
    exp.late_data = drop_tr.late_data;
    exp.abort_bus_error = drop_tr.abort_bus_error;
    exp.pre_existing_exception_grant = drop_tr.pre_existing_exception_grant;
    if (drop_tr.has_key) begin
      exp.req_type = drop_tr.key.req_type;
      exp.id = drop_tr.key.id;
      exp.vpn = drop_tr.vpn;
      exp.target = target_from_type(drop_tr.key.req_type);
    end else begin
      exp.req_type = PTW_SRC_TYPE_UNKNOWN;
      exp.id = '0;
      exp.vpn = drop_tr.vpn;
      exp.target = PTW_SRC_TARGET_NONE;
    end
    emit_expected(exp);
  endtask

  protected task collect_req_accept();
    forever begin
      ptw_src_req_accept_txn tr;
      pending_req_s pending;
      string key;
      string base_key;

      af_req_accept.get(tr);
      base_key = key_string(tr.req_type, tr.id);
      key = base_key;
      if (m_pending.exists(key)) begin
        m_multi_pending_count++;
        key = pending_key_string(tr.req_type, tr.id, tr.vpn, tr.cycle);
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_REF_MULTI_PENDING base_key=%s new_key=%s old_vpn=0x%07h new_vpn=0x%07h",
            base_key, key, m_pending[base_key].vpn, tr.vpn),
          UVM_HIGH)
        while (m_pending.exists(key))
          key = {key, "_r"};
      end

      pending.valid = 1'b1;
      pending.req_type = tr.req_type;
      pending.id = tr.id;
      pending.vpn = tr.vpn;
      pending.asid = tr.asid;
      pending.accept_asid = tr.asid;
      pending.satp_ppn = m_cur_satp_ppn;
      pending.maee = m_cur_maee;
      pending.mprv = m_cur_mprv;
      pending.mxr = m_cur_mxr;
      pending.sum = m_cur_sum;
      pending.mpp = m_cur_mpp;
      pending.priv_mode = m_cur_priv_mode;
      pending.ctx_sample_seen = 1'b0;
      pending.accept_cycle = tr.cycle;
      pending.last_cycle = tr.cycle;
      pending.last_level = PTW_SRC_LEVEL_NONE;
      pending.last_pte = '0;
      pending.last_pte_pa = '0;
      pending.expected_page_size = PTW_SRC_PGS_NONE;
      pending.refill_page_size = PTW_SRC_PGS_NONE;
      pending.refill_ppn = '0;
      pending.refill_ext_attr = '0;
      pending.refill_fields_valid = 1'b0;
      pending.refill_degraded = 1'b0;
      pending.expected_page_fault = 1'b0;
      pending.expected_access_fault = 1'b0;
      pending.bus_error_seen = 1'b0;
      pending.pmp_deny_seen = 1'b0;
      pending.pde_direct_accerr_seen = 1'b0;
      pending.access_src = PTW_SRC_ACCESS_SRC_NONE;
      pending.pde_reason = PTW_SRC_PDE_REASON_NONE;
      pending.pde_l1pmpflg = 4'h0;
      pending.pde_l2pmpflg = 4'h0;
      pending.pde_l1_tag_hit_deny_seen = 1'b0;
      pending.pde_l2_tag_hit_deny_seen = 1'b0;
      pending.pde_lookup_cycle = 0;
      pending.pde_direct_accerr_cycle = 0;
      pending.refill_source_seen = 1'b0;
      pending.expected_emitted = 1'b0;
      pending.drop_emitted = 1'b0;
      m_pending[key] = pending;
      m_req_accept_count++;
    end
  endtask

  protected task collect_ctx();
    forever begin
      ptw_src_ctx_sample_txn tr;
      string key;
      pending_req_s pending;

      af_ctx.get(tr);
      m_cur_asid = tr.asid;
      m_cur_satp_ppn = tr.satp_ppn;
      m_cur_maee = tr.maee;
      m_cur_mprv = tr.mprv;
      m_cur_mxr = tr.mxr;
      m_cur_sum = tr.sum;
      m_cur_mpp = tr.mpp;
      m_cur_priv_mode = tr.priv_mode;
      if (resolve_pending_key(tr.req_type, tr.id, key, 1'b1, tr.vpn)) begin
        pending = m_pending[key];
        pending.asid = tr.asid;
        pending.satp_ppn = tr.satp_ppn;
        pending.maee = tr.maee;
        pending.mprv = tr.mprv;
        pending.mxr = tr.mxr;
        pending.sum = tr.sum;
        pending.mpp = tr.mpp;
        pending.priv_mode = tr.priv_mode;
        pending.ctx_sample_seen = 1'b1;
        pending.last_cycle = tr.cycle;
        m_pending[key] = pending;
      end
      drain_deferred_pde_lookup_events();
      m_ctx_count++;
    end
  endtask

  protected task collect_level();
    forever begin
      ptw_src_level_evt_txn tr;
      string key;
      pending_req_s pending;
      bit leaf;
      bit page_fault;
      ptw_src_page_size_e refill_page_size;
      ppn_t refill_ppn;
      logic [4:0] refill_ext_attr;
      bit refill_degraded;

      af_level.get(tr);
      if (!resolve_pending_key(tr.req_type, tr.id, key, 1'b1, tr.vpn)) begin
        m_level_count++;
        continue;
      end

      pending = m_pending[key];
      if ((tr.req_type != PTW_SRC_TYPE_UNKNOWN)
          && (tr.level != PTW_SRC_LEVEL_NONE)) begin
        pending.asid = m_cur_asid;
        pending.satp_ppn = m_cur_satp_ppn;
        pending.maee = m_cur_maee;
        pending.mprv = m_cur_mprv;
        pending.mxr = m_cur_mxr;
        pending.sum = m_cur_sum;
        pending.mpp = m_cur_mpp;
        pending.priv_mode = m_cur_priv_mode;
        pending.ctx_sample_seen = 1'b1;
        m_context_current_sample_count++;
      end
      pending.last_cycle = tr.cycle;
      if (tr.level != PTW_SRC_LEVEL_NONE)
        pending.last_level = tr.level;
      if (tr.pte_pa != '0)
        pending.last_pte_pa = tr.pte_pa;

      if (tr.pmp_deny) begin
        pending.pmp_deny_seen = 1'b1;
        pending.expected_access_fault = 1'b1;
        pending.access_src = PTW_SRC_ACCESS_SRC_TWU_PMP;
      end
      if (tr.access_fault) begin
        pending.expected_access_fault = 1'b1;
        if (pending.access_src == PTW_SRC_ACCESS_SRC_NONE)
          pending.access_src = PTW_SRC_ACCESS_SRC_TWU_PMP;
      end

      if (tr.mbuf_data_vld) begin
        pending.last_pte = tr.pte_data;
        leaf = is_leaf(tr.pte_data);
        if (leaf) begin
          pending.expected_page_size = page_size_from_level(tr.level);
          page_fault = leaf_page_fault(pending, tr.pte_data, tr.level);
          if (!page_fault && !tr.page_fault) begin
            compute_refill_fields(pending, tr.pte_data,
              pending.expected_page_size, refill_page_size,
              refill_ppn, refill_ext_attr, refill_degraded);
            pending.refill_page_size = refill_page_size;
            pending.refill_ppn = refill_ppn;
            pending.refill_ext_attr = refill_ext_attr;
            pending.refill_degraded = refill_degraded;
            pending.refill_fields_valid = 1'b1;
            if (!pending.maee) begin
              m_maee0_sysmap_refill_count++;
              if (pending.refill_degraded) begin
                if ((pending.expected_page_size == PTW_SRC_PGS_1G)
                    && (pending.refill_page_size == PTW_SRC_PGS_2M))
                  m_maee0_degrade_1g_to_2m_count++;
                else if ((pending.expected_page_size == PTW_SRC_PGS_1G)
                    && (pending.refill_page_size == PTW_SRC_PGS_4K))
                  m_maee0_degrade_1g_to_4k_count++;
                else if ((pending.expected_page_size == PTW_SRC_PGS_2M)
                    && (pending.refill_page_size == PTW_SRC_PGS_4K))
                  m_maee0_degrade_2m_to_4k_count++;
              end
            end
          end
        end else begin
          pending.expected_page_size = PTW_SRC_PGS_NONE;
          page_fault = nonleaf_page_fault(pending, tr.pte_data, tr.level);
          if (!page_fault && ((tr.level == PTW_SRC_LEVEL_FST) || (tr.level == PTW_SRC_LEVEL_SCD))) begin
            record_predicted_pde_update(
              tr.level,
              pending.vpn,
              tr.pte_data[PTE_PPN_LSB +: PPN_WIDTH],
              tr.mbuf_pmpflg[3:0],
              (tr.level == PTW_SRC_LEVEL_SCD) ? tr.mbuf_pmpflg[7:4] : 4'h0,
              tr.cycle);
          end
        end

        if (page_fault || tr.page_fault) begin
          pending.expected_page_fault = 1'b1;
        end else if (leaf) begin
          pending.refill_source_seen = 1'b1;
        end
      end

      m_pending[key] = pending;
      m_level_count++;

      if (pending.expected_access_fault) begin
        build_and_emit_completion(key, pending, PTW_SRC_EXP_ACCESS_FAULT,
          pending.bus_error_seen ? PTW_SRC_FAULT_BUS_ERROR : PTW_SRC_FAULT_ACCESS,
          pending.last_pte, 1'b0, tr.cycle,
          pending.access_src, pending.pde_reason,
          pending.pde_l1pmpflg, pending.pde_l2pmpflg,
          pending.pde_direct_accerr_seen);
      end else if (pending.expected_page_fault) begin
        build_and_emit_completion(key, pending, PTW_SRC_EXP_PAGE_FAULT,
          PTW_SRC_FAULT_PAGE, pending.last_pte, 1'b0, tr.cycle);
      end else if (pending.refill_source_seen) begin
        build_and_emit_completion(key, pending, PTW_SRC_EXP_REFILL,
          PTW_SRC_FAULT_NONE, pending.last_pte, 1'b1, tr.cycle);
      end
    end
  endtask

  protected task collect_mem_rsp();
    forever begin
      ptw_mem_txn tr;
      string selected_key;
      string iter_key;
      bit found;
      pending_req_s pending;

      af_ptw_mem_rsp.get(tr);
      m_mem_rsp_count++;
      if (!tr.bus_error)
        continue;

      found = 1'b0;
      if (m_pending.num() == 1) begin
        foreach (m_pending[iter_key]) begin
          selected_key = iter_key;
          pending = m_pending[iter_key];
          found = 1'b1;
        end
      end

      if (found) begin
        pending.asid = m_cur_asid;
        pending.satp_ppn = m_cur_satp_ppn;
        pending.maee = m_cur_maee;
        pending.mprv = m_cur_mprv;
        pending.mxr = m_cur_mxr;
        pending.sum = m_cur_sum;
        pending.mpp = m_cur_mpp;
        pending.priv_mode = m_cur_priv_mode;
        pending.ctx_sample_seen = 1'b1;
        pending.bus_error_seen = 1'b1;
        pending.expected_access_fault = 1'b1;
        pending.access_src = PTW_SRC_ACCESS_SRC_MBUF_BUS_ERROR;
        m_pending[selected_key] = pending;
        build_and_emit_completion(selected_key, pending, PTW_SRC_EXP_ACCESS_FAULT,
          PTW_SRC_FAULT_BUS_ERROR, pending.last_pte, 1'b0, pending.last_cycle,
          pending.access_src, pending.pde_reason, pending.pde_l1pmpflg,
          pending.pde_l2pmpflg, pending.pde_direct_accerr_seen);
      end else begin
        m_probe_gap_count++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_STAGE7_OPEN_GAP kind=bus_error_without_unique_pending addr=0x%010h pending=%0d",
            tr.addr, m_pending.num()))
      end
    end
  endtask

  protected task collect_drop();
    forever begin
      ptw_src_drop_txn tr;
      string key;
      af_drop.get(tr);
      if (tr.pre_existing_exception_grant) begin
        m_pre_existing_exception_grant_count++;
        `uvm_info(get_type_name(),
          $sformatf("PTW_SOURCE_PRE_EXISTING_EXCEPTION_GRANT auxiliary_drop_ignored %s",
            tr.convert2string()),
          UVM_MEDIUM)
        continue;
      end
      emit_drop_expected(tr);
      if (tr.has_key) begin
        if (!resolve_pending_key(tr.key.req_type, tr.key.id,
              key, 1'b1, tr.vpn, 1'b0))
          key = key_string(tr.key.req_type, tr.key.id);
        if (m_pending.exists(key))
          m_pending.delete(key);
      end
    end
  endtask

  protected task collect_abort();
    forever begin
      ptw_src_abort_txn tr;
      af_abort.get(tr);
      m_pde_model.abort_flush();
      clear_pde_pmpflg_shadow();
    end
  endtask

  protected task collect_pde();
    forever begin
      ptw_src_pde_evt_txn tr;

      af_pde.get(tr);
      m_pde_event_count++;
      if (tr.kind == PTW_SRC_PDE_EVT_CLEAR) begin
        m_pde_model.clear();
        clear_pde_pmpflg_shadow();
      end else if (tr.kind == PTW_SRC_PDE_EVT_UPDATE) begin
        pde_update_info_s obs;

        m_pde_update_count++;
        obs.valid = 1'b1;
        obs.committed = 1'b0;
        obs.level = pde_update_level_from_bits(tr.update_level);
        obs.vpn = tr.update_vpn;
        obs.ppn = tr.update_ppn;
        obs.l1pmpflg = tr.update_l1pmpflg;
        obs.l2pmpflg = (obs.level == PTW_SRC_LEVEL_FST) ? 4'h0 : tr.update_l2pmpflg;
        obs.cycle = tr.cycle;
        if ((obs.level == PTW_SRC_LEVEL_FST)
            || (obs.level == PTW_SRC_LEVEL_SCD)) begin
          commit_pde_update_from_observed(obs);
        end else begin
          m_probe_gap_count++;
          `uvm_warning(get_type_name(),
            $sformatf("PTW_SOURCE_REF_PDE_PMPFLG_UPDATE_BAD_LEVEL update_level=0x%0h %s",
              tr.update_level, tr.convert2string()))
        end
      end else if ((tr.kind == PTW_SRC_PDE_EVT_HIT) || (tr.kind == PTW_SRC_PDE_EVT_MISS)) begin
        string key;

        if (tr.direct_accerr
            && pde_direct_accerr_event_is_recent(tr.req_type, tr.id, tr.cycle)) begin
          `uvm_info(get_type_name(),
            $sformatf("PTW_SOURCE_REF_PDE_DUP_DIRECT_ACCERR_IGNORED %s",
              tr.convert2string()),
            UVM_HIGH)
          continue;
        end

        m_deferred_pde_lookup_q.push_back(tr);
        if (resolve_pending_key(tr.req_type, tr.id, key, 1'b1, tr.vpn, 1'b0)
            && m_pending[key].ctx_sample_seen)
          drain_deferred_pde_lookup_events();
      end
    end
  endtask

  protected task collect_csr_write();
    forever begin
      cp0_txn tr;
      af_csr_write.get(tr);
      case (tr.op)
        CP0_WRITE_SATP: begin
          m_cur_asid = tr.wdata[59:44];
          m_cur_satp_ppn = tr.wdata[PPN_WIDTH-1:0];
          m_cur_mxr = tr.mxr;
          m_cur_sum = tr.sum;
          m_cur_mprv = tr.mprv;
          m_cur_mpp = tr.mpp;
          m_cur_maee = tr.maee;
          m_cur_priv_mode = tr.priv_mode;
          m_satp_clear_count++;
          m_pde_model.clear();
          clear_pde_pmpflg_shadow();
        end
        CP0_TLB_ALL_INV: begin
          m_satp_clear_count++;
          m_pde_model.clear();
          clear_pde_pmpflg_shadow();
        end
        CP0_SET_PRIV: m_cur_priv_mode = tr.priv_mode;
        CP0_SET_MXR: m_cur_mxr = tr.mxr;
        CP0_SET_SUM: m_cur_sum = tr.sum;
        CP0_SET_MPRV_MPP: begin
          m_cur_mprv = tr.mprv;
          m_cur_mpp = tr.mpp;
        end
        CP0_SET_MAEE: m_cur_maee = tr.maee;
        default: ;
      endcase
    end
  endtask

  protected task collect_pmp_cfg();
    forever begin
      pmp_txn tr;
      af_pmp_cfg.get(tr);
      if (tr.cfg_update) begin
        foreach (tr.flg[i])
          m_pmp_flg[i] = tr.flg[i];
        m_pmp_clear_count++;
        m_pde_model.clear();
        clear_pde_pmpflg_shadow();
      end
    end
  endtask

  protected task collect_sysmap_cfg();
    forever begin
      sysmap_cfg_txn tr;
      af_sysmap_cfg.get(tr);
      foreach (tr.enable[i]) begin
        m_sysmap_enable[i] = tr.enable[i];
        m_sysmap_base[i] = tr.base[i];
        m_sysmap_mask[i] = tr.mask[i];
        m_sysmap_flg[i] = tr.flg[i];
      end
    end
  endtask

  protected task collect_mem_req();
    forever begin
      ptw_mem_txn tr;
      af_ptw_mem_req.get(tr);
      m_mem_req_count++;
    end
  endtask

  protected task collect_mem_drop();
    forever begin
      ptw_mem_txn tr;
      af_ptw_mem_drop.get(tr);
      m_mem_drop_count++;
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    while (m_deferred_pde_lookup_q.size() > 0) begin
      m_probe_gap_count++;
      `uvm_warning(get_type_name(),
        $sformatf("PTW_SOURCE_REF_PDE_DEFERRED_LOOKUP_UNMATCHED %s",
          m_deferred_pde_lookup_q[0].convert2string()))
      void'(m_deferred_pde_lookup_q.pop_front());
    end

    finalize_pde_update_matching();

    `uvm_info(get_type_name(),
      $sformatf({"PTW_SOURCE_REF_SUMMARY stage=7 req_accept=%0d expected=%0d ",
                 "refill=%0d page_fault=%0d access_fault=%0d drop=%0d ",
                 "pending=%0d duplicate_req=%0d multi_pending=%0d ",
                 "mem_req=%0d mem_rsp=%0d ",
                 "mem_drop=%0d ctx=%0d level=%0d pde=%0d pde_update=%0d ",
                 "probe_gap=%0d satp_clear=%0d pmp_clear=%0d ",
                 "asid_current_refill=%0d context_current_sample=%0d maee0_sysmap=%0d ",
                 "degrade_1g_2m=%0d degrade_1g_4k=%0d degrade_2m_4k=%0d ",
                 "pre_existing_exception_grant=%0d ",
                 "pde_l1_pmp_deny_miss=%0d pde_l2_l1pmp_deny_accerr=%0d ",
                 "pde_l2_l2pmp_deny_accerr=%0d pde_pmpflg_update_l1=%0d ",
                 "pde_pmpflg_update_l2=%0d pde_mmode_bypass=%0d ",
                 "pde_mmode_lock_deny=%0d pde_update_match=%0d ",
                 "pde_update_mismatch=%0d pde_duplicate_direct_accerr=%0d provisional=0"},
        m_req_accept_count, m_expected_count, m_refill_expected_count,
        m_page_fault_expected_count, m_access_fault_expected_count,
        m_drop_expected_count, m_pending.num(), m_duplicate_req_count,
        m_multi_pending_count,
        m_mem_req_count, m_mem_rsp_count, m_mem_drop_count, m_ctx_count,
        m_level_count, m_pde_event_count, m_pde_update_count,
        m_probe_gap_count, m_satp_clear_count, m_pmp_clear_count,
        m_asid_current_refill_count, m_context_current_sample_count,
        m_maee0_sysmap_refill_count,
        m_maee0_degrade_1g_to_2m_count, m_maee0_degrade_1g_to_4k_count,
        m_maee0_degrade_2m_to_4k_count,
        m_pre_existing_exception_grant_count,
        m_pde_l1_pmp_deny_miss_count,
        m_pde_l2_l1pmp_deny_accerr_count,
        m_pde_l2_l2pmp_deny_accerr_count,
        m_pde_pmpflg_update_l1_count,
        m_pde_pmpflg_update_l2_count,
        m_pde_mmode_bypass_count,
        m_pde_mmode_lock_deny_count,
        m_pde_update_match_count,
        m_pde_update_mismatch_count,
        m_pde_duplicate_direct_accerr_event_count),
      UVM_NONE)

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=ref_model stage=7 status=event_driven_no_translate current_context_and_maee_degrade=1 provisional=0",
      UVM_NONE)
  endfunction

endclass : ptw_source_ref_model

`endif // PTW_SOURCE_REF_MODEL_SVH
