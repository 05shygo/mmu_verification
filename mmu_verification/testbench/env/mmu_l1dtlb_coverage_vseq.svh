`ifndef MMU_L1DTLB_COVERAGE_VSEQ_SVH
`define MMU_L1DTLB_COVERAGE_VSEQ_SVH

class mmu_l1dtlb_entry0_wfg_vseq extends l1dtlb_directed_vseq;
  `uvm_object_utils(mmu_l1dtlb_entry0_wfg_vseq)
  function new(string n = "mmu_l1dtlb_entry0_wfg_vseq"); super.new(n); m_va_base = 39'h10_0000; endfunction

  virtual task body();
    `uvm_info(get_type_name(), "===== entry0_wfg_vseq body START =====", UVM_NONE)
    m_env_h = get_env(); m_lsu_vif = m_env_h.m_lsu.vif; m_misc_vif = m_env_h.m_misc.vif;
    if (m_lsu_vif == null) `uvm_fatal(get_type_name(), "LSU VIF null")

    // =================================================================
    // 持续制造双端口LSU miss:
    //   - 调度器每个周期只能发射1个请求 (round-robin)
    //   - 双端口每周期分配2个miss → WFG积累速度快于发射速度
    //   - 当entry[0]完成refill被释放后, 其他entry仍在WFG
    //   - entry[0]重新分配 → bypass_en=0 → 进入WFG
    //   - 周期性flush → 覆盖 WFG→IDLE / WFG→ABT
    // =================================================================

    // 初始化页表
    do_bringup(512, 39'h10_0000);

    // --- 阶段1: 中等PTW延迟, 持续双端口miss压力 ---
    `uvm_info(get_type_name(), "阶段1: 持续双端口miss压力", UVM_LOW)
    configure_ptw_delay(64, 128);

    // 持续发射64轮双端口miss, 每轮2个miss
    // 调度器每cycle只能issue 1个, 我们每cycle分配2个
    // → WFG entry持续积累, entry[0]反复被释放再分配
    // → 每次重新分配时大概率有其他WFG存在 → bypass_en=0 → WFG
    for (int round = 0; round < 64; round++) begin
      raw_pipe01(va_page(round*2), va_page(round*2+1),
                 7'(round[6:0]*2), 7'(round[6:0]*2+1),
                 round[0], ~round[0]);
      wait_lsu_cycles(1);

      // 每8轮flush一次, 捕获WFG→IDLE / WFG→ABT
      if (round % 8 == 7) begin
        raw_rtu_flush();
        wait_lsu_cycles(4);
      end
    end
    #30000ns;

    // --- 阶段2: 长PTW延迟, 确保WFG停留时间更长 ---
    `uvm_info(get_type_name(), "阶段2: 长PTW + 持续双端口", UVM_LOW)
    configure_ptw_delay(512, 1024);

    for (int round = 0; round < 32; round++) begin
      raw_pipe01(va_page(128 + round*2), va_page(129 + round*2),
                 7'(round[6:0]*2+1), 7'(round[6:0]*2+2),
                 round[0], ~round[0]);
      wait_lsu_cycles(1);

      if (round % 6 == 5) begin
        raw_rtu_flush();
        wait_lsu_cycles(3);
      end
    end
    #50000ns;

    // --- 阶段3: 短PTW, 高频flush, 捕获更多WFG→IDLE ---
    `uvm_info(get_type_name(), "阶段3: 短PTW + 高频flush", UVM_LOW)
    configure_ptw_delay(16, 32);

    for (int round = 0; round < 48; round++) begin
      raw_pipe01(va_page(256 + round*2), va_page(257 + round*2),
                 7'(round[6:0]+10), 7'(round[6:0]+20),
                 1'b0, round[0]);
      wait_lsu_cycles(1);

      // 更频繁flush
      if (round % 4 == 3) begin
        raw_rtu_flush();
        wait_lsu_cycles(2);
      end
    end
    #20000ns;

    // --- 阶段4: store类型miss, 增加条件覆盖 ---
    `uvm_info(get_type_name(), "阶段4: store miss + flush", UVM_LOW)
    configure_ptw_delay(128, 256);

    for (int round = 0; round < 24; round++) begin
      raw_pipe01(va_page(384 + round*2), va_page(385 + round*2),
                 7'(round[6:0]+30), 7'(round[6:0]+40),
                 1'b1, round[0]);
      wait_lsu_cycles(1);

      if (round % 3 == 2) begin
        raw_rtu_flush();
        wait_lsu_cycles(2);
      end
    end
    #30000ns;

    // --- 最终排空 ---
    configure_ptw_delay(1, 4);
    #100000ns;

    `uvm_info(get_type_name(), "entry[0] WFG覆盖率序列完成", UVM_LOW)
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
