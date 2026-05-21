overview
    适用范围与 UVM 边界
        本文聚焦描述 MMU 内部 L2TLB 子功能，包括 L2TLB 的 ReqQ、arbiter、tag/data/RRPV SRAM、miss buffer、PFU lookup、PTW refill 和 TLB operation 相关行为。
        文中列出的 `arb_*`、`queue_*`、`tlboper_*`、`l2tlb_*` 等信号多数是 MMU 内部 L2TLB 与相邻子模块之间的接口，主要用于规格说明、white-box monitor、coverage 和 debug，不表示完整 MMU UVM 应直接驱动这些内部信号。
        后续 UVM 搭建目标是完整 MMU 验证环境；驱动边界应以 MMU 顶层真实对外接口为准，例如 IFU/LSU translation 请求、CP0/CSR/TLB operation、PTW/PMP/sysmap 等顶层可见交互。L2TLB 内部信号可作为可选观察点或辅助 checker 输入，但不应默认作为 sequence 直接驱动接口，除非某个 directed white-box test 明确声明使用 backdoor/内部注入。

    l2tlb 总共有4个访问来源：1.l2tlb request queue发来的l1tlb的lookup 请求；2.pfu发来的lookup请求；3.ptw的请求；4.tlb operation模块的请求。
    l2tlb是sram based，并且l2tlb的sram是单端口的，所以l2tlb每拍只能接收一个请求，因此需要对进入l2tlb的请求做仲裁。
    l2tlb中包含的components有：l2tlb request queue;arbiter;l2tlb tag sram,l2tlb data sram,l2tlb rrpv sram;l2tlb miss buffer；l2tlb rrpv write buffer。
    所有l1tlb发来的请求都会先进入l2tlb request queue，后续对l2tlb request queue简称l2tlb reqq。l2tlb reqq会在有需要访问l2tlb的请求时，与其他来源的访问l2tlb的请求在arbiter中进行仲裁；同时l2tlb会在多个有效请求中挑选一个请求，把挑选的请求的相关信息发到arbiter。
    tlb operation,pfu,ptw,以及l2tlb reqq的请求会在arbiter中进行仲裁，arbiter会把赢得仲裁的来源的相关信息发到l2tlb的流水线中，进行后续处理。
    进入l2tlb流水线的请求会按照来源进行不同的处理。
        来源为l2tlb reqq的请求，其源头是ifu或者lsu发到l1tlb的地址转换请求发生了miss，需要在l2tlb中找到对应的结果，并且回填回l1tlb，所以l2tlb reqq中的请求需要进入l2tlb的lookup pipeline。
        来源为ptw的请求，其源头是ifu或者lsu发来的请求在l1tlb中miss，并且在l2tlb中也miss，于是l2tlb把这个请求发到ptw模块走page table walk,从dcache或l2cache或ddr中取回页表内容，拿到叶子表项之后，需要填进l2tlb。所以，ptw的请求无需进入l2tlb的lookup流水线。
        来源为pfu的请求，其源头是lsu需要进行数据的预取。pfu的预取直接发到l2tlb，而不经过l1tlb。pfu把地址转换请求发到l2tlb，所以也需要进入l2tlb的lookup流水线。
        来源为tlb operation的请求比较复杂，要按具体情况进行不同的处理
            如果tlb operation的请求的源头是需要按va无效tlb entry：
                这种操作只关心虚拟地址是否匹配，不要求 ASID 一定匹配。tlb operation 会把需要无效化的 VA/VPN 送到 arbiter，由 arbiter 按 L2TLB 的 skew associative 规则生成 8 个 way 的 index，并让 L2TLB 打开按 VA compare 的读请求。L2TLB 在读出 8 个 way 的 tag 后，根据 entry valid、page size、VPN mask 后的 VA 匹配结果来生成命中的 way mask。因为这是按 VA 无效所有地址空间中匹配该 VA 的 entry，所以 compare 时会放宽 ASID 条件，等价于忽略 ASID，global entry 和 non-global entry 只要 VA/page size 匹配都属于需要无效的候选。
                如果读阶段没有任何 way 命中，该次操作对 L2TLB 内容没有修改，只向 tlb operation 返回本次访问完成。如果读阶段存在一个或多个 way 命中，后续写阶段使用这些命中的 way mask，把对应 entry 的 tag valid 清 0，data 也同步清 0。该操作还需要通知 L1 uTLB/L1 TLB 对同一个 VA 做无效化，避免 L1 继续使用已经从 L2 清除的旧 translation。由于 TLB 内容被修改，执行过程中需要避免新的普通 lookup/refill 与该无效化序列在同一 entry 上发生乱序。
            如果tlb operation的请求的源头是需要按asid无效tlb entry：
                这种操作不根据某一个 VA 查找 entry，而是按 set index 扫描整个 L2TLB。tlb operation 会提供目标 ASID，并通过 arbiter 逐个 set 访问 L2TLB；每个 set 访问时通常一次读出 8 个 way。L2TLB 读出 tag 后检查每个 entry 的 valid、global 和 ASID 字段。只有 entry valid 为 1、entry 不是 global entry、并且 entry.asid 等于目标 ASID 的 entry 才需要被无效化。
                如果某个 set 中没有满足条件的 entry，则该 set 不需要写回。若某个 set 中有一个或多个 way 满足 ASID 条件，写阶段使用这些 ASID hit way 作为 bank select，把对应 entry 的 tag valid 清 0，必要时 data 同步清 0。global entry 必须保留，因为 global mapping 对所有 ASID 有效，按 ASID invalidate 不应该清除它。该操作结束后需要清除或通知 L1 TLB/uTLB 中属于该 ASID 的相关 entry；如果实现无法在 L1 精确按 ASID 清除，则可以采用更保守的 L1 清空策略。LSU 发起的该类无效化还需要 abort 受影响的未完成 PTW/miss buffer 请求，防止旧 ASID translation 在 invalidate 后继续回填。
            如果tlb operation的请求的源头是需要按asid和va无效tlb entry
                这种操作同时使用 VA 和 ASID 作为匹配条件。tlb operation 会把目标 VA/VPN 和目标 ASID 送入 L2TLB 访问路径，arbiter 根据目标 VA/VPN 生成 8 个 way 的 skew index，并打开按 VA compare 的读请求。L2TLB 读出各 way tag 后，先按 entry valid、page size 和 VPN mask 判断 VA 是否匹配，再判断 ASID/global 条件是否满足。当前正式语义是：non-global entry 需要 entry.asid 等于目标 ASID 才会被无效化；global entry 只要 VA/page size 匹配就会被无效化，因为 tag.G 在 hit 逻辑中绕过 ASID 比较。也就是说，INVASID 扫描会保留 global entry，但 INVVA_ASID 会清除同 VA/page size 的 global entry。
                如果没有任何 way 满足 VA/page size 且 ASID 相等或 tag.G=1 的条件，则本次操作只返回完成，不修改 L2TLB。若存在命中 way，写阶段使用 VA+ASID/global 命中的 way mask 清除对应 entry 的 valid 位。该操作还需要通知 L1 TLB/uTLB 对同一个 VA 做无效化；如果 L1 能区分 ASID，则至少清目标 ASID 下该 VA 的 entry；由于当前 L2 会同时清同 VA 的 global entry，如果 L1 不能精确区分 global 属性，则需要采用更保守的 VA 或全局清除方式。执行该操作时，也需要处理已经在 miss buffer 或 PTW 中、与目标 VA+ASID 或同 VA global mapping 对应的未完成请求，避免 invalidate 后旧 translation 再次写回 L2TLB 或 L1TLB。
            如果tlb operation的请求的源头是需要无效所有tlb entry:
                这种操作不需要 VA compare，也不需要 ASID compare，而是对 L2TLB 全部 set 和全部 way 做扫描写无效。tlb operation 通过 counter 遍历所有 set index；每访问一个 set，bank select 通常选择 8 个 way，把该 set 下所有 entry 的 tag valid 清 0，data 可以同步清 0。RRPV 信息可以不清，因为后续 hit 和 victim 选择都应以 entry valid 为基础；当新的 entry 被写成 valid 时，对应 RRPV 会重新初始化。
                INVALL 类操作完成后，L1 ITLB、L1 DTLB 以及相关 uTLB 内容也必须被清除，保证所有层级不再保留旧 translation。该操作通常还要 abort 或清理所有未完成的 PTW/miss buffer 请求，因为这些请求是在旧 TLB 状态下产生的，继续完成可能会在 invalidate all 之后重新写入旧 translation。LSU、CP0 或寄存器侧发起的全清操作在 L2TLB 完成所有 set 的扫描和写无效后，再向对应来源返回 done。

        当pfu或l2tlb reqq的请求在l2tlb中完成lookup，但是发现miss时，需要分配进l2tlb miss buffer。
        l2tlb miss buffer会从多个有效请求中选出一个，发送到ptw模块走page table walk。

1.signal description
    说明
        本节整理 mmu_l2tlb 模块的对外接口信号，方向均以 mmu_l2tlb 为基准。
        主要参数：VPN_WIDTH=27，PPN_WIDTH=28，FLG_WIDTH=14，PGS_WIDTH=3，ASID_WIDTH=16，IDX_WIDTH=8，WAY_NUM=8，TRANS_ID_WIDTH=4，L1EID_WIDTH=3，L2EID_WIDTH=4，TYPE_WIDTH=3，RRPV_WIDTH=3。
        常用 access type 编码：3'b001 表示 TLB operation，3'b010 表示 DTLB load，3'b011 表示 ITLB/fetch，3'b100 表示 PFU prefetch，3'b101 表示 PTW refill write，3'b110 表示 DTLB store，3'b000表示ptw read。
        page size 使用 one-hot 编码：3'b001 表示 4KB，3'b010 表示 2MB，3'b100 表示 1GB。

    1.1 clock/reset/scan
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | cpurst_b | input | 1 | 异步低有效复位。复位后 l2tlb 内部 request queue、miss buffer、pipeline valid、PFU 状态机、RRPV write buffer 等状态应回到 idle/invalid，避免产生伪请求、伪 refill 或伪 fault。 |
        | forever_cpuclk | input | 1 | l2tlb 主时钟。ReqQ、SRAM 访问流水线、miss buffer、replacement policy、RRPV write buffer、PFU response FSM 都在该时钟域下工作。 |
        | pad_yy_icg_scan_en | input | 1 | scan 模式时钟门控使能。该信号传给内部 gated_clk_cell，在 scan/DFT 模式下打开门控时钟，保证可控可观测。 |

    1.2 sysreg/cp0 context
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | cp0_mmu_icg_en | input | 1 | MMU 时钟门控使能。l2tlb 内部用它配合 request valid、pipeline valid、miss/refill 等活动信号生成局部门控时钟。 |
        | cp0_mmu_maee | input | 1 | memory attribute extension enable。PFU 返回 security/share 等属性时，若该位有效则优先使用 TLB/PTE flag 中的属性；否则使用 sysmap_mmu_flg4 的属性结果。 |
        | cp0_mmu_mpp[1:0] | input | 2 | MPRV 生效时的数据访问目标特权级。PFU 权限检查在 cp0_mmu_mprv=1 时使用该字段作为有效 privilege mode。 |
        | cp0_mmu_mprv | input | 1 | modify privilege 控制位。为 1 时 PFU 权限检查使用 cp0_mmu_mpp；为 0 时使用 cp0_yy_priv_mode。 |
        | cp0_mmu_mxr | input | 1 | make executable readable。PFU flag 检查中，如果页面不可读但可执行，该位允许时可按可执行权限通过读类访问检查。 |
        | cp0_mmu_ptw_en | input | 1 | PTW 使能。l2tlb lookup miss 时，若该位为 1，可以把 miss 分配到 miss buffer 并向 PTW 发 walk；若为 0，miss 不继续走 PTW，而向 L1/PFU 返回 fault 类完成。 |
        | cp0_mmu_sum | input | 1 | supervisor user memory 控制。S mode 访问 user page 时需要该位允许，否则 PFU 权限检查失败。 |
        | cp0_yy_priv_mode[1:0] | input | 2 | 当前处理器特权级。cp0_mmu_mprv=0 时，PFU 使用该字段区分 U/S/M mode 并做 permission/PMP 相关判断。 |
        | regs_l2tlb_cur_asid[15:0] | input | 16 | 当前 ASID。普通 VA compare 时，如果 tlboper_l2tlb_asid_sel 未选择 TLB operation 专用 ASID，则使用该 ASID 与 tag ASID 比较；global entry 可绕过 ASID 匹配。 |

    1.3 l2tlb request queue and arbiter interface
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | l2tlb_arb_pfu_vpn[VPN_WIDTH-1:0] | output | 27 | PFU 请求送往 arbiter 的 VPN。当前由 lsu_mmu_va2[26:0] 产生，arbiter 在 PFU 被选中时用它生成 skew index。 |
        | queue_arb_req | output | 1 | ReqQ 向 arbiter 发出的请求有效。该请求可能来自已入队且 ready 的 entry，也可能来自当拍 L1 ITLB/DTLB 新请求的 bypass issue。 |
        | queue_arb_vpn[VPN_WIDTH-1:0] | output | 27 | ReqQ 选中请求的 VPN。进入 arbiter 后用于生成 l2tlb lookup 的各 way index，并在 pipeline 中做 tag compare。 |
        | queue_arb_eid[L1EID_WIDTH-1:0] | output | 3 | L1 DTLB miss buffer entry id。DTLB 请求完成时通过 l2tlb_l1dtlb_ref_eid 返回给 L1 DTLB；ITLB 请求没有 L1 miss buffer，通常为 0。 |
        | queue_arb_trans_id[TRANS_ID_WIDTH-1:0] | output | 4 | L2TLB ReqQ entry id。pipeline 完成后用该 id 反馈给 ReqQ，命中或 miss 成功分配 miss buffer 时释放 entry，miss buffer full 时清 sent 并等待 replay。 |
        | queue_arb_acc_type[TYPE_WIDTH-1:0] | output | 3 | ReqQ 请求类型。ITLB 为 3'b011，DTLB load 为 3'b010，DTLB store 为 3'b110；该字段决定最终返回 ITLB、DTLB 还是进入对应异常路径。 |
        | victim_way[WAY_NUM-1:0] | output | 8 | replacement policy 选出的 victim way one-hot。PTW refill 或 TLBWR 写入新 entry 时使用该 mask 选择写入 way。 |
        | rrpv_updata[WAY_NUM-1:0][RRPV_WIDTH-1:0] | output | 8x3 | replacement policy 计算出的每个 way 的新 RRPV 值。PTW refill write 时经 arbiter 写回 RRPV SRAM。 |
        | l2tlb_arb_ptw_cmplt | output | 1 | PTW refill write 被 l2tlb 接收/完成的指示。当前在 arb_l2tlb_req 且 arb_l2tlb_acc_type=3'b101 且 arb_l2tlb_write=1 时置位。 |
        | arb__l2tlb_queue_grant | input | 1 | arbiter 对 ReqQ 请求的 grant。l2tlb 把它作为 reqq issue_grant，表示当前 queue_arb_* 请求已被仲裁选中并进入 L2TLB pipeline。 |

    1.4 arbiter to l2tlb sram/pipeline interface
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | arb_l2tlb_req | input | 1 | arbiter 发给 l2tlb 的全局请求有效。每拍最多一个来源赢得仲裁并访问 L2TLB SRAM/pipeline，来源包括 ReqQ、PFU、TLB operation、PTW refill/write 等。 |
        | arb_l2tlb_vpn[VPN_WIDTH-1:0] | input | 27 | 仲裁后请求 VPN。lookup/TLBP/INVVA 使用它做 tag compare；写入类操作也可用它形成写入 tag 或 index 上下文。 |
        | arb_l2tlb_acc_type[TYPE_WIDTH-1:0] | input | 3 | 仲裁后请求类型。l2tlb 根据该字段区分普通 ITLB/DTLB lookup、PFU lookup、TLB operation、PTW refill write 等行为。 |
        | arb_l2tlb_trans_id[TRANS_ID_WIDTH-1:0] | input | 4 | 来自 ReqQ 的 transaction id。普通 lookup 完成后用它反馈 ReqQ entry 的 hit、miss_alloc 或 miss_retry。 |
        | arb_l2tlb_eid[EID_WIDTH-1:0] | input | 3 | L1 DTLB miss buffer id。DTLB 请求命中或 fault 完成时返回给 L1 DTLB。 |
        | arb_l2tlb_write | input | 1 | SRAM 写使能。为 1 时按 arb_l2tlb_bank_sel 写 tag/data，并按请求类型更新 RRPV；PTW refill、TLBWI/TLBWR、invalidate 写 invalid entry 等使用该信号。 |
        | arb_l2tlb_tag_din[47:0] | input | 48 | 写入 tag SRAM 的数据。包含 valid、VPN、ASID、page size、global 等字段；只在 arb_l2tlb_write=1 且对应 bank 被选中时写入。 |
        | arb_l2tlb_data_din[41:0] | input | 42 | 写入 data SRAM 的数据。包含 PPN 和 14bit flag/attribute 字段，用于 PTW refill 或 TLB operation 写 translation entry。 |
        | arb_l2tlb_bank_sel[WAY_NUM-1:0] | input | 8 | way/bank 选择 mask。普通 lookup 通常选择多个候选 way；TLBR/TLBWI 等 index 类操作通常选择单个 way；bit0 对应 way0，bit7 对应 way7。 |
        | arb_l2tlb_cmp_with_va | input | 1 | 是否按 VA/VPN 做 tag compare。为 1 时读出 tag 后比较 VPN/ASID/page size；为 0 时用于 TLBR/TLBWI/部分扫描类 index 操作。 |
        | arb_l2tlb_idx_w0[IDX_WIDTH-1:0] | input | 8 | way0 SRAM index。普通 lookup 时由 arbiter 按 VPN、page size selector 和 way0 hash 生成；index 操作时来自指定 index[7:0]。 |
        | arb_l2tlb_idx_w1[IDX_WIDTH-1:0] | input | 8 | way1 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way1 的独立 skew/hash index。 |
        | arb_l2tlb_idx_w2[IDX_WIDTH-1:0] | input | 8 | way2 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way2 的独立 skew/hash index。 |
        | arb_l2tlb_idx_w3[IDX_WIDTH-1:0] | input | 8 | way3 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way3 的独立 skew/hash index。 |
        | arb_l2tlb_idx_w4[IDX_WIDTH-1:0] | input | 8 | way4 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way4 的独立 skew/hash index。 |
        | arb_l2tlb_idx_w5[IDX_WIDTH-1:0] | input | 8 | way5 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way5 的独立 skew/hash index。 |
        | arb_l2tlb_idx_w6[IDX_WIDTH-1:0] | input | 8 | way6 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way6 的独立 skew/hash index。 |
        | arb_l2tlb_idx_w7[IDX_WIDTH-1:0] | input | 8 | way7 SRAM index，语义同 arb_l2tlb_idx_w0，但对应 way7 的独立 skew/hash index。 |
        | arb_l2tlb_size_bus[WAY_NUM*PGS_WIDTH-1:0] | input | 24 | 每个 way 的预测 page size，按 way 打包，每个 way 3bit。l2tlb compare 阶段用它决定该 way 按 4KB、2MB 还是 1GB 粒度匹配 VPN。 |
        | arb_l2tlb_rrpv_din[WAY_NUM*RRPV_WIDTH-1:0] | input | 24 | 写入 RRPV SRAM 的数据。PTW refill 使用 replacement policy 给出的 RRPV 更新值，TLB operation 写有效 entry 时也可初始化对应 RRPV。 |

    1.5 ptw interface
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | ptw_l2tlb_ref_type[TYPE_WIDTH-1:0] | input | 3 | PTW completion 的请求类型。l2tlb 用它区分返回属于 DTLB miss、ITLB miss 还是 PFU miss；3'b010/3'b110 为 DTLB，3'b011 为 ITLB，3'b100 为 PFU。 |
        | ptw_l2tlb_ref_acc_err | input | 1 | PTW 返回 access error。PFU miss 完成时若该信号有效，l2tlb 将 PFU 响应归为错误返回。 |
        | ptw_l2tlb_ref_cmplt | input | 1 | PTW completion 有效。用于释放/更新 l2tlb miss buffer entry，并参与 PFU miss 完成判断。 |
        | ptw_l2tlb_ref_data_vld | input | 1 | PTW 返回 translation data 有效。表示 page table walk 找到可 refill 的页表项；也作为 uTLB refill 活动指示来源之一。 |
        | ptw_l2tlb_ref_flg[13:0] | input | 14 | PTW 返回的 PTE flag/attribute，不包含 PTE.G；PTE.G 单独写入 tag.G。PFU miss 完成时，l2tlb 使用该字段做 flag fault、security/share 等判断。 |
        | ptw_l2tlb_ref_pgflt | input | 1 | PTW 返回 page fault。PFU miss completion 时会导致 PFU error；普通 L1 miss 的 fault 也需要通过 PTW/L1 completion 路径处理。 |
        | ptw_l2tlb_ref_id[L1EID_WIDTH+L2EID_WIDTH-1:0] | input | 7 | PTW 返回 transaction id。高位用于定位 l2tlb miss buffer entry，低位保留 L1 miss buffer id，用于 completion 对应原始请求。 |
        | ptw_ready | input | 1 | PTW 接收请求 ready。l2tlb miss buffer 只有在 PTW ready 且 cp0_mmu_ptw_en 有效时才发起 l2tlb_ptw_req。 |
        | l2tlb_ptw_req | output | 1 | l2tlb miss buffer 向 PTW 发出的 walk 请求有效。该信号由 mb_issue_req 与 cp0_mmu_ptw_en 共同决定。 |
        | l2tlb_ptw_type[2:0] | output | 3 | 发给 PTW 的请求类型，继承原始 miss 的 ITLB/DTLB/PFU 和 load/store/fetch 属性。 |
        | l2tlb_ptw_vpn[26:0] | output | 27 | 发给 PTW 的 miss VPN。PTW 以该 VPN 做 page table walk，并在找到叶子 PTE 后通过 refill 路径写回 L2TLB。 |
        | l2tlb_ptw_id[L1EID_WIDTH+L2EID_WIDTH-1:0] | output | 7 | 发给 PTW 的 transaction id，包含 L2 miss buffer entry id 和 L1 entry id，供 completion 回传匹配。 |

    1.6 l1 itlb/dtlb request and credit interface
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | i_req_valid | input | 1 | L1 ITLB miss 请求有效。有效时 i_req_vpn 被写入 ReqQ entry0；如果 ReqQ 没有更高优先级 ready entry，可当拍 bypass 参与 arbiter。 |
        | i_req_vpn[VPN_WIDTH-1:0] | input | 27 | L1 ITLB miss VPN。l2tlb 命中后通过 l2tlb_l1itlb_ref_* 回填 ITLB；miss 后分配 miss buffer 并请求 PTW。 |
        | i_credit_return | output | 1 | 返回给 L1 ITLB 的 credit。ReqQ entry0 释放时置位，表示 ITLB 可再次发送 miss 请求。 |
        | d_req_valid | input | 1 | L1 DTLB miss 请求有效。有效时 d_req_vpn、d_req_eid、d_req_is_load 被写入 DTLB 专用 ReqQ entry1-entry8 中最低空闲 entry。 |
        | d_req_vpn[VPN_WIDTH-1:0] | input | 27 | L1 DTLB miss VPN。用于 load/store 地址转换 lookup；命中后返回 PPN/flag，miss 后进入 l2tlb miss buffer。 |
        | d_req_eid[L1EID_WIDTH-1:0] | input | 3 | L1 DTLB miss buffer entry id。l2tlb 完成该请求时用 l2tlb_l1dtlb_ref_eid 返回，定位 L1 DTLB 中等待回填的 entry。 |
        | d_req_is_load | input | 1 | DTLB 请求 load/store 类型选择。为 1 时编码为 3'b010(load)，为 0 时编码为 3'b110(store)，影响 PTW type 和 fault/permission 分类。 |
        | d_credit_return | output | 1 | 返回给 L1 DTLB 的 credit。ReqQ entry1-entry8 任一 entry 释放时置位，通知 L1 DTLB 有可用 L2 request queue entry。 |

    1.7 l2tlb response/refill to l1 utlb
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | l2tlb_l1dtlb_pgflt | output | 1 | L2TLB 给 L1 DTLB 的 page fault 指示。DTLB lookup 出现 multi-hit，或 PTW disabled 且 miss 时置位。 |
        | l2tlb_l1dtlb_ref_cmplt | output | 1 | L2TLB 对 L1 DTLB 请求的完成指示。命中、fault 或不继续 PTW 的场景会完成，用于结束 L1 DTLB miss buffer 等待。 |
        | l2tlb_l1dtlb_ref_pavld | output | 1 | L2TLB 直接命中返回给 L1 DTLB 的 PA/translation 有效。置位时 l2tlb_l1tlb_ref_vpn/ppn/pgs/flg 携带有效回填内容。 |
        | l2tlb_l1dtlb_ref_eid[L1EID_WIDTH-1:0] | output | 3 | 返回给 L1 DTLB 的 miss buffer entry id。L1 DTLB 用它选择被回填或 fault 完成的 entry。 |
        | l2tlb_l1itlb_pgflt | output | 1 | L2TLB 给 L1 ITLB 的 page fault 指示。ITLB lookup 出现 multi-hit，或 PTW disabled 且 miss 时置位。 |
        | l2tlb_l1itlb_ref_cmplt | output | 1 | L2TLB 对 L1 ITLB 请求的完成指示。ITLB 请求在 hit 或 fault 类结束时置位。 |
        | l2tlb_l1itlb_ref_pavld | output | 1 | L2TLB 直接命中返回给 L1 ITLB 的 translation 有效。置位时共用 l2tlb_l1tlb_ref_* 数据总线携带 fetch translation。 |
        | l2tlb_l1tlb_ref_flg[13:0] | output | 14 | 返回给 L1 ITLB/DTLB 的 flag/attribute，不包含 PTE.G。包含权限位、user/access/dirty、RSW、memory attribute、security/share 等信息；PTE.G 只保存在 L2 tag.G 中。 |
        | l2tlb_l1tlb_ref_pgs[2:0] | output | 3 | 命中 entry 的 page size one-hot。L1 refill 根据该字段决定回填 4KB、2MB 或 1GB entry。 |
        | l2tlb_l1tlb_ref_ppn[27:0] | output | 28 | 命中 entry 的 PPN。L1 或后续逻辑结合 page size 和 VA offset 生成最终 PA。 |
        | l2tlb_l1tlb_ref_vpn[26:0] | output | 27 | 完成 lookup 的 VPN。用于 L1 refill 写 tag 或做返回一致性检查。 |
        | l2tlb_top_utlb_pavld | output | 1 | uTLB refill 活动指示。当前为 final_pa_vld 或 ptw_l2tlb_ref_data_vld 的组合，顶层可用它生成 uTLB clock enable 或活动判断。 |

    1.8 lsu pfu interface
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | l1dtlb_xx_mmu_off | input | 1 | DTLB/MMU off 指示。PFU 路径在 MMU off 时不做普通 translation lookup，直接把 lsu_mmu_va2 当作物理地址，并使用 sysmap/PMP 结果。 |
        | lsu_mmu_va2[27:0] | input | 28 | LSU PFU 发来的预取地址。低 27bit 作为 PFU VPN 送 arbiter；MMU off 时直接作为 PA；MMU on 且命中时与 PPN/page size 拼接生成 mmu_lsu_pa2。 |
        | lsu_mmu_va2_vld | input | 1 | LSU PFU 请求有效。arbiter 在无更高优先级请求且 PFU 未被 mask 时可选择该请求进入 L2TLB lookup。 |
        | mmu_lsu_pa2[27:0] | output | 28 | PFU translation 返回给 LSU 的物理地址。命中时由 TLB PPN 与 VA offset 拼接得到；MMU off 时直接等于 lsu_mmu_va2。 |
        | mmu_lsu_pa2_err | output | 1 | PFU 返回错误指示。PMP deny、page fault、access error、multi-hit、PTW disabled miss 或 flag fault 等会使该信号置位。 |
        | mmu_lsu_pa2_vld | output | 1 | PFU 返回有效。PFU 状态机进入 OK 或 DENY 状态时置位，表示 mmu_lsu_pa2/mmu_lsu_pa2_err/mmu_lsu_sec2/mmu_lsu_share2 有效。 |
        | mmu_lsu_sec2 | output | 1 | PFU 返回 security 属性。MMU on 且 MAEE 使能时来自 TLB flag；MMU off 或 MAEE 关闭时来自 sysmap_mmu_flg4。 |
        | mmu_lsu_share2 | output | 1 | PFU 返回 shareable 属性。MMU on 且 MAEE 使能时来自 TLB flag；MMU off 或 MAEE 关闭时来自 sysmap_mmu_flg4。 |

    1.9 tlb operation interface
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | tlboper_l2tlb_asid[15:0] | input | 16 | TLB operation 指定 ASID。TLBP/INVVA_ASID 等需要按特定 ASID compare 时使用。 |
        | tlboper_l2tlb_asid_sel | input | 1 | ASID compare 来源选择。为 1 时使用 tlboper_l2tlb_asid；为 0 时使用 regs_l2tlb_cur_asid。 |
        | tlboper_l2tlb_cmp_noasid | input | 1 | compare 时忽略 ASID。用于 INVVA_ALL 或不要求 ASID 匹配的操作；置位后非 global entry 也可不比较 ASID。 |
        | tlboper_l2tlb_inv_asid[15:0] | input | 16 | INVASID 扫描目标 ASID。l2tlb 读出每个 way 的 tag ASID 后与该字段比较，并通过 l2tlb_tlboper_asid_hit/l2tlb_tlboper_sel 反馈。 |
        | tlboper_l2tlb_tlbwr_on | input | 1 | TLBWR 操作进行中指示。l2tlb_tlboper_sel 在该信号为 1 时选择 replacement policy 输出的 victim_way。 |
        | tlboper_l2tlb_invasid_on | input | 1 | INVASID 操作进行中指示。l2tlb_tlboper_sel 在该信号为 1 时选择 ASID hit way。 |
        | tlboper_xx_pgs[2:0] | input | 3 | TLB operation 指定 page size one-hot。TLBP/INVVA 等按 VA compare 的操作使用它生成 VPN mask 和 page size 匹配条件。 |
        | tlboper_ptw_abort | input | 1 | TLB operation 要求 abort PTW/miss buffer 的控制信号。传入 l2tlb miss buffer，用于 invalidate/flush 类操作期间清理未完成 walk。 |
        | l2tlb_regs_hit | output | 1 | TLBP/probe 单命中状态。final compare 命中且非 multi-hit 时为 1，寄存器侧据此更新 TLBP hit 状态。 |
        | l2tlb_regs_hit_mult | output | 1 | TLBP/probe 多命中状态。多个 way 同时命中同一查询条件时置位。 |
        | l2tlb_regs_tlbp_hit_index[10:0] | output | 11 | TLBP 命中 entry index，编码为 {way_id[2:0], set_idx[7:0]}。 |
        | l2tlb_tlboper_asid_hit | output | 1 | INVASID/ASID 扫描命中汇总。当前 index 任意 way 的 ASID 匹配 tlboper_l2tlb_inv_asid 时置位。 |
        | l2tlb_tlboper_cmplt | output | 1 | TLB operation 在 L2TLB pipeline 中完成指示。当前 final_vld 且 final_acc_type=3'b001 时置位。 |
        | l2tlb_tlboper_sel[WAY_NUM-1:0] | output | 8 | TLB operation 选中 way mask。TLBWR 时为 victim_way，INVASID 时为 ASID hit way，INVVA/TLBP 类操作时为 VA hit way。 |
        | l2tlb_tlboper_va_hit | output | 1 | TLB operation VA compare 命中汇总。任意 way 命中当前 VA/page size/ASID 条件时置位。 |
        | l2tlb_tlbr_asid[15:0] | output | 16 | TLBR/index read 读出的 ASID 字段。来自被选中 way 的 tag SRAM。 |
        | l2tlb_tlbr_flg[13:0] | output | 14 | TLBR/index read 读出的 flag/attribute 字段。来自被选中 way 的 data SRAM。 |
        | l2tlb_tlbr_g | output | 1 | TLBR/index read 读出的 global bit。 |
        | l2tlb_tlbr_pgs[2:0] | output | 3 | TLBR/index read 读出的 page size one-hot。 |
        | l2tlb_tlbr_ppn[27:0] | output | 28 | TLBR/index read 读出的 PPN。来自被选中 way 的 data SRAM。 |
        | l2tlb_tlbr_vpn[26:0] | output | 27 | TLBR/index read 读出的 VPN。来自被选中 way 的 tag SRAM。 |

    1.10 pmp/sysmap interface for pfu
        | signal | dir | width | description |
        | --- | --- | --- | --- |
        | pmp_mmu_flg4[3:0] | input | 4 | PMP 对 PFU 地址检查的返回 flag。l2tlb 使用权限结果判断 PFU 是否被 PMP deny，并结合 M mode lock 规则生成 mmu_lsu_pa2_err。 |
        | mmu_pmp_pa4[27:0] | output | 28 | 送给 PMP port4 的 PFU 物理地址。l2tlb 在 PFU translation 得到 pfu_pa_buf 后输出该地址，供 PMP 做 permission/lock 检查。 |
        | sysmap_mmu_flg4[4:0] | input | 5 | System map 对 PFU 地址的属性/异常返回。MMU off 或 MAEE 关闭时，l2tlb 使用该 flag 提供 security/share 属性并检查 sysmap fault/deny。 |
        | mmu_sysmap_pa4[27:0] | output | 28 | 送给 sysmap port4 的 PFU 地址。当前实现直接输出 lsu_mmu_va2，用于 sysmap 提供物理属性或访问合法性信息。 |



2.components
    2.1 l2tlb request queue
        overview
            l2tlb request queue用来存储l1tlb发来的请求，所有l1tlb发来的请求都会先进入l2tlb request queue。l2tlb reqq会在有需要访问l2tlb的请求时，与其他来源的访问l2tlb的请求在arbiter中进行仲裁；同时l2tlb会在多个有效请求中挑选一个请求，把挑选的请求的相关信息发到arbiter。
            l1itlb和l1dtlb发到l2tlb的请求都会发到l2tlb reqq,l2tlb reqq中，为l1itlb和l1dtlb分别分配了entry。
                因为ifu发到l1itlb的请求如果发生了miss，那么ifu内部就会停止生成新的pc值，直到这个miss的请求完成了地址转换之后，才会发新的va到l1itlb。所以在l1itlb中，没有设计miss buffer，所以l1itlb没有outstanding的需求和功能。也就是说，l1itlb最多发一个miss请求到l2tlb，所以l2tlb reqq中只预留了一个l1itlb专用的entry。
                因为l1dtlb中有设计miss buffer，且l1dtlb具备outstanding的能力，所以在l2tlb reqq中给l1dtlb发来的请求预留了多个专用的entry，具体数量可配置，目前是8个l1dtlb专用的entry。
            l2tlb reqq是用d-flip-flop搭建的。

        function description
            由于l2tlb和l1tlb之间采取的握手协议是credit-based的握手协议，所以只要l1能发请求给l2，那么这个请求一定能被l2tlb reqq接收(l2tlb reqq有空位)。credit-based部分已在l1tlb中详细描述，在此不再赘述，并且credit握手部分的验证会放到l1tlb中，在l2tlb中无需对此进行额外验证。
            l1itlb和l1dtlb在l2tlb reqq中的entry是各自独立的，也就是说，如果同一拍中既有l1itlb的请求，又有l1dtlb的请求时，它们都会被写进l2tlb reqq。
            在l2tlb reqq的entry中，entry 0为l1itlb专用，entry1到entry8为l1dtlb专用。
            当有l1itlb的请求时，就把entry0分配给l1itlb；当有l1dtlb的请求时，就从entry1到entry8之间，找到最低位的空闲entry，分配给这个dtlb的请求。

            当l2tlb reqq中存在有效且未发射的entry，或者当l2tlb reqq不存在有效且未发射的entry但是l1tlb发了请求过来时，l2tlb reqq会参与arbiter的仲裁。同时l21tlb会选择合适的请求发送到arbiter
                当l2tlb reqq中存在有效且未发射的entry时，无论l1tlb有没有发请求到l2tlb，都会在l2tlb reqq中有效且未发射的entry中，选出一个发送到arbiter。
                    如果l2tlb reqq中有来源为itlb的未发射的请求，也就是说entry0有效且未发射，那么会优先选择把entry0的请求发送出去。
                    如果l2tlb reqq中没有来源为itlb的未发射的请求，那么会从来源为dtlb的未发射请求中选一个发送到arbiter，也就是说，itlb的优先级高于dtlb。
                当当l2tlb reqq不存在有效且未发射的entry但是l1tlb发了请求到l2tlb时，会把l1tlb发来的请求发送到arbiter，同时给l1tlb发来的请求分配reqq entry。
                    如果当拍只有l1itlb发请求到l2tlb，那么在这一拍会分配entry给这个请求，并且同时在这一拍把l1itlb发来的请求送到arbiter。
                    如果当拍只有l1dtlb发请求到l2tlb，那么在这一拍会分配entry给这个请求，并且同时在这一拍把l1dtlb发来的请求送到arbiter。
                    如果当拍同时有l1itlb和l1dtlb的请求发到l2tlb，那么在这一拍会给这两个请求都分配entry，并且同时在这一拍把l1itlb发来的请求发送到l2tlb。
                也就是说，l1itlb发来的请求的优先级永远比l1dtlb发来的请求的优先级高。

            l2tlb reqq的entry中目前存储：vld ，vpn[26:0],L1eid[L1EID_W-1:0]，Request_Type，sent。
                vld：vld指示这个entry是否已经被分配，被分配的entry不能参与后续的新发来l2的请求的分配。
                    当这个entry的请求在l2tlb中hit，会释放这个entry，拉低这个entry的vld信号。
                    当这个entry的请求在l2tlb中miss并且被分配进l2tlb miss buffer时，会释放这个entry，拉低这个entry的vld信号。
                    当这个entry的请求在l2tlb中miss并且没有被分配进l2tlb miss buffer时，不会释放这个entry，保持这个entry的vld信号。因为此时的请求发生了miss且未写入miss buffer，如果拉低vld信号，会导致这个请求被丢掉。

                vpn[26:0]：l1tlb发来请求时会带上请求的vpn，l2tlb reqq entry存储请求的vpn，以便后续在l2tlb中lookup。

                L1eid[L1EID_W-1:0]：这个是litlb miss buffer entry id,用来指示这个请求是从l1tlb miss buffer的哪个entry发来的，后续refill的时候需要根据这个id定位。
                    l1itlb中因为没有miss buffer，所以不需要存储这个eid，entry0的eid是默认的0。
                    l1dtlb中有miss buffer，所以l2tlb reqq entry会把随着l1dtlb请求过来的那个eid存储进entry。

                Request_Type:用来标识这个请求的类型。
                    entry0为l1itlb专用，来源为itlb的请求的type会被编码成3'b011。
                    entry1到entry8为l1dtlb专用，来源为l1dtlb的请求会进一步细分
                        如果是load请求，那么type被编码成3'b010。
                        如果是store请求，那么type被编码成3'b110。

                sent：用来指示这个entry是否已经被发射出去。
                    当这个entry的请求在l2tlb中有结果，会释放这个entry，拉低这个entry的vld信号的同时会拉低sent信号。有结果是指：
                        1.在l2tlb中hit
                        2.在l2tlb中检查出fault
                    当这个entry的请求在l2tlb中miss并且被分配进l2tlb miss buffer时，会释放这个entry，拉低这个entry的vld信号的同时会拉低sent信号。
                    当这个entry的请求在l2tlb中miss并且没有被分配进l2tlb miss buffer时，不会释放这个entry，保持这个entry的vld信号的同时会拉低sent信号。因为此时的请求发生了miss且未写入miss buffer（miss buffer满了，无法接受新请求），需要在后续发起replay，重走l2tlb的lookup流水线。
                    只要reqq发出去的请求有结果，reqq中的entry就可以被释放。命中，出现fault（page fault，或access fault（如果有的话），其实hit multi是算成page fault的），以及miss被miss buffer接收都算有结果。只有当miss且无法被miss buffer接收的情况才需要reqq做replay

    2.2 l2tlb
        overview
            在 RISC-V SV39 架构中，系统支持三种页面大小：4KB , 2MB , 1GB 。传统的组相联（Set-Associative）TLB 在处理混合页大小时要根据页大小使用不同索引位，硬件无法在查找前预知页大小，只能：
                - 串行查找，效率较低
                - 静态分区，TLB空间利用率低
            Skewed Associative 解决方案
                采用 8-Way Skewed Associative 架构。
                    - 核心原理： 将 TLB 分割为 8 个独立的存储体（Way），每个 Way 拥有完全独立且正交的哈希索引函数。
                    - 优势：
                        1. 并发支持： 利用不同的 Way 并行“猜测”不同的页大小。
                        2. 抗冲突： 即使两个地址在 Way 0 发生索引冲突，由于 Way 1 的哈希函数完全不同，它们在 Way 1 几乎不可能冲突。
                        3. 无空间浪费： 任意页大小均可利用 TLB 的整体容量，无需静态分区。

            function description
                1. Storage Organization
                    TLB的tag，data和rrpv各有单独的sram存储。
                    TLB 包含 8 个 Way，每个way都是一块单独的sram。也就是说，对于一个way，总共有tag，data，rrpv三个单独的sram bank，8个way加起来就是8*3=24个sram。
                    每个way有256个set，每个set有一个entry。
                    每个 Entry 的结构如下:
                        a.tag:tag is 48 bit per entry.
                            1.vld:The V bit indicates whether the PTE is valid
                            2.VPN[26:0]:entry存储的virtual page number
                            3.asid[15：0]:Address Space Identifier，区分不同进程
                            4.golbal:用于标记那些对所有进程都有效的全局映射，当golbal bit有效时，无需检查asid
                            5.Size_Type [2:0]:存储该 Entry 的实际page size。3'b001: 4KB，3'b010: 2MB，3'b100: 1GB

                        b.data:data is 42 bit per entry
                            1.PPN[27:0]:Physical Page Number
                            2.Strong Order
                            3.Cacheable
                            4.Bufferable
                            5.Shareable
                            6.Security
                            7.Reserved for Software[1:0]：The RSW field is reserved for use by supervisor software,; the implementation shall ignore this field
                            8.Dirty：The D bit indicates the virtual page has been written since the last time the D bit was cleared.
                            9.Accessed：The A bit indicates the virtual page has been read, written, or fetched from since the last time the A bit was cleared.
                            10.V ：PTE.V
                            11.User：indicates whether the page is accessible to user mode
                            12.X：indicate whether the page is executable
                            13.W：indicate whether the page is writable
                            14.R:indicate whether the page is readable

                        c.rrpv:rrpv is 3 bit per entry
                            有多少个tag和data的entry就有多少个rrpv的entry，它们是一一对应的关系。

                2.引入 Selector。
                    - 原理： 利用虚拟地址的特定位 VA[31:30] 作为随机选择子，强制规定每个 Way 在当前查找周期应假设的页大小。
                    这8个way都有自己单独的sram bank，访问这8个bank的index也各不相同。
                    利用虚拟地址的特定位 VA[31:30] 作为随机选择子，强制规定每个 Way 在当前查找周期应假设的页大小。

                3.sram的门控
                    当pfu或itlb或dtlb或需要lookup的的tlb operation访问l2tlb时，被arb_l2tlb_bank_sel选中的way会同时读出tag，data和rrpv
                    当ptw read请求访问l2tlb时，被arb_l2tlb_bank_sel选中的way会读出rrpv（不读tag和data）
                    当ptw write请求访问l2tlb时，被arb_l2tlb_bank_sel选中的way会写入tag，data和rrpv

                4.sram的clear（L2TLB TLB Operation）
                    前提
                    ----

                    L2TLB 是 8-way skew associative TLB。
                    一次 lookup 可以并行查完所有 page size 对应的候选 way。
                    每个 way 有 256 个 set。

                    推荐的 TLB index 编码：
                        index[10:8] = way id
                        index[7:0]  = set index

                    TLB operation 期间，arbiter 应阻塞普通 L2TLB lookup/refill，直到当前 TLB operation 完成。


                    1. TLBP
                    -------

                    目的：
                        用寄存器中的 VPN/ASID/page size 信息 probe L2TLB，判断是否命中。

                    期望效果：
                        不修改 L2TLB 内容。
                        返回 hit / multi-hit 状态。
                        返回 hit entry 的 index。

                    实现要点：
                        tlboper 发起 compare-with-VA read。
                        bank select 使用 8'hff，一次读 8 个 way。
                        arbiter 根据 VPN 生成 8 个 skew index。
                        L2TLB 并行比较 8 个 way 的 tag。
                        hit index 编码为 {way_id[2:0], set_idx[7:0]}。


                    2. TLBR
                    -------

                    目的：
                        按指定 index 读取一个 L2TLB entry。

                    期望效果：
                        不修改 L2TLB 内容。
                        返回指定 entry 的 VPN/ASID/page size/global/PPN/flag。

                    实现要点：
                        index[10:8] 选择 way。
                        index[7:0] 选择 set。
                        bank select 为 one-hot: 8'b1 << index[10:8]。
                        SRAM row address 只使用 index[7:0]。
                        L2TLB 返回被选中 way 的 tag/data。


                    3. TLBWI
                    --------

                    目的：
                        按指定 index 写入一个 L2TLB entry。

                    期望效果：
                        用寄存器中的 translation entry 覆盖指定 entry。
                        写入后的 entry valid 为 1。
                        清除 L1 uTLB，避免继续使用旧 translation。

                    实现要点：
                        index[10:8] 选择 way。
                        index[7:0] 选择 set。
                        bank select 为 one-hot: 8'b1 << index[10:8]。
                        tag 写入 {valid=1, vpn, asid, pgs, global}。
                        data 写入 {ppn, flags}。
                        触发 tlboper_utlb_clr。
                        如果 TLBWI 创建 valid entry，对应 entry 的 RRPV为3。


                    4. TLBWR
                    --------

                    目的：
                        写入一个由硬件替换策略选择的 L2TLB entry。

                    期望效果：
                        用寄存器中的 translation entry 覆盖 victim entry。
                        写入后的 entry valid 为 1。
                        清除 L1 TLB。

                    实现要点：
                        读阶段读取候选 set 的 8 个 way，供 replacement policy 选择 victim。
                        写阶段 bank select 使用 victim_way。
                        tag 写入 {valid=1, vpn, asid, pgs, global}。
                        data 写入 {ppn, flags}。
                        触发 tlboper_utlb_clr。
                        TLBWR 写 entry 时同步初始化 victim way 的 RRPV。


                    5. INVALL
                    ---------

                    目的：
                        使 L2TLB 中所有 entry 无效。

                    期望效果：
                        所有 tag valid 清 0。
                        data 可以同步写 0。
                        清除 L1 uTLB。
                        LSU 发起时返回 mmu_lsu_tlb_inv_done。
                        CP0 发起时返回 mmu_cp0_tlb_done。

                    实现要点：
                        counter 扫描 set index 0..255。
                        每个 set 写一次。
                        bank select 使用 8'hff。
                        tag/data 写入 0。
                        一次清一个 set 的 8 个 way。
                        RRPV 不需要清，因为hit 和 replacement policy 都正确依赖 entry valid。而entry被新置为valid时，对应entry的rrpv会置为3


                    6. INVASID
                    ----------

                    目的：
                        使指定 ASID 的非 global entries 无效。

                    期望效果：
                        清除满足以下条件的 entry：

                        entry.valid && !entry.global && entry.asid == inv_asid

                        保留 global entries。
                        保留其他 ASID 的 entries。
                        清除 L1 TLB。
                        LSU 发起时 abort PTW，并在完成后返回 mmu_lsu_tlb_inv_done。

                    实现要点：
                        按 set 扫描。
                        counter 扫描 set index 0..255。
                        读阶段 bank select 使用 8'hff，一次读 8 个 way。
                        L2TLB 内部生成 8-bit ASID hit vector：

                        asid_hit_vec[i] =
                            final_way_vld[i]
                            && !final_way_g[i]
                            && final_way_asid[i] == tlboper_l2tlb_inv_asid

                        如果 asid_hit_vec 非 0，进入写阶段。
                        写阶段 bank select 使用 asid_hit_vec。
                        tag/data 写入 0。
                        一次清掉同一个 set 中所有 ASID 命中的 way。

                        控制信号：
                        tlboper_l2tlb_invasid_on

                        L2TLB 根据 operation 类型选择返回给 tlboper 的 way mask：

                        l2tlb_tlboper_sel =
                            tlboper_l2tlb_tlbwr_on   ? victim_way :
                            tlboper_l2tlb_invasid_on ? asid_hit_vec :
                                                        final_way_hit;


                    7. INVVA_ALL
                    ------------

                    目的：
                        按 VA 使匹配 entry 无效，不比较 ASID。

                    期望效果：
                        清除所有匹配该 VA 的 entries。
                        忽略 ASID。
                        对 L1 uTLB 发出 VA invalidate 请求。
                        LSU 发起时 abort PTW，并在完成后返回 mmu_lsu_tlb_inv_done。

                    实现要点：
                        读阶段使用 compare-with-VA。
                        bank select 使用 8'hff，一次读 8 个 way。
                        arbiter 根据 VA/VPN 生成 8 个 skew index。
                        tlboper_l2tlb_cmp_noasid 置 1。
                        L2TLB 生成 final_way_hit。
                        写阶段 bank select 使用 final_way_hit。
                        tag/data 写入 0。
                        触发 tlboper_utlb_inv_va_req。


                    8. INVVA_ASID
                    -------------

                    目的：
                         按 VA + ASID 使匹配 entry 无效。

                    期望效果：
                        清除 VA 匹配且 ASID 条件满足的 entries。
                        对 L1 TLB 发出 VA invalidate 请求。
                        LSU 发起时 abort PTW，并在完成后返回 mmu_lsu_tlb_inv_done。

                    实现要点：
                        读阶段使用 compare-with-VA。
                        bank select 使用 8'hff，一次读 8 个 way。
                        arbiter 根据 VA/VPN 生成 8 个 skew index。
                        tlboper_l2tlb_asid_sel 置 1，使 L2TLB 使用 LSU 提供的 ASID 参与比较。
                        L2TLB 生成 final_way_hit。
                        写阶段 bank select 使用 final_way_hit。
                        tag/data 写入 0。
                        触发 tlboper_utlb_inv_va_req。


    2.3 arbiter
        overview
        arbiter的职责是对访问l2tlb的请求进行仲裁，并选择正确的访问l2tlb的vpn和access type，l2tlb的sram的选择信号，以及生成访问l2tlb的sram的index等控制信号。
        l2tlb 总共有4个访问来源：1.l2tlb request queue发来的l1tlb的lookup 请求；2.pfu发来的lookup请求；3.ptw的请求；4.tlb operation模块的请求。
        每一拍arbiter只能给其中一个来源授权访问l2tlb。

        function description
            1.仲裁
                每一拍arbiter只能给其中一个来源授权访问l2tlb。
                仲裁的优先级是：ptw > tlb operation > request queue > prefetch
                虽然访问l2tlb有4个来源，但是访问类型却有6种
                    1.来源为ptw的有两种访问请求。由于l2tlb的替换算法是SRRIP，而对应的RRPV值是存在SRAM中。所以ptw回填时，需要先读RRPV SRAM，读出对应的rrpv值之后，找到victim entry，然后再对l2tlb发起写操作进行页表项的回填。
                        a.ptw读操作
                        b.ptw写操作
                    2.来源为l2tlb reqq的请求也可以细分为两种
                        a.l1itlb的请求
                        b.l1dtlb的请求
                    3.pfu的prefetch请求
                    4.tlb operation的请求
                ptw refill完成的时候，会有一个refill_pa_vld（代码中不一定叫这个名字）的信号，当它拉高时，对这个信号打两拍，打两拍后的信号作为ptw write请求，而refill_pa_vld作为ptw read请求
                由于l2tlb的替换算法是SRRIP，而对应的RRPV值是存在SRAM中，ptw回填时，需要先读出RRPV SRAM中的rrpv值，根据rrpv值找到victim entry，所以在给ptw read请求授权之后，别的l2tlb不能被访问。因为l2tlb被访问就会更新rrpv值，这会导致ptw read读出来的是旧的值。所以当ptw read请求被授权时，会拉高ptw_on信号，当ptw_on信号拉高时，不会给除了ptw write请求之外的任何请求授权。当ptw write请求被l2tlb接收时，拉低ptw_on信号，取消对其他请求的阻塞。
                tlb operation有可能是需要持续进行的操作，并且不能被打断。所以当tlb operation的请求被arbiter授权之后，会拉高tlboper_on信号。当tlboper_on为高的时候，arb不能给除了tlb operation以外的所有请求授权。当tlb operation模块传回tlb operation结束的信号时，拉低tlboper_on信号，取消对其他请求的阻塞。
                pfu发来prefetch请求时，在得到结果前，会一直拉高同一个请求信号（lsu_mmu_va2_vld），所以需要在给pfu的prefetch请求授权之后，屏蔽掉pfu的请求信号。所以当pfu的prefetch请求被授权之后，会拉高prefetch_mask信号，当l2tlb返回prefetch需要replay（pfu的请求在l2tlb中miss且l2tlb miss buffer满了无法接收这个miss请求），或者l2tlb返回pfu请求的pa_vld信号，或者l2tlb返回pfu请求的error信号（page fault或access fault）时，拉低prefetch_mask信号。
                a.给ptw read请求授权的条件是：ptw模块发来ptw_arb_req信号，并且tlboper_on不为1且ptw_on信号不为1。
                b.给ptw write信号授权的条件是：ptw_write_req2信号为1（由ptw_arb_req信号打两拍得到），且tlboper_on不为1且ptw_on信号为1。
                c.给tlb operation授权的条件是：有tlboper_arb_req且没有ptw read请求，且ptw_on信号不为1。
                d.给l2tlb reqq授权的条件是：有l2tlb reqq的请求且没有ptw read请求，且ptw_on信号不为1，且tlboper_on不为1，且没有tlb operation请求。
                e.给pfu的prefetch请求授权的条件是：有lsu发来的预取请求（lsu_mmu_va2_vld），并且mmu没有被关闭，并且没有ptw read请求，并且没有tlb operation请求，并且没有l2tlb reqq的请求，并且ptw_on信号不为1，且tlboper_on不为1，且prefetch_mask信号不为1。

            2.生成访问l2tlb sram的index
                在 RISC-V SV39 架构中，系统支持三种页面大小：4KB , 2MB , 1GB 。传统的组相联（Set-Associative）TLB 在处理混合页大小时要根据页大小使用不同索引位，硬件无法在查找前预知页大小，只能：
                    - 串行查找，效率较低
                    - 静态分区，TLB空间利用率低
                Skewed Associative 解决方案
                    采用 8-Way Skewed Associative 架构。
                        - 核心原理： 将 TLB 分割为 8 个独立的存储体（Way），每个 Way 拥有完全独立且正交的哈希索引函数。
                        - 优势：
                            1. 并发支持： 利用不同的 Way 并行“猜测”不同的页大小。
                            2. 抗冲突： 即使两个地址在 Way 0 发生索引冲突，由于 Way 1 的哈希函数完全不同，它们在 Way 1 几乎不可能冲突。
                            3. 无空间浪费： 任意页大小均可利用 TLB 的整体容量，无需静态分区。
                      引入 Selector。
                        - 原理： 利用虚拟地址的特定位 VA[31:30] 作为随机选择子，强制规定每个 Way 在当前查找周期应假设的页大小。
                    这8个way都有自己单独的sram bank，访问这8个bank的index也各不相同。
                index生成步骤：
                    1.提取基础index
                        a.当Selector (VA[31:30])为00时：Way 0按照4k page size从VPN中提取index，	Way 1按照4k page size从VPN中提取index,	Way 2按照2m page size从VPN中提取index,	Way 3按照1g page size从VPN中提取index,	Way 4按照4k page size从VPN中提取index,	Way 5按照4k page size从VPN中提取index,	Way 6按照2m page size从VPN中提取index,	Way 7按照1g page size从VPN中提取index
                        b.当Selector (VA[31:30])为01时：Way 0按照2m page size从VPN中提取index，	Way 1按照1g page size从VPN中提取index,	Way 2按照4k page size从VPN中提取index,	Way 3按照4k page size从VPN中提取index,	Way 4按照2m page size从VPN中提取index,	Way 5按照1g page size从VPN中提取index,	Way 6按照4k page size从VPN中提取index,	Way 7按照4k page size从VPN中提取index
                        c.当Selector (VA[31:30])为10时：Way 0按照4k page size从VPN中提取index，	Way 1按照4k page size从VPN中提取index,	Way 2按照1g page size从VPN中提取index,	Way 3按照2m page size从VPN中提取index,	Way 4按照4k page size从VPN中提取index,	Way 5按照4k page size从VPN中提取index,	Way 6按照1g page size从VPN中提取index,	Way 7按照2m page size从VPN中提取index
                        d.当Selector (VA[31:30])为11时：Way 0按照1g page size从VPN中提取index，	Way 1按照2m page size从VPN中提取index,	Way 2按照4k page size从VPN中提取index,	Way 3按照4k page size从VPN中提取index,	Way 4按照1g page size从VPN中提取index,	Way 5按照2m page size从VPN中提取index,	Way 6按照4k page size从VPN中提取index,	Way 7按照4k page size从VPN中提取index
                    2.根据提取的基础index，生成skew_index
                        把提取的基础index进行hash运算，hash运算出来的结果作为skew_index
                发给l2tlb的index取决于给哪个请求来源授权
                    1.给ptw，reqq,pfu的prefetch授权，或者给tlb operation授权，且这次的tlb operation需要从va中提取index时（tlboper_arb_idx_not_va为0）：选择skew_index
                    2.给tlb operation授权且这次的tlb operation不需要从va中提取index时（tlboper_arb_idx_not_va为1）：选择tlb operation模块发给arbiter的index（tlboper_arb_idx）
            3.生成访问l2tlb bank的选择信号
                由于l2tlb是采用skew associative tlb这一微架构，所以ptw完成需要回填时，要按照实际的page size和Selector (VA[31:30])的值来决定把哪些entry作为候选。
                    a.当Selector (VA[31:30])为00时
                        1.当ptw回填的页表项实际page size为4k时，只访问bank0，1，4，5。mask_bank_sel = 00110011
                        2.当ptw回填的页表项实际page size为2m时，只访问bank2,6。mask_bank_sel = 01000100
                        3.当ptw回填的页表项实际page size为1g时，只访问bank3,7。mask_bank_sel = 10001000
                    b.当Selector (VA[31:30])为01时
                        1.当ptw回填的页表项实际page size为4k时，只访问bank2，3，6，7。mask_bank_sel = 11001100
                        2.当ptw回填的页表项实际page size为2m时，只访问bank0，4。mask_bank_sel = 00010001
                        3.当ptw回填的页表项实际page size为1g时，只访问bank1，5。mask_bank_sel = 00100010
                    c.当Selector (VA[31:30])为10时
                        1.当ptw回填的页表项实际page size为4k时，只访问bank0，1，4，5。mask_bank_sel = 00110011
                        2.当ptw回填的页表项实际page size为2m时，只访问bank3,7。mask_bank_sel = 10001000
                        3.当ptw回填的页表项实际page size为1g时，只访问bank2,6。mask_bank_sel = 01000100
                    d.当Selector (VA[31:30])为11时
                        1.当ptw回填的页表项实际page size为4k时，只访问bank2，3，6，7。mask_bank_sel = 11001100
                        2.当ptw回填的页表项实际page size为2m时，只访问bank1，5。mask_bank_sel = 00100010
                        3.当ptw回填的页表项实际page size为1g时，只访问bank0，4。mask_bank_sel = 00010001
                1.当给ptw read请求授权时，arb发给l2tlb的bank选择信号（arb_l2tlb_bank_sel）选择mask_bank_sel
                2.当给ptw write请求授权时，arb发给l2tlb的bank选择信号（arb_l2tlb_bank_sel）选择替换算法模块发来的victim entry所在的bank
                3.当给pfu的prefetch请求和reqq的请求授权时，选择所有的bank
                4.当给tlb operation请求授权时，选择tlb operation模块发来的bank选择信号（tlboper_arb_bank_sel）
            4.生成发给l2tlb的va比较信号（arb_l2tlb_cmp_with_va）
                a.当给pfu的prefetch请求和reqq的请求授权时，需要查找l2tlb，所以此时要拉高arb_l2tlb_cmp_with_va
                b.当给tlb operation请求授权，且tlb operation模块拉高这个请求需要比较va的信号（tlboper_arb_cmp_va）时，也需要在l2tlb中查找，此时也拉高arb_l2tlb_cmp_with_va。
                c.其他情况无需进入l2tlb的lookup流水线，所以不拉高arb_l2tlb_cmp_with_va信号
            5.生成access type信号
                a.如果访问l2tlb的请求来源是pfu，那么arb_l2tlb_acc_type[2:0]=3'b100
                b.如果访问l2tlb的请求来源是ptw write，那么arb_l2tlb_acc_type[2:0]=3'b101
                c.如果访问l2tlb的请求来源是itlb，那么arb_l2tlb_acc_type[2:0]=3'b011
                d.如果访问l2tlb的请求来源是dtlb的load，那么arb_l2tlb_acc_type[2:0]=3'b010
                e.如果访问l2tlb的请求来源是dtlb的store，那么arb_l2tlb_acc_type[2:0]=3'b110
                f.如果访问l2tlb的请求来源是tlb operation，那么arb_l2tlb_acc_type[2:0]=3'b001
                g.如果访问l2tlb的请求来源是ptw read，那么arb_l2tlb_acc_type[2:0]=3'b000

    2.4 l2tlb miss buffer
        overview
        在l2tlb的lookup流水线中miss的pfu，itlb，dtlb的请求会进入l2tlb miss buffer
        从微架构上看，每拍最多只会有一个miss请求需要进入miss buffer。
        进入miss buffer的请求将作为候选，准备发到ptw模块。
        l2tlb miss buffer是用d-flip-flop搭建的
        在l2tlb miss buffer中给l1dtlb发来的请求预留了多个专用的entry，具体数量可配置，目前是8个l1dtlb和pfu专用的entry。给l1itlb预留了1个专用entry

        function description
            在l2tlb miss buffer的entry中，entry 0为l1itlb专用，entry1到entry8为l1dtlb专用。
                当有来源为l1itlb的请求时，就把entry0分配给l1itlb；当有来源为l1dtlb或pfu的请求时，就从entry1到entry8之间，找到最低位的空闲entry，分配给这个dtlb或pfu的请求。
            当l2tlb miss buffer中存在有效且未发射的entry且ptw的ready信号拉高，或者当l2tlb miss buffer不存在有效且未发射的entry但是l2tlb的lookup流水线发来miss请求且ptw的ready信号拉高时，l2tlb会发请求到ptw模块
                当ptw的ready信号拉高且l2tlb miss buffer中存在有效且未发射的entry时，无论l2tlb的lookup流水线有没有发来miss请求，都会在l2tlb miss buffer中有效且未发射的entry中，选出一个发送到ptw。
                    如果l2tlb miss buffer中有来源为itlb的未发射的请求，也就是说entry0有效且未发射，那么会优先选择把entry0的请求发送出去。
                    如果l2tlb miss buffer中没有来源为itlb的未发射的请求，那么会从来源为dtlb的未发射请求中选一个发送到ptw，也就是说，itlb的优先级高于dtlb。
                当l2tlb miss buffer不存在有效且未发射的entry，但是l2tlb的lookup流水线发来miss请求且ptw的ready信号拉高时
                    如果miss buffer有空闲entry的话，会把lookup流水线发来的miss请求发送到ptw，同时给lookup流水线发来的miss请求分配miss buffer entry。
                    如果miss buffer没有空闲entry的话，会发feedback信号给l2tlb reqq，把reqq中对应entry的sent信号拉低，而不给这个miss请求分配miss buffer entry。

            l2tlb miss buffer的entry中目前存储：r_vld ，r_sent,entry_vpn[26:0]，entry_l1eid[2:0]，entry_type[2:0]。
                r_vld：表示该 miss buffer entry 是否有效。分配成功时置 1，PTW completion feedback 命中本 entry 且 fb_hit=1 时清 0。
                r_sent：表示该 entry 的请求是否已经发给 PTW。r_sent=0 时 entry 是 ready，可被仲裁发出；r_sent=1 时说明请求已经在 PTW 路径中等待完成。若分配同周期走 bypass 且 PTW ready，则初始化为 1；普通 issue grant 后也置 1。dealloc（即ptw refill完成且ptw refill的l2tlb miss buffer entry id匹配） 或 tlboper_ptw_abort 会清0。
                entry_vpn[26:0]：保存 miss 请求对应的 VPN。来源是 L2TLB pipeline 的 final_vpn，通过 req_vpn -> alloc_vpn 写入。后续发 PTW 时作为 issue_vpn/l2tlb_ptw_vpn 输出。
                entry_l1eid[2:0]：保存原始 L1 miss buffer entry id。对 DTLB miss，来自 final_eid/req_l1eid；对 ITLB miss，wrapper 里强制写 0。发给 PTW 的 issue_eid 会把 L2 MB entry index 和这个 L1EID 拼起来：{l2_mb_entry_id, l1eid}。
                entry_type[2:0]：保存访问类型，也就是 PTW type / access type。来源是 final_acc_type/req_acc_type。当前编码在代码中可见：3'b010 load，3'b110 store，3'b011 fetch，3'b100 prefetch/PFU。后续用于 PTW walk 和 completion 类型判断。
                当前 L2TLB miss buffer entry 保存的是“L2 miss 后发 PTW 所需的请求上下文”。

    2.5 replacement policy
        overview
        RRIP（Re-Reference Interval Prediction）算法是一种缓存替换算法，其原理是通过为每个缓存块存储其重引用预测值（RRPV），以此来预测数据块的重引用间隔。
        举例说明：
            L2TLB为way0-7，对于相同index，出现miss情况，需要allocate tlb entry时。若存在空闲way，则直接分配该way(多个空闲时，按照优先级way0->way7)，若无空闲way，则需要使用RRIP算法选择victim way。RRIP算法实际为读取不同entry的未访问时长（即RRPV）。

        RRPV使用方法：
            使用sram存储rrpv值（范围为0-7）。当某个way初次被allocate时，将其RRPV置为3，每当其被再次访问时，将其RRPV值置为0（最不易被替换）。每次访问会令其他way的RRPV值+1（即其他way经过一段时间未被访问）
            - 每次访问将被访问的entry RRPV值+1，无论hit/miss，都会更新rrpv值。
                - 如果hit，那么hit的entry RRPV值置为0，其他未hit的其他entry的RRPV值+1；
                - 如果miss，那么所有被访问的entry RRPV值+1
                - 如果ptw refill，将被写入的entry rrpv值置为3。

    2.6 rrpv write buffer
        overview
            RRPV SRAM 是单端口 SRAM。ReqQ 和 PFU 的 lookup 需要读 RRPV SRAM，lookup 结束后又需要根据 hit/miss 结果更新 RRPV。如果 lookup 更新直接写 RRPV SRAM，就会和新的 lookup 读请求产生读写结构冲突。因此 ReqQ/PFU lookup 产生的 RRPV 更新不直接写 SRAM，而是先进入 RRPV write buffer。
            RRPV write buffer 按 8 个 RRPV bank 组织。每个 buffer entry 都为 bank0 到 bank7 分别保存一组待写信息：vld、index 和 rrpv。vld 来自当次 L2TLB lookup 读出的 entry valid，表示该 bank 的 RRPV 更新是否需要最终写回 SRAM；index 是该 bank 独立的 skew index；rrpv 是 replacement policy 计算出的新 RRPV 值。
            当来自 ReqQ 或 PFU 的 lookup 在 final 阶段产生新的 RRPV 值时，L2TLB 会把 8 个 bank 的 index、entry vld 和 new RRPV 同时送入 RRPV write buffer。write buffer 接收新值时按 bank 独立做 CAM 比较：bank0 的待写 index 只和 buffer 中 bank0 的有效 index 比较，bank1 的待写 index 只和 buffer 中 bank1 的有效 index 比较，依此类推。不同 bank 之间即使 index 数值相同，也不能互相命中或覆盖。
            如果某个 bank 在 write buffer 中命中同 bank、同 index 的旧待写项，新来的 vld 和 rrpv 会覆盖旧项，且不新增 FIFO 占用。这样同一个 bank/index 上连续多次 RRPV 更新时，write buffer 中始终保留最新值。如果某个 bank 没有命中，则该 bank 的新待写项写入当前写指针指向的 buffer entry。只要本次 push 存在任意未命中的 bank，就会占用一个新的 FIFO entry，并推进写指针。
            当 RRPV write buffer 满或达到 arbiter stall 水位时，arbiter 必须阻塞会进入或依赖 RRPV write buffer 的 L2TLB 访问请求。被阻塞的来源包括 ReqQ、PFU、PTW read 和 TLB operation；阻塞期间这些来源不会产生新的 arb_l2tlb_req，避免继续接收 lookup 导致 write buffer overflow。对 arbiter 暴露的 full/stall 信号可以在实际 FIFO 满前预留若干 entry，用于吸收 full 生效前已经在 L2TLB raw/final/push 路径中的 ReqQ/PFU RRPV 更新。PTW write 不进入 RRPV write buffer，而是直接写 tag/data/RRPV SRAM，因此 RRPV write buffer full 不阻塞 PTW write，PTW write 仍可由 arbiter 授权并产生 arb_l2tlb_req。
            当没有任何 arb 授权的请求访问 L2TLB 时，RRPV write buffer 可以使用这个空闲周期写 RRPV SRAM。每次 drain 按读指针指向的 buffer entry 一次性 pop 出 bank0 到 bank7 的 8 个候选值，但只有对应 vld 为 1 的 bank 才真正打开 RRPV SRAM 写使能；vld 为 0 的 bank 不写 SRAM。drain 完成后清空该 buffer entry 的 bank vld，推进读指针并释放该 entry。
            RRPV write buffer 还提供 bypass。Lookup 或 replacement policy 需要使用 RRPV 时，如果同 bank、同 index 在 write buffer 中有有效待写值，应使用 write buffer 中最新的 RRPV，而不是 RRPV SRAM 中尚未更新的旧值。如果多个 pending 写命中同一个 bank/index，使用最新的待写值。同周期刚从 ReqQ/PFU final 阶段 push 进入 write buffer 的 RRPV 更新，也参与当前 lookup 的 bypass 比较。
            PTW refill 和 TLB operation 的直接 SRAM 写路径保持独立。PTW refill write 仍写 tag/data/RRPV SRAM；TLB operation 写也按自己的 bank select 写 SRAM。RRPV write buffer full 触发 arbiter 阻塞时，PTW delayed write 不能丢失；由于 PTW write 不占用 write buffer，它不需要等待 write buffer drain 出空间，只需要满足 ptw_on 且没有 tlboper_on，就可以被授权写入。
            复位后 RRPV write buffer 的 wr_ptr=0、rd_ptr=0、count=0，所有 bank vld 无效，empty=1，full=0。buffer payload 中的 index 和 rrpv 在 vld 为 0 时无意义。

3.pipeline
    overview
        当前 L2TLB 的查找是一套统一的 8-way skew associative 查找流水。无论请求来自 L1TLB、PFU 还是 TLB operation，都会先由 arbiter 选中，再根据 VPN 生成每个 way 的 skew index，或者在某些 TLB operation 中直接使用给定 index访问。真正的 tag compare 在 L2TLB 内部统一完成。
        单个 way 的基本命中条件是：
            1.该 way 的 entry valid；entry 中记录的 page size 和当前这个 way 根据 VPN 预测出来的 page size 一致；
            2.查找 VPN 按该 page size 做 mask 后，和 entry 中保存的 VPN 一致；
            3.ASID 匹配，或者 entry 是global，或者当前操作要求忽略 ASID。
            只有这些条件全部满足，这个 way 才算 VA hit。

        对 L1TLB 来说，包括 L1 ITLB miss 和 L1 DTLB miss，都是按 VA 查找。
            ITLB miss 进入 ReqQ 的 entry 0，DTLB miss 进入 DTLB 对应的 ReqQ entry。
            arbiter grant 后，L2TLB 会查所有 way，并打开 VA compare。
            L1TLB 请求的 hit 判断条件是：
                8 个 way 中恰好有一个 way 满足上述基本命中条件。
                如果恰好一个 way hit，就返回 PPN、flag、page size、VPN 给对应的 L1 ITLB 或 L1 DTLB。
                如果 0 个 way hit，就是 L2TLB miss，PTW 使能时进入 miss buffer 发起 PTW；
                如果多个 way hit，则认为是 multi-hit，不作为正常 hit 返回。

        对 PFU 来说，也是按 VA 查找。
            PFU 使用 lsu_mmu_va2 中的 VPN，查所有 way，并打开 VA compare。
            PFU 的 L2TLB hit 判断条件和 L1TLB 一样：
                8 个 way 中恰好一个 way 满足 valid、page size、VPN mask、ASID/global/忽略 ASID 条件。
                PFU 单 hit 之后还不一定最终成功，它还要继续检查 flag、sysmap 和 PMP。如果权限或属性检查通过，PFU 返回 PA valid；
                如果 L2TLB 多 hit、PTW 关闭时 miss、flag fault 或 PMP deny，则走 PFU error/deny 路径。

        对 TLBP 来说，它是 TLB operation 中的按 VA probe。
            TLBP 会用当前寄存器中的 VPN 和 ASID 查所有 way，并打开 VA compare。
            TLBP 的 hit 判断条件也是：
                恰好一个 way 满足基本 VA hit 条件。此时 l2tlb_regs_hit 为真，并返回probe hit index。
                如果没有 way hit，则 probe miss。
                如果多个 way hit，则 l2tlb_regs_hit_mult 为真，表示 probe 发现 multi-hit，不是正常单 hit。

        对 INVVA 的读阶段来说，它也是按 VA 查找。
            它使用来自 LSU 或当前操作指定的 VA/VPN，查所有 way，并打开 VA compare。
            INVVA 的 VA hit 判断条件是：
                至少有一个 way 满足基本 VA hit 条件。这里和普通访问不同，INVVA 更关心有没有匹配项用于后续无效化，所以输出侧会用 VA hit 信息选择要写无效的 way。
                若操作要求忽略 ASID，则 ASID 条件会被放宽，只要 VPN/page size/valid 匹配，并且 global 或 no-ASID 条件成立即可。
        对 TLBR 来说，它不是按 VA 判断 hit，而是按 index 读。
            TLBR 使用 MIR 中给出的 index 和 bank select 去读指定 way，不打开 VA compare。因此 TLBR 没有普通意义上的 “VPN 命中”。它的“选中条件”是 index 和 bank select 指到了某个 way，然后把该 way 的 VPN、ASID、G、page size、PPN、flag 读出来。

        对 TLBWI 来说，它也是按 index 操作。
            TLBWI 使用 MIR 给出的 index 和 bank select，直接写指定 way，不依赖 VA compare，也没有普通 hit/miss 判定。它的“命中/选中”含义就是 index 选中的目标 way。

        对 TLBWR 来说，读阶段通常会查所有 way 或根据当前替换策略选择 victim。
            写阶段使用 L2TLB replacement policy 给出的 victim way。
            TLBWR 不是依赖 VA compare 判断 hit 后再写，而是以 victim way 作为写入目标。因此它的关键条件不是 VA hit，而是 replacement policy 选出的 way。

        对 INVASID 和 INVALL 来说，它们本质是按 index/counter 扫描。
            INVALL 不需要 VA hit，通常是按 index 遍历并写无效。INVASID 也不是普通 VA hit，它先按 index 读出 entry，然后判断 entry 的 ASID 是否等于目标 ASID，并且entry 不是 global；满足这个 ASID 条件的 entry 才需要被无效化。

    function description
        下面按“请求被 arbiter 送进 L2TLB 的那个周期叫 T0”来描述。当前 RTL 里可以看成 3 个主要阶段：T0 发起 SRAM 访问，T1 做 raw compare，T2 产生命中结果和返回/分配动作。
        T0 是仲裁和发起查找周期。
            这一拍 arbiter 从 PTW、TLB operation、ReqQ、PFU 里选一个来源。优先级大体是 PTW，高于 TLB operation，高于 L1TLB ReqQ，高于 PFU。
            被选中的请求形成一组送给 L2TLB 的信息：VPN、访问类型、是否写、bank select、是否按 VAcompare、每个 way 的 index、以及写入 tag/data。
            如果是 L1TLB miss 或 PFU，请求是按 VA 查找，bank select 是所有 way，cmp_with_va 打开。arbiter 用 VPN 生成 8 个 way 各自的 skew index。
            如果是 TLBP 或 INVVA read，也是按 VA 查找，cmp_with_va 打开。
            如果是 TLBR、TLBWI、INVASID、INVALL 这类 index 操作，就不用 VPN 生成 skew index，而是把 TLB operation 给出的 index 直接送到各 way，cmp_with_va 关闭。
            同一个 T0，L2TLB 用这些 index 去访问 tag array、data array、RRPV array。
            对于写请求，比如 PTW refill 写入、TLBWI、TLBWR、invalidate 写无效，T0 同时根据 bank select 产生写使能。PTW refill 不会进入后面的 hitcompare 流水；它主要是写 array 和更新 RRPV。

            T0 末尾，也就是这个时钟边沿之后，L2TLB 把请求本身的信息打一拍进入 raw stage，包括 VPN、访问类型、ReqQ id、L1 DTLB eid、bank select、cmp_with_va、每个 way 的预测 page size 等。
            只有需要查找/比较的请求才会置起 raw valid；PTW refill 写和 PTW 读类请求不会作为普通 raw compare 请求继续往后走。

        T1 是 SRAM 读出和 raw compare 周期。
            这一周期 tag/data array 的读出数据已经对应 T0 发起的那组 index。L2TLB 把每个 way 的 tag 拆开，得到 valid、VPN、ASID、page size、G 位；data 拆成 PPN 和 flag。
            后每个 way 独立做命中判断。判断条件分成几部分。
                第一，entry 必须 valid。
                第二，entry 里存的 page size 要和这个 way 当前预测的 page size 一致。
                第三，查找 VPN 要按该 page size 做 mask 后和 entry VPN 一致。4K 比较完整 VPN；2M 会忽略页内较低 VPN 段；1G 会忽略更大的低位 VPN 段。
                第四，ASID 条件要满足，也就是 ASID 相等，或者 entry 是 global，或者当前 TLB operation 要求忽略 ASID。当前忽略 ASID 的信号是 tlboper_l2tlb_cmp_noasid，来自 ct_mmu_tlboper 的 tlboper_jtlb_cmp_noasid。
            T1 末尾，L2TLB 把每个 way 的 compare 子结果、读出的 tag/data 字段、请求类型、VPN、id 等打一拍进入 final stage。

        T2 是 final hit 汇总和结果输出周期。
            这一周期 L2TLB 根据 T1 打拍后的每个 way hit 结果做汇总。
            如果 8 个 way 里 0 个 way hit，就是 miss。
            如果恰好 1 个 way hit，并且这个请求是按 VA compare 的请求，也就是 cmp_with_va 为真，就是正常 single hit。
            如果不是 miss，也不是正常 single hit，就归为 multi-hit 或非普通 hit 情况。

            对 L1TLB 请求来说，T2 如果是 single hit，就产生返回给 L1 ITLB 或 L1 DTLB 的完成和 PA valid，同时返回 VPN、page size、PPN、flag。
            如果是 miss，并且 PTW 使能，就分配 L2TLB miss buffer，后续由 miss buffer 向 PTW 发起页表遍历。ReqQ 会收到 miss allocated 的反馈并释放 entry。
            如果 miss buffer 满，则 ReqQ 收到 retry，entry 重新变成 ready，之后再发。
            如果是 multi-hit，或者 PTW 关闭时 miss，就通过 page fault 类路径返回给对应 L1TLB。

            对 PFU 请求来说，T2 的 L2TLB hit 判定和 L1TLB 一样，也是要求恰好一个 way VA hit。
                single hit 后，PFU 不会立刻只看 L2TLB hit 就结束，还要用读出的 flag、sysmap、PMP 结果做权限和属性检查。
                PFU 有自己的小 FSM：先从 idle看到 L2TLB/PFU 完成，然后进入 check；如果检查失败进 deny，如果通过进 ok。最终对 LSU 输出 PA valid，或者 PA error。

            对 TLBP 来说，T2 如果恰好一个 way VA hit，就报告 probe hit，并生成 hit index；如果 0 个 hit，就是 probe miss；如果多个 hit，就报告 hit multiple。

            对 INVVA read 来说，T2 关注的是是否有 VA hit，以及 hit 的 way，用于后续写无效。

            对 TLBR、TLBWI、INVASID、INVALL 这类 index 操作来说，T2 不按普通 VA hit 解释。
                它们更像是“读出被 index/bank select 选中的 entry”。
                TLBR 把选中 entry 的 VPN、ASID、G、page size、PPN、flag 返回；
                INVASID 再用读出的 ASID和 G 位判断是否需要无效化；
                INVALL 直接按扫描/选中目标写无效；TLBWI/TLBWR 则按指定 way 或 victim way 写入。

        用一句话概括时序就是：T0 仲裁并发起 array 访问，同时保存请求；T1 array 数据出来并做每个 way 的 tag compare，同时保存 compare 和数据；T2 汇总 single hit、miss、multi-hit，并根据请求来源返回 L1TLB、驱动 PFU 检查、反馈 ReqQ/miss buffer，或者完成 TLB operation。


4.spec unclear points / open questions
    说明
        以下问题完全基于本 spec 文本本身整理，不基于 RTL 行为推断答案。问题的目标是把会影响 UVM 建模、scoreboard、checker、sequence、coverage 和 corner case 判定的模糊点先显式列出来。

    4.1 全局架构与容量
        1. spec 中一处写“每个 way 有1024个set”，TLB operation 部分又写“每个 way 有256个set”，同时推荐 index[7:0] 作为 set index；L2TLB 每个 way 的真实 set 数到底是 1024 还是 256？
        回答：每个 way 有1024个set是笔误，其实是每个 way 有256个set，已更正。

        2. 如果每个 way 是 1024 set，那么 TLB operation 的 index 编码是否应包含 10-bit set index，而不是只使用 index[7:0]？
        回答：每个 way 有1024个set是笔误，其实是每个 way 有256个set，已更正。

        3. “l2tlb 每拍只能接收一个请求”是否包括 PTW write、TLB operation 多周期扫描、RRPV write buffer drain 这些内部写请求？
        回答：   1. 包括 PTW write。
                    PTW read 和两拍后的 PTW write 都是 mmu_arb 输出到 L2TLB 的 arb_l2tlb_req 来源之一。arb_l2tlb_req 明确 OR 了 arb_ptw_write_grant，并且 arb_l2tlb_write 在 PTW write 时拉高。
                2.包括 TLB operation 的每一个扫描访问 beat。
                    TLB operation 不是“整个多周期操作算一个 L2TLB 请求”，而是 FSM 每到 RD/WT/INVALL 等阶段发一次 tlboper_arb_req，每次 grant 都占用一个 arb_l2tlb_req beat。
                3.不把 RRPV write buffer drain 算作 arbiter 接收的 L2TLB 请求，但它算 RRPV SRAM 端口访问。
                    drain 只在没有外部仲裁请求进入 L2TLB 时发生。
                L2TLB arbiter 每拍最多 grant 一个访问来源：PTW read、PTW write、TLBOp、ReqQ、PFU 互斥。
                RRPV write buffer drain 不参与这个 grant one-hot，但要单独约束 RRPV SRAM 端口：drain 只能在 !arb_l2tlb_req 的空拍写入，不能和 PTW/TLBOp/lookup 的 RRPV 访问冲突。


        4. “来源为 ptw 的请求无需进入 l2tlb 的 lookup 流水线”与后文“ptw read 读 RRPV、ptw write 写 tag/data/rrpv”的流水阶段关系是什么？
        回答：“不进入 lookup 流水线”，应理解为：PTW refill 不走 L2TLB 的 tag/data compare、hit/miss、final response 那条翻译查找流水；
             但它仍然会通过 arbiter 占用 L2TLB SRAM 端口，走一条 replacement/refill 专用的两阶段访问。
             关系可以这样拆：
                1. PTW read = replacement read，不是 translation lookup
                    PTW 完成 page walk 后先发 ptw_arb_req，arbiter grant 后编码成 arb_l2tlb_acc_type == 3'b000。
                    这一拍用于按 VPN/page size 生成 index 和 mask_bank_sel，去读 RRPV，目的是给 replacement policy 选 victim。
                    它不应该参与 tag compare / hit miss / final_pa_vld 这类 lookup 结果路径。
                2. PTW write = refill write
                    arb_ptw_grant 后，arbiter 用 ptw_write_req1/ptw_write_req2 延迟两拍生成 arb_ptw_write_grant，编码成 arb_l2tlb_acc_type == 3'b101，并拉高 arb_l2tlb_write。
                    这一拍用 victim_way 作为 bank select，写 tag/data/rrpv。
                3. 时序意图
                    简化成：
                    T0: PTW read grant，读 RRPV，ptw_on=1 阻塞其他普通访问。
                    T1: RRPV 数据进入 replacement policy，算 victim_way/rrpv_updata。
                    T2: PTW write grant，写 tag/data/rrpv，l2tlb_arb_ptw_cmplt 表示 L2TLB 接收写回。

        5. `signal description` 写“没有什么复杂信号需要特别描述”，但后文大量依赖 valid/ready/on/mask/abort/done 信号；是否需要补充正式接口信号表、方向、含义和时序？
        回答：已在signal description中补充相关内容。

        6. 本 spec 中 “l2tlb”“L2TLB”“JTLB”“uTLB”“L1 TLB” 等术语是否指不同结构？这些术语的边界和层次关系是什么？
        回答：l2tlb，L2TLB，JTLB均指levev 2 tlb（l2tlb）；uTLB，L1 TLB均指level 1 tlb(l1tlb)。l1tlb指l1dtlb和l1itlb。而l2tlb和l1tlb类似存储层次结构的l1cache和l2cache，是inclusive关系。

        7. L2TLB 是否支持多 hart、多 core、VMID 或 guest translation？如果不支持，ASID 是否是唯一地址空间标识？
        回答：L2TLB 不支持多 hart、多 core、VMID 或 guest translation 的地址空间区分。ASID 是非 global entry 的唯一地址空间标识。

        8. reset 后 tag/data/rrpv/ReqQ/miss buffer/RRPV write buffer/prefetch_mask/ptw_on/tlboper_on 的初值分别是什么？
        回答：1.tag/data/RRPV array 没有 cpurst_b reset 端口，只是通过 ct_spsram_wrapper -> mmu_fpga_ram。
                    当前仿真 RAM 在 initial 中把 mem[] 清 0，所以冷启动仿真初值是 0；但这不是 reset 清零语义。若 reset 发生在运行中，SRAM 内容不会被清；ASIC SRAM 也不能假设为 0。
                    所以仿真和验证阶段，与asic实际运行要分开理解。
              2.ReqQ：所有 entry r_vld=0、r_sent=0、vpn/asid/eid/type=0，即队列为空。
              3.miss buffer：所有 entry r_vld=0、r_sent=0、vpn/l1eid/type/queue_id=0，即 miss buffer 为空。
              4.RRPV write buffer：wr_ptr=0、rd_ptr=0、count=0，所以 empty=1、full=0；lookup_hit=0。buffer payload 本身没有清零，空时无意义。
              5.prefetch_mask=0
              6.ptw_on=0
              7.tlboper_on=0

    4.2 l2tlb request queue
        1. l2tlb reqq 中 DTLB entry 的发射选择策略只说“选一个”，是否明确为最低编号优先、round-robin、oldest-first，还是其他策略？
        回答：明确为选择最低编号的有效待发射entry。

        2. 当同拍 ITLB 和 DTLB 请求都到来且 reqq 原本无有效未发射 entry 时，spec 写只把 ITLB 请求送去仲裁；DTLB 请求是否仅入队，且 sent 初值为 0？
        回答：DTLB 请求仅入队，且 sent 初值为 0。

        3. 当新请求 bypass 送到 arbiter 但 arbiter 没有 grant 时，该 reqq entry 的 sent 应如何设置？
        回答：置为0。

        4. sent 是在“送到 arbiter”时置 1，还是在“arbiter grant 后进入 L2TLB”时置 1？
        回答：arbiter grant 后进入 L2TLB”时置 1。

        5. ReqQ entry 被释放的精确时刻是 T2 hit/miss allocated 当拍，还是下一拍？
        回答：T2 hit/miss allocated 当拍，拉高释放的相关信号，但由于dff的特性，在下一拍vld才会变低。

        6. ITLB entry0 如果尚未释放又收到新的 ITLB 请求，credit 协议保证不会发生，还是 L2TLB 需要处理或断言？
        回答：credit 协议保证不会发生ITLB entry0 如果尚未释放又收到新的 ITLB 请求。这部分会在l1itlb中进行断言和验证。

        7. `L1eid` 描述中写成 “litlb miss buffer entry id”，但 ITLB 没有 miss buffer；这里是否应为 “l1dtlb miss buffer entry id”？
        回答：可以理解为l1dtlb miss buffer entry id。因为ITLB 没有 miss buffer，所以对itlb来说L1eid根本就没用上，所以值是什么无所谓。

        8. ReqQ 是否需要保存 ASID、privilege mode、MMU enable、sum/mxr 等影响命中或权限检查的上下文？如果不保存，这些信息来自哪里？
        回答：ReqQ 没有真正保存这些上下文。它只保存/输出 vpn、eid、type、queue_id 这类请求标识。无需保存ASID，因为reqq是存储l1tlb的miss请求，而在l1tlb中根本就没有使用asid。
              privilege mode / MMU enable / sum / mxr 完全不在 ReqQ payload 中。
              ASID 来自当前 satp.asid。L2TLB 做 tag compare 时，用当前 ASID 和 tag 里的 ASID 比较；PTW refill 写 L2TLB tag 时，也用当前 ASID 写入。
              PTW refill tag 的 ASID：TWU 用当前 regs_ptw_cur_asid 写入 tag。
              privilege mode 来自当前 cp0_yy_priv_mode，数据访问还会受 MPRV/MMP 影响。SUM、MXR、MMU enable 也都是当前 CP0/MMU 控制信号。L1、L2、PTW/TWU 都是直接看这些当前值，而不是从 ReqQ entry 里取历史快照。privilege mode：L2TLB/DTLB 用当前 cp0_mmu_mprv ? cp0_mmu_mpp : cp0_yy_priv_mode
              同理，如果请求排队期间 privilege mode、SUM、MXR、MMU enable 改变，后级权限检查和 miss/refill 行为也会按“变化后的当前值”执行，而不是按请求产生时的上下文执行。
              MMU enable：regs_mmu_en = satp_mode == 4'b1000，L1 miss 入口用它过滤，L2 miss/PTW 路径还看当前 cp0_mmu_ptw_en

        9. ReqQ 只保存 vpn[26:0]，但 selector 使用 VA[31:30]；selector 是否一定可由 vpn[19:18] 还原？
        回答：是的。VA的低12bit是4k页面的页内偏移，va去掉低12bit就是vpn。

        10. ReqQ 中没有 PFU entry，但 miss buffer 中 PFU 与 DTLB 共用 entry1-entry8；PFU 请求在 miss buffer 满时如何 retry 或重新发起？
        回答：PFU 请求在l2tlb中miss且 miss buffer 满时，会拉低prefetch_mask信号，取消对pfu的请求的阻塞。这时pfu可以发起replay。无需通过reqq发起replay。

        11. 当 ReqQ entry 已 sent 但后续遇到 multi-hit、PTW disabled miss、permission fault 或 access fault 时，entry 是否都释放？
        回答：其实只要reqq发出去的请求有结果，reqq中的entry就可以被释放。命中，出现fault（page fault，或access fault（如果有的话），其实hit multi是算成page fault的），以及miss被miss buffer接收都算有结果。只有当miss且无法被miss buffer接收的情况才需要reqq做replay

        12. credit-based 握手由 L1TLB 验证，L2TLB UVM 是否仍需要检查“收到请求时一定有空 entry”这个假设？
        回答：不需要

    4.3 L2TLB entry、tag、data 与 index
        1. tag 声称 45 bit，但字段相加 vld(1)+VPN(27)+ASID(16)+global(1)+Size_Type(2)=47 bit；tag 位宽和字段布局哪个为准？
        回答：L2TLB tag：48 bit。之前的spec中描述有误，其实是48bit，并且page size是3bit。001是4k，010是2m，100是1g。打包顺序是：{vld, vpn[26:0], asid[15:0], pgs[2:0], g}。
                tag slice[47]      │ L2TLB entry valid
                tag slice[46:20]   │ VPN [26:0]
                tag slice[19:4]    │ ASID [15:0]
                tag slice[3:1]     │ PGS [2:0]
                tag slice[0]       │ G / Global
                这里的 tag[47] 是 L2TLB entry valid，不是 data 里的 PTE.V。

        2. data 声称 42 bit，请明确 PPN、Strong Order、Cacheable、Bufferable、Shareable、Security、RSW、D、A、G、U、X、W、R 的 bit slice 和打包顺序。
        回答：打包顺序是：{PPN[27:0], flg[13:0]}
                data bit slice[41:14]    │ PPN [27:0]
                data bit slice[13]       │ Strong Order / So
                data bit slice[12]       │ Cacheable / C
                data bit slice[11]       │ Bufferable / B
                data bit slice[10]       │ Shareable / Sh
                data bit slice[9]        │ Security / Sec
                data bit slice[8:7]      │ RSW [1:0]
                data bit slice[6]        │ D
                data bit slice[5]        │ A
                data bit slice[4]        │ U
                data bit slice[3]        │ X
                data bit slice[2]        │ W
                data bit slice[1]        │ R
                data bit slice[0]        │ V / PTE.V
                G 不在 data 里，当前把 G 放在 tag 的 bit [0]。PTW refill 也是这样打包的：data = {pte[37:10], pte[63:59], pte[9:6], pte[4:0]}，tag  = {1'b1, vpn, asid, pgs, pte[5]}
                先前spec有笔误，现已更正

        3. tag 中有 global，data 中也有 Global；这两个 G bit 是否重复存储？若两者不一致，以哪个为准？
        回答：先前spec有笔误，现已更正。G 不在 data 里，当前把 G 放在 tag 的 bit [0]。PTW refill 也是这样打包的：data = {pte[37:10], pte[63:59], pte[9:6], pte[4:0]}，tag  = {1'b1, vpn, asid, pgs, pte[5]}。

        4. tag 的 vld 描述为 “The V bit indicates whether the PTE is valid”，它表示 L2TLB entry valid，还是 RISC-V PTE.V？
        回答：表示 L2TLB entry valid。

        5. Size_Type 是否只有 2'b00/2'b01/2'b10 合法？2'b11 出现时 L2TLB 应如何处理？
        回答：Size_Type之前在spec有误，现已更正。3'b001是4k，3'b010是2m,3'b100是1g。

        6. PPN[27:0] 对 4KB、2MB、1GB 页面是否都保存完整 PPN？返回 PA 时低位如何由 VA 和 PPN 拼接？
        回答：当前 L2TLB data 里的 PPN[27:0] 对 4KB / 2MB / 1GB 都保存完整的 leaf PTE PTE[37:10]，不是在写入 L2TLB 时就把低位替换成 VA offset。
            L2TLB hit 后返回给 L1 的仍是原始 ref_ppn 和 ref_pgs。后续lsu或ifu在l1tlb中命中时，会由l1tlb拼接出pa回给它们，l2tlb不涉及这部分逻辑。
            PFU 路径在 L2TLB 内部会按 page size 拼出 28-bit 的 PA[39:12] 形式：
                1GB: PA[39:12] = {PPN[27:18], VA[29:12]}
                2MB: PA[39:12] = {PPN[27:9],  VA[20:12]}
                4KB: PA[39:12] =  PPN[27:0]
                这里的pa_offset = lsu_mmu_va2[26:0]，也就是 VA 的 VPN 部分。完整 byte PA 还要再拼 VA[11:0]：
                    1GB full PA = {PPN[27:18], VA[29:0]}
                    2MB full PA = {PPN[27:9],  VA[20:0]}
                    4KB full PA = {PPN[27:0],  VA[11:0]}

        7. VPN[26:0] 对应 SV39 的 VA[38:12]，那么 selector VA[31:30] 对应 VPN 的哪两位？
        回答：VPN[26:0] = VA[38:12]，所以映射关系是：VPN[i] = VA[i+12]。因此 selector VA[31:30] 对应：VA[31:30] -> VPN[19:18]

        8. 4KB、2MB、1GB 的 VPN mask 具体忽略哪些 VPN bit？
        回答：SV39 VPN 分层：
                VPN[8:0]    = VPN0 = VA[20:12]
                VPN[17:9]   = VPN1 = VA[29:21]
                VPN[26:18]  = VPN2 = VA[38:30]
            L2TLB hit mask 逻辑：
                4KB: raw_vpn_4k = raw_vpn[26:0]
                2MB: raw_vpn_2m = {raw_vpn[26:9],  9'b0}
                1GB: raw_vpn_1g = {raw_vpn[26:18], 18'b0}

        9. spec 只说“hash 运算”，每个 way、每种 page size 的 hash 函数具体是什么？
        回答：具体hash运算暂时无需纠结，暂时不作为uvm验证的点。

        10. bank mask 写成二进制如 `00110011`，bit0 是否对应 way0，bit7 是否对应 way7？
        回答：是的。

        11. lookup 访问所有 bank 时，是否 tag/data/rrpv 三类 SRAM 都读？TLB operation 是否也读 rrpv？
        回答：是。 ReqQ / PFU 这种 lookup 访问所有 bank 时，8 个 way 的 tag、data、rrpv 都会读。
                TLB operation 也读 RRPV。TLB operation read/probe 主要用 tag/data hit 结果，RRPV 读值不是结果需要的字段。TLB operation write 且 tag_din valid 时，会写 RRPV，初始化为 RRPV_VALID_INIT = 3

        12. 每个 way 的 page size 预测由 selector 决定；如果 entry 中 Size_Type 与该 way 当前预测 page size 不一致，是否即使 VPN/ASID 匹配也必须 miss？
        回答：是，必须 miss。即使 masked VPN 和 ASID/G 条件都匹配，只要 entry 的 Size_Type 与该 way 当前 selector 预测出的 page size 不一致，也会 miss。这个设计等价于：way 按 selector 动态分配 page-size 角色，entry 必须落在与其 page size对应的 way 角色上才可能 hit。

        13. “每个 Way 拥有完全独立且正交的哈希索引函数”与后文只描述“基础 index 再 hash”之间，是否需要给出每个 way 的函数差异？
        回答：具体hash运算暂时无需纠结，暂时不作为uvm验证的点。

    4.4 arbiter
        1. 仲裁优先级写为 ptw > tlb operation > request queue > prefetch；ptw read 和 ptw write 之间的优先级如何定义？
        回答：ptw write只能由ptw read请求打拍产生。一个ptw read和一个ptw write可以看作原子性的操作，是成对出现的。当一个ptw read请求被arb授权之后，会拉高ptw_on信号，阻塞除了ptw write之外的所有请求，当ptw write被授权访问l2tlb之后，才会拉低ptw_on信号，取消对其他请求的阻塞。

        2. PTW 优先级最高，但 ptw_on 期间只允许 PTW write；如果此时有新的 PTW read 请求，是否必须等待当前 ptw_on 结束？
        回答：对。因为一个ptw read和一个ptw write可以看作原子性的操作，是成对出现的，它们共同组成一次ptw refill。而当ptw refill进行的时候，不允许其他任何请求访问l2tlb。只有当ptw write完成之后，才认为一次ptw refill完成。

        3. TLB operation 被 ptw read 抢占的条件是什么？若 tlboper_on 已经为 1，新来的 ptw read 是否可抢占？
        回答：TLB operation 被 ptw read 抢占的条件是没有tlboper_on。当tlboper_on为1时，新来的ptw read不可抢占。

        4. `ptw_write_req2` 由 `ptw_arb_req` 打两拍得到是否固定假设 PTW read 后两拍一定有 write？如果 replacement 选择、流水阻塞或 SRAM stall 导致延迟变化怎么办？
        回答：PTW read 后两拍一定有 write。准确说触发源是 arb_ptw_grant，不是裸 ptw_arb_req：arb_ptw_grant -> ptw_write_req1 -> ptw_write_req2 -> arb_ptw_write_grant。
            这个假设依赖当前 L2TLB pipeline 固定两级：
                - T0：arb_ptw_grant 发起 PTW read，读 tag/data/rrpv
                - T1：raw_vld
                - T2：final_vld，replacement policy 输出 victim_way
                - 同周期 arb 用 ptw_write_req2 发 arb_ptw_write_grant
            replacement policy 也是按这个固定节拍写的
                T0: ptw request to l2tlb;
                T1: access_vld
                T2: output victim way to l2tlb

            所以不会出现你说的问题

        5. ptw_on 阻塞其他请求的起止点是 read grant 到 write accepted，还是 read request 到 write complete？
        回答：起止点是read grant 到 write grant。

        6. tlboper_on 的结束信号名称、来源、时序和多周期 operation 状态机边界是什么？
        回答：tlboper_on 的结束信号是 tlboper_xx_cmplt，它是 mmu_arb 的输入，来源于 ct_mmu_tlboper。
            结束路径：L2TLB 在一次 TLB operation 请求走到 final stage 时产生 l2tlb_tlboper_cmplt。
                    这个信号在 top 层接到 ct_mmu_tlboper，作为 jtlb_tlboper_cmplt 使用。
                    ct_mmu_tlboper 内部各个 operation 状态机会根据当前操作类型和jtlb_tlboper_cmplt 生成自己的完成信号，比如 tlb_tlbp_cmplt、tlb_tlbwi_cmplt、tlb_invva_cmplt 等。
                    所有这些完成信号再被 OR 汇总成 tlboper_cmplt，并直接赋给 tlboper_xx_cmplt。最后 tlboper_xx_cmplt 回到 mmu_arb，在tlboper_on 已经为高的情况下，于下一个 arb_clk 上升沿清掉 tlboper_on。

            多周期 FSM 边界：tlboper_on 不是具体 FSM 状态，而是 arb 侧的“当前有 TLB operation 占用窗口”标志。
                真正的多周期边界在 ct_mmu_tlboper.v 的各 operation FSM 内：
                    - TLBP/TLBR/TLBWI：IDLE -> WFG -> WFC -> IDLE
                        - WFG 发 tlb_*_req
                        - arb_tlboper_grant 后进 WFC
                        - WFC 等 jtlb_tlboper_cmplt
                        - 收到后产生 tlb_*_cmplt

                    - TLBWR：WRIDLE -> WRWFG -> WRTAG -> WRWFC -> WRIDLE
                        - 先读 victim/tag
                        - 等一次 jtlb_tlboper_cmplt
                        - 再发写请求
                        - 写访问再次等 jtlb_tlboper_cmplt
                        - 最后产生 tlb_tlbwr_cmplt

                    - INVASID：循环 RD -> WFC -> WT/NWT
                        - 每个 entry 先读
                        - 等 jtlb_tlboper_cmplt
                        - ASID 命中则写 invalid
                        - 计数到 tlb_inv_done 后产生 tlb_invasid_cmplt

                    - INVALL：IALL_IDLE -> IALL_WFC -> IALL_IDLE
                        - 不需要 read compare
                        - 逐项发 invalid write
                        - 最后一次 grant 且 tlb_inv_done 时产生 tlb_invall_cmplt

                    - INVVA：IVA_IDLE -> IVA_RD -> IVA_CMP -> IVA_WR -> IVA_WT -> IVA_CMPLT -> IVA_IDLE
                        - 读 entry
                        - 等 jtlb_tlboper_cmplt
                        - VA 命中则写 invalid
                        - 写完成后进入 IVA_CMPLT
                        - IVA_CMPLT 本身产生 tlb_invva_cmplt
            因此 tlboper_on 的结束不是由 arb 自己判断 operation 类型，而是完全依赖 ct_mmu_tlboper 汇总出的 tlboper_xx_cmplt。多周期 operation 的真实完成边界在各 FSM 产生 *_cmplt 的那个周期。

        7. prefetch_mask 在 PFU multi-hit、PTW disabled miss、PMP deny、flag fault、miss buffer full 等情况下是否都清除？
        回答：prefetch_mask 的清除条件在arb中：mmu_lsu_pa2_err | mmu_lsu_pa2_vld | l2tlb_arb_pfu_miss_mb_full
                PFU hit 且 PMP allow                 │                   清除 │ PFU FSM 到 PFU_OK，mmu_lsu_pa2_vld=1
                PFU multi-hit                        │                   清除 │ final_tlb_hit_mult 触发 l2tlb_pfu_acc_fault，到 PFU_DENY，pa2_vld/pa2_err=1
                PTW disabled miss                    │                   清除 │ !cp0_mmu_ptw_en && l2tlb_miss 触发 l2tlb_pfu_acc_fault，到 PFU_DENY
                flag fault                           │                   清除 │ final_pa_vld && l2tlb_pfu_flag_fault 触发 PFU_DENY
                PMP deny                             │                   清除 │ PFU_CHK 中 l2tlb_pfu_deny=1，下一拍到 PFU_DENY
                PTW enabled miss 且 MB alloc 成功    │               暂不清    │ 等 PTW 返回后通过 PFU FSM 产生 pa2_vld/err 再清
                PTW enabled miss 且 miss buffer full │                   清除 │ l2tlb_arb_pfu_miss_mb_full 直接清

        8. “mmu 没有被关闭”只用于 PFU grant 条件，ReqQ/TLB operation/PTW 在 MMU off 时如何处理？
        回答：MMU off 下的处理：
                - ReqQ：arb 本身没有 MMU off gating，arb_reqq_grant 只看 issue_valid/ptw/tlboper/tlboper_on/ptw_on。
                        但正常新请求在 L1 被挡住：DTLB miss 条件包含 !dutlb_off_hit，ITLB miss 条件包含 !iutlb_off_hit，所以 MMU off 时 L1直接返回 PA，不应产生新的 ReqQ refill。若 off 前已有 ReqQ entry，arb 仍可能继续 issue。
                - PFU：arb 明确用 !dutlb_xx_mmu_off 阻止 arb_pfu_grant。但 L2 PFU FSM 还有 direct-off 路径：lsu_mmu_va2_vld && l1dtlb_xx_mmu_off 会直接完成 PFU，返回 VA 低位作为 PA。
                - TLB operation：不受 MMU off 屏蔽。regs_tlboper_* 仍可发起，arb_tlboper_grant 也没有 regs_mmu_en/dutlb_xx_mmu_off 条件。
                        也就是说 TLBP/TLBR/TLBWI/TLBWR/INV 操作在 MMU off 时仍可访问/维护 L2TLB，这是当前设计行为。
                - PTW：arb 的 arb_ptw_grant 和 arb_ptw_write_grant 本身也没有 MMU off gating。
                        新 PTW 通常不会从 MMU-off 的 L1 miss 产生；但已有 miss buffer entry 只要 cp0_mmu_ptw_en 仍为 1，仍可能继续 issue PTW。TWU 本身没有regs_mmu_en 输入，主要靠 tlboper_ptw_abort abort，而不是靠 MMU off 自动 abort。

        9. 当 RRPV write buffer 满导致 stall 时，arbiter 是否停止所有来源 grant？PTW write 是否仍最高优先级？
        回答：当 RRPV write buffer 满或达到 arbiter stall 水位时，arbiter 阻塞 ReqQ、PFU、PTW read 和 TLB operation，避免继续接收 lookup 或相关访问导致 write buffer overflow。对 arbiter 暴露的 full/stall 信号可以在实际 FIFO 满前预留若干 entry，用于吸收 full 生效前已经在 L2TLB raw/final/push 路径中的 ReqQ/PFU RRPV 更新。PTW write 不进入 RRPV write buffer，而是直接写 tag/data/RRPV SRAM，所以 RRPV write buffer full 不阻塞 PTW write；如果 ptw_write_req2 有效、ptw_on 为 1 且没有 tlboper_on，arbiter 仍然可以给 PTW write 授权，并由 PTW write 产生 arb_l2tlb_req。

        10. 当 tlboper_on 为 1 且当前 tlb operation 内部没有当拍 SRAM 访问时，是否允许其他请求使用空闲 SRAM 周期？
        回答：tlboper_on 为 1时，绝不允许非tlb operation请求访问l2tlb的sram

        11. arbiter 输出的 vpn、acc_type、bank_sel、cmp_with_va、index、write data 等信号是否必须在 grant 当拍稳定，还是可以在后续流水阶段保持？
        回答：必须在 grant / arb_l2tlb_req 当拍稳定。当前接口不是“grant 后 payload 后续保持”的协议，而是“一拍 accept”：grant 当拍 arb 选中的 payload 被 L2TLB 立即消费。
              idx_w*, bank_sel, write, tag_din, data_din, rrpv_din：当拍直接驱动 tag/data/RRPV SRAM 的 cen/wen/idx/din。必须 grant 当拍稳定
              vpn, acc_type, cmp_with_va, bank_sel, idx_w*, eid/trans_id, tag_din：当拍在 arb_l2tlb_req 下打进 raw_* 寄存器。必须 grant 当拍稳定。

    4.5 TLB operation
        1. overview 中按 VA/ASID/VA+ASID/ALL invalidate 的四个分支为空，需要补充每类 operation 的完整行为吗？
        回答：已经完成补充。

        2. TLBP 的 page size 信息来自哪个寄存器？probe 时是否只匹配该 page size，还是由 skewed way 预测覆盖全部 page size？
        回答：TLBP 的 page size 来自 MEH 寄存器的 PGS 字段，也就是软件写入 MEH 时的 bits [18:16]。这个字段在 regs 中形成 regs_tlboper_cur_pgs，再传到 tlboper，最后作为 tlboper_xx_pgs 送到 L2TLB。
                但当前 probe 的实际命中比较并不是严格只按 MEH.PGS 匹配。TLBP 会打开所有 way 做查找，arbiter 根据 MEH.VPN 的 selector 为每个 way 生成当前预测 page size。
                L2TLB hit 比较时使用的是每个 way 的预测 page size，并且要求这个预测 page size 和 entry tag 中保存的 Size_Type 一致。
                因此当前行为更像是“由 skewed way 的 page-size 预测覆盖所有 way”，而不是“只查 MEH.PGS 指定的那一种 page size”。

        3. TLBP multi-hit 时返回的 index 是否有效？若无效，寄存器中应写什么值？
        回答：TLBP multi-hit 时返回的 index 不应视为有效。只有单命中时才认为 jtlb_regs_hit 有效，并把 hit index 写入 MIR；
                multi-hit 时 jtlb_regs_hit 为 0，jtlb_regs_hit_mult 为 1，所以 MIR 会被写成 probe fail，并置tlbp_tfatal。index 字段不会被更新，保持原来的值。也就是说 multi-hit 情况下寄存器应通过 “P=1、tlbp_tfatal=1” 表示结果无效，index 是无效字段，不应被软件使用。

        4. TLBR 读取 invalid entry 时返回内容是否有定义？
        回答：TLBR 读取 invalid entry 时，当前没有把返回内容定义成固定值，也没有因为 tag valid=0 而屏蔽其它字段。
              它会按 MIR 指定的 way/index 读出 tag/data SRAM，然后把读出的 VPN、PGS、ASID、G、PPN、flag 原样写回 MEH/MEL。
              也就是说 MEL.V 会反映 data 里的 V bit，但其它字段就是该 invalid entry SRAM 中保存的旧值或复位值，不应当被软件当作有效翻译内容使用。

        5. TLBWI/TLBWR 写入时是否允许写 invalid entry？valid 是否一定强制为 1？
        回答：TLBWI/TLBWR 写入时允许写入一个“PTE invalid”的 entry，但不允许写 tag invalid。
              写入路径里 tlb_tag_vld_in 在 TLBWI 或 TLBWR write 时为 1，tag 打包的最高 valid 位被强制写成 1。
              也就是说 L2TLB entry 的 tag valid 一定会被置 1。
              但 data 里的 V bit 不会被强制为 1，它来自 MEL 的 bit 0，也就是 regs_jtlb_cur_flg[0]。
              所以如果软件写 MEL.V=0，再执行 TLBWI/TLBWR，结果是：tag valid=1，但 PTE flag 的 V=0。这个 entry 在结构上有效、会参与 tagcompare，但权限检查会因为 PTE.V=0 产生 page fault。

        6. INVALL/INVASID 扫描范围按 0..255 还是 0..1023？
        回答：应按 0..255 扫描，不按 0..1023 扫描。
              原因是这里的 L2TLB 组织不是 1024 个线性 entry，而是 8 way x 256 set 的 skew-associative 结构。
              TLB operation 的扫描计数器表示 set index，宽度虽然是 11 bit，但真正送到 L2TLB SRAM 地址的是低 8 bit。高 3 bit只在 TLBR/TLBWI 这类“指定一个 way”的 index 操作中可用于生成 way select；对 INVALL/INVASID 扫描来说，读阶段 bank select 是全 8 way，所以每个 set 一拍覆盖 8 个 way。
              INVALL 的行为是：计数器从 0 开始，每次 arb grant 后处理当前 set。invall_cnt 是 255，完成条件是当前计数等于 255 且本拍 grant。
                  因此实际覆盖的是 set 0、1、2……255，合计 256 个 set。每个 set 上 bank select 为全 1，所以覆盖 8 个 way，总覆盖 8 x 256 = 2048 个 L2TLB entry。不是扫 0..1023，也不是只扫 1024 个 entry。
              INVASID 也是按 set 0..255 扫描。
                  它和 INVALL 的区别是 INVASID 先读当前 set 的 8 个 way，然后 L2TLB 用读出的 tag 判断哪些 way 满足条件。
                  如果有匹配 way，再写回清这些 way；如果没有匹配 way，则不写该 set，直接进入下一set。读阶段仍然读 8 个 way，写阶段只写 L2TLB 返回的 ASID-hit way mask。
                                         
        7. INVASID 是否只清 non-global entry；若 tag G 和 data G 不一致如何判断？
        回答：INVASID 只清 non-global entry。当前 L2TLB 判断条件是：entry valid 为 1，tag.G 为 0，tag.ASID 等于目标 ASID。
              也就是说 global entry 即使 ASID 字段等于目标 ASID，也不会被 INVASID 清掉。这个语义符合“按 ASID 失效只影响 ASID 的非全局映射”的预期。
              G 位判断以 tag.G 为准，不以 data flag 为准。L2 tag 格式是 valid、VPN、ASID、page size、global；L2 data 格式是 PPN 加 flags。
              当前 data flags 里没有 G 位，PTE 的 G 在回填或 TLBWI 时被单独放进 tag.G。data flag 中原始位置对应的不是 G，而是去掉 G 后重新压缩过的权限/属性位，例如 A、D、U、X、W、R、V 以及扩展属性。

        8. INVVA_ALL 中“忽略 ASID”时，global 条件是否仍参与，还是只看 valid/page size/VPN？
        回答：INVVA_ALL 忽略 ASID 后，global 条件不再作为筛选条件参与。
              实际等价于只看 entry valid、page size 匹配、VPN/VA 匹配。G=0 和 G=1 都会被当成命中候选，只要 VA/page size 对上，就会进入写回清除 mask。
              更准确地说，L2TLB 的 VA hit 条件可以理解成：
                   entry.valid
                   并且 page size 匹配
                   并且按 page size mask 后 VPN 匹配
                   且满足 ASID 条件
                   其中 ASID 条件是：
                       ASID 相等，或者 entry 是 global，或者当前操作要求忽略 ASID。
            INVVA_ALL 时，tlboper_l2tlb_cmp_noasid 会置 1，所以“当前操作要求忽略 ASID”这一项已经为真。
            这样 G 位即使仍在表达式里，也已经被 cmp_noasid 覆盖掉了。
            结果就是：G 不影响 INVVA_ALL 的命中与清除。global entry 和 non-global entry 只要 VA/page size 匹配都会被无效化。
            INVVA_ALL：清除 valid、按 arb per-way predicted page size 后 VA/VPN 匹配、且 tag.pgs 等于该 way predicted pgs 的 entry；ASID 和 G 不限制。

        9. INVVA_ASID 中 global entry 是否应被无效化？
        回答：会。只要 VA/page size 命中，当前会把 global entry 放进 final_way_hit，然后写阶段用 final_way_hit 作为 bank select，把它清掉。
              INVVA_ASID 时不会置 cmp_noasid，但 tlboper_l2tlb_asid_sel 会选择 LSU 提供的目标 ASID 参与比较。因此当前的命中条件实际是：
                valid、page size、VPN 匹配，并且 ASID 相等或者 entry.G=1。
                这意味着当前INVVA_ASID 会清除两类 entry：
                    第一类是 VA/page size 匹配、G=0、ASID 等于目标 ASID 的 non-global entry。
                    第二类是 VA/page size 匹配、G=1 的 global entry。global entry 不需要 ASID 等于目标 ASID，因为 G 位在 hit 逻辑里绕过了 ASID 比较。
             INVVA_ASID：当前=清除 valid、按 arb per-way predicted page size 后 VA/VPN 匹配、tag.pgs 等于 predicted pgs、并且 ASID 相等或 tag.G=1 的 entry。

        10. TLB operation 期间是否 abort 已在 miss buffer 或 PTW 中的请求？哪些 operation 需要 abort？
        回答：不是“所有 TLB operation 期间都 abort”，当前只有 LSU/TMO 发起的 invalidate 类操作会产生 tlboper_ptw_abort，而且是操作开始时的一个 pulse，不是在整个 TLB operation 期间持续拉高。
              需要 abort 的当前操作是：
                1. lsu_mmu_tlb_all_inv，对应 LSU 侧 INVALL。
                2.lsu_mmu_tlb_asid_all_inv，对应 LSU 侧 INVASID。
                3. lsu_mmu_tlb_va_all_inv，对应 LSU 侧 INVVA_ALL。
                4.lsu_mmu_tlb_va_asid_inv，对应 LSU 侧 INVVA_ASID。
              abort 只在新的 LSU invalidate operation 被接收的第一个周期产生。
              对 PTW 的影响：会 kill 正在进行的 page walk。PTW 内部memory buffer entry 会被清掉，新 create 会被挡住；如果已经有 LSU data request 在外面，则通过 abort 相关状态把总线响应 drain 掉，避免已经 abort 的 walk 继续产生 refill。
              对ptw你无需过度关注，只关注l2tlb即可。
              对 L2TLB miss buffer 要分清：当前 miss buffer 并不是直接把 entry valid 清掉。abort 进入 entry 后主要清的是 sent 状态，使已经 sent 但未完成的 miss entry 回到可重新 issue 的状态；它不是完整 deallocate。

        11. “清除 L1 uTLB”和“清除 L1 TLB”的说法不一致；TLBWI/TLBWR/INV* 到底清哪些 L1 结构？
        回答：L1 uTLB其实就是L1 TLB的意思。L1 uTLB就是L1 TLB

        12. TLBWI/TLBWR 写入 tag/data 时，寄存器中的 translation entry 字段来源、位宽、非法组合处理是否需要定义？
        回答：写入的 translation entry 来自 MMU 的软件寄存器 MEH 和 MEL。MEH 提供 VPN、page size、ASID；MEL 提供 PPN、G 和权限/属性位。
              写入 L2TLB tag 时，代码把这些字段打包成：entry valid、VPN、ASID、page size、G。写入 L2TLB data 时，代码打包成：PPN 和压缩后的 flag 字段。这里 G 不在 data 里，而是单独放在 tag 的 G 位里。
              非法组合处理方面，目前没有检查或修正。比如 page size 不是合法 one-hot、权限位组合不合法、MEL.V 为 0、大页 PPN 低位不对齐等，TLBWI/TLBWR 写入路径都不会阻止写入，也不会抛异常。
              唯一强制的是 L2TLB entry 的tag valid 会被置 1；但 data 里的 PTE.V 仍然来自 MEL.V，可以是 0。

        13. TLBWR 的读阶段“读取候选 set 的 8 个 way”中，候选 set 如何由寄存器中的 VPN/page size/selector/hash 得到？
        回答：TLBWR 读阶段的“候选 set”不是来自 MIR index，也不是直接由 MEH.page size 指定。
              实际流程是：TLBWR 先用 MEH.VPN 作为访问 VPN，然后 arbiter 取 VPN 中对应 VA[31:30] 的两位作为 selector。selector 决定每个 way 按 4K、2M、1G 中哪一种 page size 预测取 index。4K 用 VPN 低 8 位，2M 用 VPN 中间 8 位，1G 用 VPN 高位中的 8 位。
              每个 way 拿到 raw index 后，再经过各自的 hash/skew 函数生成该 way 的最终 SRAM index。
              TLBWR 读阶段读取的是由同一个 MEH.VPN 计算出的 8 个 per-way skew index 对应的 8 个 way，而不是一个普通意义上所有 way 共用同一个 set index。MEH.page size 不参与 TLBWR 读阶段候选 set 生成；它只作为之后写入 tag 的 page size 字段。

        14. INVASID 按 set 扫描时，如果同一个 set 中多个 way 命中 ASID，是否同拍全部清除？
        回答：如果同一个 set 里多个 way 都满足 ASID 命中条件，会在同一次 write invalid 阶段全部清除。

        15. INVVA read 后到 write invalid 之间，是否阻塞所有普通 lookup/refill？如果不阻塞，如何处理被命中 entry 在两阶段之间变化？
        回答：INVVA 的 read 到 write invalid 之间，普通 lookup/refill 在 arbiter 层被阻塞。流程是：INVVA 先进入 read 状态，读出候选 way 并做 VA/ASID/G/page size 比较；
             如果 jtlb_tlboper_va_hit 为 1，就进入 write 状态，用前面 L2TLB 返回的 final_way_hit mask 作为写 invalid 的 way mask。这个 mask 可以是多bit，所以 INVVA 如果出现多个 VA hit，也会按多个 bit 清。
             阻塞关系上，TLB operation 一旦被 arbiter grant，tlboper_on 会置起，一直保持到该 TLB operation complete。tlboper_on 会阻塞 ReqQ 普通 lookup、PFU lookup、PTW 新请求 grant，以及 PTW refill 写 grant。
             ReqQ/PFU 还额外被当前 tlboper_arb_req 挡住。因此在 INVVA read 已经被接受之后，到 write invalid 完成之前，正常的 L2TLB lookup/refill 不会插进来修改 tag/data。
             没有做“read 后 write 前 entry 发生变化”的特殊处理，也没有二次 compare 或 version check。它依赖 arbiter 串行化保证这段窗口内普通 lookup/refill 不会改同一批 L2TLB tag/data。
             write 阶段直接用 read 阶段得到的hit mask 清 invalid。

        16. LSU 发起和 CP0 发起的 TLB operation 在 done、abort PTW、清 L1 方面有哪些差异？
        回答：done 差异：
                LSU 只发起 invalidate 类操作：all_inv、asid_all_inv、va_all_inv、va_asid_inv。这些操作完成后，ct_mmu_tlboper 先置内部 lsu_oper_cmplt，再输出 mmu_lsu_tlb_inv_done 给 LSU。这个 done 只服务 LSU 路径。
                寄存器/MCIR 发起的 TLBP/TLBR/TLBWI/TLBWR/INVALL/INVASID 完成后，输出的是 tlboper_regs_cmplt 给 regs，用来清 MCIR pending bit、产生 CP0 register access complete。这里有一个过滤：如果当前是 LSU operation，tlboper_regs_cmplt 会被屏蔽。
                还有一个单独的 top-level cp0_mmu_tlb_all_inv 输入，它走 INVALL 状态机，完成后输出 mmu_cp0_tlb_done = tlb_invall_cmplt。所以“CP0 发起”实际分两类：MCIR/regs 路径用 tlboper_regs_cmplt，cp0_mmu_tlb_all_inv 路径用 mmu_cp0_tlb_done。
              abort PTW 差异：
                只有 LSU 发起的 TLB operation 会产生 tlboper_ptw_abort。条件是：当前有 LSU TLB op 请求，且还没有被 tlb_lsu_oper_flop 记录过。也就是 LSU invalidate 被接收时打一拍 abort pulse。
                寄存器/MCIR 发起的 TLBP/TLBR/TLBWI/TLBWR/INVALL/INVASID 不会产生 tlboper_ptw_abort。cp0_mmu_tlb_all_inv 也不在 tlb_lsu_oper 条件里，所以同样不会产生这个 abort。
                PTW 侧收到这个 abort 后，会清/抑制 PTW mbuf 创建和正在处理的 walk。也就是说：当前把 PTW abort 语义绑定给 LSU/SFENCE 类 invalidate，而不是所有 TLB operation。
                tlb_lsu_oper_flop 更准确地说不是“所有 TLB operation busy”，而是“已经接收了一个 LSU 来源的 TLB invalidate operation，并且该 operation 还没完成”的来源锁存标志。
                    它的输入源只有 LSU 四个请求：lsu_mmu_tlb_asid_all_inv，lsu_mmu_tlb_all_inv，lsu_mmu_tlb_va_all_inv，lsu_mmu_tlb_va_asid_inv。这四个 OR 成 tlb_lsu_oper。只要 tlb_lsu_oper 为 1、所有 TLB operation FSM 都 idle、并且当前不在 LSU done pulse 周期，tlb_lsu_oper_flop 就置 1。
                    置位条件可以理解为：LSU 请求存在，并且 TLBOper 当前空闲，并且上一笔 LSU done pulse 不在高电平
                    清除条件是：tlb_lsu_oper_flop 已经为 1，并且当前 LSU 对应的 invalidate operation 完成
                    这里的完成包括 INVASID 完成、INVALL 完成、INVVA 完成。完成当拍，tlb_lsu_oper_flop 被清 0，同时 lsu_oper_cmplt 被置 1。下一拍 mmu_lsu_tlb_inv_done 输出为 1，再下一拍 lsu_oper_cmplt 清 0。所以 LSU done 是一个延后一拍的一周期 pulse。
    
              清 L1 方面：
                L1 清除信号分两类：
                    tlboper_utlb_clr 是全清 L1 uTLB/L1 TLB 的信号。它在 TLBWI、TLBWR、INVASID、INVALL 请求期间拉高。这个不区分 LSU 还是 regs，只要走到这些操作状态就会清 L1。LSU 的 all/asid invalidate 会触发它；regs 的 TLBWI/TLBWR/ INVALL/INVASID 也会触发它。
                    tlboper_utlb_inv_va_req 是按 VA 清 L1 的信号，只由 LSU 的 INVVA 路径产生，因为 INVVA 的 VA 来自 lsu_mmu_tlb_va。L1 entry 里实际只比较 lsu_mmu_tlb_va[7:0] 和 entry VPN 低 8 位来清。寄存器/MCIR 路径没有 TLBIVA 操作，所以不会走这个按 VA 清 L1 的路径。
                    补充一点：regs_utlb_clr 是 SATP 写产生的 L1 全清，不属于 TLB operation 本身。

    4.6 l2tlb miss buffer 与 PTW
        1. miss buffer entry1-entry8 同时给 DTLB 和 PFU 使用，二者分配冲突时优先级是什么？
        回答：不会出现冲突的情况。同一拍最多有一个请求从l2tlb的lookup流水线送到miss buffer。

        2. miss buffer 中选择未发射请求时，只说明 ITLB 优先于 DTLB，未说明 PFU 与 DTLB 的优先级。
        回答：PFU 与 DTLB不存在优先级。miss buffer发射时会选择编号最低的有效未发射entry

        3. 当 miss buffer 有旧 ready entry，同时当前 lookup miss 且 PTW ready，当前 miss 是否只分配不 bypass issue？
        回答：是的。

        4. 当 miss buffer 无 ready entry、当前 miss 可 bypass 给 PTW 时，是否仍必须分配 miss buffer entry？
        回答：是的。

        5. PFU miss 是否真的进入 PTW？若是，PTW completion 后是否 refill L2TLB 但不回填 L1？
        回答：PFU miss 真的进入 PTW。PTW completion 后refill L2TLB 但不回填 L1。

        6. PTW completion feedback 的 `fb_hit` 匹配规则是什么？按 L2 MB entry id、VPN/type，还是其他字段？
        回答：fb_hit 的匹配规则是按 L2 Miss Buffer entry id 匹配，不按 VPN/type，也不按 L1EID。
              具体路径是：PTW completion 回来时，ptw_l2tlb_ref_id 的高位 L2EID 段被切出来作为 l2mb_feedback_eid，接到 mmu_l2tlb_mb.fb_trans_id。每个 MB entry 用 fb_valid && (fb_trans_id == entry_index) 生成 fb_match_id，再用fb_match_id && fb_hit 清 entry。

        7. `issue_eid = {l2_mb_entry_id, l1eid}` 的总位宽和字段切分是什么？
        回答：issue_eid = {l2_mb_entry_id, l1eid} 默认总宽度是 7 bit：L2EID_WIDTH + L1EID_WIDTH = 4 + 3。字段切分是高 4 bit [6:3] 为 L2 MB entry id，低 3 bit [2:0] 为 L1 DTLB miss buffer entry id。新分配 DTLB miss 时拼{dtlb_alloc_index[3:0], req_l1eid}；已有 ready entry 发 PTW 时拼 {entry_rdy_id, entry_rdy_eid}。ITLB entry 的 L1EID 固定为 0。

        8. PTW abort 时 miss buffer entry 是清 valid、清 sent，还是保留并等待 replay？
        回答：清sent，变成有效但未发射状态。

        9. PTW disabled 时 L1/PFU miss 不进 miss buffer，但返回 page fault；具体 fault 类型如何区分？
        回答：PTW disabled 造成的 miss 是 no-walk page fault，不是 access fault，也没有再细分成 instruction/load/store/prefetch cause。
              load 和 store 的区别不是靠 fault 类型区分，而是靠原始请求类型区分；最终对 LSU 只看到 page fault 置位，access fault 不置位。
              PFU 比较特殊。PFU 接口没有单独的 page fault 输出，也没有 access fault 和 page fault 两根线。PFU 的异常最终会被 L2TLB 合并成 LSU prefetch 端口的错误信号，也就是 pa2_err。因此 PTW disabled 下 PFU miss 对外表现为prefetch error，不能从 PFU 外部接口继续区分它原本是 page fault 还是 access fault。
              以分类口径是：普通取指、load、store 的 PTW-disabled miss 归 page fault；PFU 的 PTW-disabled miss 对外归合并错误，不细分。type 和 id 只用来定位请求来源和 miss buffer entry，不是异常类型编码。

        10. miss buffer full 时，ReqQ 收到 retry 并拉低 sent；PFU miss 在同样场景下是否也有 retry/mask 清除机制？
        回答：有，但不是 ReqQ 那种 retry/sent 机制。PFU 没有 ReqQ entry，也没有 sent 位。
              PFU 走的是 arbiter 里的 prefetch_mask：
                PFU 被 grant 后，prefetch_mask 置 1，防止 lsu_mmu_va2_vld 持续为 1 时每拍重复发同一个 PFU 查表请求。
                如果 PFU 查 L2 miss，而且 L2 miss buffer full，L2TLB 拉起 l2tlb_arb_pfu_miss_mb_full。
                这个信号回到 arbiter 后会清掉 prefetch_mask。mask 清掉后，只要 PFU 端仍然保持或重新发起 lsu_mmu_va2_vld，arbiter 后续就可以再次grant PFU，相当于“允许重试”。

        11. r_sent 在 feedback、dealloc 或 tlboper_ptw_abort 时清 0，但 r_vld 是否也同时清 0？
        回答：r_sent 在 dealloc（ptw refill完成并且refill的miss buffer entry id匹配） 或 tlboper_ptw_abort 时清 0。r_vld清零的时候r_sent一定清零，但是r_sent清零的时候r_vld不一定清零。r_vld只有在ptw refill完成并且refill的miss buffer entry id匹配时清零。
        
        12. 如果 PTW completion 返回 fault 而不是 translation，miss buffer entry 何时释放，L1/PFU 收到什么响应？
        回答：如果 PTW completion 返回 fault，miss buffer entry也会在refill的l2tlb miss buffer id匹配自身id时释放。无论ptw返回是pa_vld还是fault，都算这次refill完成。
              L1 DTLB 这一级：如果是 load/store 的 PTW fault，PTW 还会用 type/id 低位定位 L1DTLB miss buffer entry。这个 entry 不安装 TLB，而是进入 PGFLT/ACFLT 状态，并把 iid/vpn/fault class 写入 exception CAM。它不是在 PTWcompletion 当拍直接释放，而是等 LSU 后续 replay 同一 iid/vpn，命中 exception CAM 后返回 fault，同时 entry 释放。
              PFU 的 PTW fault completion 返回到 L2TLB 后，L2 miss buffer 同样释放；随后 L2TLB 的 PFU 状态机把它合并成 LSU prefetch 端口错误响应：pa2_vld=1 且 pa2_err=1。PFU 对外不区分 page fault 和 access fault。

        13. 同一个 VPN/ASID/type 的多个 miss 是否允许在 miss buffer 中同时存在？是否需要 merge？
        回答：不需要merge。允许在 miss buffer 中同时存在

        14. PTW refill 写入 L2TLB 与 miss buffer completion feedback 的先后关系是什么？
        回答：completion feedback 早于真正写入 L2TLB array。
              顺序是：
                PTW 产生正常 refill，请求 L2 arb。
                当 arb_ptw_grant 拉高时，PTW 同拍拉高 ptw_l2tlb_ref_data_vld，并由此形成 ptw_l2tlb_cmplt。L2TLB miss buffer 用这个 completion feedback 匹配返回 id，并开始释放对应 entry。
                但 L2TLB array 的实际写入不是 arb_ptw_grant 当拍完成。mmu_arb 里先把 PTW refill 的 tag/data latch 到 ptw_write_req1，再推进到 ptw_write_req2，之后通过 arb_ptw_write_grant 发起真正的 L2TLB write。
                因此写 array 比completion feedback 晚若干拍。
              miss buffer completion feedback 不是“L2TLB array 已经写完”的确认，而是“PTW 这笔 miss 已经产生 terminal result，payload 已被 L2 arb 接收/排入写路径”。不要要求 L2 MB 等到 SRAM write 后才释放。

    4.7 replacement policy、RRPV 与 write buffer
        1. replacement policy 描述中既说 allocate RRPV=3，又说访问 entry RRPV+1；“每次访问将被访问的 entry RRPV值+1”与“hit entry 置 0”矛盾，需要明确最终规则。
        回答：RRPV 宽度是 3bit，范围是 0..7。RRPV_MAX = (1 << RRPV_WIDTH) - 1 = 7，新分配/有效写入初始化值是 3。
                每次 access_vld 时，代码先对所有 way 的 entry_rrpv 做饱和 +1，结果存到 rrpv_reg。
                之后按事件覆盖：
                    - hit：hit way 的 RRPV 置 0；其它 way 保持刚才 +1 后的值。
                    - miss：所有 way 保持刚才 +1 后的值。
                    - PTW refill / allocate：victim way 的 RRPV 写 3；其它 way 保持刚才 +1 后的值。
                victim 选择规则是：如果有 free way，选第一个 free way；否则在未 mask 的候选 way 中，按 RRPV 从 7 降到 0 找最大 RRPV，并选该 RRPV level 中第一个 way。
                所以真实规则是：“访问时非 hit entry 会 aging +1；hit entry 最终置 0”。这两句不矛盾，因为 +1 是先统一预计算，hit 分支再把命中的 entry 覆盖为 0。新 allocate 的 entry 最终写 3。
                
        2. RRPV 范围 0-7，+1 时是否 saturate 到 7？
        回答：是，+1 是 saturate 到 7。6 加到 7，7 保持 7，不会溢出回 0。

        3. SRRIP victim 选择规则未写完整：无空闲 way 时，是找 RRPV==7，若没有则全体递增直到出现 7 吗？
        回答：无空闲 way 时不会反复递增直到出现 RRPV 等于 7。实际机制是：先看当前各 way 的 RRPV 值，在所有可选 way 里找“当前最大的 RRPV”。
              搜索顺序是从 7 往 0 找；如果有 7，就选第一个 RRPV 为 7 的 way；如果没有 7，但有 6，就选第一个 RRPV 为 6 的 way；如果最高只有 5，就选 5，以此类推。
              全体 RRPV 加 1 是访问更新阶段的 aging 行为，而且是饱和加到 7，不是 victim selection 阶段里的循环动作。也就是说，替换选择本身不等待 RRPV 被加到 7，而是直接使用当拍读到的最大 RRPV 作为 victim 依据。

        4. 空闲 way 判断是否只看 tag.valid=0？
        回答：是。

        5. 多个 invalid/free way 或多个 victim 候选时是否最低 way 优先？
        回答：是。

        6. lookup miss 时“所有被访问 entry RRPV+1”是否只更新 bank_sel 覆盖的候选 way？
        回答：lookup miss 时，replacement 模块内部先对 8 个 way 的 RRPV 全部做一次饱和 +1 预计算，没有用 bank_sel/mask_way 去过滤。miss 分支直接把这个结果作为 rrpv_updata。
              但真正写回 RRPV array 时，普通 L1/PFU lookup 走 wbuf，写回有效位来自 final_way_vld，不是 bank_sel。
              而普通 ReqQ/PFU lookup 的 bank_sel 在 arb 里本来就是全 1，所以实际效果是：对这次 lookup 读到的 8 个 way 中 valid 的entry 写回 RRPV+1，invalid entry 不写回。
              bank_sel 主要用于 victim 候选选择，而不是用于限制 miss aging 写回范围。              

        7. TLBP/TLBR/INV* 这类 TLB operation 是否更新 RRPV？
        回答：TLBP/TLBR/INV* 不会通过普通 lookup aging 路径持久更新 RRPV。
              虽然 TLBP 这类操作也会让 replacement 模块看到 raw_vld，内部可能算出 hit/miss 对应的 rrpv_updata，但顶层 wbuf_push_req 只允许 ReqQ/PFU lookup 推入 RRPV wbuf，TLB operation 不会推入，所以 RRPV array 不会因为 TLBP/TLBR 被 aging 更新。
              INV* 写 tag 时通常是清 valid，当前 rrpv_write_tlboper 还要求写入 tag 的 valid bit 为 1，所以 INV* 也不会写 RRPV。
              例外是 TLBWI/TLBWR 这类写入有效 entry 的 TLB operation：如果写入 tag valid=1，会走 rrpv_write_tlboper，把被写入的 selected way 的 RRPV 初始化为 3。这不是访问 aging，而是新 entry 初始化。

        8. PTW read 读 RRPV 后到 PTW write 之间禁止其他访问，是为了 RRPV 一致；那 RRPV write buffer 中已有同 index 更新时是否必须 bypass 到 replacement policy？
        回答： PTW read 读 RRPV 后到 PTW write 之间禁止其他访问，是为了 RRPV 一致。因为本质上来说，一次ptw refill包含ptw read和ptw write，ptw refill是原子性的，必须保证ptw refill的过程中rrpv没有被修改。
              必须 bypass。rrpv_wbuf 对每次 arb_l2tlb_req 用 lookup_idx 查 pending update，命中后输出 wbuf_cam_hit/bypassed_rrpv_rdata，再和 SRAM 读出的 l2tlb_rrpv_dout_bus 合成 l2tlb_rrpv_merged_dout_bus，这个 merged RRPV 才送进 replacement policy。
              PTW read 到 PTW write 之间禁止新的访问，是防止 PTW read 之后 RRPV 再变化；但 PTW read 之前已经在 RRPV write buffer 中的同 index 更新，必须 bypass 到 replacement policy。否则 PTW read 看到的不是最新 RRPV。

        9. RRPV write buffer FIFO 深度是多少？
        回答：RRPV write buffer 实例化深度是 8。但 full 不是等到 8/8 才拉高。当前 DEPTH=8 时，full 在 count >= 5 就拉高，预留 3 个 entry 给已经进 pipeline、后续可能 push 的 lookup 更新。

        10. RRPV write buffer 满时 stall 的精确对象是 lookup pipeline、arbiter grant，还是所有非 PTW 请求？
        回答：stall 的精确对象是 arbiter grant，不是 replacement 内部，也不是已经进入 lookup pipeline 的请求。也就是说，它不是在 replacement policy 内部暂停，也不是只暂停某一级 lookup pipeline，而是在仲裁器入口阻止新的 L2TLB 访问被 grant。
              wbuf full 会传给 arbiter，形成一个 block 条件。这个 block 条件会禁止新的 PTW read、TLB operation、ReqQ lookup、PFU lookup 获得 grant。由于这些请求拿不到 grant，就不会进入后续 L2TLB lookup pipeline。
              但已经进入 pipeline 的访问不会被回滚或停在中间，它们会继续完成，并且可能继续把 RRPV 更新 push 到 wbuf。用提前拉高 full 的方式预留了几个空位，就是为了容纳这些已经在途的更新。
              另外，PTW read 之后已经挂起的 PTW write 不受这个 full block 限制，因为这个写回必须完成。
              总体说：wbuf full stall 的是“新的 arbiter grant”，效果上阻止新的访问进入 lookup pipeline，而不是暂停已经在 pipeline 里的访问。

        11. RRPV write buffer bypass 多个 pending 写命中同一 set/way 时使用最新还是最旧值？
        回答：RRPV write buffer bypass 多个 pending 写命中同一 set/way 时，机制上使用最新值。
              理由是 bypass 扫描顺序从 FIFO head 到 tail，也就是从最旧到最新；每次命中都会覆盖前一次命中的 bypass data，所以最后留下的是最年轻的 pending write。push 侧也有 CAM 合并，同一 way/index 再次 push 时会更新已有 entry，意图也是“latest wins”。

        12. PTW complete 写 SRAM 最高优先级时，如果同拍有 RRPV write buffer drain 或 TLB operation 写，谁优先？
        回答：PTW complete 写 SRAM 与 RRPV write buffer drain 不会同拍竞争。因为 wbuf drain 的条件是 pop_grant = ~arb_l2tlb_req，而 PTW write 会使 arb_l2tlb_req=1，所以 PTW write 当拍不会 pop wbuf。
              PTW complete 写 SRAM 与 TLB operation 写也不会同拍竞争。PTW 流程中的 ptw_on 会阻止 TLB operation grant，TLB operation 只有在没有 PTW active 时才能进入 arbiter。

        13. RRPV write buffer entry 的 `{Set_Index, New_RRPV, Way_Mask}` 是否还需要保存 way id、page size、bank mask 或每 way 独立 RRPV？
        回答：RRPV write buffer 不能只理解成一个 {Set_Index, New_RRPV, Way_Mask}。
              当前 wbuf entry 实际保存的是每 way 独立信息：每个 way 有自己的 valid、index、RRPV data。way id 不需要单独保存，因为数组 lane 本身就是 way id；
              bank mask 由 per-way valid 表达；page size 不保存，因为 page size 已经体现在前面算出的 per-way skew index 里；每 way 独立 RRPV 是需要的，因为 hit way 会置 0，其他 way 会 aging，值不相同。

        14. hit 时只把 hit way RRPV 置 0，其他未 hit way +1；如果 bank_sel 不是 8'hff，未选中的 way 是否保持不变？
        回答：hit 时，代码规则是：hit way RRPV 置 0，其他 way 使用预先算好的饱和 +1 值。
              这个计算本身不看 bank_sel，但普通 ReqQ/PFU lookup 的 bank_sel 本来就是 8'hff，最终 wbuf 写回用的是 final_way_vld 过滤 valid entry。
              TLB operation 这类非全 bank 访问不会走普通 wbuf aging 写回路径，所以不会把这个 aging 结果写回。

        15. refill 写入 victim way 的 RRPV 是 3，是否同时需要对其他候选 way RRPV +1？
        回答：需要。victim way 写 RRPV=3；其他 way 使用已经预计算的 +1 aging 值。也就是说，当前实现会同时 aging 其他 way，而不是只初始化 victim way。

    4.8 pipeline、返回与异常
        1. T0/T1/T2 描述是否对所有请求固定 3 拍？TLB operation 多周期扫描、PTW read/write、RRPV write buffer drain 是否也遵循该延迟？
        回答：T0/T1/T2 不是所有请求固定 3 拍的全局协议。它只适用于一次已经拿到 arb grant 的 L2TLB lookup/read 类访问：
                T0 是 arb_l2tlb_req 访问 SRAM，T1 是 raw_vld，T2 是 final_vld，这时生成 hit/miss/multi-hit、L1TLB cmplt/pgflt、ReqQ feedback 等结果。源头请求等待仲裁、ReqQ 排队、MB full retry、PTW ready、wbuf full stall 都不包含在这 3 拍里。
              TLB operation 不固定 3 拍。TLBP/TLBR/TLBWI 这类单次访问在拿到 grant 后大体走同一个 raw/final 路径；但 TLBWR 有读后写，INVASID/INVALL 是计数扫描多 entry，INVVA 是读比较后可选写回，所以整个 operation 延迟由 FSM、grant 和扫描次数决定。
              PTW refill 在 L2TLB 侧也不是“所有阶段各固定 3 拍”。arb_ptw_grant 先作为 acc_type=000 读/选择 victim，走 raw/final 路径；随后 ptw_write_req1/2 延迟到 arb_ptw_write_grant，以 acc_type=101 写入。这个写入不再产生raw_vld/final_vld，l2tlb_arb_ptw_cmplt 在写 grant 当拍产生。
              RRPV write buffer drain 也不遵循 T0/T1/T2。普通 lookup 的 RRPV 更新先进 wbuf，wbuf_pop_grant = ~arb_l2tlb_req 时趁 L2TLB 空闲写回 RRPV SRAM；它是后台 drain，可被后续 lookup CAM bypass，不是请求完成延迟的一部分。

        2. multi-hit 对 L1TLB 被描述为 page fault 类路径；具体返回 page fault、access fault，还是专用 multi-hit error？
        回答：multi-hit 对 L1TLB 的返回就是 page fault。代码里 final_tlb_hit_mult 直接置 l2tlb_l1itlb_pgflt 或 l2tlb_l1dtlb_pgflt，同时 ref_cmplt=1、ref_pavld=0。L1DTLB 侧把 jtlb_dutlb_pgflt 写入异常 CAM，expt_wr1_acflt 固定为0；L1ITLB 侧进入 PGFLT 路径。没有专用 multi-hit error 编码，也不是 access fault。

        3. L1TLB hit 返回的 flag 是否需要在 L2TLB 做权限检查，还是 L1 自行检查？
        回答：L1自行检查。

        4. PFU 的 sysmap/PMP/flag 检查输入来自哪里，检查延迟是否影响 prefetch_mask 清除时机？
        回答：PFU 检查输入来源：sysmap：mmu_sysmap_pa4 = lsu_mmu_va2，顶层接 ct_mmu_sysmap_4 返回 sysmap_mmu_flg4。它用于 MAEE=0 时的 PFU flag fault 判断，也用于输出 sec/share。PMP：mmu_pmp_pa4 = pfu_pa_buf。pfu_pa_buf 在 pfu_idle_st && l2tlb_pfu_cmplt 时锁存 l2tlb_pfu_pa；MMU off 时是 lsu_mmu_va2，否则是由 L2TLB hit/refill 的 ref_ppn/ref_pgs 加 VA offset 组成的物理地址。PMP 返回pmp_mmu_flg4，PFU_CHK 状态用它生成 l2tlb_pfu_deny。
              flag：L2 hit 路径用 final_hit_flg，来自 L2TLB data array 读出的 hit way；PTW PFU 返回路径用 ptw_l2tlb_ref_flg/pgflt/acc_err。权限条件还使用 MXR/SUM/MPRV/MPP/priv/MAEE。
              延迟会影响 prefetch_mask 清除。prefetch_mask 在 arb_pfu_grant 后置 1，只在 mmu_lsu_pa2_vld、mmu_lsu_pa2_err 或 l2tlb_arb_pfu_miss_mb_full 时清。PFU 命中且 flag 不提前失败时，会先进入 PFU_CHK 等 PMP 判断，再到PFU_OK/PFU_DENY 拉 mmu_lsu_pa2_vld，所以 PMP 检查延迟直接推迟 mask 清除。flag/sysmap 失败则直接转 DENY，少走 PMP CHK。

        5. PFU miss 且 PTW enabled 时，是发 PTW 还是走 error/deny？overview、miss buffer 和 PFU pipeline 描述需要统一。
        回答：PFU miss 且 cp0_mmu_ptw_en=1 时，发 PTW。只有两种不是正常发 PTW：
                1. miss buffer 满：!mb_alloc_valid 时置 l2tlb_arb_pfu_miss_mb_full，用于清 prefetch_mask/让 PFU 请求可重试。
                2. cp0_mmu_ptw_en=0：PFU miss 被当成 fault/deny 类完成，不发 PTW。

        6. TLBR/TLBWI/INVASID/INVALL 这类 cmp_with_va=0 请求在 T2 被归为“非普通 hit”，是否有单独 done 信号而不是 multi-hit？
        回答：是，有单独完成路径，不看 multi-hit。TLBR/TLBWI/INVASID/INVALL 这类 TLB operation 进入 L2TLB 时 acc_type=001，其中 TLBR/TLBWI/INVASID/INVALL 的 cmp_with_va 通常为 0，所以 final_tlb_hit 和 final_tlb_hit_mult 都不会成立。它们的完成看 l2tlb_tlboper_cmplt= final_vld && acc_type==001，再由 ct_mmu_tlboper 转成各自的 tlbr_cmplt/tlbwi_cmplt/invasid_cmplt/invall_cmplt/tlboper_xx_cmplt。INVASID 另外用 l2tlb_tlboper_asid_hit 和 l2tlb_tlboper_sel 做 ASID 命中选择，不是multi-hit error。

        7. 同一 set 多 way hit 时，INVVA 会清所有 hit way；普通 lookup multi-hit 是否也会更新 RRPV？
        回答：INVVA是 VA compare 请求，cmp_with_va=1，l2tlb_tlboper_sel 会取 final_way_hit，所以同一 set 多 way hit 时，写回 invalidate 会清所有 hit way。
              普通 lookup 出现 multi-hit 时，不更新 RRPV。RRPV 更新的 push_req 只来自 normal hit 或 miss：normal hit 要求 exactly one hit，miss 要求 zero hit；multi-hit 既不是 hit 也不是 miss，所以不会 push 到 RRPV wbuf，不会 promote 任何 hit way，也不会 aging。它会走 fault/page-fault 类返回路径。

        8. flush、exception、pipeline kill 是否会取消已发射但未完成的 ReqQ/PFU/TLB operation 请求？
        回答：不会由普通 flush、exception、pipeline kill 去取消已经发射到 L2TLB 的 ReqQ/PFU/TLB operation。
              ReqQ 没有 flush/kill/expt 输入。entry 发射后 sent=1，只靠 L2 pipeline feedback 清掉；MB full retry 才把 sent 清回 0 重新发射。L1 后面 abort/flush，最多是 L1 侧等待完成后丢弃或不写异常状态，不会撤销 L2 已发出的ReqQ。
              PFU 也没有 kill 输入。arb_pfu_grant 后 prefetch_mask 置位，直到 mmu_lsu_pa2_vld、mmu_lsu_pa2_err 或 l2tlb_arb_pfu_miss_mb_full 才清。也就是 PFU 请求会自然完成或因 MB full 释放重试窗口。
              TLB operation FSM 也没有 flush/exception/pipeline kill 取消路径。TLBP/TLBR/TLBWI/TLBWR/INVASID/INVALL/INVVA 一旦进入状态机，就等 jtlb_tlboper_cmplt、grant、计数扫描完成等条件收尾。普通 pipeline kill 不会中断它。唯一相关的特殊控制是 TLB operation 产生 tlboper_ptw_abort，它影响 PTW/L2 miss buffer，不是被 flush kill 取消 TLBOp 本身。              

        9. T2 miss 且 miss buffer full 时，ReqQ sent 拉低后重新发射；重新发射是否必须重新走完整 T0/T1/T2？
        回答：是的。

        10. PTW refill 与普通 lookup 同 VPN 同周期或相邻周期发生时，是否有 forwarding 或 ordering 规则？
        回答：没有。

        11. L2TLB 返回给 L1 ITLB 和 L1 DTLB 的响应字段是否完全相同？fetch/load/store 的 fault 编码是否不同？
        回答：L2TLB 给 L1 ITLB 和 L1 DTLB 的响应字段不完全相同。共同 payload 是 VPN/PPN/FLG/PGS，共用 l2tlb_l1tlb_ref_* 数据；
              两边各自有 ref_cmplt/ref_pavld/pgflt。区别是 DTLB 多一个 ref_eid，用于定位 L1 DTLB miss buffer entry；ITLB 没有这个 id。并且 ITLB 只接 type=3'b011，DTLB 接 load/store，即 type[1:0]==2'b10。

        12. page fault、access fault、PMP deny、flag fault、multi-hit、PTW disabled miss 是否都有独立可观察响应编码？
        回答：不是都有独立可观察响应编码。对 L1 ITLB/DTLB 来说，L2TLB 直返路径基本只有成功和 page-fault 类失败：ref_cmplt、ref_pavld、pgflt。multi-hit 和 PTW disabled miss 都被编码成 pgflt=1，没有专用 multi-hit code，也没有 PTW-disabled-miss code。access fault 主要来自 PTW 或 L1 本地 PMP 检查。PTW 返回有 pgflt 和 acc_err 两类标志，但没有更细的原因码。PMP deny 不单独编码：IFU 侧表现为 deny，LSU 侧表现为 access_fault，PFU 侧表现为 mmu_lsu_pa2_err。flag fault 也没有独立编码。普通 ITLB/DTLB 权限位、V/R/W/X/U/A/D 等 flag fault 最终归入 page fault；
              PFU 的 flag/sysmap 检查失败则归入 PFU deny/error，也就是 pa2_err。所以这些只是内部原因，不是独立响应编码。
              

        13. raw stage/final stage valid 在 stall、kill、tlboper_on、ptw_on 场景下如何保持或清除？
        回答：raw/final stage valid 不是可保持的 ready/valid 协议，只是 L2TLB 内部两级流水脉冲。如果 stall 发生在 grant 之前，比如 arb 被 tlboper_on、ptw_on、wbuf full、优先级挡住，则没有 arb_l2tlb_req，raw/final 不启动。已经进入 raw/final 的请求不会因为后续 stall 被取消，会自然走到 final。
              pipeline kill/exception/flush 没有接到 L2TLB raw/final valid 控制里，所以不会清掉已发射的 L2TLB pipeline 请求；取消语义主要在 L1 自己处理，或由 TLB operation 生成 PTW abort 影响 PTW/miss buffer。
              tlboper_on 会挡住普通 ReqQ/PFU/PTW read 新 grant，但 TLB operation 自己的子请求仍可继续发射；每个 TLBOp 子请求只要拿到 arb_l2tlb_req，照样产生 raw/final 脉冲。
              ptw_on 表示 PTW read/write 原子段进行中，会挡住新的 TLBOp/ReqQ/PFU/PTW read。PTW read 是 acc_type=000，会走 raw/final，用来算 victim/RRPV；PTW write 是 acc_type=101，明确不置 raw_vld，完成走单独的l2tlb_arb_ptw_cmplt，不走 final stage。


    4.9 UVM 可观测接口与检查点
        说明：本节同时包含已澄清的 DUT/接口行为和 UVM 策略问题。已回答条目可作为规格语义使用；只涉及验证方法的条目已转入 5.13 统一收敛。
        1. UVM scoreboard 应以哪些 visible transaction 作为 L2TLB 请求和响应边界？
        2. 是否允许验证环境直接观察内部 ReqQ/miss buffer/RRPV/write buffer 状态，还是只能通过接口行为推断？
        3. 对 TLB operation 的 done、abort、L1 invalidate 请求是否都需要作为 checker 观察点？
        4. 对 PTW read/write 两阶段 refill，验证模型应把它建模为一个原子 refill，还是两个可被阻塞的访问？
        5. spec 是否需要定义所有 access type 编码的非法值行为？
        6. 对 hash index、replacement victim、RRPV update 这类内部算法，UVM reference model 是否必须精确建模？
        回答：这部分先不精确建模。

        7. 对 credit-based L1/L2 请求协议，本 L2TLB UVM 是否只假设合法输入，还是也需要注入非法/overflow 场景？
        8. 对 TLB operation 扫描类请求，coverage 是否应覆盖每个 set、每个 way、global/non-global、ASID hit/miss 和 valid/invalid 组合？
        9. 对 multi-hit，验证环境是否需要主动构造非法多命中状态？如果需要，允许通过什么接口构造？
        10. spec 是否需要给出 L2TLB 对外所有 request/response 的时序图，作为 UVM monitor 和 checker 的依据？
        回答：AI不适合读图，我是指挥AI根据spec搭建uvm。如果当前spec不足以支撑monitor和checker的设计，是否可以用文字描述补充信息？

5. AI audit questions and UVM construction decisions
    说明
        以下问题是在只阅读本 spec 文本、且参考已有 4.x 回答后继续补充的审计点。目标是让后续 AI 能够据此搭建或修改完整 MMU UVM 环境。DUT 功能语义在各小节回答；全局 UVM 建模、checker、coverage、非法输入和 timeout 策略在 5.13 集中收敛。

    5.1 spec 状态、验证边界与可观测性
        1. 4.x 中已经回答的问题是否都应视为正式 spec 语义？如果 1~3 节正文与 4.x 回答存在不一致，UVM 环境应以哪一部分作为优先级最高的 golden 规则？
        回答：应该以4.x 回答作为优先级最高的 golden 规则。最好把不一致的地方找出来，让人类工程师澄清。

        2. 本文件中多处回答使用“当前 RTL”“代码里”等表述；这些描述是否允许直接作为 UVM 期望行为，还是需要先改写成与 RTL 无关的正式功能规范？
        回答：已经改写成改写成与 RTL 无关的正式功能规范。

        3. L2TLB UVM 的 DUT 边界到底是完整 mmu_l2tlb 顶层，还是只验证 L2TLB core/arbiter/ReqQ/miss buffer 等子模块组合？
        回答：我是要搭建整个mmu的验证环境，而不只是为l2tlb搭建uvm。这个文档的内容只是作为搭建完整uvm的一部分参考。

        4. UVM 环境应驱动真实顶层端口，还是允许直接驱动内部 arbiter/L2TLB/miss buffer/TLB operation 子接口？
        回答：应该驱动真实顶层接口。

        5. `signal description` 中列出的 `arb_l2tlb_*`、`queue_arb_*`、`l2tlb_arb_*` 等信号哪些是 DUT 对外端口，哪些只是内部 monitor 可选观察点？
        回答：这些只是mmu内部中l2tlb与其他模块的接口，只有少部分是与mmu外部的接口，比如pmp，sysmap。搭建uvm的时候应该站在mmu的角度。

        6. 验证环境是否允许 white-box 观察内部 ReqQ、miss buffer、raw/final stage、RRPV write buffer、ptw_on、tlboper_on、prefetch_mask、SRAM 内容？
        回答：允许。

        7. 验证环境是否允许 backdoor 初始化或修改 tag/data/RRPV SRAM，用于构造 hit、miss、multi-hit、invalid entry、RRPV corner case？
        回答：允许，但作为 directed white-box 能力使用，不作为普通随机 sequence 的默认建表路径。正常功能流量优先通过 PTW refill、TLBWI/TLBWR 等前门构造；backdoor 主要用于 multi-hit、invalid tag + nonzero payload、warm reset 前 SRAM 状态、指定 set/way 和 RRPV/debug corner。详见 5.13.2 和 5.13.8。

        8. 如果允许 backdoor 初始化，tag/data/RRPV 是否必须保持一致性？例如 tag.valid=0 时 data/rrpv 可否任意，tag.G 与 data flags 是否还有一致性要求？
        回答：tag.valid=0 时 data/RRPV 和 tag 其它字段可任意，普通 lookup/TLBP/INVVA 都必须视为 invalid 不命中；TLBR 仍可按 index 读出旧字段。tag.valid=1 时，tag.G 是独立字段，不在 data flags 中，因此不要求 tag.G 与 `ref_flg[13:0]` 存在重复一致性；但 VPN/ASID/PGS/G/PPN/flags 必须与该 directed test 的预期 translation 语义一致，reference model 也必须同步更新。

        9. 如果不允许 backdoor 初始化，UVM 应通过哪些合法前门路径构造 L2TLB entry：PTW refill、TLBWI/TLBWR，还是二者都必须支持？
        回答：在之前的问题中已作答。

        10. UVM scoreboard 应建成 cycle-accurate SRAM/reference model，还是 transaction-level reference model，只检查可见请求响应结果？
        回答：应建成 transaction-level reference model，以 MMU 顶层可见请求/响应和软件可见 TLB operation 结果为主。ReqQ、miss buffer、pipeline、RRPV/write buffer 不做 cycle-accurate golden model，只作为 white-box monitor、coverage、debug 或局部协议 assertion 输入。详见 5.13.2。

        11. 对 hash index、victim way、RRPV update 已有回答说“暂时不作为 UVM 验证点”；这是否意味着 UVM 不需要预测具体 set/way，只需要检查功能命中结果？
        回答：是的。

        12. 如果不精确建模 hash/RRPV，coverage 中“每个 set/way/victim/RRPV 状态”的覆盖目标是否仍然需要？若需要，应通过内部采样覆盖还是前门定向激励覆盖？
        回答：v1 不把每个 set/way/victim/RRPV 状态作为 hard coverage closure。可以通过内部采样收集 debug coverage，用于评估激励分布；不要求前门定向精确覆盖所有 hash/RRPV 组合，也不因这些 debug coverage 未满而阻塞 v1 验收。详见 5.13.2 和 5.13.7。

    5.2 位宽、编号与字段定义
        1. ReqQ 有 entry0-entry8 共 9 个 entry，但 `TRANS_ID_WIDTH=3`、`queue_arb_trans_id[2:0]` 只能表示 8 个值；ReqQ transaction id 的真实宽度和 entry 编码是什么？
        回答：ReqQ transaction id 的真实宽度是4bit，之前的spec有误。

        2. miss buffer 有 entry0-entry8 共 9 个 entry，但 `L2EID_WIDTH=3` 只能表示 8 个值；L2 miss buffer entry id 的真实宽度和 entry 编码是什么？
        回答：L2 miss buffer entry id 的真实宽度是4Bit，之前的文档有误，现已修改

        3. 1.5 中 `ptw_l2tlb_ref_id[L1EID_WIDTH+L2EID_WIDTH-1:0]` 按参数是 6 bit，但 4.6 回答写 `issue_eid` 默认总宽度是 7 bit，且高 4 bit 为 L2 MB entry id；PTW id 的真实总宽度和字段切分是什么？
        回答：`ptw_l2tlb_ref_id[L1EID_WIDTH+L2EID_WIDTH-1:0]`是7bit，之前的spec有误，现已修改。高 4 bit 为 L2 MB entry id，低3bit为l1dtlb miss buffer entry id
        
        4. 4.6 回答中“L2EID_WIDTH + L1EID_WIDTH = 3 + 4”与 1.1 参数 `L1EID_WIDTH=3, L2EID_WIDTH=3` 不一致；哪个参数值为准？
        回答：L2EID_WIDTH + L1EID_WIDTH = 4 + 3。

        5. 1.4 中 `arb_l2tlb_eid[EID_WIDTH-1:0]` 使用了未定义的 `EID_WIDTH`；它是否应为 `L1EID_WIDTH`，真实宽度是多少？
        回答：它是L1EID_WIDTH，真实宽度是3bit。

        6. `lsu_mmu_va2[27:0]` 被描述为 PFU 地址，同时又说低 27 bit 作为 VPN；bit[27] 的语义是什么？
        回答：lsu_mmu_va2[27] 不是 VPN 的一部分。这根线做成 28 bit，是因为 LSU/PFU 侧按 PA_WIDTH=40 来传“页号”，即地址[39:12]，宽度是 28 bit。
              但 MMU 的 Sv39 VPN 宽度是 VA_WIDTH-12 = 39-12 = 27 bit，所以真正用于 JTLB 查询、VPN 比较的是 lsu_mmu_va2[26:0]，也就是 VA[38:12]。
              因此：
                lsu_mmu_va2[26:0] = PFU 虚地址的 VPN
                lsu_mmu_va2[27] = 地址 bit[39]，更准确说是 40-bit 地址页号/PPN 的最高位
                MMU 开启时，bit[27] 不参与 JTLB VPN 匹配；MMU 关闭或走物理地址相关路径时，它才作为物理页号高位使用。
                
        7. PFU 返回 `mmu_lsu_pa2[27:0]` 是 PA[39:12]、PA[27:0]、还是某种压缩物理页号？它与完整 byte PA 的拼接关系需要怎样定义？
        回答：mmu_lsu_pa2[27:0] 应定义为 PA[39:12]，也就是 28-bit PPN。它不是 PA[27:0]，也不是压缩物理页号。它只是完整 40-bit byte PA 去掉低 12 bit 页内偏移后的物理页号。
              完整 byte PA 的拼接关系是：full_pfu_pa[39:0] = {mmu_lsu_pa2[27:0], pfu_va[11:0]} 
              这里的 pfu_va[11:0] 来自 PFU 本地维护的预取虚地址低 12 位，不由 MMU 返回。更精确地说：
                  MMU 输入：lsu_mmu_va2[26:0] = PFU VA[38:12]，lsu_mmu_va2[27] = PFU 地址 bit[39]，仅在物理地址/MMU-off 语境下有意义
                  MMU 输出：mmu_lsu_pa2[27:0] = translated PA[39:12]

        8. 对 ITLB 请求，`queue_arb_eid` 和 PTW id 低位 L1EID 固定为 0；UVM 是否需要检查这些无效字段必须为 0，还是可以忽略？
        回答：可以忽略。

        9. `l2tlb_regs_tlbp_hit_index[10:0] = {way_id[2:0], set_idx[7:0]}` 只能编码 2048 个 entry；这是否也是所有 TLBR/TLBWI/TLBWR index 的统一编码？
        回答：{way_id[2:0], set_idx[7:0]} 是 L2TLB 物理 entry 的统一编码空间，容量就是 8 ways * 256 sets = 2048 entries。所以对 TLBP 返回值、TLBR/TLBWI 指定 entry 来说，应当统一按这个编码理解。
              TLBP 命中后返回的 index 就是这个编码。TLBR 和 TLBWI 使用 MIR 里的 index 时，也应按同样方式解释：index 的高 3 bit 选择 way，低 8 bit 选择 SRAM row/set。
              但 TLBWR 要分开理解。TLBWR 不是用 MIR 高 3 bit 指定 way，而是由替换策略选出 victim way，再写入对应 set。也就是说，TLBWR 最终写到的 entry 仍然可以用同样的 way 加 set 编码表示，但它的 way 来源不是软件写入的 index，而是硬件 replacement policy。MIR 的第 11 bit 当前不属于有效 L2TLB entry 编码。

        10. page size one-hot 只定义 3'b001/010/100；如果 tag 中 pgs 为 000、011、101、110、111，lookup、TLBR、TLBP、INVVA、replacement 应如何处理？
        回答：非法 tag.pgs 的行为是由现有 compare/replacement 逻辑自然决定的。
                普通 lookup：非法 tag.pgs 不会命中。原因是 L2TLB compare 用每个 way 的预测 page size raw_pre_pgs 去和 tag 里的 raw_way_pgs 做精确相等比较。raw_pre_pgs 只会是 001/010/100，所以 tag 里如果是 000/011/101/110/111，pagesize 相等条件为假，最终 final_way_hit 为 0。结果就是 miss。
                TLBP：和普通 lookup 一样，不会命中非法 tag.pgs entry。TLBP 也是走 final_way_hit/final_tlb_hit 这套 VA compare path，所以非法 pgs entry 不会返回 hit index，也不会参与 multi-hit 计数。
                INVVA：读阶段也走同一套 VA compare，因此非法 tag.pgs entry 不会产生 jtlb_tlboper_va_hit。如果没有其他合法 entry 命中，INVVA 直接完成，不进入写清除阶段；如果有其他合法 entry 命中，写阶段只清 final_way_hit 对应的合法命中 way，非法 pgs entry 不会被 INVVA 清掉。
                TLBR：会原样读出。TLBR 是 index read，cmp_with_va=0，通过 index 选中 way 后直接把 tag 里的 pgs 送到 l2tlb_tlbr_pgs。所以 tag 中是 011 就读出 011，不会修正，也不会报错。
                replacement：当前 replacement 不看 pgs，只看 tag valid 和 RRPV/mask。也就是说，如果 tag.valid=1 但 tag.pgs 非法，它在 replacement 里仍被当作 valid entry，不会被当作 free entry 优先回收；只有在没有 free way 时，才可能按 RRPV 规则被选为 victim。如果 tag.valid=0，那不管 pgs 是什么，都按 invalid/free 处理。

        11. access type 已定义 000、001、010、011、100、101、110；如果出现 3'b111，DUT 行为应是忽略、断言、按 miss/fault 处理，还是属于 UVM 不应产生的非法输入？
        回答：这是不应产生的非法输入。


    5.3 reset、初始化与时钟门控
        DUT 行为已答，UVM 策略见 5.13
        1. `cpurst_b` 异步拉低/释放的最小周期和释放同步要求是什么？UVM 是否需要测试 reset 在有 outstanding 请求时发生？
        回答：`cpurst_b` 为异步低有效复位，拉低后会清除 MMU/L2TLB 的寄存器型状态，包括 ReqQ valid/sent、miss buffer valid/sent、lookup 流水 valid、arbiter 运行标志、PFU 状态机、RRPV write buffer 等，使这些状态回到 idle/invalid。复位脉冲宽度需要满足触发器和时钟门控单元的最小复位脉宽要求，设计没有额外定义固定的最小周期数。`cpurst_b` 释放端需要由外部保证相对 `forever_cpuclk` 以及门控派生时钟满足 recovery/removal 时序。若 reset 发生在 outstanding 请求期间，这些在途请求会被取消，UVM scoreboard 应在 reset 拉低时清空 outstanding transaction、ReqQ/MB/L1TLB 参考状态和未完成期望。
              但 `cpurst_b` 本身不会清 L2TLB tag/data SRAM。core 级 reset 后 translation entry 必须全部 invalid，这个语义由硬件 reset-invalidate 流程保证：IFU reset vector 逻辑发 `ifu_cp0_rst_inv_req`，CP0 reset-inv FSM 拉起 `cp0_mmu_tlb_all_inv`，MMU TLB operation 执行 TLB inv-all，扫描 L2TLB 全部 index/way 并把 tag 写 0，等 `mmu_cp0_tlb_done` 后 CP0 返回 `cp0_ifu_rst_inv_done`，前端才继续 reset 后流程。UVM 需要把 `cp0_ifu_rst_inv_done` 或等价完成事件作为 reset 后开始正常取指/翻译检查的边界，并检查 reset-inv 流程最终完成。

        2. reset 期间各输入 valid/request 是否必须为 0？如果 reset 期间或刚释放 reset 当拍有请求，DUT 行为是否有定义？
        回答：reset 期间普通翻译请求、PFU 请求、PTW refill、软件 TLB operation 等输入 valid/request 应保持为 0，这是安全且有定义的使用方式。reset 刚释放后也不应立即放开普通 translation 流量，而应先让 core reset-inv 流程完成 L2TLB inv-all；在 `cp0_ifu_rst_inv_done` 之前，UVM driver/sequence 应阻塞普通 IFU/LSU 翻译访问，monitor/scoreboard 应把此阶段建模为 reset 初始化阶段，而不是正常 lookup 阶段。
              reset 刚释放当拍如果已有合法 reset-inv 请求，则按初始化流程处理；如果普通请求与 reset 释放或 reset-inv 尚未完成重叠，该场景不应作为合法功能行为。UVM 可以增加协议检查：reset assert 期间普通请求为 0；reset deassert 后，必须先观察到 `ifu_cp0_rst_inv_req -> cp0_mmu_tlb_all_inv -> mmu_cp0_tlb_done -> cp0_ifu_rst_inv_done` 这条机制完成，再允许普通翻译请求进入可检查窗口。

        3. SRAM 不随 reset 清零，但仿真 RAM initial 清 0；UVM golden model 在 reset 后应把 SRAM 视为 unknown、全 0，还是仅以 tag.valid 判断 entry 是否有效？
        回答：L2TLB entry 是否有效应以 `tag.valid` 为准。L2TLB tag/data/RRPV SRAM 不随 `cpurst_b` 直接清零，仿真 RAM 的 initial 清 0 只能代表冷启动仿真的初始值，不能代表 reset 语义，也不能用于证明 warm reset 后 SRAM 自然 invalid。reset 后 golden model 不应简单把 L2TLB SRAM 视为全 0；在 reset-inv 完成前，L2TLB SRAM 内容应视为未知或可能保留旧值。
              UVM 的参考模型建议分两层处理：`cpurst_b` 拉低时，L1iTLB/L1dTLB 等寄存器型 entry 直接置 invalid；L2TLB SRAM 保持 unknown/stale 状态，直到监测到 reset-inv 的 TLB inv-all 完成后，再把 L2TLB 全部 entry 的 `tag.valid` 置 0。后续 lookup 只依据 `tag.valid` 判定 entry 有效性；tag.valid 为 0 时，即使 data/RRPV 或其它 tag 字段非 0，也应视为无效 entry。

        4. 运行中 warm reset 后，如果 SRAM tag.valid 中仍有旧值，DUT 是否可能命中旧 entry？UVM 是否需要覆盖这种场景，还是 reset 后测试默认重新初始化 SRAM？
        回答: 如果只拉 `cpurst_b` 而不执行 reset-inv，warm reset 后 SRAM 中旧的 `tag.valid=1` entry 可能仍然被命中，这是不安全的集成方式。core 的正确 reset 语义不是依赖 SRAM 自然清零，而是依赖 reset 后自动发起 TLB inv-all，把 L2TLB 全部 index/way 的 tag 写 0，从而保证 MMU translation entry 全部 invalid。
              UVM 需要覆盖 warm reset 场景：可以在 reset 前构造 L2TLB 中存在有效 entry，然后拉 reset，之后必须观察 reset-inv 流程完成，并在完成后将参考模型中的 L2TLB 全部 entry 置 invalid；如有 backdoor/内部监测能力，还可检查 inv-all 扫描期间确实对全部 set/way 产生清 valid 写入。若某个 testbench 只驱动 `cpurst_b`，但没有驱动或没有集成 `ifu_cp0_rst_inv_req -> cp0_mmu_tlb_all_inv -> mmu_cp0_tlb_done` 机制，UVM 应将其标记为不完整 reset 环境，不应假设 reset 后 L2TLB 已经 invalid。

        5. `cp0_mmu_icg_en=0` 时，DUT 是否仍必须功能正确但少开门控时钟，还是该位关闭会阻止部分内部状态更新？
        回答：`cp0_mmu_icg_en` 是时钟门控控制位，不是 MMU 功能关闭位，也不是 reset-inv 屏蔽位。无论该位如何配置，reset 后必须仍能完成必要的 TLB inv-all 初始化流程，不能因为时钟门控配置导致 L2TLB 清 valid 流程停住。功能语义上，`cp0_mmu_icg_en=0` 不应改变 L2TLB 的访问、命中、miss、refill、invalidate 等结果，只影响时钟打开策略。
              UVM 需要注意两点：第一，测试 clock gating 时不能把 `cp0_mmu_icg_en=0` 建模成内部状态冻结；第二，若覆盖 reset 与 clock gating 组合场景，应检查 reset 释放后 reset-inv 仍能推进到 `mmu_cp0_tlb_done/cp0_ifu_rst_inv_done`，并且完成后 translation entry 按全 invalid 状态建模。

        6. `pad_yy_icg_scan_en=1` 的 scan 模式是否需要在 UVM 功能验证中覆盖？scan 模式下功能时序是否保持一致？
        回答：`pad_yy_icg_scan_en` 只用于时钟门控单元的 scan/DFT 旁路控制，不参与 L2TLB 的请求仲裁、SRAM 访问、命中比较、refill、invalidate 或响应生成。scan 使能拉高时，语义上是强制打开被门控的时钟，便于可测性；它不定义新的功能协议，也不改变 reset 后必须执行 TLB inv-all 的机制。
              正常功能 UVM 默认应使用 `pad_yy_icg_scan_en=0`。如果需要做 scan_en smoke test，只应检查打开 scan_en 不破坏 reset-inv 完成和基本功能结果，不应把 scan 模式作为独立功能时序来建立新的 scoreboard 规则。


    5.4 L1 ReqQ 与 credit 协议
    DUT 行为已答，UVM 策略见 5.13
        1. `i_req_valid`、`d_req_valid` 是单周期 pulse，还是可以保持到 credit 返回？DUT 对持续 valid 的同一请求会按每拍新请求采样还是只采一次？
        回答：应按“单拍 request fire”使用，不是保持到 credit_return 的 valid/ready 协议。mmu_l2tlb_reqq 消费端没有边沿检测、没有 sample-once 锁存，也没有 ready。
              直接用 i_req_valid/d_req_valid 做 allocate/issue 条件：valid 每高一拍，DUT 就按一拍请求处理。
              如果同一个请求持续 valid：
                - d_req_valid：每拍会尝试分配一个新的 DTLB ReqQ entry，同一 payload 会变成多笔重复请求，直到 entry/credit 假设被打破。
                - i_req_valid：每拍会写 entry0，并可能重复走 bypass/issue；不是只采一次，且 ITLB 只有 entry0，持续高还可能覆盖/重初始化 entry0。
            补充：L1I 端 iutlb_l2tlb_req 实际是 WFG 状态电平，正常有 credit 时 WFG 下一拍转 WFC，所以表现为单拍；L1D scheduler 也用 credit gate，dutlb_arb_req fire 后立即扣 credit。credit_return 是后续 entry dealloc 后返还credit，用来允许下一笔请求，不是当前 valid 的接受握手。

        2. L1 请求 payload `*_vpn`、`d_req_eid`、`d_req_is_load` 需要在 `*_req_valid` 当拍稳定即可，还是 valid 保持期间必须一直稳定？
        回答：*_req_valid 是单拍 pulse，所以 payload 只需要在该 valid 当拍稳定，满足采样时钟的 setup/hold。下一拍 valid=0 后，*_vpn、d_req_eid、d_req_is_load 可以变，不需要等 credit_return。

        3. `i_credit_return`、`d_credit_return` 是一周期 pulse 还是 level 信号？同一拍 credit_return 和新的 req_valid 同时出现时，是否允许复用刚释放的 entry？
        回答： i_credit_return、d_credit_return 按 pulse 使用，不是 level/ready 信号。们由 ReqQ entry dealloc 组合产生：entry 有效并收到 terminal feedback 时拉高；该拍时钟沿清掉 entry valid，下一拍 dealloc/credit_return 就会拉低。
              同一拍 credit_return 和新的 req_valid 可以同时出现，信用计数上允许 send+return 同拍抵消，不改变 credit count。
              但不能依赖“刚释放的 entry”在同一拍被新请求复用。ReqQ 分配逻辑看到的是清除前的 valid 状态，同拍 dealloc 的 entry 要到下一拍才真正变成 free。ITLB entry0 同拍 clear 和 alloc 时也是 clear 优先，不是同拍复用语义。             

        4. ReqQ entry 释放与新请求分配同拍发生时，分配优先级如何定义？新请求能否使用同拍释放的 entry？
        回答：ReqQ entry 的“释放”和“新分配”同拍时，整体不是“释放后立即复用”的语义。DTLB entries 的分配优先级是：先看当前拍、清除前的 entry_vld_vec，用 FFZ 选第一个已经 invalid 的 entry。
              也就是说，同拍正在 dealloc 的 entry 在分配逻辑里仍被看成 valid，不能被本拍新请求选中。它要到时钟沿后 valid 清掉，下一拍才成为可分配 entry。
              如果本拍已经存在别的空 entry，新请求可以分配到那个旧空 entry；如果唯一空位来自本拍 dealloc，则本拍不能分配，下一拍才行。
              ITLB entry0 更不支持同拍复用：同拍 entry_clr 和 entry_alloc_en 时，valid bit 逻辑 clear 优先于 alloc，时钟后 entry 仍是 invalid。因此不能把同拍释放的 entry0 当作已重新分配成功。

        5. 当 ReqQ 中没有 unsent entry 但存在 sent outstanding entry 时，新来的 ITLB/DTLB 请求是否仍可 bypass 到 arbiter？
        回答：新来的 ITLB/DTLB 请求可 bypass 到 arbiter。

        6. 当新请求 bypass 参与 arbiter 但未 grant 时，后续 arbiter 看到的是该请求已入队 entry；该 entry 在下一拍的选择优先级如何与其它 unsent entry 比较？
        回答：只要reqq中有未发射的有效entry，就不可能把新请求bypass到arbiter，也就是说，下一拍只会有这个新请求在reqq中，不存在所谓的与其它 unsent entry的竞争关系。

        7. DTLB entry1-entry8 分配采用最低空闲 entry；如果同拍有多个 DTLB 请求，协议是否保证最多一个，还是 L2TLB 需要定义多个请求的处理？
        回答：每一拍最多有一个dtlb的请求进入reqq。

        8. 如果上游违反 credit 协议，在 entry full 时仍发 ITLB/DTLB 请求，L2TLB 是否忽略、覆盖、断言，还是该场景不纳入 L2TLB UVM？
        回答：该场景不纳入 L2TLB UVM

        9. ReqQ 不保存 ASID/privilege/MMU enable/SUM/MXR，使用“当前值”；UVM 是否需要主动覆盖请求排队期间这些控制寄存器变化的场景？
        回答：不作为正常功能覆盖场景，应作为软件/系统约束禁止。DUT 行为是使用比较/检查当时的当前控制寄存器值，但完整 MMU UVM sequence 应保证 ASID/SATP/MMU enable/privilege/SUM/MXR/MPRV/MPP/MAEE 在相关 outstanding request 完成、drain、flush 或 abort 前不变化；同时用 assertion 检查控制寄存器改写前 outstanding walk/request 已安全处理。详见 5.13.3 和 5.13.8。

        10. 如果 ASID 在 ReqQ request 发出后、T2 compare 前改变，scoreboard 应按 T2 当前 ASID 判断，还是应限制 sequence 不产生这种软件不应出现的场景？
        回答：从整个 core 的视角看：正常架构路径下，不应该出现“旧 ASID 的请求还在 L2TLB lookup 流水线里，同时 SATP.ASID 已经被改掉”的情况。关键点是：这个保证不是 L2TLB 自己做的，而是 core 前后端协议做的。
              CSR/SATP 写在 C910 里不是普通乱序指令随便执行。CSR 指令会被 IDU 当作 special/fence 类指令处理，发射前要等前面的流水、ROB、PST、LSU commit 数据等基本排空。之后 CP0 真正写 SATP 也不是 decode/issue 时写，而是等该 CSR 指令到 RTUcommit0 时才写。写完还会触发 flush，清掉后续取指/执行路径，并且 SATP 写会清 L1TLB。
              所以对正常的 IFU 取指翻译、load/store 翻译来说，旧 ASID 下的架构性请求应该已经完成、被 drain，或者被 flush/abort 掉；新 ASID 下的请求应该发生在 SATP 写和 flush 之后。
              所以对正常的 IFU 取指翻译、load/store 翻译来说，旧 ASID 下的架构性请求应该已经完成、被 drain，或者被 flush/abort 掉；新 ASID 下的请求应该发生在 SATP 写和 flush 之后。
              应限制 sequence 不产生这种软件不应出现的场景

    5.5 arbiter、stall 与请求保持
    DUT 行为已答，UVM 策略见 5.13
        1. PTW、TLB operation、ReqQ、PFU 的请求信号在未 grant 时是否都必须保持有效直到 grant？如果某个请求只 pulse 一拍但未 grant，DUT 是否会丢弃？
        回答：arbiter 本身不缓存未 grant 的请求，只按当前拍看到的请求信号组合生成 grant。ReqQ 和 TLB operation 自身有等待 grant 的状态保持机制：ReqQ entry 在未 grant 时保持 ready，TLB operation 状态机在 wait-for-grant 状态保持 `tlboper_arb_req`。PTW refill 请求也需要由 PTW/TWU 侧保持到 `arb_ptw_grant` 后才算被接收。PFU 请求没有在 arbiter 侧排队，`lsu_mmu_va2_vld` 如果只 pulse 一拍且当拍没有 `arb_pfu_grant`，该次 PFU arbiter 访问不会被保存，必须由上游保持或重新发起。

        2. wbuf full stall 阻塞 PTW read、TLB operation、ReqQ、PFU；被阻塞请求的 ready/hold 协议分别是什么？
        回答：RRPV write buffer full 通过 `l2tlb_arb_rrpv_wbuf_full` 形成 arbiter block 条件，会阻止 PTW read、TLB operation、ReqQ 和 PFU 获得新的 L2TLB grant。PTW read 侧还会通过 `arb_ptw_mask` 被屏蔽，直到 wbuf full 解除后再申请；TLB operation 在自身 wait-for-grant 状态保持请求；ReqQ entry 保持 valid 且未 sent，等后续 grant；PFU 没有内部排队语义，需要上游保持 `lsu_mmu_va2_vld` 或在失败后重发。PTW write 不受 wbuf full 阻塞，因为 PTW write 直接写 tag/data/RRPV SRAM，不进入 RRPV write buffer。

        3. `tlboper_on=1` 时即使没有当拍 TLB operation SRAM 访问，也阻塞其它请求；这种空泡是否需要 checker 逐拍检查？
        回答：`tlboper_on` 从某次 TLB operation 获得 grant 后置 1，直到 `tlboper_xx_cmplt` 才清 0。在 `tlboper_on=1` 期间，PTW read、ReqQ 和 PFU 都不能获得 grant；即使某一拍没有实际 TLB operation SRAM 访问，这个阻塞仍然有效。TLB operation 自己的后续 read/write beat 可以继续通过 arbiter 访问 L2TLB。该空泡是 TLB operation 独占 L2TLB 访问窗口的一部分。

        4. `ptw_on=1` 从 read grant 到 write grant；如果预期 write grant 当拍被其它条件阻塞，是否允许 ptw_on 延长，还是设计保证一定不会阻塞？
        回答：`ptw_on` 在 PTW read grant 后置 1，并保持到对应 PTW write 完成。正常流程中，PTW read grant 后会打拍生成 `ptw_write_req1`、`ptw_write_req2`，随后由 `arb_ptw_write_grant` 发出 PTW write；`ptw_on=1` 会阻塞 TLB operation、ReqQ、PFU 和新的 PTW read，因此其它普通请求不会抢占这个 write。wbuf full 也不阻塞 PTW write。若异常条件导致 PTW write 当拍不能 grant，`ptw_on` 会继续保持，直到 PTW write 完成信号到来后才清除。

        5. 同一拍 PTW read request、TLB operation request、ReqQ request、PFU request 同时有效时，UVM 是否需要按 `ptw > tlb operation > reqq > pfu` 检查唯一 grant？
        回答：在没有 `ptw_on`、`tlboper_on`、wbuf full 等阻塞条件时，同一拍多个源同时请求的固定优先级是 PTW read 最高，其次 TLB operation，其次 ReqQ，PFU 最低。每拍最多只有一个源获得进入 L2TLB 的 grant。若已有 PTW read/write 流程在进行，则 PTW write 是该原子 refill 流程的后续访问，会阻塞其它源直到完成。

        6. 同一拍 `tlboper_on` 清除和新的 PTW/ReqQ/PFU request 到来时，是否允许新 request 当拍 grant，还是必须等下一拍？
        回答：不允许同拍 grant。grant 组合逻辑看到的是当前拍尚未清除前的 `tlboper_on=1`，因此 PTW read、ReqQ 和 PFU 当拍仍被阻塞。`tlboper_on` 在时钟沿根据 `tlboper_xx_cmplt` 清 0 后，新的 PTW/ReqQ/PFU 请求最早下一拍参与仲裁。

        7. 同一拍 `ptw_on` 因 PTW write grant 清除和新的 TLB operation/ReqQ/PFU request 到来时，是否允许新 request 当拍 grant？
        回答：不允许同拍 grant。PTW write grant 当拍，当前 `ptw_on` 仍为 1，TLB operation、ReqQ 和 PFU 的 grant 条件都被 `ptw_on` 阻塞。该拍只完成 PTW write；`ptw_on` 在时钟沿清除后，其它新请求最早下一拍获得仲裁机会。

        8. `prefetch_mask` 清除和 `lsu_mmu_va2_vld` 持续为 1 同拍发生时，PFU 是否可以同拍重新获得 grant，还是必须下一拍？
        回答：必须下一拍。PFU grant 条件使用当前拍的 `prefetch_mask`，当 `prefetch_mask=1` 且本拍因为 `mmu_lsu_pa2_vld`、`mmu_lsu_pa2_err` 或 `l2tlb_arb_pfu_miss_mb_full` 清除时，清除结果要到时钟沿后生效；因此同拍不能重新 grant。下一拍若 `lsu_mmu_va2_vld` 仍为 1，且没有更高优先级请求、`ptw_on/tlboper_on` 或 wbuf full 阻塞，PFU 才能重新获得 grant。

        9. arbiter payload 必须在 grant 当拍稳定；UVM monitor 应以哪个信号作为 accept 事件：各 source grant、`arb_l2tlb_req`，还是二者组合？
        回答：L2TLB 侧的接收事件是 `arb_l2tlb_req=1`。同一拍应有且只有一个来源 grant 或内部 PTW write grant 选择本次访问来源，并由该 grant 选择 `arb_l2tlb_vpn`、`arb_l2tlb_acc_type`、`arb_l2tlb_write`、bank select、index、tag/data din 等 payload。各 source grant 表示对应源被接受，`arb_l2tlb_req` 表示 L2TLB SRAM/pipeline 实际收到一次访问；二者在功能上是同一接受动作的源侧和目标侧表示。

        10. RRPV write buffer drain 不产生 `arb_l2tlb_req`；UVM 是否需要把 drain 建模为单独的内部 SRAM 写 transaction？
        回答：RRPV write buffer drain 是内部 replacement metadata 写回，不属于新的 L2TLB 请求访问。它在 `wbuf_empty=0` 且当前没有 `arb_l2tlb_req` 的空闲拍发生，只写 RRPV SRAM，不访问 tag/data SRAM，不启动 raw/final lookup 流水，也不产生任何 source grant 或外部 completion。它只更新后续 victim 选择和 RRPV bypass 可见的内部状态。

    5.6 SRAM、entry 内容与前门/后门一致性
    DUT 行为已答，UVM 策略见 5.13
        1. invalidate 类操作写无效时，tag/data 是否都必须写 0？overview 中写“data 也可同步清 0”，后文写“tag/data 写入 0”；UVM 是否应检查 data 被清 0？
        回答：invalidate 类操作真正产生写无效 beat 时，被选中的 way/bank 的 tag 和 data 都写 0。也就是说，tag.valid 会被清 0，tag 中 VPN/ASID/PGS/G 也写 0，data 中 PPN/flag 也写 0。若某个 invalidate read 阶段没有找到需要清除的 way，则不会对该 set 产生对应的写无效修改。INVALL 扫描时会对每个 set 的所有 way 执行写 0。

        2. tag.valid=0 但 data.V=1、PGS/G/ASID/VPN 非 0 时，lookup 必须 miss；UVM 是否需要覆盖 invalid tag + nonzero data 的场景？
        回答：必须 miss。普通 VA compare 命中条件包含 tag.valid，tag.valid=0 时该 entry 不参与有效命中；data.V、PPN、flag 或 tag 其它字段即使非 0，也不能让该 entry 命中。TLBR 这类按 index 读 entry 的操作不属于普通 lookup 命中判定，它可以读出 SRAM 中保存的旧字段。

        3. TLBWI/TLBWR 写 tag.valid=1 且 data.V 可为 0；普通 L1 lookup 命中这种 entry 后 L2TLB 是否仍返回 `ref_pavld=1`，由 L1 后续判 page fault？
        回答：是。普通 ITLB/DTLB lookup 的 L2TLB 命中只检查 tag valid、VPN/page size、ASID/global 等 tag 条件，不检查 data flag 里的 PTE.V/R/W/X/U/A/D。只要 tag 命中且没有 multi-hit，L2TLB 会返回 `ref_cmplt=1`、`ref_pavld=1`，并把 PPN/flag/page size 返回给 L1。data.V=0 这类 PTE flag fault 由 L1 后续根据返回的 flag 判断。

        4. PFU lookup 命中 data.V=0 的 entry 时，是在 L2TLB PFU flag check 阶段返回 `pa2_err`，还是仍返回 PA valid 后由 LSU 检查？
        回答：PFU 路径会在 L2TLB 内部做 flag check。data.V=0 会触发 PFU flag fault，随后 PFU response 进入 error/deny 路径，对 LSU 输出 `mmu_lsu_pa2_vld=1` 且 `mmu_lsu_pa2_err=1`。因此该错误由 L2TLB 的 PFU 检查阶段报告，不是只返回一个正常 PA 后再完全交给 LSU 判断。错误时 PA/sec/share 可能仍有输出值，但以 `pa2_err=1` 表示该结果不可作为正常翻译使用。

        5. `RSW[1:0]` 被实现忽略；TLBR 是否仍原样读出 RSW，L1 refill 是否会保存并返回 RSW？
        回答：RSW 不参与命中比较和权限判断，但会作为 flag 的一部分保存和传递。L2TLB data flag 中包含 RSW，对应 flag[8:7]。TLBWI/TLBWR 会把 MEL 中的 RSW 写入 data，PTW refill 也会把 PTE[9:8] 写入 data flag[8:7]。TLBR 读出 entry 时会把 flag[8:7] 写回 MEL.RSW，普通 L1 refill 返回的 `l2tlb_l1tlb_ref_flg` 也包含这两位。

        6. 大页 PPN 低位不对齐时，TLBWI/TLBWR/PTW refill 是否允许写入？PFU PA 拼接时是否直接用 PPN 高位并忽略低位？
        回答：TLBWI/TLBWR 和 PTW refill 写入 L2TLB 时不检查大页 PPN 低位对齐，也不会在写入时强制把大页 PPN 低位清 0；data 中保存的是完整 PPN 字段。PFU 生成 PA 时按 page size 拼接：4KB 使用完整 PPN；2MB 使用 PPN 高位并用 VA offset 替换低 9 位；1GB 使用 PPN 高位并用 VA offset 替换低 18 位。因此大页 PPN 中被页内偏移覆盖的低位不会影响 PFU 最终 PA。

        7. PTW refill 写入 tag/data 时，ASID 使用 completion 当拍当前 ASID，还是 miss 创建/发 PTW 时的 ASID？
        回答：PTW refill 写入 tag 时使用 PTW refill 生成时看到的当前 `regs_ptw_cur_asid`，也就是当前 SATP ASID，而不是 miss 创建或发 PTW request 时保存下来的 ASID。L2TLB miss buffer/PTW request 中没有单独保存原始 ASID，refill tag 的 ASID 由 PTW/TWU 侧按当前 ASID 打包进 tag。

        8. 如果 miss 创建后 ASID 改变，PTW completion 回填的 ASID 与原请求 ASID 可能不同；这种场景是否合法，UVM 应如何约束或检查？
        回答：如果 miss 创建后、PTW completion/refill 前 ASID 改变，回填 entry 的 ASID 可能变成新的当前 ASID，而 VPN/PPN 来自旧 miss 对应的 page walk，这会造成旧 translation 被错误标到新 ASID 下。该场景不应作为合法软件/系统行为。切换 ASID 或 SATP 时，需要保证旧的 outstanding walk 不会继续以旧上下文回填，或者通过 fence/invalidate/abort/drain 等机制完成同步后再允许新的地址空间使用翻译结果。

        9. TLBR 读取 invalid entry 时返回旧 SRAM 内容；UVM 是否需要检查 TLBR 精确返回这些旧字段，还是只检查 valid/PTE.V 相关字段？
        回答：TLBR 是按 index/way 读取 L2TLB 物理 entry，不因为 tag.valid=0 而屏蔽 VPN/ASID/PGS/G/PPN/flag 字段。它会把被选中 entry 的 tag/data 字段读出并写回 MEH/MEL 可见字段。若该 entry 是由 invalidate 写 0 形成的 invalid entry，则 TLBR 读到的是 0；若存在 tag.valid=0 但其它 SRAM 字段非 0 的旧内容，则 TLBR 可以读出这些旧字段。tag.valid 本身不作为单独字段返回，MEL.V 返回的是 data flag 中的 PTE.V。

        10. RRPV 对 invalid entry 无意义；TLBR 或 debug 观测是否需要返回/检查 invalid entry 的 RRPV？
        回答：RRPV 不是 TLBR 的返回内容，也不是软件可见 entry 内容。invalid entry 的 RRPV 没有功能意义，replacement 选择应优先把 tag.valid=0 的 entry 作为空闲候选；只有在没有可用 invalid entry 时，RRPV 才参与 victim 选择。invalidate 清 tag/data 时不要求同步清 RRPV，后续 RRPV 旧值或变化不影响 invalid entry 的 lookup 结果。

    5.7 lookup、fault 与响应建模
    DUT 行为已答，UVM 策略见 5.13
        1. 普通 ITLB/DTLB L2 hit 后，L2TLB 是否完全不检查 PTE.V/R/W/X/U/A/D，只返回 flag 给 L1？UVM 是否应避免在 L2 scoreboard 中判这些 fault？
        回答：普通 ITLB/DTLB L2 hit 后，L2TLB 不做 PTE.V/R/W/X/U/A/D 权限和有效性 fault 判断。L2TLB 的普通 lookup 命中只由 tag valid、VPN/page size、ASID/global 等条件决定；单命中后返回 PPN、flag、page size、VPN 给 L1。PTE flag 相关 page fault/access fault 由 L1 侧或 PTW/PMP 等后续路径处理。

        2. multi-hit 和 PTW disabled miss 对 L1 都表现为 `pgflt=1`；是否需要内部 coverage 区分二者原因，还是只检查外部 pgflt？
        回答：对 L1 直返响应而言，multi-hit 和 PTW disabled miss 都编码成 page fault 类完成，没有单独的外部原因码。两者都会在对应 ITLB/DTLB 响应上产生 `ref_cmplt=1`、`ref_pavld=0`、`pgflt=1`。内部原因不同：multi-hit 是同一次 compare 命中多个 way；PTW disabled miss 是 miss 且 `cp0_mmu_ptw_en=0`。

        3. L1 ITLB/DTLB 的 `ref_cmplt`、`ref_pavld`、`pgflt` 合法组合有哪些？例如成功是否必须 `cmplt=1,pavld=1,pgflt=0`，fault 是否必须 `cmplt=1,pavld=0,pgflt=1`？
        回答：L2TLB 直返给 L1 ITLB/DTLB 的有效完成主要有两类组合：成功命中为 `ref_cmplt=1, ref_pavld=1, pgflt=0`；multi-hit 或 PTW disabled miss 直返 fault 为 `ref_cmplt=1, ref_pavld=0, pgflt=1`。普通 miss 且 PTW enable 并成功分配 miss buffer 时，L2TLB 当拍不对 L1 拉 `ref_cmplt`。没有完成时通常为 `ref_cmplt=0, ref_pavld=0, pgflt=0`。

        4. L1 response payload `l2tlb_l1tlb_ref_*` 在 fault 或 `ref_pavld=0` 时是否有定义，UVM 是否应忽略？
        回答：当 `ref_pavld=1` 时，`l2tlb_l1tlb_ref_vpn/ppn/flg/pgs` 是有效翻译 payload。当 fault 或 `ref_pavld=0` 时，这些 payload 不作为有效翻译结果使用；它们可能仍由当前流水线的 final stage 组合逻辑给出某些值，但语义上不保证为可消费的 PA/flag。DTLB 的 `l2tlb_l1dtlb_ref_eid` 用于标识返回给哪个 L1 DTLB miss entry，fault 时仍用于关联对应请求。

        5. DTLB load/store fault 在 L2TLB 输出上是否完全相同，只通过原始 type/eid 由 L1 区分？
        回答：L2TLB 对 DTLB load 和 store 的直返 fault 编码相同，都是 DTLB 方向的 `ref_cmplt=1, ref_pavld=0, pgflt=1`。L2TLB 不在输出 fault 信号中单独区分 load fault 或 store fault；请求类型和 `eid` 由 L1 DTLB 自己保存/使用，用于后续与原始 load/store 请求关联。

        6. ITLB 和 DTLB response 如果同拍都可能完成，DUT 是否允许同时拉高 ITLB 和 DTLB completion，还是由于单 pipeline 每拍最多完成一个？
        回答：L2TLB lookup 是单入口、单条 raw/final 流水，每拍最多有一个 final lookup 请求完成。普通 L2TLB 直返响应同一拍只会对应 ITLB 或 DTLB 其中一种请求类型，不会因为同一个 L2TLB lookup 同时拉高 ITLB 和 DTLB completion。PTW completion 到 L1 的后续响应走 PTW 到 L1 的独立端口，不属于 L2TLB 直返 final stage 的同一类输出。

        7. T2 miss 且 miss buffer alloc 成功时，L1 是否当拍没有 `ref_cmplt`，直到 PTW/L1 后续路径完成？L2TLB UVM 是否只检查 MB/PTW request 而不期待 L1 response？
        回答：是。T2 发现 miss、`cp0_mmu_ptw_en=1` 且 miss buffer allocation 成功时，L2TLB 当拍只释放 ReqQ entry 并把 miss 送入 L2 miss buffer/PTW 路径，不对 L1 ITLB/DTLB 产生 `ref_cmplt`。L1 的最终 refill、page fault 或 access error 由后续 PTW 到 L1 的路径完成。

        8. PTW completion 后 L1 ITLB/DTLB 的最终 refill/fault response 是否经过 mmu_l2tlb 端口，还是由 PTW/TWU/L1 模块直接处理？L2TLB UVM 的 scoreboard 边界应在哪里结束？
        回答：PTW completion 后给 L1 ITLB/DTLB 的最终 refill/fault response 由 PTW 直接输出到 L1 ITLB/DTLB 端口，不经过 `mmu_l2tlb` 的 `l2tlb_l1*` 直返端口。`mmu_l2tlb` 会接收 PTW completion 用于释放 L2 miss buffer，并在 data valid 时配合 arbiter 执行 L2TLB refill 写入；但 L1 的最终 completion、pa_vld、pgflt、acc_err 由 PTW/L1 路径处理。

        9. PTW disabled miss 对 L1 是直返 page fault；该 response 与 multi-hit response 的时序是否都在原 lookup 的 T2 当拍产生？
        回答：是。PTW disabled miss 和 multi-hit 都在原 lookup 的 final/T2 当拍产生 L1 直返完成。multi-hit 在 T2 根据 hit sum 判断生成 `pgflt=1`；PTW disabled miss 在 T2 根据 miss 且 `cp0_mmu_ptw_en=0` 生成 `pgflt=1`。两者都是原 lookup 流水的最终阶段响应，不等待 PTW。

        10. 如果 L2TLB lookup request 在 T0 后出现 reset，T1/T2 response 是否被清除，还是 reset 行为未定义？
        回答：`cpurst_b` 拉低会异步清除 L2TLB raw/final 流水 valid 和相关寄存器状态。因此如果 T0 后、T1/T2 响应前发生 reset，尚未完成的 lookup 响应会被取消，不应再产生有效 L1 completion、miss buffer allocation 或 PFU response。reset 释放后需要按 reset 初始化流程重新开始新的请求。

    5.8 PFU 专用行为
    DUT 行为已答，UVM 策略见 5.13
        1. PFU `lsu_mmu_va2_vld` 在 `prefetch_mask=1` 期间是否必须保持同一个 VA 不变？如果 LSU 改变 VA，DUT 是忽略新 VA、覆盖旧 VA，还是属于非法输入？
        回答：在一个请求未取得结果前，pfu会一直保持一个请求，你说的情况不存在。
            `prefetch_mask=1` 表示前一笔 MMU-on PFU 请求已经被接受，但结果还没有返回。已经进入 lookup 流水的请求使用被接受当拍的 VA，后续 `lsu_mmu_va2` 的变化不会覆盖这笔在途请求，也不会在 `prefetch_mask=1` 期间再次获得 PFU grant。
              因此，在 mask 期间改变 VA 对当前在途请求等价于“不被接受”。等 `prefetch_mask` 因 `mmu_lsu_pa2_vld`、`mmu_lsu_pa2_err` 或 miss-buffer-full replay 条件清除后，如果 `lsu_mmu_va2_vld` 仍为 1，当前 VA 可能作为下一笔 PFU 请求重新参与仲裁。对单笔请求语义来说，上游应保持 VA 到响应或 replay 边界，避免把尚未撤销的新 VA 误当成下一笔预取请求。
        2. PFU output error 时 `mmu_lsu_pa2_vld` 是否总是同时为 1？还是 `mmu_lsu_pa2_err` 可单独 pulse？
        回答：`mmu_lsu_pa2_err` 不会单独 pulse。PFU error 对应 PFU_DENY 状态，该状态下 `mmu_lsu_pa2_vld=1` 且 `mmu_lsu_pa2_err=1` 同拍有效。PFU_OK 状态下 `mmu_lsu_pa2_vld=1` 且 `mmu_lsu_pa2_err=0`。也就是说，`pa2_err=1` 必然伴随 `pa2_vld=1`。
        3. PFU fault/error 时 `mmu_lsu_pa2`、`mmu_lsu_sec2`、`mmu_lsu_share2` 是否有定义，UVM 是否应忽略？
        回答：这些字段在 PFU completion 被接受时会锁存，因此 error 响应同拍也会有稳定输出值；MMU-off 时 PA 来自 `lsu_mmu_va2`，MMU-on 命中时 PA 来自命中的 PPN 与 VA offset 拼接，security/share 来自 sysmap 或 entry attribute。
              但当 `mmu_lsu_pa2_err=1` 时，这些字段不表示一笔可使用的成功翻译结果，使用方应以 error 为准，不应把 `mmu_lsu_pa2/mmu_lsu_sec2/mmu_lsu_share2` 当作有效 translation 属性消费。`mmu_lsu_pa2_vld=0` 时这些字段只是上一次锁存值或 reset 后初值，也没有新响应含义。
        4. PFU MMU-off direct path 的精确时序是什么？`lsu_mmu_va2_vld && l1dtlb_xx_mmu_off` 后几拍输出 `mmu_lsu_pa2_vld`？
        回答：在 PFU idle 时，`lsu_mmu_va2_vld && l1dtlb_xx_mmu_off` 当拍形成 direct completion，并在该拍时钟沿锁存 PA/security/share。若 sysmap 属性立即判为 fault，即 `sysmap_mmu_flg4[4]=1` 或 `sysmap_mmu_flg4[3]=0`，下一拍进入 PFU_DENY，输出 `mmu_lsu_pa2_vld=1`、`mmu_lsu_pa2_err=1`。
              若 sysmap 不报 fault，则下一拍进入 PFU_CHK，用锁存 PA 等待 PMP 返回判断，再下一拍进入 PFU_OK 或 PFU_DENY。因此无 sysmap fault 的 MMU-off direct path 在请求后第 2 拍输出 `mmu_lsu_pa2_vld`；PMP allow 时 `pa2_err=0`，PMP deny 时 `pa2_err=1`。如果 PFU 当前不在 idle，该 direct 请求不应视为被正常接受。
        5. PFU MMU-off direct path 是否使用 `prefetch_mask`，还是完全绕过 arbiter/mask？
        回答：MMU-off direct path 绕过 PFU arbiter grant 和 `prefetch_mask`。MMU-on PFU lookup 需要通过 arbiter，且受 `prefetch_mask` 阻塞；MMU-off 时不会发起 L2TLB lookup，而是直接用 `lsu_mmu_va2` 作为 PA 来源进入 PFU completion/PMP check 流程。因此 `prefetch_mask` 不限制 MMU-off direct path。
        6. `pmp_mmu_flg4[3:0]` 每一 bit 的含义是什么？PFU read/prefetch 检查时哪些组合表示 allow、deny、lock、access fault？
        回答：`pmp_mmu_flg4[3:0]` 对应 PMP entry 的 `{L, X, W, R}`：bit0 为 read permission，bit1 为 write permission，bit2 为 execute permission，bit3 为 lock bit。PFU 是 read/prefetch 检查，只使用 bit0 和 bit3；bit1/bit2 不参与 PFU deny 判定。
              对 U/S effective privilege，`R=1` 表示 PMP allow，`R=0` 表示 PMP deny，PFU 返回 `mmu_lsu_pa2_vld=1` 且 `mmu_lsu_pa2_err=1`。对 M effective privilege，若 `R=0 && L=0`，M-mode lock 规则放行；若 `R=0 && L=1`，仍然 deny；`R=1` 时无论 L 为何都 allow。PMP deny 在 PFU 输出上表现为 access-error 类 `pa2_err`。
        7. `sysmap_mmu_flg4[4:0]` 每一 bit 的含义是什么？MAEE=0 时如何从 sysmap 生成 security/share/cacheable/bufferable/strong-order 和 fault？
        回答：`sysmap_mmu_flg4[4:0]` 的属性顺序是 `{SO, C, B, Share, Sec}`：bit4 为 strong-order，bit3 为 cacheable，bit2 为 bufferable，bit1 为 shareable，bit0 为 security。
              当 MAEE=0 时，PFU 的 security/share 输出分别来自 `sysmap_mmu_flg4[0]` 和 `sysmap_mmu_flg4[1]`；cacheable、bufferable、strong-order 作为 sysmap 属性使用，其中 PFU fault 条件只检查 `SO=1` 或 `C=0`。也就是说，`sysmap_mmu_flg4[4]=1` 或 `sysmap_mmu_flg4[3]=0` 会使 PFU 走 error；bit2 bufferable 不单独触发 PFU error。MMU-off direct path 也采用同一组 sysmap 属性检查。
        8. PFU flag fault 的完整 truth table 是什么？需要明确 V/R/W/X/U/A/D、SUM、MXR、MPRV、MPP、priv mode、MAEE 如何共同决定 `pa2_err`。
        回答：PFU hit 的 flag fault 可按“任一条件为真即 fault”定义：
              1. `V=0`。
              2. `W=1 && R=0`，属于非法权限组合。
              3. `R=0 && !(MXR && X=1)`，即不可读，且不能通过 MXR 把可执行页当作可读页。
              4. effective privilege 为 S，且 `U=1 && SUM=0`。
              5. effective privilege 为 U，且 `U=0`。
              6. `A=0`。
              7. MAEE=1 时，entry attribute 中 `SO=1` 或 `C=0`。
              8. MAEE=0 时，sysmap attribute 中 `SO=1` 或 `C=0`。
              effective privilege 由 `MPRV ? MPP : current privilege` 决定。M effective privilege 不触发第 4/5 条 U/S 页权限 fault，但仍要满足 V/R/W/X/A 与 memory attribute 条件。`D` 位不参与 PFU read/prefetch 的 flag fault 判定。若上述 flag fault 不成立，PFU 还会继续做 PMP check；PMP deny 仍会使最终 `pa2_err=1`。
        9. PFU hit 后进入 PMP check 的场景中，如果同拍又有 TLB operation invalidate 清除了该 entry，PFU 是否仍按已锁存的 PPN/flag 完成？
        回答：PFU hit completion 一旦形成，会把用于 PMP check 和响应的 PA/security/share 锁存到 PFU buffer，后续 PFU_CHK/PFU_OK/PFU_DENY 使用这个已锁存结果完成。TLB operation invalidate 对 entry 的清除影响后续 lookup，不回滚已经形成 completion 并进入 PFU check 的在途 PFU 响应。
              如果 invalidate 在该 PFU lookup 形成 hit 之前已经使 entry 无效，则该请求不会按旧 entry 命中；如果 hit 已经在流水末级形成，则该笔响应按已锁存结果自然完成。
        10. PFU miss 进入 PTW 后，如果 PTW 返回 data_vld，PFU 输出使用 PTW 返回 flag 还是写入 L2TLB 后再查一次？
        回答：PFU miss 的完成由 PTW completion 直接触发，不需要先写入 L2TLB 后再发起一次 lookup。`ptw_l2tlb_ref_cmplt` 且返回类型为 PFU miss 时，会作为 PFU completion 来源；error 判定使用 PTW completion 携带的 `ptw_l2tlb_ref_flg` 中的 memory attribute，以及 `ptw_l2tlb_ref_pgflt`、`ptw_l2tlb_ref_acc_err`。
              对 PTW 返回的正常 `data_vld`，如果没有 PTW page fault/access error，且返回属性不满足 `SO=1` 或 `C=0`，PFU 进入 PMP check，随后输出 OK 或 DENY。该路径不会通过“refill 后二次查表”来重新执行完整的 PFU hit flag check。

    5.9 PTW、miss buffer 与 abort
    DUT 行为已答，UVM 策略见 5.13
        1. `l2tlb_ptw_req` 与 `ptw_ready` 的握手是 valid/ready 协议还是只在 ready 为 1 时 pulse？`l2tlb_ptw_*` payload 是否需要在未 ready 时保持？
        回答：这是 level valid/ready 语义，不是只在 `ptw_ready=1` 时才 pulse。L2 miss buffer 中只要存在 valid 且未 sent 的 entry，或当拍新 miss 可以分配，就可以拉高 `l2tlb_ptw_req`。真正把 entry 标记为 sent 的接受边界是 `l2tlb_ptw_req && ptw_ready`。
              当 `ptw_ready=0` 时，未 sent entry 保持 valid/rdy，`l2tlb_ptw_req` 可以持续为 1，`l2tlb_ptw_vpn/type/id` 必须保持为当前被选择的那笔 miss。若当拍新 miss 在 `ptw_ready=0` 时不能 bypass 接收，它会先写入 miss buffer，后续作为 stored entry 继续发给 PTW。
        2. PTW completion `ptw_l2tlb_ref_cmplt`、`ref_data_vld`、`ref_pgflt`、`ref_acc_err` 的合法组合是什么？是否互斥？
        回答：`ptw_l2tlb_ref_cmplt` 是三类完成的 OR：正常 data/refill、page fault、access error。合法组合为：
              `cmplt=0, data_vld=0, pgflt=0, acc_err=0`：没有完成。
              `cmplt=1, data_vld=1, pgflt=0, acc_err=0`：正常 walk 完成，有可 refill 的 translation data。
              `cmplt=1, data_vld=0, pgflt=1, acc_err=0`：page fault 完成。
              `cmplt=1, data_vld=0, pgflt=0, acc_err=1`：access error 完成。
              三个 completion class 互斥；同一拍不应出现 data_vld、pgflt、acc_err 多个同时为 1。任一完成都携带对应的 `type/id`，用于定位 L2 miss buffer entry 以及原始 L1/PFU 请求。
        3. PTW completion 可以乱序返回吗？如果可以，是否完全依赖 L2 MB entry id 匹配？
        回答：可以乱序返回。L2 miss buffer 允许多个 entry 已经 sent 到 PTW，PTW 内部不同 walk、fault 或 refill 路径完成的顺序不要求等于 issue 顺序。返回时以 composite id 为准，其中高位是 L2 miss buffer entry id，低位是 L1 DTLB miss entry id 或固定 0。
              L2 miss buffer 使用返回 id 的高位匹配并释放对应 entry；L1 侧使用返回 id/type 关联原始 miss。completion 的顺序本身不提供匹配语义，id 才是匹配依据。
        4. PTW completion id 如果没有命中任何 valid miss buffer entry，DUT 应忽略、报错、还是该场景非法？
        回答：这是非法 completion 场景。L2 miss buffer 只会对返回 id 命中的 valid entry 做 deallocation；如果没有任何 valid entry 匹配，该 completion 不会释放 L2 miss buffer 中的正常 entry。
              但 completion 本身仍可能在 PTW 到 L1/L2 的可见路径上形成 fault、refill 或 PFU 完成信号，因此不能把这种场景定义成安全 ignore。系统语义要求 PTW 只返回曾经由 L2 miss buffer issue 出去、且尚未完成或 abort 清理掉的 id。
        5. PTW completion 返回 fault 时是否一定不发起 L2TLB tag/data/RRPV refill write？
        回答：是。page fault 或 access error completion 不携带可 refill 的 translation data，也不会发起 L2TLB tag/data/RRPV refill 写。fault completion 只用于通知对应 L1/PFU 路径并释放 L2 miss buffer entry。
              只有正常 data/refill completion 才会进入 PTW refill arbitration，并在被 L2TLB 接收后触发后续 tag/data/RRPV 写入流程。
        6. PTW completion 正常 data_vld 但 RRPV write buffer full 导致 PTW read 无法 grant 时，PTW 是否必须保持 completion/refill request 直到被 L2TLB 接收？
        回答：正常 data/refill completion 在 L2TLB 接收之前不会对外拉 `ptw_l2tlb_ref_data_vld`。当 RRPV write buffer full 或 TLB operation 阻塞 PTW refill 时，PTW refill request 会被 mask，内部保存的 refill payload 保持等待；此时没有正常 data completion 对外发生。
              等阻塞解除并获得 `arb_ptw_grant` 后，`ptw_l2tlb_ref_data_vld` 才拉高，同拍表示这笔 refill 被 L2TLB 接收。也就是说，data_vld 是接受点上的完成脉冲，不是“先报 completion、再等待 L2TLB 接收”的两阶段协议。
        7. miss buffer allocation 与 PTW completion deallocation 同拍且指向同一个 entry 时，优先级如何定义？
        回答：合法流程下，同一个 valid entry 在 completion 当拍不会同时被重新分配。allocation 选择空 entry 时使用当前拍的 valid 状态；正在 deallocation 的 entry 在该拍开始时仍然是 valid，因此不会被当作空 entry 分配，新 allocation 要到下一拍才能使用这个刚释放的位置。
              allocation 和 deallocation 同拍但指向不同 entry 时可以并行发生：一个 entry 被 completion 释放，另一个空 entry 接收新 miss。若一个无效或非法 completion id 与当拍新 allocation 指向同一 entry 冲突，该 completion 本身属于非法输入组合，不定义为正常仲裁优先级。
        8. miss buffer full 是否按来源分别判断：ITLB 只看 entry0，DTLB/PFU 只看 entry1-entry8？
        回答：是。L2 miss buffer entry0 专用于 ITLB/fetch miss；entry1-entry8 由 DTLB load/store miss 和 PFU miss 共用。ITLB miss 只在 entry0 当前 invalid 时可以分配；DTLB/PFU miss 只在 entry1-entry8 中至少有一个 invalid entry 时可以分配。
              因此 full 判断按来源分开：entry0 valid 会阻塞新的 ITLB miss allocation；entry1-entry8 全 valid 会阻塞新的 DTLB/PFU miss allocation。DTLB/PFU 不会借用 entry0，ITLB 也不会借用 entry1-entry8。
        9. PFU 与 DTLB 共用 MB entry1-entry8；如果 PFU miss 和 DTLB miss 不可能同拍进入 MB，这个“不可能”是否依赖单 T2 pipeline，UVM 是否需要断言每拍最多一个 alloc？
        回答：PFU miss 和 DTLB miss 不会同拍从 L2TLB final stage 同时进入 L2 miss buffer。L2TLB lookup 是单入口、单条 raw/final 流水；每个 final 周期最多只有一笔 lookup 请求完成，并且该请求的 type 只能是 ITLB、DTLB 或 PFU 中的一种。
              因此 L2 miss buffer 每拍最多接收一笔由 lookup miss 产生的 allocation。它可以在同一拍处理一笔 PTW completion deallocation，但不会同拍接收 PFU 和 DTLB 两笔新的 allocation。
        10. `tlboper_ptw_abort` 只清 sent 不清 valid；abort 后所有 valid entry 是否都会重新 issue PTW？还是只重发已 sent 的 entry？
        回答：`tlboper_ptw_abort` 对 L2 miss buffer 是全局 sent 清除，不清 valid 和 payload。abort 后，所有仍 valid 的 entry 都会变成 not-sent/ready 状态；之前已经 sent 的 entry 会被重发，之前尚未 sent 的 entry 保持待发状态，并和其它 ready entry 一起按 miss buffer issue 优先级重新发给 PTW。
              因此 abort 不区分“已 sent entry”和“未 sent entry”来选择性保留 ready 状态。只要 entry valid，abort 后它就是后续 PTW issue 的候选。
        11. abort 对未 sent 的 miss buffer entry 是否有任何影响？
        回答：对未 sent entry，abort 不改变 valid、VPN、type、L1EID 等 payload；它本来就是 ready，abort 后仍然 ready。唯一统一执行的动作是把 sent 位清 0，而未 sent entry 的 sent 位本来就是 0，所以功能上没有额外变化。
              abort 同时会清 PTW 内部正在处理的 walk/refill/fault 状态，防止旧 walk 继续完成；但 L2 miss buffer 中尚未发出的 entry 会继续保留，等待后续重新 issue。
        12. LSU invalidate abort PTW 后，miss buffer entry 保留并重新 issue，会重新 page walk 旧 VPN/ASID；这是期望行为吗？如何保证不会回填 invalidate 前的旧 translation？
        回答：这是期望行为。L2 miss buffer 保存的是仍然需要完成的 miss 请求上下文；LSU invalidate 触发 abort 时，不是丢弃这些 miss，而是取消已经在 PTW 内部推进的旧 walk/refill，再把 L2 miss buffer 中仍 valid 的 entry 重新发起 walk。
              防止旧 translation 回填依赖两点：第一，abort 会清 PTW/TWU 中的在途 valid、pending refill、page/access fault 以及 PTW 内部访存缓冲状态，使 invalidate 前已经取得或正在等待的页表结果不再继续提交；第二，TLB invalidate 本身会清除目标 L1/L2 entry，后续从 L2 miss buffer 重发的 walk 必须重新经过页表读取和权限/属性检查，得到的是 abort 之后的新完成结果。
              L2 miss buffer entry 本身只保存 VPN/type/L1EID，不保存 ASID。PTW refill 使用当前地址空间相关寄存器生成 tag。因此在有 outstanding miss 时切换 ASID、页表根或相关上下文，需要由软件/系统流程保证安全边界；否则不能依赖 L2 miss buffer 自动区分旧 ASID 请求。
        13. 同一 VPN/ASID/type 多个 miss 不 merge；如果第一笔 PTW completion 已 refill L2TLB，后续重复 miss buffer entry 是否仍会发 PTW，还是有机会重新 lookup L2TLB？
        回答：已经进入 L2 miss buffer 的重复 entry 不会因为另一笔 completion 已经 refill L2TLB 而自动重新 lookup。miss buffer entry 的后续动作是按保存的 VPN/type/id 发给 PTW；没有“发 PTW 前先重新查一次 L2TLB，若命中则直接完成”的机制。
              因此多个相同 VPN/type 的 miss 如果都已经分配到 L2 miss buffer，后续会分别 issue 到 PTW，分别等待 completion。只有尚未进入 miss buffer、因 miss buffer full 等原因保留在 ReqQ 中 replay 的请求，后续重新走 L2TLB lookup 时才可能命中新 refill 的 entry。
        14. miss buffer 发 PTW 后，原 ReqQ entry 已释放；如果后续 PTW abort/retry，该请求最终如何通知原 L1，还是由 PTW/L1 miss buffer 自己保持上下文？
        回答：原 ReqQ entry 在 miss 成功分配到 L2 miss buffer 后即可释放；后续完成不再依赖 ReqQ。L2 miss buffer entry 保存 VPN、type 和原始 L1EID，并在 issue PTW 时生成 composite id。PTW completion 返回同一个 type/id，L2 miss buffer 用高位 L2 entry id 释放 entry，L1 DTLB 用低位 L1EID 关联原始 miss；ITLB 请求低位 id 固定为 0。
              如果发生 abort，L2 miss buffer 保留 entry 并清 sent，之后用同一 payload/id 重新 issue。原 L1 miss 仍由 L1 侧自己的等待状态或 miss entry 保持，直到 PTW 最终返回 refill、page fault 或 access error completion。ReqQ 不参与 abort 后的重试和最终通知。

    5.10 TLB operation 详细接口
    DUT 行为已答，UVM 策略见 5.13.6
        1. TLB operation 相关但未列入 signal table 的信号需要补全吗？例如 `tlboper_arb_req`、`tlboper_arb_idx`、`tlboper_arb_bank_sel`、`tlboper_arb_cmp_va`、`tlboper_arb_idx_not_va`、`arb_tlboper_grant`、`tlboper_xx_cmplt`。
        回答：需要补全。以下方向按 TLB operation 控制单元视角描述，进入控制单元为输入，由控制单元发出为输出；与 L2TLB 交互的反馈另行注明。
            LSU 来源请求输入：
                lsu_mmu_tlb_all_inv，1bit，LSU 发起全清请求。
                lsu_mmu_tlb_asid_all_inv，1bit，LSU 发起按 ASID 清除请求。
                lsu_mmu_tlb_va_all_inv，1bit，LSU 发起按 VA 清除、忽略 ASID 的请求。
                lsu_mmu_tlb_va_asid_inv，1bit，LSU 发起按 VA 和 ASID 清除的请求。
                lsu_mmu_tlb_asid[15:0]，目标 ASID，用于 LSU 的 ASID 类或 VA+ASID 类清除。
                lsu_mmu_tlb_va[26:0]，目标 VPN，用于 LSU 的 VA 类清除，同时送给 L1 侧按低 8 位匹配。
            寄存器来源请求输入：
                regs_tlboper_invall，1bit，寄存器侧全清请求。
                regs_tlboper_invasid，1bit，寄存器侧按 ASID 清除请求。
                regs_tlboper_tlbp，1bit，按当前 MEH 内容查找并更新 MIR 的请求。
                regs_tlboper_tlbr，1bit，按 MIR 指定位置读取并回填 MEH/MEL 的请求。
                regs_tlboper_tlbwi，1bit，按 MIR 指定位置写入 MEH/MEL 内容的请求。
                regs_tlboper_tlbwr，1bit，按当前 VPN 候选位置选择 victim way 后写入 MEH/MEL 内容的请求。
                regs_tlboper_inv_asid[15:0]，寄存器侧 INVASID 的目标 ASID。
                regs_tlboper_cur_asid[15:0]，MEH 中的 ASID，用于 TLBP、TLBWI、TLBWR 和寄存器侧 VA 比较。
                regs_tlboper_cur_pgs[2:0]，MEH 中的 page size，写入新 entry，并作为 TLBP 命中索引相关的页大小上下文。
                regs_tlboper_cur_vpn[26:0]，MEH 中的 VPN，用于 TLBP、TLBWI、TLBWR。
                regs_tlboper_mir[11:0]，MIR 中的索引；[10:8] 选择 way，[7:0] 选择 set。
                regs_jtlb_cur_ppn[27:0]，MEL 中的 PPN，TLBWI/TLBWR 写入 data。
                regs_jtlb_cur_flg[13:0]，MEL 中的属性和权限，TLBWI/TLBWR 写入 data。
                regs_jtlb_cur_g，MEL 中的 global 位，TLBWI/TLBWR 写入 tag。
            CP0 来源请求输入：
                cp0_mmu_tlb_all_inv，1bit，CP0 侧全清请求，走 INVALL 流程。
            仲裁请求输出：
                tlboper_arb_req，1bit，向仲裁发起一次访问请求；单拍操作保持到 grant，多拍操作每个 beat 单独保持到 grant。
                tlboper_arb_write，1bit，本 beat 是否为写访问。TLBWI、TLBWR 写阶段、INVASID 写阶段、INVALL、INVVA 写阶段为 1。
                tlboper_arb_vpn[26:0]，本 beat 使用的 VPN。INVVA 类来自 lsu_mmu_tlb_va，其余来自 regs_tlboper_cur_vpn。
                tlboper_arb_idx[10:0]，索引类 beat 使用的索引。INVASID/INVALL 来自扫描计数器，其余索引类操作来自 regs_tlboper_mir。
                tlboper_arb_idx_not_va，1bit，索引模式选择。TLBR、TLBWI、INVASID、INVALL 为 1，表示使用 tlboper_arb_idx[7:0] 作为各 way 的 set index。
                tlboper_arb_cmp_va，1bit，是否按 VA/VPN 做比较。TLBP 和 INVVA 读阶段为 1。
                tlboper_arb_bank_sel[7:0]，本 beat 访问的 way mask。TLBP、INVALL、INVVA 读阶段、INVASID 读阶段、TLBWR victim 读阶段访问 8 个 way；TLBR/TLBWI 使用 MIR[10:8] 指定的单 way；TLBWR 写阶段使用 victim way；INVVA/INVASID 写阶段使用命中的 way mask。
                tlboper_arb_tag_din[47:0]，写入 tag 的数据。TLBWI/TLBWR 写阶段包含 valid、VPN、ASID、page size、global；清除类写阶段为 0，用于清 valid。
                tlboper_arb_data_din[41:0]，写入 data 的数据。TLBWI/TLBWR 写阶段包含 PPN 和 flag；清除类写阶段为 0。
            仲裁反馈输入：
                arb_tlboper_grant，1bit，仲裁接受当前 tlboper_arb_* beat。该拍之后控制单元进入等待完成或下一 beat。
                arb_top_tlboper_on，1bit，仲裁侧 TLB operation busy 状态，从首次 grant 后保持到 tlboper_xx_cmplt。
            L2TLB 直接控制输出：
                tlboper_l2tlb_asid[15:0]，VA 比较使用的 ASID。INVVA 类来自 lsu_mmu_tlb_asid，TLBP 来自 regs_tlboper_cur_asid。
                tlboper_l2tlb_asid_sel，1bit，选择 TLB operation 专用 ASID 参与 VA 比较。TLBP 和 INVVA 流程中有效。
                tlboper_l2tlb_cmp_noasid，1bit，VA 清除且忽略 ASID 时有效；此时 VA 命中不要求 ASID 匹配。
                tlboper_l2tlb_inv_asid[15:0]，INVASID 扫描比较使用的目标 ASID；寄存器来源使用 regs_tlboper_inv_asid，LSU 来源使用 lsu_mmu_tlb_asid。
                tlboper_l2tlb_tlbwr_on，1bit，TLBWR 流程有效，用于 L2TLB 在反馈 way mask 时选择 victim way。
                tlboper_l2tlb_invasid_on，1bit，INVASID 流程有效，用于 L2TLB 在反馈 way mask 时选择 ASID 命中 way。
                tlboper_xx_pgs[2:0]，当前操作页大小上下文，来自 regs_tlboper_cur_pgs。
            L2TLB 反馈输入：
                l2tlb_tlboper_cmplt，1bit，L2TLB 对一次 TLB operation beat 的流水完成反馈。
                l2tlb_tlboper_va_hit，1bit，INVVA/TLBP 类 VA 比较存在命中 way。
                l2tlb_tlboper_asid_hit，1bit，INVASID 扫描当前 set 存在 ASID 命中 way。
                l2tlb_tlboper_sel[7:0]，反馈给写阶段使用的 way mask。TLBWR 时为 victim way，INVASID 时为 ASID hit way，INVVA 时为 VA hit way。
                l2tlb_regs_hit，1bit，TLBP 单命中结果。
                l2tlb_regs_hit_mult，1bit，TLBP 多命中结果。
                l2tlb_regs_tlbp_hit_index[10:0]，TLBP 命中时回写 MIR 的索引，格式为 way[2:0] 加 set[7:0]。
                l2tlb_tlbr_vpn[26:0]、l2tlb_tlbr_pgs[2:0]、l2tlb_tlbr_asid[15:0]、l2tlb_tlbr_ppn[27:0]、l2tlb_tlbr_flg[13:0]、l2tlb_tlbr_g，TLBR 读出的 entry 内容，用于回填 MEH/MEL。
            一级缓存清除和 PTW 控制输出：
                tlboper_utlb_clr，1bit，TLBWI、TLBWR、INVASID、INVALL 过程中清 L1 ITLB、L1 DTLB 和相关 uTLB。
                tlboper_utlb_inv_va_req，1bit，INVVA 过程中按 VA 清 L1 侧 entry。
                tlboper_ptw_abort，1bit，LSU 来源 invalidate 新启动时发出，用于取消正在推进的 page walk，并让 miss buffer 中仍有效的请求后续重发。
            完成与状态输出：
                tlboper_xx_cmplt，1bit，所有 TLB operation 的统一完成脉冲。
                tlboper_regs_cmplt，1bit，寄存器来源操作完成脉冲，LSU 来源操作不拉高该信号。
                tlboper_regs_tlbp_cmplt，1bit，TLBP 完成并允许 MIR 更新。
                tlboper_regs_tlbr_cmplt，1bit，TLBR 完成并允许 MEH/MEL 更新。
                mmu_lsu_tlb_inv_done，1bit，LSU 来源 invalidate 的最终完成脉冲。
                mmu_cp0_tlb_done，1bit，CP0 全清请求完成脉冲。
                tlboper_top_tlbp_cur_st[1:0]、tlboper_top_tlbr_cur_st[1:0]、tlboper_top_tlbwi_cur_st[1:0]、tlboper_top_tlbwr_cur_st[1:0]、tlboper_top_tlbiasid_cur_st[2:0]、tlboper_top_tlbiall_cur_st、tlboper_top_tlbiva_cur_st[3:0]，各子流程当前状态。
                tlboper_top_lsu_oper，1bit，当前操作归属 LSU 来源。
                tlboper_top_lsu_cmplt，1bit，LSU 来源操作完成状态脉冲。
        2. UVM 应通过寄存器抽象层驱动 MEH/MEL/MIR/MCIR/LSU invalidate，还是直接驱动 tlboper_l2tlb/tlboper_arb 低层接口？
        回答：完整 MMU UVM 默认应通过真实顶层 CP0/CSR/LSU invalidate 接口驱动 TLB operation，不直接驱动 `tlboper_l2tlb_*` 或 `tlboper_arb_*` 低层接口；低层信号作为 monitor/checker 观察点。详见 5.13.6。
        3. 多个 TLB operation 来源同拍有效时（LSU invalidate、MCIR、cp0_mmu_tlb_all_inv），优先级和互斥规则是什么？
        回答：功能语义上同一时刻只应启动一个新的 TLB operation。控制单元空闲时，LSU 来源 invalidate 优先于寄存器来源操作；寄存器来源的 TLBP、TLBR、TLBWI、TLBWR、INVASID、INVALL 在 LSU invalidate 正在启动或执行时不应被采纳。CP0 直接全清和 LSU 全清都走 INVALL 流程；若与 LSU 全清同拍出现，实际执行的是同一个全清扫描，完成时 LSU done 和 CP0 done 都可能看到完成脉冲。寄存器侧 MCIR 的命令位按字段互斥使用，若写入值同时置多个命令位，优先关系为 INVALL 高于 INVASID，高于 TLBP，高于 TLBWI，高于 TLBWR，高于 TLBR。
        4. TLBP/TLBR/TLBWI/TLBWR/INVASID/INVALL/INVVA 每个 operation 的 request、grant、cmplt、done pulse 宽度分别是多少？
        回答：request 是 level 语义，当前 beat 未被 grant 前保持有效；grant 是仲裁接受该 beat 的 1 拍脉冲；l2tlb_tlboper_cmplt 是每个已接受 beat 在 L2TLB 完成阶段产生的 1 拍脉冲；tlboper_xx_cmplt、tlboper_regs_cmplt、mmu_lsu_tlb_inv_done、mmu_cp0_tlb_done 都是最终完成 1 拍脉冲。
            TLBP：1 个读 request beat，grant 后等待 1 次 l2tlb_tlboper_cmplt，随后产生 1 次最终完成。TLBP 命中、多命中和命中索引在该完成点更新到 MIR 相关路径。
            TLBR：1 个索引读 request beat，grant 后等待 1 次 l2tlb_tlboper_cmplt，随后产生 1 次最终完成，并用读出的 entry 回填 MEH/MEL。
            TLBWI：1 个索引写 request beat，grant 后等待 1 次 l2tlb_tlboper_cmplt，随后产生 1 次最终完成。
            TLBWR：先发 1 个 victim 读 request beat，grant 后等待第 1 次 l2tlb_tlboper_cmplt；随后发 1 个写 request beat，grant 后等待第 2 次 l2tlb_tlboper_cmplt；最终完成只产生 1 次。
            INVASID：对 256 个 set 扫描。每个 set 先发读 request beat；读完成后若当前 set 有 ASID 命中，再发写 request beat 清除命中 way；若无命中，则没有写 beat。最后一个 set 处理完后产生 1 次最终完成。
            INVALL：对 256 个 set 直接发写 request beat，每个 set 1 个写 beat，8 个 way 同时选择；每个写 beat 仍会在 L2TLB 完成阶段产生 1 次 l2tlb_tlboper_cmplt。最终完成由最后一个 set 的写 grant 触发，产生 1 次。
            INVVA：先发 1 个按 VA 比较的读 request beat；若读完成后 VA 命中，再发 1 个写 request beat 清除命中 way，并等待写完成；若未命中，则不发写 beat。最终完成只产生 1 次。
        5. `tlboper_utlb_clr`、`tlboper_utlb_inv_va_req`、`mmu_lsu_tlb_inv_done`、`mmu_cp0_tlb_done`、`tlboper_regs_cmplt` 是否都属于 L2TLB UVM 必须监控的可见结果？
        回答：这些信号的功能含义如下。tlboper_utlb_clr 表示清 L1 ITLB、L1 DTLB 和相关 uTLB，TLBWI、TLBWR、INVASID、INVALL 的请求阶段会拉高。tlboper_utlb_inv_va_req 表示按 lsu_mmu_tlb_va 清 L1 侧匹配 entry，INVVA 的读请求和写请求阶段会拉高。mmu_lsu_tlb_inv_done 是 LSU 来源 invalidate 的最终完成。mmu_cp0_tlb_done 是 CP0 全清流程完成。tlboper_regs_cmplt 是寄存器来源操作完成，不覆盖 LSU 来源操作。tlboper_xx_cmplt 是所有来源共用的内部完成汇总。
        6. `tlboper_utlb_inv_va_req` 按 VA 清 L1 时，发送给 L1 的 VA/ASID payload 是什么？spec 只提到 L1 实际比较 VA/VPN 低 8 位，UVM 是否需要检查该低 8 位行为？
        回答：按 VA 清 L1 时，随 tlboper_utlb_inv_va_req 一起使用的地址 payload 是 lsu_mmu_tlb_va[26:0]，没有单独送 ASID payload 到 L1。L1 ITLB、L1 DTLB 和 uTLB entry 使用 lsu_mmu_tlb_va[7:0] 与本地保存的 VPN 低 8 位比较，匹配则清除。VA_ALL 和 VA_ASID 两类 LSU 请求在 L1 侧清除行为相同，都不做 ASID 精确区分；ASID 条件只影响 L2TLB 的 VA 命中判断。
        7. TLBWI/TLBWR 写非法 page size、非法 PTE flag、未对齐大页 PPN 时不拦截；TLBP/lookup 后续遇到这些 entry 的预期行为是否只由 tag.pgs/flag check 自然决定？
        回答：TLBWI/TLBWR 写入时不对 page size、flag 或大页 PPN 对齐做前置拦截，也不修正字段。后续 TLBP 或普通 lookup 是否命中，由 valid、VPN、page size、ASID/global 的比较自然决定；非法 page size 通常无法匹配合法候选页大小。若 entry 命中，flag 按后续权限、属性检查使用；PPN 也按已保存值参与物理地址形成，不自动按大页边界清零或对齐。
        8. INVVA_ASID 当前会清 global entry；这个行为是否是正式架构语义，还是当前实现行为但需要在 spec 中特别标注？
        回答：当前接口语义下，INVVA_ASID 会清除 VA 命中的 global entry。原因是 VA 比较中 global entry 可绕过 ASID 匹配；VA_ASID 请求没有启用忽略 ASID，但 global 位仍使该 entry 满足命中条件。该行为需要在规格中特别标注：INVASID 扫描会保留 global entry，而 INVVA_ASID 会清除同 VA 的 global entry。
        9. TLBWR 读 victim 阶段是否会产生 `l2tlb_tlboper_cmplt`，写阶段也产生一次 `l2tlb_tlboper_cmplt`？UVM 是否应看到两个内部完成但只有一个最终 operation done？
        回答：TLBWR 有两个 L2TLB beat。第一个 beat 是 victim 读，完成时产生一次 l2tlb_tlboper_cmplt，用于推进到写阶段并取得 victim way。第二个 beat 是写入 victim way，完成时再产生一次 l2tlb_tlboper_cmplt。最终 operation done 只在第二个 beat 完成后产生一次。
        10. INVASID 某个 set 没有 ASID hit 时，是否仍产生一次 read 完成但没有 write beat？coverage/checker 是否需要区分 NWT 和 WT？
        回答：某个 set 没有 ASID hit 时，仍然有读 request、读 grant 和一次 l2tlb_tlboper_cmplt；随后进入 no-write 路径，不产生写 request beat。某个 set 有 ASID hit 时，读完成后进入 write 路径，并用 ASID hit way mask 发起写清除。功能上需要区分“读完成但无写”和“读完成后有写”两种结果，因为它们对应的 L2TLB 修改行为不同。
        11. INVALL 是直接写无效不读 compare；是否每个 set 只有一个 write beat，还是也会产生 final_vld/cmplt？
        回答：INVALL 不读 compare，直接按 set index 扫描写无效。每个 set 只有一个写 beat，bank_sel 选择 8 个 way，tag/data 写入值为 0，用于清 valid。由于每个写 beat 仍进入 L2TLB 访问流水，所以每个已接受的写 beat 后仍会产生 final_vld 和 l2tlb_tlboper_cmplt；但 INVALL 自身的最终完成由最后一个 set 的写 grant 触发。
        12. TLB operation 期间如果 reset 拉低，operation done 是否取消，L1 invalidate pulse 是否可能已经发出但 L2 invalidation 未完成？
        回答：reset 拉低后，各 TLB operation 子流程状态、扫描计数、LSU 来源记录和完成脉冲状态都会回到空闲或无效，本次 operation done 不再保证产生；若 done 已在 reset 前出现，则它已经是一个已发出的完成脉冲。tlboper_utlb_clr 或 tlboper_utlb_inv_va_req 是请求阶段即可发出的清 L1 信号，因此存在 L1 清除信号已经发出、但 L2TLB 后续清除 beat 尚未全部完成时 reset 到来的情况。reset 期间应把未完成操作视为取消，复位结束后如仍需要该失效语义，应重新发起对应操作。

    5.11 replacement、RRPV 与 victim 可检查性
    DUT 行为已答，UVM 策略见 5.13.7
        说明：本节问题的 v1 UVM 结论统一收敛在 5.13.7。replacement、RRPV、victim、wbuf merge/latest-wins 相关微架构细节不作为 v1 checker，只做可选 debug coverage 或后续 replacement 专项验证。
        1. UVM 是否需要检查 TLBWR/PTW refill 选择的 victim way 与 RRPV/free-way 规则一致？还是 victim way 完全作为 DUT 内部行为不比较？
        2. 如果需要检查 victim way，hash/index/RRPV bypass/wbuf 最新值规则是否都必须补全为可实现的 reference model？
        3. RRPV write buffer full 在 count>=5 拉高；UVM 是否需要检查这个水位，还是只检查不会 overflow 和不会错误 grant？
        4. RRPV write buffer depth、水位、head/tail 顺序、CAM merge、latest-wins 是否都属于必须断言的微架构行为？
        5. 同周期 wbuf push 和 bypass lookup 命中同 bank/index 时，spec 写“同周期刚 push 也参与 bypass”；这个同周期优先级如何在 cycle-accurate UVM 中采样？
        6. PTW read 使用 merged RRPV；如果 wbuf 中某些 way valid=0，merged 结果应从 SRAM 取旧值还是视为 invalid way 不参与 victim？
        7. TLBWI/TLBWR 写有效 entry 时，RRPV 初始化为 3；是否也需要清除 wbuf 中同 bank/index 的旧 pending RRPV，避免后续 drain 覆盖新值？
        8. invalidate 清 tag/data 后，如果 wbuf 中仍有同 bank/index pending RRPV，drain 是否允许继续写 RRPV？UVM 是否应忽略 invalid entry 的 RRPV 后续变化？
        9. PTW write 直接写 RRPV SRAM 时，如果 wbuf 中有同 bank/index pending 更新，是否需要 invalidate/merge wbuf entry，还是依赖 bypass/latest rules？
        10. 普通 lookup multi-hit 不更新 RRPV；TLBP multi-hit 是否也不更新 RRPV，且不会 push wbuf？

    5.12 sequence、非法输入与 coverage
    DUT 行为已答，UVM 策略见 5.13.8
        说明：本节问题的 v1 UVM 结论统一收敛在 5.13.8。主功能随机只产生协议合法输入；非法协议输入放入负向 assertion/error-handling tests；coverage 和 timeout 的最低要求以 5.13.8 为准。
        1. L2TLB UVM 是否只产生协议合法输入，还是需要专门注入非法 access type、非法 page size、credit overflow、PTW completion bad id、多个 TLB operation 同时请求等场景？
        2. 对协议非法输入，如果 DUT 行为未定义，UVM 应检查 assertion 触发、忽略结果，还是完全不生成？
        3. multi-hit 是否必须主动构造？若必须，推荐使用 backdoor 写 tag/data，还是通过 TLBWI/TLBWR/PTW refill 前门构造？
        4. 如果通过前门构造 multi-hit，hash 函数不建模时如何保证多个 entry 会落到同一次 lookup 的候选 way？
        5. coverage 是否需要按 source 类型覆盖 ITLB、DTLB load、DTLB store、PFU、PTW refill、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID？
        6. coverage 是否需要按结果类型覆盖 single-hit、miss+MB alloc、miss+MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny？
        7. coverage 是否需要按 page size 覆盖 4KB/2MB/1GB，并交叉 selector VA[31:30]、way mask、global/non-global、ASID match/mismatch？
        8. coverage 是否需要覆盖 ASID/control 寄存器在 outstanding request 期间变化的场景，还是这种场景应作为软件约束禁止？
        9. coverage 是否需要覆盖 warm reset、wbuf full stall、ptw_on stall、tlboper_on stall、prefetch_mask retry、miss buffer abort/reissue？
        10. scoreboard 对可变延迟请求的 timeout 应如何设置？例如 TLB operation 扫描、PTW 等待、miss buffer full retry、wbuf full stall 是否需要最大等待周期约束？

    5.13 UVM 验证策略未闭合问题与文档易误导点
    说明
        本节不再重复询问 DUT 功能语义。前文很多回答已经说明 DUT 做什么；这里记录的是：UVM 是否需要检查、覆盖、建模、注入、约束这些行为尚未闭合，以及文档中仍可能误导后续 AI 的表述。

        5.13.1 文档易误导点
            1. access type 的定义是否需要统一？1.1 只列出 3'b001/010/011/100/101/110，但后文把 PTW read 编码为 3'b000，并在 5.2 问题中称 000 已定义；是否应在 signal description 中正式补充 3'b000 的含义？
            回答：已经完成补充。

            2. `arb_l2tlb_trans_id[TRANS_ID_WIDTH-1:0]` 表格中的 width 仍写成 3，但 `TRANS_ID_WIDTH=4` 且 5.2 已回答 ReqQ transaction id 真实宽度为 4bit；是否需要把该表格 width 改为 4？
            回答：已经完成修改。

            3. `arb_l2tlb_eid[EID_WIDTH-1:0]` 仍使用未定义的 `EID_WIDTH`；是否需要统一改为 `L1EID_WIDTH-1:0`，并在表格中写明真实宽度为 3bit？
            回答：EID_WIDTH在arb内部有定义。

            4. 5.2 中“`L2EID_WIDTH + L1EID_WIDTH = 3 + 4`”的顺序是否需要改成“`L2EID_WIDTH=4, L1EID_WIDTH=3, total=7`”，避免后续 AI 把高低位宽度反过来？
            回答：已经完成修改。

            5. 2.2 entry 字段中 `Size_Type [2:0]` 后面写 `2'b010`、`2'b100`，是否需要统一改成 `3'b010`、`3'b100`？
            回答：已经完成修改。

            6. `l2tlb_l1tlb_ref_flg[13:0]` 描述中写 flag 包含 global，但 5.10/5.6 回答说明 PTE.G 被单独放入 tag.G，data flags 中没有 G 位；是否需要明确 L1 refill 返回的 `ref_flg` 是否包含 G，若不包含，L1 如何获得 global 属性？
            回答：需要明确。当前 `l2tlb_l1tlb_ref_flg[13:0]` 不包含 G，来源是 L2 data SRAM 中的 `{PPN[27:0], flg[13:0]}`，而 data flag 打包已经去掉 PTE.G。PTE.G 在 PTW refill 或 TLBWI/TLBWR 写入时单独进入 L2 tag.G，用于 L2 lookup 的 ASID bypass、INVASID/INVVA_ASID 等 TLB operation 判断，以及 TLBR 的 `l2tlb_tlbr_g` 返回。
                  L1 refill 侧当前没有单独的 `ref_g` 接口，也不把 global 作为 L1 ITLB/DTLB entry 字段保存。因此 L1 不通过 `ref_flg` 获得 global 属性；L1 只保存 valid、VPN、PPN、page size 和 `flag[13:0]` 做 PA、权限和属性判断。ASID/global 相关选择在 L2 tag 命中和 TLB operation 中处理，L1 对 ASID/SATP/TLBI 相关变化按既有规格采用保守清理或全清策略建模，不依赖 per-entry G 位保留 global entry。

            7. overview 中 invalidate 写无效写成“必要时 data 也可同步清 0”，而 5.6 已回答 invalidate 写无效时 tag/data 都写 0；是否需要把旧表述改为确定语义，避免 UVM 不检查 data 清零？
            回答：已经修改。

            8. overview 中 INVVA_ASID 对 global entry 的描述仍写“需要由体系结构约束明确”，但后文已回答当前语义会清 global entry；是否需要把 overview 改成正式语义或加引用说明以后文为准？
            回答：需要改成正式语义，已修改。当前规格以 DUT 行为为准：INVVA_ASID 不置 `cmp_noasid`，但普通 VA hit 条件仍允许 `tag.G=1` 绕过 ASID 比较，所以 VA/page size 命中的 global entry 会进入 hit way mask 并在写阶段被清除。overview 不再保留“需要由体系结构约束明确”的旧表述。
            9. 文件中多个小节标题仍写“uvm部分由ai分析后回答”，其中一些问题已经有 DUT 行为回答、一些仍未回答；是否需要把这些占位标题改成“DUT 行为已答，UVM 策略待定”或类似文字？
            回答：需要，已修改。章节级占位统一改成“DUT 行为已答，UVM 策略见 5.13”；单条验证策略问题统一转入 5.13 的全局 UVM 策略项收敛。这样后续读者可以把已回答内容当作 DUT 规格语义使用，同时不会误以为内部微架构描述都应自动升级为 v1 checker。
            10. 本文是 L2TLB spec，但 5.1 回答说明后续要搭建完整 MMU UVM，且很多内部信号只是 MMU 内部观察点；是否需要在文件开头明确“本 spec 只描述 L2TLB 子功能，UVM 驱动边界以 MMU 顶层为准”？
            回答：需要，已在 overview 开头补充“适用范围与 UVM 边界”。本文作为完整 MMU UVM 的 L2TLB 子功能参考，内部 L2TLB 信号主要用于规格说明、white-box monitor、coverage 和 debug；sequence/driver 默认应从 MMU 顶层真实外部接口发起事务。只有明确声明的 directed white-box/backdoor 场景才允许直接使用内部注入或内部 SRAM 初始化。

        5.13.2 全局 UVM 建模边界
            1. UVM scoreboard 应采用 transaction-level reference model，只检查 MMU 顶层可见翻译结果，还是需要为 L2TLB 内部 ReqQ、MB、pipeline、TLB operation、RRPV 建 cycle-accurate reference model？
            回答：v1 UVM scoreboard 应采用 transaction-level reference model。检查边界以 MMU 顶层可见事务为准，包括 IFU/LSU translation、PFU translation、CSR/CP0/TLB operation、PTW completion、PMP/sysmap 响应和最终 refill/fault。ReqQ、miss buffer、raw/final pipeline、TLB operation 子状态、RRPV/write buffer 不建 cycle-accurate golden model。

            2. 若采用 transaction-level reference model，哪些内部信号只作为 debug/coverage 采样点，哪些内部信号必须作为 checker 的强检查点？
            回答：强 checker 只放在会影响顶层协议和可见功能语义的位置，包括 reset-inv 完成边界、顶层 request/response 协议、credit/request pulse 协议、PTW id 与 completion 合法组合、TLB operation done/abort/L1 invalidate 事件、最终 refill/fault 响应、以及非法输入 assertion。ReqQ valid/sent、miss buffer valid/sent、raw/final valid、ptw_on、tlboper_on、prefetch_mask、wbuf 状态、SRAM 内容、set/way/victim/RRPV 状态默认只作为 debug/coverage 采样点，除非某个 directed white-box test 明确声明要检查对应微架构行为。

            3. 既然允许 white-box 观察内部状态，UVM 是否应默认监控 ReqQ valid/sent、miss buffer valid/sent、raw/final valid、ptw_on、tlboper_on、prefetch_mask、wbuf 状态和 SRAM 内容？
            回答：应默认提供 white-box monitor 能力并采样这些状态，但默认 scoreboard 不应依赖它们做 cycle-accurate 预测。推荐把这些内部状态接入 coverage、debug log 和必要的协议断言，例如 no overflow、reset 后 invalid、stall 时不得错误 grant；不要用它们替代顶层 transaction-level 检查。

            4. backdoor 初始化 tag/data/RRPV SRAM 是否作为标准 sequence 能力，还是只用于少数 directed corner case？
            回答：backdoor 初始化可作为 UVM infrastructure 的标准能力提供，但不能作为普通随机 sequence 的默认建表方式。正常功能流量优先通过 PTW refill、TLBWI/TLBWR 等前门路径构造 entry；backdoor 只用于 directed corner case，例如 multi-hit、invalid tag + nonzero payload、指定 set/way、reset 前 warm SRAM、RRPV/debug corner。

            5. backdoor 写 SRAM 后，UVM reference model 是否必须同步更新相同 entry，还是允许只把 backdoor 状态作为 DUT 初始条件采样？
            回答：backdoor 写入会改变 DUT 初始条件，因此 reference model 必须同步更新相同 entry 的功能可见状态。tag.valid=1 时，模型需要记录 VPN、ASID、PGS、G、PPN、flags 等用于 lookup/TLB operation/TLBR 的字段；tag.valid=0 时，该 entry 在模型中视为 invalid，data/RRPV 和 tag 其它字段可任意，普通 lookup 不得命中。

            6. 对于 hash index、victim way、RRPV update 已决定“暂时不作为 UVM 验证点”的部分，coverage 是否仍需要覆盖 set/way/victim/RRPV 状态？如果需要，应通过内部采样覆盖还是前门激励覆盖？
            回答：v1 不要求 hash/victim/RRPV 覆盖作为 hard closure。可以通过内部采样收集 set/way/victim/RRPV debug coverage，帮助判断随机流量是否触达不同物理位置和 replacement 状态，但不要求前门定向激励精确打到每个 set/way/RRPV 组合，也不把未覆盖当作 v1 fail。

            7. 如果不精确建模 hash/RRPV，UVM 是否仍需要检查 TLBWR/PTW refill 最终写入的 set/way，还是只检查后续 lookup 功能可命中/可失效？
            回答：v1 不检查 TLBWR/PTW refill 选择的具体 victim way 是否符合 RRPV/free-way 规则，也不预测 PTW refill 最终写入的具体 way。scoreboard 只检查功能结果：合法 refill/write 后对应 translation 后续可命中，invalidate/TLB operation 后应失效，TLBR/TLBP 对软件可见字段符合前门或 backdoor 建模结果。

            8. UVM 是否需要把 4.x/5.x 已回答内容整理成 checker 规则列表，避免后续 AI 继续把“DUT 行为回答”和“UVM 策略回答”混在一起？
            回答：需要。后续搭建 UVM 时应维护独立的 checker/coverage 规则列表：DUT 行为回答作为功能语义输入；UVM 策略回答决定哪些语义进入 scoreboard、assertion、coverage 或只作为 debug。不能把所有 DUT 微架构描述都自动升级为 v1 scoreboard 规则。

        5.13.3 ReqQ、credit、arbiter 与 stall 的 UVM 策略
            1. ReqQ 不保存 ASID/privilege/MMU enable/SUM/MXR，除 ASID 已回答应约束不变化外，其它控制寄存器在 ReqQ 排队、lookup pipeline、PFU check、PTW completion 期间变化是否也应由 sequence 禁止？
            回答：应由 sequence 禁止。正常架构场景下，SATP/ASID/MMU enable/privilege/SUM/MXR/MPRV/MPP/MAEE 这类控制上下文不应在相关 outstanding translation、PFU check 或 PTW completion 未 drain/abort 前随意变化。若测试需要改变这些控制寄存器，必须先通过 fence/flush/invalidate/abort/drain 等系统流程建立新上下文边界。

            2. 对上游违反 credit 协议的场景，5.4 已回答“不纳入 L2TLB UVM”；完整 MMU UVM 是否仍需要在接口层加 assertion 检查，保证 L1 不会在无 credit 时发请求？
            回答：需要。完整 MMU UVM 应在 L1/MMU 接口层加入协议 assertion：无 credit 时不得发起对应 L1 请求；credit 计数不得 overflow/underflow；同拍 return+request 按协议抵消，但不能依赖同拍释放 entry 被同拍复用。

            3. `i_req_valid/d_req_valid` 持续多拍会被当作多笔请求；UVM 是否应增加协议 assertion 检查 request pulse 宽度为 1 拍？
            回答：需要。合法 sequence 只产生 1 拍 request pulse；接口 assertion 应检查 `i_req_valid`、`d_req_valid` 不得连续多拍保持为 1。持续 valid 属于协议违规，不进入正常 scoreboard 结果比较。

            4. 同拍 credit_return 与 req_valid、ReqQ dealloc 与新 alloc、bypass 未 grant 后入队等场景，是否需要作为 directed coverage/checker 项？
            回答：需要作为 directed coverage，并配套轻量 checker。检查重点是不丢请求、不重复完成、credit 计数正确、bypass 未 grant 后能入队并后续 issue；不要求建立完整 ReqQ cycle-accurate 模型。

            5. arbiter 的 `ptw > tlb operation > reqq > pfu` 优先级是否需要逐拍强检查，还是只在少量定向用例中检查？
            回答：建议做 white-box 逐拍 assertion，但只在输入请求和 stall/mask 条件明确可观测时启用。规则是：没有 `ptw_on`、`tlboper_on`、wbuf full、prefetch_mask 等阻塞时，同拍多源请求必须按 `ptw > tlb operation > reqq > pfu` 给唯一 grant；有阻塞时按对应 block 条件检查不得错误 grant。

            6. `tlboper_on` 空泡阻塞、`ptw_on` 原子 refill 阻塞、wbuf full stall、prefetch_mask 阻塞是否都需要 checker 逐拍断言“不得错误 grant”？
            回答：需要。`tlboper_on` 阻塞普通 ReqQ/PFU/PTW read，`ptw_on` 阻塞新的 TLB operation/ReqQ/PFU/PTW read，wbuf full 阻塞会产生 RRPV 新更新的访问，prefetch_mask 阻塞新的 PFU grant。UVM 应逐拍检查这些条件下不得错误接受被阻塞源。

            7. RRPV write buffer drain 不产生 `arb_l2tlb_req`，但会写 RRPV SRAM；如果 UVM 不精确建模 RRPV，是否仍需要 monitor drain 事件？
            回答：需要 monitor drain 事件，但只用于 debug/coverage 和 no-overflow 类检查。v1 不预测 drain 后每个 RRPV 值，也不把 drain 建成 scoreboard 可见事务。

            8. PFU 请求未 grant 时不在 arbiter 内缓存；UVM 是否需要检查 LSU/PFU agent 在未完成或 mask 期间保持/重发协议，还是只检查 DUT 已接受请求之后的响应？
            回答：两者都要分层检查。PFU/LSU agent 侧应保证未被接受或 mask 期间的保持/重发协议；scoreboard 只对已经被 MMU 接受的 PFU 请求建立响应期望。未 grant 的一拍 PFU pulse 不应被 scoreboard 当作已接受请求。

        5.13.4 SRAM、lookup、response 与 fault 的 UVM 策略
            1. tag.valid=0 但 tag/data 其它字段非 0 时 lookup 必须 miss；UVM 是否需要专门构造 invalid tag + nonzero data/tag 的覆盖场景？
            回答：需要 directed 覆盖。推荐用 backdoor 构造 tag.valid=0 且 tag/data 其它字段非 0 的 entry，检查普通 lookup、TLBP、INVVA 类 VA compare 均不命中；TLBR 仍可按 index 读出旧字段。

            2. TLBR 读取 invalid entry 会返回旧 SRAM 字段；UVM 是否必须精确检查 TLBR 对 VPN/ASID/PGS/G/PPN/flag 的返回值，还是只检查不会影响普通 lookup？
            回答：必须精确检查 TLBR 的软件可见返回字段。TLBR 是 index read，不因 tag.valid=0 屏蔽 VPN/ASID/PGS/G/PPN/flag；若 entry 是 invalidate 写 0 后形成，则应读出 0；若 backdoor 构造 invalid 但字段非 0，则应读出对应旧字段。

            3. invalidate 写无效时 tag/data 都写 0；UVM 是否应对所有 invalidate 类型检查 data 也被清 0，还是只检查 tag.valid 清 0 后功能 miss？
            回答：两层都要检查。功能 scoreboard 必须检查 invalidate 后相关 lookup miss；white-box directed checker 应对 INVVA/INVASID/INVALL 等真正产生写无效 beat 的路径检查被选中 tag/data 都写 0。RRPV 不要求清 0。

            4. L2TLB 普通 ITLB/DTLB hit 不检查 PTE.V/R/W/X/U/A/D；UVM scoreboard 是否应完全禁止在 L2 direct hit 路径判这些 fault，只把 flag 原样传给 L1 参考模型？
            回答：是。L2 direct hit scoreboard 只判断 tag 命中和返回 payload 是否正确，不在 L2 层判 PTE flag fault。PTE.V/R/W/X/U/A/D 等权限 fault 由 L1 或 PFU/PTW 对应参考模型处理。

            5. multi-hit 与 PTW disabled miss 对 L1 都表现为 `pgflt=1`；UVM 是否需要通过内部 coverage 区分两类原因，还是外部 scoreboard 只检查相同响应编码？
            回答：外部 scoreboard 只检查相同响应编码，即 `cmplt=1,pavld=0,pgflt=1`。内部 coverage 需要区分 multi-hit 和 PTW disabled miss 两类原因，避免只覆盖一种 fault 来源。

            6. fault 或 `ref_pavld=0` 时 `l2tlb_l1tlb_ref_*` payload 不保证可消费；UVM 是否应在所有 fault 场景忽略 payload，只检查 `eid/cmplt/pgflt/pavld`？
            回答：是。fault 或 `ref_pavld=0` 时忽略 VPN/PPN/flag/pgs payload，只检查完成编码、DTLB eid 关联、`cmplt/pgflt/pavld` 合法组合。payload 不应参与 fail 判定。

            7. L1 侧最终 PTW refill/fault response 不经过 `mmu_l2tlb` 直返端口；完整 MMU scoreboard 应在哪里合并 L2TLB miss buffer 释放、PTW completion 和 L1 最终响应？
            回答：应在完整 MMU transaction scoreboard 中合并，而不是只在 `mmu_l2tlb` 直返端口合并。L2TLB miss allocation、PTW request、PTW completion、L2 refill 写入、L1 最终 refill/page fault/access error response 是同一顶层 translation 事务的不同阶段；MB 释放属于内部一致性观察点。

            8. reset 打断 T0/T1/T2 lookup 时，UVM 是否应在 reset assert 当拍清空所有 pending expectation，并忽略 reset 后可能残留的旧 payload？
            回答：是。`cpurst_b` 拉低当拍，scoreboard 清空所有 pending expectation 和寄存器型参考状态；reset-inv 完成前忽略旧 lookup payload 或旧 response 组合。reset-inv 完成后，L2TLB 模型按全部 entry invalid 重建。

        5.13.5 PFU、PTW、miss buffer 与 abort 的 UVM 策略
            1. PFU MMU-on lookup、PFU MMU-off direct path、PFU PTW completion path 是否需要建成三条独立 scoreboard 路径？
            回答：需要。三条路径的接受边界、延迟和 fault 判定不同：MMU-off direct path 绕过 L2TLB lookup；MMU-on hit path 使用 L2 entry 并做 PFU flag/PMP/sysmap check；MMU-on miss 后由 PTW completion 直接形成 PFU completion，不通过 refill 后二次 lookup。

            2. PFU hit-path 会做完整 flag fault check，但 PFU miss 的 PTW data_vld path 不通过 refill 后二次查表；UVM reference model 是否需要分别建模这两种 fault 判定差异？
            回答：需要。PFU hit path 按 L2 data flag 做完整 V/R/W/X/U/A/SUM/MXR/MPRV/MPP/MAEE/PMP/sysmap 判断；PTW data_vld completion path 使用 PTW 返回的 pgflt/acc_err/flag attribute，并继续做必要 PMP/sysmap/attribute 检查，不重新执行一次基于 L2 hit 的完整 flag check。

            3. PFU error 时 PA/sec/share 有稳定输出但不可消费；UVM 是否只检查 `pa2_vld/pa2_err`，并在 error 时忽略 PA/sec/share？
            回答：是。`pa2_err=1` 时只检查 `mmu_lsu_pa2_vld=1` 且 error 编码正确，忽略 `mmu_lsu_pa2/mmu_lsu_sec2/mmu_lsu_share2` 的具体值；这些字段不表示可消费翻译结果。

            4. PFU flag fault 的 V/R/W/X/U/A/SUM/MXR/MPRV/MPP/MAEE 组合是否需要做完整交叉 coverage，还是只覆盖每个 fault 原因至少一次？
            回答：v1 不要求完整笛卡尔交叉。必须覆盖每个独立 fault 原因至少一次，并覆盖关键交叉：MXR 影响可读性、SUM 与 S-mode 访问 U page、MPRV/MPP 改变 effective privilege、MAEE 选择 entry attribute 或 sysmap attribute。

            5. PMP/sysmap deny、sysmap SO/C fault、MAEE on/off 是否需要在 PFU coverage 中与 MMU-on/MMU-off、hit/PTW completion 路径交叉？
            回答：需要做有限交叉。至少覆盖 PMP allow/deny、sysmap SO=1、sysmap C=0、MAEE on/off 分别出现在 MMU-off direct、MMU-on L2 hit、MMU-on PTW completion 三类路径中的代表场景；不要求全部属性位全组合。

            6. PTW completion bad id 已定义为非法 completion；UVM 是否完全不生成，还是生成 assertion/error-handling 测试？
            回答：合法随机和主功能 directed test 不生成 bad id。可以建立单独负向 assertion test 注入 bad id，期望协议 assertion/error 被触发；该类测试不比较正常功能结果。

            7. PTW completion 的 data_vld/pgflt/acc_err 合法组合是否需要 assertion 检查互斥？
            回答：需要。`ptw_l2tlb_ref_cmplt=1` 时，`ref_data_vld`、`ref_pgflt`、`ref_acc_err` 应按规格合法组合互斥或唯一有效；`cmplt=0` 时三者应为 0。非法组合应触发协议 assertion。

            8. miss buffer allocation 与 deallocation 同拍不同 entry 可并行；UVM 是否需要覆盖该并行情形？
            回答：需要 directed coverage。检查同拍 alloc/dealloc 不丢失 entry、不重复释放、id 对应正确、MB full/empty 状态更新不破坏后续 PTW issue。

            9. miss buffer full、miss retry、ReqQ replay、PFU prefetch_mask retry 是否需要端到端 directed tests？
            回答：需要。这些是 transaction-level 可见的 backpressure/retry 行为，必须有端到端 directed tests 覆盖，scoreboard 检查最终请求仍能正确完成或按合法 fault 返回。

            10. `tlboper_ptw_abort` 后 valid miss buffer entry 会全部重新 issue；UVM 是否需要覆盖 abort 前已 sent、未 sent、重复 VPN、多 entry 乱序 completion 等组合？
            回答：需要。至少覆盖 abort 前已 sent entry、未 sent entry、多个 entry、重复 VPN、PTW completion 乱序返回、abort 后 reissue 成功等组合。检查 abort 后旧 completion 不得错误写回旧 translation，reissue 后按新上下文完成。

            11. ASID/SATP 变化期间 outstanding miss 需要由系统流程保证安全；UVM 是否应通过 sequence 约束禁止这类场景，并用 assertion 检查 SATP/ASID 改写前 outstanding walk 已 drain/abort？
            回答：是。正常 sequence 禁止 ASID/SATP 改写与 outstanding walk 重叠；CSR/TLB maintenance 流程必须先 drain 或 abort。UVM 应用 assertion 检查 SATP/ASID 改写前相关 outstanding translation/PTW 已被 drain、flush 或 abort。

        5.13.6 TLB operation 的 UVM 策略
            1. 完整 MMU UVM 是否只能通过真实顶层 CP0/CSR/LSU invalidate 接口驱动 TLB operation，而不允许直接驱动 `tlboper_arb_*`、`tlboper_l2tlb_*` 低层接口？
            回答：默认只能通过真实顶层 CP0/CSR/LSU invalidate 接口驱动。`tlboper_arb_*`、`tlboper_l2tlb_*` 是 MMU 内部观察点，不作为普通 sequence driver 接口。只有明确标注的 directed white-box test 才允许直接驱动或强制内部 tlboper 信号。

            2. 如果低层 tlboper 信号仅作为 monitor，UVM 是否仍需要为每类 operation 检查 request/grant/cmplt/done beat 数量？
            回答：需要。低层 tlboper 信号虽然不是驱动接口，但应作为 checker 观察点检查每类 operation 的 request/grant/cmplt/done beat 数量和先后关系，防止提前 done、漏 done、重复 done 或扫描类操作少扫 set。

            3. `tlboper_utlb_clr`、`tlboper_utlb_inv_va_req`、`tlboper_ptw_abort`、`mmu_lsu_tlb_inv_done`、`mmu_cp0_tlb_done`、`tlboper_regs_cmplt` 是否都应作为 checker 观察点？
            回答：都应作为 checker 观察点。它们分别对应 L1/uTLB 清除、按 VA 清除、PTW abort、LSU invalidate 完成、CP0/CSR TLB operation 完成、寄存器来源操作完成。scoreboard 应检查它们与顶层 operation 类型和完成时机一致。

            4. TLBWI/TLBWR 是否需要覆盖写 valid entry、写 invalid entry、非法 pgs、非法 flag、未对齐大页 PPN，并检查后续 TLBP/lookup 的自然结果？
            回答：需要。TLBWI/TLBWR directed tests 应覆盖这些输入形态，并按规格自然结果检查：合法 valid entry 可被 lookup/TLBP 命中；invalid entry 不命中；非法 pgs 不参与 VA compare 但 TLBR 原样读出；非法 flag 在 L2 ordinary hit 不直接 fault，在 L1/PFU 对应路径产生后续效果；未对齐大页 PPN 按 page size 拼接规则处理。

            5. INVVA_ALL、INVVA_ASID、INVASID、INVALL 是否需要分别覆盖 hit、miss、多 way hit、global/non-global、ASID match/mismatch、非法 pgs 不命中等组合？
            回答：需要。每类 invalidate 都应至少覆盖 hit、miss、多 way hit、global/non-global、ASID match/mismatch 和非法 pgs 不命中。INVASID 还要覆盖 global entry 保留；INVVA_ASID 要覆盖同 VA/page size 的 global entry 被清除。

            6. INVASID 每个 set 的 read-only no-write 路径与 read-then-write 路径是否都需要 coverage？
            回答：需要。INVASID 扫描中，某个 set 无 ASID hit 时应只读不写；存在一个或多个 ASID hit way 时应 read-then-write 清除对应 way。两类路径都需要 coverage。

            7. INVALL 256 set 扫描是否需要检查每个 set 都产生一个 write beat，还是只检查最终全部 entry invalid？
            回答：v1 推荐 white-box 检查每个 set 都产生写无效 beat，并检查最终全部 entry invalid。如果环境初期无法稳定绑定内部写 beat，最低要求是通过 backdoor/后续 lookup/TLBR 确认最终所有 entry invalid，并把逐 set write beat 检查列为后续增强项。

            8. TLB operation 执行期间 reset 打断时，UVM 是否需要覆盖“L1 invalidate pulse 已发出但 L2 清除未完成”的场景？
            回答：需要。reset interrupt directed test 应覆盖 TLB operation 已经发出 L1 invalidate/abort 但 L2 扫描或写无效未完成的场景。reset assert 后清空 pending expectation；reset-inv 完成后重新建立全 invalid 模型。

        5.13.7 replacement、RRPV 与 victim 可检查性
            1. UVM 是否需要检查 TLBWR/PTW refill 选择的 victim way 与 RRPV/free-way 规则一致，还是 victim way 完全作为 DUT 内部行为不比较？
            回答：v1 不检查 victim way 与 RRPV/free-way 规则是否一致。victim way 作为 DUT 内部 replacement 行为，只通过后续 lookup、TLBR/TLBP、invalidate 等功能结果间接验证。

            2. 如果需要检查 victim way，hash/index/RRPV bypass/wbuf 最新值规则是否都必须补全为可实现的 reference model？
            回答：如果未来要检查 victim way，就必须补全 hash/index/RRPV SRAM/wbuf bypass/latest-wins/free-way 选择规则，并实现 cycle-accurate reference model。v1 不做这件事。

            3. RRPV write buffer full 在 count>=5 拉高；UVM 是否需要检查这个水位，还是只检查不会 overflow 和不会错误 grant？
            回答：v1 应检查不会 overflow，以及 full 时不会错误 grant 会产生新 RRPV 更新的访问。count>=5 的具体水位可以作为 white-box assertion/debug coverage；如果绑定稳定，建议检查，但不作为 transaction scoreboard 必要条件。

            4. RRPV write buffer depth、水位、head/tail 顺序、CAM merge、latest-wins 是否都属于必须断言的微架构行为？
            回答：不属于 v1 必须断言项。它们是 replacement metadata 微架构行为，可作为可选 white-box assertion/debug coverage；只有在项目决定验证 replacement 准确性时才升级为必须检查。

            5. 同周期 wbuf push 和 bypass lookup 命中同 bank/index 时，spec 写“同周期刚 push 也参与 bypass”；这个同周期优先级如何在 cycle-accurate UVM 中采样？
            回答：v1 不建立该 cycle-accurate 规则。若未来验证 RRPV，则采样点应定义为同一时钟周期组合 bypass 结果包含本周期 push 数据，monitor 需要在 push 条件和 bypass lookup 条件同拍成立时比较 merged RRPV；当前只做可选 debug coverage。

            6. PTW read 使用 merged RRPV；如果 wbuf 中某些 way valid=0，merged 结果应从 SRAM 取旧值还是视为该 way 没有 pending update？
            回答：对 replacement 模型来说，wbuf 中某 way valid=0 表示该 way 没有 pending update，merged 结果应从 SRAM 旧值取得。但 v1 不检查 merged RRPV 数值，只在需要 future RRPV reference model 时采用该规则。

            7. TLBWI/TLBWR 写有效 entry 时，RRPV 初始化为 3；是否也需要清除或覆盖 wbuf 中同 bank/index 的旧 pending RRPV，避免后续 drain 覆盖新值？
            回答：v1 不检查此类 RRPV/wbuf 交互，也不要求 reference model 预测旧 pending RRPV 是否被清除或覆盖。功能检查以 entry valid/tag/data 和后续 lookup 结果为准；RRPV stale update 不应影响 invalid/valid lookup 语义。

            8. invalidate 清 tag/data 后，如果 wbuf 中仍有同 bank/index pending RRPV，drain 是否允许继续写 RRPV？UVM 是否应忽略 invalid entry 的 RRPV 后续变化？
            回答：允许从 UVM 功能角度忽略。invalidate 后 entry 是否有效由 tag.valid 决定，invalid entry 的 RRPV 后续变化不影响 lookup；v1 应忽略 invalid entry 的 RRPV drain 变化。

            9. PTW write 直接写 RRPV SRAM 时，如果 wbuf 中有同 bank/index pending 更新，是否需要 invalidate/merge wbuf entry，还是依赖 bypass/latest rules？
            回答：v1 不检查该微架构细节。若未来验证 replacement，需要明确 latest-wins 或 merge/invalidate 规则并建模；当前只检查 PTW refill 功能可见结果和 no-overflow/no-wrong-grant。

            10. 普通 lookup multi-hit 不更新 RRPV；TLBP multi-hit 是否也不更新 RRPV，且不会 push wbuf？
            回答：v1 不用 RRPV 更新作为 checker。可作为 debug assertion 记录：multi-hit 不应产生正常 hit 的 RRPV 更新；TLBP multi-hit 也不应作为普通单命中去 push wbuf。该规则不参与 transaction scoreboard。

            11. 如果最终决定不检查 RRPV/victim，5.11 中上述问题是否应全部标注为“不作为 v1 UVM checker，只做可选 debug coverage”？
            回答：是。5.11/5.13.7 中 replacement、RRPV、victim、wbuf merge/latest-wins 相关问题统一标注为：不作为 v1 UVM checker，只做可选 debug coverage 或后续 replacement 专项验证。

        5.13.8 sequence、非法输入、coverage 与 timeout
            1. L2TLB/MMU UVM 是否只产生协议合法输入，还是需要专门注入非法 access type、非法 page size、credit overflow、PTW completion bad id、多个 TLB operation 同时请求等场景？
            回答：主功能随机和 directed sequence 只产生协议合法输入。非法 access type、credit overflow、PTW completion bad id、多个 TLB operation 同时请求等应放入单独负向 assertion/error-handling tests。非法 page size 分两类：tag.pgs 非法可通过 backdoor/TLBWI directed 构造并检查自然行为；协议层非法激励不进入普通随机。

            2. 对协议非法输入，如果 DUT 行为未定义，UVM 应检查 assertion 触发、忽略结果，还是完全不生成？
            回答：普通功能测试完全不生成。负向测试中只检查协议 assertion 或 error-handling 是否触发，不比较未定义功能结果；若项目没有对应 assertion，则该非法场景不作为 pass/fail 功能用例。

            3. multi-hit 是否必须主动构造？若必须，推荐使用 backdoor 写 tag/data，还是通过 TLBWI/TLBWR/PTW refill 前门构造？
            回答：必须主动构造 multi-hit directed test。推荐使用 backdoor 写 tag/data 到指定候选 way，确保同一 VA/page size/ASID/global 条件下多 way 命中。前门构造只在 hash/index/victim 可控或可观测时使用。

            4. 如果通过前门构造 multi-hit，hash 函数不建模时如何保证多个 entry 会落到同一次 lookup 的候选 way？
            回答：不能可靠保证。若不建模 hash，应避免把前门 multi-hit 作为硬性测试方法；使用 backdoor 或先通过内部 monitor/TLBR 探测实际落点后再构造。否则该测试会变成概率性覆盖，不适合作为 checker。

            5. coverage 是否需要按 source 类型覆盖 ITLB、DTLB load、DTLB store、PFU、PTW refill、TLBP、TLBR、TLBWI、TLBWR、INVALL、INVASID、INVVA_ALL、INVVA_ASID？
            回答：需要。这些 source/operation 类型都是 v1 功能 coverage 的基本 coverpoint。每类至少覆盖一次成功路径和代表性 fault/miss/invalidate 路径。

            6. coverage 是否需要按结果类型覆盖 single-hit、miss+MB alloc、miss+MB full retry、PTW disabled miss、multi-hit、PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny？
            回答：需要。这些 result 类型是 v1 必须覆盖的主功能结果，其中 MB full retry、prefetch_mask retry、PTW page fault/access error、PFU deny 建议用 directed tests 保证可达。

            7. coverage 是否需要按 page size 覆盖 4KB/2MB/1GB，并交叉 selector VA[31:30]、way mask、global/non-global、ASID match/mismatch？
            回答：page size 4KB/2MB/1GB 必须覆盖。global/non-global、ASID match/mismatch 需要与 lookup/TLB operation 做有限交叉。VA[31:30] selector 和 way mask/set/way 建议通过内部采样做 debug coverage，不作为 v1 hard closure。

            8. coverage 是否需要覆盖 ASID/control 寄存器在 outstanding request 期间变化的场景，还是这种场景应作为软件约束禁止？
            回答：作为软件/系统约束禁止，不纳入正常功能 coverage。需要通过 assertion 检查 SATP/ASID/control 改写前 outstanding request 已 drain/flush/abort；负向测试可单独验证 assertion。

            9. coverage 是否需要覆盖 warm reset、wbuf full stall、ptw_on stall、tlboper_on stall、prefetch_mask retry、miss buffer abort/reissue？
            回答：需要。warm reset、wbuf full stall、ptw_on stall、tlboper_on stall、prefetch_mask retry、miss buffer abort/reissue 都属于 v1 directed coverage 项；其中 warm reset 必须检查 reset-inv 完成后模型全 invalid。

            10. scoreboard 对可变延迟请求的 timeout 应如何设置？例如 TLB operation 扫描、PTW 等待、miss buffer full retry、wbuf full stall 是否需要最大等待周期约束？
            回答：timeout 按 testbench fairness 假设设置，而不是把所有外部 backpressure 都当作 DUT 固定延迟。UVM agent 应保证 PTW eventually ready/completion、PMP/sysmap eventually response、stall eventually release；在这些 fairness 条件满足后，为 TLB operation 扫描、PTW completion、MB retry、wbuf full stall 设置合理最大等待周期。超过 timeout 先报 testbench fairness 或 DUT forward-progress 分类错误。

            11. 如果某些等待理论上可能被上游永久 backpressure 阻塞，UVM timeout 是按 testbench fairness 假设设置，还是按 DUT 本身必须 forward progress 设置？
            回答：按两层处理。外部可无限 backpressure 的等待由 testbench fairness 假设约束，不能要求 DUT 在无 ready/无 completion 时自行完成；当外部 ready/completion/stall release 已经满足后，DUT 必须 forward progress，此时 timeout 可作为 DUT 检查。

            12. v1 UVM 的最低验收标准是什么：只通过 directed sanity、覆盖主功能路径，还是必须包含随机并发、reset/abort、非法输入、RRPV corner case？
            回答：v1 最低验收标准为：transaction-level scoreboard 可用；合法 directed sanity 通过；覆盖 ITLB/DTLB/PFU/PTW/TLB operation 主功能路径；覆盖 reset-inv、warm reset、TLB invalidate/write/read/probe、PFU fault、PTW page fault/access error、MB retry/abort/reissue；具备基本随机并发和关键协议 assertion。非法输入负向测试和 RRPV/victim corner 不阻塞 v1 功能环境成型，可作为 v1.1 或专项验证。

---
---

## 6. Phase 2 L2TLB 测试点清单

本章为 Phase 2 重新整理的 L2TLB 测试点清单。前文功能描述和 5.13 UVM 策略问答仍是来源依据；`l2tlb_function_description.txt` 仍作为只读黄金输入，本 `.md` 只承载后续 audit 补充。

### 6.1 Phase 2 边界

- 普通 MMU UVM 激励边界以 IFU/LSU translation、CP0/CSR/TLB operation、PTW/PMP/sysmap、reset 等顶层真实接口为准。
- `arb_*`、`queue_*`、`tlboper_*`、`l2tlb_*` 等内部信号只作为 monitor、checker、coverage、debug 输入；只有标记为 `Backdoor directed` 或 `White-box monitor/coverage` 的测试点可以依赖内部观察或受控 backdoor 初始化。
- 现有 `l2tlb_tests` wrapper 只作为粗映射入口，不能因为 wrapper 名称存在就判定该测试点已经覆盖。
- RRPV、victim、wbuf latest-wins 相关内容在 v1 中只作为 debug coverage 或 future replacement 专项，除非后续建立 cycle-accurate replacement reference model。

### 6.2 测试点矩阵

| ID | 功能域 | 规格来源章节 | 测试类型 | 目标行为 | 激励入口 | 可观察结果 | Checker | Coverage | 优先级 | 当前 UVM 入口 | 状态 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB_TP_001 | reset | overview, 1.1, 5.13.8 | Black-box functional | cold reset 后 ReqQ、MB、pipeline valid、PFU FSM、RRPV wbuf 均回到 idle 或 invalid | `cpurst_b` 上电复位 | 无伪 request、无伪 refill、无伪 fault，reset release 后可接受新请求 | reset drain checker；关键 valid 清零检查 | cold reset；reset 后首个 ITLB/DTLB/PFU 请求 | P0 | 需新增 reset directed | Planned | 覆盖 reset 结果类型 |
| L2TLB_TP_002 | reset | 1.1, 1.9, 5.13.8 | Black-box functional | warm reset 打断 lookup、PTW、TLBOP、PFU 活跃窗口时清空 pending expectation | 活跃 transaction 期间拉低 `cpurst_b` | reset 后旧 completion 不被消费，新 transaction 从干净状态开始 | scoreboard pending clear；no stale response | warm reset x lookup/PTW/TLBOP/PFU | P0 | 需新增 warm reset directed | Planned | reset-inv 完成后模型应 all-invalid |
| L2TLB_TP_003 | UVM boundary | overview, 5.13.1 | White-box monitor/coverage | 普通测试只通过顶层真实接口驱动，不直接驱动内部 L2TLB 端口 | IFU/LSU/CP0/PTW/PMP/sysmap 顶层 agent | 内部信号只被 probe 观察 | wrapper metadata audit | black-box vs white-box wrapper 分类 | P0 | `l2tlb_tests` 全量 audit | Planned | 防止假覆盖 |
| L2TLB_TP_004 | ReqQ | 1.3, 1.6, 2.1 | Black-box functional | ITLB miss 分配 ReqQ entry0，credit 消耗和返回正确 | IFU miss 到 L1ITLB 后转发 L2TLB | `i_credit_return` 与 completion 或释放时机一致 | credit shadow；entry0 lifecycle checker | ITLB source；alloc/issue/dealloc | P0 | `test_mmu_dir_l2tlb_reqq_*` 粗映射 | Planned | 覆盖 ITLB source |
| L2TLB_TP_005 | ReqQ | 1.3, 1.6, 2.1 | Black-box functional | DTLB load/store miss 分配 DTLB 专用 ReqQ entry，eid/type 保持正确 | LSU load/store miss 到 L1DTLB 后转发 L2TLB | `d_credit_return`、eid、load/store type 对齐 | credit and type shadow | DTLB load；DTLB store；multi-entry occupancy | P0 | `test_mmu_dir_l2tlb_reqq_dtlb_alloc_*` 粗映射 | Planned | 覆盖 DTLB load/store source |
| L2TLB_TP_006 | ReqQ | 1.3, 2.1 | White-box monitor/coverage | 新请求同拍获得 grant 时允许 bypass issue，payload 稳定 | IFU/LSU miss 与 arbiter grant 同拍 | `queue_arb_*` payload 与请求一致 | payload stability checker | bypass issue；queued issue | P1 | 需加强 `l2tlb_reqq_*` wrapper | Planned | 内部观察点 |
| L2TLB_TP_007 | ReqQ | 1.3, 2.1, 5.13.8 | Black-box functional | L2 miss 且 MB full 时 ReqQ 不释放请求，清 sent 后可 replay | 填满 MB 后再发 ITLB/DTLB miss | 无请求丢失，MB 空位释放后最终完成 | transaction lifetime checker | MB full retry；retry count 大于 0 | P0 | `test_mmu_dir_l2tlb_reqq_credit_full_no_return` 粗映射 | Planned | 覆盖 MB full retry 结果 |
| L2TLB_TP_008 | ReqQ | 1.6, 2.1 | Black-box functional | hit、miss alloc、fault completion 均能归还对应 L1 credit | ITLB/DTLB hit、miss alloc、PTW disabled miss | credit return pulse 与 ReqQ dealloc 对齐 | credit accounting checker | hit return；refill return；fault return | P0 | `test_mmu_dir_l2tlb_reqq_credit_return_*` 粗映射 | Planned | 不把 wrapper 名称当覆盖结论 |
| L2TLB_TP_009 | arbiter | overview, 1.4, 2.2 | White-box monitor/coverage | ReqQ、PFU、PTW、TLBOP 多来源同时有效时每拍最多一个访问 SRAM pipeline | 构造多 source 同拍请求 | `arb_l2tlb_req` 与 grant onehot0 一致 | arbiter onehot checker | source pairwise conflict；four-source conflict | P0 | `test_mmu_rand_l2tlb_bank_conflict_multi_source` 粗映射 | Planned | 单端口 SRAM 约束 |
| L2TLB_TP_010 | arbiter | overview, 2.2, 5.13.8 | White-box monitor/coverage | 高优先级请求与普通 lookup 冲突时，grant 顺序符合规格并无 starvation | PTW refill、TLBOP、ReqQ、PFU 同拍竞争 | 被 grant source payload 进入 L2TLB | priority checker；fairness watchdog | PTW vs TLBOP；TLBOP vs ReqQ；ReqQ vs PFU | P0 | `test_mmu_dir_l2tlb_bank_write_conflict_*` 粗映射 | Planned | 需按 RTL/规格确认精确优先级 |
| L2TLB_TP_011 | arbiter | 1.4, 2.2 | White-box monitor/coverage | grant source 的 VPN、type、eid、index、write、bank_sel 等 payload 不串源 | 多来源携带不同 payload 后交替 grant | `arb_l2tlb_*` 与 selected source 匹配 | source payload scoreboard | 每类 source payload sample | P0 | 需新增 arbiter payload monitor | Planned | Phase 6 可落到 probe |
| L2TLB_TP_012 | tag/data lookup | 1.4, 1.7, 5.13.3 | Black-box functional | ITLB 4KB L2 single-hit 返回正确 PPN 和 flag，不进入 PTW | backdoor/TLBWI 安装 4KB entry 后 IFU miss | `l2tlb_l1itlb_ref_*` payload 正确 | L2 entry shadow compare | ITLB source；4KB；single-hit | P0 | `test_mmu_dir_l2tlb_tag_match_4k_hit` 粗映射 | Planned | 覆盖 single-hit 结果 |
| L2TLB_TP_013 | tag/data lookup | 1.4, 1.7, 5.13.3 | Black-box functional | DTLB load/store 4KB L2 single-hit 返回对应 eid、PPN、flag | backdoor/TLBWI 安装 4KB entry 后 LSU load/store miss | `l2tlb_l1dtlb_ref_*` eid/type/payload 对齐 | transaction scoreboard | DTLB load；DTLB store；4KB | P0 | `test_mmu_dir_l2tlb_tag_match_4k_hit` 粗映射 | Planned | 覆盖 DTLB load/store source |
| L2TLB_TP_014 | tag/data lookup | 1.4, 1.7, 5.13.8 | Black-box functional | 2MB 和 1GB entry 命中时按 page size mask VPN 并拼接 PA | 安装 2MB/1GB entry，改变页内 offset | 返回 PPN/PA 拼接符合 page size | PA splice checker | 2MB；1GB；offset variation | P0 | `test_mmu_dir_l2tlb_tag_match_2m_1g_huge` 粗映射 | Planned | 覆盖 page size |
| L2TLB_TP_015 | tag/data lookup | 1.2, 1.4, 5.13.8 | Black-box functional | non-global entry 需要 ASID match，global entry 绕过 ASID match | 同 VA 下构造 ASID match/mismatch/global entry | only expected entry hit | ASID/global match checker | global/non-global x ASID match/mismatch | P0 | `test_mmu_rand_l2tlb_tag_match_cross_asid` 粗映射 | Planned | 与 TLBOP invalidate 交叉 |
| L2TLB_TP_016 | lookup pipeline | 1.7, 5.13.8 | Backdoor directed | 构造多个 matching way 时外部 fault 或编码符合规格，且不当作 normal single-hit 更新 | backdoor 或受控 TLBWI/TLBWR 构造 multi-hit | L1/PFU 可见结果合法，内部 multi-hit 被分类 | external result checker；white-box multi-hit cover | multi-hit；ITLB/DTLB/PFU | P1 | `test_mmu_dir_rrpv_multiple_hits_same_vpn` 需重分类 | Planned | 覆盖 multi-hit 结果 |
| L2TLB_TP_017 | miss buffer | overview, 1.5, 2.4 | Black-box functional | lookup miss 且 PTW enabled、MB 有空位时分配 MB 并发 PTW walk | ITLB/DTLB/PFU miss，`cp0_mmu_ptw_en=1` | MB entry valid，`l2tlb_ptw_req` eventually fire | MB shadow；PTW request checker | miss+MB alloc；ITLB/DTLB/PFU | P0 | `test_mmu_dir_l2tlb_mb_alloc_on_miss` 粗映射 | Planned | 覆盖 miss+MB alloc 结果 |
| L2TLB_TP_018 | lookup pipeline | 1.2, 1.7, 5.13.8 | Black-box functional | PTW disabled miss 不发 PTW request，并向 L1/PFU 返回 fault 类完成 | `cp0_mmu_ptw_en=0` 后发 miss | `l2tlb_ptw_req=0`，completion/fault 编码正确 | PTW disabled checker | PTW disabled miss；ITLB/DTLB/PFU | P0 | 需新增 PTW disabled directed | Planned | 覆盖 PTW disabled miss 结果 |
| L2TLB_TP_019 | miss buffer | 1.5, 2.4 | White-box monitor/coverage | MB issue 到 PTW 时 type、VPN、composite ID 保持原始请求归属 | MB alloc 后 PTW ready 拉高 | `l2tlb_ptw_type/vpn/id` 与 MB shadow 一致 | MB to PTW payload checker | MB issue order；ID bins | P0 | `test_mmu_rand_l2tlb_mb_issue_order` 粗映射 | Planned | PTW ID 是后续 SVA 重点 |
| L2TLB_TP_020 | miss buffer | 1.5, 2.4, 5.13.8 | Black-box functional | MB full 时新 miss 不 overflow，不错误覆盖 entry，释放后可继续 | 填满 MB，再发新 miss，然后完成一个 PTW | occupancy 有界，新请求最终 retry 或完成 | no-overflow checker；retry scoreboard | MB full；release then replay | P0 | `test_mmu_dir_l2tlb_mb_full_stall` 粗映射 | Planned | 覆盖 MB full retry 结果 |
| L2TLB_TP_021 | miss buffer | 2.4, 5.9, 5.13.6 | Black-box functional | 相同 VPN/ASID/type 的多个 miss 已分配到 MB 后不自动 merge，也不在发 PTW 前重新 lookup | 连续构造相同 VPN/ASID/type miss，使其进入不同 MB entry | 每个 valid MB entry 按自身 id/type issue PTW；ReqQ replay 的请求可因后续 refill 命中 | duplicate lifetime checker；PTW issue count checker | duplicate allocated entries；ReqQ replay after refill | P1 | `test_mmu_dir_l2tlb_mb_dup_alloc_prevention` 需重审/改名 | Planned | 修正：规格说明不要求 duplicate suppression |
| L2TLB_TP_022 | miss buffer | 1.5, 2.4 | White-box monitor/coverage | PTW completion dealloc 与新 miss alloc 同拍时 occupancy 和 ID 无 double free/lost alloc | 构造 completion 与 new miss 同拍 | MB valid vector 与 shadow 一致 | alloc/dealloc accounting checker | same-cycle alloc/dealloc | P1 | `test_mmu_dir_l2tlb_mb_dealloc_on_complete` 需加强 | Planned | Phase 6 monitor 必须可采样 |
| L2TLB_TP_023 | PTW interface | 1.5, 5.13.8 | Black-box functional | `ptw_ready` backpressure 期间 PTW request payload 稳定，ready 后 fire | MB issue 时拉低再释放 `ptw_ready` | request 保持，ready 后 handshake | PTW handshake checker | ready stall；ready release | P0 | PTW tests 可粗映射，L2 directed 需新增 | Planned | 外部 fairness 与 DUT progress 分开 |
| L2TLB_TP_024 | PTW refill | overview, 1.5, 1.7 | Black-box functional | PTW data completion 对 ITLB/DTLB/PFU miss 归属正确，合法 refill 或 final response | PTW 返回 `data_vld` completion | L2 refill write 与 L1/PFU final response ID/type 对齐 | PTW transaction scoreboard | PTW refill source；ITLB/DTLB/PFU | P0 | PTW directed tests 粗映射 | Planned | 覆盖 PTW refill source |
| L2TLB_TP_025 | PTW refill | 1.5, 1.7, 5.13.8 | Black-box functional | PTW page fault completion 不消费 payload，fault 归属原始请求 | PTW 返回 `pgflt` | L1/PFU fault completion 正确，不写入有效 translation | fault ownership checker | PTW page fault；ITLB/DTLB/PFU | P0 | PTW fault tests 粗映射 | Planned | 覆盖 PTW page fault 结果 |
| L2TLB_TP_026 | PTW refill | 1.5, 1.7, 5.13.8 | Black-box functional | PTW access error completion 不消费 payload，fault 归属原始请求 | PTW 返回 `acc_err` | L1/PFU access error 或 error completion 正确 | access error checker | PTW access error；ITLB/DTLB/PFU | P0 | PTW accerr tests 粗映射 | Planned | 覆盖 PTW access error 结果 |
| L2TLB_TP_027 | PTW interface | 1.5, 5.13.8 | Negative assertion | 非法 completion 组合、bad ID、无 outstanding completion 不进入普通功能比较 | negative PTW completion injection | assertion 或 error-handling 触发，未定义 payload 不比较 | negative protocol checker | bad ID；illegal data_vld/pgflt/acc_err | P1 | 需新增 negative suite | Planned | 普通随机不生成 |
| L2TLB_TP_028 | PFU | 1.2, 1.8, 1.10 | Black-box functional | MMU off PFU 走 direct/sysmap/PMP 路径，不做普通 L2 lookup | `l1dtlb_xx_mmu_off=1`，`lsu_mmu_va2_vld` | `mmu_lsu_pa2` direct，sec/share/err 来自 sysmap/PMP 规则 | PFU direct path checker | PFU source；MMU off | P0 | 需新增 PFU directed | Planned | 覆盖 PFU source |
| L2TLB_TP_029 | PFU | 1.2, 1.8, 1.10, 5.13.5 | Black-box functional | MMU on PFU L2 hit 后做 flag、privilege、MXR/SUM/MPRV/MPP、MAEE、PMP/sysmap 检查 | PFU request 命中 L2 entry | `pa2_vld/pa2_err/sec/share` 符合 PFU 规则 | PFU hit path checker | PFU L2 hit；permission pass | P0 | 需新增 PFU L2-hit directed | Planned | 不与 L1 permission checker 混淆 |
| L2TLB_TP_030 | PFU | 1.5, 1.8, 5.13.5 | Black-box functional | PFU miss 后 PTW data completion 使用 PTW 结果完成 PFU，不做二次 L2 lookup | PFU miss，PTW 返回 data_vld | PFU final response 与 PTW result 对齐 | PFU PTW path checker | PFU miss；PTW data_vld | P0 | 需新增 PFU PTW directed | Planned | PFU 三路径之一 |
| L2TLB_TP_031 | PFU | 1.2, 1.8, 5.13.5 | Black-box functional | PFU flag fault 产生 error completion，error 时 PA/sec/share 不作为比较对象 | 构造 flag 不满足 PFU 权限 | `mmu_lsu_pa2_vld=1` 且 `pa2_err=1` | PFU error classifier | PFU flag fault | P0 | 需新增 PFU fault directed | Planned | 覆盖 PFU flag fault 结果 |
| L2TLB_TP_032 | PFU | 1.10, 5.13.5 | Black-box functional | PMP 或 sysmap deny/fault 使 PFU 返回 error，不污染成功 payload 检查 | PMP/sysmap 返回 deny/fault | `pa2_err=1`，deny 类型可分类 | PMP/sysmap deny checker | PFU PMP deny；PFU sysmap deny | P0 | 需新增 PFU PMP/sysmap directed | Planned | 覆盖 PFU PMP/sysmap deny 结果 |
| L2TLB_TP_033 | PFU | 1.8, 5.13.5 | Black-box functional | PFU error 时只检查 valid/error 与分类，忽略 PA/sec/share payload 值 | PFU flag fault、PTW fault、PMP/sysmap deny | 不因 error payload 随机值误报 mismatch | payload ignore checker | PFU error payload bins | P0 | 需新增 scoreboard rule | Planned | Phase 4 会细化模型 |
| L2TLB_TP_034 | TLB operation | overview, 1.9, 5.13.4 | Black-box functional | TLBP 对 valid、invalid、multi-hit、page-size 条件返回 probe 结果 | CP0/CSR TLBP request | `l2tlb_tlboper_va_hit/sel` 与预期一致 | TLBP scoreboard | TLBP source；hit/miss/multi-hit | P0 | TLBOP wrapper 需新增或加强 | Planned | 覆盖 TLBP source |
| L2TLB_TP_035 | TLB operation | 1.9, 5.13.4 | Black-box functional | TLBR 按 index/way 读出 raw tag/data fields，invalid 也可读 raw 状态 | CP0/CSR TLBR request | readback fields 与 shadow 对齐 | TLBR raw read checker | TLBR source；valid/invalid | P0 | TLBOP wrapper 需新增或加强 | Planned | 覆盖 TLBR source |
| L2TLB_TP_036 | TLB operation | 1.4, 1.9, 5.13.4 | Black-box functional | TLBWI 按指定 index/way 写 valid 或 invalid entry，后续 lookup/TLBP 观察自然结果 | CP0/CSR TLBWI request | tag/data 更新，L1/uTLB clear side effect 合法 | TLBWI shadow update checker | TLBWI source；valid/invalid；illegal pgs natural behavior | P0 | TLBOP write wrapper 需新增 | Planned | 覆盖 TLBWI source |
| L2TLB_TP_037 | TLB operation | 1.3, 1.4, 1.9, 5.13.7 | Black-box functional | TLBWR 使用 DUT replacement 写入后，只检查功能可见结果，不比较 exact victim | CP0/CSR TLBWR request | 后续 lookup/TLBP/TLBR 能观察写入或合法替换结果 | functional result checker | TLBWR source；free-way pressure；max-RRPV pressure | P0 | RRPV victim wrapper 需重分类 | Planned | 覆盖 TLBWR source |
| L2TLB_TP_038 | TLB operation | overview, 1.9, 5.13.4 | Black-box functional | INVVA_ALL 按 VA/page size 失效，不要求 ASID match，global 和 non-global 都可被清 | CP0/CSR INVVA_ALL request | matching VA entries invalid，non-matching 保留 | invalidate shadow checker | INVVA_ALL source；ASID mismatch；global | P0 | `test_mmu_dir_l2tlb_inv_va` 粗映射 | Planned | 覆盖 INVVA_ALL source |
| L2TLB_TP_039 | TLB operation | overview, 1.9, 5.13.4 | Black-box functional | INVASID 扫描所有 set，只清 matching ASID 的 non-global entry，global 保留 | CP0/CSR INVASID request | target ASID non-global invalid，global remains | invalidate shadow checker | INVASID source；hit set；no-hit set | P0 | `test_mmu_dir_l2tlb_inv_asid` 粗映射 | Planned | 覆盖 INVASID source |
| L2TLB_TP_040 | TLB operation | overview, 1.9, 5.13.4 | Black-box functional | INVVA_ASID 清目标 ASID non-global 和同 VA global entry | CP0/CSR INVVA_ASID request | matching entries invalid，其他 ASID non-global 保留 | invalidate shadow checker | INVVA_ASID source；global clear | P0 | `test_mmu_dir_l2tlb_inv_va_asid` 粗映射 | Planned | 覆盖 INVVA_ASID source |
| L2TLB_TP_041 | TLB operation | overview, 1.9, 5.13.4 | Black-box functional | INVALL 扫描全部 set/way 清 valid tag，并清理 L1/uTLB 与 outstanding PTW/MB side effect | CP0/CSR INVALL request | L2 all-invalid，done after scan，相关 abort/clear 生效 | all-invalid checker；scan progress monitor | INVALL source；all set scan；abort side effect | P0 | `test_mmu_dir_l2tlb_inv_all` 粗映射 | Planned | 覆盖 INVALL source 和 reset/abort |
| L2TLB_TP_042 | TLB operation | 1.9, 5.13.4 | White-box monitor/coverage | TLBOP request、grant、pipeline cmplt、source done 不得 early、missing 或 duplicate | TLBP/TLBR/TLBWI/TLBWR/INV* directed | done 与 operation lifecycle 一一对应 | TLBOP ordering checker | all TLBOP types；done latency bins | P0 | TLBOP wrapper 需统一 metadata | Planned | Phase 3 SVA 候选 |
| L2TLB_TP_043 | TLB operation | 1.1, 1.9, 5.13.8 | Black-box functional | TLBOP 执行中 reset 时 pending 操作清空，reset 后模型 all-invalid | TLBOP scan/write 中拉 reset | 无旧 done 被消费，新请求正常 | reset plus TLBOP checker | reset during TLBP/TLBWI/INVALL | P0 | 需新增 TLBOP reset directed | Planned | reset 与 TLBOP 交叉 |
| L2TLB_TP_044 | abort | overview, 1.9, 2.4, 5.13.6 | Black-box functional | `tlboper_ptw_abort` 清理或重发受影响 MB/PTW，stale completion 不写回旧 translation | outstanding PTW/MB 期间触发 invalidate abort | stale PTW completion ignored，合法 reissue/drain | stale completion checker | abort sent MB；abort unsent MB；late completion | P0 | MB/INV wrapper 需加强 | Planned | 覆盖 abort 结果类型 |
| L2TLB_TP_045 | RRPV SRAM | 1.3, 1.4, 5.13.7 | White-box monitor/coverage | PTW refill、TLBWI/TLBWR 写有效 entry 时 RRPV 初始化行为可观察，但 v1 不以 exact 值做 pass/fail | refill/write 压力场景 | 功能可见 lookup 正确，RRPV sample 进入 debug coverage | functional checker；debug RRPV sampler | refill init；TLBWI/TLBWR init | P1 | `test_mmu_dir_rrpv_init_*` 需重分类 | Planned | 不做 exact RRPV oracle |
| L2TLB_TP_046 | RRPV wbuf | 1.1, 1.3, 5.13.7 | White-box monitor/coverage | hit aging 与 refill 压力下 wbuf 不 overflow，full 时不得错误 grant 新 RRPV 更新 | high hit/refill pressure | no overflow，full stall 行为可分类 | wbuf no-overflow checker | wbuf full stall；hit promote pressure | P1 | `test_mmu_rand_rrpv_wbuf_no_overflow` 粗映射 | Planned | 可作为 debug assertion |
| L2TLB_TP_047 | replacement | 1.3, 1.4, 5.13.7 | White-box monitor/coverage | victim/free-way/max-RRPV 行为 v1 只看写入后的功能结果，exact victim 留到 future 专项 | free-way 与 max-RRPV 压力 | 后续 lookup/TLBP/TLBR/invalidate 功能结果可解释 | functional visible checker | replacement pressure；future exact victim bins | P2 | `test_mmu_dir_rrpv_victim_*` 需重分类 | Planned | Future replacement 专项 |
| L2TLB_TP_048 | illegal input | 5.13.8 | Negative assertion | 非法 access type、协议非法 page size、bad completion ID、credit overflow 不进入普通功能测试 | isolated negative injection | assertion 或 error-handling 触发，功能结果不比较 | negative checker | bad type；bad pgs；bad ID；credit overflow | P1 | 需新增 negative suite | Planned | 普通随机必须保持协议合法 |
| L2TLB_TP_049 | timeout/fairness | 5.13.8 | Black-box functional | PTW ready wait、MB retry、TLBOP scan、wbuf stall 的 timeout 区分 TB fairness 与 DUT progress | backpressure 后 release 的 directed 场景 | fairness 满足后 eventually complete，否则分类报错 | timeout classifier | PTW wait；MB retry；TLBOP scan；wbuf stall | P0 | 需新增 scoreboard policy | Planned | 覆盖 timeout |
| L2TLB_TP_050 | coverage closure | 5.13.8 | White-box monitor/coverage | source、result、page-size、ASID/global、control/reset/abort 覆盖矩阵收口或 waiver | audit regression list | coverage report 与 waiver 对齐 | traceability matrix checker | all required source/result bins | P0 | `l2tlb_tests` audit run list 需建立 | Planned | Phase 2 Excel 同步项 |
| L2TLB_TP_051 | arbiter/PTW refill | 2.3, 5.9, 5.13.8 | White-box monitor/coverage | PTW read grant 后 `ptw_on` 阻塞非 PTW write 请求，直到 PTW write 被接收后释放 | PTW refill read/write 与 ReqQ/PFU/TLBOP 同时竞争 | `ptw_on=1` 窗口内只有对应 PTW write 可获 grant，释放后其他 source 可继续 | ptw_on exclusion checker；grant sequence checker | ptw_on stall；PTW read-to-write sequence | P0 | `test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior` 需加强 | Planned | 覆盖 ptw_on stall |
| L2TLB_TP_052 | arbiter/TLBOP | 2.3, 5.13.8 | White-box monitor/coverage | TLBOP 获 grant 后 `tlboper_on` 阻塞 ReqQ/PFU/PTW read，直到 tlb operation done | 扫描类 INVALL/INVASID 与普通 lookup/PTW/PFU 竞争 | `tlboper_on=1` 窗口内不 grant 非 TLBOP 请求，done 后恢复 | tlboper_on exclusion checker；done release checker | tlboper_on stall；scan done release | P0 | `test_mmu_dir_l2tlb_bank_write_conflict_tlbop_prior` 需加强 | Planned | 覆盖 tlboper_on stall |
| L2TLB_TP_053 | PFU/arbiter | 2.3, 5.8, 5.13.8 | Black-box functional | MMU-on PFU request 获 grant 后 `prefetch_mask` 阻止同一持续 `lsu_mmu_va2_vld` 重复获 grant，直到 response 或 MB-full replay 边界 | PFU request 保持 valid，构造 hit、fault、MB full retry 三类结果 | 每笔 PFU 只接受一次；mask 在 `pa2_vld/pa2_err` 或 retry 条件后释放 | PFU accept counter；prefetch_mask release checker | prefetch_mask hit release；error release；retry release | P0 | 需新增 PFU mask directed | Planned | 覆盖 prefetch_mask retry |
| L2TLB_TP_054 | arbiter/index | 2.2, 2.3, 5.13.8 | White-box monitor/coverage | VA[31:30] selector 与 page size 组合生成正确 skew index 和候选 bank mask | 构造 4 个 selector x 3 个 page size 的 lookup/PTW refill read | lookup 访问 all-bank；PTW read 的 `arb_l2tlb_bank_sel` 符合 mask_bank_sel 表 | index/bank mask sampler；hash/index consistency checker | selector 00/01/10/11 x 4KB/2MB/1GB | P1 | `test_mmu_dir_l2tlb_bank_skew_distribution` 粗映射 | Planned | 不要求 v1 hard close exact hash，至少 debug cover |
| L2TLB_TP_055 | miss buffer | 2.4, 5.9 | Black-box functional | MB full 判断按 source 分区：ITLB 只看 entry0，DTLB/PFU 只看 entry1-entry8 | 分别填满 entry0 或 entry1-entry8 后发 ITLB/DTLB/PFU miss | ITLB 不借用 1..8；DTLB/PFU 不借用 entry0；可用分区内仍能分配 | MB partition checker | ITLB full；DTLB/PFU full；cross-partition non-blocking | P0 | `test_mmu_dir_l2tlb_mb_full_stall` 需拆分加强 | Planned | 比现有 TP_020 更细的 full 边界 |
| L2TLB_TP_056 | PTW interface | 1.5, 5.9 | Black-box functional | 多个 sent MB entry 的 PTW completion 可乱序返回，必须只按 composite ID 释放和归属 | issue 多个 ITLB/DTLB/PFU miss 后乱序返回 completion | 对应 MB entry 释放，原始 L1/PFU ownership 正确，不依赖 issue 顺序 | PTW ID scoreboard；out-of-order completion checker | out-of-order data_vld；fault；mixed type | P0 | PTW tests 粗映射，L2 directed 需新增 | Planned | 补足 PTW ID 乱序语义 |
| L2TLB_TP_057 | PFU | 5.8, 1.10 | Black-box functional | PMP `{L,X,W,R}` 与 sysmap `{SO,C,B,Share,Sec}`、MAEE 属性选择按 truth table 产生 PFU allow/deny/sec/share | 构造 MMU-off、MMU-on hit、PFU PTW completion 三路径的 PMP/sysmap/MAEE 组合 | `pa2_vld/pa2_err/sec/share` 与有效 privilege、MAEE、PMP lock 规则一致 | PFU attribute truth-table checker | PMP R/L combos；sysmap SO/C；MAEE 0/1 | P0 | 需新增 PFU truth-table directed | Planned | 细化 TP_029/032 |
| L2TLB_TP_058 | control hazard | 5.9, 5.13.8 | Negative assertion | outstanding translation/PTW 存在时 SATP/ASID/control 改写必须先 drain/flush/abort；负向只检查 assertion/error handling | outstanding MB/PTW 期间注入 SATP/ASID/control 改写 | 普通测试不生成；负向测试期望 assertion 或 error classification | control hazard assertion checker | SATP write；ASID write；MMU/PTW enable change | P1 | 需新增 negative suite | Planned | 不作为正常功能 coverage |

### 6.3 Phase 2 覆盖检查摘要

| 检查项 | 覆盖测试点 |
| --- | --- |
| Source 类型：ITLB、DTLB load、DTLB store、PFU、PTW refill | L2TLB_TP_004, L2TLB_TP_005, L2TLB_TP_012, L2TLB_TP_013, L2TLB_TP_017, L2TLB_TP_024, L2TLB_TP_028..033 |
| Source 类型：TLBP、TLBR、TLBWI、TLBWR | L2TLB_TP_034..037 |
| Source 类型：INVALL、INVASID、INVVA_ALL、INVVA_ASID | L2TLB_TP_038..041 |
| Result 类型：single-hit、miss+MB alloc、MB full retry、PTW disabled miss、multi-hit | L2TLB_TP_012..018, L2TLB_TP_020 |
| Result 类型：PTW page fault、PTW access error、PFU flag fault、PFU PMP/sysmap deny | L2TLB_TP_025, L2TLB_TP_026, L2TLB_TP_031, L2TLB_TP_032, L2TLB_TP_057 |
| Result 类型：reset、abort、timeout | L2TLB_TP_001, L2TLB_TP_002, L2TLB_TP_043, L2TLB_TP_044, L2TLB_TP_049, L2TLB_TP_051..053 |
| RRPV/victim/wbuf 边界 | L2TLB_TP_045..047 |
| Arbiter 阻塞状态：ptw_on、tlboper_on、prefetch_mask | L2TLB_TP_051..053 |
| Skew/index/bank mask 与 selector | L2TLB_TP_054 |
| MB 分区 full 与 PTW 乱序 completion | L2TLB_TP_055, L2TLB_TP_056 |
| PFU 属性 truth table 与 control hazard | L2TLB_TP_057, L2TLB_TP_058 |
| 非法输入负向测试 | L2TLB_TP_027, L2TLB_TP_048, L2TLB_TP_058 |

## 7. Phase 3 L2TLB SVA Requirement

本章为 Phase 3 补充的 L2TLB SVA 需求清单。前文功能描述、5.13 UVM 策略问答和第 6 章 Phase 2 测试点仍是来源依据；本章只定义 assertion/cover property 需求，不要求本阶段已经编写或绑定 SystemVerilog SVA 文件。

### 7.1 Phase 3 边界

- `must`：影响顶层协议、功能正确性或非法输入约束的 assertion，v1 UVM 实现阶段必须实现或给出 waiver。
- `debug`：white-box 调试、coverage 或微架构定位增强项，不阻塞 v1 transaction-level 主功能环境成型。
- `future`：replacement/RRPV exact model 等后续专项验证项，不纳入 v1 必须实现范围。
- 普通功能随机和 directed sequence 只产生协议合法输入；非法 access type、bad PTW completion ID、credit overflow、多 TLB operation 同时驱动等场景只放入负向 assertion/error-handling tests。
- 负向测试只检查 assertion 或 error handling 是否触发，不比较未定义功能结果。
- reset 类 property 需要明确 reset assert 与 reset release 两类采样窗口；普通时序 property 默认使用 `disable iff (!cpurst_b)`。

### 7.2 SVA Requirement 矩阵

| SVA ID | 分类 | 关联测试点/风险 | 检查目标 | 触发条件 | 禁止/要求行为 | 绑定对象 | 采样信号 | reset disable | cover property |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| L2TLB_SVA_001 | must | L2TLB_TP_001, L2TLB_TP_002, L2TLB_TP_043 | reset 清空可观测 L2TLB 活跃状态 | `cpurst_b` assert 或 release 后第一个稳定采样窗口 | ReqQ/MB/PTW/PFU/TLBOP/pipeline valid 不得保留旧 transaction，不得产生伪 request/refill/fault | `ct_mmu_top` 或 `mmu_l2tlb`，必要时经 `mmu_dut_probes_if` 采样 | `l2_reqq_vld_vec`, `l2mb_vld_vec`, `l2tlb_ptw_req`, `ptw_l2tlb_cmplt`, `mmu_lsu_pa2_vld`, TLBOP done/abort 观察点 | reset assert 检查不使用 `disable iff`；release 后使用 `disable iff (!cpurst_b)` | 需要，覆盖 cold reset 与 warm reset |
| L2TLB_SVA_002 | must | L2TLB_TP_001, L2TLB_TP_002 | reset-inv 完成边界 | reset release 后到 `ifu_cp0_rst_inv_req -> cp0_mmu_tlb_all_inv -> mmu_cp0_tlb_done -> cp0_ifu_rst_inv_done` 完成前 | 不允许普通 IFU/LSU/PFU translation 进入可检查窗口；若进入则按协议违规报错 | `ct_mmu_top` | reset-inv request/done、IFU/LSU VA valid、PFU valid | `disable iff (!cpurst_b)`，release 后生效 | 需要，覆盖 reset-inv wait 与完成后首笔请求 |
| L2TLB_SVA_003 | must | L2TLB_TP_004, L2TLB_TP_005, L2TLB_TP_048 | L1 到 L2TLB request pulse 宽度 | `i_req_valid` 或 `d_req_valid` 为 1 | 合法请求必须是 1-cycle pulse；持续多拍 valid 属协议违规 | `mmu_l2tlb` 或 `mmu_l2tlb_reqq` | `i_req_valid`, `d_req_valid`, VPN/eid/type | `disable iff (!cpurst_b)` | 可选，覆盖 ITLB/DTLB request pulse |
| L2TLB_SVA_004 | must | L2TLB_TP_004, L2TLB_TP_005, L2TLB_TP_048 | credit 协议合法性 | L1 request、credit return、entry full/empty 更新 | 无 credit 时不得发新请求；credit counter 不得 overflow/underflow；同拍 request+return 按协议抵消但不得依赖同拍复用未释放 entry | `ct_mmu_top`、`mmu_l2tlb_reqq` 或 credit checker bind | L1 credit count、`i_req_valid`, `d_req_valid`, `i_credit_return`, `d_credit_return`, ReqQ valid/rdy | `disable iff (!cpurst_b)` | 需要，覆盖 return、consume、同拍抵消 |
| L2TLB_SVA_005 | must | L2TLB_TP_009, L2TLB_TP_010, L2TLB_TP_051..053 | arbiter grant onehot 与阻塞源隔离 | 多 source 请求同拍存在，或 ptw/tlboper/wbuf/prefetch mask active | 每拍最多一个 source 获 grant；被 block 的 source 不得 grant；payload 只来自获 grant source | `mmu_arb` | PTW/TLBOP/ReqQ/PFU request/grant、`arb_l2tlb_req`, `arb_l2tlb_acc_type`, block flags | `disable iff (!cpurst_b)` | 需要，覆盖 pairwise 与 four-source conflict |
| L2TLB_SVA_006 | debug | L2TLB_TP_010, L2TLB_TP_051, L2TLB_TP_052 | 无阻塞时 arbitration priority 可观测 | PTW、TLBOP、ReqQ、PFU 同拍竞争且无 block 条件 | grant 顺序应满足 `PTW > TLBOP > ReqQ > PFU`；若 RTL 规格确认不同，Phase 6 实现前必须更新本条 waiver/规则 | `mmu_arb` | source request/grant、block flags、selected payload | `disable iff (!cpurst_b)` | 需要，覆盖每组优先级 |
| L2TLB_SVA_007 | must | L2TLB_TP_004, L2TLB_TP_005, L2TLB_TP_055 | ReqQ source 分区 | ITLB/DTLB alloc 或 issue | ReqQ entry0 只服务 ITLB；entry1..8 只服务 DTLB load/store；issue type/eid 不得串源 | `mmu_l2tlb_reqq` | `i_req_valid`, `d_req_valid`, entry valid/rdy, issue_queue_id, issue_type, issue_eid | `disable iff (!cpurst_b)` | 需要，覆盖 ITLB entry0 与 DTLB entries |
| L2TLB_SVA_008 | must | L2TLB_TP_007, L2TLB_TP_020 | ReqQ no-overflow 与 feedback ID 合法 | ReqQ full、feedback valid、miss retry/replay | full 时不得覆盖 valid entry；feedback ID 必须命中 outstanding entry；retry 必须保留请求生命周期用于后续 replay | `mmu_l2tlb_reqq` | entry valid/sent/rdy、`fb_valid`, `fb_trans_id`, `fb_miss_retry`, issue signals | `disable iff (!cpurst_b)` | 需要，覆盖 MB full retry 与 release then replay |
| L2TLB_SVA_009 | must | L2TLB_TP_017, L2TLB_TP_020, L2TLB_TP_055 | MB 分区 full 与 alloc 合法性 | L2 miss 需要 MB alloc | ITLB 只使用 MB entry0；DTLB/PFU 只使用 entry1..8；对应分区 full 时不得 overflow 或覆盖 valid entry | `mmu_l2tlb_mb` | `req_valid`, `req_is_dtlb`, `req_alloc_valid`, MB entry valid/rdy/sent, alloc onehot | `disable iff (!cpurst_b)` | 需要，覆盖 ITLB full、DTLB/PFU full、cross-partition non-blocking |
| L2TLB_SVA_010 | must | L2TLB_TP_019, L2TLB_TP_022, L2TLB_TP_056 | MB alloc/dealloc 与 payload accounting | 新 miss alloc 与 PTW completion dealloc 同拍或相邻拍 | 不得 double-free、lost-alloc 或错误释放；VPN/type/eid/queue_id 在 alloc、issue、completion 生命周期内保持归属 | `mmu_l2tlb_mb` | MB valid/rdy/sent、entry VPN/type/eid/queue_id、`fb_valid`, `fb_trans_id`, issue req/id/type/vpn | `disable iff (!cpurst_b)` | 需要，覆盖 same-cycle alloc/dealloc 与乱序 completion |
| L2TLB_SVA_011 | must | L2TLB_TP_023 | PTW request ready backpressure payload 稳定 | `l2tlb_ptw_req=1` 且 `ptw_ready=0` | PTW request 的 id/type/vpn 必须保持稳定直到 ready/fire；ready 后 handshake 只能消费一笔 | `mmu_l2tlb` 或 `mmu_l2tlb_mb` | `l2tlb_ptw_req`, `ptw_ready`, `l2tlb_ptw_id`, `l2tlb_ptw_type`, `l2tlb_ptw_vpn` | `disable iff (!cpurst_b)` | 需要，覆盖 ready stall 与 release |
| L2TLB_SVA_012 | must | L2TLB_TP_024..027 | PTW completion 结果组合合法 | `ptw_l2tlb_ref_cmplt` 或 completion result bits 变化 | `ref_data_vld/ref_pgflt/ref_acc_err` 在 completion 时必须合法互斥或唯一有效；`cmplt=0` 时三者必须为 0 | `mmu_l2tlb` 或 PTW/L2TLB interface bind | `ptw_l2tlb_ref_cmplt`, `ptw_l2tlb_ref_data_vld`, `ptw_l2tlb_ref_pgflt`, `ptw_l2tlb_ref_acc_err` | `disable iff (!cpurst_b)` | 需要，覆盖 data/page-fault/access-error |
| L2TLB_SVA_013 | must | L2TLB_TP_027, L2TLB_TP_056 | PTW completion ID/type 匹配 outstanding MB | PTW completion 到达 | completion ID/type 必须匹配 valid outstanding MB entry；bad ID、无 outstanding completion 属负向 assertion 场景，不进入普通功能比较 | `mmu_l2tlb` 与 `mmu_l2tlb_mb` 组合采样，或经 probe checker | `ptw_l2tlb_ref_id`, `ptw_l2tlb_ref_type`, MB valid/sent/type/eid | `disable iff (!cpurst_b)` | 需要，覆盖 out-of-order valid/fault completion |
| L2TLB_SVA_014 | must | L2TLB_TP_014, L2TLB_TP_016, L2TLB_TP_018 | terminal fault 不得错误 retry | final stage 出现 ReqQ multi-hit，或 ReqQ miss 且 PTW disabled | multi-hit 与 PTW disabled miss 必须释放对应 ReqQ entry 并返回 fault/complete，不得因 MB full 被错误 retry 或卡住 sent entry | `mmu_l2tlb` | `final_vld`, `final_cmp_with_va`, `final_acc_type`, `final_tlb_hit_mult`, `l2tlb_miss`, `cp0_mmu_ptw_en`, `l2tlb_reqq_fb_*` | `disable iff (!cpurst_b)` | 需要，覆盖 multi-hit 和 PTW disabled miss |
| L2TLB_SVA_015 | must | L2TLB_TP_034..043 | TLBOP lifecycle ordering | TLBP/TLBR/TLBWI/TLBWR/INV* request 发起 | request、grant、pipeline cmplt、source done 必须一一对应；不得 early done、missing done、duplicate done；scan/write 类操作 done 必须在必要 L2 行为后产生 | `ct_mmu_tlboper`、`mmu_l2tlb` 或顶层 probe checker | TLBOP request/grant/cmplt/done、`tlboper_utlb_clr`, `tlboper_utlb_inv_va_req`, `tlboper_ptw_abort`, `mmu_lsu_tlb_inv_done`, `mmu_cp0_tlb_done` | `disable iff (!cpurst_b)` | 需要，覆盖所有 TLBOP type 与 done latency |
| L2TLB_SVA_016 | must | L2TLB_TP_041, L2TLB_TP_044 | abort 后 stale completion 隔离 | `tlboper_ptw_abort` 影响 valid/sent MB 或 outstanding PTW | abort 前旧 completion 不得写回旧 translation，不得错误释放新上下文 entry；合法 reissue/drain 后 completion 才可归属 | `mmu_l2tlb_mb`、PTW/L2TLB interface 或 probe checker | `tlboper_ptw_abort`, MB valid/sent/id/type/vpn, `ptw_l2tlb_ref_cmplt/id/type`, refill/write/response signals | `disable iff (!cpurst_b)` | 需要，覆盖 sent/unsent MB 与 late completion |
| L2TLB_SVA_017 | must | L2TLB_TP_058 | SATP/ASID/control hazard 禁止 | SATP、ASID、MMU enable、PTW enable、privilege、SUM/MXR/MPRV/MPP/MAEE 等 control 改写 | control 改写前相关 outstanding translation/PTW 必须已经 drain、flush 或 abort；负向测试只检查 assertion/error handling | `ct_mmu_top` 或 CP0/probe checker | CP0/CSR write strobes、control shadow、ReqQ/MB/PTW outstanding、abort/flush/done | `disable iff (!cpurst_b)` | 需要，覆盖 SATP、ASID、PTW enable、privilege change |
| L2TLB_SVA_018 | must | L2TLB_TP_048 | no-X 协议防护 | 有效 request、write、completion、response、done beat | valid 时关键 payload/control 不得为 X/Z；非法 X 输入属于协议错误，不进入普通功能结果比较 | `ct_mmu_top`, `mmu_l2tlb`, `mmu_l2tlb_reqq`, `mmu_l2tlb_mb` | IFU/LSU VA、ReqQ payload、arb payload、PTW completion、TLBOP payload、L1/PFU response payload | `disable iff (!cpurst_b)` | 可选，覆盖每类 interface valid |
| L2TLB_SVA_019 | debug | L2TLB_TP_051 | `ptw_on` 原子 refill 阻塞 | PTW read grant 后到对应 PTW write accepted 前 | `ptw_on` 窗口只允许对应 PTW write 获 grant；非 PTW write source 不得 grant；write accepted 后释放 | `mmu_arb` 或 probe checker | `ptw_on`, PTW read/write grant, `arb_l2tlb_acc_type`, source grants | `disable iff (!cpurst_b)` | 需要，覆盖 ptw_on stall 与 read-to-write sequence |
| L2TLB_SVA_020 | debug | L2TLB_TP_052 | `tlboper_on` 阻塞 | TLBOP grant 后到 tlb operation done 前 | `tlboper_on` 窗口不得 grant ReqQ/PFU/PTW read；done 后允许恢复其他 source | `mmu_arb` 或 `ct_mmu_tlboper` probe checker | `tlboper_on`, source grants, TLBOP done | `disable iff (!cpurst_b)` | 需要，覆盖 scan done release |
| L2TLB_SVA_021 | debug | L2TLB_TP_053 | PFU `prefetch_mask` 去重与释放 | MMU-on PFU request 被接受后，`lsu_mmu_va2_vld` 持续保持 | 同一持续 PFU request 不得重复 accept；mask 在 `pa2_vld/pa2_err` 或 MB-full retry 边界释放 | `mmu_l2tlb` 或 `mmu_arb` probe checker | `lsu_mmu_va2_vld`, `prefetch_mask`, PFU grant, `mmu_lsu_pa2_vld`, `mmu_lsu_pa2_err`, `l2tlb_arb_pfu_miss_mb_full` | `disable iff (!cpurst_b)` | 需要，覆盖 hit/error/retry release |
| L2TLB_SVA_022 | debug | L2TLB_TP_046 | RRPV wbuf no-overflow/no-wrong-grant | hit aging/refill 压力下 wbuf push/pop/full | wbuf 不得 overflow；full 时不得错误 grant 会产生新 RRPV update 的访问；具体 count 水位不作为 v1 transaction scoreboard 条件 | `mmu_l2tlb_rrpv_wbuf` 或 `mmu_l2tlb` | `push_req`, `pop_grant`, `full`, `empty`, internal count if exposed, `l2tlb_arb_rrpv_wbuf_full` | `disable iff (!cpurst_b)` | 需要，覆盖 full stall 与 hit promote pressure |
| L2TLB_SVA_023 | future | L2TLB_TP_047 | exact victim/free-way/max-RRPV 选择 | TLBWR 或 PTW refill 需要 victim way | 只有建立 cycle-accurate replacement model 后才检查 victim way 是否符合 free-way/max-RRPV/hash/index 规则 | `mmu_l2tlb_replacement_policy` | `entry_vld`, `entry_rrpv`, `mask_way`, `victim_way_out`, `hit/miss/ptw_req` | `disable iff (!cpurst_b)` | future cover，v1 不要求闭合 |
| L2TLB_SVA_024 | future | L2TLB_TP_045, L2TLB_TP_046, L2TLB_TP_047 | RRPV wbuf latest-wins/merge/same-cycle bypass 精确性 | 同 bank/index push、lookup bypass、pop/drain 交叠 | 只有 future replacement 专项建立 RRPV reference model 后，才检查 latest-wins、merge、same-cycle push bypass、invalid entry RRPV drain 等精确行为 | `mmu_l2tlb_rrpv_wbuf` | `push_req`, `push_idx`, `push_vld`, `push_data`, `lookup_req`, `lookup_idx`, `bypassed_rrpv_rdata`, `sram_*` | `disable iff (!cpurst_b)` | future cover，v1 只保留 debug sampling |

### 7.3 must/debug/future 汇总

| 分类 | SVA ID | v1 处理要求 |
| --- | --- | --- |
| must | L2TLB_SVA_001..005, L2TLB_SVA_007..018 | Phase 6 SVA 实现阶段必须实现或逐条给出 waiver。waiver 必须说明替代 checker、不可观测原因或绑定风险。 |
| debug | L2TLB_SVA_006, L2TLB_SVA_019..022 | 建议优先实现为 white-box assertion/cover property，用于定位仲裁、阻塞、PFU mask 和 RRPV wbuf 问题；不阻塞 v1 transaction-level 主功能成型。 |
| future | L2TLB_SVA_023, L2TLB_SVA_024 | 留给 replacement/RRPV exact 专项；v1 不因 exact victim、exact RRPV 或 latest-wins 未检查而 fail。 |

### 7.4 非法输入 SVA 使用规则

- 非法 access type、bad PTW completion ID、completion result 非法组合、credit overflow、多个 TLB operation 同时驱动等协议非法输入不进入普通随机或主功能 directed sequence。
- 负向测试可以定向注入上述非法输入，但 pass/fail 只看对应 `must` assertion 或 error handling 是否触发，不比较 DUT 未定义 payload 或后续功能结果。
- 对 tag/data 中的非法 page size、invalid tag 携带 nonzero payload、multi-hit 等可通过 backdoor 或 TLBWI directed 构造的状态，按测试点说明检查自然功能结果或 debug coverage，不把协议非法激励混入普通功能流量。
- 如果 Phase 6 实现时发现某条 `must` SVA 缺少稳定可绑定信号，必须在 Phase 6 progress 中记录 waiver 或先补 probe，再实现 SVA。

## 8. Phase 4 L2TLB Scoreboard / Reference Model 建模要求

本章为 Phase 4 补充 L2TLB scoreboard 和 reference model 的建模边界。输入依据为前文功能描述、5.13 UVM 策略问答、第 6 章 `L2TLB_TP_001..058` 测试点和第 7 章 `L2TLB_SVA_001..024` SVA requirement。本章只定义后续 UVM 实现必须遵守的建模规则，不要求本阶段修改 SystemVerilog/UVM 行为代码。

### 8.1 Phase 4 边界

- v1 scoreboard 采用 transaction-level reference model。pass/fail 以 MMU 顶层可见 translation request/response、PFU response、PTW completion 归属和软件可见 TLB operation 结果为主。
- ReqQ、miss buffer、lookup pipeline、arbiter block flag、RRPV/write buffer、hash/index/victim 选择不建立 cycle-accurate golden model。它们可以作为 white-box monitor、coverage、debug log 和 SVA 输入。
- L2 direct hit scoreboard 只检查 tag/data/page size/ASID/global/PA payload 等 L2 功能可见结果，不在 L2 层重复判定 L1 permission fault。
- fault 或 no-pavld 场景只比较 completion/fault class，不比较 VPN、PPN、flags 等 payload，避免把无效 payload 当成功能 mismatch。
- PTW miss、PTW completion、L2 refill、L1/PFU 最终响应必须在完整 MMU transaction scoreboard 中归属，不允许只在 `mmu_l2tlb` direct response 端口做局部判断。
- reset 拉低时清空所有 pending expectation 和寄存器型 shadow；reset-inv 完成后，L2 entry shadow 按 all-invalid 重建。
- illegal input 只进入负向 assertion/error-handling 测试。普通 scoreboard 不比较协议非法输入导致的未定义功能结果。

### 8.2 v1 Transaction Pass/Fail 范围

| 范围 | 输入事务 | 期望输出 | 不检查项 | 关联测试点/SVA |
| --- | --- | --- | --- | --- |
| IFU/LSU L2 direct hit | 顶层 IFU/LSU request，L2 hit 观察点，L2 entry shadow | hit 后返回正确 page size、PPN/PA payload、completion/fault class | L1 permission fault、exact way aging、RRPV update | L2TLB_TP_012, L2TLB_TP_013, L2TLB_SVA_014 |
| IFU/LSU miss + PTW | L2 miss、MB alloc、PTW request、PTW completion、L1 final response | 原 request owner 最终收到 refill、page fault 或 access error；completion ID/type 归属正确 | PTW latency cycle accuracy、MB exact entry 选择以外的微架构状态 | L2TLB_TP_017..027, L2TLB_TP_056, L2TLB_SVA_009..013 |
| PFU MMU-off direct | `lsu_mmu_va2_vld`、MMU disabled/control shadow、PMP/sysmap shadow | `pa2_vld/pa2_err/sec/share` 与 direct-map PMP/sysmap/MAEE 规则一致 | L2 tag/data lookup、RRPV、MB | L2TLB_TP_028, L2TLB_TP_057 |
| PFU MMU-on L2 hit | PFU accepted request、L2 entry shadow、PMP/sysmap shadow | hit path 完成 PFU flag/PMP/sysmap 判定，返回 allow/deny/sec/share | L1 permission model、exact RRPV aging | L2TLB_TP_029..032, L2TLB_TP_053, L2TLB_TP_057 |
| PFU MMU-on PTW completion | PFU miss、MB/PTW shadow、PTW completion、PMP/sysmap shadow | completion 归属 PFU owner，最终 `pa2_vld/pa2_err` 与 PTW/PMP/sysmap 结果一致 | refill 后二次查表 cycle 行为 | L2TLB_TP_033, L2TLB_TP_056, L2TLB_TP_057 |
| TLBP/TLBR | CP0/TLBOP request，L2 entry shadow | TLBP hit/miss 与 index/entry 内容可见结果正确；TLBR 读出软件可见字段 | invalid entry 的 stale data 是否为 0，exact scan latency | L2TLB_TP_034, L2TLB_TP_035, L2TLB_SVA_015 |
| TLBWI/TLBWR | CP0/TLB write request，TLBOP done | L2 entry shadow 被写入或覆盖，后续 lookup/TLBP/TLBR 结果匹配 | TLBWR exact victim/RRPV/free-way 选择 | L2TLB_TP_036, L2TLB_TP_037, L2TLB_TP_047 |
| INVALL/INVASID/INVVA_ALL/INVVA_ASID | LSU/CP0 invalidate request，TLBOP done | L2 entry shadow 中匹配 entry 失效；后续 lookup/TLBP miss 或 TLBR visible state 符合预期 | RRPV 是否清零、每个 invalid write beat 的 exact timing | L2TLB_TP_038..041, L2TLB_SVA_015, L2TLB_SVA_016 |
| reset/abort/control hazard | reset、reset-inv、PTW abort、SATP/ASID/control change | pending expectation 清空或被合法 abort；stale completion 不污染新上下文 | reset 内部扫描 exact latency，非法 hazard 后未定义 payload | L2TLB_TP_001, L2TLB_TP_002, L2TLB_TP_043, L2TLB_TP_044, L2TLB_TP_058 |
| timeout/fairness | ready/backpressure/full/stall 场景 | TB fairness 满足后 DUT eventually complete；否则按分类报错 | 固定最大微架构 latency，外部永久 backpressure 下的 DUT forward progress | L2TLB_TP_049, L2TLB_TP_051..053 |

### 8.3 Reference Model 状态影子

| Shadow | 维护内容 | 输入更新源 | 输出/使用者 | 不检查项 |
| --- | --- | --- | --- | --- |
| L2 entry shadow | per entry valid、VPN/tag、ASID、G、PGS、PPN、flags；tag.valid=0 时功能视为 invalid | backdoor directed 初始化、TLBWI、TLBWR、PTW refill、INV*、reset-inv complete | L2 lookup hit/miss、TLBP/TLBR、invalidate 后续检查、direct hit payload 比较 | exact physical SRAM bank/index timing；invalid entry stale data/RRPV |
| ReqQ shadow | 已接受的 IFU/DTLB request 生命周期、source、VPN、type、eid、queue owner、retry 状态 | IFU/LSU monitor accepted request、credit return、ReqQ feedback、reset/abort | 检查请求未丢失、MB full retry 后可重发、credit/owner 归属 | 每拍 grant priority、ReqQ entry exact age、internal sent/rdy cycle accuracy |
| Miss buffer shadow | miss owner、source、VPN、type、l1 eid、queue id、PTW composite ID、sent/aborted/dealloc 状态 | L2 miss allocation、PTW request fire、PTW completion、TLBOP abort、reset | PTW completion ID/type 归属、L1/PFU 最终 response 归属、out-of-order completion 检查 | exact entry victim 选择以外的内部时序；sent bit 每拍波形 |
| PTW transaction shadow | L2 miss 到 PTW request，再到 data/page-fault/access-error completion 的端到端事务 | MB shadow、PTW request/ready、PTW completion、PTW source model 输出 | 生成 L1/PFU final response 期望，区分 data_vld/page fault/access error | PTW 内部 TWU stage cycle accuracy；PDE cache exact replacement |
| PFU path shadow | PFU accepted request、MMU enable、PTW enable、PMP/sysmap/MAEE、L2 hit/miss/PTW result | PFU monitor、CP0 shadow、PMP/sysmap cfg、L2/PTW observation | MMU-off direct、MMU-on hit、MMU-on PTW completion 三路径 expected response | prefetch_mask 内部实现细节，除去重/释放协议外不做功能比较 |
| TLBOP shadow | 当前 operation type、VA、ASID、write entry payload、done/abort 状态 | CP0/LSU TLBOP monitor、TLBOP probe、L2 entry shadow update | TLBP/TLBR expected result；TLBWI/TLBWR/INV* 对 L2 shadow 的更新 | scan exact latency；TLBWR exact victim；RRPV update |
| Control/reset shadow | SATP、ASID、MMU enable、PTW enable、privilege、SUM/MXR/MPRV/MPP/MAEE、reset/reset-inv/abort epoch | CP0 monitor、reset signal、reset-inv done、TLBOP abort | 所有 transaction 的上下文选择、pending clear、stale completion 隔离 | 非法 mid-transaction control change 的功能 payload |
| Replacement/RRPV debug shadow | optional debug counters：wbuf full/empty、push/pop、victim observed、RRPV bins | `mmu_dut_probes_if`、RRPV SVA/coverage | coverage/debug/no-overflow/no-wrong-grant | exact victim way、exact RRPV value、latest-wins merge 规则 |

### 8.4 L2 Direct Hit 比较规则

- 只有当 request 被 scoreboard 认定为合法 accepted transaction，且 L2 entry shadow 中存在唯一匹配 entry 时，才生成 L2 direct hit 期望。
- tag 比较使用 VPN、ASID、G 和 page size 规则：G entry 不依赖当前 ASID；non-G entry 必须 ASID 匹配；page size 决定 VPN 低位是否作为 page offset extension。
- data 比较使用 PPN、PGS 和 flags。PA payload 按 page size 将 entry PPN 与 request VA offset/VPN 低位组合。
- L2 direct hit 不判定 PTE.V/R/W/X/U/A/D permission fault；这些 fault 归 L1 hit model、PFU hit path 或 PTW/PMP/sysmap 对应 reference model 处理。
- 若 L2 观察到 multi-hit，scoreboard 只检查外部 fault/completion 编码，内部 coverage 记录 multi-hit source；不比较任意一个 hit way 的 payload。
- 若 expected 为 miss 但 DUT 返回 hit，或 expected 为 hit 但 DUT miss/返回错误 payload，归类为 transaction mismatch，错误报告必须包含 source、VPN、ASID、G、PGS、expected PPN/flags 和 DUT payload。

### 8.5 Fault / no-pavld Payload Ignore 规则

- `cmplt=1,pavld=0,pgflt=1` 场景只比较 page-fault class，不比较 VPN、PPN、flags 或 sec/share/cache attribute payload。
- PTW access error、PMP/sysmap deny、PFU flag fault 只比较 fault/deny class 和 owner 归属；payload 字段全部 ignore，除非对应接口规格明确要求 payload 清零。
- PTW disabled miss 与 multi-hit 对 L1 可表现为同一类 page fault；外部 scoreboard 只比较相同响应编码，white-box coverage 必须区分两类原因。
- negative assertion test 中 bad completion ID、非法 result bit 组合或 X payload 触发后，不继续做普通功能结果比较。

### 8.6 PFU 三路径建模

- MMU-off direct path：不访问 L2 entry shadow，PA 由 VA direct-map 得到；PFU response 只由 direct-map sysmap、PMP flag、MAEE/control shadow 决定。
- MMU-on L2 hit path：先用 L2 entry shadow 产生 translation payload，再在 PFU path shadow 中检查 PFU flag fault、PMP/sysmap deny、sec/share/cache attribute。
- MMU-on PTW completion path：PFU miss 进入 MB/PTW shadow，PTW completion 直接归属原 PFU request；scoreboard 不要求 refill 后再二次 lookup 才生成 PFU response。
- `prefetch_mask` 相关行为作为 accepted-once/release checker 和 coverage：同一持续 PFU request 不得被重复接受，mask 在 valid/error 或 MB-full retry 边界释放。

### 8.7 PTW Completion 归属规则

- PTW request fire 时，PTW transaction shadow 必须记录 composite ID、source、VPN、type、L1 eid/PFU owner、SATP/ASID/control snapshot。
- PTW completion 可乱序返回；scoreboard 按 completion ID/type 匹配 outstanding PTW transaction，不按 issue 顺序匹配。
- data_vld completion 更新 L2 entry shadow，并向原 owner 生成最终 refill/response 期望；page fault 和 access error completion 不更新 L2 valid entry，只生成 fault 期望。
- abort/reset/control epoch change 后，旧 completion 不得写入当前 L2 shadow，也不得释放或完成新 epoch transaction；若 DUT 明确丢弃旧 completion，scoreboard 同步 retire 或 classify 为 aborted。
- MB 释放是内部一致性观察点；transaction pass/fail 以原 L1/PFU 最终 response 和 L2 entry shadow 后续可见行为为准。

### 8.8 TLB Operation 对模型的影响

| Operation | L2 shadow 更新/期望 | Scoreboard 检查 | 不检查项 |
| --- | --- | --- | --- |
| TLBP | 不修改 L2 entry shadow | 按 VA/ASID/G/page size 规则返回 hit/miss 和可见 index/result | exact scan latency，内部候选 way 顺序 |
| TLBR | 不修改 L2 entry shadow | 按指定 index/way 或 DUT visible read index 返回软件可见字段；valid=0 时只要求 invalid 语义 | invalid entry stale data 是否清零 |
| TLBWI | 指定 entry 写入 L2 entry shadow；valid=0 写入视为 invalidate | 后续 lookup/TLBP/TLBR 与写入字段一致 | RRPV 初值、write buffer drain timing |
| TLBWR | 写入 L2 entry shadow，但 v1 不预测 exact victim；directed test 需要通过 TLBR/lookup 探测或约束可见落点 | 后续 translation 可命中/可失效，TLBR/TLBP visible result 合法 | free-way/max-RRPV/victim exact 规则 |
| INVALL | 全部 valid entry 置 invalid | 后续所有相关 lookup/TLBP miss；reset-inv 后 all-invalid | 每个 set/way invalid write beat timing |
| INVASID | non-G 且 ASID 匹配 entry 置 invalid，G entry 保留 | 多 ASID/global directed 后检查保留/失效结果 | L1 内部 flush exact timing |
| INVVA_ALL | VA 匹配 entry 置 invalid，不区分 ASID；具体按规格定义的 page-size match | VA 相关 lookup/TLBP miss，非匹配 entry 保留 | exact scan order |
| INVVA_ASID | VA 与 ASID 均匹配的 non-G entry 置 invalid；G entry 按规格保留 | VA+ASID targeted invalidation 结果正确 | RRPV 清零 |

### 8.9 Replacement / RRPV 边界

- v1 不预测 exact victim way、exact RRPV value、RRPV wbuf latest-wins、same-cycle bypass 或 drain 后 SRAM 数值。
- TLBWR/PTW refill 的功能检查以软件可见结果为准：合法写入或 refill 后对应 translation 应可命中，invalidate 后应失效，TLBR/TLBP 对可见字段符合 shadow。
- 若 directed test 必须检查某个具体 way，必须使用 backdoor 初始化、TLBR 探测或内部 monitor 先确认落点；不能在没有 replacement model 时把 victim way 作为主功能 fail 条件。
- RRPV/wbuf 在 v1 只做 no-overflow、full 时 no-wrong-grant、debug coverage 和 future 专项 trace。future 若要升级为强检查，必须先补全 hash/index/RRPV SRAM/wbuf merge/latest-wins reference model。

### 8.10 Timeout / Fairness 分类

- timeout 报错必须区分外部 fairness 和 DUT forward progress。若 PTW ready、LSU/PMP/sysmap response 或其他外部 backpressure 永久不释放，归 TB fairness violation。
- 当外部 fairness 已满足后，ReqQ retry、MB full release、PTW completion、TLBOP scan done、PFU response 或 wbuf drain 仍不推进，归 DUT forward-progress violation。
- timeout checker 需要记录 oldest transaction age、source、VPN/type/eid、当前 backpressure 原因、最近一次 grant/completion/abort 事件，避免只输出固定周期超时。
- 对 reset/abort/control hazard epoch 内的 pending transaction，timeout checker 必须先 retire 或 classify 为 aborted，不得继续等待旧 transaction completion。

### 8.11 不作为 v1 Transaction Scoreboard Pass/Fail 的项目

- exact replacement victim way、free-way 选择、max-RRPV 选择和 exact RRPV 数值。
- RRPV write buffer latest-wins、same-cycle merge、invalid entry pending update 是否被清除或覆盖。
- ReqQ、MB、pipeline、arbiter block flag、TLBOP scan 的逐周期状态，除非对应 SVA 或 debug checker 明确要求。
- hash/index/bank mask 的 exact hard close；v1 至少做 selector/page-size debug coverage，强检查留给后续专项。
- fault/no-pavld 场景下的 VPN/PPN/flags/sec/share/cache attribute payload。
- L2 direct hit 层面的 PTE permission fault 判定。
- illegal protocol input 后的普通功能结果。

### 8.12 与现有 UVM 架构的对齐

- `mmu_ref_model.svh` 已提供 Sv39/PMP/SysMap transaction-level translation model，可作为完整 MMU translation reference 的基础；Phase 6 若扩展 L2 shadow，应避免破坏现有 IFU/LSU/PFU 顶层 compare API。
- `mmu_translation_sb.svh` 已接入 IFU/LSU/PFU 顶层响应和部分 L2/PTW white-box diagnostic shadow；Phase 6 应在这里或相邻 L2 专用组件中合并 PTW completion 归属和 L2 entry shadow，而不是只增加局部 direct-port checker。
- `mmu_invalidate_sb.svh` 当前主要计数 invalidate event；Phase 6 需要把 INV* 对 L2 entry shadow 的影响补齐，或把 invalidate event 接入统一 L2 shadow owner。
- `mmu_dut_probes_if.sv` 已暴露 L2 final、ReqQ、MB、PTW、TLBOP、PFU/PMP/sysmap 等观察点；这些 probe 用于 debug/coverage/SVA 和 root-cause dump，不替代 transaction-level expected/actual 比较。
- 后续实现如果发现某个 Phase 4 必需输入缺少稳定 monitor transaction，应先在 Phase 6A 补 probe/monitor，再在 Phase 6C 补 scoreboard；不得用不稳定 `$root` 层级引用绕过 monitor 边界。

### 8.13 Phase 4 退出检查摘要

| 检查项 | 状态 |
| --- | --- |
| 定义 v1 transaction scoreboard 边界 | 已完成 |
| 定义 L2 entry、ReqQ、MB、PTW、PFU、TLBOP、control/reset、replacement shadow | 已完成 |
| 定义 L2 direct hit 比较规则 | 已完成 |
| 定义 fault/no-pavld payload ignore 规则 | 已完成 |
| 定义 PFU 三路径建模规则 | 已完成 |
| 定义 PTW completion 到 L1/PFU 最终响应的事务归属 | 已完成 |
| 定义 TLB operation 对 reference model 的影响 | 已完成 |
| 明确 replacement/RRPV 不作为 v1 transaction pass/fail | 已完成 |
| 明确 timeout/fairness 分类 | 已完成 |
| 对齐现有 UVM reference model、translation scoreboard、invalidate scoreboard 和 probe interface | 已完成 |
