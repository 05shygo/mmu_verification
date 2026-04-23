// =============================================================================
// MMU UVM Verification — testbench/common/mmu_common_pkg.sv
// Phase 2: PTE utilities, VA segment helpers, exception type enum
// All function bodies are TODO — to be filled in Phase 4
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
    // TODO (Phase 4)
    make_pte = '0;
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
    // TODO (Phase 4)
    va_vpn_level = '0;
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
    // TODO (Phase 4)
    make_satp = '0;
  endfunction

endpackage : mmu_common_pkg
