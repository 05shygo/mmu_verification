# PTW ID Coverage Audit - Stage 0

This audit checks that all stage-0 required ID ranges are present in the closure baseline. It does not claim implementation closure.

## Summary

| ID family | Required range | Stage-0 result |
| --- | --- | --- |
| `PTW-AUD-*` | `PTW-AUD-001..023` | complete, all bound to `PTW-ADD-*` or `PTW-FLOW-*` |
| `PTW-ADD-*` | `PTW-ADD-001..036` | complete, all represented in `ptw_source_closure_matrix.csv` |
| `PTW-INFRA-*` | `PTW-INFRA-001..009` | complete, all represented in `ptw_source_closure_matrix.csv` |
| `PTW-FLOW-*` | `PTW-FLOW-001..023` | complete, all represented in `ptw_source_closure_matrix.csv` |
| `PDE-TP-*` | `PDE-TP-001..012` | complete, all represented in `ptw_source_closure_matrix.csv` |
| `MBUF-TP-*` | `MBUF-TP-001..012` | complete, all represented in `ptw_source_closure_matrix.csv` |
| `MAEE-TP-*` | `MAEE-TP-001..013` | complete, all represented in `ptw_source_closure_matrix.csv` |

## `PTW-AUD-*` Binding Check

| Audit ID | Bound IDs | Source checker/SVA class | Status |
| --- | --- | --- | --- |
| `PTW-AUD-001` | `PTW-ADD-001/002/034` | PTE no-fault/flg source compare, CHK/ARB SVA | bound |
| `PTW-AUD-002` | `PTW-ADD-003/034` | G/global tag/data source compare, CHK/ARB SVA | bound |
| `PTW-AUD-003` | `PTW-ADD-004`, `PTW-FLOW-020` | target source compare, ARB/L1 consumer auxiliary SVA | bound |
| `PTW-AUD-004` | `PTW-ADD-005/006`, `PTW-FLOW-021` | fault class/type/id source compare, ARB SVA | bound |
| `PTW-AUD-005` | `PTW-ADD-007`, `PTW-FLOW-015/016/017`, `PDE-TP-001..004` | PDE monitor/SVA | bound |
| `PTW-AUD-006` | `PTW-ADD-008/009`, `PDE-TP-005..009/012` | PDE update/race monitor/SVA | bound |
| `PTW-AUD-007` | `PTW-ADD-010/011/024`, `PTW-FLOW-022`, `PDE-TP-010/011`, `MBUF-TP-009..012` | clear/drop source monitor/SVA | bound |
| `PTW-AUD-008` | `PTW-ADD-012` | request/xbar/ready source monitor/SVA | bound |
| `PTW-AUD-009` | `PTW-ADD-013`, `PTW-FLOW-009/010/011` | PMP PTE PA and no-side-effect source checks | bound |
| `PTW-AUD-010` | `PTW-ADD-014` | original type PMP permission checks | bound |
| `PTW-AUD-011` | `PTW-ADD-015/030/036`, `PTW-FLOW-023` | context/effective-mode source checks | bound |
| `PTW-AUD-012` | `PTW-ADD-016`, `PTW-FLOW-012/013/014` | nonleaf raw PTE level/source fault checks | bound |
| `PTW-AUD-013` | `PTW-ADD-017/018/019/033`, `PTW-FLOW-020/021` | leaf permission and PFU source checks | bound |
| `PTW-AUD-014` | `PTW-ADD-020`, `MAEE-TP-011` | huge align before degrade SVA/source checks | bound |
| `PTW-AUD-015` | `PTW-ADD-021`, `MBUF-TP-001..004` | MBUF allocation and LSU single outstanding SVA | bound |
| `PTW-AUD-016` | `PTW-ADD-022/023`, `PTW-FLOW-018`, `MBUF-TP-005..008` | CHK hold and bus error source checks | bound |
| `PTW-AUD-017` | `PTW-ADD-024`, `PTW-FLOW-019`, `MBUF-TP-009..012` | abort/drop/no-stale source checks | bound |
| `PTW-AUD-018` | `PTW-ADD-025`, `MAEE-TP-001..003` | MAEE=1 flg source compare | bound |
| `PTW-AUD-019` | `PTW-ADD-026`, `PTW-FLOW-008`, `MAEE-TP-009/013` | MAEE=0 4K sysmap source compare | bound |
| `PTW-AUD-020` | `PTW-ADD-027/028/029`, `PTW-FLOW-004..007`, `MAEE-TP-004..010/012/013` | MAEE=0 degrade source compare | bound |
| `PTW-AUD-021` | `PTW-ADD-030`, `PTW-FLOW-023`, `MAEE-TP-012` | context sample source transaction | bound |
| `PTW-AUD-022` | `PTW-ADD-031`, `PTW-FLOW-001..023` | full-flow source scoreboard/SVA evidence | bound |
| `PTW-AUD-023` | `PTW-ADD-032` | consumer-only evidence plus required source target compare | bound as consumer-only |

