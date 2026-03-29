/*
    Broadcast a presentation-safe Intel snapshot for clients (JIP-safe).

    Sets:
      - ARC_pub_intelLog (Array of non-OPS entries)
      - ARC_pub_opsLog (Array of OPS entries)
      - ARC_pub_intelUpdatedAt (Number: serverTime)
*/

if (!isServer) exitWith {false};

private _log = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_log isEqualType [])) then { _log = []; };

private _intel = _log select { _x isEqualType [] && { (count _x) >= 3 } && { toUpper !((_x # 2) isEqualTo "OPS") } };
private _ops   = _log select { _x isEqualType [] && { (count _x) >= 3 } && { toUpper (_x # 2) isEqualTo "OPS" } };

private _iCount = count _intel;
private _oCount = count _ops;
private _iStart = (_iCount - 40) max 0;
private _oStart = (_oCount - 40) max 0;

private _intelSlice = _intel select [_iStart, _iCount - _iStart];
private _opsSlice   = _ops select [_oStart, _oCount - _oStart];

missionNamespace setVariable ["ARC_pub_intelLog", _intelSlice, true];
missionNamespace setVariable ["ARC_pub_opsLog", _opsSlice, true];
missionNamespace setVariable ["ARC_pub_intelUpdatedAt", serverTime, true];

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
    ["source", "intelBroadcast"]
], true];

true
