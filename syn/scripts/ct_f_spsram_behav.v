//=============================================================================
// Synthesis-friendly behavioral SRAM replacement for ASAP7 flow
// Replaces: ct_f_spsram_256x196 and ct_f_spsram_256x84
//
// These modules are instantiated by ct_spsram_256x196.v and ct_spsram_256x84.v
// but their source is not available (vendor-specific FPGA/TSMC wrappers).
//
// For initial synthesis, these will be synthesized to flip-flop arrays by Yosys.
// For production, replace with proper ASAP7 SRAM macros (e.g., srambank_256x4x72).
//=============================================================================

// 256 words x 196 bits (e.g., L2 TLB data array)
module ct_f_spsram_256x196 (
    input  logic [7:0]    A,
    input  logic          CEN,
    input  logic          CLK,
    input  logic [195:0]  D,
    input  logic          GWEN,
    input  logic [195:0]  WEN,
    output logic [195:0]  Q
);
    localparam DEPTH = 256;
    localparam WIDTH = 196;

    (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge CLK) begin
        if (!CEN) begin
            if (!GWEN) begin
                for (int i = 0; i < WIDTH; i++) begin
                    if (!WEN[i])
                        mem[A][i] <= D[i];
                end
                Q <= D;
            end else begin
                Q <= mem[A];
            end
        end
    end
endmodule

// 256 words x 84 bits (e.g., L2 TLB tag array)
module ct_f_spsram_256x84 (
    input  logic [7:0]   A,
    input  logic         CEN,
    input  logic         CLK,
    input  logic [83:0]  D,
    input  logic         GWEN,
    input  logic [83:0]  WEN,
    output logic [83:0]  Q
);
    localparam DEPTH = 256;
    localparam WIDTH = 84;

    (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge CLK) begin
        if (!CEN) begin
            if (!GWEN) begin
                for (int i = 0; i < WIDTH; i++) begin
                    if (!WEN[i])
                        mem[A][i] <= D[i];
                end
                Q <= D;
            end else begin
                Q <= mem[A];
            end
        end
    end
endmodule