## `PTW-ADD-*` Check

| ID | Topic | Status |
| --- | --- | --- |
| `PTW-ADD-001` | RSW no fault and flg | present |
| `PTW-ADD-002` | high reserved ignored | present |
| `PTW-ADD-003` | G tag/global only | present |
| `PTW-ADD-004` | request type success targets | present |
| `PTW-ADD-005` | request type fault targets | present |
| `PTW-ADD-006` | completion priority and `{type,id}` matching | present |
| `PTW-ADD-007` | PDE double-hit L2 wins | present |
| `PTW-ADD-008` | PDE lookup/update race | present |
| `PTW-ADD-009` | PDE update conditions | present |
| `PTW-ADD-010` | satp/PMP clear-only | present |
| `PTW-ADD-011` | reset/abort/PDE clear/flush differences | present |
| `PTW-ADD-012` | xbar hash/ready/hold/mask | present |
| `PTW-ADD-013` | PMP deny by level no side effect | present |
| `PTW-ADD-014` | PMP original request type permission | present |
| `PTW-ADD-015` | MPRV/MPP effective mode | present |
| `PTW-ADD-016` | nonleaf rule by level | present |
| `PTW-ADD-017` | write-only/MXR rule | present |
| `PTW-ADD-018` | leaf access permission matrix | present |
| `PTW-ADD-019` | A/D/U/S/SUM/effective mode | present |
| `PTW-ADD-020` | huge alignment before degrade | present |
| `PTW-ADD-021` | MBUF entry allocation | present |
| `PTW-ADD-022` | CHK not-ready hold | present |
| `PTW-ADD-023` | LSU bus error access fault/no side effects | present |
| `PTW-ADD-024` | abort LSU outstanding matrix | present |
| `PTW-ADD-025` | MAEE=1 all-size raw attributes | present |
| `PTW-ADD-026` | MAEE=0 4K sysmap | present |
| `PTW-ADD-027` | MAEE=0 1G degrade matrix | present |
| `PTW-ADD-028` | MAEE=0 2M degrade matrix | present |
| `PTW-ADD-029` | sysmap flag order/default handling | present |
| `PTW-ADD-030` | context sampling points | present |
| `PTW-ADD-031` | chapter 12 full flows | present |
| `PTW-ADD-032` | L1DTLB consumer-only evidence | present |
| `PTW-ADD-033` | PFU special permission matrix | present |
| `PTW-ADD-034` | refill tag/data/flg bit layout | present |
| `PTW-ADD-035` | same `{type,id}` no-reuse constraint | present |
| `PTW-ADD-036` | Bare/M no-request constraint | present |

## `PTW-FLOW-*` Check

| ID | Flow | Status |
| --- | --- | --- |
| `PTW-FLOW-001` | PDE miss, 1G success | present |
| `PTW-FLOW-002` | PDE miss, 2M success | present |
| `PTW-FLOW-003` | PDE miss, 4K success | present |
| `PTW-FLOW-004` | MAEE=0 1G -> 2M | present |
| `PTW-FLOW-005` | MAEE=0 1G -> 4K | present |
| `PTW-FLOW-006` | MAEE=0 2M -> 4K | present |
| `PTW-FLOW-007` | MAEE=0 1G/2M no degrade | present |
| `PTW-FLOW-008` | MAEE=0 4K sysmap refill | present |
| `PTW-FLOW-009` | first-level PMP access fault | present |
| `PTW-FLOW-010` | second-level PMP access fault | present |
| `PTW-FLOW-011` | third-level PMP access fault | present |
| `PTW-FLOW-012` | first-level CHK page fault | present |
| `PTW-FLOW-013` | second-level CHK page fault | present |
| `PTW-FLOW-014` | third-level CHK page fault | present |
| `PTW-FLOW-015` | first-level PDE hit, final 2M | present |
| `PTW-FLOW-016` | first-level PDE hit, final 4K | present |
| `PTW-FLOW-017` | second-level PDE hit, final 4K | present |
| `PTW-FLOW-018` | LSU bus error access fault | present |
| `PTW-FLOW-019` | abort with LSU outstanding | present |
| `PTW-FLOW-020` | PFU success | present |
| `PTW-FLOW-021` | PFU exception | present |
| `PTW-FLOW-022` | satp/PMP change clears PDE cache | present |
| `PTW-FLOW-023` | load/store/PFU with `MPRV=1 && MPP=M` | present |

