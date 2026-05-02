# -----------------------------------------------------------------------------
# MMU Phase 14 coverage exclusion / waiver policy
# -----------------------------------------------------------------------------
# Owner: Phase14 Closure Owner
# Tracker: ../../doc/MMU_Phase14_IssueTracker.md
#
# Phase 14 is a closure phase. Historical A-side/B-side ownership is retained
# for traceability, but active waiver/signoff execution is owned by the
# Phase14 Closure Owner.
#
# Active exclusion policy:
# - Every active `coverage exclude ...` command must carry a `-comment`.
# - The comment must include a Phase 14 tracker ID:
#     MMU-P14-ISSUE-NNN: <reason>
# - The referenced issue must exist in doc/MMU_Phase14_IssueTracker.md.
# - Waiver or signoff decisions require second review in
#   doc/MMU_Phase14_SignoffMatrix.md.
# - Small testcase/list/gate fixes can be closed directly by the Closure Owner.
# - Any change to signoff criteria, coverage threshold, waiver policy, or URG
#   fallback policy must be recorded in the issue tracker before gate/matrix
#   changes are accepted.
#
# No active exclusions are enabled at Phase 14 bootstrap. The baseline Phase 10
# policy remains in simu/exclude.do; this v4 file records only Phase 14
# tracker-backed exclusions and review policy.
#
# Example template only:
# coverage exclude -scope /tb_top/u_dut/<path> -togglenode {<signal>} \
#   -comment "MMU-P14-ISSUE-003: unreachable by documented protocol; reviewed in signoff matrix"
