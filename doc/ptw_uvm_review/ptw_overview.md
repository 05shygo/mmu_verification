ptw模块的详细工作原理：（页表大小份：1G\2M\4K）（虚拟地址39bit（vpn[26:0],offset[11:0]），vpn为27bit，vpn[2]为vpn[26:18]、vpn[1]为vpn[17:9]、vpn[0]为vpn[8:0];物理地址40bit（ppn[27:0],offset[11:0]），ppn为28bit，ppn[2]为ppn[27:18]、ppn[1]为ppn[17:9]、ppn[0]为ppn[8:0]，satp寄存器的值会提供第一级页表去ptw的基地址，即regs_ptw_satp_ppn[PPN_WIDTH-1:0]）
    1.pde cahe的工作：第一级和第二季pde cache都是默认16个entry。第一级pde cache的tag是vpn[2]，data是相应的ppn，第二级pde cache的tag是vpn[2]和vpn[1]，data是相应的ppn。每个L2tlb的请求进来时，都会先进入pde cache模块同时检查两级pde cache，并且检查所有的entry，如果命中了第一级pde cache的某个entry，那么认为命中第一级pde cache，如果命中了第二级pde cache的某个entry，那么认为命中第二级pde cache，如果命中，则选出命中的entry中相应的ppn，如果两级都命中，则认为是命中了第二级pde cache，因为第二级更靠近叶子页表。如果命中了第一级pde cache，则可以跳过twu中的第一级流水线（fst-pmp和fst-chk），并且携带选出的ppn，生成下一级页表的物理地址，进行后续处理;如果命中了第二级pde cache，则可以跳过twu中的第一和第二级流水线（fst-pmp和fst-chk、scd-pmp和scd-chk），并且携带选出的ppn，生成下一级页表的物理地址，进行后续处理。
    2.xbar_one_to_four的工作：将进过pde cache的请求分发到4个twu中的某一个，通过请求的vpn经过哈希hash决定分发的twu，以达到将请求尽可能平均的分配到4个twu的功能。当xbar_one_to_four准备将请求发射到某个twu，但是该twu暂时无法接收新请求时，那么会拉低ptw ready，ptw拒绝接收来自L2TLB的新请求。避免冲刷掉该请求。
    3.twu中pmp类流水线的工作（每一级页表都有一个pmp流水线）：生成要访问的物理地址，并且将该物理地址发到pmp，pmp会放回flg，根据flg和请求的类型可以判断pmp检测是否提供，如果未提供会触发访问异常（fetch类型请求需要保证pmp_mmu_flg[2]为低，load类型请求需要保证pmp_mmu_flg[0]为低，store类型请求需要保证pmp_mmu_flg[1]为低，pfu类型请求需要保证pmp_mmu_flg[0]为低，如果是机器模式，并且pmp_mmu_flg[3]（L-bit for M-Mode）为低，则跨页跳过pmp检查），如果通过，会发请求和请求的物理地址padder以及相关信号vpn、type、id（这三个请求必须一直携带）、twu_idx、lvl（twu_idx：可以标记该请求是哪个twu发送的，mbuf返回时可以返回到对应的twu；lvl:请求要拿到的页表数据的级数，可以根据该级数决定返回到哪一级chk类流水线）到mbuf。
    4.twu中chk类流水线的工作（每一级页表都有一个chk流水线）：拿到lsu返回的数据时，mbuf会将数据返回到相应的twu，对应级别的chk流水线（根据twu_idx、lvl），chk流水线会进行检查，检查页表是否触发页表异常，并且检查页表是否是叶子页表。如果未触发页表异常，并且检查发现是叶子页表，那么会发出更新refill寄存器的请求。如果触发页表异常，会发出更新页表异常寄存器的请求，如果未触发页表异常并且不是叶子页表，那么会进入下一级的pmp流水线。
    5.在twu中的处理：每个twu每个时钟周期都可以接受一个请求（前提是twu可以接受的情况下）。重复的进行pmp流水线的处理、发请求到mbuf，然后发请求到lsu拿到相应级别的页表数据、进入chk流水线检查页表异常和叶子表项。有页表异常寄存器和访问异常寄存器和正常refill寄存器来缓存相应请求，然后再顶层进行仲裁返回到相应的位置。因为内存被分成8个区域，如果maee开启则直接使用页表数据中的属性，如果maee没开启则使用其在内存中其所在区域的默认属性配置，但是如果是大页表，则可能跨越8个区域之间的边界，占据两个区域，这时候无法判断使用这个区域的属性配置。所以如果maee开启则不需要考虑跨页检查，如果maee未开启并且是1G或2M页表则需要考虑跨页检查，如果是1G页表进入跨页检查，会将1G页表的首和尾地址发到sysmap模块，该模块会发返回这个地址是8个区域中的哪个，只有首尾地址都在同一个区域，才能证明他没跨越边界，这时候跨越正常回填了；如果他们不在同一个区域，则需要将1G页表降级为2M页表，ppn[1]也套用vpn[1]然后继续进行检查，如果未跨越，可以回填，如果跨越，则需要将2M页表降级为4K页表，ppn[0]也套用vpn[0],然后回填。
     6.mbuf的工作：接收各个twu的请求，进过仲裁后（itlb类型的请求优先），将请求更新进mbuf的entry中，mbuf有9个entry，8个给dtlb的请求，1个专门给itlb的请求，如果entry有效并且该entry的请求还没拿到lsu返回的数据，会根据发请求的指针，发送相应entry的物理地址（itlb的请求优先发）；lsu返回数据时会跟踪到相关的entry（通过mbuf_on去跟踪，因为mmu发请求到lsu拿数据是串行的，mmu发请求到lsu时会一直把请求有效信号拉高，并且请求的物理地址保持稳定，这是因为lsu与mmu的ptw是没有握手协议的，只有lsu返回数据有效信号，才会把mmu的请求有效信号拉低，如果mmu的ptw还有请求要发，则会继续把mmu的请求有效信号拉高，只是把物理地址换成下一个请求的物理地址，保持稳定），然后会检测要进入的该twu的该级chk流水线是否已经准备好，如果准备好，则发返回数据请求给twu，将数据返回给twu的chk流水线，如果没准备好，会把数据寄存到entry中的数据寄存器，等到准备好了才发返回数据请求给twu，将数据返回给twu的chk流水线。同时每次在拿到lsu返回的数据时，会检测是否满足更新进pde cache的条件（不是叶子表项并且不会触发页表异常），如果满足则把相应的vpn和ppn更新进pde cahe，根据lvl决定更新到哪一级pde cache。
     7.触发页表异常的处理：每个twu中的fst_chk、scd_chk、thd_chk流水线都会进行页表异常的检查，lsu在返回数据给mmu之后，都会进入chk类流水线进行页表异常检查，根据lsu返回的是哪一级页表的数据，来决定进入哪一级的chk流水线，如果在chkk类流水线检查发现触发了页表异常，会将该请求的类型和id（l1dtlb中mbuf的id）更新进页表异常寄存器，页表异常寄存器会发请求到顶层模块的仲裁器，对多个twu的请求进行仲裁，最总拿到仲裁的授权，将该页表异常上报到请求来源处，根据type决定上报到l1itlb还是l1dtlb，根据id中的L1TLB部分决定上报到l1dtlb中mbuf的哪个entry，根据id中的L2TLB部分去释放L2TLB中miss buffer的entry。
     8.触发访问异常的处理：每个twu中的fst_pmp、scd_pmp、thd_pmp流水线都会进行pmp的检查，如果pmp检查未通过，会触发访问异常；同时如果lsu返回数据的时候出现了总线错误，也会触发访问异常。如果在pmp类流水线检查未通过或者lsu出现总线异常会触发了访问异常，会将该请求的类型和id（l1dtlb中mbuf的id）更新进访问异常寄存器，访问异常寄存器会发请求到顶层模块的仲裁器，对多个twu的请求进行仲裁，最总拿到仲裁的授权，将该页表异常上报到请求来源处，根据type决定上报到l1itlb还是l1dtlb，根据id中的L1TLB部分决定上报到l1dtlb中mbuf的哪个entry。根据id中的L2TLB部分去释放L2TLB中miss buffer的entry。
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
        - ptw中所有的请求都丢弃掉，pde cache的请求丢弃掉，4个twu的6级流水线都丢弃掉，mbuf的所有entry都无效化掉。回填请求也会被屏蔽，已经进入异常寄存器且正在顶层仲裁/已经被授权的异常请求则可以上报，但是未进入异常寄存器或者没拿到顶层仲裁授权的异常请求则被冲刷了。
        - 如果mbuf中有请求在lsu中处理，那么需要保持请求拉高，然后等待lsu返回数据有效信号，防止对后续请求造成影响。
        - 将所有请求冲刷掉并等待到lsu的返回信号后（只有之前发出请求到lsu中处理一半的情况下，才需要等待该信号），ptw ready才会拉高，然后让L2TLB的buffer重新发送所有的请求。
    - 14.L2TLB发来的请求附带信息：vpn、type（请求类型）、id[5:0](id[5:3]为L2TLB miss buffer的entry索引，id[2:0]为L1dTLB miss buffer的entry索引)（type和id一直伴随着请求的原因（不管是正常refill还是异常上报）是：请求返回的时候通过type决定去到哪个模块，fetch refill到itlb和L2TLB，然后通过id[5:3]去定位释放掉L2TLB miss buffer的entry，id[2:0]不会使用。load和store refill到dtlb和L2TLB，然后通过id[2:0]去定位到dtlb miss buffer的具体entry，通过id[5:3]去定位释放掉L2TLB miss buffer的entry。pfu只refill到L2TLB，通过id[5:3]去定位释放掉L2TLB miss buffer的entry，id[2:0]不会使用。）
    - 15.refill的数据包含tag和data，tag包含vpn、asid、page size和G位，data包括flg（除G位）、ppn。
    - 16.twu中流水线包含fst_pmp\fst_chk\scd_pmp\scd_chk\thd_pmp\thd_chk，pmp类流水线附带vpn、type、id、ppn（fst_pmp不携带ppn，用的是satp的基地址ppn），chk类流水线附带vpn、type、id和data（完整页表数据）。
    - 17.pmp类流水线发请求到mbuf附带信息包括：padder、vpn、type、id、lvl（属于哪一级，要访问哪一级页表）和twu_idx（发出请求的twu的索引）这些内容会一起被存储进mbuf的entry中，当该entry的请求别发送时，其on信号拉高，表示请求在途，当lsu返回数据有效信号时，会检查其定位到的twu的chk是否准备好了，如果准备好了，会发出返回的请求，拿到授权后，会携带着存储在entry中的信息和lsu返回的数据一起返回，其中twu_idx和lvl用于mbuf返回的时候，通过twu_idx索引到对应的twu，通过lvl定位到要进入哪一级的chk流水线。如果没有准备好，会将lsu的返回的数据更新进寄存器中，并且拉高get信号，表示已经拿到了lsu的数据，等待twu的chk准备好时，才拉高返回请求，等待授权，成功返回数据后都会释放掉该entry。如果lsu返回总线错误信号，那么会发出更新mbuf中访问异常寄存器的请求，拿到授权后会携带type和id更新进访问异常寄存器，同时释放掉该entry，如果没即使拿到授权，会更新进entry中的lsu bus err flop寄存器，等待mbuf中访问异常寄存器准备好时发除更新mbuf中访问异常寄存器的请求。
    - 18.pmp类流水线的请求更新进mbuf中entry的方式：mbuf中仲裁器会先选择twu中哪个请求更新进entry中（因为可能会同时多个twu发请求），仲裁优先级：itlb>twu0>twu1>twu2>twu3,得到授权后会携带请求极其信息，挑选entry更新，挑选entry的方式是：itlb的请求一直都是更新进entry8，这是专门给itlb类型请求的entry（不必担心溢出，因为itlb类型的请求同一时间一直只有一个，这是因为ifu的发请求方式的组设式的），如果是load、store、pfu的请求，会更新进entry0~7，这个通过指针的方式决定更新进哪个entry，指针初始值是1，即更新进entry0，每次更新后指针左移一位，下一次有请求到来时，更新进entry1，以此类推。更新进entry中时会将请求携带的vpn、padder、type、id、twu_idx、lvl都更新进entry中，当该entry的请求发射并且拿到lsu返回的信号时，会携带entry中的vpn、type、id以及lsu的页表数据返回到相应位置（根据twu_idx和lvl）（twu_idx：可以标记该请求是哪个twu发送的，mbuf返回时可以返回到对应的twu；lvl:请求要拿到的页表数据的级数，可以根据该级数决定返回到哪一级chk类流水线）
    - 19.mbuf中entry的发请求到lsu的方式：只要有entry的vld拉高，并且其没有get和lsu bus err flop（还没拿到lsu的返回），那么就会拉高发给lsu的请求信号，选padder时优先选itlb，即entry8的padder，优先拉高entry8的on，其他entry0~7同样使用指针的方式，指针初始值为1，先发送entry0的padder，在拿到lsu的返回后，指针左移一位，切换到entry1的padder。注意：在发请求的途中，padder不会改变，只有在拿到lsu的返回信号时，需要切换请求的padder时，padder才会变化。
    - 20.异常上报只需附带type和id去定位哪个模块的请求触发的异常，并且释放L2TLB miss buffer的entry，因为发生异常也认为是请求完成了。正常refill不仅得附带type和id去定位模块，还得携带refill的内容，refill给L2TLB需要完整的tag和data，refill给L1TLB则只需要vpn、page size和ppn、flg（除G位，refill 的flg包含5个扩展位：so、c、b、sh、sec，和2bit的rsw，以及riscv标准属性：D\A\U\X\W\R\V(我这里写的也是他们在refill的flg中的顺序)）。不需要asid是因为satp的值改变时会情况整个L1TLB，这种情况下更是不需要G位。
  


