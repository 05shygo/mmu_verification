# Phase14 DUT-quality coverage closure plan

## 目标

本闭环以更高质量地验证 DUT 为准则。覆盖率只作为定位验证盲区的仪表，不能用无行为检查的激励、无依据的 waiver 或 testbench-only toggle 来替代 DUT 风险关闭。

初始 `output/coverage/phase14_urgReport` 显示的主要瓶颈为：

- L1TLB FSM: 48.90%，主要集中在 `u_mmu_l1dtlb.gen_mb_entries[3..7].x_mb_entry`。
- PTW toggle: 62.24%，PTW condition: 71.65%，主要集中在 `twu_one/twu_two/twu_three/twu_four`。
- functional: 76.21%，主要缺口为 `cg_tlboper_fsm`、`cg_twu_data_ready_per_stage`、`cg_twu_mask_cause`、`cg_twu_except_while_arb_busy`、`cg_sysmap`、`cg_maee_leaf_level` 和 `cg_pmp`。
- `u_cv_dv_utils_unref_if` 下的低 toggle 项需要分类确认；在确认非 DUT signoff scope 前不得排除。

## 落地入口

新增 closure 回归列表：

- `simu/phase14_dut_quality_closure_list`

新增运行目标：

- `make phase14_dut_quality_closure`
- `make phase14_dut_quality_coverage_merge`
- `make phase14_dut_quality_hotspots`
- `make phase14_coverage_hotspots`

新增热点分析脚本：

- `scripts/phase14_coverage_hotspots.py`

推荐闭环顺序：

1. 运行 `make comp COV_FORCE_REBUILD=1`，确保使用带 line/FSM/toggle/condition 的 coverage binary。
2. 运行 `make phase14_dut_quality_closure`，优先执行带 checker 的目标场景。
3. 运行 `make phase14_dut_quality_coverage_merge`，基于专用 closure VDB 重新生成 URG 报告。
4. 运行 `make phase14_dut_quality_hotspots`，生成 closure 专用对象级 markdown 热点报告。
5. 对仍然低覆盖的 DUT 对象补 directed/random 场景；仅对确认不可达或非 DUT scope 的对象建立 waiver。

专用产物：

- coverage VDB: `output/coverage/phase14_dut_quality_closure.vdb`
- URG report: `output/coverage/phase14_dut_quality_urgReport`
- hotspot report: `output/coverage/phase14_dut_quality_urgReport/coverage_hotspots.md`

`make phase14_coverage_hotspots` 保留为 full/parallel Phase14 VDB 的热点分析入口。

## 覆盖提升策略

### L1TLB miss-buffer FSM

重点风险是高号 DTLB miss-buffer entry 的状态迁移未充分验证。closure list 纳入已有 L1DTLB directed tests，覆盖：

- MB full 和高号 entry 分配。
- refill/abort/flush race。
- WFI install 和 data hold。
- late refill、stale id、same-entry invalidation/install。
- access fault、page fault、load/store/AMO type propagation。

验收要求：

- 新增或复用场景必须经过 `translation_sb`、`l1dtlb_spec_sb`、whitebox covergroup 和 L1DTLB SVA。
- 高号 entry 覆盖提升必须来自真实 miss/refill/flush/abort 事务，而不是空转采样。

### PTW/TWU 四路并发

新增 `test_mmu_twu_four_lane_slow_miss_pressure`，复用 Phase12 helper 驱动 IFU + LSU pipe0/1/2 的真实 cold-miss pressure，目标是让四个 TWU lane 同时经历：

- slow PTW memory response。
- all-mask 和 partial-mask ready transition。
- MBUF ready/backpressure。
- 多 page window 的冷 miss 和后续恢复。

验收要求：

- 必须保持 scoreboard/ref model clean。
- 必须检查最终 translation/fault 结果，不接受只为 covergroup sample 的测试。
- 重点观察 `cg_twu_data_ready_per_stage`、`cg_twu_idle_vs_mask_state`、`cg_twu_mask_cause` 以及 PTW/TWU condition/toggle。

### SysMap / MAEE / PMP

closure list 纳入 Phase12/13 directed tests 和 PTW source-directed tests，覆盖：

- SysMap region 2/3/7、default flag、1G/2M no-cross/degrade、PA alignment、4TWU partial。
- MAEE mixed leaf-level 组合和 MAEE0/MAEE1 path switch。
- PMP port 4-7、fetch-origin check、grant none、deny other、PDE cache pmpflg propagation。

验收要求：

- 每个场景必须检查 refill flag、PA、page size、fault type 和 PMP result。
- PTW source-directed tests 必须启用 source SB/ref model/monitor/cov plusargs。

### TLBOP FSM

`cg_tlboper_fsm` 的未覆盖状态必须先做可达性审查，再决定补测试或 waiver。

closure list 纳入：

- INVALL/INVVA/INVASID directed tests。
- ASID/global overlap directed tests。
- refill conflict 和 walk abort tests。
- L2TLB TLBOP lifecycle directed test。

验收要求：

- 合法状态用测试覆盖，并由 invalidation SB / lifecycle SVA 检查。
- 不可达状态必须有 RTL 条件、配置条件和 owner 记录，不能通过无意义激励硬打。

## Waiver 纪律

候选低价值 toggle 项包括：

- `tb_top.u_cv_dv_utils_unref_if.u_memory_response_if`
- `tb_top.u_cv_dv_utils_unref_if.u_axi_if`

处理规则：

- 若对象属于 DUT 功能路径，必须补 stimulus 或修连接。
- 若确认是 unused testbench/interface，才允许写入 `simu/exclude_v4.do`。
- 每条 exclude 必须包含 scope、object、原因、owner、关闭条件和不影响 DUT 验证质量的依据。

## 阶段性目标

- L1TLB FSM: 75%+
- PTW toggle: 75%+
- PTW condition: 80%+
- functional: 85%+
- assertion: 保持 99%+

最终 signoff 必须基于 official Synopsys URG report；XML fallback report 只用于定位和趋势分析。

## 2026-06-09 implementation status

本轮已按计划落地第三版 DUT-quality closure。重点仍然是先关闭真实 DUT 行为风险和覆盖模型误差，再用覆盖率数据指导下一轮补洞。

### 已完成改动

- 新增 `simu/phase14_dut_quality_closure_list`，当前包含 100 个带 scoreboard/SVA/whitebox coverage 的目标用例。
- 新增 `test_mmu_twu_four_lane_slow_miss_pressure`，对四路 TWU lane 施加 slow miss、ready mask/backpressure 和多窗口 cold miss 压力。
- 新增 `test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001`，用真实 DTLB miss、PTW delay、abort/page-fault/access-fault/replay 恢复覆盖高号 miss-buffer entry `[3..7]`。
- 新增 8 个 CP0/L2TLB exact TLBOP directed tests: `test_mmu_tlbp_query_hit`、`test_mmu_tlbp_query_miss`、`test_mmu_tlbr_read_entry`、`test_mmu_tlbr_all_fields`、`test_mmu_tlbwi_write_entry`、`test_mmu_tlbwi_overwrite`、`test_mmu_tlbwr_random_replace`、`test_mmu_tlbwr_rrpv_policy`。
- 新增 12 个 TLBOP reset-mid-FSM directed tests，覆盖 `TLBP/TLBR/TLBWI/TLBWR/INVASID/INVVA` 在中间状态遭遇 reset 的行为；每个用例均检查 reset hit、reset release、驱动端 reset abort、TLBOP shadow reset-drop 处理或 LSU invalidation recovery，以及 reset 后 TLBP hit recovery。
- `cg_tlboper_fsm` 从只采 `tlbiva_cur_st[3:0]` 的盲目 `[0:15]` bins，改为采样 `TLBP/TLBR/TLBWI/TLBWR/INVASID/INVALL/INVVA` 各自合法状态。
- `Makefile` 新增 `phase14_dut_quality_closure`、`phase14_dut_quality_coverage_merge`、`phase14_dut_quality_hotspots`、`phase14_coverage_hotspots`。
- `scripts/check_sim_status.sh` 增加 hard failure pattern 检查，修复 UVM summary clean 但 VCS assertion failure 被误判 PASS 的问题。
- `scripts/phase14_coverage_hotspots.py` 增加 VDB XML 对象级热点报告，覆盖 FSM/toggle/condition/functional。
- `scripts/run_urg_report.sh` 增加 aggregate VDB 的 XML fallback；只有所有官方 URG direct/merge/context 路径失败后才启用。
- 降低默认日志噪声：PTW LSU trace、PTW responder trace、exception trace 改为显式 plusarg/compile knob；L2 source/result、payload ignore、L1DTLB stale-hit 诊断增加默认限流。

