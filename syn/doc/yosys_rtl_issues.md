# Yosys 0.20 综合 RTL 问题记录

## 1. 多维 packed 数组

**严重程度**: 高 (10 个文件)

Yosys 0.20 不支持 `logic [A:B][C:D] sig` 多维 packed 数组语法。

| 文件 | 涉及信号数 |
|------|-----------|
| `mbuf_entry.sv` | - |
| `mmu_arb.sv` | - |
| `mmu_l1dtlb.sv` | - |
| `mmu_l1dtlb_install.sv` | 6 |
| `mmu_l1dtlb_scheduler.sv` | 2 |
| `mmu_l2tlb_replacement_policy.sv` | - |
| `mmu_l2tlb.sv` | 16 |
| `ptw_mbuf.sv` | - |
| `ptw.sv` | 17 |
| `PDE_cache.sv` | - |

**根因**: SystemVerilog 2012 的 packed 多维数组在 Yosys 0.20 中未完全支持。

**修复**: `syn/scripts/preprocess_sv.py` 将多维数组展平为 1D，part-select `[i][LO:HI]` 转换为 `[(i)*W+LO +: W]`，范围访问 `[3:0]` 手工展开为全位宽信号名。

---

## 2. Packed struct 变量索引访问

**严重程度**: 中 (2 个文件)

| 文件 | 问题 |
|------|------|
| `mmu_l1dtlb_expt_cam.sv` | packed struct 字段用变量索引 |
| `mmu_l2tlb_rrpv_wbuf.sv` | 同上 |

**根因**: Yosys 0.20 无法解析 packed struct 中运行时变量索引的字段边界。

**修复**: 手工替换为显式位域范围。文件保存为 `syn/scripts/syn_mmu_l1dtlb_expt_cam.sv` 和 `syn/scripts/syn_mmu_l2tlb_rrpv_wbuf.sv`。

---

## 3. `break` 语句

**严重程度**: 中 (2 个文件)

| 文件 | 位置 |
|------|------|
| `mmu_l1dtlb_install.sv` | WFI 查找循环、PLRU 选择循环 |
| `mmu_l1dtlb_scheduler.sv` | 优先级编码器循环 |

**根因**: Yosys 不支持 `break` 退出 for 循环（always_comb / always_ff 内）。

**修复**: 用额外终止条件替代 `break`：
- WFI 循环: `break` → `&& !req_wfi_vld`
- PLRU 循环: `break` → `&& (plru_selected_way == 4'b0)`
- 优先级编码器: `break` → `&& !mb_req_vld`

---

## 4. Latch 推断

**严重程度**: 高 (Yosys 当作 ERROR)

Yosys 将 always_comb 中的不完整赋值报告为 latch 推断并**硬错误**退出。

| 文件 | 信号 | 根因 |
|------|------|------|
| `twu.sv:1086/1218` | `ptw_nxt_st` | TWU_IDLE 状态无 else 分支，未覆盖所有 case |
| `ptw_mbuf.sv:671` | `mbuf_twu_pmpflg` | always_comb 中 for 循环前无默认赋值 |
| `pplru.sv:123` | `node` | 只在 `plru_write_updt` / `plru_read_updt` 条件分支内赋值 |

**修复**: 各加一行默认赋值：
```verilog
// twu.sv
else ptw_nxt_st[2:0] = TWU_IDLE;

// ptw_mbuf.sv
mbuf_twu_pmpflg[7:0] = 8'b0;

// pplru.sv
node = 0;  // before if(plru_write_updt)
```

---

## 5. `initial` 块

**严重程度**: 低 (1 个文件)

| 文件 | 问题 |
|------|------|
| `mmu_fpga_ram.sv` | `initial begin ... end` 对 RAM 数组仿真初始化 |

**根因**: Yosys 综合不支持带有非常量初始值的 initial 块。

**修复**: 创建 `syn/scripts/syn_mmu_fpga_ram.sv` 去除 initial 块。

---

## 6. 路径空格

**严重程度**: 低

原始路径 `mmu/rtl/relate rtl/` 包含空格，Yosys 内部 RTLIL 标识符含空格导致非法字符错误。

**修复**: 创建 symlink `/tmp/relate_rtl` → `mmu/rtl/relate rtl/`，脚本中使用 `/tmp/relate_rtl/` 路径。

---

## 总结

| 类别 | 文件数 | 根因 |
|------|--------|------|
| 多维 packed 数组 | 10 | Yosys 0.20 SV 语法支持不完整 |
| Packed struct 索引 | 2 | 同上 |
| `break` 语句 | 2 | Yosys 不支持 always 块内 break |
| Latch 推断 | 3 | RTL 编码不严谨 (仿真器不报错) |
| `initial` 块 | 1 | 仿真专用代码混入综合路径 |
| 路径空格 | 1 | 目录命名不规范 |

核心结论：Yosys 0.20 的 SystemVerilog 子集比商业工具（VCS/DC）更严格，主要差距在多维 packed 数组和 packed struct 变量索引。Latch 推断问题属于 RTL 编码不严谨，仿真器默认行为掩盖了问题，建议 CI 中加入 `verilator --lint-only` 或 `svlint` 提前发现。
