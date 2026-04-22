#!/usr/bin/env python3
"""Generate MMU UVM Environment block diagram (.drawio)."""

import sys, os

sys.path.insert(0, r"D:\work_tool\CLI-Anything\drawio\agent-harness")

from cli_anything.drawio.core.session import Session
from cli_anything.drawio.core import project as proj_mod
from cli_anything.drawio.core import shapes as shapes_mod
from cli_anything.drawio.core import connectors as conn_mod
from cli_anything.drawio.core import pages as pages_mod

OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "MMU_UVM_Env_Diagram.drawio")

# ---------- styles ----------
def box(fill, font=11, bold=True, stroke="#666666"):
    fs = "1" if bold else "0"
    return (f"rounded=1;whiteSpace=wrap;html=1;fillColor={fill};"
            f"strokeColor={stroke};fontSize={font};fontStyle={fs};")

def group_box(stroke="#444444", fill="none"):
    return (f"rounded=0;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            f"strokeWidth=2;fontSize=12;fontStyle=1;verticalAlign=top;dashed=0;")

def dashed_group(stroke, fill="none"):
    return (f"rounded=0;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
            f"strokeWidth=2;fontSize=12;fontStyle=1;verticalAlign=top;dashed=1;")

def edge_s(color="#333333", dashed=False, width=1, arrow="classic"):
    d = "1" if dashed else "0"
    return (f"edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;"
            f"html=1;strokeColor={color};strokeWidth={width};dashed={d};fontSize=9;"
            f"endArrow={arrow};")

def edge_curve(color="#2e7d32", width=1):
    return (f"curved=1;rounded=1;html=1;strokeColor={color};strokeWidth={width};"
            f"dashed=1;fontSize=9;endArrow=classic;")

# ---------- session ----------
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
# Layout regions:
#   tb_top container          : x= 20  .. 1640
#   DUT center column         : x=720..980   (mid)
#   Agents left (Active)      : x= 60..360
#   Agents right (Resp/Cfg)   : x=1280..1600
#   Env (sb/refmodel)         : bottom band y=900..1180
#   Test layer                : top y=20..90
# ============================================================

# ----- Test layer (top) -----
add("test_layer", 20, 20, 1620, 70,
    "<b>Test Layer</b>  (test_base / basic / l1itlb / l1dtlb / l2tlb / ptw / tlbop / pmp / sysmap / cp0 / flush / cross / perf / err)",
    box("#e0d0ff", font=12))

# ----- tb_top container -----
add("tb_top", 20, 110, 1620, 1180,
    "<b>tb_top.sv</b>  (DUT instance + interfaces + uvm_config_db)",
    group_box("#222222"))

# ----- mmu_env container (inside tb_top) -----
add("mmu_env", 40, 150, 1580, 1130,
    "<b>mmu_env</b>",
    dashed_group("#1565c0"))

# ----- DUT (ct_mmu_top.v) -----
add("dut", 720, 540, 280, 260,
    "<b>DUT</b><br/>ct_mmu_top.v<br/><br/>"
    "L1 ITLB / L1 DTLB<br/>L2 TLB (4-way SRRIP)<br/>"
    "PTW + TWU<br/>SysMap / PMP arb<br/>CP0 regs",
    box("#f8cecc", font=12))

# ============== ACTIVE AGENTS (LEFT) ==============
left_x = 70
left_w = 260

# ifu_agent
add("ifu_agent", left_x, 200, left_w, 110,
    "<b>ifu_agent</b>  (Active)<br/>"
    "sequencer / driver / monitor<br/>"
    "ifu_mmu_* / mmu_ifu_*<br/>cov: ifu_covergroups",
    box("#dae8fc"))

# lsu_agent
add("lsu_agent", left_x, 330, left_w, 140,
    "<b>lsu_agent</b>  (Active, 5 sub-drv)<br/>"
    "Pipe0/1/2 + STAMO + TLB-INV<br/>"
    "lsu_mmu_*0/1/2, stamo_*, tlb_*inv*<br/>"
    "cov: lsu_covergroups",
    box("#dae8fc"))

# cp0_agent
add("cp0_agent", left_x, 490, left_w, 110,
    "<b>cp0_agent</b>  (Active)<br/>"
    "CSR write / priv_mode<br/>"
    "cp0_mmu_* / mmu_cp0_*<br/>cov: cp0_covergroups",
    box("#dae8fc"))

# sysmap_cfg_agent
add("sysmap_cfg_agent", left_x, 620, left_w, 100,
    "<b>sysmap_cfg_agent</b>  (Active)<br/>"
    "white-box force/release<br/>SysMap region init",
    box("#dae8fc"))

# misc_agent
add("misc_agent", left_x, 740, left_w, 130,
    "<b>misc_agent</b>  (Passive + Inject)<br/>"
    "rtu_flush / expt / hpcp<br/>"
    "biu_smp_disable / scan_en / had_debug<br/>"
    "cov: misc_covergroups",
    box("#d5e8d4"))

# ============== RESPONDER / CFG AGENTS (RIGHT) ==============
right_x = 1310
right_w = 280

# ptw_mem_agent
add("ptw_mem_agent", right_x, 200, right_w, 150,
    "<b>ptw_mem_agent</b>  (Responder)<br/>"
    "PTE response + latency<br/>bus_error injection<br/>"
    "page_table_builder<br/>(reuses dv_utils memory_shadow)<br/>"
    "cov: ptw_mem_covergroups",
    box("#ffe6cc"))

# pmp_agent
add("pmp_agent", right_x, 370, right_w, 130,
    "<b>pmp_agent</b>  (Responder, 8 ports)<br/>"
    "pmp_mmu_flg{0..7}<br/>mmu_pmp_pa{0..7}<br/>"
    "mmu_pmp_fetch{3,5,6,7}<br/>cov: pmp_covergroups",
    box("#ffe6cc"))

# virtual sequencer (right column, mid)
add("vseq", right_x, 520, right_w, 120,
    "<b>mmu_virtual_sequencer</b><br/>"
    "p_seq handles to all 7 agents<br/>"
    "mmu_vseq_lib (14 vseq classes)",
    box("#e1d5e7"))

# top_cfg
add("top_cfg", right_x, 660, right_w, 90,
    "<b>mmu_top_cfg</b><br/>agent active/passive flags<br/>SVA enable / coverage knobs",
    box("#e1d5e7"))

# ============== ENV BOTTOM BAND (refmodel + scoreboards) ==============
bot_y = 920
add("page_table_mem", 70, bot_y, 240, 110,
    "<b>mmu_page_table_mem</b><br/>shared shadow PT<br/>(memory_shadow base)",
    box("#ffe6cc"))

add("ref_model", 340, bot_y, 240, 110,
    "<b>mmu_ref_model</b><br/>translate(VA,priv,csr) API<br/>CSR mirror / Sv39 walker",
    box("#fff2cc"))

add("trans_sb", 610, bot_y, 240, 110,
    "<b>mmu_translation_sb</b><br/>VA→PA + exception<br/>compare DUT vs ref",
    box("#f5b7b1"))

add("inv_sb", 880, bot_y, 240, 110,
    "<b>mmu_invalidate_sb</b><br/>SFENCE post-state<br/>TLB residency check",
    box("#f5b7b1"))

add("credit_sb", 1150, bot_y, 240, 110,
    "<b>mmu_credit_sb</b><br/>L1↔L2 credit / ReqQ / MB<br/>capacity conservation",
    box("#f5b7b1"))

add("perf_mon", 1420, bot_y, 200, 110,
    "<b>mmu_perf_mon</b><br/>miss-rate / walk latency<br/>statistics",
    box("#d0e0f0"))

# ----- Coverage container (env-side notes) -----
add("cov_note", 70, 1060, 1550, 50,
    "<b>Functional Coverage</b>: each agent owns *_covergroups.svh  +  refmodel/SB-driven cross coverage  →  URG merge (cov_hier.cfg)",
    box("#e6e6e6", font=11))

# ----- SVA group (top inside DUT region) -----
add("sva", 720, 480, 280, 50,
    "<b>SVA (top/)</b>: mmu_sva / arb_sva / l2tlb_rrpv_sva / plru_sva / credit_sva",
    box("#ffcccc", font=10))

# ============== INTERFACES (between agent and DUT) ==============
# Tiny interface markers around DUT
add("if_ifu",   600, 220, 110, 40, "<b>ifu_if</b>",     box("#fff2cc", font=10))
add("if_lsu",   600, 360, 110, 40, "<b>lsu_if</b>",     box("#fff2cc", font=10))
add("if_cp0",   600, 510, 110, 40, "<b>cp0_if</b>",     box("#fff2cc", font=10))
add("if_smap",  600, 640, 110, 40, "<b>sysmap_cfg_if</b>", box("#fff2cc", font=10))
add("if_misc",  600, 770, 110, 40, "<b>misc_if</b>",    box("#fff2cc", font=10))

add("if_ptw",  1010, 220, 110, 40, "<b>ptw_mem_if</b>", box("#fff2cc", font=10))
add("if_pmp",  1010, 390, 110, 40, "<b>pmp_if</b>",     box("#fff2cc", font=10))

# ============== CONNECTIONS ==============
# Test -> vseq
conn("test_layer", "vseq", "start vseq", edge_s("#6a1b9a", width=2))
# vseq -> agents (sequencers)
for a in ["ifu_agent","lsu_agent","cp0_agent","sysmap_cfg_agent","misc_agent",
          "ptw_mem_agent","pmp_agent"]:
    conn("vseq", a, "", edge_s("#7e57c2", dashed=True))

# Agents <-> interfaces <-> DUT
agent_if_dut = [
    ("ifu_agent","if_ifu"),
    ("lsu_agent","if_lsu"),
    ("cp0_agent","if_cp0"),
    ("sysmap_cfg_agent","if_smap"),
    ("misc_agent","if_misc"),
]
for a, i in agent_if_dut:
    conn(a, i, "", edge_s("#1565c0", width=2))
    conn(i, "dut", "", edge_s("#1565c0", width=2))

# Right-side responders
conn("dut", "if_ptw", "", edge_s("#ef6c00", width=2))
conn("if_ptw", "ptw_mem_agent", "PTE req/rsp", edge_s("#ef6c00", width=2))
conn("dut", "if_pmp", "", edge_s("#ef6c00", width=2))
conn("if_pmp", "pmp_agent", "addr/flag", edge_s("#ef6c00", width=2))

# Monitors -> scoreboards (analysis ports, dashed)
mon_to_sb = [
    ("ifu_agent","trans_sb"),
    ("lsu_agent","trans_sb"),
    ("cp0_agent","ref_model"),
    ("ptw_mem_agent","trans_sb"),
    ("ptw_mem_agent","credit_sb"),
    ("lsu_agent","inv_sb"),
    ("misc_agent","perf_mon"),
    ("pmp_agent","trans_sb"),
]
for s, t in mon_to_sb:
    conn(s, t, "ap", edge_s("#388e3c", dashed=True))

# refmodel feeds scoreboards
conn("ref_model", "trans_sb", "expected", edge_s("#f57c00", width=2))
conn("page_table_mem", "ref_model", "PT data", edge_s("#f57c00"))
conn("ptw_mem_agent", "page_table_mem", "shared", edge_curve("#2e7d32"))

# top_cfg feeds env
conn("top_cfg", "vseq", "", edge_s("#9e9e9e", dashed=True))
conn("top_cfg", "trans_sb", "", edge_s("#9e9e9e", dashed=True))

# SVA bound to DUT
conn("sva", "dut", "bind", edge_s("#c62828", dashed=True))

# Save
proj_mod.save_project(session, OUTPUT)
print(f"Saved: {OUTPUT}")