### 调试中定位并修正的验证问题

- `mmu_pde_cache_sva`: L2 PDE tag deny 时 RTL 会阻断 `PDE_xbar_req` 并直接产生 accerr，`L2PDE_xbar_hit_vld/L1PDE_xbar_hit_vld` 仍可能反映组合 tag lookup sideband。原断言把 sideband 当成 xbar request，已改为检查 `!PDE_xbar_req`。
- `phase12_pulse_ptw_ready_for_cov`: helper 复用低地址 VA window，和压力测试窗口发生 remap 污染，触发同一请求同时 entry hit 与 exception replay。已换到独立高地址窗口。
- `mmu_l1dtlb_hit_rd_sva`: RTL 允许 exception-CAM replay 与 stale/independent TLB entry hit 同周期重叠，真实要求是 replay fault 终止请求、不产生 miss、不使用 stale PA。原互斥断言过强，已改为行为断言并新增 cover。
- TLBOP functional coverage model: `ct_mmu_tlboper` 当前 INVVA FSM 只实现 `IVA_IDLE/RD/CMP/WR/WT/CMPLT`，编码为 `0/2/3/4/5/14`；旧的 per-page-size `2M/1G` INVVA 状态在 RTL 中已经注释掉。原 `cg_tlboper_fsm` 把 `1/6..13/15` 也当成有效 bins，是覆盖模型缺陷，不是 stimulus 缺口。本轮将这些 legacy/reserved 状态改为 `ignore_bins`，并补采其他 TLBOP 子状态机。
- `test_mmu_tlbop_reset_invasid_wt` 初次在完整 closure 中失败，根因为 testbench 同步错误：测试用固定 `#200ns` 等待 reset 注入完成，但 `invasid_wt` 目标状态很晚才出现，reset 实际打断了 recovery TLBWI，导致 recovery TLBP miss。已在 `mmu_dut_probes_if` 增加 reset injector active/hit/done 状态，`tb_top` 发布状态，reset-mid test 等待 `done && hit && rst_ni` 后再开始 recovery。复跑单测和 100-test closure 均通过。

### 覆盖流根因修正

本轮定位到两个会误导覆盖闭环的流程问题：

- `make comp_fast` 后直接 `run_cov` 只能产生 assertion/functional 类数据，不能完整产生 line/FSM/toggle/condition；同时相对路径 `COV_DB_DIR=output/...` 在部分规则下会落到 `output/output/coverage/...`。后续 directed probe 和 closure 均应使用 coverage compile，并优先传入绝对 `COV_DB_DIR`。
- 并行 `run_cov` 默认共享 `RUN_DIR=$(OUTPUT_DIR)`，而 coverage compile 打开 `+vcs+fsdbon`，`run_cov` 未传入 `FSDB_OPTS`，多个仿真会竞争默认 `novas.fsdb`。第一次 TLBOP probe 中出现的 FSDB create/lock error 是共享输出目录文件竞争，不是 DUT 失败；后续使用独立 `RUN_DIR/COV_DB_DIR` 清洁复跑并通过，正式 closure 采用 `PHASE14_DUT_QUALITY_JOBS=1` 避免 aggregate VDB 和 FSDB 写入竞争。

### 验证证据

命令：

```sh
make comp COV_FORCE_REBUILD=1
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/phase14_dut_quality_probe_l1d_high_cov_v2.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_check TEST_NAME=test_mmu_ptw_ready_one_unblock SEED=97101 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_check TEST_NAME=test_mmu_arb_multi_twu_fairness SEED=97101 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_cov TEST_NAME=test_mmu_tlbp_query_hit SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_test_mmu_tlbp_query_hit_97101_cov COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_test_mmu_tlbp_query_hit_97101.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_cov TEST_NAME=test_mmu_tlbp_query_miss SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_test_mmu_tlbp_query_miss_97101_cov COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_test_mmu_tlbp_query_miss_97101.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_cov TEST_NAME=test_mmu_tlbr_read_entry SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_test_mmu_tlbr_read_entry_97101_cov COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_test_mmu_tlbr_read_entry_97101.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_cov TEST_NAME=test_mmu_tlbr_all_fields SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_test_mmu_tlbr_all_fields_97101_cov COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_test_mmu_tlbr_all_fields_97101.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make run_cov TEST_NAME=test_mmu_tlbop_reset_invasid_wt SEED=97101 PLUS_ARGS="+MMU_TLBOP_RESET_MODE=invasid_wt" RUN_DIR=output/regression/phase14_tlbop_reset_probe3/test_mmu_tlbop_reset_invasid_wt_97101 COV_DB_DIR=output/coverage/phase14_tlbop_reset_probe3/test_mmu_tlbop_reset_invasid_wt_97101.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make phase14_dut_quality_closure PHASE14_DUT_QUALITY_SEEDS=97101 PHASE14_DUT_QUALITY_JOBS=1 UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
make phase14_dut_quality_coverage_merge
make phase14_dut_quality_hotspots
bash scripts/check_sim_status.sh output/logs/*_97101_cov.log
```

结果：

- `phase14_dut_quality_closure`: 100/100 PASS，0 FAIL，effective pass rate 100%。
- 独立 hard-failure scan: 100 PASS logs，0 FAIL logs；所有当前 closure `_97101_cov.log` 均为 `UVM_ERROR=0 UVM_FATAL=0 hard_failures=0`。
- 8 个 TLBOP exact tests 的 shadow summary 覆盖 TLBP hit/miss、TLBR field read、TLBWI write/overwrite、TLBWR random/RRPV replacement，均无 `corr_err/hitidx_mis/tlbr_field_mis`。
- 12 个 TLBOP reset-mid-FSM tests 均打印 `[TLBOP_RESET_ARC] mode=... hit` 和 `reset_release`；`invasid_wt` 复跑中 recovery `tlbp_hit_setup.tlbwi` 为 `cmplt=1`，recovery TLBP `expected_hit=1 observed_hit=1 status=PASS`。
- XML fallback coverage summary 已生成到 `output/coverage/phase14_dut_quality_urgReport/coverage_summary.txt`。
- 热点报告已生成到 `output/coverage/phase14_dut_quality_urgReport/coverage_hotspots.md`。

### URG 失败根因判断

`make phase14_dut_quality_coverage_merge` 中 Synopsys URG T-2022.06 在以下路径全部崩溃：

- aggregate VDB direct report。
- compile-context + aggregate direct report。
- compile-context + aggregate merge。
- repeated `-dir` direct/merge。
- contextless aggregate merge。

共同栈为 `urg1 -> libucapi.so -> libsnpsmalloc.so mem_free()`，返回码为 1。崩溃时系统 free memory 约 995 GB，closure aggregate VDB XML 可正常扫描且 `missing_testdata_vdbs=0`，因此当前判断为 URG 工具对该 aggregate VDB 的处理崩溃/兼容性问题，不是 DUT 仿真失败，也不是明显内存耗尽。

处理原则：

- 保留 `output/coverage/phase14_dut_quality_urg.log` 作为官方 URG 失败证据。
- `output/coverage/phase14_dut_quality_coverage_merge_summary.txt` 中 `urg_rc=0` 只表示 wrapper 成功产出 fallback 报告，不表示官方 URG signoff 成功。
- XML fallback 只作为诊断和趋势报告，不作为 signoff 替代。
- 最终签核仍需 official Synopsys URG report；后续应尝试 sharded/parallel merge 路径或更新 Synopsys 工具版本。

### 当前 closure VDB 热点

XML fallback 摘要：

- line: 92.26% (6163/6680)
- branch: 89.26% (3642/4080)
- condition: 68.25% (5041/7386)
- toggle: 59.99% (102229/170404)
- FSM: 73.55% (228/310)
- functional: 73.06% (339/464)
- assertion activity diagnostic: 98.36% (1079/1097)

主要剩余瓶颈：

