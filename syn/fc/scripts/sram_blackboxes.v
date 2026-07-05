//=============================================================================
// ASAP7 / FC synthesis: SRAM hard-macro blackbox stubs
//
// These replace the vendor behavioral SRAM models so FC treats them as
// hard IP (memories from a memory compiler). Faster synthesis + matches
// the real ASIC flow where SRAMs are delivered as GDS/LIB macros.
//
// intentional blackbox (otherwise LNK-094: empty RTL module error).
//=============================================================================

//--- 256 x 196 single-port SRAM --------------------------------------------
module ct_f_spsram_256x196 (
    input  logic [7:0]    A,
    input  logic          CEN,
    input  logic          CLK,
    input  logic [195:0]  D,
    input  logic          GWEN,
    input  logic [195:0]  WEN,
    output logic [195:0]  Q
);
endmodule

//--- 256 x 84 single-port SRAM ---------------------------------------------
module ct_f_spsram_256x84 (
    input  logic [7:0]   A,
    input  logic         CEN,
    input  logic         CLK,
    input  logic [83:0]  D,
    input  logic         GWEN,
    input  logic [83:0]  WEN,
    output logic [83:0]  Q
);
endmodule

//--- Parameterized FPGA-style RAM used by ct_spram_wrapper ------------------
module mmu_fpga_ram #(
    parameter DATAWIDTH = 2,
    parameter ADDRWIDTH = 2
)(
    input                     PortAClk,
    input   [(ADDRWIDTH-1):0] PortAAddr,
    input   [(DATAWIDTH-1):0] PortADataIn,
    input                     PortAWriteEnable,
    output  [(DATAWIDTH-1):0] PortADataOut
);
endmodule
