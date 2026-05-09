# MMU UVM 环境重构 Spec 问卷

## 1. 文档目的

这份文档不是为了复述 RTL，而是为了把当前 `mmu_verification` 里所有会影响 **tests / scoreboard / reference model / monitor** 重构的问题，按“设计问卷”的方式整理出来，供你后续逐项回答。

重构目标是做出一版：

- 基于 `spec`，而不是基于 DUT 现状“抄出来”的验证环境
- 能尽量避免和 DUT 同源偏差的 reference model / scoreboard
- 能明确区分哪些是 `architectural behavior`，哪些只是 `micro-architecture`
- 能让 testcase、monitor、scoreboard 的行为边界都提前说清楚

## 2. 为什么要重写这份清单

上一版清单的问题是：

- 问题方向是对的，但不少表述还偏“标题化”
- 一些问题没有明确说明“到底要你回答到哪一层”
- 一些问题没有明确“如果不回答，会影响哪一块验证环境”
- 表格适合扫读，但不适合逐项填写有上下文的设计答案

所以这版改成更适合设计者逐项填写的问卷格式。

## 3. 当前代码里已经确认的耦合点

下面这些是本次梳理时已经确认的事实，也是后续回答问题时要重点注意的背景：

1. `page_table_builder` 同时被 `ptw_mem_responder` 和 `mmu_ref_model` 使用。
   这意味着当前 responder 和 reference model 共用同一份 page table state，不独立。

2. `mmu_ref_model` 目前只把 4K Sv39 主路径走通。
   `2M/1G`、`PMP`、`SysMap`、`A/D`、`invalidate`、`fault priority` 都还没有完整建模。

3. `mmu_translation_sb` 里存在多处按 DUT 微结构写的特殊处理。
   例如 `dtlb_expt_match` waive、`dut_pa == req_vpn` 签名式 waive、`Pipe1 STAMO` 旁路路径特殊判断、`Pipe2` 只 count 不严格 compare。

4. `mmu_invalidate_sb` 目前只做“事件计数”，没有验证“失效后真的不会命中 stale entry”。

5. `ifu_monitor` 假设 IFU 协议是严格 `1 outstanding`。

6. `lsu_monitor` 假设 LSU `pipe0`、`pipe1` 各自严格 `1 outstanding`，且可以按 FIFO 相关联 req/rsp。

7. `sysmap_cfg_agent` 通过 `force/release` whitebox 注入 SysMap 配置。

8. `PMP` flag 编码在当前代码里不一致。
   `pmp_txn.svh`、`pmp_sequences.svh`、`mmu_ref_model.check_pmp()` 的理解没有统一。

## 4. 如何填写

每个问题都按下面格式组织：

- `优先级`
  - `P0`：不回答就没法正确重构主路径
  - `P1`：建议第一轮主路径后尽快回答
  - `P2`：增强项/二期完善项

- `影响组件`
  - `TEST`：testcase / sequence / stimulus 设计
  - `SB`：scoreboard 比较规则
  - `RM`：reference model 行为定义
  - `MON`：monitor 的采样时机、相关联规则、丢弃规则

- `为什么要问`
  - 说明当前环境为什么需要这个答案

- `你至少需要回答`
  - 不是泛泛而谈，而是后续写代码时必须用到的具体口径

- `当前代码里的默认假设`
  - 说明现在代码默认站在哪一边，方便你决定是否保留

- `你的答案`
  - 你后续直接填在这里即可

## 5. 建议回答方式

如果某个问题适用，建议你的回答尽量覆盖这 6 个维度：

1. 这个行为作用于哪些通道/场景
2. 它的输入条件或触发条件是什么
3. 它的输出结果应该是什么
4. 如果多个条件同时出现，优先级怎么定
5. in-flight / replay / reset / invalidate 时是否有例外
6. 哪些是必须验证的 spec 行为，哪些只是实现细节，不需要黑盒验证

如果某个问题不适用，也建议明确写：

- `不适用`
- `为什么不适用`
- `验证环境里可以如何简化`

## 6. 建议先回答哪些问题

建议先回答所有 `P0`，优先顺序如下：

1. `MMU enable / SATP / privilege`
2. `PTE / page size / permission / A/D / fault priority`
3. `IFU / LSU / Pipe2 / STAMO` 的外部可观察语义
4. `PMP / SysMap / MAEE / attribute` 的合成规则
5. `invalidate / TLB / ASID / global page`
6. `PTW / bus_error / replay / reset`

---

## 7. 总体定义与签核口径

### G-01 签核金标准
优先级：`P0`  
影响组件：`TEST / SB / RM`

为什么要问：  
当前环境默认“仿真不报错就算通过”，但没有定义验证环境到底要对哪些外部行为负责。

你至少需要回答：
1. 对这个 MMU，功能签核时你希望黑盒验证保证什么。
2. 只需要保证 `VA -> PA/fault`，还是还要保证 `sec/ca/buf/sh/so`、invalidate 后行为、bus error、并发行为。
3. 哪些行为必须由 scoreboard 比对，哪些只需要 SVA/coverage/whitebox 观察。
4. 哪些行为即使 DUT 和 TB 现在都没实现，也必须作为“spec target”保留下来。

当前代码里的默认假设：
- 主 scoreboard 以翻译结果为核心
- 一些属性位和特殊路径并没有严格纳入签核

你的答案：

### G-02 哪些行为必须按 spec 严格比较
优先级：`P0`  
影响组件：`SB / RM`

为什么要问：  
当前 `translation_sb` 里有多处 DUT-specific waive，如果不先定义哪些行为必须严格比较，就无法决定哪些 waive 应删掉，哪些可以保留。

你至少需要回答：
1. 哪些对外行为属于 `architectural contract`，必须严格 compare。
2. 哪些行为允许是 implementation-specific，只要不影响架构结果即可。
3. 哪些现有 waiver 是“临时绕过 RTL 缺口”，哪些是“本来就不该黑盒比较”。
4. 对 `replay / expt CAM / pre_sel / STAMO overlay` 这类现象，最终是进入黄金模型，还是从黄金比较中隔离出去。

当前代码里的默认假设：
- `dtlb_expt_match` 可以 waive
- `dut_pa == req_vpn` 某些 fault 场景可以 waive
- `Pipe1 STAMO` 路径可以跳过 ref PPN compare

你的答案：

### G-03 这次重构要覆盖哪些外部通道
优先级：`P0`  
影响组件：`TEST / SB / RM / MON`

为什么要问：  
现在代码按 IFU、LSU p0/p1、pipe2、STAMO、invalidate、CP0 等路径拆散了，但没有先定义“哪些对外端口是必须闭环验证的”。

你至少需要回答：
1. 这次重构要正式覆盖哪些外部通道。
2. 每个通道是做强 compare、弱 compare、只统计、还是只看协议。
3. `IFU / LSU pipe0 / LSU pipe1 / Pipe2 / STAMO / CP0 TLB 操作 / PTW memory side` 分别在验证上要做到什么程度。
4. 哪些通道属于一期必须完成，哪些可以二期补。

当前代码里的默认假设：
- 主 compare 以 IFU + LSU p0/p1 为主
- Pipe2 只 count 或 partial compare
- STAMO 没有独立 checker

你的答案：

### G-04 一期与二期范围划分
优先级：`P1`  
影响组件：`TEST / SB / RM`

为什么要问：  
当前仓库已经有不少 test/vseq，但主线能力不完整。重构时需要决定是先把主路径闭环，还是直接同时带 huge page / invalidate / perf / error injection。

你至少需要回答：
1. 一期必须闭环哪些功能。
2. 二期可接受晚一点完成哪些功能。
3. 哪些已知 spec 功能虽然复杂，但不能推迟。
4. 是否接受先把 `4K + IFU/LSU + page fault + basic deny` 做稳，再扩展其他能力。