- `x_ct_mmu_tlboper` 仍是 FSM 最大单点缺口，但已从 44/63、69.84%、缺 19 个，提升到 56/63、88.89%、缺 7 个；`cg_tlboper_fsm` 不再出现在 functional explicit gap 列表中。后续 TLBOP 工作应针对 RTL structural FSM/transition 剩余缺口，不再追旧 INVVA legacy 状态。
- L1DTLB high miss-buffer entry 已明显提升，但 entry `[2,5,6,7]` 仍为 13/21、61.90%，entry `[0,3,4]` 为 16/21、76.19%，entry `[1]` 为 19/21、90.48%。主要剩余缺口是 WFI install、WFG flush/abort race、WFC 到 WFI/IDLE 和 fault/install 交错。
- PTW `twu_one/twu_two/twu_three/twu_four` 仍是 toggle/condition 主缺口。toggle: `twu_two` 42.14%、`twu_four` 43.65%、`twu_one` 44.12%、`twu_three` 44.54%；condition: `twu_four` 65.11%、`twu_two` 67.99%、`twu_three` 69.78%、`twu_one` 71.22%。
- functional 剩余 explicit gaps 集中在 `cg_twu_data_ready_per_stage` 8、`cg_l2_reqq` 7、`cg_sysmap` 6、`cg_pmp` 5、`cg_twu_mask_cause` 5、`cg_l1dtlb` 5、`cg_maee_leaf_level` 4。
- `tb_top.u_cv_dv_utils_unref_if.u_memory_response_if` 和 `u_axi_if` 仍是低价值 toggle 大项，暂未 waiver，需要确认是否属于 DUT signoff scope。

### TLBOP reset structural arc 追加证据

本轮继续解析 `phase14_dut_quality_closure.vdb` 的 FSM XML。`fsm.verilog.shape.xml` 为 gzip 压缩文件，原始 shape 中 `ct_mmu_tlboper` 有 71 个条目；其中 8 个是 VCS 为 2-bit CP0 FSM 插入的 pseudo `IDLE` state/transition，不对应 data bitstring。过滤这些 pseudo 条目后，63 个 shape 条目与 data bitstring 对齐，剩余 7 个未命中 structural FSM bins 均为异步 reset/default-to-idle arc：

- `tlbiasid_cur_st`: `IASID_WT -> IASID_IDLE`，RTL line 566。
- `tlbiva_cur_st`: `IVA_RD -> IVA_IDLE`，RTL line 870。
- `tlbiva_cur_st`: `IVA_WR -> IVA_IDLE`，RTL line 870。
- `tlbp_cur_st`: `PWFG -> PIDLE`，RTL line 285。
- `tlbr_cur_st`: `RWFG -> RIDLE`，RTL line 345。
- `tlbwi_cur_st`: `WIWFG -> WIIDLE`，RTL line 405。
- `tlbwr_cur_st`: `WRWFG -> WRIDLE`，RTL line 467。

处理原则：不为提高 FSM 数字而构造无意义激励。上述 7 个点对应 reset 行为，DUT 风险应通过断言和过程计数验证，而不是继续猜测非 reset stimulus。

已补充验证资产：

- `testbench/top/mmu_tlbop_lifecycle_sva.sv`: 增加 7 条 reset-from-state assertion、7 条 cover property，以及 final 过程计数 `[TLBOP_RESET_SVA_COVER]`。
- `simu/phase14_tlbop_reset_sva_probe_list`: 收敛为 7 条与上述 structural arc 一一对应的 directed reset probe。

执行命令：

```sh
make comp COV_FORCE_REBUILD=1
COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/phase14_tlbop_reset_sva_probe_pertest.vdb python3 scripts/run_test.py --reg-list simu/phase14_tlbop_reset_sva_probe_list --mode run_cov --seeds 97101 --jobs 1 --fail-fast 1 --summary output/regression/phase14_tlbop_reset_sva_probe_pertest/summary.txt --log-dir output/logs --uvm-err-only 1 --uvm-config-db-trace 0 --timeout 20000000
bash scripts/check_sim_status.sh output/logs/test_mmu_tlbop_reset_tlbp_wfg_97101_cov.log output/logs/test_mmu_tlbop_reset_tlbr_wfg_97101_cov.log output/logs/test_mmu_tlbop_reset_tlbwi_wfg_97101_cov.log output/logs/test_mmu_tlbop_reset_tlbwr_wfg_97101_cov.log output/logs/test_mmu_tlbop_reset_invasid_wt_97101_cov.log output/logs/test_mmu_tlbop_reset_invva_rd_97101_cov.log output/logs/test_mmu_tlbop_reset_invva_wr_97101_cov.log
```

结果：

- probe regression: 7/7 PASS，effective pass rate 100%。
- 精确 7 个 per-test log 均为 `UVM_ERROR=0 UVM_FATAL=0 hard_failures=0`。
- 每条 log 的目标 reset 计数为 1，非目标 reset 计数为 0：
  - `tlbp_wfg=1`
  - `tlbr_wfg=1`
  - `tlbwi_wfg=1`
  - `tlbwr_wfg=1`
  - `invasid_wt=1`
  - `invva_rd=1`
  - `invva_wr=1`

验证流程中还定位到一个日志归属风险：如果在 regression wrapper 外部固定 `COV_TAG`，`make run_cov` 会把多条 test 写到同一个 `*_cov.log`，而 `run_test.py` summary 仍指向 per-test log，可能误读旧日志。因此本轮正式证据使用新的 `phase14_tlbop_reset_sva_probe_pertest.vdb`，不固定 `COV_TAG`，让每条 test 使用自己的 `cm_name` 和 log。同时 `scripts/run_test.py` 已增加 guard：`run_cov` regression 检测到外部固定 `COV_TAG` 时在仿真前直接报错，避免后续覆盖闭环误用旧日志。

当前结论：`ct_mmu_tlboper` 剩余 7 个 structural FSM bins 已有 DUT reset 行为证据，但 VCS T-2022.06 XML bitstring 未把这些异步 reset arc 计为 FSM hit。暂不写 active `coverage exclude`，因为 `simu/exclude_v4.do` 要求 tracker ID/signoff matrix review，而本仓当前没有对应 Phase14 tracker/signoff matrix 文件。最终处理应进入工具/waiver 签核闭环，不能用 XML fallback 或本地 exclude 替代 official signoff。

### 下一轮提高覆盖率的优先级

1. TLBOP structural FSM 签核闭环：剩余 7 个 structural bins 已定位为 reset/default-to-idle arc，并已由 directed reset probe、lifecycle SVA 和过程计数验证。下一步不是继续硬打无效 stimulus，而是用 official URG 或工具 owner 确认 VCS T-2022.06 对异步 reset arc 的计数行为；如需 waiver，必须补齐 tracker/signoff matrix 后再进入 `simu/exclude_v4.do`。若后续报告出现新的非 reset TLBOP structural gap，再补 TLBP/TLBR/TLBWI/TLBWR grant stall、TLBWR WFG/TAG/WFC、INVASID hit/no-hit 多 entry、INVVA hit/no-hit 与 ASID/no-ASID 组合，且每个用例必须由 `TLBOP_DECODE` shadow、invalidation SB 和 lifecycle SVA 验证结果。
2. L1DTLB MB 高号 entry 二期：在已覆盖 ABT/PGFLT/ACFLT/WFG/WFC 的基础上，专项覆盖 WFI install、WFG 被 flush/abort、WFC 到 WFI/IDLE 以及 late/stale refill，不降低 L1DTLB spec SB 和 SVA 检查强度。
3. TWU 四 lane 均衡专项：把现有 slow miss pressure 拆成 lane-pinned directed 场景，分别命中 stage0/1/2 ready、all/partial mask、pgflt/accerr bypass、arb busy exception overlap，提高 `twu_one..four` 的 condition/toggle，而不是只增加随机压力。
4. SysMap/PMP/MAEE/L2 REQQ 补洞：按 hotspot bin name 补 region `[1,2,3,4,6,7]`、PMP port `[3..7]`、fetch-origin/other、MAEE leaf-level、L2 REQQ explicit bins，必须检查 refill flag、PA、page size、fault type 和仲裁结果。
5. 覆盖工具闭环：优先验证 sharded/parallel VDB merge 是否避开 URG aggregate 崩溃；若仍失败，固定最小 VDB reproducer 给工具 owner。签核前不得用 XML fallback 替代 official URG。

### L1DTLB high-entry matrix 追加闭环

本轮继续执行 L1DTLB MB 高号 entry 二期。目标不是单纯提高 FSM 数字，而是用真实 miss/refill/fault/install 事务补齐高号 miss-buffer 的行为风险，并保持 `translation_sb`、`l1dtlb_spec_sb`、L1DTLB SVA 和 whitebox coverage 同时开启。

调试中定位到两个关键根因：

