// =============================================================================
// PTW source-side checker shared types
//
// Stage 1 scope:
//   - Centralize PTW request type, page-size, target, level, fault, and drop
//     encodings used by future source-side monitor/ref-model/scoreboard work.
//   - Provide raw PTE decode and refill flg/tag/data formatting helpers.
//   - Provide lightweight transaction shells so analysis port names and types
//     are stable before functional sampling/modeling is implemented.
//
// Stage 3 scope:
//   - Add monitor/logger transaction payloads for request accept, actual
//     completion, context, PDE, level, and drop observability. These are still
//     provisional evidence until the stage-4 ref model/SB consumes them.
// =============================================================================
`ifndef PTW_SOURCE_TYPES_SVH
`define PTW_SOURCE_TYPES_SVH

typedef enum logic [2:0] {
  PTW_SRC_TYPE_UNKNOWN = 3'b000,
  PTW_SRC_TYPE_LOAD  = 3'b010,
  PTW_SRC_TYPE_FETCH = 3'b011,
  PTW_SRC_TYPE_PFU   = 3'b100,
  PTW_SRC_TYPE_STORE = 3'b110
} ptw_src_req_type_e;

typedef enum logic [2:0] {
  PTW_SRC_PGS_NONE = 3'b000,
  PTW_SRC_PGS_4K = 3'b001,
  PTW_SRC_PGS_2M = 3'b010,
  PTW_SRC_PGS_1G = 3'b100
} ptw_src_page_size_e;

typedef enum int unsigned {
  PTW_SRC_LEVEL_NONE = 0,
  PTW_SRC_LEVEL_FST  = 1,
  PTW_SRC_LEVEL_SCD  = 2,
  PTW_SRC_LEVEL_THD  = 3
} ptw_src_level_e;

typedef enum int unsigned {
  PTW_SRC_FAULT_NONE        = 0,
  PTW_SRC_FAULT_PAGE        = 1,
  PTW_SRC_FAULT_ACCESS      = 2,
  PTW_SRC_FAULT_BUS_ERROR   = 3,
  PTW_SRC_FAULT_UNSUPPORTED = 4
} ptw_src_fault_kind_e;

typedef enum int unsigned {
  PTW_SRC_DROP_NONE       = 0,
  PTW_SRC_DROP_RESET      = 1,
  PTW_SRC_DROP_ABORT      = 2,
  PTW_SRC_DROP_LATE_DATA  = 3,
  PTW_SRC_DROP_DUPLICATE  = 4,
  PTW_SRC_DROP_UNMODELED  = 5,
  PTW_SRC_DROP_ABORT_BUS_ERROR = 6,
  PTW_SRC_DROP_PRE_EXISTING_EXCEPTION_GRANT = 7
} ptw_src_drop_reason_e;

typedef enum int unsigned {
  PTW_SRC_TARGET_NONE  = 0,
  PTW_SRC_TARGET_L2TLB = 1,
  PTW_SRC_TARGET_L1I   = 2,
  PTW_SRC_TARGET_L1D   = 3,
  PTW_SRC_TARGET_PFU   = 4
} ptw_src_target_kind_e;

typedef enum int unsigned {
  PTW_SRC_EXP_NONE         = 0,
  PTW_SRC_EXP_REFILL       = 1,
  PTW_SRC_EXP_PAGE_FAULT   = 2,
  PTW_SRC_EXP_ACCESS_FAULT = 3,
  PTW_SRC_EXP_DROP         = 4,
  PTW_SRC_EXP_ILLEGAL      = 5,
  PTW_SRC_EXP_UNKNOWN      = 6
} ptw_src_exp_kind_e;

typedef enum int unsigned {
  PTW_SRC_PDE_EVT_NONE   = 0,
  PTW_SRC_PDE_EVT_HIT    = 1,
  PTW_SRC_PDE_EVT_UPDATE = 2,
  PTW_SRC_PDE_EVT_CLEAR  = 3,
  PTW_SRC_PDE_EVT_MISS   = 4
} ptw_src_pde_evt_kind_e;

typedef struct packed {
  ptw_src_req_type_e req_type;
  logic [5:0]        id;
} ptw_src_key_s;

typedef struct packed {
  logic        v;
  logic        r;
  logic        w;
  logic        x;
  logic        u;
  logic        g;
  logic        a;
  logic        d;
  logic [1:0]  rsw;
  ppn_t        ppn;
  logic [20:0] high_reserved;
  logic [4:0]  ext_attr;
  logic        leaf;
  logic        write_only;
} ptw_src_pte_decode_s;