以下为各种情况下的流水线或状态机处理：（重要部分）
  1.以下为一个最终得到4k页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入thd_pmp流水线；T2n+8时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2n+8时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T3n+8时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T3n+9时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T3n+10时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》thd_pmp-》mbuf-》thd_chk-》refill）
  2.以下为一个最终得到2M页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T2n+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》refill）
   3.以下为一个最终得到1G页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》refill）
   4.以下为一个最总得到2M页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至2M）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查阶段，将1G块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为2M，并且ppn改变。Tn+6时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，不会触发跨页，则检查结束，page size和ppn也不会再次改变了。Tn+7时，状态机进入数据有效状态，发出跨页的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。
   5.以下为一个最总得到4K页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至4K）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为4K，并且ppn改变。Tn+6时，状态机进入数据有效状态，发出跨页的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+7时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。
   6.以下为一个最总得到1G页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查降级至4K）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查阶段，将1G块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为2M，并且ppn改变。Tn+6时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候不会命中同一个区域，触发跨页，已经将page size降级为4K，并且ppn改变。Tn+7时，状态机进入数据有效状态，发出跨页的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。
   7.以下为一个在fst_chk流水线触发页表异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有页表异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表，但是同时也触发了页表异常，这时候会发请求更新到页表异常寄存器，Tn+5时，更新进页表异常寄存器，页表异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，可能是itlb，如果是dtlb会精确到其buffer的哪个entry（根据type和id）同时会释放掉L2TLB中miss buffer的相应entry。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》上报）
   7.以下为一个在fst_pmp流水线触发访问异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有访问异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，这时候pmp检查未通过，触发了访问异常。T3时，更新进访问异常寄存器，访问异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，可能是itlb，如果是dtlb会精确到其buffer的哪个entry（根据type和id中的L1TLB部分），同时会释放掉L2TLB中miss buffer的相应entry（根据id中的L2TLB部分）。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》上报）
   8.以下为一个最终得到4k页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查但是maee未开启）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入thd_pmp流水线；T2n+8时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2n+8时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T3n+8时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T3n+9时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，并且因为这时候maee未开启，会将要refill的ppn更新进no_maee_ppn寄存器中，T3n+10时，no_maee_ppn寄存器中的值会发给sysmap，当排sysmap返回该区域的扩展属性配置，refill寄存器的请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB，但是refill回去的flg的扩展属性部分会用sysmap返回该区域的扩展属性配置，而不是页表中的扩展属性配置。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》scd_pmp-》mbuf-》scd_chk-》thd_pmp-》mbuf-》thd_chk-》refill）
   9.以下为一个最总得到1G页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查但是不降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入1G跨页检查阶段，将1G块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，没触发跨页，page size不会降级，ppn也不会改变，Tn+6时，状态机进入数据有效状态，发出跨页检查的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。sysmap的配置用尾地址的sysmap的配置，但其实用首地址还是尾地址都无所谓，因为他们命中同一个区域，sysmap的配置也是一样的。
   10.以下为一个最总得到2M页表的ptw请求处理的完整过程（未命中pde cache）（含跨页检查但是未降级）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，因为是4k页表所以不是叶子表项，如果没有页表异常，请求会进入scd_pmp流水线；TN+5时，请求进入scd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。因为maee未开启，所以会发请求进行跨页检查，如果跨页检查状态机空闲并且其拿到授权，则Tn+5时，状态机进入2M跨页检查的阶段，将2M块的第一个4K块和最后一个4K块发给sysmap，sysmap的结果这个在当排返回，然后做两个块命中8个区域中哪一个的比较，这时候会命中同一个区域，不会触发跨页，page size不会降级，ppn不会改变。Tn+6时，状态机进入数据有效状态，发出跨页检查的refill请求，并且flg的扩展属性部分换成sysmap的配置，refill寄存器空闲，那么该refill请求更新进refill寄存器。Tn+7时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。sysmap的配置用尾地址的sysmap的配置，但其实用首地址还是尾地址都无所谓，因为他们命中同一个区域，sysmap的配置也是一样的。
   11.以下为一个第一级 PDE cache 命中后最终得到 2M 页的ptw请求处理的完整过程（第一级 PDE cache 命中）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时命中第一级 PDE cache，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，请求跳过fst，直接进入scd_pmp,进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；T3时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；Tn+4时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》scd_pmp-》mbuf-》scd_chk-》refill）
   12.以下为一个第一级 PDE cache 命中后最终得到 4K 页的ptw请求处理的完整过程（第一级 PDE cache 命中）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时命中第一级 PDE cache，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，请求跳过fst，直接进入scd_pmp,进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign scd_pmp_pa[PPN_WIDTH+11:0] = {scd_pmp_ppn[PPN_WIDTH-1:0],scd_pmp_vpn[17:9],3'b0};），进行pmp检查，发请求到mbuf；T3时，scd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的scd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进scd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；Tn+4时，请求进入scd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，检查到不是叶子页表。Tn+5时，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；Tn+6时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；T2n+6时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；T2n+7时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，T2n+8时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。（正常的流程是：pde cache(xbar_one_to_four)-》scd_pmp-》mbuf-》scd_chk-》thd_pmp=》mbuf=》thd_chk=》refill）
   13.以下为一个PFU 请求成功 refill一个1G页表的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（无异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+5时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L2TLB，只回填到L2TLB，不会回填到L1TLB，根据type，因为不是fetch、load和store所以不会回填给L1TLB，id会索引到L2TLB中miss buffer的entry，释放掉该entry，因为请求已经成功完成，回填的内容中充当L2TLB的tag的是vpn、asid、page size和G位，充当data的是ppn、flg（除G位外的flg）。（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》refill）
   14.以下为一个PFU 请求触发异常的ptw请求处理的完整过程（未命中pde cache）（不含跨页检查）（有页表异常发生）：T0时，l2tlb的请求拉高；T1时，当请求从L2tlb发到ptw时，会先同时查找第一级和第二级pde cache，此时假如未命中，该请求会根据其vpn，通过哈希hash决定分发到4个twu中的哪个twu处理，假如此时进入twu0处理；T2时，该请求进入fst_pmp流水线，会生成其要访问的物理地址（assign fst_pmp_pa[PPN_WIDTH+11:0] = {regs_ptw_satp_ppn[PPN_WIDTH-1:0],fst_pmp_vpn[VPN_WIDTH-1:18],3'b0};），然后将该物理地址发给pmp，同时pmp会返回flg，fst_pmp会根据该请求的类型，查看是否通过pmp检查，如果pmp检查通过会发请求到mbuf；T3时，fst_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+3时，ptw接收到lsu的数据会查看此时的fst_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进fst_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；TN+4时，请求进入fst_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到触发页表异常，这时候会发请求更新到页表异常寄存器，Tn+5时，更新进页表异常寄存器，页表异常寄存器会发请求将异常上报，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），会将最后该请求触发的异常上报到请求的来源，因为是pfu类型，不是fetch、load和store所以不会回填给L1TLB，会将异常上报到L2TLB，id会索引到L2TLB中miss buffer的entry，释放掉该entry，因为请求已经完成，后续L2TLB会把该异常上报到lsu的 pfu端口（正常的流程是：pde cache(xbar_one_to_four)-》fst_pmp-》mbuf-》fst_chk-》异常上报）
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
答：要求该次访问拿到的页表数据没有触发页表异常并且不是叶子表项，并且未被 abort/flush 屏蔽即可。satp/PMP 配置改变只清空 PDE cache、不 abort in-flight walk 时，不额外禁止旧 in-flight walk 返回后更新 PDE cache。
18. 当 `tlboper_ptw_abort` 或其他 TLB 维护操作发生时，PDE cache 是全清空还是只屏蔽当前请求？是否存在按 VA/ASID 精确失效 PDE cache 的行为？
答：PDE cache 全部清空，并清空ptw的所有请求，等到可以继续接受请求时，让L2重新所有请求。不存在按 VA/ASID 精确失效 PDE cache 的行为。清空全部 PDE cache + flush in-flight PTW 请求。

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
答：最终按本设计 RTL/文字规则建模，不额外套用标准 Sv39 的保留位、RSW、strong-order 检查。叶子 PTE 的 page fault 规则以第 94/95/96/131/132/133 题为准；非叶子 PTE 只在 `V=0`、write-only 规则命中、或第三级仍为非叶子 PTE 时触发 page fault，除此之外 U/G/A/D/RSW/高位保留位/扩展属性都不检查。
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
答：首地址是用1G页表的ppn[2]和全是0的ppn[1:0]，也就是1G块中的第一个4K块。尾地址是用1G页表的ppn[2]和全是1的ppn[1:0]，也就是1G块中的最后一个4K块。offset部分不考虑，因为内存地址划分的时候就是按4k为最小块的。
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
答：异常上报也需要返回原始 id 和 type。对 itlb 请求没有 L1DTLB mbuf id 时 id 字段的L1TLB部分不会被使用。虽然会返回，但是不会使用。其中id字段的L2TLB部分会去释放掉L2TLB中miss buffer的相应entry。
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
答：PTE字段64 位页表项自上而下可分为三块：最高几位为扩展属性（图中依次为 So、C、B、Sh、Sec，其后 58–38 为保留）；中间 37–10 为物理页号 PPN，按 PPN[2]（37–28，10 位）、PPN[1]（27–19，9 位）、PPN[0]（18–10，9 位） 三段拼接；最低 10 位为 RSW（9–8） 以及标准权限与状态位 D、A、G、U、X、W、R、V。refill `flg` 包含最高几位扩展属性、RSW、以及标准权限与状态位 D、A、U、X、W、R、V；G 位不进入 data `flg`，而是放在 tag/global 中。内部 `ptw_flg` 去掉 G 后才出现 `ptw_flg[5]=A`、`ptw_flg[6]=D`。
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
                   ||  ptw_hit_1g && lsu_data_flop[27:10] != 18'b0 // 1g align
                   ||  ptw_hit_2m && lsu_data_flop[18:10] != 9'b0  // 2m align
                     ) && ptw_leaf_vld)
                   || !ptw_flg[1] && !ptw_flg[3]        // thd req no R/X
                       && ptw_chk_thd);如上代码是完整的检查，部分哪一级流水线的检查。
