/*
    Server: broadcast lead-related debug state to clients.

    This makes TOC/UI tools reliable even when server->client remoteExec is restricted
    (and it's also a handy foundation for later: TOC lead selection UI, etc.).

    Broadcast variables:
      - ARC_leadPoolPublic (ARRAY)
      - ARC_lastLeadCreatedPublic (ARRAY)
      - ARC_lastLeadConsumedPublic (ARRAY)
      - ARC_leadPoolPublicUpdatedAt (NUMBER, serverTime)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

private _lastCreated = ["lastLeadCreated", []] call ARC_fnc_stateGet;
if (!(_lastCreated isEqualType [])) then { _lastCreated = []; };

private _lastConsumed = ["lastLeadConsumed", []] call ARC_fnc_stateGet;
if (!(_lastConsumed isEqualType [])) then { _lastConsumed = []; };

missionNamespace setVariable ["ARC_leadPoolPublic", _leads, true];
missionNamespace setVariable ["ARC_lastLeadCreatedPublic", _lastCreated, true];
missionNamespace setVariable ["ARC_lastLeadConsumedPublic", _lastConsumed, true];
missionNamespace setVariable ["ARC_leadPoolPublicUpdatedAt", serverTime, true];


// ---------------------------------------------------------------------------
// Console VM meta (rev) publish: monotonic rev to stabilize UI refresh ordering
// ---------------------------------------------------------------------------
private _rev = missionNamespace getVariable ["ARC_consoleVM_rev", 0];
if (!(_rev isEqualType 0)) then { _rev = 0; };
_rev = _rev + 1;
missionNamespace setVariable ["ARC_consoleVM_rev", _rev];
missionNamespace setVariable ["ARC_consoleVM_meta", [
    ["schema", "Console_VM_v1"],
    ["schemaVersion", 1],
    ["rev", _rev],
    ["publishedAt", serverTime],
    ["source", "leadBroadcast"]
], true];

true