typedef struct packed {
  logic               valid;
  vpn_t               vpn;
  asid_t              asid;
  ptw_src_page_size_e page_size;
  logic               global;
} ptw_src_refill_tag_s;

typedef struct packed {
  ppn_t       ppn;
  logic [4:0] ext_attr;
  logic [1:0] rsw;
  logic       d;
  logic       a;
  logic       u;
  logic       x;
  logic       w;
  logic       r;
  logic       v;
} ptw_src_refill_data_s;

function automatic bit ptw_src_is_legal_req_type(input logic [2:0] req_type);
  return (req_type == PTW_SRC_TYPE_LOAD)
      || (req_type == PTW_SRC_TYPE_FETCH)
      || (req_type == PTW_SRC_TYPE_PFU)
      || (req_type == PTW_SRC_TYPE_STORE);
endfunction

function automatic bit ptw_src_is_legal_page_size(input logic [2:0] page_size);
  return (page_size == PTW_SRC_PGS_4K)
      || (page_size == PTW_SRC_PGS_2M)
      || (page_size == PTW_SRC_PGS_1G);
endfunction

function automatic bit ptw_src_is_leaf_pte(input pte_t raw_pte);
  return raw_pte[1] || raw_pte[3];
endfunction

function automatic bit ptw_src_is_write_only_pte(input pte_t raw_pte);
  return raw_pte[2] && !raw_pte[1];
endfunction

function automatic ptw_src_pte_decode_s ptw_src_decode_pte(input pte_t raw_pte);
  ptw_src_pte_decode_s dec;

  dec.v             = raw_pte[0];
  dec.r             = raw_pte[1];
  dec.w             = raw_pte[2];
  dec.x             = raw_pte[3];
  dec.u             = raw_pte[4];
  dec.g             = raw_pte[5];
  dec.a             = raw_pte[6];
  dec.d             = raw_pte[7];
  dec.rsw           = raw_pte[9:8];
  dec.ppn           = raw_pte[37:10];
  dec.high_reserved = raw_pte[58:38];
  dec.ext_attr      = raw_pte[63:59];
  dec.leaf          = ptw_src_is_leaf_pte(raw_pte);
  dec.write_only    = ptw_src_is_write_only_pte(raw_pte);

  return dec;
endfunction

function automatic logic [13:0] ptw_src_make_refill_flg(
  input logic [4:0] ext_attr,
  input pte_t       raw_pte
);
  return {ext_attr, raw_pte[9:6], raw_pte[4:0]};
endfunction

function automatic logic [47:0] ptw_src_make_refill_tag(
  input vpn_t               vpn,
  input asid_t              asid,
  input ptw_src_page_size_e page_size,
  input logic               global
);
  return {1'b1, vpn, asid, page_size, global};
endfunction

function automatic logic [41:0] ptw_src_make_refill_data(
  input ppn_t       ppn,
  input logic [4:0] ext_attr,
  input pte_t       raw_pte
);
  return {ppn, ptw_src_make_refill_flg(ext_attr, raw_pte)};
endfunction

function automatic ptw_src_refill_tag_s ptw_src_decode_refill_tag(
  input logic [47:0] raw_tag
);
  ptw_src_refill_tag_s tag;

  tag.valid     = raw_tag[47];
  tag.vpn       = raw_tag[46:20];
  tag.asid      = raw_tag[19:4];
  tag.page_size = ptw_src_page_size_e'(raw_tag[3:1]);
  tag.global    = raw_tag[0];

  return tag;
endfunction

function automatic ptw_src_refill_data_s ptw_src_decode_refill_data(
  input logic [41:0] raw_data
);
  ptw_src_refill_data_s data;

  data.ppn      = raw_data[41:14];
  data.ext_attr = raw_data[13:9];
  data.rsw      = raw_data[8:7];
  data.d        = raw_data[6];
  data.a        = raw_data[5];
  data.u        = raw_data[4];
  data.x        = raw_data[3];
  data.w        = raw_data[2];
  data.r        = raw_data[1];
  data.v        = raw_data[0];

  return data;
endfunction

function automatic string ptw_src_type_name(input logic [2:0] req_type);
  case (req_type)
    PTW_SRC_TYPE_LOAD:  return "load";
    PTW_SRC_TYPE_FETCH: return "fetch";
    PTW_SRC_TYPE_PFU:   return "pfu";
    PTW_SRC_TYPE_STORE: return "store";
    default:            return "unknown";
  endcase
endfunction

function automatic string ptw_src_page_size_name(input logic [2:0] page_size);
  case (page_size)
    PTW_SRC_PGS_4K: return "4k";
    PTW_SRC_PGS_2M: return "2m";
    PTW_SRC_PGS_1G: return "1g";
    default:        return "none";
  endcase
endfunction

class ptw_src_req_accept_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_req_accept_txn)

  ptw_src_req_type_e req_type;
  logic [5:0]        id;
  vpn_t              vpn;
  asid_t             asid;
  int unsigned       cycle;

  function new(string name = "ptw_src_req_accept_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("cycle=%0d type=%s id=0x%02h vpn=0x%07h asid=0x%04h",
      cycle, req_type.name(), id, vpn, asid);
  endfunction