当前代码里的默认假设：
- 目前是增量 Phase 风格搭建，并不是一次性按完整 spec 收敛

你的答案：

### G-05 RTL 偏离 spec 时 TB 站哪一边
优先级：`P1`  
影响组件：`TEST / SB / RM`

为什么要问：  
当前文档里混有“spec 目标”和“RTL 现状”，如果不明确站位，reference model 很容易被 RTL 现状带偏。

你至少需要回答：
1. 对已知 RTL 偏离 spec 的点，TB 是按 spec 抓 bug，还是先按 RTL 现状跑通。
2. 如果某处暂时按 RTL 现状建模，是否要在文档里保留“最终 spec 目标”。
3. 是否允许同一功能先有 `spec mode` 和 `rtl-compat mode` 两套 checker 口径。

当前代码里的默认假设：
- 目前不少逻辑是为了先兼容 DUT 现状

你的答案：

---

## 8. MMU 使能、SATP、权限上下文

### M-01 支持哪些 paging mode
优先级：`P0`  
影响组件：`RM / TEST / SB`

为什么要问：  
当前 `mmu_ref_model` 只明确建了 `Bare` 和 `Sv39`。如果 DUT 还有其他 mode 或非法 mode 行为，reference model 必须知道。

你至少需要回答：
1. 规范上支持哪些 SATP mode。
2. 这些 mode 分别对应什么行为。
3. 不支持/非法 mode 时，MMU 的对外行为是什么。
4. 对 IFU/LSU/Pipe2 来说，不支持 mode 是否一致。

当前代码里的默认假设：
- `mode==0` 认为 Bare
- `mode==8` 认为 Sv39
- 其他 mode 基本没建模

你的答案：

### M-02 active SATP 的选择机制
优先级：`P0`  
影响组件：`RM / TEST / MON / SB`

为什么要问：  
当前 ref model 虽然有 `satp0/satp1` 和 `m_satp_sel`，但没有明确“什么时候用 satp0，什么时候用 satp1”。

你至少需要回答：
1. active SATP 由哪个控制源决定。
2. 这个选择是全局的，还是按通道/上下文/线程区分。
3. active SATP 的变化是组合生效、拍边生效，还是某个完成信号后生效。
4. SATP 切换时，对 in-flight 请求是否使用旧 SATP 还是新 SATP。
5. IFU、LSU、Pipe2、PTW 自身是否都看同一个 active SATP。

当前代码里的默认假设：
- 只是假设 `m_satp_sel` 已经正确表示当前使用哪一个 SATP

你的答案：

### M-03 MMU 真正的 enable 条件
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
当前 ref model 用 `(satp_mode==Sv39) && effective_priv!=M` 近似计算 `m_mmu_en`，但这可能不够。

你至少需要回答：
1. MMU enable 是否只由 `SATP.mode` 和 privilege 决定。
2. `ptw_en / no_op / maee / cskyee / 其他 CSR` 是否也会改变 enable 语义。
3. IFU 和 LSU 的 `mmu_en` 是否必须一致。
4. Pipe2 / STAMO / PTW 自身是否使用同一口径的“MMU enabled”。

当前代码里的默认假设：
- `effective_priv != M` 且 `mode == Sv39` 时认为 MMU enabled

你的答案：

### M-04 MPRV/MPP 对不同访问的影响
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
当前 ref model 只对 `acc != FETCH` 时让 `MPRV` 生效，但这只是常见处理，不一定完全等价于你这个 DUT 的 spec。

你至少需要回答：
1. `MPRV/MPP` 分别影响哪些访问类型。
2. IFU fetch 是否永远不受 `MPRV` 影响。
3. LSU load/store 是否都受 `MPRV` 影响。
4. Pipe2 prefetch 应按 load 看、按 fetch 看，还是不受 `MPRV` 影响。
5. PTW 自己访问 page table 时看的是哪一级 privilege。

当前代码里的默认假设：
- `MPRV` 只在非 fetch 的 translation 权限判断中生效

你的答案：

### M-05 MXR/SUM 的准确语义
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
这些位对 permission check 是核心输入。如果这里口径不准，reference model 的 fault 结论会系统性错误。

你至少需要回答：
1. `MXR` 是否完全按标准 Sv39：load 可读 execute-only 页。
2. `SUM` 是否完全按标准 Sv39：S-mode 访问 U-page 的控制。
3. 它们对 IFU/LSU/Pipe2 的适用范围是否一致。
4. 是否有实现裁剪、例外、或与标准不同的边界行为。

当前代码里的默认假设：
- `LOAD` 时 `MXR` 可以让 `X=1,R=0` 的页可读
- `SUM=0` 时 S-mode 访问 U-page fault

你的答案：

### M-06 no_op 的准确语义
优先级：`P1`  
影响组件：`RM / TEST / SB`

为什么要问：  
当前 ref model 把 `no_op` 当完全透明 bypass，但它也可能只是停掉内部流程，或影响 fault/attribute 生成。

你至少需要回答：
1. `no_op` 打开后，地址是否直接旁路。
2. fault 检查是否也被旁路。
3. 属性位是否仍然要有效。
4. invalidate / TLB 状态是否还会更新。

当前代码里的默认假设：
- `no_op=1` 等价于完全 bypass translation

你的答案：

### M-07 ptw_en=0 的语义
优先级：`P1`  
影响组件：`RM / TEST / SB`

为什么要问：  
当前 `ptw_en` 只是被记录，没有完整行为建模。

你至少需要回答：
1. 当 TLB hit 时，`ptw_en=0` 是否还允许正常返回。
2. 当 TLB miss 时，`ptw_en=0` 的行为是什么。
3. 是 stall、fault、bypass，还是 simply no refill。
4. 对 IFU/LSU/Pipe2 是否一致。

当前代码里的默认假设：
- 只记录 `ptw_en`，不真正参与结果判定

你的答案：

### M-08 icg_en / cskyee 是否影响功能语义
优先级：`P1`  
影响组件：`RM / TEST`

为什么要问：  
如果这些位只是实现细节，就不该进 reference model；如果会改变对外行为，就要进入模型。

你至少需要回答：
1. 这两个控制位是否会影响对外可观察功能。
2. 如果会影响，影响哪些信号、哪些通道。
3. 如果不会影响，是否可以明确归类为“黑盒验证不关心”。

当前代码里的默认假设：
- 当前 TB 基本把它们当“环境配置位”而不是功能判定输入

你的答案：

### M-09 CP0 侧功能是否纳入这次重构
优先级：`P1`  
影响组件：`TEST / SB / RM`

为什么要问：  
`cp0_txn` 已支持很多操作，但当前黄金模型和 testcase 基本没全面利用这些能力。

你至少需要回答：
1. `mir/mel/meh` 是否属于当前验证范围。
2. CP0 读写回读需要验证哪些行为。
3. `CP0_TLB_ALL_INV` 是否只看 done，还是还要验证功能效果。
4. 哪些 CP0 功能必须一期纳入，哪些可以延后。

当前代码里的默认假设：
- CP0 主要用于驱动 SATP 和全局 invalidation

你的答案：

---

## 9. VA/PA 基本语义与外部比较口径

### A-01 非 canonical VA 的规范行为
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
如果非法 VA 的 fault 口径不明确，黑盒 checker 无法区分是 page fault、access fault 还是其他异常。

你至少需要回答：
1. 什么样的 VA 算非法/非 canonical。
2. IFU、LSU、Pipe2 对非法 VA 的行为是否一致。
3. fault 类型应该是什么。
4. fault 时 PA/PPN/属性位是否还有定义。

当前代码里的默认假设：
- 几乎没显式建模非法 canonical 问题

你的答案：

