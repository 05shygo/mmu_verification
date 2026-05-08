ptw模块的详细工作原理：（页表大小份：1G\2M\4K）（虚拟地址39bit（vpn[26:0],offset[11:0]），vpn为27bit，vpn[2]为vpn[26:18]、vpn[1]为vpn[17:9]、vpn[0]为vpn[8:0];物理地址40bit（ppn[27:0],offset[11:0]），ppn为28bit，ppn[2]为ppn[27:18]、ppn[1]为ppn[17:9]、ppn[0]为ppn[8:0]，satp寄存器的值会提供第一级页表去ptw的基地址，即regs_ptw_satp_ppn[PPN_WIDTH-1:0]）
    1.pde cahe的工作：第一级和第二季pde cache都是默认16个entry。第一级pde cache的tag是vpn[2]，data是相应的ppn，第二级pde cache的tag是vpn[2]和vpn[1]，data是相应的ppn。每个L2tlb的请求进来时，都会先进入pde cache模块同时检查两级pde cache，如果命中，则选出相应的ppn，如果两级都命中，则认为是命中了第二级pde cache，因为第二级更靠近叶子页表。如果命中了第一级pde cache，则可以跳过twu中的第一级流水线（fst-pmp和fst-chk）;如果命中了第二级pde cache，则可以跳过twu中的第一和第二级流水线（fst-pmp和fst-chk、scd-pmp和scd-chk），并且携带选出的ppn，生成下一级页表的物理地址，进行后续处理。
    2.xbar_one_to_four的工作：将进过pde cache的请求分发到4个twu中的某一个，通过请求的vpn经过哈希hash决定分发的twu，以达到将请求尽可能平均的分配到4个twu的功能。
    3.twu中pmp类流水线的工作（每一级页表都有一个pmp流水线）：生成要访问的物理地址，并且将该物理地址发到pmp，pmp会放回flg，根据flg和请求的类型可以判断pmp检测是否提供，如果未提供会触发访问异常，如果通过，会发请求和请求的物理地址已经相关信号（twu_idx：可以标记该请求是哪个twu发送的，mbuf返回时可以返回到对应的twu；lvl:请求要拿到的页表数据的级数，可以根据该级数决定返回到哪一级chk类流水线，等信号）到mbuf。
    4.twu中chk类流水线的工作（每一级页表都有一个chk流水线）：拿到lsu返回的数据时，mbuf会将数据返回到相应的twu，对应级别的chk流水线，chk流水线会加内存页表是否触发页表异常，并且页表是否是叶子页表。
    5.在twu中的处理：每个twu每个时钟周期都可以接受一个请求（前提是twu可以接受的情况下）。重复的进行pmp流水线的处理、发请求到mbuf，然后发请求到lsu拿到相应级别的页表数据、进入chk流水线检查页表异常和叶子表项。有页表异常寄存器和访问异常寄存器和正常refill寄存器来缓存相应请求，然后再顶层进行仲裁返回到相应的位置。因为内存被分成8个区域，如果maee开启则直接使用页表数据中的属性，如果maee没开启则使用其在内存中其所在区域的默认属性配置，但是如果是大页表，则可能跨越8个区域之间的边界，占据两个区域，这时候无法判断使用这个区域的属性配置。所以如果maee开启则不需要考虑跨页检查，如果maee未开启并且是1G或2M页表则需要考虑跨页检查，如果是1G页表进入跨页检查，会将1G页表的首和尾地址发到sysmap模块，该模块会发返回这个地址是8个区域中的哪个，只有首尾地址都在同一个区域，才能证明他没跨越边界，这时候跨越正常回填了；如果他们不在同一个区域，则需要将1G页表降级为2M页表，ppn[1]也套用vpn[1]然后继续进行检查，如果未跨越，可以回填，如果跨越，则需要将2M页表降级为4K页表，ppn[0]也套用vpn[0],然后回填。
     6.mbuf的工作：接收各个twu的请求，进过仲裁后（itlb类型的请求优先），将请求更新进mbuf的entry中，mbuf有9个entry，8个给dtlb的请求，1个专门给itlb的请求，如果entry有效并且该entry的请求还没拿到lsu返回的数据，会根据发请求的指针，发送相应entry的物理地址（itlb的请求优先发）；lsu返回数据时会跟踪到相关的entry（通过mbuf_on去跟踪，因为mmu发请求到lsu拿数据是串行的，mmu发请求到lsu时会一直把请求有效信号拉高，并且请求的物理地址保持稳定，这是因为lsu与mmu的ptw是没有握手协议的，只有lsu返回数据有效信号，才会把mmu的请求有效信号拉低，如果mmu的ptw还有请求要发，则会继续把mmu的请求有效信号拉高，只是把物理地址换成下一个请求的物理地址，保持稳定），然后会检测要进入的该twu的该级chk流水线是否已经准备好，如果准备好，则发返回数据请求给twu，将数据返回给twu的chk流水线，如果没准备好，会把数据寄存到entry中的数据寄存器，等到准备好了才发返回数据请求给twu，将数据返回给twu的chk流水线。同时每次在拿到lsu返回的数据时，会检测是否满足更新进pde cache的条件（不是叶子表项并且不会触发页表异常），如果满足则把相应的vpn和ppn更新进pde cahe，根据lvl决定更新到哪一级pde cache。
     7.触发页表异常的处理：每个twu中的fst_chk、scd_chk、thd_chk流水线都会进行页表异常的检查，lsu在返回数据给mmu之后，都会进入chk类流水线进行页表异常检查，根据lsu返回的是哪一级页表的数据，来决定进入哪一级的chk流水线，如果在chkk类流水线检查发现触发了页表异常，会将该请求的类型和id（l1dtlb中mbuf的id）更新进页表异常寄存器，页表异常寄存器会发请求到顶层模块的仲裁器，对多个twu的请求进行仲裁，最总拿到仲裁的授权，将该页表异常上报到请求来源处，根据type决定上报到l1itlb还是l1dtlb，根据id决定上报到l1dtlb中mbuf的哪个entry。
     8.触发访问异常的处理：每个twu中的fst_pmp、scd_pmp、thd_pmp流水线都会进行pmp的检查，如果pmp检查未通过，会触发访问异常；同时如果lsu返回数据的时候出现了总线错误，也会触发访问异常。如果在pmp类流水线检查未通过或者lsu出现总线异常会触发了访问异常，会将该请求的类型和id（l1dtlb中mbuf的id）更新进访问异常寄存器，访问异常寄存器会发请求到顶层模块的仲裁器，对多个twu的请求进行仲裁，最总拿到仲裁的授权，将该页表异常上报到请求来源处，根据type决定上报到l1itlb还是l1dtlb，根据id决定上报到l1dtlb中mbuf的哪个entry。
    9.ptw ready信号：当xbar_one_to_four在分发请求到某个twu时，如果该twu暂时无法接受新请求，那么ptw就会拉低ready信号，不接受L2tlb的请求。避免请求被冲刷了。
    10.twu暂时无法接受新请求的情况：
      - twu屏蔽1-to-4 xbar模块发请求的情况：（防止请求冲突，数据被冲刷掉）（无法判断twu的落点在哪一级pmp）
        - 当pmp类流水线有wait信号时
        - Fst/ scd chk检查发现没有page fault和不是叶子表项，准备进入到下一级的PMP检查流水线时
    11.twu内部流水线停滞的情况：（都是为了防止冲刷掉其他请求，或者当前请求在该流水线的任务还未完成）
      - 1.fst_pmp_wait：
        - 当同时出现多个检查pmp的请求，fst_pmp的请求未被授权时
        - 当发出的写Mbuf的请求没有被Mbuf授权时
        - 当同时出现多个更新访问异常寄存器的请求，fst_pmp的请求未被授权时
      - 2.fst_chk_wait：
      - 当scd_pmp_wait拉高时，并且检查发现不是叶子表项时，防止覆盖掉scd_pmp的数据，fst_chk_wait拉高
      - 当发现是叶子表项并且maee开启，发出正常数据写回请求，fst_chk的请求未被授权时
      - 当同时出现多个更新页表异常寄存器的请求，fst_chk的请求未被授权时
      - 当发现是叶子表项并且maee未开启了，但是跨页处理不在空闲状态
    - - 3.scd_pmp_wait：
      - 当同时出现多个检查pmp的请求，scd_pmp的请求未被授权时
      - 当发出的写Mbuf的请求没有被Mbuf授权时
      - 当同时出现多个更新访问异常寄存器的请求，scd_pmp的请求未被授权时
    - - 4.scd_chk_wait：
      - 当thd_pmp_wait拉高时，并且检查发现不是叶子表项时，防止覆盖掉thd_pmp的数据，scd_chk_wait拉高
      - 当发现是叶子表项并且maee开启，发出正常数据写回请求，scd_chk的请求未被授权时
      - 当同时出现多个更新页表异常寄存器的请求，scd_chk的请求未被授权时
      - 当发现是叶子表项并且maee未开启了，但是跨页处理不在空闲状态
    - - 5.thd_pmp_wait：
      - 当同时出现多个检查pmp的请求，thd_pmp的请求未被授权时
      - 当发出的写Mbuf的请求没有被Mbuf授权时
      - 当同时出现多个更新访问异常寄存器的请求，thd_pmp的请求未被授权时
    - - 6.scd_chk_wait：
      - 当发现是叶子表项，同时出现其他回填的请求，thd_chk的请求未被授权时
      - 当同时出现多个更新页表异常寄存器的请求，thd_chk的请求未被授权时
    - 12.Abriter分布：
      - 1.TWU内部的abriter（itlb优先>高等级页表>低等级页表）
        - PMP检查的仲裁器（3个来源）（3级pmp流水线）
        - 正常数据写回refill的仲裁器（4个来源）（3级chk流水线和跨页检查状态机）
        - 进入跨页检查的仲裁器（2个来源）（第一级和第二级chk流水线）
        - 写入页表异常寄存器的仲裁器（3个来源）（3级chk流水线）
        - 写入访问异常寄存器的仲裁器（3个来源）（3级pmp流水线）
      - 2.TWU外部的abriter（对4个TWU的仲裁）（itlb优先>TWU索引低的优先）
        - 4个TWU发请求到mbuf，mbuf内容更新请求到entry的仲裁器（4个来源）（4个twu，在mbuf中）
        - 对4个TWU访问异常寄存器写回以及lsu触发总线错误的异常写回的仲裁器（5个来源）（4个twu和lsu总线异常触发的访问异常）
        - 对4个TWU页表异常寄存器写回的仲裁器（4个来源）（4个twu）
        - 对4个TWU正常数据写回的仲裁器（4个来源）（4个twu）
        - 对正常数据写回、访问异常写回、页表异常写回的仲裁器（3个来源）（保证每个时钟周期只返回一种结果）（访问异常写回>页表异常写回>正常数据写回）
    - 13.tlboper_ptw_abort对ptw的中断信号处理（因一致性/多核 shootdown、按 VA/ASID 或全 TLB 失效等需求，硬件要求立刻使一批或全部 TLB 项作废。这类请求与“正在进行的 miss 页表遍历”在时间上可能重叠；若此时仍允许本次 walk 的结果写入 jTLB，就会在已完成失效语义之后重新装入基于旧页表读出的映射，直接违背 shootdown 的顺序与可见性，造成陈旧翻译残留。因此在 LSU 已拉起 TLB 维护操作、但 tlboper 尚未稳定接管（tlb_lsu_oper && !tlb_lsu_oper_flop）的窗口内需要向 PTW 侧给出 tlboper_ptw_abort，从架构上强行切断“失效窗口内完成的 refill”与 TLB 的一致性假设，避免 invalidate 与 PTW 填表并发导致的错误可见性。）：
        - ptw中所有的请求都丢弃掉，pde cache的请求丢弃掉，4个twu的6级流水线都丢弃掉，mbuf的所有entry都无效化掉。回填请求也会被屏蔽，但是异常上报的请求不会。
        - 如果mbuf中有请求在lsu中处理，那么需要保持请求拉高，然后等待lsu返回数据有效信号，防止对后续请求造成影响。
        - 将所有请求冲刷掉并等待到lsu的返回信号后（只有之前发出请求到lsu中处理一半的情况下，才需要等待该信号），ptw ready才会拉高，然后让L2TLB的buffer重新发送所有的请求。
  


