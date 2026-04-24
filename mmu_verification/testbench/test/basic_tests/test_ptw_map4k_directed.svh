// =============================================================================
// MMU UVM Verification — testbench/test/basic_tests/test_ptw_map4k_directed.svh
// Phase 4: PTW memory model + reference model directed test
//
// PURPOSE:
//   Validate that page_table_builder.map_4k() correctly writes all three
//   levels of the Sv39 page table and that mmu_ref_model.translate() walks
//   those entries and returns the expected PA with zero mismatches.
//   This is a PURE SOFTWARE test — IFU/LSU channels are idle; no DUT
//   translation result is compared here.  DUT exercise begins in Phase 5.
//
// EXIT CRITERIA (Phase 4 §4):
//   · ≥10 map_4k() mappings per run, 5 independent seeds, UVM_ERROR=0
//   · translate() called 50 times per run with random VA, mismatch=0
//
// TEST FLOW:
//   1. Configure ref_model CSR mirror directly (M4 direct-set, Phase 5 uses
//      the FIFO path from cp0_monitor)
//   2. Set SATP root in page_table_builder
//   3. Build NUM_MAP random 4K mappings (VA→PA pairs stored in arrays)
//   4. Verify each mapping: ref_model.translate(va) → expected_ppn → assert
//   5. Also verify page-fault path: unmapped VA returns EXC_PAGE_FAULT
// =============================================================================
`ifndef TEST_PTW_MAP4K_DIRECTED_SVH
`define TEST_PTW_MAP4K_DIRECTED_SVH

