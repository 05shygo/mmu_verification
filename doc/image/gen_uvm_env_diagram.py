#!/usr/bin/env python3
"""Generate MMU UVM Environment block diagram (.drawio) - v3.
Layout mirrors dcache_uvm reference image:
  - Scoreboard TOP full-width band  (inside env, at top)
  - page_table_mem at top-right corner  (Memory Shadow position)
  - watchdog / top_cfg / virtual_sequencer row
  - Agent / DUT / Responder main zone
  - Reference Model BOTTOM full-width band
  - Coverage note
"""

import sys, os

TOOL_CANDIDATES = [
    r"D:\work_tool\CLI-Anything\drawio\agent-harness",
    os.path.expanduser(r"~\CLI-Anything\drawio\agent-harness"),
]
for _p in TOOL_CANDIDATES:
    if os.path.isdir(os.path.join(_p, "cli_anything", "drawio")):
        sys.path.insert(0, _p)
        break

from cli_anything.drawio.core.session import Session
from cli_anything.drawio.core import project as proj_mod
from cli_anything.drawio.core import shapes as shapes_mod
from cli_anything.drawio.core import connectors as conn_mod
from cli_anything.drawio.core import pages as pages_mod

OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "MMU_UVM_Env_Diagram.drawio")

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ styles 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
def box(fill, font=11, bold=True, stroke="#666666"):
    fs = "1" if bold else "0"
    return (f"rounded=1;whiteSpace=wrap;html=1;fillColor={fill};"
            f"strokeColor={stroke};fontSize={font};fontStyle={fs};")

def group_box(stroke="#444444", fill="none", font=12):
    return (f"rounded=0;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            f"strokeWidth=2;fontSize={font};fontStyle=1;verticalAlign=top;dashed=0;")

def dashed_group(stroke, fill="none", font=12):
    return (f"rounded=0;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            f"strokeWidth=2;fontSize={font};fontStyle=1;verticalAlign=top;dashed=1;")

def edge_s(color="#333333", dashed=False, width=1, arrow="classic"):
    d = "1" if dashed else "0"
    return (f"edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;"
            f"html=1;strokeColor={color};strokeWidth={width};dashed={d};fontSize=9;"
            f"endArrow={arrow};")

def edge_curve(color="#2e7d32", width=1):
    return (f"curved=1;rounded=1;html=1;strokeColor={color};strokeWidth={width};"
            f"dashed=1;fontSize=9;endArrow=classic;")

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ session 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
session = Session()
proj_mod.new_project(session, "a3")

ids = {}

def add(name, x, y, w, h, label, style, page=0):
    r = shapes_mod.add_shape(session, style, x, y, w, h, label, page)
    ids[name] = r["id"]
    return r["id"]

def conn(src, tgt, label="", style=None, page=0):
    return conn_mod.add_connector(session, ids[src], ids[tgt],
                                  style or edge_s(), label, page)["id"]

pages_mod.rename_page(session, 0, "MMU_UVM_Env")

# ============================================================
# Canvas layout (px)  鈥?A3 portrait, using 1700 wide canvas
#
#  y=  20-  90   Test Layer              娴呯传 #e0d0ff
#  y= 110-1530   tb_top container        solid black border
#  y= 150-1510   mmu_env (dashed blue)
#
#  鈹€鈹€ ZONE 1: Scoreboard TOP band 鈹€鈹€鈹€鈹€鈹€鈹€鈹€ y=170-295 鈹€鈹€
#    sb_group container   x=60-1470   绾㈣壊铏氱嚎
#      trans_sb  inv_sb  credit_sb  perf_mon
#
#  鈹€鈹€ ZONE 1.5: page_table_mem sticker 鈹€鈹€ x=1490-1660, y=160-295 鈹€鈹€
#    (Memory Shadow equivalent, top-right corner)
#
#  鈹€鈹€ ZONE 2: tool strip 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€  y=310-385 鈹€鈹€
#    watchdog | top_cfg | mmu_virtual_sequencer
#
#  鈹€鈹€ ZONE 3: Agent / DUT / Resp 鈹€鈹€鈹€鈹€鈹€鈹€鈹€  y=400-970 鈹€鈹€
#    Left   x=60-315    ifu lsu cp0 sysmap misc
#    Vif    x=320-415   left-side vif blocks
#    DUT    x=610-890   SVA banner + DUT + Clock+Reset
#    Vif    x=895-995   right-side vif blocks
#    Right  x=1010-1280 ptw_mem + pmp agents
#
#  鈹€鈹€ ZONE 4: RefModel BOTTOM band 鈹€鈹€鈹€鈹€鈹€ y=990-1130 鈹€鈹€
#    refmodel_group  x=60-1470   姗欒壊铏氱嚎
#      page_table_mem_inner | mmu_ref_model
#
#  鈹€鈹€ ZONE 5: coverage note 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€ y=1150-1200 鈹€鈹€
# ============================================================

# 鈹€鈹€ Test layer 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("test_layer", 20, 20, 1680, 70,
    "<b>Test Layer</b>  "
    "(test_base / basic / l1itlb / l1dtlb / l2tlb / ptw / tlbop / pmp / sysmap / cp0 / flush / cross / perf / err)",
    box("#e0d0ff", font=12))

# 鈹€鈹€ tb_top container 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("tb_top", 20, 110, 1680, 1420,
    "<b>tb_top.sv</b>  (DUT instance + interfaces + uvm_config_db)",
    group_box("#222222"))

