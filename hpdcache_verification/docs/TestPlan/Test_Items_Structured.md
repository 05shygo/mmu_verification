# HPDcache Hardware Test Plan

## Requirement 1.0: Cache must arbitrate correctly between multiple clients.

### Sub Feature: The cache must ensure requesters are served based on their priority (strict priority).

#### 📌 Test Case: Arbiter 1 fixed priority check

- **Feature Description:** Cache must arbitrate correctly between multiple clients.
- **Verification Goal:** 
  Purpose:  Arbiter shall always prioritise a high priority requester.  
  Method: A SV based model is used to do arbiter verification. The model is bind directly to arbiter instance in HPDcache RTL.  
  Link: hpdcache_fxarb_sva.sv  
- **Coverage Method:** Assertion Coverage

### Sub Feature: The cache must never simultaneously grant two requesters.

#### 📌 Test Case: Ready is one hot  (Abiter 1)

- **Verification Goal:** 
  Purpose: Arbiter shall except only one request at a time.  
  Method: A SV based model is used to do arbiter verification. The model is bind directly to arbiter instance in HPDcache RTL.  
  Link: hpdcache_fxarb_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Shcmoo 5 (hpdcache_req  (@NREQ= X) -> hpdcache_req (@NREQ=Y) )

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between 2 processor issuing a request at the same time.  If pys_indexed = 0, cache needs 2 cycle to read the address, 1 st cycle it (arbiter) accepts the request and second cycle is used to accept the virtual addresse.  
  If another processor makes a request at this second cycle, we have 2 requests coming at the same time. Cover the case where NOC ready always zero, one or random during the duration of assertion  
  Description:  
  hpdcache_req_X_valid (ld/st/cmos/amos) (p_i = 0/1) -> #N hpdcache_req_Y_valid (ld/st/cmos/amos)  
  N = [-5 : 5]  
  p_i = phys_indexed  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x2x4x4x2 =704  
- **Coverage Method:** Assertion Coverage

### Sub Feature: If neither of the following 5 conditions are true, and requestors are presenting requests, then a request must be accepted (1=RTAB not full, 2=no CMO fence in progress, 3=no uncacheable or atomic operation is in progress, 4=no load miss in stage 1 of the pipeline, 5=there is no load in stage 1 or the current request is not a store).

#### 📌 Test Case: Arbiter 1 work conserving check

- **Verification Goal:** 
  Purpose: Verify  if arbiter is ready, it shall always serve a request.  
  Method: A SV based model is used to do arbiter verification. The model is bind directly to arbiter instance in HPDcache RTL.  
  Link: hpdcache_fxarb_sva.sv  
- **Coverage Method:** Assertion Coverage

## Requirement 2.0: Requester interface must suport read + write operations.

### Sub Feature: The HPDCACHE_REQ_LOAD operation must trigger a read operation on the cache.

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests

- **Feature Description:** Requester interface must suport read + write operations.
- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Stimuli:   In this test 80% of the traffic is load and store.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests_in_region

- **Verification Goal:** 
  Same as 2.1.4.  
  Stimuli: This test performs  80% load store accesses within randomized address regions and the other accesses are fully random but within the regions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the MSHR and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Read only with large memory back pressure

- **Verification Goal:** 
  Purpose: The aim of this performance test is to show the benefits of having a MSHR on the performance.  
  Check the bandwidth of cached reads at the core interface of HPDcache when a read arrives with no inter request delay.  
  If memory response reply with a delay of 2*MSHR_SETS*MSHR_WAYS cycle(more realistic delay), the cache should be able to accept a read miss every third cycle.  
  Tarrget:    Load Performance maximising the use of MSHR  
  Scenario: Load only test  
  Stimulie: Test uses random access sequence.  
  Requirements:  
  Following condition are respected to get full performance  
  1. Load accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraints:  
  The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads in 2*3*NB_TXN cycles.  
  I would generate the address as above (cf 2.5.2)  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Mem Access Check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache makes a correct type of memory request on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: OP coverage (meaningfull)

- **Verification Goal:** 
  Purpose: Coverage that every (following) operation is followed by every operation on the same address followed by a load on the same addresse.  
  STORE  
  AMO_LR  
  AMO_SC  
  AMO_SWAP  
  AMO_ADD  
  AMO_AND  
  AMO_OR  
  AMO_XOR  
  AMO_MAX  
  AMO_MAXU  
  AMO_MIN  
  AMO_MINU  
  CMO  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: Bucket : 13x13 == 169  
- **Coverage Method:** Functional Coverage

### Sub Feature: The HPDCACHE_REQ_STORE operation must trigger a write operation on the cache.

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Stimuli:   In this test 80% of the traffic is load and store.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests_in_region

- **Verification Goal:** 
  Same as 2.1.4.  
  Stimuli: This test performs  80% load store accesses within randomized address regions and the other accesses are fully random but within the regions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write only with limited back pressure

- **Verification Goal:** 
  Purpose :  The aim of this performance test is to show the benefits of having a write buffer on the performance.  
  Check the bandwidth of cached write at the core interface of HPDcache when writes arrive with no inter request delay.  
  If memory response reply within a delay < NUM_WBUF cycles, the cache should be able to accept every write.  
  Target     : Write Performance  
  Scenario:  Write only test.  
  Stimuli   :  Test is derived from random access tests.  
  Requirement :  
  Following condition should be respected to get full performance  
  1. Store accesses are cacheable  
  2. There is not inter request delay @core interface  
  3. Memory response model reply within minimum (< NUM_WBUF cycles) delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_STORE, uncacheable=0.  
  The wbuf and rtab should be configured to get the maximum output. Following values are used:  
  m_cfg_wbuf_threshold = > 2 < HPDCACHE_WBUF_DIR_ENTRIES  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
  All writes are done at unique SET where no request is on the fly.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN stores in NB_TXN cycles.  
  In the case where write_buf_dir_entry, write_buf_data_entry < the memory write latency,  almost 3 times degrdation of performance is observed.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: OP coverage (meaningfull)

- **Verification Goal:** 
  Purpose: Coverage that every (following) operation is followed by every operation on the same address followed by a load on the same addresse.  
  STORE  
  AMO_LR  
  AMO_SC  
  AMO_SWAP  
  AMO_ADD  
  AMO_AND  
  AMO_OR  
  AMO_XOR  
  AMO_MAX  
  AMO_MAXU  
  AMO_MIN  
  AMO_MINU  
  CMO  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: Bucket : 13x13 == 169  
- **Coverage Method:** Functional Coverage

## Requirement 3.0: Requesters must provide valid requests.

### Sub Feature: The LSBits of the address (LOAD/STORE) must be aligned to the SIZE (naturally aligned).

#### 📌 Test Case: Byte enable is aligned with offset

- **Feature Description:** Requesters must provide valid requests.
- **Verification Goal:** Check if byte enable is aligned with req offset
- **Criteria Pass Fail:** prop_core_req_be_align

#### 📌 Test Case: Byte enable coverage

- **Verification Goal:** 
  Purpose: The purpose is to see the impact of byte enable disabled or enabled.  
  Coverage that each bit of the be signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Cover in the case of responses with or without error.  
  Sampling Event: Once a response is recieved  
  Buckets: HPDCACHE_REQ_DATA_WIDTH/2*2 + 2(extreme cases)  
- **Coverage Method:** Functional Coverage

### Sub Feature: The BE value from the requester must be naturally aligned to the request size (bits outside the range [2^SIZE…2^(SIZE+1)-1] must be zero. This implies the total number of 1 bits must be <= 2^SIZE.

#### 📌 Test Case: Size coverage

- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Buckets: 3 bits => 8 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage between the byte enable and the size

- **Verification Goal:** 
  Purpose: Cover that for each size, every byte enable is used.  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Bucket: ??  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage between the size, the word and op

- **Verification Goal:** 
  Purpose: Cover that for each size, every word and opcode.  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Bucket: ??  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Byte enable is aligned with size

- **Verification Goal:** Check if byte enable is aligned with requester size

## Requirement 4.0: Cache must relay requests correctly from requestors to memory interface and vice versa

### Sub Feature: The request address must be correctly transferred from requestors to the memory write interface.

#### 📌 Test Case: Mem Addr Check

- **Feature Description:** Cache must relay requests correctly from requestors to memory interface and vice versa
- **Verification Goal:** 
  Purpose: Check to see if hpdcache makes an access at correct address on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Offset coverage

- **Verification Goal:** 
  Purpose: Cover each value of address offset (least significant bit of target address)  
  The adress offset containts SET and cachline offset  
  Sampling Event: The coverage is sampled when a valid request is received.  
  Buckets: At least all sets of the cache=>  offset = i*CL_BYTES where i belongs to [0,HPDCACHE_SETS-1]  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Tag coverage

- **Verification Goal:** 
  Purpose: Cover the most significant bit of target address  
  Sampling Event: The coverage is sampled when a valid request is received.  
  Buckets:  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage between the word and op

- **Verification Goal:** 
  Purpose: Cross coverage between word and read/write  
  Buckets: 3 bits /read and write. 8*2 = 16 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage between the set and op

- **Verification Goal:** 
  Purpose: Cover that each operation is performed on each SET  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Bucket: HPDCACHE_SETS*14  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage between the set, the size and op

- **Verification Goal:** 
  Purpose: For each set cover that each operation is performed for each size.  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Bucket: ??  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage between the set, word and op

- **Verification Goal:** 
  Purpose: For each set cover that each operation is performaed for each word.  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Bucket: ?  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Address coverage

- **Verification Goal:** 
  Purpose: Coverage that each bit of the address signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Sampling Event: When a valid request is received.  
  Buckets: 2xHPDCACHE_PA_WIDTH + 2 (extreme cases)  
- **Coverage Method:** Functional Coverage

### Sub Feature: The request size and len must be correctly transferred from requestors to the memory write interface. The request size must be correct : READ_SIZE=log2(MEM_DATA_WIDTH/8) and READ_LEN=(CL_WIDTH/MEM_DATA_WIDTH)-1. MAX WRITE_SIZE=log2(WBUF_NWORDS*REQ_WORD_WIDTH /8) and WRITE_LEN=0

#### 📌 Test Case: Mem size check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache send correct size on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Mem len check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache send correct length on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Size coverage

- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Buckets: 3 bits => 8 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Length coverage

- **Verification Goal:** 
  Purpose: Coverage that each valid value of this signal was covered.  
  Sampling Event: When a valid request is received. Cover the case of zero load/write/amo  
  Buckets: 15, The current cofiguration only have 0x13,1, or 4 for read operation.  
  It supports only len = 0 for write/AMO operation.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Size coverage

- **Verification Goal:** 
  Purpose :Coverage of each value of this signal. Cover for each type of transaction.  
  Sampling Event: When a valid request is recieved.  
  Buckets: 3 bits => 8 x 13  
- **Coverage Method:** Functional Coverage

### Sub Feature: The BE masks must be correctly transferred from requesters to the memory write interface.

#### 📌 Test Case: Mem byte enable Check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache sends correct byte enable on NoC interface in case of a STORE/AMO.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Byte enable coverage

- **Verification Goal:** 
  Purpose: The purpose is to see the impact of byte enable disabled or enabled.  
  Coverage that each bit of the be signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Cover in the case of responses with or without error.  
  Sampling Event: Once a response is recieved  
  Buckets: HPDCACHE_REQ_DATA_WIDTH/2*2 + 2(extreme cases)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: TID coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of the tid signal was covered  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: HPDCACHE_TRANS_ID_WIDTH bits => 2**HPDCACHE_TRANS_ID_WIDTH buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Mem_be coverage

- **Verification Goal:** 
  Purpose: Coverage that every bit of the mem_be signal were enabled/disabled once  
  Sampling Event: When a valid response is recieved.  
  Buckets: HPDCACHE_MEM_DATA_WIDTH/8*2 + 2  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Multiple STORE (different byte enable) followed by LOAD

- **Verification Goal:** 
  Purpose: Cover the case where multiple store at the same address with random byte enable followed by a load at the same address. The purpose of this coverage is to stress the write buffer merging logic.  
  Description:  Cover the following sequence:  
  W@A BE1, W@A BE2 ….W@A Ben LOAD @A  
  BE1 !=BE2 != ... Ben  
  N = 2:8  
  buckets: 8  
- **Coverage Method:** Functional Coverage

### Sub Feature: The TID of the request must be correct: All Read TIDs are unique and all Write TIDs are unique

#### 📌 Test Case: Mem TID Check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache send correct TID on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: TID coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of the tid signal was covered  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: HPDCACHE_TRANS_ID_WIDTH bits => 2**HPDCACHE_TRANS_ID_WIDTH buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: TID coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of the tid signal was covered  
  Sampling Event: Cover when a valid request is received.  
  Buckets: 2**HPDCACHE_REQ_TRANS_ID_WIDTH buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: ID coverage

- **Verification Goal:** 
  Purpose: Coverage that each value of this signal was covered  
  Sampling Event: When a valid request is recieved.  
  Buckets HPDCACHE_MEM_ID_WIDTH bits => 2**HPDCACHE_MEM_ID_WIDTH buckets ( only if it is possible to cover all values with these buckets)  
- **Coverage Method:** Functional Coverage

### Sub Feature: The 'cacheable' indication must be transferred from requestors to the memory interface.

#### 📌 Test Case: Mem cacheable check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache send correct cacheable bit on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cache enable  ( cfig_cachectrl.E )

- **Verification Goal:** 
  Purpose: Cache Enable - When set to 0, all memory accesses are considered uncacheable  
  Method: Cover group in the test base  
  Sample Event: this coverage is sampled at the end of the test in report phase once the counters are read and verified.  
  Buckets: 2  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Uncacheable coverage

- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  CACHEABLE  
  UNCACHEABLE  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: 2  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage uncacheable and opcode

- **Verification Goal:** Cross coverage between the opcodes and the uncacheable signal. Buckets ?
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Command coverage

- **Verification Goal:** 
  Purpose: Coverage that each value of this signal was covered x cacheable  
  MEM_READ  
  MEM_WRITE  
  MEM_ATOMIC  
  RESERVED  
  Sampling Event: When a valid response is recieved.  
  Buckets: 3.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cacheable coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of this signal are covered  
  Sampling Event: When a valid request is recieved  
  Buckets: 2 buckets  
- **Coverage Method:** Functional Coverage

### Sub Feature: The request type must be relayed correctly

#### 📌 Test Case: Command coverage

- **Verification Goal:** 
  Purpose: Coverage that each value of this signal was covered x cacheable  
  MEM_READ  
  MEM_WRITE  
  MEM_ATOMIC  
  RESERVED  
  Sampling Event: When a valid response is recieved.  
  Buckets: 3.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Atomic coverage

- **Verification Goal:** 
  Purpose: Coverage that each value of this signal was covered  
  ATOMIC_ADD  
  ATOMIC_CLR  
  ATOMIC_SET  
  ATOMIC_EOR  
  ATOMIC_SMAX  
  ATOMIC_SMIN  
  ATOMIC_UMAX  
  ATOMIC_UMIN  
  ATOMIC_SWAP  
  RESERVED  
  ATOMIC_LDEX  
  ATOMIC_STEX  
  Sampling Event: When a valid response is recieved  
  Buckets: 11  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: OP coverage (meaningfull)

- **Verification Goal:** 
  Purpose: Coverage that every (following) operation is followed by every operation on the same address followed by a load on the same addresse.  
  STORE  
  AMO_LR  
  AMO_SC  
  AMO_SWAP  
  AMO_ADD  
  AMO_AND  
  AMO_OR  
  AMO_XOR  
  AMO_MAX  
  AMO_MAXU  
  AMO_MIN  
  AMO_MINU  
  CMO  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: Bucket : 13x13 == 169  
- **Coverage Method:** Functional Coverage

### Sub Feature: SID of the requester must be unique

#### 📌 Test Case: SID coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of the sid signal was covered  
  Sampling Event: Cover when a valid request is received.  
  Buckets: 2**HPDCACHE_REQ_SRC_ID_WIDTH buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: SID coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of the sid signal was covered  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: HPDCACHE_SRC_ID_WIDTHbits => 2**HPDCACHE_SRC_ID_WIDTH buckets  
- **Coverage Method:** Functional Coverage

### Sub Feature: Cache mus t send the correct data to the NoC interface in the case of STROE/AMOs

#### 📌 Test Case: Mem data Check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache send correct data on NoC interface in case of a STORE/AMO.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
  This check is performed only on the case where data merge does not happen  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Wdata coverage

- **Verification Goal:** 
  Purpose: Coverage that each bit of the wdata signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Sampling Event: When a the response of a write request is recieved.  
  Buckets: HPDCACHE_REQ_DATA_WIDTH*2 + 2(extreme cases).  
- **Coverage Method:** Functional Coverage

## Requirement 5.0: Must support multiple outstanding requests from each requestor.

### Sub Feature: Support for multiple outstanding read requests originating from one or multiple requestors.

#### 📌 Test Case: Number of outstanding Read transactions

