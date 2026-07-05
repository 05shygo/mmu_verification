#!/bin/bash
#=============================================================================
# run_fc.sh : launch Fusion Compiler (fc_shell) to synthesize ct_mmu_top
# Usage:
#   ./run_fc.sh                # full synthesis (compile_ultra, ~30 min)
#   ./run_fc.sh smoke          # RTL read+elaborate+link only (~2 min)
#   ./run_fc.sh quick          # compile -map_effort medium (~10 min)
#   CLK_NS=1.0 ./run_fc.sh     # retarget clock to 1 GHz
#=============================================================================
set -e
cd "$(dirname "$0")"

MODE="${1:-full}"
export CLK_PERIOD_NS_OVR="${CLK_NS:-}"

FC_DIR=/x2025/GPrj1/IC1/mmu_verification/syn/fc
STAMP=$(date +%Y%m%d_%H%M%S)

case "$MODE" in
  smoke)
    SCRIPT=$FC_DIR/scripts/smoke.tcl
    LOG=$FC_DIR/logs/smoke_${STAMP}.log
    echo "[smoke] RTL parse/elaborate/link check. log -> $LOG"
    ;;
  quick)
    SCRIPT=$FC_DIR/scripts/compile.tcl
    sed 's/set ::COMPILE_EFFORT.*/set ::COMPILE_EFFORT "medium"/' $SCRIPT > $FC_DIR/scripts/compile_quick.tcl
    SCRIPT=$FC_DIR/scripts/compile_quick.tcl
    LOG=$FC_DIR/logs/compile_quick_${STAMP}.log
    echo "[quick] medium-effort synthesis. log -> $LOG"
    ;;
  full|"")
    SCRIPT=$FC_DIR/scripts/compile.tcl
    LOG=$FC_DIR/logs/compile_full_${STAMP}.log
    echo "[full] compile_ultra synthesis. log -> $LOG"
    ;;
  *)
    echo "Usage: $0 [smoke|quick|full]"; exit 1;;
esac

# Override clock period if provided
if [ -n "$CLK_PERIOD_NS_OVR" ]; then
  TMPSCR=/tmp/compile_${STAMP}.tcl
  sed "s/set ::CLK_PERIOD_NS.*/set ::CLK_PERIOD_NS $CLK_PERIOD_NS_OVR/" $SCRIPT > $TMPSCR
  SCRIPT=$TMPSCR
  echo "       clock period overridden to ${CLK_PERIOD_NS_OVR} ns"
fi

# Launch Fusion Compiler (DC-compatible mode)
fc_shell -no_init \
         -x "set_app_var sh_source_uses_search_path true" \
         -f "$SCRIPT" 2>&1 | tee "$LOG"

exit ${PIPESTATUS[0]}
