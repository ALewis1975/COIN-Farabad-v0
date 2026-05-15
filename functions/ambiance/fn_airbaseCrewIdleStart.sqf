/*
    File: functions/ambiance/fn_airbaseCrewIdleStart.sqf
    Author: ARC / Ambient Airbase Subsystem
    Description:
      Starts simple idle ambient animations on a set of units.
      Hard constraint: BIS_fnc_ambientAnim only.
*/

if (!isServer) exitWith {};

params ["_units"];
if (!(_units isEqualType [])) exitWith {};

// Airbase ambience should look unarmed. We intentionally avoid "armed" ambient anim
// presets (they can look like invisible rifles depending on unit loadouts).
private _setsUnarmed = [
    "STAND_U1",
    "STAND_U2",
    "STAND_U3",
    "SIT_LOW",
    "BRIEFING"
];

// Optional: repair-only sets (only used for units that have engineer capability or a ToolKit).
private _setsRepair = [
    "REPAIR_VEH_STAND",
    "REPAIR_VEH_KNEEL"
];

{
    private _u = _x;
    if (isNull _u) then { continue; };
    if (!alive _u) then { continue; };

    // Ensure the unit is on-foot (ambient anim won't play in-vehicle). Never
    // eject airborne aircrew; a late abort/re-idle path should fail safe instead.
    if (vehicle _u != _u) then {
        private _veh = vehicle _u;
        private _vehAlt = (getPosATL _veh) select 2;
        if ((_veh isKindOf "Air") && { _vehAlt > 1.5 || { (speed _veh) > 5 } }) then {
            diag_log format ["[AIRBASESUB][WARN] ARC_fnc_airbaseCrewIdleStart: skipped airborne in-vehicle crew unit=%1 vehicle=%2 alt=%3 speed=%4", _u, _veh, _vehAlt, speed _veh];
            continue;
        };
        moveOut _u;
    };

    doStop _u;

    // Hard reset any existing ambient anim (helps with some modded ground crew).
    if (!isNil "BIS_fnc_ambientAnim__terminate") then {
        [_u] call BIS_fnc_ambientAnim__terminate;
    };

    // Ensure cTab tracking device on dismounted aircrew (if cTab is loaded)
    if (isClass (configFile >> "CfgWeapons" >> "ItemAndroid")) then {
        if (!("ItemAndroid" in (assignedItems _u))) then { _u linkItem "ItemAndroid"; };
    };

    // Choose an unarmed ambient animation. Repair animations only if the unit can plausibly do it.
    private _canRepair = ("ToolKit" in (items _u)) || { ("ToolKit" in (assignedItems _u)) } || { (_u getUnitTrait "engineer") };
    private _set = selectRandom _setsUnarmed;
    if (_canRepair && { (random 1) < 0.25 }) then { _set = selectRandom _setsRepair; };
    [_u, _set, "ASIS"] call BIS_fnc_ambientAnim;

    _u setVariable ["airbase_idle", true, true];
} forEach _units;