class test_ptw_map4k_directed extends test_base;

  `uvm_component_utils(test_ptw_map4k_directed)

  // ── Configuration constants ───────────────────────────────────────────────
  // Root page PPN (value chosen to not collide with page_table_builder
  // auto-allocator which starts at root_ppn + 16)
  localparam ppn_t  ROOT_PPN  = 28'h10;
  localparam asid_t ROOT_ASID = 16'hABCD;

  // Number of 4K mappings to build and verify per run
  localparam int NUM_MAP   = 50;   // satisfies ≥10 and ≥50 translate() calls
  localparam int NUM_FAULT = 10;   // unmapped VAs to check for page-fault

  // ── State ─────────────────────────────────────────────────────────────────
  va_t m_va [NUM_MAP];
  pa_t m_pa [NUM_MAP];
  int  m_mismatch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    mmu_ref_model      ref;
    mmu_page_table_mem pt;
    xlation_rsp_t      rsp;
    ppn_t              expected_ppn;

    ref = m_env.m_ref;
    pt  = m_env.m_pt_mem;
    m_mismatch = 0;

    // ── Step 1: Configure ref_model CSR mirror ────────────────────────────
    // Direct assignment (FIFO path connected in Phase 5)
    ref.m_satp0_mode = 4'h8;          // Sv39
    ref.m_satp0_ppn  = ROOT_PPN;
    ref.m_satp0_asid = ROOT_ASID;
    ref.m_satp_sel   = 1'b0;          // Use SATP0
    ref.m_priv       = PRIV_S;        // S-mode (mmu_en = 1)
    ref.m_ptw_en     = 1'b1;
    ref.m_mmu_en     = 1'b1;          // Force: mode=Sv39, S-mode → MMU enabled
    ref.m_no_op      = 1'b0;
    ref.m_mxr        = 1'b0;
    ref.m_sum        = 1'b0;

    // ── Step 2: Set builder root ──────────────────────────────────────────
    pt.m_builder.set_root(ROOT_PPN, ROOT_ASID);

    `uvm_info(get_type_name(),
      $sformatf("map4k test: NUM_MAP=%0d ROOT_PPN=0x%07h", NUM_MAP, ROOT_PPN),
      UVM_LOW)

    // ── Step 3: Build NUM_MAP random canonical 4K mappings ───────────────
    for (int i = 0; i < NUM_MAP; i++) begin
      // Generate a random canonical Sv39 VA:
      //   bit 38 = 0 (user space), bits [38:30] != 9'h1ff (avoid TLB alias)
      //   bits [11:0] are ignored for page mapping but forced 0 for clarity
      m_va[i] = va_t'($urandom()) & 39'h7FFFFF_FFF;
      m_va[i][11:0] = 12'b0;   // page-aligned
      // Avoid all-zero VA (common reset state) and reserved regions
      if (m_va[i] == '0) m_va[i] = va_t'(39'h1000);

      // Generate a random valid 4K physical address (40-bit, page-aligned)
      m_pa[i] = pa_t'($urandom()) & 40'hFF_FFFF_FFF;
      m_pa[i][11:0] = 12'b0;   // page-aligned

      pt.m_builder.map_4k(
        .va(m_va[i]), .pa(m_pa[i]),
        .v(1), .r(1), .w(1), .x(0),   // RW data mapping
        .u(0), .g(0), .a(1), .d(1)
      );
      `uvm_info(get_type_name(),
        $sformatf("  map[%0d]: va=0x%010h → pa=0x%010h ppn=0x%07h",
          i, m_va[i], m_pa[i], m_pa[i][39:12]), UVM_HIGH)
    end

    // Small settling delay (not needed for pure SW test, but keeps timing
    // consistent with future DUT-exercising tests that run at sim time)
    #10ns;

    // ── Step 4: Verify all mappings via ref_model.translate() ────────────
    for (int i = 0; i < NUM_MAP; i++) begin
      expected_ppn = m_pa[i][39:12];   // PA[39:12]
      rsp = ref.translate(m_va[i], ACC_LOAD);

      if (rsp.exc != EXC_NONE) begin
        `uvm_error(get_type_name(),
          $sformatf("map4k[%0d] FAULT: va=0x%010h exc=%s (expected EXC_NONE)",
            i, m_va[i], rsp.exc.name()))
        m_mismatch++;
      end else if (rsp.ppn !== expected_ppn) begin
        `uvm_error(get_type_name(),
          $sformatf("map4k[%0d] MISMATCH: va=0x%010h got_ppn=0x%07h exp_ppn=0x%07h",
            i, m_va[i], rsp.ppn, expected_ppn))
        m_mismatch++;
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("map4k[%0d] PASS: va=0x%010h → ppn=0x%07h",
            i, m_va[i], rsp.ppn), UVM_HIGH)
      end
    end

    // ── Step 5: Verify page-fault path for unmapped VAs ──────────────────
    for (int j = 0; j < NUM_FAULT; j++) begin
      va_t fault_va;
      // Generate a VA unlikely to collide with any mapped entry
      fault_va = va_t'(39'h3_0000_0000 | (j * 39'h1000));
      rsp = ref.translate(fault_va, ACC_LOAD);
      if (rsp.exc !== EXC_PAGE_FAULT) begin
        `uvm_error(get_type_name(),
          $sformatf("fault_va[%0d]=0x%010h: expected PAGE_FAULT, got exc=%s ppn=0x%07h",
            j, fault_va, rsp.exc.name(), rsp.ppn))
        m_mismatch++;
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("fault_va[%0d]=0x%010h PAGE_FAULT PASS", j, fault_va),
          UVM_HIGH)
      end
    end

    // ── Summary ────────────────────────────────────────────────────────────
    if (m_mismatch == 0) begin
      `uvm_info(get_type_name(),
        $sformatf("map4k directed test PASSED: %0d mappings + %0d fault paths, mismatch=0",
          NUM_MAP, NUM_FAULT), UVM_NONE)
    end else begin
      `uvm_error(get_type_name(),
        $sformatf("map4k directed test FAILED: mismatch=%0d", m_mismatch))
    end

    #50ns;
  endtask

endclass : test_ptw_map4k_directed

`endif // TEST_PTW_MAP4K_DIRECTED_SVH
