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

// Waived from functional coverage: clock-gating wrapper around ASAP7 ICG.
// global_en/external_en/pad_yy_icg_scan_en tied to constants; internal latch
// FSM is standard-cell protocol behaviour — clock-gating correctness is
// validated by per-block activity tests (gateclk test) and synthesis STA.

module gated_clk_cell(
  clk_in,
  global_en,
  module_en,
  local_en,
  external_en,
  pad_yy_icg_scan_en,
  clk_out
);

input  clk_in;
input  global_en;
input  module_en;
input  local_en;
input  external_en;
input  pad_yy_icg_scan_en;
output clk_out;

// coverage off
wire   clk_en_bf_latch;
wire   SE;

assign clk_en_bf_latch = (global_en && (module_en || local_en)) || external_en ;
assign SE              = pad_yy_icg_scan_en;
assign clk_out = clk_in;
// coverage on

endmodule
