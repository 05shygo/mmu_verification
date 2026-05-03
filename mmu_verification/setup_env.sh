#!/bin/bash
# MMU UVM Verification Environment Setup (bash/sh)
# Usage: source setup_env.sh
#
# For server-specific tool paths, create setup.local.sh from the template:
#   cp setup.local.sh.example setup.local.sh   # then edit with your VCS_HOME
# setup.local.sh is listed in .gitignore and is never committed.

export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MMU_RTL_DIR=${PROJECT_DIR}/../mmu/rtl
export CORE_V_VERIF=${PROJECT_DIR}/modules/dv_utils
export CV_DV_UTILS_DIR=${CORE_V_VERIF}/lib/cv_dv_utils

# --- Load server-specific tool paths (not in git) ---
if [[ -f ${PROJECT_DIR}/setup.local.sh ]]; then
    source ${PROJECT_DIR}/setup.local.sh
fi

# --- Auto-extend PATH from VCS_HOME / VERDI_HOME if set but not yet in PATH ---
if [[ -n "${VCS_HOME}" ]] && ! command -v vcs &>/dev/null; then
    export PATH=${VCS_HOME}/bin:${PATH}
fi
if [[ -n "${VERDI_HOME}" ]] && ! command -v verdi &>/dev/null; then
    export PATH=${VERDI_HOME}/bin:${PATH}
fi

# --- Summary ---
echo "PROJECT_DIR      = ${PROJECT_DIR}"
echo "MMU_RTL_DIR      = ${MMU_RTL_DIR}"
echo "CORE_V_VERIF     = ${CORE_V_VERIF}"
echo "CV_DV_UTILS_DIR  = ${CV_DV_UTILS_DIR}"
if command -v vcs &>/dev/null; then
    echo "vcs              = $(command -v vcs)"
else
    echo "WARNING: 'vcs' not found in PATH."
    echo "  -> Copy and edit the template: cp setup.local.sh.example setup.local.sh"
    echo "  -> Set VCS_HOME to your server's VCS install directory."
fi