95.    A/D 位规则是否为 fetch/load/PFU 要求 A=1，store 要求 A=1 且 D=1？IUTLB fetch 是否也要求 A=1？
答：fetch/load/PFU都要求A=1，store 要求 A=1 且 D=1。
96.    “fetch meets strong order” 触发 page fault 的规则需要明确：是 MAEE 开启时 PTE.So=1 且请求 type 为 IUTLB/fetch 触发，还是 MAEE 关闭时 sysmap.So=1 也会触发？
答：mmu中不做该检查，不需要考虑。（可能是ifu内部的检查）

### 16. PDE cache 精确行为

97. PDE cache 在 ASID 改变时会清空。请明确清空触发信号：是 satp.asid 改变、satp 任意字段改变、tlboper、reset，还是上游某个 flush 信号？
答：satp 任意字段改变。
98. `tlboper_ptw_abort` 发生时，PDE cache 是保持原有内容，只屏蔽当前 lookup/update 请求，对吗？如果页表内容被软件修改并通过 tlboper 失效 TLB，保留旧 PDE cache 是否是设计预期？
答：不对。现在应该是得tlboper_ptw_abort时也无效化所有的pde cache。
99.  PDE cache 的 PLRU 在命中时是否更新？在写入新 entry 时，如果存在 invalid entry，优先使用 invalid entry 还是仍按 PLRU victim？
答：命中时更新，写入时也更新。存在invalid entry说明satp的值修改了，优先invalid entry。
100. PDE cache lookup 与 PDE cache update 若同周期发生，读写同一个 entry 或同一个 tag 时的预期行为是什么？lookup 看旧值还是新值？
答：PDE cache lookup 与 PDE cache update 若同周期发生，这个新的数据在下一个时钟周期才会真正更新进entry中，所以这个时钟周期如果PDE cache lookup可以读出数据，但是下一个时钟周期tag就改变了，因为新的写入了。
101. PDE cache 更新的 PPN 来自非叶子 PTE。若该非叶子 PTE 的 PPN 指向的下一级页表地址 PMP 原本通过，但后续 PMP 配置变化，PDE cache 命中后会跳过被缓存级别的 PMP 检查；这是设计预期吗？是否依赖 PMP 变化时清空 PDE cache？
答：PMP 配置变化后也应该清空PDE cache。

