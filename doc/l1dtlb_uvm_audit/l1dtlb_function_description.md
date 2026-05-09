# L1DTLB Function Description and UVM Audit Basis

## 1. L1DTLB Functional Specification

### 1.1 Signal Interface
    lsu有两个能完成VA到PA转换的端口与MMU连接，每一拍lsu可以同时有两个VA转换的请求到l1dtlb。lsu把VA，va_vld，iid，vabuf信号，是否是store指令的标识信号，以及abort信号发给mmu
        vabuf信号未使用
        lsu__abort0/1 的本质：LSU 在同一拍仍然把 VA/ID 发给 MMU，但告诉 MMU“这次 AG 请求不要产生有状态后果”。它主要防止一个已经要 stall、restart、异常或 flush 的 load/store 去触发 DTLB miss/refill、匹配旧 refill 异常，或把错误异常算到这条指令上。
            lsu__abort0/1为1时，这个请求不会进入miss buffer（不启动refill流程），也不会触发异常信号的上报（不释放异常阵列的entry）
### 1.2 LSU Wakeup and Busy Signals
        weakup：当l1dtlb要进行回填时（把页面的数据写入tlb entry中）或lsu发来的请求在异常阵列中hit时，拉高weakup信号
        busy:当l1dtlb的miss buffer任意miss buffer entry valid时，拉高。意味着只要有miss正在refill，busy信号就拉高
    
    
### 1.3 Pipeline Behavior
    TO时，LSU发地址转换请求到MMU，mmu将lsu发来的va同时在tlb和异常请求寄存阵列异常请求寄存阵列中进行cam比较（lsu的两个端口同时进行）。
        如果在tlb中命中，当拍返回pa_vld,以及pa和对应的属性给lsu（T0返回）
        如果发现page fault，当拍返回pa_vld信号，并当拍拉高page_fault信号（T0返回）
        如果在tlb中hit，并且没有发现page fault，那么就会拉高pmp check信号，把T0时hit的pa打一拍，在T1时发往PMP模块进行PMP检查，PMP模块在当拍就返回response给mmu。如果检查发现pmp不通过，那么拉高acc_fault信号，返回给lsu（T1拉高cc_fault信号）
        如果在tlb中miss，在异常请求寄存阵列中hit，那么会把对应的miss buffer entry释放，并且拉高pa_vld。如果fault类型是page fault，那么当拍拉高page fault信号；如果是access fault，那么寄存一拍，在T1时拉高access fault信号。
            注意：与异常请求寄存阵列的cam比较要按iid和vpn来比较。如果在异常请求寄存阵列中hit，那么一定不能给这个请求分配miss buffer。如果在异常请求寄存阵列中hit，必须把异常请求寄存阵列中的entry和miss buffer中对应的entry释放。
        如果在tlb中miss，在异常请求寄存阵列中也miss，那么把miss_vld信号寄存一拍，当寄存后的miss_vld信号有效时，在miss buffer中进行cam比较（在T1时，把lsuT0发来的VA与miss buffer中的entry中存的vpn进行比较），与miss buffer的cam比较以4k page的vpn进行比较，也就是说，要对比全部的27bit vpn
            如果在miss buffer中hit，那么这个请求不分配miss buffer entry。
            如果在miss buffer中 miss，那么要根据miss buffer中剩余的空闲entry数量和lsu两个端口miss的数量来决定如何分配。
                如果lsu的两端口都需要分配miss buffer entry，且在同一个4k page，且miss buffer空位≥1,那么把端口0的miss写入MB entry，且entry状态进入 WFG，端口一的miss不分配miss buffer entry。（T1分配）
                如果lsu的两端口都需要分配miss buffer entry，且不在同一个4k page，且miss buffer空位≥2，那么两条 miss 同拍写入不同MB entry。（T1分配）
                如果lsu的两端口都需要分配miss buffer entry，且不在同一个4k page，且miss buffer仅 1 空位，那么iid更老的一个miss请求写入MB entry，另一个不分配MB entry（T1时分配miss buffer entry）
                如果lsu的两端口中只有一个端口需要分配miss buffer entry，那么在miss buffer有空位的情况下，分配一个miss buffer entry；如果miss buffer没空位，那么不分配miss buffer entry。
### 1.4 L2TLB Request and Credit
    l1dtlb需要把miss的请求发送到l2tlb走refill流程。
        l1dtlb内部会维护一个credit计数器，计数器初始化为l2tlb的request queue entry的数量。
            当credit计数器的值大于0时，能发请求到l2tlb request queue。
            当credit计数器等于0，但是l2tlb刚好归还了credit时，也能发请求到l2tlb。
            也就是说，只要l1dtlb能发请求到l2tlb，那一定说明l2tlb request queue的为dtlb准备的entry还有空位。
            每当l1dtlb的miss buffer发送一个请求到l2tlb request queue，都要把这个计数器减一。
            当l2tlb归还了credit时，credit计数器加一。
            如果同时发生l2tlb归还credit和发送请求到l2tlb，那么credit不变。
        在有miss请求未发送到l2tlb（有判定需要分配miss buffer entry的miss请求或miss buffer中有未发送的请求），且l1dtlb满足发请求给l2tlb（credit满足上面所说的情况）的时侯，一拍发送一个请求到l2tlb的request queue。
            当miss buffer中有未发送的请求时，优先发miss buffer中的请求；
            当miss buffer中没有未发送给l2tlb的请求时，如果有被判定需要分配miss buffer entry的miss请求，那么这个要被分配miss buffer entry的请求走bypass，直接发送到l2tlb request queue。
### 1.5 Refill and TLB Install
    当ptw或l2tlb refill完成时，需要把数据写进l1dtlb。
        每一拍只能写入一个tlb entry。
        如果miss buffer中有正在等待写入tlb的请求，优先选择miss buffer中有正在等待写入tlb的请求。
            如果同一拍出现ptw refill完成，l2tlb refill完成，miss buffer中有等待写入tlb的请求，那么选miss buffer中有正在等待写入tlb的请求，将其写入tlb
                而对应的ptw和l2tlb refill的请求，会把需要回填进tlb的内容锁存，并且它们对应的miss buffer entry的状态机进入wfi（wait for install）状态，也就是等待写入tlb的状态
        然后miss buffer中没有正在等待写入tlb的请求，那么优先选择ptw refill的请求，将其写入tlb
            如果同一拍出现ptw refill完成，l2tlb refill完成，那么优先选择ptw refill的请求，将其写入tlb
                而对应的l2tlb refill的请求，会把需要回填进tlb的内容锁存，并且对应的miss buffer entry的状态机进入wfi（wait for install）状态，也就是等待写入tlb的状态
        如果miss buffer中没有正在等待写入tlb的请求，且没有ptw refill的请求，那么选择l2tlb refill的请求，将其写入tlb

### 1.6 Exception Array
    只有当ptw或l2tlb refill的pa带着fault信号时（page fault或access fault），分配异常阵列的entry。
        能够进入异常阵列的请求一定存在于miss buffer中。那么异常阵列的entry数量应该与miss buffer保持一致。
        写入异常阵列是通过refill带着的id来索引。
        如果同一拍中，ptw和l2tlb的refill都带着fault，那么都会写进异常阵列。理论上来说，一定是写入不同的阵列entry
        当异常阵列的清除信号到来时，要按情况清理entry
            当rtu的冲刷信号有效时，那么清空异常阵列（rtu的冲刷信号到来时，会把miss buffer清空，异常阵列也就没有必要保留了）
        
### 1.7 TLB Entry, Match, and Invalidate
        l1dtlb是full associative
        当lsu有地址转化请求进入mmu时，与l1dtlb的所有entry进行比较
            比较时，按照tlb中存储的page size比较vpn
        如果有需要写进tlb的数据，按照plru模块选择的victim entry来写入
        每一拍只能有一个tlb entry被写入
        只有两种情况能让entry被写入
            第一种：当要写入tlb entry的来源是ptw或l2tlb的refill数据的时候，只有ptw或l2tlb返回refill有效信号，且refill的miss buffer entry id对应的miss buffer entry处于WFC状态，且这个entry被plru选为victim entry时，entry才能被写入
            第二种：当要写入tlb entry的来源是miss buffer中处于WFI的entry时，当entry被plru选为victim entry时，entry才能被写入
        如果ptw或l2tlb的refill完成的时候，refill的miss buffer entry id对应的miss buffer entry处于ABT状态，那么即使entry被plru选为victim entry并且refill有效，tlb entry也不能被写入
        当异常阵列的清除信号到来时，要按情况清理entry
            1.当tlboper_utlb_clr信号有效时，清空tlb的entry。
                tlboper_utlb_clr由 TLB 操作模块 ct_mmu_tlboper 产生，以下场景会产生tlboper_utlb_clr信号：
                    TLBWI：软件按指定 index 写 l2TLB。
                    TLBWR：软件按替换策略写 l2TLB。
                    INVASID / TLBI_ASID_ALL：按 ASID 失效 l2TLB。
                    INVALL / TLBI_ALL / cp0_mmu_tlb_all_inv：全失效 l2TLB。
                    这些操作都会改变 l2TLB 内容。l1TLB 是 l2TLB/PTW 翻译结果的小缓存，如果 l2TLB 被写入、替换或大范围失效，l1TLB 可能还缓存旧翻译，所以用 tlboper_utlb_clr 直接清掉全部 uTLB entry。注意它不用于 TLBP/TLBR，因为 probe/read 不改变翻译内容
            2.当regs_utlb_clr信号有效时，清空tlb的entry。
                当前端/CP0 写 SATP 时，regs_utlb_clr 拉高。SATP 里有 mode/asid/ppn，决定当前地址空间、页表根和 ASID。l1TLB entry 里没有保存 ASID，代码注释也写了 “ASID field are not included in uTLB entry”。所以 SATP 一变，原来 l1TLB 里的 VA->PA 翻译可能属于旧地址空间，必须全部失效。
            3.当ctc_inv_va_hit_clr信号有效时，将tlb的每个entry存储的vpn的0到7bit和lsu_mmu_tlb_va[7:0]进行比较，如果相同，那么就把相同的tlb entry清理掉（valid拉低）
                ctc_inv_va_hit_clr不是顶层产生的全局信号，而是每个 l1TLB entry 内部自己产生的局部清除信号。来源是 CTC/TLBI 按 VA 失效，这类操作只想失效某个 VA 相关的翻译，所以不走 tlboper_utlb_clr 全清，而是广播 tlboper_utlb_inv_va_req 和目标 lsu_mmu_tlb_va 给所有 uTLB entry。每个 entry 自己比较：命中则产生 ctc_inv_va_hit_clr，只清这个 entry。这里比较低 8 bit VPN，是一种保守的局部匹配：真实同 VA 一定会命中这 8 bit；不同 VA 低 8 bit 相同会被误清，但只是性能损失，不影响正确性。
              完整因果链可以概括为：
                1. SATP 改变、JTLB 被写/替换、或收到 TLBI/CTC 失效请求。
                2. MMU 必须防止 uTLB 继续返回旧 VA->PA/权限。
                3. 如果是 SATP 写，ct_mmu_regs 拉高 regs_utlb_clr，全清 uTLB。
                4. 如果是 TLBWI/TLBWR/INVASID/INVALL，ct_mmu_tlboper 拉高 tlboper_utlb_clr，全清 uTLB。
                5. 如果是 VA 定点失效，ct_mmu_tlboper 拉高 tlboper_utlb_inv_va_req，各 entry 内部命中后拉高 ctc_inv_va_hit_clr，清对应 entry。
                6. 清除动作最终都是 utlb_vld <= 1'b0，entry 数据可以还在，但已经不会作为有效翻译使用。



    
### 1.8 Miss Buffer and Refill FSM
        当异常阵列的清除信号到来时，要按情况清理entry
            当rtu的冲刷信号有效时，那么清空miss buffer
        miss buffer是full associative
        当T0时在tlb中和异常阵列中miss的请求要在miss buffer中查找时，与miss buffer中所有的entry进行比较
            比较时，按照4K page size进行VPN的对比
        每个miss buffer entry维护一个refill FSM
            FSM总共有IDLE,WFG(wait for grant),WFC(wait for complete),WFI(wait for install),PGFLT(page fault),ACFLT(access fault),ABT(aborted)这七个状态
                当某个entry被分配之后，就会拉高valid信号
                    只要不是IDLE状态，valid都是拉高的
                    valid拉高表示entry已经被分配了，不再是空闲状态
                当某个entry被发送到l2tlb之后就会拉高sent信号
                    sent拉高之后表示已经被发送到l2tlb了，不再作为发送的候选
                    sent没有拉高，但是valid拉高的时候表示这个entry是发送到l2tlb的候选
                当某个entry在refill时，遇到其他比它优先级更高的请求要写回到tlb中时，会进入WFI状态，拉高WFI信号
                    wfi信号拉高的时候表示作为写入tlb的候选，等待被写入tlb
                当某个entry被分配时
                    如果在分配的同一拍没有被bypass发射到l2tlb，那么就会在拉高allocate信号的下一拍进入WFG状态（IDLE->WFG）
                    如果在分配的同一拍被bypass发射到l2tlb，那么就会在拉高allocate信号的下一拍进入WFC状态（IDLE->WFC）
                当某个entry处于WFG状态时
                    如果被发送到l2tlb，那么就会在下一拍进入WFC状态
                    如果遇到rtu发来的流水线冲刷信号
                        如果rtu的冲刷信号到来的这拍，这个entry没有被选择发射出去，那么会回到IDLE状态，并且把valid拉低，把entry变回空闲状态
                        如果rtu的冲刷信号到来的这拍，这个entry被选择发射出去，那么会进入ABT状态，只有当ptw或l2tlb返回refill完成信号时，回到IDLE状态，并拉低valid信号，把entry变回空闲状态。
                当某个entry处于WFC状态时
                    如果遇到rtu发来的流水线冲刷信号
                        如果rtu的冲刷信号到来的这拍，ptw或l2tlb的refill完成信号拉高了，那么会回到IDLE状态，并且把valid拉低，把entry变回空闲状态
                        如果rtu的冲刷信号到来的这拍，ptw或l2tlb的refill完成信号没有拉高，那么进入ABT状态，只有当ptw或l2tlb返回refill完成信号时，回到IDLE状态，并拉低valid信号，把entry变回空闲状态。
                    如果没有遇到rtu发来的流水线冲刷信号
                        当ptw或l2tlb的refill完成信号拉高，并且page fault为高时，进入PGFLT状态。当后续lsu发来的请求在异常阵列中hit时，才能回到idle状态（拉低valid信号，把entry变回空闲状态）。
                        当ptw或l2tlb的refill完成信号拉高，并且page fault不为高，且access fault为高时，进入ACFLT状态。当后续lsu发来的请求在异常阵列中hit时，才能回到idle状态（拉低valid信号，把entry变回空闲状态）。
                        当ptw或l2tlb的refill完成信号拉高，并且page fault和access fault均不为高时
                            如果被授权写入tlb，那么回到idle状态，并拉低valid信号，把entry变回空闲状态。
                            如果没有被授权写入tlb，那么进入WFI状态
                当某个某个entry处于WFI状态时
                    如果遇到rtu发来的流水线冲刷信号，那么回到idle状态，并拉低valid信号，把entry变回空闲状态。
                    如果没有遇到rtu发来的流水线冲刷信号，且被授权写入tlb，那么回到idle状态，并拉低valid信号，把entry变回空闲状态。
                当某个entry处于PGFLT状态
                    如果遇到rtu发来的流水线冲刷信号，那么回到idle状态，并拉低valid信号，把entry变回空闲状态。
                    如果没有遇到rtu发来的流水线冲刷信号
                        当后续lsu发来的请求在异常阵列中hit时，回到idle状态，并拉低valid信号，把entry变回空闲状态。
                当某个entry处于ACFLT状态时
                    如果遇到rtu发来的流水线冲刷信号，那么回到idle状态，并拉低valid信号，把entry变回空闲状态。
                    如果没有遇到rtu发来的流水线冲刷信号
                        当后续lsu发来的请求在异常阵列中hit时，回到idle状态，并拉低valid信号，把entry变回空闲状态。
                当某个entry处于ABT状态时
                    如果ptw或l2tlb的refill完成信号拉高，那么回到IDLE状态



## 2. L1DTLB Spec Clarification Q&A

### 2.0 Q&A Scope
        本节所有条目都是待回答问题，不代表已经确认的设计行为。
        这些问题的目标是把l1dtlb_function_description.txt补充到足够清晰，使后续可以只基于spec审核UVM中的l1dtlb scoreboard和reference model，而不是参考RTL实现。
        建议回答时尽量给出：是否成立、精确时序、优先级、同拍冲突处理、对外可观测信号，以及reference model/scoreboard应该如何建模。

### 2.1 接口与基本信号语义
        Q-L1DTLB-001: lsu发给mmu的两个请求端口是否完全对称？如果不对称，请明确pipe0和pipe1在支持的请求类型、STAMO、abort、fault、PMP检查、miss分配、wakeup/busy语义上的差异。
        人类工程师对Q-L1DTLB-001的回答：不是完全对称。更准确地说：DTLB 读命中路径基本对称，但两个端口的来源、语义不是完全对称。普通 DTLB 查表、hit 判断、PA 返回、page fault/access fault/PMA/PMP 等逻辑，大体是同一套模板。可以理解成两个 DTLB read port。
                                      port0 主要服务 load 类请求，port1 主要服务 store 类请求。port0 不是纯 load，因为 ldamo 会让 st_inst0 拉高，用于类似原子操作的权限类型判断。
                                      STAMO 只走 port1，stamo 不查 TLB，而是用 LM 的 PA 信息。LM 是 LSU 里的 Local Monitor，它主要服务 LR/SC 和 AMO 这类原子访问，作用是记录一次原子 load/LR 建立起来的地址、属性和状态。LM 保存原子 load 的物理地址，给 STAMO 用的 PA 就来自 LM。这里的逻辑是：AMO/LR 的 load 部分先查 TLB，得到 PA，并把 PA 存进 LM；后续 STAMO store 部分不再查 TLB，而是直接复用 LM 里保存的 PA。

        Q-L1DTLB-002: vabuf信号当前描述为未使用。它在l1dtlb spec中应被视为无功能影响的旁路字段，还是某些场景下会影响VA、PA、异常、属性或scoreboard比较？
        人类工程师对Q-L1DTLB-002的回答：vabuf信号目前完全没有任何作用。

        Q-L1DTLB-003: lsu_mmu_va_vld0/1为高但对应abort0/1也为高时，l1dtlb是否仍允许返回TLB hit的pa_vld/pa/attr，还是必须屏蔽该请求的所有对外响应？
        人类工程师对Q-L1DTLB-003的回答：允许返回 TLB hit 的 pa_vld/pa/attr，没有因为 abort0/1 把所有对外响应屏蔽掉。不必屏蔽所有对外响应，当前设计也没有这么做。 pa_vld/pa/attr 在 hit 时仍可组合返回；abort 的语义不是“MMU 输出全无效”，而是“这次 LSU 请求不能在 MMU 内部产生后续状态，也不能消费 refill 异常”。

        Q-L1DTLB-004: abort0/1需要屏蔽哪些有状态后果？请分别明确TLB hit响应、miss buffer分配、L2TLB request、exception array hit释放、page_fault/access_fault输出、PMP check、PLRU更新是否受abort影响。
        人类工程师对Q-L1DTLB-004的回答：abort0/1对TLB hit响应没有影响，允许返回 TLB hit 的 pa_vld/pa/attr，没有因为 abort0/1 把所有对外响应屏蔽掉，因为在lsu内部会丢弃这个请求的响应。abort 的语义不是“MMU 输出全无效”，而是“这次 LSU 请求不能在 MMU 内部产生后续状态，也不能消费 refill 异常”。因为lsu的设计，导致需要abort信号请求取消在 MMU 内部产生后续状态。
                                      abort0/1对miss buffer分配的影响是，有abort0/1的情况下，对应的miss请求不会分配miss buffer entry。
                                      abort0/1对L2TLB request没有任何影响。因为能给l2tlb发req的都是分配了miss buffer entry的其他请求。
                                      abort0/1对exception array hit释放的影响是：即使这个带着abort信号的请求在exception array中hit，也不会释放对应的exception array entry。不允许这个带着abort信号的请求匹配pending refill
                                      abort0/1不屏蔽 hit 响应、page_fault、PMP check、PLRU read-hit 更新。
        
        Q-L1DTLB-005: iid的年龄比较规则是什么？iid是否可能回绕？如果两个pipe同拍请求都需要仲裁，scoreboard应如何判断哪个iid更老？
        人类工程师对Q-L1DTLB-005的回答：IID 可以理解成一个 0 到 127 循环递增的编号。新指令进入 ROB 时拿到当前 IID，之后 IID 加 1；如果一拍创建 4 条，就连续给 4 个 IID，然后整体加 4。加到 127 之后再加 1，就回到 0。所以 IID 一定会回绕。
                                      判断年龄时不能简单说“数字小的老”或“数字大的老”，因为有回绕。
                                      如果两个 IID 的 bit6 相同，就看低 6 位：
                                        低 6 位小的更老
                                        例如：
                                        IID 10 比 IID 20 老
                                        IID 65 比 IID 80 老
                                        因为它们都在同一个 64 个编号区间里。
                                      如果两个 IID 的 bit6 不同，就说明比较可能跨过了 64 边界。这时规则反过来：
                                        低 6 位大的更老
                                        例如：
                                        IID 70 比 IID 5 老。因为70 = bit6 为 1，低 6 位是 6，5  = bit6 为 0，低 6 位是 5。这代表 ROB 里可能还有回绕前分配的 70，同时又已经开始分配回绕后的 5。70 是先进入 ROB 的旧指令，5 是后进入 ROB 的新指令，所以 70 更老。
                                        这个比较方法依赖一个前提：ROB 同时在飞的指令数量不会超过一个最多覆盖 64 条在飞指令的可比较窗口
                                        意思是：ROB 里同时存在的有效指令，只会占据 IID 环上的一段连续区间，而且这段区间长度最多是 64 条。
                                        IID 是 7 bit，所以编号循环是：0, 1, 2, ... 126, 127, 0, 1, ...。但低 6 位每 64 个就重复一次：IID 5   的低 6 位是 5，IID 69  的低 6 位也是 5。如果 5 和 69 同时存在，就会很麻烦，因为它们低 6 位相同，只靠 bit6 区分相位。
                                        比较器要求这种相隔正好 64 的两个 IID 不会同时在 ROB 里有效。这种要求通过ROB 只有 64 项来保证。如果 ROB 最老指令是 IID 5，那么 ROB 里最多还能同时存在：5, 6, 7, ... 68，最多 64 条。下一条 IID 69 只有在最老的 IID 5 退掉、ROB 有空位后才会分配进来。所以 5 和 69 不会同时有效。
                                        以“可比较窗口”指的是这种范围：一段长度不超过 64 的连续 IID 区间
               
        Q-L1DTLB-006: store标识只影响store权限/page fault判断，还是也影响L2TLB request type、PMP访问类型、属性输出、refill路径或异常优先级？
        人类工程师对Q-L1DTLB-006的回答：store标识对TLB hit 侧 page fault：会影响。store 标识决定 R/W/D 权限怎么检查：load：检查 R，且可能受 MXR寄存器 影响。store：检查 W 和 D bit。A bit、U/S 权限、VA illegal 等不区分 load/store。store 标识会直接影响 mmu_lsu_page_fault* 是否拉高。
                                      store 标识会影响发给 L2TLB 的 access type。store标识会在refill过程中生成一些控制信号。store标识会随着refill的过程一直传递下去，如l2tlb也会把type发给ptw。
                                      store标识对PTW/refill 权限判断的影响是：store type 会影响 PTW 对最终 PTE 的权限判断：store 要求 W=1，D=1，load 要求 R=1，或 MXR 允许 X 当 R。
                                      store标识对PMP 访问类型：会影响。lsu的请求在l1tlb中hit 后做 PMP check 时，会记录当前访问是 read 还是 write，之后 access fault 判断会按 read/write 选择 PMP 权限位。还有一个细节：port0 有 dutlb_ori_read0 = 1，所以某些从 load pipe 过来的 atomic/LDAMO 类请求，即使 st_inst0 让它表现为 store，也可能同时要求 read 权限。这是为了 atomic 这类读改写访问。PTW 侧 PMP 也受 type 影响，store type 会检查 store/write 相关 PMP 权限。
                                      store标识对属性输出：基本不影响。输出属性来自 TLB entry/PMA flag。不看 lsu_mmu_st_inst。所以同一个 VA 翻译到同一个 PTE/PMA 时，load 和 store 返回的 cacheable、bufferable、shareable、secure、SO 属性应一致。
                                      store标识对异常优先级：不改变优先级，但会改变哪个异常条件成立。
                                      总结一句：store 标识不是只用于 store permission/page fault；它还决定 DTLB miss 发给 JTLB/L2TLB 的 request type，并一路影响 PTW 和 PMP 的访问类型。它不直接影响 PA/属性输出，也不切换另一条 refill 物理路径，只是给同一条 refill 逻辑带上 load/store 语义
                        
        Q-L1DTLB-007: l1dtlb输出给lsu的pa_vld表示“本次转换完成”，还是只表示“有返回事件”？当page fault/access fault发生时，pa_vld是否必须同时为高？
        人类工程师对Q-L1DTLB-007的回答：mmu_lsu_pa*_vld 更准确地说是 DTLB 对 LSU AG 口的“转换结束/有终态结果”标志，不是单纯表示“PA 可用于真正访存”。它为高时可能有几种含义：1. DTLB hit，正常得到 PA/属性。2. MMU off / machine mode，直接得到 PA。3. VA illegal，转换以 page fault 结束。4. pending refill 返回 的page fault/access fault正在挂起，发来的匹配到异常请求的iid
                                      所以 pa_vld=1 表示 LSU 这次查 MMU 不应该再当成 utlb_miss 等待了。
                                      对 LSU 来说，page fault 事件必须和 pa_vld 一起看。也就是说，mmu_lsu_page_fault 单独为高不算一个有效 page fault 返回；有效 page fault 返回需要 pa_vld=1。
                                      access fault 不要求和 pa_vld 同拍。正常来说，如果有access fault，那么access fault会在pa_vld的下一拍拉高。
                                      总结：pa_vld = 本次 DTLB 查询有终态结果，不一定是成功 PA 。page_fault 有效事件：需要和 pa_vld 配对（同一拍均为高）。access_fault 有效事件：不和 pa_vld 同拍，是独立的后级异常信号（但也只有在hit之后才可能有access fault）                                      
                                      
        Q-L1DTLB-008: page_fault和access_fault输出是1-cycle pulse、保持到lsu接受、还是保持到对应entry释放？请分别说明TLB hit路径、exception array hit路径、PMP路径和refill fault路径。
        人类工程师对Q-L1DTLB-008的回答：page_fault和access_fault输出均是1-cycle pulse。
                                      TLB hit时，lsu发请求到mmu的当拍就能查出是否page fault组合逻辑输出，只拉高一拍。access fault是在lsu发请求到mmu的下一拍产生。只有当tlb hit并且没有page fault，或者关闭了dtlb并且没有page fault的时候，会拉高pmp check信号，在拉高pmp check信号的下一拍会进行pmp检查，如果pmp检查没通过，那么就在检查的这一拍拉高access fault信号。
                                      exception array hit时：exception array中的请求一定是存在于miss buffer中的请求，因为只有当ptw或l2tlb在refill完成时携带了fault信号（page fault或access fault）时，才会把这个refill的请求写进exception array。当lsu后续再次发来对应的请求的时候，反馈给lsu的fault信号的时序和tib hit时候完全一样。区别在于page fault和access fault的产生并不是由检查产生，而是由exception array存储的fault传输给lsu。（page fault依旧查找tlb的当拍上报，access fault依旧在查找tlb的下一拍上报）
                                      refill fault路径：当ptw或l2tlb在refill完成时携带了fault信号（page fault或access fault）时，会把这个refill的请求写进exception array。当lsu后续再次发来对应的请求的时候，反馈给lsu的fault信号的时序和tib hit时候完全一样。区别在于page fault和access fault的产生并不是由检查产生，而是由exception array存储的fault传输给lsu。（page fault依旧查找tlb的当拍上报，access fault依旧在查找tlb的下一拍上报）
                                      l1dtlb中的PMP路径在TLB hit时进行，已在TLB hit时说清楚
        
        Q-L1DTLB-009: page_fault和access_fault是否可能同一pipe同拍同时为高？如果可能，优先级和scoreboard期望是什么；如果不可能，spec应明确互斥条件。
        人类工程师对Q-L1DTLB-009的回答：“同一条 LSU/MMU 请求”，page fault 和 access fault 是互斥的；如果只看裸的 mmu_lsu_page_faultx / mmu_lsu_access_faultx 端口同一周期波形，它们可能因为对应不同流水级/不同请求而同时为 1，不能直接当成同一请求双异常。
                                      对同一条请求/同一条指令：page fault 和 access fault 不应同时成立，是互斥异常。DTLB hit 路径：page fault 会阻止 PMP check，hit 后先算 page fault。只有没有 page fault 时，才启动 PMP check。所以同一条 hit 请求如果已经因为 PTE 权限、A/D、U/S、VA illegal 等产生 page fault，就不会再生成这条请求的 PMP access fault。
                                      refill的情况已经在上一条问题中回答
                                      
        Q-L1DTLB-010: weakup/wakeup信号的准确名称、位宽和含义是什么？它是每个pipe独立、每个miss buffer entry独立，还是广播给LSU的全局提示？
        人类工程师对Q-L1DTLB-0010的回答：wakeup信号的准确名称是mmu_lsu_tlb_wakeup[11:0]。链路是：MMU/L1DTLB -> LSU: mmu_lsu_tlb_wakeup[11:0]，LSU -> IDU: lsu_idu_tlb_wakeup[11:0] 。含义是：当 当tlb要被写入了，或者lsu发来的请求在exception array hit， exception array中挂起的请求以 page fault/access fault 这种异常结果结束时，MMU 发出一个 TLB wakeup，提示等待 tlb_busy 的 LSU 指令可以重新参与调度/发射判断。
                                      mmu_lsu_tlb_wakeup[11:0]不是每个 pipe 独立的 wakeup。没有 wakeup0/wakeup1，也不带 load/store pipe 编号。它也不是精确到某条 IID 的完成信号。里面没有 IID compare，也没有标识“哪个请求完成”。它本质上是广播式全局提示，L1DTLB 生成时 12 位要么全 1，要么全 0。LSU 在 lsu/rtl/ct_lsu_ctrl.v:975 只是透传成 lsu_idu_tlb_wakeup[11:0]。IDU 侧把 12 位分别接到 12 个 LSIQ entry。每个 entry 收到自己的 x_tlb_wakeup，用于清掉该 entry 的 tlb_busy 等待状态，并允许它重新判断是否可发射。
                                      

        Q-L1DTLB-011: wakeup的触发源有哪些？请明确TLB install、miss buffer entry释放、miss buffer出现空位、exception array hit、PTW/L2TLB fault返回、RTU flush清理entry是否都会触发。
        人类工程师对Q-L1DTLB-0011的回答：wakeup的触发源有两种。
                                       第一种是：lsu发来的请求在exception array hit，标志着之前的某个请求以page fault/access fault 这种异常结果结束时，MMU 发出一个 TLB wakeup，提示等待 tlb_busy 的 LSU 指令可以重新参与调度/发射判断。
                                       第二种是：当tlb要被写入了（意味着有一条之前miss的请求要回填写进tlb）
                                      
        Q-L1DTLB-012: busy信号的拉高条件是什么？是任意miss buffer entry valid，还是miss buffer全满，还是当前无法接受新的miss请求？
        人类工程师对Q-L1DTLB-0012的回答：busy信号的拉高条件是任意miss buffer entry valid，意味着有miss请求正在refill。
                                      
        Q-L1DTLB-013: busy对lsu的协议含义是什么？busy为高时LSU是否仍可能发送va_vld请求；如果发送，l1dtlb应该正常处理、drop，还是要求LSU重试？
        人类工程师对Q-L1DTLB-0013的回答：mmu_lsu_tlb_busy 在 LSU 里的作用是：当一条 load/store 发生 uTLB miss 时，判断这次 miss 是可以马上 replay，还是必须挂到 IDU LSIQ 里等 TLB refill 完成后再 replay。它不是用来阻止LSU发 VA 请求，也不是全局停 LSU。                                      
                                      busy 对 LSU 的协议含义是：MMU/L1DTLB 当前有请求正在refill。它不是 va_vld 的 ready 反压信号。也就是说，busy=1 不等于“LSU 禁止发送 VA 请求”。busy=1 时，LSU 仍然可能发送 lsu_mmu_va_vld0/1 请求。
                                      原因是 DTLB 支持 hit-under-miss：虽然有请求在refill，但 L1 DTLB 本身仍然可以做查表。如果新来的 VA 在 L1 DTLB hit，就应该正常返回 pa_vld/pa/attr，不能因为 busy=1 就丢掉或屏蔽 hit 响应。
                                      busy意味着当前 DTLB 内存在未完成的 miss/refill，因此 miss 结果还不能立即完成，LSU 对 miss 指令应挂起等待 wakeup，等 MMU 后续发 tlb_wakeup 后再重试。    
                                      所以不是“LSU 看到 busy 就不许发请求”，也不是“DTLB 把所有 busy 期间的请求都 drop”。
                                      从 LSU 的角度看，如果busy=1，LSU 不再立即反复 replay，而是把对应 LSIQ entry 挂起到 tlb_busy 状态，等 tlb_wakeup 再发。
                                      一句话总结：busy 不是 VA 请求握手的 ready；它是“新 miss 不能被接受”的状态提示。LSU 可以继续发 VA，DTLB必须正常查 hit；miss 指令由 LSU 等 wakeup 后重试。
                                      busy=0 时发生 miss，所谓“LSU 立即 replay”，不是 LSU 自己固定把同一个 VA 请求再发一次，也不是 MMU 要求它马上重试一次。更准确地说：这条 LSU 指令这一次在 AG/DC 流水中已经失败了，不能继续往后走。LSU 给 IDU/LSIQ 对应 entry 一个 immediate wakeup，把这个 entry 从 freeze 状态释放出来，让它重新参与调度。至于它下一拍、隔几拍、还是更晚再发，由 IDU 的调度仲裁决定。所以 replay 的次数不是“硬件规定一次”。
                                      总结：
                                      1.L1 DTLB hit：不受 busy 影响，正常返回。
                                      2.L1 DTLB miss，miss buffer 空：可以分配第一个 entry，但 LSU 可能会 immediate replay 一次。
                                      3.L1 DTLB miss，miss buffer 已有有效 entry：MMU 仍然可以分配或 merge 这个 miss，但 LSU 应把该指令挂成 tlb_busy，等 refill/wakeup 后再发。
                                      4.L1 DTLB miss，miss buffer 满：不能分配，只能等 wakeup 后重试。