# 鈹€鈹€ mmu_env (dashed blue) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("mmu_env", 40, 150, 1640, 1360,
    "<b>mmu_env</b>",
    dashed_group("#1565c0"))

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
# ZONE 1 : Scoreboard TOP band   y=170-295
# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("sb_group", 60, 170, 1410, 130,
    "<b>Scoreboards</b>",
    dashed_group("#b71c1c", fill="#fff5f5", font=12))

add("trans_sb", 80, 200, 330, 85,
    "<b>mmu_translation_sb</b><br/>"
    "VA鈫扨A + exception check<br/>"
    "DUT actual  vs  ref expected",
    box("#f5b7b1"))

add("inv_sb", 430, 200, 270, 85,
    "<b>mmu_invalidate_sb</b><br/>"
    "SFENCE post-state<br/>"
    "TLB residency check",
    box("#f5b7b1"))

add("credit_sb", 720, 200, 270, 85,
    "<b>mmu_credit_sb</b><br/>"
    "L1鈫擫2 credit / ReqQ / MB<br/>"
    "capacity conservation",
    box("#f5b7b1"))

add("perf_mon", 1010, 200, 440, 85,
    "<b>mmu_perf_mon</b><br/>"
    "miss-rate / walk latency statistics<br/>"
    "(dv_utils perf_mon base)",
    box("#d0e0f0"))

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
# ZONE 1.5 : page_table_mem sticker  top-right corner
# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("pt_mem_sticker", 1490, 162, 175, 135,
    "<b>mmu_page_table_mem</b><br/>"
    "shared shadow PT<br/>"
    "(Memory Shadow)<br/>"
    "dv_utils memory_shadow",
    box("#ffe6cc", font=10, stroke="#e65100"))

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
# ZONE 2 : tool strip   y=310-385
# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("watchdog", 65, 313, 190, 62,
    "<b>watchdog_c</b>  (dv_utils)<br/>simulation timeout guard",
    box("#f5f5f5", font=10))

add("top_cfg", 270, 313, 280, 62,
    "<b>mmu_top_cfg</b><br/>"
    "agent active/passive / SVA enable / cov knobs",
    box("#e1d5e7"))

add("vseq", 565, 313, 440, 62,
    "<b>mmu_virtual_sequencer</b><br/>"
    "p_seq handles 鈫?all 7 agents  |  mmu_vseq_lib (14 vseq classes)",
    box("#e1d5e7"))

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
# ZONE 3 : Agent / DUT / Responder  y=400-970
# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

# 鈹€鈹€ DUT (center) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("dut", 615, 510, 275, 295,
    "<b>DUT</b><br/>ct_mmu_top.v<br/><br/>"
    "L1 ITLB  16-entry / PLRU / credit_max=8<br/>"
    "L1 DTLB  16-entry / MB_DEPTH=8 / dPLRU<br/>"
    "L2 TLB   8way脳256set脳8bank (SRRIP/RRPV)<br/>"
    "PTW  4脳TWU 6-stage pipeline + MBUF脳9<br/>"
    "TLBOper 7 FSM  |  SysMap 8-region  |  PMP脳8",
    box("#f8cecc", font=10))

# SVA banner above DUT
add("sva", 615, 450, 275, 52,
    "<b>SVA bind (12 files)</b>: mmu_sva / arb_sva / l2tlb_rrpv_sva / plru_sva / credit_sva<br/>"
    "twu_sva / ptw_lsu_protocol_sva / mbuf_invariant_sva<br/>"
    "maee_twu_sva / pmp_twu_sva / sysmap_sva",
    box("#ffcccc", font=9))

# Clock / Reset below DUT
add("clk_drv", 615, 825, 128, 45,
    "<b>clock_driver_c</b><br/>forever_cpuclk",
    box("#e8f5e9", font=10))
add("rst_drv", 762, 825, 128, 45,
    "<b>reset_driver_c</b><br/>cpurst_b",
    box("#e8f5e9", font=10))

# 鈹€鈹€ Left Active Agents 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
LX, LW = 65, 245

