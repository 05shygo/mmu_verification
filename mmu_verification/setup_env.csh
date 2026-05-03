#!/bin/csh
# MMU UVM Verification Environment Setup (csh/tcsh)
# Usage: source setup_env.csh
#
# For server-specific tool paths, create setup.local.csh from the template:
#   cp setup.local.csh.example setup.local.csh   # then edit with your VCS_HOME
# setup.local.csh is listed in .gitignore and is never committed.

set _mmu_setup_dir = `dirname $_`
setenv PROJECT_DIR     `cd ${_mmu_setup_dir} && pwd`
unset _mmu_setup_dir
setenv MMU_RTL_DIR     ${PROJECT_DIR}/../mmu/rtl
setenv CORE_V_VERIF    ${PROJECT_DIR}/modules/dv_utils
setenv CV_DV_UTILS_DIR ${CORE_V_VERIF}/lib/cv_dv_utils

# --- Load server-specific tool paths (not in git) ---
if ( -f ${PROJECT_DIR}/setup.local.csh ) then
    source ${PROJECT_DIR}/setup.local.csh
endif

# --- Auto-extend PATH from VCS_HOME if vcs not already in PATH ---
if ( $?VCS_HOME ) then
    which vcs >& /dev/null
    if ( $status != 0 ) then
        setenv PATH ${VCS_HOME}/bin:${PATH}
    endif
endif

# --- Auto-extend PATH from VERDI_HOME if verdi not already in PATH ---
if ( $?VERDI_HOME ) then
    which verdi >& /dev/null
    if ( $status != 0 ) then
        setenv PATH ${VERDI_HOME}/bin:${PATH}
    endif
endif

# --- Summary ---
echo "PROJECT_DIR      = ${PROJECT_DIR}"
echo "MMU_RTL_DIR      = ${MMU_RTL_DIR}"
echo "CORE_V_VERIF     = ${CORE_V_VERIF}"
echo "CV_DV_UTILS_DIR  = ${CV_DV_UTILS_DIR}"
which vcs >& /dev/null
if ( $status == 0 ) then
    echo "vcs              = `which vcs`"
else
    echo "WARNING: 'vcs' not found in PATH."
    echo "  -> Copy and edit the template: cp setup.local.csh.example setup.local.csh"
    echo "  -> Set VCS_HOME to your server's VCS install directory."
endif
