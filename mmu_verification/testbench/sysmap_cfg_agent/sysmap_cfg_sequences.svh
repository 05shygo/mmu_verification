// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_sequences.svh
// Phase 3: SysMap sequence library
// =============================================================================
`ifndef SYSMAP_CFG_SEQUENCES_SVH
`define SYSMAP_CFG_SEQUENCES_SVH

// ── Base sequence ─────────────────────────────────────────────────────────────
class sysmap_cfg_base_seq extends uvm_sequence #(sysmap_cfg_txn);
  `uvm_object_utils(sysmap_cfg_base_seq)

  function new(string name = "sysmap_cfg_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // Derived classes provide body
  endtask

endclass : sysmap_cfg_base_seq

// ── Default region setup: all disabled (bypass mode) ─────────────────────────
// Phase 3 sanity test: simply disable all SysMap regions so translation
// follows the normal TLB/PTW path without any SysMap bypass.
class sysmap_region_setup_seq extends sysmap_cfg_base_seq;
  `uvm_object_utils(sysmap_region_setup_seq)

  // Optional: enable a single region for basic testing
  rand bit enable_r0;
  rand bit [27:0] r0_base;
  rand bit [27:0] r0_mask;
  rand bit [4:0]  r0_flg;

  // Default: no region enabled
  constraint c_default_off { enable_r0 == 1'b0; }

  function new(string name = "sysmap_region_setup_seq");
    super.new(name);
  endfunction

  virtual task body();
    sysmap_cfg_txn tr;
    `uvm_create(tr)
    // Disable all 8 regions (default constraint)
    foreach (tr.enable[i]) tr.enable[i] = 1'b0;
    foreach (tr.flg[i])    tr.flg[i]    = 5'h0;
    foreach (tr.base[i])   tr.base[i]   = 28'h0;
    foreach (tr.mask[i])   tr.mask[i]   = 28'h0;
    // Optionally enable region 0
    if (enable_r0) begin
      tr.enable[0] = 1'b1;
      tr.base  [0] = r0_base;
      tr.mask  [0] = r0_mask;
      tr.flg   [0] = r0_flg;
    end
    `uvm_send(tr)
  endtask

endclass : sysmap_region_setup_seq

// ── Configure one SysMap region to hit and cross against TLB ─────────────────
class sysmap_hit_cross_tlb_seq extends sysmap_cfg_base_seq;
  `uvm_object_utils(sysmap_hit_cross_tlb_seq)

  rand bit [27:0] hit_base;
  rand bit [27:0] hit_mask;
  rand bit [4:0]  hit_flg;
  rand bit [2:0]  region_idx;
  constraint c_valid_region { region_idx <= 3'd7; }
  constraint c_translation_safe_default {
    hit_flg == 5'b01111;
  }

  function new(string name = "sysmap_hit_cross_tlb_seq");
    super.new(name);
    hit_base  = 28'h200_0000;
    hit_mask  = 28'hFFF_FFFF;
    hit_flg   = 5'b01111;
    region_idx = 3'd0;
  endfunction

  virtual task body();
    sysmap_cfg_txn tr;
    `uvm_create(tr)
    foreach (tr.enable[i]) tr.enable[i] = 1'b0;
    tr.enable[region_idx] = 1'b1;
    tr.base  [region_idx] = hit_base;
    tr.mask  [region_idx] = hit_mask;
    tr.flg   [region_idx] = hit_flg;
    `uvm_send(tr)
  endtask

endclass : sysmap_hit_cross_tlb_seq

// ── Boundary conditions (adjacent regions, overlapping masks) ─────────────────
class sysmap_boundary_seq extends sysmap_cfg_base_seq;
  `uvm_object_utils(sysmap_boundary_seq)

  function new(string name = "sysmap_boundary_seq");
    super.new(name);
  endfunction

  virtual task body();
    sysmap_cfg_txn tr;
    // TODO (Phase 9): implement boundary scenarios
    `uvm_create(tr)
    foreach (tr.enable[i]) tr.enable[i] = 1'b0;
    `uvm_send(tr)
  endtask

endclass : sysmap_boundary_seq

// ── Permission flag variations ────────────────────────────────────────────────
class sysmap_perm_flag_seq extends sysmap_cfg_base_seq;
  `uvm_object_utils(sysmap_perm_flag_seq)

  rand bit [4:0] perm_flg;
  constraint c_translation_safe_perm { perm_flg == 5'b01111; }

  function new(string name = "sysmap_perm_flag_seq");
    super.new(name);
    perm_flg = 5'b01111;
  endfunction

  virtual task body();
    sysmap_cfg_txn tr;
    `uvm_create(tr)
    foreach (tr.enable[i]) tr.enable[i] = 1'b0;
    tr.enable[0] = 1'b1;
    tr.base  [0] = 28'h100_0000;
    tr.mask  [0] = 28'hFFF_F000;  // 4 KB region
    tr.flg   [0] = perm_flg;
    `uvm_send(tr)
  endtask

endclass : sysmap_perm_flag_seq

// ── Coverage sweep for the SysMap configuration mirror -----------------------
class sysmap_cfg_coverage_sweep_seq extends sysmap_cfg_base_seq;
  `uvm_object_utils(sysmap_cfg_coverage_sweep_seq)

  function new(string name = "sysmap_cfg_coverage_sweep_seq");
    super.new(name);
  endfunction

  protected task send_cfg(
    input bit [27:0] base_in   [8],
    input bit [27:0] mask_in   [8],
    input bit [4:0]  flg_in    [8],
    input bit        enable_in [8]
  );
    sysmap_cfg_txn tr;
    `uvm_create(tr)
    foreach (tr.base[i]) begin
      tr.base[i]   = base_in[i];
      tr.mask[i]   = mask_in[i];
      tr.flg[i]    = flg_in[i];
      tr.enable[i] = enable_in[i];
    end
    `uvm_send(tr)
    #20ns;
  endtask

  virtual task body();
    bit [27:0] base[8];
    bit [27:0] mask[8];
    bit [4:0]  flg[8];
    bit        enable[8];

    foreach (base[i]) begin
      base[i]   = 28'h100_0000 + (i << 12);
      mask[i]   = 28'hfff_f000;
      flg[i]    = 5'h00;
      enable[i] = 1'b0;
    end

    // Sweep the full 5-bit attr space on region0.  The cg wrapper records the
    // first changed region each cycle, so only region0 changes in this loop.
    enable[0] = 1'b1;
    for (int unsigned attr = 0; attr < 32; attr++) begin
      flg[0] = attr[4:0];
      send_cfg(base, mask, flg, enable);
    end

    // Then toggle each remaining region individually so cp_region sees r[1:7].
    for (int unsigned region = 1; region < 8; region++) begin
      enable[region] = 1'b1;
      flg[region]    = (region[0]) ? 5'b10011 : 5'b01111;
      send_cfg(base, mask, flg, enable);
    end
  endtask

endclass : sysmap_cfg_coverage_sweep_seq

`endif // SYSMAP_CFG_SEQUENCES_SVH

// ── PFU-safe: enable region 0 with flg[4]=0,flg[3]=1 for PFU VA range ─────
class sysmap_pfu_safe_flag_seq extends sysmap_cfg_base_seq;
  `uvm_object_utils(sysmap_pfu_safe_flag_seq)
  function new(string name = "sysmap_pfu_safe_flag_seq"); super.new(name); endfunction
  virtual task body();
    sysmap_cfg_txn tr;
    `uvm_create(tr)
    foreach (tr.enable[i]) tr.enable[i] = 1'b0;
    tr.enable[0] = 1'b1;
    tr.base  [0] = 28'h000_1000;  // VPN 0x1000 = VA 0x10_0000
    tr.mask  [0] = 28'hFFF_F000;  // 4KB match
    tr.flg   [0] = 5'b01100;      // bit4=0, bit3=1 (no PFU flag fault)
    `uvm_send(tr)
  endtask
endclass : sysmap_pfu_safe_flag_seq
