#!/bin/bash
# MMU UVM Verification Environment Setup
# Usage: source setup_env.sh  (must be sourced from mmu_verification/ root)

export PROJECT_DIR=${PWD}
export MMU_RTL_DIR=${PROJECT_DIR}/../mmu/rtl
export CV_DV_UTILS_DIR=${PROJECT_DIR}/modules/dv_utils/lib/cv_dv_utils

echo "PROJECT_DIR      = ${PROJECT_DIR}"
echo "MMU_RTL_DIR      = ${MMU_RTL_DIR}"
echo "CV_DV_UTILS_DIR  = ${CV_DV_UTILS_DIR}"

# Source local overrides if present (not tracked by git)
if [[ -f ${PROJECT_DIR}/setup.local.sh ]]; then
    source ${PROJECT_DIR}/setup.local.sh
fi