### 2.2 T0/T1流水线与对外时序
        Q-L1DTLB-014: T0、T1的边界需要精确定义。哪些信号在T0组合返回，哪些信号在T1寄存返回？请列出pa_vld、pa、attr、page_fault、access_fault、pmp_check_req、miss_vld、miss buffer分配的周期。
        人类工程师对Q-L1DTLB-0014的回答：pa_vld、pa、attr、page_fault均在T0组合逻辑返回。
                                       pmp_check_req在T0时，根据hit的结果和page fault的结果决定。当tlb hit并且没有page fault，或者关闭了dtlb并且没有page fault的时候，会拉高pmp check信号，拉高pmp check信号时，会把当前的pa寄存一排，在拉高pmp check信号的下一拍会进行pmp检查，如果pmp检查没通过，那么就在检查的这一拍拉高access fault信号。
                                       access_fault是在pmp检查的那一拍，即pa_vld的下一拍会拉高（如果pmp检查没通过的话）。
                                       miss_vld：对LSU来说，没有pa_vld=1的信号就意味着miss。而对mmu来说，当lsu发来的请求没有在tlb和exception array中hit时，就算miss；但是只有当请求在tlb和exception array和miss buffer中均miss时才会分配miss buffer entry。
                                       miss buffer分配的周期：T0时，lsu发来的请求在tlb和exception array中查找，当在tlb和exception array中均miss时，会把miss信号寄存一拍，在下一拍（即T1时）在miss buffer中查找，如果在miss buffer中也miss，那么就在T1这一拍分配miss buffer entry。                                       

        Q-L1DTLB-015: TLB hit且无page fault时，pa_vld是在T0返回还是等待PMP在T1完成后返回？如果T0已返回pa_vld而T1又发现PMP access fault，LSU如何关联这两个事件？
        人类工程师对Q-L1DTLB-0015的回答：TLB hit且无page fault时，pa_vld是在T0返回，无需等待PMP在T1的检查。
                                       如果T0已返回pa_vld，那么有两种情况
                                       情况一：T0时有page fault，那么T1就不会进行PMP的检查
                                       情况二：T0时没有page fault，那么T1会进行PMP的检查。如果在T1时发现PMP access fault，LSU 不是靠重新匹配地址来关联这两个事件，而是靠固定流水时序关联。T0 时，L1DTLB 命中后给 LSU 返回 pa_vld，同时 MMU 内部把这次请求的 PA、读写类型锁进 PMP 检查缓冲，并置起一个下一拍有效的 token，也就是类似 pmp_flg_vld 的标志。T1 时，PMP 结果回来。MMU 用上一拍保存的 PA 和读写类型判断 access fault，然后在同一个 MMU 端口上输出 mmu_lsu_access_fault0 或 mmu_lsu_access_fault1。LSU 这边同一条指令也按固定流水从 AG 推到后级。load 用 port0，store 用 port1。T0 的 pa_vld 被 AG 用来形成物理地址和页属性；T1 的 access fault 到来时，该指令已经在 DC/DA 对应位置，DA 级直接采样mmu_lsu_access_fault0/1 到 ld_da_expt_access_fault_mmu 或 st_da_expt_access_fault_mmu。
                                       所以关联关系是：同一端口、固定晚一拍、流水级对齐。T0 的 pa_vld 表示地址翻译结果可用，不表示 PMP 权限最终通过；T1 如果 PMP 报 access fault，LSU 在后级把这条已经前推的同一条访存指令标成异常，并阻止正常提交/前递。

        Q-L1DTLB-016: page fault在T0返回时，是否还会发起PMP check？如果不会，spec应明确page fault优先于PMP access fault。
        人类工程师对Q-L1DTLB-0016的回答：page fault在T0返回时，不会发起PMP check。page fault优先于PMP access fault。

        Q-L1DTLB-017: TLB hit且PMP check失败时，access_fault在T1输出时是否也需要pa_vld为高？PA和属性是否同时有效？
        人类工程师对Q-L1DTLB-0017的回答：TLB hit且PMP check失败时，access_fault在T1输出时有可能pa_vld也是高的，但是这个时候的pa_vld和access_fault肯定不是LSU同一次发来的请求的结果。
                                      pa_vld 表示当拍 L1 DTLB lookup / VA translation 有返回。access_fault 的 PMP 部分表示上一拍 hit 后发起的 PMP check 返回失败。
                                      PA 和属性应同时有效。即使最终因为 PMP deny 不允许真正访问 cache/总线，PA 仍然是 PMP check 的依据，属性也来自命中的 TLB entry。LSU 后续会因为 access fault 抑制正常访存副作用。

        Q-L1DTLB-018: exception array hit且fault类型为access fault时，当前描述说寄存一拍后T1拉高access fault。该T1是否相对于原LSU请求的T0，还是相对于exception array hit检测周期？
        人类工程师对Q-L1DTLB-0018的回答：该T1是否相对于exception array hit检测周期

        Q-L1DTLB-019: 如果同一pipe连续两拍发起请求，上一拍的T1 access_fault和下一拍的T0 page_fault可能重叠时，输出信号如何区分归属的iid/pipe？
        人类工程师对Q-L1DTLB-0019的回答：同一 pipe 连续两拍请求时，MMU 输出本身不带 IID tag，归属靠 LSU 流水级时序来区分。假设 load pipe0 连续两拍：第 N 拍：指令 A 在 AG 发 MMU 请求,MMU 返回 A 的 pa_vld，并把 A 的 PA/读写类型送去 PMP 检查。第 N+1 拍：指令 B 在 AG 发 MMU 请求，同时指令 A 已经推进到后一级,这时可能同时出现mmu_lsu_access_fault0 = 1，属于上一拍的 A，mmu_lsu_page_fault0 = 1，属于当前拍的 B。这两个信号虽然同一拍出现在同一个 pipe0 上，但被 LSU 不同流水级采样：page_fault 是 T0 结果，由当前 AG 指令 B 使用，并随 B 进入 DC/DA。access_fault 是 T1 结果，由上一拍已经在 DC/DA 位置的指令 A 使用，并采到 A 的 ld_da_expt_access_fault_mmu。
                                      所以区分方式是：pipe 归属靠端口号：0 是 load pipe，1 是 store pipe。IID 归属不靠 MMU fault 输出携带，而靠 LSU 自己流水寄存器里的 IID。A、B 的 IID 已经分别在不同 LSU stage 中，哪个 stage 采哪个 fault，fault 就归属于哪个 IID。

        Q-L1DTLB-020: 对外响应是否携带iid？如果不携带，scoreboard应如何在乱序或跨拍异常场景下匹配请求和响应？
        人类工程师对Q-L1DTLB-0020的回答：MMU的对外响应不携带iid。
        AI基于当前spec给出的UVM建模决策：scoreboard不应尝试从MMU响应端恢复iid，而应按pipe建立T0/T1流水队列来匹配请求和响应。
            pa_vld、pa、attr、page_fault属于当前pipe当前T0请求的结果。
            access_fault属于当前pipe上一拍已经进入PMP/后级异常检查路径的请求。
            如果同一拍同一pipe同时看到page_fault和access_fault，不能当作同一请求双异常；page_fault归当前T0请求，access_fault归上一拍T1请求。
            对exception array access fault，T1相对于exception array hit检测周期；scoreboard应把该请求在命中exception array的周期压入该pipe的access-fault pending槽，下一拍期望access_fault pulse。

### 2.3 双端口并发和仲裁
        Q-L1DTLB-021: pipe0和pipe1同拍都TLB hit时，是否都能同拍返回pa_vld/pa/attr？如果两个pipe命中同一个entry，PLRU如何更新？
        回答：pipe0和pipe1同拍都TLB hit时，都能同拍返回pa_vld/pa/attr。如果两个pipe命中同一个entry，PLRU正常更新。

        Q-L1DTLB-022: pipe0 hit、pipe1 miss同拍发生时，hit响应、miss buffer分配、PLRU更新和L2TLB request是否互不影响？如果有优先级，请明确。
        回答：pipe0 hit、pipe1 miss同拍发生时，hit响应、miss buffer分配和L2TLB request互不影响。PLRU的更新你可以暂时当成黑盒。

        Q-L1DTLB-023: pipe0和pipe1同拍都miss且属于同一4K page时，只给pipe0分配miss buffer entry的描述是否固定为pipe0优先，还是应按iid年龄或端口优先级决定？
        回答：pipe0和pipe1同拍都miss且属于同一4K page时，按端口优先级决定，固定为pipe0优先。

        Q-L1DTLB-024: pipe0和pipe1同拍都miss、不同4K page但只有一个miss buffer空位时，当前描述说选择iid更老者。若iid相等或不可比较，优先级是什么？
        回答：pipe0和pipe1同拍发请求到mmu时，iid 不可能相同。

        Q-L1DTLB-025: 双pipe同拍分别命中TLB和exception array时，exception array entry释放、miss buffer entry释放、wakeup、TLB hit响应是否都可以同拍发生？
        回答：双pipe同拍分别命中TLB和exception array时，exception array entry释放、miss buffer entry释放、wakeup、TLB hit响应都可以同拍发生

        Q-L1DTLB-026: 双pipe同拍都命中同一个exception array entry时，是两个pipe都上报fault，还是只有一个pipe消费并释放entry？如果只允许一个，请明确优先级。
        回答：pipe0和pipe1同拍发请求到mmu时，iid 不可能相同。命中exception array entry需要对比VPN和iid

        Q-L1DTLB-027: 双pipe同拍都需要分配miss buffer且都有空位时，entry选择规则是什么？是固定最低空闲entry、按pipe顺序、还是其他策略？
        回答：双pipe同拍都需要分配miss buffer且都有空位时，会选择miss buffer中的两个最低空闲entry

### 2.4 TLB Hit、权限、属性和特殊模式
        Q-L1DTLB-028: l1dtlb entry中需要保存哪些字段？请明确VPN、PPN、page size、权限位、cache属性、global/user/dirty/accessed等属性是否在L1DTLB中存在并由scoreboard建模。
        回答：l1dtlb entry中实际保存这些字段：valid；VPN[26:0]；PPN[27:0]；page size[2:0]：one-hot，001=4K、010=2M、100=1G；flag[13:0]，flag[13:0] 基本对应：flg[0] V，flg[1] R，flg[2] W，flg[3] X，flg[4] U，flg[5] A，flg[6] D，flg[7:8]  RSW / 保留软件位，flg[9]  sec，flg[10] share，flg[11] bufferable，flg[12] cacheable，flg[13] strong-order / SO。这些 flag 在refill的时候回填进tlb。L1 DTLB hit 后会用这些位做权限检查和 cache 属性输出，比如 U/A/D/R/W/X page fault 判断、ca/buf/sh/sec/so 输出。
            global(G) L1 DTLB entry 中没有作为 flag 保存，ASID     L1 DTLB entry 中也没有。
            AI基于当前spec给出的UVM建模决策：scoreboard/reference model需要建模valid、VPN、PPN、page size、flag[13:0]这些L1DTLB entry字段，否则无法独立预测PA、page fault和属性输出。
            global(G)和ASID不作为L1DTLB entry字段建模；ASID/SATP相关变化按spec描述触发L1DTLB全清。
            如果PLRU暂时作为黑盒，则scoreboard不需要精确预测“哪一个entry会被替换”，但一旦通过可观测refill/install路径确认某个翻译进入L1DTLB，后续hit返回的PA、属性和fault行为必须按这些entry字段检查。

        Q-L1DTLB-029: l1dtlb支持哪些page size？4K、2M、1G或其他page size的VPN比较位宽分别是什么？
        回答：VPN_WIDTH 是 27，对应 Sv39 的 VA[38:12]。每级 9 bit：VPN2 = VPN[26:18]，VPN1 = VPN[17:9]，VPN0 = VPN[8:0]。
              4K需要比较完整的27bit VPN，即VA[38:12]
              2M 只需要比较 VPN[26:9] 共 18 bit；
              1G只需要比较VPN的最高位VPN2 = VPN[26:18]

        Q-L1DTLB-030: 如果多个TLB entry同时命中同一VA，spec期望选择哪个entry？这是非法状态需要报错，还是有确定优先级？
        回答：官方 privileged spec 明确允许 address-translation cache/TLB 里同时存在多个能匹配同一 address/ASID 的 entry。硬件不需要报 illegal state / page fault。
              当前 RTL 微架构行为是最高 index 命中优先。
              设计UVM的时候可以做一个 micro-arch invariant 检查 “L1DTLB 不应产生 multi-hit”，但失败应归类为设计约束/性能或一致性风险。

        Q-L1DTLB-031: load、store、AMO/STAMO在page fault权限判断上的完整规则是什么？请明确R/W/X/U/S/M、MXR、SUM、A/D位等条件是否属于l1dtlb判断范围。
        回答：L1DTLB 命中路径会判断 V/R/W/X/U、当前 U/S/M mode、MXR、SUM、A/D，以及 VA illegal；PMP、cacheable/share/buffer/secure 等不是 page fault 权限判断，属于 access fault 或属性检查。
            PTE flag 含义：V：有效位，R：读权限，W：写权限，X：执行权限，U：user page，A：accessed，D：dirty。
            在以下两种情况下，LSU 的地址访问不按页表 PTE 来判 page fault：
                1.MMU 关闭。MMU 关闭时，D-L1TLB 不查 TLB，不查 PTE.V/R/W/X/U/A/D，也不看 MXR/SUM。地址基本按直通路径生成 PA，所以不会因为“页不存在、页不可读、A/D 位不对”等原因报 page fault。
                2.effective privilege 是 M mode 时，也一样。这个设计里 D-L1TLB 把 M mode 当作 MMU off/bypass 处理，不走普通页表翻译，所以 LSU page fault 被关掉。
                但这两种情况不等于访问一定成功。page fault 是页表/PTE 相关异常；PMP access fault 是物理地址保护相关异常。即使 D-L1TLB bypass 了页表，生成了物理地址，后面 PMP 仍可能拒绝这个物理地址访问，于是报 access fault，而不是 page fault。另外 “effective privilege” 不是简单等于当前 CPU privilege。对 load/store，如果 MPRV=1，RTL 里 effective mode 会用 MPP；如果当前在 M mode，但 MPRV=1 且 MPP=S/U，那 LSU 访存会按 S/U mode 走正常 DTLB/page fault 规则，而不是 M-mode bypass。
                一句话总结：MMU off 或 effective M mode：不查页表，所以没有 LSU page fault；但物理地址保护还可能报 access fault。
            load 的 page fault 条件：load 需要 PTE.V=1；如果 PTE.W=1 且 PTE.R=0，属于非法 PTE，page fault；读权限要求 PTE.R=1，或者 MXR=1 且 PTE.X=1。也就是说 MXR 只对 load 有效，可以把 executable page 当作 readable page；S mode 访问 U=1 的 user page 时，如果 SUM=0，page fault；SUM=1 才允许数据 load；U mode 访问 U=0 的 supervisor page，page fault；PTE.A 必须为 1，否则 page fault；PTE.D 对 load 不要求；PTE.W 对 load 不要求，除了 W=1/R=0 这个非法组合；PTE.X 对 load 只通过 MXR 起作用，不是单独要求。
            store 的 page fault 条件：store 需要 PTE.V=1；如果 PTE.W=1 且 PTE.R=0，属于非法 PTE，page fault；store 必须 PTE.W=1，否则 page fault；S mode 访问 U=1 的 user page 时，如果 SUM=0，page fault；U mode 访问 U=0 的 supervisor page，page fault；PTE.A 必须为 1，否则 page fault；PTE.D 必须为 1，否则 page fault；PTE.R 对 store 不单独要求，除了 W=1/R=0 非法组合。
            AMO/LDAMO 的 page fault 条件：AMO 不能靠 MXR 读取 X-only page；MXR 不救 AMOR 位同 store 一样，不单独要求，但 W=1/R=0 仍是非法 PTE，page fault。
            STAMO 的情况：STAMO 有专门的 stamo_vld/PA 路径，设计注释明确是为了避免 deadlock，STAMO 不重新查 TLB，而使用 LM 侧已有信息。所以 STAMO 本身不在 L1DTLB 里重新做 R/W/X/U/S/M、MXR、SUM、A/D 的 page fault 权限判断。权限应由前面的 AMO/LM 阶段建立；STAMO 后续仍可能遇到 PMP/access fault 或 LSU 自己的异常，但那不是 L1DTLB PTE page fault 判断。
            额外说明：VA illegal 属于 L1DTLB page fault 范围。A 位属于 L1DTLB 判断范围，load/store/AMO 都要求 A=1。D 位属于 L1DTLB 判断范围，但只对 write-type 生效，也就是 store 和 AMO；普通 load 不要求 D=1。X 位对 LSU D-L1DTLB 不表示“可执行检查”，只在 load+MXR 时作为可读替代条件。取指的 X 权限检查属于 I-TLB 路径。

        Q-L1DTLB-032: STAMO是否需要经过TLB lookup、permission check和PMP check？如果存在STAMO bypass，请明确只支持pipe0还是两个pipe都支持，以及bypass时PA/attr/fault如何产生。
        回答：STAMO 本身不做新的 TLB lookup、PTE permission check，也不做新的 PMP check。它有专门 bypass，只支持 store pipe，也就是 pipe1/port1；pipe0/port0 不支持 STAMO bypass，相关信号被绑成 0。STAMO 的 PA 来自 LM 保存的地址，也就是前面 LDAMO/AMO load 阶段已经翻译得到的物理地址。STAMO 送到 MMU 时用 stamo_vld 选择这一路 PA，而不是重新用 VA 查 D-L1TLB。STAMO 的属性也来自 LM 保存的属性，包括 cacheable、SO、bufferable、secure、share。这些属性是在前面 LDAMO 经过 MMU 翻译时得到并保存下来的，STAMO 不重新从 TLB/PTE/PMA 生成。STAMO 本身不产生新的 page fault，也不产生新的 TLB miss。因为 STAMO 的普通 mmu_req 为 0，不走正常 VA lookup 和权限判断路径。STAMO 本身也不重新做 PMP check。PMP/权限约束依赖前面的 LDAMO 阶段完成；LDAMO 会按 AMO/store-like 权限去查 TLB 和检查权限，并做 PMP 相关检查。
              所以一句话：STAMO 是 pipe1 专用 bypass，PA/attr/fault 基本复用前面 LDAMO/LM 的结果；STAMO 阶段不再重新翻译、不再重新做 PTE 权限和 PMP 检查。

        Q-L1DTLB-033: MMU off、machine mode、direct map或sysmap bypass是否属于l1dtlb spec范围？若属于，请明确默认PA、属性、fault和PMP行为。
        回答：L1DTLB 的 spec 应包含 MMU off、effective machine mode 下的 direct map 行为，因为这是 L1DTLB 对 LSU 的输出行为，不是单个 TLB entry 的内容。
              当 regs_mmu_en=0 或 effective privilege 是 M-mode 时，L1DTLB 不查 entry，也不产生 TLB miss。
              地址直接映射：物理页号等于虚拟地址的页号，也就是 PA 等于 VA 的低 40 位页地址加原 page offset。此时 pa_vld 有效，page fault固定不报，VA canonical 检查也被绕过。
              属性来自 sysmap。sysmap 给出 sec/share/buf/cache/so 这 5 个属性，L1DTLB 用它们组成默认 flag，同时默认 V/R/W/X/A/D 都为 1，U 为 0。最终输出属性是：sec 来自 sysmap，share 来自 sysmap 但会被 smp_disable 关掉，buf 在sysmap bufferable 为 1 或不是 strong-order 时为 1，so 来自 sysmap，ca 在 sysmap cacheable 为 1 且不是 strong-order 时为 1。
              direct map 不绕过 PMP。L1DTLB 会把 direct PA 送给 PMP，PMP 返回权限后仍可能产生 access fault。load/read 看 PMP read 许可，store 看 PMP write 许可。effective M-mode 只有在 PMP entry 没有 lock 时可以绕过 PMP deny；如果 PMP lock 置位，M-mode 也会因为 PMP deny 报 access fault。
              所以一句话：MMU off/M-mode/direct map/sysmap bypass 属于 L1DTLB 对 LSU 的行为 spec；默认是 VA 直通成 PA，属性取 sysmap，page fault 不报，PMP 仍检查并可报 access fault。

        Q-L1DTLB-034: PMP access fault是只在TLB hit后由PMP模块产生，还是PTW/L2TLB refill也可能携带access fault？两类access fault在输出时序上是否一致？
        回答：PMP access fault既可由TLB hit后由PMP模块产生，也可以在PTW/L2TLB refill时携带。两类access fault在输出时序上一致，但是PTW/L2TLB refill时携带的access fault是在exception array中挂起，后续lsu发来的请求在exception array中hit之后才会上报，上报时序跟PMP检查的access fault一致。