add("ifu_agent", LX, 408, LW, 92,
    "<b>ifu_agent</b>  (Active)<br/>"
    "seqr / driver / monitor<br/>"
    "ifu_mmu_* / mmu_ifu_*<br/>"
    "cov: ifu_covergroups",
    box("#dae8fc"))

add("lsu_agent", LX, 515, LW, 130,
    "<b>lsu_agent</b>  (Active, 5 sub-drv)<br/>"
    "Pipe0 / Pipe1 / Pipe2 / STAMO / TLB-INV<br/>"
    "lsu_mmu_*0/1/2, stamo_*, tlb_*inv*<br/>"
    "monitor: ap_pipe0/1 / ap_pipe2 / ap_inv<br/>"
    "cov: lsu_covergroups",
    box("#dae8fc"))

add("cp0_agent", LX, 660, LW, 88,
    "<b>cp0_agent</b>  (Active)<br/>"
    "CSR write / priv_mode / MAEE<br/>"
    "cp0_mmu_* / mmu_cp0_*<br/>"
    "cov: cp0_covergroups",
    box("#dae8fc"))

add("sysmap_cfg_agent", LX, 763, LW, 72,
    "<b>sysmap_cfg_agent</b>  (Active)<br/>"
    "white-box force/release<br/>"
    "SysMap 8-region init",
    box("#dae8fc"))

add("misc_agent", LX, 850, LW, 100,
    "<b>misc_agent</b>  (Passive + Inject)<br/>"
    "rtu_flush / expt / hpcp<br/>"
    "biu_smp_disable / scan_en<br/>"
    "had_debug  |  cov: misc_covergroups",
    box("#d5e8d4"))

# 鈹€鈹€ Left-side vif strip 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("if_ifu",  325, 428, 95, 30, "<b>ifu_if</b>",        box("#fff2cc", font=10))
add("if_lsu",  325, 540, 95, 30, "<b>lsu_if</b>",        box("#fff2cc", font=10))
add("if_cp0",  325, 675, 95, 30, "<b>cp0_if</b>",        box("#fff2cc", font=10))
add("if_smap", 325, 775, 95, 30, "<b>sysmap_cfg_if</b>", box("#fff2cc", font=9))
add("if_misc", 325, 863, 95, 30, "<b>misc_if</b>",       box("#fff2cc", font=10))

# 鈹€鈹€ Right-side vif strip 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("if_ptw", 900, 518, 100, 30, "<b>ptw_mem_if</b>",    box("#fff2cc", font=10))
add("if_pmp", 900, 638, 100, 30, "<b>pmp_if</b>",        box("#fff2cc", font=10))

# 鈹€鈹€ Right Responder Agents 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
RX, RW = 1015, 270

add("ptw_mem_agent", RX, 415, RW, 145,
    "<b>ptw_mem_agent</b>  (Responder)<br/>"
    "PTE response + latency model<br/>"
    "bus_error injection<br/>"
    "page_table_builder (memory_shadow)<br/>"
    "cov: ptw_mem_covergroups",
    box("#ffe6cc"))

add("pmp_agent", RX, 575, RW, 110,
    "<b>pmp_agent</b>  (Responder, 8 ports)<br/>"
    "pmp_mmu_flg{0..7}[3:0]<br/>"
    "mmu_pmp_pa{0..7}  mmu_pmp_fetch{3,5,6,7}<br/>"
    "cov: pmp_covergroups",
    box("#ffe6cc"))

# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
# ZONE 4 : Reference Model BOTTOM band   y=990-1130
# 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("refmodel_group", 60, 990, 1410, 145,
    "<b>Reference Model</b>",
    dashed_group("#e65100", fill="#fffde7", font=12))

add("page_table_mem", 85, 1018, 265, 100,
    "<b>mmu_page_table_mem</b><br/>"
    "shared shadow page table<br/>"
    "(dv_utils memory_shadow)",
    box("#ffe6cc", font=10))

add("ref_model", 385, 1018, 600, 100,
    "<b>mmu_ref_model</b><br/>"
    "translate(VA, priv, CSR_ctx)  鈫? expected PA / exc_type<br/>"
    "Sv39 3-level walker  |  CSR mirror (satp / priv / mxr / sum / maee)<br/>"
    "PMP flag apply  |  SysMap FLG lookup",
    box("#fff9c4", font=11, stroke="#f9a825"))

# 鈹€鈹€ Coverage note 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
add("cov_note", 60, 1155, 1590, 45,
    "<b>Functional Coverage</b>: "
    "each agent owns *_covergroups.svh  +  refmodel/SB cross cov  "
    "鈫? URG merge  (cov_hier.cfg)  |  "
    "SVA: 12 files (basic脳5 + v3.0Final脳4 + v4.0脳3)",
    box("#e6e6e6", font=11))

# 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲
# CONNECTIONS
# 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲

