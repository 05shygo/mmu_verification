#!/usr/bin/env python3
"""Generate MMU UVM Environment block diagram (.drawio) - v2.
Structural improvement: Reference Model and Scoreboards are separate standalone
containers, each directly connected to DUT, mirroring dcache_uvm reference style.
"""

import sys, os

sys.path.insert(0, r"D:\work_tool\CLI-Anything\drawio\agent-harness")

from cli_anything.drawio.core.session import Session
from cli_anything.drawio.core import project as proj_mod
from cli_anything.drawio.core import shapes as shapes_mod
from cli_anything.drawio.core import connectors as conn_mod
from cli_anything.drawio.core import pages as pages_mod

OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "MMU_UVM_Env_Diagram.drawio")

# ──────────────────────────── styles ────────────────────────────
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

# ──────────────────────────── session ───────────────────────────
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
# Canvas layout (px):
#
#  y=  20- 90   Test Layer
#  y= 110-1480  tb_top
#  y= 150-1460  mmu_env (dashed blue)
#
#  ── Agents / DUT zone ──────────────────── y=200-840
#    Left  Active Agents   x=65-335
#    Interfaces            x=600-720  (left side)
#    DUT                   x=720-1010
#    Interfaces            x=1010-1130 (right side)
#    Right Responders+Cfg  x=1300-1600
#
#  ── Reference Model zone ──────────────── y=870-1040  ← NEW standalone
#    refmodel_group container  x=300-1100
#      page_table_mem          x=330-570
#      mmu_ref_model           x=650-1030  (wider, more prominent)
#
#  ── Scoreboard zone ───────────────────── y=1080-1210 ← NEW standalone
#    sb_group container        x=60-1620
#      trans_sb   inv_sb   credit_sb   perf_mon
#
#  ── Coverage note ─────────────────────── y=1240-1290
# ============================================================

# ── Test layer ──────────────────────────────────────────────────
add("test_layer", 20, 20, 1620, 70,
    "<b>Test Layer</b>  "
    "(test_base / basic / l1itlb / l1dtlb / l2tlb / ptw / tlbop / pmp / sysmap / cp0 / flush / cross / perf / err)",
    box("#e0d0ff", font=12))

# ── tb_top container ────────────────────────────────────────────
add("tb_top", 20, 110, 1620, 1370,
    "<b>tb_top.sv</b>  (DUT instance + interfaces + uvm_config_db)",
    group_box("#222222"))

# ── mmu_env (dashed blue) ───────────────────────────────────────
add("mmu_env", 40, 150, 1580, 1320,
    "<b>mmu_env</b>",
    dashed_group("#1565c0"))

# ── Clock / Reset drivers (bottom-right of tb_top, outside env) ─
add("clk_drv", 1440, 1340, 170, 50,
    "<b>clock_driver_c</b><br/>forever_cpuclk",
    box("#e8f5e9", font=10))
add("rst_drv", 1260, 1340, 170, 50,
    "<b>reset_driver_c</b><br/>cpurst_b",
    box("#e8f5e9", font=10))

# ────────────────────────────────────────────────────────────────
# ZONE 1 : Agents + DUT  (y 200-840)
# ────────────────────────────────────────────────────────────────

# ── DUT ─────────────────────────────────────────────────────────
add("dut", 720, 470, 290, 300,
    "<b>DUT</b><br/>ct_mmu_top.v<br/><br/>"
    "L1 ITLB / L1 DTLB<br/>L2 TLB (SRRIP)<br/>"
    "PTW + TWU<br/>SysMap / PMP arb<br/>CP0 regs",
    box("#f8cecc", font=12))

# SVA banner above DUT
add("sva", 720, 410, 290, 50,
    "<b>SVA</b>: mmu_sva / arb_sva / l2tlb_rrpv_sva / plru_sva / credit_sva",
    box("#ffcccc", font=10))

# ── Left Active Agents ──────────────────────────────────────────
LX, LW = 65, 265

add("ifu_agent", LX, 210, LW, 105,
    "<b>ifu_agent</b>  (Active)<br/>"
    "sequencer / driver / monitor<br/>"
    "ifu_mmu_* / mmu_ifu_*<br/>cov: ifu_covergroups",
    box("#dae8fc"))

add("lsu_agent", LX, 330, LW, 140,
    "<b>lsu_agent</b>  (Active, 5 sub-drv)<br/>"
    "Pipe0/1/2 + STAMO + TLB-INV<br/>"
    "lsu_mmu_*0/1/2, stamo_*, tlb_*inv*<br/>"
    "cov: lsu_covergroups",
    box("#dae8fc"))

add("cp0_agent", LX, 485, LW, 105,
    "<b>cp0_agent</b>  (Active)<br/>"
    "CSR write / priv_mode<br/>"
    "cp0_mmu_* / mmu_cp0_*<br/>cov: cp0_covergroups",
    box("#dae8fc"))

