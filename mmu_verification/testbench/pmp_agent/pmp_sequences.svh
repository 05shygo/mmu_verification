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

// ── Deny fetch on IFU port (port 0) ──────────────────────────────────────────
class pmp_flg_deny_fetch_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_deny_fetch_seq)

  rand bit [2:0] deny_ports;  // bitmask: which ports get fetch-deny flag
  constraint c_nonzero_ports { deny_ports != 3'b000; }

  function new(string name = "pmp_flg_deny_fetch_seq");
    super.new(name);
    deny_ports = 3'b001;
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    // flg[2:0] are R/W/X allow bits in the current RTL.
    // 4'h7 = allow all, 4'h3 = deny fetch only.
    tr.flg[0] = deny_ports[0] ? 4'h3 : 4'h7;
    tr.flg[1] = deny_ports[1] ? 4'h3 : 4'h7;
    tr.flg[2] = deny_ports[2] ? 4'h3 : 4'h7;
    tr.flg[3] = 4'h7; tr.flg[4] = 4'h7;
    tr.flg[5] = 4'h7; tr.flg[6] = 4'h7; tr.flg[7] = 4'h7;
    `uvm_send(tr)
  endtask

endclass : pmp_flg_deny_fetch_seq

// ── Deny read/write on data ports (ports 1–2) ────────────────────────────────
class pmp_flg_deny_rw_seq extends pmp_base_seq;
  `uvm_object_utils(pmp_flg_deny_rw_seq)

  rand bit deny_rd;
  rand bit deny_wr;
  constraint c_some_deny { deny_rd || deny_wr; }

  function new(string name = "pmp_flg_deny_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    pmp_txn tr;
    bit [3:0] data_flg;
    // Keep execute allow high; drop only the requested R/W allow bits.
    data_flg = {1'b0, 1'b1, !deny_wr, !deny_rd};
    `uvm_create(tr)
    tr.flg[0] = 4'h7;          // IFU port untouched
    tr.flg[1] = data_flg;      // LSU Pipe0
    tr.flg[2] = data_flg;      // LSU Pipe1
    tr.flg[3] = 4'h7; tr.flg[4] = 4'h7;
    tr.flg[5] = 4'h7; tr.flg[6] = 4'h7; tr.flg[7] = 4'h7;
    `uvm_send(tr)
  endtask

endclass : pmp_flg_deny_rw_seq

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

  rand bit [3:0] deny_twu_mask;  // twu_one/two/three/four -> ports 3/5/6/7
  constraint c_deny_nonzero { deny_twu_mask != 4'b0000; }

  function new(string name = "pmp_flg_deny_ptw_rd_seq");
    super.new(name);
    deny_twu_mask = 4'b1111;
  endfunction

  virtual task body();
    pmp_txn tr;
    `uvm_create(tr)
    foreach (tr.flg[i]) tr.flg[i] = 4'h7;
    tr.flg[3] = deny_twu_mask[0] ? 4'h6 : 4'h7;
    tr.flg[5] = deny_twu_mask[1] ? 4'h6 : 4'h7;
    tr.flg[6] = deny_twu_mask[2] ? 4'h6 : 4'h7;
    tr.flg[7] = deny_twu_mask[3] ? 4'h6 : 4'h7;
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
      `uvm_send(tr)
    end
  endtask

endclass : pmp_flg_cross_8port_seq

`endif // PMP_SEQUENCES_SVH
