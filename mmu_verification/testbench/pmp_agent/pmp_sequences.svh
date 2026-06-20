// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_sequences.svh
// Phase 3: PMP sequence library
// =============================================================================
`ifndef PMP_SEQUENCES_SVH
`define PMP_SEQUENCES_SVH

// ── Base sequence ─────────────────────────────────────────────────────────────
class pmp_base_seq extends uvm_sequence #(pmp_txn);
  `uvm_object_utils(pmp_base_seq)

  function new(string name = "pmp_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // Derived classes provide body
  endtask

endclass : pmp_base_seq

// ── All-allow: R+W+X per TWU/TLB (pmp_mmu_flg[0]=R, [1]=W, [2]=X). Not 0x0.
//    In S-mode, flg=0 denies loads used by the page-table walker → spurious acc_err.
class pmp_flg_normal_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_normal_seq)

  function new(string name = "pmp_flg_normal_seq");
    super.new(name);
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    tr.flg[0] = 4'h7; tr.flg[1] = 4'h7; tr.flg[2] = 4'h7; tr.flg[3] = 4'h7;
    tr.flg[4] = 4'h7; tr.flg[5] = 4'h7; tr.flg[6] = 4'h7; tr.flg[7] = 4'h7;
    `uvm_send(tr)
  endtask

endclass : pmp_flg_normal_seq

// ── Deny fetch on IFU port (port 2) ──────────────────────────────────────────
class pmp_flg_deny_fetch_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_deny_fetch_seq)

  rand bit [2:0] deny_ports;  // ports 0/1/2; IFU is port 2
  constraint c_ifu_port_only { deny_ports == 3'b100; }

  function new(string name = "pmp_flg_deny_fetch_seq");
    super.new(name);
    deny_ports = 3'b100;
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    // flg[3:0] is {L,X,W,R}. 4'h7 = allow all, 4'h3 = deny X only.
    // Ports 0/1 are LSU pipe0/1; port 2 is IFU.
    tr.flg[0] = deny_ports[0] ? 4'h3 : 4'h7;
    tr.flg[1] = deny_ports[1] ? 4'h3 : 4'h7;
    tr.flg[2] = deny_ports[2] ? 4'h3 : 4'h7;
    tr.flg[3] = 4'h7; tr.flg[4] = 4'h7;
    tr.flg[5] = 4'h7; tr.flg[6] = 4'h7; tr.flg[7] = 4'h7;
    `uvm_send(tr)
  endtask

endclass : pmp_flg_deny_fetch_seq

// ── Deny read/write on LSU data ports (ports 0/1) ───────────────────────────
class pmp_flg_deny_rw_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_deny_rw_seq)

  rand bit deny_rd;
  rand bit deny_wr;
  constraint c_deny_rw { deny_rd && deny_wr; }

  function new(string name = "pmp_flg_deny_rw_seq");
    super.new(name);
    deny_rd = 1'b1;
    deny_wr = 1'b1;
  endfunction

  virtual task body();
    pmp_txn tr;
    bit [3:0] data_flg;
    // Keep execute allow high; drop only the requested R/W allow bits.
    data_flg = {1'b0, 1'b1, !deny_wr, !deny_rd};
    `uvm_create(tr)
    tr.flg[0] = data_flg;      // LSU Pipe0
    tr.flg[1] = data_flg;      // LSU Pipe1
    tr.flg[2] = 4'h7;          // IFU port untouched
    tr.flg[3] = 4'h7;          // PTW0 allow
    tr.flg[4] = 4'h7;          // PFU is not a generic LSU data-deny target
    tr.flg[5] = 4'h7; tr.flg[6] = 4'h7; tr.flg[7] = 4'h7;
    `uvm_send(tr)
  endtask

endclass : pmp_flg_deny_rw_seq

// ── Explicit PFU/LSU pipe2 read deny (port 4) ───────────────────────────────
class pmp_flg_deny_pfu_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_deny_pfu_seq)

  function new(string name = "pmp_flg_deny_pfu_seq");
    super.new(name);
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    foreach (tr.flg[i]) tr.flg[i] = 4'h7;
    tr.flg[4] = 4'h6;  // deny R on LSU Pipe2/PFU only
    `uvm_send(tr)
  endtask
endclass : pmp_flg_deny_pfu_seq

class pmp_flg_raw_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_raw_seq)

  bit [3:0] raw_flg[8];

  function new(string name = "pmp_flg_raw_seq");
    super.new(name);
    foreach (raw_flg[i]) raw_flg[i] = 4'h7;
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    foreach (raw_flg[i]) tr.flg[i] = raw_flg[i];
    `uvm_send(tr)
  endtask
endclass : pmp_flg_raw_seq

class pmp_flg_deny_ptw_rd_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_deny_ptw_rd_seq)

  rand bit        deny_twu;  // single TWU port 3 (4TWU→1TWU: was deny_twu_mask[3:0])
  constraint c_deny_active { deny_twu == 1'b1; }  // must set to have effect

  function new(string name = "pmp_flg_deny_ptw_rd_seq");
    super.new(name);
    deny_twu = 1'b1;
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    foreach (tr.flg[i]) tr.flg[i] = 4'h7;
    tr.flg[3] = deny_twu ? 4'h6 : 4'h7;
    // Ports 5/6/7 removed (4TWU→1TWU): only port 3 (single TWU) remains
    `uvm_send(tr)
  endtask