### A-02 外部到底比较完整 PA 还是只比较 PPN
优先级：`P0`  
影响组件：`SB / RM`

为什么要问：  
当前 scoreboard 实际比较的是 `PPN`，没有比较页内 offset。如果 spec 需要完整 PA，这就不够。

你至少需要回答：
1. IFU/LSU/Pipe2 外部返回的是完整 PA 还是仅 page number。
2. 页内 offset 是否永远由 VA 透传。
3. 是否存在某些通道只输出 page base、另一些输出完整 PA 的情况。
4. 未来 scoreboard 应比较哪一级粒度。

当前代码里的默认假设：
- `pa` 字段本质上被当成 PPN compare

你的答案：

### A-03 MMU off / Bare / bypass 时 VA->PA 的定义
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
一旦 MMU 关闭，整个参考模型的核心规则会切换。

你至少需要回答：
1. MMU off 时 PA 的计算方式。
2. 是零扩展、符号扩展、直接截断，还是别的规则。
3. IFU、LSU、Pipe2 是否一致。
4. 此时是否还做 PMP/SysMap/属性位判断。

当前代码里的默认假设：
- `PA = zero-extend(VA[38:0])`

你的答案：

### A-04 fault 时外部 `pa/ppn` 是否有定义
优先级：`P0`  
影响组件：`SB / RM`

为什么要问：  
当前 LSU scoreboard 里已经因为这个问题引入了特殊 waiver。

你至少需要回答：
1. 当 translation fault 发生时，外部 `pa` 是否有架构定义。
2. 是否允许返回 VPN、旧值、无意义值、实现相关值。
3. 不同 fault 类型是否有不同 `pa` 规则。
4. IFU、LSU p0/p1、Pipe2 是否一致。

当前代码里的默认假设：
- 某些 LSU fault 场景会看到 `dut_pa == req_vpn`

你的答案：

### A-05 哪一拍的结果才算可比较
优先级：`P1`  
影响组件：`MON / SB`

为什么要问：  
monitor 必须知道在哪个握手点把输出当成“最终结果”，否则可能拿到中间态。

你至少需要回答：
1. 对每个通道，什么条件代表 response valid。
2. 只有 `*_vld` 那拍才比较，还是 fault/stall 也要采样。
3. 如果同一请求会出现多拍状态变化，哪一拍是最终 compare 点。
4. 如果 fault 时没有 `*_vld`，那 compare 入口应该改成什么。

当前代码里的默认假设：
- 以 `pavld/pa*_vld` 为主 compare 触发点

你的答案：

### A-06 fault 外部编码的统一口径
优先级：`P1`  
影响组件：`SB / RM`

为什么要问：  
IFU 用 `pgflt/deny`，LSU 用 `pgflt/access_fault`，Pipe2 更不完整。要重构 scoreboard，必须统一 fault taxonomy。

你至少需要回答：
1. 每个外部 fault 信号各自代表什么。
2. 哪些 fault 原因被折叠到一个外部位。
3. 哪些 fault 必须区分。
4. Pipe2 是否存在 fault 编码，若存在，如何与 IFU/LSU 对齐。

当前代码里的默认假设：
- IFU 和 LSU 只是局部合成 `dut_fault`

你的答案：

---

## 10. PTE、页表、页大小、A/D、地址翻译规则

### PTE-01 支持哪些页大小
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
当前 builder/ref model 对 `2M/1G` 还是 stub，是否必须纳入第一版直接决定建模深度。

你至少需要回答：
1. 规范上支持哪些页大小。
2. IFU、LSU、Pipe2 是否都支持同样的页大小。
3. huge page 是否只是命中已有 TLB 条目，还是 PTW/page walk 也要完整支持。
4. huge page 是否必须一期进入主回归。

当前代码里的默认假设：
- 4K 完整
- 2M/1G 暂未真正支持

你的答案：

### PTE-02 2M/1G huge page 的对齐要求
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
huge page 的对齐和 lower PPN bits 规则，直接影响 `page fault` 判定。

你至少需要回答：
1. 2M/1G 页对应哪些 PPN bits 必须为 0。
2. 若不满足要求，报什么 fault。
3. fault 类型是否区分 IFU/LSU。
4. 这种 fault 是 page fault、access fault，还是实现定义。

当前代码里的默认假设：
- huge page 对齐错误没有真正建模

你的答案：

### PTE-03 PTE 各 bit 的准确语义
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
当前 ref model 只建了最基本的 `V/R/W/X/U/G/A/D` 语义，reserved/RSW/其他位还不完整。

你至少需要回答：
1. 各 bit 在这个 MMU 中的实际语义。
2. 哪些 bit 真正实现。
3. 哪些 bit 被忽略。
4. 哪些 bit/组合一旦非法必须 fault。

当前代码里的默认假设：
- 标准 Sv39 最小子集

你的答案：

### PTE-04 非叶 PTE 的约束
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
非叶 PTE 的 bit 规则往往和叶 PTE 不同，reference model 必须分清楚。

你至少需要回答：
1. 非叶 PTE 上哪些位必须为 0。
2. 非叶 PTE 上哪些位即使为 1 也忽略。
3. 非叶 PTE 上哪些非法组合必须 fault。
4. 若非叶 PTE 带有 `A/D/U/G/RSW/reserved`，各自怎么处理。

当前代码里的默认假设：
- 只处理了 `V/R/W/X` 的基本路径

你的答案：

### PTE-05 A/D 位的准确行为
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
这是当前 ref model 里最明显的未定点之一。A/D 是 warning 还是 fault，会彻底改变 checker 逻辑。

你至少需要回答：
1. `A=0` 时 fetch/load/store 各自应该怎样。
2. `D=0` 时 store 应该怎样。
3. 是硬件自动置位，还是 fault/trap-only。
4. 如果硬件置位，外部是否可观察，需要不需要验证。
5. 如果 fault，fault 类型和优先级是什么。

当前代码里的默认假设：
- `A=0/D=0` 只 warning，不 fault

你的答案：

### PTE-06 G bit 与 ASID / invalidate 的关系
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
后续 invalidate checker 是否正确，很大程度取决于 `G bit` 的处理规则。

你至少需要回答：
1. `G bit` 的语义。
2. global page 是否跨 ASID 生效。
3. `SFENCE.VMA with ASID` 时 global page 是否应该保留。
4. SATP 切换、全局 flush 时 global page 如何处理。

当前代码里的默认假设：
- 这部分几乎还没进入真实 checker

你的答案：

### PTE-07 需要覆盖哪些非法 PTE 场景
优先级：`P1`  
影响组件：`TEST / RM`

为什么要问：  
当前 `inject_fault()` 已经有入口，但 fault 种类和覆盖目标并没有被设计者明确确认。

你至少需要回答：
1. 哪些非法编码必须有 directed test。
2. 哪些非法编码只要 random/coverage 覆盖到即可。
3. 哪些场景你认为必须作为 regression 常驻。
4. 哪些非法编码属于“规范上无定义，可不测”。

当前代码里的默认假设：
- 已经有一些 fault kind，但不一定符合你真正想测的 spec 空间

你的答案：

### PTE-08 reference model 是否还要建 side effect
优先级：`P1`  
影响组件：`RM / SB`

为什么要问：  
reference model 可以只建“纯翻译结果”，也可以顺带建某些规范层 side effect，边界要先定。

你至少需要回答：
1. reference model 是否只需要给 expected translation result。
2. 是否还要建 `A/D` 更新、副作用、leaf-level 属性折叠。
3. 是否需要维护某种架构态以支撑后续 invalidation / context switch 检查。

当前代码里的默认假设：
- 更偏纯软件 walk，而不是完整架构状态机

你的答案：

### PTE-09 是否需要同时维护多 root / 多 ASID 页表态
优先级：`P1`  
影响组件：`TEST / RM`

