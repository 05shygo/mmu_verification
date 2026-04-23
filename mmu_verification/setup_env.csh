#!/bin/csh
# MMU UVM Verification Environment Setup (csh/tcsh)
# Usage: source setup_env.csh  (must be sourced from mmu_verification/ root)

setenv PROJECT_DIR     ${PWD}
setenv MMU_RTL_DIR     ${PROJECT_DIR}/../mmu/rtl
setenv CORE_V_VERIF    ${PROJECT_DIR}/modules/dv_utils
setenv CV_DV_UTILS_DIR ${CORE_V_VERIF}/lib/cv_dv_utils

echo "PROJECT_DIR      = ${PROJECT_DIR}"
echo "MMU_RTL_DIR      = ${MMU_RTL_DIR}"
echo "CV_DV_UTILS_DIR  = ${CV_DV_UTILS_DIR}"

# Source local overrides if present (not tracked by git)
if ( -f ${PROJECT_DIR}/setup.local.csh ) then
    source ${PROJECT_DIR}/setup.local.csh
endif