### 2.5 Miss Buffer分配、去重和请求重试
        Q-L1DTLB-035: miss buffer CAM比较固定按4K VPN比较。对于2M/1G page的miss，去重仍然按完整4K VPN，还是按最终page size相关的VPN比较？
        人类工程师对Q-L1DTLB-0035的回答：miss buffer CAM比较固定按4K VPN比较。对于2M/1G page的miss，去重仍然按完整4K VPN比较。

        Q-L1DTLB-036: T0 TLB miss且exception array miss后，T1 miss buffer CAM hit时，LSU本次请求是否会收到任何响应或wakeup，还是完全依赖已有miss完成后LSU重试？
        人类工程师对Q-L1DTLB-0035的回答：T0 TLB miss且exception array miss后，T1 miss buffer CAM hit时，LSU本次请求只会在T0时收到pa_vld=0（在lsu看来是当成miss处理），并且weakup信号不会因为在miss buffer中hit拉高。对于这个T0 TLB miss且exception array miss后，T1 miss buffer CAM hit的请求，lsu只会在这个miss 完成refill之后，且lsu再次发这个请求给mmu时会获得response。

        Q-L1DTLB-037: miss buffer无空位导致不分配entry时，本次LSU请求是否被drop？是否需要busy或wakeup通知LSU重发？
        回答：miss buffer无空位导致不分配entry时，本次LSU请求被drop。busy会在miss buffer 存在任意有效的entry时拉高（有miss请求正在refill），所以如果miss buffer无空位，此时busy一定是拉高的，当busy为高时，如果lsu的请求miss，那么会把这个请求冻住，当后续lsu收到weakup信号之后，解冻重发。

        Q-L1DTLB-038: 一个miss buffer entry能否代表多个等待同一4K page的LSU请求？如果能，entry中是否记录多个iid/pipe；如果不能，后续同VPN请求如何获得正确响应？
        回答：一个miss buffer entry能否代表多个等待同一4K page的LSU请求，但是不记录多个iid/pipe。只要lsu发来的请求在4K颗粒度上与miss buffer中正在refill的请求命中，那么就不会在miss buffer中分配entry。后续miss buffer中的请求完成refill之后，会写进tlb，lsu发来的请求会在tlb中命中，并获得response。

        Q-L1DTLB-039: miss buffer entry valid、sent、wfi等状态信号与FSM状态之间是否存在严格对应关系？例如valid是否等价于state!=IDLE，sent是否等价于已经进入WFC/WFI/PGFLT/ACFLT/ABT中的某些状态？
        回答：valid 和 FSM 有严格等价关系：entry_vld == (state != IDLE)。这是直接组合赋值。 wfi 和 FSM 有严格等价关系：entry_wfi == (state == WFI)。wfc 不是只等价于 WFC，而是 entry_wfc == (state == WFC || state == ABT)。ABT 也被当成 waiting-complete 类状态，因为已经发出去的请求还在等 late refill 回来后清 entry。
             ready 不是纯状态别名。它基本表示 state == WFG。但是还有一个前提就是本拍没有被rtu冲刷。
             issued/sent 不应写成严格状态等价。entry_issued 是 latch，不是状态译码。它在请求拿到 issue_grant 时置 1，包括 IDLE 直接 bypass 到 WFC，或 WFG 发出到 WFC；之后一直保持，直到 entry 回到 IDLE 后再清。
        Q-L1DTLB-040: 当miss buffer entry处于PGFLT或ACFLT时，entry保留的目的是什么？是为了等待原请求重放命中exception array，还是为了防止同VPN重复分配？
        回答：当miss buffer entry处于PGFLT或ACFLT时，entry保留的目的是为了等待原请求重放命中exception array，且本次不分配miss buffer。

        Q-L1DTLB-041: PGFLT/ACFLT状态的entry在没有后续LSU请求命中exception array时是否可能一直保持？是否有flush、timeout或其他清除条件？
        回答：PGFLT/ACFLT状态的entry在没有后续LSU请求命中exception array时一直保持。当rtu发来flush信号时，释放这个entry，回到idle状态，valid拉低。

### 2.6 L2TLB Request和Credit
        Q-L1DTLB-042: credit计数器初始值是多少？它等于L2TLB request queue中DTLB专用entry数量，还是总entry数量？
        回答：credit计数器初始值是L2TLB request queue中DTLB专用entry数量。

        Q-L1DTLB-043: credit计数器的最大值、最小值、饱和/溢出处理是什么？scoreboard是否需要检查credit守恒？
        回答：credit计数器的最大值是L2TLB request queue中DTLB专用entry数量，最小值是0。当前 RTL 没有显式饱和或溢出保护。scoreboard需要检查credit守恒。

        Q-L1DTLB-044: credit为0且同拍收到credit return时可以发请求。该请求是否消耗同拍归还的credit，使计数值保持0？
        回答：credit为0且同拍收到credit return时可以发请求。该请求消耗同拍归还的credit，使计数值保持0。

        Q-L1DTLB-045: 每拍最多发送一个请求到L2TLB。该限制是否包括bypass请求和miss buffer中未发送请求的总和？
        回答：每拍最多发送一个请求到L2TLB。该限制包括bypass请求和miss buffer中未发送请求的总和。

        Q-L1DTLB-046: 当miss buffer中已有未发送entry，同时当前周期又产生可bypass的新miss时，优先发送miss buffer旧entry还是当前bypass请求？
        回答：当miss buffer中已有未发送entry，同时当前周期又产生可bypass的新miss时，优先发送miss buffer旧entry。

        Q-L1DTLB-047: bypass发送到L2TLB的请求是否也必须先分配miss buffer entry？若L2TLB request被接受后，entry下一拍应进入WFC还是其他状态？
        回答：bypass发送到L2TLB的请求也要分配miss buffer entry。在分配miss buffer entry的同一拍，直接把这个bypass请求发下去。由于l1和l2采取credit-based的握手协议，所以只要l1能发请求给l2，那么这个请求一定会被l2接收。对应的miss buffer entry在下一拍进入WFC。

        Q-L1DTLB-048: L2TLB request需要携带哪些字段？请明确VA/VPN、asid、page size预测、load/store类型、iid、pipe id、miss buffer id等是否需要进入reference model。
        回答：L1 DTLB -> L2TLB 携带：request valid：d_req_valid；VPN：d_req_vpn[26:0]；miss buffer entry id：d_req_eid[2:0]；access type 信息：当前接口是 d_req_is_load。在 L2TLB 内部，d_req_is_load 会被转换成 3-bit type：load  -> 3'b010，store -> 3'b110。
              page size、PPN、permission/cache flag，这些是 L2  或 PTW refill 返回给 L1 的结果，不是 L1 miss request 的输入字段。
              AI基于当前spec给出的UVM建模决策：reference model需要记录L1 DTLB发往L2TLB request中的VPN、access type和miss buffer entry id。
              VPN用于关联后续L2TLB/PTW refill或fault结果；access type用于判断load/store相关的下游PMP/PTW访问属性；miss buffer entry id用于更新对应MB entry、exception array entry和credit守恒。
              L1DTLB->L2TLB request接口本身不携带iid、pipe id、asid或page size预测，因此reference model不应把这些字段作为该request的精确接口字段检查。
              page size、PPN、permission/cache flag是refill返回结果，应该在refill进入L1DTLB时更新到对应MB entry或TLB entry中。

### 2.7 Refill、Install和TLB写入
        Q-L1DTLB-049: PTW refill和L2TLB refill的语义差异是什么？两者是否都可能返回正常翻译、page fault和access fault？
        回答：L2TLB refill是l1发到下游的请求在l2tlb中hit，那么由l2tlb返回对应的数据给l1。PTW refill是指l1发到下游的请求在l2tlb中也miss了，走ptw通道去拿回页表数据。
              L2TLB refill会返回正常翻译、page fault，但不会返回access fault，因为l2tlb没有做pmp的检查。
              PTW refill会返回正常翻译、page fault和access fault。

        Q-L1DTLB-050: 每拍只能写一个TLB entry时，install仲裁优先级是否固定为WFI entry > PTW refill > L2TLB refill？如果不是，请给出完整优先级。
        回答：每拍只能写一个TLB entry时，install仲裁优先级固定为WFI entry > PTW normal refill > L2TLB normal refill。
              refill携带fault时不参与TLB install仲裁，而是并行写exception array并使对应miss buffer entry进入PGFLT或ACFLT。

        Q-L1DTLB-051: 如果同拍多个miss buffer entry处于WFI，选择哪个entry install？是固定entry编号优先、PLRU相关、年龄优先，还是其他规则？
        回答：如果同拍多个miss buffer entry处于WFI，选择 最低 entry 编号优先。

        Q-L1DTLB-052: PTW/L2TLB refill正常返回但未获得TLB install授权时，返回数据锁存在哪里？对应miss buffer entry进入WFI后需要保留哪些字段？
        回答：PTW/L2TLB refill正常返回但未获得TLB install授权时，返回数据锁存在对应的 miss buffer entry 里。进入 WFI 后，该 entry 至少需要保留这些字段：1.vpn_r 原始 miss VA 的 VPN，用于后续 install 写 L1DTLB tag。2.ppn_r  refill 返回的 PPN。3.flg_r refill 返回的权限/cache/属性位。4.pgs_r  refill 返回的 page size。

        Q-L1DTLB-053: refill携带fault时是否一定不写TLB？如果fault和正常install候选同拍出现，fault entry是否仍然写exception array并释放/改变miss buffer状态？
        回答：refill携带fault时一定不写TLB。
              如果 fault 和正常 install 候选同拍出现：正常候选仍按 install 仲裁写 TLB：现在是 WFI > PTW normal > L2TLB normal。fault 候选不参与 install 仲裁，但会并行写 exception array。fault 对应的 miss buffer entry 在收到refill之后转到 STATE_PGFLT 或 STATE_ACFLT，不立即释放，等后续 LSU replay hit exception CAM，后才回到 IDLE

        Q-L1DTLB-054: PTW和L2TLB同拍都返回fault时，是否允许同拍写入两个exception array entry？如果array写端口有限，请明确优先级和丢弃/延迟策略。
        回答：PTW和L2TLB同拍都返回fault时，允许同拍写入两个exception array entry。

        Q-L1DTLB-055: refill返回的miss buffer id如果对应entry不在WFC状态，spec期望如何处理？例如entry已被flush到IDLE、处于ABT、或处于PGFLT/ACFLT。
        回答：spec 期望 refill 返回的 MB id 只有在对应 entry 处于 WFC 时才被当作有效完成处理。否则按 stale/late response 处理，不能写 DTLB、不能写 exception array、不能产生 LSU wakeup。ABT 是唯一特殊态：允许 late refill 到达后只用于 drain/释放 entry 回 IDLE。
        
        Q-L1DTLB-056: ABT状态下late refill到达时，是否必须禁止TLB install和exception array写入？是否需要归还资源或产生wakeup？
        回答：ABT状态下late refill到达时，必须禁止TLB install和exception array写入。对应的miss buffer entry回到IDLE状态，不产生weakup。

        Q-L1DTLB-057: TLB写入后，原miss buffer entry是在同拍释放还是下一拍释放？LSU能否在同拍新请求命中刚写入的TLB entry？
        回答：TLB 写入和原 miss buffer entry 释放是在同一个时钟沿完成的。LSU 不能在 refill/写入发生前的同一组合周期命中刚写入 entry；但写入沿之后的下一可见周期可以命中。

### 2.8 Exception Array
        Q-L1DTLB-058: exception array entry数量是否必须等于miss buffer深度？如果不等，满阵列时fault refill如何处理？
        回答：exception array entry数量必须等于miss buffer深度。

        Q-L1DTLB-059: exception array entry的索引是否直接使用refill携带的miss buffer id？如果是，entry生命周期是否和对应miss buffer entry严格绑定？
        回答：exception array entry的索引直接使用refill携带的miss buffer id，entry生命周期和对应miss buffer entry严格绑定。
              fault refill写入exception array后，对应miss buffer entry进入PGFLT或ACFLT并保持valid。
              该exception array entry保持到后续LSU replay请求以iid+4K VPN命中exception array，或RTU flush清空exception array和miss buffer。
              后续LSU replay命中exception array时，exception array entry和对应miss buffer entry同拍释放。

        Q-L1DTLB-060: exception array CAM匹配key是iid+VPN。VPN按4K完整VPN比较，还是按page size比较？是否包含pipe id、asid、store/load类型？
        回答：exception array CAM匹配key是iid+VPN。VPN按4K完整VPN比较。不包含pipe id、asid、store/load类型。

        Q-L1DTLB-061: 后续LSU请求命中exception array后，释放exception array entry和对应miss buffer entry是在同拍还是下一拍？
        回答：后续LSU请求命中exception array后，释放exception array entry和对应miss buffer entry是在同拍。

        Q-L1DTLB-062: exception array hit时是否必须禁止给该请求分配新的miss buffer entry？如果同拍也满足TLB hit，哪个结果优先？
        回答：exception array hit时必须禁止给该请求分配新的miss buffer entry。
              正常情况下，同一请求如果在exception array hit就不应同时TLB hit，因为exception array中的请求来自fault refill，fault refill不会写入TLB。
              AI基于当前spec给出的UVM建模决策：scoreboard应把“同一pipe同一请求同时TLB hit和exception array hit”视为design/spec violation，而不是在scoreboard中定义容错优先级。

        Q-L1DTLB-063: exception array中page fault和access fault的输出时序是否不同？请明确page fault T0、access fault T1的原因和scoreboard匹配方式。
        回答：exception array中page fault和access fault的输出时序在之前的问题中有完整且详细的描述，page fault T0、access fault T1的原因也在之前的问题中有完整且详细的描述。

        Q-L1DTLB-064: RTU flush清空exception array时，对应miss buffer entry是否也全部清空？如果有refill随后返回，如何避免旧fault再次被消费？
        回答：RTU flush清空exception array时，对应miss buffer entry也全部清空。正是因为RTU flush会清空miss buffer entry，而miss buffer entry又和exception array高度绑定，才需要在RTU flush到来时清空exception array。

### 2.9 Flush、Invalidate、Reset和Entry清理
        Q-L1DTLB-065: regs_utlb_clr、tlboper_utlb_clr、ctc_inv_va_hit_clr同时发生时，清理优先级是什么？是否都只影响TLB entry valid，不影响miss buffer和exception array？
        回答：没有三者之间的清理优先级。对于任何一个entry来说，只要任意一个为 1，该 entry 的 valid 就被清 0。它们都只影响TLB entry valid，不影响miss buffer和exception array。

        Q-L1DTLB-066: tlboper_utlb_clr会清空全部L1DTLB entry。它是否也应该清空miss buffer中正在等待的请求或exception array中的fault？
        回答：tlboper_utlb_clr不会清理miss buffer中正在等待的请求或exception array中的fault，只清理L1DTLB entry。

        Q-L1DTLB-067: regs_utlb_clr由SATP变化触发。若L1DTLB entry不保存ASID，所有ASID相关失效操作是否都应全清L1DTLB？
        回答：对L1DTLB/L1ITLB 这种不保存 ASID 的 uTLB 来说，ASID 相关失效操作在 L1 上必须按全清处理，不能只清某个 ASID 的 entry。

        Q-L1DTLB-068: VA定点失效只比较VPN低8 bit是否是架构/微架构spec允许的保守失效行为？reference model是否也应按低8 bit误清建模，还是只需保证被指定VA一定失效？
        回答：VA定点失效只比较VPN低8 bit是架构/微架构spec允许的保守失效行为。
              AI基于当前spec给出的UVM建模决策：如果scoreboard只做功能最终结果检查，那么只需要保证被指定VA的旧翻译后续不能继续命中。
              如果scoreboard/reference model要逐拍预测L1DTLB hit/miss、TLB entry内容或后续refill次数，则必须按VPN低8 bit相同即保守清除来建模，因为误清会改变后续是否hit和是否重新refill。

        Q-L1DTLB-069: invalidate与TLB hit同拍发生时，本拍hit是否仍可返回旧entry，还是invalidate优先导致miss？
        回答：invalidate与TLB hit同拍发生时，本拍仍可返回旧entry；invalidate清除entry valid的效果从下一拍及之后体现。
              scoreboard在同拍invalidate+hit场景下不应把本拍旧entry返回判为错误，但下一拍开始该entry不能再作为有效翻译命中。

        Q-L1DTLB-070: invalidate与TLB install同拍选择同一个entry时，最终entry valid应为0还是1？
        回答：invalidate与TLB install同拍选择同一个entry时，最终 valid 为 0，因为 clear 优先级高于 install/update。
        
        Q-L1DTLB-071: reset释放后的初始状态需要明确哪些内容？TLB valid、miss buffer state/valid/sent、exception array valid、credit counter、PLRU状态分别是什么？
        回答：reset 释放后的 L1DTLB 初始状态建议按下面明确：
                TLB entry：valid 全 0。vpn/ppn/flg/pgs reset 为 0，但功能上应视为 don't care，因为 valid=0。复位后任何 VA lookup 都不应命中 TLB。
                Miss buffer：每个 entry state = IDLE。entry_vld = 0，因为 RTL 定义为 state != IDLE。sent/issued reset 后为 0。entry_ready/WFC/WFI 均为 0。abort_hold/fault_hold = 0，无 outstanding refill、无 late response 等待。
                Exception array：所有 entry valid = 0。iid/vpn/pgflt/acflt reset 为 0，但 valid=0 下功能 don't care。reset 后不能 replay hit exception array，也不能产生 fault wakeup。
                Credit counter：credit_cnt = CREDIT_MAX，当前 DTLB scheduler 实例是 8。含义是 reset 后 L1DTLB 认为 L2TLB ReqQ 全空，最多可发 8 个新请求。
                PLRU当成黑盒，只需要知道它会选出一个victim entry即可。

        Q-L1DTLB-072: RTU flush与L2TLB request发送同拍、refill完成同拍、TLB install同拍时，miss buffer FSM的最终状态和对外响应优先级是什么？
        回答：WFG+flush+grant -> ABT；WFC+flush+refill -> IDLE；WFI+flush -> IDLE；
              可以概括为：
                1. flush/abort kill 优先：被 flush 的 miss 不允许产生 TLB install、exception array write、LSU wakeup。
                2. request 是否已发出决定 IDLE 还是 ABT：没发出可直接 IDLE；已发出必须 ABT 等返回，避免旧 refill id 后续污染新请求。
                3. late refill 只做资源回收：ABT + refill_vld -> IDLE，不写 TLB、不写 exception array、不 wakeup。

### 2.10 PLRU和替换策略
#### 2.10.1 PLRU在UVM验证中暂时当成黑盒
        Q-L1DTLB-073: PLRU victim选择在所有TLB entry中进行，还是按bank/way分组？NUM_ENTRY、bank数量和每组entry数量需要明确。
        Q-L1DTLB-074: TLB hit是否更新PLRU？如果更新，pipe0/pipe1同拍hit不同entry时如何串行化更新？
        Q-L1DTLB-075: TLB install是否更新PLRU？如果install和hit同拍发生，PLRU更新优先级是什么？
        Q-L1DTLB-076: TLB entry被invalidate后，PLRU是否需要更新或优先选择invalid entry作为victim？
        AI基于当前spec给出的UVM建模决策：主功能scoreboard暂时不精确建模PLRU victim选择、hit更新、install更新和invalidate后的PLRU状态。
            主功能scoreboard只检查可观测功能结果：某个翻译一旦通过可观测refill/install路径进入L1DTLB，后续命中时PA、属性和fault应符合该entry字段；被invalidate/flush/reset清除后不能继续作为有效翻译使用。
            如果测试需要验证替换策略，应单独建立white-box assertion或coverage，通过RTL内部PLRU/victim观测点检查，不能把PLRU精确预测混入主translation scoreboard。
            在黑盒口径下，随机替换导致的“hit还是miss”不作为主scoreboard强判条件；主scoreboard应允许L1DTLB miss后由L2TLB/PTW重新给出同一architectural translation。

### 2.11 UVM Reference Model和Scoreboard口径
    所有和UVM有关的内容我都不太懂，需要AI根据spec的内容来协助我决策。
        Q-L1DTLB-077: 后续审核UVM时，l1dtlb reference model允许建模哪些内部结构？TLB、miss buffer、exception array、credit、PLRU是否都属于spec可见模型？
        AI基于当前spec给出的UVM建模决策：reference model应建模TLB entry、miss buffer、exception array、credit counter和per-pipe T0/T1流水。
            TLB entry用于预测PA、属性、page fault和hit/miss。
            miss buffer用于预测分配、去重、full/drop、WFG/WFC/WFI/PGFLT/ACFLT/ABT状态和refill关联。
            exception array用于预测fault replay、page_fault/access_fault输出时序和entry释放。
            credit counter用于检查L1DTLB->L2TLB request流控和credit守恒。
            PLRU在当前阶段只作为黑盒处理，不进入主功能reference model的精确预测。
        Q-L1DTLB-078: 哪些行为必须只从外部接口判断，不能依赖RTL内部探针？例如MB FSM状态、PLRU victim、exception array entry id是否允许作为scoreboard观测点？
        AI基于当前spec给出的UVM建模决策：主scoreboard的pass/fail应优先基于外部接口和spec可推导状态，不依赖RTL内部探针作为唯一真值。
            可以用外部请求、响应、refill、L2TLB request、flush/invalidate、wakeup/busy来推导TLB/MB/exception/credit模型。
            RTL内部MB FSM状态、exception array entry id、PLRU victim可以作为debug辅助观测或white-box assertion/coverage，但不能替代spec reference model。
            对PLRU victim这类当前被定义为黑盒的行为，内部探针只能用于专项检查，不应让主scoreboard因为PLRU预测不同而误报translation错误。
        Q-L1DTLB-079: 对于spec未定义但RTL有固定实现的仲裁细节，UVM应检查精确实现，还是只检查功能等价和无错误响应？
        AI基于当前spec给出的UVM建模决策：如果spec已经定义仲裁规则，UVM应精确检查，例如双pipe同4K miss固定pipe0优先、不同4K且一个空位按iid年龄、WFI多entry最低编号优先、install优先级WFI > PTW > L2TLB。
            如果spec明确标成黑盒或未定义，例如PLRU victim选择，主UVM只检查功能等价和无错误响应，不检查固定RTL实现。
            如果后续希望把某个RTL固定行为纳入UVM精确检查，应先把它补进spec，再把对应检查从debug/coverage升级为scoreboard或assertion。
        Q-L1DTLB-080: 如果同一请求可能因为busy/full/abort/flush被drop或重试，scoreboard如何识别这是合法无响应而不是漏响应？
        AI基于当前spec给出的UVM建模决策：scoreboard应为每个pipe请求建立状态分类。
            TLB hit、MMU off/M-mode direct map、VA illegal page fault、exception array page fault会在T0产生终态结果。
            PMP access fault和exception array access fault会在T1产生1-cycle access_fault。
            TLB miss且MB hit、MB full未分配、busy下miss等待replay、abort阻止状态后果、flush kill请求，均可能是合法无响应或只产生miss等待状态，不应立刻报漏响应。
            对合法无响应请求，scoreboard应期待后续由wakeup提示LSU replay，或由flush/abort终止，不应要求原请求一定产生PA/fault响应。
        Q-L1DTLB-081: 对PA、属性、page_fault、access_fault、wakeup、busy、miss统计等信号，哪些属于必须逐拍精确比较，哪些只需事件级或最终状态比较？
        AI基于当前spec给出的UVM建模决策：pa_vld、pa、属性、page_fault、access_fault应逐pipe、逐拍精确比较，但access_fault要按T1流水归属匹配。
            L1DTLB->L2TLB request valid、VPN、access type、MB entry id和credit counter应逐拍精确检查。
            busy应逐拍精确检查，其条件是任意miss buffer entry valid。
            wakeup是广播式全局提示，不携带iid/pipe，不应作为某条请求完成信号逐请求匹配；可按事件级检查其触发条件和广播全1/全0形态。
            miss统计/HPC类信号建议事件级检查，确认只在真实miss场景计数，不作为translation correctness的核心oracle。
        Q-L1DTLB-082: l1dtlb相关覆盖点应覆盖哪些spec行为？请确认是否需要覆盖双pipe并发、同VPN去重、MB full、credit边界、WFI仲裁、fault replay、flush/refill race、invalidate/install race等场景。
        AI基于当前spec给出的UVM建模决策：l1dtlb覆盖点至少应覆盖以下场景：双pipe同拍hit、hit+miss、双miss同4K去重、双miss不同4K双分配、双miss不同4K但仅一个空位按iid年龄选择、MB hit不再分配、MB full drop并等待wakeup replay、credit>0发送、credit=0且同拍return发送、MB旧请求优先于bypass、bypass allocate+issue同拍进入WFC、WFI > PTW > L2TLB install仲裁、多个WFI最低entry优先、PTW/L2TLB fault写exception array、fault replay释放entry、ABT late refill drain、RTU flush与grant/refill/install race、invalidate与hit同拍、invalidate与install同拍clear优先、MMU off/M-mode direct map、STAMO pipe1 bypass、page fault T0和access fault T1重叠归属。


## 3. L1DTLB Requirement-Driven Test Audit Table Format

### 3.1 Scope
        当前阶段从l1dtlb_function_description.md中的功能描述和requirement出发，反向审核verification plan和UVM中已有l1dtlb测试点是否覆盖正确、是否漏测、是否误测、是否重复测，以及是否暴露出TB建模缺口。
        表格主键必须是L1DTLB function item / requirement item，而不是coverage item。
        如果从coverage item出发，只能审核已有coverage是否合理；本阶段的目标是从spec出发检查verification plan和UVM是否完整、客观、与spec一致。
        当前阶段只决定测试点应保留、删除、修改、拆分、合并或新增，不进入reference model和scoreboard实现设计。
        因此表格不使用scoreboard reference列，避免把测试点审核和scoreboard建模混在一起。
        如果某个测试点后续确实需要scoreboard/reference model支持，只在Action Notes中标记“后续需要scoreboard支持”，不在本阶段展开实现方案。

### 3.2 推荐表格字段
        | Audit ID | L1DTLB Function / Requirement Item | Spec Source | Required Scenario / Condition | Expected Behavior | Related Verification Plan Item | Related UVM Test / Sequence | Observable Check | Current Status | Gap Type | Action | Action Notes |
        | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB-AUD-001 | 待审核的l1dtlb功能项或requirement名称 | 本文档中的章节、Q编号或关键描述 | 触发该requirement所需的场景、输入组合或时序条件 | 根据spec应验证的行为，不写RTL实现细节 | verification plan中的功能点、测试点或用例编号；没有则写N/A | 当前UVM中已有test/sequence名称；没有则写N/A | 当前阶段可从接口、log、coverage或test intent中观察到的检查点 | keep / modify / add / delete / split / merge / unclear | no_gap / missing_test / wrong_expected / duplicate / weak_check / tb_model_gap / spec_gap | 保留 / 修改 / 新增 / 删除 / 拆分 / 合并 / 待澄清 | 简要说明原因、缺口、建议改动和后续依赖 |

### 3.3 字段填写规则
        Audit ID：使用稳定编号，例如L1DTLB-AUD-001、L1DTLB-AUD-002。一个审核行只覆盖一个明确function/requirement，避免一行同时包含多个独立功能要求。
        L1DTLB Function / Requirement Item：写从spec抽取出来的功能项或需求项，例如“双pipe同拍hit”、“MB full drop并等待wakeup replay”、“ABT late refill drain”。这是表格主键，不使用coverage item作为主键。
        Spec Source：引用本文件中的原始依据，例如“pipeline description / Q-L1DTLB-023 / Q-L1DTLB-082”。如果spec依据不足，写“spec gap”。
        Required Scenario / Condition：写触发该requirement的最小条件，例如“pipe0/pipe1同拍miss且同4K VPN，MB至少1个空位”。
        Expected Behavior：只写按spec应发生什么，例如“pipe0分配MB，pipe1不分配”、“fault refill不写TLB，写exception array并等待replay”。
        Related Verification Plan Item：填写现有verification plan中的条目编号、章节或测试名；如果未找到对应项，写N/A。
        Related UVM Test / Sequence：填写当前UVM中已有的test、vseq或sequence；如果没有，写N/A。
        Observable Check：当前测试点审核阶段只写可观察/可判断的检查方向，例如“test是否制造该并发场景”、“coverage是否采到该组合”、“log是否能区分pipe0/pipe1”。不写scoreboard内部算法。
        Current Status：只允许使用keep、modify、add、delete、split、merge、unclear。
        Gap Type：记录缺口类型。no_gap表示无缺口；missing_test表示spec有要求但plan/UVM没有测试；wrong_expected表示现有测试期望与spec冲突；duplicate表示重复测试；weak_check表示测试刺激存在但检查不足；tb_model_gap表示测试需要TB能力但当前TB看起来不支持；spec_gap表示spec还不足以判断。
        Action：写下一步动作，例如“保留现有测试”、“修改stimulus以覆盖同拍credit return”、“新增directed test”、“删除与spec冲突的测试”、“拆成两个独立测试点”。
        Action Notes：写简短理由。若需要后续scoreboard/reference model支持，只标记依赖，不在本表中设计实现。

