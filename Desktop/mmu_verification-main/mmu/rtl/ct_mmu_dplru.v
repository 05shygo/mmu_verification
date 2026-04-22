/*Copyright 2019-2021 T-Head Semiconductor Co., Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// &ModuleBeg; @23
module ct_mmu_dplru(
input  logic         cp0_mmu_icg_en,         
input  logic         cpurst_b,               
input  logic         entry0_vld,             
input  logic         entry10_vld,            
input  logic         entry11_vld,            
input  logic         entry12_vld,            
input  logic         entry13_vld,            
input  logic         entry14_vld,            
input  logic         entry15_vld,            
input  logic         entry1_vld,             
input  logic         entry2_vld,             
input  logic         entry3_vld,             
input  logic         entry4_vld,             
input  logic         entry5_vld,             
input  logic         entry6_vld,             
input  logic         entry7_vld,             
input  logic         entry8_vld,             
input  logic         entry9_vld,             
input  logic         forever_cpuclk,         
input  logic         pad_yy_icg_scan_en,     
input  logic [15:0]  utlb_plru_read_hit0,    
input  logic [15:0]  utlb_plru_read_hit1,    
input  logic         utlb_plru_read_hit_vld0, 
input  logic         utlb_plru_read_hit_vld1, 
input  logic         utlb_plru_refill_on,    
input  logic         utlb_plru_refill_vld,   
output logic [15:0]  plru_dutlb_ref_num     

);

// &Ports; @24

// &Regs; @25
logic     [3 :0]  hit_num_flop0;          
logic     [3 :0]  hit_num_flop1;          
logic     [3 :0]  hit_num_index0;         
logic     [3 :0]  hit_num_index1;         
logic             p00;                    
logic             p10;                    
logic             p11;                    
logic             p20;                    
logic             p21;                    
logic             p22;                    
logic             p23;                    
logic             p30;                    
logic             p31;                    
logic             p32;                    
logic             p33;                    
logic             p34;                    
logic             p35;                    
logic             p36;                    
logic             p37;                    
logic     [3 :0]  refill_num_index;       
logic     [15:0]  refill_num_onehot;      
logic     [3 :0]  write_num;              

// &Wires; @26
logic    [15:0]  hit_num_onehot0;        
logic    [15:0]  hit_num_onehot1;        
logic            lru_clk;                
logic            lru_clk_en;             
logic            p00_read_updt;          
logic            p00_read_updt_val;      
logic            p00_write_updt;         
logic            p00_write_updt_val;     
logic            p10_rdupdt_by_va0;      
logic            p10_rdupdt_by_va01;     
logic            p10_rdupdt_by_va1;      
logic            p10_read_updt0;         
logic            p10_read_updt1;         
logic            p10_read_updt_val0;     
logic            p10_read_updt_val1;     
logic            p10_write_updt;         
logic            p10_write_updt_val;     
logic            p11_rdupdt_by_va0;      
logic            p11_rdupdt_by_va01;     
logic            p11_rdupdt_by_va1;      
logic            p11_read_updt0;         
logic            p11_read_updt1;         
logic            p11_read_updt_val0;     
logic            p11_read_updt_val1;     
logic            p11_write_updt;         
logic            p11_write_updt_val;     
logic            p20_rdupdt_by_va0;      
logic            p20_rdupdt_by_va01;     
logic            p20_rdupdt_by_va1;      
logic            p20_read_updt0;         
logic            p20_read_updt1;         
logic            p20_read_updt_val0;     
logic            p20_read_updt_val1;     
logic            p20_write_updt;         
logic            p20_write_updt_val;     
logic            p21_rdupdt_by_va0;      
logic            p21_rdupdt_by_va01;     
logic            p21_rdupdt_by_va1;      
logic            p21_read_updt0;         
logic            p21_read_updt1;         
logic            p21_read_updt_val0;     
logic            p21_read_updt_val1;     
logic            p21_write_updt;         
logic            p21_write_updt_val;     
logic            p22_rdupdt_by_va0;      
logic            p22_rdupdt_by_va01;     
logic            p22_rdupdt_by_va1;      
logic            p22_read_updt0;         
logic            p22_read_updt1;         
logic            p22_read_updt_val0;     
logic            p22_read_updt_val1;     
logic            p22_write_updt;         
logic            p22_write_updt_val;     
logic            p23_rdupdt_by_va0;      
logic            p23_rdupdt_by_va01;     
logic            p23_rdupdt_by_va1;      
logic            p23_read_updt0;         
logic            p23_read_updt1;         
logic            p23_read_updt_val0;     
logic            p23_read_updt_val1;     
logic            p23_write_updt;         
logic            p23_write_updt_val;     
logic            p30_rdupdt_by_va0;      
logic            p30_rdupdt_by_va01;     
logic            p30_rdupdt_by_va1;      
logic            p30_read_updt0;         
logic            p30_read_updt1;         
logic            p30_read_updt_val0;     
logic            p30_read_updt_val1;     
logic            p30_write_updt;         
logic            p30_write_updt_val;     
logic            p31_rdupdt_by_va0;      
logic            p31_rdupdt_by_va01;     
logic            p31_rdupdt_by_va1;      
logic            p31_read_updt0;         
logic            p31_read_updt1;         
logic            p31_read_updt_val0;     
logic            p31_read_updt_val1;     
logic            p31_write_updt;         
logic            p31_write_updt_val;     
logic            p32_rdupdt_by_va0;      
logic            p32_rdupdt_by_va01;     
logic            p32_rdupdt_by_va1;      
logic            p32_read_updt0;         
logic            p32_read_updt1;         
logic            p32_read_updt_val0;     
logic            p32_read_updt_val1;     
logic            p32_write_updt;         
logic            p32_write_updt_val;     
logic            p33_rdupdt_by_va0;      
logic            p33_rdupdt_by_va01;     
logic            p33_rdupdt_by_va1;      
logic            p33_read_updt0;         
logic            p33_read_updt1;         
logic            p33_read_updt_val0;     
logic            p33_read_updt_val1;     
logic            p33_write_updt;         
logic            p33_write_updt_val;     
logic            p34_rdupdt_by_va0;      
logic            p34_rdupdt_by_va01;     
logic            p34_rdupdt_by_va1;      
logic            p34_read_updt0;         
logic            p34_read_updt1;         
logic            p34_read_updt_val0;     
logic            p34_read_updt_val1;     
logic            p34_write_updt;         
logic            p34_write_updt_val;     
logic            p35_rdupdt_by_va0;      
logic            p35_rdupdt_by_va01;     
logic            p35_rdupdt_by_va1;      
logic            p35_read_updt0;         
logic            p35_read_updt1;         
logic            p35_read_updt_val0;     
logic            p35_read_updt_val1;     
logic            p35_write_updt;         
logic            p35_write_updt_val;     
logic            p36_rdupdt_by_va0;      
logic            p36_rdupdt_by_va01;     
logic            p36_rdupdt_by_va1;      
logic            p36_read_updt0;         
logic            p36_read_updt1;         
logic            p36_read_updt_val0;     
logic            p36_read_updt_val1;     
logic            p36_write_updt;         
logic            p36_write_updt_val;     
logic            p37_rdupdt_by_va0;      
logic            p37_rdupdt_by_va01;     
logic            p37_rdupdt_by_va1;      
logic            p37_read_updt0;         
logic            p37_read_updt1;         
logic            p37_read_updt_val0;     
logic            p37_read_updt_val1;     
logic            p37_write_updt;         
logic            p37_write_updt_val;     
logic    [3 :0]  plru_num;               
logic            plru_read_updt;         
logic            plru_read_updt0;        
logic            plru_read_updt1;        
logic            plru_write_updt;        
logic    [15:0]  vld_entry_num;          



//==========================================================
//                  Gate Cell
//==========================================================
assign lru_clk_en = utlb_plru_refill_on
                || plru_read_updt0
                || plru_read_updt1;
// &Instance("gated_clk_cell", "x_dplru_gateclk"); @35
gated_clk_cell  x_dplru_gateclk (
  .clk_in             (forever_cpuclk    ),
  .clk_out            (lru_clk           ),
  .external_en        (1'b0              ),
  .global_en          (1'b1              ),
  .local_en           (lru_clk_en        ),
  .module_en          (cp0_mmu_icg_en    ),
  .pad_yy_icg_scan_en (pad_yy_icg_scan_en)
);

// &Connect( .clk_in     (forever_cpuclk), @36
//           .external_en(1'b0          ), @37
//           .global_en  (1'b1          ), @38
//           .module_en  (cp0_mmu_icg_en), @39
//           .local_en   (lru_clk_en    ), @40
//           .clk_out    (lru_clk       ) @41
//          ); @42



//==========================================================
//                  Entry sel for Refill
//==========================================================
assign vld_entry_num[15:0] = {entry15_vld, entry14_vld, entry13_vld, entry12_vld,
                              entry11_vld, entry10_vld, entry9_vld,  entry8_vld,
                              entry7_vld,  entry6_vld,  entry5_vld,  entry4_vld,
                              entry3_vld,  entry2_vld,  entry1_vld,  entry0_vld};  
// &CombBeg; @53
always @( plru_num[3:0]
       or vld_entry_num[15:0])
begin
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
  16'b1111111111111111: write_num[3:0] = plru_num[3:0];
endcase
// &CombEnd; @73
end


always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    refill_num_index[3:0] <= 4'b0;
  else if(utlb_plru_refill_on)
    refill_num_index[3:0] <= write_num[3:0];
end


// &CombBeg; @85
always @( refill_num_index[3:0])
begin
case(refill_num_index[3:0])
  4'b0000: refill_num_onehot[15:0] = 16'b0000000000000001;
  4'b0001: refill_num_onehot[15:0] = 16'b0000000000000010;
  4'b0010: refill_num_onehot[15:0] = 16'b0000000000000100;
  4'b0011: refill_num_onehot[15:0] = 16'b0000000000001000;
  4'b0100: refill_num_onehot[15:0] = 16'b0000000000010000;
  4'b0101: refill_num_onehot[15:0] = 16'b0000000000100000;
  4'b0110: refill_num_onehot[15:0] = 16'b0000000001000000;
  4'b0111: refill_num_onehot[15:0] = 16'b0000000010000000;
  4'b1000: refill_num_onehot[15:0] = 16'b0000000100000000;
  4'b1001: refill_num_onehot[15:0] = 16'b0000001000000000;
  4'b1010: refill_num_onehot[15:0] = 16'b0000010000000000;
  4'b1011: refill_num_onehot[15:0] = 16'b0000100000000000;
  4'b1100: refill_num_onehot[15:0] = 16'b0001000000000000;
  4'b1101: refill_num_onehot[15:0] = 16'b0010000000000000;
  4'b1110: refill_num_onehot[15:0] = 16'b0100000000000000;
  4'b1111: refill_num_onehot[15:0] = 16'b1000000000000000;
endcase
// &CombEnd; @104
end




//----------------------------------------------------------
//                  Final Refill Sel to uTLB
//----------------------------------------------------------
assign plru_dutlb_ref_num[15:0] = refill_num_onehot[15:0];


//==========================================================
//                  Read Update
//==========================================================
// When utlb hit with different entry, updata PLRU path flop
assign hit_num_onehot0[15:0] = utlb_plru_read_hit0[15:0];
// &CombBeg; @120
always @( hit_num_onehot0[15:0])
begin
case(hit_num_onehot0[15:0])
  16'b0000000000000001: hit_num_index0[3:0] = 4'b0000;
  16'b0000000000000010: hit_num_index0[3:0] = 4'b0001;
  16'b0000000000000100: hit_num_index0[3:0] = 4'b0010;
  16'b0000000000001000: hit_num_index0[3:0] = 4'b0011;
  16'b0000000000010000: hit_num_index0[3:0] = 4'b0100;
  16'b0000000000100000: hit_num_index0[3:0] = 4'b0101;
  16'b0000000001000000: hit_num_index0[3:0] = 4'b0110;
  16'b0000000010000000: hit_num_index0[3:0] = 4'b0111;
  16'b0000000100000000: hit_num_index0[3:0] = 4'b1000;
  16'b0000001000000000: hit_num_index0[3:0] = 4'b1001;
  16'b0000010000000000: hit_num_index0[3:0] = 4'b1010;
  16'b0000100000000000: hit_num_index0[3:0] = 4'b1011;
  16'b0001000000000000: hit_num_index0[3:0] = 4'b1100;
  16'b0010000000000000: hit_num_index0[3:0] = 4'b1101;
  16'b0100000000000000: hit_num_index0[3:0] = 4'b1110;
  16'b1000000000000000: hit_num_index0[3:0] = 4'b1111;
  default             : hit_num_index0[3:0] = 4'b0000;
endcase
// &CombEnd; @140
end


always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    hit_num_flop0[3:0] <= 4'b0;
  else if(utlb_plru_read_hit_vld0)
    hit_num_flop0[3:0] <= hit_num_index0[3:0];
end


assign hit_num_onehot1[15:0] = utlb_plru_read_hit1[15:0];
// &CombBeg; @153
always @( hit_num_onehot1[15:0])
begin
case(hit_num_onehot1[15:0])
  16'b0000000000000001: hit_num_index1[3:0] = 4'b0000;
  16'b0000000000000010: hit_num_index1[3:0] = 4'b0001;
  16'b0000000000000100: hit_num_index1[3:0] = 4'b0010;
  16'b0000000000001000: hit_num_index1[3:0] = 4'b0011;
  16'b0000000000010000: hit_num_index1[3:0] = 4'b0100;
  16'b0000000000100000: hit_num_index1[3:0] = 4'b0101;
  16'b0000000001000000: hit_num_index1[3:0] = 4'b0110;
  16'b0000000010000000: hit_num_index1[3:0] = 4'b0111;
  16'b0000000100000000: hit_num_index1[3:0] = 4'b1000;
  16'b0000001000000000: hit_num_index1[3:0] = 4'b1001;
  16'b0000010000000000: hit_num_index1[3:0] = 4'b1010;
  16'b0000100000000000: hit_num_index1[3:0] = 4'b1011;
  16'b0001000000000000: hit_num_index1[3:0] = 4'b1100;
  16'b0010000000000000: hit_num_index1[3:0] = 4'b1101;
  16'b0100000000000000: hit_num_index1[3:0] = 4'b1110;
  16'b1000000000000000: hit_num_index1[3:0] = 4'b1111;
  default             : hit_num_index1[3:0] = 4'b0000;
endcase
// &CombEnd; @173
end


always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    hit_num_flop1[3:0] <= 4'b0;
  else if(utlb_plru_read_hit_vld1)
    hit_num_flop1[3:0] <= hit_num_index1[3:0];
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

assign plru_write_updt = utlb_plru_refill_vld;
assign plru_read_updt0 = utlb_plru_read_hit_vld0
                            && (hit_num_flop0[3:0] != hit_num_index0[3:0]);
assign plru_read_updt1 = utlb_plru_read_hit_vld1
                            && (hit_num_flop1[3:0] != hit_num_index1[3:0]); 
assign plru_read_updt  = plru_read_updt0 || plru_read_updt1;

//----------------------------------------------------------
//                  Level 0 Path
//----------------------------------------------------------
// Path 0
assign p00_write_updt     = plru_write_updt;
assign p00_read_updt      = plru_read_updt
                        && (hit_num_index0[3] == hit_num_index1[3]);

assign p00_write_updt_val = !refill_num_index[3];
assign p00_read_updt_val  = !hit_num_index0[3];

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p00 <= 1'b0;
  else if(p00_write_updt)
    p00 <= p00_write_updt_val;
  else if(p00_read_updt)
    p00 <= p00_read_updt_val;
end


//----------------------------------------------------------
//                  Level 1 Path
//----------------------------------------------------------
// Path 10
assign p10_write_updt     = plru_write_updt && !refill_num_index[3];
assign p10_read_updt0     = plru_read_updt0 && !hit_num_index0[3];
assign p10_read_updt1     = plru_read_updt1 && !hit_num_index1[3];

assign p10_write_updt_val = (refill_num_index[3:2] == 2'b00); 
assign p10_read_updt_val0 = (hit_num_index0[3:2] == 2'b00);
assign p10_read_updt_val1 = (hit_num_index1[3:2] == 2'b00);

assign p10_rdupdt_by_va0  =  p10_read_updt0 && !p10_read_updt1;
assign p10_rdupdt_by_va1  = !p10_read_updt0 &&  p10_read_updt1;
assign p10_rdupdt_by_va01 = (p10_read_updt0 &&  p10_read_updt1)
                         && (p10_read_updt_val0 ^~ p10_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p10 <= 1'b0;
  else if(p10_write_updt)
    p10 <= p10_write_updt_val;
  else if(p10_rdupdt_by_va0 || p10_rdupdt_by_va01)
    p10 <= p10_read_updt_val0;
  else if(p10_rdupdt_by_va1)
    p10 <= p10_read_updt_val1;
end

// Path 11
assign p11_write_updt     = plru_write_updt && refill_num_index[3];
assign p11_read_updt0     = plru_read_updt0  && hit_num_index0[3];
assign p11_read_updt1     = plru_read_updt1  && hit_num_index1[3];

assign p11_write_updt_val = (refill_num_index[3:2] == 2'b10);
assign p11_read_updt_val0 = (hit_num_index0[3:2] == 2'b10);
assign p11_read_updt_val1 = (hit_num_index1[3:2] == 2'b10);

assign p11_rdupdt_by_va0  =  p11_read_updt0 && !p11_read_updt1;
assign p11_rdupdt_by_va1  = !p11_read_updt0 &&  p11_read_updt1;
assign p11_rdupdt_by_va01 = (p11_read_updt0 &&  p11_read_updt1)
                         && (p11_read_updt_val0 ^~ p11_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p11 <= 1'b0;
  else if(p11_write_updt)
    p11 <= p11_write_updt_val;
  else if(p11_rdupdt_by_va0 || p11_rdupdt_by_va01)
    p11 <= p11_read_updt_val0;
 else if(p11_rdupdt_by_va1)
    p11 <= p11_read_updt_val1;
end


//----------------------------------------------------------
//                  Level 2 Path
//----------------------------------------------------------
// Path 20
assign p20_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b00);
assign p20_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:2] == 2'b00);
assign p20_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:2] == 2'b00);

assign p20_write_updt_val = (refill_num_index[3:1] == 3'b000);
assign p20_read_updt_val0 = (hit_num_index0[3:1] == 3'b000);
assign p20_read_updt_val1 = (hit_num_index1[3:1] == 3'b000);

assign p20_rdupdt_by_va0  =  p20_read_updt0 && !p20_read_updt1;
assign p20_rdupdt_by_va1  = !p20_read_updt0 &&  p20_read_updt1;
assign p20_rdupdt_by_va01 = (p20_read_updt0 &&  p20_read_updt1)
                         && (p20_read_updt_val0 ^~ p20_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p20 <= 1'b0;
  else if(p20_write_updt)
    p20 <= p20_write_updt_val;
  else if(p20_rdupdt_by_va0 || p20_rdupdt_by_va01)
    p20 <= p20_read_updt_val0;
  else if(p20_rdupdt_by_va1)
    p20 <= p20_read_updt_val1;
end

// Path 21
assign p21_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b01);
assign p21_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:2] == 2'b01);
assign p21_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:2] == 2'b01);

assign p21_write_updt_val = (refill_num_index[3:1] == 3'b010);
assign p21_read_updt_val0 = (hit_num_index0[3:1] == 3'b010);
assign p21_read_updt_val1 = (hit_num_index1[3:1] == 3'b010);

assign p21_rdupdt_by_va0  =  p21_read_updt0 && !p21_read_updt1;
assign p21_rdupdt_by_va1  = !p21_read_updt0 &&  p21_read_updt1;
assign p21_rdupdt_by_va01 = (p21_read_updt0 &&  p21_read_updt1)
                         && (p21_read_updt_val0 ^~ p21_read_updt_val1);


always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p21 <= 1'b0;
  else if(p21_write_updt)
    p21 <= p21_write_updt_val;
  else if(p21_rdupdt_by_va0 || p21_rdupdt_by_va01)
    p21 <= p21_read_updt_val0;
  else if(p21_rdupdt_by_va1)
    p21 <= p21_read_updt_val1;
end

// Path 22
assign p22_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b10);
assign p22_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:2] == 2'b10);
assign p22_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:2] == 2'b10);

assign p22_write_updt_val = (refill_num_index[3:1] == 3'b100);
assign p22_read_updt_val0 = (hit_num_index0[3:1] == 3'b100);
assign p22_read_updt_val1 = (hit_num_index1[3:1] == 3'b100);

assign p22_rdupdt_by_va0  =  p22_read_updt0 && !p22_read_updt1;
assign p22_rdupdt_by_va1  = !p22_read_updt0 &&  p22_read_updt1;
assign p22_rdupdt_by_va01 = (p22_read_updt0 &&  p22_read_updt1)
                         && (p22_read_updt_val0 ^~ p22_read_updt_val1);


always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p22 <= 1'b0;
  else if(p22_write_updt)
    p22 <= p22_write_updt_val;
  else if(p22_rdupdt_by_va0 || p22_rdupdt_by_va01)
    p22 <= p22_read_updt_val0;
  else if(p22_rdupdt_by_va1)
    p22 <= p22_read_updt_val1;
end

// Path 23
assign p23_write_updt     = plru_write_updt
                         && (refill_num_index[3:2] == 2'b11);
assign p23_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:2] == 2'b11);
assign p23_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:2] == 2'b11);

assign p23_write_updt_val = (refill_num_index[3:1] == 3'b110);
assign p23_read_updt_val0 = (hit_num_index0[3:1] == 3'b110);
assign p23_read_updt_val1 = (hit_num_index1[3:1] == 3'b110);

assign p23_rdupdt_by_va0  =  p23_read_updt0 && !p23_read_updt1;
assign p23_rdupdt_by_va1  = !p23_read_updt0 &&  p23_read_updt1;
assign p23_rdupdt_by_va01 = (p23_read_updt0 &&  p23_read_updt1)
                         && (p23_read_updt_val0 ^~ p23_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p23 <= 1'b0;
  else if(p23_write_updt)
    p23 <= p23_write_updt_val;
  else if(p23_rdupdt_by_va0 || p23_rdupdt_by_va01)
    p23 <= p23_read_updt_val0;
  else if(p23_rdupdt_by_va1)
    p23 <= p23_read_updt_val1; 
end


//----------------------------------------------------------
//                  Level 3 Path
//----------------------------------------------------------
//Path 30
assign p30_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b000);
assign p30_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b000);
assign p30_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b000);

assign p30_write_updt_val = (refill_num_index[3:0] == 4'b0000);
assign p30_read_updt_val0 = (hit_num_index0[3:0] == 4'b0000);
assign p30_read_updt_val1 = (hit_num_index1[3:0] == 4'b0000);

assign p30_rdupdt_by_va0  =  p30_read_updt0 && !p30_read_updt1;
assign p30_rdupdt_by_va1  = !p30_read_updt0 &&  p30_read_updt1;
assign p30_rdupdt_by_va01 = (p30_read_updt0 &&  p30_read_updt1)
                         && (p30_read_updt_val0 ^~ p30_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p30 <= 1'b0;
  else if(p30_write_updt)
    p30 <= p30_write_updt_val;
  else if(p30_rdupdt_by_va0 || p30_rdupdt_by_va01)
    p30 <= p30_read_updt_val0;
  else if(p30_rdupdt_by_va1)
    p30 <= p30_read_updt_val1;
end

//Path 31
assign p31_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b001);
assign p31_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b001);
assign p31_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b001);

assign p31_write_updt_val = (refill_num_index[3:0] == 4'b0010);
assign p31_read_updt_val0 = (hit_num_index0[3:0] == 4'b0010);
assign p31_read_updt_val1 = (hit_num_index1[3:0] == 4'b0010);

assign p31_rdupdt_by_va0  =  p31_read_updt0 && !p31_read_updt1;
assign p31_rdupdt_by_va1  = !p31_read_updt0 &&  p31_read_updt1;
assign p31_rdupdt_by_va01 = (p31_read_updt0 &&  p31_read_updt1)
                         && (p31_read_updt_val0 ^~ p31_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p31 <= 1'b0; 
  else if(p31_write_updt)
    p31 <= p31_write_updt_val;
  else if(p31_rdupdt_by_va0 || p31_rdupdt_by_va01)
    p31 <= p31_read_updt_val0;
  else if(p31_rdupdt_by_va1)
    p31 <= p31_read_updt_val1;
end
  
//Path 32
assign p32_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b010);
assign p32_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b010);
assign p32_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b010);

assign p32_write_updt_val = (refill_num_index[3:0] == 4'b0100);
assign p32_read_updt_val0 = (hit_num_index0[3:0] == 4'b0100);
assign p32_read_updt_val1 = (hit_num_index1[3:0] == 4'b0100);

assign p32_rdupdt_by_va0  =  p32_read_updt0 && !p32_read_updt1;
assign p32_rdupdt_by_va1  = !p32_read_updt0 &&  p32_read_updt1;
assign p32_rdupdt_by_va01 = (p32_read_updt0 &&  p32_read_updt1)
                         && (p32_read_updt_val0 ^~ p32_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p32 <= 1'b0; 
  else if(p32_write_updt)
    p32 <= p32_write_updt_val;
  else if(p32_rdupdt_by_va0 || p32_rdupdt_by_va01)
    p32 <= p32_read_updt_val0;
  else if(p32_rdupdt_by_va1)
    p32 <= p32_read_updt_val1;
end 
  
//Path 33
assign p33_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b011);
assign p33_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b011);
assign p33_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b011);

assign p33_write_updt_val = (refill_num_index[3:0] == 4'b0110);
assign p33_read_updt_val0 = (hit_num_index0[3:0] == 4'b0110);
assign p33_read_updt_val1 = (hit_num_index1[3:0] == 4'b0110);

assign p33_rdupdt_by_va0  =  p33_read_updt0 && !p33_read_updt1;
assign p33_rdupdt_by_va1  = !p33_read_updt0 &&  p33_read_updt1;
assign p33_rdupdt_by_va01 = (p33_read_updt0 &&  p33_read_updt1)
                         && (p33_read_updt_val0 ^~ p33_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p33 <= 1'b0; 
  else if(p33_write_updt)
    p33 <= p33_write_updt_val;
  else if(p33_rdupdt_by_va0 || p33_rdupdt_by_va01)
    p33 <= p33_read_updt_val0;
  else if(p33_rdupdt_by_va1)
    p33 <= p33_read_updt_val1;
end 
  
//Path 34
assign p34_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b100);
assign p34_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b100);
assign p34_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b100);

assign p34_write_updt_val = (refill_num_index[3:0] == 4'b1000);
assign p34_read_updt_val0 = (hit_num_index0[3:0] == 4'b1000);
assign p34_read_updt_val1 = (hit_num_index1[3:0] == 4'b1000);

assign p34_rdupdt_by_va0  =  p34_read_updt0 && !p34_read_updt1;
assign p34_rdupdt_by_va1  = !p34_read_updt0 &&  p34_read_updt1;
assign p34_rdupdt_by_va01 = (p34_read_updt0 &&  p34_read_updt1)
                         && (p34_read_updt_val0 ^~ p34_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p34 <= 1'b0; 
  else if(p34_write_updt)
    p34 <= p34_write_updt_val;
  else if(p34_rdupdt_by_va0 || p34_rdupdt_by_va01)
    p34 <= p34_read_updt_val0;
  else if(p34_rdupdt_by_va1)
    p34 <= p34_read_updt_val1;
end 
  
//Path 35
assign p35_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b101);
assign p35_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b101);
assign p35_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b101);


assign p35_write_updt_val = (refill_num_index[3:0] == 4'b1010);
assign p35_read_updt_val0 = (hit_num_index0[3:0] == 4'b1010);
assign p35_read_updt_val1 = (hit_num_index1[3:0] == 4'b1010);

assign p35_rdupdt_by_va0  =  p35_read_updt0 && !p35_read_updt1;
assign p35_rdupdt_by_va1  = !p35_read_updt0 &&  p35_read_updt1;
assign p35_rdupdt_by_va01 = (p35_read_updt0 &&  p35_read_updt1)
                         && (p35_read_updt_val0 ^~ p35_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p35 <= 1'b0; 
  else if(p35_write_updt)
    p35 <= p35_write_updt_val;
  else if(p35_rdupdt_by_va0 || p35_rdupdt_by_va01)
    p35 <= p35_read_updt_val0;
  else if(p35_rdupdt_by_va1)
    p35 <= p35_rdupdt_by_va1;
end 
  
//Path 36
assign p36_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b110);
assign p36_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b110);
assign p36_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b110);

assign p36_write_updt_val = (refill_num_index[3:0] == 4'b1100);
assign p36_read_updt_val0 = (hit_num_index0[3:0] == 4'b1100);
assign p36_read_updt_val1 = (hit_num_index1[3:0] == 4'b1100);

assign p36_rdupdt_by_va0  =  p36_read_updt0 && !p36_read_updt1;
assign p36_rdupdt_by_va1  = !p36_read_updt0 &&  p36_read_updt1;
assign p36_rdupdt_by_va01 = (p36_read_updt0 &&  p36_read_updt1)
                         && (p36_read_updt_val0 ^~ p36_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p36 <= 1'b0; 
  else if(p36_write_updt)
    p36 <= p36_write_updt_val;
  else if(p36_rdupdt_by_va0 || p36_rdupdt_by_va01)
    p36 <= p36_read_updt_val0;
  else if(p36_rdupdt_by_va1)
    p36 <= p36_read_updt_val1;
end 
  
//Path 37
assign p37_write_updt     = plru_write_updt
                         && (refill_num_index[3:1] == 3'b111);
assign p37_read_updt0     = plru_read_updt0
                         && (hit_num_index0[3:1] == 3'b111);
assign p37_read_updt1     = plru_read_updt1
                         && (hit_num_index1[3:1] == 3'b111);

assign p37_write_updt_val = (refill_num_index[3:0] == 4'b1110);
assign p37_read_updt_val0 = (hit_num_index0[3:0] == 4'b1110);
assign p37_read_updt_val1 = (hit_num_index1[3:0] == 4'b1110);

assign p37_rdupdt_by_va0  =  p37_read_updt0 && !p37_read_updt1;
assign p37_rdupdt_by_va1  = !p37_read_updt0 &&  p37_read_updt1;
assign p37_rdupdt_by_va01 = (p37_read_updt0 &&  p37_read_updt1)
                         && (p37_read_updt_val0 ^~ p37_read_updt_val1);

always @(posedge lru_clk or negedge cpurst_b)
begin
  if(!cpurst_b)
    p37 <= 1'b0; 
  else if(p37_write_updt)
    p37 <= p37_write_updt_val;
  else if(p37_rdupdt_by_va0 || p37_rdupdt_by_va01)
    p37 <= p37_read_updt_val0;
  else if(p37_rdupdt_by_va1)
    p37 <= p37_read_updt_val1;
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


// &ModuleEnd; @671
endmodule