- WFI 长期打不中的根因不是 RTL 不可达，而是旧激励用低号 entry 的 long-delay WFC 占位来制造高号 entry。这些低号 walk 会持续消耗 PTW 服务，导致目标 L2 success refill 正常拿到 `refill_gnt`，无法形成 same-cycle PTW/L2 install collision，也就不会进入 WFI。修正后改用已完成的 PGFLT entry 占位 allocator 低槽，既占用低号 entry，又不继续消耗 PTW。
- `cov7` 行为仿真干净，但 VDB 缺少 `fsm/line/cond/branch/tgl` data XML。根因是当前 `output/simv.vdb` 曾被非 coverage compile 覆盖，`run_cov` 只检查旧 baseline stamp，没有检查当前 simv coverage context。已新增 `scripts/check_vdb_coverage_context.py`，并在 `Makefile` 的 coverage compile/run 路径中同时检查 `output/simv.vdb` 和 clean baseline VDB；`scripts/run_test.py` 也阻断 regression `run_cov` 固定外部 `COV_TAG`，避免多 test 共用旧日志或旧 cm_name。

新增/修正的验证资产：

- `test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001` 使用 targeted leaf-PTE bus error 打 ACFLT，不再用全局随机 bus-error 污染低号占位 entry。
- `recover_l1d_high_matrix_phase()` 在每个 phase 之间执行 flush、`INV_ALL` 和 PTW responder control reset，避免 PDE/L2/UTLB 残留污染下一 phase。
- `prefill_l1d_mb_low_slots_pgflt()` 专门制造低号 PGFLT 占位，服务 WFI collision 场景。
- `wait_l1d_mb_entry_wfi_with_diag()` 记录目标 L2 complete、PTW complete、install grant、PDE cache 和 WFI cycle 等证据；只有最终 trial 失败才升级为 `UVM_ERROR`。
- `ptw_mem_responder` 增加 `+PTW_RESP_TRACE` gated trace，用于定位 targeted bus-error 是否命中预期 leaf PTE 地址，默认不增加日志噪声。

执行命令：

```sh
make comp COV_FORCE_REBUILD=1
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l1d_high_entry_matrix_cov8 COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l1d_high_entry_matrix_cov8.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=100000000
bash scripts/check_sim_status.sh output/logs/test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001_97101_cov.log
python3 scripts/check_vdb_coverage_context.py --vdb output/coverage/probe_l1d_high_entry_matrix_cov8.vdb --label "probe_l1d_high_entry_matrix_cov8 runtime VDB"
python3 scripts/check_vdb_coverage_context.py --vdb output/simv.vdb --label "current simv coverage context"
```

结果：

- `cov8` 仿真 PASS，`UVM_ERROR=0 UVM_FATAL=0 hard_failures=0`。
- VCS 报告本次仿真监控了 `line/cond/FSM/branch/tgl`。
- `probe_l1d_high_entry_matrix_cov8.vdb` 包含 `fsm.verilog.data.xml`、`line.verilog.data.xml`、`cond.verilog.data.xml`、`branch.verilog.data.xml` 和 `tgl.verilog.data.xml`。
- coverage context guard 均 PASS：`probe_l1d_high_entry_matrix_cov8 runtime VDB` 和 `current simv coverage context` 都有 `assert+branch+cond+fsm+line+tgl`。
- L1DTLB SVA 覆盖显示 `cp_l1dtlb_c015_wfi_install=6`、`cp_l1dtlb_c015_ptw_l2_collision=6`，entry `[2..7]` 的 `cp_l1dtlb_c015_wfi_hold` 各命中 1 次。

XML fallback 解析结果如下。`phase14_dut_quality_closure.vdb` 是旧 aggregate 基线，`old_plus_cov8` 只是把本次 focused proof 的 VDB XML 作为趋势诊断 OR 进去，不替代 official URG signoff。

- full FSM fallback: old `228/310`、73.55%；old_plus_cov8 `259/310`、83.55%。
- L1DTLB MB entry total: old `119/168`、70.83%；old_plus_cov8 `149/168`、88.69%。
- entry `[2]`: old `13/21` -> old_plus_cov8 `19/21`，新增 `PGFLT`、`WFI`、`PGFLT->IDLE`、`WFC->PGFLT`、`WFC->WFI`、`WFI->IDLE`。
- entry `[3]`: old `16/21` -> old_plus_cov8 `19/21`，新增 `WFI`、`WFC->WFI`、`WFI->IDLE`。
- entry `[4]`: old `16/21` -> old_plus_cov8 `19/21`，新增 `WFI`、`WFC->WFI`、`WFI->IDLE`。
- entry `[5]`: old `13/21` -> old_plus_cov8 `19/21`，新增 `ACFLT`、`WFI`、`ACFLT->IDLE`、`WFC->ACFLT`、`WFC->WFI`、`WFI->IDLE`。
- entry `[6]`: old `13/21` -> old_plus_cov8 `19/21`，新增 `ACFLT`、`WFI`、`ACFLT->IDLE`、`WFC->ACFLT`、`WFC->WFI`、`WFI->IDLE`。
- entry `[7]`: old `13/21` -> old_plus_cov8 `19/21`，新增 `ACFLT`、`WFI`、`ACFLT->IDLE`、`WFC->ACFLT`、`WFC->WFI`、`WFI->IDLE`。

当前 L1DTLB MB 剩余缺口已经收敛为更具体的 WFG race：

- entry `[0]`: `WFG`、`IDLE->WFG`、`WFG->ABT`、`WFG->IDLE`、`WFG->WFC`。
- entry `[1..7]`: 主要剩余 `WFG->ABT`、`WFG->IDLE`。

RTL 条件来自 `mmu_l1dtlb_mb_entry.sv` 的 WFG 分支：`abort_this_cyc && issue_sel && issue_grant` 进入 `ABT`，`abort_this_cyc && !(issue_sel && issue_grant)` 直接回 `IDLE`，`issue_sel && issue_grant` 进入 `WFC`。下一轮 L1DTLB 工作应专项制造高号 entry 在 WFG 尚未 issue 时的 flush/abort race，并用 replay/fault/translation SB 验证最终行为；不应为了覆盖 WFG 而关闭 scheduler/allocator 的真实握手机制。

### L1DTLB WFG race probe 结果

继续追 WFG race 时，新增相位扫描 probe 触发了真实 checker failure，不能作为默认 coverage closure 用例使用。失败运行命令如下：

```sh
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l1d_high_entry_matrix_cov9 COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l1d_high_entry_matrix_cov9.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=100000000
```

结果：

- `output/logs/test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001_97101_cov.log` 出现 15 次 `P6D_NR_L2_SIDE_EFFECT`。
- 典型错误为 `legal no-response reason=flush_kill produced L2 request ... token{global}`。
- 错误来自 L1DTLB spec SB 的 no-response side-effect 检查：flush kill 周期不允许产生新的 L2 request。

根因已经定位，不是单纯激励校准问题：

- 当前 `mmu_l1dtlb_mb_entry.sv` 在 WFG 状态下仍有 `abort_this_cyc && issue_sel && issue_grant -> STATE_ABT` 分支，但 `entry_ready` 同时被定义为 `(state_r == STATE_WFG) && !abort_this_cyc && !fault_hold_r`。
- 当前 `mmu_l1dtlb_scheduler.sv` 用 `bypass_en = ~(|mb_entry_ready)` 判断旁路。当 flush 使所有 WFG entry 的 ready 被 mask 后，同周期的新 miss 可能走 bypass 并对 L2 发请求。
- 上游 `/home/st-wangjun/project/openc910` 的 `ct_mmu_dutlb.v` 则保持 `dutlb_arb_req = (ref_cur_st == WFG)`，WFG 下 flush+grant 到 ABT、flush 无 grant 到 IDLE、grant 无 flush 到 WFC；没有把现有 WFG request 用 flush mask 掉。

因此当前分类为 `COVP-DUT-002`：L1DTLB WFG flush race 与 refactor 后 scheduler bypass 协作风险。默认 high-entry matrix 用例已将该扫描改为 opt-in：只有传入 `+L1DTLB_WFG_RACE_PROBE` 才复现此失败；默认 coverage closure 保持所有 spec SB/SVA 检查开启并必须通过。

opt-in gating 后重新执行默认 high-entry matrix：

