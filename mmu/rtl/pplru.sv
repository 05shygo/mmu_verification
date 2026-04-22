module pplru(
input  logic         forever_cpuclk,         
input  logic         pad_yy_icg_scan_en,   
input  logic         cp0_mmu_icg_en,         
input  logic         cpurst_b,               
input  logic [15:0]  PDE_plru_read_vld,               
input  logic [15:0]  PDE_plru_read_hit,       
input  logic         PDE_plru_read_hit_vld,    
input  logic         PDE_plru_refill_vld,  
 
output logic [15:0]  plru_PDE_ref_num  
);

    logic lru_clk;
    logic lru_clk_en;
    logic PDE_plru_refill_on;
    logic plru_write_updt;
    logic plru_read_updt;
    
    // LRU????
    logic p00, p10, p11, p20, p21, p22, p23;
    logic p30, p31, p32, p33, p34, p35, p36, p37;
    
    // ?????
    logic [15:0] vld_entry_num;
    logic [3:0]  write_num;
    logic [3:0]  refill_num_index;
    logic [15:0] refill_num_onehot;
    logic [15:0] hit_num_onehot;
    logic [3:0]  hit_num_index;
    logic [3:0]  hit_num_flop;
    logic [4:0]  plru_num;
    
    // ????????
    logic p00_write_updt_val;
    logic p00_read_updt_val;
    
    logic p10_write_updt;
    logic p10_read_updt;
    logic p10_write_updt_val;
    logic p10_read_updt_val;
    
    logic p11_write_updt;
    logic p11_read_updt;
    logic p11_write_updt_val;
    logic p11_read_updt_val;
    
    logic p20_write_updt;
    logic p20_read_updt;
    logic p20_write_updt_val;
    logic p20_read_updt_val;
    
    logic p21_write_updt;
    logic p21_read_updt;
    logic p21_write_updt_val;
    logic p21_read_updt_val;
    
    logic p22_write_updt;
    logic p22_read_updt;
    logic p22_write_updt_val;
    logic p22_read_updt_val;
    
    logic p23_write_updt;
    logic p23_read_updt;
    logic p23_write_updt_val;
    logic p23_read_updt_val;
    
    logic p30_write_updt;
    logic p30_read_updt;
    logic p30_write_updt_val;
    logic p30_read_updt_val;
    
    logic p31_write_updt;
    logic p31_read_updt;
    logic p31_write_updt_val;
    logic p31_read_updt_val;
    
    logic p32_write_updt;
    logic p32_read_updt;
    logic p32_write_updt_val;
    logic p32_read_updt_val;
    
    logic p33_write_updt;
    logic p33_read_updt;
    logic p33_write_updt_val;
    logic p33_read_updt_val;
    
    logic p34_write_updt;
    logic p34_read_updt;
    logic p34_write_updt_val;
    logic p34_read_updt_val;
    
    logic p35_write_updt;
    logic p35_read_updt;
    logic p35_write_updt_val;
    logic p35_read_updt_val;
    
    logic p36_write_updt;
    logic p36_read_updt;
    logic p36_write_updt_val;
    logic p36_read_updt_val;
    
    logic p37_write_updt;
    logic p37_read_updt;
    logic p37_write_updt_val;
    logic p37_read_updt_val;