以下为各种情况下的流水线或状态机处理：（重要部分）
  1.以下为一个最终得到4k页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入thd_pmp流水线；T2n+8时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2n+8时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T3n+8时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T3n+9时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T3n+10时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache-》xbar_one_to_four-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》thd_pmp-》mbuf-》thd_chk-》refill）
  2.以下为一个最终得到2M页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T2n+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache-》xbar_one_to_four-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》refill）
   3.以下为一个最终得到1G页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache-》xbar_one_to_four-》fst_pmp-》mbuf-》fst_chk-》refill）
   4.以下为一个最总得到1G页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至2M）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查的第一个阶段，将1G块的第一个4K块发给sysmap，然后Tn+6时，进入1G跨页检查的第二个阶段，将1G块的最后一个4K块发给sysmap，并且做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为2M，并且ppn改变。Tn+7时，状态机进入2M跨页检查的第一个阶段，将2M块的第一个4K块发给sysmap，然后Tn+8时，进入2M跨页检查的第二个阶段，将2M块的最后一个4K块发给sysmap，并且做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，不会触发跨页，则检查结束，page size和ppn也不会再次改变了。
   5.以下为一个最总得到2M页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至4K）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入2M跨页检查的第一个阶段，将2M块的第一个4K块发给sysmap，然后Tn+6时，进入2M跨页检查的第二个阶段，将2M块的最后一个4K块发给sysmap，并且做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为4K，并且ppn改变。
   6.以下为一个最总得到1G页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至4K）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查的第一个阶段，将1G块的第一个4K块发给sysmap，然后Tn+6时，进入1G跨页检查的第二个阶段，将1G块的最后一个4K块发给sysmap，并且做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为2M，并且ppn改变。Tn+7时，状态机进入2M跨页检查的第一个阶段，将2M块的第一个4K块发给sysmap，然后Tn+8时，进入2M跨页检查的第二个阶段，将2M块的最后一个4K块发给sysmap，并且做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为4K，并且ppn改变。
   7.以下为一个在fst_chk流水线触发页表异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有页表异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表，但是同时也触发了页表异常，这时候会发请求更新到页表异常寄存器，Tn+5时，更新进页表异常寄存器，页表异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，可能是itlb，如果是dtlb会精确到其buffer的哪个entry（根据type和id）。（正常的流程是：pde cache-》xbar_one_to_four-》fst_pmp-》mbuf-》fst_chk-》上报）
   7.以下为一个在fst_pmp流水线触发访问异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有访问异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，这时候pmp检查未通过，触发了访问异常。T3时，更新进访问异常寄存器，访问异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，可能是itlb，如果是dtlb会精确到其buffer的哪个entry（根据type和id）。（正常的流程是：pde cache-》xbar_one_to_four-》fst_pmp-》上报）

## 待澄清问题

本节用于记录基于本 spec 审核和修改 UVM PTW 部分前需要明确的问题。后续回答这些问题后，应把答案补充回 spec 正文或本节对应条目下。

