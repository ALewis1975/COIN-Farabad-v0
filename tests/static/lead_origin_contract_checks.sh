#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass=true

check() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -nE "$pattern" "$file" >/dev/null; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label"
    pass=false
  fi
}

check_absent() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -nE "$pattern" "$file" >/dev/null; then
    echo "[FAIL] $label"
    pass=false
  else
    echo "[PASS] $label"
  fi
}

check_absent_glob() {
  # Pattern must be absent across every tracked .sqf under functions/.
  local pattern="$1"
  local label="$2"
  if grep -rnE "$pattern" functions/ --include='*.sqf' >/dev/null; then
    echo "[FAIL] $label"
    grep -rnE "$pattern" functions/ --include='*.sqf' || true
    pass=false
  else
    echo "[PASS] $label"
  fi
}

LEADCREATE="functions/core/fn_leadCreate.sqf"
DECIDE="functions/command/fn_intelQueueDecide.sqf"
ORDER="functions/command/fn_intelOrderIssue.sqf"
OPSUI="functions/ui/fn_uiConsoleOpsPaint.sqf"
DASHUI="functions/ui/fn_uiConsoleDashboardPaint.sqf"
WORKUI="functions/ui/fn_uiConsoleWorkboardPaint.sqf"

# (a) Every lead record carries an origin.
# fn_leadCreate accepts an _origin param and injects an ["origin", ...] pair into
# missionMeta so the persisted record always carries an origin discriminator.
check '"_origin"' "$LEADCREATE" "leadCreate accepts an _origin parameter"
check '_missionMeta pushBack \["origin", _origin\]' "$LEADCREATE" "leadCreate injects an origin pair into missionMeta"
check '"FIELD"' "$LEADCREATE" "leadCreate defaults origin to FIELD for field emitters"

# S2/ISR/TOC-originated leads are stamped S2 at their create sites.
check 'call ARC_fnc_leadCreate.*"S2"|"S2"\] call ARC_fnc_leadCreate' "$DECIDE" "queueDecide stamps S2 origin on S2/ISR/TOC-created leads"

# (b) No live path issues a lead as an assignable field task.
# Path B (the LEAD order type) is deprecated: PROCEED/LEAD requests are coerced to
# STANDBY and the LEAD case is a no-op that consumes no lead.
check 'in \["PROCEED", "LEAD"\]\) then \{ _orderType = "STANDBY"' "$ORDER" "intelOrderIssue coerces PROCEED/LEAD order requests to STANDBY"
check_absent 'call ARC_fnc_leadConsumeNext' "$ORDER" "intelOrderIssue no longer consumes a lead by next"
check_absent 'call ARC_fnc_leadConsumeById' "$ORDER" "intelOrderIssue no longer consumes a lead by id"

# No live caller may issue a LEAD order to assign a lead as a field task.
check_absent_glob '\["LEAD"[^]]*\] call ARC_fnc_intelOrderIssue' "no live path issues a LEAD order via intelOrderIssue"

# Approved leads reach incidents only through the governed backlog path.
check 'call ARC_fnc_tocBacklogEnqueue' "$DECIDE" "queueDecide routes approved leads through the TOC backlog"

# Origin surfaced as a badge in the lead panels.
check '\[%1\]\[%2\]|\[FIELD\]|\[S2\]|_origin' "$OPSUI" "Ops paint renders a lead origin badge"
check '_origin|field %5 / S2 %6' "$DASHUI" "Dashboard paint shows FIELD/S2 origin breakdown"
check 'LEAD \[%1\]|_origin' "$WORKUI" "Workboard paint renders a lead origin badge"

if [[ "$pass" != true ]]; then
  echo "lead-origin contract checks: FAIL"
  exit 1
fi
echo "lead-origin contract checks: PASS"
