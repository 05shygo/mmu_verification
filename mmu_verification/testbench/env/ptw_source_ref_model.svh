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
    ppn_t                  satp_ppn;
    bit                    maee;
    bit                    mprv;
    bit                    mxr;
    bit                    sum;
    logic [1:0]            mpp;
    logic [1:0]            priv_mode;
    int unsigned           accept_cycle;
    int unsigned           last_cycle;
    ptw_src_level_e        last_level;
    pte_t                  last_pte;
    logic [39:0]           last_pte_pa;
    ptw_src_page_size_e    expected_page_size;
    bit                    expected_page_fault;
    bit                    expected_access_fault;
    bit                    bus_error_seen;
    bit                    pmp_deny_seen;
    bit                    refill_source_seen;
    bit                    expected_emitted;
    bit                    drop_emitted;
  } pending_req_s;

  pending_req_s m_pending[string];
  bit [3:0]     m_pmp_flg [8];
  bit           m_sysmap_enable [8];
  bit [27:0]    m_sysmap_base [8];
  bit [27:0]    m_sysmap_mask [8];
  bit [4:0]     m_sysmap_flg [8];

  int unsigned m_req_accept_count;
  int unsigned m_expected_count;
  int unsigned m_refill_expected_count;
  int unsigned m_page_fault_expected_count;
  int unsigned m_access_fault_expected_count;
  int unsigned m_drop_expected_count;
  int unsigned m_duplicate_req_count;
  int unsigned m_mem_req_count;
  int unsigned m_mem_rsp_count;
  int unsigned m_mem_drop_count;
  int unsigned m_ctx_count;
  int unsigned m_level_count;
  int unsigned m_pde_event_count;
  int unsigned m_pde_update_count;
  int unsigned m_probe_gap_count;

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
      "PTW_SOURCE_CLOSURE component=ref_model stage=4 status=created expected=0 provisional=0",
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
    output string             key
  );
    string candidate;
    string iter_key;
    int unsigned match_count;

    key = key_string(req_type, id);
    if (m_pending.exists(key))
      return 1'b1;

    match_count = 0;
    foreach (m_pending[iter_key]) begin
      if ((req_type != PTW_SRC_TYPE_UNKNOWN)
          && (m_pending[iter_key].req_type != req_type))
        continue;
      candidate = iter_key;
      match_count++;
    end

    if (match_count == 1) begin
      key = candidate;
      return 1'b1;
    end

    m_probe_gap_count++;
    `uvm_warning(get_type_name(),
      $sformatf("PTW_STAGE4_OPEN_GAP kind=ambiguous_pending_key type=%s id=0x%02h match_count=%0d pending=%0d",
        req_type.name(), id, match_count, m_pending.num()))
    return 1'b0;
  endfunction

  protected function bit is_leaf(input pte_t raw_pte);
    return raw_pte[PTE_R] || raw_pte[PTE_X];
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
    if (!raw_pte[PTE_V])
      return 1'b1;
    if (is_write_only_fault(raw_pte, pending.mxr))
      return 1'b1;
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

  protected function logic [4:0] ext_attr_for_refill(
    input pending_req_s pending,
    input pte_t raw_pte,
    input ptw_src_page_size_e page_size
  );
    bit hit;
    logic [4:0] attr;

    if (pending.maee)
      return raw_pte[63:59];

    attr = sysmap_attr(raw_pte[PTE_PPN_LSB +: PPN_WIDTH], hit);
    if (!hit)
      `uvm_info(get_type_name(),
        $sformatf("PTW_SOURCE_SYSMAP_DEFAULT key=%s page_size=%s ppn=0x%07h attr=0x%02h",
          key_string(pending.req_type, pending.id), page_size.name(),
          raw_pte[PTE_PPN_LSB +: PPN_WIDTH], attr),
        UVM_HIGH)
    return attr;
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
    input int unsigned cycle
  );
    ptw_src_expected_rsp_txn exp;
    ptw_src_page_size_e pgs;
    ppn_t ppn;
    logic [4:0] ext_attr;

    exp = ptw_src_expected_rsp_txn::type_id::create("ptw_expected");
    exp.cycle = cycle;
    exp.kind = kind;
    exp.req_type = pending.req_type;
    exp.id = pending.id;
    exp.vpn = pending.vpn;
    exp.asid = pending.asid;
    exp.target = target_from_type(pending.req_type);
    exp.target_l2tlb = 1'b1;
    exp.target_l1i = (pending.req_type == PTW_SRC_TYPE_FETCH);
    exp.target_l1d = (pending.req_type == PTW_SRC_TYPE_LOAD)
                  || (pending.req_type == PTW_SRC_TYPE_STORE);
    exp.target_pfu = (pending.req_type == PTW_SRC_TYPE_PFU);
    exp.fault_kind = fault_kind;
    exp.drop_reason = PTW_SRC_DROP_NONE;
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
      pgs = pending.expected_page_size;
      ppn = raw_pte[PTE_PPN_LSB +: PPN_WIDTH];
      ext_attr = ext_attr_for_refill(pending, raw_pte, pgs);
      exp.page_size = pgs;
      exp.ppn = ppn;
      exp.global_bit = raw_pte[PTE_G];
      exp.flg = ptw_src_make_refill_flg(ext_attr, raw_pte);
      exp.raw_tag = ptw_src_make_refill_tag(pending.vpn, pending.asid, pgs, raw_pte[PTE_G]);
      exp.raw_data = ptw_src_make_refill_data(ppn, ext_attr, raw_pte);
      exp.refill_valid = 1'b1;
      exp.page_fault = 1'b0;
      exp.access_fault = 1'b0;
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

      af_req_accept.get(tr);
      key = key_string(tr.req_type, tr.id);
      if (m_pending.exists(key)) begin
        m_duplicate_req_count++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_SOURCE_REF_ILLEGAL duplicate_request key=%s old_vpn=0x%07h new_vpn=0x%07h",
            key, m_pending[key].vpn, tr.vpn))
        continue;
      end

      pending.valid = 1'b1;
      pending.req_type = tr.req_type;
      pending.id = tr.id;
      pending.vpn = tr.vpn;
      pending.asid = tr.asid;
      pending.satp_ppn = '0;
      pending.maee = 1'b1;
      pending.mprv = 1'b0;
      pending.mxr = 1'b0;
      pending.sum = 1'b0;
      pending.mpp = PRIV_M;
      pending.priv_mode = PRIV_S;
      pending.accept_cycle = tr.cycle;
      pending.last_cycle = tr.cycle;
      pending.last_level = PTW_SRC_LEVEL_NONE;
      pending.last_pte = '0;
      pending.last_pte_pa = '0;
      pending.expected_page_size = PTW_SRC_PGS_NONE;
      pending.expected_page_fault = 1'b0;
      pending.expected_access_fault = 1'b0;
      pending.bus_error_seen = 1'b0;
      pending.pmp_deny_seen = 1'b0;
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
      if (resolve_pending_key(tr.req_type, tr.id, key)) begin
        pending = m_pending[key];
        pending.asid = tr.asid;
        pending.satp_ppn = tr.satp_ppn;
        pending.maee = tr.maee;
        pending.mprv = tr.mprv;
        pending.mxr = tr.mxr;
        pending.sum = tr.sum;
        pending.mpp = tr.mpp;
        pending.priv_mode = tr.priv_mode;
        pending.last_cycle = tr.cycle;
        m_pending[key] = pending;
      end
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

      af_level.get(tr);
      if (!resolve_pending_key(tr.req_type, tr.id, key)) begin
        m_level_count++;
        continue;
      end

      pending = m_pending[key];
      pending.last_cycle = tr.cycle;
      if (tr.level != PTW_SRC_LEVEL_NONE)
        pending.last_level = tr.level;
      if (tr.pte_pa != '0)
        pending.last_pte_pa = tr.pte_pa;

      if (tr.pmp_deny) begin
        pending.pmp_deny_seen = 1'b1;
        pending.expected_access_fault = 1'b1;
      end
      if (tr.access_fault) begin
        pending.expected_access_fault = 1'b1;
      end

      if (tr.mbuf_data_vld) begin
        pending.last_pte = tr.pte_data;
        leaf = is_leaf(tr.pte_data);
        if (leaf) begin
          pending.expected_page_size = page_size_from_level(tr.level);
          page_fault = leaf_page_fault(pending, tr.pte_data, tr.level);
        end else begin
          pending.expected_page_size = PTW_SRC_PGS_NONE;
          page_fault = nonleaf_page_fault(pending, tr.pte_data, tr.level);
          if (!page_fault && ((tr.level == PTW_SRC_LEVEL_FST) || (tr.level == PTW_SRC_LEVEL_SCD))) begin
            m_pde_model.queue_update(tr.level, pending.vpn,
              tr.pte_data[PTE_PPN_LSB +: PPN_WIDTH]);
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
          pending.last_pte, 1'b0, tr.cycle);
      end else if (pending.expected_page_fault) begin
        build_and_emit_completion(key, pending, PTW_SRC_EXP_PAGE_FAULT,
          PTW_SRC_FAULT_PAGE, pending.last_pte, 1'b0, tr.cycle);
      end else if (pending.refill_source_seen) begin
        build_and_emit_completion(key, pending, PTW_SRC_EXP_REFILL,
          PTW_SRC_FAULT_NONE, pending.last_pte, 1'b1, tr.cycle);
      end

      m_pde_model.tick();
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
        pending.bus_error_seen = 1'b1;
        pending.expected_access_fault = 1'b1;
        m_pending[selected_key] = pending;
        build_and_emit_completion(selected_key, pending, PTW_SRC_EXP_ACCESS_FAULT,
          PTW_SRC_FAULT_BUS_ERROR, pending.last_pte, 1'b0, pending.last_cycle);
      end else begin
        m_probe_gap_count++;
        `uvm_warning(get_type_name(),
          $sformatf("PTW_STAGE4_OPEN_GAP kind=bus_error_without_unique_pending addr=0x%010h pending=%0d",
            tr.addr, m_pending.num()))
      end
    end
  endtask

  protected task collect_drop();
    forever begin
      ptw_src_drop_txn tr;
      string key;
      af_drop.get(tr);
      emit_drop_expected(tr);
      if (tr.has_key) begin
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
    end
  endtask

  protected task collect_pde();
    forever begin
      ptw_src_pde_evt_txn tr;
      ptw_src_level_e hit_level;
      ppn_t hit_ppn;
      bit l1_hit;
      bit l2_hit;

      af_pde.get(tr);
      m_pde_event_count++;
      if (tr.kind == PTW_SRC_PDE_EVT_CLEAR) begin
        m_pde_model.clear();
      end else if (tr.kind == PTW_SRC_PDE_EVT_UPDATE) begin
        m_pde_update_count++;
        m_pde_model.commit_update(
          (tr.update_level == 2'b10) ? PTW_SRC_LEVEL_FST : PTW_SRC_LEVEL_SCD,
          tr.update_vpn,
          tr.update_ppn);
      end else if ((tr.kind == PTW_SRC_PDE_EVT_HIT) || (tr.kind == PTW_SRC_PDE_EVT_MISS)) begin
        bit lookup_hit;
        lookup_hit = m_pde_model.lookup(tr.vpn, hit_level, hit_ppn, l1_hit, l2_hit);
      end
    end
  endtask

  protected task collect_csr_write();
    forever begin
      cp0_txn tr;
      af_csr_write.get(tr);
      if ((tr.op == CP0_WRITE_SATP) || (tr.op == CP0_TLB_ALL_INV))
        m_pde_model.clear();
    end
  endtask

  protected task collect_pmp_cfg();
    forever begin
      pmp_txn tr;
      af_pmp_cfg.get(tr);
      if (tr.cfg_update) begin
        foreach (tr.flg[i])
          m_pmp_flg[i] = tr.flg[i];
        m_pde_model.clear();
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
    `uvm_info(get_type_name(),
      $sformatf({"PTW_SOURCE_REF_SUMMARY stage=4 req_accept=%0d expected=%0d ",
                 "refill=%0d page_fault=%0d access_fault=%0d drop=%0d ",
                 "pending=%0d duplicate_req=%0d mem_req=%0d mem_rsp=%0d ",
                 "mem_drop=%0d ctx=%0d level=%0d pde=%0d pde_update=%0d ",
                 "probe_gap=%0d provisional=0"},
        m_req_accept_count, m_expected_count, m_refill_expected_count,
        m_page_fault_expected_count, m_access_fault_expected_count,
        m_drop_expected_count, m_pending.num(), m_duplicate_req_count,
        m_mem_req_count, m_mem_rsp_count, m_mem_drop_count, m_ctx_count,
        m_level_count, m_pde_event_count, m_pde_update_count,
        m_probe_gap_count),
      UVM_NONE)

    `uvm_info(get_type_name(),
      "PTW_SOURCE_CLOSURE component=ref_model stage=4 status=event_driven_no_translate provisional=0",
      UVM_NONE)
  endfunction

endclass : ptw_source_ref_model

`endif // PTW_SOURCE_REF_MODEL_SVH