为什么要问：  
如果要做 context switch / satp 切换 / global page 测试，单 root builder 可能不够。

你至少需要回答：
1. 是否需要同时保留多个页表根的内容。
2. SATP 切换时页表内容是否共享、独立，还是两者都可能。
3. reference model 未来是否需要“多 context 并存”的能力。

当前代码里的默认假设：
- builder 主要按单 root 使用

你的答案：

---

## 11. 权限检查、异常分类、fault 优先级

### E-01 IFU 侧 `pgflt` 与 `deny` 的边界
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
当前 IFU 把 `pgflt | deny` 合成 `dut_fault`，但这会掩盖 fault taxonomy 的细节。

你至少需要回答：
1. `pgflt` 的根因包含哪些。
2. `deny` 的根因包含哪些。
3. 两者能否同时为 1。
4. 若同时满足多个 fault 原因，外部应该怎样编码。
5. IFU 是否可能出现 `pavld=1` 且 `deny=1` 之类组合。

当前代码里的默认假设：
- 只做 fault/no-fault 粗比较

你的答案：

### E-02 LSU 侧 `page_fault` 与 `access_fault` 的边界
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
LSU 的黄金模型和 scoreboard 都要靠这个边界来决定 expected fault type。

你至少需要回答：
1. 哪些场景应落 `page_fault`。
2. 哪些场景应落 `access_fault`。
3. `PMP deny / SysMap deny / bus error / A/D / illegal PTE / illegal VA` 分别落哪一类。
4. 是否存在某些组合由优先级决定最终只报其中一个。

当前代码里的默认假设：
- 只做 `pgflt | access_fault` 合成的粗 compare

你的答案：

### E-03 内部 fault 原因到外部 fault 信号的映射
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
reference model 现在有自己的 `EXC_*` 枚举，但和外部信号并没有严格一一对齐。

你至少需要回答：
1. page permission fail 映射到什么外部 fault。
2. invalid PTE / reserved encoding 映射到什么外部 fault。
3. PMP deny / SysMap deny 映射到什么外部 fault。
4. PTW bus error 映射到什么外部 fault。
5. illegal VA 映射到什么外部 fault。

当前代码里的默认假设：
- `EXC_*` 只是内部枚举，未完全对应 DUT 对外编码

你的答案：

### E-04 PTW bus error 的对外行为
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
bus error 是当前主路径里最大的功能缺口之一。

你至少需要回答：
1. PTW memory side 哪些组合合法：`data_vld`、`bus_error`、两者同时为 1、两者都为 0。
2. bus error 传到 IFU/LSU 后，对外 fault 信号如何体现。
3. fault 时 `pa` 是否有定义。
4. 是否有 retry/replay 行为。

当前代码里的默认假设：
- 只在枚举里预留了 `BUS_ERROR`

你的答案：

### E-05 fault priority 总表
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
一旦多个 fault 同时满足，黄金模型必须能唯一决策 expected result。

你至少需要回答：
1. illegal VA、illegal PTE、page permission、A/D、PMP deny、SysMap deny、bus error、other internal fault 的优先级顺序。
2. 这个优先级是否对 IFU/LSU/Pipe2 完全一致。
3. 若某些 fault 在不同通道优先级不同，也请明确写出。

当前代码里的默认假设：
- 没有完整优先级表

你的答案：

### E-06 Pipe2 prefetch 的权限口径
优先级：`P1`  
影响组件：`RM / SB`

为什么要问：  
当前 ref model 把 prefetch 当 `ACC_PFU`，但具体权限规则其实没有真正定义。

你至少需要回答：
1. Pipe2 是按 fetch 权限、load 权限，还是独立 prefetch 权限检查。
2. 若权限不通过，是否对外报告 fault。
3. 若不报告 fault，是 silent drop、还是别的可观察行为。

当前代码里的默认假设：
- 更接近“按 load 类检查”

你的答案：

### E-07 fault 时 `*_vld` 是否仍拉高
优先级：`P1`  
影响组件：`MON / SB`

为什么要问：  
monitor 的 compare 触发点与这个问题直接绑定。

你至少需要回答：
1. fault response 是否仍然通过 `pavld/pa*_vld` 表示完成。
2. 如果不通过 `*_vld`，那完成信号是什么。
3. IFU、LSU、Pipe2 是否一致。

当前代码里的默认假设：
- 主要通过 `*_vld` 驱动 compare

你的答案：

### E-08 fault 时属性位是否仍有定义
优先级：`P1`  
影响组件：`SB / RM`

为什么要问：  
如果 fault 时属性位无定义，就没必要把它们纳入 strict compare。

你至少需要回答：
1. fault 时 `sec/ca/buf/sh/so` 是否仍然有规范定义。
2. 若有定义，哪些 fault 下仍应有效。
3. 若无定义，scoreboard 是否可以统一忽略。

当前代码里的默认假设：
- 当前属性位在 fault 场景里基本没有严格 compare

你的答案：

---

## 12. PMP、SysMap、MAEE、属性位合成

### ATTR-01 最终要比较哪些属性位
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
当前 ref model 里绝大部分属性位还是 0，说明“属性 compare 目标”本身还没冻结。

你至少需要回答：
1. IFU/LSU/Pipe2/STAMO 最终各自需要比较哪些属性位。
2. 哪些属性位在某些通道上本来就不存在或不稳定。
3. 哪些属性位属于一期必须闭环，哪些可以二期补。

当前代码里的默认假设：
- `sec/ca/buf/sh/so` 没有完整建模

你的答案：

### ATTR-02 SysMap `flg[4:0]` 的精确定义
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
如果不先把 bit 定义讲清楚，reference model 没法把 SysMap 输出映射成最终属性。

你至少需要回答：
1. `flg[4:0]` 每一位的含义。
2. 它与 `sec/ca/buf/sh/so/deny` 的对应关系。
3. 是否有某些 bit 仅内部使用，不对外反映。

当前代码里的默认假设：
- 只记录了 `flg[4:0]`，没有真正参与翻译结果

你的答案：

### ATTR-03 PTE / SysMap / PMP / MAEE 如何合成最终属性
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
这是 reference model 里“最终输出属性”的核心规则。

你至少需要回答：
1. 最终属性位来自哪些来源。
2. 这些来源之间是覆盖、与、或、优先级选择，还是分场景使用。
3. 若多个来源给出冲突属性，最终结果怎么决定。
4. deny 与属性位的先后关系是什么。

当前代码里的默认假设：
- 目前几乎没有真正合成逻辑

你的答案：

### ATTR-04 SysMap region match 规则
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
`lookup_sysmap()` 现在只做简单命中，不知道多命中时怎么选。

你至少需要回答：
1. SysMap 是 first-hit、highest-priority、longest-mask，还是其他匹配规则。
2. 多 region 同时命中时如何选。
3. 无命中默认属性是什么。
4. region enable 和 mask 的组合规则是什么。

当前代码里的默认假设：
- 线性扫描，命中第一个 enable 的 region

你的答案：

### ATTR-05 MAEE 的准确作用
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
当前 `maee` 在 ref model 里只是个 bit，没有落到行为。

你至少需要回答：
1. MAEE 控制什么。
2. 它是否改变 SysMap 是否参与。
3. 它是否改变最终属性来源。
4. 它是否影响地址翻译本身、页大小、跨界处理、fault 类型。

当前代码里的默认假设：
- 仅保存，不参与最终决策

你的答案：

### ATTR-06 PMP flag 编码与 allow/deny 语义
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
这是当前代码里最明显的不一致点之一，不先统一就没法改 responder、ref model 和 test。