### 3.4 Current Status含义
        keep：该requirement已有测试覆盖，现有测试点与spec一致，覆盖目标清晰，可以保留。
        modify：该requirement已有测试覆盖方向，但stimulus、期望行为、命名、覆盖条件或检查点需要调整。
        add：spec要求该行为应被测试，但verification plan或UVM中未找到对应测试点。
        delete：现有测试点与spec冲突、重复无价值，或测试了不应作为l1dtlb目标的行为。
        split：一个现有测试点混合了多个独立spec行为，建议拆分。
        merge：多个测试点覆盖同一spec行为且无必要区分，建议合并。
        unclear：无法仅凭当前spec或现有测试说明判断，需要补充信息。

### 3.5 Gap Type含义
        no_gap：未发现测试点缺口。
        missing_test：漏测，spec中存在requirement，但verification plan和UVM没有对应测试点。
        wrong_expected：误测，现有测试点的expected behavior与spec不一致。
        duplicate：重复测，多个测试点覆盖同一requirement且没有必要区分。
        weak_check：弱检查，stimulus可能覆盖到了场景，但没有足够可观察检查来证明行为正确。
        tb_model_gap：TB建模缺口，测试该requirement需要monitor、coverage、agent、sequence控制或检查能力，但当前TB可能缺失。
        spec_gap：spec缺口，当前spec不足以决定测试点该如何设计或判定。

### 3.6 Action取值建议
        保留现有测试
        修改测试目标或expected behavior
        修改stimulus/sequence
        修改coverage item
        新增directed test
        新增random/constrained-random覆盖
        删除测试点
        拆分测试点
        合并测试点
        标记为后续scoreboard/reference model阶段处理

### 3.7 已完成审核表
        审核依据包括本文档第1章功能描述、第2章Q&A澄清、doc/MMU_VerificationPlan_final.md、doc/section6_3_lsu_l1dtlb_l2tlb_tlbop_baseline_tc.md，以及当前UVM中的l1dtlb_tests、phase9 common sequence、lsu sequence、mmu vseq、translation scoreboard、credit scoreboard和coverage/probe。
        当前审核共形成64条requirement-driven记录：keep 2条，modify 12条，add 47条，delete 1条，split 2条，unclear 0条。

#### 3.7.1 本轮新增/修正定位

本轮新增内容位于3.7审核表末尾，新增Audit ID为`L1DTLB-AUD-056`到`L1DTLB-AUD-064`；对应的plan-only测试点索引位于3.8第二张表末尾。

新增审核项如下：
- `L1DTLB-AUD-056`：MB entry状态派生信号一致性，新增`DTLB_MB_STATE_SIGNAL_001`。
- `L1DTLB-AUD-057`：WFI refill数据保持，新增`DTLB_WFI_DATA_HOLD_001`。
- `L1DTLB-AUD-058`：exception array容量和MB id映射，新增`DTLB_EXPT_ID_MAP_001`。
- `L1DTLB-AUD-059`：PGFLT/ACFLT保持与flush释放，新增`DTLB_MB_FAULT_HOLD_001`。
- `L1DTLB-AUD-060`：非WFC refill返回按stale/late处理，新增`DTLB_REFILL_STALE_ID_001`。
- `L1DTLB-AUD-061`：TLB install可见性和MB释放时序，新增`DTLB_INSTALL_VISIBILITY_001`。
- `L1DTLB-AUD-062`：access fault来源一致性，新增`DTLB_ACCESS_FAULT_SOURCE_PARITY_001`。
- `L1DTLB-AUD-063`：reference model观测边界和逐拍比较规则，新增`DTLB_REF_MODEL_OBSERVABILITY_001`。
- `L1DTLB-AUD-064`：RTU flush与MB FSM同拍race矩阵，新增`DTLB_MB_FLUSH_RACE_MATRIX_001`。

本轮同时修正/强化的已有审核项如下：
- `L1DTLB-AUD-006`：补充双pipe双miss时选择两个最低空闲MB entry，新增`DTLB_ALLOC_TWO_LOWEST_FREE_001`。
- `L1DTLB-AUD-029`：将“双pipe同拍命中同一个exception entry”改为负向约束，不再保留port0 priority消费期望，新增`DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001`。
- `L1DTLB-AUD-039`/`L1DTLB-AUD-040`：修正STAMO方向，明确STAMO是pipe1/store pipe bypass，pipe0为negative场景，新增`DTLB_STAMO_PIPE1_BYPASS_001`和`DTLB_STAMO_PIPE0_NEG_001`。

#### 3.7.2 审核明细表

        | Audit ID | L1DTLB Function / Requirement Item | Spec Source | Required Scenario / Condition | Expected Behavior | Related Verification Plan Item | Related UVM Test / Sequence | Observable Check | Current Status | Gap Type | Action | Action Notes |
        | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB-AUD-001 | pipe0 basic hit | 1.3, Q-L1DTLB-021 | pipe0 VA命中有效4K L1DTLB entry | T0返回pa_vld、PA和属性，不分配miss buffer | F2.1, F2.4, DTLB_HIT_001 | test_mmu_l1dtlb_dtlb_hit_001 / lsu_pipe0_only_seq | LSU monitor和translation_sb比较PA/fault | keep | no_gap | 保留现有测试 | 当前smoke覆盖有价值，可作为pipe0 hit baseline保留。 |
        | L1DTLB-AUD-002 | pipe1 basic hit | 1.3, Q-L1DTLB-001, Q-L1DTLB-021 | pipe1 VA命中有效4K L1DTLB entry | T0独立返回pa_vld、PA和属性 | F2.1, F2.4, DTLB_HIT_002 | test_mmu_l1dtlb_dtlb_hit_002 / lsu_pipe1_only_seq | LSU monitor和translation_sb比较PA/fault | keep | no_gap | 保留现有测试 | pipe1端口与pipe0不完全对称，保留单独smoke。 |
        | L1DTLB-AUD-003 | pipe0和pipe1同拍hit | 1.3, Q-L1DTLB-021, Q-L1DTLB-082 | pipe0和pipe1同一cycle同时valid，覆盖同entry和不同entry | 两个端口同拍返回T0 hit结果 | F2.1, DTLB_CONCURRENT_001 | wrapper使用mmu_concurrent_3pipe_vseq；lsu_01_concurrent_seq为空 | 观察同拍请求、两个端口hit vector和PA response | modify | weak_check | 修改stimulus/coverage | 现有vseq偏随机交错，不保证同拍同VPN或不同VPN hit，需要directed pipe01 sequence或coverage gate。 |
        | L1DTLB-AUD-004 | 同拍一个pipe hit、一个pipe miss | Q-L1DTLB-022, Q-L1DTLB-082 | 一个pipe hit，另一个pipe miss并需要MB allocation | hit response不被miss路径阻塞；miss按规则分配和发L2请求 | TC-GAP-DTLB-011, DTLB_CONCURRENT_002 | mmu_concurrent_3pipe_vseq | cross entry_hit和dutlb_miss_vld，并观察LSU response | add | missing_test | 新增directed test | 当前random可能覆盖但没有命名检查，建议新增DTLB_HIT_MISS_CONCURRENT_001。 |
        | L1DTLB-AUD-005 | 双pipe同4K page miss去重 | 1.3, Q-L1DTLB-023, Q-L1DTLB-035 | pipe0和pipe1同拍miss同一个完整27-bit 4K VPN，MB至少一个空位 | 只为pipe0分配一个MB entry，pipe1不再分配第二个entry | F2.3, DTLB_ALLOC_001 | mmu_ptw_thrash_vseq | MB allocation count、allocated VPN、pipe0/pipe1 miss probe | add | missing_test | 新增directed test | 压力vseq不能证明同4K去重规则。 |
        | L1DTLB-AUD-006 | 双pipe不同4K page miss且有两个free MB | 1.3, Q-L1DTLB-027 | pipe0和pipe1 miss不同完整27-bit VPN，至少两个MB entry空闲 | 两个miss在T1分配到miss buffer中的两个最低空闲entry | F2.3, DTLB_ALLOC_001, DTLB_ALLOC_TWO_LOWEST_FREE_001 | mmu_ptw_thrash_vseq | 同cycle两个allocation事件、allocated MB id和MB valid delta为2 | add | missing_test | 新增directed test | 需要证明dual allocation和最低空闲entry选择，而不是只做MB压力。 |
        | L1DTLB-AUD-007 | 双pipe不同4K page miss但只剩一个free MB | 1.3, Q-L1DTLB-005, Q-L1DTLB-024 | 仅一个MB entry空闲，两个pipe miss不同VPN，IID年龄含wrap边界 | older IID赢得allocation，younger request不分配 | F2.16, TC-GAP-DTLB-003 | N/A | allocated entry IID/VPN和未分配pipe的drop/no-response行为 | add | missing_test | 新增directed test | 现有random没有强制old-vs-young或IID wrap边界。 |
        | L1DTLB-AUD-008 | MB full drop/retry | 1.3, Q-L1DTLB-037, Q-L1DTLB-080 | 8个MB entry全valid，新TLB/expt-CAM miss到达 | 不分配新MB entry，LSU依靠busy/wakeup/replay协议重试 | F2.3, DTLB_MB_001, DTLB_MB_002, TC-GAP-DTLB-003 | mmu_ptw_thrash_vseq | MB full=8 bin、无allocation、LSU drop/retry观察 | modify | weak_check | 修改coverage和directed stimulus | 当前whitebox cg_l1dtlb没有MB full=8 bin，需要精确full场景和coverage。 |
        | L1DTLB-AUD-009 | mmu_lsu_tlb_busy语义 | 1.2, Q-L1DTLB-012, Q-L1DTLB-013 | 任意MB entry valid，包括occupancy=1 | mmu_lsu_tlb_busy拉高；它不是MB full指示，也不全局阻止LSU发请求 | Row 15, F2.18, PTW-031, TC-GAP-DTLB-007 | 未看到独立l1dtlb wrapper，plan中有mb_full seq描述 | cross tlb_busy和MB occupancy 1..8以及LSU request | modify | wrong_expected | 修改plan/test intent | 将“busy只在full时拉高”或“mb_full seq”类期望改为“任意MB valid即busy”，新增DTLB_BUSY_ANY_INFLIGHT_001。 |
        | L1DTLB-AUD-010 | wakeup broadcast语义 | 1.2, Q-L1DTLB-010, Q-L1DTLB-011 | TLB install或exception array replay completion发生 | mmu_lsu_tlb_wakeup[11:0]为broadcast，只有12'hfff或12'h000，不是per pipe、per IID或per entry | Row 15, F2.17, F4.23, TC-GAP-DTLB-006 | 未看到已实现L1DTLB wrapper | LSU monitor采样tlb_wakeup；top probe观察install/expt事件 | add | missing_test | 新增directed test | 分别增加install-wakeup和expt-wakeup测试，不检查onehot/per-entry语义。 |
        | L1DTLB-AUD-011 | abort hit response允许返回 | 1.1, Q-L1DTLB-003, Q-L1DTLB-004 | va_vld=1、abort=1且TLB hit | DTLB可以仍返回T0 PA/attr，LSU自行丢弃；abort不等价于所有输出清零 | DTLB_ABORT_001 | lsu_abort_seq | 观察hit+abort response，而不仅是无污染 | split | weak_check | 拆分测试点 | abort测试应拆为hit+abort、miss+abort、expt+abort三类独立期望。 |
        | L1DTLB-AUD-012 | abort miss不分配、不refill | 1.1, Q-L1DTLB-004 | abort=1且该请求本来会miss | 不分配MB，不发L2 request，不进入stateful refill flow | DTLB_ABORT_001, TC-BUG-WFG-ABT-001 | lsu_abort_seq | MB valid delta和L2 request probe | modify | weak_check | 修改stimulus/check | 现有sequence会驱动abort，但不保证miss/no-allocation被观测。 |
        | L1DTLB-AUD-013 | abort不消费exception array | 1.1, Q-L1DTLB-004 | aborted request命中pending expt-CAM entry | 不向该aborted request报告page/access fault，expt entry不因abort释放 | DTLB_ABORT_001, v7.4 expt lifecycle plan | 无directed wrapper | expt-CAM write/match/clear probe和LSU fault signal | add | missing_test | 新增directed test | 这是独立abort语义，不应隐藏在普通abort smoke中。 |
        | L1DTLB-AUD-014 | vabuf无功能影响 | 1.1, Q-L1DTLB-002 | 相同VA/IID/type下改变vabuf | PA/fault/attribute和allocation行为不变 | N/A | 无directed wrapper | 比较不同vabuf下LSU req/rsp | add | missing_test | 新增低优先级directed或random cover | monitor记录vabuf，但当前没有锁定no-effect contract。 |
        | L1DTLB-AUD-015 | T0/T1 response timing和fault pulse宽度 | 1.3, Q-L1DTLB-007, Q-L1DTLB-008, Q-L1DTLB-014, Q-L1DTLB-015, Q-L1DTLB-018, Q-L1DTLB-019 | hit、page fault、PMP access fault、expt replay page/access fault | pa_vld/PA/page_fault按spec在T0，access_fault按spec在T1；page/access fault为1-cycle pulse，同一request互斥 | F2.7-F2.9, DTLB_PERM_*, PMP tests | translation_sb, LSU covergroups | per-pipe temporal SVA/coverage、pulse width、request ownership | add | weak_check | 新增SVA/coverage | 现有scoreboard检查结果，但没有完整assert pulse width和T0/T1归属。 |
        | L1DTLB-AUD-016 | load访问R=0触发page fault | Q-L1DTLB-006, Q-L1DTLB-031 | load访问R=0且不能被MXR放行的leaf PTE | T0返回pa_vld和page_fault，该request不进入PMP检查 | F2.7, DTLB_PERM_LD_001 | wrapper使用lsu_st_ld_mix_seq和正常mapping | directed PTE setup和LSU fault response | modify | weak_check | 修改stimulus | 当前sequence没有构造R=0 PTE。 |
        | L1DTLB-AUD-017 | load MXR行为 | Q-L1DTLB-006, Q-L1DTLB-031 | load访问X=1/R=0 page，分别设置MXR=0和MXR=1 | MXR=0 fault；MXR=1在其他检查通过时允许读 | F2.7, DTLB_PERM_LD_002 | lsu_st_ld_mix_seq | CP0 MXR设置、directed PTE和LSU response | modify | weak_check | 修改stimulus | 当前wrapper没有控制MXR或X-only mapping。 |
        | L1DTLB-AUD-018 | store访问W=0和D=0 page fault | Q-L1DTLB-006, Q-L1DTLB-031 | store访问W=0 page；store访问D=0 page | page fault；L1DTLB测试不应期待硬件D-bit update/writeback | F2.8, DTLB_PERM_ST_001, DTLB_PERM_ST_002 | lsu_st_ld_mix_seq | directed PTE setup、PTE不变、page_fault pulse | modify | wrong_expected | 修改expected behavior | 将“store触发D-bit update”改为“D=0 store page fault/trap-only”，wrapper需要directed PTE控制。 |
        | L1DTLB-AUD-019 | store flag影响L2 request/PMP type | Q-L1DTLB-006, Q-L1DTLB-048 | load miss和store miss发送到L2/PTW/PMP | request type反映load/store，store路径使用写相关PMP/permission检查 | F2.10, F3.5/TC-BUG-006 adjacent | 无L1DTLB-directed wrapper | L1D到L2 request type probe或L2 acc_type coverage | add | missing_test | 新增directed test/coverage | 当前permission wrapper只做pipe0随机流量，不能证明request type传播。 |
        | L1DTLB-AUD-020 | MB CAM hit不分配、不wakeup | Q-L1DTLB-035, Q-L1DTLB-036, Q-L1DTLB-038 | 第二个请求访问已有pending MB entry的完整27-bit 4K VPN | 不新增MB entry，不立即wakeup；后续只能在refill/replay后成功 | F2.3, DTLB_MB_* | mmu_ptw_thrash_vseq | MB valid count、wakeup、后续replay response | add | missing_test | 新增directed test | 该场景不同于同拍dual-miss dedup，需要单独测试。 |
        | L1DTLB-AUD-021 | credit counter边界 | 1.4, Q-L1DTLB-042, Q-L1DTLB-043, Q-L1DTLB-044 | credit到0，同时发生credit return和request fire | credit初始/最大值为L2TLB request queue中DTLB专用entry数量，最小值为0；同拍return时可以fire request，return和fire同拍时credit计数保持稳定；scoreboard检查credit守恒 | F2.3, F2.10, DTLB_CREDIT_001, DTLB_CREDIT_002, DTLB_CREDIT_BOUND_001 | mmu_concurrent_3pipe_vseq；mmu_credit_sb仅做外部近似跟踪 | exact scheduler credit probe或SVA | modify | weak_check | 修改test/check | 现有credit测试不强制也不检查内部credit边界；DTLB_CREDIT_002当前更接近随机fairness/pressure，仍缺credit=0同拍return的directed check。 |
        | L1DTLB-AUD-022 | 每cycle最多一个L2 request和scheduler priority | 1.4, Q-L1DTLB-045, Q-L1DTLB-046 | 存在old unsent MB entry，同时新miss可走bypass | 最多发送一个request；old unsent MB优先于current bypass request | F2.10, F2.19, DTLB_SCHED_001 | mmu_concurrent_3pipe_vseq | L2 request valid/type/id和MB sent state | add | missing_test | 新增directed test | 当前sched测试名实际映射generic vseq，不能证明priority。 |
        | L1DTLB-AUD-023 | bypass allocate+issue路径 | 1.4, 1.8, Q-L1DTLB-047 | 新miss同cycle分配并发往L2 | 该entry下一cycle进入WFC，而不是WFG | F2.3a, TC-BUG-BYPASS-001 | 未看到L1DTLB wrapper | MB state transition coverage/SVA | add | missing_test | 新增directed test或SVA | verification plan有目标，但当前l1dtlb_tests未实现。 |
        | L1DTLB-AUD-024 | install arbitration优先级WFI大于PTW大于L2 | 1.5, Q-L1DTLB-050 | WFI candidate、PTW refill和L2 refill同cycle竞争 | 只写一个TLB entry，优先级为WFI、PTW、L2 | F2.15, TC-GAP-DTLB-002, DTLB_REFILL_001, DTLB_REFILL_002, DTLB_INSTALL_ARB_001 | mmu_ptw_thrash_vseq, mmu_concurrent_3pipe_vseq | install select probe如sel_wfi/sel_ptw/sel_jtlb和entry update | add | missing_test | 新增directed test/SVA | 现有refill测试是压力测试，不能证明arbitration priority；DTLB_REFILL_002当前只是generic concurrent pressure。 |
        | L1DTLB-AUD-025 | 多个WFI entry选择规则 | 1.5, Q-L1DTLB-051 | 两个或更多MB entry同时处于WFI | 选择最低entry编号的WFI entry进行install；每拍仍只允许一个TLB entry被写入 | TC-GAP-DTLB-001/002, DTLB_MB_FSM_WFI_001 | 无wrapper | MB WFI vector、selected install source、entry update id | add | missing_test | 新增directed test/SVA | 第2章已明确多WFI时最低entry编号优先，第三章应作为明确测试点跟踪。 |
        | L1DTLB-AUD-026 | fault refill写exception array、不写TLB | 1.6, Q-L1DTLB-049, Q-L1DTLB-053 | PTW对WFC MB entry返回page/access fault，或L2 refill返回page fault | fault写入expt array；不为该fault install TLB entry；L2 refill不应作为access fault来源 | F2.20, DTLB_MB_PGFLT_001 | 无directed L1DTLB wrapper | expt write probe、无entry update、后续LSU fault replay | add | missing_test | 新增directed fault-refill test | translation scoreboard有expt-CAM shadow能力，但没有命名测试稳定制造该路径。 |
        | L1DTLB-AUD-027 | PTW和L2同拍fault write | 1.6, Q-L1DTLB-054 | PTW和L2同cycle对不同MB ID返回fault | 两个exception entry都记录；若端口有限则检查spec-defined priority | F2.20/v7.4 expt lifecycle | 无wrapper | l1d_expt_wr0_vld和l1d_expt_wr1_vld probe | add | missing_test | 新增directed test/SVA | plan提到lifecycle，但未看到已实现测试。 |
        | L1DTLB-AUD-028 | exception array replay和consume | 1.3, 1.6, Q-L1DTLB-059, Q-L1DTLB-060, Q-L1DTLB-061, Q-L1DTLB-062, Q-L1DTLB-063, Q-L1DTLB-064 | LSU replay匹配IID和完整4K VPN的fault entry | expt entry和匹配MB entry同拍释放；page fault为T0，access fault为T1；expt hit禁止新分配MB | v7.4 expt lifecycle, DTLB_MB_PGFLT_001 | translation_sb expt-CAM shadow；无wrapper | expt match/clear、MB valid drop、LSU fault response | add | weak_check | 新增directed test | scoreboard有部分建模，但coverage/test intent应显式驱动并观察lifecycle。 |
        | L1DTLB-AUD-029 | 双pipe同拍命中同一个exception entry负向约束 | Q-L1DTLB-026, Q-L1DTLB-082 | 两个pipe同cycle访问相同VPN但IID不同，或构造非法同IID观察 | 合法同拍pipe0/pipe1 IID不可能相同；由于expt match需要VPN+IID，两个pipe不应同时命中同一个expt entry；若出现应作为SVA/diagnostic失败，不做port0 priority消费期望 | DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001 | 无wrapper/SVA文件观察到 | expt match0/1、IID/VPN compare和clear count | add | missing_test | 新增负向SVA/diagnostic test | 第2章明确同拍pipe IID不可能相同，原port0 priority期望应修正。 |
        | L1DTLB-AUD-030 | ABT late refill drain | 1.7, 1.8, Q-L1DTLB-056, Q-L1DTLB-072 | RTU flush/abort使MB entry进入ABT，之后PTW/L2 late refill到达 | 不install TLB，不写expt array；entry drain到IDLE | F2.3b, F2.20, TC-BUG-WFG-ABT-001, DTLB_MB_ABT_LATE_REFILL_001 | 无L1DTLB wrapper | MB state、refill valid、entry update/expt write absence | add | missing_test | 新增directed race test | mmu_sfence_during_walk_vseq不够定向。 |
        | L1DTLB-AUD-031 | RTU flush清MB和exception array | 1.6, 1.8, Q-L1DTLB-064, Q-L1DTLB-072 | RTU flush时MB/expt entry valid | MB和expt array清空；late refill不能复活旧fault/install | F10.11, DTLB_INV_004 adjacent | mmu_sfence_during_walk_vseq, mmu_reset_midtransaction_vseq elsewhere | MB valid vector、expt probe、late refill no-effect | add | missing_test | 新增L1DTLB-directed flush race | 当前random flush/stress不专门检查L1DTLB MB/expt cleanup。 |
        | L1DTLB-AUD-032 | L1DTLB全相联match支持4K/2M/1G | 1.7, Q-L1DTLB-028, Q-L1DTLB-029, Q-L1DTLB-030, Q-L1DTLB-082 | 构造4K、2M、1G translation entry并访问匹配VA | 按page-size-specific VPN bits匹配并返回正确PA/attribute/fault；duplicate multi-hit另行澄清 | F2.4-F2.6 | 未看到l1dtlb_tests huge-page wrapper | LSU response和refill page-size probe | add | missing_test | 新增huge-page L1DTLB测试 | plan列出DTLB huge功能，但当前l1dtlb suite没有huge-page wrapper。 |
        | L1DTLB-AUD-033 | 多个TLB entry同时匹配同一VA | Q-L1DTLB-030 | 构造overlap/stale entries使同一VA可能命中多个entry | 架构上允许translation cache multi-hit，不应报illegal/page fault；若检查RTL微架构mux，则当前RTL为最高index命中优先；也可增加“不应产生multi-hit”的micro-arch invariant coverage | GAP-X3.7, DTLB_DUAL_HIT_MUX_001 | 无wrapper | hit vector、PA mux output、multi-hit invariant probe | add | missing_test | 新增whitebox/micro-arch diagnostic test | 第2章已明确Q-L1DTLB-030答案；该项不再是spec_gap，但不应作为普通black-box architectural pass/fail。 |
        | L1DTLB-AUD-034 | invalidate all只清L1DTLB entry | 1.7, Q-L1DTLB-065, Q-L1DTLB-066 | tlboper_utlb_clr asserted | L1DTLB entries invalidated；该信号本身不清MB/expt entries | F2.13, DTLB_INV_001 | tlb_inv_all_seq | entry-valid probe和MB/expt no-clear check | modify | weak_check | 修改check | 现有测试驱动invalidate，但应区分entry clear和MB/expt lifecycle。 |
        | L1DTLB-AUD-035 | SATP/ASID相关L1 clear | 1.7, Q-L1DTLB-067 | SATP变化或ASID invalidate影响L1DTLB | 因L1DTLB不存ASID，ASID相关L1 invalidation应保守full clear所有L1DTLB entry | F2.13, DTLB_INV_003, CROSSASID_001 | tlb_inv_asid_seq | 操作后的entry-valid vector和后续refill/miss | modify | wrong_expected | 修改expected behavior | 不应期待ASID-selective L1DTLB invalidation；L2TLB可以另有ASID语义。 |
        | L1DTLB-AUD-036 | VA invalidate按VPN低8位保守清除 | 1.7, Q-L1DTLB-068 | 两个entry的VPN不同但VPN[7:0]相同，对其中一个VA执行invalidate | 可能保守清除两者；至少target VA必须失效 | F2.13, DTLB_INV_002 | tlb_inv_va_seq | entry valid vector和后续hit/miss/refill | add | missing_test | 新增directed test | 现有VA invalidate测试不能证明低8位保守清除行为。 |
        | L1DTLB-AUD-037 | invalidate和hit同cycle | Q-L1DTLB-069, Q-L1DTLB-082 | LSU hit request和matching invalidate同cycle发生 | 本拍仍可返回旧entry的hit结果；invalidate清valid的效果从下一拍开始体现，后续不能再命中该entry | DTLB_INV_004, DTLB_INV_HIT_SAME_CYCLE_001 | mmu_sfence_during_walk_vseq | 同cycle LSU response、entry clear、下一拍follow-up miss/refill | add | missing_test | 新增directed check | 第2章已明确old-hit同拍允许返回，下一拍起entry失效；现有random race不能替代精确检查。 |
        | L1DTLB-AUD-038 | invalidate和install同entry同cycle | Q-L1DTLB-070, Q-L1DTLB-082 | install选择的entry同cycle也被invalidate清除 | 最终valid为0，clear优先级高于install/update；该entry后续不能作为有效翻译命中 | DTLB_INV_004, DTLB_REFILL_*, DTLB_INV_INSTALL_SAME_ENTRY_001 | 无directed wrapper | entry update/clear同拍、cycle后valid、follow-up miss/refill | add | missing_test | 新增directed race test/SVA | 第2章已明确clear优先于install，第三章应作为明确测试点而非spec_gap。 |
        | L1DTLB-AUD-039 | STAMO pipe1 bypass行为 | Q-L1DTLB-001, Q-L1DTLB-032 | STAMO在store pipe/pipe1支持路径上发生 | STAMO使用LM保存的PA和属性旁路，不重新查TLB、不做新的PTE/PMP检查、不产生TLB miss，也不制造MB/refill污染 | F2.14, DTLB_STAMO_001, DTLB_STAMO_PIPE1_BYPASS_001 | lsu_stamo_seq | LSU STAMO monitor、translation_sb STAMO handling、MB valid no-change、PA/attr source | modify | wrong_expected | 修改stimulus/check | 原“pipe0 bypass”表述与第2章相反；应修正为pipe1/store pipe专用bypass，并补no-pollution和PA-source检查。 |
        | L1DTLB-AUD-040 | STAMO pipe0 negative | Q-L1DTLB-001, Q-L1DTLB-032 | pipe0出现普通请求，同时环境中存在STAMO/LM旁路活动 | pipe0不支持STAMO bypass，相关STAMO bypass信号对pipe0无功能影响；pipe0请求仍按正常TLB/direct-map/fault路径处理 | F2.14, TC-GAP-DTLB-005, DTLB_STAMO_PIPE0_NEG_001 | 无wrapper | pipe0 PA source/fault response、MB/refill变化、STAMO signal tie-off | add | missing_test | 新增directed negative test | plan中的STAMO非对称测试应以pipe0不支持bypass为负向场景。 |
        | L1DTLB-AUD-041 | MMU off或machine-mode direct map | Q-L1DTLB-033 | MMU disabled或machine mode下pipe0/pipe1请求 | PA直接生成，不进入refill flow，attribute/fault按direct-map规则 | F2.NEW.3, row 15 | 无L1DTLB wrapper | dutlb_xx_mmu_off、LSU PA/fault、无MB/L2 request | add | missing_test | 新增directed test | spec将该行为纳入L1DTLB范围，当前l1dtlb测试只用SV39 enabled bring-up。 |
        | L1DTLB-AUD-042 | reset initial state | Q-L1DTLB-071 | reset release | TLB valid=0，MB/expt invalid，credit counter初始化为CREDIT_MAX，PLRU初值仅whitebox覆盖 | General reset/regression | 无L1DTLB-specific wrapper | reset后whitebox probe | add | missing_test | 新增smoke SVA/check | 当前测试依赖reset但没有显式审核L1DTLB初始状态。 |
        | L1DTLB-AUD-043 | PLRU exact replacement policy | 2.10.1, Q-L1DTLB-073, Q-L1DTLB-074, Q-L1DTLB-075, Q-L1DTLB-076 | fill、hit、invalidate之后发生replacement | 主translation scoreboard不应预测精确PLRU victim；replacement fairness只放whitebox SVA/coverage | F2.2, DTLB_PLRU_001 | mmu_ptw_thrash_vseq；mmu_plru_sva.sv onehot0 | whitebox PLRU victim onehot/coverage | delete | wrong_expected | 删除black-box exact PLRU期望，保留whitebox检查 | 不保留假设exact LRU/PLRU victim的functional pass/fail测试；DTLB_PLRU_001如保留应改名或改作whitebox coverage。 |
        | L1DTLB-AUD-044 | 现有MB pressure wrappers重复映射 | 3.5 duplicate criteria | DTLB_ALLOC_001、DTLB_MB_001、DTLB_MB_002、DTLB_REFILL_001、DTLB_PLRU_001都映射到mmu_ptw_thrash_vseq | 这些wrapper当前共享sequence，但它们代表的requirements并不等价 | Section 6.3 baseline TC | 多个wrapper使用mmu_ptw_thrash_vseq | wrapper metadata和实际coverage对比 | split | duplicate | 拆分或retarget wrappers | 可暂时保留为traceability shells，但每个wrapper后续应retarget到独立directed场景，否则只是重复smoke。 |
        | L1DTLB-AUD-045 | MMU对外响应不携带IID | Q-L1DTLB-019, Q-L1DTLB-020 | 同一pipe连续两拍请求，T0/T1响应在相邻流水级返回 | scoreboard按pipe固定时序归属响应：pa_vld/page_fault属于当前T0请求，access_fault属于上一拍T1请求，不能依赖输出IID | DTLB_RESP_NO_IID_T01_001 | N/A | LSU monitor请求历史、每pipe T0/T1配对 | add | tb_model_gap | 新增scoreboard/coverage规则 | spec明确MMU输出不带IID，检查模型必须显式锁定按流水归属的规则。 |
        | L1DTLB-AUD-046 | 同pipe T1 access fault与下一拍T0 page fault重叠 | Q-L1DTLB-009, Q-L1DTLB-019 | 第N拍请求A触发PMP检查，第N+1拍请求B在同pipe产生T0 page fault，同时A返回T1 access fault | 同cycle page_fault和access_fault可以同时为高，但属于不同请求；同一请求仍保持page/access fault互斥 | DTLB_FAULT_OVERLAP_PIPE_001 | N/A | 连续两拍请求的per-pipe temporal SVA/scoreboard历史 | add | missing_test | 新增directed overlap test | 现有fault测试未强制该合法重叠场景，容易把同拍端口信号误判为同一请求双异常。 |
        | L1DTLB-AUD-047 | pa_vld表示终态结果而非仅表示成功PA | Q-L1DTLB-007, Q-L1DTLB-015, Q-L1DTLB-017 | 覆盖正常hit、MMU off/direct map、VA/page fault、exception replay等路径 | pa_vld表示DTLB本次查询已有终态结果；page fault应与T0 pa_vld配对，access fault是后续T1事件 | DTLB_PA_VLD_TERMINAL_001 | translation_sb已有部分行为 | LSU响应、fault配对coverage | add | weak_check | 新增语义覆盖/检查 | 防止后续把pa_vld误理解为“PA一定可用于真实访存”。 |
        | L1DTLB-AUD-048 | page fault阻止同一请求进入PMP/access fault路径 | Q-L1DTLB-009, Q-L1DTLB-016 | TLB hit或direct-map请求产生page fault条件，同时构造若进入PMP会失败的条件 | 同一请求T0上报page fault，不发起PMP check，也不得再产生该请求的access fault | DTLB_PF_BLOCKS_PMP_001, DTLB_PMP_001 | DTLB_PERM_* wrapper已有但不够directed | PMP request probe、LSU page/access fault归属 | add | weak_check | 新增permission/PMP优先级directed test | 现有permission测试需要补directed PTE/PMP配置和no-PMP-after-page-fault检查。 |
        | L1DTLB-AUD-049 | 同拍access_fault和pa_vld不一定属于同一请求 | Q-L1DTLB-017, Q-L1DTLB-019 | T1 PMP access fault返回时，同pipe新T0请求也返回pa_vld | checker不能把同拍access_fault和pa_vld强行绑定为同一请求；归属必须按LSU流水时序判断 | DTLB_ACCESS_FAULT_T1_PAIRING_001 | N/A | per-pipe响应配对SVA/scoreboard历史 | add | tb_model_gap | 新增scoreboard guard | 防止高密度请求下T0/T1事件同拍重叠导致误报。 |
        | L1DTLB-AUD-050 | load/store/AMO类型传播 | Q-L1DTLB-006, Q-L1DTLB-031, Q-L1DTLB-048 | load、store、LDAMO/atomic类请求、STAMO相关请求经过L1DTLB hit/miss路径 | 请求类型影响PTE权限、L2/PTW access type和PMP读写检查；PA/cache属性不应仅因load/store类型改变 | DTLB_TYPE_PROP_LOAD_STORE_AMO_001 | DTLB_PERM_*, DTLB_STAMO_001 | L1D到L2 type probe、PMP request type、LSU fault/attribute比较 | add | missing_test | 新增type propagation directed test | 现有permission和STAMO wrapper不能证明类型一路传递到L2/PTW/PMP。 |
        | L1DTLB-AUD-051 | L1DTLB entry字段建模完整性 | Q-L1DTLB-028, Q-L1DTLB-031 | 安装具有不同VPN、PPN、page size、permission bit、cache/security属性的entry | scoreboard/reference model应比较L1DTLB缓存的所有架构可见PA、权限和属性影响 | DTLB_ENTRY_FIELD_MODEL_001 | translation_sb已有部分模型 | refill/install probe、LSU PA/attribute/fault比较 | add | tb_model_gap | 新增模型覆盖清单 | 第2章已定义entry字段语义，第三章需要把模型完整性作为测试点跟踪。 |
        | L1DTLB-AUD-052 | TLB hit与exception array hit不同pipe同拍发生 | Q-L1DTLB-025, Q-L1DTLB-082 | 一个pipe命中普通TLB entry，另一个pipe同cycle命中exception array entry | 普通hit响应、exception replay fault、MB/expt release和wakeup可同拍发生，且互不污染两个pipe响应 | DTLB_EXPT_HIT_WITH_TLB_HIT_001 | N/A | pipe hit vector、expt match/clear、MB valid drop、wakeup broadcast、LSU响应 | add | missing_test | 新增双pipe expt/hit directed test | 现有concurrent测试未稳定构造normal hit与expt replay混合同拍场景。 |
        | L1DTLB-AUD-053 | 清理来源作用范围矩阵 | 1.6, 1.7, 1.8, Q-L1DTLB-064, Q-L1DTLB-065, Q-L1DTLB-066, Q-L1DTLB-067, Q-L1DTLB-068, Q-L1DTLB-072 | TLB entry、MB、expt entry均有live状态时，分别施加tlboper_utlb_clr、regs_utlb_clr、VA invalidate、RTU flush | TLB entry clear、VA低8位保守清理、SATP full clear、RTU清MB/expt的作用范围必须彼此区分 | DTLB_CLEANUP_SCOPE_MATRIX_001 | DTLB_INV_001..004, DTLB_MB_ABT_LATE_REFILL_001 | entry valid vector、MB valid vector、expt valid vector、late refill no-effect | add | weak_check | 新增矩阵coverage/check | 已有invalidate行分散，仍需一个矩阵测试防止把TLB entry invalidation和MB/expt cleanup混淆。 |
        | L1DTLB-AUD-054 | reset初始状态显式检查 | Q-L1DTLB-071 | reset释放后、任何LSU请求前观察L1DTLB | TLB entry invalid、MB invalid、expt array invalid、scheduler credit初始化；PLRU初值如检查仅作为whitebox | DTLB_RESET_STATE_001 | N/A | reset后whitebox probe、无spurious output检查 | add | missing_test | 新增reset smoke SVA/check | 当前回归依赖reset，但没有命名的L1DTLB reset-state测试点。 |
        | L1DTLB-AUD-055 | black-box测试不得假设精确PLRU victim | Q-L1DTLB-073, Q-L1DTLB-074, Q-L1DTLB-075, Q-L1DTLB-076, L1DTLB-AUD-043 | fill、hit、invalidate、refill后触发replacement | 功能测试只检查最终translation正确性，不预测精确victim entry；精确替换策略只放whitebox coverage/SVA | DTLB_PLRU_WHITEBOX_ONLY_001 | DTLB_PLRU_001 | PLRU onehot/fairness cover、无black-box victim scoreboard | modify | wrong_expected | 重定向PLRU测试意图 | 把PLRU约束补成独立测试点，避免后续wrapper重新引入exact-victim期望。 |
        | L1DTLB-AUD-056 | MB entry状态派生信号一致性 | Q-L1DTLB-039, Q-L1DTLB-077, Q-L1DTLB-078 | MB entry在IDLE/WFG/WFC/WFI/PGFLT/ACFLT/ABT各状态转换，包括RTU flush同拍影响ready | entry_vld等价于state!=IDLE；entry_wfi等价于state==WFI；entry_wfc等价于state==WFC或ABT；ready基本对应WFG但受本拍rtu flush屏蔽 | DTLB_MB_STATE_SIGNAL_001 | 无wrapper | MB state、entry_vld、entry_wfi、entry_wfc、ready和rtu flush probe | add | missing_test | 新增whitebox SVA/coverage | 第2章明确状态信号等价关系，现有MB测试关注分配/压力但未显式检查派生状态信号。 |
        | L1DTLB-AUD-057 | WFI refill数据保持 | Q-L1DTLB-052 | PTW/L2 normal refill返回但未获得install授权，MB entry进入WFI后等待后续install | WFI entry必须保持原miss VPN、refill PPN、flag和page size；后续被选中install时写入的数据与被latch的refill一致 | DTLB_WFI_DATA_HOLD_001 | 无wrapper | WFI entry vpn_r/ppn_r/flg_r/pgs_r、后续entry update data | add | missing_test | 新增directed test/SVA | Install arbitration已覆盖优先级，但仍需覆盖被抢占refill的数据保持。 |
        | L1DTLB-AUD-058 | exception array容量和MB id映射 | Q-L1DTLB-058, Q-L1DTLB-059, Q-L1DTLB-077, Q-L1DTLB-078 | fault refill携带不同MB id返回，包括边界id和同拍双fault | exception array entry数量必须等于MB深度；fault写入直接使用refill携带的MB id；entry生命周期与对应MB entry严格绑定 | DTLB_EXPT_ID_MAP_001 | 无wrapper | expt write id/valid vector、MB id/state、replay clear id | add | missing_test | 新增directed id mapping test/SVA | 现有fault lifecycle覆盖写入和释放，但没有显式检查exception array容量、索引和MB绑定关系。 |
        | L1DTLB-AUD-059 | PGFLT/ACFLT保持与flush释放 | Q-L1DTLB-040, Q-L1DTLB-041, Q-L1DTLB-062 | fault refill后MB entry进入PGFLT或ACFLT，期间没有后续LSU replay命中，或有同VPN新请求到达 | PGFLT/ACFLT entry保持valid等待原请求replay命中exception array；不因超时自动释放；exception hit禁止给该请求分配新MB；RTU flush可释放该entry | DTLB_MB_FAULT_HOLD_001 | DTLB_MB_PGFLT_001 | MB state/valid保持、expt valid保持、no-allocation、RTU flush clear | add | missing_test | 新增fault-hold directed test | 第2章明确PGFLT/ACFLT保留目的和清除条件，现有replay测试不证明无replay时的保持行为。 |
        | L1DTLB-AUD-060 | 非WFC refill返回按stale/late处理 | Q-L1DTLB-055, Q-L1DTLB-056, Q-L1DTLB-072 | refill返回的MB id对应entry处于IDLE、PGFLT、ACFLT、ABT或被flush后的状态 | 只有对应entry处于WFC时refill才作为有效完成；IDLE/PGFLT/ACFLT等非WFC状态不得写TLB、不得写expt、不得wakeup；ABT仅允许late refill drain到IDLE | DTLB_REFILL_STALE_ID_001 | DTLB_MB_ABT_LATE_REFILL_001 | refill valid/id、MB state、entry update/expt write/wakeup absence | add | missing_test | 新增stale refill directed/SVA | 现有ABT late refill测试只覆盖特殊态，需要补全所有非WFC状态的过滤规则。 |
        | L1DTLB-AUD-061 | TLB install可见性和MB释放时序 | Q-L1DTLB-057 | normal refill获得TLB install授权，同cycle或下一cycle有LSU访问同一VPN | TLB写入和原MB entry释放在同一时钟沿完成；写入前的同一组合周期不能命中新entry；写入沿后的下一可见周期可以命中 | DTLB_INSTALL_VISIBILITY_001 | DTLB_REFILL_001 | install event、MB valid drop、same-cycle lookup、next-cycle hit response | add | missing_test | 新增install visibility directed test/SVA | Install arbitration已有优先级测试，但缺少写入可见周期和MB释放时序检查。 |
        | L1DTLB-AUD-062 | access fault来源一致性 | Q-L1DTLB-034, Q-L1DTLB-063, Q-L1DTLB-081 | 分别通过TLB-hit后PMP失败和PTW fault refill挂入exception array后replay产生access fault | 两类access fault对LSU的可观测输出时序一致，均按T1归属匹配；refill携带的access fault需先挂exception array，后续replay hit后上报 | DTLB_ACCESS_FAULT_SOURCE_PARITY_001 | DTLB_PMP_001, DTLB_MB_PGFLT_001 | access fault pulse、T1 request ownership、expt write/replay path | add | weak_check | 新增source parity directed test | 当前PMP和fault replay测试分散，需防止两种access fault来源在scoreboard中使用不同归属规则。 |
        | L1DTLB-AUD-063 | reference model观测边界和逐拍比较规则 | Q-L1DTLB-077, Q-L1DTLB-078, Q-L1DTLB-079, Q-L1DTLB-081 | 对TLB entry、MB、exception array、credit、PLRU以及PA/fault/wakeup/busy等信号建立scoreboard规则 | 主scoreboard应建模TLB/MB/expt/credit/per-pipe T0/T1流水，pass/fail优先基于外部接口和spec可推导状态；PA/attr/page_fault/access_fault、L2 request和credit逐拍精确比较，wakeup/busy按事件或状态语义比较；PLRU精确victim不作black-box比较 | DTLB_REF_MODEL_OBSERVABILITY_001 | translation_sb已有部分模型 | scoreboard rule review、external event trace、whitebox-only probe清单 | add | tb_model_gap | 新增scoreboard建模边界清单 | 第2章给出了UVM建模决策，需要在审核表中形成明确测试/模型约束，避免checker过度依赖内部探针或漏做逐拍比较。 |
        | L1DTLB-AUD-064 | RTU flush与MB FSM同拍race矩阵 | Q-L1DTLB-072, Q-L1DTLB-082 | WFG+flush+grant、WFC+flush+refill、WFI+flush等同拍race | flush/abort kill优先；WFG+flush+grant最终进入ABT等待late refill；WFC+flush+refill最终IDLE且不install/不写expt/不wakeup；WFI+flush最终IDLE且不install | DTLB_MB_FLUSH_RACE_MATRIX_001 | DTLB_MB_ABT_LATE_REFILL_001, DTLB_REFILL_002 | MB state transition、entry update/expt write/wakeup absence、late refill drain | add | missing_test | 新增flush race矩阵directed/SVA | 现有ABT late refill只覆盖一段race，需要把第2章列出的同拍grant/refill/install race做成矩阵测试点。 |

