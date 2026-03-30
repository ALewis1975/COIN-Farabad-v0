/*
    ARC_fnc_medicalTick

    Server-only: slow medical recovery tick.

    Applies a small positive recovery to baseMed each time it is called,
    simulating periodic medical resupply missions. Rate is capped so that
    natural recovery cannot outpace the ongoing drain from ARC_fnc_incidentTick.

    Call from ARC_fnc_incidentTick (slow path, once per sustain period).

    Params: none
    Returns: BOOL
*/

if (!isServer) exitWith {false};

private _med = ["baseMed", 0.57] call ARC_fnc_stateGet;
if (!(_med isEqualType 0)) then { _med = 0.57; };
_med = (_med max 0) min 1;

// Maximum baseMed recovery ceiling (configurable)
private _ceiling = missionNamespace getVariable ["ARC_medRecoveryCeiling", 0.72];
if (!(_ceiling isEqualType 0)) then { _ceiling = 0.72; };
_ceiling = (_ceiling max 0.10) min 1;

// Recovery is only applied when below the ceiling
if (_med >= _ceiling) exitWith { false };

// Per-tick recovery step (configurable)
private _step = missionNamespace getVariable ["ARC_medRecoveryStep", 0.01];
if (!(_step isEqualType 0)) then { _step = 0.01; };
_step = (_step max 0) min 0.05;

_med = (_med + _step) min _ceiling;
["baseMed", _med] call ARC_fnc_stateSet;
missionNamespace setVariable ["ARC_pub_baseMed", _med, true];

true
