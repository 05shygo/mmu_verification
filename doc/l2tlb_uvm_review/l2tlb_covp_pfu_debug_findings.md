# L2TLB PFU Coverage Debug — Resolved

## Problem → Resolution

PFU requests never hit L2TLB. Root cause was in testbench `raw_pipe2` implementation.

## Root Cause: raw_pipe2 drove wrong VPN bits

**The DUT PFU module (`ct_lsu_pfu.v:2045`) correctly drives:**
```systemverilog
assign lsu_mmu_va2[27:0] = pfu_mmu_req_vpn[27:0];  // VPN, not VA
```

**But `raw_pipe2` in the testbench OVERRIDES it with raw VA:**
```systemverilog
// WRONG (original):
m_lsu_vif.driver_cb.lsu_mmu_va2 <= va[27:0];   // raw VA bits [27:0]

// CORRECT (fixed):
m_lsu_vif.driver_cb.lsu_mmu_va2 <= {1'b0, va[38:12]};  // VPN in bits [26:0]
```

`lsu_mmu_va2` is an OUTPUT port from DUT (PFU module), but the testbench
overrides it via the LSU interface driver. The TB must drive the same
VPN format the DUT would: `VA[38:12]` in `lsu_mmu_va2[26:0]`.

## Additional fixes required

1. **PMP deny timing**: PMP was applied pre-vseq, blocking PTW. Fixed by
   moving PMP configuration inside vseq after entry installs.
2. **Sysmap region mismatch**: PFU VA=0x7000_0000 outside sysmap safe
   region (covers 0x10_0000). Fixed by using va_page() with m_va_base.
3. **Non-global flag fault**: `!final_hit_flg[5]` fires on g=0 pages.
   Fixed by mapping PFU pages with g=1.

## URG-Confirmed Results

| Item | Before | After |
|------|--------|-------|
| LINE 1368 `pfu_nxt_st = PFU_DENY` | 0/1 | **1/1** ✅ |
| FSM PFU_CHK→PFU_DENY | Not Covered | **Covered** ✅ |
| FSM PFU_IDLE→PFU_CHK | Not Covered | **Covered** ✅ |
| FSM PFU_CHK→PFU_OK | Not Covered | ⚠️ Needs Phase 3 (PMP restore) |
| LINE 1382 default | 0/1 | ❌ Structurally unreachable |

## Files Modified

- `mmu_l1_l2_tlb_common_vseq.svh` — raw_pipe2 VPN fix + assert_mid_test_reset
- `mmu_l2tlb_directed_vseq.svh` — raw_pipe2 VPN fix (×2 copies)
- `mmu_l2tlb_coverage_vseq.svh` — PFU fullpath vseq (g=1, sysmap-safe VA, PMP timing)

## Remaining for PFU Coverage

- PFU_CHK→PFU_OK: Add Phase 3 restoring PMP to normal after Phase 2,
  then re-issuing PFU requests that will take PFU_IDLE→PFU_CHK→PFU_OK.
