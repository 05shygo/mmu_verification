// =============================================================================
// MMU UVM Verification — testbench/env/mmu_ref_model.svh
// Phase 4: MMU software reference model
//
// Implements Sv39 3-level page walk in software, including 4K / 2M / 1G
// leaf translation. Acts as the golden model for translation_sb.
//
// CSR mirror fields are updated via four TLM FIFOs drained by sync_shadow_state()
// immediately before translation compares:
//   af_csr_write    ← cp0_monitor.ap       (fan-out, Phase 5 connect)
//   af_tlb_inv      ← lsu_monitor.ap_inv   (fan-out, Phase 5 connect)
//   af_pmp_cfg      ← pmp_monitor.ap       (fan-out, Phase 5 connect)
//   af_sysmap_cfg   ← sysmap_cfg_monitor.ap(fan-out, Phase 5 connect)
//
// In Phase 4 the FIFOs are created but not yet connected; tests set CSR
// mirror fields directly (m_ref.m_mmu_en = 1, etc.) for directed testing.
//
// translate() algorithm (Sv39, 3-level walk):
//   [Decision 1] If !m_mmu_en or satp_mode==0 → passthrough (PA = {1'b0,VA})
//   [Decision 2] Walk levels 2→1→0:
//     · PTE[V]=0            → EXC_PAGE_FAULT
//     · PTE[W]=1, PTE[R]=0  → EXC_PAGE_FAULT (RISC-V W/O reserved)
//     · PTE[R]||PTE[X]      → leaf (current level)
//     · else                → pointer → recurse next level
//   [Decision 3] At leaf:
//     · Privilege check (U bit vs priv_mode)
//     · Permission check (R/W/X per acc_type_e)
//     · A/D bit enforcement (A=0 faults; store with D=0 faults)
//     · Assemble PA from leaf PPN + VA page offset
// =============================================================================
`ifndef MMU_REF_MODEL_SVH
`define MMU_REF_MODEL_SVH