add("sysmap_cfg_agent", LX, 605, LW, 90,
    "<b>sysmap_cfg_agent</b>  (Active)<br/>"
    "white-box force/release<br/>SysMap region init",
    box("#dae8fc"))

add("misc_agent", LX, 710, LW, 120,
    "<b>misc_agent</b>  (Passive + Inject)<br/>"
    "rtu_flush / expt / hpcp<br/>"
    "biu_smp_disable / scan_en / had_debug<br/>"
    "cov: misc_covergroups",
    box("#d5e8d4"))

# ── Right Responder Agents ───────────────────────────────────────
RX, RW = 1300, 285

add("ptw_mem_agent", RX, 210, RW, 150,
    "<b>ptw_mem_agent</b>  (Responder)<br/>"
    "PTE response + latency<br/>bus_error injection<br/>"
    "page_table_builder (memory_shadow)<br/>"
    "cov: ptw_mem_covergroups",
    box("#ffe6cc"))

add("pmp_agent", RX, 375, RW, 120,
    "<b>pmp_agent</b>  (Responder, 8 ports)<br/>"
    "pmp_mmu_flg{0..7}<br/>mmu_pmp_pa{0..7}<br/>"
    "mmu_pmp_fetch{3,5,6,7}<br/>cov: pmp_covergroups",
    box("#ffe6cc"))

add("vseq", RX, 510, RW, 110,
    "<b>mmu_virtual_sequencer</b><br/>"
    "p_seq handles to all 7 agents<br/>"
    "mmu_vseq_lib  (14 vseq classes)",
    box("#e1d5e7"))

add("top_cfg", RX, 635, RW, 80,
    "<b>mmu_top_cfg</b><br/>agent active/passive / SVA enable / cov knobs",
    box("#e1d5e7"))

add("watchdog", RX, 730, RW, 60,
    "<b>watchdog_c</b>  (dv_utils)<br/>simulation timeout guard",
    box("#f5f5f5", font=10))

# ── Interfaces ──────────────────────────────────────────────────
add("if_ifu",  603, 232, 108, 36, "<b>ifu_if</b>",        box("#fff2cc", font=10))
add("if_lsu",  603, 357, 108, 36, "<b>lsu_if</b>",        box("#fff2cc", font=10))
add("if_cp0",  603, 501, 108, 36, "<b>cp0_if</b>",        box("#fff2cc", font=10))
add("if_smap", 603, 621, 108, 36, "<b>sysmap_cfg_if</b>", box("#fff2cc", font=10))
add("if_misc", 603, 726, 108, 36, "<b>misc_if</b>",       box("#fff2cc", font=10))

add("if_ptw", 1020, 232, 108, 36, "<b>ptw_mem_if</b>",    box("#fff2cc", font=10))
add("if_pmp", 1020, 392, 108, 36, "<b>pmp_if</b>",        box("#fff2cc", font=10))

# ────────────────────────────────────────────────────────────────
# ZONE 2 : Reference Model  (y 870-1040)  ← STANDALONE CONTAINER
# ────────────────────────────────────────────────────────────────
add("refmodel_group", 60, 865, 1170, 175,
    "<b>Reference Model</b>",
    dashed_group("#e65100", fill="#fffde7", font=12))

add("page_table_mem", 90, 900, 270, 115,
    "<b>mmu_page_table_mem</b><br/>"
    "shared shadow page table<br/>"
    "(dv_utils memory_shadow base)",
    box("#ffe6cc"))

add("ref_model", 400, 900, 400, 115,
    "<b>mmu_ref_model</b><br/>"
    "translate(VA, priv, CSR_ctx) API<br/>"
    "Sv39 walker  |  CSR mirror<br/>"
    "PMP flag apply  →  expected PA / exc",
    box("#fff9c4", font=11, stroke="#f9a825"))

# ────────────────────────────────────────────────────────────────
# ZONE 3 : Scoreboard band  (y 1080-1215)  ← STANDALONE CONTAINER
# ────────────────────────────────────────────────────────────────
add("sb_group", 60, 1075, 1560, 155,
    "<b>Scoreboards</b>",
    dashed_group("#b71c1c", fill="#fff5f5", font=12))

add("trans_sb", 90, 1110, 360, 100,
    "<b>mmu_translation_sb</b><br/>"
    "VA→PA + exception check<br/>"
    "DUT actual  vs  ref expected",
    box("#f5b7b1"))

add("inv_sb", 480, 1110, 300, 100,
    "<b>mmu_invalidate_sb</b><br/>"
    "SFENCE post-state<br/>"
    "TLB residency check",
    box("#f5b7b1"))

add("credit_sb", 810, 1110, 300, 100,
    "<b>mmu_credit_sb</b><br/>"
    "L1↔L2 credit / ReqQ / MB<br/>"
    "capacity conservation",
    box("#f5b7b1"))