```sh
make comp COV_FORCE_REBUILD=1
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l1d_high_entry_matrix_cov10 COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l1d_high_entry_matrix_cov10.vdb UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=100000000
bash scripts/check_sim_status.sh output/logs/test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001_97101_cov.log
python3 scripts/check_vdb_coverage_context.py --vdb output/coverage/probe_l1d_high_entry_matrix_cov10.vdb --label probe_l1d_high_entry_matrix_cov10_runtime_VDB
python3 scripts/check_vdb_coverage_context.py --vdb output/simv.vdb --label current_simv_coverage_context
```

结果：

- compile PASS，编译 VDB guard 报告 `assert+branch+cond+fsm+line+tgl`。
- cov10 PASS，`UVM_ERROR=0 UVM_FATAL=0 hard_failures=0`。
- cov10 runtime VDB 和 current simv coverage context 均 PASS，包含 `assert+branch+cond+fsm+line+tgl`。
- cov10 log 没有 `P6D_NR_L2_SIDE_EFFECT`，证明默认路径没有隐藏或放松 side-effect checker。
- cov10 SVA：`cp_l1dtlb_c015_wfi_install=6`、`cp_l1dtlb_c015_ptw_l2_collision=6`，entry `[2..7]` 的 `cp_l1dtlb_c015_wfi_hold` 各命中 1 次。
- 默认 WFG race cover `cp_l1dtlb_wfg_flush_no_grant/with_grant` 为 0 match，符合 opt-in 设计，不能视作已闭合的 DUT 行为。

XML fallback 趋势诊断也与 cov8 一致：

- full FSM fallback: old `228/310`、73.55%；old_plus_cov10 `259/310`、83.55%。
- L1DTLB MB entry total: old `119/168`、70.83%；cov10 only `137/168`、81.55%；old_plus_cov10 `149/168`、88.69%。
- old_plus_cov10 per-entry: entry `[0]` `16/21`，entry `[1]` `19/21`，entry `[2..7]` 均 `19/21`。

后续动作：

- `WFG->IDLE` 可继续用 flush after allocation-valid deassert 的方式单独打，但必须证明没有 same-cycle 新 L2 request side effect。
- `WFG->ABT` 需要 DUT owner 先判定：修正 refactor 以保留 OpenC910 的 existing-WFG flush/grant 语义，或者明确该 structural arc 是有意不可达并进入 waiver/signoff。
- 在 DUT 行为澄清前，不应为了提高 FSM 数字关闭 `P6D_NR_L2_SIDE_EFFECT`，也不应把失败 probe 合入默认回归。

### 下一轮优先级更新

1. L1DTLB MB WFG race closure：先处理 `COVP-DUT-002`。`WFG->ABT` 不能继续硬打 coverage，必须先完成 DUT/refactor owner 判定或 RTL 修正；`WFG->IDLE` 可用无 side-effect 的 flush 相位专项继续验证。entry `[0]` 仍需覆盖 normal `IDLE->WFG/WFG->WFC`，避免所有低号 miss 都走 bypass grant。
2. PTW/TWU condition/toggle：仍是最大全局瓶颈，应拆成 lane-pinned 和 stage-pinned directed 场景，而不是继续单纯增加随机压力。
3. SysMap/PMP/MAEE/L2 REQQ functional gaps：继续按 explicit bin name 补真实检查型用例。
4. Official URG 工具闭环：保留 XML fallback 作为诊断趋势，但签核仍需要解决 URG T-2022.06 aggregate VDB 崩溃或获得工具/waiver owner 确认。

### 2026-06-09 no-RTL continuation

用户约束已明确：本轮不得修改 DUT RTL。因此当前继续方向改为验证侧诊断、用例纳入和文档闭环；`../mmu/rtl` 下文件不作为本轮可编辑范围。

新增验证侧资产：

- `test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001` 增加 `+L1DTLB_WFG_RACE_ONLY`、`+L1DTLB_HIGH_MATRIX_FAST_RECOVER`、`+L1DTLB_HIGH_MATRIX_SKIP_WFI`、`+L1DTLB_FAST_FINAL_QUIESCE` 等 opt-in 控制，便于短路径复现 WFG race，不改变默认 closure 行为。
- `mmu_l1dtlb_spec_sb` 增加 `+L1DTLB_FLUSH_ALLOC_DIAG` / `+L1DTLB_FLUSH_ALLOC_DIAG_LIMIT=N`，只在 opt-in 诊断下打印 flush 周期 MB 分配、状态、ready/issued/WFC/WFI、L2 request 和 PTW/L2 reference 快照。

L1DTLB WFG 诊断结果：

```sh
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 \
  PLUS_ARGS="+L1DTLB_WFG_RACE_ONLY +L1DTLB_WFG_RACE_PROBE +L1DTLB_HIGH_MATRIX_FAST_RECOVER +L1DTLB_FAST_FINAL_QUIESCE +L1DTLB_FLUSH_ALLOC_DIAG +L1DTLB_FLUSH_ALLOC_DIAG_LIMIT=8" \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l1d_high_entry_matrix_wfg_only_diag_no_rtl_mod \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l1d_high_entry_matrix_wfg_only_diag_no_rtl_mod.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=5000000
```

结果为 expected FAIL：`UVM_ERROR=34`、`UVM_FATAL=0`，其中
`P6D_ALLOC_FLUSH_SIDE_EFFECT=17`、`P6D_NR_ALLOC_SIDE_EFFECT=17`。首个错误在
cycle `4998`：`flush=1`，`base_vld=0x00`，`cur_vld=0x03`，
`trans_mask=0x03`；同一诊断快照中 `l2_req.vld=0`，PTW/L2 reference 均未完成，但 MB0 已新分配到
`WFC/issued=1`，MB1 已新分配到 `WFG/issued=0`。这说明当前 no-RTL 复现点是
flush-kill 周期新分配 miss-buffer entry，而不是 checker 误判或单纯缺少 WFG cover。

SVA cover 方面，`cp_l1dtlb_wfg_flush_no_grant` 已在 entries `[1..7]` 命中，
`cp_l1dtlb_wfg_flush_with_grant` 仍为 `0`。因此 `COVP-DUT-002` 仍阻塞
`WFG->ABT` signoff；在 DUT owner 判定或 waiver 之前，不把失败 probe 合入默认 regression，也不放松 L1DTLB spec SB。

L2TLB REQQ/arb focused closure：

```sh
make run_cov TEST_NAME=test_l2tlb_p6e_reqq_arb_fine_overlap SEED=64001 \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l2tlb_reqq_arb_fine_overlap_no_rtl_mod \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l2tlb_reqq_arb_fine_overlap_no_rtl_mod.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000
```

结果 PASS：`UVM_ERROR=0`、`UVM_FATAL=0`、`hard_failures=0`，runtime VDB guard
报告 `assert+branch+cond+fsm+line+tgl`。关键日志证据：

- `L2TLB_PHASE6E_TRIGGER` / `CHECKER` / `CLOSE` 均为 count `1`，waiver count `0`。
- Phase6C shadow clean：`ptw_req=220`、`ptw_data=220`、`l2_hit=420`、
  `l2_miss=220`、`pfu=128`、`mismatch=0`、`waived_future=0`。
- `L2TLB_REQQ_FINE`: `i_alloc=104`、`d_load_alloc=162`、
  `d_store_alloc=190`、`max_occ=2`。
- `L2TLB_ARB_FINE`: `reqq_req=514`、`reqq_grant=456`、`multi_req=668`、
  `reqq_pfu_conflict=423`、`ptw_reqq_conflict=2`、`tlbop_reqq_conflict=9`、
  `ptw_reqq_pfu_conflict=1`、`tlbop_reqq_pfu_conflict=5`。

`test_l2tlb_p6e_reqq_arb_fine_overlap` 已加入
`simu/phase14_dut_quality_closure_list`。当前证据是 focused run PASS；下一次
`make phase14_dut_quality_closure` 将按新列表进入 aggregate regression。

当前状态更新：

1. L1DTLB MB WFG：证据已足够证明存在 no-RTL reproducer，状态是 DUT/refactor open issue，不再作为单纯 coverage stimulus 推进。
2. L2TLB REQQ/arb：focused closure 已通过，并已纳入 closure list。
3. PTW 相关覆盖本轮未继续扩展；后续若恢复 PTW 工作，仍需按 lane/stage-pinned checked directed 场景推进。
4. official URG 崩溃问题仍未关闭；XML fallback 继续只作为定位和趋势，不替代 signoff。

### 2026-06-09 DUT update 后的 L1/L2 复跑闭环