你至少需要回答：
1. `pmp_mmu_flg[3:0]` 的 bit 排列是什么。
2. 每一位表示 allow 还是 deny。
3. 是否有 valid 位、lock 位、fetch/read/write 分离位。
4. `0` 和 `1` 分别代表允许还是禁止。
5. “all allow” 的正确编码是什么。

当前代码里的默认假设：
- `pmp_txn.svh` 与 `pmp_sequences.svh` 理解不一致

你的答案：

### ATTR-07 实际需要建模多少个 PMP 端口
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
当前文档里既有 5 port 也有 8 port 的说法，UVM responder 也是按 8 port 组织的。

你至少需要回答：
1. 这个 MMU 的 spec target 是多少个 PMP port。
2. 当前 RTL 实际有多少个对 MMU 可见的 PMP port。
3. 验证环境应该按 spec 建模，还是按当前 RTL 可达端口建模。
4. 若 spec port 与 RTL port 不一致，后续 checker/coverage 怎么处理。

当前代码里的默认假设：
- UVM responder/txn 以 8 port 为框架

你的答案：

### ATTR-08 不同访问对应哪个 PMP 端口
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
`check_pmp()` 未来要做 port-aware 判定，这个映射表必须先冻结。

你至少需要回答：
1. IFU 对应哪个 port。
2. LSU pipe0/pipe1 对应哪个 port。
3. Pipe2、STAMO、PTW 各 level/page-walk 对应哪个 port。
4. 是否同一类访问在不同场景会切换 port。

当前代码里的默认假设：
- `check_pmp(pa, acc, port_idx)` 只是空壳

你的答案：

### ATTR-09 PMP 与 SysMap 同时生效时的优先级
优先级：`P1`  
影响组件：`RM / SB`

为什么要问：  
如果 deny 和属性来自不同模块，reference model 必须知道先后关系。

你至少需要回答：
1. PMP 与 SysMap 谁先判定。
2. deny 与 attribute 之间谁覆盖谁。
3. 若两者都给出属性，最终如何合成。

当前代码里的默认假设：
- 当前没有正式优先级定义

你的答案：

### ATTR-10 SysMap 用 whitebox 还是 blackbox 方式验证
优先级：`P1`  
影响组件：`TEST / SB`

为什么要问：  
如果 SysMap 本来没有外部编程口，那 whitebox force 可能是合理的；如果 spec 有正式软件接口，则应尽量按黑盒驱动。

你至少需要回答：
1. SysMap 在本 IP 级验证里是否接受 whitebox force。
2. 你是否希望后续保留 whitebox 配置但 blackbox 比对结果。
3. 是否有必要补一个更贴近软件接口的配置层。

当前代码里的默认假设：
- 通过 `sysmap_cfg_agent` whitebox force/release 注入

你的答案：

---

## 13. IFU 可观察语义

### IFU-01 IFU 是否严格 1 outstanding
优先级：`P0`  
影响组件：`MON / TEST / SB`

为什么要问：  
这决定 `ifu_monitor` 还能不能用现在这种“单 pending req”相关联方式。

你至少需要回答：
1. 协议上是否保证最多 1 个 outstanding fetch translation。
2. miss 期间 `va_vld` 是否可持续保持为 1。
3. response 前 `VA` 是否必须保持不变。
4. 若 fetch 被 kill/flush/abort，是否允许 pending request 直接消失。

当前代码里的默认假设：
- 严格单 outstanding
- miss hold 期间 VA 必须稳定

你的答案：

### IFU-02 IFU req/rsp 的精确配对规则
优先级：`P0`  
影响组件：`MON / SB`

为什么要问：  
即使只有 1 outstanding，也要知道 response 到底对应哪一个 request，以及 kill/retry 时如何对待。

你至少需要回答：
1. req 与 rsp 是否必然一一对应。
2. 是否允许 request 重发/retry。
3. abort/flush 后，是否还可能晚到一个 rsp。
4. 如果晚到 rsp，scoreboard 应比较、忽略，还是报协议错。

当前代码里的默认假设：
- 只要有 pending，就把下一个 `pavld` 绑到该 pending req

你的答案：

### IFU-03 abort 的准确语义
优先级：`P0`  
影响组件：`TEST / MON / SB`

为什么要问：  
abort 场景在 monitor 中被当成 drop，但这不一定是你真正想要的 spec 行为。

你至少需要回答：
1. abort 是“取消当前请求”还是“标记当前请求无效但仍可能完成”。
2. abort 后若 DUT 仍返回结果，是否应被忽略。
3. abort 与 flush/reset 的优先关系。

当前代码里的默认假设：
- abort req 在 `va_vld` deassert 后可以无 rsp 关闭

你的答案：

### IFU-04 IFU 还需要验证哪些外部位
优先级：`P1`  
影响组件：`TEST / SB`

为什么要问：  
当前 IFU 主要只比 `pa/pgflt/deny/sec/ca/buf`，但也许还有其他必须验证的接口语义。

你至少需要回答：
1. 是否还需要比较 `sh/so` 等属性。
2. 是否需要正式验证 hold protocol、timeout、flush 交互。
3. 是否需要检查 `pavld` 与 fault/deny 组合合法性。

当前代码里的默认假设：
- IFU compare 以翻译结果为主

你的答案：

### IFU-05 IFU 主回归必须覆盖哪些场景
优先级：`P1`  
影响组件：`TEST`

为什么要问：  
testcase 重构时需要一个清晰的“IFU 场景最小集合”。

你至少需要回答：
1. 必须覆盖哪些 privilege 组合。
2. 是否必须覆盖 `MXR/SUM/global page/ASID/huge page`。
3. 是否必须覆盖 `abort/flush/invalidate/bus_error/PMP/SysMap deny`。
4. 哪些场景只需要 directed，哪些应进入 random regression。

当前代码里的默认假设：
- 目前以 supervisor 4K 正常路径为主

你的答案：

---

## 14. LSU Pipe0 / Pipe1 可观察语义

### LSU-01 pipe0/pipe1 是否各自严格 1 outstanding
优先级：`P0`  
影响组件：`MON / TEST / SB`

为什么要问：  
这决定 `lsu_monitor` 的 FIFO 相关联模型还能不能成立。

你至少需要回答：
1. pipe0 和 pipe1 是否各自最多 1 outstanding。
2. 两个 pipe 是否可同时各有 1 outstanding。
3. 同一 pipe 是否可能在前一个没完成前接收下一个 req。
4. response 是否可能乱序。

当前代码里的默认假设：
- 每个 pipe 各自严格 1 outstanding

你的答案：

### LSU-02 req/rsp 的配对 key 是什么
优先级：`P0`  
影响组件：`MON / SB`

为什么要问：  
如果后面不是 FIFO 模型，而是按 `id` 或别的 tag 配对，monitor 就要重写。

你至少需要回答：
1. 配对按 `id`、按 pipe 顺序、按 VA，还是按某个外部 tag。
2. `id` 是否在对外协议层有稳定语义。
3. 如果 replay/timeout/retry 出现，配对规则是否改变。

当前代码里的默认假设：
- 每个 pipe 单独 FIFO 即可

你的答案：

### LSU-03 `vabuf` 的规范语义
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
当前 testcase 明确把 `vabuf == va >> 11` 写死了，这很可能是把 DUT 内部要求硬编码进激励。

你至少需要回答：
1. `vabuf` 在 spec 里是否是 architecturally meaningful input。
2. 它是否必须与 VA 某些位严格对应。
3. 如果不对应，DUT 应报协议错、静默错、还是行为未定义。
4. 后续 testcase 是否应该继续显式约束它。

当前代码里的默认假设：
- `vabuf` 必须严格等于 `VA >> 11`

你的答案：

### LSU-04 expt CAM / pre_sel / `dtlb_expt_match` 是否属于黑盒验证范围
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
这是当前 `translation_sb` 最大的 DUT-specific 耦合点之一。

