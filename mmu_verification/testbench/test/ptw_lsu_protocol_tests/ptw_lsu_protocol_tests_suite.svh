// PTW->LSU protocol suite include list.
// Legacy Phase11 wrappers are kept as LSU-ID compatibility aliases; Phase12
// LSU-ID directed tests are compile-visible for Phase13 regression lists.
`include "test_pmbuf_serial_outstanding_001.svh"
`include "test_pmbuf_addr_stable_001.svh"
`include "test_pmbuf_no_tag_001.svh"
`include "test_pmbuf_inorder_resp_001.svh"
`include "test_pmbuf_ptr_hold_001.svh"
`include "ptw_lsu_id_phase12_tests.svh"
