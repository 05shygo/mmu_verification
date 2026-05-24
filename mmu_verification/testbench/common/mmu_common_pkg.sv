// =============================================================================
// MMU UVM Verification — testbench/common/mmu_common_pkg.sv
// Phase 2: PTE utilities, VA segment helpers, exception type enum
// Shared helpers live here so sequences, scoreboards, and SVA use one model.
// =============================================================================
package mmu_common_pkg;

  import mmu_params_pkg::*;

  // =========================================================================
  // Exception Type (shared by ref_model and all Scoreboards)
  // =========================================================================
  typedef enum bit [2:0] {
    EXC_NONE         = 3'd0,
    EXC_PAGE_FAULT   = 3'd1,
    EXC_ACCESS_FAULT = 3'd2,
    EXC_PMP_DENY     = 3'd3,
    EXC_BUS_ERROR    = 3'd4
  } mmu_exc_e;

  // =========================================================================
  // Translation Response (used by ref_model and translation_sb)
  // =========================================================================
  typedef struct packed {
    logic [PPN_WIDTH-1:0] ppn;    // Physical Page Number (no page offset)
    mmu_exc_e             exc;
    logic                 sec;    // Secure
    logic                 ca;     // Cacheable
    logic                 buf_en; // Bufferable
    logic                 sh;     // Shareable
    logic                 so;     // Strongly-ordered
    logic                 deny;   // Sysmap/PMP access denied
  } xlation_rsp_t;

  typedef logic [L2_TLB_WAYS*8-1:0] l2tlb_idx_bus_t;
  typedef logic [L2_TLB_WAYS*3-1:0] l2tlb_size_bus_t;

  // =========================================================================
  // L2TLB Hash / Skew Golden Model
  // Mirrors mmu_arb.sv selector, size prediction, raw index, and skew rules.
  // This is pure combinational address modeling; replacement/victim state is
  // intentionally modeled elsewhere.
  // =========================================================================
  function automatic logic [7:0] l2tlb_reverse8(input logic [7:0] in);
    for (int i = 0; i < 8; i++)
      l2tlb_reverse8[i] = in[7-i];
  endfunction

  function automatic logic [2:0] l2tlb_size_pred(
    input logic [1:0] selector,
    input logic [2:0] way
  );
    unique case (selector)
      2'b00: begin
        unique case (way)
          3'd0, 3'd1, 3'd4, 3'd5: l2tlb_size_pred = PGS_4K;
          3'd2, 3'd6:             l2tlb_size_pred = PGS_2M;
          default:                 l2tlb_size_pred = PGS_1G;
        endcase
      end
      2'b01: begin
        unique case (way)
          3'd2, 3'd3, 3'd6, 3'd7: l2tlb_size_pred = PGS_4K;
          3'd0, 3'd4:             l2tlb_size_pred = PGS_2M;
          default:                 l2tlb_size_pred = PGS_1G;
        endcase
      end
      2'b10: begin
        unique case (way)
          3'd0, 3'd1, 3'd4, 3'd5: l2tlb_size_pred = PGS_4K;
          3'd3, 3'd7:             l2tlb_size_pred = PGS_2M;
          default:                 l2tlb_size_pred = PGS_1G;
        endcase
      end
      2'b11: begin
        unique case (way)
          3'd2, 3'd3, 3'd6, 3'd7: l2tlb_size_pred = PGS_4K;
          3'd1, 3'd5:             l2tlb_size_pred = PGS_2M;
          default:                 l2tlb_size_pred = PGS_1G;
        endcase
      end
      default: l2tlb_size_pred = PGS_4K;
    endcase
  endfunction

  function automatic logic [7:0] l2tlb_raw_index(
    input vpn_t       vpn,
    input logic [2:0] way
  );
    unique case (l2tlb_size_pred(vpn[19:18], way))
      PGS_1G:  l2tlb_raw_index = vpn[25:18];
      PGS_2M:  l2tlb_raw_index = vpn[16:9];
      default: l2tlb_raw_index = vpn[7:0];
    endcase
  endfunction

  function automatic logic [7:0] l2tlb_skew_index(
    input vpn_t       vpn,
    input logic [2:0] way
  );
    logic [7:0] raw_idx;

    raw_idx = l2tlb_raw_index(vpn, way);
    unique case (way)
      3'd0:    l2tlb_skew_index = raw_idx;
      3'd1:    l2tlb_skew_index = raw_idx ^ vpn[15:8];
      3'd2:    l2tlb_skew_index = raw_idx ^ vpn[23:16];
      3'd3:    l2tlb_skew_index = raw_idx ^ {vpn[3:0], vpn[11:8]};
      3'd4:    l2tlb_skew_index = raw_idx ^ {raw_idx[6:0], raw_idx[7]};
      3'd5:    l2tlb_skew_index = raw_idx ^ {raw_idx[1:0], raw_idx[7:2]};
      3'd6:    l2tlb_skew_index = raw_idx ^ l2tlb_reverse8(raw_idx);
      default: l2tlb_skew_index = raw_idx ^ vpn[26:19];
    endcase
  endfunction

  function automatic l2tlb_idx_bus_t l2tlb_skew_index_bus(input vpn_t vpn);
    l2tlb_skew_index_bus = '0;
    for (int way = 0; way < L2_TLB_WAYS; way++) begin
      logic [2:0] way3;
      way3 = way[2:0];
      l2tlb_skew_index_bus[way*8 +: 8] = l2tlb_skew_index(vpn, way3);
    end
  endfunction

  function automatic l2tlb_size_bus_t l2tlb_size_bus(input vpn_t vpn);
    l2tlb_size_bus = '0;
    for (int way = 0; way < L2_TLB_WAYS; way++) begin
      logic [2:0] way3;
      way3 = way[2:0];
      l2tlb_size_bus[way*3 +: 3] = l2tlb_size_pred(vpn[19:18], way3);
    end
  endfunction

  function automatic logic [7:0] l2tlb_page_bank_mask(
    input logic [1:0] selector,
    input logic [2:0] page_size
  );
    l2tlb_page_bank_mask = 8'h00;
    if ((page_size == PGS_4K) || (page_size == PGS_2M) || (page_size == PGS_1G)) begin
      for (int way = 0; way < L2_TLB_WAYS; way++) begin
        logic [2:0] way3;
        way3 = way[2:0];
        if (l2tlb_size_pred(selector, way3) == page_size)
          l2tlb_page_bank_mask[way] = 1'b1;
      end
    end
  endfunction

  // =========================================================================
  // PTE Construction Utility
  // Builds a leaf PTE from PPN + permission bits.
  // Body: TODO (Phase 4 — implement per RISC-V Privileged Spec §4.4)
  // =========================================================================
  function automatic pte_t make_pte(
    ppn_t ppn,
    bit   v = 1,
    bit   r = 1,
    bit   w = 1,
    bit   x = 1,
    bit   u = 0,
    bit   g = 0,
    bit   a = 1,
    bit   d = 1
  );
    // Phase 4: assemble 64-bit RISC-V SV39 PTE
    // Bit layout: [63:54] reserved=0, [53:10] PPN (44-bit field, only lower
    //             PPN_WIDTH=28 used for PA_WIDTH=40), [9:8] RSW=0,
    //             [7] D, [6] A, [5] G, [4] U, [3] X, [2] W, [1] R, [0] V
    make_pte = '0;
    make_pte[PTE_V]                            = v;
    make_pte[PTE_R]                            = r;
    make_pte[PTE_W]                            = w;
    make_pte[PTE_X]                            = x;
    make_pte[PTE_U]                            = u;
    make_pte[PTE_G]                            = g;
    make_pte[PTE_A]                            = a;
    make_pte[PTE_D]                            = d;
    make_pte[PTE_PPN_LSB +: PPN_WIDTH]         = ppn;  // bits [37:10]
  endfunction

  // =========================================================================
  // VA VPN Segment Extraction
  // Returns the 9-bit VPN index for the given page-table level.
  //   level 2: VA[38:30]  (root / L0 page-table)
  //   level 1: VA[29:21]
  //   level 0: VA[20:12]  (leaf)
  // Body: TODO (Phase 4)
  // =========================================================================
  function automatic logic [PT_LEVEL_BITS-1:0] va_vpn_level(
    va_t va,
    int  level
  );
    // Phase 4: extract 9-bit VPN index for the given page-table level
    //   level 2 (root): VA[38:30]
    //   level 1:        VA[29:21]
    //   level 0 (leaf): VA[20:12]
    unique case (level)
      2: va_vpn_level = va[38:30];
      1: va_vpn_level = va[29:21];
      0: va_vpn_level = va[20:12];
      default: va_vpn_level = '0;
    endcase
  endfunction

  // =========================================================================
  // SATP Construction
  // Encodes SATP register: {MODE[3:0], ASID[15:0], PPN[43:0]}
  //   For Sv39: MODE = 8 (4'b1000)
  // Body: TODO (Phase 4)
  // =========================================================================
  function automatic logic [63:0] make_satp(
    logic [3:0] mode,
    asid_t      asid,
    ppn_t       ppn
  );
    // Phase 4: assemble 64-bit SATP register
    // SATP64 format: [63:60] MODE(4b), [59:44] ASID(16b), [43:0] PPN(44b)
    // For SV39: MODE=8(4'b1000), PPN_WIDTH=28, upper 16 bits of 44-bit PPN field are 0
    make_satp = {mode, asid, 16'b0, ppn};  // {4, 16, 16, 28} = 64 bits
  endfunction

endpackage : mmu_common_pkg
