// =============================================================================
// mmu_rtl_defines.v
// RTL compile-time macro definitions for ct_mmu_sysmap.v
//
// SYSMAP memory map (40-bit PA, ADDR = PA[39:12] = 28-bit PPN):
//   Region 0: 0x0_0000_0000 – 0x0_3FFF_FFFF  256 MB  Normal SRAM/ROM
//   Region 1: 0x0_4000_0000 – 0x0_7FFF_FFFF  256 MB  Peripheral / MMIO
//   Region 2: 0x0_8000_0000 – 0x0_FFFF_FFFF  512 MB  Reserved
//   Region 3: 0x1_0000_0000 – 0x1_FFFF_FFFF  1 GB    DDR low
//   Region 4: 0x2_0000_0000 – 0x3_FFFF_FFFF  2 GB    DDR main
//   Region 5: 0x4_0000_0000 – 0x7_FFFF_FFFF  4 GB    DDR high
//   Region 6: 0x8_0000_0000 – 0xF_FFFF_FFFF  8 GB    Extended
//   Region 7: above                           rest    Top / OOB
//
// FLAG encoding (FLG_WIDTH=5): bit[4:0] = {SO, DEV, NC, BUF, CA}
//   5'b01111 = normal cacheable (CA=1, BUF=1, NC=0, DEV=0, SO=0)
//   5'b10011 = device / strongly-ordered (CA=1, BUF=1, NC=0, DEV=0, SO=1)
//   Adjust to match your SoC's actual flag encoding.
// =============================================================================

// ---- SysMap region flag values (5-bit) ----
`define SYSMAP_FLG0   5'b01111
`define SYSMAP_FLG1   5'b10011
`define SYSMAP_FLG2   5'b10001
`define SYSMAP_FLG3   5'b01111
`define SYSMAP_FLG4   5'b01111
`define SYSMAP_FLG5   5'b01111
`define SYSMAP_FLG6   5'b01111
`define SYSMAP_FLG7   5'b10011

// ---- SysMap region base addresses (ADDR_WIDTH=28, PA[39:12]) ----
// sysmap_comp_hitN = (pa < BASE_ADDR_N) — monotonically increasing required
`define SYSMAP_BASE_ADDR0   28'h0040000
`define SYSMAP_BASE_ADDR1   28'h0080000
`define SYSMAP_BASE_ADDR2   28'h0100000
`define SYSMAP_BASE_ADDR3   28'h0200000
`define SYSMAP_BASE_ADDR4   28'h0400000
`define SYSMAP_BASE_ADDR5   28'h0800000
`define SYSMAP_BASE_ADDR6   28'h1000000
`define SYSMAP_BASE_ADDR7   28'hF000000
