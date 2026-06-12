`ifndef MMU_L1DTLB_COVERAGE_VSEQ_SVH
`define MMU_L1DTLB_COVERAGE_VSEQ_SVH

class mmu_l1dtlb_entry0_wfg_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_entry0_wfg_vseq)
  function new(string n = "mmu_l1dtlb_entry0_wfg_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // Approach: occupy [0][1] with long PTW, dual-alloc [2][3],
    // [3] enters WFG (gnt1, no bypass). Then free [0], allocate [0]
    // while [3] still in WFG → bypass_en=0 → [0] enters WFG.

    // Step 1-2: Occupy entries[0] and [1]
    `uvm_info(get_type_name(), "Step 1-2: occupy [0][1]", UVM_LOW)
    configure_ptw_delay(4096, 4096);
    raw_pipe0(va_page(500), 7'd8, 1'b0); wait_lsu_cycles(2);
    raw_pipe0(va_page(501), 7'd9, 1'b0); wait_lsu_cycles(2);
    #2000ns;

    // Step 3: Dual-allocate [2][3]. gnt0→[2] bypass→WFC. gnt1→[3]→WFG!
    `uvm_info(get_type_name(), "Step 3: dual-alloc [2][3]", UVM_LOW)
    configure_ptw_delay(8192, 8192);
    raw_pipe01(va_page(502), va_page(503), 7'd10, 7'd11, 1'b0, 1'b0);
    #2000ns;

    // Step 4: Wait for [0] PTW to complete → freed
    `uvm_info(get_type_name(), "Step 4: wait [0] refill complete", UVM_LOW)
    #80000ns;

    // Step 5: [0] is IDLE, [3] should be WFG, credit available
    // Allocate [0] → bypass_en=0 → [0] enters WFG!
    `uvm_info(get_type_name(), "Step 5: alloc [0] while bypass disabled", UVM_LOW)
    raw_pipe0(va_page(600), 7'd20, 1'b0);
    #200ns;

    // Step 6: Flush → WFG→IDLE or WFG→ABT
    `uvm_info(get_type_name(), "Step 6: flush", UVM_LOW)
    raw_rtu_flush();
    #5000ns;

    // Attempt 2: different timing, occupy [1..7], free [1], dual-alloc [0][1]
    configure_ptw_delay(1, 4); #50000ns;  // drain
    
    `uvm_info(get_type_name(), "Attempt 2: occupy [2..7], free [1], dual [0][1]", UVM_LOW)
    configure_ptw_delay(2048, 2048);
    for (int i = 2; i < 8; i++) begin
      raw_pipe0(va_page(700 + i), 7'(7'd30 + i[6:0]), 1'b0); wait_lsu_cycles(1);
    end
    #3000ns;
    // [2..7] in WFC. Allocate [0][1] single first:
    raw_pipe0(va_page(700), 7'd32, 1'b0);  // [0] bypass→WFC
    #2000ns;
    // [1] still free, [0] in WFC. Dual-alloc: only [1] free for both gnts?
    // Actually [0] occupied, [1] free, [2..7] occupied → only [1] free
    // So single alloc of [1] → bypass→WFC. That doesn't help.
    // Instead: free [0] first (wait for its PTW)
    #40000ns;
    // Now [0] and [1] both free, [2..7] in WFC
    // Dual-alloc: gnt0→[0](bypass→WFC), gnt1→[1](WFG!)
    raw_pipe01(va_page(702), va_page(703), 7'd42, 7'd43, 1'b0, 1'b0);
    #2000ns;
    // [1] in WFG now. Wait for [0] PTW → free [0]
    #40000ns;
    // [0] free, [1] in WFG → alloc [0] → bypass_en=0 → WFG
    raw_pipe0(va_page(704), 7'd52, 1'b0);
    #100ns;
    raw_rtu_flush();
    #5000ns;

    `uvm_info(get_type_name(), "entry[0] WFG done", UVM_LOW)
  endtask
endclass


class mmu_l1dtlb_coverage_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_coverage_vseq)
  function new(string n = "mmu_l1dtlb_coverage_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int i = 0; i < 72; i++) begin raw_pipe0(va_page(i), 7'(i[6:0]), 1'b0); #50ns; end
    #30000ns;
    for (int i = 0; i < 32; i++) begin raw_pipe01(va_page(i*2), va_page(i*2+1), 7'(i[6:0]), 7'(i[6:0]+32), 1'b0, 1'b0); #100ns; end
    #30000ns;
    for (int cycle = 0; cycle < 4; cycle++) begin
      for (int i = 0; i < 8; i++) begin raw_pipe0(va_page(cycle*8+i+80), 7'd10, 1'b0); #50ns; end
      #5000ns; raw_rtu_flush(); #2000ns;
      for (int i = 0; i < 8; i++) begin raw_pipe0(va_page(cycle*8+i+80), 7'd20, 1'b0); #50ns; end
      #5000ns;
    end
  endtask
endclass

class mmu_l1dtlb_mb_expt_coverage_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_mb_expt_coverage_vseq)
  function new(string n = "mmu_l1dtlb_mb_expt_coverage_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int cycle = 0; cycle < 4; cycle++) begin
      for (int i = 0; i < 8; i++) begin raw_pipe0(va_page(cycle*8+i+256), 7'(i[6:0]), 1'b0); wait_lsu_cycles(1); end
      #40000ns;
    end
    for (int cycle = 0; cycle < 4; cycle++) begin
      for (int i = 0; i < 4; i++) begin raw_pipe0(va_page(cycle*4+i+300), 7'(i[6:0]), 1'b0); wait_lsu_cycles(1); end
      #2000ns; raw_rtu_flush(); #5000ns;
    end
    for (int cycle = 0; cycle < 4; cycle++) begin
      raw_pipe01(va_page(cycle*2+320), va_page(cycle*2+321), 7'd30, 7'd31, 1'b0, 1'b0);
      #3000ns; raw_rtu_flush(); #2000ns;
      raw_pipe0(va_page(cycle*2+320), 7'd40, 1'b0); #5000ns;
    end
  endtask
endclass

class mmu_l1_reset_mid_op_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1_reset_mid_op_vseq)
  function new(string n = "mmu_l1_reset_mid_op_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction
  virtual task body();
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")
    for (int cycle = 0; cycle < 3; cycle++) begin
      configure_ptw_delay(512, 512);
      for (int i = 0; i < 4; i++) begin raw_pipe0(va_page(cycle*4+i+500), 7'(i[6:0]), 1'b0); wait_lsu_cycles(1); end
      #3000ns; raw_rtu_flush(); #1000ns;
      for (int i = 0; i < 4; i++) begin raw_pipe0(va_page(cycle*4+i+500), 7'(7'd50+i[6:0]), 1'b0); #100ns; end
      #10000ns;
    end
  endtask
endclass

`endif
