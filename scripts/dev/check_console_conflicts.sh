#!/usr/bin/env bash
# check_console_conflicts.sh — Static IDC collision check for Farabad Console
#
# Scans CfgDialogs.hpp for duplicate IDC values in the 78xxx range.
# Also checks that IDC 78140 (Region C) is not reused.
#
# Part of: Farabad Console Refactor Plan §9.1 static checks
# Usage: scripts/dev/check_console_conflicts.sh

set -euo pipefail

DIALOG_FILE="config/CfgDialogs.hpp"
EXIT_CODE=0

if [ ! -f "$DIALOG_FILE" ]; then
    echo "[FAIL] $DIALOG_FILE not found"
    exit 1
fi

echo "=== Farabad Console IDC collision check ==="

# Extract all IDC values in the 78xxx range
IDCS=$(grep -oP 'idc\s*=\s*\K78\d+' "$DIALOG_FILE" | sort)
DUPES=$(echo "$IDCS" | uniq -d)

if [ -n "$DUPES" ]; then
    echo "[FAIL] Duplicate IDCs found:"
    echo "$DUPES" | while read idc; do
        echo "  IDC $idc appears $(echo "$IDCS" | grep -c "^${idc}$") times"
        grep -n "idc *= *$idc" "$DIALOG_FILE" | head -5
    done
    EXIT_CODE=1
else
    echo "[PASS] No duplicate IDCs in 78xxx range"
fi

# Check reserved IDC ranges
echo ""
echo "=== IDC range audit ==="
echo "  78001-78024: Core panes + buttons"
echo "  78030-78038: OPS frames"
echo "  78050-78055: S2 workflow"
echo "  78060-78063: Status strip"
echo "  78090-78099: Shell frame"
echo "  78130-78137: AIR/TOWER"
echo "  78140:       Region C (Visual Panel)"
echo "  78141-78149: Reserved (future AIR/Region)"
echo ""

# Check for any IDC outside known ranges
UNKNOWN=$(echo "$IDCS" | grep -vE '^(78001|7801[0-6]|7802[1-4]|7803[0-8]|7805[0-5]|7806[0-3]|7809[0-9]|7813[0-7]|78140)$' || true)
if [ -n "$UNKNOWN" ]; then
    echo "[WARN] IDCs outside documented ranges:"
    echo "$UNKNOWN" | while read idc; do
        echo "  IDC $idc — verify this is intentional"
    done
else
    echo "[PASS] All IDCs within documented ranges"
fi

echo ""
echo "=== Console painter contract check ==="

# Check that all painters call at least one shared helper or have VM reads
PAINTERS=(
    "functions/ui/fn_uiConsoleDashboardPaint.sqf"
    "functions/ui/fn_uiConsoleOpsPaint.sqf"
    "functions/ui/fn_uiConsoleCommandPaint.sqf"
    "functions/ui/fn_uiConsoleAirPaint.sqf"
    "functions/ui/fn_uiConsoleBoardsPaint.sqf"
    "functions/ui/fn_uiConsoleIntelPaint.sqf"
    "functions/ui/fn_uiConsoleHandoffPaint.sqf"
    "functions/ui/fn_uiConsoleHQPaint.sqf"
    "functions/ui/fn_uiConsoleS1Paint.sqf"
)

for painter in "${PAINTERS[@]}"; do
    if [ ! -f "$painter" ]; then
        echo "  [SKIP] $painter not found"
        continue
    fi
    # Check for shared helper usage (at least one of: GetPair, FormatEmptyState, ButtonState, FormatDetail, FormatStatusChip)
    SHARED_USAGE=$(grep -c 'ARC_fnc_uiConsole' "$painter" 2>/dev/null || true)
    SHARED_USAGE=$(echo "$SHARED_USAGE" | tr -d '[:space:]')
    if [ -z "$SHARED_USAGE" ]; then SHARED_USAGE=0; fi
    VM_USAGE=$(grep -c 'consoleVmAdapterV1' "$painter" 2>/dev/null || true)
    VM_USAGE=$(echo "$VM_USAGE" | tr -d '[:space:]')
    if [ -z "$VM_USAGE" ]; then VM_USAGE=0; fi
    if [ "$SHARED_USAGE" -gt 0 ] || [ "$VM_USAGE" -gt 0 ]; then
        echo "  [PASS] $(basename "$painter"): shared=$SHARED_USAGE VM=$VM_USAGE"
    else
        echo "  [INFO] $(basename "$painter"): no shared helpers or VM reads (may be pre-migration)"
    fi
done

echo ""
echo "=== Done ==="
exit $EXIT_CODE