### 1. 基本架构与地址格式

1. 当前 PTW 是否只支持 Sv39、三级页表、4KB 基页？是否存在 Bare 模式、其他地址模式、或 satp.mode 非 Sv39 时 PTW 的预期行为？
答：当前ptw只支持Sv39，三级页表、4KB基页。存在bare模式和sv39地址模式。
2. 虚拟地址为 39 bit 时，输入到 PTW 的高位虚拟地址如果存在符号扩展或非 canonical 情况，应由 PTW 检查并报错，还是由 PTW 之前的模块保证不会出现？
答：输入到ptw的只有27bit的vpn，ptw输出ppn即可，offset部分是不会进入ptw的。不存在符号扩展或非 canonical 情况。所以是由 PTW 之前的模块保证不会出现。
3. 物理地址为 40 bit、PPN 为 28 bit 时，PTE 中 PPN 字段如果包含超出 40 bit 物理地址范围的信息，PTW 是否需要检查并触发页表异常？
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。PPN字段为28bit，所以不会出现超出 40 bit 物理地址范围的信息。
4. `regs_ptw_satp_ppn` 是否就是根页表物理页号？它在一次 walk 过程中如果发生变化，当前正在进行的请求使用旧值还是新值？
答：`regs_ptw_satp_ppn` 就是根页表物理页号。如果他在waclk过程中改变，通常是会有lsu发请求到tlboper，tlboper会发送abort信号到ptw，ptw执行中断信号处理。
5. spec 中 `vpn[2]`、`vpn[1]`、`vpn[0]` 的定义与 RISC-V Sv39 的 VPN[2:0] 是否完全一致？后续 UVM reference model 是否可以直接按 Sv39 语义建模？
答：spec 中 `vpn[2]`、`vpn[1]`、`vpn[0]` 的定义与 RISC-V Sv39 的 VPN[2:0] 完全一致。可以。

### 2. 请求输入与返回接口

6. L2TLB 发给 PTW 的请求字段完整包括哪些内容？除 vpn、type、id 之外，是否还有 ASID、VMID、privilege、access type、MXR/SUM/MPRV 等会影响检查或 refill 的字段？
答：L2TLB 发给 PTW 的请求字段完整包括vpn、type（PFU（arb_pfu_grant）固定为 3'b100；IUTLB（arb_iutlb_grant）为 3'b011；Load（arb_load_grant）为 3'b010；Store（arb_store_grant）为 3'b110）、id（l2tlb_ptw_id 是 mmu_l2tlb_mb 里 issue_eid 原样传出 的 6 bit 复合 ID，RTL 里固定拼成 {L2 段, L1 段}：高 3 bit [5:3] 表示 L2TLB Miss Buffer 槽位（新分配时是 dtlb_alloc_index，从缓冲就绪条目发出时是 entry_rdy_id），低 3 bit [2:0] 表示 L1 DTLB Miss Buffer 的 entry 编号（req_l1eid / entry_rdy_eid）；PTW 带着这 6 bit 走路，回填时再按同样划分把 L2 段对回本侧 MB、L1 段回到 L1 DTLB 对应 miss 项。）
7. `type` 的枚举值和含义是什么？它如何区分 itlb、dtlb load、dtlb store、dtlb atomic、或其他请求类型？
答：type（PFU（lsu端口2的预取端口）（arb_pfu_grant）固定为 3'b100；IUTLB（arb_iutlb_grant）为 3'b011；Load（arb_load_grant）为 3'b010；Store（arb_store_grant）为 3'b110）
8. L1DTLB mbuf 的 `id` 宽度、合法范围、复用规则是什么？同一个 id 是否可能在旧请求完成前被新请求复用？
答：id（l2tlb_ptw_id 是 mmu_l2tlb_mb 里 issue_eid 原样传出 的 6 bit 复合 ID，RTL 里固定拼成 {L2 段, L1 段}：高 3 bit [5:3] 表示 L2TLB Miss Buffer 槽位（新分配时是 dtlb_alloc_index，从缓冲就绪条目发出时是 entry_rdy_id），低 3 bit [2:0] 表示 L1 DTLB Miss Buffer 的 entry 编号（req_l1eid / entry_rdy_eid）；PTW 带着这 6 bit 走路，回填时再按同样划分把 L2 段对回本侧 MB、L1 段回到 L1 DTLB 对应 miss 项。）同一个 id 不可能在旧请求完成前被新请求复用。
9.  返回到 L1ITLB、L1DTLB、L2TLB 的正常 refill 字段完整包括哪些内容？例如 ppn、page size、权限位、属性位、异常位、id、type 是否都返回？
答：返回到 L1ITLB、L1DTLB、L2TLB 的正常 refill 字段完整包括ppn、flg、page size、vpn、asid（直接用当前进程的aisd，在satp寄存器存储着的asid）、global位、type、id。
10.  当访问异常、页表异常、正常 refill 对同一个原始请求同时或相邻周期产生时，最终只允许返回一种结果吗？优先级是否固定为访问异常高于页表异常高于正常 refill？
答：当访问异常、页表异常、正常 refill同时需要返回时，最终只允许返回一种结果。优先级固定为访问异常高于页表异常高于正常 refill。

### 3. PDE cache 行为

11. 第一级和第二级 PDE cache 的 entry 格式完整包含哪些字段？除了 valid、tag、ppn 之外，是否包含 ASID、global、权限、内存属性、替换信息？
答：不包含ASID、global、权限、内存属性。因为asid改变时pde cache会清空，这样就隐含了同一个asid的意思。替换信息每一级pde cache 有自己独立的plru算法模块来处理其替换。
12. PDE cache 是否按 ASID 或 satp 上下文隔离？如果 tag 只包含 vpn，切换地址空间时依靠什么机制避免旧 PDE cache 命中？
答：因为asid改变时pde cache会清空，这样就隐含了同一个asid的意思。
13. PDE cache 的替换策略是什么？16 个 entry 是全相联、直接映射还是组相联？命中和更新的仲裁规则是什么？
答：PDE cache 的替换策略是plru。16 个 entry是全相联，用寄存器堆搭建的。命中是用L2发来的请求附带的vpn对应部分跟pde cache的tag比较，如果相同则认为命中。（第一级pde cache用vpn[2]跟tag比较，第二级pde cache用vpn[2：1]跟tag比较）.没有仲裁规则，因为一个时钟周期最多接受一个L2tlb的请求，如果停滞了会不接受L2tlb的请求，这样不可能同时出现多个请求在查找pde cache，不需要仲裁。
14. 第一级 PDE cache 的 data 是哪一级非叶子 PTE 的 PPN？第二级 PDE cache 的 data 是哪一级非叶子 PTE 的 PPN？请明确 data 用于生成哪一级页表访问地址。
答：第一级 PDE cache 的 data 是第一级非叶子 PTE 的 PPN。第二级 PDE cache 的 data 是第二级非叶子 PTE 的 PPN。data都是用于生成下一级的页表访问地址。第一级 PDE cache 的 data用于生成第二级的页表访问地址。第二级 PDE cache 的 data用于生成第三级的页表访问地址。
15. 两级 PDE cache 同时命中时，选择第二级 PDE cache；这种情况下是否还需要校验第一级 PDE cache 与第二级 PDE cache 的一致性？
答：不需要。第二级 PDE cache更接着叶子页表。
16. PDE cache 命中后跳过对应 PMP 和 CHK 流水线。被跳过的非叶子 PTE 权限和合法性检查是否完全依赖当初填入 PDE cache 时已经完成？
答：是，更新进pde cache的页表都是通过pmp检查和页表异常检查的，只有通过了才可能会更新入pde cache中，所以cache中数据的时候不需要检查。
17. PDE cache 更新条件写为“不是叶子表项并且不会触发页表异常”。是否还要求该次访问没有访问异常、没有 abort、没有 flush、且对应上下文仍有效？
答：要求该次访问拿到的页表数据没有触发页表异常并且不是叶子表项。并且没有 abort、没有 flush、且对应上下文仍有效。
18. 当 `tlboper_ptw_abort` 或其他 TLB 维护操作发生时，PDE cache 是全清空还是只屏蔽当前请求？是否存在按 VA/ASID 精确失效 PDE cache 的行为？
答：PDE cache 是只屏蔽当前请求，并清空ptw的所有请求，等到可以继续接受请求时，让L2重新所有请求。不存在按 VA/ASID 精确失效 PDE cache 的行为。

