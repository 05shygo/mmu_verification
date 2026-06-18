module one_to_four_xbar #(
    parameter VADDR_WIDTH = 39,                         // VADDR
    parameter PADDR_WIDTH = 40,                         // PADDR
    parameter VPN_WIDTH   = VADDR_WIDTH-12,             // VPN
    parameter PPN_WIDTH   = PADDR_WIDTH-12,             // PPN
    parameter FLG_WIDTH   = 14,                         // PPN
    parameter ASID_WIDTH  = 16,                         // PPN
    parameter PGS_WIDTH   = 3,                          // Page Size
    parameter PTE_LEVEL   = 3,                          // Page Table Label
    parameter ID_WIDTH    = 7,
    parameter TYPE_WIDTH  = 3,

// VPN width per level
    parameter VPN_PERLEL  = VPN_WIDTH/PTE_LEVEL,

// Valid + VPN + ASID + PageSize + Global
    parameter TAG_WIDTH   = 1+VPN_WIDTH+ASID_WIDTH+PGS_WIDTH+1,
    parameter DATA_WIDTH  = PPN_WIDTH+FLG_WIDTH
) (
//!******************************************
//! Clock and Reset
//!******************************************
    input  logic                  forever_cpuclk,
    input  logic                  cpurst_b,
			
//!******************************************
//! TWU Request
//!******************************************
    input  logic                  twu_mask,
			
//!******************************************
//! PDE Cache Request
//!******************************************
    input  logic                  PDE_xbar_req,
    input  logic                  L2PDE_xbar_hit_vld,
    input  logic                  L1PDE_xbar_hit_vld,
    input  logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
    input  logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
    input  logic [TYPE_WIDTH-1:0] PDE_xbar_type,
    input  logic [ID_WIDTH-1:0]   PDE_xbar_id,
			
//!******************************************
//! xbar to TWU
//!******************************************
    output logic                  xbar_twu_req,
    output logic [PTE_LEVEL-2:0]  xbar_twu_hit_level,
    output logic [PPN_WIDTH-1:0]  xbar_twu_ppn,
    output logic [VPN_WIDTH-1:0]  xbar_twu_vpn,
    output logic [TYPE_WIDTH-1:0] xbar_twu_type,
    output logic [ID_WIDTH-1:0]   xbar_twu_id,

    input  logic                  tlboper_ptw_abort,
    output logic                  xbar_pde_ready

);

logic       twu_req;
logic       twu_xbar_mask;

assign twu_xbar_mask = PDE_xbar_req & twu_mask;
assign xbar_pde_ready = ~twu_xbar_mask;

assign twu_req = PDE_xbar_req & (!twu_xbar_mask);
assign xbar_twu_req = twu_req;




assign xbar_twu_hit_level[PTE_LEVEL-2:0] = {L1PDE_xbar_hit_vld,L2PDE_xbar_hit_vld};
assign xbar_twu_ppn[PPN_WIDTH-1:0] = PDE_xbar_ppn[PPN_WIDTH-1:0];
assign xbar_twu_vpn[VPN_WIDTH-1:0] = PDE_xbar_vpn[VPN_WIDTH-1:0];
assign xbar_twu_type[TYPE_WIDTH-1:0] = PDE_xbar_type[TYPE_WIDTH-1:0];
assign xbar_twu_id[ID_WIDTH-1:0] = PDE_xbar_id[ID_WIDTH-1:0];

endmodule