用户随后完成 DUT RTL 修改，并明确 L1DTLB WFG flush/grant 的设计
contract：flush 到来的这一拍不需要阻止已经获得 grant 的 WFG entry 向下游
发 L2 request；如果同拍 `abort_this_cyc` 有效，该 entry 走 ABT 处理路径。
因此，之前把所有 `flush_kill` 周期 L2 request 都视为 illegal side-effect 的
checker 语义过强，需要按 existing-WFG grant 例外修正。

本轮仍未修改 DUT RTL，只调整验证侧以匹配最新 DUT 接口和 contract：

- `mmu_l1dtlb_sva` 删除已不存在的 refill-IID match 端口绑定，并把
  `entry_ready` decode 改为等价于 `STATE_WFG`。
- `tb_top` 对已删除的 refill-IID probe 赋 0，新增只读 allocation/miss queue
  probe，用于区分真实 flush-cycle 分配和 monitor 采样相位导致的 prior-visible
  transition。
- `mmu_l1dtlb_spec_sb` 增加 `legal_flush_wfg_l2_issue()`：只有当 L2 request
  的 `eid/vpn/load-store` 与当前 valid+ready+WFG MB entry 完全匹配时，才把
  flush+grant 同拍 issue 视为合法。
- 同一 checker 增加 `flush_transition_is_prior_visible()`，当 flush 周期看到
  `cur_vld` 变化但 `mb_alloc_we_safe` 对该 transition 为 0 时，不再误报新分配。
  真实 flush 周期 allocation write-enable 或非 WFG L2 side-effect 仍会报错。

调试根因已经收敛：首个可疑 flush 周期显示 `req0=0`、`req1=0`、
`gnt_safe=00`、`we_safe=0x00`，但 monitor 看到 `cur_vld` transition。该
transition 是上一拍 allocation 在当前采样点可见，不是 DUT 在 flush 有效这一拍
继续分配。

执行命令：

```sh
make comp COV_FORCE_REBUILD=1 UVM_CONFIG_DB_TRACE=0
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001 SEED=97101 \
  PLUS_ARGS="+L1DTLB_WFG_RACE_ONLY +L1DTLB_WFG_RACE_PROBE +L1DTLB_HIGH_MATRIX_FAST_RECOVER +L1DTLB_FAST_FINAL_QUIESCE +L1DTLB_FLUSH_ALLOC_DIAG +L1DTLB_FLUSH_ALLOC_DIAG_LIMIT=16" \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l1d_wfg_race_after_alloc_checker_align \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l1d_wfg_race_after_alloc_checker_align.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=8000000
make run_cov TEST_NAME=test_l2tlb_p6e_reqq_arb_fine_overlap SEED=64001 \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l2tlb_reqq_arb_fine_overlap_after_l1_checker_align \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l2tlb_reqq_arb_fine_overlap_after_l1_checker_align.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000
bash scripts/check_sim_status.sh output/logs/test_mmu_l1dtlb_dtlb_mb_high_entry_matrix_001_97101_cov.log
bash scripts/check_sim_status.sh output/logs/test_l2tlb_p6e_reqq_arb_fine_overlap_64001_cov.log
```

结果：

- coverage compile PASS，编译 VDB guard 报告 `assert+branch+cond+fsm+line+tgl`。
- L1DTLB WFG race focused run PASS：`UVM_ERROR=0`、`UVM_FATAL=0`、
  `hard_failures=0`，aggregate VDB 更新到
  `output/coverage/probe_l1d_wfg_race_after_alloc_checker_align.vdb`。
- L1DTLB SVA cover：`cp_l1dtlb_wfg_flush_with_grant` 在 entries `[1..7]`
  命中；`cp_l1dtlb_wfg_flush_no_grant` 在 entries `[3..7]` 命中；
  `cp_l1dtlb_c020_flush_race` 在 entries `[0..7]` 均命中。
- L2TLB REQQ/arb focused run PASS：`UVM_ERROR=0`、`UVM_FATAL=0`、
  `hard_failures=0`，aggregate VDB 更新到
  `output/coverage/probe_l2tlb_reqq_arb_fine_overlap_after_l1_checker_align.vdb`。
- L2TLB Phase6E `TRIGGER` / `CHECKER` / `CLOSE` 均为 count `1`，waiver
  count `0`；Phase6C shadow clean，`mismatch=0`、`waived_future=0`。
- L2TLB fine counters 覆盖到 `i_alloc=104`、`d_load_alloc=162`、
  `d_store_alloc=190`、`reqq_grant=456`、`multi_req=668`、
  `reqq_pfu_conflict=423`、`ptw_reqq_conflict=2`、`tlbop_reqq_conflict=9`、
  `ptw_reqq_pfu_conflict=1`、`tlbop_reqq_pfu_conflict=5`。

最新状态：

1. L1DTLB MB WFG race：不再作为 open DUT/refactor blocker。已按用户确认的
   DUT contract 修正 checker/SVA，focused WFG flush+grant 覆盖通过。
2. L1DTLB checker 仍保持硬约束：只有 existing-WFG grant 可在 flush 周期发出；
   新 allocation side effect、非匹配 `eid/vpn/type` 或非 WFG request 仍会失败。
3. L2TLB REQQ/arb：focused closure 通过，当前 L2 侧未见新的 checker 或 DUT 风险。
4. PTW 覆盖本轮仍未继续推进，符合当前任务范围；后续重点仍是 TWU lane/stage
   directed pressure、SysMap/PMP/MAEE explicit functional gaps，以及 official
   URG 工具闭环。

### 2026-06-09 L2 REQQ depth closure 与当前 L1/L2 目标判断

继续针对 L2TLB `cg_l2_reqq` explicit gap 补 focused 场景。普通顺序压力
`test_l2_bank_conflict_and_reqq_full` 可以 clean pass，但 `L2TLB_REQQ_FINE`
显示 `max_occ=1`，不能覆盖 `d5_9`。TLBP/TLBWR 短窗口探索也只能到
`max_depth=4`，说明需要连续的合法 arb block，而不是简单增加 DTLB miss 数量。

最终采用 L1DTLB directed raw LSU `INV_ASID_ALL` 触发长 INVASID TLBOP 扫描，
同时发出 8 个 DTLB miss，使 REQQ 在 `tlboper_on` 期间积压到高深度。该方案是
合法外部 stimulus，未 force 内部信号，也未修改 DUT RTL。

执行命令：

```sh
make comp COV_FORCE_REBUILD=1 UVM_CONFIG_DB_TRACE=0
make run_cov TEST_NAME=test_mmu_l1dtlb_dtlb_l2_reqq_depth_001 SEED=97101 \
  RUN_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/run_l2_reqq_depth_focused_invasid \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_l2_reqq_depth_focused_invasid.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=20000000
bash scripts/check_sim_status.sh output/logs/test_mmu_l1dtlb_dtlb_l2_reqq_depth_001_97101_cov.log
python3 scripts/phase14_coverage_hotspots.py \
  --vdb-root output/coverage/phase14_l1_l2_current_trend_inputs_invasid \
  --report-dir output/coverage/phase14_l1_l2_current_trend_report_invasid \
  --top 40
```

结果：

- Focused REQQ depth run PASS：`UVM_ERROR=0`、`UVM_FATAL=0`、
  `hard_failures=0`。
- `L2TLB_REQQ_FINE`: `d_load_alloc=4`、`d_store_alloc=4`、
  `d_entry_grant=8`、`fb_miss_alloc=8`、`max_occ=8`。
- `L2TLB_ARB_FINE`: `tlbop_req=768`、`reqq_req=1029`、
  `tlbop_reqq_conflict=255`、`multi_req=255`。
- `cg_l2_reqq` 已不再出现在新趋势报告的 functional explicit uncovered
  group/coverpoint/sample 列表中。

新趋势报告：

- 输入目录：
  `output/coverage/phase14_l1_l2_current_trend_inputs_invasid`
- 报告：
  `output/coverage/phase14_l1_l2_current_trend_report_invasid/coverage_hotspots.md`
- VDB 数量：5
- FSM: 77.42% (240/310)
- Toggle: 59.50% (117740/197870)
- Condition: 67.58% (5639/8344)
- Functional: 75.00% (348/464)

对照阶段性目标：

- L1/L2 focused checker/SVA 风险：当前 L1 WFG race、L2 REQQ/arb fine overlap、
  L2 REQQ depth focused run 均 PASS。
- L2 REQQ functional explicit bins：当前已闭合。
- FSM 总体 77.42%，高于阶段性 75% 目标；`x_mmu_l2tlb` 为 81.82%。但
  L1DTLB high MB entry 局部仍有低于 75% 的对象，例如 entry2 为 66.67%，
  entry5/6/7 为 71.43%。
