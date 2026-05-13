// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/page_table_builder.svh
// Phase 4: Sv39 3-level page table builder (core shared tool)
//
// Design notes:
//   - Shared between ptw_mem_responder (to look up PTEs) and mmu_ref_model
//     (to perform software page walk), so it is a uvm_object (not component).
//   - Uses an associative array indexed by 40-bit PA as the storage backend,
//     avoiding the need for memory_shadow_c (which is a uvm_component and
//     requires a UVM hierarchy parent).
//   - m_next_ppn auto-allocates physical pages for non-leaf PTEs; starts at
//     m_root_ppn+1 after set_root() to avoid stomping the root page.
//   - map_4k() is fully implemented (Phase 4 requirement).
//   - map_2m() / map_1g() body stubs compile cleanly; implement in Phase 5.
// =============================================================================
`ifndef PAGE_TABLE_BUILDER_SVH
`define PAGE_TABLE_BUILDER_SVH

class page_table_builder extends uvm_object;

  `uvm_object_utils(page_table_builder)

  // ── Storage ───────────────────────────────────────────────────────────────
  // Key  : byte-aligned PA of PTE entry (always 8-byte aligned in practice)
  // Value: 64-bit PTE
  protected bit [63:0] m_mem [longint unsigned];

  // ── Current SATP root ─────────────────────────────────────────────────────
  ppn_t  m_root_ppn;   // SATP.PPN — set by test via set_root()
  asid_t m_root_asid;

  // ── Auto-allocator for non-leaf pages ─────────────────────────────────────
  // Increments after each allocation; tests may read this to know which PPNs
  // were allocated by the builder.
  ppn_t  m_next_ppn;

  function new(string name = "page_table_builder");
    super.new(name);
    m_root_ppn  = '0;
    m_root_asid = '0;
    m_next_ppn  = 28'h200;  // safe default; overridden by set_root()
  endfunction

  // ── Configuration API ─────────────────────────────────────────────────────

  // Set the root page table (SATP.PPN / SATP.ASID).
  // Resets the auto-allocator so non-leaf pages begin just after the root.
  virtual function void set_root(ppn_t root_ppn, asid_t asid);
    // Clear stale page table entries from previous tests before rebuilding.
    m_mem.delete();
    m_root_ppn  = root_ppn;
    m_root_asid = asid;
    // Start auto-alloc above root page to avoid collisions.
    // Root page occupies ppn; we skip a block of 16 pages for safety.
    m_next_ppn  = root_ppn + 28'd16;
    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("set_root: root_ppn=0x%07h asid=0x%04h next_ppn=0x%07h (mem cleared)",
        root_ppn, asid, m_next_ppn), UVM_MEDIUM)
  endfunction

  // ── Low-level PTE access ──────────────────────────────────────────────────

  // Read PTE at the given physical byte address.
  // Returns 0 (invalid PTE) when address is not yet written.
  virtual function pte_t read_pte_at(pa_t pte_addr);
    longint unsigned key = longint'(pte_addr);
    if (m_mem.exists(key))
      return pte_t'(m_mem[key]);
    else
      return '0;
  endfunction

  // Write PTE at the given physical byte address.
  virtual function void write_pte_at(pa_t pte_addr, pte_t pte);
    longint unsigned key = longint'(pte_addr);
    m_mem[key] = 64'(pte);
    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("write_pte_at: addr=0x%010h pte=0x%016h", pte_addr, pte),
      UVM_HIGH)
  endfunction

  // ── Internal helpers ──────────────────────────────────────────────────────

  // Compute byte address of the PTE at the given (ppn, vpn_index) position.
  // pte_addr = ppn_page_base + vpn_index * 8
  protected function pa_t _pte_addr(ppn_t ppn, logic [8:0] vpn_idx);
    // ppn << 12 = 40-bit page base; index * 8 = byte offset within page
    return pa_t'({ppn, 12'b0}) + pa_t'({31'b0, vpn_idx, 3'b0});
  endfunction

  // Allocate a fresh physical page for an intermediate-level page table.
  // Returns the new ppn and increments m_next_ppn.
  protected function ppn_t _alloc_ppn();
    ppn_t allocated = m_next_ppn;
    m_next_ppn = m_next_ppn + 28'd1;
    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("_alloc_ppn: allocated=0x%07h (next=0x%07h)",
        allocated, m_next_ppn), UVM_HIGH)
    return allocated;
  endfunction

  // Build a non-leaf (pointer) PTE: V=1, R=0, W=0, X=0.
  // The PPN points to the next-level page table.
  protected function pte_t _make_pointer_pte(ppn_t next_ppn);
    // Non-leaf: V=1, R=0, W=0, X=0 (all other perm bits = 0)
    // A/D = 0 for non-leaf per RISC-V spec
    return make_pte(.ppn(next_ppn), .v(1), .r(0), .w(0), .x(0),
                    .u(0), .g(0), .a(0), .d(0));
  endfunction

  protected function bit _is_nonleaf_pointer_pte(pte_t pte);
    return pte[PTE_V] && !pte[PTE_R] && !pte[PTE_W] && !pte[PTE_X];
  endfunction

  protected function bit _level_is_valid(int unsigned level);
    return (level <= 2);
  endfunction

  protected function bit _resolve_table_for_level(
    va_t va,
    int unsigned target_level,
    output ppn_t table_ppn
  );
    pte_t pte;
    pa_t  pte_addr;

    table_ppn = m_root_ppn;
    if (!_level_is_valid(target_level)) begin
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("_resolve_table_for_level: illegal level=%0d", target_level))
      return 1'b0;
    end

    for (int level = 2; level > int'(target_level); level--) begin
      pte_addr = _pte_addr(table_ppn, va_vpn_level(va, level));
      pte      = read_pte_at(pte_addr);
      if (!_is_nonleaf_pointer_pte(pte)) begin
        `uvm_info("PAGE_TABLE_BUILDER",
          $sformatf("_resolve_table_for_level: no pointer at level=%0d va=0x%010h pte_addr=0x%010h pte=0x%016h",
            level, va, pte_addr, pte),
          UVM_HIGH)
        return 1'b0;
      end
      table_ppn = pte[PTE_PPN_LSB +: PPN_WIDTH];
    end

    return 1'b1;
  endfunction

  protected function bit _ensure_table_for_level(
    va_t va,
    int unsigned target_level,
    output ppn_t table_ppn
  );
    pte_t pte;
    pa_t  pte_addr;
    ppn_t next_ppn;

    table_ppn = m_root_ppn;
    if (!_level_is_valid(target_level)) begin
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("_ensure_table_for_level: illegal level=%0d", target_level))
      return 1'b0;
    end

    for (int level = 2; level > int'(target_level); level--) begin
      pte_addr = _pte_addr(table_ppn, va_vpn_level(va, level));
      pte      = read_pte_at(pte_addr);
      if (!_is_nonleaf_pointer_pte(pte)) begin
        next_ppn = _alloc_ppn();
        pte      = _make_pointer_pte(next_ppn);
        write_pte_at(pte_addr, pte);
        table_ppn = next_ppn;
      end else begin
        table_ppn = pte[PTE_PPN_LSB +: PPN_WIDTH];
      end
    end

    return 1'b1;
  endfunction

  // ── Directed raw-PTE construction API ────────────────────────────────────

  virtual function ppn_t alloc_table_ppn();
    return _alloc_ppn();
  endfunction

  virtual function pte_t make_raw_pte(
    ppn_t        ppn,
    bit          v = 1,
    bit          r = 1,
    bit          w = 1,
    bit          x = 1,
    bit          u = 0,
    bit          g = 0,
    bit          a = 1,
    bit          d = 1,
    bit [1:0]    rsw = 2'b00,
    bit [20:0]   high_reserved = 21'h0,
    bit [4:0]    ext_attr = 5'h0
  );
    pte_t raw_pte;

    raw_pte = make_pte(.ppn(ppn), .v(v), .r(r), .w(w), .x(x),
                       .u(u), .g(g), .a(a), .d(d));
    raw_pte[9:8]   = rsw;
    raw_pte[58:38] = high_reserved;
    raw_pte[63:59] = ext_attr;
    return raw_pte;
  endfunction

  virtual function pte_t make_legal_pointer_pte(
    ppn_t      next_ppn,
    bit [1:0]  rsw = 2'b00,
    bit        g = 0,
    bit [20:0] high_reserved = 21'h0,
    bit [4:0]  ext_attr = 5'h0
  );
    return make_raw_pte(.ppn(next_ppn), .v(1), .r(0), .w(0), .x(0),
                        .u(0), .g(g), .a(0), .d(0),
                        .rsw(rsw), .high_reserved(high_reserved),
                        .ext_attr(ext_attr));
  endfunction

  virtual function pte_t make_illegal_nonleaf_pte(
    ppn_t      next_ppn,
    bit        v = 1,
    bit        r = 0,
    bit        w = 1,
    bit        x = 0,
    bit        u = 0,
    bit        g = 0,
    bit        a = 0,
    bit        d = 0,
    bit [1:0]  rsw = 2'b00,
    bit [20:0] high_reserved = 21'h0,
    bit [4:0]  ext_attr = 5'h0
  );
    return make_raw_pte(.ppn(next_ppn), .v(v), .r(r), .w(w), .x(x),
                        .u(u), .g(g), .a(a), .d(d),
                        .rsw(rsw), .high_reserved(high_reserved),
                        .ext_attr(ext_attr));
  endfunction

  virtual function bit get_pte_addr_for_level(
    va_t va,
    int unsigned level,
    output pa_t pte_addr
  );
    ppn_t table_ppn;

    pte_addr = '0;
    if (!_resolve_table_for_level(va, level, table_ppn))
      return 1'b0;
    pte_addr = _pte_addr(table_ppn, va_vpn_level(va, int'(level)));
    return 1'b1;
  endfunction

  virtual function bit get_or_create_pte_addr_for_level(
    va_t va,
    int unsigned level,
    output pa_t pte_addr
  );
    ppn_t table_ppn;

    pte_addr = '0;
    if (!_ensure_table_for_level(va, level, table_ppn))
      return 1'b0;
    pte_addr = _pte_addr(table_ppn, va_vpn_level(va, int'(level)));
    return 1'b1;
  endfunction

  virtual function bit read_pte_for_level(
    va_t va,
    int unsigned level,
    output pte_t raw_pte,
    output pa_t pte_addr
  );
    raw_pte = '0;
    pte_addr = '0;
    if (!get_pte_addr_for_level(va, level, pte_addr))
      return 1'b0;
    raw_pte = read_pte_at(pte_addr);
    return 1'b1;
  endfunction

  virtual function bit write_raw_pte_for_level(
    va_t va,
    int unsigned level,
    pte_t raw_pte,
    output pa_t pte_addr,
    input bit create_path = 1'b1
  );
    ppn_t table_ppn;

    pte_addr = '0;
    if (create_path) begin
      if (!_ensure_table_for_level(va, level, table_ppn))
        return 1'b0;
    end else begin
      if (!_resolve_table_for_level(va, level, table_ppn))
        return 1'b0;
    end

    pte_addr = _pte_addr(table_ppn, va_vpn_level(va, int'(level)));
    write_pte_at(pte_addr, raw_pte);
    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("write_raw_pte_for_level: va=0x%010h level=%0d pte_addr=0x%010h raw=0x%016h create_path=%0b",
        va, level, pte_addr, raw_pte, create_path),
      UVM_MEDIUM)
    return 1'b1;
  endfunction

  virtual function bit map_raw_leaf(
    va_t va,
    int unsigned level,
    ppn_t leaf_ppn,
    output pte_t raw_pte,
    output pa_t pte_addr,
    input bit v = 1,
    input bit r = 1,
    input bit w = 1,
    input bit x = 1,
    input bit u = 0,
    input bit g = 0,
    input bit a = 1,
    input bit d = 1,
    input bit [1:0] rsw = 2'b00,
    input bit [20:0] high_reserved = 21'h0,
    input bit [4:0] ext_attr = 5'h0,
    input bit allow_misaligned = 1'b0
  );
    ppn_t adjusted_ppn;

    adjusted_ppn = leaf_ppn;
    if (!allow_misaligned) begin
      if (level == 1)
        adjusted_ppn[8:0] = 9'b0;
      else if (level == 2)
        adjusted_ppn[17:0] = 18'b0;
    end

    raw_pte = make_raw_pte(.ppn(adjusted_ppn), .v(v), .r(r), .w(w), .x(x),
                           .u(u), .g(g), .a(a), .d(d),
                           .rsw(rsw), .high_reserved(high_reserved),
                           .ext_attr(ext_attr));
    return write_raw_pte_for_level(.va(va), .level(level), .raw_pte(raw_pte),
                                   .create_path(1'b1), .pte_addr(pte_addr));
  endfunction

  virtual function bit map_raw_leaf_pa(
    va_t va,
    int unsigned level,
    pa_t pa,
    output pte_t raw_pte,
    output pa_t pte_addr,
    input bit v = 1,
    input bit r = 1,
    input bit w = 1,
    input bit x = 1,
    input bit u = 0,
    input bit g = 0,
    input bit a = 1,
    input bit d = 1,
    input bit [1:0] rsw = 2'b00,
    input bit [20:0] high_reserved = 21'h0,
    input bit [4:0] ext_attr = 5'h0,
    input bit allow_misaligned = 1'b0
  );
    return map_raw_leaf(.va(va), .level(level),
                        .leaf_ppn(pa[PA_WIDTH-1:PAGE_OFFSET]),
                        .v(v), .r(r), .w(w), .x(x), .u(u), .g(g),
                        .a(a), .d(d), .rsw(rsw),
                        .high_reserved(high_reserved),
                        .ext_attr(ext_attr),
                        .allow_misaligned(allow_misaligned),
                        .raw_pte(raw_pte), .pte_addr(pte_addr));
  endfunction

  virtual function bit write_nonleaf_for_level(
    va_t va,
    int unsigned level,
    ppn_t next_ppn,
    output pte_t raw_pte,
    output pa_t pte_addr,
    input bit legal = 1'b1,
    input bit create_path = 1'b1,
    input bit r = 0,
    input bit w = 0,
    input bit x = 0,
    input bit u = 0,
    input bit g = 0,
    input bit a = 0,
    input bit d = 0,
    input bit [1:0] rsw = 2'b00,
    input bit [20:0] high_reserved = 21'h0,
    input bit [4:0] ext_attr = 5'h0
  );
    ppn_t effective_next_ppn;

    effective_next_ppn = next_ppn;
    if (effective_next_ppn == '0)
      effective_next_ppn = _alloc_ppn();

    if (legal) begin
      raw_pte = make_legal_pointer_pte(.next_ppn(effective_next_ppn),
                                       .rsw(rsw), .g(g),
                                       .high_reserved(high_reserved),
                                       .ext_attr(ext_attr));
    end else begin
      raw_pte = make_illegal_nonleaf_pte(.next_ppn(effective_next_ppn), .v(1),
                                         .r(r), .w(w), .x(x), .u(u), .g(g),
                                         .a(a), .d(d), .rsw(rsw),
                                         .high_reserved(high_reserved),
                                         .ext_attr(ext_attr));
    end

    return write_raw_pte_for_level(.va(va), .level(level), .raw_pte(raw_pte),
                                   .create_path(create_path),
                                   .pte_addr(pte_addr));
  endfunction

  // ── High-level mapping API ────────────────────────────────────────────────

  // Map a 4K page: VA → PA with given permission bits.
  //
  // Algorithm (Sv39 3-level walk with auto-allocation):
  //   1. Root (level-2): pte_addr = root_ppn_page + VPN[2]*8
  //      If PTE[V]=0 → allocate new L1 ppn, write non-leaf PTE
  //   2. L1 (level-1): pte_addr = l1_ppn_page + VPN[1]*8
  //      If PTE[V]=0 → allocate new L0 ppn, write non-leaf PTE
  //   3. L0 (level-0): pte_addr = l0_ppn_page + VPN[0]*8
  //      Write leaf PTE with PA's PPN and permission bits
  //
  // Existing non-leaf PTEs along the path are REUSED (path sharing enabled).
  virtual function void map_4k(
    va_t va,
    pa_t pa,
    bit  v = 1,
    bit  r = 1,
    bit  w = 1,
    bit  x = 1,
    bit  u = 0,
    bit  g = 0,
    bit  a = 1,
    bit  d = 1
  );
    logic [8:0] vpn2, vpn1, vpn0;
    pa_t        pte_addr_2, pte_addr_1, pte_addr_0;
    pte_t       pte2, pte1, pte0;
    ppn_t       l1_ppn, l0_ppn, leaf_ppn;

    // Extract VPN fields
    vpn2 = va[38:30];
    vpn1 = va[29:21];
    vpn0 = va[20:12];

    // ---- Level 2 (root → L1) ------------------------------------------------
    pte_addr_2 = _pte_addr(m_root_ppn, vpn2);
    pte2       = read_pte_at(pte_addr_2);
    if (!pte2[PTE_V] || pte2[PTE_R] || pte2[PTE_W] || pte2[PTE_X]) begin
      // No L1 page table yet, or an existing giga-page/invalid leaf is being
      // replaced by a finer 4K mapping.
      l1_ppn = _alloc_ppn();
      pte2   = _make_pointer_pte(l1_ppn);
      write_pte_at(pte_addr_2, pte2);
    end else begin
      // Reuse existing non-leaf PTE's PPN
      l1_ppn = pte2[PTE_PPN_LSB +: PPN_WIDTH];
    end

    // ---- Level 1 (L1 → L0) --------------------------------------------------
    pte_addr_1 = _pte_addr(l1_ppn, vpn1);
    pte1       = read_pte_at(pte_addr_1);
    if (!pte1[PTE_V] || pte1[PTE_R] || pte1[PTE_W] || pte1[PTE_X]) begin
      // No L0 page table yet, or an existing 2M leaf is being replaced by 4K
      // mappings under the same VPN[2:1].
      l0_ppn = _alloc_ppn();
      pte1   = _make_pointer_pte(l0_ppn);
      write_pte_at(pte_addr_1, pte1);
    end else begin
      l0_ppn = pte1[PTE_PPN_LSB +: PPN_WIDTH];
    end

    // ---- Level 0 (leaf) -----------------------------------------------------
    leaf_ppn   = pa[PA_WIDTH-1:PAGE_OFFSET];  // PA[39:12]
    pte0       = make_pte(.ppn(leaf_ppn), .v(v), .r(r), .w(w), .x(x),
                          .u(u), .g(g), .a(a), .d(d));
    pte_addr_0 = _pte_addr(l0_ppn, vpn0);
    write_pte_at(pte_addr_0, pte0);

    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("map_4k: va=0x%010h → pa=0x%010h ppn=0x%07h pte=0x%016h",
        va, pa, leaf_ppn, pte0), UVM_MEDIUM)
  endfunction

  // Map a 2M huge page: VA → PA.
  // Non-leaf PTE at level-2; mega-leaf at level-1 with PPN[8:0]=0.
  virtual function void map_2m(
    va_t va,
    pa_t pa,
    bit  v = 1,
    bit  r = 1,
    bit  w = 1,
    bit  x = 1,
    bit  u = 0,
    bit  g = 0,
    bit  a = 1,
    bit  d = 1
  );
    logic [8:0] vpn2, vpn1;
    pa_t        pte_addr_2, pte_addr_1;
    pte_t       pte2, pte1;
    ppn_t       l1_ppn, leaf_ppn;

    vpn2 = va[38:30];
    vpn1 = va[29:21];

    if (va[20:0] != 21'b0)
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("map_2m: VA 0x%010h is not 2M-aligned; low offset bits are ignored", va))
    if (pa[20:0] != 21'b0)
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("map_2m: PA 0x%010h is not 2M-aligned; PPN[8:0] will be forced to 0", pa))

    // ---- Level 2 (root -> L1) ----------------------------------------------
    pte_addr_2 = _pte_addr(m_root_ppn, vpn2);
    pte2       = read_pte_at(pte_addr_2);
    if (!pte2[PTE_V] || pte2[PTE_R] || pte2[PTE_W] || pte2[PTE_X]) begin
      l1_ppn = _alloc_ppn();
      pte2   = _make_pointer_pte(l1_ppn);
      write_pte_at(pte_addr_2, pte2);
    end else begin
      l1_ppn = pte2[PTE_PPN_LSB +: PPN_WIDTH];
    end

    // ---- Level 1 (leaf) ----------------------------------------------------
    leaf_ppn   = pa[PA_WIDTH-1:PAGE_OFFSET];
    leaf_ppn[8:0] = 9'b0;
    pte1       = make_pte(.ppn(leaf_ppn), .v(v), .r(r), .w(w), .x(x),
                          .u(u), .g(g), .a(a), .d(d));
    pte_addr_1 = _pte_addr(l1_ppn, vpn1);
    write_pte_at(pte_addr_1, pte1);

    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("map_2m: va=0x%010h -> pa=0x%010h ppn=0x%07h pte=0x%016h",
        va, pa, leaf_ppn, pte1), UVM_MEDIUM)
  endfunction

  // Map a 1G huge page: VA → PA.
  // Giga-leaf at level-2; PPN[17:0]=0 required.
  virtual function void map_1g(
    va_t va,
    pa_t pa,
    bit  v = 1,
    bit  r = 1,
    bit  w = 1,
    bit  x = 1,
    bit  u = 0,
    bit  g = 0,
    bit  a = 1,
    bit  d = 1
  );
    logic [8:0] vpn2;
    pa_t        pte_addr_2;
    pte_t       pte2;
    ppn_t       leaf_ppn;

    vpn2 = va[38:30];

    if (va[29:0] != 30'b0)
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("map_1g: VA 0x%010h is not 1G-aligned; low offset bits are ignored", va))
    if (pa[29:0] != 30'b0)
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("map_1g: PA 0x%010h is not 1G-aligned; PPN[17:0] will be forced to 0", pa))

    leaf_ppn      = pa[PA_WIDTH-1:PAGE_OFFSET];
    leaf_ppn[17:0] = 18'b0;
    pte2          = make_pte(.ppn(leaf_ppn), .v(v), .r(r), .w(w), .x(x),
                             .u(u), .g(g), .a(a), .d(d));
    pte_addr_2    = _pte_addr(m_root_ppn, vpn2);
    write_pte_at(pte_addr_2, pte2);

    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("map_1g: va=0x%010h -> pa=0x%010h ppn=0x%07h pte=0x%016h",
        va, pa, leaf_ppn, pte2), UVM_MEDIUM)
  endfunction

  // Remove (invalidate) a 4K leaf PTE by clearing the V bit.
  virtual function void invalidate(va_t va);
    logic [8:0] vpn2, vpn1, vpn0;
    pa_t        pte_addr_2, pte_addr_1, pte_addr_0;
    pte_t       pte2, pte1;
    ppn_t       l1_ppn, l0_ppn;

    vpn2 = va[38:30];  vpn1 = va[29:21];  vpn0 = va[20:12];

    pte_addr_2 = _pte_addr(m_root_ppn, vpn2);
    pte2 = read_pte_at(pte_addr_2);
    if (!pte2[PTE_V]) return;
    l1_ppn = pte2[PTE_PPN_LSB +: PPN_WIDTH];

    pte_addr_1 = _pte_addr(l1_ppn, vpn1);
    pte1 = read_pte_at(pte_addr_1);
    if (!pte1[PTE_V]) return;
    l0_ppn = pte1[PTE_PPN_LSB +: PPN_WIDTH];

    pte_addr_0 = _pte_addr(l0_ppn, vpn0);
    // Clear V bit to invalidate
    begin
      pte_t pte0 = read_pte_at(pte_addr_0);
      pte0[PTE_V] = 1'b0;
      write_pte_at(pte_addr_0, pte0);
    end
    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("invalidate: va=0x%010h cleared V bit", va), UVM_MEDIUM)
  endfunction

  // Inject a specific fault condition into the PTE for a mapped VA.
  // fault_kind: "V_OFF"          — clear V bit
  //             "RW_RESERVED"    — set R=0,W=1 (RISC-V reserved → page fault)
  //             "A_OFF"          — clear A bit
  //             "D_OFF"          — clear D bit  
  //             "MISALIGNED"     — set non-zero PPN[8:0] in huge-page entry
  //             "U_VIOLATION"    — flip U bit (user/supervisor mismatch)
  //             "RESERVED_BITS"  — set RSW bits (bits [9:8]) to non-zero
  virtual function void inject_fault(va_t va, string fault_kind);
    logic [8:0] vpn2, vpn1, vpn0;
    pa_t        pte_addr_2, pte_addr_1, pte_addr_0;
    pte_t       pte2, pte1, pte0;
    ppn_t       l1_ppn, l0_ppn;

    vpn2 = va[38:30];  vpn1 = va[29:21];  vpn0 = va[20:12];

    pte_addr_2 = _pte_addr(m_root_ppn, vpn2);
    pte2 = read_pte_at(pte_addr_2);
    if (!pte2[PTE_V]) begin
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("inject_fault: no L2 PTE for va=0x%010h", va))
      return;
    end
    l1_ppn = pte2[PTE_PPN_LSB +: PPN_WIDTH];

    pte_addr_1 = _pte_addr(l1_ppn, vpn1);
    pte1 = read_pte_at(pte_addr_1);
    if (!pte1[PTE_V]) begin
      `uvm_warning("PAGE_TABLE_BUILDER",
        $sformatf("inject_fault: no L1 PTE for va=0x%010h", va))
      return;
    end
    l0_ppn = pte1[PTE_PPN_LSB +: PPN_WIDTH];

    pte_addr_0 = _pte_addr(l0_ppn, vpn0);
    pte0 = read_pte_at(pte_addr_0);

    case (fault_kind)
      "V_OFF":         pte0[PTE_V]     = 1'b0;
      "RW_RESERVED":   begin pte0[PTE_R] = 1'b0; pte0[PTE_W] = 1'b1; end
      "A_OFF":         pte0[PTE_A]     = 1'b0;
      "D_OFF":         pte0[PTE_D]     = 1'b0;
      "U_VIOLATION":   pte0[PTE_U]     = ~pte0[PTE_U];
      "RESERVED_BITS": pte0[9:8]       = 2'b11;
      "MISALIGNED":    /* Phase 5: set lower PPN bits non-zero for huge page */ ;
      default:
        `uvm_warning("PAGE_TABLE_BUILDER",
          $sformatf("inject_fault: unknown fault_kind '%s'", fault_kind))
    endcase

    write_pte_at(pte_addr_0, pte0);
    `uvm_info("PAGE_TABLE_BUILDER",
      $sformatf("inject_fault: va=0x%010h kind=%s pte=0x%016h",
        va, fault_kind, pte0), UVM_MEDIUM)
  endfunction

  // Clear all entries (reset the shadow memory)
  virtual function void clear();
    m_mem.delete();
    `uvm_info("PAGE_TABLE_BUILDER", "Page table memory cleared", UVM_MEDIUM)
  endfunction

endclass : page_table_builder

`endif // PAGE_TABLE_BUILDER_SVH