//==========================================================
//                  Gate Cell
//==========================================================
assign lru_clk_en =  plru_write_updt | plru_read_updt;
// &Instance("gated_clk_cell", "x_iplru_gateclk"); @34
gated_clk_cell  x_pplru_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (lru_clk           ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (lru_clk_en        ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

//assign lru_clk = forever_cpuclk;
//==========================================================
//                  Entry sel for Refill
//==========================================================
assign vld_entry_num[15:0] = PDE_plru_read_vld[15:0];

always @( plru_num[4:0] or vld_entry_num[15:0])begin
    casez(vld_entry_num[15:0])
		16'b???????????????0: write_num[3:0] = 4'b0000;
		16'b??????????????01: write_num[3:0] = 4'b0001;
		16'b?????????????011: write_num[3:0] = 4'b0010;
		16'b????????????0111: write_num[3:0] = 4'b0011;
		16'b???????????01111: write_num[3:0] = 4'b0100;
		16'b??????????011111: write_num[3:0] = 4'b0101;
		16'b?????????0111111: write_num[3:0] = 4'b0110;
		16'b????????01111111: write_num[3:0] = 4'b0111;
		16'b???????011111111: write_num[3:0] = 4'b1000;
		16'b??????0111111111: write_num[3:0] = 4'b1001;
		16'b?????01111111111: write_num[3:0] = 4'b1010;
		16'b????011111111111: write_num[3:0] = 4'b1011;
		16'b???0111111111111: write_num[3:0] = 4'b1100;
		16'b??01111111111111: write_num[3:0] = 4'b1101;
		16'b?011111111111111: write_num[3:0] = 4'b1110;
		16'b0111111111111111: write_num[3:0] = 4'b1111;
		16'b1111111111111111: write_num[3:0] = plru_num[4:0];
		default:              write_num[3:0] = 4'b0;
	endcase
end


always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    refill_num_index[3:0] <= 4'b0;
  else
    refill_num_index[3:0] <= write_num[3:0];
end


// &CombBeg; @104
always @(refill_num_index[3:0])begin
	case(refill_num_index[3:0])
	  4'h0: refill_num_onehot[15:0] = 16'b0000000000000001;
	  4'h1: refill_num_onehot[15:0] = 16'b0000000000000010;
	  4'h2: refill_num_onehot[15:0] = 16'b0000000000000100;
	  4'h3: refill_num_onehot[15:0] = 16'b0000000000001000;
	  4'h4: refill_num_onehot[15:0] = 16'b0000000000010000;
	  4'h5: refill_num_onehot[15:0] = 16'b0000000000100000;
	  4'h6: refill_num_onehot[15:0] = 16'b0000000001000000;
	  4'h7: refill_num_onehot[15:0] = 16'b0000000010000000;
	  4'h8: refill_num_onehot[15:0] = 16'b0000000100000000;
	  4'h9: refill_num_onehot[15:0] = 16'b0000001000000000;
	  4'ha: refill_num_onehot[15:0] = 16'b0000010000000000;
	  4'hb: refill_num_onehot[15:0] = 16'b0000100000000000;
	  4'hc: refill_num_onehot[15:0] = 16'b0001000000000000;
	  4'hd: refill_num_onehot[15:0] = 16'b0010000000000000;
	  4'he: refill_num_onehot[15:0] = 16'b0100000000000000;
	  4'hf: refill_num_onehot[15:0] = 16'b1000000000000000;
	endcase
end

//----------------------------------------------------------
//                  Final Refill Sel to uTLB
//----------------------------------------------------------
assign plru_PDE_ref_num[15:0] = refill_num_onehot[15:0];

//==========================================================
//                  Read Update
//==========================================================
// When PDE hit with different entry, updata PLRU path flop
assign hit_num_onehot[15:0] = PDE_plru_read_hit[15:0];

always @( hit_num_onehot[15:0])begin
	case(hit_num_onehot[15:0])
		16'b0000000000000001: hit_num_index[3:0] = 4'b0000;
		16'b0000000000000010: hit_num_index[3:0] = 4'b0001;
		16'b0000000000000100: hit_num_index[3:0] = 4'b0010;
		16'b0000000000001000: hit_num_index[3:0] = 4'b0011;
		16'b0000000000010000: hit_num_index[3:0] = 4'b0100;
		16'b0000000000100000: hit_num_index[3:0] = 4'b0101;
		16'b0000000001000000: hit_num_index[3:0] = 4'b0110;
		16'b0000000010000000: hit_num_index[3:0] = 4'b0111;
		16'b0000000100000000: hit_num_index[3:0] = 4'b1000;
		16'b0000001000000000: hit_num_index[3:0] = 4'b1001;
		16'b0000010000000000: hit_num_index[3:0] = 4'b1010;
		16'b0000100000000000: hit_num_index[3:0] = 4'b1011;
		16'b0001000000000000: hit_num_index[3:0] = 4'b1100;
		16'b0010000000000000: hit_num_index[3:0] = 4'b1101;
		16'b0100000000000000: hit_num_index[3:0] = 4'b1110;
		16'b1000000000000000: hit_num_index[3:0] = 4'b1111;
		default             : hit_num_index[3:0] = 4'b1000;
	endcase
end

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    hit_num_flop[3:0] <= 4'b0;
  else if(PDE_plru_read_hit_vld)
    hit_num_flop[3:0] <= hit_num_index[3:0];
end

//==========================================================
//                  PLRU Path Flop
//==========================================================
//                             P00
//                             /\
//                            /  \
//                           /    \
//                         0/      \1
//                         /        \
//                     P10            P11
//                      /\           /\
//                    0/  \1       0/  \1
//                    /    \       /    \
//                P20     P21     P22     P23
//               /\      /\       /\       /\
//             0/  \1  0/  \1   0/  \1   0/  \1
//            P30 P31  P32 P33  P34 P35  P36 P37          


assign plru_write_updt = PDE_plru_refill_vld;
assign plru_read_updt  = PDE_plru_read_hit_vld
                      && (hit_num_flop[3:0] != hit_num_index[3:0]); 


//----------------------------------------------------------
//                  Level 0 Path
//----------------------------------------------------------
// Path 0
assign p00_write_updt_val = !refill_num_index[3];
assign p00_read_updt_val  = !hit_num_index[3];

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p00 <= 1'b0;
  else if(plru_write_updt)
    p00 <= p00_write_updt_val;
  else if(plru_read_updt)
    p00 <= p00_read_updt_val;
end


//----------------------------------------------------------
//                  Level 1 Path
//----------------------------------------------------------
// Path 10
assign p10_write_updt     = plru_write_updt && !refill_num_index[3];
assign p10_read_updt      = plru_read_updt  && !hit_num_index[3];

assign p10_write_updt_val = (refill_num_index[3:2] == 2'b00); 
assign p10_read_updt_val  = (hit_num_index[3:2] == 2'b00);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p10 <= 1'b0;
  else if(p10_write_updt)
    p10 <= p10_write_updt_val;
  else if(p10_read_updt)
    p10 <= p10_read_updt_val;
end

// Path 11
assign p11_write_updt     = plru_write_updt && refill_num_index[3];
assign p11_read_updt      = plru_read_updt  && hit_num_index[3];

assign p11_write_updt_val = (refill_num_index[3:2] == 2'b10);
assign p11_read_updt_val  = (hit_num_index[3:2] == 2'b10);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p11 <= 1'b0;
  else if(p11_write_updt)
    p11 <= p11_write_updt_val;
  else if(p11_read_updt)
    p11 <= p11_read_updt_val;
end


//----------------------------------------------------------
//                  Level 2 Path
//----------------------------------------------------------
// Path 20
assign p20_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b00);
assign p20_read_updt      = plru_read_updt
                         && (hit_num_index[3:2] == 2'b00);

assign p20_write_updt_val = (refill_num_index[3:1] == 3'b000);
assign p20_read_updt_val  = (hit_num_index[3:1] == 3'b000);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p20 <= 1'b0;
  else if(p20_write_updt)
    p20 <= p20_write_updt_val;
  else if(p20_read_updt)
    p20 <= p20_read_updt_val;
end

// Path 21
assign p21_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b01);
assign p21_read_updt      = plru_read_updt
                         && (hit_num_index[3:2] == 2'b01);

assign p21_write_updt_val = (refill_num_index[3:1] == 3'b010);
assign p21_read_updt_val  = (hit_num_index[3:1] == 3'b010);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p21 <= 1'b0;
  else if(p21_write_updt)
    p21 <= p21_write_updt_val;
  else if(p21_read_updt)
    p21 <= p21_read_updt_val;
end

// Path 22
assign p22_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b10);
assign p22_read_updt      = plru_read_updt
                         && (hit_num_index[3:2] == 2'b10);

assign p22_write_updt_val = (refill_num_index[3:1] == 3'b100);
assign p22_read_updt_val  = (hit_num_index[3:1] == 3'b100);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p22 <= 1'b0;
  else if(p22_write_updt)
    p22 <= p22_write_updt_val;
  else if(p22_read_updt)
    p22 <= p22_read_updt_val;
end

// Path 23
assign p23_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b11);
assign p23_read_updt      = plru_read_updt
                         && (hit_num_index[3:2] == 2'b11);

assign p23_write_updt_val = (refill_num_index[3:1] == 3'b110);
assign p23_read_updt_val  = (hit_num_index[3:1] == 3'b110);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p23 <= 1'b0;
  else if(p23_write_updt)
    p23 <= p23_write_updt_val;
  else if(p23_read_updt)
    p23 <= p23_read_updt_val;
end


//----------------------------------------------------------
//                  Level 3 Path
//----------------------------------------------------------
//Path 30
assign p30_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b000);
assign p30_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b000);

assign p30_write_updt_val = (refill_num_index[3:0] == 4'b0000);
assign p30_read_updt_val  = (hit_num_index[3:0] == 4'b0000);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p30 <= 1'b0;
  else if(p30_write_updt)
    p30 <= p30_write_updt_val;
  else if(p30_read_updt)
    p30 <= p30_read_updt_val;
end

//Path 31
assign p31_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b001);
assign p31_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b001);

assign p31_write_updt_val = (refill_num_index[3:0] == 4'b0010);
assign p31_read_updt_val  = (hit_num_index[3:0] == 4'b0010);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p31 <= 1'b0; 
  else if(p31_write_updt)
    p31 <= p31_write_updt_val;
  else if(p31_read_updt)
    p31 <= p31_read_updt_val;
end
  
//Path 32
assign p32_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b010);
assign p32_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b010);

assign p32_write_updt_val = (refill_num_index[3:0] == 4'b0100);
assign p32_read_updt_val  = (hit_num_index[3:0] == 4'b0100);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p32 <= 1'b0; 
  else if(p32_write_updt)
    p32 <= p32_write_updt_val;
  else if(p32_read_updt)
    p32 <= p32_read_updt_val;
end 
  
//Path 33
assign p33_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b011);
assign p33_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b011);

assign p33_write_updt_val = (refill_num_index[3:0] == 4'b0110);
assign p33_read_updt_val  = (hit_num_index[3:0] == 4'b0110);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p33 <= 1'b0; 
  else if(p33_write_updt)
    p33 <= p33_write_updt_val;
  else if(p33_read_updt)
    p33 <= p33_read_updt_val;
end 
  
//Path 34
assign p34_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b100);
assign p34_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b100);

assign p34_write_updt_val = (refill_num_index[3:0] == 4'b1000);
assign p34_read_updt_val  = (hit_num_index[3:0] == 4'b1000);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p34 <= 1'b0; 
  else if(p34_write_updt)
    p34 <= p34_write_updt_val;
  else if(p34_read_updt)
    p34 <= p34_read_updt_val;
end 
  
//Path 35
assign p35_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b101);
assign p35_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b101);

assign p35_write_updt_val = (refill_num_index[3:0] == 4'b1010);
assign p35_read_updt_val  = (hit_num_index[3:0] == 4'b1010);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p35 <= 1'b0; 
  else if(p35_write_updt)
    p35 <= p35_write_updt_val;
  else if(p35_read_updt)
    p35 <= p35_read_updt_val;
end 
  
//Path 36
assign p36_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b110);
assign p36_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b110);

assign p36_write_updt_val = (refill_num_index[3:0] == 4'b1100);
assign p36_read_updt_val  = (hit_num_index[3:0] == 4'b1100);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p36 <= 1'b0; 
  else if(p36_write_updt)
    p36 <= p36_write_updt_val;
  else if(p36_read_updt)
    p36 <= p36_read_updt_val;
end 
  
//Path 37
assign p37_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b111);
assign p37_read_updt      = plru_read_updt
                         && (hit_num_index[3:1] == 3'b111);

assign p37_write_updt_val = (refill_num_index[3:0] == 4'b1110);
assign p37_read_updt_val  = (hit_num_index[3:0] == 4'b1110);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p37 <= 1'b0; 
  else if(p37_write_updt)
    p37 <= p37_write_updt_val;
  else if(p37_read_updt)
    p37 <= p37_read_updt_val;
end 

//----------------------------------------------------------
//                  uTLB Replacement Algorithm
//----------------------------------------------------------
assign plru_num[3] =  p00;

assign plru_num[2] = !p00 &&  p10
                   || p00 &&  p11;

assign plru_num[1] = !p00 && !p10 &&  p20
                   ||!p00 &&  p10 &&  p21
                   || p00 && !p11 &&  p22
                   || p00 &&  p11 &&  p23;

assign plru_num[0] = !p00 && !p10 && !p20 && p30
                   ||!p00 && !p10 &&  p20 && p31
                   ||!p00 &&  p10 && !p21 && p32
                   ||!p00 &&  p10 &&  p21 && p33
                   || p00 && !p11 && !p22 && p34
                   || p00 && !p11 &&  p22 && p35
                   || p00 &&  p11 && !p23 && p36
                   || p00 &&  p11 &&  p23 && p37;



endmodule