- Overall functional 75.00%，仍低于阶段性 85% 目标。

因此，当前答案是：L1/L2 已关闭本轮最明确的 focused 风险点，尤其是
`cg_l2_reqq`；但按覆盖文档的总 functional 85% 目标，当前还没有达标。下一步
应优先补 `cg_twu_data_ready_per_stage`、`cg_sysmap`、`cg_pmp`、
`cg_twu_mask_cause`、`cg_maee_leaf_level` 和剩余 `cg_l1dtlb` explicit gaps，
同时继续处理 official URG 崩溃问题。

### 2026-06-09 final L1/L2 current-trend target closure

在上面的 L2 REQQ depth 闭合之后，继续补当前 functional 目标的最低风险缺口：

- `scripts/phase14_merge_parallel_coverage.py` 修正 XML fallback 解析，跳过
  VDB XML 中标记为 `illegal="1"` 的 covergroup bins，避免把 illegal bins
  计入 diagnostic denominator。
- 新增 `test_sysmap_cfg_coverage_sweep`，只闭合 `sysmap_cfg_agent`
  configuration mirror covergroup。该测试不 force SysMap RTL，不作为
  `ct_mmu_sysmap` DUT 行为 signoff 证据。
- 新增 `test_mmu_pmp_cfg_coverage_sweep`，闭合 PMP flag interface/agent
  covergroup 的 port 和 flag tuple 缺口。
- 新增 `test_ptw_rsp_delay1_coverage_001` 和
  `test_ptw_rsp_delay0_coverage_001`。其中 delay0 对应 covergroup 统计中的
  `cg_rsp_delay_range.d1`，因为 responder 在 accept 后零等待驱动响应时，
  monitor 侧看到的 accept-to-response 周期差为 1。

执行命令：

```sh
make comp COV_FORCE_REBUILD=1 UVM_CONFIG_DB_TRACE=0
make run_cov TEST_NAME=test_sysmap_cfg_coverage_sweep SEED=97101 \
  RUN_DIR=output/run_sysmap_cfg_coverage_sweep_current \
  COV_DB_DIR=output/coverage/probe_cfg_sweeps_current.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=8000000
make run_cov TEST_NAME=test_mmu_pmp_cfg_coverage_sweep SEED=97101 \
  RUN_DIR=output/run_pmp_cfg_coverage_sweep_current \
  COV_DB_DIR=output/coverage/probe_cfg_sweeps_current.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=8000000
make run_cov TEST_NAME=test_ptw_rsp_delay1_coverage_001 SEED=97101 \
  RUN_DIR=output/run_ptw_rsp_delay1_coverage_current \
  COV_DB_DIR=output/coverage/probe_cfg_sweeps_current.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000
make run_cov TEST_NAME=test_ptw_rsp_delay0_coverage_001 SEED=97101 \
  RUN_DIR=output/run_ptw_rsp_delay0_coverage_current \
  COV_DB_DIR=/home/st-wangjun/project/mmu_verification/mmu_verification/output/coverage/probe_ptw_rsp_delay0_current.vdb \
  UVM_ERR_ONLY=1 UVM_CONFIG_DB_TRACE=0 TIMEOUT=12000000
bash scripts/check_sim_status.sh \
  output/logs/test_sysmap_cfg_coverage_sweep_97101_cov.log \
  output/logs/test_mmu_pmp_cfg_coverage_sweep_97101_cov.log \
  output/logs/test_ptw_rsp_delay1_coverage_001_97101_cov.log \
  output/logs/test_ptw_rsp_delay0_coverage_001_97101_cov.log
python3 scripts/phase14_coverage_hotspots.py \
  --vdb-root output/coverage/phase14_l1_l2_current_trend_inputs_final \
  --report-dir output/coverage/phase14_l1_l2_current_trend_report_final \
  --top 40
```

注意：前三个 focused run 使用相对 `COV_DB_DIR` 时，实际 testdata 写在各自
`RUN_DIR/output/coverage/probe_cfg_sweeps_current.vdb` 下；最终趋势输入目录已链接
这些实际 VDB。后续复现建议使用绝对 `COV_DB_DIR`。

结果：

- 4 个新增 focused run 均 PASS：`UVM_ERROR=0`、`UVM_FATAL=0`、
  `hard_failures=0`。
- 最终趋势输入：
  `output/coverage/phase14_l1_l2_current_trend_inputs_final`
- 最终趋势报告：
  `output/coverage/phase14_l1_l2_current_trend_report_final/coverage_hotspots.md`
- VDB 数量：9。
- FSM: 77.42% (240/310)。
- Toggle: 59.58% (117896/197870)。
- Condition: 67.63% (5643/8344)。
- Functional: 85.10% (394/463)。

当前结论：

- 按本覆盖文档当前阶段性目标，Functional 85%+ 已达到。
- L1/L2 focused 风险点仍保持 clean：L1 WFG flush/grant checker/SVA、L2
  REQQ/arb fine overlap、L2 REQQ depth 均为 PASS。
- 剩余 explicit gaps 仍包括 `cg_twu_data_ready_per_stage`、`cg_twu_mask_cause`、
  `cg_maee_leaf_level`、`cg_ifu_req`、`cg_l1dtlb` 等；这些是下一轮质量提升项，
  但不再阻塞当前 85% functional 目标。
- 最终 signoff 仍必须基于 official Synopsys URG report；本节使用的 XML
  hotspot report 是诊断/趋势证据。

## C1.2 + C1.3 Structural exclusion formalization and toggle/FSM gap analysis

本节记录在 `MMU-P14-ISSUE-022` 下对 official `phase14_merged.vdb` 做的
结构化排除（toggle + FSM reset-path）以及对剩余 toggle/FSM gap 的分类。
所有排除仅针对 *structurally-unreachable* 对象；任何 *functional/behavioral*
uncovered 项均不排除，改为列入后续定向激励工作清单。

参考文档：

- `doc/archive_merged_20260607/MMU_Phase14_IssueTracker.md` (ISSUE-022)
- `doc/archive_merged_20260607/MMU_Phase14_SignoffMatrix.md` (S3/S5)
- `simu/exclude_v4.tgl` (applied URG elfile)
- `simu/exclude_v4.do` (human-readable waiver record + representative
  `coverage exclude` entries)

### C1.1 Toggle structural exclusions (COMPLETE)

排除类别（both 0->1 and 1->0）：

- `cpurst_b` / `rst_b` / `rst_n`：复位网络；功能场景只有 boot 时 0->1，
  1->0 不发生。
- `pad_yy_icg_scan_en`：DFT scan/ICG enable，功能模式恒 0。
- `hpcp_mmu_cnt_en`：performance-counter enable，验证中 gated/tie。

实现：`simu/exclude_v4.tgl`，299 个 DUT 实例。

测量影响（`phase14_merged.vdb`，URG `V-2023.12-SP2`）：

| Metric | Before | After | Delta |
| --- | --- | --- | --- |
| DUT u_dut toggle | 72.09% | 72.34% | +0.25% |
| line/branch/cond/fsm/assert | unchanged | unchanged | 0 |

结论：reset/DFT 排除是正确且标准的，但只占 raw toggle gap 很小比例。剩余
toggle gap 主要来自 address/ASID bit coverage（见 C1.3）。

### C1.2 FSM reset-path transition exclusions (COMPLETE)

#### 方法

1. `urg -full_exclusions fsm` 对 `phase14_merged.vdb` 生成 exclusion 模板。
2. 对每个 uncovered transition，逐个核对 RTL：
   - 状态寄存器块是否仅有 `reset + functional next-state`（无 abort-to-IDLE 分支）。
   - 组合 next-state 块的 WFG/WFC/WT/WRTAG case 是否有到 IDLE 的赋值。
3. 仅当两个条件都确认 *no functional path* 时才排除该 transition。

#### 排除清单（12 个 reset-only transitions）

