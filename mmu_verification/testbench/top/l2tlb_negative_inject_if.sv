// =============================================================================
// L2TLB negative protocol injector request interface.
//
// This is a testbench-only control plane.  The actual force/release of DUT nets
// is centralized in tb_top so UVM tests do not carry fragile hierarchy paths.
// =============================================================================
`ifndef L2TLB_NEGATIVE_INJECT_IF_SV
`define L2TLB_NEGATIVE_INJECT_IF_SV

package l2tlb_negative_pkg;
  typedef enum int {
    L2TLB_NEG_NONE                = 0,
    L2TLB_NEG_PTW_NO_OUTSTANDING = 1,
    L2TLB_NEG_PTW_BAD_ID_TYPE    = 2,
    L2TLB_NEG_PTW_ILLEGAL_COMBO  = 3,
    L2TLB_NEG_CONTROL_HAZARD     = 4
  } l2tlb_neg_kind_e;

  bit l2tlb_neg_sva_disable = 1'b0;
endpackage : l2tlb_negative_pkg

interface l2tlb_negative_inject_if (
  input bit clk_i,
  input bit rst_ni
);
  import l2tlb_negative_pkg::*;

  localparam int PTW_ID_WIDTH = 7;

  bit                    enabled;
  bit                    busy;
  int unsigned           request_seq;
  int unsigned           done_seq;
  l2tlb_neg_kind_e       kind;
  string                 case_name;
  string                 related_ids;
  string                 expected_class;
  logic [PTW_ID_WIDTH-1:0] ptw_id;
  logic [2:0]            ptw_type;
  logic                  data_vld;
  logic                  pgflt;
  logic                  acc_err;
  logic [13:0]           flg;
  int unsigned           hold_cycles;
  bit                    trigger_seen;
  bit                    checker_seen;
  string                 observed_msg;

  event request_ev;
  event done_ev;

  task automatic inject_ptw_completion(
    input l2tlb_neg_kind_e req_kind,
    input string req_case_name,
    input string req_related_ids,
    input string req_expected_class,
    input logic [PTW_ID_WIDTH-1:0] req_id,
    input logic [2:0] req_type,
    input logic req_data_vld,
    input logic req_pgflt,
    input logic req_acc_err,
    input logic [13:0] req_flg,
    input int unsigned req_hold_cycles = 1
  );
    wait (rst_ni === 1'b1);
    wait (!busy);
    enabled = 1'b1;
    busy = 1'b1;
    kind = req_kind;
    case_name = req_case_name;
    related_ids = req_related_ids;
    expected_class = req_expected_class;
    ptw_id = req_id;
    ptw_type = req_type;
    data_vld = req_data_vld;
    pgflt = req_pgflt;
    acc_err = req_acc_err;
    flg = req_flg;
    hold_cycles = (req_hold_cycles == 0) ? 1 : req_hold_cycles;
    trigger_seen = 1'b0;
    checker_seen = 1'b0;
    observed_msg = "";
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;
    request_seq++;
    -> request_ev;
    wait (done_seq == request_seq);
    -> done_ev;
    busy = 1'b0;
  endtask

  task automatic inject_control_hazard(
    input string req_case_name,
    input string req_related_ids,
    input string req_expected_class,
    input int unsigned req_hold_cycles = 1
  );
    wait (rst_ni === 1'b1);
    wait (!busy);
    enabled = 1'b1;
    busy = 1'b1;
    kind = L2TLB_NEG_CONTROL_HAZARD;
    case_name = req_case_name;
    related_ids = req_related_ids;
    expected_class = req_expected_class;
    ptw_id = '0;
    ptw_type = 3'b010;
    data_vld = 1'b0;
    pgflt = 1'b0;
    acc_err = 1'b0;
    flg = '0;
    hold_cycles = (req_hold_cycles == 0) ? 1 : req_hold_cycles;
    trigger_seen = 1'b0;
    checker_seen = 1'b0;
    observed_msg = "";
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;
    request_seq++;
    -> request_ev;
    wait (done_seq == request_seq);
    -> done_ev;
    busy = 1'b0;
  endtask

  function void complete(
    input bit trig,
    input bit chk,
    input string msg
  );
    trigger_seen = trig;
    checker_seen = chk;
    observed_msg = msg;
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    done_seq = request_seq;
  endfunction

endinterface : l2tlb_negative_inject_if

`endif // L2TLB_NEGATIVE_INJECT_IF_SV
