module mmu_l1dtlb_expt_cam #(
  parameter int CAM_DEPTH = 8,
  parameter int IID_WIDTH = 7,
  parameter int VPN_WIDTH = 27
) (
  input  logic                 clk,
  input  logic                 rst_b,
  input  logic                 rtu_yy_xx_flush,
  input  logic                 tlboper_utlb_clr,
  input  logic                 tlboper_utlb_inv_va_req,

  input  logic                 expt_wr0_vld,
  input  logic [$clog2(CAM_DEPTH)-1:0] expt_wr0_eid,
  input  logic [IID_WIDTH-1:0] expt_wr0_iid,
  input  logic [VPN_WIDTH-1:0] expt_wr0_vpn,
  input  logic                 expt_wr0_pgflt,
  input  logic                 expt_wr0_acflt,

  input  logic                 expt_wr1_vld,
  input  logic [$clog2(CAM_DEPTH)-1:0] expt_wr1_eid,
  input  logic [IID_WIDTH-1:0] expt_wr1_iid,
  input  logic [VPN_WIDTH-1:0] expt_wr1_vpn,
  input  logic                 expt_wr1_pgflt,
  input  logic                 expt_wr1_acflt,

  input  logic                 lsu_mmu_va0_vld,
  input  logic                 lsu_mmu_abort0,
  input  logic [IID_WIDTH-1:0] lsu_mmu_id0,
  input  logic [VPN_WIDTH-1:0] lsu_mmu_vpn0,
  input  logic                 lsu_mmu_va1_vld,
  input  logic                 lsu_mmu_abort1,
  input  logic [IID_WIDTH-1:0] lsu_mmu_id1,
  input  logic [VPN_WIDTH-1:0] lsu_mmu_vpn1,

  output logic                 expt_match0,
  output logic                 expt_pgflt0,
  output logic                 expt_acflt0,
  output logic                 expt_match1,
  output logic                 expt_pgflt1,
  output logic                 expt_acflt1,
  output logic [CAM_DEPTH-1:0] expt_hit_vec,
  output logic [11:0]          expt_wakeup
);

  typedef struct packed {
    logic                 vld;
    logic [$clog2(CAM_DEPTH)-1:0] eid;
    logic [IID_WIDTH-1:0] iid;
    logic [VPN_WIDTH-1:0] vpn;
    logic                 pgflt;
    logic                 acflt;
  } expt_ent_t;

  expt_ent_t ent[CAM_DEPTH];

  function automatic logic [$clog2(CAM_DEPTH)-1:0] first_one_idx(
    input logic [CAM_DEPTH-1:0] vec
  );
    int i;
    begin
      first_one_idx = '0;
      for (i = 0; i < CAM_DEPTH; i++) begin
        if (vec[i]) begin
          first_one_idx = i[$clog2(CAM_DEPTH)-1:0];
          break;
        end
      end
    end
  endfunction

  logic [CAM_DEPTH-1:0] free_vec;
  logic [CAM_DEPTH-1:0] hit0_vec, hit1_vec;
  logic [CAM_DEPTH-1:0] hit0_use_vec, hit1_use_vec;
  logic [CAM_DEPTH-1:0] wr0_dup_vec, wr1_dup_vec;
  logic [CAM_DEPTH-1:0] free_vec_after_wr0;

  logic hit0_any, hit1_any;
  logic [$clog2(CAM_DEPTH)-1:0] hit0_idx, hit1_idx;
  logic consume0, consume1, same_hit_entry;
  logic consume0_eff, consume1_eff;

  logic wr0_dup, wr1_dup;
  logic [$clog2(CAM_DEPTH)-1:0] wr0_dup_idx, wr1_dup_idx;
  logic wr0_alloc, wr1_alloc;
  logic [$clog2(CAM_DEPTH)-1:0] wr0_alloc_idx, wr1_alloc_idx;

  int j;
  always_comb begin
    for (j = 0; j < CAM_DEPTH; j++) begin
      free_vec[j]    = !ent[j].vld;
      hit0_vec[j]    = ent[j].vld && (ent[j].iid == lsu_mmu_id0);
      hit1_vec[j]    = ent[j].vld && (ent[j].iid == lsu_mmu_id1);
      hit0_use_vec[j]= hit0_vec[j] && (ent[j].vpn == lsu_mmu_vpn0);
      hit1_use_vec[j]= hit1_vec[j] && (ent[j].vpn == lsu_mmu_vpn1);
      wr0_dup_vec[j] = ent[j].vld && (ent[j].iid == expt_wr0_iid) && (ent[j].vpn == expt_wr0_vpn);
      wr1_dup_vec[j] = ent[j].vld && (ent[j].iid == expt_wr1_iid) && (ent[j].vpn == expt_wr1_vpn);
    end
  end

  assign hit0_any = |hit0_use_vec;
  assign hit1_any = |hit1_use_vec;
  assign hit0_idx = first_one_idx(hit0_use_vec);
  assign hit1_idx = first_one_idx(hit1_use_vec);

  assign consume0 = lsu_mmu_va0_vld && hit0_any && !lsu_mmu_abort0;
  assign consume1 = lsu_mmu_va1_vld && hit1_any && !lsu_mmu_abort1;
  assign same_hit_entry = hit0_any && hit1_any && (hit0_idx == hit1_idx);
  assign consume0_eff = consume0;
  assign consume1_eff = consume1 && !same_hit_entry;

  always_comb begin
    expt_hit_vec = '0;
    if (consume0_eff)
      expt_hit_vec[ent[hit0_idx].eid] = 1'b1;
    if (consume1_eff)
      expt_hit_vec[ent[hit1_idx].eid] = 1'b1;
  end

  always_comb begin
    expt_match0 = consume0_eff;
    expt_pgflt0 = 1'b0;
    expt_acflt0 = 1'b0;
    if (consume0_eff) begin
      expt_pgflt0 = ent[hit0_idx].pgflt;
      expt_acflt0 = ent[hit0_idx].acflt;
    end

    expt_match1 = consume1_eff;
    expt_pgflt1 = 1'b0;
    expt_acflt1 = 1'b0;
    if (consume1_eff) begin
      expt_pgflt1 = ent[hit1_idx].pgflt;
      expt_acflt1 = ent[hit1_idx].acflt;
    end
  end

  always_comb begin
    expt_wakeup = {12{consume0_eff || consume1_eff}};
  end

  assign wr0_dup = expt_wr0_vld && (|wr0_dup_vec);
  assign wr1_dup = expt_wr1_vld && (|wr1_dup_vec);
  assign wr0_dup_idx = first_one_idx(wr0_dup_vec);
  assign wr1_dup_idx = first_one_idx(wr1_dup_vec);

  assign wr0_alloc = expt_wr0_vld && !wr0_dup && (|free_vec);
  assign wr0_alloc_idx = first_one_idx(free_vec);

  always_comb begin
    free_vec_after_wr0 = free_vec;
    if (wr0_alloc)
      free_vec_after_wr0[wr0_alloc_idx] = 1'b0;
  end

  assign wr1_alloc = expt_wr1_vld && !wr1_dup && (|free_vec_after_wr0);
  assign wr1_alloc_idx = first_one_idx(free_vec_after_wr0);

  int k;
  always_ff @(posedge clk or negedge rst_b) begin
    if (!rst_b) begin
      for (k = 0; k < CAM_DEPTH; k++) begin
        ent[k].vld   <= 1'b0;
        ent[k].eid   <= '0;
        ent[k].iid   <= '0;
        ent[k].vpn   <= '0;
        ent[k].pgflt <= 1'b0;
        ent[k].acflt <= 1'b0;
      end
    end
    else if (rtu_yy_xx_flush || tlboper_utlb_clr || tlboper_utlb_inv_va_req) begin
      for (k = 0; k < CAM_DEPTH; k++) begin
        ent[k].vld <= 1'b0;
      end
    end
    else begin
      if (consume0_eff)
        ent[hit0_idx].vld <= 1'b0;
      if (consume1_eff)
        ent[hit1_idx].vld <= 1'b0;

      if (wr0_dup) begin
        ent[wr0_dup_idx].vld   <= 1'b1;
        ent[wr0_dup_idx].eid   <= expt_wr0_eid;
        ent[wr0_dup_idx].iid   <= expt_wr0_iid;
        ent[wr0_dup_idx].vpn   <= expt_wr0_vpn;
        ent[wr0_dup_idx].pgflt <= expt_wr0_pgflt;
        ent[wr0_dup_idx].acflt <= expt_wr0_acflt;
      end
      else if (wr0_alloc) begin
        ent[wr0_alloc_idx].vld   <= 1'b1;
        ent[wr0_alloc_idx].eid   <= expt_wr0_eid;
        ent[wr0_alloc_idx].iid   <= expt_wr0_iid;
        ent[wr0_alloc_idx].vpn   <= expt_wr0_vpn;
        ent[wr0_alloc_idx].pgflt <= expt_wr0_pgflt;
        ent[wr0_alloc_idx].acflt <= expt_wr0_acflt;
      end

      if (wr1_dup) begin
        ent[wr1_dup_idx].vld   <= 1'b1;
        ent[wr1_dup_idx].eid   <= expt_wr1_eid;
        ent[wr1_dup_idx].iid   <= expt_wr1_iid;
        ent[wr1_dup_idx].vpn   <= expt_wr1_vpn;
        ent[wr1_dup_idx].pgflt <= expt_wr1_pgflt;
        ent[wr1_dup_idx].acflt <= expt_wr1_acflt;
      end
      else if (wr1_alloc) begin
        ent[wr1_alloc_idx].vld   <= 1'b1;
        ent[wr1_alloc_idx].eid   <= expt_wr1_eid;
        ent[wr1_alloc_idx].iid   <= expt_wr1_iid;
        ent[wr1_alloc_idx].vpn   <= expt_wr1_vpn;
        ent[wr1_alloc_idx].pgflt <= expt_wr1_pgflt;
        ent[wr1_alloc_idx].acflt <= expt_wr1_acflt;
      end
    end
  end

endmodule