### 4. TWU 选择与 ready/backpressure

19. xbar_one_to_four 的 hash 函数具体是什么？UVM scoreboard 是否需要精确预测请求进入哪个 TWU，还是只需验证功能结果？
答：ash 函数具体是
assign twu_hash[1:0] =
    PDE_xbar_vpn[1:0]   ^
    PDE_xbar_vpn[10:9]  ^
    PDE_xbar_vpn[19:18] ^
    PDE_xbar_vpn[26:25];
  UVM scoreboard 需要精确预测请求进入哪个 TWU。
20. 当目标 TWU 无法接受请求导致 PTW ready 拉低时，L2TLB 需要保持请求字段稳定吗？是否存在 valid/ready 握手语义？
答：存在valid/ready 握手语义，PTW ready 拉低时，L2tlb认为该请求未被ptw接受，所以会继续拉高该请求。
21. 如果多个 L2TLB 请求连续到达，PTW 每周期最多接受一个请求，还是 itlb/dtlb 可并行进入？
答：PTW 每周期最多接受一个请求。由L2TLB发请求。
22. TWU “每个时钟周期都可以接受一个请求”的前提条件完整是什么？是否只受第一级 pmp/chk 路径状态影响，还是也受 mbuf、异常寄存器、refill 寄存器影响？
答：TWU “每个时钟周期都可以接受一个请求”的前提条件完整是当前在pde cache的请求要进过one_to_four_xbar.sv模块分发到某个twu，如果该twu可以接受新请求，则可以让L2tlb的新请求进入ptw。twu不能接受请求的情况上面已经提到。

### 5. PMP 检查与访问异常

23. PMP 检查的输入物理地址是否为页表项所在地址，而不是最终翻译出的物理地址？三层 PMP 检查都只检查读取页表内存的权限吗？
答：PMP 检查的是页表项所在物理地址地址的ppn部分，会精确到一个4k块，不是最终翻译出的物理地址。三层 PMP 检查都只检查读取页表内存的权限。
24.  PMP 返回的 `flg` 每一位含义是什么？针对 itlb、dtlb load、dtlb store 等请求，访问异常判定条件分别是什么？
答：assign fst_pmp_deny = (fst_pmp_fetch_type && !pmp_mmu_flg[2]
                    || fst_pmp_load_type  && !pmp_mmu_flg[0]
                    || fst_pmp_store_type && !pmp_mmu_flg[1]
                    || fst_pmp_pref_type  && !pmp_mmu_flg[0])
                    // L-bit for M-Mode
                       && !(fst_pmp_cp0_mach_mode && !pmp_mmu_flg[3]);
    以此为例，相应type对应的flg拉低，则未通过pmp检查。还有一个特殊情况pmp_mmu_flg[3]，如果机器模式下没有 L-bit for M-Mode可以跳过pmp检查。
25.  页表 walk 读取 PTE 时使用的 PMP 访问类型是 load、fetch、还是与原始请求类型相关？
答：与原始请求类型相关。
26.  PMP 检查未通过和 LSU 总线错误都归类为访问异常。两者返回给 TLB 的错误编码是否相同？UVM 是否需要区分来源？
答：两者返回给 TLB 的错误编码都是访问异常。异常附带的id不是错误编码，只是返回时L1TLB和L2TLB的miss buffer的该请求entry位置。
27.  如果某一级 PMP 已触发访问异常，该请求后续是否立即停止，不再发 mbuf/lsu 请求，也不再可能产生页表异常？
答：发生访问异常该请求结束并且会上报这个异常给tlb，tlb会上报该异常到上游，最总由软件处理。
28.  多个 PMP 流水线同时请求 PMP 仲裁时，spec 写“itlb 优先 > 高等级页表 > 低等级页表”。“高等级页表”是指第一级页表优先，还是更接近叶子的第三级页表优先？
答：高等级页表是指第三级页表优先。

### 6. PTE 检查与页表异常

29. CHK 流水线执行的页表异常检查规则完整是什么？是否严格遵循 RISC-V Sv39 PTE 的 V/R/W/X/U/G/A/D/RSW/PPN 保留位规则？
答：// judge if page fault
// page fault when PTE not valid
// page fault when PTE write only
// page fault when not match R/W/X
// page fault when supv access user region and vise versa
// page fault when A/D bit violation
// page fault when fetch meets strong order
// page fault when third request no R/X
// page fault when huge page misalign以上为触发页表异常的情况，严格遵循 RISC-V Sv39 PTE 的 V/R/W/X/U/G/A/D/RSW/PPN 保留位规则？
30. 叶子 PTE 的判定规则是否为 R/X/W 任一可用即叶子，还是存在本设计特有规则？
答：叶子 PTE 的判定规则是R/X 任一可用即叶子，并且vld有效。
31. 非叶子 PTE 中如果 D/A/U/W/R/X 等权限位存在非法组合，应触发页表异常还是忽略？
答：触发页表异常。但 非叶子 PTE和叶子页表的页表异常检查不太一致，有些只有在叶子页表的时候才触发的页表异常。非叶子 PTE只有在只可写情况下或者在第三级页表还被判断是非叶子 PTE时才触发页表异常。
32. megapage/superpage 对齐检查规则是什么？例如 1G 页要求 PPN[1:0] 为 0，2M 页要求 PPN[0] 为 0；如果不对齐是否页表异常？
答：这个应该是页表1结构在分配的时候久已经对齐了，ptw在读过来的时候页一定是对齐的，没做这个的检查。
33. A/D 位如何处理？硬件是否会自动置位 A/D，还是 A/D 不满足时直接页表异常？
答：硬件不会自动置位 A/D，A/D 不满足时直接页表异常。
34. MXR、SUM、当前特权级、MPRV 等状态是否参与叶子 PTE 权限检查？如果参与，相关输入信号在哪里定义？
答：参与。这些相关输入信号是由cp0模块输入进mmu的。
35. instruction page fault、load page fault、store page fault 是否根据请求 type 分别返回？当前 spec 只写“页表异常”，是否需要区分具体异常类型？
答：是。会根据触发异常的请求类型，将异常上报到相应模块，比如itlb类型的异常上报给itlb，load和store上报给dtlb。不区别具体异常类型，页表异常不区分是哪一种具体的异常。
36. 第三级 `thd_chk` 中“该请求必定是叶子表项”的说法是否表示第三级非叶子 PTE 必定触发页表异常？
答：是。如果在第三级chk还被判断是非叶子pte，那么必定触发页表异常。

### 7. Mbuf 与 LSU 交互

