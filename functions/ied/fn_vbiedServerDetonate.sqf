/*
    ARC_fnc_vbiedServerDetonate

    Phase 3 (VBIED v1): trigger-fired detonation handler.

    Params:
      0: STRING - deviceId (from trigger)

    Behavior:
      - Idempotent via state guard
      - Deletes trigger
      - Creates a best-effort explosion
      - Delegates to ARC_fnc_iedHandleDetonation with objKind VBIED_VEHICLE
*/

if (!isServer) exitWith {false};

params [
    ["_deviceId", "", [""]]
];

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

_deviceId = [_deviceId] call _trimFn;
if (_deviceId isEqualTo "") exitWith {false};

private _done = ["activeVbiedDetonated", false] call ARC_fnc_stateGet;
if (!(_done isEqualType true) && !(_done isEqualType false)) then { _done = false; };
if (_done) exitWith {true};

// If rendered safe, never detonate
private _safe = ["activeVbiedSafe", false] call ARC_fnc_stateGet;
if (!(_safe isEqualType true) && !(_safe isEqualType false)) then { _safe = false; };
if (_safe) exitWith {true};


// Resolve objective pos (fallback to stored record)
private _pos = ["activeObjectivePos", []] call ARC_fnc_stateGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
{
    private _rec = ["activeVbiedDeviceRecord", []] call ARC_fnc_stateGet;
    if (_rec isEqualType [] && { (count _rec) >= 5 }) then { _pos = _rec select 4; };
};
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;
if (!((_pos select 2) isEqualType 0)) then { _pos set [2, 0]; };

// Remove trigger
private _trgNid = ["activeVbiedTriggerNetId", ""] call ARC_fnc_stateGet;
if (_trgNid isEqualType "" && { !(_trgNid isEqualTo "") }) then
{
    private _trg = objectFromNetId _trgNid;
    if (!isNull _trg) then { deleteVehicle _trg; };
};

["activeVbiedDetonated", true] call ARC_fnc_stateSet;
["activeVbiedTriggerEnabled", false] call ARC_fnc_stateSet;
["activeVbiedDetonatedAt", serverTime] call ARC_fnc_stateSet;

// Best-effort explosion. (Gameplay abstraction; no construction details.)
private _cls = missionNamespace getVariable ["ARC_vbiedExplosionClass", "Bo_Mk82"]; // vanilla bomb explosion proxy
if (!(_cls isEqualType "") || { _cls isEqualTo "" }) then { _cls = "Bo_Mk82"; };
if !(isClass (configFile >> "CfgVehicles" >> _cls)) then { _cls = "Bo_Mk82"; };

private _boom = createVehicle [_cls, _pos, [], 0, "NONE"];
_boom setPosATL _pos;

// Delegate to existing detonation pipeline
private _c = ["activeVbiedDetCause", "PROX_TRIGGER"] call ARC_fnc_stateGet; if (!(_c isEqualType "")) then { _c = "PROX_TRIGGER"; }; _c = toUpper ([_c] call _trimFn); if (_c isEqualTo "") then { _c = "PROX_TRIGGER"; };
[_pos, "VBIED_VEHICLE", format ["VBIED_%1", _c]] call ARC_fnc_iedHandleDetonation;

true
