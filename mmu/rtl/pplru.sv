module pplru #(
    parameter PDE_ENTRY_NUM = 16
) (
    input  logic                         forever_cpuclk,
    input  logic                         pad_yy_icg_scan_en,
    input  logic                         cp0_mmu_icg_en,
    input  logic                         cpurst_b,
    input  logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_vld,
    input  logic [PDE_ENTRY_NUM-1:0]     PDE_plru_read_hit,
    input  logic                         PDE_plru_read_hit_vld,
    input  logic                         PDE_plru_refill_vld,

    output logic [PDE_ENTRY_NUM-1:0]     plru_PDE_ref_num
);

localparam PDE_INDEX_WIDTH    = (PDE_ENTRY_NUM <= 1) ? 1 : $clog2(PDE_ENTRY_NUM);
localparam PDE_PLRU_ENTRY_NUM = (1 << PDE_INDEX_WIDTH);
localparam PDE_PLRU_NODE_NUM  = (PDE_PLRU_ENTRY_NUM <= 1) ? 1 : PDE_PLRU_ENTRY_NUM-1;

logic                             lru_clk;
logic                             lru_clk_en;
logic                             plru_write_updt;
logic                             plru_read_updt;
logic                             invalid_entry_found;
logic                             hit_num_onehot_vld;
logic [PDE_ENTRY_NUM-1:0]         vld_entry_num;
logic [PDE_ENTRY_NUM-1:0]         refill_num_onehot;
logic [PDE_ENTRY_NUM-1:0]         hit_num_onehot;
logic [PDE_INDEX_WIDTH-1:0]       write_num;
logic [PDE_INDEX_WIDTH-1:0]       hit_num_index;
logic [PDE_INDEX_WIDTH-1:0]       hit_num_flop;
logic [PDE_INDEX_WIDTH-1:0]       plru_num;
logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits;
logic [PDE_PLRU_NODE_NUM-1:0]     plru_bits_next;

//==========================================================
//                  Gate Cell
//==========================================================
assign lru_clk_en = plru_write_updt | plru_read_updt;

gated_clk_cell x_pplru_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (lru_clk           ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (lru_clk_en        ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//==========================================================
//                  Entry sel for Refill
//==========================================================
assign vld_entry_num[PDE_ENTRY_NUM-1:0] = PDE_plru_read_vld[PDE_ENTRY_NUM-1:0];

always_comb begin
    write_num[PDE_INDEX_WIDTH-1:0] = plru_num[PDE_INDEX_WIDTH-1:0];
    invalid_entry_found = 1'b0;

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if((!invalid_entry_found) && (!vld_entry_num[i])) begin
            write_num[PDE_INDEX_WIDTH-1:0] = i;
            invalid_entry_found = 1'b1;
        end
    end

    if((!invalid_entry_found) && (plru_num[PDE_INDEX_WIDTH-1:0] >= PDE_ENTRY_NUM))
        write_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
end

// refill 选路必须和 PDE entry 写使能同拍输出。若先打一拍再输出，
// 连续两拍 PDE_plru_refill_vld 会用上一拍 way 写 entry，导致第二笔覆盖第一笔。
always_comb begin
    refill_num_onehot[PDE_ENTRY_NUM-1:0] = {PDE_ENTRY_NUM{1'b0}};

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if(write_num[PDE_INDEX_WIDTH-1:0] == i)
            refill_num_onehot[i] = 1'b1;
    end
end

//----------------------------------------------------------
//                  Final Refill Sel to PDE Cache
//----------------------------------------------------------
assign plru_PDE_ref_num[PDE_ENTRY_NUM-1:0] = refill_num_onehot[PDE_ENTRY_NUM-1:0];

//==========================================================
//                  Read Update
//==========================================================
assign hit_num_onehot[PDE_ENTRY_NUM-1:0] = PDE_plru_read_hit[PDE_ENTRY_NUM-1:0];
assign hit_num_onehot_vld = (|hit_num_onehot[PDE_ENTRY_NUM-1:0])
                         && ((hit_num_onehot[PDE_ENTRY_NUM-1:0] & (hit_num_onehot[PDE_ENTRY_NUM-1:0] - 1'b1)) == {PDE_ENTRY_NUM{1'b0}});

always_comb begin
    hit_num_index[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};

    if(PDE_ENTRY_NUM > 8)
        hit_num_index[PDE_INDEX_WIDTH-1:0] = 8;

    for(int i = 0; i < PDE_ENTRY_NUM; i = i + 1) begin
        if(hit_num_onehot_vld && hit_num_onehot[i])
            hit_num_index[PDE_INDEX_WIDTH-1:0] = i;
    end
end

always_ff @(posedge lru_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        hit_num_flop[PDE_INDEX_WIDTH-1:0] <= {PDE_INDEX_WIDTH{1'b0}};
    else if(PDE_plru_read_hit_vld)
        hit_num_flop[PDE_INDEX_WIDTH-1:0] <= hit_num_index[PDE_INDEX_WIDTH-1:0];
end

assign plru_write_updt = PDE_plru_refill_vld;
assign plru_read_updt  = PDE_plru_read_hit_vld
                       && (hit_num_flop[PDE_INDEX_WIDTH-1:0] != hit_num_index[PDE_INDEX_WIDTH-1:0]);

always_comb begin
    int node;

    plru_bits_next[PDE_PLRU_NODE_NUM-1:0] = plru_bits[PDE_PLRU_NODE_NUM-1:0];
    node = 0;

    if(plru_write_updt) begin

        // PLRU 推进使用和本拍 entry 写入完全相同的 write_num，
        // 保证连续 refill 时每一拍都按实际写入 way 更新替换树。
        for(int level = 0; level < PDE_INDEX_WIDTH; level = level + 1) begin
            plru_bits_next[node] = !write_num[PDE_INDEX_WIDTH-1-level];

            if(write_num[PDE_INDEX_WIDTH-1-level])
                node = (node << 1) + 2;
            else
                node = (node << 1) + 1;
        end
    end else if(plru_read_updt) begin
        node = 0;

        for(int level = 0; level < PDE_INDEX_WIDTH; level = level + 1) begin
            plru_bits_next[node] = !hit_num_index[PDE_INDEX_WIDTH-1-level];

            if(hit_num_index[PDE_INDEX_WIDTH-1-level])
                node = (node << 1) + 2;
            else
                node = (node << 1) + 1;
        end
    end
end

always_ff @(posedge lru_clk or negedge cpurst_b) begin
    if(!cpurst_b)
        plru_bits[PDE_PLRU_NODE_NUM-1:0] <= {PDE_PLRU_NODE_NUM{1'b0}};
    else
        plru_bits[PDE_PLRU_NODE_NUM-1:0] <= plru_bits_next[PDE_PLRU_NODE_NUM-1:0];
end

//----------------------------------------------------------
//                  PDE Replacement Algorithm
//----------------------------------------------------------
always_comb begin
    int node;

    plru_num[PDE_INDEX_WIDTH-1:0] = {PDE_INDEX_WIDTH{1'b0}};
    node = 0;

    for(int level = 0; level < PDE_INDEX_WIDTH; level = level + 1) begin
        plru_num[PDE_INDEX_WIDTH-1-level] = plru_bits[node];

        if(plru_bits[node])
            node = (node << 1) + 2;
        else
            node = (node << 1) + 1;
    end
end

endmodule