37. mbuf 的 9 个 entry 中，8 个 DTLB entry 和 1 个 ITLB entry 的分配规则是什么？DTLB entry 如何选择空闲项或处理满的情况？
答：原始来源是lsu的会进入8 个 DTLB entry，原始来源是ifu的会进入1 个 ITLB entry（因为ifu是阻塞式结构，同一时间只可能有一个ifu请求在mmu处理）。DTLB entry 是通过指针的方式更新入8 个 DTLB entry，新请求更新进entry中，指针久左移一位。不可能出现溢出的情况，因为L2TLB的miss buffer也是8个entry给dtlb的，最多只有8个dtlb请求进入ptw。所以mbuf只可能填满，不可能溢出，不需要处理溢出的情况。
38. 当 itlb 和 dtlb 请求同时竞争 mbuf 写入时，是否一定 itlb 优先？如果 itlb 专用 entry 已满，新的 itlb 请求如何 backpressure？
答：是一定 itlb 优先。因为ifu是阻塞式结构，同一时间只可能有一个ifu请求在mmu处理。所以itlb专用 entry 已满时，不可能有新的 itlb 请求。
39. mbuf 向 LSU 发请求时，itlb 请求优先；如果 itlb 请求持续存在，dtlb 是否可能饥饿？是否有公平性或轮转机制？
答：itlb 请求不可能持续存在。因为ifu是阻塞式结构，同一时间只可能有一个ifu请求在mmu处理。所以总有其处理好的时候
40. LSU 接口没有 grant/ready，PTW 请求 valid 拉高直到 LSU data valid 返回。若 LSU 返回错误或数据无效周期，mbuf 如何匹配返回到具体 entry？
答：mbuf将entry中的请求发给lsu的那一时刻就会标记该entry的请求在lsu中处理，lsu返回的时候就返回到该entry。因为lsu是串行执行的，同一时间只可能处理一个请求，只有该请求处理完成才能发出下一个请求。
41. `mbuf_on` 的精确定义是什么？它如何跟踪当前正在 LSU 中处理的 entry？
答：mbuf将entry中的请求发给lsu的那一时刻就会标记该entry的请求在lsu中处理，即mbuf_on拉高。其拉高说明该entry的请求正在 LSU 中处理。lsu返回时也是根据该信号跟踪到该entry。
42. LSU 是否保证按请求顺序返回？是否允许多 outstanding？当前 spec 似乎描述为串行单 outstanding，请确认。
答：不允许多 outstanding。lsu是串行执行的，同一时间只可能处理一个请求，只有该请求处理完成才能发出下一个请求。是串行单 outstanding。
43. LSU 返回的数据宽度、PTE 对齐、端序、以及从返回数据中取 PTE 的规则是什么？
答：lsu返回的数据位宽是64bit，就是页表数据，全部64bit都是页表数据，不需要抽取。
44. 当 LSU 返回数据但目标 CHK 流水线不 ready，mbuf 将数据寄存在 entry 中。此 entry 在等待期间是否阻塞后续 LSU 请求发出？
答：此 entry 在等待期间不阻塞后续 LSU 请求发出。

### 8. 跨页属性检查与降级

45. `maee` 的完整含义是什么？它打开时“直接使用页表数据中的属性”具体使用 PTE 的哪些属性位？
答：MAEE 表示处理器支持一种 「页表项里携带寻址/内存类型相关属性」 的机制——即在 PTE 的高位（你们图里的 So、C、B 等）编码 强序、可缓存、可缓冲 等 内存属性，MMU 在地址翻译时可用这些位决定访问语义；是否启用由 sxstatus（或同类控制寄存器）里的 MAEE 控制位（文档里常见为 bit 21）决定。它打开时“直接使用页表数据中的属性”具体使用pte的最高几位为扩展属性（依次为 So、C、B、Sh、Sec）
46. `maee` 关闭时，8 个内存区域默认属性由哪个模块或寄存器提供？属性字段有哪些？
答：在这套 RTL 里，maee（cp0_mmu_maee）关掉时，不走页表里扩展 PMA（PTE 高位），而是由 ct_mmu_sysmap + sysmap.h 里写死的 8 段物理地址区间与默认属性 提供：根据当前访问的物理地址落在哪一段（用 SYSMAP_BASE_ADDR0～SYSMAP_BASE_ADDR7 做区间比较、再 casez 选中 SYSMAP_FLG0～SYSMAP_FLG7），组合出 sysmap_mmu_flg（5 位） 和 8 路 one-hot 的 sysmap_mmu_hit；这些宏不是 CSR 运行时寄存器，而是 编译期参数（头文件里定义）。这 5 位与 MEL/jTLB 里 PMA 域同一套路，对应 Sec（安全敏感）、Sh（可共享）、B（可缓冲）、C（可缓存）、So（强序/设备序） 等存储属性，用来在 MMU off / MAEE 关闭 时决定 非分页路径或 PTW refill 里填充到 jTLB 的 PMA 片段（例如 ct_mmu_ptw.v 里 ptw_ref_pma 在 !cp0_mmu_maee 时取 sysmap_mmu_flg3[4:0]），从而约束 可缓存性、顺序、共享与安全性 等与 LSU/总线、cache、一致性相关的行为，而不是从本次 walk 读回的 PTE 扩展域取数。
47. “1G 或 2M 页表可能跨越 8 个区域边界”的边界检查，是检查最终物理页覆盖范围 `[base, end]` 是否落在同一个 sysmap 区域吗？
答：是。
48. 1G 页跨页检查时，首地址和尾地址如何计算？尾地址是页内最后一个 byte 地址，还是下一页起始地址减 1？
答：首地址是用1G页表的ppn[2]和全是1的ppn[1:0]，也就是1G块中的第一个4K块。尾地址是用1G页表的ppn[2]和全是0的ppn[1:0]，也就是1G块中的最后一个4K块。offset部分不考虑，因为内存地址划分的时候就是按4k为最小块的。
49. 1G 降级为 2M 时“ppn[1] 套用 vpn[1]”的精确计算公式是什么？是否表示最终 PPN = `{pte.ppn[2], vpn[1], pte.ppn[0]}` 或其他组合？
答：按道理来说1G页表的ppn[1]是全0，因为物理地址对齐，套用vpn[1]，则ppn[1]有数值了，物理地址变成2M对齐了。是表示最终 PPN = `{pte.ppn[2], vpn[1], pte.ppn[0]}`
50. 2M 降级为 4K 时“ppn[0] 套用 vpn[0]”的精确计算公式是什么？
答：按道理来说2M页表的ppn[0]是全0，因为物理地址对齐，套用vpn[0]，则ppn[0]有数值了，物理地址变成4K对齐了。是表示最终 PPN = `{pte.ppn[2], pte.ppn[1],vpn[0]}`.
51.  降级后的 2M 或 4K refill 使用的权限、属性、A/D/G/U 等字段来自原始大页叶子 PTE，还是需要重新访问下一级页表？
答：来自原始大页叶子 PTE。
52.  如果 1G 页跨区域后降级到 2M，2M 仍跨区域再降级到 4K，这整个过程是否不再访问内存，只在当前叶子 PTE 基础上改写 PPN 和 page size？
答：不再访问内存。只在当前叶子 PTE 基础上改写 PPN 和 page size。
53.  如果降级后的 4K 仍然跨 sysmap 区域边界，理论上不会发生；如果 sysmap 配置异常导致发生，应如何处理？
答：4K不可能跨越 sysmap 区域边界，因为划分的时候最小块就是4k。不考虑sysmap 配置异常的问题。硬件不考虑，这个因为是软件的处理。
54.  跨页检查状态机与正常 refill 仲裁失败时如何保持请求？是否可能被 abort 屏蔽？
答：因为refill是会更新到twu中的refill寄存器的，会寄存请求和需要refill的数据。只有refill请求被授权了，真正被refill了才会拉低寄存器的有效位。

### 9. 异常寄存器、refill 寄存器与仲裁

