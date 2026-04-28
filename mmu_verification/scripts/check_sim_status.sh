#!/usr/bin/env bash

set -u

MAX_MATCHES="${MMU_LOG_MAX_MATCHES:-20}"
CHAIN_MAX_MATCHES="${MMU_LOG_CHAIN_MAX_MATCHES:-8}"

usage() {
  echo "Usage: $0 <log1> [log2 ...]" >&2
}

extract_uvm_count() {
  local key="$1"
  local log="$2"
  awk -v key="$key" '
    $0 ~ ("^" key "[[:space:]]*:") {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9]+$/) {
          val = $i;
        }
      }
    }
    END {
      if (val == "") {
        print "";
      } else {
        print val;
      }
    }
  ' "$log"
}

count_error_hits() {
  local log="$1"
  awk '
    /^UVM_ERROR[[:space:]]*:/ { next }
    /^UVM_FATAL[[:space:]]*:/ { next }
    /UVM_ERROR / || /UVM_FATAL / || /Error-/ || /Error:/ || /Fatal:/ || /ASSERT/ || /SVA/ || /TEST FAILED/ || /FAILED:/ {
      count++;
    }
    END {
      print count + 0;
    }
  ' "$log"
}

print_error_hits() {
  local log="$1"
  local limit="$2"
  awk -v limit="$limit" '
    /^UVM_ERROR[[:space:]]*:/ { next }
    /^UVM_FATAL[[:space:]]*:/ { next }
    /UVM_ERROR / || /UVM_FATAL / || /Error-/ || /Error:/ || /Fatal:/ || /ASSERT/ || /SVA/ || /TEST FAILED/ || /FAILED:/ {
      printf("    %d:%s\n", NR, $0);
      shown++;
      if (shown >= limit) {
        exit;
      }
    }
  ' "$log"
}

extract_translation_mismatch_keys() {
  local log="$1"
  local limit="$2"
  awk -v limit="$limit" '
    /^UVM_ERROR[[:space:]]*:/ { next }
    /mmu_translation_sb/ && /PA mismatch/ {
      ch = "";
      va = "";
      if (match($0, /\[LSU_P[01]\]/)) {
        ch = substr($0, RSTART + 1, RLENGTH - 2);
      }
      if (match($0, /VA=0x[0-9a-fA-F]+/)) {
        va = substr($0, RSTART + 3, RLENGTH - 3);
      }
      if (ch != "" && va != "") {
        key = ch " " va;
        if (!seen[key]) {
          print key;
          seen[key] = 1;
          shown++;
          if (shown >= limit) {
            exit;
          }
        }
      }
    }
  ' "$log"
}

print_whitebox_chain_for_key() {
  local log="$1"
  local channel="$2"
  local va="$3"
  local limit="$4"
  awk -v ch="$channel" -v va="$va" -v limit="$limit" '
    index($0, "[" ch "][WB]") && index($0, "VA=" va) {
      printf("    %d:%s\n", NR, $0);
      shown++;
      if (shown >= limit) {
        exit;
      }
    }
  ' "$log"
}

print_translation_whitebox_chain() {
  local log="$1"
  local key_limit="$2"
  local wb_limit="$3"
  local keys
  local key
  local channel
  local va
  local printed=0

  keys=$(extract_translation_mismatch_keys "$log" "$key_limit")
  if [ -z "$keys" ]; then
    return 0
  fi

  echo "  translation whitebox chain:"
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    channel="${key%% *}"
    va="${key#* }"
    echo "    key: ${channel} VA=${va}"
    print_whitebox_chain_for_key "$log" "$channel" "$va" "$wb_limit"
    printed=1
  done <<EOF
$keys
EOF

  if [ "$printed" -eq 0 ]; then
    echo "    (no [LSU_Px][WB] lines matched keys)"
  fi
}

check_log() {
  local log="$1"
  local summary_seen
  local eot_seen
  local uvm_error
  local uvm_fatal
  local hit_count
  local status="PASS"
  local reason="UVM summary clean"

  if [ ! -f "$log" ]; then
    echo "[FAIL] $log"
    echo "  reason : log file not found"
    return 1
  fi

  summary_seen=$(grep -c 'UVM Report Summary' "$log" 2>/dev/null || true)
  eot_seen=$(grep -c -E 'UVM Report Summary|V C S   S i m u l a t i o n   R e p o r t|\$finish called|TEST COMPLETED' "$log" 2>/dev/null || true)
  uvm_error=$(extract_uvm_count "UVM_ERROR" "$log")
  uvm_fatal=$(extract_uvm_count "UVM_FATAL" "$log")
  hit_count=$(count_error_hits "$log")

  if [ -n "$uvm_error" ] && [ -n "$uvm_fatal" ]; then
    if [ "$uvm_error" -ne 0 ] || [ "$uvm_fatal" -ne 0 ]; then
      status="FAIL"
      reason="UVM summary reports UVM_ERROR=$uvm_error UVM_FATAL=$uvm_fatal"
    fi
  elif [ "$hit_count" -ne 0 ]; then
    status="FAIL"
    reason="log contains error/fatal patterns but no final UVM summary counts"
  elif [ "$eot_seen" -eq 0 ] || [ "$summary_seen" -eq 0 ]; then
    status="FAIL"
    reason="log missing final UVM/VCS completion summary"
  fi

  echo "[$status] $log"
  echo "  summary: UVM_ERROR=${uvm_error:-N/A} UVM_FATAL=${uvm_fatal:-N/A} error_hits=$hit_count"
  echo "  reason : $reason"

  if [ "$status" = "FAIL" ] && [ "$hit_count" -ne 0 ]; then
    echo "  error snippets:"
    print_error_hits "$log" "$MAX_MATCHES"
    if [ "$hit_count" -gt "$MAX_MATCHES" ]; then
      echo "    ... truncated, total matched lines: $hit_count"
    fi
    print_translation_whitebox_chain "$log" 4 "$CHAIN_MAX_MATCHES"
  fi

  if [ "$status" = "PASS" ]; then
    return 0
  fi
  return 1
}

main() {
  local rc=0
  local pass_count=0
  local fail_count=0
  local log

  if [ "$#" -lt 1 ]; then
    usage
    exit 2
  fi

  for log in "$@"; do
    if check_log "$log"; then
      pass_count=$((pass_count + 1))
    else
      fail_count=$((fail_count + 1))
      rc=1
    fi
    echo
  done

  echo "=== run_check summary ==="
  echo "PASS logs: $pass_count"
  echo "FAIL logs: $fail_count"

  exit "$rc"
}

main "$@"