- **Feature Description:** Must support multiple outstanding requests from each requestor.
- **Verification Goal:** 
  Purpose: The purpose of this coverage is to check the capacity of MSHR in the case of cacheable requests. Coverage on the number of outstanding read request from core. Max MSHR_SETS*MSHR_WAYS+ HPDCACHE_NUM_RTAB miss read and 1 non cacheable. Cover in the case of 1 ou  multiple requesters enabled.  
  Sapmling Event:  
  Buckets: HPDCACHE_NUM_RTAB+HPDCACHE_MSHR_SET*HPDCACHE_MSHR_WAYS  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the MSHR and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

### Sub Feature: Support for multiple outstanding write requests from one or multiple requestors

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write only with limited back pressure

- **Verification Goal:** 
  Purpose :  The aim of this performance test is to show the benefits of having a write buffer on the performance.  
  Check the bandwidth of cached write at the core interface of HPDcache when writes arrive with no inter request delay.  
  If memory response reply within a delay < NUM_WBUF cycles, the cache should be able to accept every write.  
  Target     : Write Performance  
  Scenario:  Write only test.  
  Stimuli   :  Test is derived from random access tests.  
  Requirement :  
  Following condition should be respected to get full performance  
  1. Store accesses are cacheable  
  2. There is not inter request delay @core interface  
  3. Memory response model reply within minimum (< NUM_WBUF cycles) delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_STORE, uncacheable=0.  
  The wbuf and rtab should be configured to get the maximum output. Following values are used:  
  m_cfg_wbuf_threshold = > 2 < HPDCACHE_WBUF_DIR_ENTRIES  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
  All writes are done at unique SET where no request is on the fly.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN stores in NB_TXN cycles.  
  In the case where write_buf_dir_entry, write_buf_data_entry < the memory write latency,  almost 3 times degrdation of performance is observed.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Number of outstanding Write transactions

- **Verification Goal:** 
  Purpose: The purpose of this coverage to check the capacity of write buffer in the case of cacheable requests. Coverage on the number of outstanding write request from core. Write MIN(WBUF_DIR_ENTRIES, WBUF_DATA_ENTRIES)  maximum cacheable and 1 non cacheable. Cover in the case of 1 or multiple requesters enabled.  
  Sapmling Event:  
  Buckets: HPDCACHE_NUM_RTAB+MIN(WBUF_DIR_ENTRIES, WBUF_DATA_ENTRIES)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Write OP, cache operation sequence different addresses

- **Verification Goal:** 
  Purpose: Cover that an operation at an address that follows a write operation on another address, has no impact on write operation  
  Description: Write op at address A (byte enable != 0)  followed by each of the following operation at address B (A!= B) followed by Load @ address A  
  AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU,CMO(CMO_FENCE, CMO_INVAL_LINE, CMO_INVAL_SET_WAY, CMO_INVAL_ALL, CMO_PREFETCH),LOAD,STORE, CSR READ, CSR WRITE  
  Write Op is one of the following:  
  "STORE  cached, STORE uncached, AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU, CSR WRITE"  
  Buckets: 20x14  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: CSR, cache operation sequence different addresses

- **Verification Goal:** 
  Purpose: Cover that an operation at an address that follows a CSR write operation, has no impact on CSR operation.  
  Description:  Cover the following sequence  
  CSR write @A followed by any operation followed by CSR read @A.  
  Any operation:  AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU,CMO(CMO_FENCE, CMO_INVAL_LINE, CMO_INVAL_SET_WAY, CMO_INVAL_ALL, CMO_PREFETCH),LOAD,STORE, CSR READ, CSR WRITE @B != A  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Write OP, N  other operation sequence different addresses

- **Verification Goal:** 
  Purpose: Cover that N operations at an address that follows a write operation on another address, has no impact on write operation.  
  Description:  Write op at address A (byte enable != 0)  followed by N operation @B!= A followed by Load @ address A  
  N = 1:100  
  Write Op is one of the following:  
  "STORE  cached, STORE uncached, AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU, CSR WRITE"  
  Buckets: 14x100 (may be too much buckets)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Write OP, cache operation sequence same addresses forbid amo mode

- **Verification Goal:** 
  Purpose: Cover the case where  an operations at an address, follows a write operation at same address  
  Description:  Write op at address A (byte enable != 0)  followed by each of the following operation at address A followed by Load @ address A  
  AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU,CMO(CMO_FENCE, CMO_INVAL_LINE, CMO_INVAL_SET_WAY, CMO_INVAL_ALL, CMO_PREFETCH),LOAD,STORE  
  Write Op is one of the following:  
  "STORE  cached, STORE uncached, AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU"  
  Buckets: 20x14  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Write OP, cache operation sequence same addresses repilcated amo mode (same as above sequence)

- **Verification Goal:** 
  Purpose:  
  Description:  Write op at address A (byte enable != 0)  followed by each of the following operation at address A followed by Load @ address A  
  AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU,CMO(CMO_FENCE, CMO_INVAL_LINE, CMO_INVAL_SET_WAY, CMO_INVAL_ALL, CMO_PREFETCH),LOAD,STORE  
  Write Op is one of the following:  
  "STORE  cached, STORE uncached, AMO_LR,AMO_SC,AMO_SWAP,AMO_ADD,AMO_AND,AMO_OR,AMO_XOR,AMO_MAX,AMO_MAXU,AMO_MIN,AMO_MINU"  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Multiple STORE (different byte enable) followed by LOAD

- **Verification Goal:** 
  Purpose: Cover the case where multiple store at the same address with random byte enable followed by a load at the same address. The purpose of this coverage is to stress the write buffer merging logic.  
  Description:  Cover the following sequence:  
  W@A BE1, W@A BE2 ….W@A Ben LOAD @A  
  BE1 !=BE2 != ... Ben  
  N = 2:8  
  buckets: 8  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of store merge

- **Verification Goal:** 
  Purpose: Cover the number of store merge  
  Sampling Event: When a store merge is observed  
  Method: The congestion tests contains the information regarding the store merge.  
  Buckets: ??  
- **Coverage Method:** Functional Coverage

### Sub Feature: Support for multiple outstanding read and write requests originating from one or multiple requestors.

#### 📌 Test Case: Number of outstanding read and write transactions

- **Verification Goal:** 
  Purpose: The purpose of this coverage is to check the capacity of MSHR in the case of cacheable requests. Coverage on the number of outstanding read request from core. Max MSHR_SETS*MSHR_WAYS+ HPDCACHE_NUM_RTAB miss read and 1 non cacheable. Cover in the case of 1 ou  multiple requesters enabled.  
  Sapmling Event:  
  Buckets: HPDCACHE_NUM_RTAB+HPDCACHE_MSHR_SET*HPDCACHE_MSHR_WAYS  

#### 📌 Test Case: Cross coverage outstanding transaction

- **Verification Goal:** 
  Purpose: Cross coverage between the number of outstanding read request and the number of outstanding write request  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Bucket: For READ: MSHR_SET (in the step of 5), For Write: Write Buf Entries (in the step of 5)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Schmoo 1 (hpdcache req  -> memory req interface)

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between a processor operation for a cache line and that cache line address appearing on a AXI request  transaction( from a previous request on the same line).  
  Cover 3 cases when NoC ready is zero, random, one during the whole duration of assertion.  
  Description:  
  hpdcache_req_1_valid (ld/st/cmos)  (p_i = 0/1)-> #N mem_req_2_valid  (ld/st)  
  N = [-5 : 5] @same tag/set  
  p_i = phys_indexed  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x3x2x2x3 = 396  
  Note: Covers following cases of on hold request  
  1. Cacheable LOAD or PREFETCH, and there is a hit on a pending miss (hit on the MSHR).  
  2. Cacheable LOAD or PREFETCH, there is a miss on the cache, and there is a hit (cacheline granularity) on an opened, pending or sent entry of the WBUF  
  3. Cacheable STORE, there is a miss on the cache, and there is a hit on a pending miss (hit on the MSHR)  
  6. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the miss handler FSM cannot send the read miss request  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Schmoo 2  (hpdcache req  -> memory rsp interface)

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between a processor operation for a cache line and that cache line address appearing on a AXI response  transaction( from a previous request on the same line).  
  Description:  
  hpdcache_req_1_valid(ld/st/cmos)  (p_i = 0/1) -> #N mem_resp_2_valid (ld/st) (error/non error)  
  N = [-5 : 5] @same tag/set  
  p_i = phys_indexed  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x3x2x2x2= 264  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Schmoo 3 (memory req interface -> memory rsp interface)

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between an axi operation for a cache line and that cache line address appearing on a AXI request  transaction( from a previous request on the same line).  
  Description:  
  mem_req_1_valid(ld/st) -> #N mem_resp_2_valid (ld/st) (error/non error)  
  N = [-5 : 5] @same tag/set  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x2x2x2 = 88  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Schmoo 4 (hpdcache req -> hpdcache rsp)

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between a processor for a cache line and that cache line address appearing on the response interface of hpdcache( from a previous request on the same line).  
  Description:  
  hpdcache_req_1_valid(ld/st/cmos)   (p_i = 0/1) -> #N hpdcache_rsp_2_valid (ld/st/cmos) (error/non error)  
  N = [-5 : 5] @same tag/set  
  p_i = phys_indexed  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x3x2x3x2 = 396  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Shcmoo 5 (hpdcache_req  (@NREQ= X) -> hpdcache_req (@NREQ=Y) )

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between 2 processor issuing a request at the same time.  If pys_indexed = 0, cache needs 2 cycle to read the address, 1 st cycle it (arbiter) accepts the request and second cycle is used to accept the virtual addresse.  
  If another processor makes a request at this second cycle, we have 2 requests coming at the same time. Cover the case where NOC ready always zero, one or random during the duration of assertion  
  Description:  
  hpdcache_req_X_valid (ld/st/cmos/amos) (p_i = 0/1) -> #N hpdcache_req_Y_valid (ld/st/cmos/amos)  
  N = [-5 : 5]  
  p_i = phys_indexed  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x2x4x4x2 =704  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: test_hpdcache_multiple_random_requests

- **Verification Goal:** 
  Purpose : Test to perform random accesses. The purpose is to have maximum coverage(functional and code).  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  
  Constraint      :  Every field of the transaction is randomized. Reserved op code is not used. The address are biased to more frequently select the extreme tag values(0x0, 0xFFFFF ….). The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_uncached

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Constraint       :  The field uncacheable is constrained  to have only uncacheable accesses. And is added for coverage.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Stimuli:   In this test 80% of the traffic is load and store.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_in_region

- **Verification Goal:** 
  Purpose : Test to perform random accesses within randomized address  regions. The purpose is to provoke hits and conflicts keeping stimulus relatively random.  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  The regions are generated using memory partition class from cv_dv_utils. The regions are random size but some are small which provokes hits and conflicts.  
  The sequence choses one region randomly for a SEED.  
  Constraint       :  Every field of the transaction is randomized. Reserved op code is not used. The addresses are generated within the region. The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests_in_region

- **Verification Goal:** 
  Same as 2.1.4.  
  Stimuli: This test performs  80% load store accesses within randomized address regions and the other accesses are fully random but within the regions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write(30%) Read(70% ) with no memory back pressure

- **Verification Goal:** 
  Purpose : Check the bandwidth of cached reads (70%) and cached writes(30%) at the core interface of HPDcache when reads and writes arrive with no inter request delay.  
  Target     : Read and Write Performance  
  Scenario:  Test is constraint to have 70% cacheable read and 30% cacheable  write.  
  Stimuli   :  Test is derived from random access tests.  
  Requirements:  
  Following condition are respected to get full performance  
  1. Load/Store accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_LOAD(70%), HPDCACHE_REQ_STORE(30%). Uncacheable = 0.  
  5. The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_wbuf_threshold = > 2  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads/stores in 3*NB_TXN cycles.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

## Requirement 6.0: Can provide 1 to 64 bytes of a cacheline per cycle

### Sub Feature: Any given requester can access 1 to 64 bytes of a cacheline per cycle

#### 📌 Test Case: Size coverage

- **Feature Description:** Can provide 1 to 64 bytes of a cacheline per cycle
- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Buckets: 3 bits => 8 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Mem_data coverage

- **Verification Goal:** 
  Purpose: Coverage that each bit of the mem_data signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Sampling Event: When a valid response is recieved.  
  Buckets: HPDCACHE_MEM_DATA_WIDTH*2 + 2  
- **Coverage Method:** Functional Coverage

## Requirement 7.0: Cache must provide correct responses to requesters.

### Sub Feature: Provide 1 to 64 bytes of data, based on request size.

#### 📌 Test Case: Size coverage

- **Feature Description:** Cache must provide correct responses to requesters.
- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Buckets: 3 bits => 8 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Rdata coverage

- **Verification Goal:** 
  Purpose: Coverage that each bit of the Rdata signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Sampling Event: Cover when a valid LOAD/AMO/LR response is received.  
  Buckes: HPDCACHE_REQ_DATA_WIDTH*2 buckets  + 2 (extreme values)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Last coverage

- **Verification Goal:** 
  Purpose:Coverage that each values of this signal are covered  
  Bucket: 2 buckets  
  Samlng Event: Sample at the time of NoC Reponse . Sample when the NoC response is witout an error. Sample at the time of NoC Reponse . Sample when the NoC response is witout an error.  
- **Coverage Method:** Functional Coverage

### Sub Feature: The TID of the response must correspond to the TID of the original request.

#### 📌 Test Case: Unsolicited Response

- **Verification Goal:** 
  Purpose: Check if cache send an unsolicited response. Cache shall ignore this unsolicited response.  
  Method: The memory response model is used to insert unsolicited responses.  
  NOTE: Not sure how this test works. If the memory send a response with no matching request, the behavior of the HPDcache is somehow undefined. There is no countermeasure for unsolicited responses. If it is a read response, with an ID different than '1 (all bits to 1), the HPDcache will probably forward a response to the core. If all bits of the ID are set to 1, the HPDcache will forward the response on the next uncacheable request  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

### Sub Feature: The SID of the response must correspond to the SID of the original requester.

#### 📌 Test Case: Unsolicited Response

- **Verification Goal:** 
  Purpose: Check if cache send an unsolicited response. Cache shall ignore this unsolicited response.  
  Method: The memory response model is used to insert unsolicited responses.  
  NOTE: Not sure how this test works. If the memory send a response with no matching request, the behavior of the HPDcache is somehow undefined. There is no countermeasure for unsolicited responses. If it is a read response, with an ID different than '1 (all bits to 1), the HPDcache will probably forward a response to the core. If all bits of the ID are set to 1, the HPDcache will forward the response on the next uncacheable request  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: SID coverage

- **Verification Goal:** 
  Purpose: Coverage that every value of the sid signal was covered  
  Sampling Event: Cover when a valid request is received.  
  Buckets: 2**HPDCACHE_REQ_SRC_ID_WIDTH buckets  
- **Coverage Method:** Functional Coverage

### Sub Feature: The cache must always provide coherent data if error is not set.

#### 📌 Test Case: Data Response Check

- **Verification Goal:** 
  Purpose: Check if HPDcache responds with a correct data  
  Check Data response in following cases  
  1. LOAD  
  2. SC  
  3. AMO  
  This check is ignored if data was corrupted by a previous error response from memory and is not overwritten by a fresh data. This line is considered to be corrupted.  
  This check is performed when the cache response is received  
  Method:  A memory shadow is mantained in the HPDcache SB, which is used to predict the correct responses.  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Data coverage

- **Verification Goal:** 
  Purpose: Coverage that each bit of the data signal was enable/disable once, and that the extreme value ( only '0 and only '1) are covered with 1 bucket each.  
  Bucket: HPDCACHE_MEM_DATA_WIDTH*2 + 2  
  Sampling Event: Sample at the time of NoC Reponse . Sample when the NoC response is witout an error.  
- **Coverage Method:** Functional Coverage

### Sub Feature: The cache must always provide a  response when signal need_rsp is true for a request.

#### 📌 Test Case: Need_rsp coverage

- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Sampling Event: The coverage is sampled when a valid request is received.  
  Buckets: 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cross coverage need_rsp and opcode (load/store)

- **Verification Goal:** 
  Purpose: Cross coverage between the opcodes LOAD/STORE and need_rsp signal.  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: Buckets = 4  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Data Response Check

- **Verification Goal:** 
  Purpose: Check if HPDcache responds with a correct data  
  Check Data response in following cases  
  1. LOAD  
  2. SC  
  3. AMO  
  This check is ignored if data was corrupted by a previous error response from memory and is not overwritten by a fresh data. This line is considered to be corrupted.  
  This check is performed when the cache response is received  
  Method:  A memory shadow is mantained in the HPDcache SB, which is used to predict the correct responses.  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

### Sub Feature: The cache must never provide a  response when signal need_rsp is false for a request.

#### 📌 Test Case: Unsolicited Response

- **Verification Goal:** 
  Purpose: Check if cache send an unsolicited response. Cache shall ignore this unsolicited response.  
  Method: The memory response model is used to insert unsolicited responses.  
  NOTE: Not sure how this test works. If the memory send a response with no matching request, the behavior of the HPDcache is somehow undefined. There is no countermeasure for unsolicited responses. If it is a read response, with an ID different than '1 (all bits to 1), the HPDcache will probably forward a response to the core. If all bits of the ID are set to 1, the HPDcache will forward the response on the next uncacheable request  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

