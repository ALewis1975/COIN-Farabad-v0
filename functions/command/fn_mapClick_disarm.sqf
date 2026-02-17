/*
    ARC_fnc_mapClick_disarm

    Client utility: clears map-click handler state and closes the map.

    Params:
      0: STRING reason (optional)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [["_reason", ""]];
private _reasonUp = toUpper _reason;
private _alreadyCleaned = uiNamespace getVariable ["ARC_mapClick_cleanupDone", false];
if (_alreadyCleaned) exitWith {true};

private _terminalState = switch (_reasonUp) do
{
    case "SUBMITTED": {"SUBMITTED"};
    case "TIMEOUT": {"TIMEOUT"};
    case "CANCELLED": {"CANCELLED"};
    case "MAP_CLOSED": {"CANCELLED"};
    case "REARM": {"CANCELLED"};
    default {"CANCELLED"};
};

if (_terminalState isEqualTo "CANCELLED") then
{
    private _cancelReason = if (_reasonUp isEqualTo "") then {"UNKNOWN"} else {_reasonUp};
    diag_log format ["[FARABAD][MAPCLICK][CANCEL] reason=%1", _cancelReason];
};

uiNamespace setVariable ["ARC_mapClick_cleanupDone", true];
onMapSingleClick "";
openMap [false, false];

uiNamespace setVariable ["ARC_mapClick_state", _terminalState];
uiNamespace setVariable ["ARC_mapClick_ctx", nil];
uiNamespace setVariable ["ARC_mapClick_armedAt", nil];
uiNamespace setVariable ["ARC_mapClick_deadline", nil];
uiNamespace setVariable ["ARC_mapClick_lastPos", nil];
uiNamespace setVariable ["ARC_mapClick_lastErr", _reasonUp];

true