你至少需要回答：
1. 这些现象是不是架构行为。
2. 如果不是，它们是否应该完全从黑盒 compare 中排除。
3. 如果是，它们该如何体现在 reference model 或专用 checker 里。
4. `fault 时 dut_pa=req_vpn` 这种现象是否是规范允许的外部行为。

当前代码里的默认假设：
- 遇到 `dtlb_expt_match` 或某些 signature 时直接 waive

你的答案：

### LSU-05 pipe0 与 pipe1 是否完全对称
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
如果两条 pipe 不对称，reference model 和 testcase 的场景矩阵就不能简单复用。

你至少需要回答：
1. 两条 pipe 在地址翻译语义上是否完全一致。
2. fault、replay、stall、STAMO overlay、权限、attribute 是否完全一致。
3. 是否存在某条 pipe 专属的特殊路径。

当前代码里的默认假设：
- 大部分逻辑按“同模板”处理，只在 Pipe1 对 STAMO 有额外判断

你的答案：

### LSU-06 pipe0/pipe1 主回归最小场景集
优先级：`P1`  
影响组件：`TEST`

为什么要问：  
当前只有 p0 load 和 p1 store 的轻量 sanity，不足以形成系统场景矩阵。

你至少需要回答：
1. 每条 pipe 是否都必须覆盖 load/store。
2. 是否必须覆盖 same-VA 双发、different-VA 双发。
3. 是否必须覆盖 replay、invalidate overlap、flush overlap、reset overlap。
4. 哪些场景必须 directed，哪些适合 random。

当前代码里的默认假设：
- 只做了最基础的正常路径覆盖

你的答案：

### LSU-07 LSU 还需要比较哪些外部结果
优先级：`P1`  
影响组件：`SB / RM`

为什么要问：  
当前 LSU compare 只看 `pa/pgflt/access_fault/sec`，可能不够。

你至少需要回答：
1. 是否还应比较 `ca/buf/sh/so`。
2. 是否要比较某些协议状态位。
3. 哪些结果在某些 fault 场景无定义，可忽略。

当前代码里的默认假设：
- 只比较最核心的翻译和 fault 结果

你的答案：

### LSU-08 `tlb_busy/tlb_wakeup` 是否进入正式验证
优先级：`P1`  
影响组件：`TEST / SB / SVA`

为什么要问：  
当前这些信号只作为 debug/perf 记录，但如果它们有协议含义，就应进入正式验证。

你至少需要回答：
1. 这两个信号是否属于外部协议。
2. 若属于，应该用 scoreboard、SVA 还是 whitebox checker 验证。
3. 它们需要验证哪些性质：时序、one-hot、最终唤醒、无漏唤醒等。

当前代码里的默认假设：
- 不纳入黑盒主 compare

你的答案：

---

## 15. Pipe2 Prefetch 与 STAMO

### P2-01 `va2[27:0]` 的准确语义
优先级：`P0`  
影响组件：`MON / RM / TEST / SB`

为什么要问：  
现在 Pipe2 最大的问题不是 compare，而是“输入语义都还没说清楚”。

你至少需要回答：
1. `va2[27:0]` 对应完整 VA 的哪些位。
2. 是否包含 page offset，还是只表示 VPN。
3. 是否需要从其他信号补全完整虚拟地址语义。
4. 若只给 VPN，checker 应如何定义 expected translation。

当前代码里的默认假设：
- 倾向把 `va2` 当作 `VA[38:12]` 或接近它的东西

你的答案：

### P2-02 Pipe2 是否有 fault 对外语义
优先级：`P0`  
影响组件：`MON / RM / SB`

为什么要问：  
当前 Pipe2 monitor 几乎没有 fault 相关信息，scoreboard 只能 count 或比 PA。

你至少需要回答：
1. Pipe2 是否会对外报告 page fault/access fault/deny/error。
2. 如果会，具体在哪些信号上。
3. 如果不会，prefetch 失败的外部表现是什么。

当前代码里的默认假设：
- Pipe2 fault 语义基本未建模

你的答案：

### P2-03 Pipe2 的权限检查口径
优先级：`P0`  
影响组件：`RM / SB`

为什么要问：  
只有弄清权限口径，reference model 才能知道 prefetch 应该命中、fault 还是静默丢弃。

你至少需要回答：
1. Pipe2 按 fetch、load，还是独立 prefetch 权限检查。
2. 不通过权限时是否有 fault。
3. 若无 fault，是否会 suppress response。

当前代码里的默认假设：
- 近似按 load/prefetch 语义处理

你的答案：

### P2-04 Pipe2 一期是否需要端到端 compare
优先级：`P1`  
影响组件：`TEST / MON / SB`

为什么要问：  
如果一期就要求严格 compare，就必须补 Pipe2 req/rsp 相关联和 fault/attribute 采样能力。

你至少需要回答：
1. Pipe2 一期是否只 count，还是必须真正 compare。
2. 如果 compare，应比较 `PA` 还是 `PA+fault+attribute`。
3. 如果只 count，后续升级目标是什么。

当前代码里的默认假设：
- 只 count 或部分 compare

你的答案：

### ST-01 STAMO 的角色是什么
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
当前 STAMO 既像一类“独立物理地址检查”，又会在 Pipe1 response 上覆盖 PA。必须先明确它的架构角色。

你至少需要回答：
1. STAMO 是独立功能，还是 LSU translation 流的一部分。
2. STAMO 是检查 physical attribute，还是参与 translation 结果选择。
3. 它的结果是否需要独立 scoreboard。

当前代码里的默认假设：
- STAMO 没有独立 checker
- 只在 Pipe1 compare 时被特殊考虑

你的答案：

### ST-02 哪些场景会被 STAMO 覆盖输出 PA
优先级：`P0`  
影响组件：`SB / MON / RM`

为什么要问：  
这决定主 `translation_sb` 是否应该对某些 response 跳过 ref PPN compare。

你至少需要回答：
1. 是只有 Pipe1，还是 Pipe0 也会。
2. 覆盖是常态，还是只在某些 opcode/条件下发生。
3. 覆盖发生时，translation compare 应跳过哪些项。

当前代码里的默认假设：
- Pipe1 某些 response 可能被 STAMO 覆盖

你的答案：

### ST-03 STAMO 通道要验证到什么程度
优先级：`P1`  
影响组件：`TEST / SB`

为什么要问：  
如果它只是 physical attribute check，那 checker 形态和 normal translation 完全不同。

你至少需要回答：
1. STAMO 是否需要比较 deny、属性位、异常。
2. 还是只要验证“指定 PA 被送入正确检查路径”。
3. 是否需要覆盖与 Pipe1 并发、与 invalidate 并发、与 PMP/SysMap 交互。

当前代码里的默认假设：
- `ap_stamo` 没接任何 scoreboard

你的答案：

---

## 16. TLB、ASID、invalidate、CP0 invalidation

### INV-01 invalidate 作用范围
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
如果不知道 invalidate 影响哪些结构，就无法设计真正有意义的 invalidate checker。

你至少需要回答：
1. `SFENCE.VMA` / `CP0_TLB_ALL_INV` 分别影响哪些结构。
2. ITLB、DTLB、L2/JTLB、miss buffer、exception CAM、PDE cache、其他 shadow state 是否都要受影响。
3. 哪些结构立即失效，哪些允许延迟或在途完成。

当前代码里的默认假设：
- invalidate_sb 只看事件本身，不看真实效果

你的答案：

### INV-02 四种 invalidate 类型的精确匹配规则
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
`INV_ALL / INV_VA_ALL / INV_ASID_ALL / INV_VA_ASID` 看起来简单，但真正的匹配规则通常会涉及 `G bit`、page size、ASID 等。