### 3.8 已有L1DTLB测试点索引
        本节用于回答“已有测试点是否都进入第三章审核”的traceability问题。当前mmu_verification/testbench/test/l1dtlb_tests目录下的23个已实现wrapper均已映射到3.7审核表；verification plan中尚未实现为wrapper的plan-only TC也列在第二张表中，便于后续决定是新增、修改、删除还是待澄清。

        当前UVM wrapper测试点索引：

        | Existing UVM TC-ID | Mapped Audit ID | Audit Decision |
        | --- | --- | --- |
        | DTLB_ABORT_001 | L1DTLB-AUD-011, L1DTLB-AUD-012, L1DTLB-AUD-013 | 拆分abort hit/miss/expt三类语义，并修改miss/no-allocation检查。 |
        | DTLB_ALLOC_001 | L1DTLB-AUD-005, L1DTLB-AUD-006, L1DTLB-AUD-044 | 当前pressure用途不足，需retarget到dedup/dual allocation/最低空闲entry选择等directed场景。 |
        | DTLB_CONCURRENT_001 | L1DTLB-AUD-003 | 修改为真正同拍pipe0/pipe1 hit directed test。 |
        | DTLB_CONCURRENT_002 | L1DTLB-AUD-004 | 保留随机压力含义，但新增hit+miss同拍directed test。 |
        | DTLB_CREDIT_001 | L1DTLB-AUD-021 | 修改为credit边界directed check。 |
        | DTLB_CREDIT_002 | L1DTLB-AUD-021, L1DTLB-AUD-022 | 当前随机fairness/pressure保留为辅助，不能替代credit boundary和scheduler priority directed check。 |
        | DTLB_HIT_001 | L1DTLB-AUD-001 | 保留。 |
        | DTLB_HIT_002 | L1DTLB-AUD-002 | 保留。 |
        | DTLB_INV_001 | L1DTLB-AUD-034 | 修改check，区分TLB entry clear和MB/expt lifecycle。 |
        | DTLB_INV_002 | L1DTLB-AUD-036 | 增加VPN[7:0] alias conservative clear directed check。 |
        | DTLB_INV_003 | L1DTLB-AUD-035 | 修改expected behavior为L1DTLB full clear。 |
        | DTLB_INV_004 | L1DTLB-AUD-031, L1DTLB-AUD-037, L1DTLB-AUD-038 | 保留random race压力；需补充invalidate+hit和invalidate+install的directed精确检查。 |
        | DTLB_MB_001 | L1DTLB-AUD-008, L1DTLB-AUD-020, L1DTLB-AUD-044 | 修改为MB full和MB CAM hit directed场景。 |
        | DTLB_MB_002 | L1DTLB-AUD-008, L1DTLB-AUD-020, L1DTLB-AUD-044 | 当前与DTLB_MB_001重复，建议retarget或保留为随机压力shell。 |
        | DTLB_PERM_LD_001 | L1DTLB-AUD-016 | 修改stimulus以构造R=0 PTE。 |
        | DTLB_PERM_LD_002 | L1DTLB-AUD-017 | 修改stimulus以覆盖MXR和X-only page。 |
        | DTLB_PERM_ST_001 | L1DTLB-AUD-018 | 修改stimulus以构造W=0 store page fault。 |
        | DTLB_PERM_ST_002 | L1DTLB-AUD-018 | 修改错误期望，D=0 store应page fault/trap-only，不应期待硬件D-bit update。 |
        | DTLB_PLRU_001 | L1DTLB-AUD-043, L1DTLB-AUD-044 | 删除black-box exact victim期望，保留whitebox coverage/SVA。 |
        | DTLB_REFILL_001 | L1DTLB-AUD-024, L1DTLB-AUD-026, L1DTLB-AUD-061, L1DTLB-AUD-044 | 当前pressure用途不足，需补install arbitration、fault refill和install可见性directed场景。 |
        | DTLB_REFILL_002 | L1DTLB-AUD-024, L1DTLB-AUD-031, L1DTLB-AUD-038, L1DTLB-AUD-064 | 当前generic concurrent pressure保留为辅助，不能替代refill/install/flush race directed check。 |
        | DTLB_SCHED_001 | L1DTLB-AUD-022 | 修改为old MB priority over bypass和one-request-per-cycle directed check。 |
        | DTLB_STAMO_001 | L1DTLB-AUD-039 | 修正为pipe1/store pipe bypass，补no-pollution和PA-source检查。 |

        Verification plan中尚未形成当前UVM wrapper的L1DTLB相关TC索引：

        | Plan-only TC-ID | Mapped Audit ID | Audit Decision |
        | --- | --- | --- |
        | DTLB_ALLOC_FULL_001 | L1DTLB-AUD-008 | 新增/细化MB full directed test。 |
        | DTLB_ALLOC_RACE_001 | L1DTLB-AUD-007, L1DTLB-AUD-022, L1DTLB-AUD-023 | 拆到one-free IID arbitration、scheduler priority和bypass allocate+issue race。 |
        | DTLB_ALLOC_TWO_LOWEST_FREE_001 | L1DTLB-AUD-006 | 新增双pipe双miss且有多个free时选择两个最低空闲MB entry的directed test/SVA。 |
        | DTLB_BUSY_ANY_INFLIGHT_001 | L1DTLB-AUD-009 | 修改为任意MB valid即busy。 |
        | DTLB_BUSY_RESTART_MODE_001 | L1DTLB-AUD-009, L1DTLB-AUD-010 | 作为busy/wakeup协同协议测试补充。 |
        | DTLB_CREDIT_BOUND_001 | L1DTLB-AUD-021 | 新增/细化credit boundary directed test。 |
        | DTLB_DUAL_HIT_MUX_001 | L1DTLB-AUD-033 | 新增多entry同VA命中时最高index优先mux诊断，或作为multi-hit invariant coverage。 |
        | DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001 | L1DTLB-AUD-029 | 新增双pipe同拍不应同时命中同一exception entry的负向SVA/diagnostic test。 |
        | DTLB_HIT_MISS_CONCURRENT_001 | L1DTLB-AUD-004 | 新增hit+miss同拍directed test。 |
        | DTLB_HUGE_001, DTLB_HUGE_002, DTLB_HUGE_003 | L1DTLB-AUD-032 | 新增4K/2M/1G page-size directed tests。 |
        | DTLB_HUGE_MIX_001 | L1DTLB-AUD-032, L1DTLB-AUD-033 | 新增huge-page mix；multi-hit部分按最高index优先或micro-arch invariant覆盖处理。 |
        | DTLB_INSTALL_ARB_001 | L1DTLB-AUD-024 | 新增install arbitration directed test/SVA。 |
        | DTLB_INSTALL_ID_CHK_001 | L1DTLB-AUD-024 | 作为install arbitration的数据源ID一致性SVA/check。 |
        | DTLB_INSTALL_VISIBILITY_001 | L1DTLB-AUD-061 | 新增TLB install后下一可见周期才能命中、MB同沿释放的directed test/SVA。 |
        | DTLB_INV_VA8_alias_001 | L1DTLB-AUD-036 | 新增VPN[7:0] alias invalidate directed test。 |
        | DTLB_MB_FSM_WFI_001 | L1DTLB-AUD-025 | 新增多WFI最低entry编号优先install directed test/SVA。 |
        | DTLB_MB_STATE_SIGNAL_001 | L1DTLB-AUD-056 | 新增MB FSM状态与entry_vld/entry_wfi/entry_wfc/ready派生信号一致性SVA/coverage。 |
        | DTLB_WFI_DATA_HOLD_001 | L1DTLB-AUD-057 | 新增WFI等待期间vpn/ppn/flag/page size refill数据保持检查。 |
        | DTLB_INV_HIT_SAME_CYCLE_001 | L1DTLB-AUD-037 | 新增invalidate和hit同cycle时本拍old-hit、下一拍entry失效的directed test。 |
        | DTLB_INV_INSTALL_SAME_ENTRY_001 | L1DTLB-AUD-038 | 新增invalidate和install同entry同cycle时clear优先、最终valid为0的directed test/SVA。 |
        | DTLB_MB_PGFLT_001 | L1DTLB-AUD-026, L1DTLB-AUD-028, L1DTLB-AUD-059, L1DTLB-AUD-062 | 新增fault refill、fault hold、expt replay和access-fault来源一致性directed test。 |
        | DTLB_EXPT_ID_MAP_001 | L1DTLB-AUD-058 | 新增exception array容量、MB id索引和生命周期绑定检查。 |
        | DTLB_MB_FAULT_HOLD_001 | L1DTLB-AUD-059 | 新增PGFLT/ACFLT无replay时保持、RTU flush释放、expt hit禁止新MB分配检查。 |
        | DTLB_MB_ABT_LATE_REFILL_001 | L1DTLB-AUD-030, L1DTLB-AUD-060, L1DTLB-AUD-064 | 新增ABT late refill drain，并扩展到非WFC stale refill和flush race矩阵。 |
        | DTLB_REFILL_STALE_ID_001 | L1DTLB-AUD-060 | 新增IDLE/PGFLT/ACFLT/ABT等非WFC状态下refill返回不得污染TLB/expt/wakeup的directed test/SVA。 |
        | DTLB_MB_FLUSH_RACE_MATRIX_001 | L1DTLB-AUD-064 | 新增WFG/WFC/WFI与flush/grant/refill/install同拍race矩阵测试。 |
        | DTLB_PMP_001 | L1DTLB-AUD-015, L1DTLB-AUD-048, L1DTLB-AUD-062 | 归入PMP access fault T1 timing、page fault阻止PMP和access fault来源一致性检查。 |
        | DTLB_ACCESS_FAULT_SOURCE_PARITY_001 | L1DTLB-AUD-062 | 新增PMP access fault与PTW fault-replay access fault输出时序一致性检查。 |
        | DTLB_STAMO_PIPE1_BYPASS_001 | L1DTLB-AUD-039 | 新增/修正STAMO pipe1/store pipe bypass PA/attr source和no-pollution检查。 |
        | DTLB_STAMO_PIPE0_NEG_001 | L1DTLB-AUD-040 | 新增pipe0不支持STAMO bypass的negative test。 |
        | DTLB_SYSMAP_001 | L1DTLB-AUD-041 | 归入MMU off/M-mode/direct map/sysmap bypass测试。 |
        | DTLB_WAKEUP_COMPLETE_BCAST_001 | L1DTLB-AUD-010 | 新增wakeup broadcast directed test。 |
        | DTLB_WAKEUP_EXPT_001 | L1DTLB-AUD-010, L1DTLB-AUD-028 | 新增exception replay wakeup directed test。 |
        | DTLB_WAKEUP_MULTI_RETRY_001 | L1DTLB-AUD-010 | 作为broadcast后多entry重试覆盖。 |
        | DTLB_RESP_NO_IID_T01_001 | L1DTLB-AUD-045 | 新增无IID响应归属scoreboard/coverage检查。 |
        | DTLB_FAULT_OVERLAP_PIPE_001 | L1DTLB-AUD-046 | 新增同pipe连续请求下T1 access fault与下一拍T0 page fault重叠测试。 |
        | DTLB_PA_VLD_TERMINAL_001 | L1DTLB-AUD-047 | 新增pa_vld作为终态结果、非success-only PA valid的语义检查。 |
        | DTLB_PF_BLOCKS_PMP_001 | L1DTLB-AUD-048 | 新增page fault阻止同一request发起PMP/access fault的优先级测试。 |
        | DTLB_ACCESS_FAULT_T1_PAIRING_001 | L1DTLB-AUD-049 | 新增T1 access fault与同拍T0 pa_vld跨request归属检查。 |
        | DTLB_TYPE_PROP_LOAD_STORE_AMO_001 | L1DTLB-AUD-050 | 新增load/store/AMO类型对permission、L2/PTW type和PMP type传播测试。 |
        | DTLB_ENTRY_FIELD_MODEL_001 | L1DTLB-AUD-051 | 新增L1DTLB entry字段和scoreboard建模完整性检查。 |
        | DTLB_EXPT_HIT_WITH_TLB_HIT_001 | L1DTLB-AUD-052 | 新增一pipe TLB hit、一pipe exception-array hit同拍并发测试。 |
        | DTLB_CLEANUP_SCOPE_MATRIX_001 | L1DTLB-AUD-053 | 新增tlboper/regs/VA invalidate/RTU flush清理范围矩阵测试。 |
        | DTLB_RESET_STATE_001 | L1DTLB-AUD-054 | 新增reset后L1DTLB初始状态显式检查。 |
        | DTLB_PLRU_WHITEBOX_ONLY_001 | L1DTLB-AUD-055 | 将PLRU替换策略限定为whitebox coverage/SVA，避免black-box exact victim期望。 |
        | DTLB_REF_MODEL_OBSERVABILITY_001 | L1DTLB-AUD-063 | 新增reference model观测边界、逐拍精确比较和whitebox-only probe清单。 |

