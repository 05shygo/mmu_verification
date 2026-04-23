// =============================================================================
// MMU UVM Verification — modules/mmu_params/mmu_params_pkg.sv
// Phase 2: Sv39 constants, TLB parameters, type aliases
// DUT: ct_mmu_top.v (OpenRISCV2030 MMU, Sv39)
// =============================================================================
package mmu_params_pkg;

  // =========================================================================
  // Sv39 Fixed Parameters
  // =========================================================================
  parameter int unsigned VA_WIDTH       = 39;
  parameter int unsigned PA_WIDTH       = 40;
  parameter int unsigned VPN_WIDTH      = 27;
  parameter int unsigned PPN_WIDTH      = 28;
  parameter int unsigned PAGE_OFFSET    = 12;
  parameter int unsigned ASID_WIDTH     = 16;
  parameter int unsigned PTE_WIDTH      = 64;
  parameter int unsigned PT_LEVELS      = 3;
  parameter int unsigned PT_LEVEL_BITS  = 9;
  parameter int unsigned PTES_PER_PAGE  = 512;

  // =========================================================================
  // PTE Bit Indices (RISC-V Privileged Spec §4.4)
  // =========================================================================
  parameter int unsigned PTE_V     = 0;   // Valid
  parameter int unsigned PTE_R     = 1;   // Readable
  parameter int unsigned PTE_W     = 2;   // Writable
  parameter int unsigned PTE_X     = 3;   // Executable
  parameter int unsigned PTE_U     = 4;   // User-accessible
  parameter int unsigned PTE_G     = 5;   // Global
  parameter int unsigned PTE_A     = 6;   // Accessed
  parameter int unsigned PTE_D     = 7;   // Dirty
  parameter int unsigned PTE_PPN_LSB = 10; // PPN starts at bit 10

  // =========================================================================
  // TLB Organisation
  // =========================================================================
  parameter int unsigned L1_ITLB_ENTRIES   = 16;
  parameter int unsigned L1_DTLB_ENTRIES   = 16;
  parameter int unsigned L1_DTLB_MB_DEPTH  = 8;
  parameter int unsigned L2_TLB_BANKS      = 8;
  parameter int unsigned L2_TLB_WAYS       = 8;
  parameter int unsigned L2_TLB_SETS       = 256;
  parameter int unsigned L2_TLB_MB_ITLB    = 1;
  parameter int unsigned L2_TLB_MB_DTLB    = 8;
  parameter int unsigned L2_REQQ_DEPTH     = 9;   // 1 ITLB + 8 DTLB
  parameter int unsigned L2_RRPV_WIDTH     = 3;
  parameter int unsigned L2_RRPV_INIT      = 4;   // RRPV_MAX - 3 = 7 - 3
  parameter int unsigned L2_RRPV_MAX       = 7;

  // =========================================================================
  // PTW Parameters
  // =========================================================================
  parameter int unsigned PTW_TWU_NUM    = 4;
  parameter int unsigned PTW_MBUF_DEPTH = 4;

  // =========================================================================
  // Privilege Modes (RISC-V: 00=U, 01=S, 10=H(reserved), 11=M)
  // =========================================================================
  parameter bit [1:0] PRIV_U = 2'b00;
  parameter bit [1:0] PRIV_S = 2'b01;
  parameter bit [1:0] PRIV_M = 2'b11;

  // =========================================================================
  // Sysmap / PMP
  // =========================================================================
  parameter int unsigned SYSMAP_REGIONS = 8;
  parameter int unsigned PMP_ENTRIES    = 8;

  // =========================================================================
  // Page Size Encoding (matches RTL ptw_l1tlb_ref_pgs[2:0] semantics)
  //   One-hot: pgs[0]=4K, pgs[1]=2M, pgs[2]=1G
  // =========================================================================
  typedef enum bit [2:0] {
    PGS_4K = 3'b001,
    PGS_2M = 3'b010,
    PGS_1G = 3'b100
  } pgs_e;

  // =========================================================================
  // Access Type
  // =========================================================================
  typedef enum bit [2:0] {
    ACC_FETCH = 3'd0,
    ACC_LOAD  = 3'd1,
    ACC_STORE = 3'd2,
    ACC_PFU   = 3'd3
  } acc_type_e;

  // =========================================================================
  // Basic Type Aliases
  // =========================================================================
  typedef logic [VA_WIDTH-1:0]   va_t;
  typedef logic [PA_WIDTH-1:0]   pa_t;
  typedef logic [VPN_WIDTH-1:0]  vpn_t;
  typedef logic [PPN_WIDTH-1:0]  ppn_t;
  typedef logic [ASID_WIDTH-1:0] asid_t;
  typedef logic [PTE_WIDTH-1:0]  pte_t;

endpackage : mmu_params_pkg
