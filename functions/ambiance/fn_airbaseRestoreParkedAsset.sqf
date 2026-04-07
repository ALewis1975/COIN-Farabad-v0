/*
    File: functions/ambiance/fn_airbaseRestoreParkedAsset.sqf
    Author: ARC / Ambient Airbase Subsystem

    Description:
      Respawns an airbase asset (aircraft + idle crew) back at its original 3DEN start positions
      using templates captured during ARC_fnc_airbaseInit.

      This is used for:
        - Return arrivals (after the inbound flight completes)
        - "Restock" when a departed aircraft does NOT roll a return flight (keeps the ramp populated)

    Params:
      0: HASHMAP - asset runtime hash

    Returns:
      BOOL - true if restored successfully
*/

if (!isServer) exitWith { false };

params ["_asset"];
if (isNil "_asset" || {!(_asset isEqualType createHashMap)}) exitWith { false };

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _vehVar = [_asset, "vehVar", ""] call _hg;

private _spawnType = [_asset, "startVehType", ""] call _hg;
private _startPos  = [_asset, "startPos", [0,0,0]] call _hg;
private _startDir  = [_asset, "startDir", 0] call _hg;
private _startVecUp = [_asset, "startVecUp", [0,0,1]] call _hg;

if (_spawnType isEqualTo "" || {!(_startPos isEqualType [])} || {(count _startPos) < 2}) exitWith { false };

// Safety: delete any lingering vehicle reference
private _oldVeh = [_asset, "veh", objNull] call _hg;
if (!isNull _oldVeh) then { deleteVehicle _oldVeh; };

private _newVeh = createVehicle [_spawnType, _startPos, [], 0, "NONE"];
_newVeh allowDamage false;
_newVeh enableSimulationGlobal false;
_newVeh setPosATL _startPos;
_newVeh setDir _startDir;
_newVeh setVectorUp _startVecUp;
_newVeh setVelocity [0,0,0];
_newVeh setVelocityModelSpace [0,0,0];
sleep 0.1;
_newVeh enableSimulationGlobal true;
_newVeh allowDamage true;
_newVeh engineOn false;

if (_vehVar != "") then {
    missionNamespace setVariable [_vehVar, _newVeh, true];
};

_asset set ["veh", _newVeh];

// Respawn crew from templates
private _templates = [_asset, "crewTemplates", []] call _hg;
private _crewSide  = [_asset, "crewSide", west] call _hg;

private _grpCrew = createGroup [_crewSide, true];

// Name restored crew group from the asset's callsign (e.g., PEGASUS, GRYPHON, DUSTOFF).
private _assetCallsign = [_asset, "callsign", ""] call _hg;
if (_assetCallsign isEqualType "" && { _assetCallsign isNotEqualTo "" }) then {
    _grpCrew setGroupIdGlobal [format ["%1 Crew", _assetCallsign]];
} else {
    _grpCrew setGroupIdGlobal ["FARABAD Ramp Crew"];
};

private _newCrew = [];
{
    _x params ["_vName", "_class", "_loadout", "_pos", "_dir"];

    if (_class isEqualTo "") then { continue; };
    if (!(_pos isEqualType []) || {(count _pos) < 2}) then { continue; };

    private _u = _grpCrew createUnit [_class, _pos, [], 0, "NONE"];
    _u setDir _dir;
    _u setPosATL _pos;

    if (_loadout isEqualType [] && { (count _loadout) > 0 }) then {
        _u setUnitLoadout _loadout;
    };

    if (_vName != "") then {
        missionNamespace setVariable [_vName, _u, true];
    };

    _newCrew pushBack _u;
} forEach _templates;

_asset set ["crew", _newCrew];
_asset set ["state", "PARKED"];
_asset set ["activeFlight", ""];
_asset set ["availableAt", 0];

// Restart idle ambience
if ((count _newCrew) > 0) then {
    [_newCrew] call ARC_fnc_airbaseCrewIdleStart;
};

true
