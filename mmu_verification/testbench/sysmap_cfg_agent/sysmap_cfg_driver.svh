// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_driver.svh
// Phase 3: SysMap configuration driver
//
// ct_mmu_sysmap.v has no top-level DUT ports and is macro-configured in the
// current build.  This driver mirrors sequence data to sysmap_cfg_if only.
// Whitebox force/release is intentionally disabled until DA-003 is resolved.
//
// Force path convention (needs confirmation against actual RTL hierarchy):
//   tb_top.u_dut.<sysmap_instance>.sysmap_base_addr[N]
//   tb_top.u_dut.<sysmap_instance>.sysmap_mask_addr[N]
//   tb_top.u_dut.<sysmap_instance>.sysmap_flg[N]
//   tb_top.u_dut.<sysmap_instance>.sysmap_en[N]
//
// ⚠ DA-003 OPEN: Exact internal signal names and hierarchy path must be
//   confirmed against ct_mmu_sysmap.v before enabling the force statements.
//   Until confirmed, the driver mirrors configuration to sysmap_cfg_if only.
// =============================================================================
`ifndef SYSMAP_CFG_DRIVER_SVH
`define SYSMAP_CFG_DRIVER_SVH

class sysmap_cfg_driver extends uvm_driver #(sysmap_cfg_txn);

  `uvm_component_utils(sysmap_cfg_driver)

  virtual sysmap_cfg_if vif;

  // Whitebox force paths — to be confirmed against ct_mmu_sysmap.v (DA-003)
  // Placeholder strings; actual force uses hierarchical path task below.
  localparam string SYSMAP_HIER = "tb_top.u_dut";  // adjust per elaboration

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual sysmap_cfg_if)::get(this, "", "SYSMAP_CFG_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get SYSMAP_CFG_VIF from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    sysmap_cfg_txn tr;
    // Initialise interface to all-disabled
    _apply_cfg_to_if('{default:'0}, '{default:'0}, '{default:'0}, '{default:1'b0});
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(posedge vif.clk_i);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(), {"Applying SysMap cfg: ", tr.convert2string()}, UVM_MEDIUM)
      _apply_cfg_to_if(tr.base, tr.mask, tr.flg, tr.enable);
      // TODO (DA-003): Uncomment force statements after hierarchy confirmed
      // _force_sysmap_rtl(tr);
      seq_item_port.item_done();
    end
  endtask

  // ── Mirror configuration to interface (monitor observes these) ───────────
  protected task _apply_cfg_to_if(
    bit [27:0] base_in   [8],
    bit [27:0] mask_in   [8],
    bit [4:0]  flg_in    [8],
    bit        enable_in [8]
  );
    foreach (base_in[i]) begin
      vif.cfg_base  [i] = base_in  [i];
      vif.cfg_mask  [i] = mask_in  [i];
      vif.cfg_flg   [i] = flg_in   [i];
      vif.cfg_enable[i] = enable_in[i];
    end
  endtask

  // ── RTL whitebox force (DA-003 placeholder) ───────────────────────────────
  // Uncomment and adjust hierarchy path when DA-003 is resolved.
  // protected task _force_sysmap_rtl(sysmap_cfg_txn tr);
  //   foreach (tr.base[i]) begin
  //     // force {SYSMAP_HIER}.u_ct_mmu_sysmap.sysmap_base_addr[i] = tr.base[i];
  //     // force {SYSMAP_HIER}.u_ct_mmu_sysmap.sysmap_mask_addr[i] = tr.mask[i];
  //     // force {SYSMAP_HIER}.u_ct_mmu_sysmap.sysmap_flg[i]       = tr.flg[i];
  //     // force {SYSMAP_HIER}.u_ct_mmu_sysmap.sysmap_en[i]        = tr.enable[i];
  //   end
  // endtask

endclass : sysmap_cfg_driver

`endif // SYSMAP_CFG_DRIVER_SVH