endclass : ptw_src_req_accept_txn

class ptw_src_abort_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_abort_txn)

  ptw_src_key_s          key;
  ptw_src_drop_reason_e  drop_reason;
  vpn_t                  vpn;
  bit                    has_key;
  int unsigned           cycle;

  function new(string name = "ptw_src_abort_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("cycle=%0d reason=%s has_key=%0b type=%s id=0x%02h vpn=0x%07h",
      cycle, drop_reason.name(), has_key, key.req_type.name(), key.id, vpn);
  endfunction
endclass : ptw_src_abort_txn

class ptw_src_expected_rsp_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_expected_rsp_txn)

  ptw_src_exp_kind_e     kind;
  ptw_src_req_type_e     req_type;
  logic [5:0]            id;
  vpn_t                  vpn;
  asid_t                 asid;
  ptw_src_page_size_e    page_size;
  ppn_t                  ppn;
  logic                  global;
  logic [13:0]           flg;
  ptw_src_target_kind_e  target;
  ptw_src_fault_kind_e   fault_kind;
  ptw_src_drop_reason_e  drop_reason;

  function new(string name = "ptw_src_expected_rsp_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "kind=%s type=%s id=0x%02h vpn=0x%07h asid=0x%04h pgs=%s ppn=0x%07h global=%0b flg=0x%04h target=%s fault=%s drop=%s",
      kind.name(), req_type.name(), id, vpn, asid, page_size.name(), ppn,
      global, flg, target.name(), fault_kind.name(), drop_reason.name());
  endfunction
endclass : ptw_src_expected_rsp_txn

class ptw_src_actual_rsp_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_actual_rsp_txn)

  ptw_src_exp_kind_e     kind;
  ptw_src_req_type_e     req_type;
  logic [5:0]            id;
  vpn_t                  vpn;
  asid_t                 asid;
  ptw_src_page_size_e    page_size;
  ppn_t                  ppn;
  logic                  global;
  logic [13:0]           flg;
  ptw_src_target_kind_e  target;
  ptw_src_fault_kind_e   fault_kind;
  logic [47:0]           raw_tag;
  logic [41:0]           raw_data;
  logic                  completion_or_seen;
  logic                  refill_valid;
  logic                  page_fault;
  logic                  access_fault;
  logic                  target_l2tlb;
  logic                  target_l1i;
  logic                  target_l1d;
  logic                  target_pfu;
  int unsigned           cycle;

  function new(string name = "ptw_src_actual_rsp_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "cycle=%0d kind=%s type=%s id=0x%02h vpn=0x%07h asid=0x%04h pgs=%s ppn=0x%07h global=%0b flg=0x%04h target=%s target_mask={l2=%0b,l1i=%0b,l1d=%0b,pfu=%0b} fault=%s cmplt_or=%0b refill=%0b pf=%0b af=%0b raw_tag=0x%012h raw_data=0x%011h",
      cycle, kind.name(), req_type.name(), id, vpn, asid, page_size.name(),
      ppn, global, flg, target.name(), target_l2tlb, target_l1i, target_l1d,
      target_pfu, fault_kind.name(), completion_or_seen, refill_valid,
      page_fault, access_fault, raw_tag, raw_data);
  endfunction
endclass : ptw_src_actual_rsp_txn

