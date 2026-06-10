// =============================================================================
// MMU UVM Verification - testbench/env/mmu_l2tlb_txn_shadow.svh
// Phase 6C: transaction-level L2TLB shadow / ownership helper.
//
// This helper intentionally models visible L2TLB transaction behavior, not
// cycle-accurate replacement, RRPV, wbuf, or exact victim state.
// =============================================================================
`ifndef MMU_L2TLB_TXN_SHADOW_SVH
`define MMU_L2TLB_TXN_SHADOW_SVH

typedef enum int unsigned {
  L2TLB_MISMATCH_RTL_BUG,
  L2TLB_MISMATCH_UVM_BUG,
  L2TLB_MISMATCH_SPEC_GAP,
  L2TLB_MISMATCH_TOOLING_ISSUE,
  L2TLB_MISMATCH_APPROVED_WAIVER
} l2tlb_mismatch_category_e;

typedef enum int unsigned {
  L2TLB_OWNER_UNKNOWN,
  L2TLB_OWNER_ITLB,
  L2TLB_OWNER_DTLB_LOAD,
  L2TLB_OWNER_DTLB_STORE,
  L2TLB_OWNER_PFU,
  L2TLB_OWNER_TLBOP
} l2tlb_owner_e;

typedef enum int unsigned {
  L2TLB_RSP_NORMAL,
  L2TLB_RSP_PAGE_FAULT,
  L2TLB_RSP_ACCESS_FAULT,
  L2TLB_RSP_NO_PAVLD,
  L2TLB_RSP_PFU_ERROR,
  L2TLB_RSP_ILLEGAL
} l2tlb_rsp_class_e;

