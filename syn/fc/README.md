# MMU Synthesis with Synopsys Fusion Compiler (fc_shell) + ASAP7

Synthesizes **`ct_mmu_top`** (the T-Head MMU) against the **ASAP7 7nm PDK**
(`asap7sc7p5t_28`, RVT cells, typical corner 0.7 V / 25 C, NLDM).

The classic `fc_shell` (Fusion Compiler) binary is not installed on this host;
the flow therefore uses **`fc_shell`** (Fusion Compiler V-2023.12-SP5), which is
a strict superset of Fusion Compiler and understands the same Tcl flow,
`target_library` / `link_library` mechanism, `compile_ultra`, `report_qor`, etc.

## Directory layout
```
syn/fc/
├── .synopsys_fc.setup        # search_path, target/link library (ASAP7 RVT TT)
├── run_fc.sh                 # launcher: smoke | quick | full
├── Makefile                  # make smoke | quick | full | clean
├── scripts/
│   ├── compile.tcl           # main synthesis script (analyze→elaborate→compile)
│   ├── smoke.tcl             # RTL parse/elaborate/link-only sanity check
│   ├── constraints.sdc       # clock, I/O delay, false paths
│   └── sram_blackboxes.v     # SRAM hard-macro stubs (ct_f_spsram_*, mmu_fpga_ram)
├── logs/                     # *.log (compile / smoke runs)
├── reports/                  # timing.max, area, qor, power, ...
└── results/                  # ct_mmu_top_netlist.v, .ddc, .sdc
```

## Quick start
```bash
cd /x2025/GPrj1/IC1/mmu_verification/syn/fc

# 1. fast sanity check (RTL reads, links): ~1–2 min
./run_fc.sh smoke

# 2. medium-effort synthesis: ~10–15 min
./run_fc.sh quick

# 3. full compile_ultra: ~30+ min
./run_fc.sh full
# or
make full
```

## Knobs
| Variable | Default | How to change |
|---|---|---|
| Clock period | 1.4 ns (714 MHz) | `make full CLK_NS=1.0` (1 GHz) |
| SRAM handling | blackbox (hard IP, fast) | edit `set ::USE_SRAM_BLACKBOX 0` in `compile.tcl` for behavioral→FF |
| Effort | `ultra` (compile_ultra) | edit `set ::COMPILE_EFFORT "medium"` |

## ASAP7 library selection
Target/link library = 5 NLDM liberty files, RVT, TT, 0.7 V:
`SIMPLE / INVBUF / SEQ / AO / OA` from
`/home/IC1/tools/asap7/asap7sc7p5t_28/LIB/NLDM/`.

## SRAMs
`ct_f_spsram_256x196`, `ct_f_spsram_256x84`, and the parameterised
`mmu_fpga_ram` are treated as **hard black-box macros** (`sram_blackboxes.v`)
so DC does not inflate the gate count with ~70 k memory flip-flops.  For a
behavioural run (memories → FFs, much slower), set `USE_SRAM_BLACKBOX 0`.

## Macros that must be defined
* `MMU_EXPT_TRACE_ONCE_EN` – guards debug trace blocks in `mmu_l1dtlb.sv`.
* `PA_WIDTH=40` – used by `ct_mmu_sysmap.v` (`ADDR_WIDTH = `PA_WIDTH-12`).
* `SYSMAP_*` – supplied by reading `mmu/rtl/sysmap.h` first.

## Outputs of interest
* `results/ct_mmu_top_netlist.v` – mapped gate-level netlist (ASAP7 cells)
* `results/ct_mmu_top.ddc` – binary DB for re-loading / Formality
* `reports/timing.max` / `timing.summary` – worst critical paths
* `reports/area` – hierarchical area breakdown
* `reports/qor` – quality-of-results summary
