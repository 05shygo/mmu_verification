// =============================================================================
// PTW PDE cache abstract model
//
// Stage 4 scope:
//   - Two 16-entry fully-associative levels.
//   - L2 hit wins when L1 and L2 both hit.
//   - Lookup observes current state; queued update commits on tick().
//   - clear()/abort_flush() invalidate all entries without touching DUT path.
//   - Replacement is deterministic LRU with invalid-entry preference. Directed
//     tests may force the next victim to make replacement scenarios stable.
//
// PMPFLG Stage 3 scope:
//   - Store cached L1/L2 pmpflg evidence per entry.
//   - Provide permission-qualified lookup_detail() while keeping the legacy
//     lookup() wrapper source-compatible for pre-PMPFLG users.
// =============================================================================
`ifndef PTW_PDE_CACHE_MODEL_SVH
`define PTW_PDE_CACHE_MODEL_SVH

class ptw_pde_cache_model extends uvm_object;

  `uvm_object_utils(ptw_pde_cache_model)

  localparam int unsigned PDE_NUM_ENTRIES = 16;

  typedef struct {
    bit          valid;
    logic [26:0] tag;
    ppn_t        ppn;
    logic [3:0]  l1pmpflg;
    logic [3:0]  l2pmpflg;
    int unsigned age;
  } pde_entry_s;

  typedef struct {
    bit                  lookup_hit;
    bit                  l1_hit;
    bit                  l2_hit;
    bit                  l1_tag_hit;
    bit                  l2_tag_hit;
    bit                  l1_perm_allow;
    bit                  l2_l1_perm_allow;
    bit                  l2_l2_perm_allow;
    bit                  l2_perm_allow;
    bit                  l1_deny_miss;
    bit                  l2_direct_accerr;
    ptw_src_level_e      hit_level;
    ppn_t                hit_ppn;
    logic [3:0]          cached_l1pmpflg;
    logic [3:0]          cached_l2pmpflg;
    ptw_src_pde_reason_e reason;
    int                  l1_idx;
    int                  l2_idx;
  } pde_lookup_result_s;

  typedef struct {
    bit                 valid;
    ptw_src_level_e     level;
    vpn_t               vpn;
    ppn_t               ppn;
    logic [3:0]         l1pmpflg;
    logic [3:0]         l2pmpflg;
    int                 directed_victim;
  } pde_pending_update_s;

  pde_entry_s          m_l1[PDE_NUM_ENTRIES];
  pde_entry_s          m_l2[PDE_NUM_ENTRIES];
  pde_pending_update_s m_pending_update;
  int unsigned         m_age;
  int                  m_next_l1_victim;
  int                  m_next_l2_victim;

  function new(string name = "ptw_pde_cache_model");
    super.new(name);
    clear();
  endfunction

  virtual function void clear();
    foreach (m_l1[i]) begin
      m_l1[i].valid = 1'b0;
      m_l1[i].tag   = '0;
      m_l1[i].ppn   = '0;
      m_l1[i].l1pmpflg = 4'h0;
      m_l1[i].l2pmpflg = 4'h0;
      m_l1[i].age   = 0;
    end
    foreach (m_l2[i]) begin
      m_l2[i].valid = 1'b0;
      m_l2[i].tag   = '0;
      m_l2[i].ppn   = '0;
      m_l2[i].l1pmpflg = 4'h0;
      m_l2[i].l2pmpflg = 4'h0;
      m_l2[i].age   = 0;
    end
    m_pending_update.valid = 1'b0;
    m_pending_update.level = PTW_SRC_LEVEL_NONE;
    m_pending_update.vpn   = '0;
    m_pending_update.ppn   = '0;
    m_pending_update.l1pmpflg = 4'h0;
    m_pending_update.l2pmpflg = 4'h0;
    m_pending_update.directed_victim = -1;
    m_age = 0;
    m_next_l1_victim = -1;
    m_next_l2_victim = -1;
  endfunction

  virtual function void abort_flush();
    clear();
  endfunction

  virtual function void set_next_victim(ptw_src_level_e level, int victim);
    if ((victim < 0) || (victim >= int'(PDE_NUM_ENTRIES))) begin
      `uvm_warning(get_type_name(),
        $sformatf("Ignoring illegal directed PDE victim=%0d", victim))
      return;
    end
    if (level == PTW_SRC_LEVEL_FST)
      m_next_l1_victim = victim;
    else if (level == PTW_SRC_LEVEL_SCD)
      m_next_l2_victim = victim;
    else
      `uvm_warning(get_type_name(),
        $sformatf("Ignoring directed victim for unsupported level=%s", level.name()))
  endfunction

  protected function logic [26:0] l1_tag(input vpn_t vpn);
    return {18'b0, vpn[26:18]};
  endfunction

  protected function logic [26:0] l2_tag(input vpn_t vpn);
    return {9'b0, vpn[26:9]};
  endfunction

  protected function int find_tag_l1(input vpn_t vpn);
    logic [26:0] tag;
    tag = l1_tag(vpn);
    foreach (m_l1[i]) begin
      if (m_l1[i].valid && (m_l1[i].tag == tag))
        return int'(i);
    end
    return -1;
  endfunction

  protected function int find_tag_l2(input vpn_t vpn);
    logic [26:0] tag;
    tag = l2_tag(vpn);
    foreach (m_l2[i]) begin
      if (m_l2[i].valid && (m_l2[i].tag == tag))
        return int'(i);
    end
    return -1;
  endfunction

  protected function int find_hit_l1(input vpn_t vpn);
    return find_tag_l1(vpn);
  endfunction

  protected function int find_hit_l2(input vpn_t vpn);
    return find_tag_l2(vpn);
  endfunction

  protected function pde_lookup_result_s init_lookup_result();
    pde_lookup_result_s result;

    result.lookup_hit = 1'b0;
    result.l1_hit = 1'b0;
    result.l2_hit = 1'b0;
    result.l1_tag_hit = 1'b0;
    result.l2_tag_hit = 1'b0;
    result.l1_perm_allow = 1'b0;
    result.l2_l1_perm_allow = 1'b0;
    result.l2_l2_perm_allow = 1'b0;
    result.l2_perm_allow = 1'b0;
    result.l1_deny_miss = 1'b0;
    result.l2_direct_accerr = 1'b0;
    result.hit_level = PTW_SRC_LEVEL_NONE;
    result.hit_ppn = '0;
    result.cached_l1pmpflg = 4'h0;
    result.cached_l2pmpflg = 4'h0;
    result.reason = PTW_SRC_PDE_REASON_NONE;
    result.l1_idx = -1;
    result.l2_idx = -1;

    return result;
  endfunction

  protected function int choose_victim_l1();
    int victim;
    int unsigned oldest_age;

    if (m_next_l1_victim >= 0) begin
      victim = m_next_l1_victim;
      m_next_l1_victim = -1;
      return victim;
    end

    foreach (m_l1[i]) begin
      if (!m_l1[i].valid)
        return int'(i);
    end

    victim = 0;
    oldest_age = m_l1[0].age;
    foreach (m_l1[i]) begin
      if (m_l1[i].age < oldest_age) begin
        victim = int'(i);
        oldest_age = m_l1[i].age;
      end
    end
    return victim;
  endfunction

  protected function int choose_victim_l2();
    int victim;
    int unsigned oldest_age;

    if (m_next_l2_victim >= 0) begin
      victim = m_next_l2_victim;
      m_next_l2_victim = -1;
      return victim;
    end

    foreach (m_l2[i]) begin
      if (!m_l2[i].valid)
        return int'(i);
    end

    victim = 0;
    oldest_age = m_l2[0].age;
    foreach (m_l2[i]) begin
      if (m_l2[i].age < oldest_age) begin
        victim = int'(i);
        oldest_age = m_l2[i].age;
      end
    end
    return victim;
  endfunction

  virtual function bit lookup(
    input  vpn_t           vpn,
    output ptw_src_level_e hit_level,
    output ppn_t           hit_ppn,
    output bit             l1_hit,
    output bit             l2_hit
  );
    pde_lookup_result_s result;

    result = lookup_detail(vpn, PTW_SRC_TYPE_LOAD, 1'b0);
    hit_level = result.hit_level;
    hit_ppn = result.hit_ppn;
    l1_hit = result.l1_hit;
    l2_hit = result.l2_hit;

    return result.lookup_hit;
  endfunction

  virtual function pde_lookup_result_s lookup_detail(
    input vpn_t              vpn,
    input ptw_src_req_type_e req_type,
    input bit                effective_m,
    input bit                update_plru = 1'b1
  );
    pde_lookup_result_s result;

    result = init_lookup_result();
    result.l1_idx = find_tag_l1(vpn);
    result.l2_idx = find_tag_l2(vpn);
    result.l1_tag_hit = (result.l1_idx >= 0);
    result.l2_tag_hit = (result.l2_idx >= 0);

    if (result.l2_tag_hit) begin
      result.cached_l1pmpflg = m_l2[result.l2_idx].l1pmpflg;
      result.cached_l2pmpflg = m_l2[result.l2_idx].l2pmpflg;
      result.l2_l1_perm_allow = ptw_src_pde_pmp_allow(req_type,
        result.cached_l1pmpflg, effective_m);
      result.l2_l2_perm_allow = ptw_src_pde_pmp_allow(req_type,
        result.cached_l2pmpflg, effective_m);
      result.l2_perm_allow = result.l2_l1_perm_allow
                           && result.l2_l2_perm_allow;

      if (result.l2_perm_allow) begin
        result.lookup_hit = 1'b1;
        result.l2_hit = 1'b1;
        result.hit_level = PTW_SRC_LEVEL_THD;
        result.hit_ppn = m_l2[result.l2_idx].ppn;
        result.reason = PTW_SRC_PDE_REASON_NONE;
        if (update_plru) begin
          m_age++;
          m_l2[result.l2_idx].age = m_age;
        end
      end else begin
        result.l2_direct_accerr = 1'b1;
        if (!result.l2_l1_perm_allow && !result.l2_l2_perm_allow)
          result.reason = PTW_SRC_PDE_REASON_L2_BOTH_PMP_DENY;
        else if (!result.l2_l1_perm_allow)
          result.reason = PTW_SRC_PDE_REASON_L2_L1PMP_DENY;
        else
          result.reason = PTW_SRC_PDE_REASON_L2_L2PMP_DENY;
      end

      return result;
    end

    if (result.l1_tag_hit) begin
      result.cached_l1pmpflg = m_l1[result.l1_idx].l1pmpflg;
      result.l1_perm_allow = ptw_src_pde_pmp_allow(req_type,
        result.cached_l1pmpflg, effective_m);

      if (result.l1_perm_allow) begin
        result.lookup_hit = 1'b1;
        result.l1_hit = 1'b1;
        result.hit_level = PTW_SRC_LEVEL_SCD;
        result.hit_ppn = m_l1[result.l1_idx].ppn;
        result.reason = PTW_SRC_PDE_REASON_NONE;
        if (update_plru) begin
          m_age++;
          m_l1[result.l1_idx].age = m_age;
        end
      end else begin
        result.l1_deny_miss = 1'b1;
        result.reason = PTW_SRC_PDE_REASON_L1_PMP_DENY;
      end

      return result;
    end

    result.reason = PTW_SRC_PDE_REASON_L1_TAG_MISS;
    return result;
  endfunction

  virtual function void queue_update(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
    input logic [3:0]     l1pmpflg = 4'hf,
    input logic [3:0]     l2pmpflg = 4'hf,
    input int             directed_victim = -1
  );
    if (!((level == PTW_SRC_LEVEL_FST) || (level == PTW_SRC_LEVEL_SCD))) begin
      `uvm_warning(get_type_name(),
        $sformatf("Ignoring PDE update for unsupported level=%s", level.name()))
      return;
    end

    m_pending_update.valid = 1'b1;
    m_pending_update.level = level;
    m_pending_update.vpn = vpn;
    m_pending_update.ppn = ppn;
    m_pending_update.l1pmpflg = l1pmpflg;
    m_pending_update.l2pmpflg = l2pmpflg;
    m_pending_update.directed_victim = directed_victim;
  endfunction

  virtual function void queue_update_with_pmpflg(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
    input logic [3:0]     l1pmpflg,
    input logic [3:0]     l2pmpflg,
    input int             directed_victim = -1
  );
    queue_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim);
  endfunction

  virtual function void commit_update(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
    input logic [3:0]     l1pmpflg = 4'hf,
    input logic [3:0]     l2pmpflg = 4'hf,
    input int             directed_victim = -1
  );
    int idx;

    m_age++;
    if (level == PTW_SRC_LEVEL_FST) begin
      idx = find_hit_l1(vpn);
      if (idx < 0)
        idx = (directed_victim >= 0) ? directed_victim : choose_victim_l1();
      m_l1[idx].valid = 1'b1;
      m_l1[idx].tag = l1_tag(vpn);
      m_l1[idx].ppn = ppn;
      m_l1[idx].l1pmpflg = l1pmpflg;
      m_l1[idx].l2pmpflg = 4'h0;
      m_l1[idx].age = m_age;
    end else if (level == PTW_SRC_LEVEL_SCD) begin
      idx = find_hit_l2(vpn);
      if (idx < 0)
        idx = (directed_victim >= 0) ? directed_victim : choose_victim_l2();
      m_l2[idx].valid = 1'b1;
      m_l2[idx].tag = l2_tag(vpn);
      m_l2[idx].ppn = ppn;
      m_l2[idx].l1pmpflg = l1pmpflg;
      m_l2[idx].l2pmpflg = l2pmpflg;
      m_l2[idx].age = m_age;
    end
  endfunction

  virtual function void commit_update_with_pmpflg(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
    input logic [3:0]     l1pmpflg,
    input logic [3:0]     l2pmpflg,
    input int             directed_victim = -1
  );
    commit_update(level, vpn, ppn, l1pmpflg, l2pmpflg, directed_victim);
  endfunction

  virtual function void tick();
    if (m_pending_update.valid) begin
      commit_update(m_pending_update.level, m_pending_update.vpn,
        m_pending_update.ppn, m_pending_update.l1pmpflg,
        m_pending_update.l2pmpflg, m_pending_update.directed_victim);
      m_pending_update.valid = 1'b0;
    end
  endfunction

  virtual function string lookup_result2string(input pde_lookup_result_s result);
    return $sformatf(
      "lookup_hit=%0b l1_hit=%0b l2_hit=%0b tag_hit={l1=%0b,l2=%0b} allow={l1=%0b,l2_l1=%0b,l2_l2=%0b,l2=%0b} deny={l1_miss=%0b,l2_direct_accerr=%0b} hit_level=%s hit_ppn=0x%07h pmp={l1=0x%0h,l2=0x%0h} reason=%s idx={l1=%0d,l2=%0d}",
      result.lookup_hit, result.l1_hit, result.l2_hit, result.l1_tag_hit,
      result.l2_tag_hit, result.l1_perm_allow, result.l2_l1_perm_allow,
      result.l2_l2_perm_allow, result.l2_perm_allow, result.l1_deny_miss,
      result.l2_direct_accerr, result.hit_level.name(), result.hit_ppn,
      result.cached_l1pmpflg, result.cached_l2pmpflg,
      ptw_src_pde_reason_name(result.reason), result.l1_idx, result.l2_idx);
  endfunction

  protected function string entry2string(
    input string      level_name,
    input int         idx,
    input pde_entry_s entry
  );
    return $sformatf(
      "%s[%0d]={valid=%0b tag=0x%07h ppn=0x%07h l1pmp=0x%0h l2pmp=0x%0h age=%0d}",
      level_name, idx, entry.valid, entry.tag, entry.ppn, entry.l1pmpflg,
      entry.l2pmpflg, entry.age);
  endfunction

  virtual function string dump_string();
    string s;

    s = "ptw_pde_cache_model";
    foreach (m_l1[i]) begin
      if (m_l1[i].valid)
        s = {s, "\n  ", entry2string("L1", int'(i), m_l1[i])};
    end
    foreach (m_l2[i]) begin
      if (m_l2[i].valid)
        s = {s, "\n  ", entry2string("L2", int'(i), m_l2[i])};
    end
    return s;
  endfunction

endclass : ptw_pde_cache_model

`endif // PTW_PDE_CACHE_MODEL_SVH
