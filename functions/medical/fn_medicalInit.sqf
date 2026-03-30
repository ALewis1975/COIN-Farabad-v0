/*
    ARC_fnc_medicalInit

    Server-only: initialize the medical subsystem.

    Registers a mission-level EntityKilled event handler that updates
    baseMed and casualty counters when BLUFOR or civilian units are killed.

    Called once from ARC_fnc_bootstrapServer.

    Returns: BOOL
*/

if (!isServer) exitWith {false};

// Guard: only register once per server session
if (missionNamespace getVariable ["ARC_medical_initialized", false]) exitWith
{
    diag_log "[ARC][MEDICAL] medicalInit: already initialized, skipping.";
    true
};
missionNamespace setVariable ["ARC_medical_initialized", true];

// Ensure baseline values are sane on first init
private _baseMed = ["baseMed", 0.57] call ARC_fnc_stateGet;
if (!(_baseMed isEqualType 0)) then { _baseMed = 0.57; };
_baseMed = (_baseMed max 0) min 1;
["baseMed", _baseMed] call ARC_fnc_stateSet;

private _civCasualties = ["civCasualties", 0] call ARC_fnc_stateGet;
if (!(_civCasualties isEqualType 0)) then { _civCasualties = 0; };
_civCasualties = _civCasualties max 0;
["civCasualties", _civCasualties] call ARC_fnc_stateSet;

private _baseCasualties = ["baseCasualties", 0] call ARC_fnc_stateGet;
if (!(_baseCasualties isEqualType 0)) then { _baseCasualties = 0; };
_baseCasualties = _baseCasualties max 0;
["baseCasualties", _baseCasualties] call ARC_fnc_stateSet;

// Mission-wide EntityKilled handler (server is the only machine that runs this)
addMissionEventHandler ["EntityKilled", {
    params ["_entity", "_killer", "_instigator", "_useEffects"];
    if (!isServer) exitWith {};

    private _entSide = side (group _entity);
    if !(_entSide in [west, civilian]) exitWith {};

    // Fail-safe compile
    if (isNil "ARC_fnc_medicalOnCasualty") then {
        ARC_fnc_medicalOnCasualty = compile preprocessFileLineNumbers "functions\\medical\\fn_medicalOnCasualty.sqf";
    };

    [_entity, _entSide] call ARC_fnc_medicalOnCasualty;
}];

diag_log "[ARC][MEDICAL] medicalInit: EntityKilled handler registered.";
true
