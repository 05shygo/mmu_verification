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
    int unsigned age;
  } pde_entry_s;

  typedef struct {
    bit                 valid;
    ptw_src_level_e     level;
    vpn_t               vpn;
    ppn_t               ppn;
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
      m_l1[i].age   = 0;
    end
    foreach (m_l2[i]) begin
      m_l2[i].valid = 1'b0;
      m_l2[i].tag   = '0;
      m_l2[i].ppn   = '0;
      m_l2[i].age   = 0;
    end
    m_pending_update.valid = 1'b0;
    m_pending_update.level = PTW_SRC_LEVEL_NONE;
    m_pending_update.vpn   = '0;
    m_pending_update.ppn   = '0;
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

  protected function int find_hit_l1(input vpn_t vpn);
    logic [26:0] tag;
    tag = l1_tag(vpn);
    foreach (m_l1[i]) begin
      if (m_l1[i].valid && (m_l1[i].tag == tag))
        return int'(i);
    end
    return -1;
  endfunction

  protected function int find_hit_l2(input vpn_t vpn);
    logic [26:0] tag;
    tag = l2_tag(vpn);
    foreach (m_l2[i]) begin
      if (m_l2[i].valid && (m_l2[i].tag == tag))
        return int'(i);
    end
    return -1;
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
    int l1_idx;
    int l2_idx;

    l1_idx = find_hit_l1(vpn);
    l2_idx = find_hit_l2(vpn);
    l1_hit = (l1_idx >= 0);
    l2_hit = (l2_idx >= 0);
    hit_level = PTW_SRC_LEVEL_NONE;
    hit_ppn = '0;

    if (l2_hit) begin
      m_age++;
      m_l2[l2_idx].age = m_age;
      hit_level = PTW_SRC_LEVEL_THD;
      hit_ppn = m_l2[l2_idx].ppn;
      return 1'b1;
    end

    if (l1_hit) begin
      m_age++;
      m_l1[l1_idx].age = m_age;
      hit_level = PTW_SRC_LEVEL_SCD;
      hit_ppn = m_l1[l1_idx].ppn;
      return 1'b1;
    end

    return 1'b0;
  endfunction

  virtual function void queue_update(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
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
    m_pending_update.directed_victim = directed_victim;
  endfunction

  virtual function void commit_update(
    input ptw_src_level_e level,
    input vpn_t           vpn,
    input ppn_t           ppn,
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
      m_l1[idx].age = m_age;
    end else if (level == PTW_SRC_LEVEL_SCD) begin
      idx = find_hit_l2(vpn);
      if (idx < 0)
        idx = (directed_victim >= 0) ? directed_victim : choose_victim_l2();
      m_l2[idx].valid = 1'b1;
      m_l2[idx].tag = l2_tag(vpn);
      m_l2[idx].ppn = ppn;
      m_l2[idx].age = m_age;
    end
  endfunction

  virtual function void tick();
    if (m_pending_update.valid) begin
      commit_update(m_pending_update.level, m_pending_update.vpn,
        m_pending_update.ppn, m_pending_update.directed_victim);
      m_pending_update.valid = 1'b0;
    end
  endfunction

endclass : ptw_pde_cache_model

`endif // PTW_PDE_CACHE_MODEL_SVH