class ptw_src_ctx_sample_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_ctx_sample_txn)

  ptw_src_req_type_e req_type;
  logic [5:0]        id;
  vpn_t              vpn;
  asid_t             asid;
  ppn_t              satp_ppn;
  bit                maee;
  bit                mprv;
  bit                mxr;
  bit                sum;
  logic [1:0]        mpp;
  logic [1:0]        priv_mode;
  int unsigned       cycle;

  function new(string name = "ptw_src_ctx_sample_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "cycle=%0d type=%s id=0x%02h vpn=0x%07h asid=0x%04h satp_ppn=0x%07h maee=%0b mprv=%0b mpp=0x%0h mxr=%0b sum=%0b priv=0x%0h",
      cycle, req_type.name(), id, vpn, asid, satp_ppn, maee, mprv, mpp,
      mxr, sum, priv_mode);
  endfunction
endclass : ptw_src_ctx_sample_txn

class ptw_src_level_evt_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_level_evt_txn)

  int unsigned       cycle;
  int unsigned       twu_idx;
  ptw_src_level_e    level;
  ptw_src_req_type_e req_type;
  logic [5:0]        id;
  vpn_t              vpn;
  logic [39:0]       pte_pa;
  pte_t              pte_data;
  bit                mbuf_req;
  bit                mbuf_data_vld;
  bit                refill_req;
  bit                page_fault;
  bit                access_fault;
  bit                pmp_vld;
  bit                pmp_grant;
  bit                pmp_deny;
  bit                pmp_wait;
  bit                sysmap_hit;
  logic [4:0]        sysmap_flg;

  function new(string name = "ptw_src_level_evt_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "cycle=%0d twu=%0d level=%s type=%s id=0x%02h vpn=0x%07h pte_pa=0x%010h pte=0x%016h mbuf_req=%0b data_vld=%0b refill_req=%0b pf=%0b af=%0b pmp{vld=%0b grant=%0b deny=%0b wait=%0b} sysmap{hit=%0b flg=0x%02h}",
      cycle, twu_idx, level.name(), req_type.name(), id, vpn, pte_pa,
      pte_data, mbuf_req, mbuf_data_vld, refill_req, page_fault, access_fault,
      pmp_vld, pmp_grant, pmp_deny, pmp_wait, sysmap_hit, sysmap_flg);
  endfunction
endclass : ptw_src_level_evt_txn

class ptw_src_pde_evt_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_pde_evt_txn)

  int unsigned           cycle;
  ptw_src_pde_evt_kind_e kind;
  ptw_src_req_type_e     req_type;
  logic [5:0]            id;
  vpn_t                  vpn;
  ppn_t                  ppn;
  bit                    l1_hit;
  bit                    l2_hit;
  bit                    clear;
  bit                    update;
  logic [1:0]            update_level;
  vpn_t                  update_vpn;
  ppn_t                  update_ppn;
  logic [15:0]           l1_update_vec;
  logic [15:0]           l2_update_vec;

  function new(string name = "ptw_src_pde_evt_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "cycle=%0d kind=%s type=%s id=0x%02h vpn=0x%07h ppn=0x%07h hit{l1=%0b,l2=%0b} clear=%0b update=%0b upd_level=0x%0h upd_vpn=0x%07h upd_ppn=0x%07h l1_upd=0x%04h l2_upd=0x%04h",
      cycle, kind.name(), req_type.name(), id, vpn, ppn, l1_hit, l2_hit,
      clear, update, update_level, update_vpn, update_ppn,
      l1_update_vec, l2_update_vec);
  endfunction
endclass : ptw_src_pde_evt_txn

class ptw_src_drop_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_drop_txn)

  int unsigned          cycle;
  ptw_src_key_s         key;
  vpn_t                 vpn;
  bit                   has_key;
  ptw_src_drop_reason_e drop_reason;
  bit                   reset_drop;
  bit                   abort_drop;
  bit                   late_data;
  bit                   abort_bus_error;
  bit                   pre_existing_exception_grant;

  function new(string name = "ptw_src_drop_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf(
      "cycle=%0d reason=%s has_key=%0b type=%s id=0x%02h vpn=0x%07h reset=%0b abort=%0b late_data=%0b abort_bus_error=%0b pre_existing_exception=%0b",
      cycle, drop_reason.name(), has_key, key.req_type.name(), key.id, vpn,
      reset_drop, abort_drop, late_data, abort_bus_error,
      pre_existing_exception_grant);
  endfunction
endclass : ptw_src_drop_txn

`endif // PTW_SOURCE_TYPES_SVH