你至少需要回答：
1. `VA` 是按完整 VPN 匹配还是按 page size 粒度匹配。
2. `ASID` 如何参与匹配。
3. `G bit` 如何影响匹配。
4. huge page 与 4K page 的匹配是否有差异。

当前代码里的默认假设：
- 目前只是记录 inv kind 和字段值

你的答案：

### INV-03 如何证明 stale translation 确实消失
优先级：`P0`  
影响组件：`TEST / SB / RM`

为什么要问：  
这是 invalidate checker 最核心的问题。只计数没有签核意义。

你至少需要回答：
1. invalidate 后下一次访问应该出现什么可观察行为。
2. 是必须 miss/PTW，还是只要最终结果与最新页表一致即可。
3. 是否允许命中某种更新后的条目。
4. 对 ITLB/DTLB/L2 是否要分别设计验证口径。

当前代码里的默认假设：
- 尚未真正验证 stale entry 消失

你的答案：

### INV-04 CP0 invalidation 与 LSU SFENCE 的关系
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
当前两个入口都存在，但作用范围和语义没有统一。

你至少需要回答：
1. 两者作用范围是否相同。
2. 若不同，差异在哪。
3. 两者是否都需要功能 checker，还是其中一个只需协议 checker。

当前代码里的默认假设：
- CP0 path 只看 `tlb_done`

你的答案：

### INV-05 `inv_done` 的语义
优先级：`P0`  
影响组件：`MON / SB / TEST`

为什么要问：  
当前只把它当计数事件，但它也可能是“所有结构已完成失效”的关键信号。

你至少需要回答：
1. `inv_done` 表示请求接收，还是功能完成。
2. 是 pulse 还是 level。
3. 若 invalidate 影响多个结构，它是在全部完成后才拉高，还是部分完成即可。

当前代码里的默认假设：
- 只要看到 `inv_done` 就记一次 done

你的答案：

### INV-06 reference model 是否需要维护 TLB shadow
优先级：`P1`  
影响组件：`RM / SB`

为什么要问：  
有两条路线：  
一条是 black-box，只看“之后的访问结果”；  
另一条是维护架构级 TLB state，严格建失效预期。

你至少需要回答：
1. 你更倾向哪条路线。
2. 是否需要 reference model 里真的有 TLB shadow。
3. 如果不做 shadow，invalidate 的签核是否仍然足够。

当前代码里的默认假设：
- `on_tlb_inv()` 还是 TODO

你的答案：

### INV-07 invalidate 与 in-flight 请求的关系
优先级：`P1`  
影响组件：`TEST / RM / SB`

为什么要问：  
这个问题决定 reset/flush/invalidate overlap 场景下 scoreboard 如何判定请求是旧语义还是新语义。

你至少需要回答：
1. invalidate 到来时，已经在途的请求使用旧条目还是新条目。
2. 是否允许完成旧请求，再让后续请求受新规则影响。
3. 是否存在 kill/replay/重新 walk 的机制。

当前代码里的默认假设：
- 还没有显式建模 in-flight invalidate overlap

你的答案：

### INV-08 invalidate 回归场景矩阵
优先级：`P1`  
影响组件：`TEST`

为什么要问：  
即使 checker 写好，也需要设计者明确哪些组合必须出现在主回归里。

你至少需要回答：
1. 是否必须覆盖 same ASID / other ASID。
2. 是否必须覆盖 global page。
3. 是否必须覆盖 huge page。
4. 是否必须覆盖 IFU+LSU 并发、pipe0+pipe1 并发、SATP switch overlap。

当前代码里的默认假设：
- 主要是 inv kind 计数矩阵

你的答案：

---

## 17. PTW、memory response、bus error、并发

### PTW-01 黑盒验证要不要关心 PTW 行为本身
优先级：`P0`  
影响组件：`TEST / RM / SB`

为什么要问：  
reference model 可以只算结果，也可以把某些 walk 行为纳入验证目标，这条边界必须先定。

你至少需要回答：
1. 黑盒主 checker 是否只需保证最终 translation 正确。
2. 是否还要检查某些可观察的 PTW 完成行为、次数、时延、重试。
3. 哪些 PTW 行为是 micro-architecture，不进入黑盒签核。

当前代码里的默认假设：
- 参考模型更像“纯软件 walk”

你的答案：

### PTW-02 PTW memory side 是否支持多 outstanding / 乱序
优先级：`P0`  
影响组件：`MON / TEST / SB`

为什么要问：  
如果 responder/monitor 假设与真实协议不一致，所有与 PTW 相关的 checker 都会错。

你至少需要回答：
1. PTW memory side 最多允许多少 outstanding req。
2. response 是否可乱序。
3. req/rsp 如何相关联。
4. bus_error 与正常 data rsp 是否使用同一套相关联规则。

当前代码里的默认假设：
- 当前能力更接近简单 responder，未充分定义乱序语义

你的答案：

### PTW-03 responder 与 reference model 是否允许共享 page table state
优先级：`P0`  
影响组件：`RM / TEST`

为什么要问：  
这关系到“验证环境是否独立于 DUT”的程度，也关系到后续 bug 注入方式。

你至少需要回答：
1. 你是否接受 responder 和 ref model 共享 spec-level page table state。
2. 如果不接受，是否要拆成独立内存模型和独立黄金模型。
3. 若共享，哪些风险需要通过额外 checker 或 mutation test 补上。

当前代码里的默认假设：
- responder 和 ref model 共用 `page_table_builder`

你的答案：

### PTW-04 `data_vld` 与 `bus_error` 的合法组合
优先级：`P0`  
影响组件：`RM / SB / TEST`

为什么要问：  
这个问题直接决定 PTW memory responder、monitor 和 translation fault 映射。

你至少需要回答：
1. `data_vld=1,bus_error=0` 表示什么。
2. `data_vld=0,bus_error=1` 表示什么。
3. `data_vld=1,bus_error=1` 是否允许，若允许，语义是什么。
4. `data_vld=0,bus_error=0` 在 outstanding 期间是否只是“等待”。

当前代码里的默认假设：
- 这一点尚未冻结

你的答案：

### PTW-05 PTW 的时序/超时/背压是否需要功能验证
优先级：`P1`  
影响组件：`TEST / SVA`

为什么要问：  
有些设计者只关心最终功能正确，有些则要求一定的协议/时延边界也要被验证。

你至少需要回答：
1. 是否需要验证最大响应延迟。
2. 是否需要验证 credit 用尽/backpressure 行为。
3. 是否需要验证 reset 中断后恢复。
4. 这些更适合 testcase、SVA 还是 perf monitor。

当前代码里的默认假设：
- 主要关注功能结果，不太关注 formalized latency contract

你的答案：

### PTW-06 必须覆盖哪些 PTW 冲突场景
优先级：`P1`  
影响组件：`TEST`

为什么要问：  
已有一些 vseq 名字涉及 `thrash/sfence_during_walk`，但还没有正式的 spec 场景矩阵。

你至少需要回答：
1. walk 中 invalidate 是否必须测。
2. walk 中 SATP switch 是否必须测。
3. walk 中 reset/flush/PMP/SysMap 改变是否必须测。
4. 哪些属于一期必须项。

当前代码里的默认假设：
- 已有场景名字，但未冻结为正式 spec 问题集合

你的答案：

---

## 18. Replay、stall、busy/wakeup、实现相关信号边界

### RE-01 replay / expt CAM / pre_sel 是否属于黑盒验证范围
优先级：`P0`  
影响组件：`SB / RM`

为什么要问：  
这是当前 `translation_sb` 中最重的实现耦合来源。

你至少需要回答：
1. 这些现象是不是架构行为。
2. 若不是，是否应彻底从黑盒比较中移除。
3. 若是，应该进主 checker，还是独立 micro-architecture checker。

当前代码里的默认假设：
- 遇到这些现象往往通过 waiver 绕开