| Module | FSM | Excluded transition | RTL reset line | Verification |
| --- | --- | --- | --- | --- |
| ct_mmu_tlboper | tlbp_cur_st | PWFG->IDLE | 285 | WFG case 仅 grant/stay |
| ct_mmu_tlboper | tlbr_cur_st | RWFG->IDLE | 345 | WFG case 仅 grant/stay |
| ct_mmu_tlboper | tlbwi_cur_st | TLBOP_WFG->IDLE | 405 | WFG case 仅 grant/stay |
| ct_mmu_tlboper | tlbwr_cur_st | TLBWR_WFG->IDLE | 467 | WFG case 仅 grant/stay |
| ct_mmu_tlboper | tlbwr_cur_st | WRTAG->IDLE | 467 | WRTAG case 仅 complete/stay |
| ct_mmu_tlboper | tlbiasid_cur_st | IASID_RD->IDLE | 566 | RD case 仅 grant/stay |
| ct_mmu_tlboper | tlbiasid_cur_st | IASID_WFC->IDLE | 566 | WFC case 仅 WT/NWT/stay |
| ct_mmu_tlboper | tlbiva_cur_st | IVA_CMP->IDLE | 870 | CMP case 仅 WR/CMPLT/stay |
| ct_mmu_tlboper | tlbiva_cur_st | IVA_RD->IDLE | 870 | RD case 仅 CMP/stay |
| ct_mmu_tlboper | tlbiva_cur_st | IVA_WR->IDLE | 870 | WR case 仅 WT/stay |
| ct_mmu_tlboper | tlbiva_cur_st | IVA_WT->IDLE | 870 | WT case 仅 CMPLT/stay |
| mmu_l2tlb | pfu_cur_st | PFU_CHK->PFU_IDLE | 1347 | CHK case 仅 DENY/OK |

实现：追加到 `simu/exclude_v4.tgl` 的 INSTANCE blocks（`x_ct_mmu_tlboper`
和 `x_mmu_l2tlb`），使用 URG elfile `Fsm <name> + Transition <src>-><dst>`
语法。

测量影响：

| Metric | Before | After | Delta |
| --- | --- | --- | --- |
| DUT u_dut FSM | 80.90% | 86.10% | +5.20% |
| line/branch/cond/toggle/assert | unchanged | unchanged | 0 |

instance-level 确认：`x_ct_mmu_tlboper` 6 个 FSM 中 5 个达到 100%
（tlbp/tlbr/tlbwi/tlbwr/tlbiva），tlbiasid 达到 87.50%（剩余 1 个 functional
gap）；`x_mmu_l2tlb pfu` 达到 83.33%（剩余 1 个 functional gap）。

#### 未排除的 functional FSM gaps（需定向激励）

下列 transition 有 functional code path 但当前激励未覆盖，**不排除**，
列为后续定向 testcase 工作项：

| Module | FSM | Transition | RTL condition | Existing test candidate |
| --- | --- | --- | --- | --- |
| ct_mmu_tlboper | tlbiasid | IASID_WT->IASID_IDLE | line 603: `arb_tlboper_grant && tlb_inv_done` | test_mmu_dir_l2tlb_inv_asid |
| mmu_l2tlb | pfu | PFU_CHK->PFU_DENY | line 1368: `l2tlb_pfu_deny` | 与 ISSUE-020 (L2TLB PFU race) 相关 |
| mmu_l1itlb | ref | WFG->IDLE | line 755: `ifu_mmu_abort && credit_cnt==0` | 需新增 IFU-abort-during-WFG 场景 |
| mmu_l1itlb | ref | WFG->ABT | line 753: `ifu_mmu_abort && credit_cnt!=0` | 同上 |
| mmu_l1dtlb_mb_entry | state_r | STATE_WFG->STATE_IDLE | line 148: `abort_this_cyc && !granted` | 需新增 flush-during-L1D-miss 场景 |
| twu | ptw | TWU_1G_CRS->TWU_IDLE | line 1206: `tlboper_ptw_abort` during 1G crossing | 需新增 PTW-abort-during-crossing 场景 |
| twu | ptw | TWU_2M_CRS->TWU_IDLE | line 1206: `tlboper_ptw_abort` during 2M crossing | 同上 |

共性：均为 **abort/flush-during-miss** 场景。当前 regression 覆盖了 normal
path 和 grant-after-abort path，但未覆盖 abort-before-grant 和 abort-during-
crossing。这些是真实的 DUT 验证盲区，定向 testcase 可以提升质量。

### C1.3 Toggle gap strategy analysis

#### Toggle gap composition (per-module, top contributors)

基于 `phase14_urgReport/modinfo.txt` 的 module-level toggle 统计：

| Module | Uncovered | Total | Pct | Gap category |
| --- | --- | --- | --- | --- |
| mmu_l1itlb | 131 | 385 | 65.97% | VPN/PPN bit coverage (stimulus) |
| ct_mmu_top | 107 | 342 | 68.71% | address/config bit coverage |
| mmu_dut_probes_if | 103 | 422 | 75.59% | per-entry VPN bit toggle |
| ptw | 89 | 214 | 58.41% | address/leaf-type bit coverage |
| twu | 88 | 275 | 68.00% | CSR/crossing bit coverage |
| mmu_l2tlb | 68 | 288 | 76.39% | L2 tag/PPN bit coverage |
| mmu_l1dtlb | 61 | 417 | 85.37% | per-entry VPN bit toggle |
| axi_if | 46 | 47 | 2.13% | **inactive interface instance** |
| ct_mmu_regs | 37 | 102 | 63.73% | CP0 reg bit coverage |
| memory_response_if | 33 | 34 | 2.94% | **inactive interface instance** |

TOP22 合计：992 uncovered / 3574 total = 72.24%。

#### Gap 分类

1. **Inactive interface instances (structural, ~79 bits)**:
   `axi_if` (46 bits at 2.13%) 和 `memory_response_if` (33 bits at 2.94%)
   是 verification IP 接口实例，在当前 MMU-only testbench 中不被 DUT 驱动。
   - 建议：确认这些是 `u_cv_dv_utils_unref_if` 下的未用接口，可加入 elfile
     exclusion（类似 DFT scan enable），或提升 testbench 驱动这些接口。
   - 不得在未确认 signoff scope 前 waiver。

2. **Per-entry VPN/PPN bit toggle (stimulus distribution, ~300+ bits)**:
   `mmu_dut_probes_if`、`mmu_l1itlb`、`mmu_l1dtlb` 的 per-entry VPN bits
   （如 `l1d_entry_vpn[3][23]`）未双向 toggle，因为特定 TLB entry 的特定
   address bit 未在两个方向都被命中。
   - 建议：扩宽 address randomization，确保每个 entry 都见到 0->1 和 1->0
     的 per-bit toggle。这是激励质量问题，不是结构问题。

3. **CP0/config register bit coverage (~100+ bits)**:
   `ct_mmu_regs`、`ct_mmu_top` 的配置寄存器位未全部 toggle。
   - 建议：扩展 CP0 配置 sweep，覆盖所有 MAEE/sysmap/PMP 配置组合。

4. **Real functional bits (needs targeted tests)**:
   部分未 toggle 的 bit 是功能逻辑位，需要特定场景激励。

#### Toggle threshold 现实性评估

当前 Phase14 S3 要求 toggle >= 98%。对于一个包含大量 multi-bit address field
（VPN[25:0]、PPN[21:0]、ASID[8:0]）且每个 TLB entry 独立计数的 MMU 设计，
98% toggle 意味着几乎所有 entry 的所有 address bit 都要双向 toggle——这要求
极宽的 address randomization 且每个 entry 都要充分填充。

基于当前数据，toggle 98% 需要：
- 关闭所有 inactive interface 实例（~79 bits，+~1.5%）
- 每个TLB entry 的所有 VPN/PPN bit 双向 toggle（~300+ bits，+~6%）
- 所有 CP0 config bit 全 sweep（~100+ bits，+~2%）
- 剩余 functional bits 定向覆盖

即使全部完成，从 72.34% 提升到 98% 仍需 +25.66%，涉及数千 bit 的覆盖。
建议提交 RTL/verification lead 评估：
- (a) 继续扩宽激励，逐步提升；或
- (b) 将 toggle threshold 分解为 per-module 目标（DUT core 模块 vs interface
  实例），对 inactive interface 给予 structural waiver。

### 当前 official post-exclusion baseline

```
DUT u_dut (authoritative, post simu/exclude_v4.tgl):
  SCORE  LINE   COND   TOGGLE FSM    BRANCH ASSERT
  86.48  96.71  82.63  72.34  86.10  94.13  86.95

tb_top (total, incl testbench):
  85.82  95.56  82.83  70.43  86.10  92.89  87.10
```

所有指标仍低于 Phase14 S3 阈值。后续工作（定向 FSM abort 场景 test +
toggle stimulus 扩展 + inactive interface 排除）由 ISSUE-022 跟踪。