### Sub Feature: If an error occurs during a response, the cache must respond with the signal error is set for that response except in the case of caceahble write.

#### 📌 Test Case: Error Response Check

- **Verification Goal:** 
  Purpose :  The error responses are generated correctly.  
  Description: The error is inserted on the NoC side by memory response model. In the case of error, the cache send an error response. Except in the case of store  
  This check if performed when the cache response is received  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Load with Error response

- **Verification Goal:** 
  Purpose: Cover that a Load (miss) with an error response (memory)  is followed by a LOAD/AMO (no rsp ) on the same line. Cover for cache and uncached  
  transactions.  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid load is recieved.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Error coverage

- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Sampling Event: Cover when a valid request is received.  
  Buckets:  bit => 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Error coverage

- **Verification Goal:** 
  Purpose: Error reponse from NoC.  
  Coverage that each values of this signal are covered  
  Buckets: 2 buckets  
  Sampling Event: Sample at the time of NoC Reponse  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: W_is_atomic coverage

- **Verification Goal:** 
  Purpose: Coverage that each values of this signal are covered  
  Bucket: 2 buckets  
  Sampling Event: Sample at the time of NoC Reponse . Sample when the NoC response is witout an error.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: W_error coverage

- **Verification Goal:** 
  Purpose: Coverage that each values of this signal are covered  
  Bucket:  
  MEM_RESP_OK  
  MEM_RESP_NOK  
  (There is two possibles value that are not defined : are they RESERVED ?)  
  Sampling Event: Sample at the time of NoC Reponse . Sample when the NoC response is witout an error.  
- **Coverage Method:** Functional Coverage

### Sub Feature: The cache must operate correctly, even if requesters re-use TID values for multiple, in-flight requests.

#### 📌 Test Case: Features not part of test plan


## Requirement 8.0: The cache must handle cacheable and non-cacheable requests.

### Sub Feature: The cache determines whether a given requets is cacheable based on the UNCACHEABLE signal.

#### 📌 Test Case: Uncacheable coverage

- **Feature Description:** The cache must handle cacheable and non-cacheable requests.
- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  CACHEABLE  
  UNCACHEABLE  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: 2  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: test_hpdcache_multiple_random_requests

- **Verification Goal:** 
  Purpose : Test to perform random accesses. The purpose is to have maximum coverage(functional and code).  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  
  Constraint      :  Every field of the transaction is randomized. Reserved op code is not used. The address are biased to more frequently select the extreme tag values(0x0, 0xFFFFF ….). The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_directed_addr

- **Verification Goal:** 
  Purpose :  Test to provoke the eviction at regular interval in between many hits.  
  Target     :  This test stresses the eviction mechanism.  
  Scenario:  In this test, one set is selected randomly at the beginning of the test.  Then NWAYS + 1 random tags are selected within the selected set. Random loads  and stores are performed on these preselected {tag, set}. Normally we should observe many hits with misses (because of the evictions) as the number of tags exceed the NWAYS by 1.  
  Stimuli :  The test runs hpdcache_multiple_directed_addr sequence which is driven from hpdcache_single_directed_addr.  
  Requirement :  This test  respects the constraints related to hpdcache protocol  
  Constraint       :  Every field of the transaction is randomized except set, address and uncacheable (always 0 -> cacheable).  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_directed_addr_bPLRU_prediction

- **Verification Goal:** 
  Purpose:  The purpose of this the test is to check the PLRU eviction algorithm using a black box approach.  
  Target:  PLRU algorithm  
  Scenario:  To avoid temporal conflicts between request and refill response which cannot be predicted, in this test each request is sent every N( = 15) cycles and the memory response model is configured to respond with zero delay. We require that the response from the previous request is received before the next request is issued. Otherwise it is impossible to predict the PLRU behavior using a black box approach.  
  Stimuli :  The sequence is derived from 1.2.1  
  Requirement :  This test  respects the constraints related to hpdcache protocol. This test enables a UVM based model in the SB which  does the black box prediction of the PLRU under a limited set of stimulus which is respected by this test.  
  Constraint       :  Every field of the transaction is randomized except Set, address, uncacheable (always 0 -> cacheable) and inter request delay. Memory response model is configured to respond with zero delay.  
  Note:  We note that the environment also has a SV based PLRU model which is bind directly to the memory control module to do the exact prediction of the PLRU using the signals from memory control module (white box assertion based checking).   In the UVM based model, the PLRU prediction takes into accoun the type of transactions.  
- **Criteria Pass Fail:** The TB has UVM based PLRU model which flags a UVM_ERROR in case PLRU algorithm is not respected. A tag directory is maintained which helps predict hit and miss in this particular scenario.
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

### Sub Feature: The requestor must be consistent regarding the cachability of a line in the cache.

#### 📌 Test Case: Features not part of test plan


## Requirement 9.0: Provide a memory model compliant with RISC-V Weak Memory Ordering (RVWMO)

### Sub Feature: If two transactions have overlapping address ranges, then they must be comitted in the order they were issued.

#### 📌 Test Case: For address-overlapping transactions, the cache guarantees that these are committed in the order in which they are consumed from the requesters.

- **Feature Description:** Provide a memory model compliant with RISC-V Weak Memory Ordering (RVWMO)
- **Verification Goal:** 
  Purpose: At any given time, There can never be two inflight requests (read or writes) with overlapping addresses. By the way, the addresses do not need to be identical. The addressed segment cannot overlap: (A.address, A.address + 2**A.size) do not overlap with (B.address, B.address + 2**B.size)  
  one assertion per byte  
  Method: System Verilog Temporal Assertion check  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

### Sub Feature: If two transactions do not have overlapping address ranges, there is no constraint on the order they are committed.

#### 📌 Test Case: test_hpdcache_multiple_random_requests

- **Verification Goal:** 
  Purpose : Test to perform random accesses. The purpose is to have maximum coverage(functional and code).  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  
  Constraint      :  Every field of the transaction is randomized. Reserved op code is not used. The address are biased to more frequently select the extreme tag values(0x0, 0xFFFFF ….). The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

### Sub Feature: If a cache-able READ or pre-fetch misses in the cache and hits in the write buffer, the write operation must complete to memory before the READ is processed.

#### 📌 Test Case: READ WRITE at the same address with Back Pressure

- **Verification Goal:** 
  We cannot have same addresse at the same time in the MSHR and Write Buffer  
  in this test aim to fill write buffer and mshr before RTAB is full.  

### Sub Feature: If a cache-able STORE misses on the cache but matches a pending miss, the pending miss must complete before issuing the store.

#### 📌 Test Case: READ WRITE at the same address with Back Pressure

- **Verification Goal:** 
  We cannot have same addresse at the same time in the MSHR and Write Buffer  
  in this test aim to fill write buffer and mshr before RTAB is full.  

### Sub Feature: If cacheable operation T1 (read or write) is issued before T2 (read or write) and T1 overlaps T2 then T1 must be issued on the memory interface before T2. This should, of course, be true for the specific cases when T1 and T2 are both writes, T1 and T2 are both reads.

#### 📌 Test Case: READ WRITE at the same address with Back Pressure

- **Verification Goal:** 
  We cannot have same addresse at the same time in the MSHR and Write Buffer  
  in this test aim to fill write buffer and mshr before RTAB is full.  

## Requirement 10.0: Provide an 5-channel interface to memory.

### Sub Feature: Provide a memory read request interface with ready/valid handshake

#### 📌 Test Case: Ready Valid Protocol  (request)

- **Feature Description:** Provide an 5-channel interface to memory.
- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write interfaces (data and meta data).  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

### Sub Feature: Provide a memory read response interface with ready/valid handshake

#### 📌 Test Case: Ready Valid Protocol  (response)

- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write response interfaces  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

### Sub Feature: Provide a memory write attribute request channel with ready/valid handshake

#### 📌 Test Case: Ready Valid Protocol  (request)

- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write interfaces (data and meta data).  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

### Sub Feature: Provide a memory write-data request channel with ready/valid handshake

#### 📌 Test Case: Ready Valid Protocol  (request)

- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write interfaces (data and meta data).  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

### Sub Feature: Provide a memory write response channel with ready/valid handshake

#### 📌 Test Case: Ready Valid Protocol  (response)

- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write response interfaces  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

## Requirement 11.0: Respect the ready/valid protocol on all requester and memory interfaces

### Sub Feature: Once VALID is set to '1' it must stay at '1' until RDY goes to '1' and the transfer occurs.

#### 📌 Test Case: Ready Valid Protocol  (request)

- **Feature Description:** Respect the ready/valid protocol on all requester and memory interfaces
- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write interfaces (data and meta data).  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

#### 📌 Test Case: Ready Valid Protocol  (response)

- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol for read and write response interfaces  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserted  
  Sampling Event: When a valid request is recieved.  
  Buckets: Total 6 scenarios for 2 different interfaces.  

## Requirement 12.0: The cache must support 11 AMO operations.

### Sub Feature: HPDCACHE_REQ_AMO_LR 
HPDCACHE_REQ_AMO_SC 
HPDCACHE_REQ_AMO_SWAP 
HPDCACHE_REQ_AMO_ADD 
HPDCACHE_REQ_AMO_AND 
HPDCACHE_REQ_AMO_OR 
HPDCACHE_REQ_AMO_XOR 
HPDCACHE_REQ_AMO_MAX 
HPDCACHE_REQ_AMO_MAXU 
HPDCACHE_REQ_AMO_MIN 
HPDCACHE_REQ_AMO_MINU

#### 📌 Test Case: test_hpdcache_multiple_amo_lr_sc_requests

