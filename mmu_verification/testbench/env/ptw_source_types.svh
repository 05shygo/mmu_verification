// =============================================================================
// PTW source-side checker shared types
//
// Stage 1 scope:
//   - Centralize PTW request type, page-size, target, level, fault, and drop
//     encodings used by future source-side monitor/ref-model/scoreboard work.
//   - Provide raw PTE decode and refill flg/tag/data formatting helpers.
//   - Provide lightweight transaction shells so analysis port names and types
//     are stable before functional sampling/modeling is implemented.
// =============================================================================
`ifndef PTW_SOURCE_TYPES_SVH
`define PTW_SOURCE_TYPES_SVH

typedef enum logic [2:0] {
  PTW_SRC_TYPE_LOAD  = 3'b010,
  PTW_SRC_TYPE_FETCH = 3'b011,
  PTW_SRC_TYPE_PFU   = 3'b100,
  PTW_SRC_TYPE_STORE = 3'b110
} ptw_src_req_type_e;

typedef enum logic [2:0] {
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
  PTW_SRC_DROP_UNMODELED  = 5
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
  PTW_SRC_EXP_ILLEGAL      = 5
} ptw_src_exp_kind_e;

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
    default:        return "unknown";
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
endclass : ptw_src_req_accept_txn

class ptw_src_abort_txn extends uvm_sequence_item;
  `uvm_object_utils(ptw_src_abort_txn)

  ptw_src_key_s          key;
  ptw_src_drop_reason_e  drop_reason;
  int unsigned           cycle;

  function new(string name = "ptw_src_abort_txn");
    super.new(name);
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

  function new(string name = "ptw_src_actual_rsp_txn");
    super.new(name);
  endfunction
endclass : ptw_src_actual_rsp_txn

`endif // PTW_SOURCE_TYPES_SVH