### 17. Mbuf/LSU 与异常返回

102. mbuf entry 的释放时机是什么？LSU 返回数据时释放，数据成功送入 CHK 流水线时释放，还是该级 CHK 处理完成后释放？
答：mbuf entry 的释放时机是接收到的lsu数据成功返回到相应的twu的特点位置。所以是数据成功送入 CHK 流水线时释放。
103. DTLB mbuf 分配指针“左移一位”时，如果指向的 entry 仍 valid 但其他 entry 空闲，是否会跳过 valid entry 寻找空闲项，还是依赖上游保证不会发生？
答：不可能出现准备左移到的那个entry的valid仍有效，因为mbuf中entry数量等于ptw中最多存在的请求数量，所以mbuf只可能满，不可能溢出，故而不可能出现准备左移到的那个entry的valid仍有效的情况。
104. LSU 返回 bus error 时，请求是否不进入 CHK 流水线，而是直接形成访问异常？该 mbuf entry 是否同拍释放？
答：请求不进入 CHK 流水线，而是直接形成访问异常。该mbuf entry 在该异常被授权写入mbuf的访问异常寄存器中后就释放。
105. LSU 返回 bus error 与 `tlboper_ptw_abort` 同周期时，该访问异常是否属于“abort 当拍已经获得仲裁的异常可以上报”的范畴，还是 bus error 返回会被丢弃？
答：不属于，只有在tlboper_ptw_abort到来前正常写入mbuf的访问异常寄存器中的请求才能成功上报。
1.   当 LSU 返回数据但目标 CHK 不 ready，entry 保存数据且不阻塞其他 LSU 请求。若随后发生 abort，已保存但未送入 CHK 的数据是否直接清 valid 并丢弃？
答：是。

### 18. 跨页检查与 sysmap

107. 第 48 题回答中“首地址用 ppn[1:0] 全 1、尾地址用 ppn[1:0] 全 0”的表述看起来与“第一个/最后一个 4K 块”相反。请确认 1G/2M 跨页检查的 first/last 物理块 PPN 精确计算公式。
答：现在我已经修改
108. 1G 降级到 2M 的最终 PPN 是否应为 `{pte.ppn[2], vpn[1], 9'b0}`？当前回答 `{pte.ppn[2], vpn[1], pte.ppn[0]}` 在 PPN[0] 非 0 时会产生不同结果，请确认是否依赖 PPN[0] 一定为 0。
答：其实两则都一样，因为pte.ppn[0]就是全0，因为1G页表要物理地址对齐。如果不对齐已经触发页表异常了。
109. 2M 降级到 4K 的最终 PPN 是否为 `{pte.ppn[2], pte.ppn[1], vpn[0]}`；如果原 2M PTE 的 PPN[0] 非 0 且硬件不做对齐检查，是否仍完全覆盖为 vpn[0]？
答：2M PTE 的 PPN[0] 非 0会触发页表异常，不会进入跨页检查，而是上报异常，然后结束。
110. sysmap 如果没有命中任何区域，或者异常地命中多个区域，PTW 如何处理？是否触发访问异常、页表异常、使用默认属性，还是这种配置不考虑？
答：默认sysmap 不会发生没有命中任何区域，或者异常地命中多个区域的情况。不可能出现没有命中任何区域，或者异常地命中多个区域，因为划分区域的时候最小单元是4K，而发过去的是ppn，是对4K块的地址。因此不可能出现。
111. MAEE 关闭且 4K 叶子 PTE 不需要跨页降级时，是否仍需要访问 sysmap 取得 PMA 属性用于 refill？如果需要，请补充 4K 正常 refill 的 sysmap 查询时序。
答：是。仍然需要访问 sysmap 取得 PMA 属性用于 refill。（rtl已经修好）
1.   MAEE 关闭且 1G/2M 大页首尾落在同一个 sysmap 区域时，refill 的 PMA 属性取首地址、尾地址、还是两者相同后任取一个？
答：取尾地址，但是其实取首地址、尾地址都无所谓，因为他们命中同一个 sysmap 区域，他们的 PMA 属性是一样的。
1.   跨页检查状态机最终确定不跨页或完成降级后，进入 refill 寄存器和顶层仲裁的完整时序还没有写完。请补充从跨页检查结束到 refill 返回的后续周期。
答：已补充。

### 19. 仲裁优先级与 cycle 检查边界

114. TWU 内部“itlb 优先 > 高等级页表 > 低等级页表”中，高等级已确认是第三级优先。请明确各内部仲裁器的完整顺序是否都是 `itlb` 优先，然后 `thd > scd > fst`。
答：是。
115. 正常 refill 仲裁器有 4 个来源：fst/scd/thd CHK 和跨页检查状态机。跨页检查状态机相对 thd/scd/fst 的优先级是什么？
答：itlb>跨页检查状态机>thd>scd>fst。
116. 顶层访问异常仲裁器有 5 个来源：4 个 TWU 和 LSU bus error。LSU bus error 相对 4 个 TWU 访问异常寄存器的优先级是什么？
答：LSU bus error>4 个 TWU 访问异常寄存器
117. 如果同一个原始请求理论上可能在同周期出现 bus error 访问异常和 CHK 页表异常，是否访问异常一定覆盖页表异常？还是这种组合在结构上不会发生？
答：同一个原始请求不可能在同周期出现 bus error 访问异常和 CHK 页表异常，因为bus error 访问异常触发后，该请求就不会正常返回到twu的CHK流水线了，更不会触发CHK 页表异常。是拿到lsu返回的数据有效信号的下一个时钟周期请求才真正的进入chk流水线。
118. UVM scoreboard 是否需要检查 exact cycle，例如 T0/T1/T2 和每一级固定一拍；还是只要求在有限延迟内功能结果正确，cycle-accurate 留给 assertion/monitor 检查？
答：只要求在有限延迟内功能结果正确。