### 3.9 L1DTLB SVA需求清单
        本节把第1章功能描述、第2章Q&A和第3章审核表中的L1DTLB行为转换成需要补充的SVA文本需求。这里不是SystemVerilog实现代码，而是后续编写/bind `mmu_l1dtlb_sva.sv`、子模块SVA和cover property时必须覆盖的断言清单。
        SVA分为三类：
            1. 协议/外部可观测SVA：优先使用LSU、L2TLB、PTW、PMP、TLBOP、RTU等接口信号，可作为功能正确性pass/fail依据。
            2. 白盒结构SVA：使用TLB entry、MB entry、exception array、credit counter、PLRU victim等内部probe，只用于守护微架构不变量和debug，不替代主scoreboard。
            3. cover property：用于证明directed/random测试确实打到关键同拍race、边界和优先级场景。
        除非单条SVA另有说明，所有assert property都应在`posedge forever_cpuclk`或对应子模块时钟采样，并使用`disable iff (!cpurst_b)`屏蔽复位期。所有payload类断言在valid为1时还应检查`!$isunknown(...)`。

#### 3.9.1 SVA命名和绑定建议
        SVA-ID命名规则：
            assert类使用`L1DTLB_SVA_A###`。
            cover类使用`L1DTLB_SVA_C###`。
            assume/环境约束如必须使用，则使用`L1DTLB_SVA_ENV###`，并且只能约束上游协议已经由SoC/LSU保证的行为，不能掩盖DUT bug。

        推荐绑定层次：
            `mmu_l1dtlb`顶层SVA：接口响应、busy/wakeup、TLB entry、MB array、exception array、refill/install总体仲裁。
            `mmu_l1dtlb_scheduler` SVA：credit计数、每拍最多一个L2TLB request、MB旧请求优先于bypass。
            `mmu_l1dtlb_allocator` SVA：双pipe miss分配、同4K去重、最低空闲entry选择、单空位IID年龄选择。
            `mmu_l1dtlb_mb_entry` SVA：单entry FSM状态转换、派生信号、WFI数据保持、ABT late refill drain。
            `mmu_l1dtlb_hit_rd`/entry SVA：page size match、权限/page fault、属性输出、STAMO和direct map。
            `mmu_l1dtlb_install` SVA：WFI/PTW/L2 install优先级、fault写exception array、wakeup广播。

#### 3.9.2 Assert SVA矩阵
        | SVA ID | 类型 | 追踪来源 | 绑定位置 | 需要检查的行为 |
        | --- | --- | --- | --- | --- |
        | L1DTLB_SVA_A001 | assert | Q071, AUD-054 | top | reset有效期间或释放后的第一个可检查周期，TLB entry valid全0、MB state为IDLE、MB valid全0、exception array valid全0、issued/sent清0、busy=0、wakeup=0、无spurious pa_vld/page_fault/access_fault。 |
        | L1DTLB_SVA_A002 | assert | Q071, AUD-054 | scheduler | reset后credit counter等于CREDIT_MAX，且credit counter从不小于0、不大于CREDIT_MAX。 |
        | L1DTLB_SVA_A003 | assert | Q002, AUD-014 | top/hit_rd | `lsu_mmu_vabuf0/1`不参与功能决策：在VA、va_vld、iid、store、abort、mode、TLB/MB/expt状态相同而仅vabuf不同的受控比较场景下，pa_vld、PA、attr、fault、MB allocation、L2 request不应改变。该SVA可实现为formal/equivalence辅助断言；仿真中至少cover vabuf随机变化且输出由scoreboard确认不变。 |
        | L1DTLB_SVA_A004 | assert | Q001, Q032, AUD-039, AUD-040 | hit_rd/top | STAMO只允许走pipe1/store pipe bypass；STAMO有效时不得在pipe0产生STAMO bypass效果。 |
        | L1DTLB_SVA_A005 | assert | Q032, AUD-039 | hit_rd/top | STAMO bypass不发起新的TLB lookup/miss、不得分配MB、不得写exception array、不得产生新的L2TLB request、不得产生新的L1DTLB PTE page fault。 |
        | L1DTLB_SVA_A006 | assert | Q032, AUD-039 | hit_rd/top | STAMO pipe1返回PA/属性来自LM/STAMO保存路径，不得来自当前VA查TLB结果；STAMO不污染TLB entry、MB entry和PLRU miss/refill路径。 |
        | L1DTLB_SVA_A007 | assert | Q003, Q004, AUD-011 | top/hit_rd | abort不屏蔽合法TLB hit/direct-map组合响应；若请求abort且本来TLB hit，则允许pa_vld/PA/attr按hit路径返回，不得因abort强制清零hit响应。 |
        | L1DTLB_SVA_A008 | assert | Q004, AUD-012 | allocator/top | abort请求如果TLB miss且exception array miss，不得分配新的MB entry，不得触发bypass L2TLB request。 |
        | L1DTLB_SVA_A009 | assert | Q004, AUD-013 | expt/top | abort请求即使命中exception array，也不得释放对应exception entry和MB entry，不得消费pending fault replay；exception replay fault输出是否屏蔽按spec实现检查，至少不得造成entry生命周期改变。 |
        | L1DTLB_SVA_A010 | assert | Q006, Q031, AUD-019, AUD-050 | hit_rd/scheduler | load/store/AMO类型必须传递到page fault权限判断、L2TLB request type和PMP read/write检查；同一entry下load/store不应改变PA和cache/share/buf/sec/so属性本身。 |
        | L1DTLB_SVA_A011 | assert | Q007, Q014, Q015, AUD-001, AUD-002, AUD-015, AUD-047 | hit_rd/top | TLB hit、MMU off/direct map、VA/page fault、exception page fault replay的T0终态结果必须同拍拉高对应pipe的pa_vld；pa_vld表示终态，不等价于“可正常访存”。 |
        | L1DTLB_SVA_A012 | assert | Q007, Q008, Q016, AUD-048 | hit_rd/top | 同一请求T0产生page_fault时必须同时pa_vld=1，且不得为该请求发起PMP check token。 |
        | L1DTLB_SVA_A013 | assert | Q008, Q017, Q019, Q020, AUD-015, AUD-045, AUD-049 | top | access_fault是T1事件，必须归属于同pipe上一拍进入PMP或exception-access-fault replay路径的请求；同拍pa_vld不得被强行视为同一请求的access_fault配对。 |
        | L1DTLB_SVA_A014 | assert | Q008, Q018, AUD-015, AUD-026, AUD-062 | top/expt | page_fault和access_fault输出均为1-cycle pulse；exception array page fault replay为T0 pulse，exception array access fault replay为下一拍T1 pulse。 |
        | L1DTLB_SVA_A015 | assert | Q009, Q016, AUD-015, AUD-046, AUD-048 | hit_rd/top | 同一条请求page fault和access fault互斥；page fault优先于PMP access fault。允许同一pipe同一cycle裸信号page_fault和access_fault同时为1，但必须分别归属当前T0请求和上一拍T1请求。 |
        | L1DTLB_SVA_A016 | assert | Q010, Q011, AUD-010 | install/expt/top | `mmu_lsu_tlb_wakeup[11:0]`只能为12'h000或12'hfff，不得产生per-entry/per-pipe onehot形态。 |
        | L1DTLB_SVA_A017 | assert | Q010, Q011, AUD-010 | install/expt/top | wakeup触发源限于TLB install完成/将写入可见，或LSU replay命中exception array并消费fault；MB CAM hit、MB full drop、RTU flush、ABT late refill drain不得单独产生wakeup。 |
        | L1DTLB_SVA_A018 | assert | Q012, Q013, AUD-009 | top | `mmu_lsu_tlb_busy == (|mb_entry_vld)`，busy不是VA ready反压信号；busy=1时TLB hit/direct-map请求仍应正常返回。 |
        | L1DTLB_SVA_A019 | assert | Q014, Q015 | hit_rd/top | TLB hit且无page fault时，pa_vld/PA/attr在T0返回，不等待PMP结果；PMP access fault只可在下一拍按token返回。 |
        | L1DTLB_SVA_A020 | assert | Q014, Q036 | allocator/top | T0 TLB miss且exception miss的请求，在T1才参与MB CAM和allocation；不得在T0组合分配MB。 |
        | L1DTLB_SVA_A021 | assert | Q021, AUD-003 | hit_rd/top | pipe0和pipe1同拍TLB hit时，两个pipe都必须能够同拍独立返回pa_vld/PA/attr/fault；一个pipe不得压掉另一个pipe的hit响应。 |
        | L1DTLB_SVA_A022 | assert | Q022, AUD-004 | hit_rd/allocator/top | pipe0 hit、pipe1 miss或反向hit+miss同拍时，hit响应不得被miss分配、MB full、L2 request或busy影响。 |
        | L1DTLB_SVA_A023 | assert | Q023, AUD-005 | allocator | 双pipe同拍均需分配且属于同一4K VPN时，只允许分配一个MB entry，且固定选择pipe0请求写入；pipe1不得额外分配。 |
        | L1DTLB_SVA_A024 | assert | Q024, Q005, AUD-007 | allocator | 双pipe同拍均需分配、不同4K VPN且仅一个free MB entry时，必须按IID年龄比较选择更老请求；同时断言该仲裁场景下两个IID不相等且处于可比较窗口。 |
        | L1DTLB_SVA_A025 | assert | Q027, AUD-006 | allocator | 双pipe同拍均需分配、不同4K VPN且free entry数量至少2时，必须选择两个最低编号free MB entry，并保持pipe0/pipe1 payload分别写入对应grant entry。 |
        | L1DTLB_SVA_A026 | assert | Q025, AUD-052 | top/expt/hit_rd | 一pipe普通TLB hit、另一pipe exception array hit可同拍发生；TLB hit响应、exception entry释放、MB释放和wakeup广播互不污染。 |
        | L1DTLB_SVA_A027 | assert | Q026, Q060, AUD-029 | expt/top | 两个pipe同拍不得消费同一个exception array entry；如果实现观测到同一entry双hit，应报错或至少只允许一个释放动作，不能双释放。 |
        | L1DTLB_SVA_A028 | assert | Q028, AUD-051 | entry/hit_rd | valid entry的VPN、PPN、page size和flag[13:0]在hit响应、权限判断和属性输出中一致使用；valid=0的entry不得参与hit。 |
        | L1DTLB_SVA_A029 | assert | Q029, AUD-032 | entry/hit_rd | 4K page按VPN[26:0]全比较，2M page按VPN[26:9]比较，1G page按VPN[26:18]比较；page size编码必须为合法one-hot 001/010/100。 |
        | L1DTLB_SVA_A030 | assert | Q030, AUD-033 | hit_rd | 若多个TLB entry同时匹配同一VA，输出选择应符合当前spec记录的最高index优先；如果项目决定把multi-hit作为非法微架构状态，则应改为assert `$onehot0(entry_hit*)`并把最高index优先只作为diagnostic cover。 |
        | L1DTLB_SVA_A031 | assert | Q031, AUD-016, AUD-017, AUD-018 | hit_rd | load page fault规则：V=0、W=1/R=0非法组合、读权限不满足且MXR不能救、U/S/SUM不满足、A=0、VA illegal时必须T0 page_fault；D位不应单独导致普通load page fault。 |
        | L1DTLB_SVA_A032 | assert | Q031, AUD-018 | hit_rd | store page fault规则：V=0、W=1/R=0非法组合、W=0、U/S/SUM不满足、A=0、D=0、VA illegal时必须T0 page_fault。 |
        | L1DTLB_SVA_A033 | assert | Q031, AUD-050 | hit_rd | AMO/LDAMO按write-type权限要求检查A/D/W等条件，不能用MXR把X-only page当作AMO可读写权限通过。 |
        | L1DTLB_SVA_A034 | assert | Q031, Q033, AUD-041 | hit_rd/top | regs_mmu_en=0或effective M-mode direct map时，不查TLB、不分配MB、不产生PTE page fault；pa_vld应返回，PA按VA direct map生成，属性来自sysmap。 |
        | L1DTLB_SVA_A035 | assert | Q033, AUD-041 | top/hit_rd | direct map/MMU off/M-mode不绕过PMP；无page fault但仍需按read/write类型产生PMP check，并允许T1 access_fault。 |
        | L1DTLB_SVA_A036 | assert | Q034, Q049, AUD-062 | expt/top | PTW refill可返回normal/page fault/access fault；L2TLB refill可返回normal/page fault但不得返回access fault。两类access fault最终对LSU输出时序均为replay hit后的T1 pulse。 |
        | L1DTLB_SVA_A037 | assert | Q035, Q038, AUD-020 | allocator/mb | MB CAM去重固定按完整4K VPN比较，不按最终2M/1G page size放宽；MB CAM hit不得再分配新entry。 |
        | L1DTLB_SVA_A038 | assert | Q036, AUD-020 | allocator/top | T1 MB CAM hit请求不产生wakeup、不产生pa_vld/fault响应、不分配entry；后续依赖原MB refill完成后LSU replay。 |
        | L1DTLB_SVA_A039 | assert | Q037, AUD-008 | allocator/top | MB无空位时miss请求不得分配entry，不得错误覆盖已有entry；busy必须为1，等待后续wakeup/replay。 |
        | L1DTLB_SVA_A040 | assert | Q039, AUD-056 | mb_entry | `entry_vld == (state != IDLE)`；`entry_wfi == (state == WFI)`；`entry_wfc == (state == WFC || state == ABT)`；`ready`只能在WFG且本拍未被RTU flush屏蔽时为1。 |
        | L1DTLB_SVA_A041 | assert | Q039, AUD-056 | mb_entry | `issued/sent`是latch而不是纯状态译码：issue_grant后置1，entry回IDLE后清0；不得在未issue的entry上声明已发送。 |
        | L1DTLB_SVA_A042 | assert | Q040, Q041, AUD-059 | mb_entry/expt | PGFLT/ACFLT状态必须保持entry valid和exception array valid，直到原请求replay命中exception array或RTU flush；不得超时自动释放。 |
        | L1DTLB_SVA_A043 | assert | Q042, Q043, Q044, AUD-021 | scheduler | credit更新守恒：只有L2TLB request消耗credit，只有credit_return归还credit；request和return同拍时计数不变；credit=0且同拍return允许发出一个request。 |
        | L1DTLB_SVA_A044 | assert | Q045, AUD-021 | scheduler/top | 每拍最多一个L1DTLB->L2TLB request，限制覆盖MB旧entry request和当前bypass request总和。 |
        | L1DTLB_SVA_A045 | assert | Q046, AUD-022 | scheduler | 当存在MB中未发送ready entry且同拍有新miss可bypass时，必须优先发送MB旧entry，不得让bypass抢占。 |
        | L1DTLB_SVA_A046 | assert | Q047, AUD-023 | scheduler/allocator/mb_entry | bypass request必须同拍已经分配到MB entry并携带该entry id；下一拍该entry进入WFC且issued/sent为1。 |
        | L1DTLB_SVA_A047 | assert | Q048, AUD-050 | scheduler/top | L2TLB request valid时，VPN、MB entry id和load/store access type必须稳定且非X；entry id必须在MB_DEPTH范围内，并与被发送MB entry payload一致。 |
        | L1DTLB_SVA_A048 | assert | Q050, AUD-024 | install | 每拍最多写一个TLB entry；normal install仲裁优先级固定为WFI entry > PTW normal refill > L2TLB normal refill。 |
        | L1DTLB_SVA_A049 | assert | Q050, Q053, AUD-024 | install | refill携带page/access fault时不得参与TLB install，不得写TLB entry；同拍normal install候选仍可按优先级写TLB。 |
        | L1DTLB_SVA_A050 | assert | Q051, AUD-025 | install | 多个MB entry处于WFI且可install时，必须选择最低编号WFI entry。 |
        | L1DTLB_SVA_A051 | assert | Q052, AUD-057 | mb_entry/install | WFI entry等待期间必须保持原miss VPN、refill PPN、flag和page size稳定；后续被install时写入TLB的数据必须等于WFI latch数据。 |
        | L1DTLB_SVA_A052 | assert | Q053, Q054, AUD-026, AUD-027, AUD-058 | expt/install | fault refill必须写exception array而不是TLB；PTW和L2TLB同拍fault允许两个exception write端口同时写入，id必须在范围内，若两个fault id相同应报错或明确优先级。 |
        | L1DTLB_SVA_A053 | assert | Q055, AUD-060 | install/expt/mb_entry | refill返回id对应entry只有处于WFC时才可作为有效完成；IDLE、PGFLT、ACFLT或其他非WFC状态不得写TLB、不得写exception array、不得wakeup。 |
        | L1DTLB_SVA_A054 | assert | Q056, Q072, AUD-030, AUD-060, AUD-064 | mb_entry/install/expt | ABT late refill只允许drain entry回IDLE，禁止TLB install、exception write和wakeup。 |
        | L1DTLB_SVA_A055 | assert | Q057, AUD-061 | install/top | TLB写入和对应MB entry释放在同一时钟沿完成；写入前同一组合周期LSU不能命中新写entry，下一可见周期才允许命中。 |
        | L1DTLB_SVA_A056 | assert | Q058, Q059, AUD-058 | expt/mb | exception array entry数量等于MB_DEPTH；fault写入索引直接使用refill MB id；exception entry valid生命周期和对应MB entry PGFLT/ACFLT生命周期绑定。 |
        | L1DTLB_SVA_A057 | assert | Q060, AUD-028 | expt | exception array CAM key必须是IID+完整4K VPN；不得把pipe id、ASID、load/store类型或page size纳入匹配条件。 |
        | L1DTLB_SVA_A058 | assert | Q061, AUD-028, AUD-058 | expt/mb | 后续LSU replay命中exception array时，对应exception entry和MB entry必须同拍释放；该请求不得再分配新的MB entry。 |
        | L1DTLB_SVA_A059 | assert | Q062, AUD-052 | expt/hit_rd | 同一pipe同一请求不得同时TLB hit和exception array hit；如果出现应作为design/spec violation报警。 |
        | L1DTLB_SVA_A060 | assert | Q064, Q072, AUD-031, AUD-053, AUD-064 | expt/mb/install | RTU flush清空exception array和MB；flush kill的miss不得产生TLB install、exception write或wakeup；flush后返回的旧refill按stale/ABT late规则处理。 |
        | L1DTLB_SVA_A061 | assert | Q065, Q066, Q067, AUD-034, AUD-035, AUD-053 | entry/top | regs_utlb_clr和tlboper_utlb_clr清空所有TLB entry valid，但不清MB和exception array；SATP/ASID相关L1清理通过全清entry体现。 |
        | L1DTLB_SVA_A062 | assert | Q068, AUD-036 | entry | VA定点失效按VPN低8 bit保守比较；所有VPN[7:0]匹配目标VA的valid entry下一拍必须失效，低8 bit不匹配entry不得被该局部clear误清。 |
        | L1DTLB_SVA_A063 | assert | Q069, AUD-037 | entry/hit_rd | invalidate与TLB hit同拍时，本拍允许返回旧entry hit结果；下一拍起被invalidate命中的entry不得继续作为valid hit。 |
        | L1DTLB_SVA_A064 | assert | Q070, AUD-038 | entry/install | invalidate/clear与TLB install同拍选择同一entry时，clear优先，时钟沿后该entry最终valid必须为0。 |
        | L1DTLB_SVA_A065 | assert | Q072, AUD-064 | mb_entry | WFG+flush+未grant -> IDLE；WFG+flush+grant/issue -> ABT；WFC+flush+无refill -> ABT；WFC+flush+refill -> IDLE且无install/expt/wakeup；WFI+flush -> IDLE且无install。 |
        | L1DTLB_SVA_A066 | assert | Q073, Q074, Q075, Q076, AUD-043, AUD-055 | plru/install | PLRU精确victim不作为black-box功能pass/fail；白盒只检查victim onehot/onehot0、install index在NUM_ENTRY范围内、PLRU更新输入非X。 |
        | L1DTLB_SVA_A067 | assert | Q077, Q078, Q079, Q080, Q081, AUD-063 | top | SVA/scoreboard观测边界守护：PA、attr、pa_vld、page_fault、access_fault、L2 request、credit、busy逐拍精确；wakeup按事件级和广播形态检查；PLRU victim不得进入主translation correctness断言。 |
        | L1DTLB_SVA_A068 | assert | 1.3, Q021, AUD-001, AUD-002 | hit_rd/top | 单pipe basic hit基线：pipe0单独hit和pipe1单独hit时，T0必须返回对应pipe的pa_vld、PA和属性；另一pipe无请求时不得产生串扰响应；该hit不得分配MB、不得发L2TLB request、不得写exception array。 |
        | L1DTLB_SVA_A069 | assert | Q017, AUD-015, AUD-047, AUD-049 | hit_rd/top | PMP T1 payload归属：T0 hit且无page fault时锁存给PMP的PA、属性和read/write类型必须非X并保持到T1检查；T1 access_fault只能由上一拍有效PMP token产生，不能使用同拍新T0请求的PA/属性。 |
        | L1DTLB_SVA_A070 | assert | Q080, AUD-008, AUD-020, AUD-031, AUD-063 | top/allocator/mb | 合法无响应分类：MB CAM hit、MB full未分配、abort屏蔽有状态后果、flush kill请求等场景不得被SVA误判为漏响应；但必须检查它们没有非法分配、非法install、非法exception write或非法wakeup，并由后续wakeup/replay或flush终止生命周期。 |
        | L1DTLB_SVA_A071 | assert | Q081 | top | miss统计/HPC类信号只做事件级守护：`mmu_hpcp_dutlb_miss`等miss事件不得在TLB hit、direct map、STAMO bypass、exception replay hit或abort屏蔽的请求上误拉高；真实TLB/expt miss进入miss处理时允许产生1-cycle事件。 |

#### 3.9.3 Cover Property矩阵
        | Cover ID | 追踪来源 | 需要覆盖的场景 |
        | --- | --- | --- |
        | L1DTLB_SVA_C001 | Q071, AUD-042, AUD-054 | reset释放后首次普通miss、首次hit、首次direct-map访问均被采到。 |
        | L1DTLB_SVA_C002 | Q021, Q082, AUD-001, AUD-002, AUD-003 | pipe0单独hit、pipe1单独hit、pipe0和pipe1同拍都TLB hit均被采到；双pipe同拍hit包括命中同一entry和命中不同entry两类。 |
        | L1DTLB_SVA_C003 | Q022, Q082, AUD-004 | 一pipe TLB hit、另一pipe TLB miss同拍，并且hit响应成功返回、miss进入MB处理。 |
        | L1DTLB_SVA_C004 | Q023, Q082, AUD-005 | 双pipe同拍miss且同4K VPN，只分配pipe0一个MB entry。 |
        | L1DTLB_SVA_C005 | Q027, Q082, AUD-006 | 双pipe同拍miss、不同4K、至少两个free entry，分配两个最低free entry。 |
        | L1DTLB_SVA_C006 | Q024, Q005, Q082, AUD-007 | 双pipe同拍miss、不同4K、仅一个free entry，分别覆盖pipe0更老和pipe1更老两种IID年龄结果。 |
        | L1DTLB_SVA_C007 | Q037, Q082, AUD-008 | MB full时新miss drop/不分配，busy为1，后续由wakeup后replay。 |
        | L1DTLB_SVA_C008 | Q010-Q013, AUD-009, AUD-010 | busy=1期间发生hit-under-miss；install触发wakeup广播；exception replay触发wakeup广播。 |
        | L1DTLB_SVA_C009 | Q003, Q004, AUD-011, AUD-012, AUD-013 | abort+hit、abort+miss、abort+exception-hit三类场景都被采到。 |
        | L1DTLB_SVA_C010 | Q031, AUD-016, AUD-017, AUD-018 | load R=0、load MXR读X-only、store W=0、store D=0、A=0、U/S/SUM权限组合均被采到。 |
        | L1DTLB_SVA_C011 | Q033, AUD-041 | regs_mmu_en=0 direct map、effective M-mode direct map、MPRV导致非M effective mode走正常DTLB三类场景。 |
        | L1DTLB_SVA_C012 | Q032, AUD-039, AUD-040 | STAMO pipe1 bypass成功返回；pipe0普通请求同拍存在但不受STAMO bypass污染。 |
        | L1DTLB_SVA_C013 | Q035-Q038, AUD-020 | MB CAM hit去重、MB CAM miss分配、2M/1G最终page但MB仍按4K VPN去重。 |
        | L1DTLB_SVA_C014 | Q042-Q048, AUD-019, AUD-021, AUD-022, AUD-023 | load miss和store miss分别发L2TLB request；credit>0发请求、credit=0且同拍return发请求、request+return同拍计数不变、MB旧entry优先于bypass、bypass allocate+issue同拍。 |
        | L1DTLB_SVA_C015 | Q050-Q052, AUD-024, AUD-025, AUD-057 | WFI > PTW > L2TLB install优先级、多WFI最低entry优先、WFI等待多拍后install且数据保持。 |
        | L1DTLB_SVA_C016 | Q053, Q054, AUD-026, AUD-027, AUD-058 | PTW fault写exception、L2TLB fault写exception、PTW和L2TLB同拍双fault写两个exception entry。 |
        | L1DTLB_SVA_C017 | Q055, Q056, AUD-030, AUD-060 | IDLE/PGFLT/ACFLT等非WFC stale refill被丢弃；ABT late refill drain回IDLE且无副作用。 |
        | L1DTLB_SVA_C018 | Q057, AUD-061 | install同沿释放MB；同VPN请求在install前同cycle不命中新entry、下一可见cycle命中新entry。 |
        | L1DTLB_SVA_C019 | Q058-Q063, AUD-028, AUD-059, AUD-062 | exception page fault replay、exception access fault replay、fault entry无replay保持多拍、replay同拍释放MB/expt。 |
        | L1DTLB_SVA_C020 | Q064-Q072, AUD-031, AUD-034, AUD-035, AUD-036, AUD-037, AUD-038, AUD-053, AUD-064 | tlboper全清、regs全清、VA低8位保守清、invalidate+hit同拍、invalidate+install同entry、RTU flush清MB/expt、RTU flush与grant/refill/install race矩阵。 |
        | L1DTLB_SVA_C021 | Q019, Q020, AUD-045, AUD-046, AUD-049 | 同pipe连续请求下，上一拍T1 access_fault与当前拍T0 pa_vld/page_fault重叠。 |
        | L1DTLB_SVA_C022 | Q029, AUD-032 | 4K、2M、1G三种page size各自hit、miss、invalidate、refill/install后hit。 |
        | L1DTLB_SVA_C023 | Q030, AUD-033 | 多entry同VA可匹配诊断场景，覆盖最高index优先或multi-hit invariant报警路径。 |
        | L1DTLB_SVA_C024 | Q073, Q074, Q075, Q076, AUD-043, AUD-055 | PLRU whitebox覆盖：hit更新、install更新、双pipe hit、refill victim onehot、invalidate后replacement压力。 |
        | L1DTLB_SVA_C025 | Q077, Q078, Q079, Q080, Q081, Q082, AUD-063 | reference model观测边界覆盖：外部接口可推导事件、whitebox-only事件、合法无响应事件、miss统计/HPC事件和wakeup事件级检查都被采样。 |
        | L1DTLB_SVA_C026 | AUD-014 | vabuf随机变化且其他请求条件保持等价的场景被采到，用于证明vabuf无功能影响。 |
        | L1DTLB_SVA_C027 | AUD-044 | 覆盖/回归报告层面确认原先共享`mmu_ptw_thrash_vseq`的wrapper已被retarget或至少被标记为traceability shell；该项不是DUT协议SVA，只作为验证计划完整性cover/checklist。 |