# 鈹€鈹€ Test 鈫?vseq 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("test_layer", "vseq", "start vseq", edge_s("#6a1b9a", width=2))

# 鈹€鈹€ vseq 鈫?agents (purple dashed = sequence dispatch) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
for a in ["ifu_agent", "lsu_agent", "cp0_agent", "sysmap_cfg_agent",
          "misc_agent", "ptw_mem_agent", "pmp_agent"]:
    conn("vseq", a, "", edge_s("#7e57c2", dashed=True))

# 鈹€鈹€ Left agents 鈫?vif 鈫?DUT 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
for ag, vif in [("ifu_agent",       "if_ifu"),
                ("lsu_agent",       "if_lsu"),
                ("cp0_agent",       "if_cp0"),
                ("sysmap_cfg_agent","if_smap"),
                ("misc_agent",      "if_misc")]:
    conn(ag,   vif,   "", edge_s("#1565c0", width=2))
    conn(vif,  "dut", "", edge_s("#1565c0", width=2))

# 鈹€鈹€ DUT 鈫?right-side responders (orange = PTW/PMP path) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("dut",       "if_ptw",       "", edge_s("#ef6c00", width=2))
conn("if_ptw",    "ptw_mem_agent", "PTE req/rsp", edge_s("#ef6c00", width=2))
conn("dut",       "if_pmp",       "", edge_s("#ef6c00", width=2))
conn("if_pmp",    "pmp_agent",    "PA/flag", edge_s("#ef6c00", width=2))

# 鈹€鈹€ SVA bind to DUT 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("sva", "dut", "bind", edge_s("#c62828", dashed=True))

# 鈹€鈹€ DUT 鈫?Reference Model  (monitors observe VA req) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("dut", "ref_model",
     "VA req observed\nby monitors",
     edge_s("#bf360c", width=2, dashed=True))

# 鈹€鈹€ page_table_mem sticker 鈫?page_table_mem inner (shared storage) 鈹€
conn("pt_mem_sticker", "page_table_mem",
     "shared PT\nstorage",
     edge_s("#e65100", dashed=True))

# 鈹€鈹€ page_table_mem inner 鈫?ref_model 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("page_table_mem", "ref_model", "PT data", edge_s("#e65100", width=2))

# 鈹€鈹€ ptw_mem_agent writes page_table_mem sticker (green curve) 鈹€鈹€鈹€
conn("ptw_mem_agent", "pt_mem_sticker", "page_table_builder",
     edge_curve("#2e7d32", width=1))

# 鈹€鈹€ Monitors 鈫?Reference Model  (green dashed = analysis port) 鈹€鈹€
for src in ["ifu_agent", "lsu_agent", "cp0_agent",
            "sysmap_cfg_agent", "pmp_agent"]:
    conn(src, "ref_model", "ap", edge_s("#388e3c", dashed=True))

# 鈹€鈹€ Monitors 鈫?Scoreboards  (green dashed = analysis port) 鈹€鈹€鈹€鈹€鈹€鈹€
mon_to_sb = [
    ("ifu_agent",      "trans_sb",  "ap_rsp"),
    ("lsu_agent",      "trans_sb",  "ap_pipe0/1"),
    ("lsu_agent",      "inv_sb",    "ap_inv"),
    ("lsu_agent",      "credit_sb", "ap_pipe0/1\n(stall)"),
    ("ptw_mem_agent",  "trans_sb",  "ap_rsp"),
    ("ptw_mem_agent",  "credit_sb", "ap_req"),
    ("pmp_agent",      "trans_sb",  "ap"),
    ("misc_agent",     "perf_mon",  "ap_hpcp"),
    ("cp0_agent",      "inv_sb",    "ap\n(TLB-all-inv)"),
]
for s, t, lbl in mon_to_sb:
    conn(s, t, lbl, edge_s("#388e3c", dashed=True))

# 鈹€鈹€ Reference Model 鈫?Scoreboards (orange = expected results) 鈹€鈹€鈹€
conn("ref_model", "trans_sb",  "expected PA/exc",  edge_s("#f57c00", width=2))
conn("ref_model", "inv_sb",    "inv expected",     edge_s("#f57c00", width=2))
conn("ref_model", "credit_sb", "credit expected",  edge_s("#f57c00", width=2))

# 鈹€鈹€ top_cfg 鈫?vseq 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("top_cfg", "vseq", "", edge_s("#9e9e9e", dashed=True))

# 鈹€鈹€ Clock / Reset 鈫?DUT 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
conn("clk_drv", "dut", "forever_cpuclk", edge_s("#558b2f", width=1))
conn("rst_drv", "dut", "cpurst_b",       edge_s("#558b2f", width=1))

# 鈹€鈹€ Save 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
proj_mod.save_project(session, OUTPUT)
print(f"Saved: {OUTPUT}")