你的答案：

### RE-02 如果同一请求会经历多次中间态，哪次算最终 compare
优先级：`P0`  
影响组件：`MON / SB`

为什么要问：  
只要存在 replay，monitor 就必须知道哪个输出是“最终 architecturally visible result”。

你至少需要回答：
1. 一个请求是否可能产生多次可见 response-like 事件。
2. 哪次才应进入主 scoreboard compare。
3. 其他中间态是应忽略、只做协议检查，还是应记为错误。

当前代码里的默认假设：
- 当前 monitor 偏向“第一个满足条件的 vld 就作为 rsp”

你的答案：

### RE-03 `tlb_busy/tlb_wakeup` 是否进入正式验证
优先级：`P1`  
影响组件：`TEST / SB / SVA`

为什么要问：  
这些信号可能只是 debug/perf 信号，也可能是正式对外协议。

你至少需要回答：
1. 它们是否有正式功能语义。
2. 如果有，应该验证哪些性质。
3. 更适合黑盒 compare、白盒 checker，还是 SVA。

当前代码里的默认假设：
- 更多用于 debug/perf，而非正式功能比对

你的答案：

### RE-04 replay 场景主回归想保证什么性质
优先级：`P1`  
影响组件：`TEST`

为什么要问：  
replay 类场景很容易无穷扩展，需要明确到底想验证“功能正确”还是“协议/公平性/时延上界”。

你至少需要回答：
1. replay 场景是否只要求最终结果正确。
2. 是否还要求无丢请求、无重复完成。
3. 是否还要看 pipe 优先级、公平性、最大等待时间。

当前代码里的默认假设：
- 目前更多是为了看到 replay 发生，而不是系统性签核 replay 行为

你的答案：

---

## 19. Reset、flush、异常注入、测试策略

### RST-01 reset 打在中途时，在途请求如何结束
优先级：`P0`  
影响组件：`TEST / MON / SB`

为什么要问：  
这会直接决定 monitor 的 pending queue 如何清理，以及 scoreboard 是否应该期待某个 response。

你至少需要回答：
1. reset 时在途 IFU/LSU/Pipe2/PTW/invalidate 请求应如何收尾。
2. 是否允许直接无响应消失。
3. 是否允许部分完成。
4. reset 后是否必须重新发起请求才能得到结果。

当前代码里的默认假设：
- 已有 `reset_midtransaction_vseq`，但没有正式的 compare 规则

你的答案：

### RST-02 misc / flush / expt 注入要不要进入正式主线验证
优先级：`P1`  
影响组件：`TEST / SB`

为什么要问：  
当前 `misc_agent` 已存在，但大多只做 smoke 路径。

你至少需要回答：
1. `rtu flush`、`bad_vpn`、`expt_vld` 分别会影响哪些外部行为。
2. 这些影响是否需要正式 checker。
3. 哪些场景只要 smoke，哪些需要 system-level compare。

当前代码里的默认假设：
- misc 主要用于注入和 perf/debug 观察

你的答案：

### RST-03 你希望优先做哪些错误注入
优先级：`P1`  
影响组件：`TEST`

为什么要问：  
后续 testcase 重构时需要一个清晰的 directed fault roadmap。

你至少需要回答：
1. 非法 PTE 中优先测哪些。
2. bus_error、PMP deny、SysMap deny、A/D fault、invalidates during walk 哪些必须优先。
3. 哪些错误注入是一期必须项。

当前代码里的默认假设：
- 已有 fault injection 入口，但没有正式优先级路线

你的答案：

### RST-04 testcase 路线更偏 directed 还是更偏 CRV
优先级：`P2`  
影响组件：`TEST`

为什么要问：  
这影响重构时 testcase/vseq/coverage 的组织方式。

你至少需要回答：
1. 是否先以 directed 闭环为主。
2. 随后是否再补 constrained-random。
3. 哪些主题更适合 directed，哪些更适合 random。

当前代码里的默认假设：
- 当前环境仍偏 directed/sanity 增量搭建

你的答案：

---

## 20. 我最建议你优先拍板的 10 个问题

如果你不想一开始就把整份问卷都填完，建议至少先给出下面 10 个问题的答案：

1. `ATTR-06`：PMP flag 的 bit 编码和 allow/deny 语义
2. `M-02`：active SATP 的选择机制
3. `PTE-05`：A/D 位到底是硬件置位还是 fault
4. `PTE-01`：2M/1G huge page 是否必须进入第一版黄金模型
5. `P2-02`：Pipe2 是否存在正式 fault 语义
6. `ST-01`：STAMO 是独立功能还是 translation 流的一部分
7. `RE-01`：`dtlb_expt_match / replay / pre_sel` 是否属于黑盒验证范围
8. `INV-03`：invalidate 的签核口径是否必须验证 stale translation 消失
9. `IFU-01` 与 `LSU-01`：现有 monitor 的 `1 outstanding` 假设是否正确
10. `ATTR-03` 与 `ATTR-05`：SysMap / MAEE / PMP 如何合成最终属性与 deny

---

## 21. 你回答完之后，建议怎么继续

建议后续按下面顺序推进：

1. 先冻结 `architectural translation contract`
2. 再冻结 `fault taxonomy + priority`
3. 再冻结 `PMP / SysMap / MAEE / attribute contract`
4. 然后重写 `reference model`
5. 再重写 `translation scoreboard`
6. 再补 `invalidate scoreboard`
7. 最后重构 testcase / vseq / coverage

---

## 22. 后续可继续追加的问题

如果你开始逐项回答后，我预计还会再长出两类“二级问题”：

1. 某个主问题被你确认后，需要继续细化成“可编码规则”
   例如 fault priority 一旦定下来，就会继续拆成每个通道的 compare truth table。

2. 某个主问题被你回答为“这是实现细节，不进黑盒验证”
   那我会继续追问：这个行为应转去 `whitebox checker / SVA / coverage` 中哪一类。

所以这份文档可以作为“第一层设计问卷”，后面再迭代成更接近代码实现的规格。
---

---

## 23. L1DTLB audit synchronization checklist

The current L1DTLB audit package answers a large subset of the LSU/replay/
invalidate questions above and should be treated as the active L1DTLB-specific
QA attachment.

| Item | Status | Required follow-up |
| --- | --- | --- |
| L1DTLB behavior source | Updated in `doc/l1dtlb_uvm_audit/l1dtlb_function_description.md` | Review chapters 1 and 2 as the behavior baseline |
| L1DTLB SVA requirements | Added in `l1dtlb_function_description.md` chapter 3.9 | Convert reviewed requirements into implemented/bound SVA only after UVM code stabilizes |
| L1DTLB required test scenarios | Added in `l1dtlb_function_description.md` chapter 3.10 | Keep the 65 scenario rows aligned with AUD-001..AUD-064 |
| HPDcache-style Excel testplan | Added as `doc/l1dtlb_uvm_audit/L1DTLB_TRISTAN_IP_Hardware_tp_V1.xlsx` | Use for review and testplan import; do not replace markdown audit traceability |
| Makefile document check | Added as `make l1dtlb_audit_check` | Run before Phase14 signoff archive |
| Optional L1DTLB directed run | Added as `make l1dtlb_audit_run_cov` | Run only after in-progress UVM code edits settle |

Open QA points before signoff:

1. Confirm which chapter 3.9 SVA rows are implemented, bound, or deferred.
2. Confirm whether each chapter 3.10 scenario is directed, coverage-only, or a
   traceability shell in the final UVM branch.
3. Confirm that scoreboard/pass-fail ownership keeps PLRU victim choice and other
   whitebox-only observations out of black-box correctness checks.
4. Confirm the L1DTLB Excel testplan and markdown audit stay in sync when new
   tests are added or renamed.
