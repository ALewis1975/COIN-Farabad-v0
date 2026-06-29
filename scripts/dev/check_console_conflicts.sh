#!/usr/bin/env bash
# check_console_conflicts.sh — Static IDC collision check for Farabad Console
#
# Scans CfgDialogs.hpp for duplicate IDC values in the 78xxx range within
# each top-level dialog/display class. Reusing an IDC in separate dialogs is
# valid; reusing an IDC inside the same dialog is a collision.
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

# Extract all IDC values in the 78xxx range with their enclosing top-level dialog.
IDC_ROWS=$(awk '
    BEGIN { depth = 0; top = "<global>"; }
    {
        line = $0;
        if (depth == 0 && match(line, /^[[:space:]]*class[[:space:]]+[A-Za-z0-9_]+/)) {
            top = line;
            sub(/^[[:space:]]*class[[:space:]]+/, "", top);
            sub(/[[:space:]:{].*$/, "", top);
        }
        if (match(line, /idc[[:space:]]*=[[:space:]]*78[0-9]+/)) {
            idc = line;
            sub(/^.*idc[[:space:]]*=[[:space:]]*/, "", idc);
            sub(/[^0-9].*$/, "", idc);
            print top ":" idc ":" NR;
        }
        opens = gsub(/\{/, "{", line);
        closes = gsub(/\}/, "}", line);
        depth += opens - closes;
        if (depth < 0) { depth = 0; }
    }
' "$DIALOG_FILE")

if [ -z "$IDC_ROWS" ]; then
    echo "[PASS] No 78xxx IDCs found"
    IDCS=""
else
    IDCS=$(echo "$IDC_ROWS" | awk -F: '{print $2}' | sort)
fi

DUPES=$(echo "$IDC_ROWS" | awk -F: '{print $1 ":" $2}' | sort | uniq -d)

if [ -n "$DUPES" ]; then
    echo "[FAIL] Duplicate IDCs found within a dialog:"
    echo "$DUPES" | while IFS=: read -r dialog idc; do
        echo "  ${dialog}: IDC $idc appears more than once"
        echo "$IDC_ROWS" | awk -F: -v d="$dialog" -v i="$idc" '$1 == d && $2 == i {print "    line " $3}'
    done
    EXIT_CODE=1
else
    echo "[PASS] No duplicate IDCs within any top-level dialog"
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
echo "  78141:       Tablet frame background (TabletFrame, static controlsBackground)"
echo "  78142-78149: Reserved (future AIR/Region)"
echo "  78200-78299: Modal action dialogs (EOD, closeout)"
echo "  78300-78499: Recruit dialog"
echo ""

# Check for any IDC outside known ranges
UNKNOWN=$(echo "$IDCS" | grep -vE '^(78001|7801[0-6]|7802[1-4]|7803[0-8]|7805[0-5]|7806[0-3]|7809[0-9]|7810[1-9]|7811[0-8]|7812[0-1]|7813[0-7]|78140|7814[1-9]|7819[0-2]|782[0-9][0-9]|783[0-9][0-9]|784[0-9][0-9])$' || true)
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
    "functions/ui/fn_uiConsoleCommsPaint.sqf"
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