class mmu_ref_model extends uvm_component;

  `uvm_component_utils(mmu_ref_model)

  // =========================================================================
  // CSR mirror fields (set by on_csr_write() or directly by tests in Phase 4)
  // =========================================================================
  // SATP registers (two SATPs: satp0 / satp1)
  ppn_t     m_satp0_ppn,  m_satp1_ppn;
  asid_t    m_satp0_asid, m_satp1_asid;
  bit [3:0] m_satp0_mode, m_satp1_mode;  // 8 = Sv39, 0 = Bare
  bit       m_satp_sel;                  // 0 = satp0 active, 1 = satp1

  // Privilege and mode bits
  bit [1:0] m_priv;      // current privilege: 00=U, 01=S, 11=M
  bit       m_mxr;       // Make eXecutable Readable
  bit       m_sum;       // Supervisor User Memory access
  bit       m_mprv;      // Modify PRiVilege
  bit [1:0] m_mpp;       // Machine Previous Privilege (for MPRV)

  // MMU enable / PTW / misc
  bit       m_mmu_en;    // combinational: satp_mode==8 && priv != M
  bit       m_ptw_en;    // PTW hardware walker enable
  bit       m_maee;      // M-mode Address Extension Enable
  bit       m_no_op;     // Tracked for CP0 mirror / misc checks (not a global PA bypass)

  // =========================================================================
  // PMP / SysMap mirrors (updated by on_pmp_cfg / on_sysmap_cfg)
  // =========================================================================
  bit [3:0]  m_pmp_flg [PMP_ENTRIES];

  typedef struct {
    bit [27:0] base;
    bit [27:0] mask;
    bit [4:0]  flg;
    bit        enable;
  } sysmap_entry_t;
  sysmap_entry_t m_sysmap [SYSMAP_REGIONS];

  // =========================================================================
  // Shared shadow page table (set from env.build_phase)
  // =========================================================================
  mmu_page_table_mem m_pt;

  // =========================================================================
  // TLM FIFOs (Phase 5: connected from env.connect_phase to monitor APs)
  // =========================================================================
  uvm_tlm_analysis_fifo #(cp0_txn)        af_csr_write;
  uvm_tlm_analysis_fifo #(lsu_txn)        af_tlb_inv;
  uvm_tlm_analysis_fifo #(pmp_txn)        af_pmp_cfg;
  uvm_tlm_analysis_fifo #(sysmap_cfg_txn) af_sysmap_cfg;

  // ── Statistics ────────────────────────────────────────────────────────────
  int unsigned m_n_translate_calls;
  int unsigned m_n_page_faults;
  int unsigned m_n_passthrough;

  // DUT-facing scoreboards keep this enabled so translate() observes monitor
  // FIFO updates before each compare.  Pure software directed tests that set
  // mirror fields directly may disable it to keep those hand-written fields
  // authoritative.
  bit m_auto_sync_shadow_state;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    // Reset all CSR mirrors to safe defaults
    m_satp0_ppn   = '0; m_satp1_ppn   = '0;
    m_satp0_asid  = '0; m_satp1_asid  = '0;
    m_satp0_mode  = 4'h0; m_satp1_mode = 4'h0;
    m_satp_sel    = 1'b0;
    m_priv        = PRIV_M;  // default M-mode (MMU disabled)
    m_mxr         = 1'b0;
    m_sum         = 1'b0;
    m_mprv        = 1'b0;
    m_mpp         = PRIV_M;
    m_mmu_en      = 1'b0;
    m_ptw_en      = 1'b1;
    m_maee        = 1'b0;
    m_no_op       = 1'b0;
    m_auto_sync_shadow_state = 1'b1;
  // PMP default all-allow: flg[2:0]={X,W,R}=3'b111.
    foreach (m_pmp_flg[i]) m_pmp_flg[i] = 4'h7;
    // SysMap: default all disabled
    foreach (m_sysmap[i]) m_sysmap[i].enable = 1'b0;
  endfunction

  // =========================================================================
  // UVM phases
  // =========================================================================

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_csr_write  = new("af_csr_write",  this);
    af_tlb_inv    = new("af_tlb_inv",    this);
    af_pmp_cfg    = new("af_pmp_cfg",    this);
    af_sysmap_cfg = new("af_sysmap_cfg", this);
  endfunction

  // Do not consume the shadow FIFOs from a background run_phase thread.  The
  // translation scoreboard calls translate(), which drains the FIFOs
  // synchronously through sync_shadow_state() before each compare.  Keeping a
  // single consumer avoids non-deterministic same-cycle PMP/CSR shadow races.
  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      "ref-model shadow FIFOs are drained synchronously by sync_shadow_state()",
      UVM_HIGH)
  endtask

  // Drain any monitor-published shadow-state updates without consuming time.
  // Translation scoreboarding can run on the same sampled beat as CP0/PMP/
  // SysMap activity; pulling pending FIFO items here keeps the ref model's
  // SATP/CSR mirror coherent before a compare is made.
  virtual function void sync_shadow_state();
    cp0_txn        csr_tr;
    lsu_txn        inv_tr;
    pmp_txn        pmp_tr;
    sysmap_cfg_txn sysmap_tr;
    int unsigned   n_csr;
    int unsigned   n_inv;
    int unsigned   n_pmp;
    int unsigned   n_sysmap;

    n_csr    = 0;
    n_inv    = 0;
    n_pmp    = 0;
    n_sysmap = 0;

    while (af_csr_write.try_get(csr_tr)) begin
      on_csr_write(csr_tr);
      n_csr++;
    end

    while (af_tlb_inv.try_get(inv_tr)) begin
      on_tlb_inv(inv_tr);
      n_inv++;
    end

    while (af_pmp_cfg.try_get(pmp_tr)) begin
      on_pmp_cfg_change(pmp_tr);
      n_pmp++;
    end

    while (af_sysmap_cfg.try_get(sysmap_tr)) begin
      on_sysmap_cfg_change(sysmap_tr);
      n_sysmap++;
    end

    if ((n_csr + n_inv + n_pmp + n_sysmap) != 0) begin
      `uvm_info(get_type_name(),
        $sformatf("sync_shadow_state: drained csr=%0d inv=%0d pmp=%0d sysmap=%0d before translate",
          n_csr, n_inv, n_pmp, n_sysmap),
        UVM_HIGH)
    end
  endfunction

  virtual function void set_auto_sync_shadow_state(bit enable);
    m_auto_sync_shadow_state = enable;
  endfunction

  protected function bit twu_leaf_page_fault(
    input pte_t      pte,
    input acc_type_e acc,
    input int        level,
    input bit [1:0]  eff_priv,
    input bit        mxr,
    input bit        sum
  );
    bit fault;
    fault = 1'b0;

    if (!pte[PTE_V])
      fault = 1'b1;
    if (pte[PTE_W] && !(pte[PTE_R] || (mxr && pte[PTE_X])))
      fault = 1'b1;

    case (acc)
      ACC_FETCH: begin
        if (!pte[PTE_X])
          fault = 1'b1;
      end
      ACC_LOAD: begin
        if (!pte[PTE_R] && !(mxr && pte[PTE_X]))
          fault = 1'b1;
      end
      ACC_PFU: begin
        // TWU page-fault logic has no PFU-specific R/W/X permission term.
      end
      ACC_STORE: begin
        if (!pte[PTE_W])
          fault = 1'b1;
      end
    endcase

    if ((eff_priv == PRIV_S) && pte[PTE_U] && !sum)
      fault = 1'b1;
    if ((eff_priv == PRIV_U) && !pte[PTE_U])
      fault = 1'b1;
    if (!pte[PTE_A])
      fault = 1'b1;
    if ((acc == ACC_STORE) && !pte[PTE_D])
      fault = 1'b1;

    if ((level == 2) && (pte[PTE_PPN_LSB +: 18] != 18'b0))
      fault = 1'b1;
    if ((level == 1) && (pte[PTE_PPN_LSB +: 9] != 9'b0))
      fault = 1'b1;

    return fault;
  endfunction

  protected function xlation_rsp_t translate_twu_core(
    input va_t       va,
    input acc_type_e acc,
    input ppn_t      active_ppn,
    input bit [3:0]  active_mode,
    input bit [1:0]  priv,
    input bit        mxr,
    input bit        sum,
    input bit        mprv,
    input bit [1:0]  mpp,
    input int        pmp_port_idx,
    input string     ctx
  );
    xlation_rsp_t rsp;
    bit [1:0] eff_priv;
    int resolved_pmp_port_idx;
    ppn_t cur_ppn;
    bit found_leaf;

    rsp = '{ppn: '0, exc: EXC_NONE,
            sec: 0, ca: 0, buf_en: 0, sh: 0, so: 0, deny: 0};

    eff_priv = priv;
    if (mprv && (acc != ACC_FETCH))
      eff_priv = mpp;

    if ((active_mode != 4'h8) || (eff_priv == PRIV_M)) begin
      rsp.ppn = va_t'(va) >> PAGE_OFFSET;
      if (direct_map_access_fault(rsp.ppn, acc)) begin
        rsp.deny = 1'b1;
        rsp.exc  = (acc == ACC_FETCH) ? EXC_PMP_DENY : EXC_ACCESS_FAULT;
      end
      return rsp;
    end

    if (pmp_port_idx >= 0) begin
      resolved_pmp_port_idx = pmp_port_idx;
    end else begin
      unique case (acc)
        ACC_FETCH: resolved_pmp_port_idx = 2;
        ACC_LOAD:  resolved_pmp_port_idx = 0;
        ACC_STORE: resolved_pmp_port_idx = 0;
        ACC_PFU:   resolved_pmp_port_idx = 4;
        default:   resolved_pmp_port_idx = 0;
      endcase
    end

    cur_ppn = active_ppn;
    found_leaf = 1'b0;

    for (int level = 2; level >= 0; level--) begin
      logic [PT_LEVEL_BITS-1:0] vpn_idx;
      pa_t pte_addr;
      pte_t pte;
      bit leaf_vld;
      ppn_t leaf_ppn;
      ppn_t final_ppn;

      vpn_idx  = va_vpn_level(va, level);
      pte_addr = pa_t'({cur_ppn, 12'b0}) + pa_t'({31'b0, vpn_idx, 3'b0});
      pte      = m_pt.m_builder.read_pte_at(pte_addr);
      leaf_vld = pte[PTE_V] && (pte[PTE_R] || pte[PTE_X]);

      `uvm_info(get_type_name(),
        $sformatf("translate_twu_core[%s] walk L%0d: vpn=0x%03h pte_addr=0x%010h pte=0x%016h leaf=%0b",
          ctx, level, vpn_idx, pte_addr, pte, leaf_vld),
        UVM_HIGH)

      // RTL TWU gates fst/scd page_flt with leaf_vld and only reports a
      // non-leaf-at-thd page fault at the final level.
      if (leaf_vld) begin
        found_leaf = 1'b1;
        if (twu_leaf_page_fault(pte, acc, level, eff_priv, mxr, sum)) begin
          rsp.exc = EXC_PAGE_FAULT;
          m_n_page_faults++;
          return rsp;
        end

        leaf_ppn = pte[PTE_PPN_LSB +: PPN_WIDTH];
        final_ppn = leaf_ppn;
        unique case (level)
          2: final_ppn = {leaf_ppn[PPN_WIDTH-1:18], va[29:12]};
          1: final_ppn = {leaf_ppn[PPN_WIDTH-1:9], va[20:12]};
          default: final_ppn = leaf_ppn;
        endcase
        rsp.ppn = final_ppn;

        begin
          pa_t pa_full = pa_t'({rsp.ppn, va[11:0]});
          if (!check_pmp_with_priv(pa_full, acc, resolved_pmp_port_idx, eff_priv)) begin
            rsp.deny = 1'b1;
            rsp.exc  = (acc == ACC_FETCH) ? EXC_PMP_DENY : EXC_ACCESS_FAULT;
          end
        end
        return rsp;
      end

      if (level == 0) begin
        rsp.exc = EXC_PAGE_FAULT;
        m_n_page_faults++;
        return rsp;
      end

      cur_ppn = pte[PTE_PPN_LSB +: PPN_WIDTH];
    end

    if (!found_leaf) begin
      rsp.exc = EXC_PAGE_FAULT;
      m_n_page_faults++;
    end
    return rsp;
  endfunction

  virtual function xlation_rsp_t translate_with_twu_context(
    input va_t       va,
    input acc_type_e acc,
    input ppn_t      satp_ppn,
    input bit [3:0]  satp_mode,
    input bit [1:0]  priv,
    input bit        mxr,
    input bit        sum,
    input bit        mprv,
    input bit [1:0]  mpp,
    input int        pmp_port_idx = -1,
    input string     ctx = "external"
  );
    m_n_translate_calls++;
    return translate_twu_core(va, acc, satp_ppn, satp_mode, priv, mxr, sum,
                              mprv, mpp, pmp_port_idx, ctx);
  endfunction

  // =========================================================================
  // Core API: translate()
  // =========================================================================
  // Perform a software Sv39 3-level page walk for the given VA and access type.
  //
  // [Decision 1] Passthrough conditions:
  //   a) m_mmu_en == 0 (satp_mode == 0 or M-mode): PA = {1'b0, VA[38:0]}
  //   b) M-mode with MPRV=0: passthrough (access uses M-mode effective priv)
  //
  // [Decision 2] Select active SATP:
  //   m_satp_sel=0 → satp0; m_satp_sel=1 → satp1
  //
  // [Decision 3] 3-level walk (level 2 → 1 → 0):
  //   · pte_addr = active_ppn_page_base + vpn_level(va, level) * 8
  //   · pte = m_pt.m_builder.read_pte_at(pte_addr)
  //   · V=0 → EXC_PAGE_FAULT
  //   · W=1, R=0 (reserved) → EXC_PAGE_FAULT
  //   · R=1 or X=1 → leaf (check permissions)
  //   · else → pointer (continue to next level)
  //
  // [Decision 4] Leaf permission checks:
  //   · U-bit vs privilege mode (SUM handling)
  //   · R/W/X permission vs acc_type_e (MXR for ACC_LOAD with X=1)
  //   · A/D bit: A=0 faults all accesses; D=0 faults stores
  //
  // [Decision 5] Assemble PA:
  //   level 0 (4K): PA[39:12] = leaf_ppn[27:0]
  //   level 1 (2M): PA[39:12] = {leaf_ppn[27:9],  VA[20:12]}
  //   level 2 (1G): PA[39:12] = {leaf_ppn[27:18], VA[29:12]}
  //   Misaligned superpages (leaf lower PPN bits non-zero) fault per Sv39.
  //
  // Returns xlation_rsp_t with ppn, exc, and attribute bits.
  // sec/ca/buf_en/sh/so are set to 0 in Phase 4 (Phase 5: drive from SysMap)
  // =========================================================================
  virtual function xlation_rsp_t translate(va_t va, acc_type_e acc, int pmp_port_idx = -1);
    xlation_rsp_t rsp;
    ppn_t   active_ppn;
    bit [3:0] active_mode;
    int     resolved_pmp_port_idx;

    rsp = '{ppn: '0, exc: EXC_NONE,
            sec: 0, ca: 0, buf_en: 0, sh: 0, so: 0, deny: 0};

    if (m_auto_sync_shadow_state)
      sync_shadow_state();
    m_n_translate_calls++;

    // ── [Decision 1] Passthrough ──────────────────────────────────────────
    // Effective privilege for translation:
    //   if MPRV=1 and acc != FETCH → use MPP as effective privilege
    //   otherwise → use current privilege
    begin
      bit [1:0] eff_priv = m_priv;
      if (m_mprv && (acc != ACC_FETCH)) eff_priv = m_mpp;

      // MMU is enabled only when satp_mode=8 AND effective privilege != M
      m_mmu_en = (m_satp_sel ? (m_satp1_mode == 4'h8) : (m_satp0_mode == 4'h8))
                 && (eff_priv != PRIV_M);

      if (!m_mmu_en) begin
        // Phase 4 passthrough: PA = zero-extend VA[38:0] to PA_WIDTH=40
        rsp.ppn = va_t'(va) >> PAGE_OFFSET;  // VA[39:12] zero-padded
        m_n_passthrough++;
        if (direct_map_access_fault(rsp.ppn, acc)) begin
          rsp.deny = 1'b1;
          rsp.exc  = (acc == ACC_FETCH) ? EXC_PMP_DENY : EXC_ACCESS_FAULT;
          `uvm_info(get_type_name(),
            $sformatf("translate PASSTHROUGH DENY(SysMap): va=0x%010h ppn=0x%07h acc=%s exc=%s",
              va, rsp.ppn, acc.name(), rsp.exc.name()),
            UVM_MEDIUM)
          return rsp;
        end
        `uvm_info(get_type_name(),
          $sformatf("translate PASSTHROUGH: va=0x%010h ppn=0x%07h mmu_en=%0b",
            va, rsp.ppn, m_mmu_en), UVM_HIGH)
        return rsp;
      end
    end

    // Use caller-provided PMP port when available (scoreboard knows channel).
    // Keep a conservative fallback mapping for direct unit tests.
    if (pmp_port_idx >= 0) begin
      resolved_pmp_port_idx = pmp_port_idx;
    end else begin
      unique case (acc)
        ACC_FETCH: resolved_pmp_port_idx = 2;
        ACC_LOAD:  resolved_pmp_port_idx = 0;
        ACC_STORE: resolved_pmp_port_idx = 0;
        ACC_PFU:   resolved_pmp_port_idx = 4;
        default:   resolved_pmp_port_idx = 0;
      endcase
    end

    // ── [Decision 2] Select active SATP ──────────────────────────────────
    if (m_satp_sel) begin
      active_ppn  = m_satp1_ppn;
      active_mode = m_satp1_mode;
    end else begin
      active_ppn  = m_satp0_ppn;
      active_mode = m_satp0_mode;
    end

    if (active_mode != 4'h8) begin
      // Non-Sv39 mode → passthrough (should not reach here given m_mmu_en check)
      rsp.ppn = va >> PAGE_OFFSET;
      m_n_passthrough++;
      return rsp;
    end

    // ── [Decision 3] Sv39 3-level page walk ──────────────────────────────
    begin
      automatic ppn_t  cur_ppn = active_ppn;
      automatic int    level;
      automatic pa_t   pte_addr;
      automatic pte_t  pte;
      automatic bit    is_leaf;
      automatic ppn_t  leaf_ppn;
      automatic ppn_t  final_ppn;

      is_leaf = 0;

      for (level = 2; level >= 0; level--) begin
        automatic logic [PT_LEVEL_BITS-1:0] vpn_idx = va_vpn_level(va, level);

        // Compute PTE address: ppn_page_base + vpn_idx * 8
        pte_addr = pa_t'({cur_ppn, 12'b0}) + pa_t'({31'b0, vpn_idx, 3'b0});
        pte      = m_pt.m_builder.read_pte_at(pte_addr);

        `uvm_info(get_type_name(),
          $sformatf("  walk L%0d: vpn=0x%03h pte_addr=0x%010h pte=0x%016h",
            level, vpn_idx, pte_addr, pte), UVM_HIGH)

        // ---- Check V bit -----------------------------------------------
        // Decision: PTE[V]=0 → page fault
        if (!pte[PTE_V]) begin
          rsp.exc = EXC_PAGE_FAULT;
          m_n_page_faults++;
          `uvm_info(get_type_name(),
            $sformatf("translate PAGE_FAULT (V=0): va=0x%010h L%0d pte_addr=0x%010h",
              va, level, pte_addr), UVM_MEDIUM)
          return rsp;
        end

        // ---- Check for RTL write-only encoding -------------------------
        // TWU allows W=1,R=0,X=1 when MXR makes X readable.
        if (pte[PTE_W] && !(pte[PTE_R] || (m_mxr && pte[PTE_X]))) begin
          rsp.exc = EXC_PAGE_FAULT;
          m_n_page_faults++;
          `uvm_info(get_type_name(),
            $sformatf("translate PAGE_FAULT (write-only): va=0x%010h L%0d",
              va, level), UVM_MEDIUM)
          return rsp;
        end

        // ---- Leaf detection --------------------------------------------
        // Decision: R=1 or X=1 → leaf PTE at this level
        if (pte[PTE_R] || pte[PTE_X]) begin
          is_leaf  = 1;
          leaf_ppn = pte[PTE_PPN_LSB +: PPN_WIDTH];

          // ---- [Decision 4] Permission checks -------------------------
          // Privilege vs U-bit
          begin
            bit [1:0] eff_priv = m_priv;
            if (m_mprv && (acc != ACC_FETCH)) eff_priv = m_mpp;

            if ((eff_priv == PRIV_U) && !pte[PTE_U]) begin
              // U-mode accessing S-page → page fault
              rsp.exc = EXC_PAGE_FAULT;
              m_n_page_faults++;
              `uvm_info(get_type_name(),
                $sformatf("translate PAGE_FAULT (U-mode,U=0): va=0x%010h",va),
                UVM_MEDIUM)
              return rsp;
            end
            if ((eff_priv == PRIV_S) && pte[PTE_U] && !m_sum) begin
              // S-mode accessing U-page without SUM → page fault
              rsp.exc = EXC_PAGE_FAULT;
              m_n_page_faults++;
              `uvm_info(get_type_name(),
                $sformatf("translate PAGE_FAULT (S-mode,U=1,SUM=0): va=0x%010h",va),
                UVM_MEDIUM)
              return rsp;
            end
          end

          // R/W/X permission vs access type
          // Decision branch: check permission per acc_type_e
          case (acc)
            ACC_FETCH: begin
              // Instruction fetch requires X=1
              if (!pte[PTE_X]) begin
                rsp.exc = EXC_PAGE_FAULT;
                m_n_page_faults++;
                `uvm_info(get_type_name(),
                  $sformatf("translate PAGE_FAULT (FETCH,X=0): va=0x%010h",va),
                  UVM_MEDIUM)
                return rsp;
              end
            end
            ACC_LOAD: begin
              // Load: R=1; or MXR=1 and X=1 (readable via execute-only mapping)
              if (!pte[PTE_R] && !(m_mxr && pte[PTE_X])) begin
                rsp.exc = EXC_PAGE_FAULT;
                m_n_page_faults++;
                `uvm_info(get_type_name(),
                  $sformatf("translate PAGE_FAULT (LOAD,R=0): va=0x%010h",va),
                  UVM_MEDIUM)
                return rsp;
              end
            end
            ACC_PFU: begin
              // PFU follows TWU: no R/W/X permission term; write-only, U/S,
              // A-bit, and alignment checks still apply.
            end
            ACC_STORE: begin
              // Store follows the RTL TWU formula: W=1 is sufficient here;
              // write-only reserved encodings are handled by the earlier
              // R=0,W=1 check.
              if (!pte[PTE_W]) begin
                rsp.exc = EXC_PAGE_FAULT;
                m_n_page_faults++;
                `uvm_info(get_type_name(),
                  $sformatf("translate PAGE_FAULT (STORE,W=0): va=0x%010h",va),
                  UVM_MEDIUM)
                return rsp;
              end
            end
          endcase

          // A/D bit check: A=0 faults all accesses; D=0 faults stores.
          if (!pte[PTE_A]) begin
            rsp.exc = EXC_PAGE_FAULT;
            m_n_page_faults++;
            `uvm_info(get_type_name(),
              $sformatf("translate PAGE_FAULT (A=0): va=0x%010h",va),
              UVM_MEDIUM)
            return rsp;
          end
          if ((acc == ACC_STORE) && !pte[PTE_D]) begin
            rsp.exc = EXC_PAGE_FAULT;
            m_n_page_faults++;
            `uvm_info(get_type_name(),
              $sformatf("translate PAGE_FAULT (STORE,D=0): va=0x%010h",va),
              UVM_MEDIUM)
            return rsp;
          end

          // ---- [Decision 5] Assemble PA --------------------------------
          // Sv39 superpages splice lower PA PPN bits from the VA VPN fields.
          // The leaf PTE must therefore be aligned at the corresponding level.
          final_ppn = leaf_ppn;
          unique case (level)
            2: begin
              if (leaf_ppn[17:0] != '0) begin
                rsp.exc = EXC_PAGE_FAULT;
                m_n_page_faults++;
                `uvm_info(get_type_name(),
                  $sformatf("translate PAGE_FAULT (misaligned 1G leaf): va=0x%010h leaf_ppn=0x%07h",
                    va, leaf_ppn),
                  UVM_MEDIUM)
                return rsp;
              end
              final_ppn = {leaf_ppn[PPN_WIDTH-1:18], va[29:12]};
            end
            1: begin
              if (leaf_ppn[8:0] != '0) begin
                rsp.exc = EXC_PAGE_FAULT;
                m_n_page_faults++;
                `uvm_info(get_type_name(),
                  $sformatf("translate PAGE_FAULT (misaligned 2M leaf): va=0x%010h leaf_ppn=0x%07h",
                    va, leaf_ppn),
                  UVM_MEDIUM)
                return rsp;
              end
              final_ppn = {leaf_ppn[PPN_WIDTH-1:9], va[20:12]};
            end
            default: begin
              final_ppn = leaf_ppn;
            end
          endcase
          rsp.ppn = final_ppn;

          // PMP deny is modeled as fault-class outcome so translation_sb can
          // compare against IFU deny / LSU access_fault consistently.
          begin
            pa_t pa_full = pa_t'({rsp.ppn, va[11:0]});
            if (!check_pmp(pa_full, acc, resolved_pmp_port_idx)) begin
              rsp.deny = 1'b1;
              rsp.exc  = (acc == ACC_FETCH) ? EXC_PMP_DENY : EXC_ACCESS_FAULT;
              `uvm_info(get_type_name(),
                $sformatf("translate DENY(PMP): va=0x%010h pa=0x%010h acc=%s port=%0d exc=%s",
                  va, pa_full, acc.name(), resolved_pmp_port_idx, rsp.exc.name()),
                UVM_MEDIUM)
              return rsp;
            end
          end

          `uvm_info(get_type_name(),
            $sformatf("translate OK: va=0x%010h → ppn=0x%07h leaf_ppn=0x%07h L%0d pte=0x%016h",
              va, rsp.ppn, leaf_ppn, level, pte), UVM_MEDIUM)
          return rsp;
        end

        // ---- Pointer PTE: continue to next level ----------------------
        // Decision: V=1, R=0, X=0 → non-leaf; next_ppn = PTE[53:10]
        cur_ppn = pte[PTE_PPN_LSB +: PPN_WIDTH];

      end // for level

      // Walked all 3 levels without finding a leaf — should not happen for
      // correctly structured PT, but guard against it
      rsp.exc = EXC_PAGE_FAULT;
      m_n_page_faults++;
      `uvm_warning(get_type_name(),
        $sformatf("translate PAGE_FAULT (3-level exhausted): va=0x%010h", va))
    end

    return rsp;
  endfunction

  // =========================================================================
  protected function bit check_pmp_with_priv(
    input pa_t      pa,
    input acc_type_e acc,
    input int       port_idx,
    input bit [1:0] eff_priv
  );
    bit [3:0] flg;
    // DUT-side semantics are allow bits:
    //   flg[0]=R allow, flg[1]=W allow, flg[2]=X allow, flg[3]=L/M-mode guard.
    // See mmu_l1dtlb_hit_rd.sv / mmu_l1itlb.sv.
    if (port_idx < 0 || port_idx >= PMP_ENTRIES) return 1'b1;
    flg = m_pmp_flg[port_idx];

    if ((eff_priv == PRIV_M) && !flg[3]) return 1'b1;

    unique case (acc)
      ACC_FETCH: return flg[2];
      ACC_LOAD:  return flg[0];
      ACC_PFU:   return flg[0];
      ACC_STORE: return flg[1];
      default:   return 1'b1;
    endcase
  endfunction

  // PMP check (stub — Phase 5 for full 8-port check)
  // =========================================================================
  virtual function bit check_pmp(pa_t pa, acc_type_e acc, int port_idx);
    return check_pmp_with_priv(pa, acc, port_idx, m_priv);
  endfunction

  // =========================================================================
  // SysMap lookup (stub — Phase 5 for full base/mask/flag check)
  // =========================================================================
  virtual function sysmap_entry_t lookup_sysmap(pa_t pa);
    sysmap_entry_t hit;
    hit.enable = 0;
    foreach (m_sysmap[i]) begin
      if (m_sysmap[i].enable) begin
        bit [27:0] masked_pa   = pa[39:12] & m_sysmap[i].mask;
        bit [27:0] masked_base = m_sysmap[i].base & m_sysmap[i].mask;
        if (masked_pa == masked_base) begin
          hit = m_sysmap[i];
          return hit;
        end
      end
    end
    return hit;
  endfunction

  protected function bit [4:0] rtl_default_sysmap_flg(input ppn_t ppn);
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
    return 5'b10011;
  endfunction

  protected function bit [4:0] direct_map_sysmap_flg(input ppn_t ppn);
    // PFU direct-map uses ct_mmu_sysmap's compile-time macro table.  The
    // sysmap_cfg_agent mirror is not forced into that RTL table.
    return rtl_default_sysmap_flg(ppn);
  endfunction

  protected function bit direct_map_access_fault(input ppn_t ppn, input acc_type_e acc);
    bit [4:0] flg;
    flg = direct_map_sysmap_flg(ppn);
    case (acc)
      ACC_PFU: return (flg[4] || !flg[3]);
      default: return 1'b0;
    endcase
  endfunction

  // =========================================================================
  // Internal state update callbacks (called from sync_shadow_state())
  // =========================================================================

  // Update CSR mirrors from a cp0_txn (driven by cp0_agent)
  virtual function void on_csr_write(cp0_txn tr);
    case (tr.op)
      CP0_WRITE_SATP: begin
        if (!tr.satp_sel) begin
          m_satp0_mode = tr.wdata[63:60];
          m_satp0_asid = tr.wdata[59:44];
          m_satp0_ppn  = tr.wdata[PPN_WIDTH-1:0];
        end else begin
          m_satp1_mode = tr.wdata[63:60];
          m_satp1_asid = tr.wdata[59:44];
          m_satp1_ppn  = tr.wdata[PPN_WIDTH-1:0];
        end
        // SATP write and privilege/no-op controls are observed by independent
        // monitor threads; snapshot the same-cycle context here so a SATP write
        // cannot leave the ref mirror transiently in bare/M-mode semantics.
        m_priv   = tr.priv_mode;
        m_mxr    = tr.mxr;
        m_sum    = tr.sum;
        m_mprv   = tr.mprv;
        m_mpp    = tr.mpp;
        m_ptw_en = tr.ptw_en;
        m_no_op  = tr.no_op_req;
        m_maee   = tr.maee;
      end
      CP0_SET_PRIV:     m_priv  = tr.priv_mode;
      CP0_SET_MXR:      m_mxr   = tr.mxr;
      CP0_SET_SUM:      m_sum   = tr.sum;
      CP0_SET_MPRV_MPP: begin m_mprv = tr.mprv; m_mpp = tr.mpp; end
      CP0_SET_PTW_EN:   m_ptw_en = tr.ptw_en;
      CP0_SET_NO_OP:    m_no_op  = tr.no_op_req;
      CP0_SET_MAEE:     m_maee   = tr.maee;
      default: /* other ops don't affect ref model CSR mirror */ ;
    endcase
    // Recompute m_mmu_en combinationally based on new CSR state
    m_mmu_en = (m_satp_sel ? (m_satp1_mode == 4'h8) : (m_satp0_mode == 4'h8))
               && (m_priv != PRIV_M);
    `uvm_info(get_type_name(),
      $sformatf("on_csr_write: op=%s mmu_en=%0b priv=%02b",
        tr.op.name(), m_mmu_en, m_priv), UVM_HIGH)
  endfunction

  // Update TLB shadow on invalidation (Phase 5: propagate to TLB mirror)
  virtual function void on_tlb_inv(lsu_txn tr);
    // TODO (Phase 5): clear matching entries from shadow TLB arrays
  endfunction

  // Update PMP flag mirrors
  virtual function void on_pmp_cfg_change(pmp_txn tr);
    if (!tr.cfg_update) begin
      `uvm_info(get_type_name(),
        "on_pmp_cfg_change: ignoring PMP PA/fetch observation sample",
        UVM_DEBUG)
      return;
    end
    foreach (tr.flg[i])
      m_pmp_flg[i] = tr.flg[i];
    `uvm_info(get_type_name(), "on_pmp_cfg_change: PMP flags updated", UVM_HIGH)
  endfunction

  // Update SysMap region mirrors
  virtual function void on_sysmap_cfg_change(sysmap_cfg_txn tr);
    foreach (m_sysmap[i]) begin
      m_sysmap[i].base   = tr.base[i];
      m_sysmap[i].mask   = tr.mask[i];
      m_sysmap[i].flg    = tr.flg[i];
      m_sysmap[i].enable = tr.enable[i];
    end
    `uvm_info(get_type_name(), "on_sysmap_cfg_change: SysMap updated", UVM_HIGH)
  endfunction

  // =========================================================================
  // report_phase: print translation statistics
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("ref_model stats: calls=%0d page_faults=%0d passthrough=%0d",
        m_n_translate_calls, m_n_page_faults, m_n_passthrough), UVM_LOW)
  endfunction

endclass : mmu_ref_model

`endif // MMU_REF_MODEL_SVH