#### 3.9.4 SVA实现注意事项
        1. 不要把`mmu_lsu_tlb_wakeup[11:0]`写成per-entry onehot断言。它是广播提示，只检查全0/全1形态和触发源。
        2. 不要写“busy为1时LSU请求必须被阻止”的断言。busy不是ready反压；hit-under-miss必须允许。
        3. 不要写“access_fault必须和pa_vld同拍配对”的断言。access_fault是T1事件，可能与下一条请求的T0 pa_vld/page_fault同拍重叠。
        4. 不要写“abort屏蔽所有输出”的断言。abort主要屏蔽有状态后果和exception replay消费；TLB hit响应仍可出现。
        5. 不要把PLRU exact victim作为主功能断言。PLRU只做whitebox onehot/coverage或专项微架构检查。
        6. 所有refill相关断言必须先检查refill id对应MB entry状态。只有WFC是正常完成态；ABT只允许late drain；其他状态按stale处理。
        7. 所有fault相关断言必须区分page fault T0和access fault T1，并区分TLB hit权限/PMP来源与exception array replay来源。
        8. 所有invalidate相关断言必须区分TLB entry clear和MB/expt clear：tlboper/regs/VA invalidate只清TLB entry，RTU flush清MB和exception array。

### 3.10 L1DTLB Required Test Scenarios
        本节把第1章功能描述、第2章Q&A澄清和3.7审计表中的requirement进一步整理成可直接落地的test场景。每个场景都描述触发条件、期望行为、建议test/sequence和可观察检查点；这里仍然是文档级test intent，不进入sequence、scoreboard或SVA实现细节。
        场景ID使用`L1DTLB_TS_*`，其中`AUD`列用于追踪到3.7审计表，`Suggested Test / Sequence`优先引用当前`mmu_verification/testbench/test/l1dtlb_tests`中已有wrapper名称；若现有wrapper更像traceability shell或generic pressure test，则在检查点中明确要求补directed stimulus或coverage gate。

#### 3.10.1 Basic Lookup, Dual Pipe, and Page Size
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_BASIC_HIT_PIPE0 | AUD-001 | pipe0单端口basic hit | pipe0发起valid VA，命中有效4K L1DTLB entry，pipe1无请求 | T0返回pipe0 pa_vld、PA和属性；不分配MB、不发L2 request、不写exception array | `test_mmu_l1dtlb_dtlb_hit_001` / `lsu_pipe0_only_seq` | LSU response、translation scoreboard、MB valid delta和L2 request均符合hit路径 |
        | L1DTLB_TS_BASIC_HIT_PIPE1 | AUD-002 | pipe1单端口basic hit | pipe1发起valid VA，命中有效4K L1DTLB entry，pipe0无请求 | T0返回pipe1 pa_vld、PA和属性；pipe0无串扰响应 | `test_mmu_l1dtlb_dtlb_hit_002` / `lsu_pipe1_only_seq` | per-pipe response和fault信号按pipe归属比较 |
        | L1DTLB_TS_BASIC_DUAL_HIT | AUD-003 | pipe0/pipe1同拍dual hit | 两个pipe同cycle valid，分别覆盖命中同一entry和不同entry | 两个pipe同拍独立返回T0 hit结果；一端不能压掉另一端 | `test_mmu_l1dtlb_dtlb_concurrent_001`, `test_mmu_l1dtlb_dtlb_dual_hit_mux_001` | cover同拍dual hit同entry/不同entry，检查两个PA/attr响应 |
        | L1DTLB_TS_BASIC_HIT_MISS | AUD-004 | 同拍hit+miss | 一个pipe命中TLB，另一个pipe miss并需要MB allocation | hit响应不被miss路径、busy、MB full或L2 request阻塞；miss按规则进入MB/L2流程 | `test_mmu_l1dtlb_dtlb_hit_miss_concurrent_001` | cross entry_hit与miss allocation，检查hit端T0 response和miss端MB/L2事件 |
        | L1DTLB_TS_BASIC_PAGE_SIZE_4K_2M_1G | AUD-032 | 4K/2M/1G page size匹配 | 分别构造4K、2M、1G entry，覆盖hit、miss、invalidate、refill/install后再次hit | 按page size比较VPN；PA拼接和属性来自命中entry/refill结果 | `test_mmu_l1dtlb_dtlb_huge_001`, `_002`, `_003`, `test_mmu_l1dtlb_dtlb_huge_mix_001` | page size bins、VPN compare范围、PA/attr scoreboard和invalidate后miss |
        | L1DTLB_TS_BASIC_MULTI_HIT_DIAG | AUD-033 | 多entry同VA匹配诊断 | 人工构造多个valid entry可同时匹配同一VA | 若spec保留最高index优先，则输出按最高index；若后续定义multi-hit非法，则SVA报错且test仅作diagnostic | `test_mmu_l1dtlb_dtlb_entry_field_model_001` plus whitebox diagnostic sequence | entry hit vector、selected index、multi-hit invariant或priority cover |
        | L1DTLB_TS_BASIC_ENTRY_FIELD_MODEL | AUD-051 | entry字段建模完整性 | refill/install写入VPN、PPN、page size、flag后发起hit、permission和attribute访问 | valid entry字段在hit、fault判断、PA生成和属性输出中一致使用；invalid entry不参与hit | `test_mmu_l1dtlb_dtlb_entry_field_model_001` | entry probe与LSU response/scoreboard一致，覆盖flag[13:0]属性输出 |

#### 3.10.2 Request Control, Abort, Busy, and Wakeup
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_CTRL_ABORT_HIT | AUD-011 | abort+hit允许组合响应 | va_vld=1、abort=1且TLB hit | DTLB可以仍返回T0 PA/attr；abort不等价于输出清零，LSU侧丢弃该响应 | `test_mmu_l1dtlb_dtlb_abort_001` with directed hit case | hit+abort response被采样，且无非法state update |
        | L1DTLB_TS_CTRL_ABORT_MISS | AUD-012 | abort+miss无状态后果 | abort=1且该请求若未abort会TLB/expt miss | 不分配MB、不发L2 request、不进入refill FSM | `test_mmu_l1dtlb_dtlb_abort_001`, `test_mmu_l1dtlb_dtlb_alloc_race_001` | MB valid不增加、L2 request无fire、no wakeup/expt write |
        | L1DTLB_TS_CTRL_ABORT_EXPT_HIT | AUD-013 | abort不消费exception array | aborted request命中pending exception array entry | 不向该aborted request报告fault；不释放expt entry和对应MB entry | `test_mmu_l1dtlb_dtlb_abort_001` with expt-hit directed extension | expt-CAM match被观察但clear/MB release不发生，后续非abort replay仍可消费 |
        | L1DTLB_TS_CTRL_VABUF_NO_EFFECT | AUD-014 | vabuf无功能影响 | 相同VA/IID/type/mode/TLB状态下只改变vabuf | PA、fault、attribute、MB allocation和L2 request行为不变 | add low-priority directed/random cover in L1DTLB wrapper | monitor采样vabuf变化，scoreboard比较输出等价 |
        | L1DTLB_TS_CTRL_BUSY_ANY_INFLIGHT | AUD-009 | busy为任意MB valid | MB occupancy为1到满的各个状态，包括hit-under-miss期间 | `mmu_lsu_tlb_busy`在任意MB entry valid时为1；busy不是MB full，也不阻止hit/direct-map请求 | `test_mmu_l1dtlb_dtlb_busy_any_inflight_001`, `test_mmu_l1dtlb_dtlb_busy_restart_mode_001` | cross busy与MB occupancy 1..8，采样busy=1期间hit成功 |
        | L1DTLB_TS_CTRL_WAKEUP_INSTALL | AUD-010 | install触发wakeup广播 | 正常refill/install写入TLB entry | `mmu_lsu_tlb_wakeup[11:0]`只允许12'hfff或12'h000，作为广播提示，不携带pipe/IID/entry语义 | `test_mmu_l1dtlb_dtlb_wakeup_complete_bcast_001` | install事件与wakeup事件级匹配，wakeup形态为全0/全1 |
        | L1DTLB_TS_CTRL_WAKEUP_EXPT | AUD-010 | exception replay触发wakeup广播 | LSU replay命中exception array并消费page/access fault | fault replay完成时发出广播wakeup；MB CAM hit、MB full drop、RTU flush、ABT late refill不单独触发wakeup | `test_mmu_l1dtlb_dtlb_wakeup_expt_001`, `test_mmu_l1dtlb_dtlb_wakeup_multi_retry_001` | expt clear/MB release与wakeup关联，negative source不触发wakeup |
        | L1DTLB_TS_CTRL_RESET_STATE | AUD-042, AUD-054 | reset初始状态 | reset assert/deassert后第一个可检查周期 | TLB valid全0、MB IDLE/invalid、exception invalid、sent清0、busy/wakeup/fault/pa_vld无毛刺，credit为初始最大值 | `test_mmu_l1dtlb_dtlb_reset_state_001` | reset state probe、external outputs和scheduler credit一致 |

#### 3.10.3 Miss Buffer Allocation, CAM, and FSM
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_MB_DUAL_SAME_4K_DEDUP | AUD-005 | 双pipe同4K miss去重 | pipe0/pipe1同拍miss同完整27-bit 4K VPN，至少一个free MB | 只分配一个MB entry，固定写pipe0请求，pipe1不额外分配 | `test_mmu_l1dtlb_dtlb_alloc_001` with directed same-VPN case | allocation count为1、allocated VPN等于pipe0、pipe1无第二entry |
        | L1DTLB_TS_MB_DUAL_DIFF_4K_TWO_FREE | AUD-006 | 双pipe不同4K双分配 | 两pipe同拍miss不同完整VPN，至少两个free MB | 两个miss在T1分配到两个最低编号free entry | `test_mmu_l1dtlb_dtlb_alloc_two_lowest_free_001` | 同cycle两个allocation、entry id为最低两个free、payload按pipe写入 |
        | L1DTLB_TS_MB_DUAL_DIFF_4K_ONE_FREE_AGE | AUD-007 | 单free entry按IID年龄仲裁 | 两pipe同拍miss不同VPN，只有一个free MB，覆盖普通和wrap边界IID | older IID赢得allocation，younger不分配且作为合法无响应/等待重试 | add directed IID-age extension to allocation tests | allocated IID/VPN和未分配pipe一致，覆盖pipe0 older/pipe1 older |
        | L1DTLB_TS_MB_FULL_DROP_RETRY | AUD-008 | MB full drop/retry | 8个MB entry全valid，新TLB/expt miss到达 | 不覆盖已有entry、不分配新entry；busy=1，LSU依赖wakeup/replay协议后续重试 | `test_mmu_l1dtlb_dtlb_alloc_full_001`, `test_mmu_l1dtlb_dtlb_mb_001`, `_002` | MB occupancy=8 bin、无allocation、后续wakeup后重试路径 |
        | L1DTLB_TS_MB_CAM_HIT_NO_ALLOC | AUD-020 | MB CAM hit不分配不wakeup | 第二个请求访问已有pending MB entry的完整4K VPN | 不新增MB entry、不立即wakeup、不产生pa_vld/fault响应；等待原MB refill完成后由LSU replay | `test_mmu_l1dtlb_dtlb_mb_001` with MB CAM hit directed case | MB valid count不变、wakeup不拉高、后续replay成功 |
        | L1DTLB_TS_MB_4K_DEDUP_FOR_HUGE_FINAL | AUD-020 | MB去重不按最终大页放宽 | 两个miss最终可能返回2M/1G page，但pending MB CAM比较仍为完整4K VPN | 只有完整4K VPN相同才去重；不能因最终page size大而错误合并不同4K VPN | `test_mmu_l1dtlb_dtlb_huge_mix_001` plus MB CAM directed cover | MB CAM key使用完整VPN，2M/1G refill后再按entry page size hit |
        | L1DTLB_TS_MB_STATE_SIGNAL | AUD-056 | MB entry状态派生信号 | 覆盖IDLE/WFG/WFC/WFI/PGFLT/ACFLT/ABT状态转换 | entry_vld、entry_wfi、entry_wfc、ready、issued/sent与FSM语义一致 | `test_mmu_l1dtlb_dtlb_mb_state_signal_001`, `test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001` | whitebox state/signal cross和transition coverage |
        | L1DTLB_TS_MB_FAULT_HOLD | AUD-059 | PGFLT/ACFLT保持到replay或flush | fault refill写入exception array后，原请求长时间不replay | MB和exception entry保持valid，不超时自动释放；直到matching replay或RTU flush | `test_mmu_l1dtlb_dtlb_mb_fault_hold_001`, `test_mmu_l1dtlb_dtlb_mb_pgflt_001` | fault entry lifetime、MB state和无spurious release |
        | L1DTLB_TS_MB_STALE_REFILL_ID | AUD-060 | 非WFC stale refill处理 | refill id对应entry处于IDLE/PGFLT/ACFLT或其他非WFC状态 | 不写TLB、不写exception array、不wakeup，按stale完成丢弃 | `test_mmu_l1dtlb_dtlb_refill_stale_id_001` | stale refill事件与无副作用检查 |
        | L1DTLB_TS_MB_ABT_LATE_REFILL | AUD-030, AUD-060 | ABT late refill drain | entry因flush进入ABT后，旧refill返回 | 只允许drain回IDLE；禁止TLB install、exception write和wakeup | `test_mmu_l1dtlb_dtlb_mb_abt_late_refill_001` | ABT->IDLE transition，无install/expt/wakeup side effect |

#### 3.10.4 L2 Request, Scheduler, Credit, and Type Propagation
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_SCHED_CREDIT_BOUND | AUD-021 | credit上下界和守恒 | reset、连续发request、credit return、request+return同拍，覆盖credit=0 | credit初值为DTLB专用ReqQ深度；只被request消耗、return归还；同拍request+return计数不变；credit=0且同拍return允许发一个request | `test_mmu_l1dtlb_dtlb_credit_001`, `_002`, `test_mmu_l1dtlb_dtlb_credit_bound_001` | scheduler credit probe或SVA，request fire条件与credit一致 |
        | L1DTLB_TS_SCHED_ONE_REQ_PER_CYCLE | AUD-022 | 每拍最多一个L2 request | 多个MB ready或MB ready与current bypass同拍竞争 | L1DTLB->L2TLB每cycle最多一个request | `test_mmu_l1dtlb_dtlb_sched_001` | L2 request valid event计数，每cycle不超过1 |
        | L1DTLB_TS_SCHED_OLD_MB_PRIORITY | AUD-022 | old MB优先于bypass | 已有未发送ready MB entry，同时当前cycle出现可bypass新miss | 发送old unsent MB entry，新bypass不得抢占 | `test_mmu_l1dtlb_dtlb_sched_001` with directed priority case | L2 request id/type来自old MB，new miss留在MB中待后续发送 |
        | L1DTLB_TS_SCHED_BYPASS_ALLOC_ISSUE | AUD-023 | bypass allocate+issue同拍 | 当前新miss可分配且无old unsent MB，credit允许发送 | 新miss必须先分配MB并携带entry id同拍发L2；下一拍entry进入WFC且issued/sent=1 | `test_mmu_l1dtlb_dtlb_alloc_race_001` or add directed bypass test | allocation event、L2 request eid、next-state WFC/sent一致 |
        | L1DTLB_TS_SCHED_L2_REQ_PAYLOAD | AUD-050 | L2 request payload稳定 | L2 request valid时覆盖load、store、AMO miss | VPN、MB entry id和load/store access type稳定非X；entry id范围合法并与MB payload一致 | `test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001` | L2 request interface probe、type bins、eid consistency |
        | L1DTLB_TS_SCHED_STORE_TYPE_PROP | AUD-019, AUD-050 | store/load/AMO type传播 | 分别构造load miss、store miss、AMO/LDAMO类请求 | store标识影响L2/PTW/PMP访问类型和permission判断；不直接改变同一entry的PA/属性输出 | `test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001` | L2 req type、PTW/PMP type、page fault原因和attr输出cross |

#### 3.10.5 Permission, Fault Timing, PMP, and Direct Map
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_FAULT_RESPONSE_TIMING | AUD-015 | T0/T1响应和fault pulse | TLB hit page fault、PMP access fault、exception page/access fault replay | pa_vld/PA/page_fault在T0；access_fault在T1；page/access fault为1-cycle pulse；同一请求page/access fault互斥 | `test_mmu_l1dtlb_dtlb_resp_no_iid_t01_001`, `test_mmu_l1dtlb_dtlb_pa_vld_terminal_001`, `test_mmu_l1dtlb_dtlb_access_fault_t1_pairing_001` | per-pipe temporal check、pulse width、request ownership |
        | L1DTLB_TS_FAULT_LOAD_R0 | AUD-016 | load访问R=0 page fault | load访问R=0且MXR不能放行的leaf PTE | T0返回pa_vld和page_fault，不进入PMP check | `test_mmu_l1dtlb_dtlb_perm_ld_001` with directed PTE | PTE setup、page_fault pulse、PMP token absence |
        | L1DTLB_TS_FAULT_LOAD_MXR | AUD-017 | MXR读X-only page | load访问X=1/R=0 page，分别MXR=0和MXR=1 | MXR=0 page fault；MXR=1且其他检查通过时允许读 | `test_mmu_l1dtlb_dtlb_perm_ld_002` | CP0 MXR setting、PTE flags、LSU response cross |
        | L1DTLB_TS_FAULT_STORE_W_D | AUD-018 | store W=0/D=0 page fault | store访问W=0 page和D=0 page | T0 page fault；L1DTLB test不期待硬件D-bit update/writeback | `test_mmu_l1dtlb_dtlb_perm_st_001`, `_002` | PTE不变、page_fault pulse、无D-bit writeback expectation |
        | L1DTLB_TS_FAULT_AD_US_SUM | AUD-016, AUD-018 | A/U/S/SUM权限组合 | load/store分别覆盖A=0、U/S不满足、SUM开关组合、VA illegal | 满足spec的page fault条件均T0报page_fault；合法组合允许继续PMP | permission directed extension | permission cover bins、page_fault与PMP token互斥/允许关系 |
        | L1DTLB_TS_FAULT_PF_BLOCKS_PMP | AUD-048 | page fault阻止PMP | TLB hit但PTE权限/VA illegal导致page fault，同时PMP配置可产生access fault | 该请求T0 page_fault+pa_vld，不为该请求发PMP check，不产生同请求access fault | `test_mmu_l1dtlb_dtlb_pf_blocks_pmp_001` | page_fault和PMP token/access_fault归属检查 |
        | L1DTLB_TS_FAULT_OVERLAP_PIPE | AUD-045, AUD-046, AUD-049 | T1 access fault与下一拍T0事件重叠 | 连续同pipe请求：上一拍进入PMP并在T1 access fault，当前拍又有T0 pa_vld/page_fault | 同cycle裸信号可重叠，但必须归属不同请求；scoreboard不能把access_fault和当前pa_vld强配对 | `test_mmu_l1dtlb_dtlb_fault_overlap_pipe_001`, `test_mmu_l1dtlb_dtlb_access_fault_t1_pairing_001` | request token、pipe、cycle pairing和fault ownership |
        | L1DTLB_TS_FAULT_PMP_ACCESS | AUD-047, AUD-049 | PMP T1 payload归属 | TLB hit或direct map且无page fault，PMP配置拒绝read/write | PA/attr在T0返回；T1 access_fault由上一拍有效PMP token产生，payload稳定 | `test_mmu_l1dtlb_dtlb_pmp_001` | PMP req payload、read/write type、T1 fault response |
        | L1DTLB_TS_MODE_DIRECT_MAP | AUD-041 | MMU off/M-mode direct map | regs_mmu_en=0、effective M-mode、以及MPRV导致非M effective mode三类 | MMU off/M-mode不查TLB、不分配MB、不产生PTE page fault，PA按VA direct map，属性来自sysmap；仍允许PMP检查 | `test_mmu_l1dtlb_dtlb_sysmap_001` | direct-map PA/attr、MB/L2无副作用、PMP access_fault可触发 |
        | L1DTLB_TS_MODE_STAMO_PIPE1 | AUD-039 | STAMO pipe1 bypass | pipe1/store pipe发STAMO bypass请求 | 返回LM/STAMO保存路径PA/attr；不查TLB、不分配MB、不写expt、不污染PLRU/refill路径 | `test_mmu_l1dtlb_dtlb_stamo_001`, `test_mmu_l1dtlb_dtlb_stamo_pipe1_bypass_001` | pipe1 response source、无TLB/MB/L2 side effect |
        | L1DTLB_TS_MODE_STAMO_PIPE0_NEG | AUD-040 | pipe0 STAMO negative | pipe0普通请求与STAMO相关控制同拍或尝试pipe0 STAMO | pipe0不产生STAMO bypass效果，不污染pipe0普通translation | `test_mmu_l1dtlb_dtlb_stamo_pipe0_neg_001` | pipe0按普通TLB/direct-map路径，pipe1 bypass不串扰 |

#### 3.10.6 Refill, Install, WFI, and Exception Array
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_INSTALL_ARB_WFI_PTW_L2 | AUD-024 | install优先级WFI > PTW > L2 | WFI candidate、PTW normal refill和L2 normal refill同cycle竞争 | 每拍最多写一个TLB entry，固定优先级WFI、PTW、L2；未获grant的normal refill进入WFI保存 | `test_mmu_l1dtlb_dtlb_install_arb_001`, `test_mmu_l1dtlb_dtlb_refill_001`, `_002` | install source select、entry write、loser WFI latch |
        | L1DTLB_TS_INSTALL_MULTI_WFI_LOWEST | AUD-025 | 多WFI最低entry优先 | 两个或更多MB entry同时处于WFI且可install | 选择最低编号WFI entry install，每拍仍只写一个TLB entry | `test_mmu_l1dtlb_dtlb_mb_fsm_wfi_001`, `test_mmu_l1dtlb_dtlb_install_id_chk_001` | WFI vector、selected id、entry update id |
        | L1DTLB_TS_INSTALL_WFI_DATA_HOLD | AUD-057 | WFI data hold | normal refill未获install grant进入WFI，等待多拍后install | WFI期间保持原miss VPN、refill PPN、flag、page size稳定；后续install数据等于latch数据 | `test_mmu_l1dtlb_dtlb_wfi_data_hold_001` | WFI latch fields稳定性和最终entry write一致 |
        | L1DTLB_TS_INSTALL_VISIBILITY_RELEASE | AUD-061 | install可见性与MB释放时序 | TLB install与对应MB entry release同沿发生，并在同VPN请求前后发访问 | 写入前同组合周期不能命中新entry；下一可见cycle才允许命中；MB同沿释放 | `test_mmu_l1dtlb_dtlb_install_visibility_001` | same-cycle miss/hit boundary、next-cycle hit、MB valid drop |
        | L1DTLB_TS_EXPT_FAULT_REFILL_WRITE | AUD-026 | fault refill写exception array不写TLB | PTW对WFC entry返回page/access fault，或L2返回page fault | fault写exception array；不写TLB entry；L2 refill不作为access fault来源 | `test_mmu_l1dtlb_dtlb_mb_pgflt_001`, `test_mmu_l1dtlb_dtlb_access_fault_source_parity_001` | expt write probe、TLB entry no-write、后续fault replay |
        | L1DTLB_TS_EXPT_DUAL_FAULT_WRITE | AUD-027, AUD-058 | PTW/L2同拍fault写两entry | PTW和L2同cycle对不同MB id返回fault | 两个exception entry都记录；id在范围内并直接映射refill MB id | `test_mmu_l1dtlb_dtlb_expt_id_map_001` with dual-fault extension | expt wr0/wr1 valid、id map、array capacity等于MB depth |
        | L1DTLB_TS_EXPT_REPLAY_CONSUME | AUD-028 | exception replay消费 | LSU replay匹配IID+完整4K VPN的fault entry | page fault replay为T0，access fault replay为T1；exception entry和对应MB entry同拍释放；不再分配新MB | `test_mmu_l1dtlb_dtlb_mb_pgflt_001`, `test_mmu_l1dtlb_dtlb_wakeup_expt_001` | expt match/clear、MB release、fault timing、no allocation |
        | L1DTLB_TS_EXPT_DUAL_SAME_ENTRY_NEG | AUD-029 | 双pipe同拍消费同expt entry负向约束 | 构造两个pipe同拍访问相同VPN但IID不同，或diagnostic非法同IID | 合法场景下不应同拍命中同一exception entry；若出现应作为design/spec violation，不做port0 priority消费期望 | `test_mmu_l1dtlb_dtlb_expt_dual_same_entry_neg_001` | same-entry dual hit invariant、no double release |
        | L1DTLB_TS_EXPT_HIT_WITH_TLB_HIT | AUD-052 | 一pipe TLB hit、一pipe expt hit | 两pipe同拍，一个普通TLB hit，另一个exception array hit | 两路响应/释放互不污染；TLB hit端正常返回，expt端按fault replay释放并wakeup | `test_mmu_l1dtlb_dtlb_expt_hit_with_tlb_hit_001` | per-pipe response、expt/MB clear、wakeup broadcast |
        | L1DTLB_TS_EXPT_ACCESS_FAULT_SOURCE_PARITY | AUD-062 | access fault来源一致性 | 分别由PTW fault replay和PMP检查产生access fault；L2尝试access fault作为negative | PTW可返回access fault；L2只可normal/page fault；最终对LSU均表现为replay/PMP后的T1 access_fault | `test_mmu_l1dtlb_dtlb_access_fault_source_parity_001` | source type cover、T1 timing、L2 access fault negative |

