/*
    ARC_fnc_iedChainDetonate

    Server-only: detonate the secondary chain devices linked to a primary IED
    device in a staggered sequence. Idempotent per primary device id — safe to
    call from both the explicit detonation path (ARC_fnc_iedServerDetonate) and
    the primary object's "Killed" event handler.

    Params:
      0: STRING primaryDeviceNetId
      1: ARRAY  chainNetIds (optional; falls back to ARC_activeIedChainNetIds)

    Returns:
      BOOL true if a detonation sequence was started
*/

if (!isServer) exitWith {false};

params [
    ["_primaryNid", "", [""]],
    ["_chainNetIds", [], [[]]]
];

if (_primaryNid isEqualTo "") exitWith {false};

// Idempotency guard: one sequence per primary device.
private _doneList = missionNamespace getVariable ["ARC_iedChainDetonatedPrimaries", []];
if (!(_doneList isEqualType [])) then { _doneList = []; };
if (_primaryNid in _doneList) exitWith {false};

if ((count _chainNetIds) == 0) then
{
    _chainNetIds = missionNamespace getVariable ["ARC_activeIedChainNetIds", []];
    if (!(_chainNetIds isEqualType [])) then { _chainNetIds = []; };
};
if ((count _chainNetIds) == 0) exitWith {false};

_doneList pushBack _primaryNid;
// Keep the guard list bounded.
if ((count _doneList) > 20) then { _doneList = _doneList select [(count _doneList) - 20, 20]; };
missionNamespace setVariable ["ARC_iedChainDetonatedPrimaries", _doneList, false];
private _boomClass = "Bo_Mk82";
if !(isClass (configFile >> "CfgVehicles" >> _boomClass)) then { _boomClass = "Bo_GBU12_LGB"; };

private _delay = 2;
{
    private _nid = _x;
    private _d = _delay;
    [_nid, _d, _boomClass] spawn {
        params ["_chainNid", "_delayS", "_boom"];
        sleep _delayS;
        private _chainObj = objectFromNetId _chainNid;
        if (isNull _chainObj) then
        {
            diag_log format ["[ARC][WARN] ARC_fnc_iedChainDetonate: chain device not found netId=%1", _chainNid];
        }
        else
        {
            if (alive _chainObj) then
            {
                private _p = getPosATL _chainObj;
                _p resize 3; _p set [2, 0];
                createVehicle [_boom, _p, [], 0, "CAN_COLLIDE"];
                deleteVehicle _chainObj;
                diag_log format ["[ARC][INFO] ARC_fnc_iedChainDetonate: chain device detonated netId=%1", _chainNid];
            };
        };
    };
    _delay = _delay + 2 + (floor (random 4));
} forEach _chainNetIds;

diag_log format ["[ARC][INFO] ARC_fnc_iedChainDetonate: sequence started primary=%1 chainCount=%2", _primaryNid, count _chainNetIds];

true