add("perf_mon", 1140, 1110, 450, 100,
    "<b>mmu_perf_mon</b><br/>"
    "miss-rate / walk latency statistics<br/>"
    "(dv_utils perf_mon base)",
    box("#d0e0f0"))

# ── Coverage note ────────────────────────────────────────────────
add("cov_note", 60, 1255, 1560, 45,
    "<b>Functional Coverage</b>: "
    "each agent owns *_covergroups.svh  +  refmodel/SB cross cov  "
    "→  URG merge (cov_hier.cfg)",
    box("#e6e6e6", font=11))

# ════════════════════════════════════════════════════════════════
# CONNECTIONS
# ════════════════════════════════════════════════════════════════

# ── Test → vseq ─────────────────────────────────────────────────
conn("test_layer", "vseq", "start vseq", edge_s("#6a1b9a", width=2))

# ── vseq → agents (purple dashed = sequence dispatch) ───────────
for a in ["ifu_agent","lsu_agent","cp0_agent","sysmap_cfg_agent","misc_agent",
          "ptw_mem_agent","pmp_agent"]:
    conn("vseq", a, "", edge_s("#7e57c2", dashed=True))

# ── Agents ↔ interfaces ↔ DUT (blue = RTL signal path) ──────────
for a, i in [("ifu_agent","if_ifu"), ("lsu_agent","if_lsu"),
             ("cp0_agent","if_cp0"), ("sysmap_cfg_agent","if_smap"),
             ("misc_agent","if_misc")]:
    conn(a,   i,     "", edge_s("#1565c0", width=2))
    conn(i,   "dut", "", edge_s("#1565c0", width=2))

# ── DUT ↔ right-side responders (orange = PTW / PMP path) ───────
conn("dut", "if_ptw", "", edge_s("#ef6c00", width=2))
conn("if_ptw", "ptw_mem_agent", "PTE req/rsp", edge_s("#ef6c00", width=2))
conn("dut", "if_pmp", "", edge_s("#ef6c00", width=2))
conn("if_pmp", "pmp_agent", "PA/flag", edge_s("#ef6c00", width=2))

# ── SVA bind to DUT ─────────────────────────────────────────────
conn("sva", "dut", "bind", edge_s("#c62828", dashed=True))

# ── DUT → Reference Model  (direct observed path, deep orange) ──
conn("dut", "ref_model",
     "VA req observed\nby monitors",
     edge_s("#bf360c", width=2, dashed=True))

# ── page_table_mem ↔ ref_model ──────────────────────────────────
conn("page_table_mem", "ref_model", "PT data", edge_s("#e65100", width=2))

# ── ptw_mem_agent writes page_table_mem ─────────────────────────
conn("ptw_mem_agent", "page_table_mem", "page_table_builder",
     edge_curve("#2e7d32", width=1))

# ── Monitors → Reference Model  (green dashed = analysis port) ──
for src in ["ifu_agent", "lsu_agent", "cp0_agent"]:
    conn(src, "ref_model", "ap (VA/CSR)", edge_s("#388e3c", dashed=True))

# ── Monitors → Scoreboards  (green dashed = analysis port) ──────
mon_to_sb = [
    ("ifu_agent",      "trans_sb",  "ap_rsp"),
    ("lsu_agent",      "trans_sb",  "ap_pipe0/1"),
    ("lsu_agent",      "inv_sb",    "ap_inv"),
    ("ptw_mem_agent",  "trans_sb",  "ap_rsp"),
    ("ptw_mem_agent",  "credit_sb", "ap_req"),
    ("pmp_agent",      "trans_sb",  "ap"),
    ("misc_agent",     "perf_mon",  "ap_hpcp"),
]
for s, t, lbl in mon_to_sb:
    conn(s, t, lbl, edge_s("#388e3c", dashed=True))

# ── Reference Model → Scoreboards (orange = expected results) ───
conn("ref_model", "trans_sb",  "expected PA/exc", edge_s("#f57c00", width=2))
conn("ref_model", "inv_sb",    "inv expected",    edge_s("#f57c00", width=2))
conn("ref_model", "credit_sb", "credit expected", edge_s("#f57c00", width=2))

# ── top_cfg ─────────────────────────────────────────────────────
conn("top_cfg", "vseq", "", edge_s("#9e9e9e", dashed=True))

# ── Clock / Reset → DUT ─────────────────────────────────────────
conn("clk_drv", "dut", "forever_cpuclk", edge_s("#558b2f", width=1))
conn("rst_drv", "dut", "cpurst_b",       edge_s("#558b2f", width=1))

# ── Save ────────────────────────────────────────────────────────
proj_mod.save_project(session, OUTPUT)
print(f"Saved: {OUTPUT}")