#### 3.10.7 Invalidate, Cleanup, Flush, Race, and PLRU
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_INV_TLBOPER_CLR | AUD-034 | tlboper_utlb_clr全清TLB entry | TLBWI/TLBWR/INVASID/INVALL等触发tlboper_utlb_clr | 清空全部L1DTLB entry valid；不清MB和exception array | `test_mmu_l1dtlb_dtlb_inv_001`, `_002`, `test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001` | entry valid all-zero，MB/expt lifetime不变 |
        | L1DTLB_TS_INV_REGS_CLR | AUD-035 | regs_utlb_clr全清TLB entry | SATP/mode/asid相关寄存器变化触发regs_utlb_clr | 因L1 entry不保存ASID，相关L1清理按全清entry处理；不清MB/expt | `test_mmu_l1dtlb_dtlb_inv_003`, `test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001` | all entry invalid，pending MB/expt保留 |
        | L1DTLB_TS_INV_VA8_ALIAS | AUD-036 | VA定点失效低8bit保守清理 | tlboper_utlb_inv_va_req携带目标VA，构造VPN[7:0]相同/不同entry | VPN[7:0]匹配的valid entry下拍失效；低8bit不匹配entry不被该局部clear误清 | `test_mmu_l1dtlb_dtlb_inv_va8_alias_001`, `test_mmu_l1dtlb_dtlb_inv_004` | per-entry valid变化、alias conservative clear coverage |
        | L1DTLB_TS_INV_HIT_SAME_CYCLE | AUD-037 | invalidate与TLB hit同拍 | 同cycle发起hit并触发匹配entry invalidate | 本拍允许返回旧entry hit；下一拍起该entry不得继续作为valid hit | `test_mmu_l1dtlb_dtlb_inv_hit_same_cycle_001` | same-cycle response和next-cycle miss |
        | L1DTLB_TS_INV_INSTALL_SAME_ENTRY | AUD-038 | invalidate与install同entry | clear/invalidate与TLB install同拍选择同一entry | clear优先，时钟沿后该entry最终valid=0 | `test_mmu_l1dtlb_dtlb_inv_install_same_entry_001` | selected entry final valid、no stale hit |
        | L1DTLB_TS_FLUSH_RTU_CLEAR_SCOPE | AUD-031, AUD-053 | RTU flush清理范围 | RTU flush发生时存在TLB entry、MB entry和exception entry | RTU flush清MB和exception array；TLB entry清理按spec对应控制；flush kill的miss不得install/expt write/wakeup | `test_mmu_l1dtlb_dtlb_cleanup_scope_matrix_001` | MB/expt all clear、no side effect from killed miss |
        | L1DTLB_TS_FLUSH_MB_RACE_MATRIX | AUD-064 | RTU flush与MB FSM同拍race | 分别覆盖WFG+flush无grant、WFG+flush+grant、WFC+flush无refill、WFC+flush+refill、WFI+flush | 最终状态按Q072矩阵：IDLE或ABT drain；禁止非法install/expt/wakeup | `test_mmu_l1dtlb_dtlb_mb_flush_race_matrix_001` | state transition matrix、side-effect negative checks |
        | L1DTLB_TS_PLRU_WHITEBOX_ONLY | AUD-043, AUD-055 | PLRU只作whitebox覆盖 | hit、install、双pipe hit、refill victim、invalidate后replacement pressure | 不把exact victim作为black-box pass/fail；只检查victim onehot/onehot0、index范围和更新输入非X | `test_mmu_l1dtlb_dtlb_plru_001`, `test_mmu_l1dtlb_dtlb_plru_whitebox_only_001` | whitebox cover/SVA，主translation scoreboard不预测exact victim |

#### 3.10.8 Scoreboard, Observability, and Regression Closure
        | Scenario ID | AUD | Test Scenario | Trigger / Stimulus | Expected Behavior | Suggested Test / Sequence | Observable Check |
        | --- | --- | --- | --- | --- | --- | --- |
        | L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY | AUD-063 | reference model观察边界 | 综合覆盖外部接口可推导事件、whitebox-only事件、合法无响应事件和wakeup/HPC事件 | PA、attr、pa_vld、page_fault、access_fault、L2 request、credit、busy逐拍精确；wakeup按事件级广播检查；PLRU victim不进入主正确性判断 | `test_mmu_l1dtlb_dtlb_ref_model_observability_001` | scoreboard checklist、whitebox-only probe清单、legal no-response分类 |
        | L1DTLB_TS_OBS_LEGAL_NO_RESPONSE | AUD-008, AUD-020, AUD-031, AUD-063 | 合法无响应分类 | MB CAM hit、MB full未分配、abort屏蔽状态后果、flush kill请求 | 不被误判为漏响应；但必须检查没有非法allocation、install、exception write或wakeup | `test_mmu_l1dtlb_dtlb_ref_model_observability_001` | no-response reason code或monitor annotation，后续wakeup/replay/flush终止生命周期 |
        | L1DTLB_TS_OBS_HPC_MISS_EVENT | AUD-063 | miss统计/HPC事件守护 | hit、direct map、STAMO bypass、exception replay、abort miss、真实TLB/expt miss | miss/HPC事件不在非真实miss路径误拉高；真实进入miss处理时允许1-cycle事件 | add cover/check in observability or perf wrapper | `mmu_hpcp_dutlb_miss`等事件级采样 |
        | L1DTLB_TS_OBS_WRAPPER_RETARGET | AUD-044 | 共享generic vseq retarget闭环 | 原先只映射到`mmu_ptw_thrash_vseq`或`mmu_concurrent_3pipe_vseq`的wrapper进入回归 | wrapper必须被retarget为L1DTLB-directed stimulus，或明确标记为traceability shell，不能声称已完全覆盖directed requirement | `test_mmu_l1dtlb_dtlb_ref_model_observability_001` plus regression checklist | regression report标明directed/traceability shell状态 |
        | L1DTLB_TS_OBS_SVA_COVER_CLOSURE | AUD-001..AUD-064 | SVA cover closure | 跑包含所有L1DTLB directed wrappers的regression | 3.9 cover矩阵C001-C027应能证明关键场景被采样；未命中的cover反向生成directed test缺口 | all `l1dtlb_tests_suite.svh` wrappers | cover property report和AUD/Scenario traceability矩阵 |

#### 3.10.9 Current UVM Implementation Landing Status
        | Item | Implementation |
        | --- | --- |
        | `L1DTLB_SVA_A062` / `L1DTLB_TS_INV_VA8_ALIAS` | Implemented by per-entry VPN probe `l1d_entry_vpn`, `a_va8_inv_clears_matching_entry`, `a_va8_inv_preserves_nonmatching_entry`, `cp_l1dtlb_c020_va8_alias_clear`, `DTLB_INV_VA8_alias_001`, and the spec-SB `va8_inv` gate. |
        | `L1DTLB_SVA_A064` / `L1DTLB_TS_INV_INSTALL_SAME_ENTRY` | Implemented by `a_clear_wins_install_same_entry`, `cp_l1dtlb_c020_inv_install_same_entry`, `DTLB_INV_INSTALL_SAME_ENTRY_001`, and the spec-SB clear/install-overlap gate. |
        | `L1DTLB_SVA_C006` / `DTLB_ALLOC_RACE_001` | Strengthened with one-free port0-wins and port1-wins allocator covers plus a dedicated alloc-race vseq dispatch; exact circular IID-age proof remains formal/RTL-local. |
        | `L1DTLB_SVA_C018` / `DTLB_INSTALL_VISIBILITY_001` | Strengthened with a dedicated install-visibility vseq dispatch and spec-SB `install_visible_next` event gate. |
        | `L1DTLB_TS_OBS_LEGAL_NO_RESPONSE` | Strengthened with MB-CAM, abort and flush legal-no-response counters in `mmu_l1dtlb_spec_sb.svh`; full transaction-level reason annotation remains future work. |

### 3.11 L1DTLB Reference Model和Scoreboard实现需求
        本节把第1章功能描述、第2章Q&A澄清和第3章audit/test scenario整理成UVM实现层面的文字需求，用于后续审核或补充`mmu_ref_model.svh`、`mmu_translation_sb.svh`、`mmu_credit_sb.svh`、`mmu_l1dtlb_spec_sb.svh`、`mmu_dut_probes_if.sv`、LSU/L2TLB/PTW/PMP/sysmap monitor以及相关covergroup/SVA。
        本节不是要求把所有RTL内部细节都做成主scoreboard的pass/fail oracle。主原则是：凡是由spec和外部接口能够推导的architectural或micro-architectural可见行为，必须进入reference model或scoreboard；凡是当前spec明确作为黑盒的行为，尤其是PLRU exact victim，只能进入white-box assertion/coverage/debug，不得作为主translation correctness的失败依据。

#### 3.11.1 总体分工
        L1DTLB reference model负责维护“按spec可推导的L1DTLB状态”和预测下一拍/当前拍应出现的可见结果。它至少需要包含TLB entry shadow、miss buffer shadow、exception array shadow、credit shadow、per-pipe T0/T1流水token、direct-map/sysmap/PMP相关输入镜像，以及reset/flush/invalidate对这些状态的影响。

        L1DTLB scoreboard负责把reference model的期望和DUT采样结果比较。比较对象分为三类：
            1. 逐pipe逐拍精确比较：pa_vld、PA、属性、page_fault、access_fault、L1DTLB->L2TLB request valid/VPN/type/eid、credit、busy、TLB entry valid清理后的可见命中结果。
            2. 事件级比较：wakeup广播、miss/HPC事件、合法无响应请求的生命周期、directed scenario是否真正触发目标场景。
            3. white-box辅助检查：MB FSM派生信号、exception array写入id、install source、PLRU victim onehot、entry_upd onehot等。这些可以帮助定位问题，但只有已经写入spec且不属于黑盒的部分才能升级为主pass/fail。

        现有UVM组件的建议职责划分如下：
            `mmu_ref_model.svh`继续负责页表级Sv39翻译、权限、PMP/sysmap/CSR镜像和direct-map结果；需要补充或暴露L1DTLB可复用的permission、PA拼接、属性生成函数，避免translation scoreboard和L1DTLB scoreboard各自实现一套不一致规则。
            `mmu_translation_sb.svh`负责LSU/IFU最终translation结果比较。对L1DTLB部分，它必须正确处理DTLB hit、direct map、STAMO pipe1 bypass、exception array replay、T0 page fault和T1 access fault归属。
            `mmu_l1dtlb_spec_sb.svh`负责L1DTLB micro-architecture protocol检查：MB/exception/credit/install/invalidate/flush/wakeup/busy等按cycle或事件的检查。
            `mmu_credit_sb.svh`可继续承担跨L1/L2 request queue容量守恒检查，但L1DTLB scheduler自己的credit_cnt边界和同拍return+fire规则应在L1DTLB spec scoreboard中有明确检查或与credit scoreboard共享同一个credit shadow。
            `mmu_dut_probes_if.sv`只作为可观测性补充。主scoreboard不能因为某个内部probe和reference model不同就绕过外部接口错误；也不能用PLRU victim probe替代translation正确性判断。

#### 3.11.2 Reference Model必须建模的数据结构
        L1DTLB entry shadow：
            每个entry至少保存valid、VPN[26:0]、PPN[27:0]、page size[2:0]、flag[13:0]。page size one-hot语义为4K=001、2M=010、1G=100。
            flag[13:0]需要按spec解释为V/R/W/X/U/A/D/RSW/sec/share/bufferable/cacheable/SO等字段，并用于预测page fault、PA、cacheable、bufferable、shareable、secure、strong-order等输出。
            L1DTLB entry不保存ASID和global bit；SATP变化、ASID相关TLBI或全局TLB操作对L1DTLB按全清或spec指定清理建模。
            如果同一VA多个entry同时命中，主scoreboard不应假设architectural非法；可建立white-box invariant检查multi-hit风险。若要比较RTL当前最高index优先行为，必须先把该行为明确纳入spec。

        Miss buffer shadow：
            深度按spec为8。每个entry保存valid、state、issued/sent、VPN[26:0]、IID[6:0]、store/load type、refill返回后需要install的PPN、flag、page size，以及是否已经处于WFI/PGFLT/ACFLT/ABT。
            state集合为IDLE、WFG、WFC、WFI、PGFLT、ACFLT、ABT。valid等价于state!=IDLE；wfi等价于state==WFI；wfc对WFC和ABT均有效；ready基本对应WFG但需考虑flush同拍屏蔽；issued/sent是latch，不是简单状态译码。
            MB CAM固定按完整4K VPN[26:0]比较，不按最终page size放宽比较。一个MB entry可以代表多个等待同一4K page的LSU请求，但不记录多个IID/pipe；后续请求依赖wakeup后replay并命中TLB或exception array。

        Exception array shadow：
            深度必须等于MB深度，entry id直接等于refill携带的MB id。每个entry保存valid、IID、完整4K VPN、page fault标志、access fault标志，并与对应MB entry生命周期绑定。
            只有PTW/L2TLB fault refill写exception array。L2TLB可以返回normal或page fault；PTW可以返回normal、page fault或access fault。fault refill一定不写TLB。
            exception array匹配key为IID+完整4K VPN，不包含pipe、ASID、load/store type。命中后对应exception entry和MB entry同拍释放；abort请求即使命中exception array也不得消费entry。

        Credit shadow：
            初始值为L2TLB request queue中DTLB专用entry数量，当前spec为8。最小值0，最大值CREDIT_MAX。
            L1DTLB每发出一个L2TLB request消耗1个credit；L2TLB归还credit增加1个credit；同拍return+fire时计数保持不变。credit=0但同拍return时允许fire，且该fire消耗同拍归还的credit。
            reference model需要逐拍维护credit，禁止underflow/overflow，禁止无credit且无同拍return时发request。

        Per-pipe T0/T1 token：
            每个pipe维护当前T0 request token和上一拍进入T1/PMP或exception access-fault路径的token。token至少记录pipe、cycle、VA/VPN、IID、abort、store/load/AMO/STAMO类型、effective mode、是否direct map、是否TLB hit、是否page fault、是否需要PMP check、预期PA/属性。
            MMU对外响应不携带IID，scoreboard不得从响应端恢复IID。pa_vld/PA/attr/page_fault归属当前pipe当前T0 token；access_fault归属当前pipe上一拍T1 token。

#### 3.11.3 Lookup、权限、PA和属性预测
        每个有效LSU VA请求在T0进行TLB entry CAM和exception array CAM。普通pipe0/pipe1 DTLB lookup基本对称，但pipe来源和类型语义不同：pipe0主要服务load/LDAMO，pipe1主要服务store/STAMO。

        TLB hit预测：
            4K entry比较VPN[26:0]，2M entry比较VPN[26:9]，1G entry比较VPN[26:18]。
            命中后按page size拼接PA：4K使用entry PPN和VA[11:0]；2M使用entry PPN高位和VA[20:0]；1G使用entry PPN高位和VA[29:0]。scoreboard需要检查返回PA和属性来自命中entry或direct-map/sysmap路径。
            hit且没有page fault时，pa_vld、PA和属性在T0返回，同时启动下一拍PMP check token。PMP失败时access_fault在T1输出，不要求与同拍pa_vld配对。

        Page fault预测：
            MMU关闭或effective M-mode direct map时，不按PTE产生page fault。
            普通L1DTLB hit需要检查VA illegal、V/R/W/X/U、当前/effective privilege、MXR、SUM、A/D、W=1且R=0非法组合等规则。load可由MXR允许X-only页作为可读；store和AMO需要W和D；load不要求D；A对load/store/AMO都要求为1。
            page_fault为T0 1-cycle pulse，且有效page fault事件必须与同pipe当前T0的pa_vld同拍。对同一请求page_fault和access_fault互斥；但同一pipe同一cycle的裸page_fault和access_fault可能属于不同流水token，不能直接报互斥错误。

        PMP access fault预测：
            TLB hit或direct-map且无page fault时建立T1 PMP token。load/read检查PMP read许可，store检查PMP write许可，atomic/LDAMO可能同时有read/write语义。effective M-mode在PMP entry未lock时可绕过deny；lock时M-mode也可能access fault。
            PMP access fault在T1以1-cycle pulse返回。scoreboard必须允许同一cycle当前T0又有新的pa_vld或page_fault，因为它们属于不同请求。

        Direct map/sysmap预测：
            当MMU关闭、SATP bare或effective privilege为M-mode时，L1DTLB不查TLB、不分配MB、不产生PTE page fault，PA按VA直通，属性来自sysmap，仍然进入PMP check并可能在T1产生access_fault。
            direct-map路径需要检查没有TLB/MB/L2 request/exception array副作用。MPRV=1且MPP为S/U时不能误当M-mode bypass，应按effective privilege走普通DTLB规则。

        STAMO预测：
            STAMO只支持pipe1/store pipe bypass，PA和属性来自LM/STAMO保存路径。STAMO不重新做TLB lookup、不做PTE permission check、不产生新TLB miss、不分配MB、不发L2 request、不写exception array、不重新做PMP check。
            pipe0不得产生STAMO bypass效果。pipe0普通请求和pipe1 STAMO同拍时，scoreboard需要分别按各自路径比较，不能串扰。

#### 3.11.4 Miss Buffer、L2 Request和合法无响应
        T0 TLB miss且exception array miss后，miss_vld进入T1；T1对MB做完整4K VPN CAM。若MB CAM hit，本次请求不分配新MB entry，不产生response或wakeup，属于合法无响应，后续依赖已有miss完成后的wakeup和LSU replay。

        MB分配规则必须建模：
            双pipe同拍miss且同一4K page、MB空位>=1时，只给pipe0分配entry，pipe1不分配。
            双pipe同拍miss且不同4K page、MB空位>=2时，两个最低空闲entry分别分配给两pipe。
            双pipe同拍miss且不同4K page、MB仅1个空位时，使用IID年龄比较选择更老请求。IID为7-bit循环编号，比较时按bit6和低6位规则处理回绕；pipe0/pipe1同拍IID不应相同。
            单pipe miss且MB有空位时分配一个entry；MB无空位时drop本次miss，依赖busy和后续wakeup replay。
            abort请求不分配MB，不消费exception entry；但abort不屏蔽TLB hit响应、page_fault、PMP check或PLRU read-hit更新。

        L2 request发送规则必须逐拍建模：
            每拍最多发送一个L1DTLB->L2TLB request，包括MB旧entry发送和当前新miss bypass发送的总和。
            当MB中已有未发送entry时，优先发送MB旧entry；没有未发送entry且当前有可分配miss时，允许allocate+bypass同拍发往L2TLB。
            bypass request也必须先分配MB entry；如果同拍发出，entry下一拍进入WFC，否则进入WFG。
            request payload只检查接口真实携带字段：valid、VPN[26:0]、EID、is_load/access type。不要把iid、pipe id、asid或page size预测当成L1DTLB->L2TLB request接口字段。

        合法无响应分类必须在scoreboard中显式记录reason：
            MB CAM hit等待已有refill、MB full未分配、busy下miss等待replay、abort屏蔽状态后果、flush kill请求、TLB miss但请求被同拍优先级丢弃，均不能被简单判为漏响应。
            对合法无响应请求，scoreboard仍需检查没有非法副作用：不得错误分配MB、不得错误发L2 request、不得错误消费exception array、不得错误写TLB或产生fault；后续应由wakeup/replay或flush终止生命周期。

#### 3.11.5 Refill、Install和Exception Array生命周期
        Normal refill处理：
            PTW normal refill和L2TLB normal refill只有在refill id对应MB entry处于WFC时才有效。若entry已IDLE、PGFLT/ACFLT或其他不允许完成的状态，则视为stale response，不得写TLB、不得写exception array、不得wakeup。ABT是特殊状态，late refill只用于drain回IDLE。
            每拍最多install一个TLB entry。固定优先级为WFI entry > PTW normal refill > L2TLB normal refill。多个WFI同时存在时选择最低entry编号。
            未获install grant的normal refill需要把VPN、PPN、flag、page size锁存在对应MB entry并进入WFI；WFI期间这些字段必须保持稳定，直到后续install或flush清除。
            TLB install和对应MB释放在同一个时钟沿完成。写入沿之前同一组合周期不能命中新entry；下一可见cycle才允许命中。

        Fault refill处理：
            refill携带page fault或access fault时一定不写TLB。fault entry并行写exception array，对应MB entry进入PGFLT或ACFLT并保持valid，等待后续LSU replay命中exception array。
            PTW和L2TLB同拍都返回fault时，允许同拍写两个不同exception array entry。scoreboard需要检查EID在范围内、两个fault互不覆盖、page/access fault标志互斥。
            L2TLB refill不应作为access fault来源；若接口或probe显示L2 path access fault，需要作为negative check或spec violation处理。PTW access fault和PMP access fault最终对LSU均表现为T1 access_fault，但PTW access fault必须先经exception array挂起并由replay触发。

        Exception replay处理：
            后续LSU请求按IID+完整4K VPN命中exception array时，pa_vld必须在T0拉高。若entry为page fault，page_fault也在T0拉高；若entry为access fault，则T0只建立access-fault pending token，T1拉高access_fault。
            exception array hit必须禁止该请求分配新MB entry。命中后exception entry和对应MB entry同拍释放，并产生wakeup广播。
            同一pipe同一请求同时TLB hit和exception array hit应视为design/spec violation。合法场景下双pipe不会同拍消费同一个exception entry，因为匹配key包含IID且同拍pipe IID不相同。

#### 3.11.6 Flush、Invalidate、Reset和PLRU边界
        Reset建模：
            reset释放后，TLB entry valid全0；MB state全IDLE、valid/issued/sent/wfi/wfc/ready均为0；exception array valid全0；credit=CREDIT_MAX；PLRU状态作为黑盒，不进入主模型。

        TLB entry清理建模：
            regs_utlb_clr、tlboper_utlb_clr和ctc_inv_va_hit_clr任意一个有效时，对命中的entry清valid。regs_utlb_clr和tlboper_utlb_clr按全清TLB entry建模，不清MB和exception array。
            VA定点失效按VPN[7:0]相同的保守清理建模。若scoreboard逐拍预测hit/miss和refill次数，必须把低8bit alias误清纳入模型；只做最终功能检查时，至少要保证目标VA旧翻译后续不能继续命中。
            invalidate与TLB hit同拍时，本拍允许返回旧entry结果；下一拍起该entry不得作为valid hit。invalidate与install同entry同拍时，clear优先，时钟沿后entry final valid=0。

        RTU flush建模：
            RTU flush清空MB和exception array。对TLB entry是否清理只按regs_utlb_clr/tlboper_utlb_clr/VA invalidate等对应控制建模，不把RTU flush无条件当作TLB全清。
            WFG+flush无grant回IDLE；WFG+flush+grant进入ABT；WFC+flush+refill回IDLE但禁止install/expt/wakeup；WFC+flush无refill进入ABT；WFI+flush回IDLE。ABT+late refill只释放entry，不写TLB、不写exception array、不wakeup。

        PLRU建模边界：
            主reference model不精确预测PLRU victim、hit更新、install更新或invalidate后的PLRU状态。主scoreboard只检查已可观测install进入L1DTLB的entry在后续hit时返回正确PA/属性/fault，或被clear后不再命中。
            PLRU相关检查只能放入white-box SVA/coverage：victim onehot/onehot0、index范围、更新输入非X、replacement pressure覆盖等。不得因为黑盒PLRU exact victim与reference model不同而报translation failure。

#### 3.11.7 Scoreboard逐项检查清单
        LSU响应检查：
            对pipe0/pipe1分别建立T0/T1队列。T0检查pa_vld、PA、attr、page_fault；T1检查access_fault。page_fault必须与同一T0 token的pa_vld配对；access_fault必须与上一拍有效T1 token配对。
            同一cycle同一pipe的page_fault和access_fault同时为高时，不立即报同一请求双异常；必须先按T0/T1 token归属判断。只有同一token同时产生page fault和access fault才报错。
            属性比较需要覆盖sec、share、bufferable、cacheable、SO等L1DTLB输出语义，load/store访问同一translation时属性不应因store标识而改变。

        L2 request和credit检查：
            每拍最多一个L1DTLB->L2TLB request；payload无X；EID范围合法；VPN等于被发送MB/bypass miss的完整4K VPN；is_load/access type与LSU request类型一致。
            credit shadow和DUT credit逐拍一致，或至少检查边界、同拍return+fire守恒、credit=0无return禁止fire。若DUT内部credit probe不可用，仍需用外部request/return事件建立近似守恒检查并报告不可精确覆盖的风险。

        Busy/wakeup检查：
            busy逐拍等于任意MB entry valid。busy不是LSU VA请求ready，busy=1时hit-under-miss仍需正常返回hit响应。
            wakeup是12-bit广播提示，只允许全0或全1。触发源只包括TLB install和exception array hit/replay完成；MB CAM hit、MB full本身、RTU flush drain、ABT late refill不应产生wakeup。
            wakeup不携带pipe或IID，不得作为某条请求完成信号逐请求匹配；只能作为事件级提示，并结合后续LSU replay观察生命周期闭环。

        MB/exception/install检查：
            分配数量、最低空闲entry选择、同4K去重、IID年龄仲裁、MB CAM hit不再分配、MB full drop等必须与spec一致。
            MB FSM派生信号、WFI最低编号优先、install优先级、WFI data hold、fault refill不写TLB、exception id映射、exception replay释放等需要覆盖到directed测试和scoreboard/SVA检查。
            stale/late refill必须被识别，禁止污染TLB或exception array。

        Invalidate/flush/reset检查：
            reset后初始状态、全清、VA8 alias清理、invalidate+hit、invalidate+install、flush+grant/refill/install race都需要有检查和coverage。
            清理动作如果影响后续hit/miss预测，reference model必须同步更新shadow状态，避免scoreboard用旧translation误报或漏报。

        Scenario gate和回归闭环：
            每个L1DTLB directed wrapper需要通过`L1DTLB_TC_ID`/`L1DTLB_SCENARIO_ID`或等价机制告诉scoreboard本用例目标。scoreboard final_phase需要报告目标事件是否真实发生，防止wrapper只是跑了generic vseq却没有触发需求场景。
            3.7 audit ID、3.9 SVA ID、3.10 scenario ID和UVM test name应建立traceability矩阵。未命中的cover property需要反向生成新的directed test或标记为不可达/需澄清。

#### 3.11.8 Monitor、Probe和UVM落地项
        LSU monitor需要采样每个pipe的VA、va_vld、iid、abort、store/load/AMO/STAMO标识、effective mode相关输入、pa_vld、PA、属性、page_fault、access_fault、tlb_busy、tlb_wakeup，并形成能区分T0响应和T1 fault的transaction或cycle event。

        L2TLB/PTW monitor需要采样L1DTLB发出的request、credit return、L2 normal/page-fault refill、PTW normal/page-fault/access-fault refill、refill id、VPN、PPN、flag、page size和type。refill id必须能关联到MB shadow entry。

        CP0/sysmap/PMP monitor需要把SATP、MMU enable、privilege、MPRV/MPP、MXR、SUM、TLB invalidate、sysmap region和PMP配置同步到reference model。translation比较前必须同步这些shadow状态，避免同拍CSR/PMP更新造成非确定性误报。

        `mmu_dut_probes_if.sv`建议至少保留并审查以下L1DTLB probes：MB valid/state/VPN/IID/store/ready/wfc/wfi、entry valid、L2 request valid/VPN/EID/type、scheduler credit、per-pipe hit/miss/expt_match、refill valid/source/index/VPN/PPN/page size、entry_upd、exception write valid/EID/IID/VPN/fault、RTU flush和utlb clear/inv_va控制。若主scoreboard需要独立预测但接口缺少必要事件，应优先补monitor transaction；内部probe只能作为辅助或white-box检查。

        UVM中需要完成的工作项：
            1. 在reference model中补齐L1DTLB entry/MB/exception/credit/per-pipe token shadow，或在`mmu_l1dtlb_spec_sb.svh`内建立专用L1DTLB reference sub-model，并复用`mmu_ref_model.svh`的权限、PA、属性函数。
            2. 修改translation scoreboard，使L1DTLB fault replay、T0/T1重叠、STAMO pipe1 bypass、direct-map/PMP T1 access fault不再依赖宽泛waive，而是由明确token和exception shadow解释。
            3. 强化credit scoreboard或L1DTLB spec scoreboard，覆盖CREDIT_MAX、credit=0+return、return+fire守恒、request payload和每拍最多一个request。
            4. 强化L1DTLB spec scoreboard，加入MB分配/去重/full、install仲裁、WFI data hold、fault refill、exception replay、flush race、invalidate race、wakeup源和busy逐拍检查。
            5. 给所有新增检查增加可控开关和诊断打印：失败信息应包含cycle、pipe、IID、VA/VPN、expected/actual PA、fault类型、MB id、refill source和scenario id。
            6. 对PLRU exact victim保持white-box-only，不接入主translation pass/fail；若未来要精确检查replacement，必须先把victim选择和更新优先级补进spec。
