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

onMapSingleClick "";
openMap [false, false];

uiNamespace setVariable ["ARC_mapClick_state", "IDLE"];
uiNamespace setVariable ["ARC_mapClick_ctx", nil];
uiNamespace setVariable ["ARC_mapClick_armedAt", nil];
uiNamespace setVariable ["ARC_mapClick_lastPos", nil];
uiNamespace setVariable ["ARC_mapClick_lastErr", _reason];

true