class mmu_l2tlb_txn_shadow extends uvm_object;

  `uvm_object_utils(mmu_l2tlb_txn_shadow)

  localparam int unsigned L2_SHADOW_ENTRY_DEPTH = 1024;
  localparam int unsigned L2_PTW_SHADOW_DEPTH   = 16;
  localparam int unsigned L2_INV_HISTORY_DEPTH  = 16;
  localparam int unsigned PTW_ID_WIDTH          = 7;

  typedef struct {
    bit              valid;
    bit [26:0]       vpn;
    bit [15:0]       asid;
    bit              global_bit;
    bit [2:0]        page_size;
    bit [27:0]       ppn;
    bit [13:0]       flags;
    l2tlb_owner_e    source_op;
    longint unsigned entry_epoch;
    longint unsigned update_cycle;
    string           update_reason;
  } l2_entry_t;

  typedef struct {
    bit              valid;
    bit [PTW_ID_WIDTH-1:0] id;
    bit [2:0]        req_type;
    bit [26:0]       vpn;
    bit [15:0]       asid;
    bit [27:0]       satp_ppn;
    bit [1:0]        priv_mode;
    bit              mxr;
    bit              sum;
    bit              mprv;
    bit [1:0]        mpp;
    l2tlb_owner_e    owner;
    longint unsigned epoch;
    longint unsigned req_cycle;
    time             req_time;
  } ptw_owner_t;

  typedef struct {
    bit              valid;
    lsu_inv_kind_e   kind;
    bit [26:0]       vpn;
    bit [15:0]       asid;
    longint unsigned epoch;
    longint unsigned cycle;
  } inv_event_t;

  l2_entry_t  m_entries[L2_SHADOW_ENTRY_DEPTH];
  ptw_owner_t m_ptw[L2_PTW_SHADOW_DEPTH];
  inv_event_t m_inv_history[L2_INV_HISTORY_DEPTH];

  longint unsigned m_epoch;
  longint unsigned m_ptw_abort_epoch;
  longint unsigned m_cycle;
  longint unsigned m_reset_epoch_count;
  longint unsigned m_abort_epoch_count;
  longint unsigned m_control_epoch_count;
  longint unsigned m_last_abort_cycle;
  longint unsigned m_orphan_drain_until;  // accept orphans silently until this cycle

  int unsigned m_ptw_req_seen;
  int unsigned m_ptw_data_seen;
  int unsigned m_ptw_fault_seen;
  int unsigned m_ptw_stale_seen;
  int unsigned m_ptw_orphan_seen;
  int unsigned m_l2_hit_seen;
  int unsigned m_l2_miss_seen;
  int unsigned m_l2_hit_mismatch;
  int unsigned m_l2_hit_waived;
  int unsigned m_pfu_seen;
  int unsigned m_pfu_payload_ignore_seen;
  int unsigned m_inv_seen;
  int unsigned m_cp0_all_inv_seen;
  int unsigned m_mismatch;
  int unsigned m_waived_or_future;
  int unsigned m_ptw_disabled_itlb_seen;
  int unsigned m_ptw_disabled_dtlb_load_seen;
  int unsigned m_ptw_disabled_dtlb_store_seen;
  int unsigned m_ptw_disabled_pfu_seen;
  int unsigned m_ptw_pgflt_itlb_seen;
  int unsigned m_ptw_pgflt_dtlb_load_seen;
  int unsigned m_ptw_pgflt_dtlb_store_seen;
  int unsigned m_ptw_pgflt_pfu_seen;
  int unsigned m_ptw_accerr_itlb_seen;
  int unsigned m_ptw_accerr_dtlb_load_seen;
  int unsigned m_ptw_accerr_dtlb_store_seen;
  int unsigned m_ptw_accerr_pfu_seen;
  int unsigned m_detail_log_limit;
  int unsigned m_source_result_log_count;
  int unsigned m_payload_ignore_log_count;

  function new(string name = "mmu_l2tlb_txn_shadow");
    super.new(name);
    reset_state("constructor");
  endfunction

  function void reset_state(string reason = "reset");
    for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++)
      m_entries[i].valid = 1'b0;
    for (int i = 0; i < L2_PTW_SHADOW_DEPTH; i++)
      m_ptw[i].valid = 1'b0;
    for (int i = 0; i < L2_INV_HISTORY_DEPTH; i++)
      m_inv_history[i].valid = 1'b0;

    m_epoch = 0;
    m_ptw_abort_epoch = 0;
    m_cycle = 0;
    m_reset_epoch_count = 0;
    m_abort_epoch_count = 0;
    m_control_epoch_count = 0;
    m_last_abort_cycle = 0;
    m_orphan_drain_until = 0;
    m_ptw_req_seen = 0;
    m_ptw_data_seen = 0;
    m_ptw_fault_seen = 0;
    m_ptw_stale_seen = 0;
    m_ptw_orphan_seen = 0;
    m_l2_hit_seen = 0;
    m_l2_miss_seen = 0;
    m_l2_hit_mismatch = 0;
    m_l2_hit_waived = 0;
    m_pfu_seen = 0;
    m_pfu_payload_ignore_seen = 0;
    m_inv_seen = 0;
    m_cp0_all_inv_seen = 0;
    m_mismatch = 0;
    m_waived_or_future = 0;
    m_ptw_disabled_itlb_seen = 0;
    m_ptw_disabled_dtlb_load_seen = 0;
    m_ptw_disabled_dtlb_store_seen = 0;
    m_ptw_disabled_pfu_seen = 0;
    m_ptw_pgflt_itlb_seen = 0;
    m_ptw_pgflt_dtlb_load_seen = 0;
    m_ptw_pgflt_dtlb_store_seen = 0;
    m_ptw_pgflt_pfu_seen = 0;
    m_ptw_accerr_itlb_seen = 0;
    m_ptw_accerr_dtlb_load_seen = 0;
    m_ptw_accerr_dtlb_store_seen = 0;
    m_ptw_accerr_pfu_seen = 0;
    m_source_result_log_count = 0;
    m_payload_ignore_log_count = 0;
    m_detail_log_limit = 64;
    void'($value$plusargs("PHASE6C_L2_DETAIL_LOG_LIMIT=%0d", m_detail_log_limit));
    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_SHADOW_RESET] reason=%s epoch=%0d", reason, m_epoch),
      UVM_HIGH)
  endfunction

  function string category_name(l2tlb_mismatch_category_e cat);
    case (cat)
      L2TLB_MISMATCH_RTL_BUG:         return "RTL bug";
      L2TLB_MISMATCH_UVM_BUG:         return "UVM bug";
      L2TLB_MISMATCH_SPEC_GAP:        return "spec gap";
      L2TLB_MISMATCH_TOOLING_ISSUE:   return "tooling issue";
      L2TLB_MISMATCH_APPROVED_WAIVER: return "approved waiver";
      default:                        return "unknown";
    endcase
  endfunction

  function string owner_name(l2tlb_owner_e owner);
    case (owner)
      L2TLB_OWNER_ITLB:       return "ITLB";
      L2TLB_OWNER_DTLB_LOAD:  return "DTLB_LOAD";
      L2TLB_OWNER_DTLB_STORE: return "DTLB_STORE";
      L2TLB_OWNER_PFU:        return "PFU";
      L2TLB_OWNER_TLBOP:      return "TLBOP";
      default:                return "UNKNOWN";
    endcase
  endfunction

  function string rsp_class_name(l2tlb_rsp_class_e cls);
    case (cls)
      L2TLB_RSP_NORMAL:       return "NORMAL";
      L2TLB_RSP_PAGE_FAULT:   return "PAGE_FAULT";
      L2TLB_RSP_ACCESS_FAULT: return "ACCESS_FAULT";
      L2TLB_RSP_NO_PAVLD:     return "NO_PAVLD";
      L2TLB_RSP_PFU_ERROR:    return "PFU_ERROR";
      L2TLB_RSP_ILLEGAL:      return "ILLEGAL";
      default:                return "UNKNOWN";
    endcase
  endfunction

  function l2tlb_owner_e owner_from_type(bit [2:0] typ);
    case (typ)
      3'b011: return L2TLB_OWNER_ITLB;
      3'b010: return L2TLB_OWNER_DTLB_LOAD;
      3'b110: return L2TLB_OWNER_DTLB_STORE;
      3'b100: return L2TLB_OWNER_PFU;
      3'b001: return L2TLB_OWNER_TLBOP;
      default: return L2TLB_OWNER_UNKNOWN;
    endcase
  endfunction

  function bit page_match(
    input bit [26:0] entry_vpn,
    input bit [2:0]  page_size,
    input bit [26:0] req_vpn
  );
    case (page_size)
      3'b100: return (entry_vpn[26:18] == req_vpn[26:18]); // 1G
      3'b010: return (entry_vpn[26:9]  == req_vpn[26:9]);  // 2M
      default: return (entry_vpn == req_vpn);               // 4K/unknown
    endcase
  endfunction

  function bit asid_match(input l2_entry_t ent, input bit [15:0] asid);
    return ent.global_bit || (ent.asid == asid);
  endfunction

  function int find_entry(input bit [26:0] vpn, input bit [15:0] asid);
    for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++) begin
      if (m_entries[i].valid && page_match(m_entries[i].vpn, m_entries[i].page_size, vpn)
          && asid_match(m_entries[i], asid))
        return i;
    end
    return -1;
  endfunction

  function int first_free_entry();
    for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++) begin
      if (!m_entries[i].valid)
        return i;
    end
    return -1;
  endfunction

  function void bump_epoch(string reason, input bit clear_ptw = 1'b1);
    m_epoch++;

    if (clear_ptw) begin
      m_ptw_abort_epoch++;
      for (int i = 0; i < L2_PTW_SHADOW_DEPTH; i++)
        m_ptw[i].valid = 1'b0;
    end
    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_EPOCH] reason=%s epoch=%0d ptw_abort_epoch=%0d clear_ptw=%0b cycle=%0d",
        reason, m_epoch, m_ptw_abort_epoch, clear_ptw, m_cycle),
      UVM_MEDIUM)
  endfunction

  function void on_reset();
    m_reset_epoch_count++;
    for (int i = 0; i < L2_PTW_SHADOW_DEPTH; i++)
      m_ptw[i].valid = 1'b0;
    bump_epoch("reset");
    invalidate_all("reset");
    // Drain window: in-flight PTW completions after reset are expected orphans.
    // RTL resets the PTW pipeline but completions already issued may still arrive.
    m_orphan_drain_until = m_cycle + 500;
  endfunction

  function void on_abort(string reason = "abort");
    m_abort_epoch_count++;
    m_last_abort_cycle = m_cycle;
    bump_epoch(reason);
    // Drain window: in-flight completions after abort are expected.
    m_orphan_drain_until = m_cycle + 200;
  endfunction

  function void on_control_epoch(string reason = "control_epoch");
    m_control_epoch_count++;
    // RTL does NOT abort in-flight PTW on tlboper_utlb_clr; keep PTW entries alive
    bump_epoch(reason, .clear_ptw(1'b0));
    invalidate_all(reason);
    // SATP switch may race with in-flight PTW completions in some scenarios.
    if (m_cycle + 100 > m_orphan_drain_until)
      m_orphan_drain_until = m_cycle + 100;
  endfunction

  function void invalidate_all(string reason = "INVALL");
    for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++) begin
      if (m_entries[i].valid) begin
        m_entries[i].valid = 1'b0;
        m_entries[i].update_reason = reason;
        m_entries[i].update_cycle = m_cycle;
      end
    end
  endfunction

  function void on_lsu_invalidate(lsu_inv_kind_e kind, bit [26:0] vpn, bit [15:0] asid);
    int hist_idx;
    m_inv_seen++;
    hist_idx = int'(m_inv_seen % L2_INV_HISTORY_DEPTH);
    m_inv_history[hist_idx].valid = 1'b1;
    m_inv_history[hist_idx].kind = kind;
    m_inv_history[hist_idx].vpn = vpn;
    m_inv_history[hist_idx].asid = asid;
    m_inv_history[hist_idx].epoch = m_epoch;
    m_inv_history[hist_idx].cycle = m_cycle;

    case (kind)
      INV_ALL: begin
        invalidate_all("LSU_INV_ALL");
      end
      INV_VA_ALL: begin
        for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++) begin
          if (m_entries[i].valid && page_match(m_entries[i].vpn, m_entries[i].page_size, vpn)) begin
            m_entries[i].valid = 1'b0;
            m_entries[i].update_reason = "LSU_INV_VA_ALL";
            m_entries[i].update_cycle = m_cycle;
          end
        end
      end
      INV_ASID_ALL: begin
        for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++) begin
          if (m_entries[i].valid && !m_entries[i].global_bit && (m_entries[i].asid == asid)) begin
            m_entries[i].valid = 1'b0;
            m_entries[i].update_reason = "LSU_INV_ASID_ALL";
            m_entries[i].update_cycle = m_cycle;
          end
        end
      end
      INV_VA_ASID: begin
        for (int i = 0; i < L2_SHADOW_ENTRY_DEPTH; i++) begin
          if (m_entries[i].valid && !m_entries[i].global_bit
              && (m_entries[i].asid == asid)
              && page_match(m_entries[i].vpn, m_entries[i].page_size, vpn)) begin
            m_entries[i].valid = 1'b0;
            m_entries[i].update_reason = "LSU_INV_VA_ASID";
            m_entries[i].update_cycle = m_cycle;
          end
        end
      end
      default: begin
        record_mismatch(L2TLB_MISMATCH_UVM_BUG, "LSU_INV_KIND",
          vpn, asid, 3'b000, L2TLB_OWNER_TLBOP, "legal INV kind", kind.name());
      end
    endcase

    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_INV] kind=%s vpn=0x%07h asid=0x%04h epoch=%0d cycle=%0d",
        kind.name(), vpn, asid, m_epoch, m_cycle),
      UVM_MEDIUM)
  endfunction

  function void on_cp0_all_inv();
    m_cp0_all_inv_seen++;
    invalidate_all("CP0_TLB_ALL_INV");
    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_INV] kind=CP0_TLB_ALL_INV epoch=%0d cycle=%0d",
        m_epoch, m_cycle),
      UVM_MEDIUM)
  endfunction

  function int find_ptw(input bit [PTW_ID_WIDTH-1:0] id, input bit [2:0] typ);
    for (int i = 0; i < L2_PTW_SHADOW_DEPTH; i++) begin
      if (m_ptw[i].valid && (m_ptw[i].id == id) && (m_ptw[i].req_type == typ))
        return i;
    end
    return -1;
  endfunction

  function int first_free_ptw();
    for (int i = 0; i < L2_PTW_SHADOW_DEPTH; i++) begin
      if (!m_ptw[i].valid)
        return i;
    end
    return -1;
  endfunction

  function void on_ptw_request(
    input bit [PTW_ID_WIDTH-1:0] id,
    input bit [2:0] typ,
    input bit [26:0] vpn,
    input bit [15:0] asid,
    input bit [27:0] satp_ppn,
    input bit [1:0] priv_mode,
    input bit mxr,
    input bit sum,
    input bit mprv,
    input bit [1:0] mpp
  );
    int idx;
    idx = find_ptw(id, typ);
    if (idx < 0)
      idx = first_free_ptw();
    if (idx < 0) begin
      record_mismatch(L2TLB_MISMATCH_RTL_BUG, "PTW_OWNER_OVERFLOW",
        vpn, asid, typ, owner_from_type(typ), "free PTW owner slot", "none");
      idx = int'(id % L2_PTW_SHADOW_DEPTH);
    end

    m_ptw_req_seen++;
    m_ptw[idx].valid = 1'b1;
    m_ptw[idx].id = id;
    m_ptw[idx].req_type = typ;
    m_ptw[idx].vpn = vpn;
    m_ptw[idx].asid = asid;
    m_ptw[idx].satp_ppn = satp_ppn;
    m_ptw[idx].priv_mode = priv_mode;
    m_ptw[idx].mxr = mxr;
    m_ptw[idx].sum = sum;
    m_ptw[idx].mprv = mprv;
    m_ptw[idx].mpp = mpp;
    m_ptw[idx].owner = owner_from_type(typ);
    m_ptw[idx].epoch = m_ptw_abort_epoch;
    m_ptw[idx].req_cycle = m_cycle;
    m_ptw[idx].req_time = $time;

    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_PTW_REQ] id=0x%02h type=0x%0h owner=%s vpn=0x%07h asid=0x%04h satp=0x%07h epoch=%0d cycle=%0d",
        id, typ, owner_name(m_ptw[idx].owner), vpn, asid, satp_ppn, m_epoch, m_cycle),
      UVM_HIGH)
  endfunction

  function void insert_or_update_entry(
    input bit [26:0] vpn,
    input bit [15:0] asid,
    input bit global_bit,
    input bit [2:0] page_size,
    input bit [27:0] ppn,
    input bit [13:0] flags,
    input l2tlb_owner_e owner,
    input string reason
  );
    int idx;
    idx = find_entry(vpn, asid);
    if (idx < 0)
      idx = first_free_entry();
    if (idx < 0) begin
      m_waived_or_future++;
      idx = int'(m_cycle % L2_SHADOW_ENTRY_DEPTH);
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_L2_SHADOW_FUTURE_REPLACEMENT] exact victim not modeled; overwrite slot=%0d vpn=0x%07h asid=0x%04h reason=%s",
          idx, vpn, asid, reason),
        UVM_LOW)
    end

    m_entries[idx].valid = 1'b1;
    m_entries[idx].vpn = vpn;
    m_entries[idx].asid = asid;
    m_entries[idx].global_bit = global_bit;
    m_entries[idx].page_size = page_size;
    m_entries[idx].ppn = ppn;
    m_entries[idx].flags = flags;
    m_entries[idx].source_op = owner;
    m_entries[idx].entry_epoch = m_epoch;
    m_entries[idx].update_cycle = m_cycle;
    m_entries[idx].update_reason = reason;

    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_ENTRY_UPDATE] reason=%s idx=%0d owner=%s vpn=0x%07h asid=0x%04h g=%0b pgs=0x%0h ppn=0x%07h flg=0x%04h epoch=%0d cycle=%0d",
        reason, idx, owner_name(owner), vpn, asid, global_bit, page_size, ppn,
        flags, m_epoch, m_cycle),
      UVM_HIGH)
  endfunction

  function void on_ptw_completion(
    input bit cmplt,
    input bit data_vld,
    input bit pgflt,
    input bit acc_err,
    input bit [PTW_ID_WIDTH-1:0] id,
    input bit [2:0] typ,
    input bit [47:0] tag,
    input bit [41:0] data,
    input bit [13:0] flags
  );
    int idx;
    l2tlb_rsp_class_e cls;

    if (!cmplt && !data_vld && !pgflt && !acc_err)
      return;

    idx = find_ptw(id, typ);
    if (idx < 0) begin
      m_ptw_orphan_seen++;
      // Drain window: after reset/abort/SATP-switch, the shadow clears PTW
      // tracking but RTL completions already in flight may still arrive.
      // These are NOT bugs — RTL correctly discards them.
      if (m_cycle < m_orphan_drain_until) begin
        `uvm_info(get_type_name(),
          $sformatf("[PHASE6C_L2_ORPHAN_DRAIN] id=0x%02h type=0x%0h owner=%s vpn=0x%07h cycle=%0d drain_until=%0d",
            id, typ, owner_name(owner_from_type(typ)), tag[46:20], m_cycle, m_orphan_drain_until),
          UVM_HIGH)
        return;
      end
      // Outside drain window: this is a real orphan — the shadow should
      // have a record of this PTW request but doesn't.
      record_mismatch(L2TLB_MISMATCH_RTL_BUG, "PTW_ORPHAN_COMPLETION",
        tag[46:20], '0, typ, owner_from_type(typ),
        "outstanding PTW owner for completion", "none");
      return;
    end

    if (m_ptw[idx].epoch != m_ptw_abort_epoch) begin
      m_ptw_stale_seen++;
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_L2_STALE_PTW] id=0x%02h type=0x%0h owner=%s req_ptw_abort_epoch=%0d cur_ptw_abort_epoch=%0d vpn=0x%07h class=%s",
          id, typ, owner_name(m_ptw[idx].owner), m_ptw[idx].epoch, m_ptw_abort_epoch,
          m_ptw[idx].vpn, (data_vld ? "DATA" : (pgflt ? "PGFLT" : "ACCERR"))),
        UVM_MEDIUM)
      m_ptw[idx].valid = 1'b0;
      return;
    end

    cls = data_vld ? L2TLB_RSP_NORMAL :
          pgflt    ? L2TLB_RSP_PAGE_FAULT :
          acc_err  ? L2TLB_RSP_ACCESS_FAULT : L2TLB_RSP_NO_PAVLD;

    if (data_vld) begin
      m_ptw_data_seen++;
      insert_or_update_entry(tag[46:20], tag[19:4], tag[0], tag[3:1],
        data[41:14], data[13:0] | flags, m_ptw[idx].owner, "PTW_REFILL");
    end else begin
      m_ptw_fault_seen++;
      note_source_result_bin(cls, m_ptw[idx].owner, m_ptw[idx].vpn,
        m_ptw[idx].asid, typ, id, "PTW completion source/result bin");
      note_payload_ignore(cls, m_ptw[idx].owner, m_ptw[idx].vpn,
        m_ptw[idx].asid, typ, id, "PTW completion fault/no-pavld payload ignored");
    end

    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_PTW_CMPLT] id=0x%02h type=0x%0h owner=%s class=%s vpn=0x%07h asid=0x%04h epoch=%0d cycle=%0d",
        id, typ, owner_name(m_ptw[idx].owner), rsp_class_name(cls),
        m_ptw[idx].vpn, m_ptw[idx].asid, m_epoch, m_cycle),
      UVM_HIGH)

    m_ptw[idx].valid = 1'b0;
  endfunction

  function void note_ptw_disabled_terminal(
    input bit [2:0] typ,
    input bit [26:0] vpn,
    input bit [15:0] asid,
    input bit [PTW_ID_WIDTH-1:0] id,
    input string reason = "PTW disabled miss terminal response"
  );
    l2tlb_owner_e owner;

    owner = owner_from_type(typ);
    case (owner)
      L2TLB_OWNER_ITLB:       m_ptw_disabled_itlb_seen++;
      L2TLB_OWNER_DTLB_LOAD:  m_ptw_disabled_dtlb_load_seen++;
      L2TLB_OWNER_DTLB_STORE: m_ptw_disabled_dtlb_store_seen++;
      L2TLB_OWNER_PFU:        m_ptw_disabled_pfu_seen++;
      default: begin
        record_mismatch(L2TLB_MISMATCH_UVM_BUG, "PTW_DISABLED_OWNER",
          vpn, asid, typ, owner, "ITLB/DTLB_LOAD/DTLB_STORE/PFU", "UNKNOWN");
        return;
      end
    endcase

    note_payload_ignore(L2TLB_RSP_PAGE_FAULT, owner, vpn, asid, typ, id, reason);
    `uvm_info(get_type_name(),
      $sformatf("[PHASE6C_L2_PTW_DISABLED] owner=%s id=0x%02h type=0x%0h vpn=0x%07h asid=0x%04h epoch=%0d cycle=%0d reason=%s",
        owner_name(owner), id, typ, vpn, asid, m_epoch, m_cycle, reason),
      UVM_MEDIUM)
  endfunction

  function void note_source_result_bin(
    input l2tlb_rsp_class_e cls,
    input l2tlb_owner_e owner,
    input bit [26:0] vpn,
    input bit [15:0] asid,
    input bit [2:0] typ,
    input bit [PTW_ID_WIDTH-1:0] id,
    input string reason
  );
    if (cls == L2TLB_RSP_PAGE_FAULT) begin
      case (owner)
        L2TLB_OWNER_ITLB:       m_ptw_pgflt_itlb_seen++;
        L2TLB_OWNER_DTLB_LOAD:  m_ptw_pgflt_dtlb_load_seen++;
        L2TLB_OWNER_DTLB_STORE: m_ptw_pgflt_dtlb_store_seen++;
        L2TLB_OWNER_PFU:        m_ptw_pgflt_pfu_seen++;
        default: begin end
      endcase
    end else if (cls == L2TLB_RSP_ACCESS_FAULT) begin
      case (owner)
        L2TLB_OWNER_ITLB:       m_ptw_accerr_itlb_seen++;
        L2TLB_OWNER_DTLB_LOAD:  m_ptw_accerr_dtlb_load_seen++;
        L2TLB_OWNER_DTLB_STORE: m_ptw_accerr_dtlb_store_seen++;
        L2TLB_OWNER_PFU:        m_ptw_accerr_pfu_seen++;
        default: begin end
      endcase
    end

    if (m_source_result_log_count < m_detail_log_limit) begin
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_L2_SOURCE_RESULT] class=%s owner=%s id=0x%02h type=0x%0h vpn=0x%07h asid=0x%04h epoch=%0d cycle=%0d reason=%s",
          rsp_class_name(cls), owner_name(owner), id, typ, vpn, asid,
          m_epoch, m_cycle, reason),
        UVM_MEDIUM)
    end else if (m_source_result_log_count == m_detail_log_limit) begin
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_L2_SOURCE_RESULT_SUPPRESS] suppressing further per-event source-result logs after %0d entries; counters remain in PHASE6C_L2_SHADOW summary",
          m_detail_log_limit),
        UVM_MEDIUM)
    end
    m_source_result_log_count++;
  endfunction

  function void note_payload_ignore(
    input l2tlb_rsp_class_e cls,
    input l2tlb_owner_e owner,
    input bit [26:0] vpn,
    input bit [15:0] asid,
    input bit [2:0] typ,
    input bit [PTW_ID_WIDTH-1:0] id,
    input string reason
  );
    m_pfu_payload_ignore_seen++;
    if (m_payload_ignore_log_count < m_detail_log_limit) begin
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_PAYLOAD_IGNORE] class=%s owner=%s id=0x%02h type=0x%0h vpn=0x%07h asid=0x%04h epoch=%0d reason=%s",
          rsp_class_name(cls), owner_name(owner), id, typ, vpn, asid, m_epoch, reason),
        UVM_MEDIUM)
    end else if (m_payload_ignore_log_count == m_detail_log_limit) begin
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_PAYLOAD_IGNORE_SUPPRESS] suppressing further per-event payload-ignore logs after %0d entries; counters remain in PHASE6C_L2_SHADOW summary",
          m_detail_log_limit),
        UVM_MEDIUM)
    end
    m_payload_ignore_log_count++;
  endfunction

  function void on_l2_final(
    input bit final_vld,
    input bit final_hit,
    input bit final_miss,
    input bit is_dtlb,
    input bit [26:0] vpn,
    input bit [27:0] dut_ppn,
    input bit [15:0] asid
  );
    int idx;
    l2_entry_t ent;

    if (!final_vld)
      return;

    if (final_miss)
      m_l2_miss_seen++;

    if (!final_hit)
      return;

    m_l2_hit_seen++;
    idx = find_entry(vpn, asid);
    if (idx < 0) begin
      m_l2_hit_waived++;
      m_waived_or_future++;
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_L2_HIT_NO_SHADOW] category=%s source=%s vpn=0x%07h asid=0x%04h dut_ppn=0x%07h epoch=%0d cycle=%0d action=diagnostic_only reason=entry may predate Phase6C shadow or come from unmodeled TLBWR victim",
          category_name(L2TLB_MISMATCH_APPROVED_WAIVER),
          is_dtlb ? "DTLB" : "ITLB", vpn, asid, dut_ppn, m_epoch, m_cycle),
        UVM_MEDIUM)
      return;
    end

    ent = m_entries[idx];
    if (ent.ppn !== dut_ppn) begin
      m_l2_hit_mismatch++;
      record_mismatch(L2TLB_MISMATCH_RTL_BUG, "L2_HIT_PPN",
        vpn, asid, ent.page_size, ent.source_op,
        $sformatf("ppn=0x%07h flags=0x%04h", ent.ppn, ent.flags),
        $sformatf("ppn=0x%07h", dut_ppn));
    end
  endfunction

  function void on_pfu_response(
    input bit response_seen,
    input bit deny,
    input bit acc_fault,
    input bit flag_fault,
    input bit [26:0] vpn,
    input bit [27:0] pa,
    input bit mmu_off,
    input bit [15:0] asid
  );
    l2tlb_rsp_class_e cls;
    if (!response_seen)
      return;

    m_pfu_seen++;
    if (deny || acc_fault || flag_fault) begin
      cls = L2TLB_RSP_PFU_ERROR;
      note_payload_ignore(cls, L2TLB_OWNER_PFU, vpn, asid, 3'b100, '0,
        $sformatf("PFU error payload ignored deny=%0b acc_fault=%0b flag_fault=%0b pa=0x%07h mmu_off=%0b",
          deny, acc_fault, flag_fault, pa, mmu_off));
    end else if (mmu_off) begin
      `uvm_info(get_type_name(),
        $sformatf("[PHASE6C_PFU_DIRECT] vpn=0x%07h pa=0x%07h asid=0x%04h epoch=%0d",
          vpn, pa, asid, m_epoch),
        UVM_HIGH)
    end
  endfunction

  function void record_mismatch(
    input l2tlb_mismatch_category_e cat,
    input string check_name,
    input bit [26:0] vpn,
    input bit [15:0] asid,
    input bit [2:0] page_size,
    input l2tlb_owner_e owner,
    input string expected,
    input string observed
  );
    if (cat == L2TLB_MISMATCH_APPROVED_WAIVER) begin
      m_waived_or_future++;
      `uvm_warning(get_type_name(),
        $sformatf("[PHASE6C_L2_WAIVER] check=%s category=%s source=%s vpn=0x%07h asid=0x%04h pgs=0x%0h expected={%s} observed={%s} epoch=%0d cycle=%0d",
          check_name, category_name(cat), owner_name(owner), vpn, asid, page_size,
          expected, observed, m_epoch, m_cycle))
      return;
    end

    if (l2tlb_negative_pkg::l2tlb_neg_sva_disable) begin
      `uvm_info(get_type_name(),
        $sformatf("[L2TLB_NEG_EXPECTED_CLASS] test_case=\"phase6c_shadow\" class=\"expected_shadow_mismatch\" related_ids=\"L2TLB_TP_027,L2TLB_TP_048,L2TLB_TP_056,L2TLB_TP_058,L2TLB_SVA_012,L2TLB_SVA_013,L2TLB_SVA_017,L2TLB_SVA_018\" trigger=1 checker=1 msg=\"shadow_negative check=%s category=%s source=%s vpn=0x%07h asid=0x%04h pgs=0x%0h expected={%s} observed={%s} epoch=%0d cycle=%0d\"",
          check_name, category_name(cat), owner_name(owner), vpn, asid, page_size,
          expected, observed, m_epoch, m_cycle),
        UVM_MEDIUM)
      return;
    end

    m_mismatch++;
    `uvm_error(get_type_name(),
      $sformatf("[PHASE6C_L2_MISMATCH] check=%s category=%s source=%s vpn=0x%07h asid=0x%04h pgs=0x%0h expected={%s} observed={%s} epoch=%0d cycle=%0d",
        check_name, category_name(cat), owner_name(owner), vpn, asid, page_size,
        expected, observed, m_epoch, m_cycle))
  endfunction

  function string summary();
    return $sformatf("phase6c_l2_shadow epoch=%0d cycles=%0d ptw_req=%0d ptw_data=%0d ptw_fault=%0d stale=%0d orphan=%0d l2_hit=%0d l2_miss=%0d l2_hit_mismatch=%0d l2_hit_waived=%0d pfu=%0d payload_ignore=%0d inv=%0d cp0_all_inv=%0d mismatch=%0d waived_future=%0d reset_epochs=%0d abort_epochs=%0d control_epochs=%0d ptw_disabled_itlb=%0d ptw_disabled_dtlb_load=%0d ptw_disabled_dtlb_store=%0d ptw_disabled_pfu=%0d ptw_pgflt_itlb=%0d ptw_pgflt_dtlb_load=%0d ptw_pgflt_dtlb_store=%0d ptw_pgflt_pfu=%0d ptw_accerr_itlb=%0d ptw_accerr_dtlb_load=%0d ptw_accerr_dtlb_store=%0d ptw_accerr_pfu=%0d",
      m_epoch, m_cycle, m_ptw_req_seen, m_ptw_data_seen, m_ptw_fault_seen,
      m_ptw_stale_seen, m_ptw_orphan_seen, m_l2_hit_seen, m_l2_miss_seen,
      m_l2_hit_mismatch, m_l2_hit_waived, m_pfu_seen, m_pfu_payload_ignore_seen,
      m_inv_seen, m_cp0_all_inv_seen, m_mismatch, m_waived_or_future,
      m_reset_epoch_count, m_abort_epoch_count, m_control_epoch_count,
      m_ptw_disabled_itlb_seen, m_ptw_disabled_dtlb_load_seen,
      m_ptw_disabled_dtlb_store_seen, m_ptw_disabled_pfu_seen,
      m_ptw_pgflt_itlb_seen, m_ptw_pgflt_dtlb_load_seen,
      m_ptw_pgflt_dtlb_store_seen, m_ptw_pgflt_pfu_seen,
      m_ptw_accerr_itlb_seen, m_ptw_accerr_dtlb_load_seen,
      m_ptw_accerr_dtlb_store_seen, m_ptw_accerr_pfu_seen);
  endfunction

endclass : mmu_l2tlb_txn_shadow

`endif // MMU_L2TLB_TXN_SHADOW_SVH