## `PTW-INFRA-*` Check

| ID | Infrastructure item | Status |
| --- | --- | --- |
| `PTW-INFRA-001` | `ptw_source_ref_model` | present |
| `PTW-INFRA-002` | page table builder / PTW memory sequences | present |
| `PTW-INFRA-003` | source monitor / source scoreboard | present |
| `PTW-INFRA-004` | PDE cache monitor/SVA | present |
| `PTW-INFRA-005` | PTW LSU/MBUF protocol SVA | present |
| `PTW-INFRA-006` | PMP/TWU/CHK SVA and probes | present |
| `PTW-INFRA-007` | MAEE/sysmap/degrade SVA and coverage | present |
| `PTW-INFRA-008` | xbar/arb monitor/SVA | present |
| `PTW-INFRA-009` | coverage gate/regression report | present |

## `PDE-TP-*` Check

| ID | Topic | Status |
| --- | --- | --- |
| `PDE-TP-001` | miss -> first nonleaf update | present |
| `PDE-TP-002` | L1 hit -> scd nonleaf/update | present |
| `PDE-TP-003` | L2 hit -> thd | present |
| `PDE-TP-004` | L1+L2 double hit selects L2 | present |
| `PDE-TP-005` | leaf PTE no update | present |
| `PDE-TP-006` | nonleaf page fault no update | present |
| `PDE-TP-007` | LSU bus error no update | present |
| `PDE-TP-008` | abort returned nonleaf no update | present |
| `PDE-TP-009` | lookup/update same tag old-state read | present |
| `PDE-TP-010` | satp/PMP clear-only | present |
| `PDE-TP-011` | reset/abort clear and flush | present |
| `PDE-TP-012` | PLRU hit/write/victim | present |

## `MBUF-TP-*` Check

| ID | Topic | Status |
| --- | --- | --- |
| `MBUF-TP-001` | IUTLB and TWU same-cycle mbuf write | present |
| `MBUF-TP-002` | DTLB/PFU entry0-7 rotation | present |
| `MBUF-TP-003` | LSU request valid/PA hold | present |
| `MBUF-TP-004` | single outstanding/no legal OOO | present |
| `MBUF-TP-005` | normal data and CHK ready | present |
| `MBUF-TP-006` | normal data and CHK not ready hold | present |
| `MBUF-TP-007` | bus error no CHK/refill/PDE | present |
| `MBUF-TP-008` | bus error priority | present |
| `MBUF-TP-009` | abort no LSU outstanding | present |
| `MBUF-TP-010` | abort with LSU outstanding and late data drop | present |
| `MBUF-TP-011` | abort same-cycle new bus error dropped | present |
| `MBUF-TP-012` | pre-existing granted exception visible | present |

## `MAEE-TP-*` Check

| ID | Topic | Status |
| --- | --- | --- |
| `MAEE-TP-001` | MAEE=1 1G raw attr | present |
| `MAEE-TP-002` | MAEE=1 2M raw attr | present |
| `MAEE-TP-003` | MAEE=1 4K raw attr | present |
| `MAEE-TP-004` | MAEE=0 1G no-cross | present |
| `MAEE-TP-005` | MAEE=0 1G -> 2M | present |
| `MAEE-TP-006` | MAEE=0 1G -> 4K | present |
| `MAEE-TP-007` | MAEE=0 2M no-cross | present |
| `MAEE-TP-008` | MAEE=0 2M -> 4K | present |
| `MAEE-TP-009` | MAEE=0 4K sysmap | present |
| `MAEE-TP-010` | degrade no lower walk | present |
| `MAEE-TP-011` | huge align fault before degrade | present |
| `MAEE-TP-012` | MAEE switch no rollback after sysmap entry | present |
| `MAEE-TP-013` | sysmap flag order `{So,C,B,Sh,Sec}` | present |

## Stage-0 Result

All required stage-0 ID families are represented and have a frozen owner/evidence direction. All implementation closure remains open by design and belongs to later stages.