55. 每个 TWU 的页表异常寄存器、访问异常寄存器、正常 refill 寄存器各有几项？如果已有有效请求未被顶层仲裁接受，新异常或 refill 到来时如何 backpressure？
答:各有一组寄存器。会阻塞该流水线，拉高等待信号，直到被更新入寄存器。比如chk发refill请求，如果未更新入寄存器，会拉高该流水线的wait信号。
56. 顶层对 4 个 TWU 的异常和 refill 仲裁规则中，itlb 优先和 TWU index 低优先如何同时应用？是先按 itlb/dtlb 分类再按 TWU index，还是每个请求有统一优先级编码？
答：先按 itlb/dtlb 分类再按 TWU index，不过是同一个时钟周期完成的，在有itlb时，选择该请求上报，如果没有itlb，则按TWU index。
57. 访问异常写回、页表异常写回、正常 refill 写回三者的顶层优先级为访问异常 > 页表异常 > 正常 refill。若低优先级请求长期被高优先级请求压制，是否有防饥饿机制？
答：不太可能，因为写回只需要一个时钟周期，而请求处理需要多个时钟周期，而且最多只有9个请求在ptw中（L2TLB miss buffer的entry数量限制）。
58. 异常上报是否也需要返回原始 id 和 type？对 itlb 请求没有 L1DTLB mbuf id 时 id 字段如何处理？
答：异常上报也需要返回原始 id 和 type。对 itlb 请求没有 L1DTLB mbuf id 时 id 字段不会被使用。虽然会返回，但是不会使用。
59. `tlboper_ptw_abort` 期间“回填请求被屏蔽，但是异常上报请求不会”。这里异常上报包括 abort 前已经形成的异常寄存器，还是 abort 期间新形成的 LSU bus error 也会上报？
答：只有abort到来的那一个时钟周期，正在上报的异常才可以上报。如果twu0和twu1都出现访问异常，仲裁器给twu0授权，这时候来了abort，正在上报的twu0的异常可以上报，但是twu1的异常因为没被授权，会被冲刷掉。等L2TLB重新发这个请求然后触发异常后再上报。

### 10. Abort/Flush/一致性语义

60. `tlboper_ptw_abort` 的有效周期和握手语义是什么？它是单周期脉冲还是保持到 PTW 完成 flush？
答：tlboper_ptw_abort就是lsu发来tlboper请求的那一个时钟周期，是单周期脉冲。
61. abort 发生时，已经在 pmp/chk 流水线、mbuf entry、PDE cache lookup、refill 寄存器中的请求分别如何处理？请明确哪些清 valid，哪些只是屏蔽输出。
答：全部清 valid。
62. abort 发生时，如果 LSU 中已有未完成请求，spec 要求保持 LSU 请求拉高直到返回。返回后该数据是否必须丢弃且不能更新 PDE cache、不能进入 CHK、不能产生 refill？
答：是的，返回后该数据是否必须丢弃且不能更新 PDE cache、不能进入 CHK、不能产生 refill。
63. abort 期间异常上报不屏蔽。若 abort 的目标是维护 TLB 一致性，为什么异常仍需上报？这是架构要求还是为了避免请求源挂起？
答：可以从两层分开看，不必把「TLB 一致性 abort」和「异常是否上报」绑成一件事。
语义上（偏架构）：tlboper_ptw_abort 在做的事是：本次 miss 的 refill 不能再当成合法映射写进 TLB。它并不否定页表遍历过程中已经暴露出来的事实：例如 PTE 访存总线出错、PMP 拒绝、页表项非法导致的 page fault 等。这些属于「这次访问在架构上该不该完成、不能完成又该怎么告知软件」的问题。RISC‑V 这类模型里，缺页 / 访问错应对 faulting 指令保持精确、可见；若仅仅因为发生了 shootdown 就把 walk 里已经发现的 fault 吞掉，会变成「指令既不完成也不异常」，与特权规范里的精确异常语义不一致。
实现与活性（偏避免挂死）：发起 PTW 的那条 load/store/取指仍在等 miss 路径收尾：要么 refill 成功（此处可被 abort 屏蔽），要么 报 access fault / page fault，要么至少要有确定的 refill 完成/故障完成 握手。也就是说 挡住的是「带数据的合法 refill」，不是「故障完成」。若故障也被屏蔽，请求源可能长期得不到 异常注入或明确完成，从系统角度更容易出现 逻辑挂起或不可诊断状态。
一句话：abort 针对的是 「失效窗口里别装进过时翻译」；**异常上报针对的是 「这次页表访问本身是否合法、能否完成」，二者正交。既有 架构上精确异常 的要求，也有 miss 路径必须收尾、避免请求挂死 的工程动机；在本设计中体现为 只屏蔽成功 refill 数据有效，而不笼统屏蔽 fault 完成路径。
64.  abort 完成、PTW ready 重新拉高后，L2TLB buffer 会重新发送所有请求。PTW 如何保证旧请求不会和重发请求重复返回？
答：abort之后，现有ptw不会有任何请求可以返回（如果abort同一时钟周期有异常返回，那么会让L2 的buffer中该请求所在的entry完成，这样该请求就不会再次发送了），因此重发请求不会是第二次返回。
65.  除 `tlboper_ptw_abort` 外，是否还有 reset、sfence、satp 写入、TLB invalidate 等其他 flush/abort 来源？
答：没有。

### 11. 时序、流水线与验证边界

66. 文中的 T0/T1/T2 示例是否是固定流水级时序，还是只表达逻辑顺序？UVM scoreboard 是否需要 cycle-accurate 检查？
答：是4k页表再pde cahce没命中的时序，不过T0和T1是每个请求都要经历的，都会再T0请求信号拉高，然后T1查看pde cache。
67. pde cache lookup、xbar 分发、进入 fst_pmp 是三个连续周期还是可能同周期组合完成？
答：三个连续周期。
68. PMP 返回 `flg` 是组合返回还是下一周期返回？PMP 仲裁失败时流水线 valid/data 如何保持？
答：组合返回。如果有请求没拿到pmp仲裁的授权会拉高wait信号，让该请求在流水线中保留。
69. mbuf 写入 entry 和向 LSU 发出请求是否可能同周期完成？
答：比如T0拉高写入entry的updata信号，T1完成写入，然后T1可以向lsu发请求了。因此应该可以认为是的。
70.  CHK 流水线从 mbuf 接收 LSU 数据后，页表异常检查、叶子判断、发往下一级 PMP 或 refill 是否固定一周期完成？
答：一个时钟周期完成
71.  对于 UVM reference model，哪些行为必须精确到周期，哪些只需要事务级功能正确？
答：你执行判断清楚，后续让我审查。

### 12. 文档一致性与术语

72. 文档中 “pde cahe/cache”、“第二季/第二级”、“进过/经过”、“最总/最终”、“chkk/chk”、“abriter/arbiter”等术语是否需要统一，以便后续 AI 审核时减少误解？
答：需要统一，是我打错了。
73. 第 11 节内部编号最后一项写成“6.scd_chk_wait”，但描述内容是 `thd_chk`，是否应改为 `thd_chk_wait`？
答：是。
74. 第 10 节和第 11 节的列表缩进混杂，哪些条目属于“twu 屏蔽 xbar 请求”，哪些属于“twu 内部流水线停滞”，是否需要重排？
答：已经重排。
75. `fst/scd/thd` 分别对应第一级、第二级、第三级页表；“高等级页表/低等级页表”在仲裁语境中建议明确为 `fst/scd/thd` 优先级，是否同意？
答：同意
76. 后续作为 UVM 审核依据时，是否希望本 spec 增加一张“输入字段、输出字段、内部状态、异常类型、优先级”的表格，作为 scoreboard/reference model 的检查清单？
答：是。

## 第二轮待澄清问题

