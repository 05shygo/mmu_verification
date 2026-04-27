# -----------------------------------------------------------------------------
# MMU Phase 10 baseline coverage exclusion file
# -----------------------------------------------------------------------------
# Owner: Engineer B (Phase 10 list/coverage-waiver baseline only)
#
# This file is intentionally shipped with zero active exclusions.
# Rationale:
# 1. Current MMU coverage hierarchy is still using the stale HPDcache example
#    in scripts/cov_hier.cfg and has not yet been corrected by Phase 10 A-side
#    script work to the final MMU DUT hierarchy.
# 2. Current legacy script paths still disagree on `simu/` vs `testbench/simu/`,
#    so adding active `coverage exclude` entries now would risk baking in wrong
#    scope paths.
# 3. Phase 10 B-side responsibility is to provide a reviewable waiver baseline;
#    actual exclusions should only be activated after the first MMU HTML/URG
#    report is produced under the A-owned regress/cov flow.
#
# Policy for all future active exclusions:
# - Every `coverage exclude ...` command must carry a `-comment`.
# - The comment must include:
#   - why the point is excluded,
#   - the design / architecture / tool basis,
#   - the close condition or owning bug / waiver reference.
# - No bare exclusion commands are allowed.
#
# Allowed reason classes:
# - reserved field / architecturally unused
# - unreachable by protocol / onehot design constraint
# - known RTL gap with explicit bug/JIRA owner
# - temporary integration / tool limitation
#
# Example template only; do not uncomment until MMU hierarchy is confirmed:
# coverage exclude -scope /top/u_dut/<path> -togglenode {<sig>[0]} \
#   -comment "EXAMPLE ONLY: reserved bit by architecture; close when hierarchy \
#   is confirmed and waiver is approved"
