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

  function new(string name = "sysmap_hit_cross_tlb_seq");
    super.new(name);
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

  function new(string name = "sysmap_perm_flag_seq");
    super.new(name);
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

`endif // SYSMAP_CFG_SEQUENCES_SVH