本轮问题基于已补充的答案和完整流程继续整理，重点是把 spec 收敛成后续可执行的 UVM reference model/scoreboard 规则。

### 13. 模式、上下文采样与全局状态

77. 前文回答“当前 PTW 只支持 Sv39”，同时又说“存在 bare 模式和 sv39 地址模式”。bare 模式下是否保证不会向 PTW 发起 walk 请求？如果 bare 模式下仍有请求进入 PTW，预期行为是丢弃、直接返回、报错，还是由上游保证不发生？
答：bare 模式下保证不会向 PTW 发起 walk 请求。由上游保证不发生。因为这时候的ppn就等于vpn。相当于是mmu不开启。
78. `regs_ptw_satp_ppn`、satp.asid、MXR、SUM、当前特权级、MPRV、MAEE 等 CP0/CSR 状态是在请求被 PTW accept 的周期采样并随请求携带，还是在各级 PMP/CHK/refill 使用时读取当前值？
答：这些状态都是直接连接到ptw模块的，ptw时时接收，但只有在像PMP/CHK/refill 才会使用。
79. 如果一次 walk 过程中 satp.ppn 改变但 ASID 不变，是否一定会产生 `tlboper_ptw_abort`？如果没有 abort，当前 walk 和 PDE cache 应按旧 satp.ppn 还是新 satp.ppn 行为？
答：一次 walk 途中如果只改 SATP 里的 PPN、ASID 不变，并不会因此必然产生 tlboper_ptw_abort，因为在这条实现里 abort 只跟 LSU 上来的 TLB shootdown（tlb_lsu_oper / lsu_mmu_tlb_*_inv）有关，CSR 写 SATP 并不驱动这条路径；有没有 abort 完全取决于这段时间里是否另外来了 coherence 之类的 invalidate。若没有 abort，PTW 也不会在硬件里替你“锁定 walk 开始时的那根指针”：ptw_fst_addr 组合用的是当前的 regs_ptw_satp_ppn，所以一旦 SATP 寄存器已经写成新根页号，之后凡是再走第一级页表地址公式（例如重新从根读）都会按新 PPN；而已经发往 LSU、尚未返回的根级访问仍然对着当初锁在 ptw_req_addr 上的旧物理地址，返回前后可能与已经更新的 SATP 语义交错；第二、三级地址主要来自上一级 PTE 里的 PPN，跟根指针无直接关系。硬件上可能发生；软件上若要正确，通常就用 SFENCE（及相关失效）把它收紧掉，而不是依赖「改 SATP 但不 fence」这种交叉。
80. 如果一次 walk 过程中 MXR/SUM/privilege/MPRV/MAEE 变化，PTW 是否会被 abort/flush？若不会，reference model 应按请求进入时的状态还是检查发生时的状态判断权限和属性？
答：不会。reference model 应按检查发生时的状态判断权限和属性。

### 14. 请求类型、PFU 与返回目标

81. PFU 类型 `3'b100` 的语义需要进一步明确：PFU walk 成功后会 refill 哪些结构？只 refill L2TLB，还是也可能 refill L1DTLB/L1ITLB？
答：只 refill L2TLB。
82. PFU 类型如果在 PMP 或 PTE 检查中触发访问异常/页表异常，是否会上报异常？还是作为预取请求静默丢弃并不产生架构可见异常？
答：会上报异常。
83. type 目前列出 PFU/IUTLB/Load/Store 四类。是否存在 atomic/amo 请求类型？如果没有，store 类型是否同时覆盖普通 store 和 atomic 的 D 位/PMP store 权限检查？
答：不存在 atomic/amo 请求类型。store 类型同时覆盖普通 store 和 atomic 的 D 位/PMP store 权限检查。
84. 对 IUTLB 请求，返回接口中的 `id` 字段虽然不会被使用，但其值是否有固定来源或固定填充值？scoreboard 是否应忽略 IUTLB 返回的 id？
答：固定为0.scoreboard 应忽略 IUTLB 返回的 id。
85. 正常 refill 字段中的 `flg` 具体位定义是什么？它是否同时包含 R/W/X/U/G/A/D、PMA 属性、strong order、cacheable、bufferable 等信息，还是这些字段分开返回？
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。flg就是最高几位为扩展属性和标准权限与状态位 D、A、G、U、X、W、R、V。
86.  `page size` 的输出编码是什么？例如 1G/2M/4K 分别用几 bit、什么取值表示？
答：1G是3’100，2M是010，4K是001。
87.  正常 refill 中的 ASID 写为“直接用当前 satp 中的 ASID”。这里的“当前”是请求进入 PTW 时的 ASID，还是 refill 返回当拍的 ASID？
答：refill 返回当拍的 ASID。

### 15. PTE 位级规则

88. 请给出 PTE 64 bit 的完整位定义表，包括 V/R/W/X/U/G/A/D/RSW、PPN[2:0]、保留位、以及 MAEE 扩展属性 So/C/B/Sh/Sec 的精确 bit 范围。
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。
89.  第 29 题回答列出 “huge page misalign” 会触发 page fault，但第 32 题回答说硬件没做对齐检查。请确认 1G 页 PPN[1:0] 非 0、2M 页 PPN[0] 非 0 时，PTW 是否实际触发页表异常？
答：会触发页表异常。32题的回答错误。在页表异常检查的时候会检查1G 页 PPN[1:0] 是否为 0、2M 页 PPN[0] 是否为 0 ，如果不是，则会触发页表异常。
90.  PTE 高位保留位非 0 时是否触发页表异常？MAEE 开启和关闭时，扩展属性位之外的保留位处理是否一致？
答：PTE 高位保留位必定为0，不做这方面的检查。一致。
91.  MAEE 关闭时，PTE 中 So/C/B/Sh/Sec 扩展属性位如果非 0，PTW 是忽略这些位、触发页表异常，还是仍保留到 refill 中但 PMA 使用 sysmap？
答：忽略这些位。
92.   “PTE write only” 的精确定义是否为 `W=1 && R=0`，不管 X 是 0 还是 1 都触发页表异常？
答：                     !(ptw_flg[1] || cp0_mmu_mxr && ptw_flg[3]) 
                        && ptw_flg[2]         // write only
      如果mxr拉高并且X是1，那么可以跳过只读的检查，否则W=1 && R=0就会触发页表异常。
93.非叶子 PTE 的合法性需要精确化：除 `V=1 && R=0 && W=0 && X=0` 之外，U/G/A/D/RSW/PPN/扩展属性哪些位会被检查，哪些位会被忽略？
答：只需检查只读情况，如上个问题所述。还需检查vld为低，如果页表vld为低也会触发页表异常。还需检查第三级页表，如果第三级页表的数据检查出是非叶子pte，也会触发页表异常。因为sv39中第三级页表已经是最后一级，正常情况下必定是叶子页表。
94.   叶子 PTE 权限检查请给出布尔规则：fetch/load/store/PFU 分别如何使用 R/W/X/U、MXR、SUM、privilege、MPRV、A/D、So 位决定 page fault？
答：assign ptw_page_flt = ((!ptw_flg[0]                       // not valid
                   ||  !(ptw_flg[1] || cp0_mmu_mxr && ptw_flg[3]) 
                        && ptw_flg[2]         // write only
                   ||  (!ptw_flg[1] && ptw_load_type     // match R
                       && !(cp0_mmu_mxr && ptw_flg[3])  
                   || !ptw_flg[2] && ptw_store_type     // match W
                   || !ptw_flg[3] && ptw_fetch_type     // match X
                   ||  ptw_flg[4] && cp0_supv_mode && !cp0_mmu_sum // S->U
                   || !ptw_flg[4] && cp0_user_mode      // U->S
                   || !ptw_flg[5]                       // A bit volation
                   || !ptw_flg[6] && ptw_store_type     // D bit volation
//                   ||  ptw_flg[13] && ptw_fetch_type    // fetch so
                   ||  ptw_hit_1g && lsu_data_flop[27:10] != 18'b0 // 1g align
                   ||  ptw_hit_2m && lsu_data_flop[18:10] != 9'b0  // 2m align
                     ) && ptw_leaf_vld)
                   || !ptw_flg[1] && !ptw_flg[3]        // thd req no R/X
                       && ptw_chk_thd);如上代码是完整的检查，部分哪一级流水线的检查。