- **Feature Description:** The cache must support 11 AMO operations.
- **Verification Goal:** 
  Purpose: The aim of this test is to test Load Reserved (LR)/Store Conditional (SC) sequences. The goal is to test all possible conditions where LR/SC fails or passes. A coverage item is added to cover all possible combination. A sequence of LR/SC mixed with LOAD/STORE/AMOS/CMOS are run. Most(90%) of the accesses are done at the same address.  
  Target: Load Reserved and Store Conditional Mechanism  
  Scenario:  The hpdcache_single_lr_sc_request runs a sequence with following constraints:  
  FOR 1 to (random 10 or 15 )  
  m_req_addr dist { same_addr := (50 a 100), random_addr := (100 - same_addr)};  
  m_req_op   dist { hpdcache_REQ_AMO_LR := 40, HPDCACHE_REQ_AMO_SC := 40,  
  hpdcache_REQ_LOAD     := 11,  
  hpdcache_REQ_AMO_SWAP := 1,  
  hpdcache_REQ_STORE  := 1,  
  hpdcache_REQ_AMO_ADD  := 1,  
  hpdcache_REQ_AMO_AND  := 1,  
  hpdcache_REQ_AMO_OR   := 1,  
  hpdcache_REQ_AMO_XOR  := 1,  
  hpdcache_REQ_AMO_MAX  := 1,  
  hpdcache_REQ_AMO_MAXU := 1,  
  hpdcache_REQ_AMO_MIN  := 1,  
  hpdcache_REQ_AMO_MINU := 1  
  hpdcache_REQ_CMO := 1  
  END  
  Stimuli: The sequence used is hpdcache_multiple_amo_lr_sc_requests which is driven from hpdcache_single_lr_sc_request.  
  Requirement :  This test  respects the constraints related to hpdcache protocol.  
  Constraint:  Every field of the transaction is randomized except address.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: OP coverage (meaningfull)

- **Verification Goal:** 
  Purpose: Coverage that every (following) operation is followed by every operation on the same address followed by a load on the same addresse.  
  STORE  
  AMO_LR  
  AMO_SC  
  AMO_SWAP  
  AMO_ADD  
  AMO_AND  
  AMO_OR  
  AMO_XOR  
  AMO_MAX  
  AMO_MAXU  
  AMO_MIN  
  AMO_MINU  
  CMO  
  Sampling Event: The coverage is sampled when a valid request is recieved.  
  Buckets: Bucket : 13x13 == 169  
- **Coverage Method:** Functional Coverage

### Sub Feature: The HPDC always treats LR/SC operations with a  size of 8 bytes, aligned to 8-byte boundary.

#### 📌 Test Case: Scenarios to cover LR/SC 1

- **Verification Goal:** 
  Purpose: Cover following scenerio of LR/SC  
  LR(@A(Address), @W(word(8 bytes)) -> SC(@A, @W) -> LOAD(@A, @W) : SC Pass  
  LR(@A(Address), @W(word) -> SC(@A, @W1 != W) -> LOAD(@A, @W) -> LOAD(@A, @W1) -> SC Fail  
  LR(@A(Address), @W(word) -> SC(@A1 != A, X) -> LOAD(@A) -> LOAD(@A1) -> SC Fail  
  LR(@A(Address), @W(word) -> LOAD (@A, @W) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> LOAD (@A1 != A) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A, @W1 != W) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A1) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A) -> SC(@A, @W) -> LOAD(@A)  -> SC Fail  
  Sampling Event: When a SC pass fail is detected by SB.  
  Buckets:  8  
- **Coverage Method:** Assertion Coverage

### Sub Feature: If the LR is not aligned to an 8-byte boundary, the reservation set can span two 8-byte blocks.

#### 📌 Test Case: Scenarios to cover LR/SC 1

- **Verification Goal:** 
  Purpose: Cover following scenerio of LR/SC  
  LR(@A(Address), @W(word(8 bytes)) -> SC(@A, @W) -> LOAD(@A, @W) : SC Pass  
  LR(@A(Address), @W(word) -> SC(@A, @W1 != W) -> LOAD(@A, @W) -> LOAD(@A, @W1) -> SC Fail  
  LR(@A(Address), @W(word) -> SC(@A1 != A, X) -> LOAD(@A) -> LOAD(@A1) -> SC Fail  
  LR(@A(Address), @W(word) -> LOAD (@A, @W) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> LOAD (@A1 != A) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A, @W1 != W) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A1) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A) -> SC(@A, @W) -> LOAD(@A)  -> SC Fail  
  Sampling Event: When a SC pass fail is detected by SB.  
  Buckets:  8  
- **Coverage Method:** Assertion Coverage

### Sub Feature: The HPDC supports a single reservation set. If multiple AMO_LR operations are performed, the reservation set is determined by the last one.

#### 📌 Test Case: Scenarios to cover LR/SC 2 (multiple LR)

- **Verification Goal:** 
  Same as 9.1.2  
  In the case there muliple LR at different addresse before LR@A, @W  
  HPDcache shall take into account only the last reservation set.  

### Sub Feature: An SC operation is forwarded to memory IFF the addressed bytes overlap the reservation set.

#### 📌 Test Case: Mem STEX

- **Verification Goal:** 
  Purpose: Check to verify if SC is passed to memory interface IFF SC is a pass.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Coverage Method:** Functional Coverage

### Sub Feature: An SC operation must clear the reservation, whether it succeeds, or not.

#### 📌 Test Case: Scenarios to cover LR/SC 2 (multiple SC)

- **Verification Goal:** 
  Same as 9.1.2  
  In the case there mulipleSC @A, @W following LR operation @A, @W  
  HPDcache shall pass only the first SC operation if it is a pass  

### Sub Feature: If a SC accesses a subset of the space of the reservation set, the store  operation is still forwarded to the memory.

#### 📌 Test Case: Scenarios to cover LR/SC 1

- **Verification Goal:** 
  Purpose: Cover following scenerio of LR/SC  
  LR(@A(Address), @W(word(8 bytes)) -> SC(@A, @W) -> LOAD(@A, @W) : SC Pass  
  LR(@A(Address), @W(word) -> SC(@A, @W1 != W) -> LOAD(@A, @W) -> LOAD(@A, @W1) -> SC Fail  
  LR(@A(Address), @W(word) -> SC(@A1 != A, X) -> LOAD(@A) -> LOAD(@A1) -> SC Fail  
  LR(@A(Address), @W(word) -> LOAD (@A, @W) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> LOAD (@A1 != A) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A, @W1 != W) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A1) -> SC(@A, @W) -> LOAD(@A)  -> SC Pass  
  LR(@A(Address), @W(word) -> STORE/AMO (@A) -> SC(@A, @W) -> LOAD(@A)  -> SC Fail  
  Sampling Event: When a SC pass fail is detected by SB.  
  Buckets:  8  
- **Coverage Method:** Assertion Coverage

### Sub Feature: All atomic operations must be sent to the write-request interface.

#### 📌 Test Case: Mem Access Check

- **Verification Goal:** 
  Purpose: Check to see if hpdcache makes a correct type of memory request on NoC interface.  
  Method: This check is performed when a new memory request is observed on the NoC interface  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

### Sub Feature: The cache must process two responses from the memory for each atomic operation : old_data on read response channel and write acknowledge on memory write response channel.

#### 📌 Test Case: Mem AMO check

- **Verification Goal:** 
  Purpose: Check to verify if AMO reqest on memory write interface has 2 responses: old_data on read response channel and write acknowledge on memory write response channel.  
  Method: This check is performed when a new memory respones(read and write) are observed on the NoC interface  
- **Coverage Method:** Functional Coverage

### Sub Feature: HPDCACHE_REQ_AMO_LR 
HPDCACHE_REQ_AMO_SC 
HPDCACHE_REQ_AMO_SWAP 
HPDCACHE_REQ_AMO_ADD 
HPDCACHE_REQ_AMO_AND 
HPDCACHE_REQ_AMO_OR 
HPDCACHE_REQ_AMO_XOR 
HPDCACHE_REQ_AMO_MAX 
HPDCACHE_REQ_AMO_MAXU 
HPDCACHE_REQ_AMO_MIN 
HPDCACHE_REQ_AMO_MINU

#### 📌 Test Case: Error Response Check

- **Feature Description:** The cache must support 11 AMO operations.
- **Verification Goal:** 
  Purpose :  The error responses are generated correctly.  
  Description: The error is inserted on the NoC side by memory response model. In the case of error, the cache send an error response. Except in the case of store  
  This check if performed when the cache response is received  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

### Sub Feature: In the case of the STEX operation, the write acknowledge channel indicates if the write was atomic (mem_resp_w_is_atomic). The HPDC returns the status on the signals HPDCACHE_RSP_DATA (0x0000_0000 = success, 0x0000_0001 = failure). This value is zero extended, if the requested size >= 8 bytes , and replicated if there is more than one word.

#### 📌 Test Case: SC Data Check

- **Verification Goal:** 
  Purpose: Check if Store Conditional responds with the correct data  
  Description: In the case of SC FAIL/PASS, data response is checked. The modeling of LR/SC is done in SB.  
  In case of SC PASS: Data is 0  
  In case of SC FAIL: Data > 0  
  This check is performed when the cache response is received  
  Method: SB predicts the behaviour of SC response  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

### Sub Feature: In case of a hit in the cache on a SC, and that the STEX is atomic, the cache updates the local data.

#### 📌 Test Case: SC Data Check

- **Verification Goal:** 
  Purpose: Check if Store Conditional responds with the correct data  
  Description: In the case of SC FAIL/PASS, data response is checked. The modeling of LR/SC is done in SB.  
  In case of SC PASS: Data is 0  
  In case of SC FAIL: Data > 0  
  This check is performed when the cache response is received  
  Method: SB predicts the behaviour of SC response  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

## Requirement 13.0: Requester interface must support CMO and fence operations.

### Sub Feature: Support for CMO operation must be compatible with definitions in RISC-V CMO standard.

#### 📌 Test Case: Features not part of test plan

- **Feature Description:** Requester interface must support CMO and fence operations.

### Sub Feature: Must support a memory write fence (HPDCACHE_CMO_FENCE). This operation must ensure that all open entries in the write buffer are immediately closed. No new requests are accepted from any requester until all pending write requests have been acknowledged on the NoC interface.

#### 📌 Test Case: Cross coverage opcode (meaningfull CMO) and size

- **Verification Goal:** 
  Purpose: Cross coverage between the opcode CMO and the size signal to cover each CMO operation. Cover the following sequence with every CMO transaction. (Write/Read(cacheable) -> CMO -> Read). The whole sequence should be on the same address.  This should be covered for each line.  
  CMO_FENCE  
  CMO_INVAL_INLINE  
  CMO_INVAL_ALL  
  CMO_PREFETCH  
  Sampling Event: The coverage is sampled when a valid read request after CMO is recieved.  
  Buckets: 2x4*HPDCACHE_SETS = 8*HPDCACHE_SETS  
- **Coverage Method:** Functional Coverage

### Sub Feature: Must support a CMO to invalidate a given physical address (CMO_INVAL_NLINE)

#### 📌 Test Case: Cross coverage opcode (meaningfull CMO) and size

- **Verification Goal:** 
  Purpose: Cross coverage between the opcode CMO and the size signal to cover each CMO operation. Cover the following sequence with every CMO transaction. (Write/Read(cacheable) -> CMO -> Read). The whole sequence should be on the same address.  This should be covered for each line.  
  CMO_FENCE  
  CMO_INVAL_INLINE  
  CMO_INVAL_ALL  
  CMO_PREFETCH  
  Sampling Event: The coverage is sampled when a valid read request after CMO is recieved.  
  Buckets: 2x4*HPDCACHE_SETS = 8*HPDCACHE_SETS  
- **Coverage Method:** Functional Coverage

### Sub Feature: Must support a CMO to invalidate the entire cache (CMO_INVAL_ALL)

#### 📌 Test Case: Cross coverage opcode (meaningfull CMO) and size

- **Verification Goal:** 
  Purpose: Cross coverage between the opcode CMO and the size signal to cover each CMO operation. Cover the following sequence with every CMO transaction. (Write/Read(cacheable) -> CMO -> Read). The whole sequence should be on the same address.  This should be covered for each line.  
  CMO_FENCE  
  CMO_INVAL_INLINE  
  CMO_INVAL_ALL  
  CMO_PREFETCH  
  Sampling Event: The coverage is sampled when a valid read request after CMO is recieved.  
  Buckets: 2x4*HPDCACHE_SETS = 8*HPDCACHE_SETS  
- **Coverage Method:** Functional Coverage

### Sub Feature: Must support a CMO to prefetch a given cachline (CMO_PREFETCH)

#### 📌 Test Case: Cross coverage opcode (meaningfull CMO) and size

- **Verification Goal:** 
  Purpose: Cross coverage between the opcode CMO and the size signal to cover each CMO operation. Cover the following sequence with every CMO transaction. (Write/Read(cacheable) -> CMO -> Read). The whole sequence should be on the same address.  This should be covered for each line.  
  CMO_FENCE  
  CMO_INVAL_INLINE  
  CMO_INVAL_ALL  
  CMO_PREFETCH  
  Sampling Event: The coverage is sampled when a valid read request after CMO is recieved.  
  Buckets: 2x4*HPDCACHE_SETS = 8*HPDCACHE_SETS  
- **Coverage Method:** Functional Coverage

## Requirement 14.0: Minimize number of internal RAMs activated in parallel

#### 📌 Test Case: Check that only one memory cuts is accessed/consulted at a time (or for each request?)

- **Feature Description:** Minimize number of internal RAMs activated in parallel
- **Verification Goal:** 
  Purpose: Reduced energy consumption by limiting the number of RAMs consulted per request  
  Method: System verilog assertion onehot  
- **Coverage Method:** Assertion Coverage

## Requirement 15.0: Enforce a non-allocate, write-through policy.

### Sub Feature: All write requests from requestors must appear on the memory interface (possibly after requests are coallesced).

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Feature Description:** Enforce a non-allocate, write-through policy.
- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write only with limited back pressure

- **Verification Goal:** 
  Purpose :  The aim of this performance test is to show the benefits of having a write buffer on the performance.  
  Check the bandwidth of cached write at the core interface of HPDcache when writes arrive with no inter request delay.  
  If memory response reply within a delay < NUM_WBUF cycles, the cache should be able to accept every write.  
  Target     : Write Performance  
  Scenario:  Write only test.  
  Stimuli   :  Test is derived from random access tests.  
  Requirement :  
  Following condition should be respected to get full performance  
  1. Store accesses are cacheable  
  2. There is not inter request delay @core interface  
  3. Memory response model reply within minimum (< NUM_WBUF cycles) delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_STORE, uncacheable=0.  
  The wbuf and rtab should be configured to get the maximum output. Following values are used:  
  m_cfg_wbuf_threshold = > 2 < HPDCACHE_WBUF_DIR_ENTRIES  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
  All writes are done at unique SET where no request is on the fly.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN stores in NB_TXN cycles.  
  In the case where write_buf_dir_entry, write_buf_data_entry < the memory write latency,  almost 3 times degrdation of performance is observed.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

## Requirement 16.0: Minimize latency using a write-buffer to mask write acknowledgement delay.

### Sub Feature: HPDcache uses write buffer to store a write request in writer buffer to avoid memory response delay

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Feature Description:** Minimize latency using a write-buffer to mask write acknowledgement delay.
- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write only with limited back pressure

- **Verification Goal:** 
  Purpose :  The aim of this performance test is to show the benefits of having a write buffer on the performance.  
  Check the bandwidth of cached write at the core interface of HPDcache when writes arrive with no inter request delay.  
  If memory response reply within a delay < NUM_WBUF cycles, the cache should be able to accept every write.  
  Target     : Write Performance  
  Scenario:  Write only test.  
  Stimuli   :  Test is derived from random access tests.  
  Requirement :  
  Following condition should be respected to get full performance  
  1. Store accesses are cacheable  
  2. There is not inter request delay @core interface  
  3. Memory response model reply within minimum (< NUM_WBUF cycles) delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_STORE, uncacheable=0.  
  The wbuf and rtab should be configured to get the maximum output. Following values are used:  
  m_cfg_wbuf_threshold = > 2 < HPDCACHE_WBUF_DIR_ENTRIES  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
  All writes are done at unique SET where no request is on the fly.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN stores in NB_TXN cycles.  
  In the case where write_buf_dir_entry, write_buf_data_entry < the memory write latency,  almost 3 times degrdation of performance is observed.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

## Requirement 17.0: Provide a memory-mapped CSR configuration interface

### Sub Feature: Provide CSRs for configuration

#### 📌 Test Case: test_reg_bit_bash

- **Feature Description:** Provide a memory-mapped CSR configuration interface
- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg access sequence

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg hw reset register test

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: cfig_version.MinorID

- **Verification Goal:** Purpose: Cover Major Version ID of the HPDcache
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: cfig_version.MajorID

- **Verification Goal:** Purpose: Cover Minor Version ID of the HPDcache
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: cfig_version.IpID

- **Verification Goal:** Purpose: Cover IP ID of the HPDcache
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: cfig_version.VendorID

- **Verification Goal:** Purpose:  Cover Vendor ID
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of SETs (cfig_info.Sets)

- **Verification Goal:** 
  Purpose:  Cover Number of sets in the cache (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Bucket:  3 (64, 128, 256)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of Ways (cfig_info.Ways)

- **Verification Goal:** 
  Purpose: Cover Number of ways in the cache (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Bucket:  3 (2, 4, 8)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of bytes per cacheline (cfig_info.CIBytes)

- **Verification Goal:** 
  Purpose: Cover Number of bytes per cacheline (power of 2)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of sets in MSHR (cfig_info.MSHRSets)

- **Verification Goal:** 
  Purpose: Cover Number of sets in the MSHR (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Buckets:  3 (1, 4, 64)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of Ways in MSHR ((cfig_info.MSHRWays)

- **Verification Goal:** 
  Purpose: Cover Number of ways in the MSHR (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Buckets:  3 (1, 2, 4,)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of RTAB entries (cfig_info2.RTAB)

- **Verification Goal:** 
  Purpose: Cover Number of entries in the RTAB (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Buckets: 3 (2, 4, 8)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of Entries in the Directory of WBUF (cfig_info2.WbufDir)

- **Verification Goal:** 
  Purpose: Cover Number of entries in the directory of the Write Buffer (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Bucket:  3 ( 4, 8, 16)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Number of Entries in the data buffer of WBUF (cfig_info2.WbufData)

- **Verification Goal:** 
  Purpose: Cover Number of entries in the data buffer of the Write Buffer (one-based)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Bucket: 3 (2, 4, 8)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Nymber of bytes per Write-Buffer Data Entry (cfig_info2.WbufBytes)

- **Verification Goal:** 
  Purpose: Cover Number of bytes per Write-Buffer Data Entry (power of 2)  
  Method: Cover group in the test base  
  Sampling Event: In the post shutdown phase  
  Bucket:  3 (2, 4, 8)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Cache enable  ( cfig_cachectrl.E )

- **Verification Goal:** 
  Purpose: Cache Enable - When set to 0, all memory accesses are considered uncacheable  
  Method: Cover group in the test base  
  Sample Event: this coverage is sampled at the end of the test in report phase once the counters are read and verified.  
  Buckets: 2  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Performance Counter  ( cfig_cachectrl.P )

- **Verification Goal:** 
  Purpose: This bit indicates if performance counters are enabled. Coverage that all values of this signal have been covered.  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled at the end of the test in report phase once the counters are read and verified.  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Rtab single entry (cfig_cachectrl.R)

- **Verification Goal:** 
  Purpose: Single-Entry RTAB (fallback mode) - When set to 1, the cache controller only uses one entry of the Replay Table.  
  Sample Event: This coverage is sampled at the end of congeston tests described in section 1.3.  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Wbuf threshold (cfig_wbuf.T)

- **Verification Goal:** 
  Purpose: Time-counter Threshold - This field defines the time-counter threshold on which open write-buffer entries (OPEN) go to the pending state (PEND)  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled at the end of congeston tests described in section 1.3.  
  Buckets: ??  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Wbuf reset timecnt on write (cfig_wbuf.R)

- **Verification Goal:** 
  Purpose: Reset time-counter on write - When set to 1, write accesses restart the time-counter to 0 of the used write-buffer entry  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled at the end of congeston tests described in section 1.3.  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Wbuf sequential Write-After-Write (cfig_wbuf.S)

- **Verification Goal:** 
  Purpose: Sequential Write after Write - When set to 1, the write buffer stalls write accesses that collide with an in-flight write transaction (SENT).  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled at the end of congeston tests described in section 1.3.  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Inhibit Write Buf Coalescing (cfig_wbuf.I)

- **Verification Goal:** 
  Purpose: Inhibit Write Coalescing - When set to 1, entries in the write-buffer go from the FREE state to the PEND state directly (bypassing the OPEN state). Moreover, no coalescing is accepted while the entry is in the PEND state.  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled at the end of congeston tests described in section 1.3.  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide CSRs for performance monitoring

#### 📌 Test Case: Performance counter check

- **Verification Goal:** 
  Purpose: Check to verify if the performance counters are correct.  
  Method: This check is performed in report phase, once the test is finished. The counters are predicted in the SB and are compared against the register read value.  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: test_reg_bit_bash

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg access sequence

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg hw reset register test

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: Performance Counter  ( cfig_cachectrl.P )

- **Verification Goal:** 
  Purpose: This bit indicates if performance counters are enabled. Coverage that all values of this signal have been covered.  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled at the end of the test in report phase once the counters are read and verified.  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_write_cnt : 64-bit counter for processed write requests

- **Verification Goal:** 
  Purpose: Cover that each bit of counter has 0/1. Cover min (0) and Max (64hFFFFFFFFFFFFFFFF) values.  
  It is impossible to reach max value in simulation, so it may require that counters are initialised (using backdoor/force signal) to some initial value which are closed to max value. Cover only if sampled value is different from initial value.  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled in the report phase of test_base.  
  Bucket:  2+2*64 = 130  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_write_cnt : 64-bit counter for processed write requests

- **Verification Goal:** 
  Purpose: Cover that each bit of counter has 0/1. Cover min (0) and Max (64hFFFFFFFFFFFFFFFF) values.  
  It is impossible to reach max value in simulation, so it may require that counters are initialised (using backdoor/force signal) to some initial value which are closed to max value. Cover only if sampled value is different from initial value.  
  Method: Cover group in the test base  
  Sample Event: This coverage is sampled in the report phase of test_base.  
  Bucket:  2+2*64 = 130  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_read_cnt  : 64-bit counter for processed read requests

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_prefetch_cnt   : 64-bit counter for processed prefetch requests

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_uncached_cnt : 64-bit counter for processed uncached requests

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_cmo_cnt            : 64-bit counter for processed CMO requests

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_accepted_cnt    : 64-bit counter for processed requests

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_write_miss_cnt : 64-bit counter for write cache misses

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_read_miss_cnt   : 64-bit counter for read cache misses

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_onhold_cnt : 64-bit counter for requests put on-hold

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_onhold_mshr_cnt : 64-bit counter for requests put on-hold because of MSHR conflicts

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_onhold_wbuf_cnt : 64-bit counter for requests put on-hold because of WBUF conflicts

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_onhold_rollback_cnt : 64-bit counter for requests put on-hold (again) after a rollback

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: perf_stall_cnt : 64-bit counter for stall cycles (cache does not accept a request)

- **Verification Goal:** same as 8.2.21
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide CSRs for status monitoring

#### 📌 Test Case: Features not part of test plan


### Sub Feature: The CSR space must be shared between requesters, by inaccessible from the memory interface.

#### 📌 Test Case: CSR Verification

- **Verification Goal:** 
  Purpose: To check the value of the CSRs. Some of the CSRs are systematically read in the post shutdown phase, like performance counters, cfg_info, status registers.  
  Method: UVM_REG model is used to read and write status and configuration registers.  
  Randomization: Some of the counter signals are initialized (by backdoor forcing) to some very high random values to be able to achieve overflow.  
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Assertion Coverage

## Requirement 18.0: Provide a memory interface wrapper which is compatible with AXI5.

### Sub Feature: When used with this wrapper, the memory interface must be compliant with AXI5.

#### 📌 Test Case: Features not part of test plan

- **Feature Description:** Provide a memory interface wrapper which is compatible with AXI5.

### Sub Feature: When used with this wrapper, all functions of the cache must operate correctly, and the same as without the wrapper.

#### 📌 Test Case: Features not part of test plan


## Requirement 19.0: Provide RTL whose functionality is configurable based on numerous System Verilog parameters

### Sub Feature: The design that is provided must work correctly when compiled with any combination of parameters given in the tab "CONFIGURATIONS"

#### 📌 Test Case: Parameter Coverage

- **Feature Description:** Provide RTL whose functionality is configurable based on numerous System Verilog parameters
- **Verification Goal:** The value covered for each parameters are listed as value for HPC1, value for HPC2, value for EMBEDDED1, value for EMBEDDED2.

### Sub Feature: Provide a configurable physical addres width via CONF_HPDCACHE_PA_WIDTH

#### 📌 Test Case: hpdcache_PA_WIDTH

- **Verification Goal:** Physical address width (in bits) : 49, 49, 32, 32
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable data word width with via CONF_HPDCACHE_WORD_WIDTH

#### 📌 Test Case: hpdcache_WORD_WIDTH

- **Verification Goal:** Width (in bits) of a data word: 64, 64, 32, 32
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of words in the data channels to/from requestos via CONF_HPDCACHE_REQ_WORDS

#### 📌 Test Case: hpdcache_REQ_WORDS

- **Verification Goal:** Number of words in the data channels from/to requesters: 2, 1, 1, 1
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable width for the transacion ID via CONF_HPDCACHE_REQ_TRANS_ID_WIDTH

#### 📌 Test Case: hpdcache_REQ_TRANS_ID_WIDTH

- **Verification Goal:** Width (in bits) of the transaction ID from requesters: 7, 4, 3, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable width for the source ID via CONF_HPDCACHE_REQ_SRC_ID_WIDTH

#### 📌 Test Case: hpdcache_REQ_SRC_ID_WIDTH

- **Verification Goal:** Width (in bits) of the source ID from requesters: 3, 2, 2, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of SETs via CONF_HPDCACHE_SETS

#### 📌 Test Case: hpdcache_SETS

- **Verification Goal:** Number of sets: 256, 64, 64, 128
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of WAYs via CONF_HPDCACHE_WAYS

#### 📌 Test Case: hpdcache_WAYS

- **Verification Goal:** Number of ways (associativity): 4, 8, 2, 4
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of words in a cacheline via CONF_HPDCACHE_CL_WORDS

#### 📌 Test Case: hpdcache_CL_WORDS

- **Verification Goal:** Number of words in a cacheline: 8, 2, 4, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: The design that is provided must work correctly when compiled with any combination of parameters given in the tab "CONFIGURATIONS"

#### 📌 Test Case: hpdcache_WBUF_DIR_ENTRIES

- **Feature Description:** Provide RTL whose functionality is configurable based on numerous System Verilog parameters
- **Verification Goal:** Number of entries in the directory of the write buffer: 16, 8, 4, 4
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of entries in the data portion of the write buffer via CONF_HPDCACHE_WBUF_DATA_ENTRIES

#### 📌 Test Case: hpdcache_WBUF_DATA_ENTRIES

- **Verification Goal:** Number of entries in the data part of the write buffer: 8, 4, 4, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of words per entry in the write buffer via CONF_HPDCACHE_WBUF_WORDS

#### 📌 Test Case: hpdcache_WBUF_WORDS

- **Verification Goal:** Number of data words per entry in the write buffer: 4, 1, 2, 1
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable width for the time counter in the write buffers via CONF_HPDCACHE_WBUF_TIMECNT_MAX

#### 📌 Test Case: hpdcache_WBUF_TIMECNT_MAX

- **Verification Goal:** Maximumvalue of the time counter in write buffer entries: 7, 5, 5, 3
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of entries in the replay table via CONF_HPDCACHE_RTAB_ENTRIES

#### 📌 Test Case: hpdcache_RTAB_ENTRIES

- **Verification Goal:** Number of entries in the replay table: 8, 4, 4, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of sets in the MSHR via CONF_HPDCACHE_MSHR_SETS

#### 📌 Test Case: hpdcache_MSHR_SETS

- **Verification Goal:** Number of sets in theMiss Status Holding Register (MSHR): 64, 4, 1, 1
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable number of ways in the MSHR via CONF_HPDCACHE_MSHR_WAYS

#### 📌 Test Case: hpdcache_MSHR_WAYS

- **Verification Goal:** Number of ways (associativity) in the MSHR: 2, 4, 1, 4
- **Coverage Method:** Functional Coverage

### Sub Feature: hpdcache_MEM_ID_WIDTH

#### 📌 Test Case: hpdcache_MEM_ID_WIDTH

- **Verification Goal:** Width (in bits) of the memory transaction ID: 8, 5, 4, 3
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: ID coverage

- **Verification Goal:** 
  Purpose: Coverage that each value of this signal was covered  
  Buckets: HPDCACHE_MEM_ID_WIDTH bits => 2**HPDCACHE_MEM_ID_WIDTH buckets  
  Samlping Event: Sample at the time of NoC Reponse  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: W_id coverage

- **Verification Goal:** 
  Purpose: Coverage that each value of this signal was covered  
  Buckets: HPDCACHE_MEM_ID_WIDTH bits => 2**HPDCACHE_MEM_ID_WIDTH buckets  
  Sampling Event: Sample at the time of NoC Reponse . Sample when the NoC response is witout an error.  
- **Coverage Method:** Functional Coverage

### Sub Feature: hpdcache_MEM_DATA_WIDTH

#### 📌 Test Case: hpdcache_MEM_DATA_WIDTH

- **Verification Goal:** Width (in bits) of the memory data: 512, 64, 128, 32
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of ways in the same MSHR SRAM word via CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD

#### 📌 Test Case: hpdcache_MSHR_WAYS_PER_RAM_WORD

- **Verification Goal:** Number of ways in the same MSHR SRAM word: 2, 2, 1, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: Provide a configurable physical addres width via CONF_HPDCACHE_PA_WIDTH

#### 📌 Test Case: hpdcache_MSHR_SETS_PER_RAM

- **Verification Goal:** Number of sets per RAM macro in the MSHR array of the cache: 64, 4, 1, 1
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of ways in the same CACHE data SRAM word via CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD

#### 📌 Test Case: hpdcache_DATA_WAYS_PER_RAM_WORD

- **Verification Goal:** Number of ways in the same CACHE data SRAM word: 2, 2, 2, 4
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of sets per RAM macro in the data array via CONF_HPDCACHE_DATA_SETS_PER_RAM

#### 📌 Test Case: hpdcache_DATA_SETS_PER_RAM

- **Verification Goal:** Number of sets per RAM macro in the DATA array of the cache: 128, 32, 64, 64
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of words of a given set that can be accessed simultaneously via CONF_HPDCACHE_ACCESS_WORDS

#### 📌 Test Case: hpdcache_ACCESS_WORDS

- **Verification Goal:** Number of words of a given SET that can be accessed simultaneously from the CACHE data array: 4, 2, 2, 1
- **Coverage Method:** Functional Coverage

### Sub Feature: Configure victim_sel via CONF_HPDCACHE_VICTIM_SEL

#### 📌 Test Case: hpdcache_VICTIM_SEL

- **Verification Goal:** Enable or disable victim_sel feature: 1, 0, 0, 1

## Requirement 20.0: Provide RTL such that the partitioning of data into SRAM cuts is configurable

### Sub Feature: Regardless of the partitioning of the SRAM cuts, the cache functionality must be correct.

#### 📌 Test Case: Parameter Coverage

- **Feature Description:** Provide RTL such that the partitioning of data into SRAM cuts is configurable
- **Verification Goal:** The value covered for each parameters are listed as value for HPC1, value for HPC2, value for EMBEDDED1, value for EMBEDDED2.

### Sub Feature: Control the number of ways in the same MSHR SRAM word via CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD

#### 📌 Test Case: hpdcache_MSHR_WAYS_PER_RAM_WORD

- **Verification Goal:** Number of ways in the same MSHR SRAM word: 2, 2, 1, 2
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of sets per RAM macro in the MSHR array via CONF_HPDCACHE_MSHR_SETS_PER_RAM

#### 📌 Test Case: hpdcache_MSHR_SETS_PER_RAM

- **Verification Goal:** Number of sets per RAM macro in the MSHR array of the cache: 64, 4, 1, 1
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of ways in the same CACHE data SRAM word via CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD

#### 📌 Test Case: hpdcache_DATA_WAYS_PER_RAM_WORD

- **Verification Goal:** Number of ways in the same CACHE data SRAM word: 2, 2, 2, 4
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of sets per RAM macro in the data array via CONF_HPDCACHE_DATA_SETS_PER_RAM

#### 📌 Test Case: hpdcache_DATA_SETS_PER_RAM

- **Verification Goal:** Number of sets per RAM macro in the DATA array of the cache: 128, 32, 64, 64
- **Coverage Method:** Functional Coverage

### Sub Feature: Control the number of words of a given set that can be accessed simultaneously via CONF_HPDCACHE_ACCESS_WORDS

#### 📌 Test Case: hpdcache_ACCESS_WORDS

- **Verification Goal:** Number of words of a given SET that can be accessed simultaneously from the CACHE data array: 4, 2, 2, 1
- **Coverage Method:** Functional Coverage

## Requirement 22.0: Provide an asynchronous, active low reset

### Sub Feature: Single external resetpin RST_NI. After application of the reset, the cache must restore the default directory and CSR state

#### 📌 Test Case: Reset On The Fly

- **Feature Description:** Provide an asynchronous, active low reset
- **Verification Goal:** 
  Purpose:  To apply reset on the fly randomly.  
  Method:  There is a configuration variable, m_reset_on_the_fly on the hpdcache_top_config. When this variable is enabled reset is applied. The reset uses jump mechanism of the UVM (jump to reset phase from main phase). The reusable reset agent is used to apply jump.  
  Randomization:     Following formula is used to apply the reset. Reset is applied either when req_count is somewhere between 40 and 1000 or clk_cnt == 10000.  
  if((env.m_hpdcache_sb.get_req_counter() == $urandom_range(4000, 5000)) || (clk_cnt == 10000)) env.reset_driver.emit_assert_reset();  
  Link:  Reusable UVM agent reset driver of cv_dv_utils  is used to apply the reset.  
  Expected Behaviour:  
  We expect the HPDcache to reinitialize all internal buffers (FIFOs, RTAB, WBUF, MSHR, Dcache Directory).  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Code Coverage

#### 📌 Test Case: SHCMOO 1 reset   @hpdcache core request

- **Verification Goal:** 
  Purpose: The purpose of this assertion is to make sure that hpdcache works correctly when a reset is asserted around a request on the core interface.  
  Description: If reset arrives at time T and valid is inserted at T1. Cover that T1 arrives between [T-T1:T+T1] (T1 = 5)  
  This assertion covers the cases where ready is 1 or 0 when the valid is 1.  
  This assertion covers the cases where request arrives with phy_index = 0 or 1.  
  Trigger and clock event: The clock is the clk hpdcache. The assertion is triggered by a rising edge on reset or req valid.  
  Number of Cases: 11x2(ready or not)x2(phys_indexed or not) == 44  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 2 reset  @hpdcache core response

- **Verification Goal:** 
  Purpose: The purpose of this assertion is to make sure that hpdcache works correctly when a reset is asserted around a reponse on the core interface.  
  Description: If reset arrives at time T and valid is inserted at T1. Cover that T1 arrives between [T-T1:T+T1] (T1 = 5)  
  This assertion covers the cases where reset is asserted when  a response arrives with or without a error response.  
  This assertion covers the cases where reset is asserted when a  response arrives with or without a abort response.  
  Trigger and clock event: The clock is the clk hpdcache. The assertion is triggered by a rising edge on reset or rsp valid.  
  Number of Cases: 11x2 + 11x2(abort or not) == 44  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 3 reset @memory read  request

- **Verification Goal:** 
  Same as 4.1 , in this case reset is asserted when the request arrives at memory read interface.  
  This assertion covers the cases where reset arrives when a request is cached or uncached.  
  Number of Cases: 11x2 == 22  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 4 reset @memory write request

- **Verification Goal:** 
  same as 4.3, in this case reset is asserted when the request arrives at memory write interface  
  This assertion also cover the case where reset arrives when a request is a AMO.  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 5 reset @memory read response

- **Verification Goal:** 
  same as 4.3, in this case reset is asserted when  a response arrives at memory read interface  
  This assertion also covers the cases where reset arrives when a response arrives with or without an error.  
  This assertion also covers the cases where reset arrives when a response arrives with or without ex fail .  
  Number of Cases: 11x2(error or not) + 11x2(ex fail or not) == 44  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 6 reset @memory write response

- **Verification Goal:** same as 4.5, in this case reset is asserted when the a response arrives at memory write interface
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SCHMOO 7 reset @ flush

- **Verification Goal:** 
  Purpose: The prupose of this assertion is to make sure that hpdcache works correctly when a reset is asserted when flush is going on.  
  Description: If reset arrives at time T and flush is inserted at T1. Cover that T1 arrives between [T-T1:T+T1] (T1 = 5)  
  This assertion should be covered when many cached write are on the fly.  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Back to Back to same addresse interleaved with reset

- **Verification Goal:** 
  Purpose: The purpose of thisassertion is to make sure that a new request after a reset is always miss.  
  Desciption: If a request is sent @ A followed by a reset follow by another request @A, we expect that the new resuest after the reset would be a miss.  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: No request after the reset

- **Verification Goal:** 
  Purpose: The purpose of this assertion is to make sure that HPDcache does not send spurious memory request after a reset is asserted  
  Desciption: Wait for 10 cycles after the reset before sending a new core request. During this 10 cycles HPDCache shall not make new memory request. It is a coverage as well as a check.  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: test reg hw reset register test

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: Arrays / fifos empty

- **Criteria Pass Fail:** Criteria (PASS/FAILED): If an array or fifo is not empty the asserion fails and an error is flaged.
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: RTAB empty

- **Verification Goal:** 
  Purpose  : To determine if rtab is empty after at the end of the test  
  Method   : Assertions are used on the internal signal  
  Trigger Event: Post shutdown phase,  under reset  
- **Criteria Pass Fail:** Criteria (PASS/FAILED): If rtab is not empty the asserion fails and an error is flaged.
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Wbuf empty

- **Verification Goal:** 
  Purpose  : To determine if write buffer is empty after at the end of the test  
  Method   : Assertions are used on the internal signal  
  Trigger Event: Post shutdown phase,  under reset  
- **Criteria Pass Fail:** Criteria (PASS/FAILED): If write buffer is not empty the asserion fails and an error is flaged.
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: FSM state end of test

- **Verification Goal:** 
  Purpose  : To determine that the internal FSM are in their end of test state (wbuf/refill/miss req/cmo)  
  Method   : Assertions are used on the internal signal  
  Trigger Event: Post shutdown phase ,  under reset  
- **Criteria Pass Fail:** Criteria (PASS/FAILED): If internal FSM are not in their end of test state the asserion fails and an error is flaged.
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Directory Coherency

- **Verification Goal:** 
  Purpose  : Check at the end of the test that the directory is coherent with tag directory  
  Method   : The SV based model of directory is used. The SV based model is directly  bind to the mem controller module of HPDcache and uses internal signal to get the directory state.  
  RTL directory is read via backdoor.  
  Trigger Event: Post shutdown phase  
- **Criteria Pass Fail:** Criteria (PASS/FAILED):  If there is mismatch a UVM_ERROR is flaged
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Memory coherency (External Memory and Shadow Memory)

- **Verification Goal:** 
  Purpose: Check at the end of the test that the data in the external memory is coherent with the data in the shadow external memory  
  Method: The UVM based model is compared with the memory within memory response model  
  Trigger Event: Post shutdown phase  
- **Criteria Pass Fail:** Criteria : If there is a mimsatch a UVM_ERROR is flaged
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Counter Checks

- **Verification Goal:** 
  Purpose: Predict the hpdcache performance counter vaules  
  The hpdcache has following counters. These counters are predicted in the TB of HPDcache.  
  At the end of the test in the report phase, the value of these counters are read (from registers) and compared against the reference counters.  
  These counters may require to be initialised by backdoor to be able to achieve all values.  
  perf_write_cnt : 64-bit counter for processed write requests  
  perf_read_cnt  : 64-bit counter for processed read requests  
  perf_prefetch_cnt   : 64-bit counter for processed prefetch requests  
  perf_uncached_cnt : 64-bit counter for processed uncached requests  
  perf_cmo_cnt          : 64-bit counter for processed CMO requests  
  perf_accepted_cnt    : 64-bit counter for processed requests  
  perf_write_miss_cnt : 64-bit counter for write cache misses  
  perf_read_miss_cnt   : 64-bit counter for read cache misses  
  perf_onhold_cnt : 64-bit counter for requests put on-hold  
  perf_onhold_mshr_cnt : 64-bit counter for requests put on-hold because of MSHR conflicts (how to predict ?)  
  perf_onhold_wbuf_cnt : 64-bit counter for requests put on-hold because of WBUF conflicts(how to predict ?)  
  perf_onhold_rollback_cnt : 64-bit counter for requests put on-hold (again) after a rollback(how to predict ?)  
  perf_stall_cnt : 64-bit counter for stall cycles (cache does not accept a request)  
  Method:  In the post shutdown phase, counter registers are read and compared with the value predicted within the UVM TB.  
  Trigger Event: Post shutdown phase  
- **Criteria Pass Fail:** Criteria : If there is a mimsatch a UVM_ERROR is flaged. In the cases where it is difficult to predict exact values, fuzzy values are used (the counters to be precised)
- **Coverage Method:** Assertion Coverage

## Requirement 23.0: Provide the ability to initiate a flush of the write buffer.

### Sub Feature: Initiate a flush of the write buffer via a one-cycle pulse on the input pin WBUF_FLUSH_I

#### 📌 Test Case: Flush on the fly

- **Feature Description:** Provide the ability to initiate a flush of the write buffer.
- **Verification Goal:** 
  Purpose:  To apply flush on the fly randomly.  
  Method:  There is a configuration variable, m_flush_on_the_fly on the hpdcache_top_config. When this variable is enabled flush is applied. The reusable pulse agent is used to generate pulses. It is configured to apply 10 pulses of 1 cycle each, every 2000 cycles.  
  Randomization:    Following configuration is used to apply the clock based synchronous pulses.  
  env.m_flush_cfg.set_pulse_enable(m_flush_on_the_fly);  
  env.m_flush_cfg.set_pulse_clock_based(1);  
  env.m_flush_cfg.set_pulse_width(1);  
  env.m_flush_cfg.set_pulse_period(5000);  
  env.m_flush_cfg.set_pulse_phase_shift(0);  
  env.m_flush_cfg.set_pulse_num(5);  
  Link:  Reusable UVM agent pulse_gen of cv_dv_utils is used to generate the flush  
  Expected Behavior:  
  After a flush, the HPDcache shall not accept new write requests (all core_req_ready_o are reset to 0) until wbuf_empty_o is asserted  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Code Coverage

#### 📌 Test Case: SHCMOO 1 flush   @hpdcache core request

- **Verification Goal:** 
  Purpose: The prupose of this assertion is to make sure that hpdcache works correctly when a flush is asserted around a request on the core interface.  
  Description: If flush arrives at time T and valid is inserted at T1. Cover that T1 arrives between [T-T1:T+T1] (T1 = 5)  
  This assertion is covers the cases where ready is 1 or 0 when the valid is 1.  
  This assertion covers the cases where request arrives with phy_index = 0 or 1.  
  Trigger and clock event: The clock is the clk hpdcache. The assertion is triggered by a rising edge on flush or req valid.  
  Number of Cases: 11x2(ready or not)x2(phys_indexed or not) == 44  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 2 flush @hpdcache core response

- **Verification Goal:** 
  Purpose: The prupose of this assertion is to make sure that hpdcache works correctly when a flush is asserted around a reponse on the core interface.  
  Descirption: If flush arrives at time T and valid is inserted at T1. Cover that T1 arrives between [T-T1:T+T1] (T1 = 5)  
  This assertion covers the cases where flush is asserted when  a response arrives with or without a error response.  
  This assertion covers the cases where flush is asserted when a  response arrives with or without a abort response.  
  Number of Cases: 11x2 + 11x2(abort or not) == 44  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 3 flush @memory read  request

- **Verification Goal:** 
  Same as 5.1 , in this case flush is asserted when the request arrives at memory read interface.  
  This assertion covers the cases where flush arrives when a request is cached or uncached.  
  Number of Cases: 11x2 == 22  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 4 flush @memory write request

- **Verification Goal:** 
  same as 5.3, in this case flush is asserted when the request arrives at memory write interface  
  This assertion also cover the case where flush arrives when a request is a AMO.  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 5 flush @memory read response

- **Verification Goal:** 
  same as 5.3, in this case flush is asserted when  a response arrives at memory read interface  
  This assertion also covers the cases where flush arrives when a response arrives with or without an error.  
  This assertion also covers the cases where flush arrives when a response arrives with or without ex fail  
  Number of Cases: 11x2 + 11x2 == 44  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: SHCMOO 6 flush @memory write response

- **Verification Goal:** same as 5.5, in this case flush is asserted when the a response arrives at memory write interface
- **Coverage Method:** Assertion Coverage

## Requirement 24.0: Respect the ready/valid protocol on all requester and memory interfaces

### Sub Feature: Once VALID is set to '1' it must stay at '1' until RDY goes to '1' and the transfer occurs.

#### 📌 Test Case: Ready Valid Protocol

- **Feature Description:** Respect the ready/valid protocol on all requester and memory interfaces
- **Verification Goal:** 
  Purpose: Cover following scenerios of ready valid protocol:  
  1. Read and Valid are inserted at the same time  
  2. Ready is high before the valid is inserted  
  3. Valid is high before the ready in inserte  
  Sampling Event: When a valid request is recieved.  
  Buckets: 3 buckets  
- **Coverage Method:** Assertion Coverage

## Requirement 25.0: The cache must be able to put certain requests on-hold in the RTAB and re-execute them later, while still assuring the Memory Consistency Rules (MCRs).

### Sub Feature: In case 1 (cacheable Load or pre-fetch) which hits on a pending miss - the 2nd read must wait for 1st to complete to get data.

#### 📌 Test Case: Schmoo 1 (hpdcache req  -> memory req interface)

- **Feature Description:** The cache must be able to put certain requests on-hold in the RTAB and re-execute them later, while still assuring the Memory Consistency Rules (MCRs).
- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between a processor operation for a cache line and that cache line address appearing on a AXI request  transaction( from a previous request on the same line).  
  Cover 3 cases when NoC ready is zero, random, one during the whole duration of assertion.  
  Description:  
  hpdcache_req_1_valid (ld/st/cmos)  (p_i = 0/1)-> #N mem_req_2_valid  (ld/st)  
  N = [-5 : 5] @same tag/set  
  p_i = phys_indexed  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x3x2x2x3 = 396  
  Note: Covers following cases of on hold request  
  1. Cacheable LOAD or PREFETCH, and there is a hit on a pending miss (hit on the MSHR).  
  2. Cacheable LOAD or PREFETCH, there is a miss on the cache, and there is a hit (cacheline granularity) on an opened, pending or sent entry of the WBUF  
  3. Cacheable STORE, there is a miss on the cache, and there is a hit on a pending miss (hit on the MSHR)  
  6. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the miss handler FSM cannot send the read miss request  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Shcmoo 5 (hpdcache_req  (@NREQ= X) -> hpdcache_req (@NREQ=Y) )

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between 2 processor issuing a request at the same time.  If pys_indexed = 0, cache needs 2 cycle to read the address, 1 st cycle it (arbiter) accepts the request and second cycle is used to accept the virtual addresse.  
  If another processor makes a request at this second cycle, we have 2 requests coming at the same time. Cover the case where NOC ready always zero, one or random during the duration of assertion  
  Description:  
  hpdcache_req_X_valid (ld/st/cmos/amos) (p_i = 0/1) -> #N hpdcache_req_Y_valid (ld/st/cmos/amos)  
  N = [-5 : 5]  
  p_i = phys_indexed  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x2x4x4x2 =704  
- **Coverage Method:** Assertion Coverage

### Sub Feature: In case 2 (cacheable Load or pre-fetch) which misses in the cache and hits a write-buffer entry which is open closed or sent.

#### 📌 Test Case: Schmoo 1 (hpdcache req  -> memory req interface)

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between a processor operation for a cache line and that cache line address appearing on a AXI request  transaction( from a previous request on the same line).  
  Cover 3 cases when NoC ready is zero, random, one during the whole duration of assertion.  
  Description:  
  hpdcache_req_1_valid (ld/st/cmos)  (p_i = 0/1)-> #N mem_req_2_valid  (ld/st)  
  N = [-5 : 5] @same tag/set  
  p_i = phys_indexed  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x3x2x2x3 = 396  
  Note: Covers following cases of on hold request  
  1. Cacheable LOAD or PREFETCH, and there is a hit on a pending miss (hit on the MSHR).  
  2. Cacheable LOAD or PREFETCH, there is a miss on the cache, and there is a hit (cacheline granularity) on an opened, pending or sent entry of the WBUF  
  3. Cacheable STORE, there is a miss on the cache, and there is a hit on a pending miss (hit on the MSHR)  
  6. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the miss handler FSM cannot send the read miss request  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Shcmoo 5 (hpdcache_req  (@NREQ= X) -> hpdcache_req (@NREQ=Y) )

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between 2 processor issuing a request at the same time.  If pys_indexed = 0, cache needs 2 cycle to read the address, 1 st cycle it (arbiter) accepts the request and second cycle is used to accept the virtual addresse.  
  If another processor makes a request at this second cycle, we have 2 requests coming at the same time. Cover the case where NOC ready always zero, one or random during the duration of assertion  
  Description:  
  hpdcache_req_X_valid (ld/st/cmos/amos) (p_i = 0/1) -> #N hpdcache_req_Y_valid (ld/st/cmos/amos)  
  N = [-5 : 5]  
  p_i = phys_indexed  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x2x4x4x2 =704  
- **Coverage Method:** Assertion Coverage

### Sub Feature: In case 3 (cacheable Store) which misses in the cache but matched a pending miss.

#### 📌 Test Case: Schmoo 1 (hpdcache req  -> memory req interface)

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between a processor operation for a cache line and that cache line address appearing on a AXI request  transaction( from a previous request on the same line).  
  Cover 3 cases when NoC ready is zero, random, one during the whole duration of assertion.  
  Description:  
  hpdcache_req_1_valid (ld/st/cmos)  (p_i = 0/1)-> #N mem_req_2_valid  (ld/st)  
  N = [-5 : 5] @same tag/set  
  p_i = phys_indexed  
  offset between req 1 and req2 have the same or different offsets  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x3x2x2x3 = 396  
  Note: Covers following cases of on hold request  
  1. Cacheable LOAD or PREFETCH, and there is a hit on a pending miss (hit on the MSHR).  
  2. Cacheable LOAD or PREFETCH, there is a miss on the cache, and there is a hit (cacheline granularity) on an opened, pending or sent entry of the WBUF  
  3. Cacheable STORE, there is a miss on the cache, and there is a hit on a pending miss (hit on the MSHR)  
  6. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the miss handler FSM cannot send the read miss request  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: Shcmoo 5 (hpdcache_req  (@NREQ= X) -> hpdcache_req (@NREQ=Y) )

- **Verification Goal:** 
  Purpose: This schmoo is intended to cover the temporal relationship between 2 processor issuing a request at the same time.  If pys_indexed = 0, cache needs 2 cycle to read the address, 1 st cycle it (arbiter) accepts the request and second cycle is used to accept the virtual addresse.  
  If another processor makes a request at this second cycle, we have 2 requests coming at the same time. Cover the case where NOC ready always zero, one or random during the duration of assertion  
  Description:  
  hpdcache_req_X_valid (ld/st/cmos/amos) (p_i = 0/1) -> #N hpdcache_req_Y_valid (ld/st/cmos/amos)  
  N = [-5 : 5]  
  p_i = phys_indexed  
  Trigger and clocking events: The clock is core clock. Assertion is trigerred by the request 1 valid.  
  Number of Cases: 11x2x4x4x2 =704  
- **Coverage Method:** Assertion Coverage

### Sub Feature: In case 4 (cacheable Load/Prefetch/Store) hits an entry in the RTAB.

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

### Sub Feature: In case 5 (cacheable Load/Prefetch) and MSHR has no available slots.

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the MSHR and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

### Sub Feature: In case 6 (cacheable Load/Prefetch), miss on the cache and read can not be issued to NoC (congestion).

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

### Sub Feature: If the RTAB is full, the cache must stop accepting any requests.

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the MSHR and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

### Sub Feature: When requests are taken out of the RTAB, they must be taken out in an order that respects the RVWMO. Specifically, if two requests in the RTAB overlap, then they must be taken out in the order they entered.

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

## Requirement 26.0: The cache must be dead-lock free.

### Sub Feature: No sequence of events entering the replay-buffer must trigger a dead-lock or live-lock condition.

#### 📌 Test Case: test_hpdcache_multiple_random_requests

- **Feature Description:** The cache must be dead-lock free.
- **Verification Goal:** 
  Purpose : Test to perform random accesses. The purpose is to have maximum coverage(functional and code).  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  
  Constraint      :  Every field of the transaction is randomized. Reserved op code is not used. The address are biased to more frequently select the extreme tag values(0x0, 0xFFFFF ….). The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_uncached

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Constraint       :  The field uncacheable is constrained  to have only uncacheable accesses. And is added for coverage.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Stimuli:   In this test 80% of the traffic is load and store.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_in_region

- **Verification Goal:** 
  Purpose : Test to perform random accesses within randomized address  regions. The purpose is to provoke hits and conflicts keeping stimulus relatively random.  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  The regions are generated using memory partition class from cv_dv_utils. The regions are random size but some are small which provokes hits and conflicts.  
  The sequence choses one region randomly for a SEED.  
  Constraint       :  Every field of the transaction is randomized. Reserved op code is not used. The addresses are generated within the region. The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests_in_region

- **Verification Goal:** 
  Same as 2.1.4.  
  Stimuli: This test performs  80% load store accesses within randomized address regions and the other accesses are fully random but within the regions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_directed_addr

- **Verification Goal:** 
  Purpose :  Test to provoke the eviction at regular interval in between many hits.  
  Target     :  This test stresses the eviction mechanism.  
  Scenario:  In this test, one set is selected randomly at the beginning of the test.  Then NWAYS + 1 random tags are selected within the selected set. Random loads  and stores are performed on these preselected {tag, set}. Normally we should observe many hits with misses (because of the evictions) as the number of tags exceed the NWAYS by 1.  
  Stimuli :  The test runs hpdcache_multiple_directed_addr sequence which is driven from hpdcache_single_directed_addr.  
  Requirement :  This test  respects the constraints related to hpdcache protocol  
  Constraint       :  Every field of the transaction is randomized except set, address and uncacheable (always 0 -> cacheable).  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_directed_addr_bPLRU_prediction

- **Verification Goal:** 
  Purpose:  The purpose of this the test is to check the PLRU eviction algorithm using a black box approach.  
  Target:  PLRU algorithm  
  Scenario:  To avoid temporal conflicts between request and refill response which cannot be predicted, in this test each request is sent every N( = 15) cycles and the memory response model is configured to respond with zero delay. We require that the response from the previous request is received before the next request is issued. Otherwise it is impossible to predict the PLRU behavior using a black box approach.  
  Stimuli :  The sequence is derived from 1.2.1  
  Requirement :  This test  respects the constraints related to hpdcache protocol. This test enables a UVM based model in the SB which  does the black box prediction of the PLRU under a limited set of stimulus which is respected by this test.  
  Constraint       :  Every field of the transaction is randomized except Set, address, uncacheable (always 0 -> cacheable) and inter request delay. Memory response model is configured to respond with zero delay.  
  Note:  We note that the environment also has a SV based PLRU model which is bind directly to the memory control module to do the exact prediction of the PLRU using the signals from memory control module (white box assertion based checking).   In the UVM based model, the PLRU prediction takes into accoun the type of transactions.  
- **Criteria Pass Fail:** The TB has UVM based PLRU model which flags a UVM_ERROR in case PLRU algorithm is not respected. A tag directory is maintained which helps predict hit and miss in this particular scenario.
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_in_region_bPLRU_prediction

- **Verification Goal:** 
  This is the variant of test 1.2.2 where this test is derived from the test 1.1.4.  
  Scenario: The idea is to perform black box PLRU prediction when the memory accesses are distributed across a memory region. In 1.2.2 the accesses where focused on a single set to provoke frequent evictions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_amo_lr_sc_requests

- **Verification Goal:** 
  Purpose: The aim of this test is to test Load Reserved (LR)/Store Conditional (SC) sequences. The goal is to test all possible conditions where LR/SC fails or passes. A coverage item is added to cover all possible combination. A sequence of LR/SC mixed with LOAD/STORE/AMOS/CMOS are run. Most(90%) of the accesses are done at the same address.  
  Target: Load Reserved and Store Conditional Mechanism  
  Scenario:  The hpdcache_single_lr_sc_request runs a sequence with following constraints:  
  FOR 1 to (random 10 or 15 )  
  m_req_addr dist { same_addr := (50 a 100), random_addr := (100 - same_addr)};  
  m_req_op   dist { hpdcache_REQ_AMO_LR := 40, HPDCACHE_REQ_AMO_SC := 40,  
  hpdcache_REQ_LOAD     := 11,  
  hpdcache_REQ_AMO_SWAP := 1,  
  hpdcache_REQ_STORE  := 1,  
  hpdcache_REQ_AMO_ADD  := 1,  
  hpdcache_REQ_AMO_AND  := 1,  
  hpdcache_REQ_AMO_OR   := 1,  
  hpdcache_REQ_AMO_XOR  := 1,  
  hpdcache_REQ_AMO_MAX  := 1,  
  hpdcache_REQ_AMO_MAXU := 1,  
  hpdcache_REQ_AMO_MIN  := 1,  
  hpdcache_REQ_AMO_MINU := 1  
  hpdcache_REQ_CMO := 1  
  END  
  Stimuli: The sequence used is hpdcache_multiple_amo_lr_sc_requests which is driven from hpdcache_single_lr_sc_request.  
  Requirement :  This test  respects the constraints related to hpdcache protocol.  
  Constraint:  Every field of the transaction is randomized except address.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_reg_bit_bash

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg access sequence

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg hw reset register test

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the MSHR and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write only with limited back pressure

- **Verification Goal:** 
  Purpose :  The aim of this performance test is to show the benefits of having a write buffer on the performance.  
  Check the bandwidth of cached write at the core interface of HPDcache when writes arrive with no inter request delay.  
  If memory response reply within a delay < NUM_WBUF cycles, the cache should be able to accept every write.  
  Target     : Write Performance  
  Scenario:  Write only test.  
  Stimuli   :  Test is derived from random access tests.  
  Requirement :  
  Following condition should be respected to get full performance  
  1. Store accesses are cacheable  
  2. There is not inter request delay @core interface  
  3. Memory response model reply within minimum (< NUM_WBUF cycles) delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_STORE, uncacheable=0.  
  The wbuf and rtab should be configured to get the maximum output. Following values are used:  
  m_cfg_wbuf_threshold = > 2 < HPDCACHE_WBUF_DIR_ENTRIES  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
  All writes are done at unique SET where no request is on the fly.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN stores in NB_TXN cycles.  
  In the case where write_buf_dir_entry, write_buf_data_entry < the memory write latency,  almost 3 times degrdation of performance is observed.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Read only with no memory back pressure

- **Verification Goal:** 
  Purpose:  The aim of this performance test is to show the benefits of having a MSHR on the performance.  
  Check the bandwidth of cached reads at the core interface of HPDcache when a read arrives with no inter request delay.  
  If memory response reply within a cycle (or may be cycles < MSHR_SET), the cache should be able to accept a read miss every three cycle.  
  Target    : Load Performance maximising the use of MSHR  
  Scenario : Load only test  
  Stimulie : Test uses random access sequence.  
  Requirement:  
  Following condition are respected to get full performance  
  1. Load accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraint:  
  OP = HPDCACHE_REQ_LOAD, uncacheable=0.  
  The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads in 3*NB_TXN cycles.  
  Note: Here, when you say SET, it should be MSHR_SET (which may be different than the number of sets in the cache HPDCACHE_SETS). Another thing, is that you still need to repeat the MSHR_SET in order to exploit all the MSHR as the MSHR has MSHR_WAYS per MSHR_SET. Thus, I do not know how you generate the addresses, maybe it is already as I propose hereafter:  
  req.address = (random() / CL_BYTES) * CL_BYTES            // align the base address to a cacheline  
  while (true) {  
  req.address = req.address + CL_BYTES  
  }  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Read only with large memory back pressure

- **Verification Goal:** 
  Purpose: The aim of this performance test is to show the benefits of having a MSHR on the performance.  
  Check the bandwidth of cached reads at the core interface of HPDcache when a read arrives with no inter request delay.  
  If memory response reply with a delay of 2*MSHR_SETS*MSHR_WAYS cycle(more realistic delay), the cache should be able to accept a read miss every third cycle.  
  Tarrget:    Load Performance maximising the use of MSHR  
  Scenario: Load only test  
  Stimulie: Test uses random access sequence.  
  Requirements:  
  Following condition are respected to get full performance  
  1. Load accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraints:  
  The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads in 2*3*NB_TXN cycles.  
  I would generate the address as above (cf 2.5.2)  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write(30%) Read(70% ) with no memory back pressure

- **Verification Goal:** 
  Purpose : Check the bandwidth of cached reads (70%) and cached writes(30%) at the core interface of HPDcache when reads and writes arrive with no inter request delay.  
  Target     : Read and Write Performance  
  Scenario:  Test is constraint to have 70% cacheable read and 30% cacheable  write.  
  Stimuli   :  Test is derived from random access tests.  
  Requirements:  
  Following condition are respected to get full performance  
  1. Load/Store accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_LOAD(70%), HPDCACHE_REQ_STORE(30%). Uncacheable = 0.  
  5. The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_wbuf_threshold = > 2  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads/stores in 3*NB_TXN cycles.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

## Requirement 27.0: The cache must be live-lock free.

#### 📌 Test Case: test_hpdcache_multiple_random_requests

- **Feature Description:** The cache must be live-lock free.
- **Verification Goal:** 
  Purpose : Test to perform random accesses. The purpose is to have maximum coverage(functional and code).  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  
  Constraint      :  Every field of the transaction is randomized. Reserved op code is not used. The address are biased to more frequently select the extreme tag values(0x0, 0xFFFFF ….). The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_uncached

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Constraint       :  The field uncacheable is constrained  to have only uncacheable accesses. And is added for coverage.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests

- **Verification Goal:** 
  This test is derived from test 1.1.1.  
  Stimuli:   In this test 80% of the traffic is load and store.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_in_region

- **Verification Goal:** 
  Purpose : Test to perform random accesses within randomized address  regions. The purpose is to provoke hits and conflicts keeping stimulus relatively random.  
  Target     : It targets every feature of the cache.  
  Scenario: Random  
  Stimuli : This test  respects the constraints related to hpdcache protocol  
  Requirement :  The regions are generated using memory partition class from cv_dv_utils. The regions are random size but some are small which provokes hits and conflicts.  
  The sequence choses one region randomly for a SEED.  
  Constraint       :  Every field of the transaction is randomized. Reserved op code is not used. The addresses are generated within the region. The distribution is biased to have more request with small delays between requests.  
  Cacheable requests are previleged over uncacheable requests (95% cacheable / 5% uncacheable). Uncacheable requests empty the pipeline, hence limiting concurrency. Concurrency is the best way to detect possible deadlocks/livelocks.  
  "Normal" accesses (load, stores) are previliged over CMOs and AMOs (90% normal / 5% CMOs and AMOs)  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_load_store_requests_in_region

- **Verification Goal:** 
  Same as 2.1.4.  
  Stimuli: This test performs  80% load store accesses within randomized address regions and the other accesses are fully random but within the regions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_directed_addr

- **Verification Goal:** 
  Purpose :  Test to provoke the eviction at regular interval in between many hits.  
  Target     :  This test stresses the eviction mechanism.  
  Scenario:  In this test, one set is selected randomly at the beginning of the test.  Then NWAYS + 1 random tags are selected within the selected set. Random loads  and stores are performed on these preselected {tag, set}. Normally we should observe many hits with misses (because of the evictions) as the number of tags exceed the NWAYS by 1.  
  Stimuli :  The test runs hpdcache_multiple_directed_addr sequence which is driven from hpdcache_single_directed_addr.  
  Requirement :  This test  respects the constraints related to hpdcache protocol  
  Constraint       :  Every field of the transaction is randomized except set, address and uncacheable (always 0 -> cacheable).  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_directed_addr_bPLRU_prediction

- **Verification Goal:** 
  Purpose:  The purpose of this the test is to check the PLRU eviction algorithm using a black box approach.  
  Target:  PLRU algorithm  
  Scenario:  To avoid temporal conflicts between request and refill response which cannot be predicted, in this test each request is sent every N( = 15) cycles and the memory response model is configured to respond with zero delay. We require that the response from the previous request is received before the next request is issued. Otherwise it is impossible to predict the PLRU behavior using a black box approach.  
  Stimuli :  The sequence is derived from 1.2.1  
  Requirement :  This test  respects the constraints related to hpdcache protocol. This test enables a UVM based model in the SB which  does the black box prediction of the PLRU under a limited set of stimulus which is respected by this test.  
  Constraint       :  Every field of the transaction is randomized except Set, address, uncacheable (always 0 -> cacheable) and inter request delay. Memory response model is configured to respond with zero delay.  
  Note:  We note that the environment also has a SV based PLRU model which is bind directly to the memory control module to do the exact prediction of the PLRU using the signals from memory control module (white box assertion based checking).   In the UVM based model, the PLRU prediction takes into accoun the type of transactions.  
- **Criteria Pass Fail:** The TB has UVM based PLRU model which flags a UVM_ERROR in case PLRU algorithm is not respected. A tag directory is maintained which helps predict hit and miss in this particular scenario.
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_in_region_bPLRU_prediction

- **Verification Goal:** 
  This is the variant of test 1.2.2 where this test is derived from the test 1.1.4.  
  Scenario: The idea is to perform black box PLRU prediction when the memory accesses are distributed across a memory region. In 1.2.2 the accesses where focused on a single set to provoke frequent evictions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_amo_lr_sc_requests

- **Verification Goal:** 
  Purpose: The aim of this test is to test Load Reserved (LR)/Store Conditional (SC) sequences. The goal is to test all possible conditions where LR/SC fails or passes. A coverage item is added to cover all possible combination. A sequence of LR/SC mixed with LOAD/STORE/AMOS/CMOS are run. Most(90%) of the accesses are done at the same address.  
  Target: Load Reserved and Store Conditional Mechanism  
  Scenario:  The hpdcache_single_lr_sc_request runs a sequence with following constraints:  
  FOR 1 to (random 10 or 15 )  
  m_req_addr dist { same_addr := (50 a 100), random_addr := (100 - same_addr)};  
  m_req_op   dist { hpdcache_REQ_AMO_LR := 40, HPDCACHE_REQ_AMO_SC := 40,  
  hpdcache_REQ_LOAD     := 11,  
  hpdcache_REQ_AMO_SWAP := 1,  
  hpdcache_REQ_STORE  := 1,  
  hpdcache_REQ_AMO_ADD  := 1,  
  hpdcache_REQ_AMO_AND  := 1,  
  hpdcache_REQ_AMO_OR   := 1,  
  hpdcache_REQ_AMO_XOR  := 1,  
  hpdcache_REQ_AMO_MAX  := 1,  
  hpdcache_REQ_AMO_MAXU := 1,  
  hpdcache_REQ_AMO_MIN  := 1,  
  hpdcache_REQ_AMO_MINU := 1  
  hpdcache_REQ_CMO := 1  
  END  
  Stimuli: The sequence used is hpdcache_multiple_amo_lr_sc_requests which is driven from hpdcache_single_lr_sc_request.  
  Requirement :  This test  respects the constraints related to hpdcache protocol.  
  Constraint:  Every field of the transaction is randomized except address.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_reg_bit_bash

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg access sequence

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test reg hw reset register test

- **Verification Goal:** Built-in UVM sequences to check CSRs via reg model
- **Criteria Pass Fail:** UVM regmodel flags UVM_ERROR in case of a mismatch
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? HPDCACHE_WBUF_DIR_ENTRIES: 1) +  num_rtab_entry;  
  else  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  default:  
  begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES;  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? HPDCACHE_WBUF_DIR_ENTRIES : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*HPDCACHE_WBUF_DIR_ENTRIES  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = HPDCACHE_WBUF_DIR_ENTRIES;  
  default :    num_expected_write =CNT*HPDCACHE_WBUF_DIR_ENTRIES;  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the MSHR and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of MSHR, RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be NUM_WBUF_ENTRIES.  If the value does not match the expected a UVM_ERROR is flaged.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter enable

- **Verification Goal:** 
  Purpose: The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where accesses are made at the same SET. The number of accepted requests depends on wbuf_threshold, rtab_single_flag, wbuf_waw_flag, wbuf_inhibit_write_coalescing, cfg_wbuf_reset_timecnt_on_write_i  
  Target:  Write Buffer and RTAB.  
  Scenario:  This sequence issues only HPDCACHE_REQ_DATA_WIDTH bits wide cacheable STORE at the same cache line with different offsets. Inter request delay is zero and only one requester is enabled at a time.  
  cnt = $urandom_range(env.m_hpdcache_conf.m_cfg_wbuf_threshold+1, env.m_hpdcache_conf.m_cfg_wbuf_threshold+10);  
  For i=1->HPDCACHE_WBUF_DIR_ENTRIES+HPDCACHE_RTAB_ENTRIES+10  
  tag = random;  
  set = unique_set[i];  
  For j=1->CNT  
  offset=random  
  addr = {tag, set, offset}  
  cacheable=1  
  op = STORE  
  End  
  End  
  Stimuli: The sequence is hpdcache_same_tag_set_access_request_cached  
  Requirements:  In this test, the sequence  is run with memory responses disabled at first (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles. The memory response model accepts each request but does not respond.  
  Constraint:  In this test m_cfg_wbuf_reset_timecnt_on_write is enabled to 1. OP is fixed to HPDCACHE_REQ_STORE. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets are random.  
  Note: Every time a write is observed the wbuf time counter is reset to 0. There is no delay between the requests made to hpdcache. Hence write buffer counter will be reseted all the time.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL): We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number of write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*CNT+HPDCACHE_RTAB_ENTRIES) cycles.  
  num_rtab_entry = (m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES );  
  if wbuf_inhibit_write_coalescing = 1 // write merge not allowed  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin  
  num_expected_write =( (cnt==1) ? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES): 1) +  num_rtab_entry;  
  else  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry  
  end  
  else  
  if(env.m_hpdcache_conf.m_cfg_wbuf_sequential_waw == 1 ) begin // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end else begin  
  case(env.m_hpdcache_conf.m_cfg_wbuf_threshold)  
  0:  
  begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  default:  
  begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  end  
  endcase  
  num_expected_write =  num_expected_write + ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  end  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with Write HPDCACHE_REQ_DATA_WIDTH bits same address (offset random) with threshold reset time counter disable

- **Verification Goal:** 
  Test is same as 2.3.1  
  Constraint                     :  In this test m_cfg_wbuf_reset_timecnt_on_write is disabled.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL)  : We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  Following formula is used to check the expected number write requests accepted by HPDCACHE in the first  (HPDCACHE_WBUF_DIR_ENTRIES*(m_cfg_wbuf_threshold*2+1)+HPDCACHE_RTAB_ENTRIES) cycles.  
  CNT  = (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 0) ? $urandom_range(1, 2) :  
  (env.m_hpdcache_conf.m_cfg_wbuf_threshold == 1) ? $urandom_range(1, 2) :  
  $urandom_range(1, env.m_hpdcache_conf.m_cfg_wbuf_threshold);  
  num_rtab_entry             = ((m_cfg_rtab_single_entry == 1) ? 1 : (HPDCACHE_RTAB_ENTRIES));  
  if(m_cfg_wbuf_sequential_waw == 1 ) begin  // Cannot have 2 writes on the fly at the same address after wbuf SENT (merging is possible)  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin // mergin is not allowed in the wbuf  
  num_expected_write = ((cnt ==1)? MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) : 1) +  num_rtab_entry;  
  end else begin  
  num_expected_write =  cnt*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES)  + num_rtab_entry;  
  end  
  else // no waw=0  
  if(env.m_hpdcache_conf.m_cfg_wbuf_inhibit_write_coalescing == 1) begin  
  num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES) +  num_rtab_entry;  
  else  
  CASE m_cfg_wbuf_threshold  
  [0:1]:           num_expected_write = MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  default :    num_expected_write =CNT*MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES);  
  endcase  
  num_expected_write =  num_expected_write +num_rtab_entry  
  end  
  Note: HPDcache has 3 pipeline stage, so a fuzzyness of 3 expected in the expected write  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with load at the same address (offset random)

- **Verification Goal:** 
  Purpose :  The purpose of this test is to verify the number of requests accepted by the wbuf and rtab in the case where acceses are made at the consecutive SETS.  The number of accepted requests depends on rtab_single_flag.  
  Target:  MSHR and RTAB mecanism  
  Scenerio: In this test, the following sequence  is run with memory reponses disabled for first 1000 cycles. We then check the number of requests accepted by the cache, just before the memory reponses are enabled  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli:  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :  In this test OP is fixed to HPDCACHE_REQ_LOAD. Uncacheable = 0 -> always cacheable. SETs are choses from a UNIQUE set list. TAGs and offsets  are random.  
  The maximum number of requests will be actually dependant of min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS, HPDCACHE_SETS). Here you should replace the 8 by RTAB_ENTRIES  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL) :  
  We check the number of requests accepted by the cache, just before the memory reponses are enabled. If the value does not match the expected a UVM_ERROR is flaged.  
  Expected number of request the moment back pressure is released after 1000 cycles  
  get_req_counter() == (m_cfg_rtab_single_entry == 1) ? HPDCACHE_SETS + 1: HPDCACHE_SETS +RTAB_ENTRIES  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Back Pressure with LOAD
Back Pressure with STORE

- **Verification Goal:** 
  Purpose :  The purpose of this test is to check the functionning of RTAB and Write Buffer in the case accesses are made at the different SETs(unique).  
  Target:  MSHR, RTAB and Write Buffer mechanism  
  Scenario :  In this tests following sequence is run with memory responses disabled for first 1000 cycles.  
  In this test only one requester is enabled.  
  for(int i = 0; i < num_txn; i ++) begin  
  // --------------------------------  
  // Randomize transaction item  
  // --------------------------------  
  if ( !item.randomize() with { m_req_sid == sid ; } )  
  `uvm_fatal("body","Randomization failed");  
  set    = hpdcache_get_req_addr_set(item.m_req_addr);  
  offset = hpdcache_get_req_addr_offset(item.m_req_addr);  
  tag    = hpdcache_get_req_addr_tag(item.m_req_addr);  
  if(i < HPDCACHE_SETS) begin  
  set = unique_set[i];  
  item.m_req_addr = {tag, set, offset};  
  end  
  end  
  Stimuli               : The sequence is hpdcache_consecutive_set_access_request_cached.  
  Requirements:  In this test, the sequence  is run with memory reponses disabled for first 1000 cycles. The memory response model accepts each request but does not respond.  
  Constraint        :   In this test OP is fixed to HPDCACHE_REQ_LOAD/STORE. Uncacheable = 0 -> alwasy cacheable. SETs are UNIQUE in the first 1000 cycles. TAGs and offsets are random.  
  Note: Covers the following case of on hold request  
  5. Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR has no available slots  
  As above, the number of loads shall be min(HPDCACHE_MSHR_SETS*HPDCACHE_MSHR_WAYS,HPDCACHE_SETS)  
- **Criteria Pass Fail:** Criteria (PASS/FAIL)  : In this test in the case of LOAD we get minimum (SETS + RTAB ENTRIES) number of miss on the fly. In the case of the store, requests on fly are expected to be MIN (HPDCACHE_WBUF_DIR_ENTRIES, HPDCACHE_WBUF_DATA_ENTRIES).  If the value does not match the expected a UVM_ERROR is flaged.
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write only with limited back pressure

- **Verification Goal:** 
  Purpose :  The aim of this performance test is to show the benefits of having a write buffer on the performance.  
  Check the bandwidth of cached write at the core interface of HPDcache when writes arrive with no inter request delay.  
  If memory response reply within a delay < NUM_WBUF cycles, the cache should be able to accept every write.  
  Target     : Write Performance  
  Scenario:  Write only test.  
  Stimuli   :  Test is derived from random access tests.  
  Requirement :  
  Following condition should be respected to get full performance  
  1. Store accesses are cacheable  
  2. There is not inter request delay @core interface  
  3. Memory response model reply within minimum (< NUM_WBUF cycles) delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_STORE, uncacheable=0.  
  The wbuf and rtab should be configured to get the maximum output. Following values are used:  
  m_cfg_wbuf_threshold = > 2 < HPDCACHE_WBUF_DIR_ENTRIES  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
  All writes are done at unique SET where no request is on the fly.  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN stores in NB_TXN cycles.  
  In the case where write_buf_dir_entry, write_buf_data_entry < the memory write latency,  almost 3 times degrdation of performance is observed.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Read only with no memory back pressure

- **Verification Goal:** 
  Purpose:  The aim of this performance test is to show the benefits of having a MSHR on the performance.  
  Check the bandwidth of cached reads at the core interface of HPDcache when a read arrives with no inter request delay.  
  If memory response reply within a cycle (or may be cycles < MSHR_SET), the cache should be able to accept a read miss every three cycle.  
  Target    : Load Performance maximising the use of MSHR  
  Scenario : Load only test  
  Stimulie : Test uses random access sequence.  
  Requirement:  
  Following condition are respected to get full performance  
  1. Load accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraint:  
  OP = HPDCACHE_REQ_LOAD, uncacheable=0.  
  The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads in 3*NB_TXN cycles.  
  Note: Here, when you say SET, it should be MSHR_SET (which may be different than the number of sets in the cache HPDCACHE_SETS). Another thing, is that you still need to repeat the MSHR_SET in order to exploit all the MSHR as the MSHR has MSHR_WAYS per MSHR_SET. Thus, I do not know how you generate the addresses, maybe it is already as I propose hereafter:  
  req.address = (random() / CL_BYTES) * CL_BYTES            // align the base address to a cacheline  
  while (true) {  
  req.address = req.address + CL_BYTES  
  }  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Read only with large memory back pressure

- **Verification Goal:** 
  Purpose: The aim of this performance test is to show the benefits of having a MSHR on the performance.  
  Check the bandwidth of cached reads at the core interface of HPDcache when a read arrives with no inter request delay.  
  If memory response reply with a delay of 2*MSHR_SETS*MSHR_WAYS cycle(more realistic delay), the cache should be able to accept a read miss every third cycle.  
  Tarrget:    Load Performance maximising the use of MSHR  
  Scenario: Load only test  
  Stimulie: Test uses random access sequence.  
  Requirements:  
  Following condition are respected to get full performance  
  1. Load accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraints:  
  The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  Criteria (PASS/FAIL):  
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads in 2*3*NB_TXN cycles.  
  I would generate the address as above (cf 2.5.2)  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

#### 📌 Test Case: Write(30%) Read(70% ) with no memory back pressure

- **Verification Goal:** 
  Purpose : Check the bandwidth of cached reads (70%) and cached writes(30%) at the core interface of HPDcache when reads and writes arrive with no inter request delay.  
  Target     : Read and Write Performance  
  Scenario:  Test is constraint to have 70% cacheable read and 30% cacheable  write.  
  Stimuli   :  Test is derived from random access tests.  
  Requirements:  
  Following condition are respected to get full performance  
  1. Load/Store accesses are cacheable  
  2. There is no conflit within the MSHR (An access should not be made on a SET which already has an ongoing miss)  
  3. There is no inter request delay @core interface  
  4. Memory response model reply within minimum delay possible  
  Constraints:  
  OP = HPDCACHE_REQ_LOAD(70%), HPDCACHE_REQ_STORE(30%). Uncacheable = 0.  
  5. The wbuf and rtab should be configurered to get the maximum outuput. Following values are used:  
  m_cfg_wbuf_threshold = > 2  
  m_cfg_wbuf_reset_timecnt_on_write = 1;  
  m_cfg_wbuf_sequential_waw = 0;  
  m_cfg_wbuf_inhibit_write_coalescing = 0;  
  m_cfg_rtab_single_entry = 0  
- **Criteria Pass Fail:** 
  A check is performed at the end of test in report phase.  
  The cache is expected to accept  NB_TXN loads/stores in 3*NB_TXN cycles.  
- **Test Type:** Constrained-Random
- **Coverage Method:** Testcase

## Requirement 28.0: The cache provides a set of pulse event counters which output one-cycle pulses each time a given event occurs

### Sub Feature: evt_o.write_req --> pulses on a write request accepted

#### 📌 Test Case: Event write req

- **Feature Description:** The cache provides a set of pulse event counters which output one-cycle pulses each time a given event occurs
- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.read_req --> pulses on a read request accepted

#### 📌 Test Case: Event read req

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.prefetch_req --> pulses on a  prefetch request accepted

#### 📌 Test Case: Evetn prefetch req

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.uncached_req --> pulses on a  uncached request accepted

#### 📌 Test Case: Event uncached req

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.cmo_req --> pulses on a  CMO request accepted

#### 📌 Test Case: Event cmo req

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.accepted_req --> pulses on a request accepted (any type)

#### 📌 Test Case: Event accepted req

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.cache_write_miss --> pulses on a  Write miss event

#### 📌 Test Case: Event cache write miss

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.cache_read_miss --> pulses on a  Read miss event

#### 📌 Test Case: Event cache read miss

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.req_onhold --> pulses on a  Request put on-hold in the RTAB

#### 📌 Test Case: Event req on hold

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.write_req --> pulses on a write request accepted

#### 📌 Test Case: Event req on hold mshr

- **Feature Description:** The cache provides a set of pulse event counters which output one-cycle pulses each time a given event occurs
- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.req_onhold_wbuf --> pulses on a  Request put on-hold because of a WBUF conflict

#### 📌 Test Case: Event req on hold wbuf

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.req_onhold_rollback --> pulses on a Request put on-hold (again) after a rollback

#### 📌 Test Case: Event req on hold rollback

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

### Sub Feature: evt_o.stall --> pulses on a  Cache stalls request event

#### 📌 Test Case: Event req stall

- **Verification Goal:** 
  Purpose: Coverage that all values of this signal have been covered  
  Method: Code coverage toggle  
  Buckets: 1 bit => 2 buckets  
- **Coverage Method:** Code Coverage

## Requirement 29.0: Support Physical or Virtual Indexing

### Sub Feature: It allows the address and physical memory attributes (PMA) to be sent by the requesters in two different
(but consecutive) cycles. 
The address is split in 2 different parts: one for offset and other for physical tag
This kind of indexing is named Virtually-Indexed Physically-Tagged (VIPT).

#### 📌 Test Case: phys_indexed

- **Feature Description:** Support Physical or Virtual Indexing
- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Sampling Event: The coverage is sampled when a valid request is received.  
  Buckets: 3  
- **Coverage Method:** Functional Coverage

### Sub Feature: When using the virtual indexing, the requester can abort the request during the second cycle of the addressing pipeline. 
In that case, the requester needs to set the req_abort signal to 1. And cache responds with a signal is_aborted (if need_rsp = 1)

#### 📌 Test Case: Abort Reponse Check

- **Verification Goal:** 
  Purpose: The abort responses are generated correctly.  
  Description: If a request is generated with abort field set, in the case of virtually indexed addressing, the cache respond with abort flag. Check abort response in following cases.  
  This check if performed when the cache response is received  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: abort coverage

- **Verification Goal:** 
  Purpose: Coverage of each value of this signal  
  Sampling Event: The coverage is sampled when a valid request is received.  
  Buckets: 2  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Store with Abort response

- **Verification Goal:** 
  Purpose: Cover that a Store with an abort is followed by a LOAD/AMOS (no rsp )on the same line. Cover for cache and uncached transactions.  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid store is recieved.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Load with Abort response

- **Verification Goal:** 
  Purpose: Cover that a Load with an abort response (memory)  is followed by a LOAD/AMO (no rsp ) on the same line. Cover for cache and uncached transactions.  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid load is recieved.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: AMOs with Abort  response

- **Verification Goal:** 
  Purpose: Cover that an AMO with an abort  is followd by a LOAD/AMO(no rsp) on the same line  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid AMO is recieved.  
- **Coverage Method:** Functional Coverage

## Requirement 30.0: HPDcache implements by default a PLRU replacement policy

### Sub Feature: The HPDcache must use this policy to select the victim way where a new cacheline is written

#### 📌 Test Case: test_hpdcache_multiple_directed_addr_bPLRU_prediction

- **Feature Description:** HPDcache implements by default a PLRU replacement policy
- **Verification Goal:** 
  Purpose:  The purpose of this the test is to check the PLRU eviction algorithm using a black box approach.  
  Target:  PLRU algorithm  
  Scenario:  To avoid temporal conflicts between request and refill response which cannot be predicted, in this test each request is sent every N( = 15) cycles and the memory response model is configured to respond with zero delay. We require that the response from the previous request is received before the next request is issued. Otherwise it is impossible to predict the PLRU behavior using a black box approach.  
  Stimuli :  The sequence is derived from 1.2.1  
  Requirement :  This test  respects the constraints related to hpdcache protocol. This test enables a UVM based model in the SB which  does the black box prediction of the PLRU under a limited set of stimulus which is respected by this test.  
  Constraint       :  Every field of the transaction is randomized except Set, address, uncacheable (always 0 -> cacheable) and inter request delay. Memory response model is configured to respond with zero delay.  
  Note:  We note that the environment also has a SV based PLRU model which is bind directly to the memory control module to do the exact prediction of the PLRU using the signals from memory control module (white box assertion based checking).   In the UVM based model, the PLRU prediction takes into accoun the type of transactions.  
- **Criteria Pass Fail:** The TB has UVM based PLRU model which flags a UVM_ERROR in case PLRU algorithm is not respected. A tag directory is maintained which helps predict hit and miss in this particular scenario.
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: test_hpdcache_multiple_random_requests_in_region_bPLRU_prediction

- **Verification Goal:** 
  This is the variant of test 1.2.2 where this test is derived from the test 1.1.4.  
  Scenario: The idea is to perform black box PLRU prediction when the memory accesses are distributed across a memory region. In 1.2.2 the accesses where focused on a single set to provoke frequent evictions.  
- **Criteria Pass Fail:** TB has multiple checks, in case of an error as UVM_ERROR is flagged. Please refer to section "Environnement Checks( section: 6)".
- **Test Type:** Directed Self-Checking
- **Coverage Method:** Testcase

#### 📌 Test Case: PLU Check

- **Verification Goal:** 
  Purpose: Check if PLRU algorithm is correct.  
  Method: A SV based PLRU model is bind to the mem_ctrl instance in the HPDcache to be able the check the correct functioning of PLRU.  
- **Test Type:** ENV capability, not specific test
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Bit-PLRU configuration variable

- **Verification Goal:** 
  Purpose:  To make sure that plru bit is enabled. Cover that in the TB the plru is enabled (in the directed test)  
  Buckets: 1  
  Sampling Event: Sample when PLRU check is done.  
- **Coverage Method:** Functional Coverage

### Sub Feature: Replacement policy must provide one bit per cache line

#### 📌 Test Case: Least Recently used bit

- **Verification Goal:** 
  Purpose: To make sure every bit of PLRU has been covered. Cover that each PLRU bit is least recently used (first 0) -> for a PLRU status of 4 bits  
  XX10  
  X101  
  1011  
  0111  
  Sampling Event: When the PLRU bit is flipped.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Each operation with PLRU bit set

- **Verification Goal:** 
  Purpose: Every cache operation on each line with PLRU bit set  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

### Sub Feature: LRU bits are 0 at reset and mut be udated at each read, store, atomic operation.

#### 📌 Test Case: Least Recently used bit

- **Verification Goal:** 
  Purpose: To make sure every bit of PLRU has been covered. Cover that each PLRU bit is least recently used (first 0) -> for a PLRU status of 4 bits  
  XX10  
  X101  
  1011  
  0111  
  Sampling Event: When the PLRU bit is flipped.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: HIT (write/read) each line

- **Verification Goal:** 
  Purpose: Cover that each line is a read/write hit  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

### Sub Feature: LRU bits are updated by refill

#### 📌 Test Case: MISS(write/read) each line

- **Verification Goal:** 
  Purpose: Cover that each line is a read/write miss  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Evict each line

- **Verification Goal:** 
  Purpose:cover that each line has been evicted  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

### Sub Feature: Cache controler applies the plru algomrithm in the case of a hit for a request from a requester

#### 📌 Test Case: MISS(write/read) each line

- **Verification Goal:** 
  Purpose: Cover that each line is a read/write miss  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

### Sub Feature: Cache controler applies the plru algorithm in the case of a refill, once victim way is selected

#### 📌 Test Case: Evict each line

- **Verification Goal:** 
  Purpose:cover that each line has been evicted  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

### Sub Feature: In the case of error responses, PLRU is not updated

#### 📌 Test Case: Store with Error response

- **Verification Goal:** 
  Purpose: Cache is updated in the case of cached store in any case error or not.  Cover that a Store with an error response(memory ) is followed by a LOAD/AMOS (no rsp )on the same line. Cover for cache and uncached transactions.  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid store is recieved.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: Load with Error response

- **Verification Goal:** 
  Purpose: Cover that a Load (miss) with an error response (memory)  is followed by a LOAD/AMO (no rsp ) on the same line. Cover for cache and uncached  
  transactions.  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid load is recieved.  
- **Coverage Method:** Functional Coverage

#### 📌 Test Case: AMOs with Error response

- **Verification Goal:** 
  Purpose: Cover that an AMO with an error response(memory) is followd by a LOAD/AMO(no rsp) on the same line  
  Trigger and Clocking Events: The clock is a core clk. The assertion is triggered by when a valid AMO is recieved.  
- **Coverage Method:** Functional Coverage

### Sub Feature: In the case of CMOs (fence or invalid), PLRU is not updated

#### 📌 Test Case: Each CMOs with PLRU bit set

- **Verification Goal:** 
  Purpose: CMOs operation does not update the PLRU. In this coverage it is verified that a CMO operation is performed in each PLRU bit set  
  Sampling Event: When a write/read hit is predicted by the model of PLRU (SV base model)  
- **Coverage Method:** Functional Coverage

## Requirement 31.0: HPDCache must make sure no X is propgated

### Sub Feature: HPDcache must make sure that when ready & valid = 1,  no signal is at X or Z on the respective interface

#### 📌 Test Case: No signals with X/Z values when valid

- **Feature Description:** HPDCache must make sure no X is propgated
- **Verification Goal:** 
  Purpose: Assertion to check that no signal got an X/Z values in it when the valid signal is enabled.  
  Following are the signals.  
  Core request  
  tag  
  offset  
  wdata  
  op  
  be  
  size  
  uncacheable  
  sid  
  tid  
  need_rsp  
  phy_indexed  
  pma.io  
  pma.uncached  
  Core response  
  rdata  
  sid  
  tid  
  error  
  abort  
  Method: SV Assertion $unknown is used to check the signals.  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

#### 📌 Test Case: No signals with X/Z values when valid

- **Verification Goal:** 
  Purpose: Assertion to check that no signal got an X/Z values in it when the valid signal is enabled  
  memory request interface (read and write)  
  mem_req_addr  
  mem_req_len  
  mem_req_size  
  mem_req_id  
  mem_req_command  
  mem_req_atomic  
  mem_req_cacheable  
  memory write data request  
  mem_req_w_data  
  mem_req_w_be  
  mem_req_w_last  
  memory read respons interface (read and write)  
  mem_resp_r_error  
  mem_resp_r_id  
  mem_resp_r_data  
  mem_resp_r_last  
  memory write respons interface (read and write)  
  mem_resp_w_is_atomic  
  mem_resp_w_error  
  mem_resp_w_id  
  Method: SV Assertion $unknown is used to check the signals.  
  Link: hpdcache_sva.sv  
- **Coverage Method:** Assertion Coverage

