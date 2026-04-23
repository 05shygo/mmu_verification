// =============================================================================
// MMU UVM Verification — Minimal Base Test (Phase 2 smoke check)
// =============================================================================
`ifndef MMU_BASE_TEST_SV
`define MMU_BASE_TEST_SV

class mmu_base_test extends uvm_test;
    `uvm_component_utils(mmu_base_test)

    function new(string name = "mmu_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "MMU base test build_phase: UVM env skeleton ready (Phase 2)", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "MMU base test run_phase: simulation started OK", UVM_LOW)
        #100ns;
        `uvm_info(get_type_name(), "MMU base test run_phase: done", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : mmu_base_test

`endif // MMU_BASE_TEST_SV