endclass : pmp_flg_deny_ptw_rd_seq

// ── Cross all 8 ports with random flag patterns ───────────────────────────────
class pmp_flg_cross_8port_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_cross_8port_seq)

  rand int unsigned n_iters;
  constraint c_iters { n_iters inside {[4:16]}; }

  function new(string name = "pmp_flg_cross_8port_seq");
    super.new(name);
    n_iters = 8;
  endfunction

  virtual task body();
    pmp_txn tr;
    for (int i = 0; i < int'(n_iters); i++) begin
      `uvm_create(tr)
      tr.c_all_allow.constraint_mode(0);
      // Use meaningful allow-bit combinations instead of one-hot literals:
      // 7=allow, 6=deny read, 5=deny write, 3=deny fetch, 0=deny all.
      if (!tr.randomize() with {
          foreach (tr.flg[k]) tr.flg[k] inside {4'h7, 4'h6, 4'h5, 4'h3, 4'h0};
        })
        `uvm_warning(get_type_name(), "Randomisation failed — using defaults")
      tr.flg[4] = 4'h7;  // keep PFU comparable unless a PFU-specific deny seq is used
      `uvm_send(tr)
    end
  endtask

endclass : pmp_flg_cross_8port_seq

// ── Deterministic flag sweep for agent coverage closure ----------------------
class pmp_flg_coverage_sweep_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_coverage_sweep_seq)

  function new(string name = "pmp_flg_coverage_sweep_seq");
    super.new(name);
  endfunction

  protected task send_flags(input bit [3:0] flg_in[8]);
    pmp_txn tr;
    `uvm_create(tr)
    foreach (tr.flg[i]) tr.flg[i] = flg_in[i];
    `uvm_send(tr)
  endtask

  virtual task body();
    bit [3:0] flg[8];

    foreach (flg[i]) flg[i] = 4'h7;

    // Cover acc0[3:1] values 0..7 while keeping port0 read-allow set.
    for (int unsigned acc = 0; acc < 8; acc++) begin
      foreach (flg[i]) flg[i] = 4'h7;
      flg[0] = {acc[2:0], 1'b1};
      send_flags(flg);
    end

    // Cover first R-allow port p[0:7].  Lower ports are read-denied so the
    // covergroup's first_r_allow_port() selects the intended port.
    for (int unsigned port = 0; port < 8; port++) begin
      foreach (flg[i]) flg[i] = 4'h0;
      flg[port] = 4'h1;
      send_flags(flg);
    end

    foreach (flg[i]) flg[i] = 4'h7;
    send_flags(flg);
  endtask

endclass : pmp_flg_coverage_sweep_seq

`endif // PMP_SEQUENCES_SVH
