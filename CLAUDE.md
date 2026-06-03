## Project Overview
MMU (Memory Management Unit) UVM 验证工程，基于 VCS + Verdi，复用 hpdcache_verification 的 dv_utils 框架。

## Agent Workflow (from Babel)

| Agent | 用途 | 适用本工程 |
|-------|------|-----------|
| bba-architect | PRD → ARCH → MAS | 新功能设计时 |
| bba-guru-rtl | RTL 生成 | MMU RTL 开发时 |
| bba-guru-verification | 验证：testbench + 覆盖率 | 核心 |
| bba-guru-synthesis | 综合：SDC → yosys → STA | 需要综合时 |
| bba-guru-pd | Physical Design → GDSII | 暂不需要 |

Skills 位于 `.claude/skills/`，包括 lint、CDC、验证计划生成、testbench 生成、覆盖率收集等。

## Directory Structure

```
mmu_verification/
  mmu_verification/        # 主验证工程 (UVM, VCS + Verdi)
    modules/               # dv_utils, mmu_params
    testbench/             # UVM testbench
    simu/                  # 仿真输出
  hpdcache_verification/   # 参考验证框架
  mmu/                     # DUT RTL
  syn/                     # 综合脚本
  libs/asap7 -> /home/IC1/tools/asap7  # PDK
  .claude/                 # Agents + Skills
```

## PDK

ASAP7 7nm PDK at `libs/asap7/`（symlink to `/home/IC1/tools/asap7`）。
主要使用 `asap7sc7p5t_28` (7.5-track, version 28)。

## EDA Tools

| Tool | Version | Function |
|------|---------|----------|
| VCS | 2023.12-SP2 | RTL simulation |
| Verdi | 2023.12-SP2 | Debug / waveform |
| Yosys | 0.20 | RTL synthesis |
| Verilator | latest | Open-source simulation |

Commercial tools path: `/mnt/tools/synopsys/`
Open-source tools: `yosys`, `verilator` in PATH.

## Git Remotes

| Remote | URL | 用途 |
|--------|-----|------|
| origin | gitlink.org.cn/amoslee2011/mmu_verification.git | 主仓库 |