### 20. 建议补充的完整处理过程

119. 请补充“第一级 PDE cache 命中，最终得到 4K/2M 页”的完整流程，明确从 PDE cache 命中后进入哪一级 PMP、如何生成物理地址、是否更新第二级 PDE cache。
答：请求进入PDE cache后会同时查找第一级和第二级pde cache的所有entry，并行查找，如果有命中第一级PDE cache的某个entry则为命中第一级PDE cache，第二级同理。命中第一级PDE cache可以跳过fst pmp和fst chhk，直接进入scd pmp。命中第二级PDE cache可以直接进入thd pmp。并且在lsu返回其页表数据时如果为非叶子页表并且未触发异常（在mbuf中检查）也会更新第二级 PDE cache。
120.   请补充“第二级 PDE cache 命中，最终得到 4K 页”的完整流程，明确跳过 fst/scd 后如何进入 thd_pmp/thd_chk。
答：  T0时L2TLB的请求拉高，T1时，第二级 PDE cache 命中则跳过fst和scd，直接进入thd pmp，请求进入thd_pmp流水线，进行fst_pmp流水线类似的工作，生成要访问的物理地址（assign thd_pmp_pa[PPN_WIDTH+11:0] = {thd_pmp_ppn[PPN_WIDTH-1:0],thd_pmp_vpn[8：0],3'b0};），进行pmp检查，发请求到mbuf；T2时，thd_pmp发到mbuf的请求会更新进mbuf的entry中，如果条件允许会将请求发到lsu，等待lsu返回数据，期间请求会一直拉高，并且物理地址保持稳定，这是因为lsu没有grant和ready的握手协议，假设经过n个时钟周期；Tn+2时，ptw接收到lsu的数据会查看此时的thd_chk流水线是否可以准备好接收请求（即没有请求在该流水线停留或者有请求即将进入该流水线），如果可以则发出写回请求，将该请求的相关数据更新进thd_chk的流水线，如果不可以则会更新进mbuf的entry的寄存器中，等待该流水线准备好；Tn+3时，请求进入thd_chk流水线，该流水线会根据拿到的页表数据，进行页表异常检查，和叶子表项检查，这时候会检查到是叶子页表。如果没有页表异常会发出refill请求，该refill请求更新进refill寄存器，Tn+4时，请求经过顶层模块的仲裁后（因为4个twu可能同时发refill请求，而且页表异常、访问异常、正常refill三者也要进行仲裁），并且拿到arb的grant，会将最后的叶子表项的数据refill回L1TLB和L2TLB。

121. 请补充“LSU 返回 bus error 触发访问异常”的完整流程，包括 mbuf entry、访问异常寄存器、顶层仲裁和返回源的处理。
答：T0时，LSU 返回 bus error ，会跟踪到请求entry，然后发出更新mbuf中的访问异常寄存器的请求，T1时，mbuf中的访问异常寄存器有效信号拉高，并且携带该请求的id和type，mbuf中的访问异常寄存器发出上报请求到顶层，仲裁后拿到授权后，将异常上报。
122.   请补充“abort 到来时 LSU 中有 outstanding 请求”的完整流程，包括 abort 当拍清哪些 valid、PTW ready 何时拉低/拉高、LSU 返回后如何丢弃数据、L2TLB 何时重发。
答：  如果abort 到来时请求刚刚准备要发出第一拍，那么直接屏蔽请求即可，不用担心lsu会接收到请求，如果abort 到来时请求已经在持有了段时间，不是发出的第一拍，那么需要保持请求拉高，直到lsu返回数据有效信号但是这个数据不会拿去干什么，直接丢失，然后ptw才能接收L2TLB重新发的请求，如果abort 到来时刚好收到lsu返回数据有效信号，那么也不需要保持请求拉高了。
123.请补充“maee 关闭但不需要降级的大页 refill”完整流程，即 1G/2M 首尾 sysmap 命中同一区域后如何选择 PMA、写入 refill 寄存器并返回。
答：已补充。

## 第三轮待澄清问题

本轮问题主要来自第二轮答案后的剩余边界和少量正文/答案之间的冲突。目标是让后续 UVM 审核能明确区分“最终 spec 预期行为”和“当前 RTL 可能还要修改的行为”。

### 21. Spec 版本与待修改 RTL

124. 文档中出现了“现在应该是得 tlboper_ptw_abort 时也无效化所有的 pde cache”和“rtl 要改下”等表述。后续 UVM 审核应以这些最新回答作为最终 spec 吗？如果当前 RTL 与这些回答不一致，是否应判定为 RTL bug？
答：tlboper_ptw_abort 时也无效化所有的 pde cache，我已经在rtl实现了，你直接按这些最新回答作为最终 spec 。
125. 对于已经发现需要修改 RTL 的点，是否希望在本文档中单独增加“已知 RTL 待修项”小节，避免后续 AI 审核时把旧 RTL 行为误认为 spec？
答：是
126. 文档中有些回答直接引用 RTL 表达式，例如 `ptw_page_flt`。这些 RTL 表达式是否就是规范性规则？如果后续文字描述和 RTL 表达式冲突，UVM reference model 应优先按哪一个建模？
答：是规范性规则。如果后续文字描述和 RTL 表达式冲突，UVM reference model 应优先按文字描述。

### 22. PTE/flg 位映射与权限规则

127. 请给出 `ptw_flg`/refill `flg` 的精确 bit map。现在文字说 flg 包含扩展属性和 D/A/G/U/X/W/R/V，但代码片段中 `ptw_flg[5]` 被当作 A、`ptw_flg[6]` 被当作 D，和标准 PTE bit 中 G/A/D 的位置不完全一致。scoreboard 应按 raw PTE bit 位置，还是按设计内部重新打包后的 `ptw_flg` 位置？
答：flg包含扩展属性和 D/A/G/U/X/W/R/V，这里的ptw_flg相比flg缺少了G位，所以`ptw_flg[5]` 被当作 A、`ptw_flg[6]` 被当作 D。scoreboard 应按 raw PTE bit 位置。
128. PTE 高位扩展属性 So/C/B/Sh/Sec 的精确 bit 编号和顺序是什么？例如是否为 bit[63:59]，且从高到低依次为 So、C、B、Sh、Sec？
答：从 最高位往低位 紧挨着排布在 bit 63～bit 59，顺序依次是：bit 63 为 So，bit 62 为 C，bit 61 为 B，bit 60 为 Sh，bit 59 为 Sec。
129. refill 返回的 `global` 位如何生成？只使用叶子 PTE 的 G 位，还是需要 OR 上任意上级非叶子 PTE 的 G 位？如果非叶子 G 位参与 global，PDE cache 不存 G 位时如何保证 PDE cache 命中路径仍能返回正确 global？
答：refill 返回的 `global` 位是页表flg中的G位，只使用叶子 PTE 的 G 位。
130. RSW[1:0] 是否完全忽略，既不参与异常判断，也不进入 refill `flg`？
答：RSW[1:0]就是一个保留位，不会对他做任何处理。但也进入refill `flg`。
131. “write only” 规则请再次确认：在本设计中 `W=1,R=0,X=1,MXR=1` 是否允许通过，不触发 page fault？这与标准 Sv39 常规规则不同，后续 reference model 需要按本设计还是按 RISC-V 标准建模？
答：本设计中 `W=1,R=0,X=1,MXR=1` 允许通过，不触发 page fault。后续 reference model 需要按本设计。
132. A 位检查请明确：对所有叶子 PTE，不论 fetch/load/store/PFU，是否都要求 A=1？第 95 题回答里 “load 要求 A=1（在 mxr 有效的情况下）” 是否应改为 “load 总是要求 A=1”？
答：对所有叶子 PTE，不论 fetch/load/store/PFU，都要求 A=1。我已经修改了第 95 题回答。
133. PFU 的 PTE 权限检查按 load 处理、fetch 处理，还是独立处理？例如 PFU 是否要求 R=1 或 `MXR && X=1`，是否要求 A=1，是否检查 D 位？
答：独立处理，就是按PFU类型处理。PFU不要求 R=1 或 `MXR && X=1`，要求 A=1，不检查 D 位。
134. MPRV 和 M-mode 对页表权限检查的影响还不够明确。`cp0_supv_mode` 和 `cp0_user_mode` 都为 0 的机器模式下，U/S 权限检查是否完全跳过？MPRV 是否已经被 CP0 转换成 `cp0_supv_mode/cp0_user_mode` 后再输入 PTW？
答：机器模式下，ppn等于ppn，不会有请求进入ptw，所以不考虑U/S 权限检查，不考虑该问题。
135. page fault 和 access fault 返回给上游时是否只有“页表异常/访问异常”两类标志，没有 instruction/load/store/prefetch cause 细分？PFU 异常是否也没有独立 cause 编码？
答：page fault 和 access fault 返回给上游时只有“页表异常/访问异常”两类标志。type和id只是用来让异常定位到请求的出处而已，不是异常的类型编码。比如type是fentch，那么就上报给itlb，如果type是load或store，那么就上报给dtlb，并且根据上报到精确的dtlb miss buffer的entry中。

### 23. 上下文变化、清空与一致性

136. satp 任意字段改变会清空 PDE cache。它是否也会清空 PTW 当前 in-flight 请求、TWU 流水线、mbuf、异常寄存器和 refill 寄存器？还是只清 PDE cache，不影响正在进行的 walk？
答：不会。satp 任意字段改变只会清空 PDE cache，不会做认为其他操作，不影响正在进行的 walk。
137. 如果 satp.asid 在一次 walk 中途改变，而该 walk 没有被 abort/flush，且 refill 返回当拍使用新 ASID，那么旧页表 walk 的结果是否可能以新 ASID refill？这是设计允许的行为，还是软件必须通过 sfence/tlboper 避免？
答：软件会跳过sfence/tlboper 避免，一般情况下satp.asid改变都会伴随着后续的abort。
138. PMP 配置变化后“也应该清空 PDE cache”。该清空是否由硬件信号自动触发？是否同时 abort/flush in-flight PTW 请求？如果只是软件约束，请说明 UVM 是否需要主动建模该事件。
答：该清空由硬件信号自动触发。只会清空PDE cache，不会abort/flush in-flight PTW 请求。
139. `tlboper_ptw_abort` 同拍如果发生 PDE cache lookup 或 PDE cache update，优先级如何定义？是先无效化再 lookup/update，使当拍不会命中/写入，还是当拍已完成的 lookup/update 可能生效但随后被清掉？
答：tlboper_ptw_abort时所有的请求都会被冲刷，在PDE cache lookup的请求会被冲刷掉，PDE cache update的请求也不会让他更新进pde cache，pde cache会被全部清空。当拍已完成的 lookup/update 可能生效但随后被清掉。
140. reset、satp 改变、PMP 配置改变、tlboper abort 这几类事件对 PDE cache、TWU、mbuf、refill/异常寄存器的影响是否可以整理成一张表？目前第 65 题说没有其他 abort 来源，但第 97/101 题又引入了 PDE cache 清空来源，容易混淆。
答：reset和tlboper abort 会清空PDE cache 并且abort/flush in-flight PTW 请求。satp 改变、PMP 配置改变只会清空PDE cache，不会做其他操作。

### 24. 返回目标、匹配与异常可见性

141. 请按 type 列出正常 refill 的目标：IUTLB 是否 refill L1ITLB 和 L2TLB？Load/Store 是否 refill L1DTLB 和 L2TLB？PFU 是否只 refill L2TLB？是否存在只 refill L1 不 refill L2 的情况？
答：IUTLB 是 refill L1ITLB 和 L2TLB，Load/Store 是 refill L1DTLB 和 L2TLB，PFU 只 refill L2TLB，不存在只 refill L1 不 refill L2 的情况
142. PFU 触发 page fault/access fault 时异常上报到哪里？因为 PFU 正常情况只 refill L2TLB，它的异常是否返回给 L2TLB miss buffer、LSU prefetch 端口，还是被上游静默处理？
答：它的异常返回给 L2TLB，然后L2TLB上报到LSU prefetch 端口。
143. PTW 返回可能因为多个 TWU 和不同页级并发而乱序。scoreboard 是否应完全按 `type + id` 匹配返回，而不检查请求返回顺序？对 IUTLB id 固定为 0 且同一时间只允许一个 IFU 请求，这个假设是否足够？
答：PTW 返回可能出现多个 TWU 和不同页级的请求要返回，但是仲裁部分会决定那个请求先返回，是有顺序的，不是乱序的。优先级同样是itlb优先，然后thd>scd>fst。
144. 第 118 题说 scoreboard 只要求有限延迟内功能正确。是否需要给出一个无 LSU 长延迟/无 backpressure 情况下的最大期望延迟，还是 scoreboard 不设固定周期上限，只做事务最终匹配？
答：scoreboard 不设固定周期上限，只做事务最终匹配。

### 25. Mbuf、LSU 与 abort 边界

145. LSU bus error 时，mbuf entry 在“访问异常被授权写入 mbuf 的访问异常寄存器后”释放。若访问异常寄存器暂时 busy 或仲裁未授权，该 mbuf entry 是否保持 valid 并阻塞对应 entry 复用？
答：若访问异常寄存器暂时 busy 或仲裁未授权会将该LSU bus error 的信号先寄存在LSU bus error flop寄存器中，然后尝试发请求，异常寄存器空闲并仲裁授权时就释放了，在这之前不会释放。
146. `tlboper_ptw_abort` 到来时“请求刚刚准备要发出第一拍”和“已经持有了一段时间”的边界请精确定义。是否以 LSU request valid 在 abort 前一拍已经为 1 作为是否必须继续保持 valid 等待返回的判断条件？
答：LSU request valid 在 abort 前一拍已经为 1 ，那么需要继续保持 valid 等待返回。可以以 LSU request valid 在 abort 前一拍已经为 1 作为必须继续保持 valid 等待返回的判断条件。
147. abort 当拍如果 LSU data valid 返回普通数据而非 bus error，且目标 CHK ready，是否仍必须丢弃数据，不进入 CHK、不更新 PDE cache、不产生 refill？
答：仍必须丢弃数据，不进入 CHK、不更新 PDE cache、不产生 refill。
148. abort 当拍如果 LSU data valid 返回 bus error，第 105 题说可上报。它是否一定因为 LSU bus error 优先级最高而获得访问异常仲裁，还是仍可能因最终输出仲裁/下游阻塞而被清掉？
答：abort 当拍如果 LSU data valid 返回 bus error，那么他得先更新进mbuf的访问异常寄存器，这需要一个时钟周期，而abort会阻止其更新进mbuf的访问异常寄存器导致异常不会上报。如果你是指abort 当拍mbuf的访问异常寄存器有异常要上报，那么进入顶层的仲裁，该仲裁的确是LSU bus error 优先级最高，是可以成功立刻上报的。

### 26. MAEE、sysmap 与跨页降级

149. MAEE 关闭时，所有 page size 的 refill `flg` 扩展属性是否都必须来自 sysmap，包括 4K、2M、1G、以及 1G/2M 降级后的 2M/4K？
答：MAEE 关闭时，所有 page size 的 refill `flg` 扩展属性都必须来自 sysmap，包括 4K、2M、1G、以及 1G/2M 降级后的 2M/4K。
150. 4K 页在 MAEE 关闭时查询 sysmap 使用的地址是最终物理 PPN，即叶子 PTE 的 PPN 吗？如果是降级得到的 4K，则使用降级后的最终 PPN 吗？
答：是的。是的。
151. MAEE 在 walk 中途改变且不会触发 abort。若 CHK 时 MAEE=0 进入跨页/sysmap 流程，但 refill 前 MAEE 变为 1，最终 refill 属性按进入跨页时的 MAEE=0，还是 refill 当拍的 MAEE=1？
答：最终 refill 属性按进入跨页时的 MAEE=0。是否进入跨页都是以当前maee的值为参考的，refill不会因为maee的值改变而改变要refill的值。进入跨页检查而导致要refill的数据改变是不可逆的，而且跨页检查也是不会中断的。
152. 1G/2M 跨页检查的 first/last PPN 已在正文中修改。请考虑把公式单独列出：1G first=`{pte.ppn[2], 9'b0, 9'b0}`、1G last=`{pte.ppn[2], 9'h1ff, 9'h1ff}`；2M first=`{pte.ppn[2], pte.ppn[1], 9'b0}`、2M last=`{pte.ppn[2], pte.ppn[1], 9'h1ff}`。这些公式是否正确？
答：正确。
153. 大页跨区域降级后，如果降级结果为 2M 且不再跨区域，refill 的 page size 为 2M，PPN 为 `{pte.ppn[2], vpn[1], 9'b0}`，属性取该 2M 尾地址 sysmap；请确认该组合规则。
答：正确。

### 27. 仍建议补充的完整流程

154. 请补充“第一级 PDE cache 命中后最终得到 2M 页”和“第一级 PDE cache 命中后最终得到 4K 页”的完整流程，尤其是 scd_pmp/thd_pmp 地址生成公式，以及 scd_chk 读到非叶子 PTE 后是否更新第二级 PDE cache。
答：已补充。
155. 请补充“satp 改变或 PMP 配置改变导致 PDE cache 清空”的完整流程，明确是否影响 in-flight PTW 请求，以及 L2TLB 是否需要重发。
答：satp 改变或 PMP 配置改变会生成一个激励信号，该激励信号会让pde cache中所有entry的valid在下一个时钟周期都拉低。不会影响in-flight PTW 请求。L2TLB 不需要重发。不过satp改变都伴随着tlboper_ptw_abort（不保证是他们是同一拍）。
156. 请补充“PFU 请求成功 refill”和“PFU 请求触发异常”的完整流程，明确目标、id、返回字段和异常可见性。
答：已补充。

## 第四轮待澄清问题

本轮只记录少量剩余校对点。PTW 主体行为已经基本清楚，下面这些主要用于避免后续 UVM 审核时因文档局部冲突而误判。

### 28. 文档局部一致性

157. 第 11、12 个完整流程的标题和内容疑似反了：第 11 个标题写“第一级 PDE cache 命中后最终得到 4K 页”，但流程在 `scd_chk` 检查到叶子后直接 refill，看起来应是最终得到 2M 页；第 12 个标题写“最终得到 2M 页”，但流程 `scd_chk` 非叶子后进入 `thd_pmp/thd_chk`，看起来应是最终得到 4K 页。请确认是否需要交换这两个标题。
答：我已经修改。
158. 第 119 题回答仍写“命中第一级 PDE cache 可以跳过 fst，直接进入 scd pmp”，但没有明确 scd_chk 读到非叶子 PTE 且无异常时，是否会把该第二级非叶子 PTE 更新进第二级 PDE cache。请确认：第一级 PDE cache 命中、随后 scd_chk 得到非叶子 PTE 时，是否仍按 `lvl=scd` 更新第二级 PDE cache？
答：会，我已经修改。当表示在scd_chk进行叶子表项和页表异常的检查才更新进pde cache，而是mbuf中有自己的叶子表项和页表异常的检查，当拿到lsu的返回时会进行检查，如果发现是非叶子页表，并且没有触发页表异常，那么会更新进pde cache。
159. 第 148 题回答修正了第 105 题语义：abort 当拍 LSU data valid 返回 bus error 时不会上报，因为 abort 阻止其写入 mbuf 访问异常寄存器；只有 abort 当拍之前已经在 mbuf 访问异常寄存器中、并正在顶层仲裁的异常可以上报。请确认后续以第 148 题为准。
答：确认，以第 148 题为准。
160. 第 125 题回答希望增加“已知 RTL 待修项”，但第 124 题又说 tlboper 清 PDE cache 已经在 RTL 实现。当前是否还存在已知 RTL 待修项？如果存在，请列出；如果不存在，后续 UVM 审核可不再维护该小节。
答：当前不存在，之前的tlboper 清 PDE cache 已经在 RTL 实现。

## 第五轮待澄清问题

本轮不是新增大机制，主要是把旧答案和最新答案之间仍可能让 UVM reference model/scoreboard 建模歧义的地方收敛掉。

### 29. 旧答案与最终 spec 优先级

161. 第 18 题仍写 `tlboper_ptw_abort` 只屏蔽当前 PDE cache 请求；但第 98/124/140/159 题已经确认 `tlboper_ptw_abort` 会清空全部 PDE cache，并且以最新回答作为最终 spec。请确认后续应把第 18 题旧答改成“清空全部 PDE cache + flush in-flight PTW 请求”，避免审核时读到旧答误判。
答：我已经修改。
162. 正文第 13 条写“回填请求会被屏蔽，但是异常上报的请求不会”；第 59/105/148/159 题又把异常上报限定为 abort 当拍之前已经进入异常寄存器且正在顶层仲裁/已经被授权的异常，新形成的 LSU bus error 不会上报。请确认正文第 13 条应改成这个更窄条件。
答：已修改。
163. 第 111 题仍保留“MAEE 关闭且 4K 页需要 sysmap refill，RTL 要改下”的表述，但第 160 题说当前不存在已知 RTL 待修项。请确认 4K 页 MAEE 关闭时走 sysmap 的 RTL 是否已经修好；如果还没修好，是否应恢复“已知 RTL 待修项”小节并把该项列进去。
答：已经修好。

### 30. flg/RSW/G 位映射

164. 正文第 20 条说 L1 refill 的 `flg` 包含 2bit RSW；第 130 题说 RSW[1:0] 不参与异常判断，也不进入 refill `flg`。请确认最终 refill `flg` 是否完全不包含 RSW；如果不包含，请把正文第 20 条里的 RSW 删除。
答：refill flg包含 RSW，但是其不参与异常判断。
165. 请区分 raw PTE bit、内部 `ptw_flg` bit、refill tag/data bit 三套映射。尤其需要确认：raw PTE 的 G bit 是否只单独返回为 `global`，不进入 data `flg`；内部 `ptw_flg` 是否去掉 G 后才出现 `ptw_flg[5]=A`、`ptw_flg[6]=D`；MAEE=0 时 sysmap 5bit 写入 refill `flg` 的 bit 顺序到底是 `{So,C,B,Sh,Sec}` 还是 `{Sec,Sh,B,C,So}`。
答：raw PTE的G位不进入data flg，而是放在tag中。内部 `ptw_flg` 是去掉 G 后才出现 `ptw_flg[5]=A`、`ptw_flg[6]=D`。是{So,C,B,Sh,Sec}。

### 31. Page fault 最终规则

166. 第 29 题说严格遵循 RISC-V Sv39，并列出 `fetch meets strong order`；但第 90/96/130/131 题确认保留位不检查、RSW 忽略、strong order 不由 MMU 检查、write-only/MXR 按本设计的非标准规则。请确认 UVM reference model 最终只按第 94/95/96/131/132/133 题的 RTL/文字规则建模，不再额外套用标准 Sv39 的保留位/RSW/strong-order 检查。
答： UVM reference model 最终只按第 94/95/96/131/132/133 题的 RTL/文字规则建模，不再额外套用标准 Sv39 的保留位/RSW/strong-order 检查。
167. 非叶子 PTE 的最终 page fault 规则请再收敛一次：是否仅为 `V=0`、write-only 规则、以及第三级仍为非叶子 PTE 这几类会触发 fault；除此之外 U/G/A/D/RSW/高位保留位/扩展属性都不检查？如果还有其他非叶子检查，请补完整布尔规则。
答：仅V=0`、write-only 规则、以及第三级仍为非叶子 PTE这几类会触发 fault。除此之外 U/G/A/D/RSW/高位保留位/扩展属性非叶子PTE都不检查。

### 32. 上下文改变与 PDE cache 更新

168. satp/PMP 配置改变只清空 PDE cache，不 abort in-flight walk。若清空之后，旧 in-flight walk 又返回一个非叶子 PTE 且无异常，是否允许它重新更新 PDE cache？第 17 题里的“对应上下文仍有效”是否表示 satp/PMP 已改变时必须禁止这次 PDE cache update？
答：允许它重新更新 PDE cache，但是satp配置改变一般情况下伴随着abort。PMP 配置一般情况下也不发生改变。不必须，后续会来abort进行处理。
169. 如果 satp.asid 或 satp.ppn 改变但没有 `tlboper_ptw_abort`，旧 walk 最终可能按 refill 当拍的新 ASID 返回。请确认这是软件必须避免、UVM 可以约束不生成的场景，还是 scoreboard 必须按硬件现状允许这种交错行为。
答：satp.asid 或 satp.ppn 改变一般伴随tlboper_ptw_abort。UVM 可以约束不生成的该场景。

### 33. 完整流程标题和流水级笔误

170. 完整流程第 4/5 个标题写“最终得到 1G/2M 页表”，但括号和正文分别描述“降级至 2M/4K”，最终 refill 的 page size 也应是降级后的 2M/4K。请确认这两个标题应分别改成“最终得到 2M 页表”和“最终得到 4K 页表”。
答：已修改。
171. 第 120 题以及若干完整流程中，进入 `thd_pmp` 后仍写 `assign scd_pmp_pa` 或“scd_pmp 发到 mbuf”。请确认这些只是笔误，规范应按当前流水级使用 `thd_pmp_pa/thd_pmp`。
答：是笔误，规范应按当前流水级使用 `thd_pmp_pa/thd_pmp`。

### 34. Scoreboard 与仲裁顺序

172. 第 118/144 题说 scoreboard 只做事务最终匹配、不设固定周期上限；第 143 题又强调 PTW 返回有仲裁顺序。请确认 scoreboard 是否需要检查同周期多个候选返回时的仲裁优先级，还是仲裁优先级交给 assertion/monitor，scoreboard 只按 `type + id` 匹配最终结果。
答：仲裁优先级交给 assertion/monitor，scoreboard 只按 `type + id` 匹配最终结果。。

### 35. Machine mode 请求约束

173. 第 24 题 PMP 检查里存在 machine mode 跳过 PMP 的规则，但第 134 题说机器模式下不会有请求进入 PTW。请确认 UVM 是否应约束不产生 `cp0_mach_mode` 下的 PTW 请求；如果不约束，reference model 是否仍按第 24 题的 machine-mode PMP skip 规则处理。
答：这是因为当请求类型是fetch时，使用流水线里 真实硬件特权级（M/S/U），但是当请求类型的load、store、pfu时，如果mprv有效时，访存要按 mstatus.MPP（cp0_mmu_mpp）当「有效特权」，即 MPRV 下 S/U 访存用 MPP 档 的 RISC‑V 语义，如果mprv有效无效，才用流水线里 真实硬件特权级（M/S/U）。因此ptw在机器状态不能表示core流水线请求在机器状态。当core流水线请求在机器状态，那么肯定是没有请求会进入ptw的，因为纯 M 态、不做地址翻译时，本来就不该靠 PTW 走路。但是当core流水线请求不在机器状态，但是请求类型是load、store、pfu并且mprv有效时，并且mstatus.MPP是M态，是做地址翻译的，也靠 PTW 走路，但是ptw选用机器模式状态进行。

## 第六轮待澄清问题

本轮只剩少量会影响 UVM reference model 输入状态采样和 refill 字段建模的点。PTW 主流程、PDE cache、mbuf/LSU、abort、MAEE/sysmap、异常/refill 返回目标已经基本收敛。

### 36. 旧答案同步与字段定义

174. 第 164 题已经确认 refill `flg` 包含 RSW，只是不参与异常判断；但第 130 题仍写 RSW 不进入 refill `flg`。请确认后续应以第 164 题为准，并把第 130 题旧答改为“RSW 进入 refill flg，但不参与 page fault 判断”。
答：确认后续应以第 164 题为准。以修改。
175. 第 168 题确认 satp/PMP 改变清空 PDE cache 后，旧 in-flight walk 返回的非叶子 PTE 仍允许重新更新 PDE cache；但第 17 题仍写 PDE cache 更新要求“对应上下文仍有效”。请确认后续应把第 17 题里的“对应上下文仍有效”删除或改成“未被 abort/flush 屏蔽即可”，否则 reference model 会误认为 satp/PMP 改变后必须禁止旧 walk 更新 PDE cache。
答：已修改。
176. 第 29 题旧答仍写“严格遵循 RISC-V Sv39”并列出 strong-order/page-fault 项；第 166/167 题已经确认最终按本设计 RTL/文字规则，不额外检查保留位、RSW、strong-order，非叶子 PTE 也只检查 `V=0`、write-only、第三级非叶子。请确认第 29 题旧答也应同步改成第 166/167 题的最终规则。
答：第 29 题旧答也应同步改成第 166/167 题的最终规则。

### 37. MPRV/MPP effective privilege

177. 第 173 题补充了 load/store/PFU 在 `MPRV=1` 时按 `mstatus.MPP` 作为有效特权级。请明确 reference model 应如何生成权限检查使用的 effective mode：fetch 是否永远用流水线真实特权级；load/store/PFU 是否在 `MPRV=1` 时用 `MPP`，否则用真实特权级；`cp0_supv_mode/cp0_user_mode/cp0_mach_mode` 输入到 PTW 时是否已经是这个 effective mode？
答：fetch 永远用流水线真实特权级，load/store/PFU 在 `MPRV=1` 时用 `MPP`，否则用真实特权。
178. 当 load/store/PFU 因 `MPRV=1 && MPP=M` 进入 PTW 且 PTW 选用 machine mode 状态时，PMP 检查是否按第 24 题的 machine-mode skip 规则执行，即 `cp0_mach_mode && !pmp_mmu_flg[3]` 时不触发 access fault？同一请求的 PTE U/S 权限检查是否也按 machine effective mode 跳过 S/U 检查？
答：是的。当 load/store/PFU 时 `MPRV=1 && MPP=M，那么所有的检查包括pmp检查和页表检查都是按照M态进行。
179. 请补充或确认 “load/store/PFU，`MPRV=1 && MPP=M`，且发生 PTW walk” 的完整处理流程是否和普通 load/store/PFU walk 相同，只是在 PMP 检查和 PTE U/S 权限检查中使用 machine effective mode；正常 refill/异常返回目标仍按原始 `type + id` 返回到 DTLB/L2TLB 或 PFU 端口。
答：是的。并且正常 refill/异常返回目标仍按原始 `type + id` 返回到 DTLB/L2TLB 或 PFU 端口。

### 38. 文档笔误同步

180. 第 171 题确认 `thd_pmp` 后仍写 `scd_pmp 发到 mbuf` 属于笔误。正文完整流程第 1、第 12、第 120 题等位置仍能搜到这些残留表述。请确认这些位置后续都统一改成 `thd_pmp 发到 mbuf`，不改变 spec 行为。
答：这些位置后续都统一改成 `thd_pmp 发到 mbuf。后续发现你可自行修改。