95.   A/D 位规则是否为 fetch/load/PFU 要求 A=1，store 要求 A=1 且 D=1？IUTLB fetch 是否也要求 A=1？
答：fetch要求A=1,store要求W=1和D=1，load要求A=1（在mxr有效的情况下）
96.   “fetch meets strong order” 触发 page fault 的规则需要明确：是 MAEE 开启时 PTE.So=1 且请求 type 为 IUTLB/fetch 触发，还是 MAEE 关闭时 sysmap.So=1 也会触发？
答：mmu中不做该检查，不需要考虑。（可能是ifu内部的检查）

### 16. PDE cache 精确行为

97. PDE cache 在 ASID 改变时会清空。请明确清空触发信号：是 satp.asid 改变、satp 任意字段改变、tlboper、reset，还是上游某个 flush 信号？
答：satp 任意字段改变。
98. `tlboper_ptw_abort` 发生时，PDE cache 是保持原有内容，只屏蔽当前 lookup/update 请求，对吗？如果页表内容被软件修改并通过 tlboper 失效 TLB，保留旧 PDE cache 是否是设计预期？
答：不对。现在应该是得tlboper_ptw_abort时也无效化所有的pde cache。
99.  PDE cache 的 PLRU 在命中时是否更新？在写入新 entry 时，如果存在 invalid entry，优先使用 invalid entry 还是仍按 PLRU victim？
答：命中时更新，写入时也更新。存在invalid entry说明satp的值修改了，优先invalid entry。
100. PDE cache lookup 与 PDE cache update 若同周期发生，读写同一个 entry 或同一个 tag 时的预期行为是什么？lookup 看旧值还是新值？
答：DE cache lookup 与 PDE cache update 若同周期发生，这个新的数据在下一个时钟周期才会真正更新进entry中，所以这个时钟周期如果PDE cache lookup可以读出数据，但是下一个时钟周期tag就改变了，因为新的写入了。
101. PDE cache 更新的 PPN 来自非叶子 PTE。若该非叶子 PTE 的 PPN 指向的下一级页表地址 PMP 原本通过，但后续 PMP 配置变化，PDE cache 命中后会跳过被缓存级别的 PMP 检查；这是设计预期吗？是否依赖 PMP 变化时清空 PDE cache？
答：

### 17. Mbuf/LSU 与异常返回

102. mbuf entry 的释放时机是什么？LSU 返回数据时释放，数据成功送入 CHK 流水线时释放，还是该级 CHK 处理完成后释放？
答
103. DTLB mbuf 分配指针“左移一位”时，如果指向的 entry 仍 valid 但其他 entry 空闲，是否会跳过 valid entry 寻找空闲项，还是依赖上游保证不会发生？
104. LSU 返回 bus error 时，请求是否不进入 CHK 流水线，而是直接形成访问异常？该 mbuf entry 是否同拍释放？
105. LSU 返回 bus error 与 `tlboper_ptw_abort` 同周期时，该访问异常是否属于“abort 当拍已经获得仲裁的异常可以上报”的范畴，还是 bus error 返回会被丢弃？
106. 当 LSU 返回数据但目标 CHK 不 ready，entry 保存数据且不阻塞其他 LSU 请求。若随后发生 abort，已保存但未送入 CHK 的数据是否直接清 valid 并丢弃？

### 18. 跨页检查与 sysmap

107. 第 48 题回答中“首地址用 ppn[1:0] 全 1、尾地址用 ppn[1:0] 全 0”的表述看起来与“第一个/最后一个 4K 块”相反。请确认 1G/2M 跨页检查的 first/last 物理块 PPN 精确计算公式。
108. 1G 降级到 2M 的最终 PPN 是否应为 `{pte.ppn[2], vpn[1], 9'b0}`？当前回答 `{pte.ppn[2], vpn[1], pte.ppn[0]}` 在 PPN[0] 非 0 时会产生不同结果，请确认是否依赖 PPN[0] 一定为 0。
109. 2M 降级到 4K 的最终 PPN 是否为 `{pte.ppn[2], pte.ppn[1], vpn[0]}`；如果原 2M PTE 的 PPN[0] 非 0 且硬件不做对齐检查，是否仍完全覆盖为 vpn[0]？
110. sysmap 如果没有命中任何区域，或者异常地命中多个区域，PTW 如何处理？是否触发访问异常、页表异常、使用默认属性，还是这种配置不考虑？
111. MAEE 关闭且 4K 叶子 PTE 不需要跨页降级时，是否仍需要访问 sysmap 取得 PMA 属性用于 refill？如果需要，请补充 4K 正常 refill 的 sysmap 查询时序。
112. MAEE 关闭且 1G/2M 大页首尾落在同一个 sysmap 区域时，refill 的 PMA 属性取首地址、尾地址、还是两者相同后任取一个？
113. 跨页检查状态机最终确定不跨页或完成降级后，进入 refill 寄存器和顶层仲裁的完整时序还没有写完。请补充从跨页检查结束到 refill 返回的后续周期。

### 19. 仲裁优先级与 cycle 检查边界

114. TWU 内部“itlb 优先 > 高等级页表 > 低等级页表”中，高等级已确认是第三级优先。请明确各内部仲裁器的完整顺序是否都是 `itlb` 优先，然后 `thd > scd > fst`。
115. 正常 refill 仲裁器有 4 个来源：fst/scd/thd CHK 和跨页检查状态机。跨页检查状态机相对 thd/scd/fst 的优先级是什么？
116. 顶层访问异常仲裁器有 5 个来源：4 个 TWU 和 LSU bus error。LSU bus error 相对 4 个 TWU 访问异常寄存器的优先级是什么？
117. 如果同一个原始请求理论上可能在同周期出现 bus error 访问异常和 CHK 页表异常，是否访问异常一定覆盖页表异常？还是这种组合在结构上不会发生？
118. UVM scoreboard 是否需要检查 exact cycle，例如 T0/T1/T2 和每一级固定一拍；还是只要求在有限延迟内功能结果正确，cycle-accurate 留给 assertion/monitor 检查？

### 20. 建议补充的完整处理过程

119. 请补充“第一级 PDE cache 命中，最终得到 4K/2M 页”的完整流程，明确从 PDE cache 命中后进入哪一级 PMP、如何生成物理地址、是否更新第二级 PDE cache。
120. 请补充“第二级 PDE cache 命中，最终得到 4K 页”的完整流程，明确跳过 fst/scd 后如何进入 thd_pmp/thd_chk。
121. 请补充“LSU 返回 bus error 触发访问异常”的完整流程，包括 mbuf entry、访问异常寄存器、顶层仲裁和返回源的处理。
122. 请补充“abort 到来时 LSU 中有 outstanding 请求”的完整流程，包括 abort 当拍清哪些 valid、PTW ready 何时拉低/拉高、LSU 返回后如何丢弃数据、L2TLB 何时重发。
123. 请补充“maee 关闭但不需要降级的大页 refill”完整流程，即 1G/2M 首尾 sysmap 命中同一区域后如何选择 PMA、写入 refill 寄存器并返回。
